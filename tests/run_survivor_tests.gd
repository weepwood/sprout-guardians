extends SceneTree

var _failures: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    print("Running plant survivors tests...")
    _test_balance()
    _test_pool()
    _test_arsenal()
    _test_character_profiles()
    _test_growth_assist()
    _test_map_events_and_progress()
    _test_animation_and_boss_profiles()
    _test_pool_pressure()
    _test_endurance_rules()
    _test_visual_theme()
    for mutation_id: StringName in SurvivorArsenal.IDS:
        var icon: AtlasTexture = PixelArtAssets.blessing_icon(mutation_id) as AtlasTexture
        _assert_true(icon != null and icon.atlas == PixelArtAssets.MUTATION_ATLAS and icon.region.size == Vector2(56, 56), "Generated mutation PNG region: %s" % mutation_id)
    _test_difficulty_settings()

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

    SurvivorMaps.selected = SurvivorMaps.CLASSIC
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
    for edge_sample: int in range(20):
        var edge_spawn: Vector2 = game.call("_survivor_spawn_edge") as Vector2
        _assert_true(edge_spawn.distance_to(game_hero.global_position) >= 112.0, "Edge spawns preserve minimum distance: %d" % edge_sample)
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
    game.call("_reroll_reward")
    _assert_equal_int(int(game.get("reward_rerolls")), 1, "Reroll consumes one run-limited charge")
    _assert_equal_int(int(game.get("pending_level_ups")), 1, "Reroll preserves the pending level")
    _assert_true(bool(game.get("choice_open")), "Reroll preserves the reward overlay")
    game.call("_reroll_reward")
    game.call("_reroll_reward")
    _assert_equal_int(int(game.get("reward_rerolls")), 0, "Reroll cannot exceed run budget")
    game.call("_select_choice", 99)
    _assert_true(bool(game.get("choice_open")), "Invalid choice index cannot dismiss the level-up overlay")
    _assert_equal_int(int(game.get("pending_level_ups")), 1, "Invalid choice index does not consume a level")

    game.call("_select_choice", 0)
    await process_frame
    _assert_true(not bool(game.get("choice_open")), "Choosing a mutation resumes time survival")
    _assert_equal_int(game_hero.level, 2, "Level-up choice evolves the main plant")

    game.call("_on_experience_collected", int(game.get("experience_to_next")))
    _assert_true(bool(game.get("choice_open")), "Next upgrade opens after choosing a reward")
    game.call("_skip_reward")
    _assert_true(not bool(game.get("choice_open")), "Skipping a reward resumes combat")
    _assert_equal_int(int(game.get("pending_level_ups")), 0, "Skip consumes one pending upgrade")
    _assert_equal_int(game_hero.level, 3, "Skip preserves base level growth")

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
        var stale_position: Vector2 = spawned.global_position
        var stale_id: int = spawned.get_instance_id()
        spawned.free()
        _assert_true(not is_instance_id_valid(stale_id), "Enemy reference was released")
        spatial_index.query_radius(stale_position, 12.0)
        _assert_true(true, "Spatial query tolerates stale instance IDs")

    var spawned_gem: SurvivorExperienceGem = game.call("_spawn_experience_gem", game_hero.global_position + Vector2(40.0, 0.0), 1) as SurvivorExperienceGem
    await process_frame
    _assert_true(spawned_gem.get_parent() == game.get_node("World/Runtime/Pickups"), "Experience gem enters the pickup container")

    game.set("final_boss_spawned", true)
    game.set("final_boss_defeated", true)
    game.call("_process", 0.016)
    _assert_true(bool(game.get("game_ended")), "Defeating the final boss ends the run without chasing leftover minions")

    game.queue_free()
    await process_frame
    SurvivorMaps.selected = SurvivorMaps.EXPLORATION
    var exploration: Node = packed.instantiate()
    root.add_child(exploration)
    await process_frame
    var explorer: GreedHeroPlant = exploration.get("hero_plant") as GreedHeroPlant
    _assert_true(explorer.movement_bounds == SurvivorMaps.movement_bounds(1), "Exploration uses expanded movement bounds")
    _assert_true(exploration.get("world_camera") is Camera2D, "Exploration activates follow camera")
    _assert_true((exploration.get_node("World/ArenaGround") as TextureRect).size == Vector2(1280, 720), "Generated terrain fills expanded world")
    for point_index: int in range(20):
        var spawn: Vector2 = exploration.call("_survivor_spawn_edge")
        _assert_true(Rect2(Vector2.ZERO, SurvivorMaps.EXPLORATION_SIZE).has_point(spawn), "Exploration enemy spawns stay inside world")
        _assert_true(spawn.distance_to(explorer.global_position) >= 112.0, "Exploration spawn remains fair")
    exploration.queue_free()
    SurvivorMaps.selected = SurvivorMaps.CLASSIC
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


