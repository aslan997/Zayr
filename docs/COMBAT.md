# Zayr — Combat Design

Combat design and implementation rules. This document records the agreed
design so implementation stays consistent with it. Update as combat
milestones land — see [PROGRESS.md](PROGRESS.md) for current status.

## 1. Philosophy

Combat should be:
- Fast
- Responsive
- Readable
- Deliberate
- Rewarding

Explicitly **not** Soulslike punishment — the game is not intended to be
extremely difficult. Players should feel powerful while still being rewarded
for learning enemy patterns.

## 2. The Veyr Edge

Zayr does not carry a conventional manufactured weapon. His primary combat
tool is the **Veyr Edge** (working name) — a shape of condensed Veyr
manifested around his body, not technically a sword.

- Appears when Zayr attacks, dissolves when inactive
- Feels energetic rather than metallic — geometric characteristics, uses
  shaders/particles where appropriate
- Visually distinct from ordinary fantasy weapons
- Can change form according to the attack performed. Potential forms
  (introduced later, not all at once): Edge, Spear, Crescent, Lance, others.

## 3. Planned Player Combat Actions

- Veyr Edge attacks — **implemented** (§6)
- 3-hit combo — **implemented** (§6)
- Veyr Step — **implemented** (§7). Not a movement ability like the dash —
  an evasive/repositioning blink, hence living in this combat doc rather
  than [ARCHITECTURE.md](ARCHITECTURE.md)'s player-movement section.
- Heavy attack — **implemented** (§8): a single, slower, more deliberate
  swing, not part of the 3-hit combo.
- Charged attack — not yet implemented
- Aerial attacks — not yet implemented
- Veyr ranged attack — not yet implemented for the player (the enemy has
  one via the reusable `Projectile` primitive it was built to eventually
  serve — see [ARCHITECTURE.md](ARCHITECTURE.md) §4)
- Perfect Step — **implemented** (§7.1): rewards precisely timing a Veyr
  Step through an actual incoming enemy attack.

## 4. Resource: Veyr

Veyr is not conventional mana. It regenerates primarily through active
combat — successful attacks, skilled defensive actions, environmental Veyr
sources. Exact regeneration/cost balance is not yet determined.

## 5. Intended Implementation Primitives

Once combat implementation begins, expect:

- **Hitbox / Hurtbox** components (separate, composable, per
  [ARCHITECTURE.md](ARCHITECTURE.md) principles) — **implemented**, see §6.
- **Explicit attack timing windows** — `Hitbox.activate()`/`deactivate()`,
  used by both the player's combo and the first enemy — **implemented**.
- **Hitstop on impactful hits** — **implemented** for the player's attacks
  (`Engine.time_scale` dip). Still not applied to the enemy hitting the
  player (the player's HURT state, §10, uses knockback instead - no
  hitstop was asked for there).
- **Readable enemy telegraphs** — **implemented**, minimally: the first
  enemy has a slow windup before its hitbox opens, per its own
  `@export`-tunable timing.
- **Stagger / stability system for enemies** — **implemented** (§9).
- Controlled, restrained screen shake — not built yet.

## 6. Status

**Veyr Edge 3-hit combo implemented, and the first enemy exists and can
both hit and be hit by the player. See [PROGRESS.md](PROGRESS.md).**

- Two enemy variants exist, sharing a common `EnemyController` +
  `EnemyAIBase` interface (see [ARCHITECTURE.md](ARCHITECTURE.md) §4):
  - **Melee** (`Enemy.tscn`) — patrols near its spawn point, chases the
    player within `detection_range`, and performs its own telegraphed
    attack (reusing `Hitbox`) within `attack_range` on a cooldown.
  - **Ranged** (`RangedEnemy.tscn`) — stationary; within `detection_range`
    it winds up then fires a **`Projectile`** (a moving, single-use
    `Hitbox` — `scripts/combat/Projectile.gd`) at the player on a
    cooldown. `Projectile` is written to be reusable later for Zayr's own
    ranged Veyr attack (§3), not enemy-specific. Now also disappears on
    hitting world geometry rather than passing through it - see §11.
  - Both have a `HealthComponent` and `Hurtbox` like the player, and are
    removed from the scene (after a brief fade) when health reaches 0.
    `EnemyController` shows a shared attacking-tint telegraph (on top of
    whichever attack-specific visual the AI drives) whenever
    `ai.is_attacking` is true.
  - **Mini-boss** (`MiniBoss.tscn`) — extends `EnemyController`/uses the
    same `EnemyAIBase` interface; combines the melee and ranged patterns
    above in one entity (melee within `melee_range`, ranged beyond it up
    to `detection_range`), plus a one-time "phase 2" (shortened cooldowns
    + a base-color shift) below a configurable health ratio. See
    [ARCHITECTURE.md](ARCHITECTURE.md) §4.1 for what it deliberately
    doesn't do (no phase 3, no enrage timer, no boss-unique attack).
