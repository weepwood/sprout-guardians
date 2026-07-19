extends Resource
class_name WaveData

@export var id: StringName = &"wave_01"
@export var display_name: String = "Wave 1"
@export_multiline var tactical_hint: String = ""
@export var spawn_groups: Array[Resource] = []
@export var clear_reward: int = 35
@export var early_start_bonus: int = 0


func get_spawn_groups() -> Array[SpawnGroupData]:
    var typed_groups: Array[SpawnGroupData] = []
    for resource: Resource in spawn_groups:
        var group: SpawnGroupData = resource as SpawnGroupData
        if group != null:
            typed_groups.append(group)
    return typed_groups


func get_preview_text() -> String:
    var parts: PackedStringArray = PackedStringArray()
    for group: SpawnGroupData in get_spawn_groups():
        if group.enemy == null or group.count <= 0:
            continue
        parts.append("%s x%d" % [group.enemy.display_name, group.count])
    return " · ".join(parts)


func get_total_enemy_count() -> int:
    var total: int = 0
    for group: SpawnGroupData in get_spawn_groups():
        total += maxi(0, group.count)
    return total
