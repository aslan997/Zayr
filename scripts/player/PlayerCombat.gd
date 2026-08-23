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
## Also owns the heavy attack (see docs/COMBAT.md): a single, slower,
## more deliberate swing - not part of the 3-hit combo, mutually
## exclusive with it (can't start one while the other is active), reusing
## the same Hitbox/SwingVisual rather than a second set of nodes. Zayr is
## fully vulnerable through its startup/active/recovery - it grants no
## invulnerability of its own.
##
## Charged attacks, aerial attacks, and the ranged Veyr attack are not
## implemented - this also does not lock or interrupt movement/dash on
## its own (Veyr Step can interrupt either attack via cancel_attack()), a
## known simplification until full combo/interrupt rules are designed.

const COMBO_LENGTH: int = 3

@onready var body: CharacterBody2D = get_parent()
@onready var movement: PlayerMovement = get_parent().get_node("Movement")
@onready var veyr: VeyrComponent = get_parent().get_node("VeyrComponent")
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
## Per-swing stability damage dealt to enemies (see docs/COMBAT.md's
## StabilityComponent). Not from the design brief - placeholder, tunable.
## Deliberately small: normal attacks shouldn't reliably stagger on their
## own, unlike the heavy attack below.
@export var stability_damages: PackedFloat32Array = [6.0, 6.0, 8.0]
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

@export_group("Heavy Attack")
## Visible charge before the hitbox opens - deliberately much longer than
## a combo swing's windup, per docs/COMBAT.md ("not an instant
## high-damage attack").
@export var heavy_startup: float = 0.5
@export var heavy_active_duration: float = 0.2
@export var heavy_recovery: float = 0.35
## Recovery after the swing ends before another attack (of either kind)
## can start.
@export var heavy_cooldown: float = 0.4
## Not from the design brief - placeholder, tunable. Significantly more
## than a combo swing, per "deal significantly more damage."
@export var heavy_damage: float = 32.0
## Substantial relative to StabilityComponent's default max (50) - meant
## to be able to break a regular enemy's stability in one hit, per
## "break enemy defenses."
@export var heavy_stability_damage: float = 40.0
@export var heavy_hit_offset: float = 30.0
@export var heavy_color: Color = Color(1.0, 0.5, 0.15)
## Off by default per the design brief ("should NOT consume Veyr...
## unless architecture makes it particularly appropriate") - flip on and
## set heavy_veyr_cost to change that later without touching this system.
@export var heavy_consumes_veyr: bool = false
@export var heavy_veyr_cost: float = 20.0

var is_attacking: bool = false
## 0-based index of the swing currently playing (or last played).
var combo_index: int = 0
var is_heavy_attacking: bool = false

var _attack_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _hitbox_opened: bool = false
var _hitbox_closed: bool = false
var _queued_next: bool = false
var _heavy_timer: float = 0.0
var _heavy_hitbox_opened: bool = false
var _heavy_cooldown_timer: float = 0.0


func _ready() -> void:
	hitbox.hit_landed.connect(_on_hitbox_hit_landed)


func physics_update(delta: float, attack_just_pressed: bool, heavy_attack_just_pressed: bool) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	_heavy_cooldown_timer = maxf(_heavy_cooldown_timer - delta, 0.0)

	if is_heavy_attacking:
		_process_heavy_attack(delta)
		return

	if heavy_attack_just_pressed and not is_attacking and _heavy_cooldown_timer <= 0.0:
		_start_heavy_attack()
		return

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
	hitbox.stability_damage = stability_damages[combo_index]
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


func _start_heavy_attack() -> void:
	if heavy_consumes_veyr:
		if not veyr.can_spend(heavy_veyr_cost):
			return
		veyr.spend(heavy_veyr_cost)

	is_heavy_attacking = true
	_heavy_timer = 0.0
	_heavy_hitbox_opened = false
	hitbox.position.x = heavy_hit_offset * movement.facing
	hitbox.scale.x = movement.facing
	hitbox.damage = heavy_damage
	hitbox.stability_damage = heavy_stability_damage
	swing_visual.color = heavy_color
	swing_visual.visible = true
	swing_visual.modulate.a = 1.0


func _process_heavy_attack(delta: float) -> void:
	_heavy_timer += delta
	var active_end: float = heavy_startup + heavy_active_duration
	var total: float = active_end + heavy_recovery

	if not _heavy_hitbox_opened and _heavy_timer >= heavy_startup:
		_heavy_hitbox_opened = true
		hitbox.activate()

	if _heavy_hitbox_opened and hitbox.monitoring and _heavy_timer >= active_end:
		hitbox.deactivate()

	if _heavy_timer < active_end:
		swing_visual.modulate.a = 1.0
	else:
		var fade_span: float = maxf(total - active_end, 0.001)
		swing_visual.modulate.a = 1.0 - clampf((_heavy_timer - active_end) / fade_span, 0.0, 1.0)

	if _heavy_timer >= total:
		is_heavy_attacking = false
		swing_visual.visible = false
		hitbox.deactivate()
		_heavy_cooldown_timer = heavy_cooldown


## Forcibly ends an in-progress attack of either kind (used by systems
## that can interrupt combat, e.g. PlayerVeyrStep). Leaves things reset
## and on cooldown, same as an attack ending normally.
func cancel_attack() -> void:
	if is_heavy_attacking:
		is_heavy_attacking = false
		hitbox.deactivate()
		swing_visual.visible = false
		_heavy_cooldown_timer = heavy_cooldown
		return

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
