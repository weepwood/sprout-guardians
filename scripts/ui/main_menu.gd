extends Node2D

var settings: SettingsService
var localization: LocalizationService
var save_game: SaveGameService
var audio_manager: ProceduralAudioManager

var title_label: Label
var subtitle_label: Label
var play_button: Button
var settings_button: Button
var collection_button: Button
var quit_button: Button
var language_button: Button
var progress_label: Label

var settings_backdrop: ColorRect
var settings_panel: Panel
var settings_title_label: Label
var settings_language_button: Button
var music_button: Button
var sfx_button: Button
var fullscreen_button: Button
var flash_button: Button
var settings_back_button: Button


func _ready() -> void:
    settings = SettingsService.new()
    settings.load_settings()
    localization = LocalizationService.new()
    localization.set_locale(settings.locale, false)
    save_game = SaveGameService.new()
    save_game.load_game()

    audio_manager = ProceduralAudioManager.new()
    audio_manager.name = "MenuAudio"
    add_child(audio_manager)
    settings.apply_runtime(audio_manager)

    _create_ui()
    _apply_locale()
    queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and settings_panel != null and settings_panel.visible:
        _hide_settings()
        get_viewport().set_input_as_handled()


func _draw() -> void:
    draw_rect(Rect2(0.0, 0.0, 640.0, 360.0), Color("102c2b"))
    for x_value: int in range(0, 640, 32):
        for y_value: int in range(0, 360, 32):
            var alternating: bool = (int(x_value / 32) + int(y_value / 32)) % 2 == 0
            draw_rect(Rect2(float(x_value), float(y_value), 32.0, 32.0), Color("173f35") if alternating else Color("14382f"))
    draw_circle(Vector2(86.0, 276.0), 72.0, Color("245e43"))
    draw_circle(Vector2(552.0, 84.0), 94.0, Color("1d513d"))
    draw_rect(Rect2(0.0, 312.0, 640.0, 48.0), Color("0b2223"))
    for position_value: Vector2 in [Vector2(42.0, 310.0), Vector2(122.0, 320.0), Vector2(515.0, 315.0), Vector2(592.0, 304.0)]:
        draw_rect(Rect2(position_value + Vector2(-3.0, 0.0), Vector2(6.0, 24.0)), Color("59412c"))
        draw_circle(position_value, 18.0, Color("39784c"))
        draw_circle(position_value + Vector2(-10.0, 3.0), 12.0, Color("2c6642"))


func _create_ui() -> void:
    var canvas: CanvasLayer = CanvasLayer.new()
    canvas.name = "UI"
    add_child(canvas)

    title_label = _make_label(canvas, Vector2(92.0, 38.0), Vector2(456.0, 54.0), 34)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle_label = _make_label(canvas, Vector2(120.0, 88.0), Vector2(400.0, 28.0), 14)
    subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    play_button = _make_button(canvas, Vector2(218.0, 132.0), Vector2(204.0, 38.0))
    play_button.pressed.connect(_open_level_select)
    settings_button = _make_button(canvas, Vector2(218.0, 178.0), Vector2(204.0, 38.0))
    settings_button.pressed.connect(_show_settings)
    collection_button = _make_button(canvas, Vector2(218.0, 224.0), Vector2(204.0, 38.0))
    collection_button.pressed.connect(_show_collection_summary)
    quit_button = _make_button(canvas, Vector2(218.0, 270.0), Vector2(204.0, 38.0))
    quit_button.pressed.connect(_quit_game)
    quit_button.visible = not OS.has_feature("web")

    language_button = _make_button(canvas, Vector2(550.0, 16.0), Vector2(72.0, 30.0))
    language_button.pressed.connect(_toggle_language)

    progress_label = _make_label(canvas, Vector2(106.0, 322.0), Vector2(428.0, 24.0), 12)
    progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    settings_backdrop = ColorRect.new()
    settings_backdrop.position = Vector2.ZERO
    settings_backdrop.size = Vector2(640.0, 360.0)
    settings_backdrop.color = Color(0.015, 0.045, 0.05, 0.92)
    settings_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    settings_backdrop.visible = false
    canvas.add_child(settings_backdrop)

    settings_panel = _make_panel(canvas, Vector2(140.0, 24.0), Vector2(360.0, 312.0))
    settings_panel.visible = false

    settings_title_label = _make_label(canvas, Vector2(164.0, 38.0), Vector2(312.0, 30.0), 21)
    settings_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    settings_language_button = _make_button(canvas, Vector2(170.0, 76.0), Vector2(300.0, 34.0))
    settings_language_button.pressed.connect(_toggle_language)
    music_button = _make_button(canvas, Vector2(170.0, 116.0), Vector2(300.0, 34.0))
    music_button.pressed.connect(_toggle_music)
    sfx_button = _make_button(canvas, Vector2(170.0, 156.0), Vector2(300.0, 34.0))
    sfx_button.pressed.connect(_toggle_sfx)
    fullscreen_button = _make_button(canvas, Vector2(170.0, 196.0), Vector2(300.0, 34.0))
    fullscreen_button.pressed.connect(_toggle_fullscreen)
    flash_button = _make_button(canvas, Vector2(170.0, 236.0), Vector2(300.0, 34.0))
    flash_button.pressed.connect(_toggle_flash)
    settings_back_button = _make_button(canvas, Vector2(250.0, 286.0), Vector2(140.0, 30.0))
    settings_back_button.pressed.connect(_hide_settings)
    _set_settings_controls_visible(false)


func _open_level_select() -> void:
    audio_manager.play_event(&"ui_click")
    get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func _show_settings() -> void:
    audio_manager.play_event(&"ui_click")
    settings_backdrop.visible = true
    settings_panel.visible = true
    _set_main_chrome_visible(false)
    _set_main_controls_visible(false)
    _set_settings_controls_visible(true)
    _refresh_settings_buttons()
    settings_language_button.grab_focus()


