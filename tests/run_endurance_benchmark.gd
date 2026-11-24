extends SceneTree

# Stress harness: fixed delta; assisted health is intentional, not win-rate evidence.
# Wall interval is headless throughput (not rendered FPS).
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    SurvivorBalance.selected_difficulty = 1
    var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
    var initial_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
    var initial_memory: int = OS.get_static_memory_usage()
    var game: Node = scene.instantiate()
    game.set("simulation_mode", true)
    game.set("endless_mode", true)
    game.set("simulation_map", 1)
    game.set("run_seed", 20261124)
    root.add_child(game)
    var hero: GreedHeroPlant = game.get("hero_plant") as GreedHeroPlant
    hero.max_health = 10000
    hero.heal(10000)
    var elapsed: float = 0.0
    var next_sample: float = 0.0
    var samples: Array[Dictionary] = []
    var intervals: Array[int] = []
    var started: int = Time.get_ticks_usec()
    for frame_index: int in range(60 * 720):
        if bool(game.get("game_ended")):
            break
        if bool(game.get("choice_open")):
            var choices: Array = game.get("_current_choices")
            if not choices.is_empty():
                game.call("_select_choice", 0)
        var goal: Vector2 = Vector2(640, 360) + Vector2(cos(float(frame_index) / 110.0) * 170.0, sin(float(frame_index) / 110.0) * 95.0)
        game.set("simulation_direction", (goal - hero.global_position).limit_length(1.0))
        var tick: int = Time.get_ticks_usec()
        await process_frame
        intervals.append(Time.get_ticks_usec() - tick)
        elapsed = float(game.get("survival_elapsed"))
        if elapsed >= next_sample:
            var sample: Dictionary = {"elapsed": elapsed, "memory_bytes": OS.get_static_memory_usage(), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "enemies": get_nodes_in_group("greed_enemies").size(), "bosses": game.get("bosses_defeated"), "projectiles": game.get("projectile_pool").metrics(), "pickups": game.get("pickup_pool").metrics()}
            samples.append(sample)
            print("ENDURANCE_SAMPLE ", JSON.stringify(sample))
            next_sample += 30.0
        if elapsed >= 600.0:
            break
    intervals.sort()
    var count: int = intervals.size()
    var wall: int = Time.get_ticks_usec() - started
    var projectiles: Dictionary = game.get("projectile_pool").metrics()
    var pickups: Dictionary = game.get("pickup_pool").metrics()
    var result: Dictionary = {"assisted": true, "sim_seconds": elapsed, "wall_seconds": float(wall) / 1000000.0, "frames": count, "p50_wall_us": intervals[floori(float(count - 1) * 0.5)] if count > 0 else 0, "p95_wall_us": intervals[floori(float(count - 1) * 0.95)] if count > 0 else 0, "p99_wall_us": intervals[floori(float(count - 1) * 0.99)] if count > 0 else 0, "samples": samples}
    print("ENDURANCE_SUMMARY ", JSON.stringify(result))
    var valid: bool = elapsed >= 600.0 and int(projectiles["idle"]) <= 128 and int(pickups["idle"]) <= 128 and int(game.get("bosses_defeated")) >= 2
    game.queue_free()
    for _i: int in range(12):
        await process_frame
    var residual_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - initial_nodes
    var remaining: int = get_nodes_in_group("greed_enemies").size() + get_nodes_in_group("greed_projectiles").size() + get_nodes_in_group("survivor_experience").size()
    print("ENDURANCE_TEARDOWN ", JSON.stringify({"initial_nodes": initial_nodes, "residual_nodes": residual_nodes, "memory_delta": OS.get_static_memory_usage() - initial_memory, "remaining_combat_nodes": remaining}))
    quit(0 if valid and remaining == 0 else 1)
