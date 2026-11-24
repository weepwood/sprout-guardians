extends "res://scripts/greed/greed_game_mouse.gd"

const SURVIVAL_DURATION: float = 90.0
const FIRST_ELITE_TIME: float = 30.0
const SECOND_ELITE_TIME: float = 60.0
const BASE_EXPERIENCE_REQUIREMENT: int = 8
const MAX_ACTIVE_ENEMIES: int = 64

var survival_elapsed: float = 0.0
var endless_mode: bool = false
var bosses_defeated: int = 0
var survival_spawn_timer: float = 0.15
var experience: int = 0
var experience_to_next: int = BASE_EXPERIENCE_REQUIREMENT
var pending_level_ups: int = 0
var first_elite_spawned: bool = false
var second_elite_spawned: bool = false
var final_boss_spawned: bool = false
var final_boss_defeated: bool = false
var input_controller: SurvivorInputController
var spawn_director: SurvivorSpawnDirector = SurvivorSpawnDirector.new()
var difficulty: int = 1
var run_seed: int = 0
var arsenal: SurvivorArsenal = SurvivorArsenal.new()
var simulation_direction: Vector2 = Vector2.ZERO
var simulation_mode: bool = false
var total_damage: float = 0.0
var total_xp: int = 0
var first_upgrade_seconds: float = -1.0
var peak_enemies: int = 0
var _hud_refresh_remaining: float = 0.0


func _ready() -> void:
    difficulty = 2 if SurvivorChallenge.selected and not simulation_mode else SurvivorBalance.selected_difficulty
    if run_seed == 0:
        run_seed = randi_range(1, 2147483647)
    spawn_director.configure(difficulty, run_seed)
    experience_to_next = SurvivorBalance.experience_requirement(1, difficulty)
    super._ready()
    _rng.seed = run_seed
    input_controller = get_node_or_null("RunInput") as SurvivorInputController
    if hero_plant != null and is_instance_valid(hero_plant):
        hero_plant.enable_arcade_movement()
        hero_plant.movement_bounds = Rect2(17.0, 43.0, 606.0, 275.0)
    wave_index = 0
    wave_active = true
    spawn_remaining = -1
    next_wave_timer = 0.0
    survival_elapsed = 0.0
    survival_spawn_timer = 0.15
    status_label.text = _t("SURVIVE AND GROW", "持续生存并成长")
    _refresh_hud()


func _process(delta: float) -> void:
    if game_ended or choice_open:
        return

    _apply_continuous_movement()
    survival_elapsed += delta
    wave_elapsed = survival_elapsed
    seconds_since_last_kill += delta

    if hero_plant != null and is_instance_valid(hero_plant):
        hero_plant.fury_multiplier = GreedBalance.fury_multiplier(seconds_since_last_kill)
        hero_plant.rescue_active = GreedBalance.rescue_active(seconds_since_last_kill)
    for familiar: GreedPlant in plants:
        if familiar == null or not is_instance_valid(familiar):
            continue
        familiar.fury_multiplier = GreedBalance.fury_multiplier(seconds_since_last_kill)
        familiar.rescue_active = GreedBalance.rescue_active(seconds_since_last_kill)

    arsenal.tick(delta, hero_plant, blessing_system, _on_projectile_requested, _on_arsenal_visual_requested, difficulty)
    _spawn_time_milestones()
    if survival_elapsed < SURVIVAL_DURATION or endless_mode:
        survival_spawn_timer -= delta
        var active_enemies: int = get_tree().get_nodes_in_group("greed_enemies").size()
        peak_enemies = maxi(peak_enemies, active_enemies)
        if survival_spawn_timer <= 0.0 and active_enemies < _active_enemy_cap():
            _spawn_survivor_enemy(false, false)
            survival_spawn_timer = _current_spawn_interval()
    if not final_boss_spawned and ((endless_mode and SurvivorEndurance.boss_due(survival_elapsed, bosses_defeated)) or (not endless_mode and survival_elapsed >= SURVIVAL_DURATION)):
        final_boss_spawned = true
        _spawn_survivor_enemy(true, true)
        status_label.text = _t("FINAL BLOOM BEAST", "最终花兽出现")

    # The boss is the final objective; surviving minions must not stall victory.
    if final_boss_spawned and final_boss_defeated:
        if endless_mode:
            bosses_defeated += 1
            final_boss_spawned = false
            final_boss_defeated = false
        else:
            bosses_defeated = 1
            _finish_run(true)
            return

    _hud_refresh_remaining -= delta
    if _hud_refresh_remaining > 0.0:
        return
    _hud_refresh_remaining = 0.10
    var remaining_seconds: int = maxi(0, int(ceil(SURVIVAL_DURATION - survival_elapsed)))
    var enemy_count: int = get_tree().get_nodes_in_group("greed_enemies").size()
    if endless_mode:
        status_label.text = _t("ENDLESS · BOSS %d", "无尽 · 首领 %d") % [bosses_defeated]
    elif survival_elapsed < SURVIVAL_DURATION:
        status_label.text = _t("SURVIVE %02ds · %d ENEMIES", "生存 %02d秒 · %d 个敌人") % [remaining_seconds, enemy_count]
    _refresh_hud()
    _update_control_status()


