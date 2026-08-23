extends Area2D
class_name Hurtbox
## Damageable region belonging to an entity. Reports incoming hits to the
## entity's HealthComponent via an exported NodePath, so Hitbox never needs
## to know about HealthComponent directly.

signal hit_received(damage: float, hitbox: Hitbox)
## Emitted instead of (well, alongside - take_damage() still runs and
## still no-ops) applying damage when a hit lands while the owner's
## HealthComponent is invulnerable (e.g. mid Veyr Step). Generic - lets
## systems like Perfect Step detect "an attack would have hit" using the
## existing Hitbox/Hurtbox overlap detection, without a separate combat
## detection system.
signal hit_avoided(damage: float, hitbox: Hitbox)

@export var health_component_path: NodePath
## Optional - only entities with a StabilityComponent (enemies/bosses, not
## the player) need to set this. Leave unset for a Hurtbox with no
## stability interaction.
@export var stability_component_path: NodePath

## The entity this Hurtbox belongs to (its parent) - lets a Hitbox refuse
## to hit a Hurtbox owned by the same entity as itself. Both Hitbox and
## Hurtbox are always direct children of their owning body, matching how
## Player.tscn and Enemy.tscn are structured.
@onready var owner_body: Node = get_parent()

var _health: HealthComponent
var _stability: StabilityComponent


func _ready() -> void:
	monitoring = false
	monitorable = true
	if health_component_path != NodePath():
		_health = get_node(health_component_path)
	if stability_component_path != NodePath():
		_stability = get_node(stability_component_path)


func receive_hit(damage: float, hitbox: Hitbox) -> void:
	hit_received.emit(damage, hitbox)
	if _health and _health.is_invulnerable:
		hit_avoided.emit(damage, hitbox)
	if _health:
		_health.take_damage(damage)
	if _stability and hitbox.stability_damage > 0.0:
		_stability.damage_stability(hitbox.stability_damage)
