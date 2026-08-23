extends Area2D
class_name Hurtbox
## Damageable region belonging to an entity. Reports incoming hits to the
## entity's HealthComponent via an exported NodePath, so Hitbox never needs
## to know about HealthComponent directly.

signal hit_received(damage: float, hitbox: Hitbox)

@export var health_component_path: NodePath

## The entity this Hurtbox belongs to (its parent) - lets a Hitbox refuse
## to hit a Hurtbox owned by the same entity as itself. Both Hitbox and
## Hurtbox are always direct children of their owning body, matching how
## Player.tscn and Enemy.tscn are structured.
@onready var owner_body: Node = get_parent()

var _health: HealthComponent


func _ready() -> void:
	monitoring = false
	monitorable = true
	if health_component_path != NodePath():
		_health = get_node(health_component_path)


func receive_hit(damage: float, hitbox: Hitbox) -> void:
	hit_received.emit(damage, hitbox)
	if _health:
		_health.take_damage(damage)
