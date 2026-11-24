extends "res://scripts/ui/greed_main_menu.gd"

var difficulty_picker: OptionButton
var character_picker: OptionButton
var map_picker: OptionButton
var archive_tabs: TabContainer
var character_screen: Control
var select_hero_button: Button
var archive_backdrop: ColorRect
var archive_panel: Panel
var archive_title: Label
var archive_summary: Label
var archive_subtitle: Label
var archive_back_button: Button
var responsive: ResponsiveUI
var resolution_picker: OptionButton
var ui_scale_picker: OptionButton
var hero_detail_portrait: TextureRect
var hero_detail_name: Label
var hero_detail_description: Label
var hero_map_preview: TextureRect
var hero_map_label: Label
var hero_map_picker: OptionButton
var hero_difficulty_picker: OptionButton
var hero_preview_tween: Tween
var music_slider: HSlider
var sfx_slider: HSlider
var audio_save: Timer
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(960,540), Vector2i(1280,720), Vector2i(1366,768), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(2560,1440)]


func _ready() -> void:
    SurvivorChallenge.selected = false
    SurvivorEndurance.selected = false
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
    if not save_game.is_survivor_map_unlocked(SurvivorMaps.selected):
        SurvivorMaps.selected = 0

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
    character_picker.add_theme_constant_override("icon_max_width", 0)
    character_picker.fit_to_longest_item = false
    character_picker.clip_text = true
    get_node("UI/Main").add_child(character_picker)
    character_picker.item_selected.connect(_select_character)
    map_picker = OptionButton.new()
    map_picker.name = "MapPicker"
    map_picker.position = Vector2(226, 145)
    map_picker.size = Vector2(102, 28)
    map_picker.fit_to_longest_item = false
    map_picker.clip_text = true
    get_node("UI/Main").add_child(map_picker)
    map_picker.item_selected.connect(_select_map)
    _create_archive_tabs()
    select_hero_button = Button.new()
    select_hero_button.position = Vector2(28, 184)
    select_hero_button.size = Vector2(300, 34)
    get_node("UI/Main").add_child(select_hero_button)
    select_hero_button.pressed.connect(_show_character_screen)
    PlayfulUITheme.apply_button(select_hero_button, "mint")
    _apply_locale()
    _apply_playful_design()
    _apply_hd_menu()
    _create_display_controls()
    responsive = ResponsiveUI.new()
    add_child(responsive)
    responsive.bind(get_node("UI") as CanvasLayer, settings, _layout_menu)
    settings.settings_changed.connect(_display_settings_changed)
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
    for picker: OptionButton in [difficulty_picker, character_picker, map_picker]:
        PlayfulUITheme.apply_forest_picker(picker)
        picker.add_theme_font_size_override("font_size", 12)
    if is_instance_valid(archive_tabs):
        PlayfulUITheme.apply_tabs(archive_tabs)
    PlayfulUITheme.apply_forest_panel(get_node("World/MenuFrame") as Panel)
    PlayfulUITheme.apply_forest_button(play_button, true)
    for button: Button in [settings_button, collection_button, quit_button, language_button, select_hero_button]:
        PlayfulUITheme.apply_forest_button(button)
    for label: Label in [title_label, subtitle_label, progress_label]:
        PlayfulUITheme.apply_label(label, Color("#fff4d7"))
        label.add_theme_color_override("font_shadow_color", Color(0.02, 0.07, 0.04, 0.8))
        label.add_theme_constant_override("shadow_offset_x", 1)
        label.add_theme_constant_override("shadow_offset_y", 1)



