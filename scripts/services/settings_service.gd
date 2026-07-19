extends RefCounted
class_name SettingsService

signal settings_changed

const CURRENT_VERSION: int = 1
const DEFAULT_PATH: String = "user://settings.cfg"

var settings_path: String = DEFAULT_PATH
var locale: String = "en"
var music_enabled: bool = true
var sfx_enabled: bool = true
var music_volume_db: float = -20.0
var sfx_volume_db: float = -9.0
var fullscreen: bool = false
var screen_flash_enabled: bool = true
var performance_overlay_enabled: bool = false


func load_settings() -> void:
    _apply_defaults()
    var config: ConfigFile = ConfigFile.new()
    var error: Error = config.load(settings_path)
    if error != OK:
        locale = "zh_CN" if OS.get_locale_language().to_lower().begins_with("zh") else "en"
        save_settings()
        return

    var version: int = int(config.get_value("meta", "version", 0))
    locale = _normalize_locale(String(config.get_value("general", "locale", locale)))
    music_enabled = bool(config.get_value("audio", "music_enabled", music_enabled))
    sfx_enabled = bool(config.get_value("audio", "sfx_enabled", sfx_enabled))
    music_volume_db = clampf(float(config.get_value("audio", "music_volume_db", music_volume_db)), -60.0, 0.0)
    sfx_volume_db = clampf(float(config.get_value("audio", "sfx_volume_db", sfx_volume_db)), -60.0, 0.0)
    fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
    screen_flash_enabled = bool(config.get_value("effects", "screen_flash_enabled", screen_flash_enabled))
    performance_overlay_enabled = bool(config.get_value("effects", "performance_overlay_enabled", performance_overlay_enabled))

    if version < CURRENT_VERSION:
        save_settings()


func save_settings() -> bool:
    var config: ConfigFile = ConfigFile.new()
    config.set_value("meta", "version", CURRENT_VERSION)
    config.set_value("general", "locale", locale)
    config.set_value("audio", "music_enabled", music_enabled)
    config.set_value("audio", "sfx_enabled", sfx_enabled)
    config.set_value("audio", "music_volume_db", music_volume_db)
    config.set_value("audio", "sfx_volume_db", sfx_volume_db)
    config.set_value("display", "fullscreen", fullscreen)
    config.set_value("effects", "screen_flash_enabled", screen_flash_enabled)
    config.set_value("effects", "performance_overlay_enabled", performance_overlay_enabled)
    var error: Error = config.save(settings_path)
    if error != OK:
        push_warning("Unable to save settings: %s" % error_string(error))
        return false
    settings_changed.emit()
    return true


func apply_runtime(audio_manager: ProceduralAudioManager = null) -> void:
    if audio_manager != null:
        audio_manager.music_volume_db = music_volume_db
        audio_manager.sfx_volume_db = sfx_volume_db
        audio_manager.set_music_enabled(music_enabled)
        audio_manager.set_sfx_enabled(sfx_enabled)
        audio_manager.apply_volume_settings()

    if OS.has_feature("web"):
        return
    DisplayServer.window_set_mode(
        DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
    )


func set_locale(value: String) -> void:
    locale = _normalize_locale(value)
    save_settings()


func toggle_music() -> void:
    music_enabled = not music_enabled
    save_settings()


func toggle_sfx() -> void:
    sfx_enabled = not sfx_enabled
    save_settings()


func toggle_fullscreen() -> void:
    fullscreen = not fullscreen
    save_settings()


func toggle_screen_flash() -> void:
    screen_flash_enabled = not screen_flash_enabled
    save_settings()


func _apply_defaults() -> void:
    locale = "en"
    music_enabled = true
    sfx_enabled = true
    music_volume_db = -20.0
    sfx_volume_db = -9.0
    fullscreen = false
    screen_flash_enabled = true
    performance_overlay_enabled = false


func _normalize_locale(value: String) -> String:
    return "zh_CN" if value.to_lower().begins_with("zh") else "en"
