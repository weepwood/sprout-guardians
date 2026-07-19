extends Node2D

const DEFAULT_LEVEL: LevelData = preload("res://data/levels/morning_forest.tres")

var level_data: LevelData
var game_manager: GameManager
var economy_system: EconomySystem
var base_health_system: BaseHealthSystem
var wave_manager: WaveManager
var enemy_registry: EnemyRegistry
var projectile_pool: ProjectilePool
var audio_manager: ProceduralAudioManager

var towers_by_slot: Dictionary = {}
var selected_tower: SproutTower = null
var selected_build_tower_index: int = 0
var tower_build_buttons: Array[Button] = []

var coins_label: Label
var lives_label: Label
var wave_label: Label
var hint_label: Label
var tower_label: Label
var result_label: Label
var next_wave_label: Label
var next_wave_hint_label: Label
var feedback_label: Label
var screen_flash: ColorRect
var onboarding_panel: Panel
var onboarding_label: Label
var onboarding_skip_button: Button
var start_wave_button: Button
var pause_button: Button
var speed_button: Button
var upgrade_button: Button
var sell_button: Button
var restart_button: Button

var onboarding_step: int = 0
var onboarding_active: bool = true


func _ready() -> void:
    level_data = DEFAULT_LEVEL
    _create_systems()
    _create_ui()
    game_manager.reset()
    wave_manager.setup(level_data)
    economy_system.setup(level_data.starting_coins)
    base_health_system.setup(level_data.base_health)
    _refresh_hud()
    _refresh_build_buttons()
    _refresh_wave_preview()
    _show_onboarding_step()
    queue_redraw()


func _create_systems() -> void:
    game_manager = GameManager.new()
    game_manager.name = "GameManager"
    add_child(game_manager)

    economy_system = EconomySystem.new()
    economy_system.name = "EconomySystem"
    add_child(economy_system)

    base_health_system = BaseHealthSystem.new()
    base_health_system.name = "BaseHealthSystem"
    add_child(base_health_system)

    wave_manager = WaveManager.new()
    wave_manager.name = "WaveManager"
    add_child(wave_manager)

    enemy_registry = EnemyRegistry.new()
    enemy_registry.name = "EnemyRegistry"
    add_child(enemy_registry)

    projectile_pool = ProjectilePool.new()
    projectile_pool.name = "ProjectilePool"
    projectile_pool.initial_capacity = 48
    add_child(projectile_pool)

    audio_manager = ProceduralAudioManager.new()
    audio_manager.name = "AudioManager"
    add_child(audio_manager)

    var debug_overlay: DebugPerformanceOverlay = DebugPerformanceOverlay.new()
    debug_overlay.name = "DebugPerformanceOverlay"
    debug_overlay.configure(enemy_registry, projectile_pool)
    add_child(debug_overlay)

    economy_system.coins_changed.connect(_on_coins_changed)
    economy_system.transaction_rejected.connect(_on_transaction_rejected)
    base_health_system.health_changed.connect(_on_health_changed)
    base_health_system.depleted.connect(_on_base_depleted)
    wave_manager.wave_started.connect(_on_wave_started)
    wave_manager.enemy_spawn_requested.connect(_spawn_enemy)
    wave_manager.wave_completed.connect(_on_wave_completed)
    wave_manager.campaign_completed.connect(_on_campaign_completed)
    game_manager.pause_changed.connect(_on_pause_changed)
    game_manager.speed_changed.connect(_on_speed_changed)
    game_manager.game_finished.connect(_on_game_finished)


func _unhandled_input(event: InputEvent) -> void:
    if game_manager.game_ended:
        return
    if not (event is InputEventMouseButton):
        return

    var mouse_event: InputEventMouseButton = event as InputEventMouseButton
    if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
        return
    if mouse_event.position.y < 45.0:
        return

    var world_point: Vector2 = get_global_mouse_position()
    var clicked_tower: SproutTower = _tower_at(world_point)
    if clicked_tower != null:
        _select_tower(clicked_tower)
        get_viewport().set_input_as_handled()
        return

    var slot_index: int = _slot_at(world_point)
    if slot_index >= 0:
        if towers_by_slot.has(slot_index):
            _select_tower(towers_by_slot[slot_index] as SproutTower)
        else:
            _build_tower(slot_index)
        get_viewport().set_input_as_handled()
        return

    _select_tower(null)


