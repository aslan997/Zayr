extends Node
class_name PlayerVeyrStep
## Zayr's Veyr Step: an instantaneous 8-directional blink, deliberately
## NOT a faster/second dash (see docs/COMBAT.md). Teleports immediately
## with no traveled motion, in the direction held at the moment of
## activation (falls back to Movement.facing with no directional input
## held). Briefly makes Zayr invulnerable and hides his visual, and draws
## a short fading trail between the old and new position. Works
## identically on the ground or in the air.
##
## Can interrupt an in-progress dash or attack - that's the point
## ("emergency repositioning") - but only as a one-time reset via
## PlayerMovement.cancel_dash()/PlayerCombat.cancel_attack(), not a full
## attack-cancel-window system (deliberately not built yet).
##
## A straight-line safety check (CharacterBody2D.move_and_collide in
## test-only mode) clamps the teleport short of any wall it would
## otherwise land inside.

@onready var body: CharacterBody2D = get_parent()
@onready var movement: PlayerMovement = get_parent().get_node("Movement")
@onready var combat: PlayerCombat = get_parent().get_node("Combat")
@onready var health: HealthComponent = get_parent().get_node("HealthComponent")
@onready var visual: Polygon2D = get_parent().get_node("Visual")
@onready var trail: Line2D = get_parent().get_node("TrailLine")

@export_group("Veyr Step")
## Deliberately shorter than the normal dash's 130px - a repositioning
## tool, not extra mobility range.
@export var step_distance: float = 90.0
## How long the transition lasts: Zayr is invulnerable, hidden, and the
## trail is visible/fading for this whole window. Very short by design -
## this is meant to read as instantaneous, not as travel.
@export var step_duration: float = 0.1
## Recovery before Veyr Step can be used again.
@export var step_cooldown: float = 0.55
@export var trail_color: Color = Color(0.55, 0.4, 1.0)
@export var trail_width: float = 4.0

var is_stepping: bool = false

var _step_timer: float = 0.0
var _cooldown_timer: float = 0.0


func _ready() -> void:
	trail.width = trail_width
	trail.default_color = trail_color
	trail.clear_points()
	trail.modulate.a = 0.0


func physics_update(delta: float, aim_x: float, aim_y: float, step_just_pressed: bool) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)

	if step_just_pressed and not is_stepping and _cooldown_timer <= 0.0:
		_do_step(aim_x, aim_y)
		return

	if is_stepping:
		_step_timer -= delta
		trail.modulate.a = clampf(_step_timer / step_duration, 0.0, 1.0)
		if _step_timer <= 0.0:
			_end_step()


func _do_step(aim_x: float, aim_y: float) -> void:
	var direction: Vector2 = Vector2(aim_x, aim_y)
	if direction.length() < 0.01:
		direction = Vector2(movement.facing, 0.0)
	direction = direction.normalized()

	var start_pos: Vector2 = body.global_position
	var motion: Vector2 = direction * step_distance
	var collision: KinematicCollision2D = body.move_and_collide(motion, true)
	var safe_motion: Vector2 = collision.get_travel() if collision else motion
	body.global_position = start_pos + safe_motion
	body.velocity = Vector2.ZERO

	movement.cancel_dash()
	combat.cancel_attack()

	is_stepping = true
	_step_timer = step_duration
	_cooldown_timer = step_cooldown
	health.is_invulnerable = true
	visual.visible = false

	trail.clear_points()
	trail.add_point(start_pos)
	trail.add_point(body.global_position)
	trail.modulate.a = 1.0


func _end_step() -> void:
	is_stepping = false
	health.is_invulnerable = false
	visual.visible = true
	trail.modulate.a = 0.0
