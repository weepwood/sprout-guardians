extends "res://scripts/main.gd"

var i18n: LocalizationService
var language_button: Button


func _ready() -> void:
    i18n = LocalizationService.new()
    i18n.load_preference()
    super._ready()
    _create_language_button()
    _apply_locale()


func _create_language_button() -> void:
    var canvas: Node = get_node_or_null("UI")
    if canvas == null:
        return
    language_button = _make_button(canvas, "", Vector2(570.0, 114.0), Vector2(58.0, 27.0))
    language_button.pressed.connect(_toggle_language)


func _toggle_language() -> void:
    audio_manager.play_event(&"ui_click")
    i18n.toggle_locale()
    _apply_locale()
    _show_feedback(i18n.text("language.%s" % i18n.locale_code), Color("d9ff8c"))


func _apply_locale() -> void:
    if i18n == null:
        return
    if start_wave_button != null:
        start_wave_button.text = i18n.text("ui.start_wave") if wave_manager.current_wave_index < 0 else i18n.text("ui.next_wave")
    if pause_button != null:
        pause_button.text = i18n.text("ui.resume") if get_tree().paused else i18n.text("ui.pause")
    if restart_button != null:
        restart_button.text = i18n.text("ui.restart")
    if onboarding_skip_button != null:
        onboarding_skip_button.text = i18n.text("ui.skip")
    if language_button != null:
        language_button.text = i18n.text("ui.language_target_zh") if i18n.locale_code == "en" else i18n.text("ui.language_target_en")
        language_button.tooltip_text = i18n.text("ui.language_tooltip")
    _refresh_hud()
    _refresh_build_buttons()
    _refresh_wave_preview()
    _show_onboarding_step()
    if result_label != null and result_label.visible:
        result_label.text = i18n.text("result.victory") if game_manager.state == GameManager.State.VICTORY else i18n.text("result.defeat")


func _select_build_tower(index: int) -> void:
    super._select_build_tower(index)
    var tower_data: TowerData = level_data.get_tower(index)
    if tower_data != null:
        hint_label.text = i18n.text("hint.tower_selected", [i18n.tower_name(tower_data), i18n.tower_description(tower_data)])


func _refresh_build_buttons() -> void:
    if i18n == null:
        return
    for index: int in range(tower_build_buttons.size()):
        var button: Button = tower_build_buttons[index]
        var tower_data: TowerData = level_data.get_tower(index)
        if tower_data == null:
            button.disabled = true
            button.text = i18n.text("ui.unavailable")
            continue
        var prefix: String = "> " if index == selected_build_tower_index else ""
        button.text = "%s%s %d" % [prefix, i18n.tower_short_name(tower_data), tower_data.build_cost]

    var selected_data: TowerData = level_data.get_tower(selected_build_tower_index)
    if hint_label != null and selected_data != null and hint_label.text.is_empty():
        hint_label.text = i18n.text("hint.choose_tower")


func _build_tower(slot_index: int) -> void:
    var tower_data: TowerData = level_data.get_tower(selected_build_tower_index)
    if tower_data == null:
        hint_label.text = i18n.text("hint.no_tower_data")
        return
    if not economy_system.spend(tower_data.build_cost, &"build_tower"):
        return

    var tower: SproutTower = SproutTower.new()
    add_child(tower)
    tower.position = level_data.build_slots[slot_index]
    tower.configure(slot_index, tower_data, projectile_pool, enemy_registry)
    towers_by_slot[slot_index] = tower
    _select_tower(tower)
    hint_label.text = i18n.text("hint.tower_planted", [i18n.tower_name(tower_data)])
    audio_manager.play_event(&"build")
    _show_feedback(i18n.text("feedback.planted", [i18n.tower_name(tower_data)]), tower_data.accent_color)
    if onboarding_active and onboarding_step <= 1:
        onboarding_step = 2
        _show_onboarding_step()
    queue_redraw()


