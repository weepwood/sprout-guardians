extends "res://scripts/greed/survivor_game.gd"

const HERO_SCENE: PackedScene = preload("res://scenes/actors/hero_plant.tscn")
const FAMILIAR_SUN_SCENE: PackedScene = preload("res://scenes/actors/familiar_sun.tscn")
const FAMILIAR_SPROUT_SCENE: PackedScene = preload("res://scenes/actors/familiar_sprout.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/actors/enemy.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/effects/projectile.tscn")
const EXPERIENCE_GEM_SCENE: PackedScene = preload("res://scenes/effects/experience_gem.tscn")

var experience_bar: ProgressBar
var pixel_skin: PixelSkinController
var map_id: int = SurvivorMaps.CLASSIC
var world_camera: Camera2D
var simulation_character: int = 0
var challenge_active: bool = false
var challenge_date: String = ""
var damage_by_enemy: Dictionary = {"contact": 0, "ranged": 0, "boss": 0}
var _current_threat: String = "contact"
var damage_by_source: Dictionary = {"hero": 0.0, "familiar": 0.0, "arsenal": 0.0}
var damage_received: int = 0
var _previous_health: int = -1
var _projectile_source: String = "arsenal"
var simulation_map: int = 0
var map_events: SurvivorMapEvents = SurvivorMapEvents.new()
var event_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var event_nodes: Array[Sprite2D] = []
var magnet_until: float = -1.0
var evolution_announced: Dictionary = {}
var effect_sprites: Array[Sprite2D] = []
var run_state: SurvivorRunState
var run_trace: SurvivorRunTrace
var run_save: SaveGameService
var pause_open: bool = false
var pause_backdrop: ColorRect
var pause_panel: Panel
var pause_title: Label
var pause_subtitle: Label
var pause_resume_button: Button
var pause_leave_button: Button
var pause_build_label: Label
var reward_rerolls: int = 2
var reroll_button: Button
var skip_button: Button
var choice_hint: Label
var choice_badge: TextureRect
var reward_focus_index: int = 0
var warning_frame: Panel
var combo_label: Label
var _warning_seconds: float = 0.0
var _warning_message: String = ""
var _combo_count: int = 0
var _combo_seconds: float = 0.0
const COMBO_TIMEOUT: float = 3.2

var actors_container: Node2D
var enemies_container: Node2D
var projectile_pool: SurvivorNodePool = SurvivorNodePool.new()
var pickup_pool: SurvivorNodePool = SurvivorNodePool.new()
var _next_pickup_sound: int = 0
var _next_hit_sound: int = 0
var projectiles_container: Node2D
var pickups_container: Node2D
var effects_container: Node2D
var editor_preview: Node2D
var player_spawn: Marker2D
var familiar_spawn_sun: Marker2D
var familiar_spawn_sprout: Marker2D


func _ready() -> void:
    challenge_active = SurvivorChallenge.selected and not simulation_mode
    if not simulation_mode:
        endless_mode = SurvivorEndurance.selected and not challenge_active
    if challenge_active:
        challenge_date = SurvivorChallenge.date_key()
        run_seed = SurvivorChallenge.seed_for(challenge_date)
    if not simulation_mode:
        run_save = SaveGameService.new()
        run_save.load_game()
    super._ready()
    event_rng.seed = run_seed ^ 0x6375
    _setup_map()
    pixel_skin = get_node("PixelSkinController") as PixelSkinController
    run_state = get_node("RunState") as SurvivorRunState
    run_trace = get_node("RunTrace") as SurvivorRunTrace
    run_state.phase_changed.connect(_on_run_phase_changed)
    run_state.start_run()
    if simulation_mode:
        combat_feedback.hit_stop_enabled = false
        audio_manager.set_music_enabled(false)
        audio_manager.set_sfx_enabled(false)
    if impact_system != null:
        impact_system.z_index = 9
    _apply_playful_hud()
    _apply_locale()
    _refresh_hud()


func _draw() -> void:
    pass


func _bind_scene_nodes() -> void:
    if actors_container != null:
        return
    actors_container = get_node("World/Runtime/Actors") as Node2D
    enemies_container = get_node("World/Runtime/Enemies") as Node2D
    projectiles_container = get_node("World/Runtime/Projectiles") as Node2D
    pickups_container = get_node("World/Runtime/Pickups") as Node2D
    effects_container = get_node("World/Runtime/Effects") as Node2D
    editor_preview = get_node("World/EditorPreview") as Node2D
    player_spawn = get_node("World/Runtime/Actors/PlayerSpawn") as Marker2D
    familiar_spawn_sun = get_node("World/Runtime/Actors/FamiliarSpawnSun") as Marker2D
    familiar_spawn_sprout = get_node("World/Runtime/Actors/FamiliarSpawnSprout") as Marker2D


func _create_services() -> void:
    _bind_scene_nodes()
    super._create_services()
    if impact_system != null and impact_system.get_parent() != effects_container:
        impact_system.reparent(effects_container, true)
    if combat_feedback != null and combat_feedback.get_parent() != effects_container:
        combat_feedback.reparent(effects_container, true)