func _test_balance() -> void:
    for difficulty: int in range(3):
        var previous: float = 0.0
        for second: int in range(91):
            var config: Dictionary = SurvivorBalance.enemy_config(float(second), difficulty, false, false)
            _assert_true(not config["elite"] and not config["boss"], "Ordinary spawn never inherits elite flags")
            _assert_true(float(config["health"]) >= previous, "Baseline HP curve is monotonic")
            previous = float(config["health"])
        for seed_value: int in range(20):
            var a: SurvivorSpawnDirector = SurvivorSpawnDirector.new()
            var b: SurvivorSpawnDirector = SurvivorSpawnDirector.new()
            a.configure(difficulty, seed_value)
            b.configure(difficulty, seed_value)
            for second: int in range(90):
                _assert_true(a.next_enemy(float(second), false, false) == b.next_enemy(float(second), false, false), "Seeded enemy sequence repeats")
    _assert_true(SurvivorBalance.spawn_interval(0.0, 0) > SurvivorBalance.spawn_interval(0.0, 2), "Casual spawns more slowly")


func _test_pool() -> void:
    var pool: SurvivorNodePool = SurvivorNodePool.new()
    var scene: PackedScene = load("res://scenes/effects/experience_gem.tscn") as PackedScene
    var holder: Node2D = Node2D.new()
    root.add_child(holder)
    var first: SurvivorExperienceGem = pool.acquire(scene, holder) as SurvivorExperienceGem
    first.recycle = pool.release
    first.configure(null, 2)
    first.age = 44.0
    first._process(2.0)
    _assert_true(not first.visible and not first.is_in_group("survivor_experience"), "Expired pickup is inactive and removed from active group")
    var second: SurvivorExperienceGem = pool.acquire(scene, holder) as SurvivorExperienceGem
    second.configure(null, 3)
    _assert_true(first == second and second.age == 0.0 and second.visible, "Pooled pickup resets age and visibility")
    _assert_equal_int(pool.created, 1, "Pool creates only one node")
    holder.queue_free()


func _test_arsenal() -> void:
    var system: BlessingSystem = BlessingSystem.new()
    var rewards: Array[BlessingData] = SurvivorArsenal.reward_pool()
    system.setup(rewards, 123)
    _assert_equal_int(rewards.size(), 6, "Six distinct mutation families")
    for i: int in range(3):
        system.apply_blessing(rewards[0])
    _assert_true(not SurvivorArsenal.evolved(system, 0), "Evolution requires partner")
    system.apply_blessing(rewards[2])
    _assert_true(SurvivorArsenal.evolved(system, 0), "Seed and frost unlock evolution")
    system.free()


func _test_difficulty_settings() -> void:
    var service: SettingsService = SettingsService.new()
    service.settings_path = "user://survivor_difficulty_test.cfg"
    service.survivor_difficulty = 2
    _assert_true(service.save_settings(), "Difficulty settings save")
    service.survivor_difficulty = 0
    service.load_settings()
    _assert_equal_int(service.survivor_difficulty, 2, "Difficulty persists across reload")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(service.settings_path))


func _test_character_profiles() -> void:
    for i: int in range(3):
        var config: Dictionary = SurvivorCharacters.configuration(i)
        _assert_equal_int(int(config["character_index"]), i, "Character configuration matches selection")
        _assert_true(PixelArtAssets.generated_actor(i) != null, "Generated character art resolves")
    _assert_true(float(SurvivorCharacters.configuration(1)["splash_radius"]) > 0.0, "Sunflower has area shots")
    _assert_true(float(SurvivorCharacters.configuration(2)["slow_ratio"]) > 0.0, "Frostflower has slow shots")


