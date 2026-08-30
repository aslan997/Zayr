extends Node
class_name PlayerCombat
## Zayr's Veyr Edge combo: 3 swings (see docs/COMBAT.md). Reads
## Movement.facing to aim the Hitbox each swing and drives the placeholder
## swing visual. Pressing attack again while a swing is playing queues the
## next swing, resolved the instant the current one ends (no gap between
## chained swings) - this part requires no buffering, since the press
## lands while the swing is still live.
## If nothing was queued by the time a swing ends, the player still has
## combo_chain_window seconds afterward to press again and continue the
## combo (advance to the next swing, or loop back to swing 1 if that was
## the 3rd) - originally this was a hard cutoff at the exact instant a
## swing ended, which needed pressing attack again almost immediately to
## chain at all; combo_chain_window turns that instant into a real grace
## window, per direct feedback that chaining felt like it required
## clicking unreasonably fast. A press inside the window skips
## attack_cooldown entirely (it's a continuation, not a fresh start). Only
## once the window expires does the combo fully reset, requiring
## attack_cooldown before a new swing 1 can begin - so holding/spamming
## the button still can't bypass recovery indefinitely, it just has a more
## forgiving reaction window than before.
## Also owns the heavy attack (see docs/COMBAT.md): a single, slower,
## more deliberate swing - not part of the 3-hit combo, mutually
## exclusive with it (can't start one while the other is active), reusing
## the same Hitbox/SwingVisual rather than a second set of nodes. Zayr is
## fully vulnerable through its startup/active/recovery - it grants no
## invulnerability of its own.
##
## Also owns the Aerial Attack (see docs/COMBAT.md): a dedicated single
## strike - own windup/active/recovery timing, own damage/stability,
## own color - that takes over whenever the tap-based attack button is
## pressed while airborne, instead of the grounded 3-hit combo. Reads
## aim_down the same way Heavy Attack and the charged attack do, to
## strike downward (useful against enemies below) instead of
## horizontally. Deliberately a genuinely distinct move, not just the
## combo's first swing repositioned - see docs/PROGRESS.md for why that
## was revised. Heavy Attack and the charged attack keep their own
## pre-existing aim_down-positioning capability unchanged; this doesn't
## replace that, it only takes over what the light attack button does
## specifically while airborne.
##
## Also owns the charged attack (see docs/COMBAT.md): hold charged_attack
## (a dedicated key, not the tap-based attack button - avoids any tap/
## hold ambiguity with the combo) to charge for up to charge_max_time,
## release to strike with damage/stability linearly scaled from a
## minimum to a maximum based on how long it was held. Reuses the same
## Hitbox/SwingVisual and the aerial-down variant, same as the combo and
## heavy attack.
##
## None of the four attack types lock or interrupt movement/dash on
## their own (Veyr Step can interrupt any of them via cancel_attack()),
## a known simplification until full combo/interrupt rules are designed.
##
## Mutually exclusive with PlayerRangedAttack in both directions (can't
## melee-swing and fire a projectile at once) - see that component's
## own guard against this one.

const COMBO_LENGTH: int = 3

@onready var body: CharacterBody2D = get_parent()
@onready var movement: PlayerMovement = get_parent().get_node("Movement")
@onready var veyr: VeyrComponent = get_parent().get_node("VeyrComponent")
@onready var hitbox: Hitbox = get_parent().get_node("Hitbox")
@onready var swing_visual: Polygon2D = hitbox.get_node("SwingVisual")
@onready var ranged_attack: PlayerRangedAttack = get_parent().get_node("RangedAttack")

