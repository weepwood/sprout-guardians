extends SceneTree

var _failures: int = 0
var _spawn_count: int = 0
var _campaign_completed: bool = false
var _depletion_count: int = 0


func _initialize() -> void:
    print("Running Sprout Guardians core tests...")
    _test_level_resources()
    _test_tower_roles()
    _test_enemy_and_boss_content()
    _test_localization()
    _test_campaign_scenes()
    _test_settings_persistence()
    _test_save_game_service()
    _test_economy_system()
    _test_base_health_system()
    _test_wave_manager()

    if _failures > 0:
        push_error("Core tests failed: %d" % _failures)
        quit(1)
        return

    print("All Sprout Guardians core tests passed.")
    quit(0)


func _test_level_resources() -> void:
    var level: LevelData = load("res://data/levels/morning_forest.tres") as LevelData
    _assert_true(level != null, "Morning Forest LevelData loads")
    if level == null:
        return
    _assert_equal_int(level.starting_coins, 260, "Morning Forest starts with content-slice sunlight")
    _assert_equal_int(level.base_health, 10, "Starting sprout health remains unchanged")
    _assert_equal_int(level.get_wave_count(), 10, "Morning Forest contains ten complete waves")
    _assert_equal_int(level.build_slots.size(), 6, "Morning Forest contains six build slots")
    _assert_equal_int(level.available_towers.size(), 3, "Morning Forest exposes three tower roles")

    var tower: TowerData = level.get_tower(0)
    _assert_true(tower != null, "Pea Tower resource is linked from the level")
    if tower != null:
        _assert_equal_int(tower.build_cost, 75, "Pea Tower build cost remains unchanged")
        _assert_equal_int(tower.get_upgrade_cost(1), 55, "First Pea Tower upgrade cost remains unchanged")

    var final_wave: WaveData = level.get_wave(9)
    _assert_true(final_wave != null, "Final wave resource loads")
    if final_wave != null:
        _assert_true(final_wave.get_total_enemy_count() >= 5, "Final wave includes boss support enemies")
        _assert_true(not final_wave.get_preview_text().is_empty(), "Final wave exposes an enemy preview")


func _test_tower_roles() -> void:
    var pea: TowerData = load("res://data/towers/pea_tower.tres") as TowerData
    var mushroom: TowerData = load("res://data/towers/mushroom_lamp.tres") as TowerData
    var ice: TowerData = load("res://data/towers/ice_flower.tres") as TowerData

    _assert_true(pea != null, "Pea Tower data loads")
    _assert_true(mushroom != null, "Mushroom Lamp data loads")
    _assert_true(ice != null, "Ice Flower data loads")
    if mushroom != null:
        _assert_true(mushroom.splash_radius > 0.0, "Mushroom Lamp has splash damage")
        _assert_true(mushroom.status_effect != null, "Mushroom Lamp applies poison")
    if ice != null:
        _assert_true(ice.status_effect != null, "Ice Flower applies a status effect")
        if ice.status_effect != null:
            _assert_true(ice.status_effect.speed_multiplier < 1.0, "Ice Flower status slows enemies")


func _test_enemy_and_boss_content() -> void:
    var stone_beast: EnemyData = load("res://data/enemies/stone_beast.tres") as EnemyData
    var golem: EnemyData = load("res://data/enemies/forest_golem.tres") as EnemyData
    _assert_true(stone_beast != null, "Stone Beast data loads")
    _assert_true(golem != null, "Forest Golem data loads")
    if stone_beast != null:
        _assert_true(stone_beast.armor >= 5.0, "Stone Beast has meaningful armor")
    if golem != null:
        _assert_equal_int(golem.phase_thresholds.size(), 2, "Forest Golem defines two phase thresholds")
        _assert_true(golem.phase_pulse_radius > 0.0, "Forest Golem phase pulse has a radius")
        _assert_true(golem.phase_tower_disable_duration > 0.0, "Forest Golem phase pulse disables towers")