- Fixed a latent `Hitbox`/`Hurtbox` gap while adding the enemy: neither
  had any owner-exclusion check, so an entity with both a `Hitbox` and a
  `Hurtbox` (which the player already had, and the enemy now also has)
  could in principle damage itself if its own hitbox and hurtbox
  overlapped. Both now track an `owner_body` and `Hitbox` skips a
  `Hurtbox` owned by the same body.

- `PlayerCombat` (`scripts/player/PlayerCombat.gd`) — reads the `attack`
  input and plays 3 swings, each with its own `@export`-tunable
  windup/active/duration/damage/color. Pressing attack again while a swing
  is playing queues the next one, resolved (with no gap) the instant the
  current swing ends. If nothing is queued by the end of the 3rd swing —
  or a press comes in after it's already landed — the combo resets to
  swing 1 and the usual `attack_cooldown` applies; it does **not**
  instantly loop back into swing 1 (that would let holding the button down
  bypass any recovery entirely).
- Each swing positions/activates a `Hitbox` in Zayr's current facing
  direction and applies a brief hitstop (via `Engine.time_scale`, restored
  afterward) on a landed hit.
- Placeholder Veyr Edge visual: a simple geometric polygon (the "Edge"
  form only — Spear/Crescent/Lance are not implemented), tinted
  differently per swing so combo progress is readable pre-animation. No
  shader/particles yet — flagged as placeholder, not final VFX.
- Per-swing damage (12/12/20) is a placeholder, not from the brief — exact
  combat balance is still TBD.
- **Not implemented, deliberately out of scope:** charged attacks, aerial
  attacks, the ranged Veyr attack, screen shake.
- **Known simplification:** the attack does not lock or cancel movement/
  dash on its own — they run independently, *except* that Veyr Step (§7)
  and the player's own HURT state (§10) can both interrupt an in-progress
  attack. Revisit the rest once full combo/interrupt rules are actually
  designed; not invented here.

### Previous status (combat primitives skeleton)

- `HealthComponent` (`scripts/combat/HealthComponent.gd`) — generic health
  pool (`take_damage`, `heal`, `died` signal). Attached to Zayr.
- `VeyrComponent` (`scripts/combat/VeyrComponent.gd`) — Veyr resource pool
  (`spend`, `add`). **Regeneration rules are intentionally not
  implemented** — §4 above ("regenerates through active combat") isn't
  specific enough to build from yet; this only exposes the manual pool
  API. Attached to Zayr.
- `Hitbox` / `Hurtbox` (`scripts/combat/Hitbox.gd`, `Hurtbox.gd`) —
  `Area2D`-based. A `Hurtbox` reports hits to its owner's
  `HealthComponent`; a `Hitbox` starts disabled and only deals damage
  between `activate()`/`deactivate()`, and won't hit the same `Hurtbox`
  twice within one activation window. Zayr has a `Hurtbox` wired to his
  `HealthComponent`. **No `Hitbox` exists yet anywhere** — that requires
  an actual attack (Veyr Edge) to drive it, which is out of scope here.
- No enemies, no damage sources, no death handling, no UI. See
  [PROGRESS.md](PROGRESS.md) for validation performed.

## 7. Veyr Step

User-specified design (paraphrased from the brief this was built from —
see [PROGRESS.md](PROGRESS.md) for the full milestone entry):

- An instantaneous 8-directional blink — Zayr dissolves into Veyr and
  reappears at the destination, not a fast traveled dash. Deliberately
  **not** a second/faster dash: shorter range than the dash, no travel
  animation, no speed-up.
