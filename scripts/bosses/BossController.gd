extends EnemyController
class_name BossController
## Mini-boss controller. Extends EnemyController rather than duplicating
## it - the boss is still just a body with gravity/horizontal velocity
## from its AI and the same hit-flash/attacking-tint/death-fade feedback,
## per the EnemyAIBase contract (see docs/ARCHITECTURE.md). The only
## boss-specific addition is a base-color shift when BossAI's phase 2
## triggers, a cheap and readable "it got angrier" cue.

@export var phase2_color: Color = Color(0.9, 0.25, 0.1)

@onready var boss_ai: BossAI = $AI


func _ready() -> void:
	super._ready()
	boss_ai.phase2_started.connect(_on_phase2_started)


func _on_phase2_started() -> void:
	_base_color = phase2_color
