extends RefCounted
class_name SurvivorArsenal

const IDS: Array[StringName] = [&"mutation_seed", &"mutation_spore", &"mutation_frost", &"mutation_sun", &"mutation_thorn", &"mutation_symbiosis"]
const NAMES_EN: Array[String] = ["Seed Volley", "Spore Burst", "Frost Petals", "Sun Pulse", "Thorn Ring", "Symbiotic Swarm"]
const NAMES_ZH: Array[String] = ["种子齐射", "孢子爆发", "霜瓣", "日光脉冲", "荆棘环", "共生蜂群"]
const DESC_EN: Array[String] = ["Extra seed shots", "Area burst", "Slowing petals", "Periodic healing and light", "Close-range area strike", "Multi-target familiar shots"]
const DESC_ZH: Array[String] = ["额外种子弹", "范围爆发", "减速花瓣", "周期治疗与光弹", "近身范围打击", "多目标协同弹"]
const COLORS: Array[Color] = [Color("a9e66d"), Color("c98de0"), Color("91dafa"), Color("ffcf69"), Color("83bc75"), Color("f0a5b0")]
const EVOLUTION_PARTNERS: Array[int] = [2, 4, 0, 5, 1, 3]
var timers: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

static func reward_pool() -> Array[BlessingData]:
    var result: Array[BlessingData] = []
    for i: int in range(IDS.size()):
        var data: BlessingData = BlessingData.new()
        data.id = IDS[i]
        data.name_en = NAMES_EN[i]
        data.name_zh = NAMES_ZH[i]
        data.description_en = DESC_EN[i]
        data.description_zh = DESC_ZH[i]
        data.rarity = BlessingData.Rarity.RARE
        data.effect_type = BlessingData.EffectType.DAMAGE
        data.value_per_stack = 0.0
        data.max_stacks = 3
        data.base_weight = 2.8
        result.append(data)
    return result

static func evolved(blessings: BlessingSystem, index: int) -> bool:
    return blessings.get_blessing_stack(IDS[index]) >= 3 and blessings.get_blessing_stack(IDS[EVOLUTION_PARTNERS[index]]) >= 1

func tick(delta: float, hero: GreedHeroPlant, blessings: BlessingSystem, fire: Callable) -> void:
    if not is_instance_valid(hero) or blessings == null:
        return
    for i: int in range(IDS.size()):
        var rank: int = blessings.get_blessing_stack(IDS[i])
        if rank <= 0:
            continue
        timers[i] -= delta
        if timers[i] > 0.0:
            continue
        var evolution: bool = evolved(blessings, i)
        var radius: float = 76.0 if i == 4 else 250.0
        var targets: Array[GreedEnemy] = []
        for node: Node in GreedEnemySpatialIndex.combat_candidates(hero.get_tree(), hero.global_position, radius):
            var enemy: GreedEnemy = node as GreedEnemy
            if is_instance_valid(enemy) and enemy.health > 0.0 and hero.global_position.distance_squared_to(enemy.global_position) <= radius * radius:
                targets.append(enemy)
        if i == 3 and hero.health < hero.max_health:
            hero.health = mini(hero.max_health, hero.health + (2 if evolution else 1))
            hero.health_changed.emit(hero.health, hero.max_health)
        if targets.is_empty():
            timers[i] = 0.4 if i != 3 else 7.0
            continue
        targets.sort_custom(func(a: GreedEnemy, b: GreedEnemy) -> bool: return hero.global_position.distance_squared_to(a.global_position) < hero.global_position.distance_squared_to(b.global_position))
        var count: int = (2 + rank + int(evolution)) if i == 0 or i == 5 else 1
        var splash: float = (35.0 + rank * 6.0) if i == 1 or i == 4 else 0.0
        var slow: float = 0.38 if i == 2 or (i == 0 and evolution) else 0.0
        if evolution and i == 1:
            splash += 22.0
        if evolution and i == 2:
            splash = 32.0
        if evolution and i == 4:
            splash += 20.0
            slow = 0.25
        if evolution and i == 3:
            splash = 44.0
        var damage: float = (8.0 + rank * 5.0) * (1.45 if evolution else 1.0)
        for shot: int in range(mini(count, targets.size())):
            fire.call(hero.global_position, targets[shot], damage, false, 400.0, splash, slow, 38.0, COLORS[i])
        timers[i] = (7.0 if i == 3 else 1.8) * (0.8 if evolution else 1.0)
