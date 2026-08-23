extends CharacterBody2D
class_name PlayerController
## Reads input, drives the state machine, and delegates physics math to
## the Movement component. Combat/health/abilities will be added later as
## sibling components without this file absorbing their responsibilities.

enum State { IDLE, RUN, JUMP, FALL, WALL_SLIDE }

## Temporary debug tint per state, so state transitions are visible before
## real animations exist. Safe to delete once an AnimationPlayer/AnimatedSprite
## drives visuals instead.
const STATE_DEBUG_COLOR: Dictionary = {
	State.IDLE: Color(0.55, 0.75, 0.95),
	State.RUN: Color(0.4, 0.9, 0.55),
	State.JUMP: Color(0.95, 0.85, 0.35),
	State.FALL: Color(0.95, 0.55, 0.3),
	State.WALL_SLIDE: Color(0.8, 0.4, 0.9),
}

@onready var movement: PlayerMovement = $Movement
@onready var _debug_visual: Polygon2D = $Visual

var state: State = State.IDLE


func _physics_process(delta: float) -> void:
	var move_input: float = Input.get_axis("move_left", "move_right")
	var jump_just_pressed: bool = Input.is_action_just_pressed("jump")

	movement.physics_update(delta, move_input, jump_just_pressed)

	_update_state(move_input)
	_update_debug_visual()


func _update_state(move_input: float) -> void:
	if movement.is_wall_sliding:
		state = State.WALL_SLIDE
	elif not is_on_floor():
		state = State.JUMP if velocity.y < 0.0 else State.FALL
	elif move_input != 0.0 and absf(velocity.x) > 1.0:
		state = State.RUN
	else:
		state = State.IDLE


func _update_debug_visual() -> void:
	if not _debug_visual:
		return
	_debug_visual.color = STATE_DEBUG_COLOR.get(state, Color.WHITE)
	# Flip only the visual, not the CharacterBody2D itself - flipping the
	# root's scale would also mirror the child Camera2D's view.
	if velocity.x < -1.0:
		_debug_visual.scale.x = -1.0
	elif velocity.x > 1.0:
		_debug_visual.scale.x = 1.0
