extends RefCounted
class_name PlayfulUITheme

# Original garden-toy visual language: warm surfaces, soft borders and a clear
# keyboard/gamepad focus state. No third-party game UI assets are bundled.
const INK: Color = Color("#433a36")
const MUTED: Color = Color("#826c60")
const CREAM: Color = Color("#fff9ed")
const PAPER: Color = Color("#fff1d9")
const YELLOW: Color = Color("#ffd36d")
const CORAL: Color = Color("#ffa49a")
const MINT: Color = Color("#b8e5b6")
const OUTLINE: Color = Color("#c5a88a")
const FOCUS: Color = Color("#7657ae")


static func surface(color_value: Color = CREAM, radius: int = 16, border: Color = OUTLINE, shadow: int = 3) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = color_value
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(radius)
    style.shadow_color = Color(0.22, 0.15, 0.11, 0.25)
    style.shadow_size = shadow
    style.shadow_offset = Vector2(0.0, 2.0)
    style.content_margin_left = 8.0
    style.content_margin_right = 8.0
    style.content_margin_top = 3.0
    style.content_margin_bottom = 3.0
    return style


static func apply_panel(panel: Panel, kind: String = "paper") -> void:
    var fill: Color = CREAM
    if kind == "hud":
        fill = Color("#fff3da")
    elif kind == "glass":
        var frosted: StyleBoxFlat = surface(Color(0.15, 0.25, 0.20, 0.38), 12, Color(1.0, 1.0, 1.0, 0.26), 2)
        frosted.set_border_width_all(1)
        panel.add_theme_stylebox_override("panel", frosted)
        return
    elif kind == "modal":
        fill = Color("#fff7e8")
    elif kind == "mint":
        fill = MINT
    panel.add_theme_stylebox_override("panel", surface(fill, 17 if kind == "modal" else 14))


static func apply_button(button: Button, kind: String = "soft", animate: bool = true) -> void:
    var normal_color: Color = PAPER
    var hover_color: Color = Color("#fff9ec")
    var down_color: Color = Color("#e7d5b7")
    if kind == "primary":
        normal_color = YELLOW
        hover_color = Color("#ffe18d")
        down_color = Color("#f3b946")
    elif kind == "mint":
        normal_color = MINT
        hover_color = Color("#d3f2cf")
        down_color = Color("#91ce9a")
    elif kind == "coral":
        normal_color = CORAL
        hover_color = Color("#ffc5ba")
        down_color = Color("#eb8881")
    elif kind == "tiny":
        normal_color = Color("#fff7e8")
        hover_color = Color("#ffe5b4")
        down_color = Color("#f5cc88")

    var normal: StyleBoxFlat = surface(normal_color, 13 if kind != "tiny" else 10)
    var hover: StyleBoxFlat = surface(hover_color, 13 if kind != "tiny" else 10, Color("#a68769"), 4)
    var pressed: StyleBoxFlat = surface(down_color, 13 if kind != "tiny" else 10, OUTLINE, 1)
    var focused: StyleBoxFlat = surface(Color(1.0, 1.0, 1.0, 0.0), 13 if kind != "tiny" else 10, FOCUS, 0)
    focused.set_border_width_all(3)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("hover_pressed", pressed)
    button.add_theme_stylebox_override("focus", focused)
    button.add_theme_stylebox_override("disabled", surface(Color("#ddd8c9"), 12, Color("#a69c8d"), 0))
    button.add_theme_color_override("font_disabled_color", Color("#685f55"))
    for state_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        button.add_theme_color_override(state_name, INK)
    button.focus_mode = Control.FOCUS_ALL
    button.pivot_offset = button.size * 0.5
    if animate and not button.has_meta("playful_motion_bound"):
        button.set_meta("playful_motion_bound", true)
        button.mouse_entered.connect(_animate_button.bind(button, true))
        button.mouse_exited.connect(_animate_button.bind(button, false))
        button.focus_entered.connect(_animate_button.bind(button, true))
        button.focus_exited.connect(_animate_button.bind(button, false))


