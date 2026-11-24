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
var _primary_is_trusted: bool = false


func load_game() -> Dictionary:
    recovered_from_backup = false
    var loaded: Variant = _read_json(save_path)
    _primary_is_trusted = loaded is Dictionary
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

    # Never rotate an invalid primary over a valid recovery backup.
    # A successful recovery first restores the primary, then normal rotation resumes.
    if _primary_is_trusted and FileAccess.file_exists(save_path):
        var existing: Variant = _read_json(save_path)
        if existing is Dictionary and not (existing as Dictionary).is_empty():
            _write_text(backup_path, FileAccess.get_file_as_string(save_path))

    var serialized: String = JSON.stringify(data, "  ", false)
    var success: bool = _write_text(save_path, serialized)
    if success:
        _primary_is_trusted = true
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


func record_survivor_result(victory: bool, elapsed_seconds: float, reached_level: int, kills: int, details: Dictionary = {}) -> bool:
    _ensure_loaded()
    var before: Dictionary = data.duplicate(true)
    var statistics: Dictionary = get_survivor_statistics()
    statistics["total_runs"] = int(statistics["total_runs"]) + 1
    if victory:
        statistics["total_victories"] = int(statistics["total_victories"]) + 1
    else:
        statistics["total_defeats"] = int(statistics["total_defeats"]) + 1
    var safe_duration: int = maxi(0, int(floor(elapsed_seconds))) if is_finite(elapsed_seconds) else 0
    statistics["best_survival_seconds"] = maxi(int(statistics["best_survival_seconds"]), safe_duration)
    statistics["best_kills"] = maxi(int(statistics["best_kills"]), maxi(0, kills))
    statistics["best_level"] = maxi(int(statistics["best_level"]), maxi(1, reached_level))
    statistics["last_run"] = {
        "victory": victory,
        "survival_seconds": safe_duration,
        "level": maxi(1, reached_level),
        "kills": maxi(0, kills),
    }
    statistics["last_run"].merge(details, false)
    data["statistics"] = statistics
    var progress: Dictionary = get_survivor_progress()
    progress["seeds"] = mini(999999, int(progress["seeds"]) + floori(float(maxi(0, kills)) / 10.0) + (12 if victory else 0))
    progress["evolutions"] = int(progress["evolutions"]) + maxi(0, int(details.get("evolutions", 0)))
    progress["events"] = int(progress["events"]) + maxi(0, int(details.get("events", 0)))
    if victory and bool(details.get("challenge", false)):
        progress["challenge_wins"] = int(progress["challenge_wins"]) + 1
    data["survivor_progress"] = progress
    if save_game():
        return true
    data = before
    return false


func get_survivor_statistics() -> Dictionary:
    _ensure_loaded()
    var raw: Dictionary = data.get("statistics", {}) as Dictionary
    var result: Dictionary = {
        "total_runs": maxi(0, int(raw.get("total_runs", 0))),
        "total_victories": maxi(0, int(raw.get("total_victories", 0))),
        "total_defeats": maxi(0, int(raw.get("total_defeats", 0))),
        "best_survival_seconds": maxi(0, int(raw.get("best_survival_seconds", 0))),
        "best_kills": maxi(0, int(raw.get("best_kills", 0))),
        "best_level": maxi(1, int(raw.get("best_level", 1))),
    }
    var last: Variant = raw.get("last_run", {})
    result["last_run"] = (last as Dictionary).duplicate(true) if last is Dictionary else {}
    return result


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
    var temporary: String = path + ".tmp"
    var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        push_warning("Unable to write save file %s: %s" % [path, error_string(FileAccess.get_open_error())])
        return false
    file.store_string(text)
    file.flush()
    var write_error: Error = file.get_error()
    file.close()
    if write_error != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
        return false
    var rename_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
    if rename_error != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
        return false
    return true


func get_survivor_progress() -> Dictionary:
    _ensure_loaded()
    var value: Variant = data.get("survivor_progress", {})
    var raw: Dictionary = value if value is Dictionary else {}
    return {
        "seeds": clampi(int(raw.get("seeds", 0)), 0, 999999),
        "health_rank": clampi(int(raw.get("health_rank", 0)), 0, 3),
        "damage_rank": clampi(int(raw.get("damage_rank", 0)), 0, 3),
        "speed_rank": clampi(int(raw.get("speed_rank", 0)), 0, 3),
        "challenge_wins": maxi(0, int(raw.get("challenge_wins", 0))),
        "claimed": _sanitize_claims(raw.get("claimed", [])),
        "evolutions": maxi(0, int(raw.get("evolutions", 0))),
        "events": maxi(0, int(raw.get("events", 0))),
    }


func is_survivor_character_unlocked(index: int) -> bool:
    return index >= 0 and (index < 3 or (index == 3 and int(get_survivor_statistics()["total_victories"]) >= 1) or (index == 4 and int(get_survivor_progress()["events"]) >= 5))


func buy_survivor_upgrade(key: String) -> bool:
    if key not in ["health_rank", "damage_rank", "speed_rank"]:
        return false
    var progress: Dictionary = get_survivor_progress()
    var rank: int = int(progress[key])
    var cost: int = 15 * (rank + 1)
    if rank >= 3 or int(progress["seeds"]) < cost:
        return false
    var old: Dictionary = progress.duplicate(true)
    progress["seeds"] = int(progress["seeds"]) - cost
    progress[key] = rank + 1
    data["survivor_progress"] = progress
    if save_game():
        return true
    data["survivor_progress"] = old
    return false


func _sanitize_claims(value: Variant) -> Array:
    var valid: Array = []
    if value is Array:
        for key: Variant in value:
            if key in ["first_win", "events", "evolutions", "challenge"] and not valid.has(key):
                valid.append(key)
    return valid

func achievement_available(key: String) -> bool:
    var progress: Dictionary = get_survivor_progress()
    if (progress["claimed"] as Array).has(key):
        return false
    match key:
        "first_win":
            return int(get_survivor_statistics()["total_victories"]) >= 1
        "events":
            return int(progress["events"]) >= 5
        "evolutions":
            return int(progress["evolutions"]) >= 3
        "challenge":
            return int(progress["challenge_wins"]) >= 1
    return false

func claim_achievement(key: String) -> bool:
    if not achievement_available(key):
        return false
    var before: Dictionary = get_survivor_progress()
    var progress: Dictionary = before.duplicate(true)
    (progress["claimed"] as Array).append(key)
    progress["seeds"] = mini(999999, int(progress["seeds"]) + 15)
    data["survivor_progress"] = progress
    if save_game():
        return true
    data["survivor_progress"] = before
    return false
