extends Node2D
class_name GreedCore

signal health_changed(current: int, maximum: int)
signal defeated

const ARENA_RECT: Rect2 = Rect2(54.0, 68.0, 532.0, 244.0)

var max_health: int = 12
var health: int = 12
var move_speed: float = 64.0
var invulnerability_time: float = 0.0
var _wander_phase: float = 0.0
var _hit_flash: float = 0.0


func _ready() -> void:
    add_to_group("greed_core")
    queue_redraw()


func _process(delta: float) -> void:
    invulnerability_time = maxf(0.0, invulnerability_time - delta)
    _hit_flash = maxf(0.0, _hit_flash - delta)
    _wander_phase += delta

    var danger: Vector2 = Vector2.ZERO
    var nearest_distance: float = INF
    for node: Node in get_tree().get_nodes_in_group("greed_enemies"):
        var enemy: Node2D = node as Node2D
        if enemy == null or not is_instance_valid(enemy):
            continue
        var offset: Vector2 = global_position - enemy.global_position
        var distance_value: float = maxf(1.0, offset.length())
        nearest_distance = minf(nearest_distance, distance_value)
        if distance_value < 150.0:
            danger += offset.normalized() * (150.0 - distance_value) / 150.0

    var center: Vector2 = ARENA_RECT.get_center()
    var center_pull: Vector2 = (center - global_position) * 0.012
    var wander: Vector2 = Vector2(cos(_wander_phase * 0.71), sin(_wander_phase * 0.93)) * 0.22
    var desired: Vector2 = danger * 1.45 + center_pull + wander
    if desired.length_squared() > 0.01:
        global_position += desired.normalized() * move_speed * delta
    global_position.x = clampf(global_position.x, ARENA_RECT.position.x, ARENA_RECT.end.x)
    global_position.y = clampf(global_position.y, ARENA_RECT.position.y, ARENA_RECT.end.y)
    queue_redraw()


func take_contact_damage(amount: int) -> bool:
    if amount <= 0 or health <= 0 or invulnerability_time > 0.0:
        return false
    health = maxi(0, health - amount)
    invulnerability_time = 0.75
    _hit_flash = 0.16
    health_changed.emit(health, max_health)
    queue_redraw()
    if health <= 0:
        defeated.emit()
    return true


func heal(amount: int) -> void:
    if amount <= 0 or health <= 0:
        return
    health = mini(max_health, health + amount)
    health_changed.emit(health, max_health)
    queue_redraw()


func _draw() -> void:
    var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.05
    var body: Color = Color.WHITE if _hit_flash > 0.0 else Color("b8ec71")
    draw_circle(Vector2.ZERO, 15.0 * pulse, Color(0.12, 0.28, 0.18, 0.72))
    draw_circle(Vector2.ZERO, 11.0 * pulse, body)
    draw_rect(Rect2(-3.0, -8.0, 2.0, 3.0), Color("183225"))
    draw_rect(Rect2(2.0, -8.0, 2.0, 3.0), Color("183225"))
    draw_line(Vector2(-6.0, 8.0), Vector2(-11.0, 14.0), Color("69ad4c"), 3.0)
    draw_line(Vector2(6.0, 8.0), Vector2(11.0, 14.0), Color("69ad4c"), 3.0)
    if invulnerability_time > 0.0:
        draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 24, Color(0.82, 0.94, 1.0, 0.65), 2.0)