extends Resource
class_name EnemyData

@export var id: StringName = &"beetle"
@export var display_name: String = "Beetle"
@export_multiline var description: String = "A basic corrupted forest creature."
@export var enemy_scene: PackedScene

@export_group("Movement")
@export var move_speed: float = 42.0
@export var is_flying: bool = false

@export_group("Survivability")
@export var max_health: float = 42.0
@export var armor: float = 0.0
@export_range(0.0, 1.0, 0.01) var magic_resistance: float = 0.0

@export_group("Rewards and goal")
@export var reward: int = 12
@export var goal_damage: int = 1

@export_group("Boss phases")
@export var is_boss: bool = false
@export var phase_thresholds: PackedFloat32Array = PackedFloat32Array([0.7, 0.4])
@export var phase_speed_multipliers: PackedFloat32Array = PackedFloat32Array([1.15, 1.35])
@export var phase_armor_bonuses: PackedFloat32Array = PackedFloat32Array([2.0, 5.0])
@export var phase_colors: PackedColorArray = PackedColorArray()
@export var phase_pulse_radius: float = 150.0
@export var phase_tower_disable_duration: float = 1.5

@export_group("Presentation")
@export var body_color: Color = Color("86c85a")
@export var body_size: Vector2 = Vector2(12.0, 12.0)