func _test_growth_assist() -> void:
    _assert_true(is_equal_approx(SurvivorExperienceGem.effective_magnet_radius(0.0, 1), 122.0), "Fresh gems retain immediate pickup radius")
    _assert_true(SurvivorExperienceGem.effective_magnet_radius(3.0, 1) >= 340.0, "Starter drops gradually magnetize from long range")
    _assert_true(SurvivorExperienceGem.effective_magnet_radius(6.0, 2) < 340.0, "Later progression retains incentive to move")


func _test_map_events_and_progress() -> void:
    var events: SurvivorMapEvents = SurvivorMapEvents.new()
    _assert_equal_int(events.due(15.0), -1, "Map event waits until scheduled time")
    _assert_equal_int(events.due(16.0), SurvivorMapEvents.Kind.CHEST, "Chest event fires")
    _assert_equal_int(events.due(16.0), -1, "Chest event does not repeat")
    events.start_challenge(68.0, 20)
    _assert_equal_int(events.challenge_result(75.0, 30), 1, "Challenge completes once")
    _assert_equal_int(events.challenge_result(75.0, 30), 0, "Challenge reward cannot be repeated")
    events.start_challenge(68.0, 20)
    _assert_equal_int(events.challenge_result(81.0, 25), -1, "Expired challenge fails")
    for map_id: int in range(1, 4):
        _assert_true(PixelArtAssets.biome_texture(map_id) != null, "Generated biome texture loads")
        _assert_true(SurvivorMaps.world_size(map_id) == Vector2(1280, 720), "Biome world size")
    var service: SaveGameService = SaveGameService.new()
    service.save_path = "user://survivor_progress_test.json"
    service.backup_path = "user://survivor_progress_test.bak"
    DirAccess.remove_absolute(ProjectSettings.globalize_path(service.save_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(service.backup_path))
    service.load_game()
    _assert_true(not service.is_survivor_character_unlocked(3), "New hybrid character starts locked")
    _assert_true(service.record_survivor_result(true, 95, 8, 100, {"events": 2, "evolutions": 1}), "Progress records with run")
    _assert_true(service.is_survivor_character_unlocked(3), "Victory unlocks hybrid character")
    _assert_true(service.buy_survivor_upgrade("health_rank"), "Earned seeds buy upgrade")
    service.load_game()
    _assert_equal_int(int(service.get_survivor_progress()["health_rank"]), 1, "Upgrade persists")
    _assert_true(not service.buy_survivor_upgrade("health_rank"), "Insufficient seeds cannot buy upgrade")
    _assert_true(service.claim_achievement("first_win"), "First victory achievement can be claimed")
    _assert_true(not service.claim_achievement("first_win"), "Achievement cannot be claimed twice")
    _assert_true(service.buy_survivor_upgrade("speed_rank"), "Earned seeds buy speed upgrade")
    service.load_game()
    _assert_equal_int(int(service.get_survivor_progress()["speed_rank"]), 1, "Speed upgrade persists")
    _assert_true(not service.achievement_available("first_win"), "Claim state persists")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(service.save_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(service.backup_path))


func _test_animation_and_boss_profiles() -> void:
    for state: int in range(5):
        for frame_index: int in range(4):
            var icon: AtlasTexture = SurvivorAnimation.frame(0, state, (float(frame_index) + 0.01) / (16.0 if state >= 2 else 9.0)) as AtlasTexture
            _assert_true(icon != null and icon.region.size == Vector2(36, 36), "Generated animation frame resolves")
            if icon != null:
                _assert_true(icon.region.position == Vector2(frame_index * 36, state * 36), "Generated frame index is correct")
    var death: AtlasTexture = SurvivorAnimation.frame(0, SurvivorAnimation.State.DEATH, 10.0) as AtlasTexture
    _assert_true(death != null and death.region.position.x == 108.0, "Death animation does not loop")
    _assert_true(float(SurvivorBiomeBoss.profile(1)["hp"]) > 1.0, "Forest boss emphasizes durability")
    _assert_true(float(SurvivorBiomeBoss.profile(2)["cooldown"]) < 4.2, "Night boss emphasizes attack tempo")
    _assert_true(float(SurvivorBiomeBoss.profile(3)["warning"]) > 0.9, "Swamp boss allows longer warning")
    _assert_true(float(SurvivorCharacters.configuration(2)["move_speed"]) > float(SurvivorCharacters.configuration(1)["move_speed"]), "Character movement profiles differ")


func _test_pool_pressure() -> void:
    var pool: SurvivorNodePool = SurvivorNodePool.new()
    pool.capacity = 32
    var scene: PackedScene = load("res://scenes/effects/experience_gem.tscn") as PackedScene
    var holder: Node2D = Node2D.new()
    root.add_child(holder)
    for cycle: int in range(5000):
        var item: Node2D = pool.acquire(scene, holder)
        pool.release(item)
    _assert_equal_int(pool.created, 1, "5000 cycles create one reusable node")
    _assert_equal_int(pool.reused, 4999, "5000 cycles reuse 4999 times")
    var batch: Array[Node2D] = []
    for i: int in range(64):
        batch.append(pool.acquire(scene, holder))
    for item: Node2D in batch:
        pool.release(item)
        pool.release(item)
    var metrics: Dictionary = pool.metrics()
    _assert_equal_int(int(metrics["active"]), 0, "Burst releases all active nodes")
    _assert_equal_int(int(metrics["peak_active"]), 64, "Tracks burst peak")
    _assert_equal_int(int(metrics["idle"]), 32, "Idle capacity is bounded")
    _assert_equal_int(int(metrics["discarded"]), 32, "Over-capacity nodes are discarded once")
    holder.queue_free()


func _test_endurance_rules() -> void:
    _assert_equal_int(SurvivorEndurance.stage(179.0), 1, "Endurance stage before second boss")
    _assert_true(SurvivorEndurance.boss_due(180.0, 1), "Second boss due after 180 seconds")
    _assert_true(not SurvivorEndurance.boss_due(179.9, 1), "Second boss does not spawn early")
    _assert_true(SurvivorEndurance.enemy_multiplier(360.0) > 1.0, "Endurance scales enemies")
    _assert_equal_int(SurvivorArsenal.reward_pool().size(), 6, "Classic reward pool stays unchanged")
    _assert_equal_int(SurvivorArsenal.reward_pool(true).size(), 8, "Endless gets two additional weapons")
    var barrage: AtlasTexture = PixelArtAssets.blessing_icon(&"mutation_barrage") as AtlasTexture
    var mist: AtlasTexture = PixelArtAssets.blessing_icon(&"mutation_mist") as AtlasTexture
    _assert_true(barrage != null and mist != null and barrage.region != mist.region and barrage.atlas == mist.atlas, "Endless weapons use two distinct generated PNG regions")
    _assert_equal_int(SurvivorChallenge.seed_for("2026-11-24"), 20261124, "Daily seed uses UTC date")
    for i: int in range(9):
        var tile: AtlasTexture = PixelArtAssets.biome_actor(i) as AtlasTexture
        _assert_true(tile != null and tile.region.size == Vector2(48, 48), "Generated biome art region resolves")


func _test_visual_theme() -> void:
    _assert_true(is_equal_approx(PlayfulUITheme.contrast_ratio(Color.BLACK, Color.WHITE), 21.0), "Black-white reference contrast is 21:1")
    _assert_true(is_equal_approx(PlayfulUITheme.contrast_ratio(Color.WHITE, Color.WHITE), 1.0), "Identical reference colors are 1:1")
    for background: Color in [Color("#fffaf1"), Color("#fff0d8"), Color("#eedebd")]:
        _assert_true(PlayfulUITheme.contrast_ratio(PlayfulUITheme.INK, background) >= 4.5, "Reward title contrast at least 4.5:1")
        _assert_true(PlayfulUITheme.contrast_ratio(Color("#665249"), background) >= 4.5, "Reward detail contrast at least 4.5:1")
        _assert_true(PlayfulUITheme.contrast_ratio(PlayfulUITheme.readable_on_light(Color("#ffd36d"), background), background) >= 4.5, "Bright rarity is darkened to readable contrast")
    _assert_equal_int(SurvivorSpawnDirector.swamp_ranged_cap(1), 4, "Swamp caps simultaneous ranged enemies")
    _assert_true(SurvivorEndurance.enemy_multiplier(900.0) < 3.2, "Endurance growth softens after six waves")
