extends Node2D

const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const ARENA_RECT: Rect2 = Rect2(34.0, 50.0, 572.0, 278.0)
const WAVE_START_DELAY: float = 1.6

var settings: SettingsService
var i18n: LocalizationService
var audio_manager: ProceduralAudioManager
var blessing_system: BlessingSystem
var impact_system: PixelImpactSystem
var core: GreedCore
var plants: Array[GreedPlant] = []

var wave_index: int = -1
var wave_active: bool = false
var spawn_remaining: int = 0
var spawn_timer: float = 0.0
var next_wave_timer: float = WAVE_START_DELAY
var wave_elapsed: float = 0.0
var seconds_since_last_kill: float = 0.0
var coins: int = 0
var greed_score: int = 0
var enemies_defeated: int = 0
var choice_open: bool = false
var game_ended: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _current_choices: Array[BlessingData] = []

var wave_label: Label
var health_label: Label
var coins_label: Label
var greed_label: Label
var status_label: Label
var power_label: Label
var language_button: Button
var speed_button: Button
var menu_button: Button

var choice_backdrop: ColorRect
var choice_panel: Panel
var choice_title: Label
var choice_buttons: Array[Button] = []
var result_label: Label
var result_button: Button


func _ready() -> void:
    _rng.seed = 0x6A2D2026
    _create_services()
    _create_arena()
    _create_ui()
    _apply_locale()
    queue_redraw()


func _process(delta: float) -> void:
    if game_ended or choice_open:
        return

    if not wave_active:
        next_wave_timer = maxf(0.0, next_wave_timer - delta)
        status_label.text = _t("NEXT GREED WAVE %.1fs", "下一轮贪婪波次 %.1f秒") % next_wave_timer
        if next_wave_timer <= 0.0:
            _start_next_wave()
        return

    wave_elapsed += delta
    seconds_since_last_kill += delta
    var fury: float = GreedBalance.fury_multiplier(wave_elapsed)
    var rescue: bool = GreedBalance.rescue_active(seconds_since_last_kill)
    for plant: GreedPlant in plants:
        if plant == null or not is_instance_valid(plant):
            continue
        plant.fury_multiplier = fury
        plant.rescue_active = rescue

    if spawn_remaining > 0:
        spawn_timer -= delta
        if spawn_timer <= 0.0:
            _spawn_enemy()
            spawn_remaining -= 1
            var config: Dictionary = GreedBalance.WAVE_TABLE[wave_index]
            spawn_timer = float(config.get("spawn_interval", 0.7))

    var active_enemies: int = get_tree().get_nodes_in_group("greed_enemies").size()
    if spawn_remaining <= 0 and active_enemies <= 0:
        _complete_wave()
        return

    var fury_percent: int = int(round((fury - 1.0) * 100.0))
    if rescue:
        status_label.text = _t("RESCUE OVERDRIVE · RANGE +60%% · RATE +47%%", "救援超载 · 射程 +60%% · 攻速 +47%%")
    elif fury_percent > 0:
        status_label.text = _t("GARDEN FURY +%d%%", "花园狂怒 +%d%%") % fury_percent
    else:
        status_label.text = _t("AUTONOMOUS COMBAT · CHOOSE REWARDS ONLY", "全自动战斗 · 玩家只需选择奖励")
    _refresh_hud()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("11151d"))
    draw_rect(ARENA_RECT, Color("273129"))
    for x_value: int in range(int(ARENA_RECT.position.x), int(ARENA_RECT.end.x), 24):
        for y_value: int in range(int(ARENA_RECT.position.y), int(ARENA_RECT.end.y), 24):
            var grid_x: int = int(x_value / 24)
            var grid_y: int = int(y_value / 24)
            var alternating: bool = (grid_x + grid_y) % 2 == 0
            draw_rect(Rect2(float(x_value), float(y_value), 24.0, 24.0), Color("2d382e") if alternating else Color("293329"))
    draw_rect(ARENA_RECT, Color("8f7351"), false, 5.0)

    var center: Vector2 = ARENA_RECT.get_center()
    draw_circle(center, 28.0, Color("3d312c"))
    draw_circle(center, 20.0, Color("b98b3c"))
    draw_circle(center, 12.0, Color("f0c85a"))
    draw_line(center + Vector2(-7.0, 0.0), center + Vector2(7.0, 0.0), Color("503b24"), 3.0)
    draw_line(center + Vector2(0.0, -7.0), center + Vector2(0.0, 7.0), Color("503b24"), 3.0)

    _draw_door(Vector2(center.x, ARENA_RECT.position.y), Vector2(56.0, 18.0))
    _draw_door(Vector2(center.x, ARENA_RECT.end.y), Vector2(56.0, 18.0))
    _draw_door(Vector2(ARENA_RECT.position.x, center.y), Vector2(18.0, 56.0))
    _draw_door(Vector2(ARENA_RECT.end.x, center.y), Vector2(18.0, 56.0))


