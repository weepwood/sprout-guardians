extends Resource
class_name WaveData

@export var id: StringName = &"wave_01"
@export var display_name: String = "Wave 1"
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
