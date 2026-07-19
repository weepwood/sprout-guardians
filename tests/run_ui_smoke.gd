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
    await _test_gameplay_scene()

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
    var level_select: Node = await _instantiate_scene("res://scenes/level_select.tscn", "Level select")
    if level_select == null:
        return

    var localization: LocalizationService = level_select.get("localization") as LocalizationService
    var initial_locale: String = localization.locale_code
    level_select.call("_toggle_language")
    await process_frame

    _assert_true(localization.locale_code != initial_locale, "Level-select language button changes locale")
    var title: Label = level_select.get("title_label") as Label
    var expected_title: String = "选择守护区域" if localization.locale_code == "zh_CN" else "CHOOSE A GARDEN"
    _assert_equal_string(title.text, expected_title, "Level-select title updates immediately")

    var level_buttons: Array = level_select.get("level_buttons") as Array
    _assert_equal_int(level_buttons.size(), 3, "Level select exposes three campaign slots")
    for button_value: Variant in level_buttons:
        var button: Button = button_value as Button
        _assert_control_inside_viewport(button, "Level button stays inside viewport")

    level_select.queue_free()
    await process_frame


func _test_gameplay_scene() -> void:
    var game: Node = await _instantiate_scene("res://scenes/main.tscn", "Autonomous gameplay")
    if game == null:
        return

    var localization: LocalizationService = game.get("i18n") as LocalizationService
    var initial_locale: String = localization.locale_code
    game.call("_toggle_language")
    await process_frame
    _assert_true(localization.locale_code != initial_locale, "Gameplay language button changes locale")

    var coins_label: Label = game.get("coins_label") as Label
    var expected_prefix: String = "阳光" if localization.locale_code == "zh_CN" else "Sunlight"
    _assert_true(coins_label.text.begins_with(expected_prefix), "Gameplay HUD updates after language switch")

    var start_button: Button = game.get("start_wave_button") as Button
    var auto_button: Button = game.get("auto_button") as Button
    var upgrade_button: Button = game.get("upgrade_button") as Button
    var sell_button: Button = game.get("sell_button") as Button
    var build_buttons: Array = game.get("tower_build_buttons") as Array
    _assert_true(not start_button.visible, "Manual Start Wave is removed from autonomous mode")
    _assert_true(not auto_button.visible, "Auto-wave cannot be disabled in autonomous mode")
    _assert_true(not upgrade_button.visible and not sell_button.visible, "Manual upgrade and sell controls are removed")
    for button_value: Variant in build_buttons:
        _assert_true(not (button_value as Button).visible, "Manual plant deployment controls are removed")

    var garden_director: AutonomousGardenDirector = game.get("garden_director") as AutonomousGardenDirector
    _assert_true(garden_director != null and garden_director.enabled, "Autonomous garden director starts enabled")
    garden_director.force_decision()
    await process_frame
    await process_frame

    var towers_by_slot: Dictionary = game.get("towers_by_slot") as Dictionary
    _assert_true(towers_by_slot.size() >= 1, "Director deploys the first plant without player input")

    var auto_director: AutoBattleDirector = game.get("auto_battle_director") as AutoBattleDirector
    _assert_true(auto_director != null and auto_director.auto_enabled, "Automatic wave flow is permanently enabled")
    auto_director._process(2.0)
    for _frame: int in range(6):
        await process_frame
    var wave_manager: WaveManager = game.get("wave_manager") as WaveManager
    _assert_true(wave_manager.current_wave_index >= 0, "First wave starts without pressing Start Wave")

    var rewards: CombatRewardSystem = game.get("combat_reward_system") as CombatRewardSystem
    rewards.grant_surprise_drop(1)
    await process_frame
    await process_frame

    var chest_panel: Panel = game.get("chest_panel") as Panel
    var chest_buttons: Array = game.get("chest_choice_buttons") as Array
    _assert_true(chest_panel.visible, "Surprise drop opens as the player's primary interaction")
    _assert_true(paused, "Surprise choice pauses all automation")
    _assert_equal_int(chest_buttons.size(), 3, "Surprise drop presents three choices")
    _assert_control_inside_viewport(chest_panel, "Surprise choice panel stays inside viewport")
    _assert_true(garden_director.blocked, "Garden director pauses while the player chooses")

    var choices: Array = game.get("_current_choices") as Array
    _assert_equal_int(choices.size(), 3, "Surprise drop contains three valid data entries")
    var selected: BlessingData = choices[0] as BlessingData
    game.call("_select_blessing", 0)
    await process_frame

    var blessings: BlessingSystem = game.get("blessing_system") as BlessingSystem
    _assert_true(not chest_panel.visible, "Choosing a surprise closes the choice overlay")
    _assert_true(not paused, "Choosing a surprise resumes autonomous combat")
    _assert_true(not garden_director.blocked, "Garden director resumes after the choice")
    _assert_equal_int(blessings.get_blessing_stack(selected.id), 1, "Chosen surprise modifies the run")

    var effects: PixelImpactSystem = game.get("pixel_impact_system") as PixelImpactSystem
    effects.spawn_hit(Vector2(320.0, 180.0), Color("ffffff"), 25.0, true)
    _assert_true(effects.get_active_particle_count() > 0, "Critical impact creates pixel particles")
    _assert_true(effects.get_active_particle_count() <= effects.max_particles, "Gameplay particles remain bounded")

    var director_panel_label: Label = game.get("director_status_label") as Label
    var language_button: Button = game.get("language_button") as Button
    var menu_button: Button = game.get("menu_button") as Button
    _assert_control_inside_viewport(director_panel_label, "Director status stays inside viewport")
    _assert_control_inside_viewport(language_button, "Gameplay language button stays inside viewport")
    _assert_control_inside_viewport(menu_button, "Gameplay menu button stays inside viewport")

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