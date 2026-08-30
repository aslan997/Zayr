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
- Charged attack — **implemented** (§15): hold to charge, release to
  strike with damage/stability linearly scaled by charge duration
- Aerial attacks — **implemented** (§14): a downward-angled variant of
  the combo/heavy/charged attack, usable while airborne
- Veyr ranged attack — **implemented** (§13): fires the same
  `Projectile` primitive the enemy ranged attack already used, per the
  reuse it was originally built for (see [ARCHITECTURE.md](ARCHITECTURE.md)
  §4)
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

## 12. Temporary Tuning Values (Step 15)

**Every number below is an explicit placeholder** — none came from a
design brief, none have been balance-tested, and all are `@export`ed
specifically so they're trivial to retune later without touching code.
Approved as-is per [PROGRESS.md](PROGRESS.md) Step 15, listed here in one
place for easy reference when an actual balance pass happens.

**Heavy Attack** (`PlayerCombat.gd`):

| Value | Default |
|---|---|
| `heavy_startup` | 0.5s |
| `heavy_active_duration` | 0.2s |
| `heavy_recovery` | 0.35s |
| `heavy_cooldown` | 0.4s |
| `heavy_damage` | 32 |
| `heavy_stability_damage` | 40 |
| `heavy_hit_offset` | 30px |
| `heavy_consumes_veyr` | `false` |
| `heavy_veyr_cost` | 20 (inert while the above is `false`) |

**Stability / Stagger** (`StabilityComponent.gd` defaults, and
per-scene/per-attack overrides):

