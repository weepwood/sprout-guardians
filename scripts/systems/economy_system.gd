extends Node
class_name EconomySystem

signal coins_changed(value: int, delta: int, reason: StringName)
signal transaction_rejected(required: int, available: int, reason: StringName)

var coins: int = 0


func setup(starting_coins: int) -> void:
    coins = maxi(0, starting_coins)
    coins_changed.emit(coins, 0, &"setup")


func can_afford(amount: int) -> bool:
    return amount >= 0 and coins >= amount


func spend(amount: int, reason: StringName = &"purchase") -> bool:
    if amount < 0 or not can_afford(amount):
        transaction_rejected.emit(amount, coins, reason)
        return false
    coins -= amount
    coins_changed.emit(coins, -amount, reason)
    return true


func earn(amount: int, reason: StringName = &"reward") -> void:
    if amount <= 0:
        return
    coins += amount
    coins_changed.emit(coins, amount, reason)
