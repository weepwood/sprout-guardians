extends Node
class_name PixelSkinController

var _sprites: Dictionary = {}
var _elapsed: float = 0.0
var _frame_delta: float = 0.0
var _hero_animation_state: int = -1
var _hero_animation_clock: float = 0.0


func _ready() -> void:
    get_tree().node_added.connect(_on_node_added)
    _skin_existing_nodes()


func _exit_tree() -> void:
    if get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.disconnect(_on_node_added)


func _process(delta: float) -> void:
    _elapsed += delta
    _frame_delta = delta
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
        if node is Node2D and not (node as Node2D).visible:
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
    # Do not schedule deferred work for every HUD Label and pooled visual.
    if node is GreedHeroPlant or node is GreedPlant or node is GreedEnemy or node is GreedProjectile or node is SurvivorExperienceGem:
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
    if node is GreedHeroPlant:
        (node as GreedHeroPlant).render_with_sprite = true
    elif node is GreedPlant:
        (node as GreedPlant).render_with_sprite = true
    elif node is GreedEnemy:
        (node as GreedEnemy).render_with_sprite = true
    elif node is GreedProjectile:
        (node as GreedProjectile).render_with_sprite = true
    elif node is SurvivorExperienceGem:
        (node as SurvivorExperienceGem).render_with_sprite = true
    sprite.texture = texture_value
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    _sprites[node.get_instance_id()] = sprite
    _configure_sprite(node, sprite)


func _texture_for_node(node: Node) -> Texture2D:
    if node is GreedHeroPlant:
        var hero: GreedHeroPlant = node as GreedHeroPlant
        if hero.config.has("character_index"):
            return HDArt.portrait(int(hero.config["character_index"]))
        return PixelArtAssets.texture(&"hero")
    if node is GreedPlant:
        var familiar: GreedPlant = node as GreedPlant
        if familiar.config.has("survivor_art"):
            return HDArt.actor(1 if familiar.orbit_index % 2 == 0 else 2)
        if familiar.orbit_index % 2 == 0:
            return PixelArtAssets.texture(&"familiar_sun")
        return PixelArtAssets.texture(&"familiar_sprout")
    if node is GreedEnemy:
        var enemy: GreedEnemy = node as GreedEnemy
        if enemy.survivor_combat:
            if enemy.boss and enemy.boss_profile > 0:
                return HDArt.biome(enemy.boss_profile - 1)
            if enemy.biome_enemy > 0 and not enemy.boss:
                return HDArt.biome(enemy.biome_enemy + 2)
            if enemy.boss:
                return HDArt.actor(5)
            if enemy.elite or enemy.survivor_variant == 2 or enemy.survivor_variant == 4:
                return HDArt.actor(4)
            return HDArt.actor(3)
        if enemy.boss:
            return PixelArtAssets.texture(&"enemy_boss")
        if enemy.elite:
            return PixelArtAssets.texture(&"enemy_elite")
        if enemy.survivor_variant == 1:
            return PixelArtAssets.texture(&"enemy_purple")
        if enemy.survivor_variant == 2:
            return PixelArtAssets.texture(&"enemy_maw")
        return PixelArtAssets.texture(&"enemy_green")
    if node is GreedProjectile:
        var projectile: GreedProjectile = node as GreedProjectile
        return PixelArtAssets.projectile_texture(projectile.splash_radius, projectile.slow_ratio)
    if node is SurvivorExperienceGem:
        return PixelArtAssets.texture(&"xp_gem")
    return null


func _configure_sprite(node: Node, sprite: Sprite2D) -> void:
    if node is GreedHeroPlant:
        sprite.position = Vector2(0.0, -5.0)
        sprite.scale = Vector2.ONE * 0.70 * HDArt.fit(sprite.texture, 56.0)
        sprite.z_index = 5
    elif node is GreedPlant:
        sprite.position = Vector2(0.0, -2.0)
        sprite.scale = Vector2.ONE * 0.39 * HDArt.fit(sprite.texture, 56.0)
        sprite.z_index = 5
    elif node is GreedEnemy:
        var enemy: GreedEnemy = node as GreedEnemy
        sprite.position = Vector2(0.0, -3.0)
        sprite.scale = Vector2.ONE * (0.92 if enemy.boss else (0.53 if enemy.elite else 0.40)) * HDArt.fit(sprite.texture, 56.0)
        sprite.z_index = 4
    elif node is GreedProjectile:
        sprite.scale = Vector2.ONE * 0.24
        sprite.z_index = 7
    elif node is SurvivorExperienceGem:
        sprite.scale = Vector2.ONE * 0.23
        sprite.z_index = 6


