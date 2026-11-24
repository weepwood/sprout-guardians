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
        elif elapsed >= 45.0 and roll < 0.38:
            variant = 3
        elif elapsed >= 55.0 and roll < 0.50:
            variant = 4
        elif elapsed >= 35.0 and roll > 0.78:
            variant = 2
    return SurvivorBalance.enemy_config(elapsed, difficulty, elite, boss, variant)


static func biome_variant_chance(map_id: int, elapsed: float) -> float:
    # Keep the dangerous swamp ranged density below the other biomes;
    # forest/night get short themed pressure windows after the first elite.
    if map_id == SurvivorMaps.SWAMP:
        return 0.12
    return 0.30 if elapsed >= 40.0 and elapsed < 47.0 else 0.18
