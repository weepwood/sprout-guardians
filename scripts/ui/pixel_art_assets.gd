extends RefCounted
class_name PixelArtAssets

const ACTORS_ATLAS: Texture2D = preload("res://assets/pixel/actors_atlas.svg")
const EFFECTS_ATLAS: Texture2D = preload("res://assets/pixel/effects_atlas.svg")
const GRASS_TILE: Texture2D = preload("res://assets/pixel/grass_tile.svg")
const UI_PANEL: Texture2D = preload("res://assets/pixel/ui_panel.svg")
const TOY_ATLAS: Texture2D = preload("res://assets/toy/sprout_toy_atlas.png")
const MUTATION_ATLAS: Texture2D = preload("res://assets/generated/mutation_icons.png")
const GENERATED_ACTORS: Texture2D = preload("res://assets/generated/actor_atlas.png")
const BIOME_ATLAS: Texture2D = preload("res://assets/generated/biomes_events.png")
const BIOME_ACTORS: Texture2D = preload("res://assets/generated/biome_actors.png")
const MUTATION_IDS: Array[String] = ["mutation_seed", "mutation_spore", "mutation_frost", "mutation_sun", "mutation_thorn", "mutation_symbiosis"]

# 3x3 source art atlas. Each 56px cell is an authored image, never generated
# by a gameplay Node2D.draw_* callback. Keep the original SVG keys below for
# legacy levels and tiny monochrome HUD icons.
const TOY_REGIONS: Dictionary = {
    &"hero": Rect2(0, 0, 56, 56),
    &"familiar_sun": Rect2(56, 0, 56, 56),
    &"familiar_sprout": Rect2(112, 0, 56, 56),
    &"enemy_green": Rect2(0, 56, 56, 56),
    &"enemy_purple": Rect2(56, 56, 56, 56),
    &"enemy_maw": Rect2(0, 56, 56, 56),
    &"enemy_elite": Rect2(56, 56, 56, 56),
    &"enemy_boss": Rect2(112, 56, 56, 56),
    &"xp_gem": Rect2(56, 112, 56, 56),
    &"projectile_leaf": Rect2(0, 112, 56, 56),
    &"projectile_petal": Rect2(0, 112, 56, 56),
    &"projectile_frost": Rect2(0, 112, 56, 56),
    &"impact_star": Rect2(112, 112, 56, 56),
}

const REGIONS: Dictionary = {
    &"hero": Rect2(0.0, 0.0, 48.0, 48.0),
    &"familiar_sun": Rect2(48.0, 0.0, 32.0, 32.0),
    &"familiar_sprout": Rect2(80.0, 0.0, 32.0, 32.0),
    &"enemy_green": Rect2(112.0, 0.0, 32.0, 32.0),
    &"enemy_purple": Rect2(144.0, 0.0, 32.0, 32.0),
    &"enemy_maw": Rect2(176.0, 0.0, 40.0, 40.0),
    &"enemy_elite": Rect2(216.0, 0.0, 40.0, 40.0),
    &"enemy_boss": Rect2(0.0, 48.0, 56.0, 56.0),
    &"xp_gem": Rect2(0.0, 0.0, 16.0, 16.0),
    &"projectile_leaf": Rect2(16.0, 0.0, 16.0, 12.0),
    &"projectile_petal": Rect2(32.0, 0.0, 12.0, 12.0),
    &"projectile_frost": Rect2(44.0, 0.0, 12.0, 12.0),
    &"icon_heart": Rect2(56.0, 0.0, 24.0, 24.0),
    &"icon_skull": Rect2(80.0, 0.0, 24.0, 24.0),
    &"icon_leaf": Rect2(104.0, 0.0, 24.0, 24.0),
}

const EFFECT_KEYS: Dictionary = {
    &"xp_gem": true,
    &"projectile_leaf": true,
    &"projectile_petal": true,
    &"projectile_frost": true,
    &"icon_heart": true,
    &"icon_skull": true,
    &"icon_leaf": true,
}

static var _texture_cache: Dictionary = {}


