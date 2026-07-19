extends Node
class_name CombatRewardSystem

signal combo_changed(combo: int, tier: int, time_remaining: float)
signal chest_progress_changed(progress: int, target: int)
signal chest_ready(pending_chests: int)

@export_range(3, 100, 1) var chest_target: int = 12
@export_range(0.5, 20.0, 0.1) var combo_window: float = 3.2

var combo: int = 0
var combo_time_remaining: float = 0.0
var chest_progress: int = 0
var pending_chests: int = 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE


func setup(target: int = 12, window: float = 3.2) -> void:
    chest_target = maxi(3, target)
    combo_window = maxf(0.5, window)
    reset_run()


func reset_run() -> void:
    combo = 0
    combo_time_remaining = 0.0
    chest_progress = 0
    pending_chests = 0
    combo_changed.emit(combo, get_combo_tier(), combo_time_remaining)
    chest_progress_changed.emit(chest_progress, chest_target)


func _process(delta: float) -> void:
    if combo <= 0 or combo_time_remaining <= 0.0:
        return
    var speed: float = maxf(0.01, Engine.time_scale)
    combo_time_remaining = maxf(0.0, combo_time_remaining - delta / speed)
    if combo_time_remaining <= 0.0:
        combo = 0
    combo_changed.emit(combo, get_combo_tier(), combo_time_remaining)


func register_kill(is_elite: bool = false) -> void:
    combo += 1
    combo_time_remaining = combo_window
    var gain: int = 4 if is_elite else 1
    if combo % 5 == 0:
        gain += 1
    _add_chest_progress(gain)
    combo_changed.emit(combo, get_combo_tier(), combo_time_remaining)


func register_wave_clear() -> void:
    _add_chest_progress(3)


func register_escape() -> void:
    combo = 0
    combo_time_remaining = 0.0
    combo_changed.emit(combo, get_combo_tier(), combo_time_remaining)


func get_combo_tier() -> int:
    if combo >= 30:
        return 4
    if combo >= 15:
        return 3
    if combo >= 8:
        return 2
    if combo >= 3:
        return 1
    return 0


func get_combo_reward_multiplier() -> float:
    return 1.0 + float(get_combo_tier()) * 0.08


func consume_chest() -> bool:
    if pending_chests <= 0:
        return false
    pending_chests -= 1
    return true


func _add_chest_progress(amount: int) -> void:
    chest_progress += maxi(0, amount)
    while chest_progress >= chest_target:
        chest_progress -= chest_target
        pending_chests += 1
    chest_progress_changed.emit(chest_progress, chest_target)
    if pending_chests > 0:
        chest_ready.emit(pending_chests)