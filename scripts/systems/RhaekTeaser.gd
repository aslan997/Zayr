extends Node
class_name RhaekTeaser
## Stages the vertical slice's final "Rhaek Teaser" beat as three parts -
## presence, attention, departure - not a static silhouette (see
## docs/PROGRESS.md). Rhaek is a reserved, uncharacterized canon character
## (see docs/GDD.md/LORE.md): this deliberately reveals nothing about who
## they are - just a distant, unreachable, backlit humanoid silhouette
## that fades into view, turns and briefly brightens to show it notices
## the player, then dissolves using the same violet burst/fade visual
## language as Zayr's own Veyr Step (implying a shared nature, not
## stating one). No dialogue, no approach, no fight - purely atmospheric.
##
## Enhanced pass (see docs/PROGRESS.md): this now also (1) optionally
## waits for another scene-local sequence to actually finish first
## (wait_for_path - Stage 6's MemorySequence never restricts player
## movement, so a fast player could otherwise reach this trigger while
## the memory is still visually playing), (2) eases the camera out for
## the duration of Rhaek's presence so he's actually visible from the
## player's real position (confirmed via screenshot he was NOT, at the
## previous unmodified zoom - see docs/PROGRESS.md), and (3), since this
## is the last beat of the vertical slice, closes it out: a brief
## stillness after Rhaek is gone, then a fade to black and a developer-
## facing end marker. Still no combat of any kind - no health, no
## Hitbox, no AI - and still no new sequencing framework: everything
## below is one linear function using the same Tween/timer primitives
## already used throughout this project.

@export var presence_fade_duration: float = 0.6
@export var attention_delay: float = 1.4
@export var attention_pulse_duration: float = 0.4
@export var departure_delay: float = 1.6
@export var dissolve_duration: float = 0.5
## Boosted above 1.0 so it actually catches the WorldEnvironment's glow
## (see docs/PROGRESS.md art pass) - values >1.0 are valid HDR overshoot
## for 2D CanvasItem colors, not a mistake.
@export var attention_color: Color = Color(0.72, 0.53, 1.3)
@export var trigger_path: NodePath
## Optional - if set, play() waits for this node's `finished` signal
## (skipped if it's already finished) before actually starting. Wired to
## Stage 6's MemorySequence so Rhaek never appears mid-memory.
@export var wait_for_path: NodePath
## Small scene-local camera flourish, the same "ease out, hold, ease
## back" idea as AvarisReveal.gd but inlined here (not a second
## AvarisReveal instance) so it stays synchronized with this sequence's
## own timing - it needs to hold for the whole presence/attention/
## departure beat, not a brief independent peek.
@export var camera_path: NodePath
@export var camera_zoom_out: Vector2 = Vector2(0.55, 0.55)
@export var camera_ease_duration: float = 1.0
## End-of-slice close. Not a menu/credits/title system - a plain fade
## and one developer-facing line, per docs/PROGRESS.md.
@export var end_fade_path: NodePath
@export var end_label_path: NodePath
@export var end_stillness_duration: float = 1.5
@export var end_fade_duration: float = 1.2
@export var end_label_text: String = "Vertical Slice Complete"

signal finished

@onready var silhouette: Polygon2D = $Silhouette
@onready var depart_burst: Polygon2D = $DepartBurst
@onready var depart_particles: GPUParticles2D = $DepartParticles
@onready var light: PointLight2D = $Light
@onready var trigger: PlayerTrigger = get_node(trigger_path)
@onready var camera: Camera2D = get_node(camera_path)
@onready var end_fade: ColorRect = get_node_or_null(end_fade_path)
@onready var end_label: Label = get_node_or_null(end_label_path)

var _base_color: Color
var _played: bool = false


func _ready() -> void:
	_base_color = silhouette.color
	silhouette.modulate.a = 0.0
	depart_burst.visible = false
	depart_burst.modulate.a = 0.0
	light.visible = false
	trigger.triggered.connect(play)


func play() -> void:
	if _played:
		return
	_played = true
	_await_gate_then_run()


func _await_gate_then_run() -> void:
	if wait_for_path != NodePath():
		var gate: Node = get_node(wait_for_path)
		if "is_finished" in gate and not gate.is_finished:
			await gate.finished
	_run_sequence()


func _run_sequence() -> void:
	var base_zoom: Vector2 = camera.zoom
	var zoom_out: Tween = create_tween()
	zoom_out.tween_property(camera, "zoom", camera_zoom_out, camera_ease_duration)

	# PRESENCE - fades into view, distant and unreachable.
	light.visible = true
	var fade_in: Tween = create_tween()
	fade_in.tween_property(silhouette, "modulate:a", 1.0, presence_fade_duration)
	await fade_in.finished

	await get_tree().create_timer(attention_delay).timeout

	# ATTENTION - turns toward the player and briefly brightens. The turn
	# alone may be subtle at this distance, so the color pulse carries
	# the beat: something has noticed you.
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player: Node2D = players[0]
		var dir: float = signf(player.global_position.x - silhouette.global_position.x)
		if dir != 0.0:
			silhouette.scale.x = dir
	var pulse: Tween = create_tween()
	pulse.tween_property(silhouette, "color", attention_color, attention_pulse_duration * 0.5)
	pulse.tween_property(silhouette, "color", _base_color, attention_pulse_duration * 0.5)
	await pulse.finished

	await get_tree().create_timer(departure_delay).timeout

	# DEPARTURE - dissolves via the same burst/fade language as Veyr Step.
	depart_burst.global_position = silhouette.global_position
	depart_burst.visible = true
	depart_burst.modulate.a = 1.0
	depart_burst.scale = Vector2.ONE * 0.3
	depart_particles.restart()
	var dissolve: Tween = create_tween()
	dissolve.set_parallel(true)
	dissolve.tween_property(silhouette, "modulate:a", 0.0, dissolve_duration)
	dissolve.tween_property(depart_burst, "scale", Vector2.ONE * 1.6, dissolve_duration)
	dissolve.tween_property(depart_burst, "modulate:a", 0.0, dissolve_duration)
	await dissolve.finished
	depart_burst.visible = false
	light.visible = false

	var zoom_in: Tween = create_tween()
	zoom_in.tween_property(camera, "zoom", base_zoom, camera_ease_duration)
	await zoom_in.finished

	await _close_slice()
	finished.emit()


## Last beat of the vertical slice: a short quiet pause once Rhaek is
## gone, then fade to black and show the developer-facing end marker.
func _close_slice() -> void:
	await get_tree().create_timer(end_stillness_duration).timeout
	if end_fade:
		var fade_tween: Tween = create_tween()
		fade_tween.tween_property(end_fade, "modulate:a", 1.0, end_fade_duration)
		await fade_tween.finished
	if end_label:
		end_label.text = end_label_text
		end_label.visible = true
