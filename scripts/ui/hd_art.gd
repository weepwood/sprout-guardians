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
