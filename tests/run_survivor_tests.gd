extends SceneTree

var _failures: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    print("Running plant survivors tests...")

    var hero: GreedHeroPlant = GreedHeroPlant.new()
    root.add_child(hero)
    hero.global_position = GreedCore.ARENA_RECT.get_center()
    hero.configure(GreedBalance.STARTER_PLANTS[0], null)

    var gem: SurvivorExperienceGem = SurvivorExperienceGem.new()
    root.add_child(gem)
    gem.global_position = hero.global_position + Vector2(72.0, 0.0)
    gem.configure(hero, 3)
    var collected_values: Array[int] = []
    gem.collected.connect(func(amount: int) -> void: collected_values.append(amount))
    var initial_distance: float = gem.global_position.distance_to(hero.global_position)
    gem._process(0.15)
    _assert_true(gem.global_position.distance_to(hero.global_position) < initial_distance, "Experience dew magnetizes toward the main plant")
    for _frame: int in range(20):
        if is_instance_valid(gem):
            gem._process(0.05)
    var collected_amount: int = 0
    for value: int in collected_values:
        collected_amount += value
    _assert_equal_int(collected_amount, 3, "Experience dew grants its configured value")

    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    _assert_true(packed != null, "Default plant survivors scene loads")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame

    _assert_true(game is Node2D, "Plant survivors scene instantiates")
    _assert_equal_int(int(game.get("experience_to_next")), 8, "First level requires eight experience")
    _assert_true(bool(game.get("wave_active")), "Time survival combat is active immediately")

    var game_hero: GreedHeroPlant = game.get("hero_plant") as GreedHeroPlant
    var start_position: Vector2 = game_hero.global_position
    game.set("_movement_keys", {"left": false, "right": true, "up": false, "down": false})
    game.call("_apply_continuous_movement")
    game_hero._process(0.25)
    _assert_true(game_hero.global_position.x > start_position.x, "Continuous movement input moves the main plant")

    game.call("_on_experience_collected", 8)
    _assert_true(bool(game.get("choice_open")), "Reaching the experience threshold opens a level-up choice")
    _assert_equal_int(int(game.get("pending_level_ups")), 1, "One pending level is recorded")
    var title: Label = game.get("choice_title") as Label
    _assert_true(title.text.contains("LEVEL UP") or title.text.contains("等级提升"), "Level-up overlay uses survivor wording")

    game.call("_select_choice", 0)
    await process_frame
    _assert_true(not bool(game.get("choice_open")), "Choosing a mutation resumes time survival")
    _assert_equal_int(game_hero.level, 2, "Level-up choice evolves the main plant")

    game.set("survival_elapsed", 31.0)
    game.call("_spawn_time_milestones")
    _assert_true(bool(game.get("first_elite_spawned")), "Thirty-second elite milestone triggers")

    var spawned: GreedEnemy = game.call("_spawn_survivor_enemy", false, false) as GreedEnemy
    _assert_true(spawned != null and is_instance_valid(spawned), "Continuous survivor spawner creates enemies")
    _assert_true(not spawned.elite and not spawned.boss, "Regular timed spawns are not forced elites")

    game.queue_free()
    if is_instance_valid(hero):
        hero.queue_free()
    await process_frame

    if _failures > 0:
        push_error("Plant survivors tests failed: %d" % _failures)
        quit(1)
        return
    print("All plant survivors tests passed.")
    quit(0)


func _assert_true(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)


func _assert_equal_int(actual: int, expected: int, message: String) -> void:
    _assert_true(actual == expected, "%s (expected %d, got %d)" % [message, expected, actual])