func _draw() -> void:
    draw_rect(Rect2(0.0, 0.0, 640.0, 360.0), Color("173932"))

    for x_value: int in range(0, 640, 32):
        for y_value: int in range(48, 360, 32):
            var checker: bool = (int(x_value / 32) + int(y_value / 32)) % 2 == 0
            var tile_color: Color = Color("326d4e") if checker else Color("2b6247")
            draw_rect(Rect2(float(x_value), float(y_value), 32.0, 32.0), tile_color)

    _draw_forest_decorations()
    draw_polyline(level_data.path_points, Color("553d32"), 30.0, false)
    draw_polyline(level_data.path_points, Color("b58a5a"), 22.0, false)
    draw_polyline(level_data.path_points, Color(0.82, 0.67, 0.43, 0.34), 2.0, false)

    for index: int in range(level_data.build_slots.size()):
        if towers_by_slot.has(index):
            continue
        var position_value: Vector2 = level_data.build_slots[index]
        draw_circle(position_value, 18.0, Color("173f32"))
        draw_circle(position_value, 14.0, Color("83b969"))
        draw_rect(Rect2(position_value - Vector2(5.0, 1.0), Vector2(10.0, 2.0)), Color("e1efad"))
        draw_rect(Rect2(position_value - Vector2(1.0, 5.0), Vector2(2.0, 10.0)), Color("e1efad"))

    draw_rect(Rect2(610.0, 88.0, 24.0, 40.0), Color("4b302a"))
    draw_rect(Rect2(614.0, 83.0, 16.0, 9.0), Color("e4e77a"))


func _draw_forest_decorations() -> void:
    var tree_positions: Array[Vector2] = [
        Vector2(28.0, 70.0), Vector2(55.0, 258.0), Vector2(194.0, 66.0),
        Vector2(318.0, 72.0), Vector2(385.0, 266.0), Vector2(598.0, 260.0),
    ]
    for tree_position: Vector2 in tree_positions:
        draw_rect(Rect2(tree_position + Vector2(-3.0, 7.0), Vector2(6.0, 11.0)), Color("5a3e2a"))
        draw_circle(tree_position, 12.0, Color("22563c"))
        draw_circle(tree_position + Vector2(-6.0, 2.0), 8.0, Color("397a4d"))
        draw_circle(tree_position + Vector2(6.0, 2.0), 8.0, Color("448a55"))

    for flower_position: Vector2 in [Vector2(115.0, 270.0), Vector2(242.0, 70.0), Vector2(445.0, 260.0), Vector2(535.0, 245.0)]:
        draw_rect(Rect2(flower_position, Vector2(2.0, 7.0)), Color("7bb564"))
        draw_circle(flower_position + Vector2(1.0, -1.0), 3.0, Color("f4d77d"))


