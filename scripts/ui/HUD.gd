extends CanvasLayer
class_name HUD
## Minimal on-screen health/Veyr/boss-health display. Finds the player
## via the "player" group and a boss via the "boss" group (same lookup
## pattern EnemyAI/BossAI already use to find the player) so it doesn't
## need manual wiring per region - just instance HUD.tscn. The boss bar
## stays hidden if no "boss" group node exists in the scene.

const BOSS_BAR_HIDE_DELAY: float = 1.0

@onready var health_bar: ResourceBar = $HealthBar
@onready var veyr_bar: ResourceBar = $VeyrBar
@onready var boss_bar: ResourceBar = $BossBar


func _ready() -> void:
	boss_bar.visible = false
	# Deferred so every node's _ready() (including the player's/boss's
	# HealthComponent/VeyrComponent, which set their starting values in
	# their own _ready()) has already run, regardless of sibling order.
	call_deferred("_connect_to_player")
	call_deferred("_connect_to_boss")


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


func _connect_to_boss() -> void:
	var boss: Node = get_tree().get_first_node_in_group("boss")
	if not boss:
		return
	var health: HealthComponent = boss.get_node("HealthComponent")
	health.health_changed.connect(_on_boss_health_changed)
	health.died.connect(_on_boss_died)
	boss_bar.visible = true
	_on_boss_health_changed(health.current_health, health.max_health)


func _on_health_changed(current: float, max_value: float) -> void:
	health_bar.set_value(current, max_value)


func _on_veyr_changed(current: float, max_value: float) -> void:
	veyr_bar.set_value(current, max_value)


func _on_boss_health_changed(current: float, max_value: float) -> void:
	boss_bar.set_value(current, max_value)


func _on_boss_died() -> void:
	# Let the player see the bar hit zero before it disappears.
	get_tree().create_timer(BOSS_BAR_HIDE_DELAY).timeout.connect(func() -> void: boss_bar.visible = false)
