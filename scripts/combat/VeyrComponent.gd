extends Node
class_name VeyrComponent
## Veyr resource pool - NOT conventional mana (see docs/COMBAT.md).
## Regeneration rules ("through active combat") are not yet designed, so
## this only exposes a manual pool API (spend/add). Do not add automatic
## regeneration here until that design is confirmed - see docs/PROGRESS.md.

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
