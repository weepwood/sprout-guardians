extends SceneTree

var _failures: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    print("Running Sprout Guardians UI smoke tests...")
    _remove_user_file(SettingsService.DEFAULT_PATH)
    _remove_user_file(SaveGameService.DEFAULT_SAVE_PATH)
    _remove_user_file(SaveGameService.DEFAULT_BACKUP_PATH)

    await _test_main_menu()
    await _test_level_select()
    await _test_survivor_scene()

    Engine.time_scale = 1.0
    _remove_user_file(SettingsService.DEFAULT_PATH)
    _remove_user_file(SaveGameService.DEFAULT_SAVE_PATH)
    _remove_user_file(SaveGameService.DEFAULT_BACKUP_PATH)

    if _failures > 0:
        push_error("UI smoke tests failed: %d" % _failures)
        quit(1)
        return
    print("All Sprout Guardians UI smoke tests passed.")
    quit(0)


func _test_main_menu() -> void:
    var menu: Node = await _instantiate_scene("res://scenes/main_menu.tscn", "Main menu")
    if menu == null:
        return

    var localization: LocalizationService = menu.get("localization") as LocalizationService
    var initial_locale: String = localization.locale_code
    menu.call("_toggle_language")
    await process_frame

    _assert_true(localization.locale_code != initial_locale, "Main-menu language button changes locale")
    var title: Label = menu.get("title_label") as Label
    var expected_title: String = "芽芽守卫战" if localization.locale_code == "zh_CN" else "SPROUT GUARDIANS"
    _assert_equal_string(title.text, expected_title, "Main-menu title updates immediately")
    var difficulty_picker: OptionButton = menu.get("difficulty_picker") as OptionButton
    _assert_equal_int(difficulty_picker.item_count, 3, "Three difficulty tiers remain")
    _assert_equal_string(difficulty_picker.get_item_text(0), "简单" if localization.locale_code == "zh_CN" else "Easy", "Easy mode is explicitly labeled")
    var menu_button_style: StyleBoxFlat = (menu.get("play_button") as Button).get_theme_stylebox("normal") as StyleBoxFlat
    _assert_true(menu_button_style != null and menu_button_style.corner_radius_top_left >= 12, "Play button uses rounded toy-like theme")
    _assert_true((menu.get("play_button") as Button).has_focus(), "Main menu starts with a keyboard-friendly focused action")

    menu.call("_show_character_screen")
    await process_frame
    var selection: Control = menu.get("character_screen") as Control
    _assert_true(selection != null and selection.visible, "Dedicated hero screen opens")
    _assert_true(not (menu.get("play_button") as Button).visible, "Hero screen hides main actions")
    menu.call("_hide_character_screen")
    await process_frame
    _assert_true((menu.get("play_button") as Button).visible, "Hero screen closes and restores menu")
    menu.call("_show_collection_summary")
    await process_frame
    var archive_panel: Panel = menu.get("archive_panel") as Panel
    var archive_summary: Label = menu.get("archive_summary") as Label
    _assert_true(archive_panel.visible, "Garden journal opens as a real modal")
    _assert_true(archive_summary.text.contains("RUNS") or archive_summary.text.contains("累计挑战"), "Journal displays persistent run statistics")
    _assert_control_inside_viewport(archive_panel, "Garden journal stays inside viewport")
    menu.call("_hide_archive")
    await process_frame
    _assert_true(not archive_panel.visible, "Garden journal closes correctly")

    menu.call("_show_settings")
    await process_frame
    var backdrop: ColorRect = menu.get("settings_backdrop") as ColorRect
    var panel: Panel = menu.get("settings_panel") as Panel
    var play_button: Button = menu.get("play_button") as Button
    var settings_title: Label = menu.get("settings_title_label") as Label
    _assert_true(backdrop.visible, "Settings modal backdrop is visible")
    _assert_true(panel.visible, "Settings modal panel is visible")
    _assert_true(not play_button.visible, "Main menu actions are hidden behind settings")
    _assert_true(settings_title.visible, "Settings title is visible")
    _assert_control_inside_viewport(panel, "Settings panel stays inside viewport")

    menu.call("_hide_settings")
    await process_frame
    _assert_true(not panel.visible and play_button.visible, "Closing settings restores main menu")

    menu.queue_free()
    await process_frame


func _test_level_select() -> void:
    var level_select: Node = await _instantiate_scene("res://scenes/level_select.tscn", "Legacy level select")
    if level_select == null:
        return

    var localization: LocalizationService = level_select.get("localization") as LocalizationService
    var initial_locale: String = localization.locale_code
    level_select.call("_toggle_language")
    await process_frame

    _assert_true(localization.locale_code != initial_locale, "Legacy level-select language button changes locale")
    var level_buttons: Array = level_select.get("level_buttons") as Array
    _assert_equal_int(level_buttons.size(), 3, "Legacy campaign data remains loadable for regression comparison")

    level_select.queue_free()
    await process_frame


