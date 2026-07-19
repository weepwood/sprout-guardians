extends Node
class_name StatusEffectComponent

signal effect_applied(effect_id: StringName, stacks: int)
signal effect_removed(effect_id: StringName)

var _enemy: SproutEnemy
var _effects: Dictionary = {}


func setup(enemy: SproutEnemy) -> void:
    _enemy = enemy


func apply(effect: StatusEffectData) -> void:
    if effect == null or effect.duration <= 0.0:
        return

    var effect_id: StringName = effect.id
    if _effects.has(effect_id):
        var current: Dictionary = _effects[effect_id] as Dictionary
        match effect.stack_mode:
            StatusEffectData.StackMode.REPLACE:
                current = _make_state(effect, 1)
            StatusEffectData.StackMode.REFRESH:
                current["remaining"] = effect.duration
                current["tick"] = effect.tick_interval
            StatusEffectData.StackMode.STACK:
                current["stacks"] = mini(effect.max_stacks, int(current.get("stacks", 1)) + 1)
                current["remaining"] = effect.duration
        _effects[effect_id] = current
    else:
        _effects[effect_id] = _make_state(effect, 1)

    var state: Dictionary = _effects[effect_id] as Dictionary
    effect_applied.emit(effect_id, int(state.get("stacks", 1)))


func get_speed_multiplier() -> float:
    var multiplier: float = 1.0
    for value: Variant in _effects.values():
        var state: Dictionary = value as Dictionary
        var effect: StatusEffectData = state.get("data") as StatusEffectData
        if effect == null:
            continue
        multiplier *= pow(effect.speed_multiplier, int(state.get("stacks", 1)))
    return maxf(0.05, multiplier)


func clear() -> void:
    for effect_id: Variant in _effects.keys():
        effect_removed.emit(effect_id as StringName)
    _effects.clear()


func _process(delta: float) -> void:
    if _enemy == null or not is_instance_valid(_enemy):
        return

    var expired: Array[StringName] = []
    for effect_id_value: Variant in _effects.keys():
        var effect_id: StringName = effect_id_value as StringName
        var state: Dictionary = _effects[effect_id] as Dictionary
        var effect: StatusEffectData = state.get("data") as StatusEffectData
        if effect == null:
            expired.append(effect_id)
            continue

        state["remaining"] = float(state.get("remaining", 0.0)) - delta
        if effect.tick_interval > 0.0 and effect.damage_per_tick > 0.0:
            var tick: float = float(state.get("tick", effect.tick_interval)) - delta
            while tick <= 0.0:
                _enemy.take_damage(effect.damage_per_tick * float(int(state.get("stacks", 1))))
                tick += effect.tick_interval
                if not is_instance_valid(_enemy):
                    return
            state["tick"] = tick

        if float(state.get("remaining", 0.0)) <= 0.0:
            expired.append(effect_id)
        else:
            _effects[effect_id] = state

    for effect_id: StringName in expired:
        _effects.erase(effect_id)
        effect_removed.emit(effect_id)


func _make_state(effect: StatusEffectData, stacks: int) -> Dictionary:
    return {
        "data": effect,
        "remaining": effect.duration,
        "tick": effect.tick_interval,
        "stacks": stacks,
    }