func _update_tower_panel() -> void:
    if i18n == null or upgrade_button == null or sell_button == null or tower_label == null:
        return
    var valid_selection: bool = selected_tower != null and is_instance_valid(selected_tower)
    upgrade_button.disabled = not valid_selection
    sell_button.disabled = not valid_selection

    if not valid_selection:
        tower_label.text = i18n.text("ui.no_tower_selected")
        upgrade_button.text = i18n.text("ui.upgrade")
        sell_button.text = i18n.text("ui.sell")
        return

    var upgrade_cost: int = selected_tower.get_upgrade_cost()
    var status_text: String = i18n.text("ui.disabled") if selected_tower.is_disabled() else ""
    tower_label.text = "%s Lv.%d DMG %.0f%s" % [i18n.tower_name(selected_tower.data), selected_tower.level, selected_tower.damage, status_text]
    upgrade_button.disabled = upgrade_cost < 0
    upgrade_button.text = i18n.text("ui.max") if upgrade_cost < 0 else i18n.text("ui.upgrade_cost", [upgrade_cost])
    sell_button.text = i18n.text("ui.sell_value", [selected_tower.get_sell_value()])


func _upgrade_selected() -> void:
    if selected_tower == null or not is_instance_valid(selected_tower):
        return
    var cost: int = selected_tower.get_upgrade_cost()
    if cost < 0:
        return
    if not economy_system.spend(cost, &"upgrade_tower"):
        return
    selected_tower.apply_upgrade()
    hint_label.text = i18n.text("hint.tower_upgraded", [selected_tower.level])
    audio_manager.play_event(&"upgrade")
    _show_feedback(i18n.text("feedback.level", [selected_tower.level]), Color("f0cf75"))
    if onboarding_active and onboarding_step == 3:
        _complete_onboarding()
    _update_tower_panel()


func _sell_selected() -> void:
    if selected_tower == null or not is_instance_valid(selected_tower):
        return
    economy_system.earn(selected_tower.get_sell_value(), &"sell_tower")
    towers_by_slot.erase(selected_tower.slot_index)
    selected_tower.queue_free()
    selected_tower = null
    hint_label.text = i18n.text("hint.tower_sold")
    audio_manager.play_event(&"sell")
    _show_feedback(i18n.text("feedback.sold"), Color("d7c18b"))
    _update_tower_panel()
    queue_redraw()


func _on_enemy_escaped(enemy: SproutEnemy, damage: int) -> void:
    enemy_registry.unregister_enemy(enemy)
    base_health_system.damage(damage)
    wave_manager.notify_enemy_removed()
    audio_manager.play_event(&"base_hit")
    _flash_screen(Color(0.9, 0.22, 0.2, 0.42))
    _show_feedback(i18n.text("feedback.sprout_damage", [damage]), Color("ff8178"))


func _on_enemy_phase_changed(enemy: SproutEnemy, phase_index: int) -> void:
    if enemy == null or enemy.data == null:
        return
    var disabled_count: int = 0
    for value: Variant in towers_by_slot.values():
        var tower: SproutTower = value as SproutTower
        if tower == null or not is_instance_valid(tower):
            continue
        if tower.global_position.distance_to(enemy.global_position) <= enemy.data.phase_pulse_radius:
            tower.disable_for(enemy.data.phase_tower_disable_duration)
            disabled_count += 1
    audio_manager.play_event(&"boss_phase")
    _flash_screen(Color(0.95, 0.52, 0.22, 0.50))
    _show_feedback(i18n.text("feedback.golem_phase", [phase_index + 1, disabled_count]), Color("ffd06a"))
    hint_label.text = i18n.text("hint.golem_phase", [phase_index + 1])


func _on_wave_started(index: int, _total: int) -> void:
    start_wave_button.disabled = true
    var wave: WaveData = level_data.get_wave(index)
    hint_label.text = i18n.text("hint.wave_incoming", [index + 1])
    var tactical_hint: String = i18n.wave_hint(wave)
    if not tactical_hint.is_empty():
        hint_label.text += " " + tactical_hint
    _show_feedback(i18n.text("feedback.wave", [index + 1]), Color("d9ff8c"))
    _refresh_hud()
    _refresh_wave_preview()


