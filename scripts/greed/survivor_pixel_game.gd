extends "res://scripts/greed/survivor_game.gd"

const HERO_SCENE: PackedScene = preload("res://scenes/actors/hero_plant.tscn")
const FAMILIAR_SUN_SCENE: PackedScene = preload("res://scenes/actors/familiar_sun.tscn")
const FAMILIAR_SPROUT_SCENE: PackedScene = preload("res://scenes/actors/familiar_sprout.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/actors/enemy.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/effects/projectile.tscn")
const EXPERIENCE_GEM_SCENE: PackedScene = preload("res://scenes/effects/experience_gem.tscn")

var experience_bar: ProgressBar
var pixel_skin: PixelSkinController
var run_state: SurvivorRunState
var run_trace: SurvivorRunTrace
var pause_open: bool = false
var pause_backdrop: ColorRect
var pause_panel: Panel
var pause_title: Label
var pause_subtitle: Label
var pause_resume_button: Button
var pause_leave_button: Button

var actors_container: Node2D
var enemies_container: Node2D
var projectiles_container: Node2D
var pickups_container: Node2D
var effects_container: Node2D
var editor_preview: Node2D
var player_spawn: Marker2D
var familiar_spawn_sun: Marker2D
var familiar_spawn_sprout: Marker2D


func _ready() -> void:
    super._ready()
    pixel_skin = get_node("PixelSkinController") as PixelSkinController
    run_state = get_node("RunState") as SurvivorRunState
    run_trace = get_node("RunTrace") as SurvivorRunTrace
    run_state.phase_changed.connect(_on_run_phase_changed)
    run_state.start_run()
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
    hero_plant.configure(GreedBalance.STARTER_PLANTS[0], blessing_system)
    hero_plant.health_changed.connect(_on_core_health_changed)
    hero_plant.defeated.connect(_on_core_defeated)
    hero_plant.fired.connect(_on_hero_fired)
    hero_plant.projectile_requested.connect(_on_projectile_requested)
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
        familiar.configure(hero_plant, GreedBalance.STARTER_PLANTS[config_index], familiar_index, blessing_system)
        familiar.set_focus_source(hero_plant)
        familiar.fired.connect(_on_plant_fired)
        familiar.projectile_requested.connect(_on_projectile_requested)
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

    choice_backdrop = get_node("UI/ChoiceLayer/Backdrop") as ColorRect
    choice_panel = get_node("UI/ChoiceLayer/Panel") as Panel
    choice_title = get_node("UI/ChoiceLayer/Title") as Label
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
    var projectile: GreedProjectile = PROJECTILE_SCENE.instantiate() as GreedProjectile
    projectile.name = "GreedProjectile"
    projectiles_container.add_child(projectile)
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
    var config: Dictionary
    if force_boss:
        config = GreedBalance.WAVE_TABLE[GreedBalance.WAVE_TABLE.size() - 1].duplicate(true)
    elif force_elite:
        var elite_index: int = 4 if survival_elapsed < SECOND_ELITE_TIME else 8
        config = GreedBalance.WAVE_TABLE[elite_index].duplicate(true)
    else:
        var tier: int = clampi(int(floor(survival_elapsed / 10.0)), 0, GreedBalance.WAVE_TABLE.size() - 3)
        config = GreedBalance.WAVE_TABLE[tier].duplicate(true)
        config["elite"] = false
        config["boss"] = false
        config["health"] = float(config.get("health", 24.0)) * (1.0 + survival_elapsed / 150.0)
        config["speed"] = float(config.get("speed", 42.0)) * (1.0 + survival_elapsed / 360.0)

    var enemy: GreedEnemy = ENEMY_SCENE.instantiate() as GreedEnemy
    enemy.name = "SurvivorEnemy"
    enemies_container.add_child(enemy)
    enemy.global_position = _door_spawn_position()
    enemy.configure(hero_plant, config, 1.0)
    enemy.damaged.connect(_on_enemy_damaged)
    enemy.defeated.connect(_on_enemy_defeated)
    enemy.core_contact.connect(_on_enemy_core_contact)
    return enemy


func _spawn_experience_gem(position_value: Vector2, amount: int) -> SurvivorExperienceGem:
    var gem: SurvivorExperienceGem = EXPERIENCE_GEM_SCENE.instantiate() as SurvivorExperienceGem
    gem.name = "ExperienceGem"
    pickups_container.add_child(gem)
    gem.global_position = position_value
    gem.configure(hero_plant, amount)
    gem.collected.connect(_on_experience_collected)
    return gem