func _draw_door(center: Vector2, size_value: Vector2) -> void:
    draw_rect(Rect2(center - size_value * 0.5, size_value), Color("17131b"))
    draw_rect(Rect2(center - size_value * 0.5, size_value), Color("b05850"), false, 3.0)


func _create_services() -> void:
    settings = SettingsService.new()
    settings.load_settings()
    i18n = LocalizationService.new()
    i18n.set_locale(settings.locale, false)

    audio_manager = ProceduralAudioManager.new()
    audio_manager.name = "GreedAudio"
    add_child(audio_manager)
    settings.apply_runtime(audio_manager)

    blessing_system = BlessingSystem.new()
    blessing_system.name = "BlessingSystem"
    add_child(blessing_system)
    blessing_system.setup(_load_blessing_pool(), 0x6A2D2026)
    blessing_system.sunlight_jackpot.connect(_on_coin_jackpot)

    impact_system = PixelImpactSystem.new()
    impact_system.name = "PixelImpactSystem"
    impact_system.max_particles = 256
    add_child(impact_system)


func _create_arena() -> void:
    core = GreedCore.new()
    core.name = "GardenCore"
    core.global_position = ARENA_RECT.get_center()
    add_child(core)
    core.health_changed.connect(_on_core_health_changed)
    core.defeated.connect(_on_core_defeated)

    for index: int in range(GreedBalance.STARTER_PLANTS.size()):
        var plant: GreedPlant = GreedPlant.new()
        plant.name = "StarterPlant%d" % index
        plant.global_position = core.global_position + Vector2.from_angle(TAU * float(index) / 3.0) * 44.0
        add_child(plant)
        plant.configure(core, GreedBalance.STARTER_PLANTS[index], index, blessing_system)
        plant.fired.connect(_on_plant_fired)
        plants.append(plant)


func _create_ui() -> void:
    var canvas: CanvasLayer = CanvasLayer.new()
    canvas.name = "UI"
    add_child(canvas)

    wave_label = _make_label(canvas, Vector2(12.0, 8.0), Vector2(150.0, 24.0), 14)
    health_label = _make_label(canvas, Vector2(166.0, 8.0), Vector2(110.0, 24.0), 14)
    coins_label = _make_label(canvas, Vector2(280.0, 8.0), Vector2(100.0, 24.0), 14)
    greed_label = _make_label(canvas, Vector2(384.0, 8.0), Vector2(100.0, 24.0), 14)

    language_button = _make_button(canvas, Vector2(492.0, 6.0), Vector2(48.0, 26.0))
    language_button.pressed.connect(_toggle_language)
    speed_button = _make_button(canvas, Vector2(544.0, 6.0), Vector2(40.0, 26.0))
    speed_button.text = "1×"
    speed_button.pressed.connect(_cycle_speed)
    menu_button = _make_button(canvas, Vector2(588.0, 6.0), Vector2(42.0, 26.0))
    menu_button.pressed.connect(_return_to_menu)

    status_label = _make_label(canvas, Vector2(92.0, 332.0), Vector2(456.0, 20.0), 12)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    power_label = _make_label(canvas, Vector2(8.0, 48.0), Vector2(170.0, 90.0), 11)
    power_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    choice_backdrop = ColorRect.new()
    choice_backdrop.position = Vector2.ZERO
    choice_backdrop.size = VIEW_SIZE
    choice_backdrop.color = Color(0.02, 0.025, 0.04, 0.94)
    choice_backdrop.visible = false
    canvas.add_child(choice_backdrop)

    choice_panel = _make_panel(canvas, Vector2(74.0, 48.0), Vector2(492.0, 264.0))
    choice_panel.visible = false
    choice_title = _make_label(canvas, Vector2(94.0, 62.0), Vector2(452.0, 38.0), 21)
    choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    choice_title.visible = false

    for index: int in range(3):
        var button: Button = _make_button(canvas, Vector2(102.0, 112.0 + float(index) * 58.0), Vector2(436.0, 48.0))
        button.visible = false
        button.add_theme_font_size_override("font_size", 12)
        button.pressed.connect(_select_choice.bind(index))
        choice_buttons.append(button)

    result_label = _make_label(canvas, Vector2(120.0, 126.0), Vector2(400.0, 76.0), 28)
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    result_label.visible = false
    result_button = _make_button(canvas, Vector2(240.0, 220.0), Vector2(160.0, 36.0))
    result_button.visible = false
    result_button.pressed.connect(_restart_run)

    _refresh_hud()


