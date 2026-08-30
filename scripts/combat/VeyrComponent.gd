extends Node
class_name VeyrComponent
## Veyr resource pool - NOT conventional mana (see docs/COMBAT.md).
## Deliberately stays a dumb pool: spend()/add(), clamped to
## [0, max_veyr]. No passive regeneration lives here and none should be
## added - Veyr is meant to regain only through aggressive/skilled play
## (successful melee hits, Perfect Step), not by standing still. Each of
## those event sources calls add() on itself at the moment it happens -
## see PlayerCombat.gd ("Veyr Regeneration" export group, called from
## _on_hitbox_hit_landed) and PlayerVeyrStep.gd (_trigger_perfect_step).
## PlayerRangedAttack.gd deliberately never calls add() here, so ranged
## Veyr attacks cannot refund their own cost.

signal veyr_changed(current: float, max: float)

@export var max_veyr: float = 100.0

var current_veyr: float


func _ready() -> void:
	current_veyr = max_veyr


func can_spend(amount: float) -> bool:
	return amount >= 0.0 and current_veyr >= amount


func spend(amount: float) -> bool:
	if not can_spend(amount):
		return false
	current_veyr -= amount
	veyr_changed.emit(current_veyr, max_veyr)
	return true


func add(amount: float) -> void:
	if amount <= 0.0:
		return
	current_veyr = minf(current_veyr + amount, max_veyr)
	veyr_changed.emit(current_veyr, max_veyr)
