extends Node
class_name SurvivorRunTrace

## Lightweight breadcrumbs to accompany Godot's native user://logs/godot.log.
## No network requests, user identifiers, or gameplay-frame logging.

const LOG_PATH: String = "user://diagnostics/survivor-session.log"
const MAX_LINES: int = 80

var _lines: Array[String] = []


func _ready() -> void:
    if OS.has_feature("web"):
        return
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://diagnostics"))
    note("scene_ready", "engine=%s os=%s" % [Engine.get_version_info().get("string", "unknown"), OS.get_name()])


func note(event_name: String, context: String = "") -> void:
    if OS.has_feature("web"):
        return
    var now: String = Time.get_datetime_string_from_system()
    _lines.append("%s | %s | %s" % [now, event_name, context])
    while _lines.size() > MAX_LINES:
        _lines.pop_front()
    var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string("\n".join(_lines) + "\n")
        file.close()