@export_group("Veyr Edge Combo")
## Per-swing total duration (index 0..2 = swing 1..3), from swing start
## until it either chains into the next swing or ends.
@export var swing_durations: PackedFloat32Array = [0.35, 0.32, 0.42]
## Per-swing delay before the hitbox becomes active (windup).
@export var hitbox_start_times: PackedFloat32Array = [0.08, 0.07, 0.1]
## Per-swing time the hitbox deactivates again (must be > the matching
## hitbox_start_times entry).
@export var hitbox_end_times: PackedFloat32Array = [0.18, 0.16, 0.24]
## Per-swing damage. Not from the design brief (exact combat balance is
## still TBD per docs/COMBAT.md) - placeholder, tunable.
@export var damages: PackedFloat32Array = [12.0, 12.0, 20.0]
## Per-swing stability damage dealt to enemies (see docs/COMBAT.md's
## StabilityComponent). Not from the design brief - placeholder, tunable.
## Deliberately small: normal attacks shouldn't reliably stagger on their
## own, unlike the heavy attack below.
@export var stability_damages: PackedFloat32Array = [6.0, 6.0, 8.0]
## Per-swing placeholder swing-visual color, purely to make the combo's
## progress readable before real VFX exists.
@export var swing_colors: Array[Color] = [
	Color(0.6, 0.95, 1.0),
	Color(0.55, 0.8, 1.0),
	Color(0.9, 0.75, 1.0),
]
## How far in front of Zayr (in his facing direction) the hitbox is placed.
@export var hit_offset: float = 26.0
## Recovery after the combo fully resets (the chain window below expired
## with nothing pressed) before a fresh swing 1 can start. Does NOT apply
## to a press that lands inside combo_chain_window - that's a
## continuation, not a fresh start.
@export var attack_cooldown: float = 0.1
## How long after a swing ends the player can still press attack to
## continue the combo (advance to the next swing, or loop back to swing 1
## if that was the 3rd) without it counting as a fresh start. Distinct
## from the instant-chain window while a swing is still playing (queueing
## a press then needs no buffering at all, since the swing itself is
## still live) - this is specifically the grace period *after* a swing
## has already ended and nothing was queued yet.
@export var combo_chain_window: float = 1.0

@export_group("Hitstop")
@export var hitstop_duration: float = 0.06
@export_range(0.0, 1.0) var hitstop_time_scale: float = 0.05

@export_group("Heavy Attack")
## Visible charge before the hitbox opens - deliberately much longer than
## a combo swing's windup, per docs/COMBAT.md ("not an instant
## high-damage attack").
@export var heavy_startup: float = 0.5
@export var heavy_active_duration: float = 0.2
@export var heavy_recovery: float = 0.35
## Recovery after the swing ends before another attack (of either kind)
## can start.
@export var heavy_cooldown: float = 0.4
## Not from the design brief - placeholder, tunable. Significantly more
## than a combo swing, per "deal significantly more damage."
@export var heavy_damage: float = 32.0
## Substantial relative to StabilityComponent's default max (50) - meant
## to be able to break a regular enemy's stability in one hit, per
## "break enemy defenses."
@export var heavy_stability_damage: float = 40.0
@export var heavy_hit_offset: float = 30.0
@export var heavy_color: Color = Color(1.0, 0.5, 0.15)
## Off by default per the design brief ("should NOT consume Veyr...
## unless architecture makes it particularly appropriate") - flip on and
## set heavy_veyr_cost to change that later without touching this system.
@export var heavy_consumes_veyr: bool = false
@export var heavy_veyr_cost: float = 20.0

@export_group("Aerial Attack")
## Not from a design brief - placeholder, tunable. How far below Zayr's
## origin the hitbox is placed for a downward strike (hold aim_down
## while airborne and attacking) - shared by the Aerial Attack, Heavy
## Attack, and the charged attack.
@export var aerial_down_offset: float = 30.0
## Deliberately short - being airborne is itself a risk, this shouldn't
## feel sluggish to commit to.
@export var aerial_windup: float = 0.06
@export var aerial_active_duration: float = 0.12
@export var aerial_recovery: float = 0.15
## Recovery after the strike ends before another attack (of any kind)
## can start.
@export var aerial_cooldown: float = 0.3
## Not from a design brief - placeholder, tunable. Between a combo
## swing's first and last hit, reflecting that this is its own distinct
## tool, not a repositioned combo swing.
@export var aerial_damage: float = 16.0
@export var aerial_stability_damage: float = 8.0
@export var aerial_hit_offset: float = 26.0
## Distinct from every other attack's color, so it reads as its own move.
@export var aerial_color: Color = Color(0.4, 0.9, 0.6)