func _create_arena() -> void:
    _bind_scene_nodes()
    editor_preview.visible = false

    hero_plant = HERO_SCENE.instantiate() as GreedHeroPlant
    hero_plant.name = "MainPlant"
    actors_container.add_child(hero_plant)
    hero_plant.global_position = player_spawn.global_position
    var character_id: int = simulation_character if simulation_mode else SurvivorCharacters.selected
    if not simulation_mode and run_save != null and not run_save.is_survivor_character_unlocked(character_id):
        character_id = 0
    var hero_config: Dictionary = SurvivorCharacters.configuration(character_id)
    hero_plant.max_health = maxi(1, hero_plant.max_health + int(hero_config.get("health_bonus", 0)))
    hero_plant.health = hero_plant.max_health
    if not simulation_mode and not challenge_active and run_save != null:
        var progress: Dictionary = run_save.get_survivor_progress()
        hero_config["move_speed"] = float(hero_config["move_speed"]) * (1.0 + 0.03 * int(progress["speed_rank"]))
        hero_config["damage"] = float(hero_config["damage"]) * (1.0 + 0.05 * int(progress["damage_rank"]))
        hero_plant.max_health += int(progress["health_rank"])
        hero_plant.health = hero_plant.max_health
    hero_plant.configure(hero_config, blessing_system)
    _previous_health = hero_plant.health
    hero_plant.health_changed.connect(_track_health)
    hero_plant.health_changed.connect(_on_core_health_changed)
    hero_plant.defeated.connect(_on_core_defeated)
    hero_plant.fired.connect(_on_hero_fired)
    hero_plant.projectile_requested.connect(_on_attributed_projectile.bind("hero"))
    hero_plant.dash_started.connect(_on_hero_dash_started)
    core = hero_plant

    plants.clear()
    var familiar_scenes: Array[PackedScene] = [FAMILIAR_SUN_SCENE, FAMILIAR_SPROUT_SCENE]
    var familiar_spawns: Array[Marker2D] = [familiar_spawn_sun, familiar_spawn_sprout]
    for familiar_index: int in range(familiar_scenes.size()):
        var config_index: int = familiar_index + 1
        var familiar: GreedPlant = familiar_scenes[familiar_index].instantiate() as GreedPlant
        familiar.name = "FloatingFamiliar%d" % familiar_index
        actors_container.add_child(familiar)
        familiar.global_position = familiar_spawns[familiar_index].global_position
        var familiar_config: Dictionary = GreedBalance.STARTER_PLANTS[config_index].duplicate(true)
        familiar_config["survivor_art"] = true
        familiar.configure(hero_plant, familiar_config, familiar_index, blessing_system)
        familiar.set_focus_source(hero_plant)
        familiar.fired.connect(_on_plant_fired)
        familiar.projectile_requested.connect(_on_attributed_projectile.bind("familiar"))
        plants.append(familiar)


func _create_ui() -> void:
    wave_label = get_node("UI/TopHUD/TimeLabel") as Label
    health_label = get_node("UI/TopHUD/HealthLabel") as Label
    coins_label = get_node("UI/TopHUD/KillsLabel") as Label
    greed_label = get_node("UI/TopHUD/LevelLabel") as Label
    language_button = get_node("UI/TopHUD/LanguageButton") as Button
    speed_button = get_node("UI/TopHUD/SpeedButton") as Button
    menu_button = get_node("UI/TopHUD/MenuButton") as Button
    power_label = get_node("UI/PowerLabel") as Label
    control_label = get_node("UI/ControlLabel") as Label
    status_label = get_node("UI/StatusLabel") as Label
    experience_bar = get_node("UI/ExperienceBar") as ProgressBar
    warning_frame = get_node("UI/WarningFrame") as Panel
    combo_label = get_node("UI/ComboLabel") as Label

    choice_backdrop = get_node("UI/ChoiceLayer/Backdrop") as ColorRect
    choice_panel = get_node("UI/ChoiceLayer/Panel") as Panel
    choice_title = get_node("UI/ChoiceLayer/Title") as Label
    choice_hint = get_node("UI/ChoiceLayer/ChoiceHint") as Label
    choice_badge = get_node("UI/ChoiceLayer/ChoiceSigil") as TextureRect
    reroll_button = get_node("UI/ChoiceLayer/RerollButton") as Button
    skip_button = get_node("UI/ChoiceLayer/SkipButton") as Button
    reroll_button.pressed.connect(_reroll_reward)
    skip_button.pressed.connect(_skip_reward)
    result_label = get_node("UI/ChoiceLayer/ResultLabel") as Label
    result_button = get_node("UI/ChoiceLayer/ResultButton") as Button

    choice_buttons.clear()
    for index: int in range(3):
        var button: Button = get_node("UI/ChoiceLayer/ChoiceButton%d" % index) as Button
        choice_buttons.append(button)
        if not button.pressed.is_connected(_select_choice.bind(index)):
            button.pressed.connect(_select_choice.bind(index))

    if not language_button.pressed.is_connected(_toggle_language):
        language_button.pressed.connect(_toggle_language)
    if not speed_button.pressed.is_connected(_cycle_speed):
        speed_button.pressed.connect(_cycle_speed)
    if not menu_button.pressed.is_connected(_toggle_pause):
        menu_button.pressed.connect(_toggle_pause)
    if not result_button.pressed.is_connected(_restart_run):
        result_button.pressed.connect(_restart_run)

    pause_backdrop = get_node("UI/PauseLayer/Backdrop") as ColorRect
    pause_panel = get_node("UI/PauseLayer/Panel") as Panel
    pause_title = get_node("UI/PauseLayer/Title") as Label
    pause_subtitle = get_node("UI/PauseLayer/Subtitle") as Label
    pause_resume_button = get_node("UI/PauseLayer/ResumeButton") as Button
    pause_leave_button = get_node("UI/PauseLayer/LeaveButton") as Button
    pause_build_label = get_node("UI/PauseLayer/BuildSummary") as Label
    pause_resume_button.pressed.connect(_toggle_pause)
    pause_leave_button.pressed.connect(_return_to_menu)

    _refresh_hud()


