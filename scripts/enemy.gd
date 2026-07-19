extends Node2D
class_name SproutEnemy

signal defeated(enemy: SproutEnemy, reward: int)
signal escaped(enemy: SproutEnemy, damage: int)

var data: EnemyData
var path_points: PackedVector2Array = PackedVector2Array()
var path_index: int = 1
var move_speed: float = 48.0
var max_health: float = 50.0
var health: float = 50.0
var reward: int = 10
var goal_damage: int = 1
var progress_ratio: float = 0.0
var is_flying: bool = false

var status_effects: StatusEffectComponent

var _total_length: float = 1.0
var _travelled: float = 0.0
var _finished: bool = false
var _flash_time: float = 0.0
var _body_color: Color = Color("86c85a")
var _body_size: Vector2 = Vector2(12.0, 12.0)


func configure(points: PackedVector2Array, enemy_data: EnemyData) -> void:
    data = enemy_data
    path_points = points
    path_index = 1
    _travelled = 0.0
    _finished = false

    if data != null:
        max_health = data.max_health
        health = data.max_health
        move_speed = data.move_speed
        reward = data.reward
        goal_damage = data.goal_damage
        is_flying = data.is_flying
        _body_color = data.body_color
        _body_size = data.body_size

    _total_length = _calculate_path_length()
    if not path_points.is_empty():
        global_position = path_points[0]

    status_effects = StatusEffectComponent.new()
    status_effects.name = "StatusEffects"
    add_child(status_effects)
    status_effects.setup(self)

    add_to_group("enemies")
    queue_redraw()


func _process(delta: float) -> void:
    if _finished or path_points.size() < 2:
        return

    if _flash_time > 0.0:
        _flash_time = maxf(0.0, _flash_time - delta)

    var target_point: Vector2 = path_points[path_index]
    var distance_to_target: float = global_position.distance_to(target_point)
    var speed_multiplier: float = 1.0 if status_effects == null else status_effects.get_speed_multiplier()
    var movement: float = move_speed * speed_multiplier * delta

    if movement >= distance_to_target:
        global_position = target_point
        _travelled += distance_to_target
        path_index += 1
        if path_index >= path_points.size():
            _reach_goal()
            return
    else:
        global_position = global_position.move_toward(target_point, movement)
        _travelled += movement

    progress_ratio = clampf(_travelled / _total_length, 0.0, 1.0)
    queue_redraw()


func take_damage(amount: float) -> void:
    if _finished or amount <= 0.0:
        return
    var armor: float = 0.0 if data == null else data.armor
    var final_damage: float = maxf(1.0, amount - armor)
    health -= final_damage
    _flash_time = 0.08
    queue_redraw()
    if health <= 0.0:
        _die()


func apply_status(effect: StatusEffectData) -> void:
    if not _finished and status_effects != null:
        status_effects.apply(effect)


func _die() -> void:
    if _finished:
        return
    _finished = true
    defeated.emit(self, reward)
    queue_free()


func _reach_goal() -> void:
    if _finished:
        return
    _finished = true
    escaped.emit(self, goal_damage)
    queue_free()


func _calculate_path_length() -> float:
    var length: float = 0.0
    for index: int in range(1, path_points.size()):
        length += path_points[index - 1].distance_to(path_points[index])
    return maxf(length, 1.0)


func _draw() -> void:
    var color: Color = Color.WHITE if _flash_time > 0.0 else _body_color
    var half_size: Vector2 = _body_size * 0.5
    draw_rect(Rect2(-half_size - Vector2(2.0, 2.0), _body_size + Vector2(4.0, 4.0)), Color("274c35"))
    draw_rect(Rect2(-half_size, _body_size), color)
    draw_rect(Rect2(-5.0, -4.0, 3.0, 3.0), Color("183225"))
    draw_rect(Rect2(2.0, -4.0, 3.0, 3.0), Color("183225"))

    var health_ratio: float = clampf(health / max_health, 0.0, 1.0)
    draw_rect(Rect2(-9.0, -13.0, 18.0, 3.0), Color("2a2430"))
    draw_rect(Rect2(-9.0, -13.0, 18.0 * health_ratio, 3.0), Color("f06b63"))
