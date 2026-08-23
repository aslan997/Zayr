extends Node
class_name PlayerMovement
## Owns all player movement tuning and physics math.
## Knows nothing about input mapping, state machines, or combat -
## PlayerController calls physics_update() once per physics frame.

@onready var body: CharacterBody2D = get_parent()

@export_group("Horizontal Movement")
@export var run_speed: float = 240.0
@export var ground_acceleration: float = 1800.0
@export var ground_deceleration: float = 2200.0
@export_range(0.0, 1.0) var air_control: float = 0.7

@export_group("Vertical Movement")
@export var gravity: float = 1400.0
@export var jump_velocity: float = -500.0
@export var max_fall_speed: float = 900.0

@export_group("Jump Assist")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export_group("Wall Movement")
@export var wall_slide_speed: float = 120.0
@export var wall_jump_velocity_y: float = -460.0
## Horizontal push-off speed on wall jump. Not specified in the original
## design brief (only vertical velocity was given) - inferred from
## run_speed and exposed here for tuning.
@export var wall_jump_horizontal_speed: float = 240.0
@export var wall_jump_input_lock_time: float = 0.12

@export_group("Dash")
@export var dash_distance: float = 130.0
@export var dash_duration: float = 0.16
## Not specified in the original design brief - minimal anti-spam recovery
## time after a dash ends, exposed for tuning (0 to disable).
@export var dash_cooldown: float = 0.2
@export var air_dash_enabled: bool = true

var is_wall_sliding: bool = false
var just_wall_jumped: bool = false
var is_dashing: bool = false
var dash_is_air: bool = false
var air_dash_available: bool = true

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _wall_jump_lock_timer: float = 0.0
var _wall_normal_x: float = 0.0
var _facing: float = 1.0
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: float = 1.0


func physics_update(delta: float, move_input: float, jump_just_pressed: bool, dash_just_pressed: bool) -> void:
	just_wall_jumped = false
	_update_timers(delta, jump_just_pressed)
	_dash_cooldown_timer = max(_dash_cooldown_timer - delta, 0.0)

	if move_input != 0.0:
		_facing = signf(move_input)

	var on_floor: bool = body.is_on_floor()

	if on_floor:
		air_dash_available = true

	if is_dashing:
		_process_dash(delta)
		body.move_and_slide()
		return

	if dash_just_pressed and _dash_cooldown_timer <= 0.0 and (on_floor or (air_dash_enabled and air_dash_available)):
		_start_dash(on_floor)
		_process_dash(delta)
		body.move_and_slide()
		return

	var on_wall: bool = body.is_on_wall() and not on_floor

	is_wall_sliding = false

	if on_wall:
		_wall_normal_x = body.get_wall_normal().x

	# Wall jump takes priority over a normal jump while airborne against a wall.
	if on_wall and _jump_buffer_timer > 0.0:
		_do_wall_jump()
	elif _jump_buffer_timer > 0.0 and (on_floor or _coyote_timer > 0.0):
		_do_jump()
	else:
		_apply_gravity(delta)

	if on_wall and not on_floor and body.velocity.y > 0.0 and _wall_jump_lock_timer <= 0.0:
		is_wall_sliding = true
		body.velocity.y = min(body.velocity.y, wall_slide_speed)

	if _wall_jump_lock_timer <= 0.0:
		_apply_horizontal(delta, move_input, on_floor)

	body.move_and_slide()


func _start_dash(on_floor: bool) -> void:
	is_dashing = true
	dash_is_air = not on_floor
	_dash_timer = dash_duration
	_dash_direction = _facing
	if not on_floor:
		air_dash_available = false


func _process_dash(delta: float) -> void:
	_dash_timer -= delta
	body.velocity = Vector2(_dash_direction * (dash_distance / dash_duration), 0.0)
	if _dash_timer <= 0.0:
		is_dashing = false
		_dash_cooldown_timer = dash_cooldown


func _update_timers(delta: float, jump_just_pressed: bool) -> void:
	if body.is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

	if jump_just_pressed:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	_wall_jump_lock_timer = max(_wall_jump_lock_timer - delta, 0.0)


func _apply_gravity(delta: float) -> void:
	body.velocity.y = min(body.velocity.y + gravity * delta, max_fall_speed)


func _do_jump() -> void:
	body.velocity.y = jump_velocity
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0


func _do_wall_jump() -> void:
	body.velocity.y = wall_jump_velocity_y
	body.velocity.x = _wall_normal_x * wall_jump_horizontal_speed
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_wall_jump_lock_timer = wall_jump_input_lock_time
	just_wall_jumped = true


func _apply_horizontal(delta: float, move_input: float, on_floor: bool) -> void:
	var target_speed: float = move_input * run_speed
	var accel: float = ground_acceleration if on_floor else ground_acceleration * air_control
	var decel: float = ground_deceleration if on_floor else ground_deceleration * air_control

	if move_input != 0.0:
		body.velocity.x = move_toward(body.velocity.x, target_speed, accel * delta)
	else:
		body.velocity.x = move_toward(body.velocity.x, 0.0, decel * delta)