static func apply_label(label: Label, color_value: Color = INK) -> void:
    if color_value in [FLUENT_TEXT, FLUENT_MUTED, FLUENT_ACCENT]:
        label.set_meta("fluent_label", color_value)
        var ink: Color = text_color() if color_value == FLUENT_TEXT else (muted_color() if color_value == FLUENT_MUTED else accent_color())
        label.add_theme_color_override("font_color", ink)
    else:
        if label.has_meta("fluent_label"):
            label.remove_meta("fluent_label")
        label.add_theme_color_override("font_color", color_value)


static func apply_progress(bar: ProgressBar) -> void:
    var backing: StyleBoxFlat = surface(Color("#f5e3ca"), 7, Color("#ccb397"), 0)
    backing.set_border_width_all(1)
    var filling: StyleBoxFlat = surface(Color("#80d1a0"), 7, Color("#4e9e79"), 0)
    filling.set_border_width_all(1)
    bar.add_theme_stylebox_override("background", backing)
    bar.add_theme_stylebox_override("fill", filling)


static func _animate_button(button: Button, active: bool) -> void:
    if not is_instance_valid(button) or not button.is_inside_tree():
        return
    if button.has_meta("fluent_no_scale"):
        return
    var should_raise: bool = active or button.has_focus()
    var tween: Tween = button.create_tween()
    tween.set_trans(Tween.TRANS_BACK)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(button, "scale", Vector2.ONE * (1.035 if should_raise else 1.0), 0.15)


static func apply_tabs(tabs: TabContainer) -> void:
    tabs.add_theme_stylebox_override("tab_selected", surface(MINT, 8, OUTLINE, 0))
    tabs.add_theme_stylebox_override("tab_unselected", surface(PAPER, 8, OUTLINE, 0))
    tabs.add_theme_stylebox_override("tab_hovered", surface(CREAM, 8, OUTLINE, 0))
    tabs.add_theme_stylebox_override("panel", surface(CREAM, 8, OUTLINE, 0))
    tabs.add_theme_color_override("font_selected_color", INK)
    tabs.add_theme_color_override("font_unselected_color", MUTED)
    tabs.add_theme_color_override("font_hovered_color", INK)


# WCAG relative luminance is linear sRGB, not the encoded RGB components.
static func contrast_ratio(foreground: Color, background: Color) -> float:
    var a: float = foreground.srgb_to_linear().get_luminance()
    var b: float = background.srgb_to_linear().get_luminance()
    return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


static func readable_on_light(foreground: Color, background: Color) -> Color:
    var candidate: Color = foreground
    for _i: int in range(12):
        if contrast_ratio(candidate, background) >= 4.5:
            return candidate
        candidate = candidate.darkened(0.12)
    return INK

# Windows Fluent-inspired game chrome. The forest artwork remains the backdrop.
# Keep the existing public helper names for older scenes.
const FLUENT_TEXT: Color = Color("#f4f7fb")
const FLUENT_MUTED: Color = Color("#c5d1df")
const FLUENT_ACCENT: Color = Color("#8ecbff")
const FLUENT_SHADER: Shader = preload("res://assets/ui/glass_frosted.gdshader")

static var light_mode: bool = false
static var glass_level: int = 2
static var reduce_motion: bool = false

static func configure_appearance(light: bool, strength: int, reduced: bool) -> void:
    light_mode = light
    glass_level = clampi(strength, 0, 3)
    reduce_motion = reduced

static func text_color() -> Color:
    return Color("#243548") if light_mode else FLUENT_TEXT

static func muted_color() -> Color:
    return Color("#43576a") if light_mode else FLUENT_MUTED

static func accent_color() -> Color:
    return Color("#235f95") if light_mode else FLUENT_ACCENT

static func tile_color() -> Color:
    return Color("#e5edf5") if light_mode else Color("#303d4b")

static func outline_color() -> Color:
    return Color("#9caec0") if light_mode else Color("#526171")

