extends SceneTree

# Full real gameplay path, not simulation_mode. Scripted input, not human play.
# Run only with isolated test saves locally; CI has its own user:// directory.
const OUT: String = "res://build/player-replay"
const DIRECTIONS: Array[StringName] = [&"ui_right", &"ui_down", &"ui_left", &"ui_up"]
var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _release_input() -> void:
    for action: StringName in DIRECTIONS:
        Input.action_release(action)

func _run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    for tier: int in [0, 1]:
        var settings: SettingsService = SettingsService.new()
        settings.load_settings()
        settings.survivor_difficulty = tier
        settings.survivor_character = 0
        settings.survivor_map = 0
        settings.save_settings()
        SurvivorBalance.selected_difficulty = tier
        SurvivorCharacters.selected = 0
        SurvivorMaps.selected = 0
        SurvivorChallenge.selected = false
        SurvivorEndurance.selected = false
        var game: Node = packed.instantiate()
        game.set("run_seed", 101)
        root.add_child(game)
        await process_frame
        var hero: GreedHeroPlant = game.get("hero_plant") as GreedHeroPlant
        var start: Vector2 = hero.global_position
        var rewards: int = 0
        var moved: bool = false
        var last_action: int = -1
        for frame: int in range(60 * 130):
            if bool(game.get("game_ended")):
                break
            if bool(game.get("choice_open")):
                _release_input()
                last_action = -1
                var press: InputEventKey = InputEventKey.new()
                press.keycode = KEY_ENTER
                press.pressed = true
                Input.parse_input_event(press)
                await process_frame
                var release: InputEventKey = InputEventKey.new()
                release.keycode = KEY_ENTER
                release.pressed = false
                Input.parse_input_event(release)
                rewards += 1
                continue
            var action: int = posmod(floori(float(game.get("survival_elapsed")) / 1.35), DIRECTIONS.size())
            if action != last_action:
                _release_input()
                Input.action_press(DIRECTIONS[action])
                last_action = action
            await process_frame
            moved = moved or hero.global_position.distance_to(start) > 20.0
        _release_input()
        var blessings: BlessingSystem = game.get("blessing_system") as BlessingSystem
        var evolved: int = 0
        for i: int in range(SurvivorArsenal.IDS.size()):
            if SurvivorArsenal.evolved(blessings, i):
                evolved += 1
        var result: Dictionary = {"difficulty":tier,"actual_input":true,"simulation_mode":game.get("simulation_mode"),"elapsed":game.get("survival_elapsed"),"moved":moved,"rewards":rewards,"level":hero.level,"kills":game.get("enemies_defeated"),"victory":game.get("final_boss_defeated"),"evolutions":evolved,"ended":game.get("game_ended")}
        print("PLAYER_REPLAY ", JSON.stringify(result))
        if not moved or rewards <= 0 or not bool(result["ended"]) or bool(result["simulation_mode"]):
            failures += 1
        if DisplayServer.get_name() != "headless":
            RenderingServer.force_draw(false)
            await process_frame
            var img: Image = root.get_texture().get_image()
            if img != null and not img.is_empty():
                img.save_png(ProjectSettings.globalize_path(OUT + "/result-%d.png" % tier))
        game.queue_free()
        await process_frame
        await process_frame
    print("PLAYER_REPLAY_SUMMARY failures=", failures)
    quit(0 if failures == 0 else 1)
