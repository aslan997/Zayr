extends Camera2D
class_name CameraController
## Smooth-follow camera with a small directional look-ahead.
## Smoothing itself uses Camera2D's built-in position_smoothing
## (tune position_smoothing_speed in the Inspector). This script only adds
## look-ahead. Camera limits are intentionally NOT set here - they are
## region-specific and get overridden per-instance by the region scene
## (e.g. TestArena.tscn) so this scene stays reusable.

@export var look_ahead_distance: float = 60.0
@export var look_ahead_smoothing: float = 4.0
@export var look_ahead_velocity_threshold: float = 10.0

var _target_offset: Vector2 = Vector2.ZERO

@onready var _target: Node2D = get_parent()


func _ready() -> void:
	position_smoothing_enabled = true


func _process(delta: float) -> void:
	if _target is CharacterBody2D:
		var vx: float = (_target as CharacterBody2D).velocity.x
		if vx > look_ahead_velocity_threshold:
			_target_offset.x = look_ahead_distance
		elif vx < -look_ahead_velocity_threshold:
			_target_offset.x = -look_ahead_distance

	offset = offset.lerp(_target_offset, clampf(look_ahead_smoothing * delta, 0.0, 1.0))