- Aimed by whatever direction is held at the moment of activation
  (8-way: 4 cardinal + 4 diagonal); defaults to Zayr's current facing
  with no direction held.
- Primarily evasive/repositioning, but usable offensively too (closing
  distance, getting behind an enemy).
- A very short invulnerability window during the transition, rewarding
  precise defensive timing.
- Works identically on the ground and in the air.
- Not spammable — cooldown/resource-gated.
- Can interrupt certain movement/attack states for emergency
  repositioning, but not everything, and not via a full cancel-window
  system (not designed yet, not invented here).
- Visual: brief dissolve, a short trail/afterimage connecting the two
  points, reform at the destination — not a visible travel animation.

**Implemented as described**, in `scripts/player/PlayerVeyrStep.gd`:

- Teleports immediately (`CharacterBody2D.global_position` set directly,
  no traveled motion) in the 8-directional input read from
  `move_left`/`move_right` + two new actions, `aim_up`/`aim_down` (W/S),
  added specifically for this — the project had no vertical input before
  Veyr Step, since it's a side-scroller with no look-up/crouch. Falls
  back to `Movement.facing` with no direction held.
- `step_distance` (90px, less than the dash's 130px) and `step_duration`/
  `step_cooldown` are all `@export`-tunable, per the brief's "prioritize
  responsiveness... over perfect balancing; make important values
  configurable."
- Invulnerability: `HealthComponent` gained an `is_invulnerable` flag
  (generic, not Veyr-Step-specific) that `take_damage()` now checks.
  Set/cleared by `PlayerVeyrStep` for the `step_duration` window.
- Interrupt: on activation, calls `PlayerMovement.cancel_dash()` and
  `PlayerCombat.cancel_attack()` (new methods on each, applying the same
  cooldown a normal end would) — a one-time reset, not a cancel-window
  system. Veyr Step itself can always be triggered regardless of what
  movement/combat are doing (subject to its own cooldown).
- Wall safety: the teleport motion is checked with
  `CharacterBody2D.move_and_collide(motion, true)` (test-only) first, and
  clamped to `get_travel()` if the straight-line path would end inside
  solid geometry — otherwise an 8-directional blink could put Zayr inside
  a wall.
- Visual: a `Line2D` trail (a `top_level` node so its points stay in world
  space independent of Zayr's own transform) drawn between the pre- and
  post-step position, fading over `step_duration`; Zayr's own placeholder
  visual is hidden for that same window and restored after. Plus two
  small 8-pointed-star `Polygon2D` bursts (`DepartBurst`/`ArriveBurst`,
  also `top_level`): the departure one shrinks from `burst_start_scale`
  to `burst_end_scale` (a "shatter"), the arrival one grows the other way
  (a "reform"), both fading out over `step_duration` alongside the trail —
  not a real particle system, but delivers the brief's "dissolve into
  geometric Veyr particles... reform at the destination" without one.

**Known limitations, not fixed:**
- Projectile.tscn's world-collision limitation ([ARCHITECTURE.md](ARCHITECTURE.md)
  §4) doesn't apply here, but the wall-clamp above hasn't been exercised
  against every wall shape in the arena — flagging for manual play-test
  rather than assuming it's airtight everywhere.

### 7.1 Perfect Step

User-specified design (paraphrased — see [PROGRESS.md](PROGRESS.md) for
the milestone entry): when a Veyr Step's invulnerability window is what
stops an actual incoming enemy attack from landing — not merely "used
Veyr Step near an enemy" — reward the precisely-timed evade: a brief
extra hitstop, a stronger version of the normal burst, a small Veyr
refund, and an optional audio cue. Explicitly **not**: a second teleport,
an automatic attack, extended slow-motion, permanent invulnerability, or
a separate input — it's a reactive bonus layered onto a normal step, not
a new ability with its own trigger.

**Implemented in `scripts/player/PlayerVeyrStep.gd`, detected via the
existing Hitbox/Hurtbox system per the brief's explicit instruction (no
separate combat-detection system):**

