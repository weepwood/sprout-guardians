extends Node
class_name EnemyRegistry

const CELL_SIZE: float = 96.0
const REBUILD_INTERVAL: float = 0.10

var _enemies: Array[SproutEnemy] = []
var _cells: Dictionary = {}
var _rebuild_cooldown: float = 0.0


func register_enemy(enemy: SproutEnemy) -> void:
    if enemy == null or _enemies.has(enemy):
        return
    _enemies.append(enemy)
    _rebuild_cells()


func unregister_enemy(enemy: SproutEnemy) -> void:
    _enemies.erase(enemy)


func query_radius(center: Vector2, radius: float) -> Array[SproutEnemy]:
    var results: Array[SproutEnemy] = []
    var minimum: Vector2i = _cell_for(center - Vector2(radius, radius))
    var maximum: Vector2i = _cell_for(center + Vector2(radius, radius))
    var radius_squared: float = radius * radius

    for cell_x: int in range(minimum.x, maximum.x + 1):
        for cell_y: int in range(minimum.y, maximum.y + 1):
            var key: Vector2i = Vector2i(cell_x, cell_y)
            if not _cells.has(key):
                continue
            var bucket: Array = _cells[key] as Array
            for value: Variant in bucket:
                var enemy: SproutEnemy = value as SproutEnemy
                if enemy == null or not is_instance_valid(enemy):
                    continue
                if center.distance_squared_to(enemy.global_position) <= radius_squared:
                    results.append(enemy)
    return results


func get_enemy_count() -> int:
    return _enemies.size()


func _process(delta: float) -> void:
    _rebuild_cooldown -= delta
    if _rebuild_cooldown <= 0.0:
        _rebuild_cooldown = REBUILD_INTERVAL
        _rebuild_cells()


func _rebuild_cells() -> void:
    _cells.clear()
    for index: int in range(_enemies.size() - 1, -1, -1):
        var enemy: SproutEnemy = _enemies[index]
        if enemy == null or not is_instance_valid(enemy):
            _enemies.remove_at(index)
            continue
        var key: Vector2i = _cell_for(enemy.global_position)
        var bucket: Array = []
        if _cells.has(key):
            bucket = _cells[key] as Array
        bucket.append(enemy)
        _cells[key] = bucket


func _cell_for(position_value: Vector2) -> Vector2i:
    return Vector2i(
        floori(position_value.x / CELL_SIZE),
        floori(position_value.y / CELL_SIZE)
    )
