extends Node2D
class_name ProjectilePool

@export_range(0, 512, 1) var initial_capacity: int = 32

var _available: Array[SproutProjectile] = []
var _active_count: int = 0


func _ready() -> void:
    for _index: int in range(initial_capacity):
        _available.append(_create_projectile())


func launch(
        start_position: Vector2,
        target: SproutEnemy,
        damage: float,
        speed: float,
        color: Color,
        projectile_size: float = 4.0,
        splash_radius: float = 0.0,
        status_effect: StatusEffectData = null,
        enemy_registry: EnemyRegistry = null
) -> SproutProjectile:
    var projectile: SproutProjectile
    if _available.is_empty():
        projectile = _create_projectile()
    else:
        projectile = _available.pop_back()
    _active_count += 1
    projectile.launch(
        start_position,
        target,
        damage,
        speed,
        color,
        projectile_size,
        splash_radius,
        status_effect,
        enemy_registry
    )
    return projectile


func get_active_count() -> int:
    return _active_count


func get_capacity() -> int:
    return get_child_count()


func _create_projectile() -> SproutProjectile:
    var projectile: SproutProjectile = SproutProjectile.new()
    projectile.name = "PooledProjectile"
    add_child(projectile)
    projectile.recycle_requested.connect(_release)
    projectile.reset()
    return projectile


func _release(projectile: SproutProjectile) -> void:
    if projectile == null or _available.has(projectile):
        return
    projectile.reset()
    _active_count = maxi(0, _active_count - 1)
    _available.append(projectile)
