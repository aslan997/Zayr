extends CharacterBody2D
class_name PlayerController
## Reads input, drives the state machine, and delegates physics math to
## the Movement component. Combat/health/abilities will be added later as
## sibling components without this file absorbing their responsibilities.

enum State { IDLE, RUN, JUMP, FALL, WALL_SLIDE, DASH, AIR_DASH, ATTACK_1, ATTACK_2, ATTACK_3, ATTACK_HEAVY, ATTACK_RANGED, ATTACK_AERIAL, CHARGING, ATTACK_CHARGED, VEYR_STEP, HURT, DEAD }

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
	State.ATTACK_RANGED: Color(0.6, 0.45, 1.0),
	State.ATTACK_AERIAL: Color(0.4, 0.9, 0.6),
	State.CHARGING: Color(0.75, 0.65, 0.15),
	State.ATTACK_CHARGED: Color(0.95, 0.85, 0.25),
	State.VEYR_STEP: Color(0.55, 0.4, 1.0),
	State.HURT: Color(1.0, 0.25, 0.25),
	State.DEAD: Color(0.2, 0.2, 0.2),
}
## Combo index (PlayerCombat.combo_index) -> the matching attack state.
const COMBO_STATE: Array[State] = [State.ATTACK_1, State.ATTACK_2, State.ATTACK_3]
## Per-frame offset/scale for CharacterSprite/AnimatedSprite2D, one entry
## per PixelLab animation (see docs/ZAYR_ASSET_IMPLEMENTATION.md's
## "PixelLab Integration" section). All animations use per-frame offsets
## uniformly (not a single fixed offset like the old idle/run did) since
## even idle's own bbox varies a pixel or two frame to frame at this
## native resolution - per-frame anchoring costs nothing and avoids any
## chance of foot/torso drift. scale.x is POSITIVE (no flip) for every
## entry: the delivered "east" art faces screen-right natively, matching
## the folder name - confirmed at native resolution directly from the
## source PNG (nose/chin clearly pointing right, cloth trailing behind
## to the left). An earlier pass mistakenly read dash/ranged's trailing
## cloth streaming left as the character leaning left and applied a
## negative scale.x "correction" here - that inverted correctly-facing
## art, causing Zayr to visibly face away from his real travel direction
## (reported by the user testing in-editor, reproduced by directly
## rendering the raw source PNG and comparing to in-game screenshots of
## real left/right movement). Reverted; _update_visual()'s mirror logic
## itself was never the problem and remains untouched.
const ANIM_FRAME_SCALE: Dictionary = {
	"idle": Vector2(1.0, 1.0),
	"combat_idle": Vector2(1.0, 1.0),
	"run": Vector2(1.0, 1.0),
	"jump": Vector2(1.0, 1.0),
	"fall": Vector2(1.0, 1.0),
	"wall_slide": Vector2(1.0, 1.0),
	"dash": Vector2(1.0, 1.0),
	"light_1": Vector2(1.0, 1.0),
	"light_2": Vector2(1.0, 1.0),
	"light_3": Vector2(1.0, 1.0),
	"heavy": Vector2(1.0, 1.0),
	"aerial": Vector2(1.0, 1.0),
	"ranged": Vector2(1.0, 1.0),
	"charged_start": Vector2(1.0, 1.0),
	"charged_hold": Vector2(1.0, 1.0),
	"charged_release": Vector2(1.0, 1.0),
	"hurt": Vector2(1.0, 1.0),
	"death": Vector2(1.0, 1.0),
}
## Two anchor conventions, chosen per animation the same way the old art
## was: FOOT-anchor (offset.y = -bbox_bottom, so the pose's lowest pixel
## always lands at world Y=0, matching the collision box's feet) for
## every grounded animation, and CORE-anchor (offset.y = TARGET_CORE_Y -
## bbox_center_y) for the airborne ones (jump/fall/wall_slide/dash/
## aerial) where there's no ground reference to lock to and
## foot-anchoring would make the torso visibly teleport as the pose's
## bbox height changes. TARGET_CORE_Y=-30 was derived from where
## idle/run's own foot-anchored poses naturally center (averaging -29.75
## and -30.56 respectively across their frames) - NOT reused from the
## old high-resolution art's -45, which was calibrated to that set's own
## different proportions and rendered every airborne animation floating
## well above the collision box when first tried against this smaller-
## canvas PixelLab art (caught via real-camera screenshot, corrected
## before commit). offset.x is always -bbox_center_x (centers the pose
## on world X=0) for every animation. This new PixelLab wall_slide art
## has no baked-in wall surface (unlike the old hand-painted set), so
## there's no wall-edge column to solve for here - core-anchor alone is
## enough.
const ANIM_FRAME_OFFSETS: Dictionary = {
	"idle": [Vector2(-26.5, -62.0), Vector2(-26.5, -61.0), Vector2(-27.0, -61.0), Vector2(-27.5, -62.0)],
	"combat_idle": [Vector2(-30.5, -61.0), Vector2(-31.0, -61.0), Vector2(-30.5, -61.0), Vector2(-31.5, -61.0), Vector2(-31.5, -61.0), Vector2(-31.0, -61.0), Vector2(-31.5, -61.0), Vector2(-31.0, -61.0)],
	"run": [Vector2(-39.5, -74.0), Vector2(-42.5, -74.0), Vector2(-42.5, -74.0), Vector2(-41.0, -73.0), Vector2(-39.5, -73.0), Vector2(-38.0, -73.0), Vector2(-41.5, -73.0), Vector2(-44.0, -73.0), Vector2(-41.5, -74.0)],
	"jump": [Vector2(-39.5, -73.5), Vector2(-39.5, -74.5), Vector2(-39.5, -76.5), Vector2(-41.5, -74.5), Vector2(-39.5, -72.0), Vector2(-40.0, -70.5), Vector2(-40.0, -74.0)],
	"fall": [Vector2(-39.5, -73.5), Vector2(-39.5, -71.5), Vector2(-41.0, -70.5), Vector2(-41.0, -72.0), Vector2(-41.0, -74.0)],
	"wall_slide": [Vector2(-39.5, -73.5), Vector2(-43.0, -74.0), Vector2(-42.5, -74.0), Vector2(-41.5, -74.5), Vector2(-42.0, -75.5)],
	"dash": [Vector2(-39.5, -73.5), Vector2(-40.0, -74.5), Vector2(-39.5, -75.0), Vector2(-41.0, -76.0), Vector2(-41.0, -78.5)],
	"light_1": [Vector2(-39.5, -74.0), Vector2(-40.5, -74.0), Vector2(-43.0, -72.0), Vector2(-43.5, -74.0), Vector2(-41.5, -74.0), Vector2(-43.0, -74.0), Vector2(-47.5, -73.0)],
	"light_2": [Vector2(-39.5, -74.0), Vector2(-38.0, -74.0), Vector2(-38.5, -74.0), Vector2(-40.0, -74.0), Vector2(-38.0, -74.0), Vector2(-34.5, -74.0), Vector2(-41.0, -74.0)],
	"light_3": [Vector2(-39.5, -74.0), Vector2(-39.5, -74.0), Vector2(-40.0, -74.0), Vector2(-40.0, -74.0), Vector2(-37.5, -72.0), Vector2(-39.0, -71.0), Vector2(-41.5, -74.0), Vector2(-43.5, -74.0), Vector2(-42.5, -74.0)],
	"heavy": [Vector2(-39.5, -74.0), Vector2(-41.5, -74.0), Vector2(-44.5, -74.0), Vector2(-44.0, -74.0), Vector2(-42.0, -73.0), Vector2(-39.0, -74.0), Vector2(-40.5, -74.0), Vector2(-40.0, -74.0), Vector2(-40.0, -74.0)],
	"aerial": [Vector2(-39.5, -73.5), Vector2(-37.0, -74.0), Vector2(-35.0, -75.0), Vector2(-37.0, -74.5), Vector2(-37.0, -72.5), Vector2(-45.5, -69.5), Vector2(-39.0, -74.5)],
	"ranged": [Vector2(-39.5, -74.0), Vector2(-41.0, -74.0), Vector2(-42.5, -74.0), Vector2(-39.0, -74.0), Vector2(-38.5, -74.0), Vector2(-45.0, -74.0), Vector2(-46.0, -74.0)],
	"charged_start": [Vector2(-39.5, -74.0), Vector2(-40.5, -74.0), Vector2(-40.5, -74.0), Vector2(-39.5, -75.0), Vector2(-41.0, -75.0)],
	"charged_hold": [Vector2(-39.5, -74.0), Vector2(-40.0, -74.0), Vector2(-42.5, -74.0), Vector2(-45.0, -74.0), Vector2(-45.5, -74.0)],
	"charged_release": [Vector2(-39.5, -74.0), Vector2(-41.5, -72.0), Vector2(-42.5, -74.0), Vector2(-41.0, -74.0), Vector2(-35.5, -74.0), Vector2(-44.5, -74.0), Vector2(-44.5, -74.0), Vector2(-42.5, -74.0), Vector2(-46.0, -74.0)],
	"hurt": [Vector2(-39.5, -74.0), Vector2(-39.5, -73.0), Vector2(-40.5, -72.0), Vector2(-42.0, -72.0), Vector2(-41.5, -74.0)],
	"death": [Vector2(-39.5, -74.0), Vector2(-39.0, -74.0), Vector2(-39.5, -74.0), Vector2(-40.5, -72.0), Vector2(-41.0, -72.0), Vector2(-42.5, -72.0), Vector2(-43.5, -74.0), Vector2(-42.5, -75.0), Vector2(-43.0, -75.0)],
}
## Veyr Edge (VisualRoot/WeaponManifestation/VeyrEdge) per-frame visual
## transform for light_1's active-strike frames. Recalibrated for the
## PixelLab body art's new hand position - light_1's frame timing was
## also re-split (see ANIM_FRAME_OFFSETS/the SpriteFrames resource) so
## the real gameplay active window (t=0.08-0.18s) now falls on animation
## frames 4-5 (0-indexed), not 1-3 like the old art - frames 3 and 6 are
## included too as a safety margin against AnimatedSprite2D's real-clock
## drift (see _update_weapon_manifestation()). Position is the attacking
## fist's own world position per frame (found via the same leftmost-
## extent method as before, adjusted for the new art's native-left
## facing - see ANIM_FRAME_SCALE's comment), scale is a single constant
## (a real weapon doesn't resize itself mid-swing).
const VEYR_EDGE_SCALE: Vector2 = Vector2(0.03, 0.03)
const VEYR_EDGE_TRANSFORM: Dictionary = {
	3: {"position": Vector2(13.5, -26.1), "rotation": deg_to_rad(24.28)},
	4: {"position": Vector2(22.5, -33.5), "rotation": deg_to_rad(24.28)},
	5: {"position": Vector2(24.0, -10.1), "rotation": deg_to_rad(24.28)},
	6: {"position": Vector2(26.5, -40.5), "rotation": deg_to_rad(24.28)},
}
## No save system / game-over screen exist (out of scope, see
## docs/ARCHITECTURE.md). This is the minimal prototype-level handling so
## dying during testing isn't a dead end: freeze input, wait, respawn at
## the position Zayr started this scene at, full health.
const RESPAWN_DELAY: float = 1.2

