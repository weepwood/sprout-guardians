extends SceneTree

var _failures: int = 0
var _spawn_count: int = 0
var _campaign_completed: bool = false
var _depletion_count: int = 0


func _initialize() -> void:
    print("Running Sprout Guardians core tests...")
    _test_level_resources()
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
    _assert_equal_int(level.starting_coins, 220, "Starting sunlight remains unchanged")
    _assert_equal_int(level.base_health, 10, "Starting sprout health remains unchanged")
    _assert_equal_int(level.get_wave_count(), 4, "Prototype still contains four waves")
    _assert_equal_int(level.build_slots.size(), 6, "Prototype still contains six build slots")

    var tower: TowerData = level.get_tower(0)
    _assert_true(tower != null, "Pea Tower resource is linked from the level")
    if tower != null:
        _assert_equal_int(tower.build_cost, 75, "Pea Tower build cost remains unchanged")
        _assert_equal_int(tower.get_upgrade_cost(1), 55, "First upgrade cost remains unchanged")


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
