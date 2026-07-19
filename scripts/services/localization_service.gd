extends RefCounted
class_name LocalizationService

signal locale_changed(locale_code: String)

const SETTINGS_PATH: String = "user://settings.cfg"
const DEFAULT_LOCALE: String = "en"
const CHINESE_LOCALE: String = "zh_CN"

const TEXT: Dictionary = {
    "language.en": {"en": "English", "zh_CN": "英文"},
    "language.zh_CN": {"en": "Chinese", "zh_CN": "中文"},
    "ui.start_wave": {"en": "Start Wave", "zh_CN": "开始波次"},
    "ui.next_wave": {"en": "Next Wave", "zh_CN": "下一波"},
    "ui.pause": {"en": "Pause", "zh_CN": "暂停"},
    "ui.resume": {"en": "Resume", "zh_CN": "继续"},
    "ui.upgrade": {"en": "Upgrade", "zh_CN": "升级"},
    "ui.upgrade_cost": {"en": "Upgrade %d", "zh_CN": "升级 %d"},
    "ui.sell": {"en": "Sell", "zh_CN": "出售"},
    "ui.sell_value": {"en": "Sell %d", "zh_CN": "出售 %d"},
    "ui.max": {"en": "MAX", "zh_CN": "已满级"},
    "ui.restart": {"en": "Restart", "zh_CN": "重新开始"},
    "ui.skip": {"en": "Skip", "zh_CN": "跳过"},
    "ui.unavailable": {"en": "Unavailable", "zh_CN": "不可用"},
    "ui.no_tower_selected": {"en": "No tower selected", "zh_CN": "未选择防御塔"},
    "ui.disabled": {"en": " DISABLED", "zh_CN": " 已禁用"},
    "ui.sunlight": {"en": "Sunlight: %d", "zh_CN": "阳光：%d"},
    "ui.sprout": {"en": "Sprout: %d", "zh_CN": "幼苗：%d"},
    "ui.wave": {"en": "Wave: %d/%d", "zh_CN": "波次：%d/%d"},
    "ui.language_tooltip": {"en": "Switch language", "zh_CN": "切换语言"},
    "ui.language_target_en": {"en": "EN", "zh_CN": "EN"},
    "ui.language_target_zh": {"en": "中文", "zh_CN": "中文"},
    "hint.choose_tower": {"en": "Choose a tower, then click a green build slot. F3: debug.", "zh_CN": "选择一种防御塔，然后点击绿色建造位。F3：调试信息。"},
    "hint.tower_selected": {"en": "%s selected: %s", "zh_CN": "已选择%s：%s"},
    "hint.no_tower_data": {"en": "No tower data is configured for this build option.", "zh_CN": "当前建造选项没有配置防御塔数据。"},
    "hint.tower_planted": {"en": "%s planted. Select it to upgrade or sell.", "zh_CN": "已种下%s。选中后可以升级或出售。"},
    "hint.tower_upgraded": {"en": "Tower upgraded to level %d.", "zh_CN": "防御塔已升级到 %d 级。"},
    "hint.tower_sold": {"en": "Tower sold. The build slot is available again.", "zh_CN": "防御塔已出售，建造位重新可用。"},
    "hint.not_enough_upgrade": {"en": "Not enough sunlight for this upgrade.", "zh_CN": "阳光不足，无法升级。"},
    "hint.not_enough": {"en": "Not enough sunlight. Defeat enemies to earn more.", "zh_CN": "阳光不足。击败敌人可以获得更多阳光。"},
    "hint.wave_incoming": {"en": "Wave %d incoming!", "zh_CN": "第 %d 波即将来袭！"},
    "hint.wave_cleared": {"en": "Wave cleared. Review the next-wave preview and adjust your garden.", "zh_CN": "本波已清除。查看下一波预览并调整防线。"},
    "hint.golem_phase": {"en": "Forest Golem phase %d: faster, tougher, and disrupting nearby towers.", "zh_CN": "森林魔像进入第 %d 阶段：移动更快、防御更高，并会干扰附近防御塔。"},
    "preview.final_active": {"en": "FINAL WAVE ACTIVE", "zh_CN": "最终波进行中"},
    "preview.defeat_remaining": {"en": "Defeat every remaining enemy.", "zh_CN": "击败所有剩余敌人。"},
    "preview.unavailable": {"en": "Next wave unavailable", "zh_CN": "下一波不可用"},
    "preview.title": {"en": "NEXT %d/%d · %s", "zh_CN": "下一波 %d/%d · %s"},
    "feedback.planted": {"en": "%s planted", "zh_CN": "已种下%s"},
    "feedback.level": {"en": "LEVEL %d", "zh_CN": "%d 级"},
    "feedback.sold": {"en": "Tower sold", "zh_CN": "防御塔已出售"},
    "feedback.sprout_damage": {"en": "Sprout -%d", "zh_CN": "幼苗 -%d"},
    "feedback.golem_phase": {"en": "GOLEM PHASE %d · %d TOWERS DISRUPTED", "zh_CN": "魔像第 %d 阶段 · %d 座塔受干扰"},
    "feedback.wave": {"en": "WAVE %d", "zh_CN": "第 %d 波"},
    "feedback.wave_clear": {"en": "WAVE CLEAR +%d", "zh_CN": "波次清除 +%d"},
    "feedback.not_enough": {"en": "NOT ENOUGH SUNLIGHT", "zh_CN": "阳光不足"},
    "feedback.tutorial_complete": {"en": "TUTORIAL COMPLETE", "zh_CN": "新手引导完成"},
    "result.victory": {"en": "VICTORY\nThe sprout is safe!", "zh_CN": "胜利\n幼苗安全了！"},
    "result.defeat": {"en": "DEFEAT\nThe mist reached the sprout.", "zh_CN": "失败\n迷雾侵袭了幼苗。"},
    "tutorial.1": {"en": "1/4 Choose Pea, Mushroom, or Ice from the build bar.", "zh_CN": "1/4 从建造栏选择豌豆塔、蘑菇灯或冰晶莲。"},
    "tutorial.2": {"en": "2/4 Click a glowing green build slot to plant the selected tower.", "zh_CN": "2/4 点击发光的绿色建造位，种下所选防御塔。"},
    "tutorial.3": {"en": "3/4 Press Start Wave. Review the next-wave panel before each battle.", "zh_CN": "3/4 点击开始波次。每次战斗前请查看下一波预览。"},
    "tutorial.4": {"en": "4/4 Select a tower and upgrade it when you have enough sunlight.", "zh_CN": "4/4 选中防御塔，并在阳光充足时进行升级。"},
    "tower.pea_tower.name": {"en": "Pea Tower", "zh_CN": "豌豆塔"},
    "tower.pea_tower.short": {"en": "Pea", "zh_CN": "豌豆"},
    "tower.pea_tower.description": {"en": "Reliable single-target damage that prioritizes enemies closest to the sprout.", "zh_CN": "稳定的单体输出，优先攻击最接近幼苗的敌人。"},
    "tower.mushroom_lamp.name": {"en": "Mushroom Lamp", "zh_CN": "蘑菇灯"},
    "tower.mushroom_lamp.short": {"en": "Mushroom", "zh_CN": "蘑菇"},
    "tower.mushroom_lamp.description": {"en": "Launches toxic spores that damage groups and stack poison over time.", "zh_CN": "发射有毒孢子，对群体造成伤害并叠加持续中毒。"},
    "tower.ice_flower.name": {"en": "Ice Flower", "zh_CN": "冰晶莲"},
    "tower.ice_flower.short": {"en": "Ice", "zh_CN": "冰晶"},
    "tower.ice_flower.description": {"en": "Slows priority targets with crystal shards, buying time for damage towers.", "zh_CN": "用冰晶碎片减速重点目标，为输出防御塔争取时间。"},
    "enemy.beetle.name": {"en": "Beetle", "zh_CN": "甲虫"},
    "enemy.jump_mushroom.name": {"en": "Jump Mushroom", "zh_CN": "跳跳菇"},
    "enemy.corrupted_slime.name": {"en": "Corrupted Slime", "zh_CN": "腐化史莱姆"},
    "enemy.stone_beast.name": {"en": "Stone Beast", "zh_CN": "岩石兽"},
    "enemy.forest_golem.name": {"en": "Forest Golem", "zh_CN": "森林魔像"},
    "wave.wave_01.name": {"en": "First Footsteps", "zh_CN": "初次脚步"},
    "wave.wave_02.name": {"en": "Jumping Trouble", "zh_CN": "跳跃危机"},
    "wave.wave_03.name": {"en": "Purple Tide", "zh_CN": "紫色浪潮"},
    "wave.wave_04.name": {"en": "Stonewall", "zh_CN": "岩石壁垒"},
    "wave.wave_05.name": {"en": "Fast and Sticky", "zh_CN": "迅捷与黏液"},
    "wave.wave_06.name": {"en": "Armored Column", "zh_CN": "装甲纵队"},
    "wave.wave_07.name": {"en": "Forest Convergence", "zh_CN": "森林合流"},
    "wave.wave_08.name": {"en": "Mist Swarm", "zh_CN": "迷雾虫群"},
    "wave.wave_09.name": {"en": "Last Defense", "zh_CN": "最后防线"},
    "wave.wave_10.name": {"en": "Heart of the Mist", "zh_CN": "迷雾之心"},
    "wave.wave_01.hint": {"en": "Pea Towers handle basic enemies efficiently.", "zh_CN": "豌豆塔可以高效处理基础敌人。"},
    "wave.wave_02.hint": {"en": "Fast enemies reward early placement near the first corner.", "zh_CN": "高速敌人适合在第一个拐角附近提前布防。"},
    "wave.wave_03.hint": {"en": "Mushroom splash and poison work well against grouped slimes.", "zh_CN": "蘑菇灯的范围伤害和中毒适合对付成群史莱姆。"},
    "wave.wave_04.hint": {"en": "Stone Beasts have armor. Upgrade damage or use poison.", "zh_CN": "岩石兽拥有护甲。请提升单次伤害或使用中毒。"},
    "wave.wave_05.hint": {"en": "Combine Ice Flowers with damage towers to control mixed pressure.", "zh_CN": "使用冰晶莲配合输出塔，控制混合敌群。"},
    "wave.wave_06.hint": {"en": "Armored enemies need concentrated fire and upgraded towers.", "zh_CN": "装甲敌人需要集中火力和升级后的防御塔。"},
    "wave.wave_07.hint": {"en": "Balance single-target damage, splash, and slowing control.", "zh_CN": "平衡单体输出、范围伤害和减速控制。"},
    "wave.wave_08.hint": {"en": "Dense formations are ideal targets for Mushroom Lamps.", "zh_CN": "密集编队是蘑菇灯最理想的目标。"},
    "wave.wave_09.hint": {"en": "Prepare upgrades and keep control coverage near the final bends.", "zh_CN": "准备升级，并确保最后几个弯道有减速覆盖。"},
    "wave.wave_10.hint": {"en": "The Forest Golem changes phases and disrupts nearby towers.", "zh_CN": "森林魔像会切换阶段并干扰附近防御塔。"},
}