func _on_projectile_requested(
        origin: Vector2,
        target: GreedEnemy,
        damage: float,
        critical: bool,
        speed: float,
        splash_radius: float,
        slow_ratio: float,
        knockback_force: float,
        color: Color
) -> void:
    if target == null or not is_instance_valid(target):
        return
    var projectile: GreedProjectile = projectile_pool.acquire(PROJECTILE_SCENE, projectiles_container) as GreedProjectile
    projectile.recycle = projectile_pool.release
    projectile.source_kind = _projectile_source
    if not projectile.damage_applied.is_connected(_record_source_damage):
        projectile.damage_applied.connect(_record_source_damage)
    projectile.configure(
        origin,
        target,
        damage,
        critical,
        speed,
        splash_radius,
        slow_ratio,
        knockback_force,
        color
    )
    launched_projectiles += 1


func _spawn_survivor_enemy(force_elite: bool, force_boss: bool) -> GreedEnemy:
    var config: Dictionary = spawn_director.next_enemy(survival_elapsed, force_elite, force_boss)
    if force_boss:
        config = SurvivorBiomeBoss.apply(config, map_id)
    if map_id != SurvivorMaps.CLASSIC and not force_elite and not force_boss and survival_elapsed >= 25.0 and event_rng.randf() < SurvivorSpawnDirector.biome_variant_chance(map_id, survival_elapsed):
        config = SurvivorBalance.enemy_config(survival_elapsed, difficulty, false, false, SurvivorMaps.exclusive_variant(map_id))
        config["biome_enemy"] = map_id
        config["health"] = float(config["health"]) * 1.12
    if endless_mode:
        config["health"] = float(config["health"]) * SurvivorEndurance.enemy_multiplier(survival_elapsed)
    return _spawn_configured_enemy(config, _survivor_spawn_edge())


func _spawn_configured_enemy(config: Dictionary, position_value: Vector2) -> GreedEnemy:
    var enemy: GreedEnemy = ENEMY_SCENE.instantiate() as GreedEnemy
    enemy.name = "SurvivorEnemy"
    enemies_container.add_child(enemy)
    enemy.global_position = position_value
    enemy.configure(hero_plant, config, 1.0)
    enemy.damaged.connect(_on_enemy_damaged)
    enemy.defeated.connect(_on_enemy_defeated)
    enemy.core_contact.connect(_on_attributed_contact)
    enemy.summon_requested.connect(_on_summon_requested)
    enemy.skill_resolved.connect(_on_skill_resolved)
    return enemy


# Spawn along the visible playfield boundary, keeping a minimum fair distance
# from the hero. This also avoids the former fixed four-door bottleneck.
func _survivor_spawn_edge() -> Vector2:
    var camera_center: Vector2 = world_camera.get_screen_center_position() if is_instance_valid(world_camera) else Vector2(320.0, 180.0)
    var area: Rect2 = SurvivorMaps.spawn_area(map_id, camera_center)
    var options: Array[Vector2] = []
    for index: int in range(4):
        match index:
            0:
                options.append(Vector2(_rng.randf_range(area.position.x, area.end.x), area.position.y))
            1:
                options.append(Vector2(_rng.randf_range(area.position.x, area.end.x), area.end.y))
            2:
                options.append(Vector2(area.position.x, _rng.randf_range(area.position.y, area.end.y)))
            3:
                options.append(Vector2(area.end.x, _rng.randf_range(area.position.y, area.end.y)))
    for i: int in range(options.size() - 1, 0, -1):
        var j: int = _rng.randi_range(0, i)
        var temp: Vector2 = options[i]
        options[i] = options[j]
        options[j] = temp
    var hero_at: Vector2 = hero_plant.global_position if hero_plant != null else area.get_center()
    for point: Vector2 in options:
        if point.distance_to(hero_at) >= 112.0:
            return point
    var farthest: Vector2 = options[0]
    for point: Vector2 in options:
        if point.distance_squared_to(hero_at) > farthest.distance_squared_to(hero_at):
            farthest = point
    return farthest


func _spawn_experience_gem(position_value: Vector2, amount: int) -> SurvivorExperienceGem:
    var gem: SurvivorExperienceGem = pickup_pool.acquire(EXPERIENCE_GEM_SCENE, pickups_container) as SurvivorExperienceGem
    gem.recycle = pickup_pool.release
    gem.global_position = position_value
    gem.configure(hero_plant, amount)
    gem.force_magnet = magnet_until > survival_elapsed
    if not gem.collected.is_connected(_on_experience_collected):
        gem.collected.connect(_on_experience_collected)
    return gem


func _open_surprise_choice() -> void:
    super._open_surprise_choice()
    if choice_open and run_state != null:
        run_state.open_reward()
    _render_reward_cards()


