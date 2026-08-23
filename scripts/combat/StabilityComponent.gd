extends Node
class_name StabilityComponent
## Generic enemy stagger/stability pool - separate from HealthComponent
## (an enemy can take health damage without necessarily losing composure).
## Reusable by any enemy or boss via different @export values (see
## docs/COMBAT.md). Self-contained: ticks its own passive regen and
## stagger timer via _physics_process(), so attaching the node is enough -
## nothing needs to call an update method on it.

signal stability_changed(current: float, max: float)
signal staggered
signal recovered_from_stagger

@export var max_stability: float = 50.0
## Stability regenerated per second while not staggered and not full.
@export var recovery_rate: float = 8.0
## How long the staggered state lasts before automatically recovering.
@export var stagger_duration: float = 1.5
## Delay after taking stability damage before passive regen resumes, so
## stability doesn't visibly refill mid-combo.
@export var regen_delay: float = 1.0

var current_stability: float
var is_staggered: bool = false

var _stagger_timer: float = 0.0
var _regen_delay_timer: float = 0.0


func _ready() -> void:
	current_stability = max_stability


func _physics_process(delta: float) -> void:
	if is_staggered:
		_stagger_timer -= delta
		if _stagger_timer <= 0.0:
			_recover_from_stagger()
		return

	_regen_delay_timer = maxf(_regen_delay_timer - delta, 0.0)
	if _regen_delay_timer <= 0.0 and current_stability < max_stability:
		current_stability = minf(current_stability + recovery_rate * delta, max_stability)
		stability_changed.emit(current_stability, max_stability)


## No-op while already staggered - can't become "more" staggered.
func damage_stability(amount: float) -> void:
	if amount <= 0.0 or is_staggered:
		return
	current_stability = maxf(current_stability - amount, 0.0)
	_regen_delay_timer = regen_delay
	stability_changed.emit(current_stability, max_stability)
	if current_stability <= 0.0:
		_enter_stagger()


func _enter_stagger() -> void:
	is_staggered = true
	_stagger_timer = stagger_duration
	staggered.emit()


func _recover_from_stagger() -> void:
	is_staggered = false
	current_stability = max_stability
	stability_changed.emit(current_stability, max_stability)
	recovered_from_stagger.emit()
