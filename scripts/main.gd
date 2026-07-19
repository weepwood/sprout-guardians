extends Node2D

const TOWER_COST: int = 75
const STARTING_COINS: int = 220
const STARTING_LIVES: int = 10

var path_points: PackedVector2Array = PackedVector2Array([
    Vector2(-16.0, 92.0),
    Vector2(152.0, 92.0),
    Vector2(152.0, 224.0),
    Vector2(348.0, 224.0),
    Vector2(348.0, 108.0),
    Vector2(656.0, 108.0),
])

var slot_positions: Array[Vector2] = [
    Vector2(84.0, 154.0),
    Vector2(214.0, 148.0),
    Vector2(272.0, 278.0),
    Vector2(414.0, 174.0),
    Vector2(486.0, 62.0),
    Vector2(558.0, 166.0),
]

var waves: Array[Dictionary] = [
    {"count": 6, "health": 42.0, "speed": 42.0, "reward": 12, "interval": 0.85, "color": Color("86c85a")},
    {"count": 9, "health": 58.0, "speed": 49.0, "reward": 13, "interval": 0.68, "color": Color("d3a34f")},
    {"count": 12, "health": 82.0, "speed": 46.0, "reward": 15, "interval": 0.58, "color": Color("9e73c8")},
    {"count": 1, "health": 620.0, "speed": 31.0, "reward": 160, "interval": 1.0, "color": Color("c76464")},
]

var coins: int = STARTING_COINS
var lives: int = STARTING_LIVES
var current_wave: int = -1
var active_enemies: int = 0
var spawn_remaining: int = 0
var spawn_cooldown: float = 0.0
var wave_active: bool = false
var game_ended: bool = false
var speed_index: int = 0
var speed_values: Array[float] = [1.0, 2.0, 3.0]

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
    Engine.time_scale = 1.0
    _create_ui()
    _refresh_hud()
    queue_redraw()


func _process(delta: float) -> void:
    if not wave_active or game_ended:
        return

    if spawn_remaining > 0:
        spawn_cooldown -= delta
        if spawn_cooldown <= 0.0:
            _spawn_enemy()
            spawn_remaining -= 1
            var wave: Dictionary = waves[current_wave]
            spawn_cooldown = float(wave["interval"])

    _check_wave_complete()


func _unhandled_input(event: InputEvent) -> void:
    if game_ended:
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

    draw_polyline(path_points, Color("553d32"), 30.0, false)
    draw_polyline(path_points, Color("b58a5a"), 22.0, false)

    for index: int in range(slot_positions.size()):
        if towers_by_slot.has(index):
            continue
        var position_value: Vector2 = slot_positions[index]
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
    hint_label.text = "Click a green build slot to plant a Pea Tower (75)."

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
    if coins < TOWER_COST:
        hint_label.text = "Not enough sunlight. Defeat enemies to earn more."
        return

    coins -= TOWER_COST
    var tower: SproutTower = SproutTower.new()
    add_child(tower)
    tower.position = slot_positions[slot_index]
    tower.configure(slot_index)
    towers_by_slot[slot_index] = tower
    _select_tower(tower)
    hint_label.text = "Pea Tower planted. Select it to upgrade or sell."
    _refresh_hud()
    queue_redraw()


func _tower_at(world_point: Vector2) -> SproutTower:
    for value: Variant in towers_by_slot.values():
        var tower: SproutTower = value as SproutTower
        if tower != null and is_instance_valid(tower) and tower.contains_world_point(world_point):
            return tower
    return null


func _slot_at(world_point: Vector2) -> int:
    for index: int in range(slot_positions.size()):
        if slot_positions[index].distance_to(world_point) <= 20.0:
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
    var valid_selection: bool = selected_tower != null and is_instance_valid(selected_tower)
    upgrade_button.disabled = not valid_selection
    sell_button.disabled = not valid_selection

    if not valid_selection:
        tower_label.text = "No tower selected"
        upgrade_button.text = "Upgrade"
        sell_button.text = "Sell"
        return

    var upgrade_cost: int = selected_tower.get_upgrade_cost()
    tower_label.text = "Pea Tower Lv.%d  DMG %.0f" % [selected_tower.level, selected_tower.damage]
    upgrade_button.disabled = upgrade_cost < 0
    upgrade_button.text = "MAX" if upgrade_cost < 0 else "Upgrade %d" % upgrade_cost
    sell_button.text = "Sell %d" % selected_tower.get_sell_value()


