extends Node
class_name BaseHealthSystem

signal health_changed(value: int, delta: int)
signal depleted

var health: int = 0
var max_health: int = 0
var _depleted_emitted: bool = false


func setup(starting_health: int) -> void:
    max_health = maxi(1, starting_health)
    health = max_health
    _depleted_emitted = false
    health_changed.emit(health, 0)


func damage(amount: int) -> void:
    if amount <= 0 or health <= 0:
        return
    var previous: int = health
    health = maxi(0, health - amount)
    health_changed.emit(health, health - previous)
    if health <= 0 and not _depleted_emitted:
        _depleted_emitted = true
        depleted.emit()


func heal(amount: int) -> void:
    if amount <= 0 or health <= 0:
        return
    var previous: int = health
    health = mini(max_health, health + amount)
    if health != previous:
        health_changed.emit(health, health - previous)
