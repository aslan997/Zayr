extends Node
class_name EnemyAIBase
## Common interface EnemyController expects from any enemy AI variant
## (EnemyAI for the melee enemy, RangedEnemyAI for the ranged one).
## EnemyController only ever talks to these fields/physics_update() - it
## doesn't know or care which concrete AI is driving them, so new enemy
## variants don't require any EnemyController change.

## -1.0 = facing left, 1.0 = facing right.
var facing: float = -1.0
## Horizontal velocity EnemyController should apply this frame.
var move_velocity_x: float = 0.0
## True for the whole duration of an attack (windup through recovery) -
## EnemyController uses this to show a shared "about to/currently
## attacking" tint, on top of whatever attack-specific visual the AI
## itself drives (a melee swing shape, a fired projectile, ...).
var is_attacking: bool = false


func physics_update(_delta: float) -> void:
	pass


## Forcibly ends an in-progress attack (used by EnemyController when
## stability breaks mid-attack - see StabilityComponent). Base no-op;
## subclasses with a Hitbox/attack state override this to clean it up
## properly (deactivate the Hitbox, hide any attack visual, ...).
func cancel_attack() -> void:
	pass
