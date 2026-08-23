extends Control
class_name ResourceBar
## Generic current/max resource bar (health, Veyr, ...) - flat-color
## rectangles matching the project's placeholder-geometric visual
## language, not a themed ProgressBar. Reusable: HUD.gd just calls
## set_value() whenever the underlying resource changes.

@onready var fill: ColorRect = $Fill
@onready var background: ColorRect = $Background

@export var fill_color: Color = Color(0.8, 0.2, 0.2)
@export var background_color: Color = Color(0.12, 0.12, 0.14, 0.85)

var _full_width: float = 0.0


func _ready() -> void:
	fill.color = fill_color
	background.color = background_color
	# Background/Fill are plain ColorRects with no anchors, so they don't
	# auto-follow the root Control's size - resize them explicitly here.
	# This is what makes overriding `size` per-instance (e.g. a wider
	# boss bar) actually work, not just report a different root size.
	_full_width = size.x
	background.size = size
	fill.size = size


func set_value(current: float, max_value: float) -> void:
	var ratio: float = clampf(current / maxf(max_value, 0.001), 0.0, 1.0)
	fill.size.x = _full_width * ratio