# Input is sampled every frame. Gameplay never delegates to the inherited
# click/drag/lock-on handler; mouse remains available for menus and rewards.
func _unhandled_input(_event: InputEvent) -> void:
    pass


func _apply_continuous_movement() -> void:
    if hero_plant == null or not is_instance_valid(hero_plant):
        return
    if simulation_mode:
        hero_plant.set_arcade_direction(simulation_direction)
        return
    if input_controller == null:
        hero_plant.set_arcade_direction(Vector2.ZERO)
        return
    hero_plant.set_arcade_direction(input_controller.movement_direction())


func _cancel_keyboard_motion() -> void:
    if hero_plant != null and is_instance_valid(hero_plant):
        hero_plant.set_arcade_direction(Vector2.ZERO)


func _spawn_time_milestones() -> void:
    if survival_elapsed >= FIRST_ELITE_TIME and not first_elite_spawned:
        first_elite_spawned = true
        _spawn_survivor_enemy(true, false)
        impact_system.spawn_reward(hero_plant.global_position, Color("f0a34d"))
        _grant_milestone_growth()
    if survival_elapsed >= SECOND_ELITE_TIME and not second_elite_spawned:
        second_elite_spawned = true
        _spawn_survivor_enemy(true, false)
        if difficulty != 0:
            _spawn_survivor_enemy(true, false)
        impact_system.spawn_reward(hero_plant.global_position, Color("df72ef"))
        _grant_milestone_growth()


func _grant_milestone_growth() -> void:
    var amount: int = SurvivorBalance.milestone_experience(difficulty)
    if amount > 0 and is_instance_valid(hero_plant):
        _spawn_experience_gem(hero_plant.global_position, amount)


func _spawn_survivor_enemy(force_elite: bool, force_boss: bool) -> GreedEnemy:
    var config: Dictionary = spawn_director.next_enemy(survival_elapsed, force_elite, force_boss)

    var enemy: GreedEnemy = GreedEnemy.new()
    enemy.name = "SurvivorEnemy"
    enemy.global_position = _door_spawn_position()
    add_child(enemy)
    enemy.configure(hero_plant, config, 1.0)
    enemy.damaged.connect(_on_enemy_damaged)
    enemy.defeated.connect(_on_enemy_defeated)
    enemy.core_contact.connect(_on_enemy_core_contact)
    return enemy


func _current_spawn_interval() -> float:
    var base: float = SurvivorBalance.spawn_interval(survival_elapsed, difficulty)
    return SurvivorEndurance.spawn_interval(survival_elapsed, base) if endless_mode else base


func _active_enemy_cap() -> int:
    return SurvivorBalance.enemy_cap(survival_elapsed, difficulty)


func _on_enemy_defeated(enemy: GreedEnemy, coin_reward: int, elite: bool) -> void:
    var drop_position: Vector2 = hero_plant.global_position if hero_plant != null else ARENA_RECT.get_center()
    var experience_value: int = SurvivorBalance.enemy_experience(difficulty, elite)
    var was_boss: bool = false
    if enemy != null and is_instance_valid(enemy):
        drop_position = enemy.global_position
        was_boss = enemy.boss
        if was_boss:
            experience_value = 12
    _spawn_experience_gem(drop_position, experience_value)
    if was_boss:
        final_boss_defeated = true
    super._on_enemy_defeated(enemy, coin_reward, elite)


func _spawn_experience_gem(position_value: Vector2, amount: int) -> SurvivorExperienceGem:
    var gem: SurvivorExperienceGem = SurvivorExperienceGem.new()
    gem.name = "ExperienceGem"
    gem.global_position = position_value
    add_child(gem)
    gem.configure(hero_plant, amount, difficulty)
    gem.collected.connect(_on_experience_collected)
    return gem


