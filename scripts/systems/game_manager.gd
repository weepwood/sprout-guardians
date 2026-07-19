extends Node
class_name GameManager

signal pause_changed(paused: bool)
signal speed_changed(multiplier: float)
signal game_finished(victory: bool)

enum State {
    PREPARING,
    RUNNING,
    PAUSED,
    VICTORY,
    DEFEAT,
}

var state: State = State.PREPARING
var game_ended: bool = false
var speed_values: Array[float] = [1.0, 2.0, 3.0]
var speed_index: int = 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS


func reset() -> void:
    game_ended = false
    state = State.PREPARING
    speed_index = 0
    Engine.time_scale = 1.0
    get_tree().paused = false
    pause_changed.emit(false)
    speed_changed.emit(1.0)


func mark_running() -> void:
    if not game_ended and not get_tree().paused:
        state = State.RUNNING


func mark_preparing() -> void:
    if not game_ended and not get_tree().paused:
        state = State.PREPARING


func toggle_pause() -> bool:
    if game_ended:
        return get_tree().paused
    get_tree().paused = not get_tree().paused
    state = State.PAUSED if get_tree().paused else State.RUNNING
    pause_changed.emit(get_tree().paused)
    return get_tree().paused


func cycle_speed() -> float:
    if game_ended:
        return Engine.time_scale
    speed_index = (speed_index + 1) % speed_values.size()
    Engine.time_scale = speed_values[speed_index]
    speed_changed.emit(Engine.time_scale)
    return Engine.time_scale


func finish(victory: bool) -> void:
    if game_ended:
        return
    game_ended = true
    state = State.VICTORY if victory else State.DEFEAT
    get_tree().paused = true
    game_finished.emit(victory)


func restart() -> void:
    Engine.time_scale = 1.0
    get_tree().paused = false
    get_tree().reload_current_scene()
