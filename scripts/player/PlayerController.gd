extends CharacterBody2D
class_name PlayerController
## Reads input, drives the state machine, and delegates physics math to
## the Movement component. Combat/health/abilities will be added later as
## sibling components without this file absorbing their responsibilities.

enum State { IDLE, RUN, JUMP, FALL, WALL_SLIDE, DASH, AIR_DASH, ATTACK_1, ATTACK_2, ATTACK_3, ATTACK_HEAVY, VEYR_STEP, HURT, DEAD }

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
	State.ATTACK_HEAVY: Color(1.0, 0.5, 0.15),
	State.VEYR_STEP: Color(0.55, 0.4, 1.0),
	State.HURT: Color(1.0, 0.25, 0.25),
	State.DEAD: Color(0.2, 0.2, 0.2),
}
## Combo index (PlayerCombat.combo_index) -> the matching attack state.
const COMBO_STATE: Array[State] = [State.ATTACK_1, State.ATTACK_2, State.ATTACK_3]
## No save system / game-over screen exist (out of scope, see
## docs/ARCHITECTURE.md). This is the minimal prototype-level handling so
## dying during testing isn't a dead end: freeze input, wait, respawn at
## the position Zayr started this scene at, full health.
const RESPAWN_DELAY: float = 1.2

@export_group("Hurt")
## Not from a design brief - placeholder, tunable. How long Zayr is
## stunned (no normal input) after taking a hit.
@export var hurt_duration: float = 0.35
## Applied away from the hitbox that hit him (falls back to away-from-
## facing if the hitbox is exactly on top of him).
@export var knockback_force_x: float = 220.0
## Negative = upward pop, a common knockback convention.
@export var knockback_force_y: float = -180.0
## Optional brief invulnerability after a hit lands, separate from and
## stacking safely with Veyr Step's own (see HealthComponent). 0 disables
## it. Deliberately simple - a flat window, not a decaying/complex system.
@export var post_hit_invulnerable_duration: float = 0.5

@onready var movement: PlayerMovement = $Movement
@onready var combat: PlayerCombat = $Combat
@onready var veyr_step: PlayerVeyrStep = $VeyrStep
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var _debug_visual: Polygon2D = $Visual

var state: State = State.IDLE
var _spawn_position: Vector2
var _is_dead: bool = false
var _respawn_timer: float = 0.0
var _is_hurt: bool = false
var _hurt_timer: float = 0.0
var _post_hit_invuln_timer: float = 0.0


func _ready() -> void:
	_spawn_position = global_position
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if _post_hit_invuln_timer > 0.0:
		_post_hit_invuln_timer -= delta
		if _post_hit_invuln_timer <= 0.0:
			health.remove_invulnerability()

	if _is_dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	if _is_hurt:
		_hurt_timer -= delta
		velocity.y += movement.gravity * delta
		move_and_slide()
		if _hurt_timer <= 0.0:
			_is_hurt = false
		return

	var move_input: float = Input.get_axis("move_left", "move_right")
	var aim_y: float = Input.get_axis("aim_up", "aim_down")
	var jump_just_pressed: bool = Input.is_action_just_pressed("jump")
	var dash_just_pressed: bool = Input.is_action_just_pressed("dash")
	var attack_just_pressed: bool = Input.is_action_just_pressed("attack")
	var heavy_attack_just_pressed: bool = Input.is_action_just_pressed("heavy_attack")
	var veyr_step_just_pressed: bool = Input.is_action_just_pressed("veyr_step")

	movement.physics_update(delta, move_input, jump_just_pressed, dash_just_pressed)
	combat.physics_update(delta, attack_just_pressed, heavy_attack_just_pressed)
	veyr_step.physics_update(delta, move_input, aim_y, veyr_step_just_pressed)

	_update_state(move_input)
	_update_debug_visual()


func _on_hit_received(_damage: float, hitbox: Hitbox) -> void:
	if _is_dead or _is_hurt or health.is_invulnerable:
		return
	_enter_hurt(hitbox)


func _enter_hurt(hitbox: Hitbox) -> void:
	_is_hurt = true
	_hurt_timer = hurt_duration
	state = State.HURT

	var away_dir: float = signf(global_position.x - hitbox.global_position.x)
	if away_dir == 0.0:
		away_dir = -movement.facing
	velocity = Vector2(away_dir * knockback_force_x, knockback_force_y)

	movement.cancel_dash()
	combat.cancel_attack()

	if post_hit_invulnerable_duration > 0.0:
		_post_hit_invuln_timer = post_hit_invulnerable_duration
		# Deferred: _on_hit_received fires from Hurtbox.receive_hit() BEFORE
		# that same call reaches its own take_damage() - granting
		# invulnerability synchronously here would make this hit block its
		# own damage. Deferring runs it after the current hit is done.
		call_deferred("_grant_post_hit_invulnerability")

	_update_debug_visual()


func _grant_post_hit_invulnerability() -> void:
	health.add_invulnerability()


func _on_died() -> void:
	_is_dead = true
	_is_hurt = false
	_respawn_timer = RESPAWN_DELAY
	velocity = Vector2.ZERO
	movement.is_dashing = false
	combat.is_attacking = false
	combat.is_heavy_attacking = false
	state = State.DEAD
	_update_debug_visual()


func _respawn() -> void:
	_is_dead = false
	global_position = _spawn_position
	velocity = Vector2.ZERO
	health.revive()
	state = State.IDLE


func _update_state(move_input: float) -> void:
	if veyr_step.is_stepping:
		state = State.VEYR_STEP
	elif movement.is_dashing:
		state = State.AIR_DASH if movement.dash_is_air else State.DASH
	elif combat.is_heavy_attacking:
		state = State.ATTACK_HEAVY
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
	_debug_visual.color = STATE_DEBUG_COLOR.get(state, Color.WHITE)
	# Flip only the visual, not the CharacterBody2D itself - flipping the
	# root's scale would also mirror the child Camera2D's view. Uses
	# movement.facing (not instantaneous velocity) so it matches the
	# direction PlayerCombat aims the Hitbox, including while standing still.
	_debug_visual.scale.x = movement.facing
