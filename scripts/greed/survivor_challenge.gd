extends RefCounted
class_name SurvivorChallenge

static var selected: bool = false
const SEED: int = 20261124

static func date_key() -> String:
    return Time.get_date_string_from_system(true)

static func seed_for(day: String) -> int:
    return maxi(1, int(day.replace("-", "")))
