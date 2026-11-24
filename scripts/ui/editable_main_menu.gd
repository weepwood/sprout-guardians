extends "res://scripts/ui/greed_main_menu.gd"

var difficulty_picker: OptionButton
var character_picker: OptionButton
var archive_backdrop: ColorRect
var archive_panel: Panel
var archive_title: Label
var archive_summary: Label
var archive_subtitle: Label
var archive_back_button: Button


func _ready() -> void:
    settings = SettingsService.new()
    settings.load_settings()
    SurvivorBalance.selected_difficulty = settings.survivor_difficulty
    SurvivorCharacters.selected = settings.survivor_character
    localization = LocalizationService.new()
    localization.set_locale(settings.locale, false)
    save_game = SaveGameService.new()
    save_game.load_game()

    audio_manager = ProceduralAudioManager.new()
    audio_manager.name = "MenuAudio"
    add_child(audio_manager)
    settings.apply_runtime(audio_manager)

    _bind_existing_ui()
    difficulty_picker = OptionButton.new()
    difficulty_picker.name = "DifficultyPicker"
    difficulty_picker.position = Vector2(12, 12)
    difficulty_picker.size = Vector2(132, 28)
    get_node("UI/Main").add_child(difficulty_picker)
    difficulty_picker.item_selected.connect(_select_difficulty)
    character_picker = OptionButton.new()
    character_picker.name = "CharacterPicker"
    character_picker.position = Vector2(12, 46)
    character_picker.size = Vector2(132, 30)
    get_node("UI/Main").add_child(character_picker)
    character_picker.item_selected.connect(_select_character)
    _apply_locale()
    _apply_playful_design()
    if OS.get_cmdline_user_args().has("--ci-survivors-smoke"):
        # The export-only smoke path opens the actual gameplay scene instead
        # of testing only whether the main menu window can be created.
        call_deferred("_open_level_select")
    else:
        play_button.grab_focus()


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
    archive_backdrop = get_node("UI/Archive/Backdrop") as ColorRect
    archive_panel = get_node("UI/Archive/Panel") as Panel
    archive_title = get_node("UI/Archive/Title") as Label
    archive_summary = get_node("UI/Archive/Summary") as Label
    archive_subtitle = get_node("UI/Archive/Subtitle") as Label
    archive_back_button = get_node("UI/Archive/BackButton") as Button
    archive_back_button.pressed.connect(_hide_archive)

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


func _apply_playful_design() -> void:
    PlayfulUITheme.apply_panel(get_node("World/MenuFrame") as Panel, "paper")
    PlayfulUITheme.apply_panel(settings_panel, "modal")
    PlayfulUITheme.apply_panel(archive_panel, "modal")
    for label: Label in [
        title_label, subtitle_label, progress_label, settings_title_label,
        archive_title, archive_summary, archive_subtitle
    ]:
        PlayfulUITheme.apply_label(label)
    PlayfulUITheme.apply_button(play_button, "primary")
    PlayfulUITheme.apply_button(settings_button, "mint")
    PlayfulUITheme.apply_button(collection_button)
    PlayfulUITheme.apply_button(quit_button, "coral")
    PlayfulUITheme.apply_button(language_button, "tiny")
    PlayfulUITheme.apply_button(settings_language_button)
    PlayfulUITheme.apply_button(music_button)
    PlayfulUITheme.apply_button(sfx_button)
    PlayfulUITheme.apply_button(fullscreen_button)
    PlayfulUITheme.apply_button(flash_button)
    PlayfulUITheme.apply_button(settings_back_button, "primary")
    PlayfulUITheme.apply_button(archive_back_button, "primary")


func _apply_locale() -> void:
    super._apply_locale()
    if difficulty_picker != null:
        difficulty_picker.clear()
        difficulty_picker.add_item(_t("Casual", "休闲"))
        difficulty_picker.add_item(_t("Normal", "普通"))
        difficulty_picker.add_item(_t("Expert", "专家"))
        difficulty_picker.select(SurvivorBalance.selected_difficulty)
    if character_picker != null:
        character_picker.clear()
        for i: int in range(3):
            character_picker.add_icon_item(PixelArtAssets.generated_actor(i), _t(SurvivorCharacters.EN[i], SurvivorCharacters.ZH[i]))
            character_picker.set_item_tooltip(i, _t(SurvivorCharacters.DESCRIPTIONS_EN[i], SurvivorCharacters.DESCRIPTIONS_ZH[i]))
        character_picker.select(SurvivorCharacters.selected)
    if archive_title == null:
        return
    archive_title.text = _t("GARDEN JOURNAL", "花园战绩")
    archive_subtitle.text = _t("Every little run makes the garden grow.", "每一局，都是芽芽成长的足迹。")
    archive_back_button.text = _t("BACK TO GARDEN", "返回花园")
    _refresh_archive()
    var stats: Dictionary = save_game.get_survivor_statistics()
    progress_label.text = _t(
        "Runs %d  ·  Victories %d  ·  Best %ds",
        "累计 %d 局  ·  胜利 %d 局  ·  最长 %d 秒"
    ) % [stats["total_runs"], stats["total_victories"], stats["best_survival_seconds"]]


func _show_collection_summary() -> void:
    audio_manager.play_event(&"ui_click")
    _refresh_archive()
    archive_backdrop.visible = true
    archive_panel.visible = true
    archive_title.visible = true
    archive_summary.visible = true
    archive_subtitle.visible = true
    archive_back_button.visible = true
    _set_main_chrome_visible(false)
    _set_main_controls_visible(false)
    archive_back_button.grab_focus()


func _hide_archive() -> void:
    audio_manager.play_event(&"ui_click")
    for control: Control in [
        archive_backdrop, archive_panel, archive_title, archive_summary,
        archive_subtitle, archive_back_button
    ]:
        control.visible = false
    _set_main_chrome_visible(true)
    _set_main_controls_visible(true)
    collection_button.grab_focus()


func _refresh_archive() -> void:
    if archive_summary == null or save_game == null:
        return
    var stats: Dictionary = save_game.get_survivor_statistics()
    archive_summary.text = _t(
        "RUNS                 %d\nVICTORIES             %d\nDEFEATS               %d\nLONGEST SURVIVAL      %ds\nMOST ENEMIES          %d\nHIGHEST LEVEL         %d",
        "累计挑战          %d 局\n获胜次数          %d 局\n失败次数          %d 局\n最长生存          %d 秒\n单局最多击杀      %d\n最高达到等级      %d"
    ) % [
        stats["total_runs"], stats["total_victories"], stats["total_defeats"],
        stats["best_survival_seconds"], stats["best_kills"], stats["best_level"]
    ]


func _unhandled_input(event: InputEvent) -> void:
    if archive_backdrop != null and archive_backdrop.visible and event.is_action_pressed("ui_cancel"):
        _hide_archive()
        get_viewport().set_input_as_handled()
        return
    super._unhandled_input(event)


func _select_difficulty(index: int) -> void:
    SurvivorBalance.selected_difficulty = clampi(index, 0, 2)
    settings.survivor_difficulty = SurvivorBalance.selected_difficulty
    settings.save_settings()


func _select_character(index: int) -> void:
    SurvivorCharacters.selected = clampi(index, 0, 2)
    settings.survivor_character = SurvivorCharacters.selected
    settings.save_settings()