func _on_wave_completed(index: int, clear_reward: int) -> void:
    economy_system.earn(clear_reward, &"wave_clear")
    game_manager.mark_preparing()
    audio_manager.play_event(&"wave_clear")
    _show_feedback(i18n.text("feedback.wave_clear", [clear_reward]), Color("f0cf75"))
    _refresh_hud()
    _refresh_wave_preview()
    if index < wave_manager.get_total_waves() - 1:
        start_wave_button.disabled = false
        start_wave_button.text = i18n.text("ui.next_wave")
        hint_label.text = i18n.text("hint.wave_cleared")


func _refresh_wave_preview() -> void:
    if i18n == null or next_wave_label == null or next_wave_hint_label == null or level_data == null:
        return
    var preview_index: int = wave_manager.current_wave_index + 1
    if preview_index >= level_data.get_wave_count():
        next_wave_label.text = i18n.text("preview.final_active")
        next_wave_hint_label.text = i18n.text("preview.defeat_remaining")
        return
    var wave: WaveData = level_data.get_wave(preview_index)
    if wave == null:
        next_wave_label.text = i18n.text("preview.unavailable")
        next_wave_hint_label.text = ""
        return
    next_wave_label.text = i18n.text("preview.title", [preview_index + 1, level_data.get_wave_count(), i18n.wave_name(wave)])
    next_wave_hint_label.text = i18n.wave_preview(wave)
    next_wave_hint_label.tooltip_text = i18n.wave_hint(wave)


func _on_game_finished(victory: bool) -> void:
    start_wave_button.disabled = true
    pause_button.disabled = true
    speed_button.disabled = true
    result_label.text = i18n.text("result.victory") if victory else i18n.text("result.defeat")
    result_label.visible = true
    restart_button.text = i18n.text("ui.restart")
    restart_button.visible = true
    audio_manager.play_event(&"victory" if victory else &"defeat")
    _flash_screen(Color(0.55, 0.95, 0.55, 0.38) if victory else Color(0.8, 0.18, 0.22, 0.42))


func _on_pause_changed(paused: bool) -> void:
    if pause_button != null and i18n != null:
        pause_button.text = i18n.text("ui.resume") if paused else i18n.text("ui.pause")


func _on_transaction_rejected(_required: int, _available: int, reason: StringName) -> void:
    if reason == &"upgrade_tower":
        hint_label.text = i18n.text("hint.not_enough_upgrade")
    else:
        hint_label.text = i18n.text("hint.not_enough")
    _show_feedback(i18n.text("feedback.not_enough"), Color("ff8178"))


func _show_onboarding_step() -> void:
    if i18n == null or not onboarding_active or onboarding_panel == null:
        return
    var keys: PackedStringArray = PackedStringArray(["tutorial.1", "tutorial.2", "tutorial.3", "tutorial.4"])
    onboarding_step = clampi(onboarding_step, 0, keys.size() - 1)
    onboarding_label.text = i18n.text(keys[onboarding_step])
    onboarding_panel.visible = true
    onboarding_label.visible = true
    onboarding_skip_button.text = i18n.text("ui.skip")
    onboarding_skip_button.visible = true


func _complete_onboarding() -> void:
    onboarding_active = false
    onboarding_panel.visible = false
    onboarding_label.visible = false
    onboarding_skip_button.visible = false
    _show_feedback(i18n.text("feedback.tutorial_complete"), Color("d9ff8c"))


func _refresh_hud() -> void:
    if i18n == null or coins_label == null or lives_label == null or wave_label == null:
        return
    coins_label.text = i18n.text("ui.sunlight", [economy_system.coins])
    lives_label.text = i18n.text("ui.sprout", [base_health_system.health])
    wave_label.text = i18n.text("ui.wave", [wave_manager.current_wave_index + 1, wave_manager.get_total_waves()])
    _update_tower_panel()