func _create_ui() -> void:
    var canvas: CanvasLayer = CanvasLayer.new()
    canvas.name = "UI"
    canvas.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(canvas)

    _make_panel(canvas, Vector2.ZERO, Vector2(640.0, 42.0), Color("10272a"), Color("6f9b66"))

    coins_label = _make_label(canvas, Vector2(14.0, 8.0), Vector2(130.0, 26.0))
    lives_label = _make_label(canvas, Vector2(142.0, 8.0), Vector2(110.0, 26.0))
    wave_label = _make_label(canvas, Vector2(248.0, 8.0), Vector2(120.0, 26.0))

    start_wave_button = _make_button(canvas, "Start Wave", Vector2(388.0, 5.0), Vector2(105.0, 32.0))
    start_wave_button.pressed.connect(_start_next_wave)

    pause_button = _make_button(canvas, "Pause", Vector2(498.0, 5.0), Vector2(64.0, 32.0))
    pause_button.pressed.connect(_toggle_pause)

    speed_button = _make_button(canvas, "1x", Vector2(567.0, 5.0), Vector2(58.0, 32.0))
    speed_button.pressed.connect(_cycle_speed)

    _make_panel(canvas, Vector2(8.0, 289.0), Vector2(396.0, 63.0), Color(0.05, 0.12, 0.13, 0.96), Color("5f8a58"))
    _create_build_buttons(canvas)
    hint_label = _make_label(canvas, Vector2(14.0, 325.0), Vector2(384.0, 24.0))
    hint_label.add_theme_font_size_override("font_size", 12)

    _make_panel(canvas, Vector2(410.0, 292.0), Vector2(218.0, 60.0), Color(0.05, 0.12, 0.13, 0.96), Color("5f8a58"))
    tower_label = _make_label(canvas, Vector2(418.0, 296.0), Vector2(200.0, 20.0))
    tower_label.text = "No tower selected"
    tower_label.add_theme_font_size_override("font_size", 12)

    upgrade_button = _make_button(canvas, "Upgrade", Vector2(418.0, 319.0), Vector2(96.0, 28.0))
    upgrade_button.pressed.connect(_upgrade_selected)

    sell_button = _make_button(canvas, "Sell", Vector2(519.0, 319.0), Vector2(99.0, 28.0))
    sell_button.pressed.connect(_sell_selected)

    _make_panel(canvas, Vector2(410.0, 48.0), Vector2(218.0, 62.0), Color(0.05, 0.12, 0.13, 0.94), Color("846ca1"))
    next_wave_label = _make_label(canvas, Vector2(418.0, 53.0), Vector2(202.0, 22.0))
    next_wave_label.add_theme_color_override("font_color", Color("eadcff"))
    next_wave_hint_label = _make_label(canvas, Vector2(418.0, 74.0), Vector2(202.0, 32.0))
    next_wave_hint_label.add_theme_font_size_override("font_size", 11)
    next_wave_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    feedback_label = _make_label(canvas, Vector2(145.0, 124.0), Vector2(350.0, 42.0))
    feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    feedback_label.add_theme_font_size_override("font_size", 20)
    feedback_label.visible = false
    feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

    screen_flash = ColorRect.new()
    screen_flash.position = Vector2.ZERO
    screen_flash.size = Vector2(640.0, 360.0)
    screen_flash.color = Color.WHITE
    screen_flash.modulate.a = 0.0
    screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(screen_flash)

    _create_onboarding(canvas)

    result_label = _make_label(canvas, Vector2(120.0, 126.0), Vector2(400.0, 70.0))
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    result_label.add_theme_font_size_override("font_size", 28)
    result_label.visible = false

    restart_button = _make_button(canvas, "Restart", Vector2(270.0, 202.0), Vector2(100.0, 36.0))
    restart_button.pressed.connect(_restart_game)
    restart_button.visible = false

    _update_tower_panel()


func _create_onboarding(parent: Node) -> void:
    onboarding_panel = _make_panel(parent, Vector2(118.0, 50.0), Vector2(284.0, 58.0), Color(0.08, 0.12, 0.17, 0.97), Color("f0cf75"))
    onboarding_label = _make_label(parent, Vector2(128.0, 57.0), Vector2(210.0, 44.0))
    onboarding_label.add_theme_font_size_override("font_size", 12)
    onboarding_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    onboarding_skip_button = _make_button(parent, "Skip", Vector2(344.0, 65.0), Vector2(50.0, 28.0))
    onboarding_skip_button.pressed.connect(_skip_onboarding)


func _create_build_buttons(parent: Node) -> void:
    tower_build_buttons.clear()
    var count: int = mini(3, level_data.available_towers.size())
    for index: int in range(count):
        var button: Button = _make_button(parent, "Tower", Vector2(14.0 + float(index) * 128.0, 294.0), Vector2(122.0, 27.0))
        button.pressed.connect(_select_build_tower.bind(index))
        tower_build_buttons.append(button)


func _make_panel(parent: Node, position_value: Vector2, size_value: Vector2, fill: Color, border: Color) -> Panel:
    var panel: Panel = Panel.new()
    panel.position = position_value
    panel.size = size_value
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)
    return panel


func _make_label(parent: Node, position_value: Vector2, size_value: Vector2) -> Label:
    var label: Label = Label.new()
    label.position = position_value
    label.size = size_value
    label.add_theme_color_override("font_color", Color("f4f0d1"))
    label.add_theme_font_size_override("font_size", 15)
    parent.add_child(label)
    return label


func _make_button(parent: Node, text_value: String, position_value: Vector2, size_value: Vector2) -> Button:
    var button: Button = Button.new()
    button.text = text_value
    button.position = position_value
    button.size = size_value
    button.focus_mode = Control.FOCUS_NONE
    button.process_mode = Node.PROCESS_MODE_ALWAYS
    button.add_theme_font_size_override("font_size", 12)
    _apply_pixel_button_style(button)
    parent.add_child(button)
    return button


