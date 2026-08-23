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
│   ├── enemies/         Enemy scenes (Enemy.tscn - one enemy so far)
│   ├── bosses/          Boss scenes (not yet populated)
│   ├── regions/         Level/region scenes (test arena lives here for now)
│   ├── ui/               UI scenes (not yet populated)
│   └── interactables/   Interactable object scenes (not yet populated)
│
├── scripts/
│   ├── player/          PlayerController, PlayerMovement, ...
│   ├── combat/          HealthComponent, VeyrComponent, Hitbox, Hurtbox
│   ├── enemies/         EnemyController, EnemyAI
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
additional sibling components without `PlayerController.gd` or
`PlayerMovement.gd` growing to absorb their responsibilities. `HealthComponent`,
`VeyrComponent`, and a `Hurtbox` (all in `scripts/combat/`, reusable beyond
the player) are attached this way, and **`PlayerCombat.gd`** (Zayr's first
Veyr Edge attack) follows the same `physics_update()`-called-from-controller
pattern as `PlayerMovement.gd` — see [COMBAT.md](COMBAT.md) §6.
`PlayerAbilities.gd` doesn't exist yet.

### State Machine

`PlayerController.gd` holds a simple enum-based state machine. Only the
states needed so far are implemented:

```
IDLE, RUN, JUMP, FALL, WALL_SLIDE, DASH, AIR_DASH, ATTACK_1, ATTACK_2, ATTACK_3
```

The remaining eventual states (`HEAVY_ATTACK, CHARGING, HURT, DEAD, EMBER,
VEIL`) are **not** implemented yet. States are derived from
movement output each physics frame — the enum can be extended without
restructuring the controller, since transitions are just a `match` on
current velocity/contact/dash state.

### Dash / Air Dash

Implemented in `PlayerMovement.gd` alongside the rest of the movement math,
following the brief's values (130px distance, 0.16s duration). Horizontal
only (matches the genre convention implied by a single distance value, not
an invented 8-directional system). Air dash is a single charge, consumed on
use and restored on landing. Two implementation defaults were needed that
weren't specified in the brief and are exposed as `@export` for tuning:
`dash_cooldown` (anti-spam recovery after a ground dash) and the fact that
momentum carries after the dash ends rather than hard-resetting to zero.

A temporary debug visualization (tinting the placeholder polygon per state)
is included purely to make state transitions visible during manual testing
before real animations exist. It is trivial to remove once animations are
added.

### 3.1 Hitbox/Hurtbox Ownership

`Hitbox` and `Hurtbox` (`scripts/combat/`) are always direct children of
the entity that owns them (Zayr, an enemy). Both expose an `owner_body`
(their `get_parent()`), and `Hitbox` refuses to hit a `Hurtbox` whose
`owner_body` matches its own — this is what stops an entity damaging
itself now that more than one entity (player + enemy) has both a `Hitbox`
and a `Hurtbox`; it isn't enforced by collision layers, since every
entity's Hitbox/Hurtbox share the same layers (see §6).

## 4. Enemy Architecture

Mirrors the player's Controller/component split:

- **`scenes/enemies/Enemy.tscn`** — `CharacterBody2D` root, same shape/
  layout conventions as `Player.tscn` (origin at feet, `HealthComponent`,
  `Hurtbox`, `Hitbox` with a `SwingVisual` child).
- **`scripts/enemies/EnemyController.gd`** — applies gravity, calls
  `EnemyAI.physics_update()`, and owns this enemy's hit-flash/death-fade
  feedback (on `HealthComponent.died`: fade out, then `queue_free()`).
- **`scripts/enemies/EnemyAI.gd`** — the only implemented behavior so far:
  stationary, detects the player (via the `"player"` group, which
  `Player.tscn` adds itself to) within `detection_range`, faces them, and
  performs a telegraphed attack (own `Hitbox`) within `attack_range` on a
  cooldown. **No movement/chase/patrol yet** — deliberately deferred, see
  [PROGRESS.md](PROGRESS.md).

This is the first enemy in the project. `BossController` and any shared
`EnemyController` base behavior beyond this one enemy don't exist yet —
revisit once a second enemy type shows what's actually common between them,
rather than guessing now.

## 5. Camera

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

## 6. Collision Layers

Defined in Project Settings → Layer Names → 2D Physics:

- Layer 1: `world`
- Layer 2: `player`
- Layer 3: `hitbox`
- Layer 4: `hurtbox`
- Layer 5: `enemy`

A `Hitbox` monitors layer 4 (`collision_mask = 8`) and lives on layer 3;
a `Hurtbox` lives on layer 4, is monitorable, and does not itself monitor
anything (`collision_mask = 0`). Every entity's `Hitbox` and `Hurtbox`
share the same layers 3/4 — a `Hitbox` refusing to hit a `Hurtbox` owned
by the same parent node (see §3.1) is what stops an entity from hitting
itself, not layer separation. `Enemy` bodies physically collide with
`world` only (`collision_mask = 1`), not with the player, so they don't
push each other around. Additional layers (interactable) will be added
when needed.

## 7. Input Map

Defined actions (keyboard only for now — gamepad remapping is a later
concern):

- `move_left` — A / Left Arrow
- `move_right` — D / Right Arrow
- `jump` — Space
- `dash` — Left Shift
- `attack` — J

## 8. Known Gaps / Not Yet Decided

- No save system yet.
- No animation system yet (placeholder geometry only).
- No player death/game-over handling — `HealthComponent.died` exists and
  works (the enemy uses it), but nothing is wired to it on the player.
  Health is generous by default so this hasn't mattered in testing yet;
  flagging so it isn't forgotten once enemies deal real pressure.
- Falling off the test arena has no death/respawn handling — out of scope
  until health/save systems exist.
- Only one enemy type exists — no patrol/chase movement, no ranged/varied
  attacks, no `BossController`.