func _apply_locale() -> void:
    super._apply_locale()
    language_button.text = "ZH" if localization.locale_code == "en" else "EN"
    if is_instance_valid(select_hero_button):
        select_hero_button.text = _t("CHOOSE HERO / CHALLENGE", "选择角色 / 挑战")
    if difficulty_picker != null:
        difficulty_picker.clear()
        difficulty_picker.add_item(_t("Easy", "简单"))
        difficulty_picker.add_item(_t("Normal", "普通"))
        difficulty_picker.add_item(_t("Expert", "专家"))
        difficulty_picker.set_item_tooltip(0, _t("Easy: fewer enemies, faster upgrades and generous XP pickup.", "简单：敌人更少，升级更快，经验更容易拾取。"))
        difficulty_picker.set_item_tooltip(1, _t("Normal: balanced growth, lighter late waves.", "普通：成长与挑战平衡，减轻后期敌群压力。"))
        difficulty_picker.set_item_tooltip(2, _t("Expert: original high-pressure rules.", "专家：保留原有高压战斗规则。"))
        difficulty_picker.select(SurvivorBalance.selected_difficulty)
        difficulty_picker.tooltip_text = difficulty_picker.get_item_tooltip(SurvivorBalance.selected_difficulty)
    if character_picker != null:
        character_picker.clear()
        for i: int in range(SurvivorCharacters.EN.size()):
            var short_names: Array[String] = ["Sprout", "Sun", "Frost", "Symbio", "Bramble"]
            character_picker.add_item(_t(short_names[i], SurvivorCharacters.ZH[i]))
            character_picker.set_item_tooltip(i, _t(SurvivorCharacters.DESCRIPTIONS_EN[i], SurvivorCharacters.DESCRIPTIONS_ZH[i]))
            character_picker.set_item_disabled(i, not save_game.is_survivor_character_unlocked(i))
        character_picker.select(SurvivorCharacters.selected)
        character_picker.tooltip_text = _t(SurvivorCharacters.EN[SurvivorCharacters.selected], SurvivorCharacters.ZH[SurvivorCharacters.selected])
    if map_picker != null:
        map_picker.clear()
        for i: int in range(SurvivorMaps.NAMES_EN.size()):
            map_picker.add_item(_t(SurvivorMaps.NAMES_EN[i], SurvivorMaps.NAMES_ZH[i]))
            map_picker.set_item_disabled(i, not save_game.is_survivor_map_unlocked(i))
            if not save_game.is_survivor_map_unlocked(i):
                map_picker.set_item_tooltip(i, _t("Clear the previous map", "通关前一张地图解锁"))
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
    if is_instance_valid(character_screen) and character_screen.visible and event.is_action_pressed("ui_cancel"):
        _hide_character_screen()
        get_viewport().set_input_as_handled()
        return
    if archive_backdrop != null and archive_backdrop.visible and event.is_action_pressed("ui_cancel"):
        _hide_archive()
        get_viewport().set_input_as_handled()
        return
    super._unhandled_input(event)


func _select_difficulty(index: int) -> void:
    SurvivorBalance.selected_difficulty = clampi(index, 0, 2)
    difficulty_picker.tooltip_text = difficulty_picker.get_item_tooltip(SurvivorBalance.selected_difficulty)
    settings.survivor_difficulty = SurvivorBalance.selected_difficulty
    settings.save_settings()


func _select_character(index: int) -> void:
    if not save_game.is_survivor_character_unlocked(index):
        return
    SurvivorCharacters.selected = clampi(index, 0, 4)
    settings.survivor_character = SurvivorCharacters.selected
    settings.save_settings()


func _select_map(index: int) -> void:
    if not save_game.is_survivor_map_unlocked(index):
        return
    SurvivorMaps.selected = clampi(index, 0, 3)
    settings.survivor_map = SurvivorMaps.selected
    settings.save_settings()