func _render_reward_cards() -> void:
    reward_focus_index = 0
    reroll_button.visible = choice_open
    skip_button.visible = choice_open
    reroll_button.disabled = reward_rerolls <= 0
    reroll_button.text = _t("Reroll (R) %d", "重选 (R) %d") % reward_rerolls
    skip_button.text = _t("Skip (X)", "跳过 (X)")
    choice_hint.visible = choice_open
    choice_badge.visible = choice_open
    for index: int in range(choice_buttons.size()):
        choice_buttons[index].visible = choice_open and index < _current_choices.size()
        if index >= _current_choices.size():
            continue
        var data: BlessingData = _current_choices[index]
        var button: Button = choice_buttons[index]
        button.text = ""
        button.icon = null
        var icon_view: TextureRect = button.get_node("GiftIcon") as TextureRect
        icon_view.texture = PixelArtAssets.blessing_icon(data.id)
        var rarity: Label = button.get_node("GiftRarity") as Label
        rarity.text = data.rarity_name(i18n.locale_code).to_upper()
        rarity.add_theme_color_override("font_color", data.rarity_color())
        var title: Label = button.get_node("GiftName") as Label
        title.text = data.localized_name(i18n.locale_code)
        var detail: Label = button.get_node("GiftDetail") as Label
        var stack: int = blessing_system.get_blessing_stack(data.id) + 1
        detail.text = "%s\nLv.%d" % [data.localized_description(i18n.locale_code, stack), stack]
        var weapon_index: int = SurvivorArsenal.IDS.find(data.id)
        if weapon_index >= 0:
            var partner: int = SurvivorArsenal.EVOLUTION_PARTNERS[weapon_index]
            var partner_name: String = _t(SurvivorArsenal.NAMES_EN[partner], SurvivorArsenal.NAMES_ZH[partner])
            detail.text += "\n" + _t("Evolve: Lv.3 + ", "进化：3级 + ") + partner_name
        var card_outline: Color = data.rarity_color().lerp(Color("#c5a88a"), 0.45)
        button.add_theme_stylebox_override("normal", PlayfulUITheme.surface(Color("#fffaf1"), 14, card_outline, 3))
        button.add_theme_stylebox_override("hover", PlayfulUITheme.surface(Color("#fff0d8"), 14, card_outline, 5))
    if choice_open and not choice_buttons.is_empty():
        choice_buttons[0].grab_focus()


func _refresh_hud() -> void:
    super._refresh_hud()
    if wave_label == null or hero_plant == null:
        return
    var shown_time: int = int(floor(survival_elapsed)) if endless_mode else mini(int(floor(survival_elapsed)), int(SURVIVAL_DURATION))
    wave_label.text = _t("TIME %02d:%02d", "时间 %02d:%02d") % [int(shown_time / 60), shown_time % 60]
    if endless_mode:
        wave_label.text = _t("∞ %02d:%02d", "∞ %02d:%02d") % [int(shown_time / 60), shown_time % 60]
    health_label.text = "%d/%d" % [hero_plant.health, hero_plant.max_health]
    coins_label.text = "%d" % enemies_defeated
    greed_label.text = _t("LV.%d XP", "等级%d 经验") % hero_plant.level
    if experience_bar != null:
        experience_bar.max_value = float(maxi(1, experience_to_next))
        experience_bar.value = float(experience)
        experience_bar.tooltip_text = _t(
            "Experience %d / %d" % [experience, experience_to_next],
            "经验 %d / %d" % [experience, experience_to_next]
        )


func _process(delta: float) -> void:
    if pause_open:
        return
    var old_first: bool = first_elite_spawned
    var old_second: bool = second_elite_spawned
    var old_boss: bool = final_boss_spawned
    super._process(delta)
    if not choice_open and not game_ended:
        _tick_map_events()
        _announce_evolutions()

    if not old_first and first_elite_spawned:
        _show_event_banner(_t("ELITE INCOMING!", "精英怪来袭！"))
    if not old_second and second_elite_spawned:
        _show_event_banner(_t("ELITE SWARM!", "精英怪群来袭！"))
    if not old_boss and final_boss_spawned:
        _show_event_banner(_t(SurvivorBiomeBoss.EN[map_id], SurvivorBiomeBoss.ZH[map_id]), 3.8)

    if not choice_open and not game_ended:
        _warning_seconds = maxf(0.0, _warning_seconds - delta)
        _combo_seconds = maxf(0.0, _combo_seconds - delta)
        if _combo_seconds <= 0.0:
            _combo_count = 0
    warning_frame.visible = _warning_seconds > 0.0 and not choice_open and not game_ended
    status_label.visible = warning_frame.visible
    if warning_frame.visible:
        status_label.text = _warning_message
    combo_label.visible = _combo_seconds > 0.0 and _combo_count >= 3 and not choice_open and not game_ended
    if control_label != null:
        control_label.visible = survival_elapsed < 4.2 and not choice_open and not game_ended


func _show_event_banner(message: String, duration: float = 2.8) -> void:
    _warning_message = message
    _warning_seconds = maxf(0.1, duration)
    status_label.text = message
    status_label.visible = true
    warning_frame.visible = true


func _on_enemy_defeated(enemy: GreedEnemy, coin_reward: int, elite: bool) -> void:
    var was_boss: bool = enemy != null and is_instance_valid(enemy) and enemy.boss
    var should_split: bool = is_instance_valid(enemy) and enemy.survivor_variant == 4
    var death_position: Vector2 = enemy.global_position if is_instance_valid(enemy) else Vector2.ZERO
    super._on_enemy_defeated(enemy, coin_reward, elite)
    if should_split and not game_ended:
        call_deferred("_spawn_minions", death_position, 2)
    if was_boss or game_ended:
        return
    _combo_count = _combo_count + 1 if _combo_seconds > 0.0 else 1
    _combo_seconds = COMBO_TIMEOUT
    if _combo_count >= 3:
        combo_label.text = _t("COMBO x%d", "连击 x%d") % _combo_count
        combo_label.visible = true


