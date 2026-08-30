extends Area2D
class_name PlayerTrigger
## Small, generic "the player entered this zone" signal emitter. Reused
## across the vertical slice for narrative cues (reveal/memory/Rhaek) and
## fall-safety kill zones - deliberately minimal (one signal, one
## optional one-shot flag). NOT a general-purpose event/quest/sequence
## framework: each usage site just connects `triggered` and does its own
## small thing.

signal triggered

## true (default): fires once, then stops detecting further entries -
## what narrative cues want. Kill zones set this false, since they
## should fire every time the player falls into one.
@export var one_shot: bool = true

var _fired: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player's physical body layer (see ARCHITECTURE.md §6)
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if one_shot and _fired:
		return
	if not body.is_in_group("player"):
		return
	_fired = true
	triggered.emit()
	if one_shot:
		# Godot blocks mutating monitoring synchronously from within the
		# body_entered signal it's driving - defer it (same class of issue
		# as the post-hit invulnerability fix in docs/PROGRESS.md Step 15).
		set_deferred("monitoring", false)
