extends Node
class_name PlayerVeyrStep
## Zayr's Veyr Step: an instantaneous 8-directional blink, deliberately
## NOT a faster/second dash (see docs/COMBAT.md). Teleports immediately
## with no traveled motion, in the direction held at the moment of
## activation (falls back to Movement.facing with no directional input
## held). Briefly makes Zayr invulnerable and hides his visual, and draws
## a short fading trail between the old and new position plus a small
## geometric "shatter" burst at the departure point and a "reform" burst
## at the arrival point. Works identically on the ground or in the air.
##
## Can interrupt an in-progress dash or attack - that's the point
## ("emergency repositioning") - but only as a one-time reset via
## PlayerMovement.cancel_dash()/PlayerCombat.cancel_attack(), not a full
## attack-cancel-window system (deliberately not built yet).
##
## A straight-line safety check (CharacterBody2D.move_and_collide in
## test-only mode) clamps the teleport short of any wall it would
## otherwise land inside.
##
## Also owns Perfect Step (see docs/COMBAT.md): if an enemy Hitbox would
## have hit Zayr's own Hurtbox during the invulnerability window (that's
## what Hurtbox.hit_avoided means - detected via the existing Hitbox/
## Hurtbox overlap system, not a separate check), reward the precisely-
## timed evade with a stronger burst, a brief hitstop, a meaningful Veyr
## refund (deliberately the largest single Veyr gain in the kit - see
## PlayerCombat.gd's smaller per-hit melee restores - since Perfect Step
## represents mastery of Zayr's Veyr manipulation, per docs/COMBAT.md's
## combat economy), and an optional audio cue. Does not teleport again,
## does not attack, does not extend invulnerability, and needs no
## separate input - it's purely a reactive bonus layered onto a normal
## step.

@onready var body: CharacterBody2D = get_parent()
@onready var movement: PlayerMovement = get_parent().get_node("Movement")
@onready var combat: PlayerCombat = get_parent().get_node("Combat")
@onready var ranged_attack: PlayerRangedAttack = get_parent().get_node("RangedAttack")
@onready var health: HealthComponent = get_parent().get_node("HealthComponent")
@onready var hurtbox: Hurtbox = get_parent().get_node("Hurtbox")
@onready var veyr: VeyrComponent = get_parent().get_node("VeyrComponent")
## Hides the whole production VisualRoot (not the debug rectangle - see
## PlayerController.show_debug_visual) for the step's duration.
@onready var visual: Node2D = get_parent().get_node("VisualRoot")
@onready var trail: Line2D = get_parent().get_node("TrailLine")
@onready var depart_burst: Polygon2D = get_parent().get_node("DepartBurst")
@onready var arrive_burst: Polygon2D = get_parent().get_node("ArriveBurst")
@onready var depart_particles: GPUParticles2D = get_parent().get_node("DepartParticles")
@onready var arrive_particles: GPUParticles2D = get_parent().get_node("ArriveParticles")
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

@export_group("Veyr Step")
## Deliberately shorter than the normal dash's 130px - a repositioning
## tool, not extra mobility range.
@export var step_distance: float = 90.0
## How long the transition lasts: Zayr is invulnerable, hidden, and the
## trail/bursts are visible/fading for this whole window. Very short by
## design - this is meant to read as instantaneous, not as travel.
@export var step_duration: float = 0.1
## Recovery before Veyr Step can be used again.
@export var step_cooldown: float = 0.55
## Boosted above 1.0 so it actually catches the vertical slice's
## WorldEnvironment glow (see docs/PROGRESS.md art pass) - values >1.0
## are valid HDR overshoot for 2D CanvasItem colors, not a mistake.
@export var trail_color: Color = Color(0.72, 0.53, 1.3)
@export var trail_width: float = 4.0
## The departure burst shrinks from this scale to burst_end_scale (a
## "shatter"); the arrival burst grows from burst_end_scale to this scale
## (a "reform"), both fading out over step_duration at the same time.
@export var burst_start_scale: float = 1.3
@export var burst_end_scale: float = 0.2

