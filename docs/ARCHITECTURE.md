# Zayr — Architecture

Technical architecture and coding rules. Source of truth for how the codebase
is organized. Update this when structural decisions are made.

## 1. Guiding Principles

- **Modular, not monolithic.** No giant manager files. Prefer many small,
  focused scripts over one script that does everything.
- **Composition over inheritance-heavy hierarchies.** Player/enemy behavior is
  built from focused components (movement, combat, health, etc.), not one
  script owning every responsibility.
- **Data-driven where useful.** Tuning values live in the Inspector via
  `@export`, not as magic numbers buried in code.
- **Small, reviewable changes.** Significant architectural changes are
  explained (what/why/affected files) before being made.

## 2. Project Structure

```
/
├── project.godot
├── scenes/
│   ├── player/          Player scene(s)
│   ├── enemies/         Enemy scenes (not yet populated)
│   ├── bosses/          Boss scenes (not yet populated)
│   ├── regions/         Level/region scenes (test arena lives here for now)
│   ├── ui/               UI scenes (not yet populated)
│   └── interactables/   Interactable object scenes (not yet populated)
│
├── scripts/
│   ├── player/          PlayerController, PlayerMovement, ...
│   ├── combat/          Hitbox/Hurtbox and combat components (not yet populated)
│   ├── enemies/         Enemy AI/controller scripts (not yet populated)
│   ├── bosses/          Boss controller scripts (not yet populated)
│   ├── systems/         Cross-cutting systems (camera, save, dialogue, memory, ...)
│   └── ui/              UI scripts (not yet populated)
│
├── assets/
│   ├── characters/, environments/, vfx/, audio/, fonts/   (empty, placeholder art only so far)
│
├── shaders/             (empty — Veyr Edge VFX shaders will live here later)
│
├── data/
│   ├── enemies/, bosses/, dialogue/, memories/            (empty — data-driven resources later)
│
└── docs/
    ├── GDD.md, ARCHITECTURE.md, COMBAT.md, LORE.md, PROGRESS.md
```

Directories with no content yet contain a `.gitkeep` so the structure is
visible in version control before they're populated.

## 3. Player Architecture

The player is built with composition, split by responsibility:

- **`scenes/player/Player.tscn`** — `CharacterBody2D` root. Owns a
  `CollisionShape2D`, a placeholder visual, and a `Camera2D` (with
  `CameraController.gd`).
- **`scripts/player/PlayerController.gd`** — attached to the `CharacterBody2D`
  root. Reads input, drives the state machine, and delegates all physics math
  to the movement component each physics frame.
- **`scripts/player/PlayerMovement.gd`** — attached to a child `Node` named
  `Movement`. Owns all movement tuning (`@export` vars) and physics math
  (acceleration, gravity, jump, coyote time, jump buffering, wall slide, wall
  jump). Exposes a single `physics_update()` entry point called by the
  controller. Knows nothing about state machine, combat, or input mapping.

This split exists so that combat, health, and abilities can be added later as
additional sibling components (`PlayerCombat.gd`, `HealthComponent.gd`,
`VeyrComponent.gd`, `PlayerAbilities.gd`) without `PlayerController.gd` or
`PlayerMovement.gd` growing to absorb their responsibilities.

### State Machine

`PlayerController.gd` holds a simple enum-based state machine. Only the
states needed by the current milestone are implemented:

```
IDLE, RUN, JUMP, FALL, WALL_SLIDE
```

The full eventual state list (`ATTACK_1/2/3, HEAVY_ATTACK, CHARGING, DASH,
AIR_DASH, HURT, DEAD, EMBER, VEIL`) is **not** implemented yet. States are
derived from movement output each physics frame — the enum can be extended
without restructuring the controller, since transitions are just a `match` on
current velocity/contact state.

A temporary debug visualization (tinting the placeholder polygon per state)
is included purely to make state transitions visible during manual testing
before real animations exist. It is trivial to remove once animations are
added.

## 4. Camera

- **`scripts/systems/CameraController.gd`** — attached to the `Camera2D`
  child of the player. Uses Godot's built-in `position_smoothing_enabled`
  for smooth following (tunable via the built-in
  `position_smoothing_speed` inspector property) and adds a small custom
  horizontal look-ahead offset based on the player's current velocity
  direction, exposed via `@export` and lerped smoothly.
- Camera **limits** (`limit_left/top/right/bottom`) are Godot's built-in
  `Camera2D` properties. Because they are arena-specific, they are **not**
  hardcoded in `Player.tscn` (which must stay reusable across regions).
  Instead each region scene (e.g. `TestArena.tscn`) overrides the limit
  values on the instanced player's `Camera2D` node for that region.

## 5. Collision Layers

Defined in Project Settings → Layer Names → 2D Physics:

- Layer 1: `world`
- Layer 2: `player`

Additional layers (enemy, hitbox, hurtbox, interactable) will be added when
those systems are implemented — not yet needed.

## 6. Input Map

Defined actions (keyboard only for now — gamepad remapping is a later
concern):

- `move_left` — A / Left Arrow
- `move_right` — D / Right Arrow
- `jump` — Space

## 7. Known Gaps / Not Yet Decided

- No save system yet.
- No health/damage/combat components yet.
- No animation system yet (placeholder geometry only).
- Falling off the test arena has no death/respawn handling — out of scope
  until health/save systems exist.
