extends Node
class_name GreedEnemySpatialIndex

# Shared, periodically refreshed spatial buckets for the high-density arena.
# Positions are sampled every 100 ms; visual movement stays frame-rate independent.
const CELL_SIZE: float = 64.0
const REBUILD_INTERVAL: float = 0.10

var _cells: Dictionary = {}
var _rebuild_timer: float = 0.0


func _ready() -> void:
    add_to_group("greed_enemy_spatial_index")


func _process(delta: float) -> void:
    _rebuild_timer -= delta
    if _rebuild_timer <= 0.0:
        _rebuild_timer = REBUILD_INTERVAL
        _rebuild_cells()


func query_radius(center: Vector2, radius: float) -> Array[GreedEnemy]:
    var nearby: Array[GreedEnemy] = []
    if radius < 0.0:
        return nearby
    if _cells.is_empty():
        _rebuild_cells()

    var cell_radius: Vector2 = Vector2(radius, radius)
    var minimum: Vector2i = _cell_for(center - cell_radius)
    var maximum: Vector2i = _cell_for(center + cell_radius)
    var radius_squared: float = radius * radius
    for x: int in range(minimum.x, maximum.x + 1):
        for y: int in range(minimum.y, maximum.y + 1):
            var bucket: Array = _cells.get(Vector2i(x, y), []) as Array
            for value: Variant in bucket:
                var enemy: GreedEnemy = value as GreedEnemy
                if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
                    continue
                if enemy.health > 0.0 and center.distance_squared_to(enemy.global_position) <= radius_squared:
                    nearby.append(enemy)
    return nearby


func _rebuild_cells() -> void:
    _cells.clear()
    for node: Node in get_tree().get_nodes_in_group("greed_enemies"):
        var enemy: GreedEnemy = node as GreedEnemy
        if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
            continue
        if enemy.health <= 0.0:
            continue
        var key: Vector2i = _cell_for(enemy.global_position)
        var bucket: Array = _cells.get(key, []) as Array
        bucket.append(enemy)
        _cells[key] = bucket


func _cell_for(position_value: Vector2) -> Vector2i:
    return Vector2i(floori(position_value.x / CELL_SIZE), floori(position_value.y / CELL_SIZE))