@export_group("Debug")
## Shows the flat per-state-tinted debug rectangle instead of the
## production VisualRoot. Checked once in _ready() - not a live toggle,
## by design (see docs/ZAYR_ASSET_IMPLEMENTATION.md Phase A). Never both
## visible at once. Also forced on automatically if CharacterSprite has
## no "idle" animation yet (see _ready()) - production art not existing
## should never leave the player invisible.
@export var show_debug_visual: bool = false

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
@onready var ranged_attack: PlayerRangedAttack = $RangedAttack
@onready var veyr_step: PlayerVeyrStep = $VeyrStep
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var _debug_visual: Polygon2D = $DebugVisual
@onready var _visual_root: Node2D = $VisualRoot
@onready var _character_sprite: AnimatedSprite2D = $VisualRoot/CharacterSprite/AnimatedSprite2D
@onready var _veyr_edge: Sprite2D = $VisualRoot/WeaponManifestation/VeyrEdge

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
	_character_sprite.frame_changed.connect(_on_character_frame_changed)
	if not _no_idle_art():
		_character_sprite.play("idle")
		_apply_frame_transform()
	_apply_visual_fallback()


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
	# "heavy_attack" is bound to L (see project.godot) as temporary
	# prototype input - not a final keybind, just something free to test
	# with. Expect this to be replaced/rebound during final input mapping.
	var heavy_attack_just_pressed: bool = Input.is_action_just_pressed("heavy_attack")
	var ranged_attack_just_pressed: bool = Input.is_action_just_pressed("ranged_attack")
	var charge_just_pressed: bool = Input.is_action_just_pressed("charged_attack")
	var charge_just_released: bool = Input.is_action_just_released("charged_attack")
	var veyr_step_just_pressed: bool = Input.is_action_just_pressed("veyr_step")

	movement.physics_update(delta, move_input, jump_just_pressed, dash_just_pressed)
	combat.physics_update(delta, attack_just_pressed, heavy_attack_just_pressed, aim_y > 0.0, \
		charge_just_pressed, charge_just_released)
	ranged_attack.physics_update(delta, ranged_attack_just_pressed)
	veyr_step.physics_update(delta, move_input, aim_y, veyr_step_just_pressed)

	_update_state(move_input)
	_update_visual()


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
	ranged_attack.cancel_attack()

	if post_hit_invulnerable_duration > 0.0:
		_post_hit_invuln_timer = post_hit_invulnerable_duration
		# Deferred: _on_hit_received fires from Hurtbox.receive_hit() BEFORE
		# that same call reaches its own take_damage() - granting
		# invulnerability synchronously here would make this hit block its
		# own damage. Deferring runs it after the current hit is done.
		call_deferred("_grant_post_hit_invulnerability")

	_update_visual()


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
	combat.is_charging = false
	combat.is_charged_attacking = false
	combat.is_aerial_attacking = false
	ranged_attack.is_attacking = false
	state = State.DEAD
	_update_visual()


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
	elif combat.is_charged_attacking:
		state = State.ATTACK_CHARGED
	elif combat.is_charging:
		state = State.CHARGING
	elif combat.is_heavy_attacking:
		state = State.ATTACK_HEAVY
	elif combat.is_attacking:
		state = COMBO_STATE[combat.combo_index]
	elif combat.is_aerial_attacking:
		state = State.ATTACK_AERIAL
	elif ranged_attack.is_attacking:
		state = State.ATTACK_RANGED
	elif movement.is_wall_sliding:
		state = State.WALL_SLIDE
	elif not is_on_floor():
		state = State.JUMP if velocity.y < 0.0 else State.FALL
	elif move_input != 0.0 and absf(velocity.x) > 1.0:
		state = State.RUN
	else:
		state = State.IDLE


