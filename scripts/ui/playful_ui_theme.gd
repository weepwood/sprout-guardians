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

# V0.6 forest chrome. Keep light reward cards and their contrast contract.
static func apply_forest_panel(panel: Panel) -> void:
    var style: StyleBoxFlat = surface(Color(0.09, 0.16, 0.12, 0.94), 12, Color("#6f8768"), 4)
    style.set_border_width_all(1)
    panel.add_theme_stylebox_override("panel", style)


static func apply_forest_button(button: Button, primary: bool = false) -> void:
    apply_button(button, "primary" if primary else "soft", false)
    var focus: StyleBoxFlat = surface(Color(0, 0, 0, 0), 9, Color("#f6e4a5"), 0)
    focus.set_border_width_all(2)
    button.add_theme_stylebox_override("focus", focus)
    if primary:
        return
    var normal: StyleBoxFlat = surface(Color("#294337"), 8, Color("#55725a"), 1)
    var hover: StyleBoxFlat = surface(Color("#365643"), 8, Color("#9bb884"), 2)
    var pressed: StyleBoxFlat = surface(Color("#314b38"), 8, Color("#f0cf80"), 1)
    pressed.set_border_width_all(2)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("hover_pressed", pressed)
    button.add_theme_stylebox_override("disabled", surface(Color("#25352d"), 8, Color("#475449"), 0))
    for name_value: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        button.add_theme_color_override(name_value, Color("#f8f3de"))
    button.add_theme_color_override("font_disabled_color", Color("#a6b6a4"))

# Native option popup, styled to match the game menu rather than the default cream theme.
static func apply_forest_picker(picker: OptionButton) -> void:
    apply_forest_button(picker)
    picker.add_theme_color_override("font_color", Color("#f8f3de"))
    picker.add_theme_color_override("font_disabled_color", Color("#a6b6a4"))
    var popup: PopupMenu = picker.get_popup()
    popup.add_theme_stylebox_override("panel", surface(Color("#20382b"), 8, Color("#6f8768"), 4))
    popup.add_theme_stylebox_override("hover", surface(Color("#365643"), 5, Color("#9bb884"), 0))
    popup.add_theme_color_override("font_color", Color("#f8f3de"))
    popup.add_theme_color_override("font_hover_color", Color("#fff4d7"))
    popup.add_theme_color_override("font_disabled_color", Color("#a6b6a4"))
    popup.add_theme_constant_override("v_separation", 7)