func _open_surprise_choice() -> void:
    super._open_surprise_choice()
    if choice_open and run_state != null:
        run_state.open_reward()
    for index: int in range(choice_buttons.size()):
        if index >= _current_choices.size():
            continue
        var data: BlessingData = _current_choices[index]
        choice_buttons[index].icon = PixelArtAssets.blessing_icon(data.id)


func _refresh_hud() -> void:
    super._refresh_hud()
    if wave_label == null or hero_plant == null:
        return
    var shown_time: int = mini(int(floor(survival_elapsed)), int(SURVIVAL_DURATION))
    wave_label.text = _t("TIME %02d:%02d", "时间 %02d:%02d") % [int(shown_time / 60), shown_time % 60]
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
    super._process(delta)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key_event: InputEventKey = event as InputEventKey
        if key_event.pressed and not key_event.echo:
            if key_event.keycode == KEY_ESCAPE or key_event.keycode == KEY_P:
                _toggle_pause()
                get_viewport().set_input_as_handled()
                return
    if pause_open:
        return
    super._unhandled_input(event)


func _toggle_pause() -> void:
    if game_ended or choice_open or run_state == null:
        return
    if not run_state.toggle_pause():
        return
    pause_open = run_state.phase == SurvivorRunState.Phase.PAUSED
    _set_combat_frozen(pause_open)
    for control: Control in [pause_backdrop, pause_panel, pause_title, pause_subtitle, pause_resume_button, pause_leave_button]:
        control.visible = pause_open
    if pause_open:
        _cancel_keyboard_motion()
        pause_resume_button.grab_focus()
    else:
        menu_button.grab_focus()


func _apply_locale() -> void:
    super._apply_locale()
    if menu_button != null:
        menu_button.text = _t("PAUSE", "暂停")
    if pause_title != null:
        pause_title.text = _t("TAKE A LITTLE BREAK", "歇一会儿吧")
        pause_subtitle.text = _t("Your garden is waiting for you.", "芽芽们会在这里等你回来。")
        pause_resume_button.text = _t("RESUME GAME", "继续游戏")
        pause_leave_button.text = _t("RETURN TO MENU", "返回主菜单")


func _update_control_status() -> void:
    if control_label == null or hero_plant == null or not is_instance_valid(hero_plant):
        return
    if choice_open:
        control_label.text = _t("PICK A GARDEN GIFT TO CONTINUE", "选择一份花园礼物继续")
    elif hero_plant.is_dashing():
        control_label.text = _t("DASH! YOU ARE BRIEFLY INVINCIBLE", "冲刺中 · 短暂无敌")
    else:
        control_label.text = _t("WASD MOVE  ·  SPACE DASH  ·  AUTO ATTACK", "WASD 移动  ·  空格闪避  ·  自动攻击")


func _apply_playful_hud() -> void:
    PlayfulUITheme.apply_panel(get_node("UI/TopHUD/Frame") as Panel, "hud")
    PlayfulUITheme.apply_panel(get_node("UI/BuildPanel") as Panel, "hud")
    PlayfulUITheme.apply_panel(get_node("UI/ExperienceFrame") as Panel, "hud")
    PlayfulUITheme.apply_panel(choice_panel, "modal")
    PlayfulUITheme.apply_panel(pause_panel, "modal")
    PlayfulUITheme.apply_progress(experience_bar)
    for label: Label in [
        wave_label, health_label, coins_label, greed_label, power_label,
        choice_title, result_label, pause_title, pause_subtitle
    ]:
        PlayfulUITheme.apply_label(label)
    PlayfulUITheme.apply_label(control_label, Color("#fff5d7"))
    PlayfulUITheme.apply_label(status_label, Color("#fff9e7"))
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
    if run_state != null:
        run_state.close_reward()


func _finish_run(victory: bool) -> void:
    if game_ended:
        return
    super._finish_run(victory)
    if run_state != null:
        run_state.finish(victory)


func _on_run_phase_changed(previous: int, current: int) -> void:
    if run_trace != null:
        run_trace.note("phase_change", "%d -> %d; elapsed=%.2f; kills=%d" % [
            previous, current, survival_elapsed, enemies_defeated
        ])


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT and hero_plant != null:
        _cancel_keyboard_motion()
