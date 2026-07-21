extends "res://scripts/ui/greed_main_menu.gd"


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

    _bind_existing_ui()
    _apply_locale()


func _draw() -> void:
    pass


func _bind_existing_ui() -> void:
    title_label = get_node("UI/Main/TitleLabel") as Label
    subtitle_label = get_node("UI/Main/SubtitleLabel") as Label
    play_button = get_node("UI/Main/PlayButton") as Button
    settings_button = get_node("UI/Main/SettingsButton") as Button
    collection_button = get_node("UI/Main/CollectionButton") as Button
    quit_button = get_node("UI/Main/QuitButton") as Button
    language_button = get_node("UI/Main/LanguageButton") as Button
    progress_label = get_node("UI/Main/ProgressLabel") as Label

    settings_backdrop = get_node("UI/Settings/Backdrop") as ColorRect
    settings_panel = get_node("UI/Settings/Panel") as Panel
    settings_title_label = get_node("UI/Settings/TitleLabel") as Label
    settings_language_button = get_node("UI/Settings/LanguageButton") as Button
    music_button = get_node("UI/Settings/MusicButton") as Button
    sfx_button = get_node("UI/Settings/SfxButton") as Button
    fullscreen_button = get_node("UI/Settings/FullscreenButton") as Button
    flash_button = get_node("UI/Settings/FlashButton") as Button
    settings_back_button = get_node("UI/Settings/BackButton") as Button

    play_button.pressed.connect(_open_level_select)
    settings_button.pressed.connect(_show_settings)
    collection_button.pressed.connect(_show_collection_summary)
    quit_button.pressed.connect(_quit_game)
    language_button.pressed.connect(_toggle_language)
    settings_language_button.pressed.connect(_toggle_language)
    music_button.pressed.connect(_toggle_music)
    sfx_button.pressed.connect(_toggle_sfx)
    fullscreen_button.pressed.connect(_toggle_fullscreen)
    flash_button.pressed.connect(_toggle_flash)
    settings_back_button.pressed.connect(_hide_settings)

    quit_button.visible = not OS.has_feature("web")
    _set_settings_controls_visible(false)
