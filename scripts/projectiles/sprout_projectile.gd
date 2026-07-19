extends Node2D
class_name SproutProjectile

signal recycle_requested(projectile: SproutProjectile)

var target: SproutEnemy
var damage: float = 0.0
var speed: float = 240.0
var body_color: Color = Color("d9ff8c")
var active: bool = false


func launch(
        start_position: Vector2,
        target_value: SproutEnemy,
        damage_value: float,
        speed_value: float,
        color_value: Color
) -> void:
    global_position = start_position
    target = target_value
    damage = damage_value
    speed = speed_value
    body_color = color_value
    active = true
    visible = true
    set_process(true)
    queue_redraw()


func reset() -> void:
    active = false
    target = null
    damage = 0.0
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
        target.take_damage(damage)
        _request_recycle()
        return

    global_position = global_position.move_toward(target.global_position, movement)


func _request_recycle() -> void:
    if not active:
        return
    active = false
    recycle_requested.emit(self)


func _draw() -> void:
    draw_rect(Rect2(-3.0, -2.0, 6.0, 4.0), Color("365f3b"))
    draw_rect(Rect2(-2.0, -1.0, 4.0, 2.0), body_color)
