extends Node2D
class_name GreedPlant

signal fired(plant: GreedPlant, target: GreedEnemy, critical: bool, damage: float)

var core: GreedCore
var blessing_system: BlessingSystem
var config: Dictionary = {}
var orbit_index: int = 0
var orbit_radius: float = 44.0
var orbit_speed: float = 0.72
var level: int = 1
var fury_multiplier: float = 1.0
var rescue_active: bool = false

var _cooldown: float = 0.0
var _orbit_phase: float = 0.0
var _shot_time: float = 0.0
var _shot_target_local: Vector2 = Vector2.ZERO


func configure(
        core_value: GreedCore,
        plant_config: Dictionary,
        index: int,
        blessings: BlessingSystem = null
) -> void:
    core = core_value
    config = plant_config.duplicate(true)
    orbit_index = index
    blessing_system = blessings
    orbit_radius = 42.0 + float(index % 2) * 18.0
    orbit_speed = 0.66 + float(index) * 0.07
    _orbit_phase = TAU * float(index) / 3.0
    _cooldown = 0.12 + float(index) * 0.06
    add_to_group("greed_plants")
    queue_redraw()


func _process(delta: float) -> void:
    if core == null or not is_instance_valid(core):
        return
    _orbit_phase += delta * orbit_speed
    var target_position: Vector2 = core.global_position + Vector2.from_angle(_orbit_phase + float(orbit_index) * 2.05) * orbit_radius
    global_position = global_position.lerp(target_position, clampf(delta * 7.5, 0.0, 1.0))

    _cooldown -= delta
    _shot_time = maxf(0.0, _shot_time - delta)
    if _cooldown <= 0.0:
        var target_enemy: GreedEnemy = _find_target()
        if target_enemy != null:
            _attack(target_enemy)
            _cooldown = _effective_interval()
        else:
            _cooldown = 0.08
    queue_redraw()


func upgrade() -> void:
    level += 1
    orbit_radius = minf(86.0, orbit_radius + 3.0)
    queue_redraw()


func get_display_name(locale_code: String) -> String:
    return String(config.get("name_zh", "植物")) if locale_code == "zh_CN" else String(config.get("name_en", "Plant"))


func get_sustained_dps() -> float:
    var projectile_count: int = int(config.get("projectile_count", 1))
    return _effective_damage(false) * float(projectile_count) / maxf(0.08, _effective_interval())


func _find_target() -> GreedEnemy:
    var best: GreedEnemy = null
    var best_distance: float = INF
    var effective_range: float = float(config.get("range", 220.0))
    if blessing_system != null:
        effective_range *= blessing_system.get_range_multiplier()
    if rescue_active:
        effective_range *= 1.6

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
    var projectile_count: int = int(config.get("projectile_count", 1))
    var splash_radius: float = float(config.get("splash_radius", 0.0))
    var slow_ratio: float = float(config.get("slow_ratio", 0.0))

    for shot_index: int in range(projectile_count):
        var target_for_shot: GreedEnemy = target_enemy if shot_index == 0 else _alternate_target(target_enemy)
        if target_for_shot == null:
            target_for_shot = target_enemy
        if splash_radius > 0.0:
            for node: Node in get_tree().get_nodes_in_group("greed_enemies"):
                var splash_enemy: GreedEnemy = node as GreedEnemy
                if splash_enemy == null or not is_instance_valid(splash_enemy):
                    continue
                if splash_enemy.global_position.distance_to(target_for_shot.global_position) <= splash_radius:
                    splash_enemy.take_damage(damage_value, critical)
                    splash_enemy.apply_knockback(global_position, 42.0)
        else:
            target_for_shot.take_damage(damage_value, critical)
            target_for_shot.apply_knockback(global_position, 58.0 if critical else 32.0)

        if slow_ratio > 0.0 and is_instance_valid(target_for_shot):
            target_for_shot.apply_slow(1.0 - slow_ratio, 1.6)

    _shot_target_local = to_local(target_enemy.global_position)
    _shot_time = 0.09
    fired.emit(self, target_enemy, critical, damage_value)


func _alternate_target(primary: GreedEnemy) -> GreedEnemy:
    var best: GreedEnemy = null
    var best_distance: float = INF
    for node: Node in get_tree().get_nodes_in_group("greed_enemies"):
        var enemy: GreedEnemy = node as GreedEnemy
        if enemy == null or enemy == primary or not is_instance_valid(enemy):
            continue
        var distance_value: float = global_position.distance_to(enemy.global_position)
        if distance_value < best_distance:
            best = enemy
            best_distance = distance_value
    return best


func _effective_damage(critical: bool) -> float:
    var result: float = float(config.get("damage", 10.0))
    result *= 1.0 + float(level - 1) * 0.24
    result *= fury_multiplier
    if blessing_system != null:
        result *= blessing_system.get_damage_multiplier()
    if critical:
        result *= BlessingSystem.CRITICAL_DAMAGE_MULTIPLIER
    return result


func _effective_interval() -> float:
    var result: float = float(config.get("interval", 0.6))
    result *= pow(0.92, float(level - 1))
    if blessing_system != null:
        result *= blessing_system.get_attack_interval_multiplier()
    if rescue_active:
        result *= 0.68
    return maxf(0.08, result)


func _draw() -> void:
    var body_color: Color = Color(String(config.get("color_hex", "8fe45f")))
    var base_color: Color = body_color.darkened(0.35)
    draw_circle(Vector2.ZERO, 11.0 + float(level - 1) * 0.7, Color(0.06, 0.12, 0.09, 0.72))
    draw_circle(Vector2.ZERO, 8.0 + float(level - 1) * 0.5, body_color)
    draw_rect(Rect2(-3.0, -4.0, 2.0, 2.0), Color("173026"))
    draw_rect(Rect2(2.0, -4.0, 2.0, 2.0), Color("173026"))
    draw_line(Vector2(-5.0, 7.0), Vector2(-9.0, 12.0), base_color, 2.0)
    draw_line(Vector2(5.0, 7.0), Vector2(9.0, 12.0), base_color, 2.0)
    for marker: int in range(level):
        draw_rect(Rect2(-6.0 + float(marker) * 4.0, 12.0, 3.0, 2.0), Color("ffe071"))
    if _shot_time > 0.0:
        var beam_color: Color = body_color
        beam_color.a = 0.78
        draw_line(Vector2.ZERO, _shot_target_local, beam_color, 2.0)
        draw_circle(_shot_target_local, 3.0, Color("fff2a0"))