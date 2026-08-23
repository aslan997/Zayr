extends EnemyAIBase
class_name EnemyAI
## Melee enemy behavior: patrols between two points centered on its spawn
## position; when the player enters detection_range, chases them; when
## within attack_range, performs a telegraphed attack (own Hitbox) on a
## cooldown, standing still while doing so. Loses interest and resumes
## patrolling once the player leaves detection_range. Finds the player via
## the "player" group (Player.tscn adds itself to it).

@onready var body: CharacterBody2D = get_parent()
@onready var hitbox: Hitbox = get_parent().get_node("Hitbox")
@onready var swing_visual: Polygon2D = hitbox.get_node("SwingVisual")

@export_group("Patrol")
## Not from the design brief - placeholder, tunable. Deliberately slower
## than the player's run_speed so it reads as a threat to react to, not
## outrun the reader's attention.
@export var move_speed: float = 60.0
## How far each way from spawn it patrols (spawn - patrol_distance to
## spawn + patrol_distance). Relies on the enemy being placed somewhere
## with enough clear floor either side - no ledge/edge detection yet.
@export var patrol_distance: float = 110.0

@export_group("Detection")
@export var detection_range: float = 140.0
@export var attack_range: float = 40.0

@export_group("Telegraphed Attack")
@export var attack_windup: float = 0.4
@export var attack_active_duration: float = 0.15
@export var attack_recovery: float = 0.3
@export var attack_cooldown: float = 0.6
@export var damage: float = 10.0
## Not from a design brief - placeholder, tunable. Kept small per
## docs/COMBAT.md: normal attacks shouldn't reliably stagger on their own.
@export var stability_damage: float = 8.0
@export var hit_offset: float = 24.0

var _attack_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _hitbox_opened: bool = false
var _player: Node2D = null
var _patrol_left_x: float = 0.0
var _patrol_right_x: float = 0.0
var _patrol_target_x: float = 0.0


func _ready() -> void:
	hitbox.damage = damage
	hitbox.stability_damage = stability_damage
	var spawn_x: float = body.global_position.x
	_patrol_left_x = spawn_x - patrol_distance
	_patrol_right_x = spawn_x + patrol_distance
	_patrol_target_x = _patrol_right_x


func physics_update(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	_find_player_if_needed()

	if is_attacking:
		move_velocity_x = 0.0
		_process_attack(delta)
		return

	var to_player_dist: float = INF
	var to_player: float = 0.0
	if _player and is_instance_valid(_player):
		to_player = _player.global_position.x - body.global_position.x
		to_player_dist = absf(to_player)

	if to_player_dist <= attack_range and _cooldown_timer <= 0.0:
		facing = signf(to_player) if to_player != 0.0 else facing
		move_velocity_x = 0.0
		_start_attack()
		return

	if to_player_dist <= detection_range:
		facing = signf(to_player) if to_player != 0.0 else facing
		move_velocity_x = facing * move_speed
	else:
		_patrol(delta)


func _patrol(_delta: float) -> void:
	if absf(body.global_position.x - _patrol_target_x) < 4.0:
		_patrol_target_x = _patrol_left_x if _patrol_target_x == _patrol_right_x else _patrol_right_x
	facing = signf(_patrol_target_x - body.global_position.x)
	move_velocity_x = facing * move_speed


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


func cancel_attack() -> void:
	if not is_attacking:
		return
	is_attacking = false
	hitbox.deactivate()
	swing_visual.visible = false
