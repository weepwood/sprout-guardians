extends Node
class_name AutoBattleDirector

signal auto_changed(enabled: bool)
signal countdown_changed(seconds_remaining: float, waiting: bool)
signal start_requested

@export_range(0.5, 15.0, 0.1) var countdown_duration: float = 2.5

var auto_enabled: bool = false
var waiting: bool = false
var blocked: bool = false
var countdown_remaining: float = 0.0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
    if not auto_enabled or not waiting or blocked:
        return
    countdown_remaining = maxf(0.0, countdown_remaining - delta)
    countdown_changed.emit(countdown_remaining, waiting)
    if countdown_remaining > 0.0:
        return
    waiting = false
    countdown_changed.emit(0.0, false)
    start_requested.emit()


func set_auto_enabled(value: bool, schedule_immediately: bool = true) -> void:
    if auto_enabled == value:
        return
    auto_enabled = value
    if not auto_enabled:
        cancel()
    elif schedule_immediately:
        arm(0.8)
    auto_changed.emit(auto_enabled)


func toggle() -> bool:
    set_auto_enabled(not auto_enabled)
    return auto_enabled


func arm(delay: float = -1.0) -> void:
    if not auto_enabled:
        return
    waiting = true
    countdown_remaining = countdown_duration if delay < 0.0 else maxf(0.0, delay)
    countdown_changed.emit(countdown_remaining, true)


func cancel() -> void:
    waiting = false
    countdown_remaining = 0.0
    countdown_changed.emit(0.0, false)


func set_blocked(value: bool) -> void:
    blocked = value
    countdown_changed.emit(countdown_remaining, waiting)


func is_counting_down() -> bool:
    return auto_enabled and waiting