func _upgrade_selected() -> void:
    if selected_tower == null or not is_instance_valid(selected_tower):
        return
    var cost: int = selected_tower.get_upgrade_cost()
    if cost < 0:
        return
    if coins < cost:
        hint_label.text = "Not enough sunlight for this upgrade."
        return
    coins -= cost
    selected_tower.apply_upgrade()
    hint_label.text = "Tower upgraded to level %d." % selected_tower.level
    _refresh_hud()
    _update_tower_panel()


func _sell_selected() -> void:
    if selected_tower == null or not is_instance_valid(selected_tower):
        return
    coins += selected_tower.get_sell_value()
    towers_by_slot.erase(selected_tower.slot_index)
    selected_tower.queue_free()
    selected_tower = null
    hint_label.text = "Tower sold. The build slot is available again."
    _refresh_hud()
    _update_tower_panel()
    queue_redraw()


func _start_next_wave() -> void:
    if game_ended or wave_active:
        return
    if current_wave + 1 >= waves.size():
        return

    current_wave += 1
    var wave: Dictionary = waves[current_wave]
    spawn_remaining = int(wave["count"])
    spawn_cooldown = 0.1
    wave_active = true
    start_wave_button.disabled = true
    hint_label.text = "Wave %d incoming!" % (current_wave + 1)
    _refresh_hud()


func _spawn_enemy() -> void:
    var wave: Dictionary = waves[current_wave]
    var enemy: SproutEnemy = SproutEnemy.new()
    add_child(enemy)
    var enemy_color: Color = wave["color"]
    enemy.configure(
        path_points,
        float(wave["health"]),
        float(wave["speed"]),
        int(wave["reward"]),
        enemy_color
    )
    enemy.defeated.connect(_on_enemy_defeated)
    enemy.escaped.connect(_on_enemy_escaped)
    active_enemies += 1


func _on_enemy_defeated(reward: int) -> void:
    coins += reward
    active_enemies = maxi(0, active_enemies - 1)
    _refresh_hud()
    _check_wave_complete()


func _on_enemy_escaped(damage: int) -> void:
    lives = maxi(0, lives - damage)
    active_enemies = maxi(0, active_enemies - 1)
    _refresh_hud()
    if lives <= 0:
        _finish_game(false)
        return
    _check_wave_complete()


func _check_wave_complete() -> void:
    if not wave_active or spawn_remaining > 0 or active_enemies > 0:
        return

    wave_active = false
    coins += 35 + current_wave * 10
    _refresh_hud()

    if current_wave >= waves.size() - 1:
        _finish_game(true)
        return

    start_wave_button.disabled = false
    start_wave_button.text = "Next Wave"
    hint_label.text = "Wave cleared. Prepare your garden for the next attack."


func _finish_game(victory: bool) -> void:
    if game_ended:
        return
    game_ended = true
    wave_active = false
    start_wave_button.disabled = true
    pause_button.disabled = true
    speed_button.disabled = true
    result_label.text = "VICTORY\nThe sprout is safe!" if victory else "DEFEAT\nThe mist reached the sprout."
    result_label.visible = true
    restart_button.visible = true
    get_tree().paused = true


func _toggle_pause() -> void:
    if game_ended:
        return
    get_tree().paused = not get_tree().paused
    pause_button.text = "Resume" if get_tree().paused else "Pause"


func _cycle_speed() -> void:
    if game_ended:
        return
    speed_index = (speed_index + 1) % speed_values.size()
    Engine.time_scale = speed_values[speed_index]
    speed_button.text = "%dx" % int(speed_values[speed_index])


func _restart_game() -> void:
    Engine.time_scale = 1.0
    get_tree().paused = false
    get_tree().reload_current_scene()


func _refresh_hud() -> void:
    coins_label.text = "Sunlight: %d" % coins
    lives_label.text = "Sprout: %d" % lives
    wave_label.text = "Wave: %d/%d" % [current_wave + 1, waves.size()]
    _update_tower_panel()