func _set_main_controls_visible(value: bool) -> void:
    super._set_main_controls_visible(value)
    (get_node("World/MenuFrame") as Control).visible = value
    for picker: Control in [difficulty_picker, character_picker, map_picker, select_hero_button]:
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
        button.icon = HDArt.portrait(i)
        button.expand_icon = true
        button.custom_minimum_size = Vector2(320, 34)
        button.text = _t(SurvivorCharacters.EN[i], SurvivorCharacters.ZH[i])
        button.tooltip_text = _t(SurvivorCharacters.DESCRIPTIONS_EN[i], SurvivorCharacters.DESCRIPTIONS_ZH[i])
        button.disabled = not save_game.is_survivor_character_unlocked(i)
        button.pressed.connect(_choose_archive_character.bind(i))
        PlayfulUITheme.apply_button(button, "soft", false)
        characters.add_child(button)
    var weapons: VBoxContainer = _archive_page(_t("Weapons", "武器"))
    for i: int in range(SurvivorArsenal.IDS.size()):
        _archive_entry(weapons, HDArt.weapon(SurvivorArsenal.IDS[i]), _t(SurvivorArsenal.NAMES_EN[i], SurvivorArsenal.NAMES_ZH[i]) + "\n" + _t("Lv.3 + ", "三级 + ") + _t(SurvivorArsenal.NAMES_EN[SurvivorArsenal.EVOLUTION_PARTNERS[i]], SurvivorArsenal.NAMES_ZH[SurvivorArsenal.EVOLUTION_PARTNERS[i]]) + "\n" + _t(SurvivorArsenal.DESC_EN[i], SurvivorArsenal.DESC_ZH[i]) + "\n" + _t("Both Lv.3: resonance", "双方三级：共鸣"))
    var enemies: VBoxContainer = _archive_page(_t("Enemies", "敌人"))
    var enemy_names: Array[String] = [_t("Chaser", "追击怪"), _t("Charger", "冲锋怪"), _t("Armored", "重甲怪"), _t("Ranged warning", "远程预警"), _t("Splitter", "分裂怪"), _t("Bloom Boss", "黑花首领")]
    for i: int in range(enemy_names.size()):
        _archive_entry(enemies, HDArt.actor(5 if i == 5 else (4 if i == 2 or i == 4 else 3)), enemy_names[i])
    for map_index: int in range(1, 4):
        _archive_entry(enemies, HDArt.biome(map_index - 1), _t(SurvivorBiomeBoss.EN[map_index], SurvivorBiomeBoss.ZH[map_index]))
        _archive_entry(enemies, HDArt.biome(map_index + 2), _t(SurvivorMaps.NAMES_EN[map_index], SurvivorMaps.NAMES_ZH[map_index]) + _t(" special enemy", "专属敌人"))
    var progress_page: VBoxContainer = _archive_page(_t("Growth", "成长"))
    var progress: Dictionary = save_game.get_survivor_progress()
    var stats: Dictionary = save_game.get_survivor_statistics()
    _archive_entry(progress_page, null, _t("Seeds %d · Wins %d · Events %d · Evolutions %d", "种子 %d · 胜利 %d · 事件 %d · 进化 %d") % [progress["seeds"], stats["total_victories"], progress["events"], progress["evolutions"]])
    _archive_entry(progress_page, null, _t("Endless best: %ds / %d bosses · Daily: %s", "无尽纪录：%d秒 / %d首领 · 每日：%s") % [progress["endless_best_seconds"], progress["endless_best_bosses"], progress["last_daily_win"]])
    var map_wins: Array = progress["map_wins"]
    for map_index: int in range(4):
        _archive_entry(progress_page, null, _t(SurvivorMaps.NAMES_EN[map_index], SurvivorMaps.NAMES_ZH[map_index]) + " · " + _t("%d wins", "%d 次胜利") % int(map_wins[map_index]))
    for key: String in ["health_rank", "damage_rank", "speed_rank"]:
        var rank: int = int(progress[key])
        var upgrade: Button = Button.new()
        upgrade.text = (_t("Health +1", "生命 +1") if key == "health_rank" else (_t("Damage +5%", "伤害 +5%") if key == "damage_rank" else _t("Speed +3%", "移速 +3%"))) + " · %d/3 · %d" % [rank, 15 * (rank + 1)]
        upgrade.disabled = rank >= 3 or int(progress["seeds"]) < 15 * (rank + 1)
        upgrade.pressed.connect(_buy_archive_upgrade.bind(key))
        PlayfulUITheme.apply_button(upgrade, "soft", false)
        progress_page.add_child(upgrade)
    _archive_entry(progress_page, null, _t("Achievements", "成就") + "\n" + _t("First victory: ", "初次胜利：") + str(mini(1, int(stats["total_victories"]))) + "/1 · " + _t("Events: ", "事件达人：") + str(mini(5, int(progress["events"]))) + "/5 · " + _t("Evolutions: ", "进化大师：") + str(mini(3, int(progress["evolutions"]))) + "/3")
    var achievement_keys: Array[String] = ["first_win", "events", "evolutions", "challenge", "endurance", "map_mastery", "all_map_wins", "endurance_300"]
    var achievement_names: Array[String] = [_t("First victory", "首次胜利"), _t("Five events", "完成五个事件"), _t("Three evolutions", "三次进化"), _t("Challenge victory", "挑战胜利"), _t("Two endless bosses", "无尽击败两位首领"), _t("All maps unlocked", "全部地图解锁"), _t("Win on every map", "四张地图均通关"), _t("Survive 300s in endless", "无尽生存300秒")]
    for i: int in range(achievement_keys.size()):
        var claim: Button = Button.new()
        claim.text = achievement_names[i] + " · +15"
        claim.disabled = not save_game.achievement_available(achievement_keys[i])
        claim.pressed.connect(_claim_archive_achievement.bind(achievement_keys[i]))
        PlayfulUITheme.apply_button(claim, "soft", false)
        progress_page.add_child(claim)
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
    label.add_theme_color_override("font_color", Color("3e4632"))
    row.add_child(label)


