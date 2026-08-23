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
  [ARCHITECTURE.md](ARCHITECTURE.md) principles)
- Stagger / stability system for enemies
- Explicit attack timing windows
- Hitstop on impactful hits
- Controlled, restrained screen shake
- Readable enemy telegraphs

None of this is built yet. This section exists so implementation direction
is agreed before code is written.

## 6. Status

No combat code exists. See [PROGRESS.md](PROGRESS.md) for current milestone
status — the present milestone is movement-only, no combat.
