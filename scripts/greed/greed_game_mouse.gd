extends "res://scripts/greed/greed_game_balanced.gd"

var hero_plant: GreedHeroPlant
var control_label: Label
var launched_projectiles: int = 0


func _create_arena() -> void:
    hero_plant = GreedHeroPlant.new()
    hero_plant.name = "MainPlant"
    hero_plant.global_position = ARENA_RECT.get_center()
    add_child(hero_plant)
    hero_plant.configure(GreedBalance.STARTER_PLANTS[0], blessing_system)
    hero_plant.health_changed.connect(_on_core_health_changed)
    hero_plant.defeated.connect(_on_core_defeated)
    hero_plant.fired.connect(_on_hero_fired)
    hero_plant.projectile_requested.connect(_on_projectile_requested)
    hero_plant.dash_started.connect(_on_hero_dash_started)
    core = hero_plant

    plants.clear()
    for config_index: int in range(1, GreedBalance.STARTER_PLANTS.size()):
        var familiar_index: int = config_index - 1
        var familiar: GreedPlant = GreedPlant.new()
        familiar.name = "FloatingFamiliar%d" % familiar_index
        familiar.global_position = hero_plant.global_position + Vector2.from_angle(PI * float(familiar_index)) * (42.0 + float(familiar_index) * 18.0)
        add_child(familiar)
        familiar.configure(hero_plant, GreedBalance.STARTER_PLANTS[config_index], familiar_index, blessing_system)
        familiar.set_focus_source(hero_plant)
        familiar.fired.connect(_on_plant_fired)
        familiar.projectile_requested.connect(_on_projectile_requested)
        plants.append(familiar)


func _create_ui() -> void:
    super._create_ui()
    var canvas: CanvasLayer = get_node("UI") as CanvasLayer
    control_label = _make_label(canvas, Vector2(168.0, 46.0), Vector2(324.0, 58.0), 11)
    control_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    control_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    control_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _update_control_status()


func _process(delta: float) -> void:
    super._process(delta)
    if hero_plant != null and is_instance_valid(hero_plant):
        hero_plant.fury_multiplier = GreedBalance.fury_multiplier(wave_elapsed)
        hero_plant.rescue_active = GreedBalance.rescue_active(seconds_since_last_kill)
    _update_control_status()


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
    _draw_door(Vector2(center.x, ARENA_RECT.position.y), Vector2(56.0, 18.0))
    _draw_door(Vector2(center.x, ARENA_RECT.end.y), Vector2(56.0, 18.0))
    _draw_door(Vector2(ARENA_RECT.position.x, center.y), Vector2(18.0, 56.0))
    _draw_door(Vector2(ARENA_RECT.end.x, center.y), Vector2(18.0, 56.0))


func _unhandled_input(event: InputEvent) -> void:
    if game_ended or choice_open or hero_plant == null or not is_instance_valid(hero_plant):
        return

    if event is InputEventKey:
        var key_event: InputEventKey = event as InputEventKey
        if key_event.pressed and not key_event.echo and (key_event.keycode == KEY_SPACE or key_event.physical_keycode == KEY_SPACE):
            if hero_plant.request_dash(get_viewport().get_mouse_position()):
                get_viewport().set_input_as_handled()
            return

    if event is InputEventMouseMotion:
        var motion: InputEventMouseMotion = event as InputEventMouseMotion
        if hero_plant.dragging:
            hero_plant.drag_to(motion.position)
            get_viewport().set_input_as_handled()
        return

    if not (event is InputEventMouseButton):
        return
    var mouse_event: InputEventMouseButton = event as InputEventMouseButton

    if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
        hero_plant.clear_focus_target()
        hero_plant.set_selected(false)
        get_viewport().set_input_as_handled()
        return

    if mouse_event.button_index != MOUSE_BUTTON_LEFT:
        return

    if not mouse_event.pressed:
        if hero_plant.dragging:
            hero_plant.end_drag(mouse_event.position)
            get_viewport().set_input_as_handled()
        return

    _handle_left_click(mouse_event.position, mouse_event.double_click)
    get_viewport().set_input_as_handled()


func _handle_left_click(position_value: Vector2, double_click: bool = false) -> void:
    var enemy: GreedEnemy = _enemy_at_point(position_value)
    if enemy != null:
        _set_priority_target(enemy)
        return
    if double_click and GreedCore.ARENA_RECT.has_point(position_value):
        if hero_plant.request_dash(position_value):
            return
    if hero_plant.is_point_inside(position_value):
        hero_plant.begin_drag()
        return
    if hero_plant.selected and GreedCore.ARENA_RECT.has_point(position_value):
        hero_plant.set_move_target(position_value)
        return
    hero_plant.set_selected(false)


func _set_priority_target(enemy: GreedEnemy) -> void:
    if hero_plant == null or not is_instance_valid(hero_plant):
        return
    hero_plant.set_focus_target(enemy)


