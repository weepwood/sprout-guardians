extends Node
class_name ResponsiveUI

# Separate logical UI geometry from the world camera. HUD uses requested zoom;
# only dense modal/menu groups are fitted to the available logical viewport.
const BASE: Vector2 = Vector2(640, 360)
var canvas: CanvasLayer
var settings: SettingsService
var layout: Callable
var resize_save: Timer
var logical_size: Vector2 = BASE

func bind(target: CanvasLayer, preferences: SettingsService, callback: Callable) -> void:
    canvas = target
    settings = preferences
    layout = callback
    resize_save = Timer.new()
    resize_save.one_shot = true
    resize_save.wait_time = 0.45
    resize_save.ignore_time_scale = true
    resize_save.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(resize_save)
    resize_save.timeout.connect(settings.remember_window_size)
    get_viewport().size_changed.connect(_resized)
    refresh()

func refresh() -> void:
    if not is_instance_valid(canvas):
        return
    var view: Vector2 = get_viewport().get_visible_rect().size
    if view.x < 1.0 or view.y < 1.0:
        return
    var factor: float = settings.ui_scale
    canvas.scale = Vector2.ONE * factor
    logical_size = view / factor
    layout.call(logical_size)

func _resized() -> void:
    refresh()
    if SettingsService.native_display():
        resize_save.start()

func _exit_tree() -> void:
    if is_instance_valid(resize_save) and not resize_save.is_stopped():
        settings.remember_window_size()

static func center_group(group: Control, view: Vector2) -> void:
    var fit: float = minf(1.0, minf(view.x / BASE.x, view.y / BASE.y))
    group.scale = Vector2.ONE * fit
    group.position = (view - BASE * fit) * 0.5
    group.size = BASE
    group.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var backdrop: Control = group.get_node_or_null("Backdrop") as Control
    if backdrop != null:
        backdrop.position = -group.position / fit
        backdrop.size = view / fit

static func place(control: Control, rect: Rect2) -> void:
    control.position = rect.position
    control.size = rect.size