| Value | Default |
|---|---|
| `StabilityComponent.max_stability` (component default) | 50 |
| `StabilityComponent.recovery_rate` | 8/s |
| `StabilityComponent.stagger_duration` | 1.5s |
| `StabilityComponent.regen_delay` | 1.0s |
| `Enemy.tscn` (melee) `max_stability` | 40 |
| `RangedEnemy.tscn` `max_stability` | 30 |
| `MiniBoss.tscn` `max_stability` | 100 |
| `MiniBoss.tscn` `stagger_duration` | 2.0s (overrides the 1.5s default) |
| `PlayerCombat.stability_damages` (combo swings 1/2/3) | 6 / 6 / 8 |
| `EnemyAI.stability_damage` (melee enemy's attack) | 8 |
| `RangedEnemyAI.stability_damage` (ranged enemy's shot) | 6 |
| `BossAI.melee_stability_damage` | 10 |
| `BossAI.ranged_stability_damage` | 6 |

**Player HURT** (`PlayerController.gd`):

| Value | Default |
|---|---|
| `hurt_duration` | 0.35s |
| `knockback_force_x` | 220 |
| `knockback_force_y` | -180 (upward pop) |
| `post_hit_invulnerable_duration` | 0.5s (0 disables it) |

**Projectile** (`Projectile.gd` default; per-shooter overrides):

| Value | Default |
|---|---|
| `Projectile.speed` (component default) | 260 |
| `Projectile.lifetime` | 2.0s |
| `RangedEnemyAI.projectile_speed` | 260 |
| `BossAI.projectile_speed` | 240 |
| `Projectile.tscn` `collision_mask` | `9` (world + hurtbox layers) |

`collision_mask` is a structural setting, not a balance value — listed
above for completeness, not something to "retune."

## 13. Ranged Veyr Attack

User asked to add "aerial attacks, ranged Veyr, or charged attacks" and,
when asked which to prioritize, picked the ranged Veyr attack. No
mechanical brief was given (same situation Heavy Attack and Perfect Step
were in before), so the design below was proposed and approved before
implementation, following the project's established process for
unspecified named abilities.

**Implemented in a new component, `scripts/player/PlayerRangedAttack.gd`
— unlike Heavy Attack, not folded into `PlayerCombat.gd`**, because it
doesn't share `PlayerCombat`'s `Hitbox`: it fires a moving `Projectile`,
the same primitive `RangedEnemyAI`/`BossAI` already use, reused as-is
rather than duplicated.

- Brief windup (`windup`, 0.15s default) — just enough to read as a
  beat, not a real telegraph — then fires. **Horizontal only**, matching
  every existing use of `Projectile`. Full 8-directional aim (reusing
  Veyr Step's `aim_up`/`aim_down` system) was considered and explicitly
  deferred: it would mean changing `Projectile.direction` from a `float`
  to a `Vector2`, which is shared with every enemy that fires one — not
  worth that risk for this pass. Could be added later as its own
  increment.
- **Costs Veyr** (`veyr_cost`, 15 default) — the first ability that
  actually spends `VeyrComponent`'s pool in normal play (Heavy Attack's
  equivalent flag defaults to `false`; Perfect Step only ever *adds*
  Veyr). Spent only at the moment of firing (`_fire()`), not at windup
  start, specifically so an interrupted windup (Veyr Step cancelling it
  mid-flight) doesn't waste the cost. With no Veyr regeneration
  designed yet (§4), this makes the ability a genuinely scarce resource
  until Perfect Step refunds it — an intentional consequence of the
  design, not an oversight.
- Mutually exclusive with the combo/heavy attack **in both directions**,
  via a symmetric cross-component check rather than shared state (see
  [ARCHITECTURE.md](ARCHITECTURE.md) §3): `PlayerRangedAttack` won't
  start while `PlayerCombat.is_attacking`/`is_heavy_attacking`, and
  `PlayerCombat` won't start either of its own attacks while
  `PlayerRangedAttack.is_attacking`.
- Cancellable by Veyr Step mid-windup via `cancel_attack()`, same pattern
  as the combo/heavy attack and the HURT state — confirmed via test that
  cancelling mid-windup does not spend Veyr (it hadn't been charged yet).
- The fired `Projectile`'s visual is recolored to the established
  Veyr-violet (`Color(0.55, 0.4, 1.0)`) at runtime so it reads as Zayr's
  own ability, not a copy of an enemy's orange-red shot.
- Input: **Q** — deliberately not a mouse button. The user explicitly
  asked not to use middle mouse ("can have issues"); Q sits right next
  to WASD, reachable without moving the movement hand, same reasoning
  already applied to `veyr_step`'s move to Ctrl.

**Placeholder values** (`PlayerRangedAttack.gd`, all `@export`-tunable,
none from a design brief):

| Value | Default |
|---|---|
| `windup` | 0.15s |
| `cooldown` | 0.6s |
| `damage` | 14 |
| `stability_damage` | 6 |
| `projectile_speed` | 320 |
| `muzzle_offset` | (26, -23) |
| `veyr_cost` | 15 |

### Validation performed by the assistant

Wrote a throwaway real-engine-loop test (not committed, deleted after)
against the actual `TestArena.tscn` and its training dummy: confirmed
Veyr is untouched during the windup and only drops by exactly 15 the
instant it fires; confirmed the shot lands on the dummy for exactly the
configured 14 damage; confirmed pressing the melee attack mid-ranged-
windup — and pressing ranged attack mid-melee-swing — both correctly
refuse (mutual exclusion holds in both directions); confirmed Veyr Step
cancels an in-progress windup and Veyr stays at its pre-windup value
(not further reduced); confirmed the attack correctly refuses to even
start when Veyr is below `veyr_cost`. `godot --headless --path . --import`
and `--quit-after` boot checks were clean on both `TestArena.tscn` and
the vertical slice (which shares `Player.tscn`).

**Not yet verified (needs manual play):** whether the windup timing and
15-Veyr cost feel right in an actual fight, and whether burning through
the Veyr pool this fast (with no regeneration yet) feels like a fair
resource or a frustrating dead end — this is exactly the kind of
balance question that needs a human playing it, not headless proof.

## 14. Aerial Attacks

User's next pick from the same three-option ask (§13). Before proposing
a design, inspected whether attacking while airborne already did
anything, since no code in `PlayerCombat.gd` gates attacks to grounded-
only. Confirmed via a real-engine-loop test that it technically already
works (jump, swing, `Hitbox` activates mid-air) but is barely useful:
the `Hitbox` is horizontal-only at Zayr's own current height, so a
swing while elevated above a ground-level enemy simply misses
vertically even at correct horizontal range — reproduced exactly
(hitbox at y≈501 while the target's hurtbox spans y≈543-593). Reported
this finding before proposing a fix, then implemented an approved
first version.

### Revision: from a positional variant to a genuinely distinct move

The first version (documented in earlier revisions of this section, now
superseded) made Aerial Attack a *positional variant* of the combo/heavy
attack — same `Hitbox`, same damage/timing values, just repositioned and
rotated when `aim_down` was held while airborne. A follow-up requirements
pass explicitly asked for the Aerial Attack to **"have its own hitbox/
timing"** and **"feel meaningfully different from simply performing the
ground attack in the air"** — the original version didn't clear that
bar, since it was literally the ground attack's own values, repositioned.
Reworked accordingly:

- **The tap-based `attack` button, while airborne, now triggers a
  dedicated Aerial Attack instead of the grounded 3-hit combo** —
  `combo_index`/`is_attacking` are never touched while airborne, so it
  doesn't chain into or interrupt combo state. Landing mid-swing doesn't
  cancel it; it just plays out, same as every other attack type here.
- **Own timing** (`aerial_windup` 0.06s → `aerial_active_duration` 0.12s
  → `aerial_recovery` 0.15s → `aerial_cooldown` 0.3s) — deliberately
  short across the board, since being airborne is itself a risk and this
  shouldn't feel sluggish to commit to.
- **Own damage/stability** (`aerial_damage` 16, `aerial_stability_damage`
  8) — between a combo swing's first and last hit, not equal to either,
  so it reads as its own tool rather than a repositioned swing.
- **Own color** (`aerial_color`, teal-green) so the debug-tint state
  (`State.ATTACK_AERIAL`) reads as visually distinct from every other
  attack too.
- Still reuses the shared `Hitbox`/`SwingVisual` node (not a second
  physical object) and the same `_position_hitbox()` helper for the
  `aim_down` → downward-strike behavior — "own hitbox" here means its
  own values driving that shared primitive, the same sense in which
  Heavy Attack already has "its own" `Hitbox` usage distinct from the
  combo's, not a second `Hitbox` node. This keeps "do not create a new
  combat framework" intact — it's the established windup/active/
  recovery shape every other attack in this file already uses.
- Heavy Attack and the charged attack **keep their own pre-existing
  `aim_down` positioning capability unchanged** — this rework only
  redirects what the *light* attack button does specifically while
  airborne; it doesn't touch what heavy/charged attacks do in the air.
- Mutual exclusion extended in both directions: starting an Aerial
  Attack checks `not is_attacking and not is_heavy_attacking`; starting
  the charge or Heavy Attack now also checks `not is_aerial_attacking`;
  `PlayerRangedAttack`'s guard was extended the same way.
- Cancellable by Veyr Step via the same `cancel_attack()` every other
  attack uses.

**Placeholder values** (`PlayerCombat.gd`, all `@export`-tunable, none
from a design brief):

| Value | Default |
|---|---|
| `aerial_windup` | 0.06s |
| `aerial_active_duration` | 0.12s |
| `aerial_recovery` | 0.15s |
| `aerial_cooldown` | 0.3s |
| `aerial_damage` | 16 |
| `aerial_stability_damage` | 8 |
| `aerial_hit_offset` | 26px |
| `aerial_down_offset` | 30px (shared with Heavy Attack/charged attack) |

### Validation performed by the assistant

`godot --headless --path . --import` / `--quit-after` boot checks clean
on both `TestArena.tscn` and the vertical slice.

Wrote a throwaway real-engine-loop test (not committed, deleted after)
confirming: the Aerial Attack starts with its own `aerial_damage` (16),
**not** the combo's 12 — the actual thing this rework needed to fix;
`is_attacking`/`combo_index` are untouched while it plays, confirming no
combo interference; a horizontal aerial swing (no `aim_down`) completes
cleanly on its own timing without touching a ground-level target, the
same known vertical-offset behavior as before, confirming this wasn't
silently changed.

For the `aim_down` downward strike against a **real enemy** (not just
the training dummy, to also confirm stability-damage interaction), input-
driven testing repeatedly hit real headless-testing timing artifacts —
documented in [ARCHITECTURE.md](ARCHITECTURE.md) §9 so they're not
re-diagnosed: a stale `is_on_floor()` reading immediately after a
teleport (the CharacterBody2D cache isn't refreshed until the next
`move_and_slide()`), and `aerial_cooldown` not having actually elapsed
in real physics time between two attack attempts in the same test run
(checking a cooldown timer that reads `0` both "never started" and
"already cleared" is ambiguous — must also check the attack's own
`is_*_attacking` flag). Rather than keep fighting input timing, isolated
the actual thing at risk — the positioning/rotation/damage math — by
calling `PlayerCombat._start_aerial_attack()` directly with `aim_down`
forced and a controlled position, then force-activating the `Hitbox`:
the real melee enemy's health dropped from 40 to exactly 24 (16 damage,
exactly `aerial_damage`), confirming the geometry, rotation, and
stability-damage wiring are all correct independent of input-timing
noise.

A **full regression pass** (real-engine-loop, not committed, deleted
after) confirmed the combo (44 damage for a full 3-hit chain), Heavy
Attack (32, unchanged), the charged attack (14.4 for a quick release,
unchanged), the ranged attack (14 damage, Veyr correctly spent to 85),
Veyr Step (engages and resolves cleanly), Perfect Step (triggers
correctly on an engineered overlap — see §7.1's original technique), and
HURT correctly interrupting an in-progress attack (100 → 90 health, state
transitions to `HURT`) — **none of this regressed** from adding the
Aerial Attack's new states and mutual-exclusion checks.

**Not yet verified (needs manual play):** whether the Aerial Attack's
damage/timing values feel right, whether "light attack while airborne is
now a totally different move than on the ground" reads as intentional
rather than confusing without any in-game explanation, and whether the
`aim_down` downward-strike input feels discoverable in an actual fight
against a moving enemy rather than a stationary or teleported one.

## 15. Charged Attack

The last of the three from the original ask (§13). Proposed a design
before implementing, being deliberately careful: Heavy Attack's own
brief (§8) explicitly said "do not create a complicated charge system,"
so the goal here was the simplest version that still reads as a genuine
charged attack, not a meter/tier system.

**Implemented inside `PlayerCombat.gd`, alongside the combo and heavy
attack — not a separate component**, same reasoning as heavy attack:
it reuses the same `Hitbox`/`SwingVisual` and needs tight mutual-
exclusion coordination with the other two:

- Dedicated hold-to-charge input (`charged_attack`, **E**) — deliberately
  **not** overloading the tap-based `attack` button, which sidesteps any
  tap-vs-hold ambiguity with the 3-hit combo entirely rather than trying
  to disambiguate a quick tap from a held press on the same input.
- Holding charges for up to `charge_max_time` (1.0s default, caps there
  — no "overcharging" past full). Releasing at any point resolves the
  attack: damage and stability damage are linearly interpolated
  (`lerpf`) from a minimum to a maximum based on `charge_timer /
  charge_max_time` — one lerp, not discrete tiers or a visible meter.
  The hitbox opens immediately on release (no further windup — charging
  itself was the windup) and stays active for `charged_active_duration`
  before a short recovery.
- Payoff for committing the full charge is deliberately higher than
  Heavy Attack's fixed values (38 damage / 45 stability at max charge vs
  Heavy's 32/40) — Heavy Attack is instant; this asks the player to hold
  still and stay vulnerable for up to a full second, so full commitment
  should out-damage the instant option.
- Gets the aerial-down variant (§14) for free — `_release_charge()`
  calls the same `_position_hitbox()` helper the combo/heavy attack use,
  so holding aim_down while airborne and releasing a charge strikes
  downward exactly like the other two.
- Mutually exclusive with the combo, heavy attack, and ranged attack in
  all directions: charging/charged-attacking early-returns at the top of
  `physics_update()` before the combo/heavy code paths are even reached
  (so they can't interrupt a charge), starting a charge itself checks
  `not is_attacking and not is_heavy_attacking`, and
  `PlayerRangedAttack`'s own guard was extended to also check `not
  combat.is_charging and not combat.is_charged_attacking`.
- Cancellable by Veyr Step at any point — mid-charge (no Veyr spent,
  no hit dealt, same "cost only committed at actual resolution" pattern
  as the ranged attack) or mid-swing after release, via the same
  `cancel_attack()` every other attack already uses.
- No Veyr cost by default (`charged_consumes_veyr = false`), matching
  Heavy Attack's exact convention — a physical technique, not a
  Veyr-spending one, though the flag exists if that's revisited later.

### Follow-up: progressive charge telegraph

A follow-up requirements pass asked specifically for a "**clear**
charge/startup indication." The original implementation already tinted
Zayr's own debug visual via `State.CHARGING` (the same mechanism every
other state already uses) and dimmed the `SwingVisual` while charging,
but that was a flat dim/bright toggle, not something that visibly
communicated *how* charged the attack was. Added a progressive telegraph
instead: while charging, `SwingVisual`'s scale grows (0.7× → 1.5×) and
opacity brightens (0.35 → 1.0) continuously with `charge_timer /
charge_max_time`, and `_release_charge()` now carries the reached size
into the strike itself (scale 1.0× → 1.6× based on the same charge
fraction) — so a fuller charge visibly *looks* like a bigger hit, not
just a bigger number. Every other attack-start function (`_start_swing`,
`_start_heavy_attack`, `_start_aerial_attack`) now explicitly resets
`swing_visual.scale` back to `Vector2.ONE`, since charging is the only
thing that mutates it.

**Spammability check (also explicitly required)**: even a near-zero-
charge tap still commits to the full `charged_active_duration` +
`charged_recovery` + `charged_cooldown` (0.15s + 0.3s + 0.4s ≈ 0.85s)
before another charged attack can start — a deliberately large minimum
commitment window regardless of how briefly it was held, on top of the
combo/heavy/aerial/ranged attacks all being locked out for that same
window via the shared mutual-exclusion checks.

**Placeholder values** (`PlayerCombat.gd`, all `@export`-tunable, none
from a design brief):

| Value | Default |
|---|---|
| `charge_max_time` | 1.0s |
| `charged_active_duration` | 0.15s |
| `charged_recovery` | 0.3s |
| `charged_cooldown` | 0.4s |
| `charged_min_damage` / `charged_max_damage` | 14 / 38 |
| `charged_min_stability` / `charged_max_stability` | 8 / 45 |
| `charged_hit_offset` | 28px |
| `charged_consumes_veyr` | `false` |

### Validation performed by the assistant

`godot --headless --path . --import` / `--quit-after` boot checks clean
on both `TestArena.tscn` and the vertical slice. Wrote throwaway real-
engine-loop tests (not committed, deleted after) against `TestArena.
tscn`'s training dummy: a quick release (near-zero charge) dealt 14.4
damage, matching the ~14 minimum; a full-duration hold (actually waiting
out the real 1.0s, not simulated) dealt exactly 38.0 damage, the exact
configured maximum — confirming the `lerp` scaling genuinely works
across the full range, not just at one end; confirmed a melee tap is
refused while charging (mutual exclusion holds); confirmed Veyr Step
cancels a held charge with **zero** damage dealt afterward (health
stayed at exactly 60, the dummy's full health, confirming the cancelled
charge never resolved into a hit).

**A real test-harness gotcha hit and solved along the way** (documented
in [ARCHITECTURE.md](ARCHITECTURE.md) §9 so a future session doesn't
re-diagnose it): testing the full sequence — quick-release, then release
and re-press for a full-charge attempt, then mutual exclusion, then
Veyr Step cancellation — all in one throwaway script caused the second
press to silently fail to register as a fresh `is_action_just_pressed()`
edge (`Input.is_action_pressed()` correctly read `true` throughout, but
the charge stayed stuck at exactly one physics tick's accumulated time
and `is_charging` read `false`). Root-caused by re-running the same
full-charge scenario as an **isolated** script with a single press and
no prior release in that run — it worked perfectly, producing the exact
expected 38.0 damage. This is a scripted-testing artifact from
`action_press`/`action_release` cycling within one run, not a bug in
the actual input-handling code (which is a standard, unremarkable
`Input.is_action_just_pressed()`/`is_action_just_released()` pattern
that behaves correctly with real input events during real play).

**Not yet verified (needs manual play):** whether holding a key for up
to a full second feels responsive or sluggish in an actual fight,
whether the damage curve (14 → 38) feels meaningfully rewarding across
its range rather than "just mash it at max charge every time," and
whether committing to a full-second hold ever feels punishing against a
fast/aggressive enemy — exactly the kind of feel question headless
testing can't answer.

## 16. Requirements Audit (Ranged Veyr / Aerial / Charged)

User provided a formal, itemized requirements list for all three
abilities after they'd already been implemented, asking specifically
that each be verified as met — not just "does it work," but "does it
satisfy this list." Going through it line by line:

**Ranged Veyr** — mid-range projectile ✓; complements melee rather than
replaces it ✓ (mutual exclusion + Veyr cost + cooldown mean it can't
substitute for melee as a primary damage loop); configurable damage/
speed/cooldown ✓ (`damage`, `projectile_speed`, `cooldown`); interacts
correctly with the existing Hitbox/Hurtbox architecture ✓ (reuses
`Projectile extends Hitbox` as-is); no new combat framework ✓ (zero new
primitives, only a new component orchestrating existing ones). No
changes needed.

**Aerial Attack** — this is where the audit found a real gap: "own
hitbox/timing" and "feel meaningfully different from simply performing
the ground attack in the air" were **not** met by the original
positional-variant design (same damage/timing as the combo, just
repositioned). Reworked into a genuinely distinct move with its own
windup/active/recovery timing and its own damage/stability values — see
§14's revision writeup above. Now meets both points directly. Useful
against enemies below (aim_down) and during general vertical combat
(default horizontal swing while airborne) ✓. Configurable ✓ (8 new
`@export`s). Still no new combat framework — reuses the shared `Hitbox`
and the same windup/active/recovery shape every other attack here uses.

**Charged Attack** — high-commitment ✓ (up to 1s hold); significantly
higher damage/stability than normal attacks ✓ (38/45 at max charge vs
the combo's 12/12/20 and 6/6/8); meaningful recovery/commitment ✓
(active+recovery+cooldown ≈ 0.85s minimum even on instant release);
not spammable ✓ (same 0.85s minimum window, plus every other attack
locked out for that window too); configurable charge time/damage/
stability/recovery ✓. "Clear charge/startup indication" was upgraded
from a flat dim/bright toggle to a progressive scale+brightness
telegraph (§15's follow-up) specifically because "clear" reads as a
higher bar than what the original flat toggle provided.

**Cross-cutting requirements**: "do not redesign the existing combat
system" — the combo, Heavy Attack, ranged attack's own internals, Veyr
Step, and Perfect Step were not restructured, only extended with
additional mutual-exclusion checks against the new states (confirmed via
the full regression pass in §14). "Do not add abilities beyond these
three" — nothing else was added. "Do not begin Stage 3 or modify the
vertical slice level" — `AvarisVerticalSlice.tscn` was not opened or
touched during this pass; every change in this audit is scoped to
`scripts/player/`, `scripts/systems/CameraController.gd` was untouched,
and `TestArena.tscn` (used for all testing) was not modified either,
only used as the existing test bed. "Use the existing architecture
wherever possible" — no new primitives were created anywhere in this
pass; every change is either a new `@export`-tunable value on an
existing component or a new method following the exact windup/active/
recovery/cooldown shape already established by Heavy Attack.

## 17. Veyr Regeneration

Veyr was spend-only until this pass (see §4, §13) — the ranged attack
gave the pool its first real purpose, but nothing ever refilled it
except Perfect Step's existing refund (§7). The user asked for a
first regeneration pass with an explicit combat-economy intent: Veyr
should come back through *aggressive, skilled melee play*, not through
passive waiting, so that spending it on Veyr tools (the ranged attack)
means temporarily stepping back from the thing that refills it.

```
melee hit / Perfect Step -> gain Veyr -> spend on Veyr tools -> re-engage in melee -> gain Veyr
```

**What restores Veyr, and what deliberately does not:**

| Source | Restores Veyr? | Amount |
|---|---|---|
| Combo hit (any of the 3 swings) that lands | Yes | `veyr_restore_normal` |
| Heavy Attack hit that lands | Yes, more than normal | `veyr_restore_heavy` |
| Aerial Attack hit that lands | Yes | `veyr_restore_aerial` |
| Charged Attack hit that lands | Yes, conservative | `veyr_restore_charged` |
| A swing that misses (hitbox never overlaps a Hurtbox) | No | — |
| Perfect Step (existing, §7) | Yes, the largest single gain | `perfect_veyr_restore` |
| Ranged Veyr attack hit | **No, by design** | — |
| Taking damage (HURT state) | No | — |
| Standing idle / waiting | No | — |

Ranged Veyr never restoring is not a special-cased check — it falls out
of the existing architecture directly. `PlayerCombat.gd`'s shared
`Hitbox` (used by the combo, Heavy Attack, Aerial Attack, and Charged
Attack) is the only Hitbox whose `hit_landed` signal is connected to
`_restore_veyr_on_hit()`. `PlayerRangedAttack.gd`'s `Projectile` is a
*separate* `Hitbox` instance (see §13) whose `hit_landed` is only ever
connected to its own cleanup (`queue_free()` in `Projectile.gd`) — there
is no code path from a projectile hit to `veyr.add()` at all, so a
ranged shot landing physically cannot refund its own cost. This is what
prevents the standing-back-and-firing-indefinitely loop the user
explicitly flagged as the failure mode to avoid.

Taking damage and idling not restoring Veyr are likewise not special
cases — `VeyrComponent` never gained a `_process()` or any automatic
tick, and nothing in `PlayerController.gd`'s hurt-handling
(`_on_hit_received`/`_enter_hurt`) calls `veyr.add()`. `VeyrComponent`
stays exactly what its docstring says: a dumb pool with `spend()`/`add()`
and clamping, never a source of regeneration itself — every gain is
triggered by the specific event that earned it, at the call site of
that event, not inside the component.

### Implementation

All four melee restores live in `PlayerCombat.gd`'s existing
`_on_hitbox_hit_landed()` handler (already connected to the shared
`Hitbox.hit_landed` signal, previously used only to trigger hitstop) via
a new `_restore_veyr_on_hit()` call, which checks which of the four
mutually-exclusive attack-state flags (`is_attacking`,
`is_heavy_attacking`, `is_aerial_attacking`, `is_charged_attacking`) is
active at the moment the hit lands and calls `veyr.add()` with that
attack's own restore amount. New `@export_group("Veyr Regeneration")`
holds all four values. Perfect Step's restore (`PlayerVeyrStep.gd`) was
already implemented in an earlier pass (§7) and needed no changes — it
already calls `veyr.add(perfect_veyr_restore)` from
`_trigger_perfect_step()`, which fires from the real
`Hurtbox.hit_avoided` signal, the same primitive every other
invulnerability-interaction in this project uses.

`veyr.add()` (`VeyrComponent.gd`) already clamped to `max_veyr` before
this pass (`current_veyr = minf(current_veyr + amount, max_veyr)`), so
the "Veyr cannot exceed its maximum" requirement needed no new code —
just verification.

### Placeholder tuning values

Not from a design brief — placeholder, tunable, deliberately
conservative per the user's explicit instruction.

| Value | Default | Notes |
|---|---|---|
| `veyr_restore_normal` (`PlayerCombat.gd`) | 4.0 | Baseline the other three are set relative to |
| `veyr_restore_heavy` (`PlayerCombat.gd`) | 7.0 | Slightly more than normal, per the brief's "heavy attacks restore slightly more" |
| `veyr_restore_aerial` (`PlayerCombat.gd`) | 5.0 | Between normal and heavy — its own risk (airborne commitment), no heavy-style startup |
| `veyr_restore_charged` (`PlayerCombat.gd`) | 6.0 | Flat regardless of charge level — deliberately not scaled like damage/stability, so a longer charge isn't also a bigger Veyr farm |
| `perfect_veyr_restore` (`PlayerVeyrStep.gd`, pre-existing) | 15.0 | Unchanged — already the largest single gain in the kit, satisfying "particularly rewarding" without needing a numeric change |

For scale: the ranged attack costs 15 Veyr, Heavy Attack and Charged
Attack cost 20 each when `*_consumes_veyr` is enabled (both off by
default). A Perfect Step alone refunds a full ranged shot; several
landed melee hits are needed to do the same, by design — melee is the
steady drip, Perfect Step is the reward for precision.

### Explicitly not built (per the user's instructions)

- No consumable mana potions.
- No Veyr pickups from enemies.
- No passive/rapid regeneration (`VeyrComponent` still has no `_process`
  or timer of any kind).
- No resource-combo multipliers (each restore is a flat, independent
  `veyr.add()` call — no streak/combo tracking).
- No new UI (the existing Veyr bar, driven by `veyr_changed`, already
  reflects every gain here with no changes needed).

### Validation performed by the assistant

Headless-validated through the real engine loop (`TestArena.tscn`),
exercising the actual `Hitbox.activate()` → `area_entered` →
`Hurtbox.receive_hit()` → `hit_landed` signal chain for every melee
case (not a bypassed/mocked signal) — attacks were triggered via direct
method calls (`_start_swing()`, `_start_heavy_attack()`,
`_start_aerial_attack()`, `_start_charge()`/`_release_charge()`) to
avoid the project's known input-timing test flakiness (see
[ARCHITECTURE.md](ARCHITECTURE.md) §9), but the hit detection and Veyr
gain themselves ran through the unmodified real signal path:

- Normal combo hit restored exactly `veyr_restore_normal`; a swing
  aimed where it could not connect restored nothing (and dealt no
  damage, confirming it was a genuine miss, not a suppressed hit).
- Heavy Attack hit restored exactly `veyr_restore_heavy`, confirmed
  greater than the normal restore.
- Aerial Attack hit restored exactly `veyr_restore_aerial`.
- Charged Attack hit (full charge) restored exactly
  `veyr_restore_charged`.
- Ranged Veyr attack: confirmed the cost (15) was spent at fire, then
  confirmed the projectile went on to actually land a hit (dummy health
  dropped by the configured ranged damage) with Veyr unchanged from its
  post-fire value — proving the "no restore" case was tested against a
  real landed hit, not a shot that simply missed.
- Perfect Step: engineered the same real-overlap scenario used in prior
  passes (position Zayr at a live enemy attack's Hitbox location,
  force the stepping/invulnerability state, let the real enemy Hitbox
  activate and overlap) and confirmed `hit_avoided` fired and restored
  exactly `perfect_veyr_restore`, confirmed greater than every melee
  restore amount.
- Taking damage: confirmed Veyr is unchanged after a HURT-state hit.
- Max clamp: set Veyr to 98 (2 below max) and landed a 7-restore Heavy
  Attack hit — confirmed it clamped to exactly 100, not 105.
- Light regression: re-confirmed the combo's first-swing damage, and
  ran Veyr Step through a real (non-engineered) step via its own
  `physics_update()` parameters directly (bypassing simulated `Input`
  entirely, sidestepping the project's known just-pressed-in-a-loop
  flakiness) to confirm it still engages and resolves cleanly with the
  new hit-landed handler in place.

One test-harness bug found and fixed during this pass, not a game bug:
the throwaway script's own `SceneTree.current_scene` was never set
after manually instantiating `TestArena.tscn`, so
`PlayerRangedAttack._fire()`'s `body.get_tree().current_scene.add_child(proj)`
call failed (`current_scene` was null) and the ranged-attack test's
projectile silently never spawned. Fixed by setting
`current_scene = arena` right after adding the arena to the tree root;
not worth a new ARCHITECTURE.md bullet since it's specific to
hand-built test scripts that skip normal scene loading, not a general
testing-methodology gotcha like the ones already documented there.

**Not yet verified (needs manual play):** whether these regeneration
amounts feel right in an actual fight — whether melee-only Veyr income
feels rewarding rather than stingy, whether the gap between a ranged
attack's cost and a single melee hit's refund feels like a fair
trade-off, and whether Perfect Step's refund feels like the standout
"mastery" reward it's meant to be relative to everything else here.

## 18. Behavioral Clarification: EnemyAI Detection Ignores Elevation

Found while enhancing the vertical slice's Stage 3 Veyr Step encounter
with real verticality (a raised platform) for the first time in this
project - not a new bug introduced by that pass, a pre-existing trait
of `EnemyAI.gd` that no prior encounter's geometry ever exposed.

`EnemyAI.physics_update()`'s detection and attack-range checks
(`to_player_dist`) are computed from **X distance only** - Y is never
considered. On flat, single-elevation encounters (every one built
before Stage 3) this is invisible: everything is always at the same
height anyway. Once a player can escape **vertically** (a jump, or
Veyr Step) to a spot that's still X-close but now Y-unreachable, an
enemy still considers the player "in range" and will still chase/wind
up/attack based on X alone - it doesn't know it can no longer actually
land the hit.

Consequence observed in testing: luring two melee enemies toward the
same spot and then escaping straight up leaves both still "locked on"
to the player's X position, standing close enough to each other that
their own attacks - aimed at an X position they can't vertically
reach - land on **each other** instead, since `Hitbox` has no
same-faction/team exclusion (see `Hitbox.gd` §"Intended Implementation
Primitives" - it only ever excludes hits against its own `owner_body`).
Confirmed via a real-engine test: two flankers reduced to 32/40 and
6/40 health purely from this, with the player never involved and never
at risk (Veyr Step itself always landed safely; this is not a Veyr
Step or destination-safety issue).

**Not fixed.** This is a general trait of the shared `EnemyAI`/`Hitbox`
architecture, not something scoped to the Stage 3 pass that found it,
and changing detection logic or adding faction exclusion is out of
scope for a Stage 3 encounter addition. Recorded here so a future pass
that touches enemy AI or adds more vertical encounters has the context:
if this ever needs fixing, the two independent options are (a) make
`EnemyAI`'s detection/attack-range checks 2D distance instead of X-only,
or (b) give `Hitbox` a faction/owner-type exclusion so allied hits never
land regardless of position. Neither was attempted here.

## 19. Behavioral Clarification: Projectile Has No Vertical Aim

Found while first attempting to elevate Stage 5's ranged sentry onto a
small platform, as a way to give the ranged encounter "modest
verticality." Related to §18's finding but distinct: this one is about
`Projectile` itself, not `EnemyAI`'s detection.

`Projectile.gd`/`RangedEnemyAI.gd`/`BossAI._fire_projectile()` all fire
a shot that travels **perfectly horizontally** at a fixed Y equal to the
firer's own `muzzle_offset.y` - there is no vertical aim component at
all (`direction` is a `float`, `-1.0` or `1.0`, not a `Vector2`). This
was already true and correct for every previous ranged encounter,
because every ranged enemy so far has stood at the same height as the
player it's shooting at.

The first attempt to put `RangedSentry` up on a small perch broke this
silently and completely: once the shooter's muzzle height no longer
matches a grounded player's ~46px-tall standing collision range, the
shot flies over their head at **every distance**, not just up close -
it doesn't arc or angle, so there is no range at which it would ever
connect. Caught immediately by a real-engine test (the sentry's own
"can it hit an exposed player" check started failing), not shipped.

**Not fixed at the primitive level** - `Projectile` staying horizontal-
only is a deliberate, load-bearing simplification from when the ranged
attack was first built (see §13: "not worth the risk" of touching a
primitive every ranged enemy and the player's own Ranged Veyr all
share). Fixed instead by reverting the sentry to ground level and
moving the "modest verticality" piece of Stage 5's design to a
player-usable platform instead (`SentryPerch`, repositioned away from
the sentry) - verticality for the player to use, not for an enemy to
stand on. If a future encounter genuinely needs an elevated shooter
that can still hit a grounded player, the fix would be giving
`Projectile` a real `Vector2` direction (and updating every call site
that currently passes a `float`) - not attempted here, out of scope for
a Stage 5 content pass.
