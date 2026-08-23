extends Node
class_name EnemyAI
## Minimal first-enemy behavior: stationary until the player enters
## detection_range, faces them, and performs a telegraphed attack (own
## Hitbox) when in attack_range, on a cooldown. No movement/chase/patrol
## yet - see docs/PROGRESS.md for scope. Finds the player via the "player"
## group (Player.tscn adds itself to it).

@onready var body: Node2D = get_parent()
@onready var hitbox: Hitbox = get_parent().get_node("Hitbox")
@onready var swing_visual: Polygon2D = hitbox.get_node("SwingVisual")

@export_group("Detection")
@export var detection_range: float = 140.0
@export var attack_range: float = 40.0

@export_group("Telegraphed Attack")
## Not from the design brief - placeholder, tunable. Deliberately slow/
## readable per docs/COMBAT.md ("readable enemy telegraphs").
@export var attack_windup: float = 0.4
@export var attack_active_duration: float = 0.15
@export var attack_recovery: float = 0.3
@export var attack_cooldown: float = 0.6
@export var damage: float = 10.0
@export var hit_offset: float = 24.0

var facing: float = -1.0
var is_attacking: bool = false

var _attack_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _hitbox_opened: bool = false
var _player: Node2D = null


func _ready() -> void:
	hitbox.damage = damage


func physics_update(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	_find_player_if_needed()

	if is_attacking:
		_process_attack(delta)
		return

	if _player == null or not is_instance_valid(_player):
		_player = null
		return

	var to_player: float = _player.global_position.x - body.global_position.x
	if absf(to_player) > detection_range:
		return

	if to_player != 0.0:
		facing = signf(to_player)

	if absf(to_player) <= attack_range and _cooldown_timer <= 0.0:
		_start_attack()


func _start_attack() -> void:
	is_attacking = true
	_attack_timer = 0.0
	_hitbox_opened = false
	hitbox.position.x = hit_offset * facing
	hitbox.scale.x = facing
	swing_visual.visible = true


func _process_attack(delta: float) -> void:
	_attack_timer += delta
	var total: float = attack_windup + attack_active_duration + attack_recovery

	if not _hitbox_opened and _attack_timer >= attack_windup:
		_hitbox_opened = true
		hitbox.activate()

	if _hitbox_opened and hitbox.monitoring and _attack_timer >= attack_windup + attack_active_duration:
		hitbox.deactivate()
		swing_visual.visible = false

	if _attack_timer >= total:
		is_attacking = false
		_cooldown_timer = attack_cooldown


func _find_player_if_needed() -> void:
	if _player and is_instance_valid(_player):
		return
	var players: Array = body.get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
