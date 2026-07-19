extends "res://scripts/rewarded_game.gd"

var garden_director: AutonomousGardenDirector
var pixel_impact_system: PixelImpactSystem
var director_status_label: Label
var director_mode_label: Label

var _automation_action: bool = false
var _director_status_en: String = "Garden director booting"
var _director_status_zh: String = "花园导演正在启动"


func _ready() -> void:
    super._ready()
    onboarding_active = false
    if onboarding_panel != null:
        onboarding_panel.visible = false
    if onboarding_label != null:
        onboarding_label.visible = false
    if onboarding_skip_button != null:
        onboarding_skip_button.visible = false

    _apply_autonomous_ui_state()
    auto_battle_director.set_auto_enabled(true, false)
    auto_battle_director.arm(1.25)
    garden_director.set_enabled(true)
    garden_director.force_decision()
    _refresh_reward_hud()


func _create_systems() -> void:
    super._create_systems()

    pixel_impact_system = PixelImpactSystem.new()
    pixel_impact_system.name = "PixelImpactSystem"
    add_child(pixel_impact_system)
    pixel_impact_system.impact_pulse.connect(_on_impact_pulse)

    garden_director = AutonomousGardenDirector.new()
    garden_director.name = "AutonomousGardenDirector"
    add_child(garden_director)
    garden_director.setup(
        level_data,
        economy_system,
        wave_manager,
        Callable(self, "_provide_towers"),
        Callable(self, "_is_director_preparing"),
        blessing_system.seed_value if blessing_system != null else 20260719
    )
    garden_director.deploy_requested.connect(_on_director_deploy_requested)
    garden_director.upgrade_requested.connect(_on_director_upgrade_requested)
    garden_director.relocate_requested.connect(_on_director_relocate_requested)
    garden_director.status_changed.connect(_on_director_status_changed)


func _create_ui() -> void:
    super._create_ui()
    var canvas: Node = get_node_or_null("UI")
    if canvas == null:
        return

    _make_panel(canvas, Vector2(116.0, 48.0), Vector2(286.0, 54.0), Color(0.035, 0.085, 0.095, 0.96), Color("79c879"))
    director_mode_label = _make_label(canvas, Vector2(124.0, 53.0), Vector2(270.0, 19.0))
    director_mode_label.add_theme_font_size_override("font_size", 12)
    director_mode_label.add_theme_color_override("font_color", Color("bdf5a8"))
    director_status_label = _make_label(canvas, Vector2(124.0, 72.0), Vector2(270.0, 25.0))
    director_status_label.add_theme_font_size_override("font_size", 11)
    director_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _refresh_director_status()


func _apply_locale() -> void:
    super._apply_locale()
    _refresh_director_status()
    if chest_title_label != null and chest_title_label.visible:
        chest_title_label.text = _run_t("SURPRISE DROP · CHOOSE ONE", "惊喜掉落 · 三选一")


func _unhandled_input(_event: InputEvent) -> void:
    # Default autonomous mode intentionally has no world-click placement or tower control.
    return


func _build_tower(_slot_index: int) -> void:
    if not _automation_action:
        return
    super._build_tower(_slot_index)


func _upgrade_selected() -> void:
    if not _automation_action:
        return
    super._upgrade_selected()


func _sell_selected() -> void:
    if not _automation_action:
        return
    super._sell_selected()


func _start_next_wave() -> void:
    if not _automation_action:
        return
    super._start_next_wave()


func _on_auto_start_requested() -> void:
    _automation_action = true
    super._on_auto_start_requested()
    _automation_action = false


func _spawn_enemy(enemy_data: EnemyData, path_index: int) -> void:
    var enemy: SproutEnemy = SproutEnemy.new()
    add_child(enemy)
    enemy.configure(level_data.get_enemy_path(path_index), enemy_data)
    enemy_registry.register_enemy(enemy)
    enemy.damaged.connect(_on_enemy_damaged)
    enemy.defeated.connect(_on_enemy_defeated)
    enemy.escaped.connect(_on_enemy_escaped)
    enemy.phase_changed.connect(_on_enemy_phase_changed)


func _on_enemy_damaged(enemy: SproutEnemy, amount: float, critical: bool, fatal: bool) -> void:
    if enemy == null or not is_instance_valid(enemy) or pixel_impact_system == null:
        return
    var color_value: Color = enemy.get_body_color()
    pixel_impact_system.spawn_hit(enemy.global_position, color_value, amount, critical)
    if fatal:
        pixel_impact_system.spawn_kill(enemy.global_position, color_value, enemy.get_body_size())


func _on_enemy_defeated(enemy: SproutEnemy, reward: int) -> void:
    super._on_enemy_defeated(enemy, reward)
    if garden_director != null:
        garden_director.force_decision()


func _on_enemy_phase_changed(enemy: SproutEnemy, phase_index: int) -> void:
    super._on_enemy_phase_changed(enemy, phase_index)
    if enemy != null and is_instance_valid(enemy) and pixel_impact_system != null:
        pixel_impact_system.spawn_boss_phase(enemy.global_position, enemy.get_body_color())