func _test_survivor_scene() -> void:
    var game: Node = await _instantiate_scene("res://scenes/main.tscn", "Plant survivors arena")
    if game == null:
        return

    var localization: LocalizationService = game.get("i18n") as LocalizationService
    var initial_locale: String = localization.locale_code
    game.call("_toggle_language")
    await process_frame
    _assert_true(localization.locale_code != initial_locale, "Plant survivors language button changes locale")

    var hero: GreedHeroPlant = game.get("hero_plant") as GreedHeroPlant
    var familiars: Array = game.get("plants") as Array
    _assert_true(hero != null, "Survivor run starts with one controllable main plant")
    _assert_equal_int(familiars.size(), 2, "Secondary plants remain two floating familiars")
    _assert_true(bool(game.get("wave_active")), "Time-survival combat starts immediately")
    var top_frame: Panel = game.get_node("UI/TopHUD/Frame") as Panel
    _assert_true(top_frame != null, "Survivors HUD has a themeable top capsule")
    var hud_style: StyleBoxFlat = top_frame.get_theme_stylebox("panel") as StyleBoxFlat
    _assert_true(hud_style != null and hud_style.corner_radius_top_left >= 10, "Survivors HUD uses rounded cards")
    _assert_true(game.find_child("StartWaveButton", true, false) == null, "Survivor mode has no manual wave control")
    _assert_true(game.find_child("UpgradeButton", true, false) == null, "Survivor mode has no manual upgrade control")
    _assert_true(game.find_child("BuildBar", true, false) == null, "Survivor mode has no tower build bar")

    var input_controller: SurvivorInputController = game.get_node("RunInput") as SurvivorInputController
    var initial_position: Vector2 = hero.global_position
    input_controller.set_test_direction(Vector2.RIGHT)
    game.call("_apply_continuous_movement")
    hero._process(0.25)
    _assert_true(hero.global_position.x > initial_position.x, "WASD immediately moves the hero")
    input_controller.set_test_direction(Vector2.ZERO)
    game.call("_apply_continuous_movement")
    var stopped_position: Vector2 = hero.global_position
    hero._process(0.2)
    _assert_true(hero.global_position.distance_to(stopped_position) < 0.01, "Input release stops the hero immediately")
    input_controller.clear_test_direction()
    _assert_true(not (game.get_node("UI/BuildPanel") as Panel).visible, "Build details do not obstruct gameplay")
    _assert_true(game.get_node("World/ArenaGround") is TextureRect, "Garden floor is a reusable image asset")
    var bg: TextureRect = game.get_node("World/ArenaGround") as TextureRect
    _assert_true(bg.texture != null and bg.size.x >= 640.0, "Garden artwork covers the whole battle viewport")
    var warning: Panel = game.get_node("UI/WarningFrame") as Panel
    game.call("_show_event_banner", "TEST WAVE", 2.5)
    _assert_true(warning.visible, "Timed wave warning becomes visible")
    _assert_true((game.get("status_label") as Label).text == "TEST WAVE", "Wave warning displays the event text")
    game.set("_warning_seconds", 0.0)
    game.call("_process", 0.016)
    _assert_true(not warning.visible, "Wave warning clears without occupying permanent HUD space")
    var on_edge: Vector2 = game.call("_survivor_spawn_edge") as Vector2
    _assert_true(on_edge.distance_to(hero.global_position) >= 112.0, "Enemies spawn away from player when safe edge is available")

    game.call("_toggle_pause")
    _assert_true(bool(game.get("pause_open")), "Pause opens the new cozy overlay")
    _assert_true((game.get("pause_panel") as Panel).visible, "Pause dialog becomes visible")
    _assert_true(hero.process_mode == Node.PROCESS_MODE_DISABLED, "Pausing freezes the main plant")
    var timer_before_pause: float = float(game.get("survival_elapsed"))
    game.call("_process", 0.5)
    _assert_true(absf(float(game.get("survival_elapsed")) - timer_before_pause) < 0.001, "Survival timer stops while paused")
    game.call("_toggle_pause")
    _assert_true(not bool(game.get("pause_open")), "Resume closes the pause overlay")
    _assert_true(hero.process_mode != Node.PROCESS_MODE_DISABLED, "Resume restores gameplay processing")

    game.set("survival_spawn_timer", 0.0)
    await process_frame
    await process_frame
    var enemies: Array[Node] = get_nodes_in_group("greed_enemies")
    _assert_true(enemies.size() >= 1, "Enemies continuously enter from arena borders")
    var fake_click: InputEventMouseButton = InputEventMouseButton.new()
    fake_click.button_index = MOUSE_BUTTON_LEFT
    fake_click.pressed = true
    fake_click.position = Vector2(220, 140)
    game.call("_unhandled_input", fake_click)
    _assert_true(hero.get_focus_target() == null, "Mouse clicks never manually lock targets in survivors")
    _assert_true(not hero.has_move_target, "Mouse clicks do not assign a movement destination")
    for familiar_value: Variant in familiars:
        var familiar: GreedPlant = familiar_value as GreedPlant
        _assert_true(familiar.focus_source == hero, "Familiars inherit hero proximity targeting")

    game.call("_on_experience_collected", 8)
    await process_frame
    var choice_panel: Panel = game.get("choice_panel") as Panel
    var choice_buttons: Array = game.get("choice_buttons") as Array
    _assert_true(bool(game.get("choice_open")), "Collecting enough experience opens a level-up choice")
    _assert_true(choice_panel.visible, "Level-up overlay is visible")
    var reward_style: StyleBoxFlat = choice_panel.get_theme_stylebox("panel") as StyleBoxFlat
    _assert_true(reward_style != null and reward_style.corner_radius_top_left >= 14, "Reward card shares the warm rounded style")
    _assert_equal_int(choice_buttons.size(), 3, "Level-up presents three mutation choices")
    _assert_true((choice_buttons[0] as Button).get_node("GiftIcon") is TextureRect, "Reward card contains a separate illustration")
    _assert_true((choice_buttons[0] as Button).position.y == (choice_buttons[1] as Button).position.y, "Reward cards share a horizontal baseline")
    _assert_true((choice_buttons[2] as Button).position.x > (choice_buttons[1] as Button).position.x, "Third card sits to the right")
    _assert_true((game.get("choice_hint") as Label).visible, "Reward selection shows keyboard instructions")
    _assert_control_inside_viewport(choice_panel, "Level-up reward panel stays inside viewport")

    var choices: Array = game.get("_current_choices") as Array
    var selected_blessing: BlessingData = choices[0] as BlessingData
    var hero_level_before: int = hero.level
    game.call("_select_choice", 0)
    await process_frame

    var blessings: BlessingSystem = game.get("blessing_system") as BlessingSystem
    _assert_true(not bool(game.get("choice_open")), "Choosing a mutation resumes survival")
    _assert_true(not choice_panel.visible, "Choosing a mutation closes the level-up overlay")
    _assert_true(not (game.get("choice_hint") as Label).visible, "Keyboard reward instructions disappear after picking")
    _assert_equal_int(blessings.get_blessing_stack(selected_blessing.id), 1, "Chosen mutation modifies the run")
    _assert_equal_int(hero.level, hero_level_before + 1, "Level-up choice evolves the main plant")

    var wave_label: Label = game.get("wave_label") as Label
    var greed_label: Label = game.get("greed_label") as Label
    _assert_true(wave_label.text.contains("TIME") or wave_label.text.contains("时间"), "HUD displays survival time")
    _assert_true(greed_label.text.contains("XP") or greed_label.text.contains("经验"), "HUD displays level and experience")

    var effects: PixelImpactSystem = game.get("impact_system") as PixelImpactSystem
    effects.spawn_hit(Vector2(320.0, 180.0), Color("ffffff"), 25.0, true)
    _assert_true(effects.get_active_particle_count() > 0, "Critical survivor impact creates pixel particles")
    _assert_true(effects.get_active_particle_count() <= effects.max_particles, "Survivor particles remain bounded")

    var control_label: Label = game.get("control_label") as Label
    var language_button: Button = game.get("language_button") as Button
    var speed_button: Button = game.get("speed_button") as Button
    var menu_button: Button = game.get("menu_button") as Button
    _assert_control_inside_viewport(control_label, "Survivor-control guidance stays inside viewport")
    _assert_control_inside_viewport(language_button, "Survivor language button stays inside viewport")
    _assert_control_inside_viewport(speed_button, "Survivor speed button stays inside viewport")
    _assert_control_inside_viewport(menu_button, "Survivor menu button stays inside viewport")

    game.queue_free()
    await process_frame


