extends RefCounted
class_name SurvivorBalance

const BASE_XP: int = 8
const PROFILES: Array[Vector3] = [
    Vector3(0.60, 0.78, 0.65),
    Vector3(0.90, 0.95, 1.0),
    Vector3(1.3, 1.2, 1.25),
]
static var selected_difficulty: int = 1

static func profile(difficulty: int) -> Vector3:
    return PROFILES[clampi(difficulty, 0, 2)]

static func enemy_config(elapsed: float, difficulty: int, elite: bool, boss: bool, variant: int = 0) -> Dictionary:
    var t: float = clampf(elapsed, 0.0, 90.0)
    var p: Vector3 = profile(difficulty)
    var tier: int = clampi(difficulty, 0, 2)
    var hp: float = 18.0 + t * [0.42, 0.48, 0.60][tier]
    var speed: float = (35.0 + t * 0.22) * [0.85, 0.95, 1.0][tier]
    var damage: int = 1
    if variant == 1 and not elite and not boss:
        hp *= 0.75
        speed *= 1.25
    elif variant == 2 and not elite and not boss:
        hp *= 1.45
        speed *= 0.72
    if not elite and not boss:
        match variant:
            3:
                hp *= 0.85
                speed *= 0.80
            4:
                hp *= 1.1
                speed *= 0.85
            5:
                hp *= 0.36
                speed *= 1.25
    if elite:
        hp = 100.0 if t < 60.0 else 210.0
        speed = 38.0
        damage = 2
    if boss:
        hp = [750.0, 750.0, 850.0][tier]
        speed = 40.0
        damage = 3
    return {"health": hp * p.x, "speed": speed, "damage": maxi(1, roundi(damage * p.z)), "elite": elite or boss, "boss": boss, "variant": variant if not elite and not boss else 0, "survivor_combat": true}

static func spawn_interval(elapsed: float, difficulty: int) -> float:
    var t: float = clampf(elapsed, 0.0, 90.0)
    var respite: float = 0.28 if (t >= 30.0 and t < 36.0) or (t >= 60.0 and t < 66.0) else 0.0
    return (lerpf(0.85, [0.60, 0.50, 0.35][clampi(difficulty, 0, 2)], t / 90.0) + respite) / profile(difficulty).y

static func experience_requirement(level: int, difficulty: int) -> int:
    var increments: int = maxi(0, level - 1)
    match clampi(difficulty, 0, 2):
        0:
            return 5 + increments * 2
        1:
            return 6 + increments * 2
        _:
            return maxi(5, roundi((BASE_XP + increments * 3) * 1.15))

static func enemy_cap(elapsed: float, difficulty: int = 2) -> int:
    var t: float = maxf(0.0, elapsed)
    match clampi(difficulty, 0, 2):
        0:
            return mini(23, 8 + floori(t / 6.0))
        1:
            return mini(32, 10 + floori(t / 5.0))
        _:
            return mini(64, 12 + floori(t / 5.0) * 2)


static func enemy_experience(difficulty: int, elite: bool) -> int:
    return [6, 5, 3][clampi(difficulty, 0, 2)] if elite else (2 if difficulty == 0 else 1)


static func milestone_experience(difficulty: int) -> int:
    return [5, 3, 0][clampi(difficulty, 0, 2)]
