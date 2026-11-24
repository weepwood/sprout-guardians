extends RefCounted
class_name SurvivorMapEvents

enum Kind { CHEST, HEAL, MAGNET, CHALLENGE }
const TIMES: Array[float] = [16.0, 34.0, 52.0, 68.0]
const CHALLENGE_SECONDS: float = 12.0
const CHALLENGE_KILLS: int = 10
var next_index: int = 0
var completed: int = 0
var challenge_deadline: float = -1.0
var challenge_start_kills: int = 0

func due(elapsed: float) -> int:
    if next_index >= TIMES.size() or elapsed < TIMES[next_index]:
        return -1
    var kind: int = next_index
    next_index += 1
    return kind

func start_challenge(elapsed: float, kills: int) -> void:
    challenge_deadline = elapsed + CHALLENGE_SECONDS
    challenge_start_kills = kills

# 0 pending, 1 victory, -1 timeout. Terminal results are consumed once.
func challenge_result(elapsed: float, kills: int) -> int:
    if challenge_deadline < 0.0:
        return 0
    if elapsed > challenge_deadline:
        challenge_deadline = -1.0
        return -1
    if kills - challenge_start_kills >= CHALLENGE_KILLS:
        challenge_deadline = -1.0
        completed += 1
        return 1
    return 0
