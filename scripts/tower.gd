extends Node2D
class_name SproutTower

signal critical_shot(damage_value: float)

var data: TowerData
var level: int = 1
var damage: float = 12.0
var attack_interval: float = 0.65
var attack_range: float = 92.0
var total_spent: int = 75
var slot_index: int = -1
var is_selected: bool = false
var disabled_time: float = 0.0

var _projectile_pool: ProjectilePool
var _enemy_registry: EnemyRegistry
var _blessing_system: BlessingSystem
var _effective_status_effect: StatusEffectData
var _attack_strategy: AttackStrategy = ProjectileAttackStrategy.new()
var _cooldown: float = 0.15
var _shot_time: float = 0.0
var _shot_target: Vector2 = Vector2.ZERO


func configure(
        index: int,
        tower_data: TowerData,
        projectile_pool: ProjectilePool,
        enemy_registry: EnemyRegistry
) -> void:
    slot_index = index
    data = tower_data
    _projectile_pool = projectile_pool
    _enemy_registry = enemy_registry
    level = 1
    total_spent = 0 if data == null else data.build_cost
    _apply_level_stats()
    add_to_group("towers")
    queue_redraw()


func attach_blessing_system(system: BlessingSystem) -> void:
    if _blessing_system != null and _blessing_system.modifiers_changed.is_connected(_on_blessing_modifiers_changed):
        _blessing_system.modifiers_changed.disconnect(_on_blessing_modifiers_changed)
    _blessing_system = system
    if _blessing_system != null and not _blessing_system.modifiers_changed.is_connected(_on_blessing_modifiers_changed):
        _blessing_system.modifiers_changed.connect(_on_blessing_modifiers_changed)
    _apply_level_stats()
    queue_redraw()


func _process(delta: float) -> void:
    _shot_time = maxf(0.0, _shot_time - delta)
    if disabled_time > 0.0:
        disabled_time = maxf(0.0, disabled_time - delta)
        queue_redraw()
        return

    _cooldown -= delta
    if _cooldown <= 0.0:
        var target: SproutEnemy = _select_target()
        if target != null:
            var shot_damage: float = damage
            if _blessing_system != null and _blessing_system.roll_critical():
                shot_damage *= BlessingSystem.CRITICAL_DAMAGE_MULTIPLIER
                critical_shot.emit(shot_damage)
            _attack_strategy.fire(
                global_position + _get_attack_origin(),
                target,
                data,
                shot_damage,
                _projectile_pool,
                _enemy_registry,
                _effective_status_effect
            )
            _shot_target = to_local(target.global_position)
            _shot_time = 0.08
            _cooldown = attack_interval
        else:
            _cooldown = 0.08

    if _shot_time > 0.0:
        queue_redraw()


func disable_for(duration: float) -> void:
    disabled_time = maxf(disabled_time, duration)
    queue_redraw()


func is_disabled() -> bool:
    return disabled_time > 0.0


func _select_target() -> SproutEnemy:
    if _enemy_registry == null:
        return null

    var candidates: Array[SproutEnemy] = _enemy_registry.query_radius(global_position, attack_range)
    var best_target: SproutEnemy = null
    var best_value: float = 0.0
    var has_value: bool = false

    for enemy: SproutEnemy in candidates:
        if enemy == null or not is_instance_valid(enemy):
            continue
        if data != null:
            if enemy.is_flying and not data.can_attack_flying:
                continue
            if not enemy.is_flying and not data.can_attack_ground:
                continue

        var value: float = _target_value(enemy)
        if not has_value or _is_better_target(value, best_value):
            best_target = enemy
            best_value = value
            has_value = true

    return best_target


func _target_value(enemy: SproutEnemy) -> float:
    if data == null:
        return enemy.progress_ratio
    match data.target_mode:
        TowerData.TargetMode.LAST:
            return enemy.progress_ratio
        TowerData.TargetMode.STRONGEST:
            return enemy.health
        TowerData.TargetMode.WEAKEST:
            return enemy.health
        TowerData.TargetMode.NEAREST:
            return global_position.distance_squared_to(enemy.global_position)
        _:
            return enemy.progress_ratio


func _is_better_target(value: float, current: float) -> bool:
    if data == null:
        return value > current
    match data.target_mode:
        TowerData.TargetMode.LAST, TowerData.TargetMode.WEAKEST, TowerData.TargetMode.NEAREST:
            return value < current
        _:
            return value > current


func get_upgrade_cost() -> int:
    if data == null:
        return -1
    return data.get_upgrade_cost(level)


func apply_upgrade() -> void:
    var cost: int = get_upgrade_cost()
    if cost < 0:
        return
    total_spent += cost
    level += 1
    _apply_level_stats()
    queue_redraw()


func get_sell_value() -> int:
    var ratio: float = 0.7 if data == null else data.sell_ratio
    return int(round(float(total_spent) * ratio))


func get_display_name() -> String:
    return "Tower" if data == null else data.display_name


func set_selected(value: bool) -> void:
    is_selected = value
    queue_redraw()


