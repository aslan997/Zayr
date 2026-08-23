extends CharacterBody2D
class_name EnemyController
## Root controller for the first enemy. Applies gravity, takes horizontal
## velocity from EnemyAI (patrol/chase/attack), and delegates behavior to
## it, matching the Controller/component split used for the player.
## Handles the hit-flash and death (fade + queue_free) feedback for this
## enemy specifically.

@export var gravity: float = 1400.0

@onready var ai: EnemyAI = $AI
@onready var health: HealthComponent = $HealthComponent
@onready var visual: Polygon2D = $Visual

const HURT_FLASH_DURATION: float = 0.08
const DEATH_FADE_DURATION: float = 0.15

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
	visual.color = Color.WHITE if _hurt_flash_timer > 0.0 else _base_color
	visual.scale.x = ai.facing


func _on_damaged(_amount: float) -> void:
	_hurt_flash_timer = HURT_FLASH_DURATION


func _on_died() -> void:
	_dying = true
	var tween: Tween = create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, DEATH_FADE_DURATION)
	tween.tween_callback(queue_free)
