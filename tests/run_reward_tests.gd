extends SceneTree

var _failures: int = 0
var _auto_start_requests: int = 0


func _initialize() -> void:
    print("Running Sprout Guardians reward-loop tests...")
    _test_seeded_choices()
    _test_pity_and_stacking()
    _test_combo_and_chest_meter()
    _test_auto_battle_blocking()

    if _failures > 0:
        push_error("Reward-loop tests failed: %d" % _failures)
        quit(1)
        return
    print("All Sprout Guardians reward-loop tests passed.")
    quit(0)


func _test_seeded_choices() -> void:
    var first: BlessingSystem = BlessingSystem.new()
    var second: BlessingSystem = BlessingSystem.new()
    var pool: Array[BlessingData] = _load_pool()
    first.setup(pool, 20260719)
    second.setup(pool, 20260719)

    var first_choices: Array[BlessingData] = first.roll_choices(3)
    var second_choices: Array[BlessingData] = second.roll_choices(3)
    _assert_equal_int(first_choices.size(), 3, "A golden chest returns three choices")
    _assert_equal_int(second_choices.size(), 3, "Second seeded chest returns three choices")

    var unique_ids: Dictionary = {}
    for index: int in range(first_choices.size()):
        unique_ids[String(first_choices[index].id)] = true
        _assert_equal_string(String(first_choices[index].id), String(second_choices[index].id), "Same seed produces the same reward sequence")
    _assert_equal_int(unique_ids.size(), 3, "Chest choices are non-identical when the pool permits")


func _test_pity_and_stacking() -> void:
    var system: BlessingSystem = BlessingSystem.new()
    var pool: Array[BlessingData] = _load_pool()
    system.setup(pool, 99)
    system.pity_without_high = BlessingSystem.HIGH_RARITY_GUARANTEE
    var choices: Array[BlessingData] = system.roll_choices(3)
    var found_high: bool = false
    for data: BlessingData in choices:
        if data.rarity >= BlessingData.Rarity.EPIC:
            found_high = true
    _assert_true(found_high, "Pity guarantee produces an Epic or Legendary option")

    var verdant: BlessingData = load("res://data/blessings/verdant_force.tres") as BlessingData
    system.apply_blessing(verdant)
    system.apply_blessing(verdant)
    _assert_equal_int(system.get_blessing_stack(&"verdant_force"), 2, "Duplicate blessings increase stack count")
    _assert_near(system.get_damage_multiplier(), 1.30, 0.001, "Two Verdant Force stacks increase damage by 30%")


func _test_combo_and_chest_meter() -> void:
    var rewards: CombatRewardSystem = CombatRewardSystem.new()
    rewards.setup(5, 1.0)
    for _index: int in range(5):
        rewards.register_kill(false)
    _assert_true(rewards.combo == 5, "Rapid kills build a combo")
    _assert_true(rewards.pending_chests >= 1, "Chest threshold creates a pending golden chest")
    _assert_true(rewards.consume_chest(), "Pending chest can be consumed exactly once")

    rewards._process(1.1)
    _assert_equal_int(rewards.combo, 0, "Combo expires after its decay window")
    rewards.register_kill(false)
    rewards.register_escape()
    _assert_equal_int(rewards.combo, 0, "An escaped enemy breaks the combo")


func _test_auto_battle_blocking() -> void:
    _auto_start_requests = 0
    var director: AutoBattleDirector = AutoBattleDirector.new()
    director.start_requested.connect(_on_auto_start_requested)
    director.set_auto_enabled(true, false)
    director.arm(0.5)
    director.set_blocked(true)
    director._process(1.0)
    _assert_equal_int(_auto_start_requests, 0, "Blocked reward selection pauses auto-wave countdown")
    director.set_blocked(false)
    director._process(0.6)
    _assert_equal_int(_auto_start_requests, 1, "Unblocked auto director requests the next wave once")
    director._process(1.0)
    _assert_equal_int(_auto_start_requests, 1, "Auto director does not request duplicate waves")


func _on_auto_start_requested() -> void:
    _auto_start_requests += 1


func _load_pool() -> Array[BlessingData]:
    var paths: Array[String] = [
        "res://data/blessings/verdant_force.tres",
        "res://data/blessings/rapid_growth.tres",
        "res://data/blessings/long_roots.tres",
        "res://data/blessings/sun_harvest.tres",
        "res://data/blessings/spore_bloom.tres",
        "res://data/blessings/frozen_time.tres",
        "res://data/blessings/lucky_seed.tres",
        "res://data/blessings/golden_rain.tres",
    ]
    var result: Array[BlessingData] = []
    for path: String in paths:
        var data: BlessingData = load(path) as BlessingData
        if data != null:
            result.append(data)
    return result


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


func _assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
    _assert_true(absf(actual - expected) <= tolerance, "%s (expected %.3f, got %.3f)" % [message, expected, actual])