extends RefCounted
class_name SurvivorCharacters

static var selected: int = 0
const EN: Array[String] = ["Sprout", "Sunflower", "Frostflower", "Symbiotic Sprout", "Bramble"]
const ZH: Array[String] = ["芽芽", "向日葵", "冰晶花", "共生芽", "荆棘卫士"]
const DESCRIPTIONS_EN: Array[String] = ["Balanced seed shots", "Slower, stronger area shots", "Fast slowing shots", "Hybrid shots; first victory unlock", "Heavy shots; complete five events"]
const DESCRIPTIONS_ZH: Array[String] = ["均衡种子射击", "较慢的高伤范围攻击", "快速减速攻击", "范围与减速结合；首次胜利解锁", "重型攻击；完成五个事件解锁"]

static func configuration(index: int) -> Dictionary:
    var safe_index: int = clampi(index, 0, 4)
    var config: Dictionary = GreedBalance.STARTER_PLANTS[0].duplicate(true)
    config["character_index"] = safe_index
    config["name_en"] = EN[safe_index]
    config["name_zh"] = ZH[safe_index]
    config["move_speed"] = 155.0
    config["health_bonus"] = 0
    if safe_index == 1:
        config.merge({"damage": 23.0, "interval": 0.55, "splash_radius": 34.0, "color_hex": "ffce63", "move_speed": 140.0, "health_bonus": 2}, true)
    elif safe_index == 2:
        config.merge({"damage": 15.0, "interval": 0.36, "slow_ratio": 0.46, "color_hex": "80dfff", "move_speed": 170.0, "health_bonus": 0}, true)
    elif safe_index == 3:
        config.merge({"damage": 17.0, "interval": 0.46, "splash_radius": 24.0, "slow_ratio": 0.26, "color_hex": "c9a7ed", "move_speed": 155.0, "health_bonus": 1}, true)
    elif safe_index == 4:
        config.merge({"damage": 27.0, "interval": 0.70, "splash_radius": 42.0, "color_hex": "9dbd6a", "move_speed": 135.0, "health_bonus": 3}, true)
    return config


static func art_index(character_id: int) -> int:
    return 0 if character_id >= 3 else clampi(character_id, 0, 2)
