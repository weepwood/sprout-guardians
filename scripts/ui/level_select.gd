extends Node2D

const LEVELS: Array[Dictionary] = [
    {"id": &"morning_forest", "name_en": "Morning Forest", "name_zh": "晨光森林", "scene": "res://scenes/main.tscn"},
    {"id": &"twilight_marsh", "name_en": "Twilight Marsh", "name_zh": "暮色沼泽", "scene": ""},
    {"id": &"crystal_hollow", "name_en": "Crystal Hollow", "name_zh": "水晶幽谷", "scene": ""},
]

var settings: SettingsService
var localization: LocalizationService
var save_game: SaveGameService
var audio_manager: ProceduralAudioManager
var title_label: Label
var description_label: Label
var language_button: Button
var back_button: Button
var level_buttons: Array[Button] = []
var level_detail_labels: Array[Label] = []


func _ready() -> void:
    settings = SettingsService.new()
    settings.load_settings()
    localization = LocalizationService.new()
    localization.set_locale(settings.locale, false)
    save_game = SaveGameService.new()
    save_game.load_game()

    audio_manager = ProceduralAudioManager.new()
    audio_manager.name = "LevelSelectAudio"
    add_child(audio_manager)
    settings.apply_runtime(audio_manager)

    _create_ui()
    _apply_locale()
    queue_redraw()


func _draw() -> void:
    draw_rect(Rect2(0.0, 0.0, 640.0, 360.0), Color("102a31"))
    for y_value: int in range(0, 360, 24):
        draw_rect(Rect2(0.0, float(y_value), 640.0, 12.0), Color(0.10, 0.25, 0.27, 0.28))
    draw_circle(Vector2(90.0, 310.0), 90.0, Color("1f5945"))
    draw_circle(Vector2(560.0, 300.0), 105.0, Color("1a4b42"))


func _create_ui() -> void:
    var canvas: CanvasLayer = CanvasLayer.new()
    canvas.name = "UI"
    add_child(canvas)

    title_label = _make_label(canvas, Vector2(100.0, 24.0), Vector2(440.0, 42.0), 28)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    description_label = _make_label(canvas, Vector2(92.0, 66.0), Vector2(456.0, 26.0), 13)
    description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    for index: int in range(LEVELS.size()):
        var y_position: float = 108.0 + float(index) * 70.0
        var panel: Panel = _make_panel(canvas, Vector2(90.0, y_position), Vector2(460.0, 58.0))
        var button: Button = _make_button(canvas, Vector2(104.0, y_position + 10.0), Vector2(238.0, 38.0))
        button.pressed.connect(_select_level.bind(index))
        level_buttons.append(button)
        var detail: Label = _make_label(canvas, Vector2(356.0, y_position + 9.0), Vector2(178.0, 40.0), 12)
        detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        level_detail_labels.append(detail)
        panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

    back_button = _make_button(canvas, Vector2(18.0, 18.0), Vector2(82.0, 30.0))
    back_button.pressed.connect(_go_back)
    language_button = _make_button(canvas, Vector2(540.0, 18.0), Vector2(82.0, 30.0))
    language_button.pressed.connect(_toggle_language)


func _select_level(index: int) -> void:
    if index < 0 or index >= LEVELS.size():
        return
    var entry: Dictionary = LEVELS[index]
    var level_id: StringName = entry["id"] as StringName
    if not save_game.is_level_unlocked(level_id):
        audio_manager.play_event(&"base_hit")
        description_label.text = _t("This level is still locked.", "该关卡尚未解锁。")
        return
    var scene_path: String = String(entry.get("scene", ""))
    if scene_path.is_empty():
        audio_manager.play_event(&"base_hit")
        description_label.text = _t("This campaign map is planned for a later milestone.", "该战役地图将在后续里程碑中实现。")
        return
    audio_manager.play_event(&"ui_click")
    get_tree().change_scene_to_file(scene_path)


func _go_back() -> void:
    audio_manager.play_event(&"ui_click")
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _toggle_language() -> void:
    audio_manager.play_event(&"ui_click")
    localization.toggle_locale()
    settings.set_locale(localization.locale_code)
    _apply_locale()


func _apply_locale() -> void:
    title_label.text = _t("CHOOSE A GARDEN", "选择守护区域")
    description_label.text = _t("Complete levels to earn stars and unlock the campaign.", "完成关卡、获得星级并逐步解锁战役。")
    back_button.text = _t("BACK", "返回")
    language_button.text = "中文" if localization.locale_code == "en" else "EN"

    for index: int in range(LEVELS.size()):
        var entry: Dictionary = LEVELS[index]
        var level_id: StringName = entry["id"] as StringName
        var unlocked: bool = save_game.is_level_unlocked(level_id)
        var stars: int = save_game.get_level_stars(level_id)
        var display_name: String = String(entry["name_zh"] if localization.locale_code == "zh_CN" else entry["name_en"])
        level_buttons[index].text = display_name if unlocked else "%s · %s" % [display_name, _t("LOCKED", "未解锁")]
        level_buttons[index].disabled = not unlocked
        level_detail_labels[index].text = "%s\n%s" % [_stars(stars), _t("Available" if unlocked else "Locked", "可游玩" if unlocked else "未解锁")]


func _stars(value: int) -> String:
    var output: String = ""
    for index: int in range(3):
        output += "★" if index < value else "☆"
    return output


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
    style.bg_color = Color(0.04, 0.11, 0.13, 0.94)
    style.border_color = Color("668f78")
    style.set_border_width_all(2)
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
    var hover: StyleBoxFlat = normal.duplicate()
    hover.bg_color = Color("356553")
    hover.border_color = Color("d1e88d")
    var disabled: StyleBoxFlat = normal.duplicate()
    disabled.bg_color = Color("263330")
    disabled.border_color = Color("4f615a")
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("disabled", disabled)
    button.add_theme_color_override("font_color", Color("f4f0d1"))
    parent.add_child(button)
    return button
