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

static func fluent_surface(fill: Color, radius_value: int = 8, outline: Color = Color("#526171"), shadow: int = 0) -> StyleBoxFlat:
    var style: StyleBoxFlat = surface(fill, radius_value, outline, shadow)
    style.set_border_width_all(1)
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
    return style

static func apply_forest_panel(panel: Panel, blur: bool = false) -> void:
    apply_acrylic_panel(panel, false, blur)

static func apply_acrylic_panel(panel: Panel, light: bool = false, blur: bool = true) -> void:
    var glass: ColorRect = panel.get_node_or_null("AcrylicBackdrop") as ColorRect
    var use_blur: bool = blur and DisplayServer.get_name() != "headless"
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
        shader_material.set_shader_parameter("tint", Color(0.93, 0.95, 0.98, 0.86) if light else Color(0.095, 0.12, 0.16, 0.62))
        _resize_acrylic(panel, glass)
    # Solid fallback in headless / shader-disabled environments. Light text stays
    # readable even when the backdrop is bright; light reward cards remain opaque.
    var base: Color = Color("#f2f5fa") if light else Color("#202a36")
    base.a = (0.92 if light else 0.27) if use_blur else 0.96
    panel.add_theme_stylebox_override("panel", fluent_surface(base, 14 if light else 10, Color("#aebdce") if light else Color(0.70, 0.80, 0.92, 0.34), 3 if blur else 0))

static func _resize_acrylic(panel: Panel, glass: ColorRect) -> void:
    if is_instance_valid(glass) and glass.material is ShaderMaterial:
        (glass.material as ShaderMaterial).set_shader_parameter("panel_size", panel.size.max(Vector2.ONE))

static func apply_forest_button(button: Button, primary: bool = false) -> void:
    button.set_meta("fluent_no_scale", true)
    button.scale = Vector2.ONE
    var normal: Color = FLUENT_ACCENT if primary else Color("#303d4b")
    var hover: Color = Color("#b2dcff") if primary else Color("#405365")
    var down: Color = Color("#6eafdf") if primary else Color("#263442")
    var ink: Color = Color("#152333") if primary else FLUENT_TEXT
    var border: Color = Color("#5c798f") if not primary else Color("#aedcff")
    button.add_theme_stylebox_override("normal", fluent_surface(normal, 7, border))
    button.add_theme_stylebox_override("hover", fluent_surface(hover, 7, Color("#a5c8e7")))
    button.add_theme_stylebox_override("pressed", fluent_surface(down, 7, FLUENT_ACCENT))
    button.add_theme_stylebox_override("hover_pressed", button.get_theme_stylebox("pressed"))
    button.add_theme_stylebox_override("disabled", fluent_surface(Color("#27313c"), 7, Color("#414e5c")))
    var focus: StyleBoxFlat = fluent_surface(Color.TRANSPARENT, 7, FLUENT_ACCENT)
    focus.set_border_width_all(2)
    button.add_theme_stylebox_override("focus", focus)
    for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        button.add_theme_color_override(state, ink)
    button.add_theme_color_override("font_disabled_color", Color("#a6b5c5"))
    button.focus_mode = Control.FOCUS_ALL

static func apply_forest_picker(picker: OptionButton) -> void:
    apply_forest_button(picker)
    picker.fit_to_longest_item = false
    picker.clip_text = true
    var popup: PopupMenu = picker.get_popup()
    popup.add_theme_stylebox_override("panel", fluent_surface(Color("#283542"), 8, Color("#65798c"), 3))
    popup.add_theme_stylebox_override("hover", fluent_surface(Color("#40576c"), 5, Color("#7ba7c8")))
    popup.add_theme_color_override("font_color", FLUENT_TEXT)
    popup.add_theme_color_override("font_hover_color", FLUENT_TEXT)
    popup.add_theme_color_override("font_disabled_color", Color("#a6b5c5"))
    popup.add_theme_constant_override("v_separation", 7)

static func apply_fluent_tabs(tabs: TabContainer) -> void:
    tabs.add_theme_stylebox_override("tab_selected", fluent_surface(Color("#3e566d"), 6, FLUENT_ACCENT))
    tabs.add_theme_stylebox_override("tab_unselected", fluent_surface(Color("#263542"), 6))
    tabs.add_theme_stylebox_override("tab_hovered", fluent_surface(Color("#394c60"), 6))
    tabs.add_theme_stylebox_override("panel", fluent_surface(Color("#26323f"), 7))
    tabs.add_theme_color_override("font_selected_color", FLUENT_TEXT)
    tabs.add_theme_color_override("font_unselected_color", FLUENT_MUTED)
    tabs.add_theme_color_override("font_hovered_color", FLUENT_TEXT)

static func apply_light_reward(button: Button, border: Color = Color("#bdcad7")) -> void:
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
    var backing: StyleBoxFlat = surface(Color("#263542"), 3, Color("#536579"), 0)
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
    var backing: StyleBoxFlat = surface(Color("#182431"), 4, Color("#65788b"), 0)
    var fill: StyleBoxFlat = surface(FLUENT_ACCENT, 4, FLUENT_ACCENT, 0)
    for style: StyleBoxFlat in [backing, fill]:
        style.set_border_width_all(1)
        style.content_margin_top = 2
        style.content_margin_bottom = 2
    slider.add_theme_stylebox_override("slider", backing)
    slider.add_theme_stylebox_override("grabber_area", fill)
    slider.add_theme_stylebox_override("grabber_area_highlight", fill)