func _test_localization() -> void:
    var localization: LocalizationService = LocalizationService.new()
    localization.set_locale("zh_CN", false)
    _assert_equal_string(localization.text("ui.start_wave"), "开始波次", "Chinese start-wave text is available")

    var pea: TowerData = load("res://data/towers/pea_tower.tres") as TowerData
    _assert_equal_string(localization.tower_name(pea), "豌豆塔", "Pea Tower has a Chinese name")

    var level: LevelData = load("res://data/levels/morning_forest.tres") as LevelData
    var stone_wave: WaveData = null if level == null else level.get_wave(3)
    _assert_true(stone_wave != null, "Stone Beast wave is available for localization")
    if stone_wave != null:
        _assert_true(localization.wave_preview(stone_wave).contains("岩石兽"), "Chinese wave preview translates enemy names")
        _assert_true(not localization.wave_hint(stone_wave).is_empty(), "Chinese tactical hint is available")

    localization.set_locale("en", false)
    _assert_equal_string(localization.text("ui.start_wave"), "Start Wave", "English remains available after switching locale")
    _assert_equal_string(localization.tower_name(pea), "Pea Tower", "English tower names remain available")


func _test_campaign_scenes() -> void:
    _assert_true(load("res://scenes/main_menu.tscn") is PackedScene, "Main menu scene loads")
    _assert_true(load("res://scenes/level_select.tscn") is PackedScene, "Level select scene loads")
    _assert_true(load("res://scenes/main.tscn") is PackedScene, "Campaign gameplay scene loads")


func _test_settings_persistence() -> void:
    var path: String = "user://sprout_test_settings.cfg"
    _remove_test_file(path)

    var settings: SettingsService = SettingsService.new()
    settings.settings_path = path
    settings.load_settings()
    settings.locale = "zh_CN"
    settings.music_enabled = false
    settings.sfx_enabled = false
    settings.screen_flash_enabled = false
    _assert_true(settings.save_settings(), "Settings service writes a configuration file")

    var reloaded: SettingsService = SettingsService.new()
    reloaded.settings_path = path
    reloaded.load_settings()
    _assert_equal_string(reloaded.locale, "zh_CN", "Locale survives settings reload")
    _assert_true(not reloaded.music_enabled, "Music preference survives settings reload")
    _assert_true(not reloaded.sfx_enabled, "SFX preference survives settings reload")
    _assert_true(not reloaded.screen_flash_enabled, "Effects preference survives settings reload")
    _remove_test_file(path)


func _test_save_game_service() -> void:
    var save_path: String = "user://sprout_test_save.json"
    var backup_path: String = "user://sprout_test_save.backup.json"
    _remove_test_file(save_path)
    _remove_test_file(backup_path)

    var save: SaveGameService = SaveGameService.new()
    save.save_path = save_path
    save.backup_path = backup_path
    save.load_game()
    _assert_true(save.is_level_unlocked(&"morning_forest"), "Morning Forest is unlocked in a new save")
    save.record_level_result(&"morning_forest", 2, 7)

    var reloaded: SaveGameService = SaveGameService.new()
    reloaded.save_path = save_path
    reloaded.backup_path = backup_path
    reloaded.load_game()
    _assert_equal_int(reloaded.get_level_stars(&"morning_forest"), 2, "Level stars survive save reload")

    reloaded.record_level_result(&"morning_forest", 3, 10)
    _write_test_file(save_path, "{broken json")
    var recovered: SaveGameService = SaveGameService.new()
    recovered.save_path = save_path
    recovered.backup_path = backup_path
    recovered.load_game()
    _assert_true(recovered.recovered_from_backup, "Corrupted primary save recovers from backup")
    _assert_true(recovered.get_level_stars(&"morning_forest") >= 2, "Backup recovery preserves completed-level progress")

    _remove_test_file(save_path)
    _remove_test_file(backup_path)
    _write_test_file(save_path, JSON.stringify({
        "version": 1,
        "completed_levels": ["morning_forest"],
        "stars": {"morning_forest": 3},
        "unlocked_levels": ["morning_forest"],
    }))
    var migrated: SaveGameService = SaveGameService.new()
    migrated.save_path = save_path
    migrated.backup_path = backup_path
    migrated.load_game()
    _assert_equal_int(int(migrated.data.get("schema_version", 0)), SaveGameService.CURRENT_VERSION, "Legacy save migrates to current schema")
    _assert_equal_int(migrated.get_level_stars(&"morning_forest"), 3, "Legacy stars survive migration")

    _remove_test_file(save_path)
    _remove_test_file(backup_path)