func _apply_pixel_button_style(button: Button) -> void:
    var states: Dictionary = {
        "normal": [Color("24483f"), Color("7ba269")],
        "hover": [Color("356553"), Color("d1e88d")],
        "pressed": [Color("182f2b"), Color("f0cf75")],
        "disabled": [Color("263330"), Color("54635c")],
    }
    for state: String in states:
        var values: Array = states[state]
        var style: StyleBoxFlat = StyleBoxFlat.new()
        style.bg_color = values[0] as Color
        style.border_color = values[1] as Color
        style.border_width_left = 2
        style.border_width_top = 2
        style.border_width_right = 2
        style.border_width_bottom = 2
        button.add_theme_stylebox_override(state, style)
    button.add_theme_color_override("font_color", Color("f4f0d1"))
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color("f0cf75"))


func _select_build_tower(index: int) -> void:
    if index < 0 or index >= level_data.available_towers.size():
        return
    selected_build_tower_index = index
    _select_tower(null)
    _refresh_build_buttons()
    audio_manager.play_event(&"ui_click")

    var tower_data: TowerData = level_data.get_tower(index)
    if tower_data != null:
        hint_label.text = "%s selected: %s" % [tower_data.display_name, tower_data.description]
    if onboarding_active and onboarding_step == 0:
        onboarding_step = 1
        _show_onboarding_step()


func _refresh_build_buttons() -> void:
    for index: int in range(tower_build_buttons.size()):
        var button: Button = tower_build_buttons[index]
        var tower_data: TowerData = level_data.get_tower(index)
        if tower_data == null:
            button.disabled = true
            button.text = "Unavailable"
            continue
        var short_name: String = tower_data.display_name
        short_name = short_name.replace(" Tower", "").replace(" Lamp", "").replace(" Flower", "")
        var prefix: String = "> " if index == selected_build_tower_index else ""
        button.text = "%s%s %d" % [prefix, short_name, tower_data.build_cost]

    var selected_data: TowerData = level_data.get_tower(selected_build_tower_index)
    if hint_label != null and selected_data != null and hint_label.text.is_empty():
        hint_label.text = "Choose a tower, then click a green build slot. F3: debug."


func _build_tower(slot_index: int) -> void:
    var tower_data: TowerData = level_data.get_tower(selected_build_tower_index)
    if tower_data == null:
        hint_label.text = "No tower data is configured for this build option."
        return
    if not economy_system.spend(tower_data.build_cost, &"build_tower"):
        return

    var tower: SproutTower = SproutTower.new()
    add_child(tower)
    tower.position = level_data.build_slots[slot_index]
    tower.configure(slot_index, tower_data, projectile_pool, enemy_registry)
    towers_by_slot[slot_index] = tower
    _select_tower(tower)
    hint_label.text = "%s planted. Select it to upgrade or sell." % tower_data.display_name
    audio_manager.play_event(&"build")
    _show_feedback("%s planted" % tower_data.display_name, tower_data.accent_color)
    if onboarding_active and onboarding_step <= 1:
        onboarding_step = 2
        _show_onboarding_step()
    queue_redraw()


func _tower_at(world_point: Vector2) -> SproutTower:
    for value: Variant in towers_by_slot.values():
        var tower: SproutTower = value as SproutTower
        if tower != null and is_instance_valid(tower) and tower.contains_world_point(world_point):
            return tower
    return null


func _slot_at(world_point: Vector2) -> int:
    for index: int in range(level_data.build_slots.size()):
        if level_data.build_slots[index].distance_to(world_point) <= 20.0:
            return index
    return -1


func _select_tower(tower: SproutTower) -> void:
    if selected_tower != null and is_instance_valid(selected_tower):
        selected_tower.set_selected(false)
    selected_tower = tower
    if selected_tower != null:
        selected_tower.set_selected(true)
    _update_tower_panel()


func _update_tower_panel() -> void:
    if upgrade_button == null or sell_button == null or tower_label == null:
        return
    var valid_selection: bool = selected_tower != null and is_instance_valid(selected_tower)
    upgrade_button.disabled = not valid_selection
    sell_button.disabled = not valid_selection

    if not valid_selection:
        tower_label.text = "No tower selected"
        upgrade_button.text = "Upgrade"
        sell_button.text = "Sell"
        return

    var upgrade_cost: int = selected_tower.get_upgrade_cost()
    var status_text: String = " DISABLED" if selected_tower.is_disabled() else ""
    tower_label.text = "%s Lv.%d DMG %.0f%s" % [selected_tower.get_display_name(), selected_tower.level, selected_tower.damage, status_text]
    upgrade_button.disabled = upgrade_cost < 0
    upgrade_button.text = "MAX" if upgrade_cost < 0 else "Upgrade %d" % upgrade_cost
    sell_button.text = "Sell %d" % selected_tower.get_sell_value()


