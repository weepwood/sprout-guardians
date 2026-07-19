extends CanvasLayer
class_name DebugPerformanceOverlay

var enemy_registry: EnemyRegistry
var projectile_pool: ProjectilePool
var _label: Label
var _refresh_cooldown: float = 0.0


func configure(registry: EnemyRegistry, pool: ProjectilePool) -> void:
    enemy_registry = registry
    projectile_pool = pool


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 100

    var panel: ColorRect = ColorRect.new()
    panel.position = Vector2(8.0, 50.0)
    panel.size = Vector2(176.0, 84.0)
    panel.color = Color(0.02, 0.06, 0.07, 0.86)
    add_child(panel)

    _label = Label.new()
    _label.position = Vector2(14.0, 56.0)
    _label.size = Vector2(164.0, 74.0)
    _label.add_theme_font_size_override("font_size", 13)
    _label.add_theme_color_override("font_color", Color("dcebd6"))
    add_child(_label)

    visible = false
    _refresh_text()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key_event: InputEventKey = event as InputEventKey
        if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F3:
            visible = not visible
            if visible:
                _refresh_text()
            get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
    if not visible:
        return
    _refresh_cooldown -= delta
    if _refresh_cooldown <= 0.0:
        _refresh_cooldown = 0.25
        _refresh_text()


func _refresh_text() -> void:
    if _label == null:
        return
    var enemies: int = 0 if enemy_registry == null else enemy_registry.get_enemy_count()
    var projectiles: int = 0 if projectile_pool == null else projectile_pool.get_active_count()
    var capacity: int = 0 if projectile_pool == null else projectile_pool.get_capacity()
    _label.text = "DEBUG  [F3]\nFPS: %d\nEnemies: %d\nProjectiles: %d/%d" % [
        Engine.get_frames_per_second(),
        enemies,
        projectiles,
        capacity,
    ]
