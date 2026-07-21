extends "res://scripts/greed/survivor_game.gd"

const TILE_SIZE: int = 32
const DECOR_POINTS: Array[Vector2] = [
    Vector2(58.0, 78.0), Vector2(124.0, 292.0), Vector2(186.0, 94.0),
    Vector2(226.0, 274.0), Vector2(294.0, 116.0), Vector2(348.0, 294.0),
    Vector2(414.0, 86.0), Vector2(472.0, 276.0), Vector2(542.0, 106.0),
    Vector2(576.0, 244.0), Vector2(92.0, 196.0), Vector2(516.0, 188.0),
]

var experience_bar: ProgressBar
var pixel_skin: PixelSkinController


func _ready() -> void:
    super._ready()
    pixel_skin = PixelSkinController.new()
    pixel_skin.name = "PixelSkinController"
    add_child(pixel_skin)
    if impact_system != null:
        impact_system.z_index = 9
    queue_redraw()
    _refresh_hud()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("07110d"))
    draw_rect(ARENA_RECT.grow(6.0), Color("0b1712"))
    for x_value: int in range(int(ARENA_RECT.position.x), int(ARENA_RECT.end.x), TILE_SIZE):
        for y_value: int in range(int(ARENA_RECT.position.y), int(ARENA_RECT.end.y), TILE_SIZE):
            var tile_rect: Rect2 = Rect2(float(x_value), float(y_value), float(TILE_SIZE), float(TILE_SIZE))
            var grid_sum: int = int(x_value / TILE_SIZE) + int(y_value / TILE_SIZE)
            var tile_modulate: Color = Color.WHITE if grid_sum % 2 == 0 else Color(0.90, 0.96, 0.90, 1.0)
            draw_texture_rect(PixelArtAssets.GRASS_TILE, tile_rect, false, tile_modulate)
    draw_rect(ARENA_RECT, Color("193820"), false, 5.0)
    draw_rect(ARENA_RECT.grow(-3.0), Color("d8b23f"), false, 2.0)

    for index: int in range(DECOR_POINTS.size()):
        var point: Vector2 = DECOR_POINTS[index]
        var flower_color: Color
        match index % 3:
            0:
                flower_color = Color("d34b78")
            1:
                flower_color = Color("4fd4e8")
            _:
                flower_color = Color("d9ef4a")
        draw_rect(Rect2(point - Vector2.ONE, Vector2(3.0, 3.0)), flower_color)
        draw_rect(Rect2(point + Vector2(1.0, 3.0), Vector2(2.0, 3.0)), Color("2f6f3e"))

    draw_rect(Rect2(0.0, 0.0, VIEW_SIZE.x, 42.0), Color(0.01, 0.03, 0.02, 0.80))
    draw_rect(Rect2(0.0, 328.0, VIEW_SIZE.x, 32.0), Color(0.01, 0.03, 0.02, 0.88))


