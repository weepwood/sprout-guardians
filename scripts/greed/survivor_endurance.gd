extends RefCounted
class_name SurvivorEndurance

static var selected: bool = false
const BOSS_PERIOD: float = 90.0

static func stage(elapsed: float) -> int:
    return maxi(0, floori(elapsed / BOSS_PERIOD))

static func enemy_multiplier(elapsed: float) -> float:
    return minf(6.0, 1.0 + 0.22 * stage(elapsed))

static func spawn_interval(elapsed: float, base: float) -> float:
    return maxf(0.12, base / (1.0 + 0.12 * stage(elapsed)))

static func boss_due(elapsed: float, defeated: int) -> bool:
    return elapsed >= BOSS_PERIOD * (defeated + 1)
