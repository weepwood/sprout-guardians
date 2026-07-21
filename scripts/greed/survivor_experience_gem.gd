extends Node2D
class_name SurvivorExperienceGem

signal collected(amount: int)

const PICKUP_RADIUS: float = 22.0
const MAGNET_RADIUS: float = 96.0
const MAGNET_SPEED: float = 240.0
const LIFE_SECONDS: float = 45.0

var target: GreedHeroPlant
var experience_value: int = 1
var age: float = 0.0
var _phase: float = 0.0


func configure(target_value: GreedHeroPlant, amount: int = 1) -> void:
    target = target_value
    experience_value = maxi(1, amount)
    _phase = fmod(global_position.x * 0.017 + global_position.y * 0.031, TAU)
    add_to_group("survivor_experience")
    queue_redraw()


func _process(delta: float) -> void:
    age += delta
    _phase += delta * 4.0
    if age >= LIFE_SECONDS:
        queue_free()
        return
    if target == null or not is_instance_valid(target):
        queue_redraw()
        return

    var distance_value: float = global_position.distance_to(target.global_position)
    if distance_value <= PICKUP_RADIUS:
        collected.emit(experience_value)
        queue_free()
        return
    if distance_value <= MAGNET_RADIUS:
        var speed_scale: float = lerpf(0.55, 1.35, 1.0 - distance_value / MAGNET_RADIUS)
        global_position = global_position.move_toward(target.global_position, MAGNET_SPEED * speed_scale * delta)
    queue_redraw()


func _draw() -> void:
    var pulse: float = 1.0 + sin(_phase) * 0.12
    var radius: float = 5.0 * pulse
    draw_circle(Vector2.ZERO, radius + 2.0, Color(0.05, 0.15, 0.12, 0.75))
    draw_circle(Vector2.ZERO, radius, Color("71e6a0"))
    draw_circle(Vector2(-1.5, -1.5), 1.5, Color("d9ffe4"))
