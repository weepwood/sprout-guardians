extends RefCounted
class_name HDArt

# Full-color PNGs are preferred only when actually imported. Old saves/builds
# may still boot with legacy resources; the V0.6 release gate forbids fallback.
const ROOT: String = "res://assets/generated/hd/"
const MAPS: Array[String] = ["classic", "forest", "night", "swamp"]
static var _cache: Dictionary = {}

static func load_png(relative: String) -> Texture2D:
    if not _cache.has(relative):
        var path: String = ROOT + relative + ".png"
        _cache[relative] = load(path) as Texture2D if ResourceLoader.exists(path) else null
    return _cache[relative] as Texture2D

static func terrain(map_id: int) -> Texture2D:
    return load_png("terrain/" + MAPS[clampi(map_id, 0, 3)])

static func actor(index: int) -> Texture2D:
    var image: Texture2D = load_png("actors/actor_%d" % index)
    return image if image != null else PixelArtAssets.generated_actor(index)

static func biome(index: int) -> Texture2D:
    var image: Texture2D = load_png("biome/biome_%d" % index)
    return image if image != null else PixelArtAssets.biome_actor(index)

static func weapon(id_value: StringName) -> Texture2D:
    var index: int = SurvivorArsenal.IDS.find(id_value)
    var image: Texture2D = load_png("weapons/weapon_%d" % index) if index >= 0 else null
    return image if image != null else PixelArtAssets.blessing_icon(id_value)

static func portrait(character_id: int) -> Texture2D:
    var sheet: Texture2D = load_png("animations/hero_%d" % character_id)
    if sheet != null:
        var cell: int = floori(float(sheet.get_width()) / 4.0)
        if cell >= 128 and sheet.get_width() == cell * 4 and sheet.get_height() == cell * 5:
            var key: String = "portrait_%d" % character_id
            if not _cache.has(key):
                var region: AtlasTexture = AtlasTexture.new()
                region.atlas = sheet
                region.region = Rect2(0, 0, cell, cell)
                region.filter_clip = true
                _cache[key] = region
            return _cache[key] as Texture2D
    return actor(SurvivorCharacters.art_index(character_id))

static func fit(texture_value: Texture2D, display_pixels: float) -> float:
    if texture_value == null:
        return 1.0
    return display_pixels / maxf(1.0, maxf(texture_value.get_width(), texture_value.get_height()))


# Optional independent enemy action sheets: 4 columns × 5 state rows.
# Missing sheets deliberately return null instead of recycling hero frames.
static func enemy_frame(key: String, state: int, elapsed: float) -> Texture2D:
    var sheet: Texture2D = load_png("enemy_animations/" + key)
    if sheet == null:
        return null
    var cell: int = floori(float(sheet.get_width()) / 4.0)
    if cell < 128 or sheet.get_width() != cell * 4 or sheet.get_height() != cell * 5:
        return null
    var row: int = clampi(state, 0, 4)
    var index: int = floori(maxf(elapsed, 0.0) * (14.0 if row >= 2 else 8.0))
    index = mini(index, 3) if row >= 2 else posmod(index, 4)
    var cache_key: String = "enemy:%s:%d:%d" % [key, row, index]
    if not _cache.has(cache_key):
        var frame: AtlasTexture = AtlasTexture.new()
        frame.atlas = sheet
        frame.region = Rect2(index * cell, row * cell, cell, cell)
        frame.filter_clip = true
        _cache[cache_key] = frame
    return _cache[cache_key] as Texture2D


# Purely decorative edge placement. Never advances the combat/event RNG and
# never introduces a collision shape, target, pickup or spawn restriction.
static func decorate_map(world: Node2D, map_id: int) -> void:
    var old: Node = world.get_node_or_null("HDMapDecorations")
    if old != null:
        old.queue_free()
    var textures: Array[Texture2D] = []
    for i: int in range(6):
        var texture_value: Texture2D = load_png("props/%s/prop_%d" % [MAPS[clampi(map_id, 0, 3)], i])
        if texture_value != null:
            textures.append(texture_value)
    if textures.is_empty():
        return
    var layer: Node2D = Node2D.new()
    layer.name = "HDMapDecorations"
    layer.z_index = 1
    world.add_child(layer)
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 83631 + map_id * 7919
    var bounds: Rect2 = SurvivorMaps.movement_bounds(map_id)
    var count: int = 12 if map_id == SurvivorMaps.CLASSIC else 28
    for i: int in range(count):
        var sprite: Sprite2D = Sprite2D.new()
        sprite.texture = textures[i % textures.size()]
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        var side: int = i % 4
        var t: float = (floorf(float(i) / 4.0) + rng.randf_range(0.3, 0.7)) / ceilf(float(count) / 4.0)
        var inset: float = rng.randf_range(10.0, 22.0)
        if side == 0 or side == 2:
            sprite.position = Vector2(lerpf(bounds.position.x + 20.0, bounds.end.x - 20.0, t), bounds.position.y + inset if side == 0 else bounds.end.y - inset)
        else:
            sprite.position = Vector2(bounds.position.x + inset if side == 1 else bounds.end.x - inset, lerpf(bounds.position.y + 20.0, bounds.end.y - 20.0, t))
        sprite.scale = Vector2.ONE * fit(sprite.texture, rng.randf_range(22.0, 38.0))
        sprite.flip_h = rng.randf() < 0.5
        sprite.modulate = Color(1.0, 1.0, 1.0, 0.78)
        layer.add_child(sprite)
