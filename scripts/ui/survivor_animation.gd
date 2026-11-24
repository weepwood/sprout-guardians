extends RefCounted
class_name SurvivorAnimation

enum State { IDLE, MOVE, ATTACK, HIT, DEATH }
const FRAMES: int = 4
const CELL: int = 36
const SPROUT_SHEET: Texture2D = preload("res://assets/generated/animations/hero_0.png")
static var _sheets: Dictionary = {}
static var _frames: Dictionary = {}

static func state(hero: GreedHeroPlant) -> int:
    if hero.health <= 0:
        return State.DEATH
    if float(hero.get("_hit_flash")) > 0.0:
        return State.HIT
    if float(hero.get("_shot_time")) > 0.0:
        return State.ATTACK
    if hero.arcade_direction.length_squared() > 0.0:
        return State.MOVE
    return State.IDLE

# Valid PNG sheets are optional; never import promotional composites.
static func frame(character_id: int, animation_state: int, elapsed: float) -> Texture2D:
    if not _sheets.has(character_id):
        var path: String = "res://assets/generated/animations/hero_%d.png" % character_id
        var sheet: Texture2D = SPROUT_SHEET if character_id == 0 or character_id >= 3 else (load(path) as Texture2D if ResourceLoader.exists(path) else null)
        if sheet != null and sheet.get_size() != Vector2(CELL * FRAMES, CELL * 5):
            sheet = null
        _sheets[character_id] = sheet
    var texture_value: Texture2D = _sheets[character_id] as Texture2D
    if texture_value == null:
        return null
    var one_shot: bool = animation_state >= State.ATTACK
    var index: int = floori(maxf(0.0, elapsed) * (16.0 if one_shot else 9.0))
    var frame_index: int = mini(index, FRAMES - 1) if one_shot else posmod(index, FRAMES)
    var key: String = "%d:%d:%d" % [character_id, animation_state, frame_index]
    if not _frames.has(key):
        var region: AtlasTexture = AtlasTexture.new()
        region.atlas = texture_value
        region.region = Rect2(frame_index * CELL, clampi(animation_state, 0, 4) * CELL, CELL, CELL)
        region.filter_clip = true
        _frames[key] = region
    return _frames[key] as Texture2D