- `Hurtbox.gd` gained one generic addition: `receive_hit()` now emits a
  new `hit_avoided(damage, hitbox)` signal when the hit lands while the
  owner's `HealthComponent.is_invulnerable` is true (in addition to still
  calling the already-existing no-op `take_damage()`). This is a fact
  about the *Hurtbox*, not about Veyr Step or the player specifically —
  keeps the primitive reusable — so all Perfect-Step-specific behavior
  and tuning lives in `PlayerVeyrStep.gd`, which just listens for it.
- Because an enemy's `Hitbox` only ever overlaps the player's `Hurtbox`
  when it's a genuine attack (the owner-exclusion from §6/Step 6 already
  rules out anything else touching it), `hit_avoided` firing on the
  player's own `Hurtbox` **is** "an actual enemy attack that would have
  hit Zayr" — no additional detection logic was needed.
- Guarded to fire at most once per step (`_perfect_triggered_this_step`)
  and only within a separately-configurable `perfect_detection_window`
  (defaults to the same span as `step_duration`, but independently
  tunable later without touching the invulnerability window itself — the
  brief's "perfect detection window" value).
- On trigger: a separate hitstop (own `perfect_hitstop_duration`/
  `perfect_hitstop_time_scale` exports — not shared with `PlayerCombat`'s
  hitstop), a `perfect_burst_scale_multiplier` applied on top of the
  normal depart/arrive burst scale for the rest of that step, and
  `VeyrComponent.add(perfect_veyr_restore)`.
- Audio: **there is no audio system anywhere in this project** (checked
  before implementing — no `AudioStreamPlayer` usage, `assets/audio/` is
  empty). Per the brief's own "if the audio system is already available"
  condition, one wasn't built. Added a ready-to-use hook instead: an
  `AudioStreamPlayer` child + an exported `perfect_audio_cue: AudioStream`
  defaulting to `null` — silent until a sound asset is assigned, no
  audio-manager infrastructure invented.
- All new tunables live only in `PlayerVeyrStep.gd`'s exports — `Hurtbox`
  only gained the one generic signal, nothing Perfect-Step-specific was
  hardcoded into it, `HealthComponent`, or anywhere else.

## 8. Heavy Attack

User-specified design (paraphrased — see [PROGRESS.md](PROGRESS.md) for
the milestone entry): a slower, more powerful Veyr manifestation dealing
significantly more damage and stability damage than a normal swing, with
a visible startup, an active window, and a recovery — Zayr is fully
vulnerable through all three, since it is explicitly **not** meant to be
an instant high-damage attack. A meaningful alternative to the 3-hit
combo, not a charge system (single deliberate attack, no held-button
scaling). Does not consume Veyr in the initial implementation unless the
architecture makes that particularly appropriate - kept configurable
either way.

**Implemented in `scripts/player/PlayerCombat.gd`, alongside the 3-hit
combo rather than as a separate component** — it needs to reuse the same
`Hitbox`/`SwingVisual` and coordinate mutual exclusion with the combo (a
new component would have meant either duplicating that machinery or
awkwardly reaching across two components for every shared action):

- `heavy_startup` (0.5s default) → `heavy_active_duration` (0.2s) →
  `heavy_recovery` (0.35s), all `@export`-tunable. The hitbox only opens
  after the full startup elapses - confirmed by test (see
  [PROGRESS.md](PROGRESS.md)) that `Hitbox.monitoring` stays `false`
  through startup and only flips once it's over.
- `heavy_damage` (32, placeholder) and `heavy_stability_damage` (40,
  placeholder) are both substantially higher than a combo swing's — the
  stability value in particular is sized to be able to break a regular
  enemy's stability pool (default 40, see §9) in one hit, per "break
  enemy defenses."
- Mutually exclusive with the 3-hit combo in both directions: pressing
  heavy attack while combo-attacking is ignored, and vice versa. Both
  share `PlayerCombat.cancel_attack()` (already used by Veyr Step to
  interrupt an in-progress attack, and now also by the HURT state, §10)
  so an interrupted heavy attack cleans up (deactivates the `Hitbox`,
  resets, applies `heavy_cooldown`) exactly like an interrupted combo
  swing does.
- **Does not grant invulnerability** — no code path in the heavy attack
  touches `HealthComponent`, so Zayr is fully vulnerable through startup/
  active/recovery by simple omission, matching the brief directly.
- `heavy_consumes_veyr` defaults to `false` per the brief; flipping it (
  plus setting `heavy_veyr_cost`) is the only change needed to turn Veyr
  cost on later, without touching any other logic.

## 9. Enemy Stability / Stagger

User-specified design (paraphrased): every enemy has configurable max
stability, takes stability damage from attacks, and enters a stagger/
broken state at zero — unable to attack, clearly telegraphed visually,
recovering after a duration. Reusable by future bosses; the mini-boss
uses the same infrastructure as regular enemies with different values.
Not every attack should interrupt an enemy — normal attacks deal small
stability damage, heavy attacks substantially more. No boss-specific
stagger mechanics yet, and no Perfect Step interaction yet (explicitly
deferred by the brief).

**Implemented as a new generic component,
`scripts/combat/StabilityComponent.gd`**, wired into the existing
Hitbox/Hurtbox flow and the shared `EnemyController` rather than into
each enemy AI script individually:

- `StabilityComponent` is self-contained: `max_stability`,
  `recovery_rate`, `stagger_duration`, `regen_delay` are all `@export`ed,
  and it ticks its own passive regen / stagger timer via
  `_physics_process()` — attaching the node is enough, nothing needs to
  drive it externally.
- `Hitbox` gained an `@export var stability_damage` (0 by default, so a
  Hitbox that doesn't care about stability - e.g. an enemy's attack
  against the player, who has no `StabilityComponent` - simply leaves it
  at 0). `Hurtbox` gained an optional `stability_component_path`
  (unset for the player's `Hurtbox`) and applies stability damage
  alongside health damage in `receive_hit()` when both are present.
- Per docs' "normal attacks small, heavy substantially more": the melee
  enemy's attack deals 8, the ranged enemy's shot deals 6, the boss's
  melee/ranged deal 10/6, and the player's combo swings deal 6/6/8 —
  all placeholders, all `@export`-tunable — against the player's heavy
  attack's 40. None of the regular per-hit values alone breaks a regular
  enemy's default 40-stability pool; the heavy attack does, in one hit.
- **Enforcement lives in `EnemyController`, not per-AI-script**: while
  `stability.is_staggered`, `EnemyController` simply does not call
  `ai.physics_update()` at all that frame - the AI can neither move nor
  attack "for free," with no stagger-awareness code needed in `EnemyAI`,
  `RangedEnemyAI`, or `BossAI` individually. Horizontal velocity eases to
  0 (`stagger_deceleration`) instead of continuing whatever it was doing.
  A `stagger_color` tint is applied (highest-priority visual state, since
  a staggered enemy can't also be mid-attack) for "a clear visual
  indication."
- On the stagger transition, `EnemyController` calls a new
  `EnemyAIBase.cancel_attack()` (mirroring `PlayerMovement`/
  `PlayerCombat`'s own `cancel_attack()` pattern) so an attack interrupted
  mid-swing doesn't leave its `Hitbox` stuck active - each AI overrides it
  to clean up its own attack state (or no-ops, for `RangedEnemyAI`'s
  windup-only case, which has no `Hitbox` to deactivate).
- **Design decision beyond the literal brief, flagged for review:** the
  brief says a staggered enemy "temporarily cannot perform normal
  attacks"; this implementation also freezes its movement (patrol/chase),
  since that fell out naturally from "don't call `physics_update()`" being
  the simplest, most reusable enforcement point. A staggered-but-still-
  patrolling enemy would need per-AI-script awareness instead. If frozen
  movement isn't the intended feel, this is the one thing to revisit.
- Each enemy's stability values differ per the brief's "different values"
  instruction: melee 40, ranged 30 (more fragile), boss 100 (with a
  longer 2.0s `stagger_duration`, vs. 1.5s default) — placeholders.
- **Perfect Step interaction is explicitly not added**, per the brief.

## 10. Player HURT State

User-specified design (paraphrased): Zayr enters a HURT state on a valid
enemy hit - configurable knockback, briefly prevented from acting, a
short damage feedback effect, reduced health, returning to normal control
after a configurable duration. No complex invulnerability - an optional
brief post-hit grace window is fine, but not permanent invulnerability.
Veyr Step's own invulnerability must keep working independently.

**Implemented in `scripts/player/PlayerController.gd`** (a new `HURT`
state, following the same early-return pattern `DEAD` already uses,
rather than a separate component - the state needs tight coordination
with the controller's own input/state-machine loop):

- Listens to the player's own `Hurtbox.hit_received` (not
  `HealthComponent.damaged`, which carries no direction) so knockback can
  be aimed away from the hitbox that landed - falling back to
  away-from-facing if the hitbox is exactly on top of Zayr. Filters out
  hits that didn't actually apply (already dead, already hurt, or
  currently invulnerable) before entering HURT.
- `knockback_force_x`/`knockback_force_y` (220 / -180, a slight upward
  pop - a common knockback convention) are applied once as a velocity
  impulse; the knockback velocity itself does not decay during the hurt
  window (a deliberate simplification - a fixed-velocity slide for a
  fixed duration, not an impulse-with-drag system).
- During `hurt_duration` (0.35s default), input is fully inert - the
  controller returns early before reading any input, applying only
  gravity and `move_and_slide()` directly (not routed through
  `PlayerMovement`, which would reintroduce normal movement/dash logic).
  `PlayerMovement.cancel_dash()` and `PlayerCombat.cancel_attack()` are
  both called on entry.
- `post_hit_invulnerable_duration` (0.5s default, 0 disables it) grants a
  brief grace window afterward, explicitly kept simple (a flat timer, not
  a decaying/stacking system) per the brief.
- **A real bug was found and fixed while implementing this**: granting
  invulnerability synchronously inside the `hit_received` handler ran
  *before* `Hurtbox.receive_hit()` reached its own `take_damage()` call
  for that same hit (both happen within one synchronous call chain), so
  the hit that was supposed to trigger the grace period was blocking its
  own damage. Fixed by deferring the grant with `call_deferred()`, so it
  applies only after the current hit has already been fully processed.
  Caught by the real-engine-loop test in
  [PROGRESS.md](PROGRESS.md), not assumed correct.
- **`HealthComponent.is_invulnerable` was refactored from a plain bool to
  a reference-counted flag** (`add_invulnerability()`/
  `remove_invulnerability()`, true while at least one source is active) -
  necessary, not incidental: Veyr Step and the new post-hit grace window
  are two independent sources that can overlap in time, and a plain bool
  would let whichever one ends first incorrectly cancel the other's
  window. `PlayerVeyrStep.gd`'s two direct assignments were updated to the
  new API (its actual behavior is unchanged - same two moments, same
  duration, same effect).
- Damage feedback: the existing `STATE_DEBUG_COLOR` mechanism already
  distinguishes states by tint, so `HURT` (red) is visible the same way
  every other state already is - no separate flash mechanism was added
  (an older ad-hoc hurt-flash timer that predated the state machine
  properly modeling this was removed, since it's now redundant).

## 11. Projectile World Collision

User-specified design (paraphrased): a projectile should still damage the
player when appropriate, but must disappear on hitting solid world
geometry rather than passing through walls/floors/platforms indefinitely.
Keep it simple - no generalized projectile framework beyond what's
necessary.

**Implemented in `scripts/combat/Projectile.gd`** by listening to
`Area2D.body_entered` (world geometry is `StaticBody2D`, not another
`Area2D`, so it never fires `area_entered`/`hit_landed` - a separate
signal is needed) and `queue_free()`-ing on the first one, same as
landing a hit. `Projectile.tscn`'s `collision_mask` was widened to
include the world layer alongside the hurtbox layer (no new collision
shape or physics body needed).

- **A real, non-obvious engine bug was found and fixed while implementing
  this, confirmed via an isolated headless reproduction (not assumed):**
  the base `Hitbox._ready()` sets `monitorable = false` (correct for a
  melee `Hitbox`, which only ever needs to detect `Hurtbox` *areas*, never
  *bodies*). Empirically, in this Godot version, an `Area2D` with
  `monitorable = false` **does not fire `body_entered` at all** - not
  merely "can't be detected by other areas," as the property's name and
  docs would suggest. `Projectile.gd` (which `extends Hitbox` and
  inherits that `_ready()`) now explicitly sets `monitorable = true`
  after calling `super._ready()`, scoped to `Projectile` only - the base
  `Hitbox` class is untouched, since melee attacks never need body
  detection and this doesn't affect them.