# Keyboard navigation for the three side-by-side reward cards; mouse may still
# click menus but never controls the hero or targets enemies.
func _input(event: InputEvent) -> void:
    if not choice_open or not (event is InputEventKey):
        return
    var key: InputEventKey = event as InputEventKey
    if not key.pressed or key.echo:
        return
    match key.keycode:
        KEY_LEFT, KEY_A:
            _focus_reward(reward_focus_index - 1)
        KEY_RIGHT, KEY_D:
            _focus_reward(reward_focus_index + 1)
        KEY_1:
            _select_choice(0)
        KEY_2:
            _select_choice(1)
        KEY_3:
            _select_choice(2)
        KEY_R:
            _reroll_reward()
        KEY_X:
            _skip_reward()
        KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
            _select_choice(reward_focus_index)
        _:
            return
    get_viewport().set_input_as_handled()


func _focus_reward(index: int) -> void:
    if not choice_open or _current_choices.is_empty():
        return
    reward_focus_index = posmod(index, _current_choices.size())
    choice_buttons[reward_focus_index].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key: InputEventKey = event as InputEventKey
        if key.pressed and not key.echo and not choice_open and not game_ended:
            if key.keycode == KEY_ESCAPE or key.keycode == KEY_P:
                _toggle_pause()
                get_viewport().set_input_as_handled()
    # Intentionally no super: disables legacy mouse click-to-move, dragging,
    # enemy focus and Space/double-click dash in this survival mode.


func _toggle_pause() -> void:
    if game_ended or choice_open or run_state == null:
        return
    if not run_state.toggle_pause():
        return
    pause_open = run_state.phase == SurvivorRunState.Phase.PAUSED
    _set_combat_frozen(pause_open)
    for control: Control in [pause_backdrop, pause_panel, pause_title, pause_subtitle, pause_build_label, pause_resume_button, pause_leave_button]:
        control.visible = pause_open
    if pause_open:
        _cancel_keyboard_motion()
        var equipped: PackedStringArray = []
        for i: int in range(SurvivorArsenal.IDS.size()):
            var rank: int = blessing_system.get_blessing_stack(SurvivorArsenal.IDS[i])
            if rank > 0:
                equipped.append(_t(SurvivorArsenal.NAMES_EN[i], SurvivorArsenal.NAMES_ZH[i]) + " Lv.%d%s" % [rank, " ★" if SurvivorArsenal.evolved(blessing_system, i) else ""])
        pause_build_label.text = _t("YOUR GARDEN\n", "当前构筑\n") + power_label.text + "\n" + " · ".join(equipped)
        pause_resume_button.grab_focus()
    else:
        get_viewport().gui_release_focus()


func _apply_locale() -> void:
    super._apply_locale()
    if menu_button != null:
        menu_button.text = _t("PAUSE", "暂停")
    if pause_title != null:
        pause_title.text = _t("TAKE A LITTLE BREAK", "歇一会儿吧")
        pause_subtitle.text = _t("Your garden is waiting for you.", "芽芽们会在这里等你回来。")
        pause_resume_button.text = _t("RESUME GAME", "继续游戏")
        pause_leave_button.text = _t("RETURN TO MENU", "返回主菜单")
    if choice_hint != null:
        choice_hint.text = _t("1 / 2 / 3 · Enter", "1 / 2 / 3 · 回车")


func _update_control_status() -> void:
    if control_label == null or hero_plant == null or not is_instance_valid(hero_plant):
        return
    if choice_open:
        control_label.text = _t("PICK A GARDEN GIFT TO CONTINUE", "选择一份花园礼物继续")
    else:
        control_label.text = _t("WASD / ARROWS MOVE  ·  AUTOMATIC ATTACK", "WASD / 方向键移动  ·  自动攻击")


func _apply_playful_hud() -> void:
    PlayfulUITheme.apply_panel(get_node("UI/TopHUD/Frame") as Panel, "glass")
    PlayfulUITheme.apply_panel(get_node("UI/ExperienceFrame") as Panel, "glass")
    PlayfulUITheme.apply_panel(warning_frame, "glass")
    PlayfulUITheme.apply_panel(choice_panel, "modal")
    PlayfulUITheme.apply_panel(pause_panel, "modal")
    PlayfulUITheme.apply_progress(experience_bar)
    for label: Label in [
        choice_title, result_label, pause_title, pause_subtitle, pause_build_label
    ]:
        PlayfulUITheme.apply_label(label)
    for label: Label in [wave_label, health_label, coins_label, greed_label]:
        PlayfulUITheme.apply_label(label, Color("#fffaf0"))
    PlayfulUITheme.apply_label(control_label, Color("#fef7e8"))
    PlayfulUITheme.apply_label(choice_hint, Color("#fff8df"))
    PlayfulUITheme.apply_label(status_label, Color("#fff9e7"))
    PlayfulUITheme.apply_label(combo_label, Color("#ffed92"))
    PlayfulUITheme.apply_button(language_button, "tiny")
    PlayfulUITheme.apply_button(speed_button, "tiny")
    PlayfulUITheme.apply_button(menu_button, "coral")
    for button: Button in choice_buttons:
        PlayfulUITheme.apply_button(button, "soft")
    PlayfulUITheme.apply_button(result_button, "primary")
    PlayfulUITheme.apply_button(pause_resume_button, "primary")
    PlayfulUITheme.apply_button(pause_leave_button, "soft")


func _select_choice(index: int) -> void:
    var allowed: bool = choice_open and index >= 0 and index < _current_choices.size()
    if not allowed:
        return
    super._select_choice(index)
    _hide_reward_actions()
    choice_hint.visible = false
    choice_badge.visible = false
    if run_state != null:
        run_state.close_reward()