func _test_economy_system() -> void:
    var economy: EconomySystem = EconomySystem.new()
    economy.setup(220)
    _assert_true(economy.spend(75, &"test_build"), "Affordable transaction succeeds")
    _assert_equal_int(economy.coins, 145, "Build transaction deducts exact amount")
    _assert_true(not economy.spend(999, &"test_reject"), "Unaffordable transaction is rejected")
    _assert_equal_int(economy.coins, 145, "Rejected transaction does not change balance")
    economy.earn(12, &"test_reward")
    _assert_equal_int(economy.coins, 157, "Reward transaction adds exact amount")
    economy.free()


func _test_base_health_system() -> void:
    _depletion_count = 0
    var health: BaseHealthSystem = BaseHealthSystem.new()
    health.depleted.connect(_on_test_depleted)
    health.setup(10)
    health.damage(3)
    _assert_equal_int(health.health, 7, "Base damage reduces health")
    health.damage(20)
    health.damage(1)
    _assert_equal_int(health.health, 0, "Base health never becomes negative")
    _assert_equal_int(_depletion_count, 1, "Base depletion emits exactly once")
    health.free()


func _test_wave_manager() -> void:
    _spawn_count = 0
    _campaign_completed = false

    var enemy: EnemyData = EnemyData.new()
    enemy.id = &"test_enemy"

    var group: SpawnGroupData = SpawnGroupData.new()
    group.enemy = enemy
    group.count = 1
    group.spawn_interval = 0.1
    group.start_delay = 0.0

    var wave: WaveData = WaveData.new()
    wave.spawn_groups.append(group)
    wave.clear_reward = 35

    var level: LevelData = LevelData.new()
    level.waves.append(wave)

    var manager: WaveManager = WaveManager.new()
    root.add_child(manager)
    manager.enemy_spawn_requested.connect(_on_test_spawn_requested)
    manager.campaign_completed.connect(_on_test_campaign_completed)
    manager.setup(level)

    _assert_true(manager.start_next_wave(), "Wave manager starts configured wave")
    manager._process(0.1)
    _assert_equal_int(_spawn_count, 1, "Wave manager emits one spawn request")
    _assert_equal_int(manager.active_enemies, 1, "Wave manager tracks active enemy count")
    manager.notify_enemy_removed()
    _assert_true(_campaign_completed, "Final wave completion emits campaign completion")
    manager.free()


func _write_test_file(path: String, content: String) -> void:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        _assert_true(false, "Test file can be opened: %s" % path)
        return
    file.store_string(content)
    file.close()


func _remove_test_file(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _on_test_spawn_requested(_enemy: EnemyData, _path_index: int) -> void:
    _spawn_count += 1


func _on_test_campaign_completed() -> void:
    _campaign_completed = true


func _on_test_depleted() -> void:
    _depletion_count += 1


func _assert_true(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)


func _assert_equal_int(actual: int, expected: int, message: String) -> void:
    _assert_true(actual == expected, "%s (expected %d, got %d)" % [message, expected, actual])


func _assert_equal_string(actual: String, expected: String, message: String) -> void:
    _assert_true(actual == expected, "%s (expected '%s', got '%s')" % [message, expected, actual])