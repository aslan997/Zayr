extends Node2D
## Root of the vertical slice (see docs/PROGRESS.md). Stage 1 only:
## Awakening chamber + Movement Introduction. Its only job is wiring the
## fall-safety KillZone to the player's existing damage/respawn flow - no
## new death/respawn system, no sequencing framework.

@onready var player: PlayerController = $Player
@onready var kill_zone: PlayerTrigger = $KillZone


func _ready() -> void:
	kill_zone.triggered.connect(_on_kill_zone_triggered)


func _on_kill_zone_triggered() -> void:
	player.health.take_damage(9999.0)