@export_group("Charged Attack")
## Time held to reach full charge - releasing sooner still attacks, just
## scaled down (see charged_min_damage/charged_max_damage below).
@export var charge_max_time: float = 1.0
@export var charged_active_duration: float = 0.15
@export var charged_recovery: float = 0.3
## Recovery after a charged attack ends before another attack (of any
## kind) can start.
@export var charged_cooldown: float = 0.4
## Damage at a just-released (near-zero charge) vs. a full charge. Not
## from a design brief - placeholder, tunable. Deliberately higher than
## Heavy Attack's fixed 32 at full charge, since Heavy Attack is instant
## and this requires committing up to a full second of vulnerability.
@export var charged_min_damage: float = 14.0
@export var charged_max_damage: float = 38.0
@export var charged_min_stability: float = 8.0
@export var charged_max_stability: float = 45.0
@export var charged_hit_offset: float = 28.0
## Distinct from the combo's cyan/blue/violet and Heavy Attack's orange,
## so a charged attack reads as its own thing.
@export var charged_color: Color = Color(0.95, 0.85, 0.25)
## Off by default, same convention as heavy_consumes_veyr.
@export var charged_consumes_veyr: bool = false
@export var charged_veyr_cost: float = 20.0

@export_group("Veyr Regeneration")
## Restores Veyr on a successful (landed) melee hit - see docs/COMBAT.md's
## combat economy: aggressive/skilled play should regain Veyr, not
## passive waiting. Deliberately small per hit; this is the baseline
## the other three restore amounts below are set relative to. Ranged
## Veyr attacks deliberately do NOT restore Veyr (see
## PlayerRangedAttack.gd) - only the shared melee Hitbox (combo/heavy/
## aerial/charged) triggers this, via _on_hitbox_hit_landed below.
@export var veyr_restore_normal: float = 4.0
## Slightly more than a normal hit, reflecting Heavy Attack's greater
## commitment (long startup, fully vulnerable).
@export var veyr_restore_heavy: float = 7.0
## Between normal and heavy - aerial attacks carry their own risk
## (committing to a strike while airborne) without heavy's startup.
@export var veyr_restore_aerial: float = 5.0
## Conservative by design brief instruction ("keep the amount
## conservative") - flat regardless of charge level, not scaled like
## damage/stability are, so charging longer isn't also a Veyr-farming
## strategy.
@export var veyr_restore_charged: float = 6.0

var is_attacking: bool = false
## 0-based index of the swing currently playing (or last played).
var combo_index: int = 0
var is_heavy_attacking: bool = false
var is_charging: bool = false
var is_charged_attacking: bool = false
var is_aerial_attacking: bool = false

var _attack_timer: float = 0.0
var _cooldown_timer: float = 0.0
## Counts down from combo_chain_window once a swing ends with nothing
## queued yet. While > 0, a fresh attack press continues the combo (see
## physics_update) instead of being treated as a cold start.
var _combo_chain_timer: float = 0.0
var _hitbox_opened: bool = false
var _hitbox_closed: bool = false
var _queued_next: bool = false
var _heavy_timer: float = 0.0
var _heavy_hitbox_opened: bool = false
var _heavy_cooldown_timer: float = 0.0
var _base_hitbox_y: float = 0.0
var _aim_down_held: bool = false
var _charge_timer: float = 0.0
var _charged_timer: float = 0.0
var _charged_hitbox_opened: bool = false
var _charged_cooldown_timer: float = 0.0
var _aerial_timer: float = 0.0
var _aerial_hitbox_opened: bool = false
var _aerial_cooldown_timer: float = 0.0


func _ready() -> void:
	_base_hitbox_y = hitbox.position.y
	hitbox.hit_landed.connect(_on_hitbox_hit_landed)


