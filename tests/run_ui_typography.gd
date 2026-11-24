extends SceneTree

var failures: int = 0
var cases: int = 0
const UI_FONT: FontFile = preload("res://assets/ui/fonts/SproutUISans-Regular.otf")

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)

func _glyphs(value: String) -> void:
    for i: int in range(value.length()):
        var cp: int = value.unicode_at(i)
        if cp >= 32:
            _check(UI_FONT.has_char(cp), "Missing bundled glyph %d in %s" % [cp, value])

func _label(label: Label, box: Rect2) -> void:
    _glyphs(label.text)
    var font: Font = label.get_theme_font("font")
    var size_value: int = label.get_theme_font_size("font_size")
    var lines: PackedStringArray = label.text.split("\n")
    var widest: float = 0.0
    for line: String in lines:
        widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x)
    _check(widest <= label.size.x + 0.5, "Text exceeds width: %s (%f > %f)" % [label.text, widest, label.size.x])
    _check(font.get_height(size_value) * lines.size() <= label.size.y + 0.5, "Text exceeds height: " + label.text)
    _check(box.grow(0.5).encloses(Rect2(label.position, label.size)), "Label outside allocated area: " + label.text)

func _run() -> void:
    for key: String in LocalizationService.TEXT:
        for value: String in (LocalizationService.TEXT[key] as Dictionary).values():
            _glyphs(value)
    var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
    game.set("simulation_mode", true)
    root.add_child(game)
    game.set_process(false)
    await process_frame
    var system: BlessingSystem = game.get("blessing_system") as BlessingSystem
    var locale: LocalizationService = game.get("i18n") as LocalizationService
    var pool: Array[BlessingData] = system.pool.duplicate()
    for data: BlessingData in SurvivorArsenal.reward_pool(true):
        if not pool.any(func(other: BlessingData) -> bool: return other.id == data.id):
            pool.append(data)
    game.set("choice_open", true)
    for language: String in ["en", "zh_CN"]:
        locale.set_locale(language, false)
        for data: BlessingData in pool:
            for rank: int in range(data.max_stacks):
                var index: int = SurvivorArsenal.IDS.find(data.id)
                for partner_rank: int in ([0,1,3] if index >= 0 else [0]):
                    system.stacks.clear()
                    system.stacks[String(data.id)] = rank
                    if index >= 0:
                        system.stacks[String(SurvivorArsenal.IDS[SurvivorArsenal.EVOLUTION_PARTNERS[index]])] = partner_rank
                    var choices: Array[BlessingData] = [data]
                    game.set("_current_choices", choices)
                    game.call("_render_reward_cards")
                    var button: Button = (game.get("choice_buttons") as Array)[0] as Button
                    var previous_end: float = 0.0
                    for name_value: String in ["GiftRarity", "GiftName", "GiftDetail"]:
                        var label: Label = button.get_node(name_value) as Label
                        _label(label, Rect2(Vector2.ZERO, button.size))
                        _check(label.position.y >= previous_end, "Reward labels overlap: " + label.text)
                        previous_end = label.position.y + label.size.y
                    cases += 1
    game.set("choice_open", false)
    system.stacks.clear()
    for id: StringName in SurvivorArsenal.IDS:
        system.stacks[String(id)] = 3
    game.call("_toggle_pause")
    for language: String in ["en", "zh_CN"]:
        locale.set_locale(language, false)
        game.call("_apply_locale")
        await process_frame
        var grid: GridContainer = game.get("pause_weapon_grid") as GridContainer
        _check(grid.get_child_count() == 8, "Full build shows eight weapons")
        for item: Label in grid.get_children():
            _label(item, Rect2(Vector2.ZERO, grid.size))
        _check(grid.position.y + grid.size.y <= (game.get("language_button") as Button).position.y + 0.5, "Pause build overlaps controls")
    # Full build, both compact and spacious logical HUDs. Native rendering
    # remains covered separately by run_responsive_capture.
    game.call("_toggle_pause")
    game.call("_refresh_weapon_strip")
    await process_frame
    for physical: Vector2 in [Vector2(640,480), Vector2(640,360), Vector2(640,400), Vector2(840,360)]:
        for factor: float in [0.8, 1.0, 1.25]:
            var view: Vector2 = physical / factor
            game.call("_layout_game", view)
            await process_frame
            var left: Control = game.get_node("UI/TopHUD/Frame") as Control
            var timer: Control = game.get("hud_timer_panel") as Control
            var right: Control = game.get("hud_right_panel") as Control
            _check(not Rect2(left.position,left.size).intersects(Rect2(timer.position,timer.size)), "HUD left/timer overlap")
            _check(not Rect2(timer.position,timer.size).intersects(Rect2(right.position,right.size)), "HUD timer/right overlap")
            var strip: Control = game.get("hud_weapons") as Control
            var xp: Control = game.get("hud_xp_label") as Control
            _check(Rect2(Vector2.ZERO,view).grow(0.5).encloses(Rect2(strip.position,strip.size)), "Full weapon strip outside viewport")
            _check(not Rect2(strip.position,strip.size).intersects(Rect2(xp.position,xp.size)), "Weapon strip overlaps XP label")
            cases += 1
    game.call("_toggle_pause")
    system.stacks.clear()
    game.call("_refresh_pause_build")
    await process_frame
    var pause_panel: Panel = game.get("pause_panel") as Panel
    _check(pause_panel.size.y < 250, "Empty build uses compact pause panel")
    var resume: Button = game.get("pause_resume_button") as Button
    _check(Rect2(pause_panel.position,pause_panel.size).encloses(Rect2(resume.position,resume.size)), "Compact resume stays in panel")
    game.queue_free()
    await process_frame
    await _menu_chrome()
    print("TYPOGRAPHY_SUMMARY cases=", cases, " failures=", failures)
    quit(0 if failures == 0 and cases > 100 else 1)