func _choose_archive_character(index: int) -> void:
    _select_character(index)
    character_picker.select(SurvivorCharacters.selected)
    _hide_archive()


func _buy_archive_upgrade(key: String) -> void:
    if save_game.buy_survivor_upgrade(key):
        call_deferred("_refresh_archive_tabs")


func _claim_archive_achievement(key: String) -> void:
    if save_game.claim_achievement(key):
        call_deferred("_refresh_archive_tabs")

func _show_character_screen() -> void:
    if is_instance_valid(character_screen):
        character_screen.queue_free()
    _set_main_chrome_visible(false)
    _set_main_controls_visible(false)
    character_screen = Control.new()
    character_screen.name = "HeroSelection"
    get_node("UI").add_child(character_screen)
    var backdrop: ColorRect = ColorRect.new()
    backdrop.name = "Backdrop"
    backdrop.size = Vector2(640, 360)
    backdrop.color = Color(0.07, 0.13, 0.10, 0.93)
    character_screen.add_child(backdrop)
    var title: Label = Label.new()
    title.position = Vector2(20, 12)
    title.size = Vector2(600, 30)
    title.text = _t("CHOOSE YOUR GUARDIAN", "选择你的守护者")
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 22)
    PlayfulUITheme.apply_label(title, Color("#f5df9c"))
    character_screen.add_child(title)
    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.position = Vector2(20, 50)
    scroll.size = Vector2(330, 246)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    character_screen.add_child(scroll)
    var column: GridContainer = GridContainer.new()
    column.columns = 1
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("h_separation", 8)
    column.add_theme_constant_override("v_separation", 8)
    scroll.add_child(column)
    var group: ButtonGroup = ButtonGroup.new()
    for i: int in range(SurvivorCharacters.EN.size()):
        var cfg: Dictionary = SurvivorCharacters.configuration(i)
        var button: Button = Button.new()
        button.icon = HDArt.portrait(i)
        button.expand_icon = true
        button.custom_minimum_size = Vector2(306, 68)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.text = _t(SurvivorCharacters.EN[i], SurvivorCharacters.ZH[i]) + "\n" + _t("DMG %.0f · SPD %.0f · HP %+d", "伤害 %.0f · 移速 %.0f · 生命 %+d") % [cfg["damage"], cfg["move_speed"], cfg["health_bonus"]]
        button.tooltip_text = _t(SurvivorCharacters.DESCRIPTIONS_EN[i], SurvivorCharacters.DESCRIPTIONS_ZH[i])
        button.disabled = not save_game.is_survivor_character_unlocked(i)
        if button.disabled:
            button.text += "\n" + _t("LOCKED", "未解锁")
        button.add_theme_font_size_override("font_size", 13)
        button.toggle_mode = true
        button.button_group = group
        button.button_pressed = i == SurvivorCharacters.selected
        button.pressed.connect(_choose_screen_hero.bind(i))
        PlayfulUITheme.apply_forest_button(button)
        button.add_theme_constant_override("icon_max_width", 60)
        column.add_child(button)
    var details: Panel = Panel.new()
    character_screen.add_child(details)
    ResponsiveUI.place(details, Rect2(360, 50, 260, 246))
    PlayfulUITheme.apply_forest_panel(details)
    hero_detail_portrait = TextureRect.new()
    hero_detail_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    hero_detail_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    hero_detail_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    details.add_child(hero_detail_portrait)
    ResponsiveUI.place(hero_detail_portrait, Rect2(80, 6, 100, 82))
    hero_detail_name = Label.new()
    hero_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hero_detail_name.add_theme_font_size_override("font_size", 17)
    PlayfulUITheme.apply_label(hero_detail_name, Color("#f5df9c"))
    details.add_child(hero_detail_name)
    ResponsiveUI.place(hero_detail_name, Rect2(10, 88, 240, 25))
    hero_detail_description = Label.new()
    hero_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hero_detail_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hero_detail_description.add_theme_font_size_override("font_size", 12)
    PlayfulUITheme.apply_label(hero_detail_description, Color("#f8f3de"))
    details.add_child(hero_detail_description)
    ResponsiveUI.place(hero_detail_description, Rect2(12, 113, 236, 43))
    hero_map_preview = TextureRect.new()
    hero_map_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    hero_map_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    hero_map_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
    details.add_child(hero_map_preview)
    ResponsiveUI.place(hero_map_preview, Rect2(12, 166, 77, 62))
    hero_map_label = Label.new()
    hero_map_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hero_map_label.add_theme_font_size_override("font_size", 12)
    PlayfulUITheme.apply_label(hero_map_label, Color("#f8f3de"))
    details.add_child(hero_map_label)
    ResponsiveUI.place(hero_map_label, Rect2(12, 229, 77, 14))
    hero_map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hero_map_label.add_theme_font_size_override("font_size", 10)
    hero_map_picker = OptionButton.new()
    details.add_child(hero_map_picker)
    ResponsiveUI.place(hero_map_picker, Rect2(98, 164, 150, 29))
    hero_difficulty_picker = OptionButton.new()
    details.add_child(hero_difficulty_picker)
    ResponsiveUI.place(hero_difficulty_picker, Rect2(98, 201, 150, 29))
    for picker: OptionButton in [hero_map_picker, hero_difficulty_picker]:
        picker.fit_to_longest_item = false
        picker.clip_text = true
        PlayfulUITheme.apply_forest_picker(picker)
        picker.add_theme_font_size_override("font_size", 12)
    for i: int in range(map_picker.item_count):
        hero_map_picker.add_item(map_picker.get_item_text(i))
        hero_map_picker.set_item_disabled(i, map_picker.is_item_disabled(i))
        hero_map_picker.set_item_tooltip(i, map_picker.get_item_tooltip(i))
    for i: int in range(difficulty_picker.item_count):
        hero_difficulty_picker.add_item(difficulty_picker.get_item_text(i))
        hero_difficulty_picker.set_item_tooltip(i, difficulty_picker.get_item_tooltip(i))
    hero_map_picker.item_selected.connect(_choose_screen_map)
    hero_difficulty_picker.item_selected.connect(_choose_screen_difficulty)
    _refresh_hero_detail()
    var back: Button = Button.new()
    back.position = Vector2(20, 306)
    back.size = Vector2(100, 36)
    back.text = _t("BACK", "返回")
    back.pressed.connect(_hide_character_screen)
    PlayfulUITheme.apply_forest_button(back)
    character_screen.add_child(back)
    var start: Button = Button.new()
    start.position = Vector2(126, 306)
    start.size = Vector2(154, 36)
    start.text = _t("START RUN", "开始冒险")
    start.pressed.connect(_start_screen_run.bind(false))
    PlayfulUITheme.apply_forest_button(start, true)
    character_screen.add_child(start)
    var challenge: Button = Button.new()
    challenge.position = Vector2(286, 306)
    challenge.size = Vector2(170, 36)
    challenge.text = _t("DAILY CHALLENGE", "每日挑战")
    challenge.tooltip_text = SurvivorChallenge.date_key() + " · " + _t("UTC seed · Night garden · no permanent bonuses", "UTC每日种子 · 夜间花园 · 禁用永久加成")
    challenge.pressed.connect(_start_screen_run.bind(true))
    PlayfulUITheme.apply_forest_button(challenge)
    character_screen.add_child(challenge)
    var endless: Button = Button.new()
    endless.position = Vector2(462, 306)
    endless.size = Vector2(158, 36)
    endless.text = _t("ENDLESS", "无尽模式")
    endless.pressed.connect(_start_endless)
    PlayfulUITheme.apply_forest_button(endless)
    character_screen.add_child(endless)
    if is_instance_valid(responsive):
        responsive.refresh()
    back.grab_focus()

