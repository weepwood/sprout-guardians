extends RefCounted
class_name SurvivorBalance

const BASE_XP: int = 8
const PROFILES: Array[Vector3] = [
    Vector3(0.75, 0.82, 0.8),
    Vector3(1.0, 1.0, 1.0),
    Vector3(1.3, 1.2, 1.25),
]
static var selected_difficulty: int = 1

static func profile(difficulty: int) -> Vector3:
    return PROFILES[clampi(difficulty, 0, 2)]

static func enemy_config(elapsed: float, difficulty: int, elite: bool, boss: bool, variant: int = 0) -> Dictionary:
    var t: float = clampf(elapsed, 0.0, 90.0)
    var p: Vector3 = profile(difficulty)
    var hp: float = 18.0 + t * 0.60
    var speed: float = 35.0 + t * 0.22
    var damage: int = 1
    if variant == 1 and not elite and not boss:
        hp *= 0.75
        speed *= 1.25
    elif variant == 2 and not elite and not boss:
        hp *= 1.45
        speed *= 0.72
    if elite:
        hp = 100.0 if t < 60.0 else 210.0
        speed = 38.0
        damage = 2
    if boss:
        hp = 850.0
        speed = 40.0
        damage = 3
    return {"health": hp * p.x, "speed": speed, "damage": maxi(1, roundi(damage * p.z)), "elite": elite or boss, "boss": boss}

static func spawn_interval(elapsed: float, difficulty: int) -> float:
    var t: float = clampf(elapsed, 0.0, 90.0)
    var respite: float = 0.28 if (t >= 30.0 and t < 36.0) or (t >= 60.0 and t < 66.0) else 0.0
    return (lerpf(0.85, 0.35, t / 90.0) + respite) / profile(difficulty).y

static func experience_requirement(level: int, difficulty: int) -> int:
    return maxi(5, roundi((BASE_XP + maxi(0, level - 1) * 3) * [0.75, 1.0, 1.15][clampi(difficulty, 0, 2)]))

static func enemy_cap(elapsed: float) -> int:
    return mini(64, 12 + floori(maxf(0.0, elapsed) / 5.0) * 2)
