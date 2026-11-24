extends RefCounted
class_name SurvivorSpawnDirector

var difficulty: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func configure(value: int, run_seed: int) -> void:
    difficulty = clampi(value, 0, 2)
    rng.seed = run_seed

func next_enemy(elapsed: float, elite: bool, boss: bool) -> Dictionary:
    var variant: int = 0
    if elapsed >= 15.0 and not elite and not boss:
        var roll: float = rng.randf()
        if roll < 0.22:
            variant = 1
        elif elapsed >= 35.0 and roll > 0.78:
            variant = 2
    return SurvivorBalance.enemy_config(elapsed, difficulty, elite, boss, variant)