func _choose_screen_hero(index: int) -> void:
    _select_character(index)
    character_picker.select(SurvivorCharacters.selected)
    _refresh_hero_detail()
    if is_instance_valid(hero_detail_portrait):
        if hero_preview_tween != null and hero_preview_tween.is_valid():
            hero_preview_tween.kill()
        hero_detail_portrait.modulate.a = 0.7
        hero_preview_tween = hero_detail_portrait.create_tween()
        hero_preview_tween.tween_property(hero_detail_portrait, "modulate:a", 1.0, 0.16)

func _choose_screen_map(index: int) -> void:
    _select_map(index)
    map_picker.select(SurvivorMaps.selected)
    _refresh_hero_detail()

func _choose_screen_difficulty(index: int) -> void:
    _select_difficulty(index)
    difficulty_picker.select(SurvivorBalance.selected_difficulty)
    _refresh_hero_detail()

func _hide_character_screen() -> void:
    if is_instance_valid(character_screen):
        character_screen.hide()
        character_screen.queue_free()
    character_screen = null
    _set_main_chrome_visible(true)
    _set_main_controls_visible(true)
    select_hero_button.grab_focus()

func _start_screen_run(challenge: bool) -> void:
    SurvivorChallenge.selected = challenge
    SurvivorEndurance.selected = false
    _open_level_select()


