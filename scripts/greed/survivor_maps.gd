extends RefCounted
class_name SurvivorMaps

const CLASSIC: int = 0
const EXPLORATION: int = 1
const NIGHT: int = 2
const SWAMP: int = 3
const NAMES_EN: Array[String] = ["Classic", "Forest", "Night Garden", "Swamp"]
const NAMES_ZH: Array[String] = ["经典", "森林", "夜间花园", "沼泽"]
const VIEW_SIZE: Vector2 = Vector2(640.0, 360.0)
const EXPLORATION_SIZE: Vector2 = Vector2(1280.0, 720.0)
const CLASSIC_MOVEMENT: Rect2 = Rect2(17.0, 43.0, 606.0, 275.0)
static var selected: int = CLASSIC

static func world_size(map_id: int) -> Vector2:
    return EXPLORATION_SIZE if map_id != CLASSIC else VIEW_SIZE

static func movement_bounds(map_id: int) -> Rect2:
    return Rect2(Vector2(18.0, 18.0), EXPLORATION_SIZE - Vector2(36.0, 36.0)) if map_id != CLASSIC else CLASSIC_MOVEMENT

static func spawn_area(map_id: int, camera_center: Vector2) -> Rect2:
    if map_id == CLASSIC:
        return Rect2(12.0, 44.0, 616.0, 275.0)
    # Use the visible viewport perimeter with an outer margin, clipped to map.
    var area: Rect2 = Rect2(camera_center - VIEW_SIZE * 0.5, VIEW_SIZE).grow(24.0)
    return area.intersection(Rect2(Vector2(12.0, 12.0), EXPLORATION_SIZE - Vector2(24.0, 24.0)))

static func clamp_spawn(map_id: int, position_value: Vector2) -> Vector2:
    if map_id == CLASSIC:
        return position_value
    return position_value.clamp(Vector2(12.0, 12.0), EXPLORATION_SIZE - Vector2(12.0, 12.0))


static func exclusive_variant(map_id: int) -> int:
    match map_id:
        EXPLORATION:
            return 2
        NIGHT:
            return 1
        SWAMP:
            return 3
    return 0
