extends Node2D
class_name GreedEnemy

@export var render_with_sprite: bool = false

signal damaged(enemy: GreedEnemy, final_damage: float, critical: bool)
signal defeated(enemy: GreedEnemy, coin_reward: int, elite: bool)
signal core_contact(enemy: GreedEnemy, damage: int)
signal summon_requested(position_value: Vector2)

var target: GreedCore
var max_health: float = 30.0
var health: float = 30.0
var move_speed: float = 48.0
var contact_damage: int = 1
var coin_reward: int = 1
var elite: bool = false
var boss: bool = false
var priority_targeted: bool = false
var body_color: Color = Color("dd6d63")
var body_size: float = 12.0
var survivor_variant: int = 0
var survivor_combat: bool = false
var biome_enemy: int = 0
var _skill_timer: float = 3.5
var _warning_left: float = 0.0
var _warning_position: Vector2 = Vector2.ZERO
var _warning_radius: float = 0.0
var _warning_sprite: Sprite2D
var _summoned: bool = false
var _behavior_clock: float = 0.0

var _contact_cooldown: float = 0.0
var _flash_time: float = 0.0
var _squash_time: float = 0.0
var _slow_time: float = 0.0
var _slow_multiplier: float = 1.0
var _knock_velocity: Vector2 = Vector2.ZERO
var _finished: bool = false
var _spatial_index: GreedEnemySpatialIndex


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
    survivor_variant = int(config.get("variant", 0))
    survivor_combat = bool(config.get("survivor_combat", false))
    biome_enemy = clampi(int(config.get("biome_enemy", 0)), 0, 3)
    if survivor_variant == 5:
        body_size = 8.0
    if survivor_variant == 1:
        body_color = Color("b98ce0")
    elif survivor_variant == 2:
        body_color = Color("8da761")
    _behavior_clock = 0.0
    priority_targeted = false
    _spatial_index = get_tree().get_first_node_in_group("greed_enemy_spatial_index") as GreedEnemySpatialIndex
    _slow_time = 0.0
    _slow_multiplier = 1.0
    add_to_group("greed_enemies")
    if _spatial_index != null:
        _spatial_index.invalidate_combat()
    queue_redraw()


func _process(delta: float) -> void:
    if _finished:
        return
    var was_flashing: bool = _flash_time > 0.0
    var was_squashed: bool = _squash_time > 0.0
    var was_slowed: bool = _slow_time > 0.0
    _contact_cooldown = maxf(0.0, _contact_cooldown - delta)
    _flash_time = maxf(0.0, _flash_time - delta)
    _squash_time = maxf(0.0, _squash_time - delta)
    _slow_time = maxf(0.0, _slow_time - delta)
    if _slow_time <= 0.0:
        _slow_multiplier = 1.0
    _knock_velocity = _knock_velocity.move_toward(Vector2.ZERO, 420.0 * delta)
    global_position += _knock_velocity * delta
    if was_flashing != (_flash_time > 0.0) or was_squashed != (_squash_time > 0.0) or was_slowed != (_slow_time > 0.0):
        queue_redraw()

    if target == null or not is_instance_valid(target) or target.health <= 0:
        return

    if survivor_combat and (boss or survivor_variant == 3):
        _update_skill(delta)
        if _finished or target.health <= 0:
            return
    var to_core: Vector2 = target.global_position - global_position
    var distance_value: float = to_core.length()
    if distance_value > 1.0:
        var separation: Vector2 = _separation_force()
        var direction: Vector2 = (to_core.normalized() + separation * 0.55).normalized()
        _behavior_clock += delta
        var movement_factor: float = 1.0
        if survivor_variant == 1:
            # Alternating visible anticipation and a short acceleration burst.
            var cycle: float = fmod(_behavior_clock, 3.4)
            movement_factor = 0.30 if cycle < 0.55 else (1.65 if cycle < 1.05 else 1.0)
        elif survivor_variant == 2:
            movement_factor = 0.85
        if boss and get_health_ratio() < 0.5:
            movement_factor *= 1.25
        if survivor_variant == 3 and distance_value < 130.0:
            direction = -direction if distance_value < 85.0 else Vector2.ZERO
        global_position += direction * move_speed * _slow_multiplier * movement_factor * delta

    if distance_value <= body_size * 0.55 + 13.0 and _contact_cooldown <= 0.0:
        _contact_cooldown = 0.85
        core_contact.emit(self, contact_damage)
        _knock_velocity = -to_core.normalized() * 150.0
        _squash_time = 0.12
        queue_redraw()


func take_damage(amount: float, critical: bool = false) -> float:
    if _finished or amount <= 0.0:
        return 0.0
    var final_damage: float = minf(health, maxf(1.0, amount))
    health -= final_damage
    _flash_time = 0.08
    _squash_time = 0.09
    damaged.emit(self, final_damage, critical)
    if health <= 0.0:
        _die()
    queue_redraw()
    return final_damage


func apply_slow(multiplier: float, duration: float) -> void:
    if _finished or duration <= 0.0:
        return
    _slow_multiplier = minf(_slow_multiplier, clampf(multiplier, 0.2, 1.0))
    _slow_time = maxf(_slow_time, duration)
    queue_redraw()


