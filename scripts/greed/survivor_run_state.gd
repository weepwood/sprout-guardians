extends Node
class_name SurvivorRunState

## The first extracted part of the survivor-mode state machine.
## This node mirrors the legacy flags while they are migrated subsystem by
## subsystem. No global SceneTree.pause or Engine.time_scale side effects.

signal phase_changed(previous: int, current: int)

enum Phase { READY, RUNNING, REWARD, PAUSED, VICTORY, DEFEAT }

var phase: Phase = Phase.READY


func start_run() -> void:
    if phase == Phase.READY:
        _set_phase(Phase.RUNNING)


func open_reward() -> bool:
    if phase != Phase.RUNNING:
        return false
    _set_phase(Phase.REWARD)
    return true


func close_reward() -> bool:
    if phase != Phase.REWARD:
        return false
    _set_phase(Phase.RUNNING)
    return true


func toggle_pause() -> bool:
    if phase == Phase.RUNNING:
        _set_phase(Phase.PAUSED)
        return true
    if phase == Phase.PAUSED:
        _set_phase(Phase.RUNNING)
        return true
    return false


func finish(victory: bool) -> void:
    if phase == Phase.VICTORY or phase == Phase.DEFEAT:
        return
    _set_phase(Phase.VICTORY if victory else Phase.DEFEAT)


func is_playing() -> bool:
    return phase == Phase.RUNNING


func _set_phase(next_phase: Phase) -> void:
    if phase == next_phase:
        return
    var previous: Phase = phase
    phase = next_phase
    phase_changed.emit(int(previous), int(phase))
