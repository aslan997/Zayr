extends CanvasLayer
class_name HUD
## Minimal on-screen health/Veyr/boss-health display. Finds the player
## via the "player" group and a boss via the "boss" group (same lookup
## pattern EnemyAI/BossAI already use to find the player) so it doesn't
## need manual wiring per region - just instance HUD.tscn. The boss bar
## only shows while the player is within vicinity_range of the boss (not
## from the moment a "boss" group node merely exists in the scene, which
## could be far away and not yet encountered) and stays hidden if no
## "boss" group node exists at all.

const BOSS_BAR_HIDE_DELAY: float = 1.0
## Not from a design brief - placeholder, tunable. How close the player
## needs to be to a boss before its health bar appears.
@export var vicinity_range: float = 320.0

@onready var health_bar: ResourceBar = $HealthBar
@onready var veyr_bar: ResourceBar = $VeyrBar
@onready var boss_bar: ResourceBar = $BossBar

var _player: Node2D
var _boss: Node2D
var _boss_dead: bool = false


func _ready() -> void:
	boss_bar.visible = false
	# Deferred so every node's _ready() (including the player's/boss's
	# HealthComponent/VeyrComponent, which set their starting values in
	# their own _ready()) has already run, regardless of sibling order.
	call_deferred("_connect_to_player")
	call_deferred("_connect_to_boss")


func _process(_delta: float) -> void:
	if not _boss or _boss_dead or not _player:
		return
	var in_range: bool = _player.global_position.distance_to(_boss.global_position) <= vicinity_range
	if boss_bar.visible != in_range:
		boss_bar.visible = in_range


func _connect_to_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		return
	var health: HealthComponent = _player.get_node("HealthComponent")
	var veyr: VeyrComponent = _player.get_node("VeyrComponent")
	health.health_changed.connect(_on_health_changed)
	veyr.veyr_changed.connect(_on_veyr_changed)
	_on_health_changed(health.current_health, health.max_health)
	_on_veyr_changed(veyr.current_veyr, veyr.max_veyr)


func _connect_to_boss() -> void:
	_boss = get_tree().get_first_node_in_group("boss")
	if not _boss:
		return
	var health: HealthComponent = _boss.get_node("HealthComponent")
	health.health_changed.connect(_on_boss_health_changed)
	health.died.connect(_on_boss_died)
	_on_boss_health_changed(health.current_health, health.max_health)


func _on_health_changed(current: float, max_value: float) -> void:
	health_bar.set_value(current, max_value)


func _on_veyr_changed(current: float, max_value: float) -> void:
	veyr_bar.set_value(current, max_value)


func _on_boss_health_changed(current: float, max_value: float) -> void:
	boss_bar.set_value(current, max_value)


func _on_boss_died() -> void:
	_boss_dead = true
	# Let the player see the bar hit zero before it disappears.
	get_tree().create_timer(BOSS_BAR_HIDE_DELAY).timeout.connect(func() -> void: boss_bar.visible = false)
