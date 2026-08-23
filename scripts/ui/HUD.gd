extends CanvasLayer
class_name HUD
## Minimal on-screen health/Veyr display. Finds the player via the
## "player" group (same lookup EnemyAI already uses to find the player)
## so it doesn't need manual wiring per region - just instance HUD.tscn.

@onready var health_bar: ResourceBar = $HealthBar
@onready var veyr_bar: ResourceBar = $VeyrBar


func _ready() -> void:
	# Deferred so every node's _ready() (including the player's
	# HealthComponent/VeyrComponent, which set their starting values in
	# their own _ready()) has already run, regardless of sibling order.
	call_deferred("_connect_to_player")


func _connect_to_player() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var health: HealthComponent = player.get_node("HealthComponent")
	var veyr: VeyrComponent = player.get_node("VeyrComponent")
	health.health_changed.connect(_on_health_changed)
	veyr.veyr_changed.connect(_on_veyr_changed)
	_on_health_changed(health.current_health, health.max_health)
	_on_veyr_changed(veyr.current_veyr, veyr.max_veyr)


func _on_health_changed(current: float, max_value: float) -> void:
	health_bar.set_value(current, max_value)


func _on_veyr_changed(current: float, max_value: float) -> void:
	veyr_bar.set_value(current, max_value)
