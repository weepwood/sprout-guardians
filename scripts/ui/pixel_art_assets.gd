extends RefCounted
class_name PixelArtAssets

const ACTORS_ATLAS: Texture2D = preload("res://assets/pixel/actors_atlas.svg")
const EFFECTS_ATLAS: Texture2D = preload("res://assets/pixel/effects_atlas.svg")
const GRASS_TILE: Texture2D = preload("res://assets/pixel/grass_tile.svg")
const UI_PANEL: Texture2D = preload("res://assets/pixel/ui_panel.svg")

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
    if not REGIONS.has(key):
        push_error("Unknown pixel-art texture key: %s" % String(key))
        return null
    var atlas_texture: AtlasTexture = AtlasTexture.new()
    atlas_texture.atlas = EFFECTS_ATLAS if EFFECT_KEYS.has(key) else ACTORS_ATLAS
    atlas_texture.region = REGIONS[key]
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
    if id_text.contains("frozen") or id_text.contains("slow"):
        return texture(&"projectile_frost")
    if id_text.contains("spore") or id_text.contains("bloom"):
        return texture(&"projectile_petal")
    return texture(&"icon_leaf")
