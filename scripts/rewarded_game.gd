extends "res://scripts/campaign_game.gd"

var blessing_system: BlessingSystem
var combat_reward_system: CombatRewardSystem
var auto_battle_director: AutoBattleDirector

var combo_label: Label
var chest_meter_label: Label
var auto_button: Button
var auto_countdown_label: Label

var chest_backdrop: ColorRect
var chest_panel: Panel
var chest_title_label: Label
var chest_choice_buttons: Array[Button] = []
var _current_choices: Array[BlessingData] = []
var _resume_after_chest: bool = false


func _create_systems() -> void:
    super._create_systems()

    blessing_system = BlessingSystem.new()
    blessing_system.name = "BlessingSystem"
    add_child(blessing_system)
    blessing_system.setup(_load_blessing_pool())

    combat_reward_system = CombatRewardSystem.new()
    combat_reward_system.name = "CombatRewardSystem"
    add_child(combat_reward_system)
    combat_reward_system.setup(12, 3.2)

    auto_battle_director = AutoBattleDirector.new()
    auto_battle_director.name = "AutoBattleDirector"
    add_child(auto_battle_director)

    blessing_system.sunlight_jackpot.connect(_on_sunlight_jackpot)
    blessing_system.blessing_applied.connect(_on_blessing_applied)
    combat_reward_system.combo_changed.connect(_on_combo_changed)
    combat_reward_system.chest_progress_changed.connect(_on_chest_progress_changed)
    combat_reward_system.chest_ready.connect(_on_chest_ready)
    auto_battle_director.auto_changed.connect(_on_auto_changed)
    auto_battle_director.countdown_changed.connect(_on_auto_countdown_changed)
    auto_battle_director.start_requested.connect(_on_auto_start_requested)


func _create_ui() -> void:
    super._create_ui()
    var canvas: Node = get_node_or_null("UI")
    if canvas == null:
        return

    _make_panel(canvas, Vector2(8.0, 48.0), Vector2(104.0, 112.0), Color(0.04, 0.10, 0.11, 0.95), Color("d5b34f"))
    combo_label = _make_label(canvas, Vector2(14.0, 54.0), Vector2(92.0, 22.0))
    combo_label.add_theme_font_size_override("font_size", 12)
    chest_meter_label = _make_label(canvas, Vector2(14.0, 76.0), Vector2(92.0, 26.0))
    chest_meter_label.add_theme_font_size_override("font_size", 11)
    chest_meter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    auto_button = _make_button(canvas, "AUTO", Vector2(14.0, 106.0), Vector2(92.0, 26.0))
    auto_button.pressed.connect(_toggle_auto_battle)
    auto_countdown_label = _make_label(canvas, Vector2(14.0, 134.0), Vector2(92.0, 20.0))
    auto_countdown_label.add_theme_font_size_override("font_size", 10)
    auto_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    chest_backdrop = ColorRect.new()
    chest_backdrop.position = Vector2.ZERO
    chest_backdrop.size = Vector2(640.0, 360.0)
    chest_backdrop.color = Color(0.02, 0.025, 0.035, 0.94)
    chest_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    chest_backdrop.visible = false
    canvas.add_child(chest_backdrop)

    chest_panel = _make_panel(canvas, Vector2(84.0, 54.0), Vector2(472.0, 252.0), Color(0.07, 0.08, 0.11, 0.995), Color("f0c64e"))
    chest_panel.visible = false
    chest_title_label = _make_label(canvas, Vector2(104.0, 68.0), Vector2(432.0, 42.0))
    chest_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    chest_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    chest_title_label.add_theme_font_size_override("font_size", 21)
    chest_title_label.visible = false

    for index: int in range(3):
        var button: Button = _make_button(canvas, "Blessing", Vector2(108.0, 118.0 + float(index) * 56.0), Vector2(424.0, 46.0))
        button.add_theme_font_size_override("font_size", 12)
        button.pressed.connect(_select_blessing.bind(index))
        button.visible = false
        chest_choice_buttons.append(button)

    _refresh_reward_hud()


