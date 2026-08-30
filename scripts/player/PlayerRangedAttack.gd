extends Node
class_name PlayerRangedAttack
## Zayr's Veyr ranged attack (docs/GDD.md §4 "eventual full set" -
## previously unimplemented, see docs/PROGRESS.md). Fires a Projectile -
## the exact primitive RangedEnemyAI/BossAI already use, reused as-is -
## in Zayr's current facing direction. Horizontal only, matching how
## every existing Projectile use already works; full 8-directional aim
## (reusing Veyr Step's aim system) was considered but would mean
## changing Projectile's direction from a float to a Vector2, which is
## shared with every enemy that fires one - not worth that risk here.
##
## Costs Veyr (spent only at the moment it actually fires, not at
## windup start, so an interrupted windup doesn't waste the cost) -
## this is the first thing that gives the Veyr bar an actual purpose in
## normal play. Deliberately never restores Veyr itself (see
## VeyrComponent, PlayerCombat.gd's "Veyr Regeneration" group) - only
## melee hits and Perfect Step do that, specifically so standing back
## and firing ranged shots can't be a self-sustaining loop. Spend here,
## regain by re-engaging in melee.
##
## Mutually exclusive with the combo/heavy/charged attack in both
## directions (see PlayerCombat.gd's matching guard) and cancellable by
## Veyr Step mid-windup, same as the other three attacks.

@export_group("Ranged Attack")
@export var projectile_scene: PackedScene
## Not from a design brief - placeholder, tunable.
@export var windup: float = 0.15
@export var cooldown: float = 0.6
@export var damage: float = 14.0
## Kept small per docs/COMBAT.md: normal attacks shouldn't reliably
## stagger on their own.
@export var stability_damage: float = 6.0
@export var projectile_speed: float = 320.0
@export var muzzle_offset: Vector2 = Vector2(26.0, -23.0)
@export var veyr_cost: float = 15.0
## Recolors the shared Projectile visual so Zayr's shot reads as his
## own ability, not a copy of an enemy's.
@export var projectile_color: Color = Color(0.55, 0.4, 1.0, 1.0)

@onready var body: CharacterBody2D = get_parent()
@onready var movement: PlayerMovement = get_parent().get_node("Movement")
@onready var combat: PlayerCombat = get_parent().get_node("Combat")
@onready var veyr: VeyrComponent = get_parent().get_node("VeyrComponent")

var is_attacking: bool = false

var _windup_timer: float = 0.0
var _cooldown_timer: float = 0.0


func physics_update(delta: float, ranged_just_pressed: bool) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)

	if is_attacking:
		_process_windup(delta)
		return

	if ranged_just_pressed and _cooldown_timer <= 0.0 \
			and not combat.is_attacking and not combat.is_heavy_attacking \
			and not combat.is_charging and not combat.is_charged_attacking \
			and not combat.is_aerial_attacking \
			and veyr.can_spend(veyr_cost):
		_start_attack()


func _start_attack() -> void:
	is_attacking = true
	_windup_timer = 0.0


func _process_windup(delta: float) -> void:
	_windup_timer += delta
	if _windup_timer >= windup:
		_fire()
		is_attacking = false
		_cooldown_timer = cooldown


func _fire() -> void:
	if not projectile_scene or not veyr.spend(veyr_cost):
		return
	var proj: Projectile = projectile_scene.instantiate()
	body.get_tree().current_scene.add_child(proj)
	proj.owner_body = body
	proj.global_position = body.global_position + Vector2(muzzle_offset.x * movement.facing, muzzle_offset.y)
	proj.direction = movement.facing
	proj.speed = projectile_speed
	proj.damage = damage
	proj.stability_damage = stability_damage
	var visual: Polygon2D = proj.get_node_or_null("Visual")
	if visual:
		visual.color = projectile_color
	proj.activate()


## Forcibly aborts an in-progress windup (used by Veyr Step). No Veyr
## was spent yet - spend() only happens at the moment of firing.
func cancel_attack() -> void:
	if not is_attacking:
		return
	is_attacking = false
	_cooldown_timer = cooldown