# Replay only controls using the Fluent helpers; reward surfaces remain light.
static func refresh_tree(node: Node) -> void:
    if node is Panel and node.has_meta("fluent_panel"):
        var config: Array = node.get_meta("fluent_panel")
        apply_acrylic_panel(node as Panel, bool(config[0]), bool(config[1]))
    elif node is OptionButton and node.has_meta("fluent_picker"):
        apply_forest_picker(node as OptionButton)
    elif node is Button and node.has_meta("fluent_button"):
        apply_forest_button(node as Button, bool(node.get_meta("fluent_button")))
    elif node is TabContainer and node.has_meta("fluent_tabs"):
        apply_fluent_tabs(node as TabContainer)
    elif node is HSlider and node.has_meta("fluent_slider"):
        apply_forest_slider(node as HSlider)
    elif node is Label and node.has_meta("fluent_label"):
        apply_label(node as Label, node.get_meta("fluent_label"))
    if node is ScrollContainer:
        for scroll: ScrollBar in [(node as ScrollContainer).get_v_scroll_bar(), (node as ScrollContainer).get_h_scroll_bar()]:
            style_scrollbar(scroll)
    for child: Node in node.get_children():
        refresh_tree(child)

static func style_scrollbar(scroll: ScrollBar) -> void:
    var track: StyleBoxFlat = fluent_surface(Color.TRANSPARENT, 3, Color.TRANSPARENT)
    for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
        track.set_content_margin(side, 2.0)
    track.set_border_width_all(0)
    scroll.add_theme_stylebox_override("scroll", track)
    for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
        var style: StyleBoxFlat = fluent_surface(muted_color() if state == "grabber" else accent_color(), 4, Color.TRANSPARENT)
        style.content_margin_left = 2
        style.content_margin_right = 2
        scroll.add_theme_stylebox_override(state, style)

# Opening transitions never alter layout or input. Kill an earlier tween on
# repeated opens; hidden pages do not receive delayed callbacks.
static func reveal(control: Control) -> void:
    var old: Tween = control.get_meta("fluent_reveal") as Tween if control.has_meta("fluent_reveal") else null
    if old != null and old.is_valid():
        old.kill()
    control.modulate.a = 1.0
    if reduce_motion or DisplayServer.get_name() == "headless":
        return
    control.modulate.a = 0.82
    var tween: Tween = control.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    control.set_meta("fluent_reveal", tween)
    tween.tween_property(control, "modulate:a", 1.0, 0.16)


static func fluent_surface(fill: Color, radius_value: int = 8, outline: Color = Color("#526171"), shadow: int = 0) -> StyleBoxFlat:
    var style: StyleBoxFlat = surface(fill, radius_value, outline, shadow)
    style.set_border_width_all(1)
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
    return style

static func apply_forest_panel(panel: Panel, blur: bool = false) -> void:
    apply_acrylic_panel(panel, false, blur)

static func apply_acrylic_panel(panel: Panel, light: bool = false, blur: bool = true) -> void:
    panel.set_meta("fluent_panel", [light, blur])
    light = light or light_mode
    var glass: ColorRect = panel.get_node_or_null("AcrylicBackdrop") as ColorRect
    var use_blur: bool = blur and glass_level > 0 and DisplayServer.get_name() != "headless"
    if use_blur and glass == null:
        glass = ColorRect.new()
        glass.name = "AcrylicBackdrop"
        glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
        glass.show_behind_parent = true
        panel.add_child(glass)
        glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        var shader_material: ShaderMaterial = ShaderMaterial.new()
        shader_material.shader = FLUENT_SHADER
        glass.material = shader_material
        panel.resized.connect(_resize_acrylic.bind(panel, glass))
    if glass != null:
        glass.visible = use_blur
        var shader_material: ShaderMaterial = glass.material as ShaderMaterial
        shader_material.set_shader_parameter("radius", 14.0 if light else 10.0)
        shader_material.set_shader_parameter("blur_lod", [0.0, 2.5, 3.8, 4.8][glass_level])
        shader_material.set_shader_parameter("tint", Color(0.93, 0.95, 0.98, 0.83) if light else Color(0.095, 0.12, 0.16, 0.53))
        shader_material.set_shader_parameter("highlight", 0.045 if light else 0.11)
        _resize_acrylic(panel, glass)
    # Solid fallback in headless / shader-disabled environments. Light text stays
    # readable even when the backdrop is bright; light reward cards remain opaque.
    var base: Color = Color("#f2f5fa") if light else Color("#202a36")
    base.a = (0.42 if light else 0.24) if use_blur else 0.98
    panel.add_theme_stylebox_override("panel", fluent_surface(base, 14 if light else 10, Color("#aebdce") if light else Color(0.70, 0.80, 0.92, 0.34), 3 if blur else 0))

