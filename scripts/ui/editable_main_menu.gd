extends "res://scripts/ui/greed_main_menu.gd"

var difficulty_picker: OptionButton
var character_picker: OptionButton
var map_picker: OptionButton
var archive_tabs: TabContainer
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
    SurvivorMaps.selected = settings.survivor_map
    localization = LocalizationService.new()
    localization.set_locale(settings.locale, false)
    save_game = SaveGameService.new()
    save_game.load_game()
    if not save_game.is_survivor_character_unlocked(SurvivorCharacters.selected):
        SurvivorCharacters.selected = 0

    audio_manager = ProceduralAudioManager.new()
    audio_manager.name = "MenuAudio"
    add_child(audio_manager)
    settings.apply_runtime(audio_manager)

    _bind_existing_ui()
    difficulty_picker = OptionButton.new()
    difficulty_picker.name = "DifficultyPicker"
    difficulty_picker.position = Vector2(28, 145)
    difficulty_picker.size = Vector2(92, 28)
    get_node("UI/Main").add_child(difficulty_picker)
    difficulty_picker.item_selected.connect(_select_difficulty)
    character_picker = OptionButton.new()
    character_picker.name = "CharacterPicker"
    character_picker.position = Vector2(126, 145)
    character_picker.size = Vector2(94, 28)
    get_node("UI/Main").add_child(character_picker)
    character_picker.item_selected.connect(_select_character)
    map_picker = OptionButton.new()
    map_picker.name = "MapPicker"
    map_picker.position = Vector2(226, 145)
    map_picker.size = Vector2(102, 28)
    get_node("UI/Main").add_child(map_picker)
    map_picker.item_selected.connect(_select_map)
    _create_archive_tabs()
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
        for i: int in range(SurvivorCharacters.EN.size()):
            character_picker.add_icon_item(PixelArtAssets.generated_actor(SurvivorCharacters.art_index(i)), _t(SurvivorCharacters.EN[i], SurvivorCharacters.ZH[i]))
            character_picker.set_item_tooltip(i, _t(SurvivorCharacters.DESCRIPTIONS_EN[i], SurvivorCharacters.DESCRIPTIONS_ZH[i]))
            character_picker.set_item_disabled(i, not save_game.is_survivor_character_unlocked(i))
        character_picker.select(SurvivorCharacters.selected)
    if map_picker != null:
        map_picker.clear()
        for i: int in range(SurvivorMaps.NAMES_EN.size()):
            map_picker.add_item(_t(SurvivorMaps.NAMES_EN[i], SurvivorMaps.NAMES_ZH[i]))
        map_picker.select(SurvivorMaps.selected)
    if archive_title == null:
        return
    archive_title.text = _t("GARDEN JOURNAL", "花园战绩")
    archive_subtitle.text = _t("Every little run makes the garden grow.", "每一局，都是芽芽成长的足迹。")
    archive_back_button.text = _t("BACK TO GARDEN", "返回花园")
    _refresh_archive()
    _refresh_archive_tabs()
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
    archive_summary.visible = false
    archive_subtitle.visible = false
    archive_tabs.show()
    _refresh_archive_tabs()
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
    if is_instance_valid(archive_tabs):
        archive_tabs.hide()
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
    if not save_game.is_survivor_character_unlocked(index):
        return
    SurvivorCharacters.selected = clampi(index, 0, 3)
    settings.survivor_character = SurvivorCharacters.selected
    settings.save_settings()


func _select_map(index: int) -> void:
    SurvivorMaps.selected = clampi(index, 0, 3)
    settings.survivor_map = SurvivorMaps.selected
    settings.save_settings()


func _set_main_controls_visible(value: bool) -> void:
    super._set_main_controls_visible(value)
    for picker: OptionButton in [difficulty_picker, character_picker, map_picker]:
        if is_instance_valid(picker):
            picker.visible = value


func _create_archive_tabs() -> void:
    archive_tabs = TabContainer.new()
    archive_tabs.name = "GardenArchiveTabs"
    archive_tabs.position = Vector2(139, 82)
    archive_tabs.size = Vector2(362, 190)
    get_node("UI/Archive").add_child(archive_tabs)
    archive_tabs.hide()