func _upgrade_selected() -> void:
    if selected_tower == null or not is_instance_valid(selected_tower):
        return
    var cost: int = selected_tower.get_upgrade_cost()
    if cost < 0:
        return
    if not economy_system.spend(cost, &"upgrade_tower"):
        return
    selected_tower.apply_upgrade()
    hint_label.text = "Tower upgraded to level %d." % selected_tower.level
    audio_manager.play_event(&"upgrade")
    _show_feedback("LEVEL %d" % selected_tower.level, Color("f0cf75"))
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
    hint_label.text = "Tower sold. The build slot is available again."
    audio_manager.play_event(&"sell")
    _show_feedback("Tower sold", Color("d7c18b"))
    _update_tower_panel()
    queue_redraw()


func _start_next_wave() -> void:
    if game_manager.game_ended:
        return
    if wave_manager.start_next_wave():
        game_manager.mark_running()
        audio_manager.play_event(&"wave_start")
        if onboarding_active and onboarding_step == 2:
            onboarding_step = 3
            _show_onboarding_step()


func _spawn_enemy(enemy_data: EnemyData, path_index: int) -> void:
    var enemy: SproutEnemy = SproutEnemy.new()
    add_child(enemy)
    enemy.configure(level_data.get_enemy_path(path_index), enemy_data)
    enemy_registry.register_enemy(enemy)
    enemy.defeated.connect(_on_enemy_defeated)
    enemy.escaped.connect(_on_enemy_escaped)
    enemy.phase_changed.connect(_on_enemy_phase_changed)


func _on_enemy_defeated(enemy: SproutEnemy, reward: int) -> void:
    enemy_registry.unregister_enemy(enemy)
    economy_system.earn(reward, &"enemy_defeated")
    wave_manager.notify_enemy_removed()


func _on_enemy_escaped(enemy: SproutEnemy, damage: int) -> void:
    enemy_registry.unregister_enemy(enemy)
    base_health_system.damage(damage)
    wave_manager.notify_enemy_removed()
    audio_manager.play_event(&"base_hit")
    _flash_screen(Color(0.9, 0.22, 0.2, 0.42))
    _show_feedback("Sprout -%d" % damage, Color("ff8178"))


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
    _show_feedback("GOLEM PHASE %d · %d TOWERS DISRUPTED" % [phase_index + 1, disabled_count], Color("ffd06a"))
    hint_label.text = "Forest Golem phase %d: faster, tougher, and disrupting nearby towers." % (phase_index + 1)


func _on_wave_started(index: int, _total: int) -> void:
    start_wave_button.disabled = true
    var wave: WaveData = level_data.get_wave(index)
    hint_label.text = "Wave %d incoming!" % (index + 1)
    if wave != null and not wave.tactical_hint.is_empty():
        hint_label.text += " " + wave.tactical_hint
    _show_feedback("WAVE %d" % (index + 1), Color("d9ff8c"))
    _refresh_hud()
    _refresh_wave_preview()


func _on_wave_completed(index: int, clear_reward: int) -> void:
    economy_system.earn(clear_reward, &"wave_clear")
    game_manager.mark_preparing()
    audio_manager.play_event(&"wave_clear")
    _show_feedback("WAVE CLEAR +%d" % clear_reward, Color("f0cf75"))
    _refresh_hud()
    _refresh_wave_preview()
    if index < wave_manager.get_total_waves() - 1:
        start_wave_button.disabled = false
        start_wave_button.text = "Next Wave"
        hint_label.text = "Wave cleared. Review the next-wave preview and adjust your garden."


func _refresh_wave_preview() -> void:
    if next_wave_label == null or next_wave_hint_label == null or level_data == null:
        return
    var preview_index: int = wave_manager.current_wave_index + 1
    if preview_index >= level_data.get_wave_count():
        next_wave_label.text = "FINAL WAVE ACTIVE"
        next_wave_hint_label.text = "Defeat every remaining enemy."
        return
    var wave: WaveData = level_data.get_wave(preview_index)
    if wave == null:
        next_wave_label.text = "Next wave unavailable"
        next_wave_hint_label.text = ""
        return
    next_wave_label.text = "NEXT %d/%d · %s" % [preview_index + 1, level_data.get_wave_count(), wave.display_name]
    next_wave_hint_label.text = wave.get_preview_text()
    if not wave.tactical_hint.is_empty():
        next_wave_hint_label.tooltip_text = wave.tactical_hint