@export_group("Perfect Step")
## How long after activation an avoided hit still counts as "perfect".
## Independently tunable from step_duration (defaults to the same span)
## so detection can later be narrowed to reward genuinely precise timing
## without touching the invulnerability window itself.
@export var perfect_detection_window: float = 0.1
## Brief hitstop rewarding the evade - deliberately separate values from
## PlayerCombat's own hitstop, and deliberately short (not an extended
## slow-motion effect).
@export var perfect_hitstop_duration: float = 0.05
@export_range(0.0, 1.0) var perfect_hitstop_time_scale: float = 0.05
## Multiplies the normal depart/arrive burst scale on a perfect step.
@export var perfect_burst_scale_multiplier: float = 1.6
## Not from the design brief - placeholder, tunable.
@export var perfect_veyr_restore: float = 15.0
## No audio system exists in this project yet (see docs/COMBAT.md) - this
## is a ready hook, not a system: assign a stream to hear a cue, leave it
## empty (default) and Perfect Step stays silent.
@export var perfect_audio_cue: AudioStream = null

var is_stepping: bool = false

var _step_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _perfect_detection_timer: float = 0.0
var _perfect_triggered_this_step: bool = false
var _perfect_burst_bonus: float = 1.0


func _ready() -> void:
	trail.width = trail_width
	trail.default_color = trail_color
	trail.clear_points()
	trail.modulate.a = 0.0

	for burst in [depart_burst, arrive_burst]:
		burst.color = trail_color
		burst.visible = false
		burst.modulate.a = 0.0

	hurtbox.hit_avoided.connect(_on_hit_avoided)


func physics_update(delta: float, aim_x: float, aim_y: float, step_just_pressed: bool) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)

	if step_just_pressed and not is_stepping and _cooldown_timer <= 0.0:
		_do_step(aim_x, aim_y)
		return

	if is_stepping:
		_step_timer -= delta
		_perfect_detection_timer = maxf(_perfect_detection_timer - delta, 0.0)
		var progress: float = 1.0 - clampf(_step_timer / step_duration, 0.0, 1.0)
		var fade: float = 1.0 - progress
		trail.modulate.a = fade
		depart_burst.modulate.a = fade
		depart_burst.scale = Vector2.ONE * lerpf(burst_start_scale, burst_end_scale, progress) * _perfect_burst_bonus
		arrive_burst.modulate.a = fade
		arrive_burst.scale = Vector2.ONE * lerpf(burst_end_scale, burst_start_scale, progress) * _perfect_burst_bonus
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
	ranged_attack.cancel_attack()

	is_stepping = true
	_step_timer = step_duration
	_cooldown_timer = step_cooldown
	_perfect_detection_timer = perfect_detection_window
	_perfect_triggered_this_step = false
	_perfect_burst_bonus = 1.0
	health.add_invulnerability()
	visual.visible = false

	trail.clear_points()
	trail.add_point(start_pos)
	trail.add_point(body.global_position)
	trail.modulate.a = 1.0

	depart_burst.global_position = start_pos
	depart_burst.scale = Vector2.ONE * burst_start_scale
	depart_burst.modulate.a = 1.0
	depart_burst.visible = true

	arrive_burst.global_position = body.global_position
	arrive_burst.scale = Vector2.ONE * burst_end_scale
	arrive_burst.modulate.a = 1.0
	arrive_burst.visible = true

	# Complementary particle bursts alongside the existing polygon shapes -
	# additive, not a replacement, so the tested scale/alpha tween logic
	# above is untouched (see docs/PROGRESS.md art pass Stage D).
	depart_particles.global_position = start_pos
	depart_particles.restart()
	arrive_particles.global_position = body.global_position
	arrive_particles.restart()


func _end_step() -> void:
	is_stepping = false
	health.remove_invulnerability()
	visual.visible = true
	trail.modulate.a = 0.0
	depart_burst.visible = false
	arrive_burst.visible = false


func _on_hit_avoided(_damage: float, _hitbox: Hitbox) -> void:
	if not is_stepping or _perfect_triggered_this_step or _perfect_detection_timer <= 0.0:
		return
	_perfect_triggered_this_step = true
	_trigger_perfect_step()


func _trigger_perfect_step() -> void:
	_perfect_burst_bonus = perfect_burst_scale_multiplier
	veyr.add(perfect_veyr_restore)
	if perfect_audio_cue:
		audio_player.stream = perfect_audio_cue
		audio_player.play()
	_apply_perfect_hitstop()


func _apply_perfect_hitstop() -> void:
	Engine.time_scale = perfect_hitstop_time_scale
	await body.get_tree().create_timer(perfect_hitstop_duration, true, false, true).timeout
	Engine.time_scale = 1.0
