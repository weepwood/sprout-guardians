extends Node
class_name PixelSkinController

var _sprites: Dictionary = {}
var _elapsed: float = 0.0


func _ready() -> void:
    get_tree().node_added.connect(_on_node_added)
    _skin_existing_nodes()


func _exit_tree() -> void:
    if get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.disconnect(_on_node_added)


func _process(delta: float) -> void:
    _elapsed += delta
    var stale_ids: Array[int] = []
    for instance_id_value: Variant in _sprites.keys():
        var node: Node = instance_from_id(int(instance_id_value)) as Node
        var sprite_value: Variant = _sprites[instance_id_value]
        if node == null or not is_instance_valid(node) or not is_instance_valid(sprite_value):
            stale_ids.append(int(instance_id_value))
            continue
        var sprite: Sprite2D = sprite_value as Sprite2D
        if sprite == null:
            stale_ids.append(int(instance_id_value))
            continue
        _update_sprite(node, sprite)
    for stale_id: int in stale_ids:
        _sprites.erase(stale_id)


func _skin_existing_nodes() -> void:
    for group_name: StringName in [&"greed_plants", &"greed_enemies", &"greed_projectiles", &"survivor_experience"]:
        for node: Node in get_tree().get_nodes_in_group(group_name):
            _skin_node(node)
    for node: Node in get_tree().get_nodes_in_group("greed_familiars"):
        _skin_node(node)
    var hero: Node = null
    if get_parent() != null:
        hero = get_parent().get("hero_plant") as Node
    if hero != null:
        _skin_node(hero)


func _on_node_added(node: Node) -> void:
    call_deferred("_skin_node", node)


func _skin_node(node: Node) -> void:
    if node == null or not is_instance_valid(node):
        return
    if _sprites.has(node.get_instance_id()):
        return

    var texture_value: Texture2D = _texture_for_node(node)
    if texture_value == null:
        return

    var sprite: Sprite2D
    if node.has_node("PixelSprite"):
        sprite = node.get_node("PixelSprite") as Sprite2D
    else:
        sprite = Sprite2D.new()
        sprite.name = "PixelSprite"
        sprite.centered = true
        sprite.z_index = 4
        node.add_child(sprite)

    if sprite == null:
        return
    sprite.texture = texture_value
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _sprites[node.get_instance_id()] = sprite
    _configure_sprite(node, sprite)


func _texture_for_node(node: Node) -> Texture2D:
    if node is GreedHeroPlant:
        return PixelArtAssets.texture(&"hero")
    if node is GreedPlant:
        var familiar: GreedPlant = node as GreedPlant
        if familiar.orbit_index % 2 == 0:
            return PixelArtAssets.texture(&"familiar_sun")
        return PixelArtAssets.texture(&"familiar_sprout")
    if node is GreedEnemy:
        var enemy: GreedEnemy = node as GreedEnemy
        if enemy.boss:
            return PixelArtAssets.texture(&"enemy_boss")
        if enemy.elite:
            return PixelArtAssets.texture(&"enemy_elite")
        return PixelArtAssets.regular_enemy_texture(int(enemy.get_instance_id()))
    if node is GreedProjectile:
        var projectile: GreedProjectile = node as GreedProjectile
        return PixelArtAssets.projectile_texture(projectile.splash_radius, projectile.slow_ratio)
    if node is SurvivorExperienceGem:
        return PixelArtAssets.texture(&"xp_gem")
    return null


func _configure_sprite(node: Node, sprite: Sprite2D) -> void:
    if node is GreedHeroPlant:
        sprite.position = Vector2(0.0, -5.0)
        sprite.z_index = 5
    elif node is GreedPlant:
        sprite.position = Vector2(0.0, -2.0)
        sprite.z_index = 5
    elif node is GreedEnemy:
        sprite.position = Vector2(0.0, -3.0)
        sprite.z_index = 4
    elif node is GreedProjectile:
        sprite.z_index = 7
    elif node is SurvivorExperienceGem:
        sprite.z_index = 6


func _update_sprite(node: Node, sprite: Sprite2D) -> void:
    if node is GreedHeroPlant:
        var hero: GreedHeroPlant = node as GreedHeroPlant
        sprite.position.y = -5.0 + sin(_elapsed * 6.0) * 1.0
        sprite.scale = Vector2.ONE * (1.08 if hero.is_dashing() else 1.0)
        sprite.modulate = Color(1.0, 0.72, 0.72) if float(hero.get("_hit_flash")) > 0.0 else Color.WHITE
        return

    if node is GreedPlant:
        var familiar: GreedPlant = node as GreedPlant
        sprite.position.y = -2.0 + sin(_elapsed * 7.5 + float(familiar.orbit_index) * PI) * 1.5
        sprite.scale = Vector2.ONE * (1.0 + minf(0.22, float(familiar.level - 1) * 0.035))
        return

    if node is GreedEnemy:
        var enemy: GreedEnemy = node as GreedEnemy
        var squash_active: bool = float(enemy.get("_squash_time")) > 0.0
        sprite.scale = Vector2(1.18, 0.78) if squash_active else Vector2.ONE
        if float(enemy.get("_flash_time")) > 0.0:
            sprite.modulate = Color(1.0, 0.72, 0.72)
        elif float(enemy.get("_slow_time")) > 0.0:
            sprite.modulate = Color(0.68, 0.92, 1.0)
        else:
            sprite.modulate = Color.WHITE
        return

    if node is GreedProjectile:
        var projectile: GreedProjectile = node as GreedProjectile
        var direction_value: Vector2 = projectile.get("_travel_direction")
        sprite.rotation = direction_value.angle()
        sprite.scale = Vector2.ONE * (1.35 if projectile.critical else 1.0)
        return

    if node is SurvivorExperienceGem:
        sprite.rotation = _elapsed * 1.4
        sprite.scale = Vector2.ONE * (1.0 + sin(_elapsed * 5.0) * 0.08)