func physics_update(delta: float, attack_just_pressed: bool, heavy_attack_just_pressed: bool, \
		aim_down_held: bool, charge_just_pressed: bool, charge_just_released: bool) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	_heavy_cooldown_timer = maxf(_heavy_cooldown_timer - delta, 0.0)
	_charged_cooldown_timer = maxf(_charged_cooldown_timer - delta, 0.0)
	_aerial_cooldown_timer = maxf(_aerial_cooldown_timer - delta, 0.0)
	_combo_chain_timer = maxf(_combo_chain_timer - delta, 0.0)
	_aim_down_held = aim_down_held

	if is_charged_attacking:
		_process_charged_attack(delta)
		return

	if is_charging:
		_charge_timer = minf(_charge_timer + delta, charge_max_time)
		# Progressive telegraph: grows and brightens as charge builds, so
		# "how charged am I" is visible at a glance, not just a flat
		# dim/bright toggle.
		var progress: float = clampf(_charge_timer / charge_max_time, 0.0, 1.0)
		swing_visual.scale = Vector2.ONE * lerpf(0.7, 1.5, progress)
		swing_visual.modulate.a = lerpf(0.35, 1.0, progress)
		if charge_just_released:
			_release_charge()
		return

	if is_aerial_attacking:
		_process_aerial_attack(delta)
		return

	if is_heavy_attacking:
		_process_heavy_attack(delta)
		return

	if charge_just_pressed and not is_attacking and not is_heavy_attacking \
			and not is_aerial_attacking and _charged_cooldown_timer <= 0.0 \
			and not ranged_attack.is_attacking:
		_start_charge()
		return

	if heavy_attack_just_pressed and not is_attacking and not is_aerial_attacking \
			and _heavy_cooldown_timer <= 0.0 and not ranged_attack.is_attacking:
		_start_heavy_attack()
		return

	if attack_just_pressed and not body.is_on_floor():
		# Airborne: the Aerial Attack takes over the light attack button
		# entirely - it does not chain into or interrupt the grounded
		# combo (combo_index/is_attacking are untouched here).
		if not is_attacking and not is_heavy_attacking and _aerial_cooldown_timer <= 0.0 \
				and not ranged_attack.is_attacking:
			_start_aerial_attack()
		return

	if attack_just_pressed:
		if is_attacking:
			_queued_next = true
		elif _combo_chain_timer > 0.0 and not ranged_attack.is_attacking:
			# Inside the post-swing grace window - continue the combo
			# rather than treating this as a fresh, cooldown-gated start.
			_combo_chain_timer = 0.0
			combo_index = (combo_index + 1) if combo_index < COMBO_LENGTH - 1 else 0
			_start_swing()
		elif _cooldown_timer <= 0.0 and not ranged_attack.is_attacking:
			combo_index = 0
			_start_swing()

	if is_attacking:
		_process_swing(delta)


## Positions the shared Hitbox for whichever swing is starting - the
## normal horizontal placement, or the aerial-down variant (airborne +
## aim_down) which moves it below Zayr and rotates it (and its child
## SwingVisual) 90 degrees to point downward, reusing the same shape
## rather than a second Hitbox/visual set.
func _position_hitbox(horizontal_offset: float) -> void:
	if not body.is_on_floor() and _aim_down_held:
		hitbox.position = Vector2(0.0, aerial_down_offset)
		hitbox.rotation = deg_to_rad(90.0)
		hitbox.scale.x = 1.0
	else:
		hitbox.position = Vector2(horizontal_offset * movement.facing, _base_hitbox_y)
		hitbox.rotation = 0.0
		hitbox.scale.x = movement.facing


func _start_swing() -> void:
	is_attacking = true
	_attack_timer = 0.0
	_hitbox_opened = false
	_hitbox_closed = false
	_queued_next = false
	_position_hitbox(hit_offset)
	hitbox.damage = damages[combo_index]
	hitbox.stability_damage = stability_damages[combo_index]
	swing_visual.color = swing_colors[combo_index]
	swing_visual.visible = true
	swing_visual.modulate.a = 1.0
	swing_visual.scale = Vector2.ONE


func _process_swing(delta: float) -> void:
	_attack_timer += delta
	var start_t: float = hitbox_start_times[combo_index]
	var end_t: float = hitbox_end_times[combo_index]
	var duration: float = swing_durations[combo_index]

	if not _hitbox_opened and _attack_timer >= start_t:
		_hitbox_opened = true
		hitbox.activate()

	if _hitbox_opened and not _hitbox_closed and _attack_timer >= end_t:
		_hitbox_closed = true
		hitbox.deactivate()

	if _attack_timer < end_t:
		swing_visual.modulate.a = 1.0
	else:
		var fade_span: float = maxf(duration - end_t, 0.001)
		swing_visual.modulate.a = 1.0 - clampf((_attack_timer - end_t) / fade_span, 0.0, 1.0)

	if _attack_timer >= duration:
		is_attacking = false
		swing_visual.visible = false
		hitbox.deactivate()
		_advance_or_end_combo()