func _start_next_wave() -> void:
    if game_ended or choice_open or wave_active:
        return
    wave_index += 1
    if wave_index >= GreedBalance.WAVE_TABLE.size():
        _finish_run(true)
        return
    var config: Dictionary = GreedBalance.WAVE_TABLE[wave_index]
    spawn_remaining = int(config.get("count", 1))
    spawn_timer = 0.15
    wave_elapsed = 0.0
    seconds_since_last_kill = 0.0
    wave_active = true
    audio_manager.play_event(&"wave_start")
    impact_system.spawn_reward(ARENA_RECT.get_center(), Color("f0c85a"))
    _refresh_hud()


func _spawn_enemy() -> void:
    var config: Dictionary = GreedBalance.WAVE_TABLE[wave_index]
    var enemy: GreedEnemy = GreedEnemy.new()
    enemy.name = "GreedEnemy"
    enemy.global_position = _door_spawn_position()
    add_child(enemy)
    enemy.configure(core, config, 1.0)
    enemy.damaged.connect(_on_enemy_damaged)
    enemy.defeated.connect(_on_enemy_defeated)
    enemy.core_contact.connect(_on_enemy_core_contact)


func _door_spawn_position() -> Vector2:
    var center: Vector2 = ARENA_RECT.get_center()
    var door: int = _rng.randi_range(0, 3)
    match door:
        0:
            return Vector2(center.x + _rng.randf_range(-58.0, 58.0), ARENA_RECT.position.y + 12.0)
        1:
            return Vector2(center.x + _rng.randf_range(-58.0, 58.0), ARENA_RECT.end.y - 12.0)
        2:
            return Vector2(ARENA_RECT.position.x + 12.0, center.y + _rng.randf_range(-54.0, 54.0))
        _:
            return Vector2(ARENA_RECT.end.x - 12.0, center.y + _rng.randf_range(-54.0, 54.0))


func _complete_wave() -> void:
    if not wave_active:
        return
    wave_active = false
    coins += 3 + wave_index
    greed_score += 10 + wave_index * 3
    audio_manager.play_event(&"wave_clear")
    impact_system.spawn_reward(ARENA_RECT.get_center(), Color("f4d66d"))
    if wave_index >= GreedBalance.WAVE_TABLE.size() - 1:
        _finish_run(true)
        return
    _open_surprise_choice()


func _open_surprise_choice() -> void:
    choice_open = true
    _set_combat_frozen(true)
    _current_choices = blessing_system.roll_choices(3)
    choice_backdrop.visible = true
    choice_panel.visible = true
    choice_title.visible = true
    choice_title.text = _t("GREED REWARD · CHOOSE YOUR MUTATION", "贪婪奖励 · 选择一种变异")
    for index: int in range(choice_buttons.size()):
        var button: Button = choice_buttons[index]
        button.visible = index < _current_choices.size()
        if index >= _current_choices.size():
            continue
        var data: BlessingData = _current_choices[index]
        var next_stack: int = blessing_system.get_blessing_stack(data.id) + 1
        button.text = "%s · %s · Lv.%d\n%s" % [
            data.rarity_name(i18n.locale_code),
            data.localized_name(i18n.locale_code),
            next_stack,
            data.localized_description(i18n.locale_code, next_stack),
        ]
        button.add_theme_color_override("font_color", data.rarity_color())
    if not choice_buttons.is_empty():
        choice_buttons[0].grab_focus()
    audio_manager.play_event(&"chest_open")