func _apply_locale() -> void:
    super._apply_locale()
    if auto_button == null:
        return
    _refresh_reward_hud()
    _refresh_chest_choices()


func _build_tower(slot_index: int) -> void:
    var previous: Variant = towers_by_slot.get(slot_index)
    super._build_tower(slot_index)
    var built: SproutTower = towers_by_slot.get(slot_index) as SproutTower
    if built == null or built == previous:
        return
    built.attach_blessing_system(blessing_system)
    built.critical_shot.connect(_on_tower_critical_shot)


func _start_next_wave() -> void:
    auto_battle_director.cancel()
    super._start_next_wave()


func _on_enemy_defeated(enemy: SproutEnemy, reward: int) -> void:
    var elite: bool = enemy != null and enemy.data != null and enemy.data.id == &"forest_golem"
    enemy_registry.unregister_enemy(enemy)
    combat_reward_system.register_kill(elite)
    var modified_reward: int = blessing_system.modify_reward(reward)
    modified_reward = int(round(float(modified_reward) * combat_reward_system.get_combo_reward_multiplier()))
    economy_system.earn(modified_reward, &"enemy_defeated")
    wave_manager.notify_enemy_removed()

    var tier: int = combat_reward_system.get_combo_tier()
    if tier > 0 and combat_reward_system.combo % 5 == 0:
        _show_feedback(_run_t("COMBO x%d", "连击 x%d") % combat_reward_system.combo, Color("ffe477"))
        audio_manager.play_event(&"combo")


func _on_enemy_escaped(enemy: SproutEnemy, damage_value: int) -> void:
    combat_reward_system.register_escape()
    super._on_enemy_escaped(enemy, damage_value)


func _on_wave_completed(index: int, clear_reward: int) -> void:
    super._on_wave_completed(index, clear_reward)
    combat_reward_system.register_wave_clear()
    if index < wave_manager.get_total_waves() - 1:
        auto_battle_director.arm()


func _on_game_finished(victory: bool) -> void:
    auto_battle_director.cancel()
    auto_battle_director.set_blocked(true)
    super._on_game_finished(victory)


func _toggle_auto_battle() -> void:
    audio_manager.play_event(&"ui_click")
    var enabled: bool = auto_battle_director.toggle()
    if enabled and game_manager.state == GameManager.State.PREPARING:
        auto_battle_director.arm(1.0)
    _refresh_reward_hud()


func _on_auto_start_requested() -> void:
    if game_manager.game_ended or chest_panel.visible:
        return
    if game_manager.state == GameManager.State.PREPARING:
        _start_next_wave()


func _on_auto_changed(_enabled: bool) -> void:
    _refresh_reward_hud()


func _on_auto_countdown_changed(seconds_remaining: float, waiting: bool) -> void:
    if auto_countdown_label == null:
        return
    if not waiting or not auto_battle_director.auto_enabled:
        auto_countdown_label.text = ""
        return
    auto_countdown_label.text = _run_t("NEXT %.1fs", "下波 %.1f秒") % seconds_remaining


func _on_combo_changed(_combo: int, _tier: int, _time_remaining: float) -> void:
    _refresh_reward_hud()


func _on_chest_progress_changed(_progress: int, _target: int) -> void:
    _refresh_reward_hud()


func _on_chest_ready(_pending_chests: int) -> void:
    if chest_panel == null or chest_panel.visible:
        return
    if not combat_reward_system.consume_chest():
        return
    _current_choices = blessing_system.roll_choices(3)
    if _current_choices.is_empty():
        return

    _resume_after_chest = not get_tree().paused
    get_tree().paused = true
    auto_battle_director.set_blocked(true)
    chest_backdrop.visible = true
    chest_panel.visible = true
    chest_title_label.visible = true
    for button: Button in chest_choice_buttons:
        button.visible = true
    _refresh_chest_choices()
    chest_choice_buttons[0].grab_focus()
    audio_manager.play_event(&"chest_open")
    _flash_screen(Color(1.0, 0.78, 0.22, 0.50))