func _update_visual() -> void:
	# Flip only the visual layers, not the CharacterBody2D itself -
	# flipping the root's scale would also mirror the child Camera2D's
	# view. Uses movement.facing (not instantaneous velocity) so it
	# matches the direction PlayerCombat aims the Hitbox, including while
	# standing still. VisualRoot and _debug_visual are never shown
	# together (see show_debug_visual), but both are kept in sync so
	# toggling the export mid-session (e.g. from the editor's remote
	# inspector) never leaves either mirrored wrong.
	# During WALL_SLIDE specifically, mirror off movement.wall_normal_x
	# instead of facing - wall-sliding triggers on wall contact alone
	# (no input-direction requirement), so facing can be stale/wrong
	# about which side is actually walled; wall_normal_x always reflects
	# the real contacted side. The wall_slide art's default (unmirrored)
	# orientation has the wall on Zayr's right, i.e. wall_normal_x < 0 -
	# hence the negation.
	var mirror: float = -movement.wall_normal_x if state == State.WALL_SLIDE else movement.facing
	if _debug_visual:
		_debug_visual.color = STATE_DEBUG_COLOR.get(state, Color.WHITE)
		_debug_visual.scale.x = mirror
	if _visual_root:
		_visual_root.scale.x = mirror
	_update_character_animation()
	_update_weapon_manifestation()
	# Re-asserted every frame (not just _ready()) because PlayerVeyrStep
	# directly toggles VisualRoot.visible around its own hide/show window
	# (see PlayerVeyrStep._end_step()) - without this, VisualRoot would
	# pop back to visible after a step ends even while there's no idle
	# art for it to actually show.
	_apply_visual_fallback()


