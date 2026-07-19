extends Node2D

const DEFAULT_LEVEL: LevelData = preload("res://data/levels/morning_forest.tres")

var level_data: LevelData
var game_manager: GameManager
var economy_system: EconomySystem
var base_health_system: BaseHealthSystem
var wave_manager: WaveManager
var enemy_registry: EnemyRegistry
var projectile_pool: ProjectilePool

var towers_by_slot: Dictionary = {}
var selected_tower: SproutTower = null

var coins_label: Label
var lives_label: Label
var wave_label: Label
var hint_label: Label
var tower_label: Label
var result_label: Label
var start_wave_button: Button
var pause_button: Button
var speed_button: Button
var upgrade_button: Button
var sell_button: Button
var restart_button: Button


func _ready() -> void:
    level_data = DEFAULT_LEVEL
    _create_systems()
    _create_ui()
    game_manager.reset()
    wave_manager.setup(level_data)
    economy_system.setup(level_data.starting_coins)
    base_health_system.setup(level_data.base_health)
    _refresh_hud()
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
    projectile_pool.initial_capacity = 32
    add_child(projectile_pool)

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
    draw_rect(Rect2(0.0, 0.0, 640.0, 360.0), Color("183c35"))

    for x_value: int in range(0, 640, 32):
        for y_value: int in range(48, 360, 32):
            var checker: bool = (int(x_value / 32) + int(y_value / 32)) % 2 == 0
            var tile_color: Color = Color("2f684b") if checker else Color("2a5f45")
            draw_rect(Rect2(float(x_value), float(y_value), 32.0, 32.0), tile_color)

    draw_polyline(level_data.path_points, Color("553d32"), 30.0, false)
    draw_polyline(level_data.path_points, Color("b58a5a"), 22.0, false)

    for index: int in range(level_data.build_slots.size()):
        if towers_by_slot.has(index):
            continue
        var position_value: Vector2 = level_data.build_slots[index]
        draw_circle(position_value, 17.0, Color("214c39"))
        draw_circle(position_value, 13.0, Color("79a95d"))
        draw_rect(Rect2(position_value - Vector2(4.0, 1.0), Vector2(8.0, 2.0)), Color("d4e6a1"))
        draw_rect(Rect2(position_value - Vector2(1.0, 4.0), Vector2(2.0, 8.0)), Color("d4e6a1"))

    draw_rect(Rect2(610.0, 88.0, 24.0, 40.0), Color("4b302a"))
    draw_rect(Rect2(614.0, 83.0, 16.0, 9.0), Color("d9df75"))


func _create_ui() -> void:
    var canvas: CanvasLayer = CanvasLayer.new()
    canvas.name = "UI"
    canvas.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(canvas)

    var top_bar: ColorRect = ColorRect.new()
    top_bar.color = Color("142b2d")
    top_bar.position = Vector2.ZERO
    top_bar.size = Vector2(640.0, 42.0)
    canvas.add_child(top_bar)

    coins_label = _make_label(canvas, Vector2(14.0, 8.0), Vector2(130.0, 26.0))
    lives_label = _make_label(canvas, Vector2(142.0, 8.0), Vector2(110.0, 26.0))
    wave_label = _make_label(canvas, Vector2(248.0, 8.0), Vector2(120.0, 26.0))

    start_wave_button = _make_button(canvas, "Start Wave", Vector2(388.0, 5.0), Vector2(105.0, 32.0))
    start_wave_button.pressed.connect(_start_next_wave)

    pause_button = _make_button(canvas, "Pause", Vector2(498.0, 5.0), Vector2(64.0, 32.0))
    pause_button.pressed.connect(_toggle_pause)

    speed_button = _make_button(canvas, "1x", Vector2(567.0, 5.0), Vector2(58.0, 32.0))
    speed_button.pressed.connect(_cycle_speed)

    hint_label = _make_label(canvas, Vector2(12.0, 326.0), Vector2(392.0, 26.0))
    var tower_data: TowerData = level_data.get_tower(0)
    var tower_cost: int = 0 if tower_data == null else tower_data.build_cost
    hint_label.text = "Click a green build slot to plant a Pea Tower (%d). F3: debug." % tower_cost

    var tower_panel: ColorRect = ColorRect.new()
    tower_panel.color = Color(0.07, 0.14, 0.14, 0.90)
    tower_panel.position = Vector2(410.0, 292.0)
    tower_panel.size = Vector2(218.0, 60.0)
    canvas.add_child(tower_panel)

    tower_label = _make_label(canvas, Vector2(418.0, 296.0), Vector2(200.0, 20.0))
    tower_label.text = "No tower selected"

    upgrade_button = _make_button(canvas, "Upgrade", Vector2(418.0, 319.0), Vector2(96.0, 28.0))
    upgrade_button.pressed.connect(_upgrade_selected)

    sell_button = _make_button(canvas, "Sell", Vector2(519.0, 319.0), Vector2(99.0, 28.0))
    sell_button.pressed.connect(_sell_selected)

    result_label = _make_label(canvas, Vector2(120.0, 126.0), Vector2(400.0, 70.0))
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    result_label.add_theme_font_size_override("font_size", 28)
    result_label.visible = false

    restart_button = _make_button(canvas, "Restart", Vector2(270.0, 202.0), Vector2(100.0, 36.0))
    restart_button.pressed.connect(_restart_game)
    restart_button.visible = false

    _update_tower_panel()


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
    parent.add_child(button)
    return button