func _start_endless() -> void:
    SurvivorChallenge.selected = false
    SurvivorEndurance.selected = true
    _open_level_select()


func _apply_hd_menu() -> void:
    var background: Texture2D = HDArt.load_png("menu/background")
    if background == null:
        background = HDArt.terrain(SurvivorMaps.CLASSIC)
    if background != null:
        var grass: TextureRect = get_node("World/Grass") as TextureRect
        grass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        grass.texture = background
        grass.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        grass.modulate = Color.WHITE if HDArt.load_png("menu/background") != null else Color(0.82, 0.90, 0.78, 1.0)
        (get_node("World/Shade") as ColorRect).color = Color(0.06, 0.13, 0.09, 0.36)
    var names: Array[String] = ["HeroPreview", "FamiliarSunPreview", "FamiliarSproutPreview"]
    var ids: Array[int] = [0, 1, 2]
    for i: int in range(names.size()):
        var preview: Node2D = get_node("World/" + names[i]) as Node2D
        var image: Texture2D = HDArt.portrait(ids[i])
        if image == null:
            continue
        var sprite: Sprite2D = Sprite2D.new()
        sprite.name = names[i] + "HD"
        sprite.texture = image
        sprite.position = preview.position
        sprite.scale = Vector2.ONE * HDArt.fit(image, 112.0 if i == 0 else 70.0)
        preview.hide()
        preview.get_parent().add_child(sprite)