static func _resize_acrylic(panel: Panel, glass: ColorRect) -> void:
    if is_instance_valid(glass) and glass.material is ShaderMaterial:
        (glass.material as ShaderMaterial).set_shader_parameter("panel_size", panel.size.max(Vector2.ONE))

static func apply_forest_button(button: Button, primary: bool = false) -> void:
    button.set_meta("fluent_button", primary)
    button.set_meta("fluent_no_scale", true)
    button.scale = Vector2.ONE
    var normal: Color = FLUENT_ACCENT if primary else tile_color()
    var hover: Color = Color("#b2dcff") if primary else (Color("#d7e6f4") if light_mode else Color("#405365"))
    var down: Color = Color("#6eafdf") if primary else (Color("#c6d9ec") if light_mode else Color("#263442"))
    if button.toggle_mode and not primary:
        down = Color("#c2dcf5") if light_mode else Color("#365c7b")
    var ink: Color = Color("#152333") if primary else text_color()
    var border: Color = outline_color() if not primary else Color("#aedcff")
    button.add_theme_stylebox_override("normal", fluent_surface(normal, 7, border))
    button.add_theme_stylebox_override("hover", fluent_surface(hover, 7, Color("#a5c8e7")))
    button.add_theme_stylebox_override("pressed", fluent_surface(down, 7, accent_color()))
    button.add_theme_stylebox_override("hover_pressed", button.get_theme_stylebox("pressed"))
    button.add_theme_stylebox_override("disabled", fluent_surface(Color("#dce3ea") if light_mode else Color("#27313c"), 7, outline_color()))
    var focus: StyleBoxFlat = fluent_surface(Color.TRANSPARENT, 7, accent_color())
    focus.set_border_width_all(2)
    button.add_theme_stylebox_override("focus", focus)
    for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        button.add_theme_color_override(state, ink)
    button.add_theme_color_override("font_disabled_color", muted_color())
    button.focus_mode = Control.FOCUS_ALL

static func apply_forest_picker(picker: OptionButton) -> void:
    picker.set_meta("fluent_picker", true)
    apply_forest_button(picker)
    picker.fit_to_longest_item = false
    picker.clip_text = true
    picker.add_theme_constant_override("modulate_arrow", 1)
    var popup: PopupMenu = picker.get_popup()
    popup.add_theme_stylebox_override("panel", fluent_surface(tile_color(), 8, outline_color(), 3))
    popup.add_theme_stylebox_override("hover", fluent_surface(Color("#d2e4f6") if light_mode else Color("#40576c"), 5, outline_color()))
    popup.add_theme_color_override("font_color", text_color())
    popup.add_theme_color_override("font_hover_color", text_color())
    popup.add_theme_color_override("font_disabled_color", muted_color())
    popup.add_theme_constant_override("v_separation", 7)

static func apply_fluent_tabs(tabs: TabContainer) -> void:
    tabs.set_meta("fluent_tabs", true)
    tabs.add_theme_stylebox_override("tab_selected", fluent_surface(Color("#cce2f6") if light_mode else Color("#3e566d"), 6, FLUENT_ACCENT))
    tabs.add_theme_stylebox_override("tab_unselected", fluent_surface(Color("#e5edf5") if light_mode else Color("#263542"), 6))
    tabs.add_theme_stylebox_override("tab_hovered", fluent_surface(Color("#d7e6f4") if light_mode else Color("#394c60"), 6))
    tabs.add_theme_stylebox_override("panel", fluent_surface(Color("#eef3f8") if light_mode else Color("#26323f"), 7))
    tabs.add_theme_color_override("font_selected_color", text_color())
    tabs.add_theme_color_override("font_unselected_color", muted_color())
    tabs.add_theme_color_override("font_hovered_color", text_color())

