extends Node
class_name PlayerCombat
## Zayr's Veyr Edge combo: 3 swings (see docs/COMBAT.md). Reads
## Movement.facing to aim the Hitbox each swing and drives the placeholder
## swing visual. Pressing attack again while a swing is playing queues the
## next swing, resolved the instant the current one ends (no gap between
## chained swings). If nothing is queued when the final swing ends - or a
## press comes in after the final swing already landed - the combo resets
## to swing 1 and the usual cooldown applies before another attack can
## start; the combo does not instantly loop into itself.
## Heavy/charged attacks, aerial attacks, and the ranged Veyr attack are
## not implemented - this also does not lock or interrupt movement/dash,
## a known simplification until combo/interrupt rules are designed.

const COMBO_LENGTH: int = 3

@onready var body: CharacterBody2D = get_parent()
@onready var movement: PlayerMovement = get_parent().get_node("Movement")
@onready var hitbox: Hitbox = get_parent().get_node("Hitbox")
@onready var swing_visual: Polygon2D = hitbox.get_node("SwingVisual")

@export_group("Veyr Edge Combo")
## Per-swing total duration (index 0..2 = swing 1..3), from swing start
## until it either chains into the next swing or ends.
@export var swing_durations: PackedFloat32Array = [0.35, 0.32, 0.42]
## Per-swing delay before the hitbox becomes active (windup).
@export var hitbox_start_times: PackedFloat32Array = [0.08, 0.07, 0.1]
## Per-swing time the hitbox deactivates again (must be > the matching
## hitbox_start_times entry).
@export var hitbox_end_times: PackedFloat32Array = [0.18, 0.16, 0.24]
## Per-swing damage. Not from the design brief (exact combat balance is
## still TBD per docs/COMBAT.md) - placeholder, tunable.
@export var damages: PackedFloat32Array = [12.0, 12.0, 20.0]
## Per-swing placeholder swing-visual color, purely to make the combo's
## progress readable before real VFX exists.
@export var swing_colors: Array[Color] = [
	Color(0.6, 0.95, 1.0),
	Color(0.55, 0.8, 1.0),
	Color(0.9, 0.75, 1.0),
]
## How far in front of Zayr (in his facing direction) the hitbox is placed.
@export var hit_offset: float = 26.0
## Recovery after the combo ends (fully, or because nothing was queued
## in time) before a fresh attack can start.
@export var attack_cooldown: float = 0.1

@export_group("Hitstop")
@export var hitstop_duration: float = 0.06
@export_range(0.0, 1.0) var hitstop_time_scale: float = 0.05

var is_attacking: bool = false
## 0-based index of the swing currently playing (or last played).
var combo_index: int = 0

var _attack_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _hitbox_opened: bool = false
var _hitbox_closed: bool = false
var _queued_next: bool = false


func _ready() -> void:
	hitbox.hit_landed.connect(_on_hitbox_hit_landed)


func physics_update(delta: float, attack_just_pressed: bool) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)

	if attack_just_pressed:
		if is_attacking:
			_queued_next = true
		elif _cooldown_timer <= 0.0:
			combo_index = 0
			_start_swing()

	if is_attacking:
		_process_swing(delta)


func _start_swing() -> void:
	is_attacking = true
	_attack_timer = 0.0
	_hitbox_opened = false
	_hitbox_closed = false
	_queued_next = false
	hitbox.position.x = hit_offset * movement.facing
	hitbox.scale.x = movement.facing
	hitbox.damage = damages[combo_index]
	swing_visual.color = swing_colors[combo_index]
	swing_visual.visible = true
	swing_visual.modulate.a = 1.0


func _process_swing(delta: float) -> void:
	_attack_timer += delta
	var start_t: float = hitbox_start_times[combo_index]
	var end_t: float = hitbox_end_times[combo_index]
	var duration: float = swing_durations[combo_index]

	if not _hitbox_opened and _attack_timer >= start_t:
		_hitbox_opened = true
		hitbox.activate()

	if _hitbox_opened and not _hitbox_closed and _attack_timer >= end_t:
		_hitbox_closed = true
		hitbox.deactivate()

	if _attack_timer < end_t:
		swing_visual.modulate.a = 1.0
	else:
		var fade_span: float = maxf(duration - end_t, 0.001)
		swing_visual.modulate.a = 1.0 - clampf((_attack_timer - end_t) / fade_span, 0.0, 1.0)

	if _attack_timer >= duration:
		is_attacking = false
		swing_visual.visible = false
		hitbox.deactivate()
		_advance_or_end_combo()


func _advance_or_end_combo() -> void:
	var has_next_swing: bool = combo_index < COMBO_LENGTH - 1
	if _queued_next and has_next_swing:
		combo_index += 1
		_start_swing()
	else:
		# Either the combo is done, or a press queued during the final
		# swing - either way, don't instantly loop back into swing 1;
		# require the normal cooldown first.
		combo_index = 0
		_queued_next = false
		_cooldown_timer = attack_cooldown


## Forcibly ends an in-progress swing (used by systems that can interrupt
## combat, e.g. PlayerVeyrStep). Leaves the combo reset and on cooldown,
## same as a swing ending normally without a queued follow-up.
func cancel_attack() -> void:
	if not is_attacking:
		return
	is_attacking = false
	hitbox.deactivate()
	swing_visual.visible = false
	combo_index = 0
	_queued_next = false
	_cooldown_timer = attack_cooldown


func _on_hitbox_hit_landed(_hurtbox: Hurtbox) -> void:
	_apply_hitstop()


func _apply_hitstop() -> void:
	Engine.time_scale = hitstop_time_scale
	await body.get_tree().create_timer(hitstop_duration, true, false, true).timeout
	Engine.time_scale = 1.0
