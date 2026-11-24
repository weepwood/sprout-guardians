extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var service: SaveGameService = SaveGameService.new()
    service.save_path = "user://cross_platform_recovery.json"
    service.backup_path = "user://cross_platform_recovery.bak"
    for path: String in [service.save_path, service.backup_path, service.save_path + ".tmp", service.backup_path + ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    service.load_game()
    var valid: bool = service.is_survivor_map_unlocked(1) and not service.is_survivor_map_unlocked(2)
    valid = service.record_survivor_result(true, 100, 8, 100, {"map": 1}) and valid
    valid = service.is_survivor_map_unlocked(2) and valid
    valid = service.record_survivor_result(true, 100, 8, 100, {"map": 2}) and valid
    valid = service.is_survivor_map_unlocked(3) and valid
    valid = service.record_survivor_result(true, 100, 8, 100, {"challenge": true, "challenge_date": "2026-11-24"}) and valid
    var seeds: int = int(service.get_survivor_progress()["seeds"])
    valid = service.record_survivor_result(true, 100, 8, 100, {"challenge": true, "challenge_date": "2026-11-24"}) and valid
    valid = int(service.get_survivor_progress()["seeds"]) == seeds + 22 and valid
    valid = service.claim_achievement("first_win") and valid
    valid = not service.claim_achievement("first_win") and valid
    valid = service.save_game() and valid
    var expected: Dictionary = service.get_survivor_progress().duplicate(true)
    var file: FileAccess = FileAccess.open(service.save_path, FileAccess.WRITE)
    if file == null:
        quit(1)
        return
    file.store_string("{broken")
    file.close()
    service.load_game()
    valid = service.recovered_from_backup and service.get_survivor_progress() == expected and valid
    var old_path: String = service.save_path
    service.save_path = "user://missing_save_parent/cannot_write.json"
    valid = not service.buy_survivor_upgrade("speed_rank") and service.get_survivor_progress() == expected and valid
    service.save_path = old_path
    for path: String in [service.save_path, service.backup_path, service.save_path + ".tmp", service.backup_path + ".tmp"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("SAVE_RECOVERY ", OS.get_name(), " ", valid)
    quit(0 if valid else 1)
