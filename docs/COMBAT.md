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

(Not yet implemented — recorded here for future milestones.)

- Veyr Edge attacks
- 3-hit combo
- Heavy attack
- Charged attack
- Aerial attacks
- Veyr ranged attack
- Veyr Step
- Perfect Step

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

- A minimal first enemy (`scripts/enemies/EnemyController.gd` +
  `EnemyAI.gd`, `scenes/enemies/Enemy.tscn`) patrols near its spawn point,
  chases the player within `detection_range`, and performs its own
  telegraphed attack (reusing `Hitbox`) within `attack_range` on a
  cooldown. It has a `HealthComponent` and `Hurtbox` like the player, and
  is removed from the scene (after a brief fade) when its health reaches
  0. No varied attacks, no `BossController`, no ledge detection or chase
  leash — see [ARCHITECTURE.md](ARCHITECTURE.md) §4.
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
  aerial attacks, the ranged Veyr attack, Veyr Step, Perfect Step,
  stagger/stability, screen shake, enemy telegraphs.
- **Known simplification:** the attack does not lock or cancel movement/
  dash — they run independently. Revisit once combo/interrupt rules are
  actually designed; not invented here.

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
