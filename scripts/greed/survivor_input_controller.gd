extends Node
class_name SurvivorInputController

# Classic survivor controls: the player only steers the hero. No click-to-move,
# manual aim, or dash. ui_* also supports the default gamepad left stick/D-pad.
var _debug_input_enabled: bool = false
var _debug_direction: Vector2 = Vector2.ZERO


func movement_direction() -> Vector2:
    if _debug_input_enabled:
        return _debug_direction.limit_length(1.0)

    var horizontal: float = float(int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)))
    var vertical: float = float(int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W)))
    var keyboard_vector: Vector2 = Vector2(horizontal, vertical)
    var mapped_vector: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    var combined: Vector2 = keyboard_vector + mapped_vector
    return combined.limit_length(1.0)


func set_test_direction(value: Vector2) -> void:
    _debug_input_enabled = true
    _debug_direction = value


func clear_test_direction() -> void:
    _debug_input_enabled = false
    _debug_direction = Vector2.ZERO
