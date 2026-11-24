extends RefCounted
class_name SurvivorNodePool

var available: Array[Node2D] = []
var capacity: int = 128
var created: int = 0
var reused: int = 0
var active: Dictionary = {}
var peak_active: int = 0
var discarded: int = 0

func acquire(scene: PackedScene, parent: Node) -> Node2D:
    while not available.is_empty():
        var item: Node2D = available.pop_back()
        if is_instance_valid(item) and not item.is_queued_for_deletion():
            item.show()
            item.process_mode = Node.PROCESS_MODE_INHERIT
            reused += 1
            _mark_active(item)
            return item
    var fresh: Node2D = scene.instantiate() as Node2D
    parent.add_child(fresh)
    created += 1
    _mark_active(fresh)
    return fresh

func release(item: Node2D) -> void:
    if not is_instance_valid(item) or not active.has(item.get_instance_id()):
        return
    active.erase(item.get_instance_id())
    item.hide()
    item.process_mode = Node.PROCESS_MODE_DISABLED
    if available.size() >= capacity:
        discarded += 1
        item.queue_free()
    else:
        available.append(item)


func _mark_active(item: Node2D) -> void:
    active[item.get_instance_id()] = true
    peak_active = maxi(peak_active, active.size())


func metrics() -> Dictionary:
    return {"created": created, "reused": reused, "active": active.size(), "peak_active": peak_active, "idle": available.size(), "discarded": discarded}
