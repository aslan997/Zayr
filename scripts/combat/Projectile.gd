extends Hitbox
class_name Projectile
## A moving, single-use Hitbox - the first ranged enemy's shot, and
## reusable later for Zayr's own "Veyr ranged attack" (docs/COMBAT.md §3,
## not implemented yet). Travels in a straight line at `speed` in
## `direction`, and destroys itself on landing a hit, hitting solid world
## geometry, or after `lifetime` - whichever comes first.
##
## World collision is detected via Area2D's own body_entered (world
## geometry is StaticBody2D, not another Area2D, so it doesn't fire
## area_entered/hit_landed) - the scene sets collision_mask to include
## the world layer alongside the hurtbox layer, no extra collision shape
## or physics body needed.
##
## Usage: instantiate, add to the tree, set position/direction/owner_body/
## damage, then call activate() (inherited from Hitbox) - it does nothing
## until activated, same as a melee Hitbox.

@export var speed: float = 260.0
@export var lifetime: float = 2.0

## -1.0 = travels left, 1.0 = travels right.
var direction: float = 1.0

var _age: float = 0.0


func _ready() -> void:
	super._ready()
	# The base Hitbox sets monitorable = false (correct for a melee Hitbox,
	# which only ever needs to detect Hurtbox areas). Empirically, in this
	# Godot version an Area2D with monitorable = false does not fire
	# body_entered at all - not just "can't be detected by others", as the
	# docs' wording implies - so a projectile specifically needs it back on
	# to detect world geometry. Confirmed via an isolated headless
	# reproduction, not assumed.
	monitorable = true
	hit_landed.connect(_on_hit_landed)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_hit_landed(_hurtbox: Hurtbox) -> void:
	queue_free()


func _on_body_entered(_body: Node) -> void:
	queue_free()
