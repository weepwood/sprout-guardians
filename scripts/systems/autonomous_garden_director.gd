extends Node
class_name AutonomousGardenDirector

signal deploy_requested(tower_index: int, slot_index: int, reason: String)
signal upgrade_requested(slot_index: int, reason: String)
signal relocate_requested(from_slot: int, to_slot: int, reason: String)
signal status_changed(english: String, chinese: String)
signal decision_made(kind: StringName)

@export_range(0.2, 5.0, 0.05) var decision_interval: float = 0.65
@export_range(1, 12, 1) var desired_plant_count: int = 4

var enabled: bool = false
var blocked: bool = false
var pending_action: bool = false
var decision_count: int = 0
var seed_value: int = 0

var _level_data: LevelData
var _economy: EconomySystem
var _wave_manager: WaveManager
var _towers_provider: Callable
var _preparing_provider: Callable
var _decision_time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(
        level_data: LevelData,
        economy: EconomySystem,
        wave_manager: WaveManager,
        towers_provider: Callable,
        preparing_provider: Callable,
        requested_seed: int = 0
) -> void:
    _level_data = level_data
    _economy = economy
    _wave_manager = wave_manager
    _towers_provider = towers_provider
    _preparing_provider = preparing_provider
    seed_value = requested_seed
    if seed_value == 0:
        seed_value = 20260719
    _rng.seed = seed_value
    _decision_time = 0.05
    pending_action = false
    decision_count = 0


func set_enabled(value: bool) -> void:
    enabled = value
    if enabled:
        _decision_time = minf(_decision_time, 0.08)
        status_changed.emit("Garden director online", "花园导演已启动")
    else:
        status_changed.emit("Garden director offline", "花园导演已停止")


func set_blocked(value: bool) -> void:
    blocked = value
    if blocked:
        status_changed.emit("Waiting for your surprise choice", "正在等待你选择惊喜加成")
    else:
        _decision_time = minf(_decision_time, 0.12)


func notify_action_resolved(success: bool) -> void:
    pending_action = false
    _decision_time = decision_interval if success else decision_interval * 0.45


func force_decision() -> void:
    if enabled and not blocked and not pending_action:
        _decision_time = 0.0
        _decide()


func _process(delta: float) -> void:
    if not enabled or blocked or pending_action or get_tree().paused:
        return
    if _level_data == null or _economy == null or not _towers_provider.is_valid():
        return
    _decision_time = maxf(0.0, _decision_time - delta)
    if _decision_time > 0.0:
        return
    _decide()


func _decide() -> void:
    _decision_time = decision_interval
    decision_count += 1
    var towers: Dictionary = _get_towers()
    var empty_slots: Array[int] = _get_empty_slots(towers)

    if towers.is_empty():
        if _request_deploy(towers, empty_slots, "Establishing the first autonomous plant"):
            return

    if towers.size() < mini(desired_plant_count, _level_data.build_slots.size()):
        if _request_deploy(towers, empty_slots, "Expanding formation coverage"):
            return

    if _request_upgrade(towers):
        return

    if not empty_slots.is_empty() and towers.size() < _level_data.build_slots.size():
        if _request_deploy(towers, empty_slots, "Adding another plant role"):
            return

    if _is_preparing() and decision_count % 3 == 0:
        if _request_relocation(towers, empty_slots):
            return

    status_changed.emit("Formation stable · saving sunlight", "阵型稳定 · 正在积攒阳光")


func _request_deploy(towers: Dictionary, empty_slots: Array[int], reason: String) -> bool:
    if empty_slots.is_empty():
        return false
    var tower_index: int = choose_tower_index(_get_next_wave())
    if tower_index < 0:
        return false
    var data: TowerData = _level_data.get_tower(tower_index)
    if data == null or _economy.coins < data.build_cost:
        return false
    var slot_index: int = choose_best_slot(data, empty_slots)
    if slot_index < 0:
        return false
    pending_action = true
    deploy_requested.emit(tower_index, slot_index, reason)
    decision_made.emit(&"deploy")
    status_changed.emit("Deploying %s" % data.display_name, "正在自动部署%s" % data.display_name)
    return true


func _request_upgrade(towers: Dictionary) -> bool:
    var best_slot: int = -1
    var best_score: float = -INF
    for slot_value: Variant in towers.keys():
        var slot_index: int = int(slot_value)
        var tower: SproutTower = towers[slot_value] as SproutTower
        if tower == null or not is_instance_valid(tower):
            continue
        var cost: int = tower.get_upgrade_cost()
        if cost < 0 or _economy.coins < cost:
            continue
        var damage_rate: float = tower.damage / maxf(0.08, tower.attack_interval)
        var coverage: float = _slot_score(slot_index, tower.attack_range)
        var score: float = damage_rate * (0.75 + coverage) / maxf(1.0, float(cost))
        score += float(4 - tower.level) * 0.05
        if score > best_score:
            best_score = score
            best_slot = slot_index
    if best_slot < 0:
        return false
    pending_action = true
    upgrade_requested.emit(best_slot, "Improving the highest-value plant")
    decision_made.emit(&"upgrade")
    status_changed.emit("Upgrading formation efficiency", "正在自动升级最高收益植物")
    return true


