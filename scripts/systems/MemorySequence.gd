extends Node
class_name MemorySequence
## Stages the vertical slice's "Memory" beat as PRESENT -> PAST -> PRESENT,
## not an instant palette swap: a slow whole-scene tint shift (via
## CanvasModulate) fades in, "memory only" geometry becomes visible while
## held, then everything fades/destabilizes back out. Purely atmospheric:
## does not freeze, alter, or take over player control - no dialogue, no
## new characters, no plot specifics, only mood/composition.
##
## Enhanced pass (see docs/PROGRESS.md): the original version only ever
## lit up bridges/windows near the Stage 4 reveal, which is thousands of
## pixels behind the player by the time they actually reach this trigger
## - effectively invisible from where the memory plays (confirmed via a
## real screenshot, not assumed). This version adds three things, all
## positioned where the player actually is: (1) existing nearby ruin
## geometry (e.g. Stage 5's pillars) temporarily brightens to an "alive"
## color via activation_paths, so the *specific ruins the player is
## standing next to* visibly become their former selves, not just an
## unrelated distant backdrop; (2) a few simple shapes drift slowly
## during the hold (drift_paths) to imply distant inhabited activity
## without any named vehicles/characters/tech; (3) a brief destabilize()
## flicker before the final fade-out, so the memory visibly slips away
## rather than cutting cleanly.

## Emitted once the full PRESENT->PAST->PRESENT cycle has actually
## finished (not when it starts) - lets a later scene-local sequence
## (e.g. RhaekTeaser.gd's wait_for_path) hold until this one has fully
## resolved, even though this sequence never restricts player movement
## and a fast player could otherwise reach a later trigger mid-memory.
signal finished

@export var fade_duration: float = 1.2
@export var hold_duration: float = 5.0
@export var destabilize_duration: float = 0.9
## Also doubles as this scene's ambient-lighting baseline (see the art
## pass, docs/ARCHITECTURE.md §11/§B) - this is the only CanvasModulate
## in the scene, so dimming the world for the PointLight2Ds to punch
## through reuses this tint rather than adding a second, conflicting
## CanvasModulate. Set on the scene instance, not this default - see
## AvarisVerticalSlice.tscn.
@export var present_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var past_tint: Color = Color(0.75, 0.65, 1.0, 1.0)
@export var trigger_path: NodePath
## Existing world geometry (outside MemoryOnly - e.g. nearby ruin
## silhouettes already in the scene) that temporarily brightens to
## activation_color during the memory, reverting to its own original
## color afterward. This is the "the ruins you're standing next to were
## once alive" beat, using geometry the player can already see instead
## of unrelated far-away detail.
@export var activation_paths: Array[NodePath] = []
@export var activation_color: Color = Color(1.2, 1.05, 1.6, 0.9)
## MemoryOnly children that drift slowly back and forth during the hold
## - a handful of simple shapes implying distant activity, not named
## vehicles or characters. Reset to their authored position when the
## memory ends.
@export var drift_paths: Array[NodePath] = []
@export var drift_offset: Vector2 = Vector2(60.0, -14.0)
@export var drift_duration: float = 3.0

@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var memory_only: Node2D = $MemoryOnly
@onready var trigger: PlayerTrigger = get_node(trigger_path)

var _played: bool = false
var is_finished: bool = false
var _activation_original_colors: Array[Color] = []
var _drift_start_positions: Array[Vector2] = []
var _drift_tweens: Array[Tween] = []


func _ready() -> void:
	memory_only.visible = false
	memory_only.modulate.a = 1.0
	canvas_modulate.color = present_tint
	for p in activation_paths:
		var node: Polygon2D = get_node(p)
		_activation_original_colors.append(node.color)
	for p in drift_paths:
		var node: Node2D = get_node(p)
		_drift_start_positions.append(node.position)
	trigger.triggered.connect(play)


func play() -> void:
	if _played:
		return
	_played = true
	_run_sequence()


func _run_sequence() -> void:
	memory_only.visible = true
	var tween_in: Tween = create_tween()
	tween_in.set_parallel(true)
	tween_in.tween_property(canvas_modulate, "color", past_tint, fade_duration)
	for i in activation_paths.size():
		var node: Polygon2D = get_node(activation_paths[i])
		tween_in.tween_property(node, "color", activation_color, fade_duration)
	await tween_in.finished

	_start_drift()
	await get_tree().create_timer(hold_duration).timeout
	_stop_drift()

	await _destabilize()

	var tween_out: Tween = create_tween()
	tween_out.set_parallel(true)
	tween_out.tween_property(canvas_modulate, "color", present_tint, fade_duration)
	for i in activation_paths.size():
		var node: Polygon2D = get_node(activation_paths[i])
		tween_out.tween_property(node, "color", _activation_original_colors[i], fade_duration)
	await tween_out.finished
	memory_only.visible = false
	is_finished = true
	finished.emit()


func _start_drift() -> void:
	for i in drift_paths.size():
		var node: Node2D = get_node(drift_paths[i])
		var start: Vector2 = _drift_start_positions[i]
		var t: Tween = create_tween()
		t.set_loops()
		t.tween_property(node, "position", start + drift_offset, drift_duration)
		t.tween_property(node, "position", start, drift_duration)
		_drift_tweens.append(t)


func _stop_drift() -> void:
	for t in _drift_tweens:
		if t and t.is_valid():
			t.kill()
	_drift_tweens.clear()
	for i in drift_paths.size():
		var node: Node2D = get_node(drift_paths[i])
		node.position = _drift_start_positions[i]


## Brief visual instability before the memory lets go - a few rapid
## alpha flickers on the memory-only content, not a shader. The
## emotional idea: Zayr can't hold onto it.
func _destabilize() -> void:
	var flicker_tween: Tween = create_tween()
	var flickers: int = 4
	var step: float = destabilize_duration / float(flickers * 2)
	for i in flickers:
		flicker_tween.tween_property(memory_only, "modulate:a", 0.2, step)
		flicker_tween.tween_property(memory_only, "modulate:a", 1.0, step)
	await flicker_tween.finished
	memory_only.modulate.a = 1.0