func _select_choice(index: int) -> void:
    if not choice_open or index < 0 or index >= _current_choices.size():
        return
    var selected: BlessingData = _current_choices[index]
    blessing_system.apply_blessing(selected)
    var upgrade_target: GreedPlant = _lowest_level_plant()
    if upgrade_target != null:
        upgrade_target.upgrade()
    impact_system.spawn_reward(ARENA_RECT.get_center(), selected.rarity_color())
    audio_manager.play_event(&"blessing")

    choice_open = false
    choice_backdrop.visible = false
    choice_panel.visible = false
    choice_title.visible = false
    for button: Button in choice_buttons:
        button.visible = false
    _current_choices.clear()
    _set_combat_frozen(false)
    next_wave_timer = WAVE_START_DELAY
    _refresh_hud()


func _lowest_level_plant() -> GreedPlant:
    var result: GreedPlant = null
    for plant: GreedPlant in plants:
        if plant == null or not is_instance_valid(plant):
            continue
        if result == null or plant.level < result.level:
            result = plant
    return result


func _on_plant_fired(_plant: GreedPlant, target: GreedEnemy, critical: bool, damage: float) -> void:
    if target == null or not is_instance_valid(target):
        return
    if critical:
        audio_manager.play_event(&"critical")
        impact_system.spawn_hit(target.global_position, target.body_color, damage, true)


func _on_enemy_damaged(enemy: GreedEnemy, damage: float, critical: bool) -> void:
    if enemy == null or not is_instance_valid(enemy):
        return
    impact_system.spawn_hit(enemy.global_position, enemy.body_color, damage, critical)


func _on_enemy_defeated(enemy: GreedEnemy, coin_reward: int, elite: bool) -> void:
    var position_value: Vector2 = ARENA_RECT.get_center()
    var color_value: Color = Color("dd6d63")
    var size_value: Vector2 = Vector2(12.0, 12.0)
    if enemy != null and is_instance_valid(enemy):
        position_value = enemy.global_position
        color_value = enemy.body_color
        size_value = Vector2.ONE * enemy.body_size
    impact_system.spawn_kill(position_value, color_value, size_value)
    coins += blessing_system.modify_reward(coin_reward)
    greed_score += 2 if elite else 1
    enemies_defeated += 1
    seconds_since_last_kill = 0.0
    if elite:
        audio_manager.play_event(&"boss_phase")
    _refresh_hud()


func _on_enemy_core_contact(enemy: GreedEnemy, damage: int) -> void:
    if core.take_contact_damage(damage):
        impact_system.spawn_hit(core.global_position, Color("b8ec71"), float(damage) * 12.0, true)
        audio_manager.play_event(&"base_hit")
    if enemy != null and is_instance_valid(enemy):
        enemy.apply_knockback(core.global_position, 190.0)


func _on_core_health_changed(_current: int, _maximum: int) -> void:
    _refresh_hud()


func _on_core_defeated() -> void:
    _finish_run(false)


func _on_coin_jackpot(amount: int) -> void:
    coins += amount
    greed_score += int(amount / 4)
    impact_system.spawn_reward(ARENA_RECT.get_center(), Color("ffd45e"))
    _refresh_hud()


func _finish_run(victory: bool) -> void:
    if game_ended:
        return
    game_ended = true
    wave_active = false
    _set_combat_frozen(true)
    choice_backdrop.visible = true
    result_label.visible = true
    result_button.visible = true
    if victory:
        result_label.text = _t("GREED FLOOR CLEARED\n%d COINS · %d DEFEATED", "贪婪楼层完成\n%d 金币 · 击败 %d") % [coins, enemies_defeated]
        audio_manager.play_event(&"victory")
    else:
        result_label.text = _t("THE GARDEN FELL\nTRY A NEW MUTATION PATH", "花园核心倒下\n尝试新的变异路线")
        audio_manager.play_event(&"defeat")
    result_button.text = _t("RESTART RUN", "重新开始")