var locale_code: String = DEFAULT_LOCALE


func load_preference() -> void:
    var detected: String = _detect_locale()
    var config: ConfigFile = ConfigFile.new()
    var error: Error = config.load(SETTINGS_PATH)
    if error == OK:
        detected = String(config.get_value("general", "locale", detected))
    set_locale(detected, false)


func set_locale(value: String, persist: bool = true) -> void:
    var normalized: String = _normalize_locale(value)
    if locale_code == normalized:
        if persist:
            _save_preference()
        return
    locale_code = normalized
    if persist:
        _save_preference()
    locale_changed.emit(locale_code)


func toggle_locale() -> void:
    set_locale(CHINESE_LOCALE if locale_code == DEFAULT_LOCALE else DEFAULT_LOCALE)


func text(key: String, values: Array = []) -> String:
    var localized: Dictionary = TEXT.get(key, {}) as Dictionary
    var result: String = String(localized.get(locale_code, localized.get(DEFAULT_LOCALE, key)))
    if values.is_empty():
        return result
    return result % values


func tower_name(data: TowerData) -> String:
    if data == null:
        return text("ui.unavailable")
    return text("tower.%s.name" % String(data.id))


func tower_short_name(data: TowerData) -> String:
    if data == null:
        return text("ui.unavailable")
    return text("tower.%s.short" % String(data.id))