func apply_knockback(origin: Vector2, force: float) -> void:
    var direction: Vector2 = (global_position - origin).normalized()
    _knock_velocity += direction * force


func set_priority_targeted(value: bool) -> void:
    priority_targeted = value
    queue_redraw()


func is_point_inside(position_value: Vector2) -> bool:
    return global_position.distance_to(position_value) <= body_size * 0.65 + 8.0


func get_health_ratio() -> float:
    return clampf(health / maxf(1.0, max_health), 0.0, 1.0)


func _die() -> void:
    if _finished:
        return
    _finished = true
    if is_instance_valid(_warning_sprite):
        _warning_sprite.queue_free()
    priority_targeted = false
    defeated.emit(self, coin_reward, elite or boss)
    queue_free()


func _separation_force() -> Vector2:
    var result: Vector2 = Vector2.ZERO
    var neighbors: Array[GreedEnemy] = []
    if _spatial_index != null and is_instance_valid(_spatial_index):
        neighbors = _spatial_index.query_radius(global_position, 32.0)
    else:
        # Standalone enemy tests and legacy scenes have no spatial service.
        for node: Node in get_tree().get_nodes_in_group("greed_enemies"):
            var other_enemy: GreedEnemy = node as GreedEnemy
            if other_enemy != null and is_instance_valid(other_enemy):
                neighbors.append(other_enemy)
    for other: GreedEnemy in neighbors:
        if other == self or other.is_queued_for_deletion():
            continue
        var offset: Vector2 = global_position - other.global_position
        var distance_value: float = offset.length()
        if distance_value > 0.1 and distance_value < 26.0:
            result += offset.normalized() * (26.0 - distance_value) / 26.0
    return result


func _draw() -> void:
    if render_with_sprite:
        return
    var scale_y: float = 0.72 if _squash_time > 0.0 else 1.0
    var scale_x: float = 1.28 if _squash_time > 0.0 else 1.0
    var color_value: Color = Color.WHITE if _flash_time > 0.0 else body_color
    if _slow_time > 0.0:
        color_value = color_value.lerp(Color("86ddff"), 0.32)
    var size_value: Vector2 = Vector2(body_size * scale_x, body_size * scale_y)
    var half: Vector2 = size_value * 0.5
    draw_rect(Rect2(-half - Vector2(2.0, 2.0), size_value + Vector2(4.0, 4.0)), Color("3a2630"))
    draw_rect(Rect2(-half, size_value), color_value)
    draw_rect(Rect2(-half.x + 3.0, -3.0, 3.0, 3.0), Color("241a24"))
    draw_rect(Rect2(half.x - 6.0, -3.0, 3.0, 3.0), Color("241a24"))
    if elite or boss:
        draw_arc(Vector2.ZERO, body_size * 0.72, 0.0, TAU, 20, Color(1.0, 0.82, 0.32, 0.66), 2.0)
    if priority_targeted:
        var reticle_radius: float = body_size * 0.82 + 7.0
        draw_arc(Vector2.ZERO, reticle_radius, 0.0, TAU, 28, Color("ff6b58"), 2.0)
        for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
            var direction: Vector2 = Vector2.from_angle(angle)
            draw_line(direction * (reticle_radius - 4.0), direction * (reticle_radius + 5.0), Color("ffd2c9"), 2.0)
    var bar_width: float = 42.0 if boss else (26.0 if elite else 18.0)
    draw_rect(Rect2(-bar_width * 0.5, -half.y - 8.0, bar_width, 3.0), Color("201824"))
    draw_rect(Rect2(-bar_width * 0.5, -half.y - 8.0, bar_width * get_health_ratio(), 3.0), Color("f16f67"))

# A locked ground target gives the player a visible opportunity to dodge.
func _update_skill(delta: float) -> void:
    if boss and not _summoned and get_health_ratio() <= 0.5:
        _summoned = true
        summon_requested.emit(global_position)
    if _warning_left > 0.0:
        _warning_left = maxf(0.0, _warning_left - delta)
        if is_instance_valid(_warning_sprite):
            _warning_sprite.modulate.a = 0.35 + 0.55 * (1.0 - _warning_left / 0.9)
        if _warning_left <= 0.0:
            if is_instance_valid(_warning_sprite):
                _warning_sprite.hide()
            if target.global_position.distance_to(_warning_position) <= _warning_radius:
                core_contact.emit(self, 2 if boss else 1)
            _skill_timer = 2.8 if boss and get_health_ratio() <= 0.5 else (4.2 if boss else 5.0)
        return
    _skill_timer -= delta
    if _skill_timer > 0.0 or global_position.distance_to(target.global_position) > 250.0:
        return
    _warning_left = 0.9
    _warning_position = target.global_position
    _warning_radius = 43.0 if boss else 25.0
    if not is_instance_valid(_warning_sprite):
        _warning_sprite = Sprite2D.new()
        _warning_sprite.texture = PixelArtAssets.blessing_icon(&"mutation_spore")
        _warning_sprite.z_index = 2
        add_child(_warning_sprite)
        _warning_sprite.top_level = true
    _warning_sprite.global_position = _warning_position
    _warning_sprite.scale = Vector2.ONE * (_warning_radius * 2.0 / 56.0)
    _warning_sprite.modulate = Color(1.0, 0.55, 0.55, 0.35)
    _warning_sprite.show()
