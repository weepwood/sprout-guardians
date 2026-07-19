extends Node2D
class_name GreedEnemy

signal damaged(enemy: GreedEnemy, final_damage: float, critical: bool)
signal defeated(enemy: GreedEnemy, coin_reward: int, elite: bool)
signal core_contact(enemy: GreedEnemy, damage: int)

var target: GreedCore
var max_health: float = 30.0
var health: float = 30.0
var move_speed: float = 48.0
var contact_damage: int = 1
var coin_reward: int = 1
var elite: bool = false
var boss: bool = false
var body_color: Color = Color("dd6d63")
var body_size: float = 12.0

var _contact_cooldown: float = 0.0
var _flash_time: float = 0.0
var _squash_time: float = 0.0
var _knock_velocity: Vector2 = Vector2.ZERO
var _finished: bool = false


func configure(core: GreedCore, config: Dictionary, health_scale: float = 1.0) -> void:
    target = core
    max_health = maxf(1.0, float(config.get("health", 30.0)) * health_scale)
    health = max_health
    move_speed = float(config.get("speed", 48.0))
    contact_damage = int(config.get("damage", 1))
    elite = bool(config.get("elite", false))
    boss = bool(config.get("boss", false))
    coin_reward = 4 if boss else (2 if elite else 1)
    body_size = 28.0 if boss else (18.0 if elite else 12.0)
    body_color = Color("a557d4") if boss else (Color("e39b4b") if elite else Color("dd6d63"))
    add_to_group("greed_enemies")
    queue_redraw()


func _process(delta: float) -> void:
    if _finished:
        return
    _contact_cooldown = maxf(0.0, _contact_cooldown - delta)
    _flash_time = maxf(0.0, _flash_time - delta)
    _squash_time = maxf(0.0, _squash_time - delta)
    _knock_velocity = _knock_velocity.move_toward(Vector2.ZERO, 420.0 * delta)
    global_position += _knock_velocity * delta

    if target == null or not is_instance_valid(target) or target.health <= 0:
        queue_redraw()
        return

    var to_core: Vector2 = target.global_position - global_position
    var distance_value: float = to_core.length()
    if distance_value > 1.0:
        var separation: Vector2 = _separation_force()
        var direction: Vector2 = (to_core.normalized() + separation * 0.55).normalized()
        global_position += direction * move_speed * delta

    if distance_value <= body_size * 0.55 + 13.0 and _contact_cooldown <= 0.0:
        _contact_cooldown = 0.85
        core_contact.emit(self, contact_damage)
        _knock_velocity = -to_core.normalized() * 150.0
        _squash_time = 0.12

    queue_redraw()


func take_damage(amount: float, critical: bool = false) -> float:
    if _finished or amount <= 0.0:
        return 0.0
    var final_damage: float = maxf(1.0, amount)
    health -= final_damage
    _flash_time = 0.08
    _squash_time = 0.09
    damaged.emit(self, final_damage, critical)
    if health <= 0.0:
        _die()
    queue_redraw()
    return final_damage


func apply_knockback(origin: Vector2, force: float) -> void:
    var direction: Vector2 = (global_position - origin).normalized()
    _knock_velocity += direction * force


func get_health_ratio() -> float:
    return clampf(health / maxf(1.0, max_health), 0.0, 1.0)


func _die() -> void:
    if _finished:
        return
    _finished = true
    defeated.emit(self, coin_reward, elite or boss)
    queue_free()


func _separation_force() -> Vector2:
    var result: Vector2 = Vector2.ZERO
    for node: Node in get_tree().get_nodes_in_group("greed_enemies"):
        var other: GreedEnemy = node as GreedEnemy
        if other == null or other == self or not is_instance_valid(other):
            continue
        var offset: Vector2 = global_position - other.global_position
        var distance_value: float = offset.length()
        if distance_value > 0.1 and distance_value < 26.0:
            result += offset.normalized() * (26.0 - distance_value) / 26.0
    return result


func _draw() -> void:
    var scale_y: float = 0.72 if _squash_time > 0.0 else 1.0
    var scale_x: float = 1.28 if _squash_time > 0.0 else 1.0
    var color_value: Color = Color.WHITE if _flash_time > 0.0 else body_color
    var size_value: Vector2 = Vector2(body_size * scale_x, body_size * scale_y)
    var half: Vector2 = size_value * 0.5
    draw_rect(Rect2(-half - Vector2(2.0, 2.0), size_value + Vector2(4.0, 4.0)), Color("3a2630"))
    draw_rect(Rect2(-half, size_value), color_value)
    draw_rect(Rect2(-half.x + 3.0, -3.0, 3.0, 3.0), Color("241a24"))
    draw_rect(Rect2(half.x - 6.0, -3.0, 3.0, 3.0), Color("241a24"))
    if elite or boss:
        draw_arc(Vector2.ZERO, body_size * 0.72, 0.0, TAU, 20, Color(1.0, 0.82, 0.32, 0.66), 2.0)
    var bar_width: float = 42.0 if boss else (26.0 if elite else 18.0)
    draw_rect(Rect2(-bar_width * 0.5, -half.y - 8.0, bar_width, 3.0), Color("201824"))
    draw_rect(Rect2(-bar_width * 0.5, -half.y - 8.0, bar_width * get_health_ratio(), 3.0), Color("f16f67"))