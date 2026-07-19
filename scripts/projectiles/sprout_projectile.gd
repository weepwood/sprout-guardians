extends Node2D
class_name SproutProjectile

signal recycle_requested(projectile: SproutProjectile)

var target: SproutEnemy
var damage: float = 0.0
var speed: float = 240.0
var body_color: Color = Color("d9ff8c")
var projectile_size: float = 4.0
var splash_radius: float = 0.0
var status_effect: StatusEffectData
var enemy_registry: EnemyRegistry
var critical_hit: bool = false
var active: bool = false


func launch(
        start_position: Vector2,
        target_value: SproutEnemy,
        damage_value: float,
        speed_value: float,
        color_value: Color,
        size_value: float = 4.0,
        splash_radius_value: float = 0.0,
        status_effect_value: StatusEffectData = null,
        enemy_registry_value: EnemyRegistry = null,
        critical_hit_value: bool = false
) -> void:
    global_position = start_position
    target = target_value
    damage = damage_value
    speed = speed_value
    body_color = color_value
    projectile_size = maxf(2.0, size_value)
    splash_radius = maxf(0.0, splash_radius_value)
    status_effect = status_effect_value
    enemy_registry = enemy_registry_value
    critical_hit = critical_hit_value
    active = true
    visible = true
    set_process(true)
    queue_redraw()


func reset() -> void:
    active = false
    target = null
    damage = 0.0
    status_effect = null
    enemy_registry = null
    splash_radius = 0.0
    critical_hit = false
    visible = false
    set_process(false)


func _process(delta: float) -> void:
    if not active:
        return
    if target == null or not is_instance_valid(target):
        _request_recycle()
        return

    var distance: float = global_position.distance_to(target.global_position)
    var movement: float = speed * delta
    if movement >= distance or distance <= 5.0:
        global_position = target.global_position
        _impact()
        _request_recycle()
        return

    global_position = global_position.move_toward(target.global_position, movement)


func _impact() -> void:
    var impacted: Array[SproutEnemy] = []
    if splash_radius > 0.0 and enemy_registry != null:
        impacted = enemy_registry.query_radius(global_position, splash_radius)
    elif target != null and is_instance_valid(target):
        impacted.append(target)

    if impacted.is_empty() and target != null and is_instance_valid(target):
        impacted.append(target)

    for enemy: SproutEnemy in impacted:
        if enemy == null or not is_instance_valid(enemy):
            continue
        enemy.take_damage(damage, critical_hit)
        if status_effect != null and is_instance_valid(enemy):
            enemy.apply_status(status_effect)


func _request_recycle() -> void:
    if not active:
        return
    active = false
    recycle_requested.emit(self)


func _draw() -> void:
    var half_width: float = projectile_size * 0.5
    var trail_color: Color = Color("fff1a3") if critical_hit else Color("365f3b")
    draw_rect(Rect2(-half_width - 1.0, -2.0, projectile_size + 2.0, 4.0), trail_color)
    draw_rect(Rect2(-half_width, -1.0, projectile_size, 2.0), body_color)