func _on_campaign_completed() -> void:
    _finish_game(true)


func _on_base_depleted() -> void:
    _finish_game(false)


func _finish_game(victory: bool) -> void:
    if game_manager.game_ended:
        return
    game_manager.finish(victory)


func _on_game_finished(victory: bool) -> void:
    start_wave_button.disabled = true
    pause_button.disabled = true
    speed_button.disabled = true
    result_label.text = "VICTORY\nThe sprout is safe!" if victory else "DEFEAT\nThe mist reached the sprout."
    result_label.visible = true
    restart_button.visible = true
    audio_manager.play_event(&"victory" if victory else &"defeat")
    _flash_screen(Color(0.55, 0.95, 0.55, 0.38) if victory else Color(0.8, 0.18, 0.22, 0.42))


func _toggle_pause() -> void:
    audio_manager.play_event(&"ui_click")
    game_manager.toggle_pause()


func _cycle_speed() -> void:
    audio_manager.play_event(&"ui_click")
    game_manager.cycle_speed()


func _restart_game() -> void:
    audio_manager.play_event(&"ui_click")
    game_manager.restart()


func _on_pause_changed(paused: bool) -> void:
    if pause_button != null:
        pause_button.text = "Resume" if paused else "Pause"


func _on_speed_changed(multiplier: float) -> void:
    if speed_button != null:
        speed_button.text = "%dx" % int(multiplier)


func _on_coins_changed(_value: int, _delta: int, _reason: StringName) -> void:
    _refresh_hud()


func _on_health_changed(_value: int, _delta: int) -> void:
    _refresh_hud()


func _on_transaction_rejected(_required: int, _available: int, reason: StringName) -> void:
    if reason == &"upgrade_tower":
        hint_label.text = "Not enough sunlight for this upgrade."
    else:
        hint_label.text = "Not enough sunlight. Defeat enemies to earn more."
    _show_feedback("NOT ENOUGH SUNLIGHT", Color("ff8178"))


func _show_feedback(text_value: String, color_value: Color) -> void:
    if feedback_label == null:
        return
    feedback_label.text = text_value
    feedback_label.add_theme_color_override("font_color", color_value)
    feedback_label.visible = true
    feedback_label.modulate = Color.WHITE
    feedback_label.scale = Vector2(0.86, 0.86)
    feedback_label.pivot_offset = feedback_label.size * 0.5
    var tween: Tween = create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(feedback_label, "scale", Vector2.ONE, 0.12)
    tween.tween_interval(0.55)
    tween.tween_property(feedback_label, "modulate:a", 0.0, 0.28)
    tween.tween_callback(_hide_feedback)


func _hide_feedback() -> void:
    if feedback_label != null:
        feedback_label.visible = false


func _flash_screen(color_value: Color) -> void:
    if screen_flash == null:
        return
    screen_flash.color = color_value
    screen_flash.modulate.a = color_value.a
    var tween: Tween = create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(screen_flash, "modulate:a", 0.0, 0.42)


func _show_onboarding_step() -> void:
    if not onboarding_active or onboarding_panel == null:
        return
    var messages: PackedStringArray = PackedStringArray([
        "1/4 Choose Pea, Mushroom, or Ice from the build bar.",
        "2/4 Click a glowing green build slot to plant the selected tower.",
        "3/4 Press Start Wave. Review the next-wave panel before each battle.",
        "4/4 Select a tower and upgrade it when you have enough sunlight.",
    ])
    onboarding_step = clampi(onboarding_step, 0, messages.size() - 1)
    onboarding_label.text = messages[onboarding_step]
    onboarding_panel.visible = true
    onboarding_label.visible = true
    onboarding_skip_button.visible = true


func _skip_onboarding() -> void:
    audio_manager.play_event(&"ui_click")
    _complete_onboarding()


func _complete_onboarding() -> void:
    onboarding_active = false
    onboarding_panel.visible = false
    onboarding_label.visible = false
    onboarding_skip_button.visible = false
    _show_feedback("TUTORIAL COMPLETE", Color("d9ff8c"))


func _refresh_hud() -> void:
    if coins_label == null or lives_label == null or wave_label == null:
        return
    coins_label.text = "Sunlight: %d" % economy_system.coins
    lives_label.text = "Sprout: %d" % base_health_system.health
    wave_label.text = "Wave: %d/%d" % [wave_manager.current_wave_index + 1, wave_manager.get_total_waves()]
    _update_tower_panel()