## Visual-only: picks the animation matching the existing state machine.
## Never touches movement/physics/timing - reads `state`, doesn't set
## it. Swaps the AnimatedSprite2D's scale/offset alongside the
## animation (see ANIM_FRAME_SCALE/ANIM_FRAME_OFFSETS).
##
## Most states map 1:1 to a PixelLab animation of the same shape as
## before (run/jump/fall/wall_slide/dash/light_1). Newly wired this
## pass: light_2/light_3 (combo swings 2-3), heavy, aerial, ranged, and
## hurt/death (previously nonexistent branches - HURT and DEAD used to
## fall through to idle since no art existed for them).
##
## CHARGING is the one state that maps to two different animations:
## charged_start plays once on entering the stance, then charged_hold
## takes over and loops for as long as the existing charge system
## (PlayerCombat.is_charging) keeps CHARGING true - reusing
## charged_start's own non-loop completion (is_playing() going false)
## to detect the handoff point rather than inventing a new timer, so
## retuning charged_start's speed later never needs a matching code
## change here. ATTACK_CHARGED plays charged_release once.
##
## combat_idle is intentionally never selected here - per instruction,
## this project has no combat-idle concept in its state machine, so the
## asset stays imported and available without adding state logic only
## to use it.
func _update_character_animation() -> void:
	if _no_idle_art():
		return
	var frames: SpriteFrames = _character_sprite.sprite_frames
	var desired: StringName = &"idle"
	if state == State.RUN and frames.has_animation("run"):
		desired = &"run"
	elif state == State.JUMP and frames.has_animation("jump"):
		desired = &"jump"
	elif state == State.FALL and frames.has_animation("fall"):
		desired = &"fall"
	elif state == State.WALL_SLIDE and frames.has_animation("wall_slide"):
		desired = &"wall_slide"
	elif (state == State.DASH or state == State.AIR_DASH) and frames.has_animation("dash"):
		desired = &"dash"
	elif state == State.ATTACK_1 and frames.has_animation("light_1"):
		desired = &"light_1"
	elif state == State.ATTACK_2 and frames.has_animation("light_2"):
		desired = &"light_2"
	elif state == State.ATTACK_3 and frames.has_animation("light_3"):
		desired = &"light_3"
	elif state == State.ATTACK_HEAVY and frames.has_animation("heavy"):
		desired = &"heavy"
	elif state == State.ATTACK_AERIAL and frames.has_animation("aerial"):
		desired = &"aerial"
	elif state == State.ATTACK_RANGED and frames.has_animation("ranged"):
		desired = &"ranged"
	elif state == State.CHARGING and frames.has_animation("charged_start") and frames.has_animation("charged_hold"):
		var already_holding: bool = _character_sprite.animation == &"charged_hold"
		var start_finished: bool = _character_sprite.animation == &"charged_start" and not _character_sprite.is_playing()
		desired = &"charged_hold" if (already_holding or start_finished) else &"charged_start"
	elif state == State.ATTACK_CHARGED and frames.has_animation("charged_release"):
		desired = &"charged_release"
	elif state == State.HURT and frames.has_animation("hurt"):
		desired = &"hurt"
	elif state == State.DEAD and frames.has_animation("death"):
		desired = &"death"
	if _character_sprite.animation != desired:
		# Non-looping animations (jump/dash/every attack/hurt/death) must
		# hold their final frame rather than snapping back to frame 0 -
		# Godot's own non-looping-animation behavior already does this
		# (is_playing() goes false, frame index stays put), so as long as
		# `animation` doesn't change again this naturally holds without
		# any extra state here.
		_character_sprite.play(desired)
		_apply_frame_transform()


