extends CharacterBody2D
class_name EnemyController
## Root controller shared by every enemy variant (melee EnemyAI, ranged
## RangedEnemyAI, boss BossAI, ...). Applies gravity, takes horizontal
## velocity from whichever EnemyAIBase is attached, and handles the
## hit-flash/attacking-tint/stagger/death feedback generically - it never
## needs to change when a new AI variant is added, since it only talks to
## the EnemyAIBase interface.
##
## Also owns the StabilityComponent integration (see docs/COMBAT.md):
## while staggered, the AI simply isn't ticked at all (no
## physics_update() call), so it can neither move nor attack for free -
## no per-AI-script stagger checks needed. On the stagger transition, the
## AI's in-progress attack (if any) is force-cancelled via
## EnemyAIBase.cancel_attack() so a Hitbox can't get stuck active.

@export var gravity: float = 1400.0
## How fast horizontal velocity eases to 0 while staggered (AI isn't
## driving move_velocity_x during that time).
@export var stagger_deceleration: float = 900.0
## Tint while staggered - takes priority over the attacking tint, since
## a staggered enemy can't be attacking.
@export var stagger_color: Color = Color(0.9, 0.9, 0.7)

@onready var ai: EnemyAIBase = $AI
@onready var health: HealthComponent = $HealthComponent
@onready var stability: StabilityComponent = $StabilityComponent
@onready var visual: Polygon2D = $Visual

const HURT_FLASH_DURATION: float = 0.08
const DEATH_FADE_DURATION: float = 0.15
## Shared "about to / currently attacking" telegraph tint, on top of
## whatever attack-specific visual the AI itself drives.
const ATTACKING_TINT: Color = Color(1.0, 0.85, 0.3)

var _base_color: Color
var _hurt_flash_timer: float = 0.0
var _dying: bool = false


func _ready() -> void:
	_base_color = visual.color
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	stability.staggered.connect(_on_staggered)


func _physics_process(delta: float) -> void:
	if _dying:
		return

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += gravity * delta

	if stability.is_staggered:
		velocity.x = move_toward(velocity.x, 0.0, stagger_deceleration * delta)
	else:
		ai.physics_update(delta)
		velocity.x = ai.move_velocity_x
	move_and_slide()

	_hurt_flash_timer = maxf(_hurt_flash_timer - delta, 0.0)
	if _hurt_flash_timer > 0.0:
		visual.color = Color.WHITE
	elif stability.is_staggered:
		visual.color = stagger_color
	elif ai.is_attacking:
		visual.color = ATTACKING_TINT
	else:
		visual.color = _base_color
	visual.scale.x = ai.facing


func _on_damaged(_amount: float) -> void:
	_hurt_flash_timer = HURT_FLASH_DURATION


func _on_staggered() -> void:
	ai.cancel_attack()


func _on_died() -> void:
	_dying = true
	var tween: Tween = create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, DEATH_FADE_DURATION)
	tween.tween_callback(queue_free)
