extends SceneTree

# Fixed-size material/layout evidence. Use an isolated user:// namespace when
# running locally; the normal responsive/quality gate remains independent.
const OUT: String = "res://build/fluent"
var failed: bool = false
var captured: int = 0
var drawn: bool = false

func _initialize() -> void:
    call_deferred("_run")

func _on_draw() -> void:
    drawn = true

func _capture(name_value: String) -> void:
    await process_frame
    drawn = false
    RenderingServer.frame_post_draw.connect(_on_draw, CONNECT_ONE_SHOT)
    RenderingServer.force_draw(false)
    var deadline: int = Time.get_ticks_msec() + 5000
    while not drawn and Time.get_ticks_msec() < deadline:
        await process_frame
    if not drawn:
        if RenderingServer.frame_post_draw.is_connected(_on_draw):
            RenderingServer.frame_post_draw.disconnect(_on_draw)
        failed = true
        push_error("Fluent capture did not render: " + name_value)
        return
    var img: Image = root.get_texture().get_image()
    if img == null or img.is_empty() or img.save_png(ProjectSettings.globalize_path(OUT + "/" + name_value + ".png")) != OK:
        failed = true
        push_error("Fluent capture failed: " + name_value)
        return
    captured += 1
    print("FLUENT_CAPTURE ", name_value, " ", img.get_size())

func _run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    var menu: Node = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
    root.add_child(menu)
    await process_frame
    await _capture("01-home")
    menu.call("_show_settings")
    await _capture("02-settings")
    menu.call("_hide_settings")
    menu.call("_show_collection_summary")
    await _capture("03-journal")
    menu.call("_hide_archive")
    menu.call("_show_character_screen")
    await _capture("04-hero")
    menu.queue_free()
    await process_frame
    var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
    game.set("simulation_mode", true)
    game.set("simulation_map", 0)
    game.set("run_seed", 101)
    root.add_child(game)
    game.set_process(false)
    await _capture("05-combat")
    game.call("_toggle_pause")
    if not bool(game.get("pause_open")):
        failed = true
    await _capture("06-pause")
    game.call("_toggle_pause")
    game.call("_on_experience_collected", int(game.get("experience_to_next")))
    if not bool(game.get("choice_open")):
        failed = true
    var locale: LocalizationService = game.get("i18n") as LocalizationService
    locale.set_locale("en", false)
    game.call("_apply_locale")
    await _capture("07-reward-en")
    locale.set_locale("zh_CN", false)
    game.call("_apply_locale")
    await _capture("08-reward-zh")
    game.call("_select_choice", 0)
    game.call("_finish_run", false)
    await _capture("09-result")
    game.queue_free()
    await process_frame
    print("FLUENT_SUMMARY captured=", captured, " failed=", failed)
    quit(0 if captured == 9 and not failed else 1)
