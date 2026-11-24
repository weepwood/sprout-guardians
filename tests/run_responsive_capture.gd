extends SceneTree

# Real native windows (Linux Xvfb or desktop), no fake concept screenshots.
const OUT: String = "res://build/responsive"
const SIZES: Array[Vector2i] = [Vector2i(960,720), Vector2i(1280,720), Vector2i(1280,800), Vector2i(1260,540)]
var failures: int = 0
var captures: int = 0
var frame_drawn: bool = false

func _initialize() -> void:
    call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
    print("RESPONSIVE ", message, " ", ok)
    if not ok:
        failures += 1
        push_error(message)

func _resize(value: Vector2i) -> void:
    root.size = value
    for i: int in range(12):
        await process_frame
    _expect(root.size == value, "Actual window size %s (got %s)" % [value, root.size])
    var view: Vector2 = root.get_visible_rect().size
    _expect(absf(view.aspect() - Vector2(value).aspect()) < 0.02, "Aspect preserved %s" % view)

func _inside(control: Control, description: String) -> void:
    var box: Rect2 = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
    _expect(root.get_visible_rect().grow(1.0).encloses(box), description + " " + str(box))

func _capture(name_value: String) -> void:
    await process_frame
    frame_drawn = false
    RenderingServer.frame_post_draw.connect(_on_frame_drawn, CONNECT_ONE_SHOT)
    var deadline: int = Time.get_ticks_msec() + 5000
    while not frame_drawn and Time.get_ticks_msec() < deadline:
        await process_frame
    if not frame_drawn:
        if RenderingServer.frame_post_draw.is_connected(_on_frame_drawn):
            RenderingServer.frame_post_draw.disconnect(_on_frame_drawn)
        _expect(false, "Timed out waiting for rendered frame " + name_value)
        return
    var image: Image = root.get_texture().get_image()
    _expect(image != null and not image.is_empty(), "Rendered frame " + name_value)
    if image != null and not image.is_empty():
        _expect(image.save_png(ProjectSettings.globalize_path(OUT + "/" + name_value + ".png")) == OK, "Saved " + name_value)
        captures += 1

func _on_frame_drawn() -> void:
    frame_drawn = true

