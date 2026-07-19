extends "res://scripts/greed/greed_game.gd"


func _complete_wave() -> void:
    if not wave_active:
        return
    if core != null and is_instance_valid(core):
        var recovery: int = 2 if wave_index == 4 or wave_index == 8 else 1
        core.heal(recovery)
    super._complete_wave()