func _menu_chrome() -> void:
    var menu: Node = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
    root.add_child(menu)
    await process_frame
    var locale: LocalizationService = menu.get("localization") as LocalizationService
    var prefs: SettingsService = menu.get("settings") as SettingsService
    var group: Control = menu.get_node("UI/Settings") as Control
    var main: Control = menu.get_node("UI/Main") as Control
    for language: String in ["en", "zh_CN"]:
        locale.set_locale(language, false)
        menu.call("_apply_locale")
        for light: bool in [false, true]:
            prefs.light_ui = light
            menu.call("_refresh_appearance")
            for key: String in ["play_button", "settings_button", "collection_button", "quit_button", "select_hero_button", "language_button", "settings_language_button", "settings_back_button", "music_button", "sfx_button", "flash_button", "motion_button"]:
                var button: Button = menu.get(key) as Button
                _check(button.icon != null and button.has_meta("chrome_icon"), "Missing chrome icon: " + key)
                _check(button.get_theme_color("icon_normal_color") == button.get_theme_color("font_color"), "Icon tint mismatch: " + key)
                var size_value: int = button.get_theme_font_size("font_size")
                var required: float = button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x
                required += button.get_theme_stylebox("normal").get_minimum_size().x + button.get_theme_constant("icon_max_width") + button.get_theme_constant("h_separation")
                _check(required <= button.size.x + 0.5, "Button text/icon exceeds budget: " + button.text)
                cases += 1
            for physical: Vector2 in [Vector2(640,480), Vector2(640,360), Vector2(640,400), Vector2(840,360)]:
                for factor: float in [0.8,1.0,1.25]:
                    var view: Vector2 = physical / factor
                    ResponsiveUI.center_group(group,view)
                    ResponsiveUI.center_group(main,view)
                    var bounds: Rect2 = Rect2(Vector2.ZERO,view).grow(0.5)
                    for key: String in ["play_button","settings_button","collection_button","quit_button","settings_panel","settings_back_button","theme_picker","glass_picker","motion_button"]:
                        var control: Control = menu.get(key) as Control
                        var parent: Control = control.get_parent() as Control
                        _check(bounds.encloses(parent.get_transform() * Rect2(control.position,control.size)), "Scaled control outside viewport: " + key)
                    cases += 1
    menu.queue_free()
    await process_frame