func _request_relocation(towers: Dictionary, empty_slots: Array[int]) -> bool:
    if towers.is_empty() or empty_slots.is_empty():
        return false
    var best_target: int = -1
    var best_target_score: float = -INF
    for slot_index: int in empty_slots:
        var score: float = _slot_score(slot_index, 112.0)
        if score > best_target_score:
            best_target_score = score
            best_target = slot_index

    var source_slot: int = -1
    var source_score: float = INF
    for slot_value: Variant in towers.keys():
        var slot_index: int = int(slot_value)
        var tower: SproutTower = towers[slot_value] as SproutTower
        if tower == null or not is_instance_valid(tower):
            continue
        var score: float = _slot_score(slot_index, tower.attack_range)
        if score < source_score:
            source_score = score
            source_slot = slot_index

    if source_slot < 0 or best_target < 0 or best_target_score <= source_score + 0.12:
        return false
    pending_action = true
    relocate_requested.emit(source_slot, best_target, "Rebalancing autonomous coverage")
    decision_made.emit(&"relocate")
    status_changed.emit("Relocating a plant to stronger coverage", "正在把植物移动到更优火力位置")
    return true


func choose_tower_index(wave: WaveData) -> int:
    if _level_data == null or _level_data.available_towers.is_empty():
        return -1
    var total_count: int = 0
    var speed_pressure: float = 0.0
    var armor_pressure: float = 0.0
    var boss_pressure: float = 0.0
    if wave != null:
        for group: SpawnGroupData in wave.get_spawn_groups():
            if group == null or group.enemy == null:
                continue
            total_count += group.count
            speed_pressure += group.enemy.move_speed * float(group.count)
            armor_pressure += group.enemy.armor * float(group.count)
            if group.enemy.is_boss:
                boss_pressure += float(group.count)
    var average_speed: float = speed_pressure / maxf(1.0, float(total_count))
    var average_armor: float = armor_pressure / maxf(1.0, float(total_count))

    var best_index: int = -1
    var best_score: float = -INF
    for index: int in range(_level_data.available_towers.size()):
        var data: TowerData = _level_data.get_tower(index)
        if data == null or _economy == null or _economy.coins < data.build_cost:
            continue
        var score: float = 1.0
        match data.id:
            &"mushroom_lamp":
                score += float(total_count) * 0.08 + average_armor * 0.03
            &"ice_flower":
                score += average_speed * 0.022 + float(total_count) * 0.015
            _:
                score += boss_pressure * 1.6 + maxf(0.0, 4.0 - average_armor) * 0.08
        score -= float(data.build_cost) * 0.001
        score += _rng.randf_range(0.0, 0.0001)
        if score > best_score:
            best_score = score
            best_index = index
    return best_index


func choose_best_slot(tower_data: TowerData, candidates: Array[int]) -> int:
    var best_slot: int = -1
    var best_score: float = -INF
    var range_value: float = 100.0 if tower_data == null else tower_data.get_range_for_level(1)
    for slot_index: int in candidates:
        var score: float = _slot_score(slot_index, range_value)
        if score > best_score:
            best_score = score
            best_slot = slot_index
    return best_slot


func _slot_score(slot_index: int, range_value: float) -> float:
    if _level_data == null or slot_index < 0 or slot_index >= _level_data.build_slots.size():
        return -INF
    var slot_position: Vector2 = _level_data.build_slots[slot_index]
    var score: float = 0.0
    var points: PackedVector2Array = _level_data.path_points
    for index: int in range(points.size()):
        var distance: float = slot_position.distance_to(points[index])
        if distance > range_value * 1.18:
            continue
        var proximity: float = 1.0 - distance / maxf(1.0, range_value * 1.18)
        var route_weight: float = 0.75 + float(index) / maxf(1.0, float(points.size() - 1)) * 0.5
        score += proximity * route_weight
    return score


func _get_next_wave() -> WaveData:
    if _level_data == null:
        return null
    var index: int = 0
    if _wave_manager != null:
        index = clampi(_wave_manager.current_wave_index + 1, 0, max(0, _level_data.get_wave_count() - 1))
    return _level_data.get_wave(index)


func _get_towers() -> Dictionary:
    if not _towers_provider.is_valid():
        return {}
    var value: Variant = _towers_provider.call()
    return value as Dictionary if value is Dictionary else {}


func _get_empty_slots(towers: Dictionary) -> Array[int]:
    var result: Array[int] = []
    if _level_data == null:
        return result
    for index: int in range(_level_data.build_slots.size()):
        if not towers.has(index):
            result.append(index)
    return result


func _is_preparing() -> bool:
    if not _preparing_provider.is_valid():
        return true
    return bool(_preparing_provider.call())