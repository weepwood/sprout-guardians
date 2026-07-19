extends GreedCore
class_name GreedHeroPlant

signal fired(hero: GreedHeroPlant, target: GreedEnemy, critical: bool, damage: float)
signal selection_changed(selected: bool)
signal focus_changed(target: GreedEnemy)

var blessing_system: BlessingSystem
var config: Dictionary = {}
var level: int = 1
var fury_multiplier: float = 1.0
var rescue_active: bool = false
var selected: bool = false
var dragging: bool = false
var has_move_target: bool = false
var move_target: Vector2 = Vector2.ZERO
var focus_target: GreedEnemy

var _cooldown: float = 0.0
var _shot_time: float = 0.0
var _shot_target_local: Vector2 = Vector2.ZERO


func configure(plant_config: Dictionary, blessings: BlessingSystem = null) -> void:
    config = plant_config.duplicate(true)
    blessing_system = blessings
    move_speed = 155.0
    _cooldown = 0.08
    move_target = global_position
    queue_redraw()


func _process(delta: float) -> void:
    invulnerability_time = maxf(0.0, invulnerability_time - delta)
    _hit_flash = maxf(0.0, _hit_flash - delta)
    _shot_time = maxf(0.0, _shot_time - delta)

    if focus_target != null and not is_instance_valid(focus_target):
        focus_target = null
        focus_changed.emit(null)

    if not dragging and has_move_target:
        global_position = global_position.move_toward(move_target, move_speed * delta)
        if global_position.distance_to(move_target) <= 2.0:
            global_position = move_target
            has_move_target = false

    global_position = _clamp_to_arena(global_position)

    _cooldown -= delta
    if _cooldown <= 0.0:
        var target_enemy: GreedEnemy = _find_target()
        if target_enemy != null:
            _attack(target_enemy)
            _cooldown = _effective_interval()
        else:
            _cooldown = 0.06
    queue_redraw()


func set_selected(value: bool) -> void:
    if selected == value:
        return
    selected = value
    if not selected:
        dragging = false
    selection_changed.emit(selected)
    queue_redraw()


func begin_drag() -> void:
    set_selected(true)
    dragging = true
    has_move_target = false
    queue_redraw()


func drag_to(position_value: Vector2) -> void:
    if not dragging:
        return
    global_position = _clamp_to_arena(position_value)
    move_target = global_position
    queue_redraw()


func end_drag(position_value: Vector2) -> void:
    if not dragging:
        return
    global_position = _clamp_to_arena(position_value)
    move_target = global_position
    dragging = false
    has_move_target = false
    queue_redraw()


func set_move_target(position_value: Vector2) -> void:
    set_selected(true)
    move_target = _clamp_to_arena(position_value)
    has_move_target = true
    dragging = false
    queue_redraw()


func set_focus_target(enemy: GreedEnemy) -> void:
    if focus_target != null and is_instance_valid(focus_target):
        focus_target.set_priority_targeted(false)
    focus_target = enemy
    if focus_target != null and is_instance_valid(focus_target):
        focus_target.set_priority_targeted(true)
        set_selected(true)
    focus_changed.emit(focus_target)
    queue_redraw()


func clear_focus_target() -> void:
    set_focus_target(null)


func get_focus_target() -> GreedEnemy:
    if focus_target != null and is_instance_valid(focus_target):
        return focus_target
    return null


func is_point_inside(position_value: Vector2) -> bool:
    return global_position.distance_to(position_value) <= 21.0


func upgrade() -> void:
    level += 1
    max_health += 1 if level % 3 == 0 else 0
    if level % 3 == 0:
        health = mini(max_health, health + 1)
        health_changed.emit(health, max_health)
    queue_redraw()


func get_display_name(locale_code: String) -> String:
    return String(config.get("name_zh", "主植物")) if locale_code == "zh_CN" else String(config.get("name_en", "Main Plant"))


func get_sustained_dps() -> float:
    var projectile_count: int = int(config.get("projectile_count", 1))
    return _effective_damage(false) * float(projectile_count) / maxf(0.08, _effective_interval())


