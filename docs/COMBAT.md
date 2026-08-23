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
- Heavy attack — not yet implemented
- Charged attack — not yet implemented
- Aerial attacks — not yet implemented
- Veyr ranged attack — not yet implemented for the player (the enemy has
  one via the reusable `Projectile` primitive it was built to eventually
  serve — see [ARCHITECTURE.md](ARCHITECTURE.md) §4)
- Perfect Step — not yet implemented (a precision-timing variant of Veyr
  Step, per the original brief; Veyr Step itself doesn't yet reward
  "precise timing" beyond its invulnerability window existing at all —
  see §7's known limitations)

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
  (`Engine.time_scale` dip). Not yet applied to the enemy hitting the
  player.
- **Readable enemy telegraphs** — **implemented**, minimally: the first
  enemy has a slow windup before its hitbox opens, per its own
  `@export`-tunable timing.
- Stagger / stability system for enemies — not built yet.
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
    ranged Veyr attack (§3), not enemy-specific.
  - Both have a `HealthComponent` and `Hurtbox` like the player, and are
    removed from the scene (after a brief fade) when health reaches 0.
    `EnemyController` shows a shared attacking-tint telegraph (on top of
    whichever attack-specific visual the AI drives) whenever
    `ai.is_attacking` is true.
  - No `BossController`; each variant's specific known limitations are in
    [ARCHITECTURE.md](ARCHITECTURE.md) §4.
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
- **Not implemented, deliberately out of scope:** heavy/charged attacks,
  aerial attacks, the ranged Veyr attack, Perfect Step, stagger/stability,
  screen shake, enemy telegraphs.
- **Known simplification:** the attack does not lock or cancel movement/
  dash on its own — they run independently, *except* that Veyr Step (§7)
  can now interrupt an in-progress attack. Revisit the rest once full
  combo/interrupt rules are actually designed; not invented here.

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
  visual is hidden for that same window and restored after. No particle
  "shatter" burst — flagged as a placeholder simplification, see below.

**Known limitations, not fixed:**
- The "dissolve into geometric Veyr particles" part of the brief is only
  partially realized — there's a fading trail line, but no actual burst/
  shard effect at the departure and arrival points. Deferred rather than
  building a particle system for a prototype.
- No distinct reward for *precise* invulnerability timing beyond the
  window existing at all — that's explicitly the not-yet-implemented
  "Perfect Step" from the brief (§3), a separate ability.
- Projectile.tscn's world-collision limitation ([ARCHITECTURE.md](ARCHITECTURE.md)
  §4) doesn't apply here, but the wall-clamp above hasn't been exercised
  against every wall shape in the arena — flagging for manual play-test
  rather than assuming it's airtight everywhere.