func _advance_or_end_combo() -> void:
	var has_next_swing: bool = combo_index < COMBO_LENGTH - 1
	if _queued_next and has_next_swing:
		combo_index += 1
		_start_swing()
	else:
		# Either the combo is done, or a press queued during the final
		# swing - either way, don't instantly loop back into swing 1.
		# combo_index is deliberately left as-is (not reset here): a press
		# within combo_chain_window reads it to continue the combo (see
		# physics_update); it only gets explicitly reset to 0 once that
		# window expires and a fresh cold-start swing 1 actually begins.
		_queued_next = false
		_combo_chain_timer = combo_chain_window
		_cooldown_timer = attack_cooldown


func _start_charge() -> void:
	is_charging = true
	_charge_timer = 0.0
	swing_visual.color = charged_color
	swing_visual.visible = true
	swing_visual.modulate.a = 0.5


## Resolves a held charge into the actual strike - the hitbox opens
## immediately (no separate windup; charging up was the windup) and
## deactivates after charged_active_duration.
func _release_charge() -> void:
	var t: float = clampf(_charge_timer / charge_max_time, 0.0, 1.0)
	if charged_consumes_veyr and not veyr.can_spend(charged_veyr_cost):
		is_charging = false
		swing_visual.visible = false
		_charged_cooldown_timer = charged_cooldown
		return
	if charged_consumes_veyr:
		veyr.spend(charged_veyr_cost)

	is_charging = false
	is_charged_attacking = true
	_charged_timer = 0.0
	_charged_hitbox_opened = false
	_position_hitbox(charged_hit_offset)
	hitbox.damage = lerpf(charged_min_damage, charged_max_damage, t)
	hitbox.stability_damage = lerpf(charged_min_stability, charged_max_stability, t)
	swing_visual.color = charged_color
	swing_visual.visible = true
	swing_visual.modulate.a = 1.0
	# Keeps the size the charge grew to during the strike itself too, so
	# a fuller charge visibly lands as a bigger hit, not just more damage.
	swing_visual.scale = Vector2.ONE * lerpf(1.0, 1.6, t)


func _process_charged_attack(delta: float) -> void:
	_charged_timer += delta
	var total: float = charged_active_duration + charged_recovery

	if not _charged_hitbox_opened:
		_charged_hitbox_opened = true
		hitbox.activate()

	if _charged_hitbox_opened and hitbox.monitoring and _charged_timer >= charged_active_duration:
		hitbox.deactivate()

	if _charged_timer < charged_active_duration:
		swing_visual.modulate.a = 1.0
	else:
		var fade_span: float = maxf(charged_recovery, 0.001)
		swing_visual.modulate.a = 1.0 - clampf((_charged_timer - charged_active_duration) / fade_span, 0.0, 1.0)

	if _charged_timer >= total:
		is_charged_attacking = false
		swing_visual.visible = false
		hitbox.deactivate()
		_charged_cooldown_timer = charged_cooldown


## The Aerial Attack: a dedicated single strike with its own timing and
## damage, not the combo/heavy attack repositioned. Same windup/active/
## recovery shape as Heavy Attack, just much shorter - see the "Aerial
## Attack" export group.
func _start_aerial_attack() -> void:
	is_aerial_attacking = true
	_aerial_timer = 0.0
	_aerial_hitbox_opened = false
	_position_hitbox(aerial_hit_offset)
	hitbox.damage = aerial_damage
	hitbox.stability_damage = aerial_stability_damage
	swing_visual.color = aerial_color
	swing_visual.visible = true
	swing_visual.modulate.a = 1.0
	swing_visual.scale = Vector2.ONE


func _process_aerial_attack(delta: float) -> void:
	_aerial_timer += delta
	var active_end: float = aerial_windup + aerial_active_duration
	var total: float = active_end + aerial_recovery

	if not _aerial_hitbox_opened and _aerial_timer >= aerial_windup:
		_aerial_hitbox_opened = true
		hitbox.activate()

	if _aerial_hitbox_opened and hitbox.monitoring and _aerial_timer >= active_end:
		hitbox.deactivate()

	if _aerial_timer < active_end:
		swing_visual.modulate.a = 1.0
	else:
		var fade_span: float = maxf(aerial_recovery, 0.001)
		swing_visual.modulate.a = 1.0 - clampf((_aerial_timer - active_end) / fade_span, 0.0, 1.0)

	if _aerial_timer >= total:
		is_aerial_attacking = false
		swing_visual.visible = false
		hitbox.deactivate()
		_aerial_cooldown_timer = aerial_cooldown


