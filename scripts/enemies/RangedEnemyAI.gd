extends EnemyAIBase
class_name RangedEnemyAI
## Second enemy variant: stays put and fires a Projectile at the player
## instead of melee attacking. Stationary - no movement toward/away from
## the player yet (that would need a "keep at range"/kiting behavior this
## first pass doesn't attempt). Finds the player via the "player" group
## (Player.tscn adds itself to it), same as EnemyAI.

@onready var body: CharacterBody2D = get_parent()

@export var projectile_scene: PackedScene

@export_group("Detection")
@export var detection_range: float = 260.0

@export_group("Ranged Attack")
## Not from the design brief - placeholder, tunable.
@export var attack_windup: float = 0.35
@export var attack_cooldown: float = 1.1
@export var damage: float = 8.0
@export var projectile_speed: float = 260.0
## Where the projectile spawns, relative to this enemy, in its facing
## direction (matches the melee enemy's hit_offset convention).
@export var muzzle_offset: Vector2 = Vector2(20.0, -23.0)

var _attack_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _player: Node2D = null


func physics_update(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	_find_player_if_needed()

	if is_attacking:
		_process_attack(delta)
		return

	if _player == null or not is_instance_valid(_player):
		return

	var to_player: float = _player.global_position.x - body.global_position.x
	if absf(to_player) > detection_range:
		return

	facing = signf(to_player) if to_player != 0.0 else facing

	if _cooldown_timer <= 0.0:
		_start_attack()


func _start_attack() -> void:
	is_attacking = true
	_attack_timer = 0.0


func _process_attack(delta: float) -> void:
	_attack_timer += delta
	if _attack_timer >= attack_windup:
		_fire()
		is_attacking = false
		_cooldown_timer = attack_cooldown


func _fire() -> void:
	if not projectile_scene:
		return
	var proj: Projectile = projectile_scene.instantiate()
	body.get_tree().current_scene.add_child(proj)
	proj.owner_body = body
	proj.global_position = body.global_position + Vector2(muzzle_offset.x * facing, muzzle_offset.y)
	proj.direction = facing
	proj.speed = projectile_speed
	proj.damage = damage
	proj.activate()


func _find_player_if_needed() -> void:
	if _player and is_instance_valid(_player):
		return
	var players: Array = body.get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
