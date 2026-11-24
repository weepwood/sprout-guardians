extends SceneTree

# This is a real renderer smoke test. File existence alone does not pass.
const OUT: String = "res://build/hd-art"
var failures: int = 0
var preview: bool = false
var captures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _expect(condition: bool, description: String) -> void:
    print("HD_ART ", description, " ", condition)
    if not condition:
        failures += 1
        push_error(description)

func _path(texture_value: Texture2D) -> String:
    if texture_value == null:
        return ""
    if texture_value is AtlasTexture:
        return _path((texture_value as AtlasTexture).atlas)
    return texture_value.resource_path

func _capture(name_value: String) -> void:
    captures += 1
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    _expect(image != null and not image.is_empty(), "Actual rendered frame " + name_value)
    if image != null and not image.is_empty():
        _expect(image.save_png(ProjectSettings.globalize_path(OUT + "/" + name_value + ".png")) == OK, "Saved " + name_value)

func _run() -> void:
    preview = OS.get_cmdline_user_args().has("--hd-preview")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    var menu_scene: PackedScene = load("res://scenes/main_menu.tscn") as PackedScene
    var menu: Node = menu_scene.instantiate()
    root.add_child(menu)
    await process_frame
    var menu_ground: TextureRect = menu.get_node("World/Grass") as TextureRect
    var menu_path: String = HDArt.ROOT + "menu/background.png"
    if preview and HDArt.load_png("menu/background") == null:
        menu_path = HDArt.ROOT + "terrain/classic.png"
        print("HD_ART_PREVIEW missing menu background; terrain fallback")
    _expect(_path(menu_ground.texture) == menu_path, "Menu background actually rendered")
    for i: int in range(3):
        var name_value: String = ["HeroPreviewHD", "FamiliarSunPreviewHD", "FamiliarSproutPreviewHD"][i]
        var preview: Sprite2D = menu.get_node_or_null("World/" + name_value) as Sprite2D
        _expect(preview != null and _path(preview.texture) == HDArt.ROOT + "animations/hero_%d.png" % i, "Menu preview %d actual texture" % i)
    await _capture("menu")
    menu.call("_show_character_screen")
    await process_frame
    await _capture("hero-selection")
    menu.queue_free()
    await process_frame
    SurvivorBalance.selected_difficulty = 1
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    for map_id: int in range(4):
        for character_id: int in range(5):
            if preview and HDArt.load_png("animations/hero_%d" % character_id) == null:
                print("HD_ART_PREVIEW missing hero ", character_id)
                continue
            var game: Node = packed.instantiate()
            game.set("simulation_mode", true)
            game.set("simulation_map", map_id)
            game.set("simulation_character", character_id)
            game.set("run_seed", 101)
            root.add_child(game)
            for _frame: int in range(360):
                await process_frame
            var ground: TextureRect = game.get_node("World/ArenaGround") as TextureRect
            _expect(_path(ground.texture) == HDArt.ROOT + "terrain/" + HDArt.MAPS[map_id] + ".png", "Map %d actual texture" % map_id)
            var hero: GreedHeroPlant = game.get("hero_plant") as GreedHeroPlant
            var sprite: Sprite2D = hero.get_node_or_null("PixelSprite") as Sprite2D
            _expect(sprite != null and _path(sprite.texture) == HDArt.ROOT + "animations/hero_%d.png" % character_id, "Hero %d actual animated texture" % character_id)
            if sprite != null and sprite.texture != null:
                var size: Vector2 = sprite.texture.get_size() * sprite.scale.abs()
                _expect(maxf(size.x, size.y) >= 47.0 and maxf(size.x, size.y) < 60.0, "Hero HD display size is readable without changing combat bounds")
            if character_id == 0:
                _audit_map_props(game, map_id)
            await _capture("map-%d-hero-%d" % [map_id, character_id])
            game.queue_free()
            await process_frame
    for index: int in range(SurvivorArsenal.IDS.size()):
        _expect(_path(HDArt.weapon(SurvivorArsenal.IDS[index])) == HDArt.ROOT + "weapons/weapon_%d.png" % index, "Weapon %d icon actual resolver" % index)
    await _audit_weapon_effects(packed)
    if preview:
        _expect(captures >= 14, "Preview covers at least three heroes and four maps")
        print("HD_ART_PREVIEW_COMPLETE ", failures, " CAPTURES ", captures)
    else:
        _expect(captures == 22, "Strict capture count")
        print("HD_ART_COMPLETE ", failures)
    quit(0 if failures == 0 else 1)

