extends SceneTree

var _failures: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    print("Running greed arena balance tests...")

    _assert_equal_int(GreedBalance.STARTER_PLANTS.size(), 3, "Greed mode starts with three plant familiars")
    _assert_equal_int(GreedBalance.WAVE_TABLE.size(), 10, "Greed floor contains ten combat waves")
    _assert_true(GreedBalance.starter_sustained_dps() >= 80.0, "Starter sustained DPS exceeds minimum combat floor")
    _assert_true(GreedBalance.starter_margin_ratio() >= 2.0, "Starter DPS is at least twice wave-1 health spawn rate")
    _assert_true(GreedBalance.projected_wave_clear_seconds(0) <= 18.0, "Wave 1 projects to clear within 18 seconds")
    _assert_true(GreedBalance.maximum_projected_wave_seconds() <= 18.0, "Minimum automatic progression projects every wave below 18 seconds")
    for wave_index: int in range(GreedBalance.WAVE_TABLE.size()):
        _assert_true(
            GreedBalance.projected_wave_clear_seconds(wave_index) <= 18.0,
            "Greed wave %d remains clearable without relying on a lucky mutation" % (wave_index + 1)
        )
    _assert_true(
        GreedBalance.minimum_progression_dps(9) > GreedBalance.starter_sustained_dps() * 2.0,
        "Guaranteed automatic evolution more than doubles squad DPS before the boss"
    )
    _assert_float_close(GreedBalance.fury_multiplier(19.9), 1.0, 0.001, "Garden Fury waits until the anti-stall threshold")
    _assert_true(GreedBalance.fury_multiplier(20.0) > 1.0, "Garden Fury activates after 20 seconds")
    _assert_true(GreedBalance.fury_multiplier(200.0) <= 2.2, "Garden Fury respects its maximum multiplier")
    _assert_true(not GreedBalance.rescue_active(11.9), "Rescue overdrive is inactive before twelve seconds without a kill")
    _assert_true(GreedBalance.rescue_active(12.0), "Rescue overdrive activates at twelve seconds without a kill")

    var core: GreedCore = GreedCore.new()
    root.add_child(core)
    core.global_position = GreedCore.ARENA_RECT.get_center()
    var initial_health: int = core.health
    _assert_true(core.take_contact_damage(1), "Garden core accepts its first contact hit")
    _assert_equal_int(core.health, initial_health - 1, "Contact damage reduces core health")
    _assert_true(not core.take_contact_damage(1), "Contact invulnerability blocks immediate repeated damage")
    core.heal(1)
    _assert_equal_int(core.health, initial_health, "Automatic inter-wave recovery restores core health")

    var blessings: BlessingSystem = BlessingSystem.new()
    root.add_child(blessings)
    blessings.setup([], 12345)
    var plant: GreedPlant = GreedPlant.new()
    root.add_child(plant)
    plant.configure(core, GreedBalance.STARTER_PLANTS[0], 0, blessings)
    _assert_true(plant.get_sustained_dps() > 35.0, "Pea Shooter has meaningful starter DPS")
    var before_upgrade: float = plant.get_sustained_dps()
    plant.upgrade()
    _assert_true(plant.get_sustained_dps() > before_upgrade, "Automatic plant evolution increases sustained DPS")

    var wave_one: Dictionary = GreedBalance.WAVE_TABLE[0]
    var enemy: GreedEnemy = GreedEnemy.new()
    root.add_child(enemy)
    enemy.configure(core, wave_one)
    var starting_enemy_health: float = enemy.health
    enemy.take_damage(18.0)
    _assert_true(enemy.health < starting_enemy_health, "Arena enemies take direct familiar damage")
    enemy.apply_slow(0.7, 1.0)

    plant.queue_free()
    enemy.queue_free()
    blessings.queue_free()
    core.queue_free()
    await process_frame

    if _failures > 0:
        push_error("Greed arena tests failed: %d" % _failures)
        quit(1)
        return
    print("All greed arena balance tests passed.")
    quit(0)


func _assert_true(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)


func _assert_equal_int(actual: int, expected: int, message: String) -> void:
    _assert_true(actual == expected, "%s (expected %d, got %d)" % [message, expected, actual])


func _assert_float_close(actual: float, expected: float, tolerance: float, message: String) -> void:
    _assert_true(absf(actual - expected) <= tolerance, "%s (expected %.3f, got %.3f)" % [message, expected, actual])