func _run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    var menu: Node = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
    root.add_child(menu)
    await process_frame
    for value: Vector2i in SIZES:
        await _resize(value)
        _inside(menu.get("play_button") as Control, "Play button")
        var bg: TextureRect = menu.get_node("World/Grass") as TextureRect
        _expect(bg.size.is_equal_approx(root.get_visible_rect().size), "Menu background fills viewport")
        await _capture("menu-%dx%d" % [value.x,value.y])
    # Exercise a continuous sequence rather than just isolated window sizes.
    for i: int in range(12):
        root.size = Vector2i(960 + i * 26, 600 + i * 8)
        await process_frame
        _inside(menu.get("play_button") as Control, "Continuous resize menu action")
    await _resize(SIZES[-1])
    await create_timer(0.65).timeout
    menu.call("_show_settings")
    await process_frame
    _inside(menu.get("settings_panel") as Control, "Display settings panel")
    var prefs: SettingsService = menu.get("settings") as SettingsService
    _expect(prefs.window_size == root.size, "Debounced native resize persisted")
    var reloaded: SettingsService = SettingsService.new()
    reloaded.load_settings()
    _expect(reloaded.window_size == prefs.window_size, "Window size survives reload")
    var music: HSlider = menu.get("music_slider") as HSlider
    music.value = -27
    await create_timer(0.4).timeout
    reloaded.load_settings()
    _expect(is_equal_approx(reloaded.music_volume_db, -27.0), "Audio slider persisted")
    prefs.set_ui_scale(1.25)
    (menu.get("responsive") as ResponsiveUI).refresh()
    _inside(menu.get("settings_panel") as Control, "125 percent requested, safe fit")
    prefs.set_ui_scale(0.8)
    (menu.get("responsive") as ResponsiveUI).refresh()
    _expect(is_equal_approx((menu.get_node("UI") as CanvasLayer).scale.x, 0.8), "80 percent UI scale applied")
    prefs.set_ui_scale(1.0)
    (menu.get("responsive") as ResponsiveUI).refresh()
    await _capture("settings")
    menu.call("_hide_settings")
    menu.call("_show_character_screen")
    await process_frame
    _inside(menu.get("hero_detail_portrait") as Control, "Hero portrait")
    _inside(menu.get("hero_map_picker") as Control, "Character screen map picker")
    _inside(menu.get("hero_difficulty_picker") as Control, "Character screen difficulty picker")
    menu.call("_choose_screen_difficulty", 2)
    _expect(SurvivorBalance.selected_difficulty == 2 and prefs.survivor_difficulty == 2, "Character screen difficulty updates existing preference")
    menu.call("_choose_screen_difficulty", 1)
    await _capture("character-selection")
    menu.queue_free()
    await process_frame
    # Actual viewport in runtime, but simulation prevents game-save writes.
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    for map_id: int in [SurvivorMaps.CLASSIC, SurvivorMaps.EXPLORATION]:
        var game: Node = packed.instantiate()
        game.set("simulation_mode", true)
        game.set("simulation_map", map_id)
        game.set("run_seed", 101)
        root.add_child(game)
        await process_frame
        # Opt into the runtime camera branch without saving run data.
        game.set("simulation_mode", false)
        game.set("run_save", null)
        for value: Vector2i in SIZES:
            await _resize(value)
            _inside(game.get("menu_button") as Control, "Pause control")
            _inside(game.get("experience_bar") as Control, "XP bar")
            var hero: GreedHeroPlant = game.get("hero_plant") as GreedHeroPlant
            _expect(hero.movement_bounds == SurvivorMaps.movement_bounds(map_id), "World movement bounds unchanged")
            var camera_view: Vector2 = game.get("camera_view_size")
            _expect(camera_view.x >= 639.0 and camera_view.y >= 359.0, "Camera sees logical viewport " + str(camera_view))
            if map_id != SurvivorMaps.CLASSIC:
                var camera: Camera2D = game.get("world_camera") as Camera2D
                var area: Rect2 = SurvivorMaps.spawn_area(map_id, camera.get_screen_center_position(), camera_view)
                _expect(area.size.x > 0 and area.size.y > 0 and Rect2(Vector2.ZERO, SurvivorMaps.world_size(map_id)).encloses(area), "Spawn perimeter clipped to map")
            await _capture("combat-%d-%dx%d" % [map_id,value.x,value.y])
        var game_prefs: SettingsService = game.get("settings") as SettingsService
        game_prefs.set_ui_scale(1.25)
        (game.get("responsive") as ResponsiveUI).refresh()
        _expect(is_equal_approx((game.get_node("UI") as CanvasLayer).scale.x, 1.25), "125 percent HUD scale applied")
        _inside(game.get("menu_button") as Control, "Scaled pause button")
        _inside(game.get("experience_bar") as Control, "Scaled XP bar")
        game.call("_toggle_pause")
        await process_frame
        _inside(game.get("pause_panel") as Control, "Pause panel")
        game_prefs.set_ui_scale(1.0)
        (game.get("responsive") as ResponsiveUI).refresh()
        await _capture("pause-%d" % map_id)
        game.call("_toggle_pause")
        game.call("_on_experience_collected", int(game.get("experience_to_next")))
        await process_frame
        var buttons: Array = game.get("choice_buttons")
        _expect(bool(game.get("choice_open")), "Reward opened")
        for button: Button in buttons:
            _inside(button, "Reward card " + String(button.name))
        await _capture("reward-%d" % map_id)
        game.call("_select_choice", 0)
        game.call("_finish_run", false)
        await process_frame
        _inside(game.get("result_button") as Control, "Result button")
        var result_panel: Control = game.get("choice_panel") as Control
        _inside(result_panel, "Result panel")
        await _capture("result-%d" % map_id)
        game.queue_free()
        await process_frame
    print("RESPONSIVE_SUMMARY failures=%d captures=%d" % [failures,captures])
    quit(0 if failures == 0 and captures == 20 else 1)