func _refresh_archive_tabs() -> void:
    if not is_instance_valid(archive_tabs):
        return
    var previous: int = maxi(0, archive_tabs.current_tab)
    for child: Node in archive_tabs.get_children():
        archive_tabs.remove_child(child)
        child.queue_free()
    var characters: VBoxContainer = _archive_page(_t("Heroes", "角色"))
    for i: int in range(SurvivorCharacters.EN.size()):
        var button: Button = Button.new()
        button.icon = PixelArtAssets.generated_actor(SurvivorCharacters.art_index(i))
        button.expand_icon = true
        button.custom_minimum_size = Vector2(320, 34)
        button.text = _t(SurvivorCharacters.EN[i], SurvivorCharacters.ZH[i])
        button.tooltip_text = _t(SurvivorCharacters.DESCRIPTIONS_EN[i], SurvivorCharacters.DESCRIPTIONS_ZH[i])
        button.disabled = not save_game.is_survivor_character_unlocked(i)
        button.pressed.connect(_choose_archive_character.bind(i))
        characters.add_child(button)
    var weapons: VBoxContainer = _archive_page(_t("Weapons", "武器"))
    for i: int in range(SurvivorArsenal.IDS.size()):
        _archive_entry(weapons, PixelArtAssets.blessing_icon(SurvivorArsenal.IDS[i]), _t(SurvivorArsenal.NAMES_EN[i], SurvivorArsenal.NAMES_ZH[i]) + "\n" + _t("Lv.3 + ", "三级 + ") + _t(SurvivorArsenal.NAMES_EN[SurvivorArsenal.EVOLUTION_PARTNERS[i]], SurvivorArsenal.NAMES_ZH[SurvivorArsenal.EVOLUTION_PARTNERS[i]]))
    var enemies: VBoxContainer = _archive_page(_t("Enemies", "敌人"))
    var enemy_names: Array[String] = [_t("Chaser", "追击怪"), _t("Charger", "冲锋怪"), _t("Armored", "重甲怪"), _t("Ranged warning", "远程预警"), _t("Splitter", "分裂怪"), _t("Bloom Boss", "黑花首领")]
    for i: int in range(enemy_names.size()):
        _archive_entry(enemies, PixelArtAssets.generated_actor(5 if i == 5 else (4 if i == 2 or i == 4 else 3)), enemy_names[i])
    var progress_page: VBoxContainer = _archive_page(_t("Growth", "成长"))
    var progress: Dictionary = save_game.get_survivor_progress()
    var stats: Dictionary = save_game.get_survivor_statistics()
    _archive_entry(progress_page, null, _t("Seeds %d · Wins %d · Events %d · Evolutions %d", "种子 %d · 胜利 %d · 事件 %d · 进化 %d") % [progress["seeds"], stats["total_victories"], progress["events"], progress["evolutions"]])
    for key: String in ["health_rank", "damage_rank"]:
        var rank: int = int(progress[key])
        var upgrade: Button = Button.new()
        upgrade.text = (_t("Health +1", "生命 +1") if key == "health_rank" else _t("Damage +5%", "伤害 +5%")) + " · %d/3 · %d" % [rank, 15 * (rank + 1)]
        upgrade.disabled = rank >= 3 or int(progress["seeds"]) < 15 * (rank + 1)
        upgrade.pressed.connect(_buy_archive_upgrade.bind(key))
        progress_page.add_child(upgrade)
    _archive_entry(progress_page, null, _t("Achievements", "成就") + "\n" + _t("First victory: ", "初次胜利：") + str(mini(1, int(stats["total_victories"]))) + "/1 · " + _t("Events: ", "事件达人：") + str(mini(5, int(progress["events"]))) + "/5 · " + _t("Evolutions: ", "进化大师：") + str(mini(3, int(progress["evolutions"]))) + "/3")
    _archive_entry(progress_page, null, archive_summary.text)
    archive_tabs.current_tab = mini(previous, archive_tabs.get_tab_count() - 1)


func _archive_page(title_value: String) -> VBoxContainer:
    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.name = title_value
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    archive_tabs.add_child(scroll)
    var column: VBoxContainer = VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(column)
    return column


func _archive_entry(parent: VBoxContainer, texture_value: Texture2D, value: String) -> void:
    var row: HBoxContainer = HBoxContainer.new()
    parent.add_child(row)
    if texture_value != null:
        var icon: TextureRect = TextureRect.new()
        icon.texture = texture_value
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.custom_minimum_size = Vector2(38, 38)
        row.add_child(icon)
    var label: Label = Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_font_size_override("font_size", 12)
    row.add_child(label)


func _choose_archive_character(index: int) -> void:
    _select_character(index)
    character_picker.select(SurvivorCharacters.selected)
    _hide_archive()


func _buy_archive_upgrade(key: String) -> void:
    if save_game.buy_survivor_upgrade(key):
        call_deferred("_refresh_archive_tabs")
