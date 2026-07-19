extends Node
class_name WaveManager

signal wave_started(index: int, total: int)
signal enemy_spawn_requested(enemy_data: EnemyData, path_index: int)
signal wave_completed(index: int, clear_reward: int)
signal campaign_completed

var level_data: LevelData
var current_wave_index: int = -1
var active_enemies: int = 0
var wave_active: bool = false

var _group_states: Array[Dictionary] = []


func setup(data: LevelData) -> void:
    level_data = data
    current_wave_index = -1
    active_enemies = 0
    wave_active = false
    _group_states.clear()


func start_next_wave() -> bool:
    if level_data == null or wave_active:
        return false
    if current_wave_index + 1 >= level_data.get_wave_count():
        return false

    current_wave_index += 1
    var wave: WaveData = level_data.get_wave(current_wave_index)
    if wave == null:
        return false

    _group_states.clear()
    for group: SpawnGroupData in wave.get_spawn_groups():
        if group.enemy == null or group.count <= 0:
            continue
        _group_states.append({
            "group": group,
            "remaining": group.count,
            "cooldown": group.start_delay,
        })

    wave_active = true
    wave_started.emit(current_wave_index, level_data.get_wave_count())
    if _group_states.is_empty():
        _complete_current_wave()
    return true


func _process(delta: float) -> void:
    if not wave_active:
        return

    for index: int in range(_group_states.size()):
        var state: Dictionary = _group_states[index]
        var remaining: int = int(state.get("remaining", 0))
        if remaining <= 0:
            continue

        var group: SpawnGroupData = state.get("group") as SpawnGroupData
        if group == null or group.enemy == null:
            state["remaining"] = 0
            _group_states[index] = state
            continue

        var cooldown: float = float(state.get("cooldown", 0.0)) - delta
        while cooldown <= 0.0 and remaining > 0:
            active_enemies += 1
            enemy_spawn_requested.emit(group.enemy, group.path_index)
            remaining -= 1
            cooldown += maxf(0.05, group.spawn_interval)

        state["remaining"] = remaining
        state["cooldown"] = cooldown
        _group_states[index] = state

    _check_wave_complete()


func notify_enemy_removed() -> void:
    active_enemies = maxi(0, active_enemies - 1)
    _check_wave_complete()


func get_total_waves() -> int:
    return 0 if level_data == null else level_data.get_wave_count()


func _check_wave_complete() -> void:
    if not wave_active or active_enemies > 0:
        return
    for state: Dictionary in _group_states:
        if int(state.get("remaining", 0)) > 0:
            return
    _complete_current_wave()


func _complete_current_wave() -> void:
    if not wave_active:
        return
    wave_active = false
    var wave: WaveData = level_data.get_wave(current_wave_index)
    var reward: int = 0 if wave == null else wave.clear_reward
    wave_completed.emit(current_wave_index, reward)
    if current_wave_index >= level_data.get_wave_count() - 1:
        campaign_completed.emit()
