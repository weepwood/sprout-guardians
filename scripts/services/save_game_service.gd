extends RefCounted
class_name SaveGameService

signal save_loaded(recovered_from_backup: bool)
signal save_changed

const CURRENT_VERSION: int = 2
const DEFAULT_SAVE_PATH: String = "user://savegame.json"
const DEFAULT_BACKUP_PATH: String = "user://savegame.backup.json"

var save_path: String = DEFAULT_SAVE_PATH
var backup_path: String = DEFAULT_BACKUP_PATH
var data: Dictionary = {}
var recovered_from_backup: bool = false


func load_game() -> Dictionary:
    recovered_from_backup = false
    var loaded: Variant = _read_json(save_path)
    if not (loaded is Dictionary):
        loaded = _read_json(backup_path)
        recovered_from_backup = loaded is Dictionary

    if loaded is Dictionary:
        data = _migrate_and_sanitize(loaded as Dictionary)
    else:
        data = _default_data()

    save_game()
    save_loaded.emit(recovered_from_backup)
    return data.duplicate(true)


func save_game() -> bool:
    if data.is_empty():
        data = _default_data()
    data["schema_version"] = CURRENT_VERSION

    if FileAccess.file_exists(save_path):
        var existing: String = FileAccess.get_file_as_string(save_path)
        if not existing.is_empty():
            _write_text(backup_path, existing)

    var serialized: String = JSON.stringify(data, "  ", false)
    var success: bool = _write_text(save_path, serialized)
    if success:
        save_changed.emit()
    return success


func record_level_result(level_id: StringName, stars: int, remaining_health: int) -> void:
    _ensure_loaded()
    var level_key: String = String(level_id)
    var completed_levels: Dictionary = data.get("completed_levels", {}) as Dictionary
    var previous: Dictionary = completed_levels.get(level_key, {}) as Dictionary
    completed_levels[level_key] = {
        "completed": true,
        "stars": maxi(int(previous.get("stars", 0)), clampi(stars, 1, 3)),
        "best_remaining_health": maxi(int(previous.get("best_remaining_health", 0)), maxi(0, remaining_health)),
    }
    data["completed_levels"] = completed_levels
    unlock_level(level_id)
    save_game()


func unlock_level(level_id: StringName) -> void:
    _ensure_loaded()
    var level_key: String = String(level_id)
    var unlocked: Array = data.get("unlocked_levels", []) as Array
    if not unlocked.has(level_key):
        unlocked.append(level_key)
    data["unlocked_levels"] = unlocked


func get_level_stars(level_id: StringName) -> int:
    _ensure_loaded()
    var completed_levels: Dictionary = data.get("completed_levels", {}) as Dictionary
    var result: Dictionary = completed_levels.get(String(level_id), {}) as Dictionary
    return clampi(int(result.get("stars", 0)), 0, 3)


func is_level_unlocked(level_id: StringName) -> bool:
    _ensure_loaded()
    var unlocked: Array = data.get("unlocked_levels", []) as Array
    return unlocked.has(String(level_id))


func mark_encyclopedia_seen(entry_id: StringName) -> void:
    _ensure_loaded()
    var encyclopedia: Dictionary = data.get("encyclopedia", {}) as Dictionary
    var seen: Array = encyclopedia.get("seen", []) as Array
    var entry_key: String = String(entry_id)
    if not seen.has(entry_key):
        seen.append(entry_key)
    encyclopedia["seen"] = seen
    data["encyclopedia"] = encyclopedia
    save_game()


func reset_progress() -> bool:
    data = _default_data()
    recovered_from_backup = false
    return save_game()


func _ensure_loaded() -> void:
    if data.is_empty():
        load_game()


func _default_data() -> Dictionary:
    return {
        "schema_version": CURRENT_VERSION,
        "completed_levels": {},
        "unlocked_levels": ["morning_forest"],
        "encyclopedia": {"seen": []},
        "statistics": {
            "total_victories": 0,
            "total_defeats": 0,
        },
    }


func _migrate_and_sanitize(source: Dictionary) -> Dictionary:
    var migrated: Dictionary = source.duplicate(true)
    var version: int = int(migrated.get("schema_version", migrated.get("version", 1)))

    if version <= 1:
        var converted_levels: Dictionary = {}
        var old_stars: Dictionary = migrated.get("stars", {}) as Dictionary
        var old_completed: Array = migrated.get("completed_levels", []) as Array
        for level_id: Variant in old_completed:
            var key: String = String(level_id)
            converted_levels[key] = {
                "completed": true,
                "stars": clampi(int(old_stars.get(key, 1)), 1, 3),
                "best_remaining_health": 0,
            }
        migrated["completed_levels"] = converted_levels
        migrated.erase("stars")
        version = 2

    migrated["schema_version"] = CURRENT_VERSION

    var completed_levels: Variant = migrated.get("completed_levels", {})
    if not (completed_levels is Dictionary):
        completed_levels = {}
    var sanitized_levels: Dictionary = {}
    for level_key: Variant in (completed_levels as Dictionary).keys():
        var raw_result: Variant = (completed_levels as Dictionary)[level_key]
        if not (raw_result is Dictionary):
            continue
        var raw: Dictionary = raw_result as Dictionary
        sanitized_levels[String(level_key)] = {
            "completed": bool(raw.get("completed", true)),
            "stars": clampi(int(raw.get("stars", 0)), 0, 3),
            "best_remaining_health": maxi(0, int(raw.get("best_remaining_health", 0))),
        }
    migrated["completed_levels"] = sanitized_levels

    var unlocked_value: Variant = migrated.get("unlocked_levels", ["morning_forest"])
    var unlocked: Array = unlocked_value as Array if unlocked_value is Array else ["morning_forest"]
    if not unlocked.has("morning_forest"):
        unlocked.push_front("morning_forest")
    migrated["unlocked_levels"] = unlocked

    var encyclopedia_value: Variant = migrated.get("encyclopedia", {"seen": []})
    migrated["encyclopedia"] = encyclopedia_value if encyclopedia_value is Dictionary else {"seen": []}
    var statistics_value: Variant = migrated.get("statistics", {})
    migrated["statistics"] = statistics_value if statistics_value is Dictionary else {}
    return migrated


func _read_json(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    var text: String = FileAccess.get_file_as_string(path)
    if text.is_empty():
        return null
    return JSON.parse_string(text)


func _write_text(path: String, text: String) -> bool:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_warning("Unable to write save file %s: %s" % [path, error_string(FileAccess.get_open_error())])
        return false
    file.store_string(text)
    file.flush()
    file.close()
    return true
