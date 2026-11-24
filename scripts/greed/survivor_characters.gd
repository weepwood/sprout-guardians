extends RefCounted
class_name SurvivorCharacters

static var selected: int = 0
const EN: Array[String] = ["Sprout", "Sunflower", "Frostflower"]
const ZH: Array[String] = ["芽芽", "向日葵", "冰晶花"]
const DESCRIPTIONS_EN: Array[String] = ["Balanced seed shots", "Slower, stronger area shots", "Fast slowing shots"]
const DESCRIPTIONS_ZH: Array[String] = ["均衡种子射击", "较慢的高伤范围攻击", "快速减速攻击"]

static func configuration(index: int) -> Dictionary:
    var safe_index: int = clampi(index, 0, 2)
    var config: Dictionary = GreedBalance.STARTER_PLANTS[0].duplicate(true)
    config["character_index"] = safe_index
    config["name_en"] = EN[safe_index]
    config["name_zh"] = ZH[safe_index]
    if safe_index == 1:
        config.merge({"damage": 23.0, "interval": 0.55, "splash_radius": 28.0, "color_hex": "ffce63"}, true)
    elif safe_index == 2:
        config.merge({"damage": 13.0, "interval": 0.36, "slow_ratio": 0.3, "color_hex": "80dfff"}, true)
    return config
