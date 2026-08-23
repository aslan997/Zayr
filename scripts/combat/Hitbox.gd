extends Area2D
class_name Hitbox
## Active damage-dealing region. Starts disabled - the owning entity's
## attack logic calls activate()/deactivate() to open/close the timing
## window (see docs/COMBAT.md "explicit attack timing windows"). Not
## wired to any attack yet; this is the reusable primitive only.

signal hit_landed(hurtbox: Hurtbox)

@export var damage: float = 10.0

## Hurtboxes already hit during the current activation, so one swing can't
## multi-hit the same target across several overlapping physics frames.
var _hit_this_activation: Array[Hurtbox] = []


func _ready() -> void:
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)


func activate() -> void:
	_hit_this_activation.clear()
	monitoring = true


func deactivate() -> void:
	monitoring = false


func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox and area not in _hit_this_activation:
		_hit_this_activation.append(area)
		area.receive_hit(damage, self)
		hit_landed.emit(area)
