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
    await _test_greed_arena_scene()

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


func _test_greed_arena_scene() -> void:
    var game: Node = await _instantiate_scene("res://scenes/main.tscn", "Main-plant greed arena")
    if game == null:
        return

    var localization: LocalizationService = game.get("i18n") as LocalizationService
    var initial_locale: String = localization.locale_code
    game.call("_toggle_language")
    await process_frame
    _assert_true(localization.locale_code != initial_locale, "Greed arena language button changes locale")

    var hero: GreedHeroPlant = game.get("hero_plant") as GreedHeroPlant
    var familiars: Array = game.get("plants") as Array
    _assert_true(hero != null, "Greed arena starts with one controllable main plant")
    _assert_equal_int(familiars.size(), 2, "Secondary plants are represented as two floating familiars")
    _assert_true(game.find_child("StartWaveButton", true, false) == null, "Default mode has no manual Start Wave control")
    _assert_true(game.find_child("UpgradeButton", true, false) == null, "Default mode has no manual upgrade control")
    _assert_true(game.find_child("BuildBar", true, false) == null, "Default mode has no tower build bar")

    var initial_position: Vector2 = hero.global_position
    game.call("_handle_left_click", initial_position)
    _assert_true(hero.dragging and hero.selected, "Clicking the main plant begins direct mouse control")
    hero.end_drag(initial_position)
    var move_destination: Vector2 = initial_position + Vector2(64.0, 28.0)
    game.call("_handle_left_click", move_destination)
    _assert_true(hero.has_move_target, "A selected main plant accepts a floor movement command")
    hero._process(0.25)
    _assert_true(hero.global_position.distance_to(initial_position) > 1.0, "Main plant moves toward the clicked destination")

    game.set("next_wave_timer", 0.0)
    await process_frame
    await process_frame
    _assert_equal_int(int(game.get("wave_index")), 0, "First greed wave starts automatically")
    _assert_true(bool(game.get("wave_active")), "Greed arena enters active combat without a wave button")

    game.set("spawn_timer", 0.0)
    await process_frame
    await process_frame
    var enemies: Array[Node] = get_nodes_in_group("greed_enemies")
    _assert_true(enemies.size() >= 1, "Enemies enter from arena doors without path-following setup")
    var priority_enemy: GreedEnemy = enemies[0] as GreedEnemy
    game.call("_set_priority_target", priority_enemy)
    _assert_true(hero.get_focus_target() == priority_enemy, "Click command locks a main attack target")
    _assert_true(priority_enemy.priority_targeted, "Priority enemy displays its target marker")
    for familiar_value: Variant in familiars:
        var familiar: GreedPlant = familiar_value as GreedPlant
        _assert_true(familiar.focus_source == hero, "Floating familiar shares the main plant target source")
        _assert_true(familiar.call("_find_target") == priority_enemy, "Floating familiar prioritizes the clicked enemy")

    game.set("spawn_remaining", 0)
    for node: Node in get_nodes_in_group("greed_enemies"):
        node.queue_free()
    await process_frame
    await process_frame
    await process_frame

    var choice_panel: Panel = game.get("choice_panel") as Panel
    var choice_buttons: Array = game.get("choice_buttons") as Array
    _assert_true(bool(game.get("choice_open")), "Every cleared greed wave guarantees a surprise choice")
    _assert_true(choice_panel.visible, "Surprise choice overlay opens after a wave")
    _assert_equal_int(choice_buttons.size(), 3, "Surprise reward presents three mutation choices")
    _assert_control_inside_viewport(choice_panel, "Greed reward panel stays inside viewport")

    var choices: Array = game.get("_current_choices") as Array
    var selected_blessing: BlessingData = choices[0] as BlessingData
    var hero_level_before: int = hero.level
    game.call("_select_choice", 0)
    await process_frame

    var blessings: BlessingSystem = game.get("blessing_system") as BlessingSystem
    _assert_true(not bool(game.get("choice_open")), "Choosing a mutation resumes the run")
    _assert_true(not choice_panel.visible, "Choosing a mutation closes the reward overlay")
    _assert_equal_int(blessings.get_blessing_stack(selected_blessing.id), 1, "Chosen mutation modifies the run")
    _assert_equal_int(hero.level, hero_level_before + 1, "Every reward evolves the main plant")

    var effects: PixelImpactSystem = game.get("impact_system") as PixelImpactSystem
    effects.spawn_hit(Vector2(320.0, 180.0), Color("ffffff"), 25.0, true)
    _assert_true(effects.get_active_particle_count() > 0, "Critical arena impact creates pixel particles")
    _assert_true(effects.get_active_particle_count() <= effects.max_particles, "Arena particles remain bounded")

    var control_label: Label = game.get("control_label") as Label
    var language_button: Button = game.get("language_button") as Button
    var speed_button: Button = game.get("speed_button") as Button
    var menu_button: Button = game.get("menu_button") as Button
    _assert_control_inside_viewport(control_label, "Mouse-control guidance stays inside viewport")
    _assert_control_inside_viewport(language_button, "Greed language button stays inside viewport")
    _assert_control_inside_viewport(speed_button, "Greed speed button stays inside viewport")
    _assert_control_inside_viewport(menu_button, "Greed menu button stays inside viewport")

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