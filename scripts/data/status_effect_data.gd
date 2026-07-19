extends Resource
class_name StatusEffectData

enum StackMode {
    REPLACE,
    REFRESH,
    STACK,
}

@export var id: StringName = &"slow"
@export var display_name: String = "Slow"
@export var duration: float = 2.0
@export var tick_interval: float = 0.0
@export var damage_per_tick: float = 0.0
@export_range(0.05, 2.0, 0.05) var speed_multiplier: float = 1.0
@export var stack_mode: StackMode = StackMode.REFRESH
@export_range(1, 99, 1) var max_stacks: int = 1