static func apply_light_reward(button: Button, border: Color = Color("#bdcad7")) -> void:
    if button.has_meta("fluent_button"):
        button.remove_meta("fluent_button")
    button.set_meta("fluent_no_scale", true)
    button.add_theme_stylebox_override("normal", fluent_surface(Color("#f8fafd"), 8, border))
    button.add_theme_stylebox_override("hover", fluent_surface(Color("#e8f2ff"), 8, Color("#6d9eca")))
    button.add_theme_stylebox_override("pressed", fluent_surface(Color("#dbe8f7"), 8, Color("#386c9f")))
    button.add_theme_stylebox_override("hover_pressed", button.get_theme_stylebox("pressed"))
    var focus: StyleBoxFlat = fluent_surface(Color.TRANSPARENT, 8, Color("#235f9d"))
    focus.set_border_width_all(2)
    button.add_theme_stylebox_override("focus", focus)
    button.add_theme_stylebox_override("disabled", fluent_surface(Color("#e0e5ec"), 8))
    for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        button.add_theme_color_override(state, Color("#1c2b3b"))
    button.add_theme_color_override("font_disabled_color", Color("#586572"))

# Dark semantic inks on light reward surfaces, including pressed state.
static func reward_rarity_ink(rarity: int) -> Color:
    match rarity:
        BlessingData.Rarity.RARE:
            return Color("#123859")
        BlessingData.Rarity.EPIC:
            return Color("#4b2269")
        BlessingData.Rarity.LEGENDARY:
            return Color("#583400")
        _:
            return Color("#263e20")

# Compact in-game progress surfaces use forest backing and a single semantic fill.
static func apply_forest_progress(bar: ProgressBar, color_value: Color) -> void:
    var backing: StyleBoxFlat = surface(Color("#e5edf5") if light_mode else Color("#263542"), 3, Color("#536579"), 0)
    var filling: StyleBoxFlat = surface(color_value, 3, color_value, 0)
    for style: StyleBoxFlat in [backing, filling]:
        style.set_border_width_all(0)
        style.content_margin_top = 0
        style.content_margin_bottom = 0
        style.content_margin_left = 0
        style.content_margin_right = 0
    bar.add_theme_stylebox_override("background", backing)
    bar.add_theme_stylebox_override("fill", filling)

static func apply_forest_slider(slider: HSlider) -> void:
    slider.set_meta("fluent_slider", true)
    var backing: StyleBoxFlat = surface(Color("#cbd8e5") if light_mode else Color("#182431"), 4, outline_color(), 0)
    var fill: StyleBoxFlat = surface(FLUENT_ACCENT, 4, FLUENT_ACCENT, 0)
    for style: StyleBoxFlat in [backing, fill]:
        style.set_border_width_all(1)
        style.content_margin_top = 2
        style.content_margin_bottom = 2
    slider.add_theme_stylebox_override("slider", backing)
    slider.add_theme_stylebox_override("grabber_area", fill)
    slider.add_theme_stylebox_override("grabber_area_highlight", fill)

# Fit an explicitly budgeted label by measuring the actual bundled font.
# Keep text intact; no ellipsis or invisible truncation for gameplay data.
static func fit_label(label: Label, rect: Rect2, preferred: int, minimum: int = 10) -> void:
    label.autowrap_mode = TextServer.AUTOWRAP_OFF
    label.clip_text = true
    var font: Font = label.get_theme_font("font")
    var lines: PackedStringArray = label.text.split("\n")
    var chosen: int = preferred
    for size_value: int in range(preferred, minimum - 1, -1):
        chosen = size_value
        var widest: float = 0.0
        for line: String in lines:
            widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value).x)
        if widest <= rect.size.x - 2.0 and font.get_height(size_value) * lines.size() <= rect.size.y:
            break
    label.add_theme_font_size_override("font_size", chosen)
    label.add_theme_constant_override("line_spacing", 0)
    label.position = rect.position
    label.size = rect.size

static var _heading_font: FontVariation

static func heading(label: Label, size_value: int) -> void:
    if _heading_font == null:
        _heading_font = FontVariation.new()
        _heading_font.base_font = load("res://assets/ui/fonts/SproutUISans-Regular.otf") as Font
        _heading_font.variation_embolden = 0.35
    label.add_theme_font_override("font", _heading_font)
    label.add_theme_font_size_override("font_size", size_value)
