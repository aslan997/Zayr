extends Node
class_name AvarisReveal
## Stage 4's Avaris reveal camera flourish (see docs/PROGRESS.md). The
## reveal itself is composition-driven - the backdrop geometry does the
## work - this just gives it a brief, one-shot "the view opens up"
## beat: the camera eases out to show more of the skyline, holds, then
## settles back into normal gameplay framing. Deliberately small and
## scene-local, not a cinematic camera framework - CameraController.gd
## (look-ahead/offset) is untouched; this only ever tweens `zoom` on the
## same Camera2D, a different property, so the two can't fight.

@export var zoom_out_target: Vector2 = Vector2(0.85, 0.85)
@export var ease_out_duration: float = 1.1
@export var hold_duration: float = 1.2
@export var ease_in_duration: float = 1.1
@export var trigger_path: NodePath
@export var camera_path: NodePath

@onready var trigger: PlayerTrigger = get_node(trigger_path)
@onready var camera: Camera2D = get_node(camera_path)

var _played: bool = false


func _ready() -> void:
	trigger.triggered.connect(play)


func play() -> void:
	if _played:
		return
	_played = true
	var base_zoom: Vector2 = camera.zoom
	var tween: Tween = create_tween()
	tween.tween_property(camera, "zoom", zoom_out_target, ease_out_duration)
	tween.tween_interval(hold_duration)
	tween.tween_property(camera, "zoom", base_zoom, ease_in_duration)
