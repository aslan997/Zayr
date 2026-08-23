extends EnemyAIBase
class_name BossAI
## Mini-boss behavior: stationary until the player enters detection_range,
## then alternates between a melee swing (own Hitbox, close range - same
## pattern as EnemyAI) and a ranged shot (a Projectile, longer range -
## same pattern as RangedEnemyAI) depending on distance to the player. No
## new combat primitive was needed for this - it's the existing ones
## combined in one entity.
##
## Once health drops to phase2_health_ratio, enters a faster "phase 2"
## (shorter cooldowns) and emits phase2_started once - a numeric
## escalation, not a new mechanic.

signal phase2_started

@onready var body: CharacterBody2D = get_parent()
@onready var health: HealthComponent = get_parent().get_node("HealthComponent")
@onready var hitbox: Hitbox = get_parent().get_node("Hitbox")
@onready var swing_visual: Polygon2D = hitbox.get_node("SwingVisual")

@export_group("Detection")
@export var detection_range: float = 220.0
@export var melee_range: float = 55.0

@export_group("Melee Attack")
@export var melee_windup: float = 0.35
@export var melee_active_duration: float = 0.18
@export var melee_recovery: float = 0.25
@export var melee_cooldown: float = 0.5
@export var melee_damage: float = 14.0
@export var melee_hit_offset: float = 30.0

@export_group("Ranged Attack")
@export var projectile_scene: PackedScene
@export var ranged_windup: float = 0.4
@export var ranged_cooldown: float = 1.0
@export var ranged_damage: float = 10.0
@export var projectile_speed: float = 240.0
@export var muzzle_offset: Vector2 = Vector2(30.0, -30.0)

@export_group("Phase 2")
## Not from a design brief - placeholder, tunable. Below this health
## ratio, cooldowns shorten (a faster, more aggressive boss).
@export_range(0.0, 1.0) var phase2_health_ratio: float = 0.5
@export_range(0.1, 1.0) var phase2_cooldown_multiplier: float = 0.65

enum AttackKind { MELEE, RANGED }

var _phase2: bool = false
var _attack_kind: AttackKind = AttackKind.MELEE
var _attack_timer: float = 0.0
var _hitbox_opened: bool = false
var _melee_cooldown_timer: float = 0.0
var _ranged_cooldown_timer: float = 0.0
var _player: Node2D = null


func _ready() -> void:
	health.damaged.connect(_on_damaged)


func _on_damaged(_amount: float) -> void:
	if not _phase2 and health.current_health <= health.max_health * phase2_health_ratio:
		_phase2 = true
		phase2_started.emit()


func physics_update(delta: float) -> void:
	_melee_cooldown_timer = maxf(_melee_cooldown_timer - delta, 0.0)
	_ranged_cooldown_timer = maxf(_ranged_cooldown_timer - delta, 0.0)
	_find_player_if_needed()

	if is_attacking:
		_process_attack(delta)
		return

	if _player == null or not is_instance_valid(_player):
		return

	var to_player: float = _player.global_position.x - body.global_position.x
	var dist: float = absf(to_player)
	if dist > detection_range:
		return

	facing = signf(to_player) if to_player != 0.0 else facing

	if dist <= melee_range and _melee_cooldown_timer <= 0.0:
		_start_attack(AttackKind.MELEE)
	elif dist > melee_range and _ranged_cooldown_timer <= 0.0 and projectile_scene:
		_start_attack(AttackKind.RANGED)


func _start_attack(kind: AttackKind) -> void:
	is_attacking = true
	_attack_kind = kind
	_attack_timer = 0.0
	_hitbox_opened = false
	if kind == AttackKind.MELEE:
		hitbox.position.x = melee_hit_offset * facing
		hitbox.scale.x = facing
		hitbox.damage = melee_damage
		swing_visual.visible = true


func _process_attack(delta: float) -> void:
	_attack_timer += delta
	var cooldown_mult: float = phase2_cooldown_multiplier if _phase2 else 1.0

	if _attack_kind == AttackKind.MELEE:
		var active_end: float = melee_windup + melee_active_duration
		var total: float = active_end + melee_recovery
		if not _hitbox_opened and _attack_timer >= melee_windup:
			_hitbox_opened = true
			hitbox.activate()
		if _hitbox_opened and hitbox.monitoring and _attack_timer >= active_end:
			hitbox.deactivate()
			swing_visual.visible = false
		if _attack_timer >= total:
			is_attacking = false
			_melee_cooldown_timer = melee_cooldown * cooldown_mult
	else:
		if _attack_timer >= ranged_windup:
			_fire_projectile()
			is_attacking = false
			_ranged_cooldown_timer = ranged_cooldown * cooldown_mult


func _fire_projectile() -> void:
	var proj: Projectile = projectile_scene.instantiate()
	body.get_tree().current_scene.add_child(proj)
	proj.owner_body = body
	proj.global_position = body.global_position + Vector2(muzzle_offset.x * facing, muzzle_offset.y)
	proj.direction = facing
	proj.speed = projectile_speed
	proj.damage = ranged_damage
	proj.activate()


func _find_player_if_needed() -> void:
	if _player and is_instance_valid(_player):
		return
	var players: Array = body.get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
