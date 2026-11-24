extends SceneTree

# Actual Godot renderer, no concept-image substitutes.
const OUT: String = "res://build/visual"
var failed: bool = false

func _initialize() -> void:
    call_deferred("_run")

func _capture(name_value: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var img: Image = root.get_texture().get_image()
    if img == null or img.is_empty():
        push_error("Empty rendered screenshot: " + name_value)
        failed = true
        return
    if img.save_png(ProjectSettings.globalize_path(OUT + "/" + name_value + ".png")) != OK:
        failed = true
    print("RENDER_CAPTURE ", name_value, " ", img.get_size())

func _run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    var menu_scene: PackedScene = load("res://scenes/main_menu.tscn") as PackedScene
    var menu: Node = menu_scene.instantiate()
    root.add_child(menu)
    await _capture("01-menu")
    menu.call("_show_character_screen")
    await _capture("02-hero-selection")
    menu.call("_hide_character_screen")
    menu.call("_show_collection_summary")
    await _capture("03-archive")
    menu.queue_free()
    await process_frame
    SurvivorBalance.selected_difficulty = 0
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    var game: Node = packed.instantiate()
    game.set("simulation_mode", true)
    game.set("simulation_map", 1)
    game.set("run_seed", 101)
    root.add_child(game)
    var hero: GreedHeroPlant = game.get("hero_plant") as GreedHeroPlant
    var combat_captured: bool = false
    var reward_captured: bool = false
    for i: int in range(60 * 130):
        if bool(game.get("game_ended")):
            break
        if bool(game.get("choice_open")):
            if not reward_captured:
                var title: Label = game.get_node("UI/ChoiceLayer/ChoiceButton0/GiftName") as Label
                var detail: Label = game.get_node("UI/ChoiceLayer/ChoiceButton0/GiftDetail") as Label
                var card: Button = game.get_node("UI/ChoiceLayer/ChoiceButton0") as Button
                var rarity: Label = card.get_node("GiftRarity") as Label
                for state: String in ["normal", "hover", "pressed"]:
                    var surface: StyleBoxFlat = card.get_theme_stylebox(state) as StyleBoxFlat
                    if surface == null:
                        failed = true
                        continue
                    for label: Label in [title, detail, rarity]:
                        var ratio: float = PlayfulUITheme.contrast_ratio(label.get_theme_color("font_color"), surface.bg_color)
                        print("REWARD_CONTRAST ", state, " ", label.name, " ", ratio)
                        if ratio < 4.5:
                            push_error("Reward card text contrast below 4.5:1")
                            failed = true
                await _capture("05-reward")
                reward_captured = true
            var choices: Array = game.get("_current_choices")
            if not choices.is_empty():
                game.call("_select_choice", 0)
        var target: Vector2 = Vector2(640, 360) + Vector2(cos(float(i) / 110.0) * 170.0, sin(float(i) / 110.0) * 95.0)
        game.set("simulation_direction", (target - hero.global_position).limit_length(1.0))
        await process_frame
        if not combat_captured and float(game.get("survival_elapsed")) >= 6.0 and not bool(game.get("choice_open")):
            await _capture("04-combat")
            combat_captured = true
    if bool(game.get("game_ended")):
        await _capture("06-result")
    else:
        failed = true
    game.queue_free()
    await process_frame
    quit(0 if not failed and combat_captured and reward_captured else 1)