func _hide_settings() -> void:
    audio_manager.play_event(&"ui_click")
    settings_backdrop.visible = false
    settings_panel.visible = false
    _set_settings_controls_visible(false)
    _set_main_chrome_visible(true)
    _set_main_controls_visible(true)
    settings_button.grab_focus()


func _show_collection_summary() -> void:
    audio_manager.play_event(&"ui_click")
    var stars: int = save_game.get_level_stars(&"morning_forest")
    progress_label.text = _t("Morning Forest collection: %d/3 stars · Encyclopedia coming next", "晨光森林收集进度：%d/3 星 · 图鉴将在后续完善") % stars


func _toggle_language() -> void:
    audio_manager.play_event(&"ui_click")
    localization.toggle_locale()
    settings.set_locale(localization.locale_code)
    _apply_locale()


func _toggle_music() -> void:
    settings.toggle_music()
    settings.apply_runtime(audio_manager)
    if settings.sfx_enabled:
        audio_manager.play_event(&"ui_click")
    _refresh_settings_buttons()


func _toggle_sfx() -> void:
    settings.toggle_sfx()
    settings.apply_runtime(audio_manager)
    audio_manager.play_event(&"ui_click")
    _refresh_settings_buttons()


func _toggle_fullscreen() -> void:
    audio_manager.play_event(&"ui_click")
    settings.toggle_fullscreen()
    settings.apply_runtime(audio_manager)
    _refresh_settings_buttons()


func _toggle_flash() -> void:
    audio_manager.play_event(&"ui_click")
    settings.toggle_screen_flash()
    _refresh_settings_buttons()


func _quit_game() -> void:
    get_tree().quit()


func _apply_locale() -> void:
    title_label.text = _t("SPROUT GUARDIANS", "芽芽守卫战")
    subtitle_label.text = _t("Protect the garden. Grow a stronger defense.", "守护花园，培育更强大的防线。")
    play_button.text = _t("PLAY", "开始游戏")
    settings_button.text = _t("SETTINGS", "游戏设置")
    collection_button.text = _t("COLLECTION", "图鉴与收集")
    quit_button.text = _t("QUIT", "退出游戏")
    language_button.text = "中文" if localization.locale_code == "en" else "EN"
    settings_title_label.text = _t("GAME SETTINGS", "游戏设置")
    settings_language_button.text = _t("Language: English", "语言：简体中文")
    settings_back_button.text = _t("BACK", "返回")
    var stars: int = save_game.get_level_stars(&"morning_forest")
    progress_label.text = _t("Campaign progress · Morning Forest %d/3 stars", "战役进度 · 晨光森林 %d/3 星") % stars
    _refresh_settings_buttons()


func _refresh_settings_buttons() -> void:
    if music_button == null:
        return
    music_button.text = _t("Music: %s", "背景音乐：%s") % _on_off(settings.music_enabled)
    sfx_button.text = _t("Sound effects: %s", "游戏音效：%s") % _on_off(settings.sfx_enabled)
    fullscreen_button.text = _t("Fullscreen: %s", "全屏显示：%s") % _on_off(settings.fullscreen)
    flash_button.text = _t("Screen flash: %s", "屏幕闪烁：%s") % _on_off(settings.screen_flash_enabled)


func _set_main_chrome_visible(value: bool) -> void:
    title_label.visible = value
    subtitle_label.visible = value
    language_button.visible = value
    progress_label.visible = value


func _set_main_controls_visible(value: bool) -> void:
    play_button.visible = value
    settings_button.visible = value
    collection_button.visible = value
    quit_button.visible = value and not OS.has_feature("web")


func _set_settings_controls_visible(value: bool) -> void:
    settings_title_label.visible = value
    settings_language_button.visible = value
    music_button.visible = value
    sfx_button.visible = value
    fullscreen_button.visible = value and not OS.has_feature("web")
    flash_button.visible = value
    settings_back_button.visible = value


func _on_off(value: bool) -> String:
    if localization.locale_code == "zh_CN":
        return "开启" if value else "关闭"
    return "ON" if value else "OFF"


func _t(english: String, chinese: String) -> String:
    return chinese if localization.locale_code == "zh_CN" else english


func _make_label(parent: Node, position_value: Vector2, size_value: Vector2, font_size: int) -> Label:
    var label: Label = Label.new()
    label.position = position_value
    label.size = size_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color("f4f0d1"))
    parent.add_child(label)
    return label


func _make_panel(parent: Node, position_value: Vector2, size_value: Vector2) -> Panel:
    var panel: Panel = Panel.new()
    panel.position = position_value
    panel.size = size_value
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.04, 0.10, 0.11, 0.99)
    style.border_color = Color("8eb46e")
    style.set_border_width_all(3)
    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)
    return panel


func _make_button(parent: Node, position_value: Vector2, size_value: Vector2) -> Button:
    var button: Button = Button.new()
    button.position = position_value
    button.size = size_value
    button.focus_mode = Control.FOCUS_ALL
    button.add_theme_font_size_override("font_size", 14)
    var normal: StyleBoxFlat = StyleBoxFlat.new()
    normal.bg_color = Color("24483f")
    normal.border_color = Color("7ba269")
    normal.set_border_width_all(2)
    var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color("356553")
    hover.border_color = Color("d1e88d")
    var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("182f2b")
    pressed.border_color = Color("f0cf75")
    var focus: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
    focus.border_color = Color("f0cf75")
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("focus", focus)
    button.add_theme_color_override("font_color", Color("f4f0d1"))
    parent.add_child(button)
    return button