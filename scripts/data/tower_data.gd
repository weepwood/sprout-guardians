extends Resource
class_name TowerData

enum TargetMode {
    FIRST,
    LAST,
    STRONGEST,
    WEAKEST,
    NEAREST,
}

@export var id: StringName = &"pea_tower"
@export var display_name: String = "Pea Tower"
@export_multiline var description: String = "A reliable single-target plant tower."
@export var tower_scene: PackedScene

@export_group("Economy")
@export var build_cost: int = 75
@export_range(0.0, 1.0, 0.05) var sell_ratio: float = 0.7
@export var upgrade_costs: PackedInt32Array = PackedInt32Array([55, 110])

@export_group("Combat")
@export var damage: float = 12.0
@export var attack_interval: float = 0.65
@export var attack_range: float = 92.0
@export var projectile_speed: float = 260.0
@export var projectile_color: Color = Color("d9ff8c")
@export var target_mode: TargetMode = TargetMode.FIRST
@export var can_attack_ground: bool = true
@export var can_attack_flying: bool = true

@export_group("Upgrades")
@export var max_level: int = 3
@export var damage_multiplier_per_level: float = 1.55
@export var interval_multiplier_per_level: float = 0.82
@export var range_bonus_per_level: float = 8.0


func get_upgrade_cost(current_level: int) -> int:
    var cost_index: int = current_level - 1
    if current_level >= max_level or cost_index < 0 or cost_index >= upgrade_costs.size():
        return -1
    return upgrade_costs[cost_index]


func get_damage_for_level(current_level: int) -> float:
    return damage * pow(damage_multiplier_per_level, maxi(0, current_level - 1))


func get_interval_for_level(current_level: int) -> float:
    return maxf(0.08, attack_interval * pow(interval_multiplier_per_level, maxi(0, current_level - 1)))


func get_range_for_level(current_level: int) -> float:
    return attack_range + range_bonus_per_level * float(maxi(0, current_level - 1))