func _create_display_controls() -> void:
    var group: Control = get_node("UI/Settings") as Control
    ResponsiveUI.place(settings_panel, Rect2(92, 20, 456, 320))
    ResponsiveUI.place(settings_title_label, Rect2(112, 29, 416, 32))
    ResponsiveUI.place(settings_language_button, Rect2(112, 64, 202, 30))
    ResponsiveUI.place(flash_button, Rect2(326, 64, 202, 30))
    ResponsiveUI.place(music_button, Rect2(112, 100, 202, 28))
    ResponsiveUI.place(sfx_button, Rect2(326, 100, 202, 28))
    ResponsiveUI.place(fullscreen_button, Rect2(112, 164, 416, 30))
    ResponsiveUI.place(settings_back_button, Rect2(220, 294, 200, 32))
    PlayfulUITheme.apply_forest_panel(settings_panel)
    PlayfulUITheme.apply_label(settings_title_label, Color("#f5df9c"))
    for button: Button in [settings_language_button, flash_button, music_button, sfx_button, fullscreen_button, settings_back_button]:
        PlayfulUITheme.apply_forest_button(button, button == settings_back_button)
    resolution_picker = OptionButton.new()
    resolution_picker.name = "ResolutionPicker"
    group.add_child(resolution_picker)
    ResponsiveUI.place(resolution_picker, Rect2(112, 204, 416, 32))
    resolution_picker.item_selected.connect(_select_resolution)
    ui_scale_picker = OptionButton.new()
    ui_scale_picker.name = "UIScalePicker"
    group.add_child(ui_scale_picker)
    ResponsiveUI.place(ui_scale_picker, Rect2(112, 244, 416, 32))
    ui_scale_picker.item_selected.connect(_select_ui_scale)
    for picker: OptionButton in [resolution_picker, ui_scale_picker]:
        PlayfulUITheme.apply_forest_picker(picker)
        picker.fit_to_longest_item = false
        picker.hide()
    audio_save = Timer.new()
    audio_save.one_shot = true
    audio_save.wait_time = 0.3
    add_child(audio_save)
    audio_save.timeout.connect(settings.save_settings)
    music_slider = _volume_slider(group, Rect2(119, 132, 188, 22), settings.music_volume_db, true)
    sfx_slider = _volume_slider(group, Rect2(333, 132, 188, 22), settings.sfx_volume_db, false)
    _refresh_settings_buttons()

func _volume_slider(group: Control, rect: Rect2, value: float, music: bool) -> HSlider:
    var slider: HSlider = HSlider.new()
    slider.name = "MusicVolume" if music else "SfxVolume"
    group.add_child(slider)
    slider.min_value = -60
    slider.max_value = 0
    slider.step = 1
    slider.value = value
    ResponsiveUI.place(slider, rect)
    PlayfulUITheme.apply_forest_slider(slider)
    slider.value_changed.connect(_volume_changed.bind(music))
    slider.hide()
    return slider

func _volume_changed(value: float, music: bool) -> void:
    if music:
        settings.music_volume_db = value
    else:
        settings.sfx_volume_db = value
    settings.apply_runtime(audio_manager)
    audio_save.start()
    _refresh_volume_labels()

func _refresh_volume_labels() -> void:
    music_button.text = _t("Music: %s · %d dB", "音乐：%s · %d dB") % [_on_off(settings.music_enabled), settings.music_volume_db]
    sfx_button.text = _t("Sound: %s · %d dB", "音效：%s · %d dB") % [_on_off(settings.sfx_enabled), settings.sfx_volume_db]

func _display_settings_changed() -> void:
    if settings_panel.visible and not resolution_picker.get_popup().visible and not ui_scale_picker.get_popup().visible:
        _refresh_settings_buttons()

func _hide_settings() -> void:
    if is_instance_valid(audio_save) and not audio_save.is_stopped():
        audio_save.stop()
        settings.save_settings()
    super._hide_settings()

func _toggle_fullscreen() -> void:
    audio_manager.play_event(&"ui_click")
    settings.set_display_mode((settings.display_mode + 1) % 3)
    _refresh_settings_buttons()

