extends SceneTree

var _failures: int = 0
var _spawned_projectiles: Array[GreedProjectile] = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    print("Running greed arena balance tests...")

    _assert_equal_int(GreedBalance.STARTER_PLANTS.size(), 3, "Greed mode defines one main plant and two familiar configs")
    _assert_equal_int(GreedBalance.WAVE_TABLE.size(), 10, "Greed floor contains ten combat waves")
    _assert_true(GreedBalance.starter_sustained_dps() >= 80.0, "Combined starter sustained DPS exceeds minimum combat floor")
    _assert_true(GreedBalance.starter_margin_ratio() >= 2.0, "Starter squad DPS is at least twice wave-1 health spawn rate")
    _assert_true(GreedBalance.projected_wave_clear_seconds(0) <= 18.0, "Wave 1 projects to clear within 18 seconds")
    _assert_true(GreedBalance.maximum_projected_wave_seconds() <= 18.0, "Main-plant progression keeps every wave below 18 seconds")
    for wave_index: int in range(GreedBalance.WAVE_TABLE.size()):
        _assert_true(
            GreedBalance.projected_wave_clear_seconds(wave_index) <= 18.0,
            "Greed wave %d remains clearable without a lucky mutation" % (wave_index + 1)
        )
    _assert_true(
        GreedBalance.minimum_progression_dps(9) > GreedBalance.starter_sustained_dps() * 2.0,
        "Guaranteed main-plant evolution more than doubles DPS before the boss"
    )
    _assert_float_close(GreedBalance.fury_multiplier(19.9), 1.0, 0.001, "Garden Fury waits until the anti-stall threshold")
    _assert_true(GreedBalance.fury_multiplier(20.0) > 1.0, "Garden Fury activates after 20 seconds")
    _assert_true(not GreedBalance.rescue_active(11.9), "Rescue overdrive is inactive before twelve seconds without a kill")
    _assert_true(GreedBalance.rescue_active(12.0), "Rescue overdrive activates at twelve seconds without a kill")

    var blessings: BlessingSystem = BlessingSystem.new()
    root.add_child(blessings)
    blessings.setup([], 12345)

    var hero: GreedHeroPlant = GreedHeroPlant.new()
    root.add_child(hero)
    hero.global_position = GreedCore.ARENA_RECT.get_center()
    hero.configure(GreedBalance.STARTER_PLANTS[0], blessings)
    hero.projectile_requested.connect(_spawn_test_projectile)
    var initial_health: int = hero.health
    _assert_true(hero.take_contact_damage(1), "Main plant accepts its first contact hit")
    _assert_equal_int(hero.health, initial_health - 1, "Contact damage reduces main-plant health")
    _assert_true(not hero.take_contact_damage(1), "Contact invulnerability blocks immediate repeated damage")
    hero.heal(1)
    _assert_equal_int(hero.health, initial_health, "Inter-wave recovery restores main-plant health")

    var initial_position: Vector2 = hero.global_position
    hero.set_selected(true)
    hero.set_move_target(initial_position + Vector2(70.0, 20.0))
    hero._process(0.25)
    _assert_true(hero.global_position.distance_to(initial_position) > 1.0, "Selected main plant follows a mouse movement destination")

    var dash_start: Vector2 = hero.global_position
    _assert_true(hero.request_dash(dash_start + Vector2(90.0, 0.0)), "Main plant accepts a dash request toward the cursor")
    _assert_true(hero.invulnerability_time >= GreedHeroPlant.DASH_INVULNERABILITY, "Dash grants brief contact invulnerability")
    _assert_true(not hero.request_dash(dash_start + Vector2(0.0, 90.0)), "Dash cooldown blocks an immediate second dash")
    hero._process(0.08)
    _assert_true(hero.global_position.distance_to(dash_start) > 20.0, "Dash moves the main plant a meaningful distance")
    hero._process(0.08)
    _assert_true(not hero.is_dashing(), "Dash completes within its short movement window")

    var before_upgrade: float = hero.get_sustained_dps()
    hero.upgrade()
    _assert_true(hero.get_sustained_dps() > before_upgrade, "Main-plant evolution increases sustained DPS")

    var familiar: GreedPlant = GreedPlant.new()
    root.add_child(familiar)
    familiar.global_position = hero.global_position + Vector2(34.0, 0.0)
    familiar.configure(hero, GreedBalance.STARTER_PLANTS[1], 0, blessings)
    familiar.set_focus_source(hero)
    familiar.projectile_requested.connect(_spawn_test_projectile)
    _assert_true(familiar.focus_source == hero, "Floating familiar follows the main plant focus source")

    var wave_one: Dictionary = GreedBalance.WAVE_TABLE[0]
    var enemy: GreedEnemy = GreedEnemy.new()
    root.add_child(enemy)
    enemy.global_position = hero.global_position + Vector2(50.0, 0.0)
    enemy.configure(hero, wave_one)
    hero.set_focus_target(enemy)
    _assert_true(hero.get_focus_target() == enemy, "Main plant stores a clicked priority target")
    _assert_true(enemy.priority_targeted, "Focused enemy exposes a visible targeting state")
    _assert_true(familiar.call("_find_target") == enemy, "Familiar inherits the main plant priority target")

    var starting_enemy_health: float = enemy.health
    hero.call("_attack", enemy)
    _assert_float_close(enemy.health, starting_enemy_health, 0.001, "Launching a projectile does not deal instant damage")
    _assert_equal_int(_spawned_projectiles.size(), 1, "Main plant creates one physical projectile")
    var hero_projectile: GreedProjectile = _spawned_projectiles[0]
    _assert_true(hero_projectile.global_position.distance_to(enemy.global_position) > 1.0, "Projectile begins at the firing plant rather than the target")
    for _frame: int in range(12):
        if is_instance_valid(hero_projectile):
            hero_projectile._process(0.02)
    _assert_true(enemy.health < starting_enemy_health, "Projectile applies damage after reaching the target")

    var projectile_count_before_familiar: int = _spawned_projectiles.size()
    if is_instance_valid(enemy):
        familiar.call("_attack", enemy)
    _assert_true(_spawned_projectiles.size() > projectile_count_before_familiar, "Floating familiar also launches a physical projectile")

    hero.clear_focus_target()
    if is_instance_valid(enemy):
        _assert_true(not enemy.priority_targeted, "Clearing focus removes the enemy target marker")

    for projectile: GreedProjectile in _spawned_projectiles:
        if projectile != null and is_instance_valid(projectile):
            projectile.queue_free()
    familiar.queue_free()
    if is_instance_valid(enemy):
        enemy.queue_free()
    hero.queue_free()
    blessings.queue_free()
    await process_frame

    if _failures > 0:
        push_error("Greed arena tests failed: %d" % _failures)
        quit(1)
        return
    print("All greed arena balance tests passed.")
    quit(0)


func _spawn_test_projectile(
        origin: Vector2,
        target: GreedEnemy,
        damage: float,
        critical: bool,
        speed: float,
        splash_radius: float,
        slow_ratio: float,
        knockback_force: float,
        color: Color
) -> void:
    var projectile: GreedProjectile = GreedProjectile.new()
    root.add_child(projectile)
    projectile.configure(
        origin,
        target,
        damage,
        critical,
        speed,
        splash_radius,
        slow_ratio,
        knockback_force,
        color
    )
    _spawned_projectiles.append(projectile)


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