# Isolated renderer test: use actual launch/impact signals, not screenshots of icons.
# No damage is applied and no save is written. Normal simulations remain unchanged.
func _audit_weapon_effects(packed: PackedScene) -> void:
    var game: Node = packed.instantiate()
    game.set("simulation_mode", true)
    game.set("simulation_map", 0)
    game.set("simulation_character", 0)
    game.set("run_seed", 101)
    root.add_child(game)
    game.set_process(false)
    var hero: GreedHeroPlant = game.get("hero_plant") as GreedHeroPlant
    hero.set_process(false)
    for familiar: Node in get_nodes_in_group("greed_familiars"):
        familiar.set_process(false)
        if familiar is Node2D:
            (familiar as Node2D).hide()
    var target: GreedEnemy = game.call("_spawn_configured_enemy", SurvivorBalance.enemy_config(0.0, 1, false, false, 0), hero.global_position + Vector2(120.0, 0.0)) as GreedEnemy
    target.set_process(false)
    var verified: int = 0
    for index: int in range(8):
        var projectile_path: String = "vfx/projectile_%d" % index
        var has_projectile: bool = HDArt.load_png(projectile_path) != null
        var has_impact: bool = HDArt.load_png("vfx/impact_%d" % index) != null
        var has_evolution: bool = HDArt.load_png("vfx/evolution_%d" % index) != null
        if not preview:
            _expect(has_projectile and has_impact and has_evolution, "Weapon %d complete VFX assets" % index)
        if not has_projectile and not has_impact and not has_evolution:
            continue
        game.call("_on_arsenal_visual_requested", hero.global_position, target, 1.0, false, 360.0, 0.0, 0.0, 0.0, Color.WHITE, index, false)
        var projectile: GreedProjectile = null
        for node: Node in get_nodes_in_group("greed_projectiles"):
            if node is GreedProjectile and (node as GreedProjectile).visual_weapon == index:
                projectile = node as GreedProjectile
                break
        _expect(projectile != null, "Weapon %d actual launched projectile" % index)
        if projectile == null:
            continue
        projectile.set_process(false)
        # Park the real launched projectile between actors for unobstructed visual evidence.
        projectile.global_position = hero.global_position.lerp(target.global_position, 0.5)
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw
        if has_projectile:
            var sprite: Sprite2D = projectile.get_node_or_null("PixelSprite") as Sprite2D
            _expect(sprite != null and sprite.is_visible_in_tree() and _path(sprite.texture) == HDArt.ROOT + projectile_path + ".png", "Weapon %d actual projectile texture" % index)
            if sprite != null and sprite.texture != null:
                var size: Vector2 = sprite.texture.get_size() * sprite.scale.abs()
                _expect(maxf(size.x, size.y) >= 29.0 and maxf(size.x, size.y) <= 37.0, "HD projectile visible footprint")
            verified += 1
            await _capture_vfx("weapon-%d-projectile" % index)
        for evolved: bool in [false, true]:
            if (evolved and not has_evolution) or (not evolved and not has_impact):
                continue
            projectile.visual_evolved = evolved
            # Real _impact places the projectile on its target before emitting.
            projectile.global_position = target.global_position
            # Visual effects are normally suppressed in headless simulations.
            # Enable only for this synchronous visual signal, not a gameplay tick.
            game.set("simulation_mode", false)
            projectile.impacted.emit(projectile, target, 0.0, false)
            game.set("simulation_mode", true)
            var effects: Array = game.get("effect_sprites")
            var effect: Sprite2D = effects.back() as Sprite2D if not effects.is_empty() else null
            var expected_path: String = HDArt.ROOT + ("vfx/evolution_" if evolved else "vfx/impact_") + str(index) + ".png"
            _expect(is_instance_valid(effect) and effect.is_visible_in_tree() and _path(effect.texture) == expected_path, "Weapon %d actual %s texture" % [index, "evolution" if evolved else "impact"])
            if is_instance_valid(effect):
                _expect(effect.global_position.is_equal_approx(target.global_position), "Impact fixture uses actual target position")
                var size: Vector2 = effect.texture.get_size() * effect.scale.abs()
                _expect(maxf(size.x, size.y) >= (63.0 if evolved else 55.0), "HD impact initial visible footprint")
            verified += 1
            await _capture_vfx("weapon-%d-%s" % [index, "evolution" if evolved else "impact"])
            if is_instance_valid(effect):
                effect.queue_free()
            await process_frame
        projectile.call("_finish")
        await process_frame
    print("HD_ART_VFX_RUNTIME_CHECKS ", verified)
    if not preview:
        _expect(verified == 24, "All 24 weapon visual routes exercised")
    game.queue_free()
    await process_frame

# Separate JPEG evidence leaves the existing 22 PNG scene-capture gate intact.
# These are isolated visual fixtures, not screenshots of an organic battle.
func _capture_vfx(name_value: String) -> void:
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    _expect(image != null and not image.is_empty(), "Actual VFX renderer frame " + name_value)
    if image != null and not image.is_empty():
        _expect(image.save_jpg(ProjectSettings.globalize_path(OUT + "/" + name_value + ".jpg"), 0.95) == OK, "Saved VFX evidence " + name_value)

# Validate actual decoration nodes, not just the existence of PNG files.
func _audit_map_props(game: Node, map_id: int) -> void:
    var prefix: String = HDArt.ROOT + "props/" + HDArt.MAPS[map_id] + "/"
    var layer: Node2D = game.get_node_or_null("World/HDMapDecorations") as Node2D
    if preview and layer == null:
        print("HD_ART_PREVIEW missing map props ", map_id)
        return
    _expect(layer != null and layer.is_visible_in_tree(), "Map %d decoration layer rendered" % map_id)
    if layer == null:
        return
    var paths: Dictionary = {}
    for child: Node in layer.get_children():
        var sprite: Sprite2D = child as Sprite2D
        if sprite == null:
            _expect(false, "Map decoration is Sprite2D")
            continue
        var path_value: String = _path(sprite.texture)
        _expect(sprite.is_visible_in_tree() and path_value.begins_with(prefix), "Map %d actual prop texture %s" % [map_id, path_value])
        paths[path_value] = true
        if sprite.texture != null:
            var size: Vector2 = sprite.texture.get_size() * sprite.scale.abs()
            _expect(maxf(size.x, size.y) >= 19.0 and maxf(size.x, size.y) <= 79.0, "Decoration visual scale")
        _expect(sprite.get_child_count() == 0, "Decoration is visual only")
    _expect(paths.size() == 6, "Map %d all six independent prop textures" % map_id)
    _expect(layer.get_child_count() >= (12 if map_id == 0 else 28), "Map %d minimum edge decoration count" % map_id)
    print("HD_ART_PROP_RUNTIME ", map_id, " ", paths.size(), " ", layer.get_child_count())
