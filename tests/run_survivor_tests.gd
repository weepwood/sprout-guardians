extends SceneTree

var _failures: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    print("Running plant survivors tests...")

    _assert_true(PixelArtAssets.texture(&"hero") != null, "Main-plant pixel texture loads from the actor atlas")
    _assert_true(PixelArtAssets.texture(&"enemy_boss") != null, "Boss pixel texture loads from the actor atlas")
    _assert_true(PixelArtAssets.texture(&"xp_gem") != null, "Experience gem texture loads from the effects atlas")
    _assert_true(PixelArtAssets.GRASS_TILE != null, "Concept-art grass tile loads")

    for scene_path: String in [
        "res://scenes/actors/hero_plant.tscn",
        "res://scenes/actors/familiar_sun.tscn",
        "res://scenes/actors/familiar_sprout.tscn",
        "res://scenes/actors/enemy.tscn",
        "res://scenes/effects/projectile.tscn",
        "res://scenes/effects/experience_gem.tscn",
    ]:
        _assert_true(load(scene_path) is PackedScene, "Reusable scene loads: %s" % scene_path)

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

    var menu_packed: PackedScene = load("res://scenes/main_menu.tscn") as PackedScene
    _assert_true(menu_packed != null, "Editor-visible main menu scene loads")
    var menu: Node = menu_packed.instantiate()
    root.add_child(menu)
    await process_frame
    _assert_true(menu.has_node("World/Grass"), "Main menu stores its visible background in the scene tree")
    _assert_true(menu.has_node("UI/Main/PlayButton"), "Main menu play button is editable in the scene tree")
    _assert_true(menu.has_node("UI/Settings/Panel"), "Main menu settings panel is editable in the scene tree")
    menu.queue_free()
    await process_frame

    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    _assert_true(packed != null, "Default plant survivors scene loads")
    var game: Node = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    await process_frame

    _assert_true(game is Node2D, "Plant survivors scene instantiates")
    _assert_true(game.has_node("World/ArenaGround"), "Arena ground is directly editable in the scene tree")
    _assert_true(game.has_node("World/EditorPreview/Hero"), "Editor preview actors exist in the scene tree")
    _assert_true(game.has_node("World/Runtime/Actors/PlayerSpawn"), "Player spawn marker exists in the scene tree")
    _assert_true(game.has_node("World/Runtime/Enemies"), "Enemy runtime container exists")
    _assert_true(game.has_node("World/Runtime/Projectiles"), "Projectile runtime container exists")
    _assert_true(game.has_node("World/Runtime/Pickups"), "Pickup runtime container exists")
    _assert_true(game.has_node("World/Runtime/Effects"), "Effect runtime container exists")
    _assert_true(game.has_node("UI/TopHUD/TimeLabel"), "Top HUD is editable in the scene tree")
    _assert_true(game.has_node("UI/ChoiceLayer/Panel"), "Level-up panel is editable in the scene tree")
    _assert_equal_int(int(game.get("experience_to_next")), 8, "First level requires eight experience")
    _assert_true(bool(game.get("wave_active")), "Time survival combat is active immediately")

    var preview: Node2D = game.get_node("World/EditorPreview") as Node2D
    _assert_true(not preview.visible, "Editor-only actor preview is hidden during gameplay")

    var skin: PixelSkinController = game.get("pixel_skin") as PixelSkinController
    _assert_true(skin != null and is_instance_valid(skin), "Pixel skin controller is active")
    var game_hero: GreedHeroPlant = game.get("hero_plant") as GreedHeroPlant
    _assert_true(game_hero.get_parent() == game.get_node("World/Runtime/Actors"), "Main plant is instantiated into the actor container")
    _assert_true(game_hero.has_node("PixelSprite"), "Main plant receives the concept-art pixel sprite")
    var familiars: Array = game.get("plants") as Array
    for familiar_value: Variant in familiars:
        var familiar: GreedPlant = familiar_value as GreedPlant
        _assert_true(familiar.get_parent() == game.get_node("World/Runtime/Actors"), "Floating familiar is instantiated into the actor container")
        _assert_true(familiar.has_node("PixelSprite"), "Floating familiar receives a pixel sprite")

    var experience_progress: ProgressBar = game.get("experience_bar") as ProgressBar
    _assert_true(experience_progress != null, "Pixel HUD includes an experience bar")
    _assert_equal_int(int(experience_progress.max_value), 8, "Experience bar uses the current level threshold")

    var input_controller: SurvivorInputController = game.get_node("RunInput") as SurvivorInputController
    _assert_true(input_controller != null, "Survivor movement is handled by an independent input controller")
    _assert_true(game_hero.arcade_movement, "Hero enters classic survivors arcade movement")
    var start_position: Vector2 = game_hero.global_position
    input_controller.set_test_direction(Vector2.RIGHT)
    game.call("_apply_continuous_movement")
    game_hero._process(0.25)
    _assert_true(game_hero.global_position.x > start_position.x, "Direct input immediately moves the hero")
    input_controller.set_test_direction(Vector2.ZERO)
    game.call("_apply_continuous_movement")
    var released_position: Vector2 = game_hero.global_position
    game_hero._process(0.2)
    _assert_true(game_hero.global_position.distance_to(released_position) < 0.01, "Releasing direction stops motion immediately")
    game_hero.set_move_target(released_position + Vector2(30.0, 0.0))
    _assert_true(not game_hero.has_move_target, "Click-to-move is disabled in survivors")
    _assert_true(not game_hero.request_dash(released_position + Vector2(70.0, 0.0)), "Base dash is disabled in classic survivors")
    input_controller.clear_test_direction()

    game.call("_on_experience_collected", 8)
    _assert_true(bool(game.get("choice_open")), "Reaching the experience threshold opens a level-up choice")
    _assert_equal_int(int(game.get("pending_level_ups")), 1, "One pending level is recorded")
    var title: Label = game.get("choice_title") as Label
    _assert_true(title.text.contains("LEVEL UP") or title.text.contains("等级提升"), "Level-up overlay uses survivor wording")
    var choice_buttons: Array = game.get("choice_buttons") as Array
    _assert_true(((choice_buttons[0] as Button).get_node("GiftIcon") as TextureRect).texture != null, "Level-up cards display authored icons")
    _assert_true((choice_buttons[1] as Button).position.x > (choice_buttons[0] as Button).position.x + 50.0, "Upgrade choices are arranged horizontally")
    var key_right: InputEventKey = InputEventKey.new()
    key_right.pressed = true
    key_right.keycode = KEY_RIGHT
    game.call("_input", key_right)
    _assert_equal_int(int(game.get("reward_focus_index")), 1, "Right arrow moves reward selection")
    key_right.keycode = KEY_LEFT
    game.call("_input", key_right)
    _assert_equal_int(int(game.get("reward_focus_index")), 0, "Left arrow moves reward selection")
    game.call("_select_choice", 99)
    _assert_true(bool(game.get("choice_open")), "Invalid choice index cannot dismiss the level-up overlay")
    _assert_equal_int(int(game.get("pending_level_ups")), 1, "Invalid choice index does not consume a level")

    game.call("_select_choice", 0)
    await process_frame
    _assert_true(not bool(game.get("choice_open")), "Choosing a mutation resumes time survival")
    _assert_equal_int(game_hero.level, 2, "Level-up choice evolves the main plant")

    game.set("survival_elapsed", 31.0)
    game.call("_spawn_time_milestones")
    _assert_true(bool(game.get("first_elite_spawned")), "Thirty-second elite milestone triggers")

    var spawned: GreedEnemy = game.call("_spawn_survivor_enemy", false, false) as GreedEnemy
    await process_frame
    _assert_true(spawned != null and is_instance_valid(spawned), "Continuous survivor spawner creates enemies")
    _assert_true(spawned.get_parent() == game.get_node("World/Runtime/Enemies"), "Spawned enemy enters the enemy container")
    _assert_true(not spawned.elite and not spawned.boss, "Regular timed spawns are not forced elites")
    _assert_true(spawned.has_node("PixelSprite"), "Spawned enemies receive a pixel sprite")

    var spatial_index: GreedEnemySpatialIndex = game.get_node("GreedEnemySpatialIndex") as GreedEnemySpatialIndex
    _assert_true(spatial_index != null, "Arena has the enemy spatial index")
    if spatial_index != null:
        spatial_index._rebuild_cells()
        _assert_true(spatial_index.query_radius(spawned.global_position, 10.0).has(spawned), "Spatial query finds nearby active enemies")
        _assert_true(spatial_index.query_radius(spawned.global_position + Vector2(220.0, 0.0), 10.0).is_empty(), "Spatial query excludes distant enemies")

    var spawned_gem: SurvivorExperienceGem = game.call("_spawn_experience_gem", game_hero.global_position + Vector2(40.0, 0.0), 1) as SurvivorExperienceGem
    await process_frame
    _assert_true(spawned_gem.get_parent() == game.get_node("World/Runtime/Pickups"), "Experience gem enters the pickup container")

    game.set("final_boss_spawned", true)
    game.set("final_boss_defeated", true)
    game.call("_process", 0.016)
    _assert_true(bool(game.get("game_ended")), "Defeating the final boss ends the run without chasing leftover minions")

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