func _create_ui() -> void:
    super._create_ui()
    var canvas: CanvasLayer = get_node("UI") as CanvasLayer

    var top_frame: NinePatchRect = _make_pixel_frame(canvas, Vector2(4.0, 3.0), Vector2(484.0, 34.0))
    top_frame.name = "PixelTopFrame"
    canvas.move_child(top_frame, 0)

    var bottom_frame: NinePatchRect = _make_pixel_frame(canvas, Vector2(10.0, 332.0), Vector2(620.0, 24.0))
    bottom_frame.name = "PixelExperienceFrame"
    canvas.move_child(bottom_frame, 1)

    _make_pixel_icon(canvas, PixelArtAssets.texture(&"icon_heart"), Vector2(10.0, 8.0))
    _make_pixel_icon(canvas, PixelArtAssets.texture(&"icon_leaf"), Vector2(132.0, 8.0))
    _make_pixel_icon(canvas, PixelArtAssets.texture(&"icon_skull"), Vector2(352.0, 8.0))

    health_label.position = Vector2(38.0, 8.0)
    health_label.size = Vector2(92.0, 24.0)
    greed_label.position = Vector2(160.0, 8.0)
    greed_label.size = Vector2(82.0, 24.0)
    wave_label.position = Vector2(242.0, 7.0)
    wave_label.size = Vector2(108.0, 26.0)
    wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    coins_label.position = Vector2(380.0, 8.0)
    coins_label.size = Vector2(104.0, 24.0)

    status_label.position = Vector2(92.0, 307.0)
    status_label.size = Vector2(456.0, 20.0)
    control_label.position = Vector2(166.0, 44.0)
    control_label.size = Vector2(328.0, 58.0)

    experience_bar = ProgressBar.new()
    experience_bar.name = "ExperienceBar"
    experience_bar.position = Vector2(22.0, 339.0)
    experience_bar.size = Vector2(596.0, 10.0)
    experience_bar.min_value = 0.0
    experience_bar.max_value = float(experience_to_next)
    experience_bar.value = float(experience)
    experience_bar.show_percentage = false
    experience_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var bar_background: StyleBoxFlat = StyleBoxFlat.new()
    bar_background.bg_color = Color("0b1712")
    bar_background.border_color = Color("5b4027")
    bar_background.set_border_width_all(1)
    var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
    bar_fill.bg_color = Color("8fcf3d")
    bar_fill.border_color = Color("d9ef4a")
    bar_fill.set_border_width_all(1)
    experience_bar.add_theme_stylebox_override("background", bar_background)
    experience_bar.add_theme_stylebox_override("fill", bar_fill)
    canvas.add_child(experience_bar)

    var choice_style: StyleBoxFlat = StyleBoxFlat.new()
    choice_style.bg_color = Color(0.035, 0.070, 0.045, 0.985)
    choice_style.border_color = Color("d8b23f")
    choice_style.set_border_width_all(3)
    choice_panel.add_theme_stylebox_override("panel", choice_style)

    for button: Button in choice_buttons:
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        var normal_style: StyleBoxFlat = StyleBoxFlat.new()
        normal_style.bg_color = Color("101b13")
        normal_style.border_color = Color("5b4027")
        normal_style.set_border_width_all(2)
        var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
        hover_style.bg_color = Color("193820")
        hover_style.border_color = Color("d8b23f")
        button.add_theme_stylebox_override("normal", normal_style)
        button.add_theme_stylebox_override("hover", hover_style)
        button.add_theme_stylebox_override("focus", hover_style)

    _refresh_hud()


func _make_pixel_frame(parent: Node, position_value: Vector2, size_value: Vector2) -> NinePatchRect:
    var frame: NinePatchRect = NinePatchRect.new()
    frame.position = position_value
    frame.size = size_value
    frame.texture = PixelArtAssets.UI_PANEL
    frame.patch_margin_left = 8
    frame.patch_margin_top = 8
    frame.patch_margin_right = 8
    frame.patch_margin_bottom = 8
    frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(frame)
    return frame


func _make_pixel_icon(parent: Node, texture_value: Texture2D, position_value: Vector2) -> TextureRect:
    var icon: TextureRect = TextureRect.new()
    icon.texture = texture_value
    icon.position = position_value
    icon.size = Vector2(24.0, 24.0)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(icon)
    return icon


func _open_surprise_choice() -> void:
    super._open_surprise_choice()
    for index: int in range(choice_buttons.size()):
        if index >= _current_choices.size():
            continue
        var data: BlessingData = _current_choices[index]
        choice_buttons[index].icon = PixelArtAssets.blessing_icon(data.id)


func _refresh_hud() -> void:
    super._refresh_hud()
    if wave_label == null or hero_plant == null:
        return
    var shown_time: int = mini(int(floor(survival_elapsed)), int(SURVIVAL_DURATION))
    wave_label.text = "%02d:%02d" % [int(shown_time / 60), shown_time % 60]
    health_label.text = "%d/%d" % [hero_plant.health, hero_plant.max_health]
    coins_label.text = "%d" % enemies_defeated
    greed_label.text = "LV.%d" % hero_plant.level
    if experience_bar != null:
        experience_bar.max_value = float(maxi(1, experience_to_next))
        experience_bar.value = float(experience)
        experience_bar.tooltip_text = _t(
            "Experience %d / %d" % [experience, experience_to_next],
            "经验 %d / %d" % [experience, experience_to_next]
        )