func _update_sprite(node: Node, sprite: Sprite2D) -> void:
    if node is GreedHeroPlant:
        var hero: GreedHeroPlant = node as GreedHeroPlant
        sprite.position.y = -5.0 + sin(_elapsed * 6.0) * 1.0
        var stride: float = sin(_elapsed * 13.0) * 0.045 if hero.arcade_direction.length_squared() > 0.0 else 0.0
        sprite.scale = Vector2(0.70 + stride, 0.70 - stride)
        if absf(hero.arcade_direction.x) > 0.15:
            sprite.flip_h = hero.arcade_direction.x < 0.0
        if hero.is_dashing():
            sprite.scale = Vector2.ONE * 0.75
        sprite.modulate = Color(1.0, 0.72, 0.72) if float(hero.get("_hit_flash")) > 0.0 else Color.WHITE
        var character_id: int = int(hero.config.get("character_index", 0))
        if character_id == 3 and HDArt.load_png("animations/hero_3") == null:
            sprite.modulate *= Color(0.88, 0.72, 1.0)
        elif character_id == 4 and HDArt.load_png("animations/hero_4") == null:
            sprite.modulate *= Color(0.78, 0.91, 0.52)
        if hero.config.has("character_index"):
            var state: int = SurvivorAnimation.state(hero)
            if _hero_animation_state >= SurvivorAnimation.State.ATTACK and _hero_animation_state < SurvivorAnimation.State.DEATH and state < SurvivorAnimation.State.ATTACK and _hero_animation_clock < 0.24:
                state = _hero_animation_state
            if state != _hero_animation_state:
                _hero_animation_state = state
                _hero_animation_clock = 0.0
            else:
                _hero_animation_clock += _frame_delta
            var frame: Texture2D = SurvivorAnimation.display_frame(int(hero.config["character_index"]), state, _hero_animation_clock)
            if frame != null:
                sprite.texture = frame
        sprite.scale *= HDArt.fit(sprite.texture, 56.0)
        return

    if node is GreedPlant:
        var familiar: GreedPlant = node as GreedPlant
        sprite.position.y = -2.0 + sin(_elapsed * 7.5 + float(familiar.orbit_index) * PI) * 1.5
        sprite.scale = Vector2.ONE * (0.39 + minf(0.12, float(familiar.level - 1) * 0.018)) * HDArt.fit(sprite.texture, 56.0)
        return

    if node is GreedEnemy:
        var enemy: GreedEnemy = node as GreedEnemy
        var squash_active: bool = float(enemy.get("_squash_time")) > 0.0
        var base_scale: float = 0.92 if enemy.boss else (0.53 if enemy.elite else 0.40)
        base_scale *= HDArt.fit(sprite.texture, 56.0)
        sprite.scale = Vector2(1.14, 0.84) * base_scale if squash_active else Vector2.ONE * base_scale
        if enemy.survivor_variant == 1 and fmod(float(enemy.get("_behavior_clock")), 3.4) < 0.55:
            sprite.scale *= Vector2(1.12, 0.76)
        if enemy.boss and enemy.get_health_ratio() < 0.5:
            sprite.scale *= 1.08
        if float(enemy.get("_flash_time")) > 0.0:
            sprite.modulate = Color(1.0, 0.72, 0.72)
        elif float(enemy.get("_slow_time")) > 0.0:
            sprite.modulate = Color(0.68, 0.92, 1.0)
        else:
            sprite.modulate = Color.WHITE
        if enemy.biome_enemy > 0:
            var biome_tints: Array[Color] = [Color.WHITE, Color(0.86, 1.0, 0.72), Color(0.68, 0.8, 1.0), Color(0.6, 0.95, 0.76)]
            sprite.modulate *= biome_tints[clampi(enemy.biome_enemy, 0, 3)]
        if enemy.survivor_combat and enemy.survivor_variant == 1:
            sprite.modulate *= Color(0.82, 0.92, 1.0)
        elif enemy.survivor_combat and enemy.survivor_variant == 3:
            sprite.modulate *= Color(1.0, 0.77, 0.90)
        return

    if node is GreedProjectile:
        var projectile: GreedProjectile = node as GreedProjectile
        var direction_value: Vector2 = projectile.get("_travel_direction")
        var hd: Texture2D = HDArt.load_png("vfx/projectile_%d" % projectile.visual_weapon) if projectile.visual_weapon >= 0 else null
        sprite.texture = hd if hd != null else PixelArtAssets.projectile_texture(projectile.splash_radius, projectile.slow_ratio)
        sprite.rotation = direction_value.angle()
        sprite.scale = Vector2.ONE * (0.30 if projectile.critical else 0.24) * HDArt.fit(sprite.texture, 56.0)
        sprite.modulate = Color.WHITE if hd != null else projectile.body_color.lerp(Color.WHITE, 0.28)
        return

    if node is SurvivorExperienceGem:
        sprite.rotation = _elapsed * 1.4
        sprite.scale = Vector2.ONE * (0.23 + sin(_elapsed * 5.0) * 0.018)
