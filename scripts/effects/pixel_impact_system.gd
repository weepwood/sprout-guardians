extends Node2D
class_name PixelImpactSystem

signal impact_pulse(position: Vector2, strength: float)

@export_range(32, 512, 1) var max_particles: int = 192
@export var effects_enabled: bool = true

var _particles: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _visual_pool: Array[Sprite2D] = []
var _visible_count: int = 0


func _ready() -> void:
    _rng.seed = 0x51A7C0DE
    z_index = 80


func _process(delta: float) -> void:
    if _particles.is_empty():
        return
    for index: int in range(_particles.size() - 1, -1, -1):
        var particle: Dictionary = _particles[index]
        var life: float = float(particle["life"]) - delta
        if life <= 0.0:
            _particles.remove_at(index)
            continue
        var velocity: Vector2 = particle["velocity"] as Vector2
        var drag: float = float(particle["drag"])
        velocity = velocity.move_toward(Vector2.ZERO, drag * delta)
        velocity.y += float(particle["gravity"]) * delta
        particle["position"] = (particle["position"] as Vector2) + velocity * delta
        particle["velocity"] = velocity
        particle["life"] = life
        _particles[index] = particle
    _sync_visuals()


func spawn_hit(position_value: Vector2, color_value: Color, damage: float, critical: bool = false) -> void:
    if not effects_enabled:
        return
    var count: int = 11 if critical else clampi(4 + int(damage / 12.0), 4, 8)
    var speed: float = 155.0 if critical else 95.0
    _spawn_radial(position_value, color_value, count, speed, 0.18 if critical else 0.12, 2.0 if critical else 1.0)
    if critical:
        _spawn_cross(position_value, Color("fff2a0"), 13.0)
        impact_pulse.emit(position_value, 0.65)


func spawn_kill(position_value: Vector2, color_value: Color, body_size: Vector2 = Vector2(12.0, 12.0)) -> void:
    if not effects_enabled:
        return
    var count: int = clampi(int((body_size.x + body_size.y) * 0.8), 12, 30)
    _spawn_radial(position_value, color_value, count, 130.0, 0.28, 2.0)
    _spawn_radial(position_value, Color("d9ff9e"), 6, 75.0, 0.34, 1.0)
    impact_pulse.emit(position_value, 0.42)


func spawn_boss_phase(position_value: Vector2, color_value: Color) -> void:
    if not effects_enabled:
        return
    _spawn_radial(position_value, color_value, 38, 190.0, 0.46, 3.0)
    for radius: float in [12.0, 22.0, 34.0]:
        _spawn_ring(position_value, Color("ffd36a"), radius, 12)
    impact_pulse.emit(position_value, 1.0)


func spawn_reward(position_value: Vector2, rarity_color: Color) -> void:
    if not effects_enabled:
        return
    _spawn_radial(position_value, rarity_color, 28, 120.0, 0.52, 2.0)
    _spawn_cross(position_value, Color("fff4b8"), 22.0)
    impact_pulse.emit(position_value, 0.78)


func get_active_particle_count() -> int:
    return _particles.size()


func clear() -> void:
    _particles.clear()
    _sync_visuals()


func _spawn_radial(
        position_value: Vector2,
        color_value: Color,
        count: int,
        speed: float,
        lifetime: float,
        size_value: float
) -> void:
    for index: int in range(count):
        var angle: float = TAU * float(index) / maxf(1.0, float(count)) + _rng.randf_range(-0.22, 0.22)
        var speed_value: float = speed * _rng.randf_range(0.45, 1.05)
        _push_particle({
            "position": position_value.round(),
            "velocity": Vector2.from_angle(angle) * speed_value,
            "life": lifetime * _rng.randf_range(0.72, 1.18),
            "max_life": lifetime,
            "color": color_value,
            "size": size_value + float(_rng.randi_range(0, 2)),
            "drag": speed * 1.4,
            "gravity": 85.0,
            "tail": _uses_tail(index),
        })


func _spawn_ring(position_value: Vector2, color_value: Color, radius: float, count: int) -> void:
    for index: int in range(count):
        var angle: float = TAU * float(index) / float(count)
        var direction: Vector2 = Vector2.from_angle(angle)
        _push_particle({
            "position": (position_value + direction * radius).round(),
            "velocity": direction * 78.0,
            "life": 0.34,
            "max_life": 0.34,
            "color": color_value,
            "size": 2.0,
            "drag": 96.0,
            "gravity": 0.0,
            "tail": true,
        })


func _spawn_cross(position_value: Vector2, color_value: Color, radius: float) -> void:
    for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
        _push_particle({
            "position": position_value.round(),
            "velocity": direction * radius * 8.0,
            "life": 0.18,
            "max_life": 0.18,
            "color": color_value,
            "size": 3.0,
            "drag": radius * 18.0,
            "gravity": 0.0,
            "tail": true,
        })


func _push_particle(particle: Dictionary) -> void:
    if _particles.size() >= max_particles:
        _particles.pop_front()
    _particles.append(particle)


func _uses_tail(index: int) -> bool:
    return index % 3 == 0


# A pool of authored star sprites replaces the previous draw_rect/draw_line
# calls. Visual lifetime is independent from gameplay hit/damage data.
func _sync_visuals() -> void:
    var active: int = _particles.size()
    while _visual_pool.size() < active:
        var sprite: Sprite2D = Sprite2D.new()
        sprite.name = "ImpactSprite%d" % _visual_pool.size()
        sprite.texture = PixelArtAssets.texture(&"impact_star")
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        sprite.centered = true
        sprite.z_index = 0
        add_child(sprite)
        _visual_pool.append(sprite)
    for index: int in range(active):
        var particle: Dictionary = _particles[index]
        var sprite: Sprite2D = _visual_pool[index]
        var alpha: float = clampf(float(particle["life"]) / maxf(0.001, float(particle["max_life"])), 0.0, 1.0)
        var tint: Color = particle["color"] as Color
        tint.a *= alpha
        sprite.modulate = tint
        sprite.position = particle["position"] as Vector2
        var scale_value: float = maxf(0.035, float(particle["size"]) * 0.047)
        var is_tail: bool = bool(particle["tail"])
        sprite.scale = Vector2(scale_value * (1.35 if is_tail else 1.0), scale_value)
        if is_tail:
            sprite.rotation = (particle["velocity"] as Vector2).angle()
        else:
            sprite.rotation = 0.0
        sprite.visible = true
    for index: int in range(active, _visible_count):
        _visual_pool[index].visible = false
    _visible_count = active
