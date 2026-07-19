extends CanvasLayer
class_name GreedCombatFeedback

const MAX_DAMAGE_NUMBERS: int = 48
const NORMAL_NUMBER_LIFETIME: float = 0.55
const CRITICAL_NUMBER_LIFETIME: float = 0.72
const HIT_STOP_TIME_SCALE: float = 0.08

var _entries: Array[Dictionary] = []
var _hit_stop_end_msec: int = 0
var _restore_time_scale: float = 1.0


func _ready() -> void:
    layer = 4
    process_mode = Node.PROCESS_MODE_ALWAYS


func spawn_damage(position_value: Vector2, damage: float, critical: bool) -> void:
    var label: Label = _acquire_label()
    label.text = ("CRIT %d" if critical else "%d") % int(round(damage))
    label.position = position_value + Vector2(-18.0 if critical else -10.0, -20.0)
    label.size = Vector2(72.0 if critical else 44.0, 22.0)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 16 if critical else 12)
    label.add_theme_color_override("font_color", Color("ffe071") if critical else Color("f4f0d1"))
    label.modulate = Color.WHITE
    label.visible = true
    label.z_index = 20

    _entries.append({
        "label": label,
        "velocity": Vector2(0.0, -34.0 if critical else -24.0),
        "remaining": CRITICAL_NUMBER_LIFETIME if critical else NORMAL_NUMBER_LIFETIME,
        "maximum": CRITICAL_NUMBER_LIFETIME if critical else NORMAL_NUMBER_LIFETIME,
    })


func request_hit_stop(duration_seconds: float) -> void:
    if duration_seconds <= 0.0:
        return
    var now: int = Time.get_ticks_msec()
    if not is_hit_stop_active():
        _restore_time_scale = maxf(0.01, Engine.time_scale)
        Engine.time_scale = minf(_restore_time_scale, HIT_STOP_TIME_SCALE)
    _hit_stop_end_msec = maxi(_hit_stop_end_msec, now + int(round(duration_seconds * 1000.0)))


func is_hit_stop_active() -> bool:
    return _hit_stop_end_msec > Time.get_ticks_msec()


func cancel_hit_stop() -> void:
    if _hit_stop_end_msec <= 0:
        return
    Engine.time_scale = _restore_time_scale
    _hit_stop_end_msec = 0


func get_active_number_count() -> int:
    return _entries.size()


func _process(delta: float) -> void:
    if _hit_stop_end_msec > 0 and Time.get_ticks_msec() >= _hit_stop_end_msec:
        cancel_hit_stop()

    var unscaled_delta: float = delta / maxf(0.05, Engine.time_scale)
    for index: int in range(_entries.size() - 1, -1, -1):
        var entry: Dictionary = _entries[index]
        var label: Label = entry["label"] as Label
        var remaining: float = float(entry["remaining"]) - unscaled_delta
        var maximum: float = maxf(0.01, float(entry["maximum"]))
        if label == null or remaining <= 0.0:
            if label != null:
                label.visible = false
            _entries.remove_at(index)
            continue
        label.position += Vector2(entry["velocity"]) * unscaled_delta
        label.modulate.a = clampf(remaining / maximum, 0.0, 1.0)
        entry["remaining"] = remaining
        _entries[index] = entry


func _acquire_label() -> Label:
    if _entries.size() >= MAX_DAMAGE_NUMBERS:
        var recycled: Dictionary = _entries.pop_front()
        var recycled_label: Label = recycled["label"] as Label
        if recycled_label != null:
            return recycled_label

    var label: Label = Label.new()
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)
    return label


func _exit_tree() -> void:
    cancel_hit_stop()
