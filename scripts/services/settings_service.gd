extends RefCounted
class_name SettingsService

signal settings_changed

const CURRENT_VERSION: int = 2
const DEFAULT_PATH: String = "user://settings.cfg"

var settings_path: String = DEFAULT_PATH
var locale: String = "en"
var music_enabled: bool = true
var sfx_enabled: bool = true
var music_volume_db: float = -20.0
var sfx_volume_db: float = -9.0
var fullscreen: bool = false
# 0 windowed, 1 borderless fullscreen, 2 exclusive fullscreen (platform dependent).
var display_mode: int = 0
var window_size: Vector2i = Vector2i(1280, 720)
var ui_scale: float = 1.0
static var _display_initialized: bool = false
var screen_flash_enabled: bool = true
var performance_overlay_enabled: bool = false
var survivor_difficulty: int = 1
var survivor_character: int = 0
var survivor_map: int = 0


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
    display_mode = clampi(int(config.get_value("display", "mode", 1 if fullscreen else 0)), 0, 2)
    fullscreen = display_mode != 0
    window_size = Vector2i(clampi(int(config.get_value("display", "width", 1280)), 640, 7680), clampi(int(config.get_value("display", "height", 720)), 360, 4320))
    ui_scale = clampf(float(config.get_value("display", "ui_scale", 1.0)), 0.8, 1.25)
    screen_flash_enabled = bool(config.get_value("effects", "screen_flash_enabled", screen_flash_enabled))
    performance_overlay_enabled = bool(config.get_value("effects", "performance_overlay_enabled", performance_overlay_enabled))

    survivor_difficulty = clampi(int(config.get_value("gameplay", "survivor_difficulty", 1)), 0, 2)
    survivor_character = clampi(int(config.get_value("gameplay", "survivor_character", 0)), 0, 4)
    survivor_map = clampi(int(config.get_value("gameplay", "survivor_map", 0)), 0, 3)
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
    config.set_value("display", "mode", display_mode)
    config.set_value("display", "width", window_size.x)
    config.set_value("display", "height", window_size.y)
    config.set_value("display", "ui_scale", ui_scale)
    config.set_value("effects", "screen_flash_enabled", screen_flash_enabled)
    config.set_value("effects", "performance_overlay_enabled", performance_overlay_enabled)
    config.set_value("gameplay", "survivor_difficulty", survivor_difficulty)
    config.set_value("gameplay", "survivor_character", survivor_character)
    config.set_value("gameplay", "survivor_map", survivor_map)
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

    var music_bus: int = AudioServer.get_bus_index("Music")
    if music_bus >= 0:
        AudioServer.set_bus_volume_db(music_bus, music_volume_db)
        AudioServer.set_bus_mute(music_bus, not music_enabled)
    var sfx_bus: int = AudioServer.get_bus_index("SFX")
    if sfx_bus >= 0:
        AudioServer.set_bus_volume_db(sfx_bus, sfx_volume_db)
        AudioServer.set_bus_mute(sfx_bus, not sfx_enabled)

    if not _display_initialized and native_display():
        _display_initialized = true
        apply_display(not OS.get_cmdline_args().has("--resolution"))


static func native_display() -> bool:
    return not OS.has_feature("web") and DisplayServer.get_name().to_lower() != "headless"


func apply_display(restore_size: bool = false) -> void:
    if not native_display():
        return
    var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
    if display_mode == 1:
        mode = DisplayServer.WINDOW_MODE_FULLSCREEN
    elif display_mode == 2:
        mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
    DisplayServer.window_set_mode(mode)
    if display_mode == 0:
        DisplayServer.window_set_min_size(Vector2i(640, 360))
        if restore_size:
            var usable: Vector2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
            DisplayServer.window_set_size(window_size.clamp(Vector2i(640, 360), usable.max(Vector2i(640, 360))))


func set_display_mode(value: int) -> void:
    remember_window_size()
    display_mode = clampi(value, 0, 2)
    fullscreen = display_mode != 0
    apply_display(true)
    save_settings()


func set_resolution(value: Vector2i) -> void:
    window_size = value.clamp(Vector2i(640, 360), Vector2i(7680, 4320))
    if display_mode == 0:
        apply_display(true)
    save_settings()


func set_ui_scale(value: float) -> void:
    ui_scale = clampf(value, 0.8, 1.25)
    save_settings()


func remember_window_size() -> void:
    if native_display() and display_mode == 0 and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
        var actual: Vector2i = DisplayServer.window_get_size()
        if actual.x >= 640 and actual.y >= 360 and actual != window_size:
            window_size = actual
            save_settings()


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
    set_display_mode(0 if fullscreen else 1)


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
    display_mode = 0
    window_size = Vector2i(1280, 720)
    ui_scale = 1.0
    screen_flash_enabled = true
    performance_overlay_enabled = false
    survivor_difficulty = 1
    survivor_character = 0
    survivor_map = 0


func _normalize_locale(value: String) -> String:
    return "zh_CN" if value.to_lower().begins_with("zh") else "en"