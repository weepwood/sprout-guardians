extends Resource
class_name BlessingData

enum Rarity {
    COMMON,
    RARE,
    EPIC,
    LEGENDARY,
}

enum EffectType {
    DAMAGE,
    ATTACK_SPEED,
    RANGE,
    REWARD,
    POISON,
    SLOW,
    CRITICAL,
    SUNLIGHT,
}

@export var id: StringName = &"blessing"
@export var rarity: Rarity = Rarity.COMMON
@export var effect_type: EffectType = EffectType.DAMAGE
@export var name_en: String = "Blessing"
@export var name_zh: String = "祝福"
@export_multiline var description_en: String = ""
@export_multiline var description_zh: String = ""
@export var value_per_stack: float = 0.10
@export_range(1, 99, 1) var max_stacks: int = 5
@export_range(0.01, 100.0, 0.01) var base_weight: float = 1.0


func localized_name(locale_code: String) -> String:
    return name_zh if locale_code.to_lower().begins_with("zh") else name_en


func localized_description(locale_code: String, next_stack: int = 1) -> String:
    var template: String = description_zh if locale_code.to_lower().begins_with("zh") else description_en
    if template.contains("%"):
        return template % [value_per_stack * 100.0, next_stack]
    return template


func rarity_name(locale_code: String) -> String:
    var chinese: bool = locale_code.to_lower().begins_with("zh")
    match rarity:
        Rarity.RARE:
            return "稀有" if chinese else "Rare"
        Rarity.EPIC:
            return "史诗" if chinese else "Epic"
        Rarity.LEGENDARY:
            return "传说" if chinese else "Legendary"
        _:
            return "普通" if chinese else "Common"


func rarity_color() -> Color:
    match rarity:
        Rarity.RARE:
            return Color("66b7ff")
        Rarity.EPIC:
            return Color("c784ff")
        Rarity.LEGENDARY:
            return Color("ffd45e")
        _:
            return Color("b9d79b")