func _finish_run(victory: bool) -> void:
    if game_ended:
        return
    super._finish_run(victory)
    _hide_reward_actions()
    choice_hint.visible = false
    choice_badge.visible = false
    warning_frame.visible = false
    combo_label.visible = false
    if run_state != null:
        run_state.finish(victory)
    result_label.text += "\n" + _t("Damage %.0f · XP %d · Peak %d", "伤害 %.0f · 经验 %d · 敌群峰值 %d") % [total_damage, total_xp, peak_enemies]
    result_label.text += "\n" + _t("Evolved %d · Events %d", "进化 %d · 事件 %d") % [evolution_announced.size(), map_events.completed]
    if run_save != null and not simulation_mode:
        var saved: bool = run_save.record_survivor_result(
            victory, survival_elapsed, hero_plant.level if is_instance_valid(hero_plant) else 1, enemies_defeated,
            {"damage": total_damage, "xp": total_xp, "map": map_id, "difficulty": difficulty, "evolutions": evolution_announced.size(), "events": map_events.completed, "source_damage": damage_by_source.duplicate(), "damage_received": damage_received, "challenge": challenge_active, "challenge_date": challenge_date, "endless": endless_mode, "bosses": bosses_defeated, "damage_by_enemy": damage_by_enemy.duplicate()}
        )
        if run_trace != null:
            run_trace.note("run_recorded", "saved=%s victory=%s kills=%d" % [saved, victory, enemies_defeated])
    _show_result_workspace(victory)


func _on_run_phase_changed(previous: int, current: int) -> void:
    if run_trace != null:
        run_trace.note("phase_change", "%d -> %d; elapsed=%.2f; kills=%d" % [
            previous, current, survival_elapsed, enemies_defeated
        ])


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT and hero_plant != null:
        _cancel_keyboard_motion()


# Audio follows confirmed hits, not shots that may miss.
func _on_hero_fired(_hero: GreedHeroPlant, _target: GreedEnemy, _critical: bool, _damage: float) -> void:
    pass

func _on_plant_fired(_plant: GreedPlant, _target: GreedEnemy, _critical: bool, _damage: float) -> void:
    pass

func _on_enemy_damaged(enemy: GreedEnemy, damage: float, critical: bool) -> void:
    super._on_enemy_damaged(enemy, damage, critical)
    if critical and is_instance_valid(enemy):
        _spawn_bitmap_effect(enemy.global_position, PixelArtAssets.blessing_icon(&"mutation_seed"), Color("ffe071"))
    var now: int = Time.get_ticks_msec()
    if now >= _next_hit_sound:
        _next_hit_sound = now + (90 if critical else 65)
        audio_manager.play_event(&"critical" if critical else &"survivor_hit")

func _on_experience_collected(amount: int) -> void:
    var now: int = Time.get_ticks_msec()
    if now >= _next_pickup_sound:
        _next_pickup_sound = now + 90
        audio_manager.play_event(&"survivor_pickup")
    super._on_experience_collected(amount)


func _hide_reward_actions() -> void:
    if reroll_button != null:
        reroll_button.hide()
    if skip_button != null:
        skip_button.hide()


func _reroll_reward() -> void:
    if not choice_open or game_ended or reward_rerolls <= 0:
        return
    reward_rerolls -= 1
    var previous_pity: int = blessing_system.pity_without_high
    _current_choices = blessing_system.roll_choices(3)
    # Rerolls do not advance the guarantee counter.
    blessing_system.pity_without_high = previous_pity
    _render_reward_cards()


func _skip_reward() -> void:
    if not choice_open or game_ended:
        return
    # A skipped reward still consumes exactly one level-up and retains base growth.
    hero_plant.upgrade()
    if hero_plant.level % 3 == 0:
        var familiar: GreedPlant = _lowest_level_plant()
        if familiar != null:
            familiar.upgrade()
    pending_level_ups = maxi(0, pending_level_ups - 1)
    choice_open = false
    choice_backdrop.hide()
    choice_panel.hide()
    choice_title.hide()
    choice_hint.hide()
    choice_badge.hide()
    for button: Button in choice_buttons:
        button.hide()
    _current_choices.clear()
    _hide_reward_actions()
    _set_combat_frozen(false)
    if run_state != null:
        run_state.close_reward()
    _refresh_hud()
    if pending_level_ups > 0:
        call_deferred("_open_surprise_choice")


func _on_summon_requested(position_value: Vector2) -> void:
    call_deferred("_spawn_minions", position_value, 3)


func _spawn_minions(position_value: Vector2, count: int) -> void:
    if game_ended or not is_instance_valid(hero_plant):
        return
    var available: int = maxi(0, _active_enemy_cap() - get_tree().get_nodes_in_group("greed_enemies").size())
    for i: int in range(mini(count, available)):
        var offset: Vector2 = Vector2.from_angle(TAU * float(i) / float(count)) * 24.0
        var config: Dictionary = SurvivorBalance.enemy_config(survival_elapsed, difficulty, false, false, 5)
        var minion: GreedEnemy = _spawn_configured_enemy(config, SurvivorMaps.clamp_spawn(map_id, position_value + offset))
        if choice_open or pause_open:
            minion.process_mode = Node.PROCESS_MODE_DISABLED