static func texture(key: StringName) -> Texture2D:
    if _texture_cache.has(key):
        return _texture_cache[key] as Texture2D
    var atlas_texture: AtlasTexture = AtlasTexture.new()
    if TOY_REGIONS.has(key):
        atlas_texture.atlas = TOY_ATLAS
        atlas_texture.region = TOY_REGIONS[key]
    elif REGIONS.has(key):
        atlas_texture.atlas = EFFECTS_ATLAS if EFFECT_KEYS.has(key) else ACTORS_ATLAS
        atlas_texture.region = REGIONS[key]
    else:
        push_error("Unknown texture asset key: %s" % String(key))
        return null
    atlas_texture.filter_clip = true
    _texture_cache[key] = atlas_texture
    return atlas_texture


static func regular_enemy_texture(instance_id_value: int) -> Texture2D:
    match posmod(instance_id_value, 3):
        0:
            return texture(&"enemy_green")
        1:
            return texture(&"enemy_purple")
        _:
            return texture(&"enemy_maw")


static func projectile_texture(splash_radius: float, slow_ratio: float) -> Texture2D:
    if slow_ratio > 0.0:
        return texture(&"projectile_frost")
    if splash_radius > 0.0:
        return texture(&"projectile_petal")
    return texture(&"projectile_leaf")


static func blessing_icon(blessing_id: StringName) -> Texture2D:
    var id_text: String = String(blessing_id).to_lower()
    if id_text == "mutation_barrage":
        return blessing_icon(&"mutation_thorn")
    if id_text == "mutation_mist":
        return blessing_icon(&"mutation_frost")
    var index: int = MUTATION_IDS.find(id_text)
    if index >= 0:
        if not _texture_cache.has(blessing_id):
            var icon: AtlasTexture = AtlasTexture.new()
            icon.atlas = MUTATION_ATLAS
            icon.region = Rect2(float(index % 3) * 56.0, float(floori(float(index) / 3.0)) * 56.0, 56.0, 56.0)
            icon.filter_clip = true
            _texture_cache[blessing_id] = icon
        return _texture_cache[blessing_id] as Texture2D
    if id_text.contains("frozen") or id_text.contains("slow"):
        return texture(&"projectile_frost")
    if id_text.contains("spore") or id_text.contains("bloom"):
        return texture(&"projectile_petal")
    return texture(&"icon_leaf")


static func generated_actor(index: int) -> Texture2D:
    var safe_index: int = clampi(index, 0, 5)
    var key: StringName = StringName("generated_actor_%d" % safe_index)
    if not _texture_cache.has(key):
        var icon: AtlasTexture = AtlasTexture.new()
        icon.atlas = GENERATED_ACTORS
        icon.region = Rect2(float(safe_index % 3) * 56.0, float(floori(float(safe_index) / 3.0)) * 56.0, 56.0, 56.0)
        icon.filter_clip = true
        _texture_cache[key] = icon
    return _texture_cache[key] as Texture2D


static func biome_texture(map_id: int) -> Texture2D:
    var i: int = clampi(map_id - 1, 0, 2)
    var key: StringName = StringName("biome_%d" % i)
    if not _texture_cache.has(key):
        var names: Array[String] = ["forest", "night", "swamp"]
        var path: String = "res://assets/generated/terrain/%s.png" % names[i]
        if ResourceLoader.exists(path):
            var terrain: Texture2D = load(path) as Texture2D
            if terrain != null:
                _texture_cache[key] = terrain
                return terrain
        var source: Image = BIOME_ATLAS.get_image()
        var tile: Image = source.get_region(Rect2i(i * 32, 0, 32, 32))
        tile.resize(128, 128, Image.INTERPOLATE_BILINEAR)
        _texture_cache[key] = ImageTexture.create_from_image(tile)
    return _texture_cache[key] as Texture2D


static func event_icon(kind: int) -> Texture2D:
    return biome_actor(6 + clampi(kind, 0, 2))


static func biome_actor(index: int) -> Texture2D:
    var i: int = clampi(index, 0, 8)
    var key: StringName = StringName("biome_actor_%d" % i)
    if not _texture_cache.has(key):
        var icon: AtlasTexture = AtlasTexture.new()
        icon.atlas = BIOME_ACTORS
        icon.region = Rect2((i % 3) * 48, floori(float(i) / 3.0) * 48, 48, 48)
        icon.filter_clip = true
        _texture_cache[key] = icon
    return _texture_cache[key] as Texture2D
