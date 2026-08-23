extends Hitbox
class_name Projectile
## A moving, single-use Hitbox - the first ranged enemy's shot, and
## reusable later for Zayr's own "Veyr ranged attack" (docs/COMBAT.md §3,
## not implemented yet). Travels in a straight line at `speed` in
## `direction`, and destroys itself on landing a hit or after `lifetime`,
## whichever comes first. Does not collide with world geometry yet -
## passes through walls/floors rather than stopping at them; flagged as a
## known simplification, not fixed here.
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
	hit_landed.connect(_on_hit_landed)


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_hit_landed(_hurtbox: Hurtbox) -> void:
	queue_free()
