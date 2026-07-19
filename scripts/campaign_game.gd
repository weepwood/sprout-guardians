extends "res://scripts/localized_main.gd"

var campaign_settings: SettingsService
var campaign_save: SaveGameService
var menu_button: Button


func _ready() -> void:
    campaign_settings = SettingsService.new()
    campaign_settings.load_settings()
    campaign_save = SaveGameService.new()
    campaign_save.load_game()
    super._ready()
    campaign_settings.apply_runtime(audio_manager)
    _create_menu_button()
    _apply_locale()


func _create_menu_button() -> void:
    var canvas: Node = get_node_or_null("UI")
    if canvas == null:
        return
    menu_button = _make_button(canvas, "", Vector2(490.0, 114.0), Vector2(74.0, 27.0))
    menu_button.pressed.connect(_return_to_menu)


func _toggle_language() -> void:
    super._toggle_language()
    campaign_settings.set_locale(i18n.locale_code)


func _apply_locale() -> void:
    super._apply_locale()
    if menu_button != null:
        menu_button.text = "菜单" if i18n.locale_code == "zh_CN" else "MENU"


func _flash_screen(color_value: Color) -> void:
    if campaign_settings != null and not campaign_settings.screen_flash_enabled:
        return
    super._flash_screen(color_value)


func _on_game_finished(victory: bool) -> void:
    super._on_game_finished(victory)
    if not victory:
        return
    var stars: int = _calculate_stars()
    campaign_save.record_level_result(&"morning_forest", stars, base_health_system.health)
    var star_text: String = ""
    for index: int in range(3):
        star_text += "★" if index < stars else "☆"
    _show_feedback(star_text, Color("f0cf75"))


func _calculate_stars() -> int:
    if base_health_system.health >= level_data.base_health:
        return 3
    if base_health_system.health >= ceili(float(level_data.base_health) * 0.6):
        return 2
    return 1


func _return_to_menu() -> void:
    audio_manager.play_event(&"ui_click")
    Engine.time_scale = 1.0
    get_tree().paused = false
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
