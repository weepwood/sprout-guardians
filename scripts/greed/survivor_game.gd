extends "res://scripts/greed/greed_game_mouse.gd"

const SURVIVAL_DURATION: float = 90.0
const FIRST_ELITE_TIME: float = 30.0
const SECOND_ELITE_TIME: float = 60.0
const BASE_EXPERIENCE_REQUIREMENT: int = 8
const MAX_ACTIVE_ENEMIES: int = 48

var survival_elapsed: float = 0.0
var survival_spawn_timer: float = 0.15
var experience: int = 0
var experience_to_next: int = BASE_EXPERIENCE_REQUIREMENT
var pending_level_ups: int = 0
var first_elite_spawned: bool = false
var second_elite_spawned: bool = false
var final_boss_spawned: bool = false
var final_boss_defeated: bool = false
var _movement_keys: Dictionary = {
    "left": false,
    "right": false,
    "up": false,
    "down": false,
}


func _ready() -> void:
    super._ready()
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

    _spawn_time_milestones()
    if survival_elapsed < SURVIVAL_DURATION:
        survival_spawn_timer -= delta
        var active_enemies: int = get_tree().get_nodes_in_group("greed_enemies").size()
        if survival_spawn_timer <= 0.0 and active_enemies < _active_enemy_cap():
            _spawn_survivor_enemy(false, false)
            survival_spawn_timer = _current_spawn_interval()
    elif not final_boss_spawned:
        final_boss_spawned = true
        _spawn_survivor_enemy(true, true)
        status_label.text = _t("FINAL BLOOM BEAST", "最终花兽出现")

    if final_boss_spawned and final_boss_defeated:
        var remaining: int = get_tree().get_nodes_in_group("greed_enemies").size()
        if remaining <= 0:
            _finish_run(true)
            return

    var remaining_seconds: int = maxi(0, int(ceil(SURVIVAL_DURATION - survival_elapsed)))
    var enemy_count: int = get_tree().get_nodes_in_group("greed_enemies").size()
    if survival_elapsed < SURVIVAL_DURATION:
        status_label.text = _t("SURVIVE %02ds · %d ENEMIES", "生存 %02d秒 · %d 个敌人") % [remaining_seconds, enemy_count]
    _refresh_hud()
    _update_control_status()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key_event: InputEventKey = event as InputEventKey
        var key_value: Key = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
        var handled_movement: bool = true
        match key_value:
            KEY_A, KEY_LEFT:
                _movement_keys["left"] = key_event.pressed
            KEY_D, KEY_RIGHT:
                _movement_keys["right"] = key_event.pressed
            KEY_W, KEY_UP:
                _movement_keys["up"] = key_event.pressed
            KEY_S, KEY_DOWN:
                _movement_keys["down"] = key_event.pressed
            _:
                handled_movement = false
        if handled_movement:
            get_viewport().set_input_as_handled()
            return
    super._unhandled_input(event)


func _apply_continuous_movement() -> void:
    if hero_plant == null or not is_instance_valid(hero_plant) or hero_plant.dragging or hero_plant.is_dashing():
        return
    var direction: Vector2 = Vector2(
        float(int(bool(_movement_keys["right"])) - int(bool(_movement_keys["left"]))),
        float(int(bool(_movement_keys["down"])) - int(bool(_movement_keys["up"])))
    )
    if direction.length_squared() <= 0.0:
        return
    direction = direction.normalized()
    hero_plant.set_move_target(hero_plant.global_position + direction * 96.0)


func _spawn_time_milestones() -> void:
    if survival_elapsed >= FIRST_ELITE_TIME and not first_elite_spawned:
        first_elite_spawned = true
        _spawn_survivor_enemy(true, false)
        impact_system.spawn_reward(ARENA_RECT.get_center(), Color("f0a34d"))
    if survival_elapsed >= SECOND_ELITE_TIME and not second_elite_spawned:
        second_elite_spawned = true
        _spawn_survivor_enemy(true, false)
        _spawn_survivor_enemy(true, false)
        impact_system.spawn_reward(ARENA_RECT.get_center(), Color("df72ef"))


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
    return maxf(0.16, 0.72 - survival_elapsed * 0.0052)


func _active_enemy_cap() -> int:
    return mini(MAX_ACTIVE_ENEMIES, 14 + int(floor(survival_elapsed / 6.0)) * 2)


func _on_enemy_defeated(enemy: GreedEnemy, coin_reward: int, elite: bool) -> void:
    var drop_position: Vector2 = hero_plant.global_position if hero_plant != null else ARENA_RECT.get_center()
    var experience_value: int = 3 if elite else 1
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
    gem.configure(hero_plant, amount)
    gem.collected.connect(_on_experience_collected)
    return gem


func _on_experience_collected(amount: int) -> void:
    experience += maxi(1, amount)
    while experience >= experience_to_next:
        experience -= experience_to_next
        pending_level_ups += 1
        experience_to_next = _experience_requirement_for_level(hero_plant.level + pending_level_ups)
    if pending_level_ups > 0 and not choice_open:
        _open_surprise_choice()
    _refresh_hud()


func _experience_requirement_for_level(level_value: int) -> int:
    return BASE_EXPERIENCE_REQUIREMENT + maxi(0, level_value - 1) * 5


func _open_surprise_choice() -> void:
    super._open_surprise_choice()
    choice_title.text = _t("LEVEL UP · CHOOSE A GARDEN MUTATION", "等级提升 · 选择花园变异")


func _select_choice(index: int) -> void:
    if not choice_open:
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
    var shown_time: int = mini(int(floor(survival_elapsed)), int(SURVIVAL_DURATION))
    wave_label.text = _t("TIME %02d:%02d", "时间 %02d:%02d") % [int(shown_time / 60), shown_time % 60]
    health_label.text = _t("HP %d/%d", "生命 %d/%d") % [hero_plant.health, hero_plant.max_health]
    coins_label.text = _t("KILLS %d", "击杀 %d") % enemies_defeated
    greed_label.text = _t("LV.%d XP %d/%d", "等级 %d 经验 %d/%d") % [hero_plant.level, experience, experience_to_next]


func _update_control_status() -> void:
    if control_label == null or hero_plant == null or not is_instance_valid(hero_plant):
        return
    if choice_open:
        control_label.text = _t("LEVEL UP · CHOOSE ONE MUTATION", "等级提升 · 选择一项变异")
    elif hero_plant.is_dashing():
        control_label.text = _t("DASHING · BRIEF CONTACT IMMUNITY", "闪避中 · 短暂无视接触伤害")
    else:
        control_label.text = _t("WASD / ARROWS TO MOVE · SPACE OR DOUBLE CLICK TO DASH · ATTACKS ARE AUTOMATIC", "WASD / 方向键移动 · 空格或双击闪避 · 自动攻击")


func _finish_run(victory: bool) -> void:
    if game_ended:
        return
    game_ended = true
    wave_active = false
    _set_combat_frozen(true)
    choice_backdrop.visible = true
    result_label.visible = true
    result_button.visible = true
    if victory:
        result_label.text = _t("DAWN BLOOMED\nLV.%d · %d DEFEATED", "黎明开花\n等级 %d · 击败 %d") % [hero_plant.level, enemies_defeated]
        audio_manager.play_event(&"victory")
    else:
        result_label.text = _t("THE GARDEN WITHERED\nGROW A NEW BUILD", "花园枯萎\n重新培育一种构筑")
        audio_manager.play_event(&"defeat")
    result_button.text = _t("START NEW RUN", "开始新一局")
