extends Node2D
class_name SproutTower

var data: TowerData
var level: int = 1
var damage: float = 12.0
var attack_interval: float = 0.65
var attack_range: float = 92.0
var total_spent: int = 75
var slot_index: int = -1
var is_selected: bool = false

var _projectile_pool: ProjectilePool
var _enemy_registry: EnemyRegistry
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


func _process(delta: float) -> void:
    _cooldown -= delta
    _shot_time = maxf(0.0, _shot_time - delta)

    if _cooldown <= 0.0:
        var target: SproutEnemy = _select_target()
        if target != null:
            _attack_strategy.fire(global_position + Vector2(12.0, -5.0), target, data, damage, _projectile_pool)
            _shot_target = to_local(target.global_position)
            _shot_time = 0.08
            _cooldown = attack_interval
        else:
            _cooldown = 0.08

    if _shot_time > 0.0:
        queue_redraw()


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


func _draw() -> void:
    if is_selected:
        draw_circle(Vector2.ZERO, attack_range, Color(0.45, 0.9, 0.55, 0.10))
        draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, Color(0.55, 0.95, 0.65, 0.55), 1.0)

    draw_rect(Rect2(-12.0, 5.0, 24.0, 7.0), Color("3e6a3f"))
    draw_rect(Rect2(-4.0, -2.0, 8.0, 10.0), Color("5ca653"))
    draw_rect(Rect2(-8.0, -10.0, 16.0, 11.0), Color("8bd35f"))
    draw_rect(Rect2(5.0, -7.0, 10.0 + float(level - 1) * 2.0, 5.0), Color("69b84d"))
    draw_rect(Rect2(-4.0, -7.0, 2.0, 2.0), Color("203a2a"))
    draw_rect(Rect2(2.0, -7.0, 2.0, 2.0), Color("203a2a"))

    for marker: int in range(level):
        draw_rect(Rect2(-7.0 + marker * 6.0, 14.0, 4.0, 3.0), Color("f5d76e"))

    if _shot_time > 0.0:
        draw_line(Vector2(12.0, -5.0), _shot_target, Color(0.85, 1.0, 0.55, 0.30), 1.0)
