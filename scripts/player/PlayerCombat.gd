extends Node
class_name PlayerCombat
## Zayr's first Veyr Edge attack: a single swing, not the 3-hit combo yet
## (see docs/COMBAT.md). Reads Movement.facing to aim the Hitbox and drives
## the placeholder swing visual. Combo chaining, heavy/charged attacks,
## aerial attacks, and the ranged Veyr attack are not implemented - this
## does not lock or interrupt movement/dash, which is a known
## simplification until combo/interrupt rules are designed.

@onready var body: CharacterBody2D = get_parent()
@onready var movement: PlayerMovement = get_parent().get_node("Movement")
@onready var hitbox: Hitbox = get_parent().get_node("Hitbox")
@onready var swing_visual: Polygon2D = hitbox.get_node("SwingVisual")

@export_group("Veyr Edge - Swing 1")
## Total time from swing start until Zayr can act on a new attack input.
@export var attack_duration: float = 0.35
## Delay before the hitbox becomes active (windup).
@export var hitbox_start_time: float = 0.08
## When the hitbox deactivates again (must be greater than hitbox_start_time).
@export var hitbox_end_time: float = 0.18
## Extra recovery after attack_duration before another attack can start.
@export var attack_cooldown: float = 0.1
## How far in front of Zayr (in his facing direction) the hitbox is placed.
@export var hit_offset: float = 26.0

@export_group("Hitstop")
@export var hitstop_duration: float = 0.06
@export_range(0.0, 1.0) var hitstop_time_scale: float = 0.05

var is_attacking: bool = false

var _attack_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _hitbox_opened: bool = false
var _hitbox_closed: bool = false


func _ready() -> void:
	hitbox.hit_landed.connect(_on_hitbox_hit_landed)


func physics_update(delta: float, attack_just_pressed: bool) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)

	if attack_just_pressed and not is_attacking and _cooldown_timer <= 0.0:
		_start_attack()

	if is_attacking:
		_process_attack(delta)


func _start_attack() -> void:
	is_attacking = true
	_attack_timer = 0.0
	_hitbox_opened = false
	_hitbox_closed = false
	hitbox.position.x = hit_offset * movement.facing
	hitbox.scale.x = movement.facing
	swing_visual.visible = true
	swing_visual.modulate.a = 1.0


func _process_attack(delta: float) -> void:
	_attack_timer += delta

	if not _hitbox_opened and _attack_timer >= hitbox_start_time:
		_hitbox_opened = true
		hitbox.activate()

	if _hitbox_opened and not _hitbox_closed and _attack_timer >= hitbox_end_time:
		_hitbox_closed = true
		hitbox.deactivate()

	if _attack_timer < hitbox_end_time:
		swing_visual.modulate.a = 1.0
	else:
		var fade_span: float = maxf(attack_duration - hitbox_end_time, 0.001)
		swing_visual.modulate.a = 1.0 - clampf((_attack_timer - hitbox_end_time) / fade_span, 0.0, 1.0)

	if _attack_timer >= attack_duration:
		is_attacking = false
		swing_visual.visible = false
		hitbox.deactivate()
		_cooldown_timer = attack_cooldown


func _on_hitbox_hit_landed(_hurtbox: Hurtbox) -> void:
	_apply_hitstop()


func _apply_hitstop() -> void:
	Engine.time_scale = hitstop_time_scale
	await body.get_tree().create_timer(hitstop_duration, true, false, true).timeout
	Engine.time_scale = 1.0
