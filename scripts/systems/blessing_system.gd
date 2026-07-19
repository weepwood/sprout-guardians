extends Node
class_name BlessingSystem

signal blessing_applied(data: BlessingData, stack_count: int)
signal modifiers_changed
signal sunlight_jackpot(amount: int)

const HIGH_RARITY_PITY_START: int = 4
const HIGH_RARITY_GUARANTEE: int = 8
const CRITICAL_DAMAGE_MULTIPLIER: float = 1.75

var pool: Array[BlessingData] = []
var stacks: Dictionary = {}
var pity_without_high: int = 0
var seed_value: int = 0

var _reward_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _combat_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(blessing_pool: Array[BlessingData], requested_seed: int = 0) -> void:
    pool = blessing_pool.duplicate()
    stacks.clear()
    pity_without_high = 0
    seed_value = requested_seed
    if seed_value == 0:
        seed_value = int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec())
    _reward_rng.seed = seed_value
    _combat_rng.seed = seed_value ^ 0x5F3759DF


func roll_choices(count: int = 3) -> Array[BlessingData]:
    var candidates: Array[BlessingData] = []
    for data: BlessingData in pool:
        if data == null:
            continue
        if data.effect_type == BlessingData.EffectType.SUNLIGHT or get_stack(data.id) < data.max_stacks:
            candidates.append(data)

    if candidates.is_empty():
        candidates = pool.duplicate()

    var choices: Array[BlessingData] = []
    var requested: int = mini(maxi(0, count), candidates.size())
    for _index: int in range(requested):
        var selected: BlessingData = _roll_one(candidates)
        if selected == null:
            break
        choices.append(selected)
        candidates.erase(selected)

    var found_high: bool = false
    for data: BlessingData in choices:
        if data.rarity >= BlessingData.Rarity.EPIC:
            found_high = true
            break
    pity_without_high = 0 if found_high else pity_without_high + 1
    return choices


func apply_blessing(data: BlessingData) -> int:
    if data == null:
        return 0
    var current: int = get_stack(data.id)
    var next_stack: int = mini(data.max_stacks, current + 1)
    stacks[String(data.id)] = next_stack
    if data.effect_type == BlessingData.EffectType.SUNLIGHT:
        sunlight_jackpot.emit(maxi(1, int(round(data.value_per_stack))))
    blessing_applied.emit(data, next_stack)
    modifiers_changed.emit()
    return next_stack


func get_stack(blessing_id: StringName) -> int:
    return int(stacks.get(String(blessing_id), 0))


func get_damage_multiplier() -> float:
    return 1.0 + _effect_total(BlessingData.EffectType.DAMAGE)


func get_attack_interval_multiplier() -> float:
    return maxf(0.35, 1.0 - _effect_total(BlessingData.EffectType.ATTACK_SPEED))


func get_range_multiplier() -> float:
    return 1.0 + _effect_total(BlessingData.EffectType.RANGE)


func get_reward_multiplier() -> float:
    return 1.0 + _effect_total(BlessingData.EffectType.REWARD)


func get_critical_chance() -> float:
    return clampf(_effect_total(BlessingData.EffectType.CRITICAL), 0.0, 0.75)


func roll_critical() -> bool:
    return _combat_rng.randf() < get_critical_chance()


func modify_reward(base_reward: int) -> int:
    return maxi(0, int(round(float(base_reward) * get_reward_multiplier())))


func modify_status_effect(source: StatusEffectData) -> StatusEffectData:
    if source == null:
        return null
    var result: StatusEffectData = source.duplicate(true) as StatusEffectData
    if result.damage_per_tick > 0.0:
        var poison_bonus: float = _effect_total(BlessingData.EffectType.POISON)
        result.damage_per_tick *= 1.0 + poison_bonus
        result.duration *= 1.0 + poison_bonus * 0.5
    if result.speed_multiplier < 1.0:
        var slow_bonus: float = _effect_total(BlessingData.EffectType.SLOW)
        result.speed_multiplier = clampf(result.speed_multiplier - slow_bonus, 0.15, 1.0)
    return result


func _effect_total(effect: BlessingData.EffectType) -> float:
    var total: float = 0.0
    for data: BlessingData in pool:
        if data == null or data.effect_type != effect:
            continue
        total += data.value_per_stack * float(get_stack(data.id))
    return total


func _roll_one(candidates: Array[BlessingData]) -> BlessingData:
    if candidates.is_empty():
        return null

    if pity_without_high >= HIGH_RARITY_GUARANTEE:
        var guaranteed: Array[BlessingData] = []
        for data: BlessingData in candidates:
            if data.rarity >= BlessingData.Rarity.EPIC:
                guaranteed.append(data)
        if not guaranteed.is_empty():
            return guaranteed[_reward_rng.randi_range(0, guaranteed.size() - 1)]

    var total_weight: float = 0.0
    for data: BlessingData in candidates:
        total_weight += _effective_weight(data)
    if total_weight <= 0.0:
        return candidates[0]

    var roll: float = _reward_rng.randf_range(0.0, total_weight)
    var cursor: float = 0.0
    for data: BlessingData in candidates:
        cursor += _effective_weight(data)
        if roll <= cursor:
            return data
    return candidates.back()


func _effective_weight(data: BlessingData) -> float:
    var weight: float = maxf(0.001, data.base_weight)
    if pity_without_high >= HIGH_RARITY_PITY_START:
        var pity_steps: int = pity_without_high - HIGH_RARITY_PITY_START + 1
        if data.rarity == BlessingData.Rarity.EPIC:
            weight *= 1.0 + float(pity_steps) * 0.45
        elif data.rarity == BlessingData.Rarity.LEGENDARY:
            weight *= 1.0 + float(pity_steps) * 0.25
    return weight