func _start_heavy_attack() -> void:
	if heavy_consumes_veyr:
		if not veyr.can_spend(heavy_veyr_cost):
			return
		veyr.spend(heavy_veyr_cost)

	is_heavy_attacking = true
	_heavy_timer = 0.0
	_heavy_hitbox_opened = false
	_position_hitbox(heavy_hit_offset)
	hitbox.damage = heavy_damage
	hitbox.stability_damage = heavy_stability_damage
	swing_visual.color = heavy_color
	swing_visual.visible = true
	swing_visual.modulate.a = 1.0
	swing_visual.scale = Vector2.ONE


func _process_heavy_attack(delta: float) -> void:
	_heavy_timer += delta
	var active_end: float = heavy_startup + heavy_active_duration
	var total: float = active_end + heavy_recovery

	if not _heavy_hitbox_opened and _heavy_timer >= heavy_startup:
		_heavy_hitbox_opened = true
		hitbox.activate()

	if _heavy_hitbox_opened and hitbox.monitoring and _heavy_timer >= active_end:
		hitbox.deactivate()

	if _heavy_timer < active_end:
		swing_visual.modulate.a = 1.0
	else:
		var fade_span: float = maxf(total - active_end, 0.001)
		swing_visual.modulate.a = 1.0 - clampf((_heavy_timer - active_end) / fade_span, 0.0, 1.0)

	if _heavy_timer >= total:
		is_heavy_attacking = false
		swing_visual.visible = false
		hitbox.deactivate()
		_heavy_cooldown_timer = heavy_cooldown


## Forcibly ends an in-progress attack of either kind (used by systems
## that can interrupt combat, e.g. PlayerVeyrStep). Leaves things reset
## and on cooldown, same as an attack ending normally.
func cancel_attack() -> void:
	if is_aerial_attacking:
		is_aerial_attacking = false
		hitbox.deactivate()
		swing_visual.visible = false
		_aerial_cooldown_timer = aerial_cooldown
		return

	if is_charging:
		is_charging = false
		swing_visual.visible = false
		_charged_cooldown_timer = charged_cooldown
		return

	if is_charged_attacking:
		is_charged_attacking = false
		hitbox.deactivate()
		swing_visual.visible = false
		_charged_cooldown_timer = charged_cooldown
		return

	if is_heavy_attacking:
		is_heavy_attacking = false
		hitbox.deactivate()
		swing_visual.visible = false
		_heavy_cooldown_timer = heavy_cooldown
		return

	if not is_attacking:
		return
	is_attacking = false
	hitbox.deactivate()
	swing_visual.visible = false
	combo_index = 0
	_queued_next = false
	_cooldown_timer = attack_cooldown


func _on_hitbox_hit_landed(_hurtbox: Hurtbox) -> void:
	_apply_hitstop()
	_restore_veyr_on_hit()


## Rewards a successfully landed melee hit with a small Veyr refund - the
## "aggressive play regains Veyr" half of the combat economy (see
## docs/COMBAT.md). Only ever called from a hit via the shared Hitbox
## (combo/heavy/aerial/charged all funnel through hit_landed above), so
## a missed swing restores nothing and the ranged attack's separate
## Projectile Hitbox never reaches this at all.
func _restore_veyr_on_hit() -> void:
	if is_charged_attacking:
		veyr.add(veyr_restore_charged)
	elif is_heavy_attacking:
		veyr.add(veyr_restore_heavy)
	elif is_aerial_attacking:
		veyr.add(veyr_restore_aerial)
	elif is_attacking:
		veyr.add(veyr_restore_normal)


func _apply_hitstop() -> void:
	Engine.time_scale = hitstop_time_scale
	await body.get_tree().create_timer(hitstop_duration, true, false, true).timeout
	Engine.time_scale = 1.0
