# Zayr — Combat Design

Combat design and implementation rules. **No combat is implemented yet** —
this document records the agreed design so future implementation stays
consistent with it. Update as combat milestones land.

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
  [ARCHITECTURE.md](ARCHITECTURE.md) principles) — **implemented as
  reusable primitives**, see §6.
- Stagger / stability system for enemies
- Explicit attack timing windows — the `Hitbox.activate()`/`deactivate()`
  window is the primitive this will build on
- Hitstop on impactful hits
- Controlled, restrained screen shake
- Readable enemy telegraphs

The items above beyond Hitbox/Hurtbox are not built yet.

## 6. Status

**Combat primitives skeleton implemented, no attacks/enemies yet.**

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