func _refresh_settings_buttons() -> void:
    super._refresh_settings_buttons()
    if not is_instance_valid(resolution_picker):
        return
    _refresh_volume_labels()
    var modes: Array[String] = [_t("Windowed", "窗口化"), _t("Borderless fullscreen", "无边框全屏"), _t("Exclusive fullscreen", "独占全屏")]
    fullscreen_button.text = _t("Display: ", "显示模式：") + modes[settings.display_mode]
    resolution_picker.clear()
    var selected_index: int = -1
    for i: int in range(WINDOW_SIZES.size()):
        var value: Vector2i = WINDOW_SIZES[i]
        resolution_picker.add_item("%d × %d" % [value.x, value.y], i)
        if value == settings.window_size:
            selected_index = i
    if selected_index < 0:
        selected_index = WINDOW_SIZES.size()
        resolution_picker.add_item(_t("Custom", "自定义") + " %d × %d" % [settings.window_size.x, settings.window_size.y], selected_index)
    resolution_picker.select(selected_index)
    resolution_picker.disabled = settings.display_mode != 0 or not SettingsService.native_display()
    ui_scale_picker.clear()
    for percent: int in [80, 90, 100, 110, 125]:
        ui_scale_picker.add_item(_t("UI scale: ", "界面缩放：") + "%d%%" % percent, percent)
        if is_equal_approx(settings.ui_scale, percent / 100.0):
            ui_scale_picker.select(ui_scale_picker.item_count - 1)
    ui_scale_picker.tooltip_text = _t("Automatically limited to fit the window", "自动限制缩放，防止界面超出窗口")

func _set_settings_controls_visible(value: bool) -> void:
    super._set_settings_controls_visible(value)
    if is_instance_valid(resolution_picker):
        resolution_picker.visible = value and not OS.has_feature("web")
        ui_scale_picker.visible = value
    if is_instance_valid(music_slider):
        music_slider.visible = value
        sfx_slider.visible = value

func _select_resolution(index: int) -> void:
    if index >= 0 and index < WINDOW_SIZES.size():
        settings.set_resolution(WINDOW_SIZES[index])
        _refresh_settings_buttons()

func _select_ui_scale(index: int) -> void:
    settings.set_ui_scale(ui_scale_picker.get_item_id(index) / 100.0)
    responsive.refresh()

func _layout_menu(view: Vector2) -> void:
    for path: String in ["UI/Main", "UI/Settings", "UI/Archive"]:
        ResponsiveUI.center_group(get_node(path) as Control, view)
    if is_instance_valid(character_screen):
        ResponsiveUI.center_group(character_screen, view)
    var physical_view: Vector2 = get_viewport().get_visible_rect().size
    for path: String in ["World/Backdrop", "World/Grass", "World/Shade"]:
        (get_node(path) as Control).size = physical_view
    var frame: Panel = get_node("World/MenuFrame") as Panel
    var factor: float = (get_node("UI") as CanvasLayer).scale.x * (get_node("UI/Main") as Control).scale.x
    frame.scale = Vector2.ONE * factor
    frame.position = (physical_view - ResponsiveUI.BASE * factor) * 0.5 + Vector2(338, 76) * factor
    for child: Node in get_node("World").get_children():
        if child is Sprite2D and String(child.name).ends_with("PreviewHD"):
            if not child.has_meta("base_position"):
                child.set_meta("base_position", child.position)
                child.set_meta("base_scale", child.scale)
            child.scale = Vector2(child.get_meta("base_scale")) * factor
            child.position = (physical_view - ResponsiveUI.BASE * factor) * 0.5 + Vector2(child.get_meta("base_position")) * factor

func _refresh_hero_detail() -> void:
    if not is_instance_valid(hero_detail_portrait):
        return
    var id: int = SurvivorCharacters.selected
    hero_detail_portrait.texture = HDArt.portrait(id)
    hero_detail_name.text = _t(SurvivorCharacters.EN[id], SurvivorCharacters.ZH[id])
    hero_detail_description.text = _t(SurvivorCharacters.DESCRIPTIONS_EN[id], SurvivorCharacters.DESCRIPTIONS_ZH[id])
    hero_map_preview.texture = HDArt.terrain(SurvivorMaps.selected)
    hero_map_label.text = _t("MAP", "地图")
    hero_map_picker.select(SurvivorMaps.selected)
    hero_difficulty_picker.select(SurvivorBalance.selected_difficulty)
