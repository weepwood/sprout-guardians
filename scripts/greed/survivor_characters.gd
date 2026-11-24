extends RefCounted
class_name SurvivorCharacters

static var selected: int = 0
const EN: Array[String] = ["Sprout", "Sunflower", "Frostflower", "Symbiotic Sprout"]
const ZH: Array[String] = ["芽芽", "向日葵", "冰晶花", "共生芽"]
const DESCRIPTIONS_EN: Array[String] = ["Balanced seed shots", "Slower, stronger area shots", "Fast slowing shots", "Hybrid shots; first victory unlock"]
const DESCRIPTIONS_ZH: Array[String] = ["均衡种子射击", "较慢的高伤范围攻击", "快速减速攻击", "范围与减速结合；首次胜利解锁"]

static func configuration(index: int) -> Dictionary:
    var safe_index: int = clampi(index, 0, 3)
    var config: Dictionary = GreedBalance.STARTER_PLANTS[0].duplicate(true)
    config["character_index"] = safe_index
    config["name_en"] = EN[safe_index]
    config["name_zh"] = ZH[safe_index]
    config["move_speed"] = 155.0
    config["health_bonus"] = 0
    if safe_index == 1:
        config.merge({"damage": 23.0, "interval": 0.55, "splash_radius": 34.0, "color_hex": "ffce63", "move_speed": 140.0, "health_bonus": 2}, true)
    elif safe_index == 2:
        config.merge({"damage": 13.0, "interval": 0.36, "slow_ratio": 0.4, "color_hex": "80dfff", "move_speed": 170.0, "health_bonus": -1}, true)
    elif safe_index == 3:
        config.merge({"damage": 16.0, "interval": 0.48, "splash_radius": 20.0, "slow_ratio": 0.22, "color_hex": "c9a7ed", "move_speed": 155.0, "health_bonus": 1}, true)
    return config


static func art_index(character_id: int) -> int:
    return 0 if character_id == 3 else clampi(character_id, 0, 2)