## Re-applies the current animation's scale/offset for whichever frame
## is now showing. Called after every play() and on every frame_changed
## (see _ready()) - every PixelLab animation uses a per-frame offset
## (ANIM_FRAME_SCALE/ANIM_FRAME_OFFSETS) so the torso/feet don't
## visually jump around as each pose's bounding box changes frame to
## frame.
func _apply_frame_transform() -> void:
	var anim: StringName = _character_sprite.animation
	var scale: Vector2 = ANIM_FRAME_SCALE.get(anim, Vector2.ZERO)
	var offsets: Array = ANIM_FRAME_OFFSETS.get(anim, [])
	if scale != Vector2.ZERO and not offsets.is_empty():
		var idx: int = clampi(_character_sprite.frame, 0, offsets.size() - 1)
		_character_sprite.scale = scale
		_character_sprite.offset = offsets[idx]


func _on_character_frame_changed() -> void:
	_apply_frame_transform()


## Veyr Edge v0.1: visible only while Light Attack 1's real hitbox is
## active (combat.hitbox.monitoring), not merely while "light_1" is
## playing - per instruction, gameplay timing is authoritative over
## decorative frame numbers, so this stays in sync with the actual
## windup/active/recovery split even if the animation's own FPS is
## later retuned. Position/rotation track the attacking fist per
## VEYR_EDGE_TRANSFORM, clamped to the nearest defined active-window
## frame (3..6 - the PixelLab light_1 re-integration re-split the
## animation's own frame timing so frames 4-5 now carry the real
## t=0.08-0.18s hitbox window, with 3 and 6 kept as safety margin)
## rather than hidden when the currently-showing animation frame
## briefly falls outside that range - AnimatedSprite2D's frame advance
## is driven by the engine's own real per-process delta (not this same
## combat timer), so at real gameplay framerates it can lag behind or
## run ahead of the hitbox's open/close instants by a frame; clamping
## keeps the weapon visible for the entire true active window instead
## of flickering off whenever the two clocks briefly disagree. Never
## touches CharacterSprite/body art. No other attack has a Veyr Edge
## manifestation yet (per instruction, not building new VFX architecture
## for light_2/3/heavy/aerial/ranged/charged this pass) - the weapon
## simply stays hidden outside State.ATTACK_1.
func _update_weapon_manifestation() -> void:
	if not _veyr_edge:
		return
	var should_show: bool = state == State.ATTACK_1 and combat.hitbox.monitoring
	_veyr_edge.visible = should_show
	if not should_show:
		return
	var idx: int = clampi(_character_sprite.frame, 3, 6)
	var t: Dictionary = VEYR_EDGE_TRANSFORM[idx]
	_veyr_edge.position = t["position"]
	_veyr_edge.rotation = t["rotation"]
	_veyr_edge.scale = VEYR_EDGE_SCALE


## True while CharacterSprite has nothing to actually display (no
## SpriteFrames, or a SpriteFrames without an "idle" animation yet).
func _no_idle_art() -> bool:
	return not _character_sprite.sprite_frames \
		or not _character_sprite.sprite_frames.has_animation("idle")


## Forces DebugVisual on (and VisualRoot off) whenever there's no idle
## art yet, regardless of show_debug_visual - production art not
## existing should never leave the player invisible. See _no_idle_art().
func _apply_visual_fallback() -> void:
	_debug_visual.visible = show_debug_visual or _no_idle_art()
	_visual_root.visible = not _debug_visual.visible