func _instantiate_scene(path: String, label: String):
    var packed: PackedScene = load(path) as PackedScene
    if packed == null:
        _failures += 1
        push_error("FAIL: %s scene could not load" % label)
        return null
    var instance: Node = packed.instantiate()
    root.add_child(instance)
    await process_frame
    await process_frame
    _assert_true(is_instance_valid(instance), "%s scene instantiates" % label)
    return instance


func _assert_control_inside_viewport(control: Control, message: String) -> void:
    if control == null:
        _assert_true(false, message + " (control missing)")
        return
    var rect: Rect2 = control.get_global_rect()
    var inside: bool = rect.position.x >= -0.5 and rect.position.y >= -0.5
    inside = inside and rect.end.x <= 640.5 and rect.end.y <= 360.5
    _assert_true(inside, "%s (rect %s)" % [message, rect])


func _remove_user_file(path: String) -> void:
    var absolute: String = ProjectSettings.globalize_path(path)
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(absolute)


func _assert_true(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)


func _assert_equal_int(actual: int, expected: int, message: String) -> void:
    _assert_true(actual == expected, "%s (expected %d, got %d)" % [message, expected, actual])


func _assert_equal_string(actual: String, expected: String, message: String) -> void:
    _assert_true(actual == expected, "%s (expected '%s', got '%s')" % [message, expected, actual])
