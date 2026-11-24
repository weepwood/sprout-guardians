extends SceneTree

# Real scene, normal enemy contact damage, actual weapons and XP pickups.
# Run with --fixed-fps 60; this measures scripted policies, not human win rate.
var results: Array[Dictionary] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
    var difficulties: Array[int] = [0, 1, 2]
    var equal_rewards: bool = OS.get_cmdline_user_args().has("--equal-rewards")
    var character_id: int = 0
    var map_id: int = 0
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--simulation-difficulty="):
            difficulties = [clampi(int(argument.get_slice("=", 1)), 0, 2)]
        elif argument.begins_with("--simulation-character="):
            character_id = clampi(int(argument.get_slice("=", 1)), 0, 4)
        elif argument.begins_with("--simulation-map="):
            map_id = clampi(int(argument.get_slice("=", 1)), 0, 3)
        elif argument == "--simulation-reward=first":
            equal_rewards = true
    for difficulty: int in difficulties:
        for case_index: int in range(9):
            var seed_value: int = [101, 202, 303][floori(float(case_index) / 3.0)]
            SurvivorBalance.selected_difficulty = difficulty
            var game: Node = scene.instantiate()
            game.set("run_seed", seed_value)
            game.set("simulation_mode", true)
            game.set("simulation_character", character_id)
            game.set("simulation_map", map_id)
            root.add_child(game)
            var hero: GreedHeroPlant = game.get("hero_plant") as GreedHeroPlant
            # Full cross product: each seed runs each of the three policies.
            var policy: int = case_index % 3
            for frame: int in range(60 * 125):
                if bool(game.get("game_ended")):
                    break
                if bool(game.get("choice_open")):
                    var choices: Array = game.get("_current_choices")
                    if not choices.is_empty():
                        var choice: int = 0
                        if policy == 1 and not equal_rewards:
                            for i: int in range(choices.size()):
                                if SurvivorArsenal.IDS.has(choices[i].id):
                                    choice = i
                                    break
                        elif policy == 2 and not equal_rewards:
                            choice = posmod(frame + seed_value, choices.size())
                        game.call("_select_choice", choice)
                var direction: Vector2 = Vector2.ZERO
                if policy == 1:
                    var target: Vector2 = (Vector2(320, 181) if map_id == 0 else SurvivorMaps.world_size(map_id) * 0.5) + Vector2(cos(frame / 110.0) * 170.0, sin(frame / 110.0) * 95.0)
                    direction = (target - hero.global_position).limit_length(1.0)
                elif policy == 2:
                    var repel: Vector2 = Vector2.ZERO
                    for node: Node in get_nodes_in_group("greed_enemies"):
                        var enemy: GreedEnemy = node as GreedEnemy
                        if is_instance_valid(enemy) and enemy.health > 0:
                            var offset: Vector2 = hero.global_position - enemy.global_position
                            repel += offset.normalized() / maxf(10.0, offset.length())
                    direction = (repel * 130.0 + ((Vector2(320,181) if map_id == 0 else SurvivorMaps.world_size(map_id) * 0.5) - hero.global_position) / 160.0).limit_length(1.0)
                game.set("simulation_direction", direction)
                await process_frame
            var result: Dictionary = {"seed": seed_value, "difficulty": difficulty, "policy": policy, "victory": bool(game.get("final_boss_defeated")), "elapsed": game.get("survival_elapsed"), "first_upgrade": game.get("first_upgrade_seconds"), "kills": game.get("enemies_defeated"), "level": hero.level, "damage": game.get("total_damage"), "peak_enemies": game.get("peak_enemies")}
            var source_damage: Dictionary = game.get("damage_by_source")
            result["source_damage"] = source_damage.duplicate()
            result["damage_received"] = game.get("damage_received")
            result["projectile_pool"] = game.get("projectile_pool").metrics()
            result["pickup_pool"] = game.get("pickup_pool").metrics()
            result["character"] = character_id
            result["map"] = map_id
            result["reward_policy"] = "first" if equal_rewards else "mixed"
            result["outcome"] = "victory" if result["victory"] else ("defeat" if bool(game.get("game_ended")) else "timeout")
            if float(result["elapsed"]) <= 0.0 or int(result["kills"]) < 0 or (int(result["kills"]) > 0 and float(source_damage.get("hero", 0.0)) + float(source_damage.get("familiar", 0.0)) + float(source_damage.get("arsenal", 0.0)) <= 0.0):
                push_error("Invalid simulation result: %s" % str(result))
                quit(1)
                return
            results.append(result)
            print("SIMULATION ", JSON.stringify(result))
            game.queue_free()
            await process_frame
            await process_frame
    print("SIMULATION_SUMMARY ", JSON.stringify(results))
    quit(0 if results.size() == difficulties.size() * 9 else 1)