func _setup_map() -> void:
    # Keep the existing benchmark arena independent of menu settings.
    map_id = simulation_map if simulation_mode else (SurvivorMaps.NIGHT if challenge_active else SurvivorMaps.selected)
    var ground: TextureRect = get_node("World/ArenaGround") as TextureRect
    ground.size = SurvivorMaps.world_size(map_id)
    ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
    ground.stretch_mode = TextureRect.STRETCH_TILE
    hero_plant.movement_bounds = SurvivorMaps.movement_bounds(map_id)
    if map_id == SurvivorMaps.CLASSIC:
        return
    ground.texture = PixelArtAssets.biome_texture(map_id)
    var backdrop: ColorRect = get_node("World/Backdrop") as ColorRect
    backdrop.size = SurvivorMaps.world_size(map_id)
    var offset: Vector2 = SurvivorMaps.EXPLORATION_SIZE * 0.5 - hero_plant.global_position
    hero_plant.global_position += offset
    for familiar: GreedPlant in plants:
        familiar.global_position += offset
    world_camera = Camera2D.new()
    world_camera.name = "WorldCamera"
    world_camera.limit_left = 0
    world_camera.limit_top = 0
    world_camera.limit_right = int(SurvivorMaps.EXPLORATION_SIZE.x)
    world_camera.limit_bottom = int(SurvivorMaps.EXPLORATION_SIZE.y)
    hero_plant.add_child(world_camera)
    world_camera.make_current()
    world_camera.force_update_scroll()


func _tick_map_events() -> void:
    if map_id == SurvivorMaps.CLASSIC or not is_instance_valid(hero_plant):
        return
    var kind: int = map_events.due(survival_elapsed)
    if kind >= 0:
        _spawn_map_event(kind)
    for index: int in range(event_nodes.size() - 1, -1, -1):
        var item: Sprite2D = event_nodes[index]
        if not is_instance_valid(item):
            event_nodes.remove_at(index)
            continue
        if item.global_position.distance_to(hero_plant.global_position) <= 30.0:
            var event_kind: int = int(item.get_meta("kind"))
            item.queue_free()
            event_nodes.remove_at(index)
            _collect_map_event(event_kind)
    var outcome: int = map_events.challenge_result(survival_elapsed, enemies_defeated)
    if outcome == 1:
        _spawn_experience_gem(hero_plant.global_position, 10)
        _show_event_banner(_t("CHALLENGE COMPLETE", "挑战完成"))
    elif outcome == -1:
        _show_event_banner(_t("CHALLENGE EXPIRED", "挑战结束"))


func _spawn_map_event(kind: int) -> void:
    var item: Sprite2D = Sprite2D.new()
    item.texture = PixelArtAssets.event_icon(kind if kind < 3 else 0)
    item.scale = Vector2.ONE * 1.15
    item.z_index = 3
    item.set_meta("kind", kind)
    effects_container.add_child(item)
    var angle: float = event_rng.randf_range(0.0, TAU)
    item.global_position = SurvivorMaps.clamp_spawn(map_id, hero_plant.global_position + Vector2.from_angle(angle) * 138.0)
    var label: Label = Label.new()
    label.text = [_t("Chest", "宝箱"), _t("Heal", "治疗"), _t("Magnet", "磁铁"), _t("Challenge", "挑战")][kind]
    label.position = Vector2(-28.0, 17.0)
    label.size = Vector2(56.0, 18.0)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 10)
    item.add_child(label)
    event_nodes.append(item)
    _show_event_banner(label.text + _t(" nearby", "已出现"))


func _collect_map_event(kind: int) -> void:
    match kind:
        SurvivorMapEvents.Kind.CHEST:
            _spawn_experience_gem(hero_plant.global_position, 8)
        SurvivorMapEvents.Kind.HEAL:
            hero_plant.heal(maxi(1, ceili(float(hero_plant.max_health) * 0.35)))
        SurvivorMapEvents.Kind.MAGNET:
            magnet_until = survival_elapsed + 10.0
            for node: Node in get_tree().get_nodes_in_group("survivor_experience"):
                if node is SurvivorExperienceGem:
                    (node as SurvivorExperienceGem).force_magnet = true
        SurvivorMapEvents.Kind.CHALLENGE:
            map_events.start_challenge(survival_elapsed, enemies_defeated)
            _show_event_banner(_t("10 KILLS IN 12s", "12秒击败10个敌人"), 3.8)
            return
    map_events.completed += 1
    _spawn_bitmap_effect(hero_plant.global_position, PixelArtAssets.event_icon(kind), Color.WHITE)


func _announce_evolutions() -> void:
    for i: int in range(SurvivorArsenal.IDS.size()):
        if SurvivorArsenal.evolved(blessing_system, i) and not evolution_announced.has(i):
            evolution_announced[i] = true
            _spawn_bitmap_effect(hero_plant.global_position, PixelArtAssets.blessing_icon(SurvivorArsenal.IDS[i]), SurvivorArsenal.COLORS[i])
            _show_event_banner(_t("EVOLVED: ", "已进化：") + _t(SurvivorArsenal.NAMES_EN[i], SurvivorArsenal.NAMES_ZH[i]))


func _spawn_bitmap_effect(position_value: Vector2, texture_value: Texture2D, tint: Color) -> void:
    if simulation_mode or texture_value == null:
        return
    for i: int in range(effect_sprites.size() - 1, -1, -1):
        if not is_instance_valid(effect_sprites[i]):
            effect_sprites.remove_at(i)
    if effect_sprites.size() >= 16:
        return
    var sprite: Sprite2D = Sprite2D.new()
    sprite.texture = texture_value
    sprite.modulate = Color(tint.r, tint.g, tint.b, 0.9)
    sprite.z_index = 10
    sprite.scale = Vector2.ONE * 0.55
    effects_container.add_child(sprite)
    sprite.global_position = position_value
    effect_sprites.append(sprite)
    var tween: Tween = sprite.create_tween().set_parallel(true)
    tween.tween_property(sprite, "scale", Vector2.ONE * 1.5, 0.35)
    tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
    tween.chain().tween_callback(sprite.queue_free)


