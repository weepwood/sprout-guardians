extends RefCounted
class_name GreedBalance

const STARTER_PLANTS: Array[Dictionary] = [
    {
        "id": &"pea_shooter",
        "name_en": "Pea Shooter",
        "name_zh": "豌豆射手",
        "damage": 18.0,
        "interval": 0.42,
        "range": 250.0,
        "projectile_speed": 420.0,
        "projectile_count": 1,
        "splash_radius": 0.0,
        "slow_ratio": 0.0,
        "color_hex": "8fe45f",
    },
    {
        "id": &"spore_bloom",
        "name_en": "Spore Bloom",
        "name_zh": "孢子花",
        "damage": 14.0,
        "interval": 0.72,
        "range": 220.0,
        "projectile_speed": 340.0,
        "projectile_count": 1,
        "splash_radius": 46.0,
        "slow_ratio": 0.0,
        "color_hex": "d28cff",
    },
    {
        "id": &"frost_petal",
        "name_en": "Frost Petal",
        "name_zh": "霜瓣花",
        "damage": 11.0,
        "interval": 0.58,
        "range": 235.0,
        "projectile_speed": 390.0,
        "projectile_count": 1,
        "splash_radius": 0.0,
        "slow_ratio": 0.28,
        "color_hex": "80dfff",
    },
]

const WAVE_TABLE: Array[Dictionary] = [
    {"count": 6, "health": 24.0, "speed": 42.0, "spawn_interval": 0.85, "damage": 1, "elite": false},
    {"count": 8, "health": 32.0, "speed": 48.0, "spawn_interval": 0.72, "damage": 1, "elite": false},
    {"count": 10, "health": 40.0, "speed": 52.0, "spawn_interval": 0.62, "damage": 1, "elite": false},
    {"count": 12, "health": 50.0, "speed": 56.0, "spawn_interval": 0.56, "damage": 1, "elite": false},
    {"count": 4, "health": 150.0, "speed": 44.0, "spawn_interval": 1.05, "damage": 2, "elite": true},
    {"count": 14, "health": 66.0, "speed": 60.0, "spawn_interval": 0.50, "damage": 1, "elite": false},
    {"count": 16, "health": 76.0, "speed": 64.0, "spawn_interval": 0.46, "damage": 1, "elite": false},
    {"count": 18, "health": 88.0, "speed": 68.0, "spawn_interval": 0.42, "damage": 1, "elite": false},
    {"count": 2, "health": 520.0, "speed": 48.0, "spawn_interval": 2.2, "damage": 2, "elite": true},
    {"count": 1, "health": 1650.0, "speed": 42.0, "spawn_interval": 0.1, "damage": 3, "elite": true, "boss": true},
]


static func starter_sustained_dps() -> float:
    var total: float = main_plant_sustained_dps(1)
    total += familiar_sustained_dps(1, 1)
    total += familiar_sustained_dps(2, 1)
    return total


static func main_plant_sustained_dps(level: int) -> float:
    return _plant_sustained_dps(STARTER_PLANTS[0], level, 0.28, 0.91)


static func familiar_sustained_dps(config_index: int, level: int) -> float:
    if config_index < 1 or config_index >= STARTER_PLANTS.size():
        return 0.0
    return _plant_sustained_dps(STARTER_PLANTS[config_index], level, 0.22, 0.93)


static func _plant_sustained_dps(plant: Dictionary, level: int, damage_step: float, interval_factor: float) -> float:
    var effective_level: int = maxi(1, level)
    var damage_value: float = float(plant["damage"]) * (1.0 + float(effective_level - 1) * damage_step)
    var interval_value: float = float(plant["interval"]) * pow(interval_factor, float(effective_level - 1))
    var direct: float = damage_value * float(plant.get("projectile_count", 1)) / maxf(0.08, interval_value)
    var splash_bonus: float = 1.25 if float(plant.get("splash_radius", 0.0)) > 0.0 else 1.0
    return direct * splash_bonus


static func minimum_progression_dps(rewards_received: int) -> float:
    var reward_count: int = maxi(0, rewards_received)
    var hero_level: int = 1 + reward_count
    var familiar_levels: Array[int] = [1, 1]
    var familiar_upgrades: int = int(floor(float(hero_level) / 3.0))
    for upgrade_index: int in range(familiar_upgrades):
        familiar_levels[upgrade_index % familiar_levels.size()] += 1

    return main_plant_sustained_dps(hero_level) \
        + familiar_sustained_dps(1, familiar_levels[0]) \
        + familiar_sustained_dps(2, familiar_levels[1])


static func wave_health_spawn_rate(index: int) -> float:
    if index < 0 or index >= WAVE_TABLE.size():
        return 0.0
    var wave: Dictionary = WAVE_TABLE[index]
    return float(wave["health"]) / maxf(0.05, float(wave["spawn_interval"]))


static func starter_margin_ratio() -> float:
    return starter_sustained_dps() / maxf(1.0, wave_health_spawn_rate(0))


static func projected_wave_clear_seconds(index: int) -> float:
    if index < 0 or index >= WAVE_TABLE.size():
        return INF
    var wave: Dictionary = WAVE_TABLE[index]
    var count: int = int(wave.get("count", 0))
    var spawn_tail: float = maxf(0.0, float(count - 1)) * float(wave.get("spawn_interval", 0.0))
    var total_health: float = float(count) * float(wave.get("health", 0.0))
    var guaranteed_dps: float = minimum_progression_dps(index)
    return spawn_tail + total_health / maxf(1.0, guaranteed_dps)


static func maximum_projected_wave_seconds() -> float:
    var worst: float = 0.0
    for index: int in range(WAVE_TABLE.size()):
        worst = maxf(worst, projected_wave_clear_seconds(index))
    return worst


static func fury_multiplier(elapsed_seconds: float) -> float:
    if elapsed_seconds < 20.0:
        return 1.0
    var steps: int = 1 + int(floor((elapsed_seconds - 20.0) / 5.0))
    return 1.0 + minf(1.2, float(steps) * 0.12)


static func rescue_active(seconds_since_last_kill: float) -> bool:
    return seconds_since_last_kill >= 12.0