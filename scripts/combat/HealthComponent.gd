extends Node
class_name HealthComponent
## Generic health pool, usable by the player or any enemy/boss later.
## Knows nothing about combat, hitboxes, or how damage is dealt.

signal health_changed(current: float, max: float)
signal damaged(amount: float)
signal died

@export var max_health: float = 100.0

var current_health: float


func _ready() -> void:
	current_health = max_health


func take_damage(amount: float) -> void:
	if amount <= 0.0 or is_dead():
		return
	current_health = maxf(current_health - amount, 0.0)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	if is_dead():
		died.emit()


func heal(amount: float) -> void:
	if amount <= 0.0 or is_dead():
		return
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return current_health <= 0.0


## Resets health after death (or to top it off at full otherwise).
## Deliberately bypasses the is_dead() guard that take_damage()/heal() use
## - reviving *from* dead is the entire point.
func revive(to_amount: float = -1.0) -> void:
	current_health = max_health if to_amount < 0.0 else clampf(to_amount, 0.0, max_health)
	health_changed.emit(current_health, max_health)