func _on_skill_resolved(position_value: Vector2, boss_attack: bool) -> void:
    _spawn_bitmap_effect(position_value, PixelArtAssets.blessing_icon(&"mutation_spore"), Color("e3a0f8") if boss_attack else Color("f5b1cc"))


func _on_attributed_projectile(origin: Vector2, target: GreedEnemy, damage: float, critical: bool, speed: float, splash_radius: float, slow_ratio: float, knockback_force: float, color: Color, source: String) -> void:
    _projectile_source = source
    _on_projectile_requested(origin, target, damage, critical, speed, splash_radius, slow_ratio, knockback_force, color)
    _projectile_source = "arsenal"


func _record_source_damage(source: String, actual_damage: float) -> void:
    damage_by_source[source] = float(damage_by_source.get(source, 0.0)) + actual_damage


func _track_health(current: int, _maximum: int) -> void:
    if _previous_health >= 0 and current < _previous_health:
        var loss: int = _previous_health - current
        damage_received += loss
        damage_by_enemy[_current_threat] = int(damage_by_enemy.get(_current_threat, 0)) + loss
    _previous_health = current


func _show_result_workspace(victory: bool) -> void:
    result_label.text = _t("GARDEN BLOOMED", "花园绽放") if victory else _t("GARDEN FELL", "花园倒下")
    result_label.position = Vector2(110, 32)
    result_label.size = Vector2(420, 36)
    result_label.add_theme_font_size_override("font_size", 24)
    var column: VBoxContainer = VBoxContainer.new()
    column.position = Vector2(110, 76)
    column.size = Vector2(420, 190)
    get_node("UI/ChoiceLayer").add_child(column)
    var metrics_label: Label = Label.new()
    metrics_label.text = _t("Time %.1fs · Kills %d · Level %d\nDamage %.0f · XP %d · Taken %d\nHero %.0f · Familiars %.0f · Weapons %.0f\nEvolutions %d · Events %d", "时间 %.1f秒 · 击杀 %d · 等级 %d\n伤害 %.0f · 经验 %d · 承伤 %d\n主角 %.0f · 随从 %.0f · 武器 %.0f\n进化 %d · 事件 %d") % [survival_elapsed, enemies_defeated, hero_plant.level, total_damage, total_xp, damage_received, damage_by_source["hero"], damage_by_source["familiar"], damage_by_source["arsenal"], evolution_announced.size(), map_events.completed]
    metrics_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    metrics_label.add_theme_font_size_override("font_size", 13)
    column.add_child(metrics_label)
    var graph: HBoxContainer = HBoxContainer.new()
    graph.custom_minimum_size.y = 18.0
    column.add_child(graph)
    var sum_damage: float = maxf(1.0, float(damage_by_source["hero"]) + float(damage_by_source["familiar"]) + float(damage_by_source["arsenal"]))
    var keys: Array[String] = ["hero", "familiar", "arsenal"]
    var labels: Array[String] = [_t("Hero", "主角"), _t("Familiars", "随从"), _t("Weapons", "武器")]
    var colors: Array[Color] = [Color("99c57c"), Color("e4bb70"), Color("b69bd1")]
    for i: int in range(keys.size()):
        var amount: float = float(damage_by_source[keys[i]])
        if amount <= 0.0:
            continue
        var bar: ColorRect = ColorRect.new()
        bar.color = colors[i]
        bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        bar.size_flags_stretch_ratio = maxf(0.01, amount / sum_damage)
        bar.tooltip_text = labels[i] + " %.1f%%" % (amount / sum_damage * 100.0)
        graph.add_child(bar)
    var icons: HBoxContainer = HBoxContainer.new()
    icons.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_child(icons)
    for i: int in range(SurvivorArsenal.IDS.size()):
        var rank: int = blessing_system.get_blessing_stack(SurvivorArsenal.IDS[i])
        if rank <= 0:
            continue
        var item: TextureRect = TextureRect.new()
        item.texture = PixelArtAssets.blessing_icon(SurvivorArsenal.IDS[i])
        item.custom_minimum_size = Vector2(32, 32)
        item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        item.tooltip_text = _t(SurvivorArsenal.NAMES_EN[i], SurvivorArsenal.NAMES_ZH[i]) + " Lv.%d" % rank
        icons.add_child(item)
    result_button.position = Vector2(140, 282)
    result_button.size = Vector2(170, 38)
    var home: Button = Button.new()
    home.text = _t("MAIN MENU", "返回主菜单")
    home.position = Vector2(330, 282)
    home.size = Vector2(170, 38)
    get_node("UI/ChoiceLayer").add_child(home)
    home.pressed.connect(_leave_result)
    PlayfulUITheme.apply_button(home)
    result_button.grab_focus()

func _leave_result() -> void:
    SurvivorChallenge.selected = false
    SurvivorEndurance.selected = false
    _return_to_menu()


func _on_attributed_contact(enemy: GreedEnemy, damage: int) -> void:
    _current_threat = "boss" if enemy.boss else ("ranged" if enemy.survivor_variant == 3 else "contact")
    _on_enemy_core_contact(enemy, damage)
    _current_threat = "contact"