func _build_tower(slot_index: int) -> void:
    var tower_data: TowerData = level_data.get_tower(0)
    if tower_data == null:
        hint_label.text = "No tower data is configured for this level."
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
    tower_label.text = "%s Lv.%d  DMG %.0f" % [selected_tower.get_display_name(), selected_tower.level, selected_tower.damage]
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
    _update_tower_panel()


func _sell_selected() -> void:
    if selected_tower == null or not is_instance_valid(selected_tower):
        return
    economy_system.earn(selected_tower.get_sell_value(), &"sell_tower")
    towers_by_slot.erase(selected_tower.slot_index)
    selected_tower.queue_free()
    selected_tower = null
    hint_label.text = "Tower sold. The build slot is available again."
    _update_tower_panel()
    queue_redraw()


func _start_next_wave() -> void:
    if game_manager.game_ended:
        return
    if wave_manager.start_next_wave():
        game_manager.mark_running()


func _spawn_enemy(enemy_data: EnemyData, path_index: int) -> void:
    var enemy: SproutEnemy = SproutEnemy.new()
    add_child(enemy)
    enemy.configure(level_data.get_path(path_index), enemy_data)
    enemy_registry.register_enemy(enemy)
    enemy.defeated.connect(_on_enemy_defeated)
    enemy.escaped.connect(_on_enemy_escaped)


func _on_enemy_defeated(enemy: SproutEnemy, reward: int) -> void:
    enemy_registry.unregister_enemy(enemy)
    economy_system.earn(reward, &"enemy_defeated")
    wave_manager.notify_enemy_removed()


func _on_enemy_escaped(enemy: SproutEnemy, damage: int) -> void:
    enemy_registry.unregister_enemy(enemy)
    base_health_system.damage(damage)
    wave_manager.notify_enemy_removed()


func _on_wave_started(index: int, _total: int) -> void:
    start_wave_button.disabled = true
    hint_label.text = "Wave %d incoming!" % (index + 1)
    _refresh_hud()


func _on_wave_completed(index: int, clear_reward: int) -> void:
    economy_system.earn(clear_reward, &"wave_clear")
    game_manager.mark_preparing()
    _refresh_hud()
    if index < wave_manager.get_total_waves() - 1:
        start_wave_button.disabled = false
        start_wave_button.text = "Next Wave"
        hint_label.text = "Wave cleared. Prepare your garden for the next attack."


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


func _toggle_pause() -> void:
    game_manager.toggle_pause()


func _cycle_speed() -> void:
    game_manager.cycle_speed()


func _restart_game() -> void:
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


func _refresh_hud() -> void:
    if coins_label == null or lives_label == null or wave_label == null:
        return
    coins_label.text = "Sunlight: %d" % economy_system.coins
    lives_label.text = "Sprout: %d" % base_health_system.health
    wave_label.text = "Wave: %d/%d" % [wave_manager.current_wave_index + 1, wave_manager.get_total_waves()]
    _update_tower_panel()
