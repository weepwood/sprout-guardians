extends RefCounted
class_name SurvivorBiomeBoss

# Classic remains the unchanged calibration baseline.
const PROFILES: Array[Dictionary] = [
    {"hp": 1.0, "speed": 1.0, "radius": 43.0, "warning": 0.9, "cooldown": 4.2, "phase_cooldown": 2.8, "summon_threshold": 0.5},
    {"hp": 1.18, "speed": 0.85, "radius": 54.0, "warning": 1.15, "cooldown": 4.4, "phase_cooldown": 3.0, "summon_threshold": 0.65},
    {"hp": 0.95, "speed": 1.25, "radius": 35.0, "warning": 0.75, "cooldown": 3.4, "phase_cooldown": 2.3, "summon_threshold": 0.5},
    {"hp": 0.88, "speed": 0.95, "radius": 47.0, "warning": 1.2, "cooldown": 5.0, "phase_cooldown": 3.5, "summon_threshold": 0.4},
]
const EN: Array[String] = ["Bloom Beast", "Ancient Bramble", "Moonshade", "Bog Bloom"]
const ZH: Array[String] = ["黑花首领", "远古荆棘", "月影花王", "沼泽花兽"]

static func profile(map_id: int) -> Dictionary:
    return PROFILES[clampi(map_id, 0, 3)].duplicate()

static func apply(config: Dictionary, map_id: int) -> Dictionary:
    var result: Dictionary = config.duplicate(true)
    var stats: Dictionary = profile(map_id)
    result["health"] = float(result["health"]) * float(stats["hp"])
    result["speed"] = float(result["speed"]) * float(stats["speed"])
    result["boss_profile"] = map_id
    return result
