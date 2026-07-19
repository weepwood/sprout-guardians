extends Resource
class_name LevelData

@export var id: StringName = &"morning_forest"
@export var display_name: String = "Morning Forest"
@export_multiline var description: String = "Protect the young sprout from the first mist invasion."

@export_group("Starting state")
@export var starting_coins: int = 220
@export var base_health: int = 10

@export_group("Layout")
@export var path_points: PackedVector2Array = PackedVector2Array()
@export var build_slots: PackedVector2Array = PackedVector2Array()

@export_group("Content")
@export var available_towers: Array[Resource] = []
@export var waves: Array[Resource] = []


func get_tower(index: int) -> TowerData:
    if index < 0 or index >= available_towers.size():
        return null
    return available_towers[index] as TowerData


func get_wave(index: int) -> WaveData:
    if index < 0 or index >= waves.size():
        return null
    return waves[index] as WaveData


func get_wave_count() -> int:
    return waves.size()


func get_enemy_path(_path_index: int = 0) -> PackedVector2Array:
    return path_points
