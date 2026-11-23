extends SceneTree

# Exercises the real editable scene and its state machine without waiting
# ninety wall-clock seconds. Logs are scanned for script errors by CI.
var _failures: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    print("Running Sprout Guardians survivor integration tests...")
    for iteration: int in range(2):
        await _run_full_session(iteration)
    if _failures > 0:
        push_error("Survivor integration failed: %d assertions" % _failures)
        quit(1)
        return
    print("Survivor integration tests passed.")
    quit(0)


func _run_full_session(iteration: int) -> void:
    var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
    var game: Node = scene.instantiate()
    root.add_child(game)
    await process_frame
    var hero: GreedHeroPlant = game.get("hero_plant") as GreedHeroPlant
    var state: SurvivorRunState = game.get("run_state") as SurvivorRunState
    _check(hero != null and state != null, "Scene composes playable hero and run state")
    if hero == null or state == null:
        game.queue_free()
        await process_frame
        return

    _check(state.phase == SurvivorRunState.Phase.RUNNING, "Run enters RUNNING")
    var feedback: GreedCombatFeedback = game.get("combat_feedback") as GreedCombatFeedback
    _check(feedback != null, "Combat feedback manager exists")
    if feedback != null:
        for index: int in range(280):
            feedback.spawn_damage(Vector2(180.0, 140.0), float(7 + index), index % 5 == 0)
        _check(feedback.get_active_number_count() <= GreedCombatFeedback.MAX_DAMAGE_NUMBERS, "Active damage labels stay bounded")
        _check(feedback.get_allocated_label_count() <= GreedCombatFeedback.MAX_DAMAGE_NUMBERS, "Damage label pool prevents unlimited allocation")
        feedback._process(2.0)
        _check(feedback.get_active_number_count() == 0, "Expired damage labels are returned to pool")
        for index: int in range(200):
            feedback.spawn_damage(Vector2(200.0, 140.0), float(10 + index), false)
        _check(feedback.get_allocated_label_count() <= GreedCombatFeedback.MAX_DAMAGE_NUMBERS, "Damage label pool reuses previous allocations")
        feedback._process(2.0)
    var impact: PixelImpactSystem = game.get("impact_system") as PixelImpactSystem
    if impact != null:
        for index: int in range(25):
            impact.spawn_hit(Vector2(250.0, 160.0), Color("#ee9988"), 26.0, index % 3 == 0)
        impact._process(0.04)
        _check(impact.get_active_particle_count() <= impact.max_particles, "Textured impact pool respects particle cap")
        _check(impact.find_children("ImpactSprite*", "Sprite2D", false).size() <= impact.max_particles, "Particle visual pool is bounded")
        impact.clear()
    _check(hero.has_node("PixelSprite"), "Hero uses authored image sprite")
    _check(hero.render_with_sprite, "Legacy hero drawing disabled in survivor scene")
    var hero_sprite: Sprite2D = hero.get_node("PixelSprite") as Sprite2D
    _check(hero_sprite.texture != null, "Hero image texture is assigned")

    game.call("_toggle_pause")
    _check(state.phase == SurvivorRunState.Phase.PAUSED, "Pausing enters PAUSED state")
    game.call("_toggle_pause")
    _check(state.phase == SurvivorRunState.Phase.RUNNING, "Resuming restores RUNNING state")

    game.call("_on_experience_collected", 8)
    _check(state.phase == SurvivorRunState.Phase.REWARD, "Experience enters REWARD state")
    _check(bool(game.get("choice_open")), "Reward is visible")
    game.call("_select_choice", iteration % 3)
    await process_frame
    _check(state.phase == SurvivorRunState.Phase.RUNNING, "Reward selection resumes run")

    # Keep enemy contact irrelevant for this deterministic gameplay lifecycle test.
    hero.max_health = 20000
    hero.health = 20000
    for second: int in range(93):
        if bool(game.get("game_ended")):
            break
        game.call("_process", 1.0)
        if second % 12 == 0:
            await process_frame

    _check(bool(game.get("first_elite_spawned")), "First elite milestone spawns")
    _check(bool(game.get("second_elite_spawned")), "Second elite milestone spawns")
    _check(bool(game.get("final_boss_spawned")), "Final boss milestone spawns")
    var found_boss: GreedEnemy = null
    for node: Node in get_nodes_in_group("greed_enemies"):
        var enemy: GreedEnemy = node as GreedEnemy
        if enemy != null and is_instance_valid(enemy) and enemy.boss:
            found_boss = enemy
            break
    _check(found_boss != null, "Boss actor is active and correctly configured")
    if found_boss != null:
        found_boss.take_damage(1000000.0)
        game.call("_process", 0.016)
        _check(bool(game.get("game_ended")), "Boss defeat completes a run")
        _check(state.phase == SurvivorRunState.Phase.VICTORY, "Victory is a terminal phase")
        _check((game.get("result_button") as Button).visible, "Run displays restart action")
        var saved_stats: Dictionary = (game.get("run_save") as SaveGameService).get_survivor_statistics()
        _check(int(saved_stats["total_victories"]) >= 1, "Victory is recorded in the persistent run journal")
        _check(int(saved_stats["best_kills"]) >= 0, "Persistent run record preserves kill count")

    game.queue_free()
    await process_frame
    await process_frame


func _check(value: bool, message: String) -> void:
    if value:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
