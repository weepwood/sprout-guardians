extends SceneTree

var failures: int = 0
var cases: int = 0
const UI_FONT: FontFile = preload("res://assets/ui/fonts/SproutUISans-Regular.otf")

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)

func _glyphs(value: String) -> void:
    for i: int in range(value.length()):
        var cp: int = value.unicode_at(i)
        if cp >= 32:
            _check(UI_FONT.has_char(cp), "Missing bundled glyph %d in %s" % [cp, value])

func _label(label: Label, box: Rect2) -> void:
    _glyphs(label.text)
    var font: Font = label.get_theme_font("font")
    var size_value: int = label.get_theme_font_size("font_size")
    var lines: PackedStringArray = label.text.split("\n")
    var widest: float = 0.0
    for line: String in lines:
        widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x)
    _check(widest <= label.size.x + 0.5, "Text exceeds width: %s (%f > %f)" % [label.text, widest, label.size.x])
    _check(font.get_height(size_value) * lines.size() <= label.size.y + 0.5, "Text exceeds height: " + label.text)
    _check(box.grow(0.5).encloses(Rect2(label.position, label.size)), "Label outside allocated area: " + label.text)

func _run() -> void:
    for key: String in LocalizationService.TEXT:
        for value: String in (LocalizationService.TEXT[key] as Dictionary).values():
            _glyphs(value)
    var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
    game.set("simulation_mode", true)
    root.add_child(game)
    game.set_process(false)
    await process_frame
    var system: BlessingSystem = game.get("blessing_system") as BlessingSystem
    var locale: LocalizationService = game.get("i18n") as LocalizationService
    var pool: Array[BlessingData] = system.pool.duplicate()
    for data: BlessingData in SurvivorArsenal.reward_pool(true):
        if not pool.any(func(other: BlessingData) -> bool: return other.id == data.id):
            pool.append(data)
    game.set("choice_open", true)
    for language: String in ["en", "zh_CN"]:
        locale.set_locale(language, false)
        for data: BlessingData in pool:
            for rank: int in range(data.max_stacks):
                var index: int = SurvivorArsenal.IDS.find(data.id)
                for partner_rank: int in ([0,1,3] if index >= 0 else [0]):
                    system.stacks.clear()
                    system.stacks[String(data.id)] = rank
                    if index >= 0:
                        system.stacks[String(SurvivorArsenal.IDS[SurvivorArsenal.EVOLUTION_PARTNERS[index]])] = partner_rank
                    var choices: Array[BlessingData] = [data]
                    game.set("_current_choices", choices)
                    game.call("_render_reward_cards")
                    var button: Button = (game.get("choice_buttons") as Array)[0] as Button
                    var previous_end: float = 0.0
                    for name_value: String in ["GiftRarity", "GiftName", "GiftDetail"]:
                        var label: Label = button.get_node(name_value) as Label
                        _label(label, Rect2(Vector2.ZERO, button.size))
                        _check(label.position.y >= previous_end, "Reward labels overlap: " + label.text)
                        previous_end = label.position.y + label.size.y
                    cases += 1
    game.set("choice_open", false)
    system.stacks.clear()
    for id: StringName in SurvivorArsenal.IDS:
        system.stacks[String(id)] = 3
    game.call("_toggle_pause")
    for language: String in ["en", "zh_CN"]:
        locale.set_locale(language, false)
        game.call("_apply_locale")
        await process_frame
        var grid: GridContainer = game.get("pause_weapon_grid") as GridContainer
        _check(grid.get_child_count() == 8, "Full build shows eight weapons")
        for item: Label in grid.get_children():
            _label(item, Rect2(Vector2.ZERO, grid.size))
        _check(grid.position.y + grid.size.y <= (game.get("language_button") as Button).position.y + 0.5, "Pause build overlaps controls")
    game.queue_free()
    await process_frame
    print("TYPOGRAPHY_SUMMARY cases=", cases, " failures=", failures)
    quit(0 if failures == 0 and cases > 100 else 1)
