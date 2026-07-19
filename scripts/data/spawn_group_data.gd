extends Resource
class_name SpawnGroupData

@export var enemy: EnemyData
@export_range(1, 999, 1) var count: int = 5
@export_range(0.05, 30.0, 0.05) var spawn_interval: float = 0.8
@export_range(0.0, 120.0, 0.05) var start_delay: float = 0.0
@export_range(0, 16, 1) var path_index: int = 0
