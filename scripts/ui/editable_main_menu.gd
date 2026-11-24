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
    scroll.size = Vector2(600, 246)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    character_screen.add_child(scroll)
    var column: GridContainer = GridContainer.new()
    column.columns = 2
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
        button.custom_minimum_size = Vector2(280, 76)
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
        button.add_theme_constant_override("icon_max_width", 72)
        column.add_child(button)
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
    back.grab_focus()

func _choose_screen_hero(index: int) -> void:
    _select_character(index)
    character_picker.select(SurvivorCharacters.selected)

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