func _on_experience_collected(amount: int) -> void:
    total_xp += maxi(1, amount)
    experience += maxi(1, amount)
    while experience >= experience_to_next:
        experience -= experience_to_next
        pending_level_ups += 1
        experience_to_next = _experience_requirement_for_level(hero_plant.level + pending_level_ups)
    if pending_level_ups > 0 and not choice_open:
        if first_upgrade_seconds < 0.0:
            first_upgrade_seconds = survival_elapsed
        _open_surprise_choice()
    _refresh_hud()


func _experience_requirement_for_level(level_value: int) -> int:
    return SurvivorBalance.experience_requirement(level_value, difficulty)


func _open_surprise_choice() -> void:
    if game_ended:
        return
    _cancel_keyboard_motion()
    super._open_surprise_choice()
    choice_title.text = _t("LEVEL UP · CHOOSE A GARDEN MUTATION", "等级提升 · 选择花园变异")


func _select_choice(index: int) -> void:
    if not choice_open or index < 0 or index >= _current_choices.size():
        return
    super._select_choice(index)
    pending_level_ups = maxi(0, pending_level_ups - 1)
    if pending_level_ups > 0:
        call_deferred("_open_surprise_choice")


func _set_combat_frozen(value: bool) -> void:
    super._set_combat_frozen(value)
    var mode: int = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
    for node: Node in get_tree().get_nodes_in_group("survivor_experience"):
        if node != null and is_instance_valid(node):
            node.process_mode = mode


func _refresh_hud() -> void:
    super._refresh_hud()
    if wave_label == null or hero_plant == null:
        return
    var shown_time: int = int(floor(survival_elapsed)) if endless_mode else mini(int(floor(survival_elapsed)), int(SURVIVAL_DURATION))
    wave_label.text = _t("TIME %02d:%02d", "时间 %02d:%02d") % [int(shown_time / 60), shown_time % 60]
    health_label.text = _t("HP %d/%d", "生命 %d/%d") % [hero_plant.health, hero_plant.max_health]
    coins_label.text = _t("KILLS %d", "击杀 %d") % enemies_defeated
    greed_label.text = _t("LV.%d XP %d/%d", "等级 %d 经验 %d/%d") % [hero_plant.level, experience, experience_to_next]


func _update_control_status() -> void:
    if control_label == null or hero_plant == null or not is_instance_valid(hero_plant):
        return
    if choice_open:
        control_label.text = _t("LEVEL UP · CHOOSE ONE MUTATION", "等级提升 · 选择一项变异")
    else:
        control_label.text = _t("WASD / ARROWS MOVE · WEAPONS FIRE AUTOMATICALLY", "WASD / 方向键移动 · 武器自动攻击")


func _finish_run(victory: bool) -> void:
    if game_ended:
        return
    game_ended = true
    wave_active = false
    _set_combat_frozen(true)
    choice_backdrop.visible = true
    choice_panel.visible = true
    choice_title.visible = false
    for button: Button in choice_buttons:
        button.visible = false
    result_label.visible = true
    result_button.visible = true
    result_button.grab_focus()
    if victory:
        result_label.text = _t("DAWN BLOOMED\nLV.%d · %d DEFEATED", "黎明开花\n等级 %d · 击败 %d") % [hero_plant.level, enemies_defeated]
        audio_manager.play_event(&"victory")
    else:
        result_label.text = _t("THE GARDEN WITHERED\nGROW A NEW BUILD", "花园枯萎\n重新培育一种构筑")
        audio_manager.play_event(&"defeat")
    result_button.text = _t("START NEW RUN", "开始新一局")


func _create_services() -> void:
    super._create_services()
    var rewards: Array[BlessingData] = blessing_system.pool.duplicate()
    rewards.append_array(SurvivorArsenal.reward_pool(endless_mode))
    blessing_system.setup(rewards, run_seed)


func _on_enemy_damaged(enemy: GreedEnemy, damage: float, critical: bool) -> void:
    total_damage += damage
    super._on_enemy_damaged(enemy, damage, critical)


# Visual metadata is separate from damage, targeting, timing and seeded RNG.
func _on_arsenal_visual_requested(origin: Vector2, target: GreedEnemy, damage: float, critical: bool, speed: float, splash_radius: float, slow_ratio: float, knockback_force: float, color: Color, _weapon: int, _evolved: bool) -> void:
    _on_projectile_requested(origin, target, damage, critical, speed, splash_radius, slow_ratio, knockback_force, color)