func tower_description(data: TowerData) -> String:
    if data == null:
        return ""
    return text("tower.%s.description" % String(data.id))


func enemy_name(data: EnemyData) -> String:
    if data == null:
        return text("ui.unavailable")
    return text("enemy.%s.name" % String(data.id))


func wave_name(data: WaveData) -> String:
    if data == null:
        return text("preview.unavailable")
    return text("wave.%s.name" % String(data.id))


func wave_hint(data: WaveData) -> String:
    if data == null:
        return ""
    return text("wave.%s.hint" % String(data.id))


func wave_preview(data: WaveData) -> String:
    if data == null:
        return ""
    var counts: Dictionary = {}
    var order: Array[StringName] = []
    var enemy_data_by_id: Dictionary = {}
    for group: SpawnGroupData in data.get_spawn_groups():
        if group == null or group.enemy == null:
            continue
        var enemy_id: StringName = group.enemy.id
        if not counts.has(enemy_id):
            counts[enemy_id] = 0
            order.append(enemy_id)
            enemy_data_by_id[enemy_id] = group.enemy
        counts[enemy_id] = int(counts[enemy_id]) + group.count

    var parts: PackedStringArray = PackedStringArray()
    for enemy_id: StringName in order:
        var enemy_data: EnemyData = enemy_data_by_id[enemy_id] as EnemyData
        parts.append("%s x%d" % [enemy_name(enemy_data), int(counts[enemy_id])])
    return " · ".join(parts)


func _detect_locale() -> String:
    var language: String = OS.get_locale_language().to_lower()
    return CHINESE_LOCALE if language.begins_with("zh") else DEFAULT_LOCALE


func _normalize_locale(value: String) -> String:
    var normalized: String = value.strip_edges()
    if normalized.to_lower().begins_with("zh"):
        return CHINESE_LOCALE
    return DEFAULT_LOCALE


func _save_preference() -> void:
    var config: ConfigFile = ConfigFile.new()
    config.load(SETTINGS_PATH)
    config.set_value("general", "locale", locale_code)
    var error: Error = config.save(SETTINGS_PATH)
    if error != OK:
        push_warning("Unable to save locale preference: %s" % error_string(error))