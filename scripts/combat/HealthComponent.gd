extends Node
class_name HealthComponent
## Generic health pool, usable by the player or any enemy/boss later.
## Knows nothing about combat, hitboxes, or how damage is dealt.

signal health_changed(current: float, max: float)
signal damaged(amount: float)
signal died

@export var max_health: float = 100.0

var current_health: float
## True while any invulnerability source is active. take_damage() no-ops
## entirely while true. Reference-counted (see add/remove_invulnerability)
## rather than a plain settable bool, so two independent sources - e.g.
## PlayerVeyrStep's transition window and a post-hit grace window from
## the HURT state - can overlap without one ending early and cancelling
## the other.
var is_invulnerable: bool:
	get:
		return _invulnerability_sources > 0

var _invulnerability_sources: int = 0


func _ready() -> void:
	current_health = max_health


## Adds one invulnerability source. Call remove_invulnerability() exactly
## once per add() - see is_invulnerable.
func add_invulnerability() -> void:
	_invulnerability_sources += 1


func remove_invulnerability() -> void:
	_invulnerability_sources = maxi(_invulnerability_sources - 1, 0)


func take_damage(amount: float) -> void:
	if amount <= 0.0 or is_dead() or is_invulnerable:
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
