extends SceneTree

var _failures: int = 0
var _deploy_requests: int = 0
var _upgrade_requests: int = 0
var _relocate_requests: int = 0
var _test_towers: Dictionary = {}
var _test_preparing: bool = true


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    print("Running autonomous roguelite tests...")
    _test_director_determinism_and_single_action()
    _test_guaranteed_surprise_drop()
    await _test_pixel_effect_budget()

    if _failures > 0:
        push_error("Autonomous roguelite tests failed: %d" % _failures)
        quit(1)
        return
    print("All autonomous roguelite tests passed.")
    quit(0)


func _test_director_determinism_and_single_action() -> void:
    var level: LevelData = load("res://data/levels/morning_forest.tres") as LevelData
    _assert_true(level != null, "Morning Forest loads for autonomous decisions")
    if level == null:
        return

    var economy: EconomySystem = EconomySystem.new()
    economy.setup(level.starting_coins)
    var wave_manager: WaveManager = WaveManager.new()
    wave_manager.setup(level)

    var first: AutonomousGardenDirector = AutonomousGardenDirector.new()
    var second: AutonomousGardenDirector = AutonomousGardenDirector.new()
    first.setup(level, economy, wave_manager, Callable(self, "_provide_test_towers"), Callable(self, "_provide_test_preparing"), 424242)
    second.setup(level, economy, wave_manager, Callable(self, "_provide_test_towers"), Callable(self, "_provide_test_preparing"), 424242)

    var wave: WaveData = level.get_wave(0)
    _assert_equal_int(first.choose_tower_index(wave), second.choose_tower_index(wave), "Same seed and pressure choose the same plant role")

    var candidates: Array[int] = [0, 1, 2, 3, 4, 5]
    var tower_data: TowerData = level.get_tower(0)
    _assert_equal_int(first.choose_best_slot(tower_data, candidates), second.choose_best_slot(tower_data, candidates), "Same formation state chooses the same deployment slot")

    _deploy_requests = 0
    first.deploy_requested.connect(_on_test_deploy_requested)
    first.set_enabled(true)
    first.force_decision()
    first.force_decision()
    _assert_equal_int(_deploy_requests, 1, "Director never emits two economy actions while one is pending")
    _assert_true(first.pending_action, "Director marks an emitted action as pending")
    first.notify_action_resolved(false)
    _assert_true(not first.pending_action, "Director unlocks after receiving an action result")

    first.free()
    second.free()
    economy.free()
    wave_manager.free()


func _test_guaranteed_surprise_drop() -> void:
    var rewards: CombatRewardSystem = CombatRewardSystem.new()
    rewards.setup(12, 3.2)
    rewards.grant_surprise_drop(1)
    _assert_equal_int(rewards.pending_chests, 1, "Wave clear can guarantee one surprise choice")
    _assert_true(rewards.consume_chest(), "Guaranteed surprise can be consumed")
    _assert_equal_int(rewards.pending_chests, 0, "Guaranteed surprise is consumed exactly once")
    rewards.free()


func _test_pixel_effect_budget() -> void:
    var effects: PixelImpactSystem = PixelImpactSystem.new()
    effects.max_particles = 32
    root.add_child(effects)
    await process_frame
    effects.spawn_boss_phase(Vector2(320.0, 180.0), Color("ff9a62"))
    effects.spawn_reward(Vector2(320.0, 180.0), Color("ffd45e"))
    effects.spawn_kill(Vector2(300.0, 170.0), Color("82d16f"), Vector2(24.0, 24.0))
    _assert_true(effects.get_active_particle_count() <= 32, "Pixel effects remain inside the configured particle budget")
    effects._process(1.0)
    _assert_equal_int(effects.get_active_particle_count(), 0, "Pixel particles expire without leaving nodes behind")
    effects.queue_free()
    await process_frame


func _provide_test_towers() -> Dictionary:
    return _test_towers


func _provide_test_preparing() -> bool:
    return _test_preparing


func _on_test_deploy_requested(_tower_index: int, _slot_index: int, _reason: String) -> void:
    _deploy_requests += 1


func _assert_true(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)


func _assert_equal_int(actual: int, expected: int, message: String) -> void:
    _assert_true(actual == expected, "%s (expected %d, got %d)" % [message, expected, actual])