func _select_blessing(index: int) -> void:
    if index < 0 or index >= _current_choices.size():
        return
    var selected: BlessingData = _current_choices[index]
    var stack_count: int = blessing_system.apply_blessing(selected)
    audio_manager.play_event(&"blessing")
    _show_feedback("%s · %s %d" % [selected.localized_name(i18n.locale_code), _run_t("STACK", "层数"), stack_count], selected.rarity_color())

    chest_backdrop.visible = false
    chest_panel.visible = false
    chest_title_label.visible = false
    for button: Button in chest_choice_buttons:
        button.visible = false
    _current_choices.clear()
    auto_battle_director.set_blocked(false)
    if _resume_after_chest and not game_manager.game_ended:
        get_tree().paused = false

    if combat_reward_system.pending_chests > 0:
        call_deferred("_on_chest_ready", combat_reward_system.pending_chests)
    elif auto_battle_director.auto_enabled and game_manager.state == GameManager.State.PREPARING and not auto_battle_director.waiting:
        auto_battle_director.arm()


func _on_blessing_applied(_data: BlessingData, _stack_count: int) -> void:
    _update_tower_panel()
    _refresh_reward_hud()


func _on_sunlight_jackpot(amount: int) -> void:
    economy_system.earn(amount, &"golden_rain")
    _show_feedback(_run_t("JACKPOT +%d SUN", "大奖 +%d 阳光") % amount, Color("ffd45e"))
    _flash_screen(Color(1.0, 0.78, 0.18, 0.58))


func _on_tower_critical_shot(damage_value: float) -> void:
    _show_feedback(_run_t("CRIT %.0f!", "暴击 %.0f！") % damage_value, Color("fff08a"))
    audio_manager.play_event(&"critical")


func _refresh_reward_hud() -> void:
    if combo_label == null or chest_meter_label == null or auto_button == null:
        return
    var tier: int = combat_reward_system.get_combo_tier()
    combo_label.text = _run_t("COMBO %d · T%d", "连击 %d · 阶%d") % [combat_reward_system.combo, tier]
    chest_meter_label.text = _run_t("GOLD CHEST\n%d/%d", "黄金宝箱\n%d/%d") % [combat_reward_system.chest_progress, combat_reward_system.chest_target]
    auto_button.text = _run_t("AUTO: ON", "自动：开") if auto_battle_director.auto_enabled else _run_t("AUTO: OFF", "自动：关")


func _refresh_chest_choices() -> void:
    if chest_title_label == null or not chest_title_label.visible:
        return
    chest_title_label.text = _run_t("GOLDEN CHEST · CHOOSE ONE", "黄金宝箱 · 三选一")
    for index: int in range(chest_choice_buttons.size()):
        var button: Button = chest_choice_buttons[index]
        if index >= _current_choices.size():
            button.visible = false
            continue
        var data: BlessingData = _current_choices[index]
        var next_stack: int = blessing_system.get_stack(data.id) + 1
        button.text = "%s · %s\n%s" % [data.rarity_name(i18n.locale_code), data.localized_name(i18n.locale_code), data.localized_description(i18n.locale_code, next_stack)]
        button.add_theme_color_override("font_color", data.rarity_color())


func _load_blessing_pool() -> Array[BlessingData]:
    var paths: Array[String] = [
        "res://data/blessings/verdant_force.tres",
        "res://data/blessings/rapid_growth.tres",
        "res://data/blessings/long_roots.tres",
        "res://data/blessings/sun_harvest.tres",
        "res://data/blessings/spore_bloom.tres",
        "res://data/blessings/frozen_time.tres",
        "res://data/blessings/lucky_seed.tres",
        "res://data/blessings/golden_rain.tres",
    ]
    var result: Array[BlessingData] = []
    for path: String in paths:
        var data: BlessingData = load(path) as BlessingData
        if data != null:
            result.append(data)
    return result


func _run_t(english: String, chinese: String) -> String:
    return chinese if i18n != null and i18n.locale_code == "zh_CN" else english