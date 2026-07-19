extends Node2D
class_name SproutTower

var level: int = 1
var damage: float = 12.0
var attack_interval: float = 0.65
var attack_range: float = 92.0
var build_cost: int = 75
var total_spent: int = 75
var slot_index: int = -1
var is_selected: bool = false

var _cooldown: float = 0.15
var _shot_time: float = 0.0
var _shot_target: Vector2 = Vector2.ZERO


func configure(index: int) -> void:
    slot_index = index
    add_to_group("towers")
    queue_redraw()


func _process(delta: float) -> void:
    _cooldown -= delta
    _shot_time = maxf(0.0, _shot_time - delta)

    if _cooldown <= 0.0:
        var target: SproutEnemy = _select_target()
        if target != null:
            target.take_damage(damage)
            _shot_target = to_local(target.global_position)
            _shot_time = 0.08
            _cooldown = attack_interval
        else:
            _cooldown = 0.08

    if _shot_time > 0.0:
        queue_redraw()


func _select_target() -> SproutEnemy:
    var best_target: SproutEnemy = null
    var best_progress: float = -1.0

    for node: Node in get_tree().get_nodes_in_group("enemies"):
        var enemy: SproutEnemy = node as SproutEnemy
        if enemy == null or not is_instance_valid(enemy):
            continue
        if global_position.distance_to(enemy.global_position) > attack_range:
            continue
        if enemy.progress_ratio > best_progress:
            best_progress = enemy.progress_ratio
            best_target = enemy

    return best_target


func get_upgrade_cost() -> int:
    if level >= 3:
        return -1
    return 55 * level


func apply_upgrade() -> void:
    var cost: int = get_upgrade_cost()
    if cost < 0:
        return
    total_spent += cost
    level += 1
    damage *= 1.55
    attack_interval = maxf(0.28, attack_interval * 0.82)
    attack_range += 8.0
    queue_redraw()


func get_sell_value() -> int:
    return int(round(float(total_spent) * 0.7))


func set_selected(value: bool) -> void:
    is_selected = value
    queue_redraw()


func contains_world_point(point: Vector2) -> bool:
    return global_position.distance_to(point) <= 18.0


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
        draw_line(Vector2(12.0, -5.0), _shot_target, Color("d9ff8c"), 2.0)
