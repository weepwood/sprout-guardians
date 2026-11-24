extends RefCounted
class_name SurvivorNodePool

var available: Array[Node2D] = []
var capacity: int = 128
var created: int = 0
var reused: int = 0

func acquire(scene: PackedScene, parent: Node) -> Node2D:
    while not available.is_empty():
        var item: Node2D = available.pop_back()
        if is_instance_valid(item) and not item.is_queued_for_deletion():
            item.show()
            item.process_mode = Node.PROCESS_MODE_INHERIT
            reused += 1
            return item
    var fresh: Node2D = scene.instantiate() as Node2D
    parent.add_child(fresh)
    created += 1
    return fresh

func release(item: Node2D) -> void:
    if not is_instance_valid(item) or available.has(item):
        return
    item.hide()
    item.process_mode = Node.PROCESS_MODE_DISABLED
    if available.size() >= capacity:
        item.queue_free()
    else:
        available.append(item)