func _set_combat_frozen(value: bool) -> void:
    var mode: int = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
    if core != null:
        core.process_mode = mode
    for plant: GreedPlant in plants:
        if plant != null and is_instance_valid(plant):
            plant.process_mode = mode
    for node: Node in get_tree().get_nodes_in_group("greed_enemies"):
        if node != null and is_instance_valid(node):
            node.process_mode = mode


func _toggle_language() -> void:
    i18n.toggle_locale()
    settings.set_locale(i18n.locale_code)
    _apply_locale()


func _cycle_speed() -> void:
    if Engine.time_scale < 1.5:
        Engine.time_scale = 2.0
    elif Engine.time_scale < 2.5:
        Engine.time_scale = 3.0
    else:
        Engine.time_scale = 1.0
    speed_button.text = "%d×" % int(Engine.time_scale)


func _return_to_menu() -> void:
    Engine.time_scale = 1.0
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _restart_run() -> void:
    Engine.time_scale = 1.0
    get_tree().reload_current_scene()


func _apply_locale() -> void:
    language_button.text = "中文" if i18n.locale_code == "en" else "EN"
    menu_button.text = _t("MENU", "菜单")
    _refresh_hud()
    if choice_open:
        choice_title.text = _t("GREED REWARD · CHOOSE YOUR MUTATION", "贪婪奖励 · 选择一种变异")


func _refresh_hud() -> void:
    if wave_label == null:
        return
    wave_label.text = _t("GREED WAVE %d/%d", "贪婪波次 %d/%d") % [maxi(0, wave_index + 1), GreedBalance.WAVE_TABLE.size()]
    var current_health: int = core.health if core != null else 0
    var maximum_health: int = core.max_health if core != null else 0
    health_label.text = _t("CORE %d/%d", "核心 %d/%d") % [current_health, maximum_health]
    coins_label.text = _t("COINS %d", "金币 %d") % coins
    greed_label.text = _t("GREED %d", "贪婪 %d") % greed_score
    var lines: PackedStringArray = PackedStringArray()
    for plant: GreedPlant in plants:
        if plant == null or not is_instance_valid(plant):
            continue
        lines.append("%s Lv.%d · %.0f DPS" % [plant.get_display_name(i18n.locale_code), plant.level, plant.get_sustained_dps()])
    lines.append(_t("Starter safety margin %.1fx", "开局安全倍率 %.1f倍") % GreedBalance.starter_margin_ratio())
    power_label.text = "\n".join(lines)


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


func _t(english: String, chinese: String) -> String:
    return chinese if i18n != null and i18n.locale_code == "zh_CN" else english


func _make_label(parent: Node, position_value: Vector2, size_value: Vector2, font_size: int) -> Label:
    var label: Label = Label.new()
    label.position = position_value
    label.size = size_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color("f4f0d1"))
    parent.add_child(label)
    return label


func _make_button(parent: Node, position_value: Vector2, size_value: Vector2) -> Button:
    var button: Button = Button.new()
    button.position = position_value
    button.size = size_value
    button.focus_mode = Control.FOCUS_ALL
    button.add_theme_font_size_override("font_size", 11)
    var normal: StyleBoxFlat = StyleBoxFlat.new()
    normal.bg_color = Color("2a3432")
    normal.border_color = Color("9d8152")
    normal.set_border_width_all(2)
    var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color("3a4c43")
    hover.border_color = Color("f0c85a")
    var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("171d20")
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("focus", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_color_override("font_color", Color("f4f0d1"))
    parent.add_child(button)
    return button


func _make_panel(parent: Node, position_value: Vector2, size_value: Vector2) -> Panel:
    var panel: Panel = Panel.new()
    panel.position = position_value
    panel.size = size_value
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.06, 0.07, 0.10, 0.995)
    style.border_color = Color("f0c85a")
    style.set_border_width_all(3)
    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)
    return panel