extends CharacterBody2D
class_name EnemyController
## Root controller shared by every enemy variant (melee EnemyAI, ranged
## RangedEnemyAI, ...). Applies gravity, takes horizontal velocity from
## whichever EnemyAIBase is attached, and handles the hit-flash/
## attacking-tint/death feedback generically - it never needs to change
## when a new AI variant is added, since it only talks to the EnemyAIBase
## interface.

@export var gravity: float = 1400.0

@onready var ai: EnemyAIBase = $AI
@onready var health: HealthComponent = $HealthComponent
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


func _physics_process(delta: float) -> void:
	if _dying:
		return

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += gravity * delta

	ai.physics_update(delta)
	velocity.x = ai.move_velocity_x
	move_and_slide()

	_hurt_flash_timer = maxf(_hurt_flash_timer - delta, 0.0)
	if _hurt_flash_timer > 0.0:
		visual.color = Color.WHITE
	elif ai.is_attacking:
		visual.color = ATTACKING_TINT
	else:
		visual.color = _base_color
	visual.scale.x = ai.facing


func _on_damaged(_amount: float) -> void:
	_hurt_flash_timer = HURT_FLASH_DURATION


func _on_died() -> void:
	_dying = true
	var tween: Tween = create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, DEATH_FADE_DURATION)
	tween.tween_callback(queue_free)