func _find_target() -> GreedEnemy:
    var effective_range: float = float(config.get("range", 250.0))
    if blessing_system != null:
        effective_range *= blessing_system.get_range_multiplier()
    if rescue_active:
        effective_range *= 1.6

    var priority: GreedEnemy = get_focus_target()
    if priority != null and global_position.distance_to(priority.global_position) <= effective_range:
        return priority

    var best: GreedEnemy = null
    var best_distance: float = INF
    for node: Node in get_tree().get_nodes_in_group("greed_enemies"):
        var enemy: GreedEnemy = node as GreedEnemy
        if enemy == null or not is_instance_valid(enemy):
            continue
        var distance_value: float = global_position.distance_to(enemy.global_position)
        if distance_value <= effective_range and distance_value < best_distance:
            best = enemy
            best_distance = distance_value
    return best


func _attack(target_enemy: GreedEnemy) -> void:
    if target_enemy == null or not is_instance_valid(target_enemy):
        return
    var critical: bool = blessing_system != null and blessing_system.roll_critical()
    var damage_value: float = _effective_damage(critical)
    target_enemy.take_damage(damage_value, critical)
    target_enemy.apply_knockback(global_position, 70.0 if critical else 38.0)
    _shot_target_local = to_local(target_enemy.global_position)
    _shot_time = 0.10
    fired.emit(self, target_enemy, critical, damage_value)


func _effective_damage(critical: bool) -> float:
    var result: float = float(config.get("damage", 18.0))
    result *= 1.0 + float(level - 1) * 0.28
    result *= fury_multiplier
    if blessing_system != null:
        result *= blessing_system.get_damage_multiplier()
    if critical:
        result *= BlessingSystem.CRITICAL_DAMAGE_MULTIPLIER
    return result


func _effective_interval() -> float:
    var result: float = float(config.get("interval", 0.42))
    result *= pow(0.91, float(level - 1))
    if blessing_system != null:
        result *= blessing_system.get_attack_interval_multiplier()
    if rescue_active:
        result *= 0.68
    return maxf(0.07, result)


func _clamp_to_arena(position_value: Vector2) -> Vector2:
    return Vector2(
        clampf(position_value.x, ARENA_RECT.position.x, ARENA_RECT.end.x),
        clampf(position_value.y, ARENA_RECT.position.y, ARENA_RECT.end.y)
    )


func _draw() -> void:
    var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.04
    var body_color: Color = Color.WHITE if _hit_flash > 0.0 else Color(String(config.get("color_hex", "8fe45f")))

    if selected:
        draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 28, Color("ffe071"), 2.0)
        draw_arc(Vector2.ZERO, 24.0, -PI * 0.25, PI * 0.25, 8, Color(1.0, 0.88, 0.35, 0.45), 1.0)
    if has_move_target:
        var local_target: Vector2 = to_local(move_target)
        draw_line(Vector2.ZERO, local_target, Color(0.94, 0.82, 0.36, 0.36), 1.0)
        draw_arc(local_target, 6.0, 0.0, TAU, 12, Color("ffe071"), 1.0)
    if get_focus_target() != null:
        draw_line(Vector2.ZERO, to_local(focus_target.global_position), Color(1.0, 0.36, 0.28, 0.42), 1.0)

    draw_circle(Vector2.ZERO, 17.0 * pulse, Color(0.08, 0.18, 0.11, 0.82))
    draw_circle(Vector2.ZERO, 12.0 * pulse, body_color)
    draw_rect(Rect2(-4.0, -7.0, 3.0, 3.0), Color("173026"))
    draw_rect(Rect2(2.0, -7.0, 3.0, 3.0), Color("173026"))
    draw_line(Vector2(-7.0, 9.0), Vector2(-13.0, 15.0), body_color.darkened(0.35), 3.0)
    draw_line(Vector2(7.0, 9.0), Vector2(13.0, 15.0), body_color.darkened(0.35), 3.0)
    for marker: int in range(mini(level, 8)):
        draw_rect(Rect2(-14.0 + float(marker) * 4.0, 18.0, 3.0, 2.0), Color("ffe071"))
    if _shot_time > 0.0:
        draw_line(Vector2.ZERO, _shot_target_local, Color(0.75, 1.0, 0.48, 0.88), 3.0)
        draw_circle(_shot_target_local, 4.0, Color("fff2a0"))
    if invulnerability_time > 0.0:
        draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 24, Color(0.82, 0.94, 1.0, 0.72), 2.0)