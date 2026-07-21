extends Node2D
class_name GreedProjectile

signal impacted(projectile: GreedProjectile, target: GreedEnemy, damage: float, critical: bool)
signal expired(projectile: GreedProjectile)

var target: GreedEnemy
var damage: float = 1.0
var critical: bool = false
var speed: float = 360.0
var splash_radius: float = 0.0
var slow_ratio: float = 0.0
var knockback_force: float = 32.0
var source_position: Vector2 = Vector2.ZERO
var body_color: Color = Color("8fe45f")
var lifetime: float = 2.0

var _finished: bool = false
var _travel_direction: Vector2 = Vector2.RIGHT


func configure(
        origin: Vector2,
        target_enemy: GreedEnemy,
        damage_value: float,
        is_critical: bool,
        speed_value: float,
        splash_value: float,
        slow_value: float,
        knockback_value: float,
        color_value: Color
) -> void:
    global_position = origin
    source_position = origin
    target = target_enemy
    damage = maxf(1.0, damage_value)
    critical = is_critical
    speed = maxf(80.0, speed_value)
    splash_radius = maxf(0.0, splash_value)
    slow_ratio = clampf(slow_value, 0.0, 0.8)
    knockback_force = maxf(0.0, knockback_value)
    body_color = color_value
    lifetime = 2.4
    _finished = false
    add_to_group("greed_projectiles")
    queue_redraw()


func _process(delta: float) -> void:
    if _finished:
        return
    lifetime -= delta
    if lifetime <= 0.0 or target == null or not is_instance_valid(target):
        _finish()
        return

    var offset: Vector2 = target.global_position - global_position
    var distance_value: float = offset.length()
    if distance_value > 0.01:
        _travel_direction = offset.normalized()
    var step: float = speed * delta
    if distance_value <= maxf(5.0, step):
        global_position = target.global_position
        _impact()
        return

    global_position += _travel_direction * step
    queue_redraw()


func _impact() -> void:
    if _finished or target == null or not is_instance_valid(target):
        _finish()
        return

    if splash_radius > 0.0:
        var impact_position: Vector2 = target.global_position
        for node: Node in get_tree().get_nodes_in_group("greed_enemies"):
            var enemy: GreedEnemy = node as GreedEnemy
            if enemy == null or not is_instance_valid(enemy):
                continue
            if enemy.global_position.distance_to(impact_position) <= splash_radius:
                _damage_enemy(enemy, 0.82 if enemy != target else 1.0)
    else:
        _damage_enemy(target, 1.0)

    impacted.emit(self, target, damage, critical)
    _finish()


func _damage_enemy(enemy: GreedEnemy, multiplier: float) -> void:
    if enemy == null or not is_instance_valid(enemy):
        return
    enemy.take_damage(damage * multiplier, critical)
    if is_instance_valid(enemy):
        enemy.apply_knockback(source_position, knockback_force)
        if slow_ratio > 0.0:
            enemy.apply_slow(1.0 - slow_ratio, 1.6)


func _finish() -> void:
    if _finished:
        return
    _finished = true
    expired.emit(self)
    queue_free()


func _draw() -> void:
    var trail_color: Color = body_color
    trail_color.a = 0.42
    var trail_length: float = 13.0 if critical else 8.0
    draw_line(Vector2.ZERO, -_travel_direction * trail_length, trail_color, 2.0)
    var size_value: float = 4.5 if critical else 3.0
    draw_rect(Rect2(-size_value, -size_value, size_value * 2.0, size_value * 2.0), body_color)
    if critical:
        draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 12, Color(1.0, 0.92, 0.45, 0.82), 2.0)
