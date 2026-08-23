extends CharacterBody2D
class_name PlayerController
## Reads input, drives the state machine, and delegates physics math to
## the Movement component. Combat/health/abilities will be added later as
## sibling components without this file absorbing their responsibilities.

enum State { IDLE, RUN, JUMP, FALL, WALL_SLIDE, DASH, AIR_DASH, ATTACK_1, ATTACK_2, ATTACK_3 }

## Temporary debug tint per state, so state transitions are visible before
## real animations exist. Safe to delete once an AnimationPlayer/AnimatedSprite
## drives visuals instead.
const STATE_DEBUG_COLOR: Dictionary = {
	State.IDLE: Color(0.55, 0.75, 0.95),
	State.RUN: Color(0.4, 0.9, 0.55),
	State.JUMP: Color(0.95, 0.85, 0.35),
	State.FALL: Color(0.95, 0.55, 0.3),
	State.WALL_SLIDE: Color(0.8, 0.4, 0.9),
	State.DASH: Color(1.0, 1.0, 1.0),
	State.AIR_DASH: Color(1.0, 0.95, 0.2),
	State.ATTACK_1: Color(0.3, 0.95, 0.85),
	State.ATTACK_2: Color(0.3, 0.75, 0.95),
	State.ATTACK_3: Color(0.85, 0.55, 0.95),
}
## Combo index (PlayerCombat.combo_index) -> the matching attack state.
const COMBO_STATE: Array[State] = [State.ATTACK_1, State.ATTACK_2, State.ATTACK_3]
## Brief white flash on the debug visual when Zayr takes damage, so a hit
## from an enemy is visible before real hurt animations/UI exist.
const HURT_FLASH_DURATION: float = 0.1

@onready var movement: PlayerMovement = $Movement
@onready var combat: PlayerCombat = $Combat
@onready var health: HealthComponent = $HealthComponent
@onready var _debug_visual: Polygon2D = $Visual

var state: State = State.IDLE
var _hurt_flash_timer: float = 0.0


func _ready() -> void:
	health.damaged.connect(_on_damaged)


func _physics_process(delta: float) -> void:
	var move_input: float = Input.get_axis("move_left", "move_right")
	var jump_just_pressed: bool = Input.is_action_just_pressed("jump")
	var dash_just_pressed: bool = Input.is_action_just_pressed("dash")
	var attack_just_pressed: bool = Input.is_action_just_pressed("attack")

	movement.physics_update(delta, move_input, jump_just_pressed, dash_just_pressed)
	combat.physics_update(delta, attack_just_pressed)
	_hurt_flash_timer = maxf(_hurt_flash_timer - delta, 0.0)

	_update_state(move_input)
	_update_debug_visual()


func _on_damaged(_amount: float) -> void:
	_hurt_flash_timer = HURT_FLASH_DURATION


func _update_state(move_input: float) -> void:
	if movement.is_dashing:
		state = State.AIR_DASH if movement.dash_is_air else State.DASH
	elif combat.is_attacking:
		state = COMBO_STATE[combat.combo_index]
	elif movement.is_wall_sliding:
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
	_debug_visual.color = Color.WHITE if _hurt_flash_timer > 0.0 else STATE_DEBUG_COLOR.get(state, Color.WHITE)
	# Flip only the visual, not the CharacterBody2D itself - flipping the
	# root's scale would also mirror the child Camera2D's view. Uses
	# movement.facing (not instantaneous velocity) so it matches the
	# direction PlayerCombat aims the Hitbox, including while standing still.
	_debug_visual.scale.x = movement.facing
