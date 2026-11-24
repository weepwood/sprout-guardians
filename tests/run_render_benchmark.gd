extends SceneTree

# Software-rendering workload. Fixed simulation delta, measured wall intervals
# between real completed frames. Not a claim about physical low-end GPUs.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    SurvivorBalance.selected_difficulty = 1
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    var game: Node = packed.instantiate()
    game.set("simulation_mode", true)
    game.set("endless_mode", true)
    game.set("simulation_map", 1)
    game.set("run_seed", 20261124)
    root.add_child(game)
    var hero: GreedHeroPlant = game.get("hero_plant") as GreedHeroPlant
    hero.max_health = 10000
    hero.heal(10000)
    var intervals: Array[int] = []
    var samples: Array[Dictionary] = []
    var next_sample: float = 0.0
    var previous: int = Time.get_ticks_usec()
    var elapsed: float = 0.0
    for frame_index: int in range(60 * 140):
        if bool(game.get("game_ended")):
            break
        if bool(game.get("choice_open")):
            var choices: Array = game.get("_current_choices")
            if not choices.is_empty():
                game.call("_select_choice", 0)
        var goal: Vector2 = Vector2(640, 360) + Vector2(cos(float(frame_index) / 110.0) * 170.0, sin(float(frame_index) / 110.0) * 95.0)
        game.set("simulation_direction", (goal - hero.global_position).limit_length(1.0))
        await RenderingServer.frame_post_draw
        var now: int = Time.get_ticks_usec()
        if frame_index >= 120:
            intervals.append(now - previous)
        previous = now
        elapsed = float(game.get("survival_elapsed"))
        if elapsed >= next_sample:
            samples.append({"seconds": elapsed, "memory_bytes": OS.get_static_memory_usage(), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "enemies": get_nodes_in_group("greed_enemies").size()})
            next_sample += 15.0
        if elapsed >= 120.0:
            break
    intervals.sort()
    var count: int = intervals.size()
    var report: Dictionary = {"sim_seconds": elapsed, "assisted": true, "frames": count, "adapter": RenderingServer.get_video_adapter_name(), "vendor": RenderingServer.get_video_adapter_vendor(), "viewport": str(root.get_texture().get_size()), "p50_ms": _percentile(intervals, 0.50), "p95_ms": _percentile(intervals, 0.95), "p99_ms": _percentile(intervals, 0.99), "samples": samples}
    print("RENDER_BENCHMARK ", JSON.stringify(report))
    game.queue_free()
    for _i: int in range(12):
        await process_frame
    quit(0 if elapsed >= 120.0 and count > 6000 and get_nodes_in_group("greed_enemies").is_empty() else 1)

func _percentile(values: Array[int], ratio: float) -> float:
    return float(values[floori(float(values.size() - 1) * ratio)]) / 1000.0 if not values.is_empty() else 0.0