func contains_world_point(point: Vector2) -> bool:
    return global_position.distance_to(point) <= 18.0


func _apply_level_stats() -> void:
    if data == null:
        return
    damage = data.get_damage_for_level(level)
    attack_interval = data.get_interval_for_level(level)
    attack_range = data.get_range_for_level(level)
    _effective_status_effect = data.status_effect
    if _blessing_system != null:
        damage *= _blessing_system.get_damage_multiplier()
        attack_interval = maxf(0.08, attack_interval * _blessing_system.get_attack_interval_multiplier())
        attack_range *= _blessing_system.get_range_multiplier()
        _effective_status_effect = _blessing_system.modify_status_effect(data.status_effect)


func _on_blessing_modifiers_changed() -> void:
    _apply_level_stats()
    queue_redraw()


func _get_attack_origin() -> Vector2:
    if data == null:
        return Vector2(12.0, -5.0)
    match data.id:
        &"mushroom_lamp":
            return Vector2(0.0, -10.0)
        &"ice_flower":
            return Vector2(0.0, -12.0)
        _:
            return Vector2(12.0, -5.0)


func _draw() -> void:
    var accent: Color = Color("69b84d") if data == null else data.accent_color
    if is_selected:
        var range_fill: Color = accent
        range_fill.a = 0.10
        var range_line: Color = accent
        range_line.a = 0.62
        draw_circle(Vector2.ZERO, attack_range, range_fill)
        draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, range_line, 1.0)

    if data == null or data.id == &"pea_tower":
        _draw_pea_tower()
    elif data.id == &"mushroom_lamp":
        _draw_mushroom_lamp()
    elif data.id == &"ice_flower":
        _draw_ice_flower()
    else:
        _draw_pea_tower()

    for marker: int in range(level):
        draw_rect(Rect2(-7.0 + marker * 6.0, 14.0, 4.0, 3.0), Color("f5d76e"))

    if _shot_time > 0.0:
        var shot_color: Color = Color("d9ff8c") if data == null else data.projectile_color
        shot_color.a = 0.35
        draw_line(_get_attack_origin(), _shot_target, shot_color, 1.0)

    if disabled_time > 0.0:
        draw_rect(Rect2(-13.0, -13.0, 26.0, 26.0), Color(0.25, 0.32, 0.38, 0.42), false, 2.0)
        draw_line(Vector2(-9.0, -11.0), Vector2(0.0, -4.0), Color("ffe07a"), 2.0)
        draw_line(Vector2(0.0, -4.0), Vector2(-3.0, 3.0), Color("ffe07a"), 2.0)
        draw_line(Vector2(-3.0, 3.0), Vector2(8.0, 10.0), Color("ffe07a"), 2.0)


func _draw_pea_tower() -> void:
    var base: Color = Color("3e6a3f") if data == null else data.base_color
    var body: Color = Color("8bd35f") if data == null else data.body_color
    var accent: Color = Color("69b84d") if data == null else data.accent_color
    draw_rect(Rect2(-12.0, 5.0, 24.0, 7.0), base)
    draw_rect(Rect2(-4.0, -2.0, 8.0, 10.0), accent)
    draw_rect(Rect2(-8.0, -10.0, 16.0, 11.0), body)
    draw_rect(Rect2(5.0, -7.0, 10.0 + float(level - 1) * 2.0, 5.0), accent)
    draw_rect(Rect2(-4.0, -7.0, 2.0, 2.0), Color("203a2a"))
    draw_rect(Rect2(2.0, -7.0, 2.0, 2.0), Color("203a2a"))


func _draw_mushroom_lamp() -> void:
    var base: Color = data.base_color
    var body: Color = data.body_color
    var accent: Color = data.accent_color
    draw_rect(Rect2(-11.0, 7.0, 22.0, 5.0), base)
    draw_rect(Rect2(-4.0, -2.0, 8.0, 11.0), accent)
    draw_circle(Vector2(0.0, -5.0), 11.0 + float(level - 1), body)
    draw_circle(Vector2(-4.0, -7.0), 2.0, Color("f3dcff"))
    draw_circle(Vector2(4.0, -4.0), 2.0, Color("f3dcff"))
    draw_rect(Rect2(-3.0, 0.0, 2.0, 2.0), Color("30213b"))
    draw_rect(Rect2(2.0, 0.0, 2.0, 2.0), Color("30213b"))


func _draw_ice_flower() -> void:
    var base: Color = data.base_color
    var body: Color = data.body_color
    var accent: Color = data.accent_color
    draw_rect(Rect2(-10.0, 7.0, 20.0, 5.0), base)
    for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
        draw_circle(direction * 7.0, 5.0 + float(level - 1) * 0.5, body)
    draw_circle(Vector2.ZERO, 6.0, accent)
    draw_rect(Rect2(-3.0, -2.0, 2.0, 2.0), Color("18354f"))
    draw_rect(Rect2(2.0, -2.0, 2.0, 2.0), Color("18354f"))