func _on_wave_completed(index: int, clear_reward: int) -> void:
    super._on_wave_completed(index, clear_reward)
    if index < wave_manager.get_total_waves() - 1:
        combat_reward_system.grant_surprise_drop(1)


func _on_chest_ready(pending_chests: int) -> void:
    if garden_director != null:
        garden_director.set_blocked(true)
    super._on_chest_ready(pending_chests)


func _open_pending_chest() -> void:
    super._open_pending_chest()
    if chest_title_label != null and chest_title_label.visible:
        chest_title_label.text = _run_t("SURPRISE DROP · CHOOSE ONE", "惊喜掉落 · 三选一")


func _select_blessing(index: int) -> void:
    var selected: BlessingData = null
    if index >= 0 and index < _current_choices.size():
        selected = _current_choices[index]
    super._select_blessing(index)
    if selected != null and pixel_impact_system != null:
        pixel_impact_system.spawn_reward(Vector2(320.0, 180.0), selected.rarity_color())
    if garden_director != null:
        garden_director.set_blocked(false)
        garden_director.force_decision()


func _on_game_finished(victory: bool) -> void:
    if garden_director != null:
        garden_director.set_blocked(true)
        garden_director.set_enabled(false)
    super._on_game_finished(victory)


func _on_director_deploy_requested(tower_index: int, slot_index: int, _reason: String) -> void:
    var before_count: int = towers_by_slot.size()
    selected_build_tower_index = tower_index
    _automation_action = true
    super._build_tower(slot_index)
    _automation_action = false
    var success: bool = towers_by_slot.size() > before_count and towers_by_slot.has(slot_index)
    if success:
        var tower: SproutTower = towers_by_slot[slot_index] as SproutTower
        if tower != null:
            tower.set_selected(false)
        selected_tower = null
        _update_tower_panel()
    garden_director.notify_action_resolved(success)


func _on_director_upgrade_requested(slot_index: int, _reason: String) -> void:
    var tower: SproutTower = towers_by_slot.get(slot_index) as SproutTower
    if tower == null or not is_instance_valid(tower):
        garden_director.notify_action_resolved(false)
        return
    var cost: int = tower.get_upgrade_cost()
    if cost < 0 or not economy_system.spend(cost, &"director_upgrade"):
        garden_director.notify_action_resolved(false)
        return
    tower.apply_upgrade()
    audio_manager.play_event(&"upgrade")
    _show_feedback(_run_t("AUTO UPGRADE · Lv.%d", "自动升级 · %d级") % tower.level, Color("f0cf75"))
    garden_director.notify_action_resolved(true)


func _on_director_relocate_requested(from_slot: int, to_slot: int, _reason: String) -> void:
    if not towers_by_slot.has(from_slot) or towers_by_slot.has(to_slot):
        garden_director.notify_action_resolved(false)
        return
    var tower: SproutTower = towers_by_slot[from_slot] as SproutTower
    if tower == null or not is_instance_valid(tower):
        garden_director.notify_action_resolved(false)
        return
    towers_by_slot.erase(from_slot)
    towers_by_slot[to_slot] = tower
    tower.slot_index = to_slot
    tower.set_selected(false)
    selected_tower = null
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(tower, "position", level_data.build_slots[to_slot], 0.28)
    tween.tween_callback(_finish_director_relocation)
    audio_manager.play_event(&"build")
    _show_feedback(_run_t("FORMATION SHIFT", "阵型自动换位"), Color("9ce8ff"))
    queue_redraw()


func _finish_director_relocation() -> void:
    garden_director.notify_action_resolved(true)
    _update_tower_panel()
    queue_redraw()


func _on_director_status_changed(english: String, chinese: String) -> void:
    _director_status_en = english
    _director_status_zh = chinese
    _refresh_director_status()


func _refresh_director_status() -> void:
    if director_mode_label == null or director_status_label == null:
        return
    director_mode_label.text = _run_t("AUTONOMOUS GARDEN · PLAYER CHOOSES DROPS", "全自动花园 · 玩家只选择惊喜")
    director_status_label.text = _director_status_zh if i18n != null and i18n.locale_code == "zh_CN" else _director_status_en


func _apply_autonomous_ui_state() -> void:
    if start_wave_button != null:
        start_wave_button.visible = false
    if auto_button != null:
        auto_button.visible = false
    for button: Button in tower_build_buttons:
        button.visible = false
    if upgrade_button != null:
        upgrade_button.visible = false
    if sell_button != null:
        sell_button.visible = false
    if tower_label != null:
        tower_label.visible = false
    if hint_label != null:
        hint_label.text = _run_t("The garden deploys, upgrades, moves, and fights automatically.", "植物部署、升级、移动与战斗均由系统自动执行。")


func _provide_towers() -> Dictionary:
    return towers_by_slot


func _is_director_preparing() -> bool:
    return game_manager != null and game_manager.state == GameManager.State.PREPARING


func _on_impact_pulse(_position_value: Vector2, strength: float) -> void:
    if strength >= 0.75:
        _flash_screen(Color(1.0, 0.78, 0.24, minf(0.28, strength * 0.24)))