func _enemy_at_point(position_value: Vector2) -> GreedEnemy:
    var result: GreedEnemy = null
    var closest: float = INF
    for node: Node in get_tree().get_nodes_in_group("greed_enemies"):
        var enemy: GreedEnemy = node as GreedEnemy
        if enemy == null or not is_instance_valid(enemy) or not enemy.is_point_inside(position_value):
            continue
        var distance_value: float = enemy.global_position.distance_to(position_value)
        if distance_value < closest:
            result = enemy
            closest = distance_value
    return result


func _on_projectile_requested(
        origin: Vector2,
        target: GreedEnemy,
        damage: float,
        critical: bool,
        speed: float,
        splash_radius: float,
        slow_ratio: float,
        knockback_force: float,
        color: Color
) -> void:
    if target == null or not is_instance_valid(target):
        return
    var projectile: GreedProjectile = GreedProjectile.new()
    projectile.name = "GreedProjectile"
    add_child(projectile)
    projectile.configure(
        origin,
        target,
        damage,
        critical,
        speed,
        splash_radius,
        slow_ratio,
        knockback_force,
        color
    )
    launched_projectiles += 1


func _on_hero_dash_started(_from_position: Vector2, to_position: Vector2) -> void:
    impact_system.spawn_reward(to_position, Color("8ee8ff"))


func _select_choice(index: int) -> void:
    if not choice_open or index < 0 or index >= _current_choices.size():
        return
    var selected_blessing: BlessingData = _current_choices[index]
    blessing_system.apply_blessing(selected_blessing)

    if hero_plant != null and is_instance_valid(hero_plant):
        hero_plant.upgrade()
        if hero_plant.level % 3 == 0:
            var familiar: GreedPlant = _lowest_level_plant()
            if familiar != null:
                familiar.upgrade()

    var reward_position: Vector2 = ARENA_RECT.get_center()
    if hero_plant != null and is_instance_valid(hero_plant):
        reward_position = hero_plant.global_position
    impact_system.spawn_reward(reward_position, selected_blessing.rarity_color())
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


func _on_hero_fired(_hero: GreedHeroPlant, target: GreedEnemy, critical: bool, _damage: float) -> void:
    if target == null or not is_instance_valid(target):
        return
    if critical:
        audio_manager.play_event(&"critical")


func _on_plant_fired(_plant: GreedPlant, target: GreedEnemy, critical: bool, _damage: float) -> void:
    if target == null or not is_instance_valid(target):
        return
    if critical:
        audio_manager.play_event(&"critical")


func _on_enemy_defeated(enemy: GreedEnemy, coin_reward: int, elite: bool) -> void:
    if hero_plant != null and is_instance_valid(hero_plant) and hero_plant.get_focus_target() == enemy:
        hero_plant.clear_focus_target()
    super._on_enemy_defeated(enemy, coin_reward, elite)


func _set_combat_frozen(value: bool) -> void:
    super._set_combat_frozen(value)
    var mode: int = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
    for node: Node in get_tree().get_nodes_in_group("greed_projectiles"):
        if node != null and is_instance_valid(node):
            node.process_mode = mode


func _refresh_hud() -> void:
    super._refresh_hud()
    if power_label == null:
        return
    var lines: PackedStringArray = PackedStringArray()
    if hero_plant != null and is_instance_valid(hero_plant):
        lines.append(_t("MAIN", "主植物") + " · %s Lv.%d · %.0f DPS" % [hero_plant.get_display_name(i18n.locale_code), hero_plant.level, hero_plant.get_sustained_dps()])
    for familiar: GreedPlant in plants:
        if familiar == null or not is_instance_valid(familiar):
            continue
        lines.append(_t("PET", "浮游宠物") + " · %s Lv.%d · %.0f DPS" % [familiar.get_display_name(i18n.locale_code), familiar.level, familiar.get_sustained_dps()])
    power_label.text = "\n".join(lines)


func _apply_locale() -> void:
    super._apply_locale()
    _update_control_status()


func _update_control_status() -> void:
    if control_label == null or hero_plant == null or not is_instance_valid(hero_plant):
        return
    if choice_open:
        control_label.text = _t("Choose one mutation to continue", "选择一项变异后继续战斗")
        return
    if hero_plant.is_dashing():
        control_label.text = _t("DASHING · BRIEF CONTACT IMMUNITY", "闪避中 · 短暂无视接触伤害")
        return
    if hero_plant.dragging:
        control_label.text = _t("DRAGGING MAIN PLANT · RELEASE TO STOP", "正在拖动主植物 · 松开鼠标停止")
        return
    var target: GreedEnemy = hero_plant.get_focus_target()
    if target != null:
        control_label.text = _t("TARGET LOCKED · DOUBLE CLICK OR SPACE TO DASH · RIGHT CLICK TO CLEAR", "已锁定目标 · 双击地面或空格闪避 · 右键取消")
        return
    if hero_plant.selected:
        control_label.text = _t("CLICK FLOOR TO MOVE · DOUBLE CLICK OR SPACE TO DASH · CLICK ENEMY TO FOCUS", "点击地面移动 · 双击地面或空格闪避 · 点击怪物集火")
        return
    control_label.text = _t("CLICK OR DRAG MAIN PLANT · DOUBLE CLICK FLOOR TO DASH · CLICK ENEMY TO FOCUS", "点击或拖动主植物 · 双击地面闪避 · 点击怪物集火")
