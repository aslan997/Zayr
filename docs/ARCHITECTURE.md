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
│   ├── enemies/         Enemy scenes (Enemy.tscn, RangedEnemy.tscn, Projectile.tscn)
│   ├── bosses/          Boss scenes (not yet populated)
│   ├── regions/         Level/region scenes (test arena lives here for now)
│   ├── ui/               UI scenes (not yet populated)
│   └── interactables/   Interactable object scenes (not yet populated)
│
├── scripts/
│   ├── player/          PlayerController, PlayerMovement, ...
│   ├── combat/          HealthComponent, VeyrComponent, Hitbox, Hurtbox, Projectile
│   ├── enemies/         EnemyController, EnemyAIBase, EnemyAI, RangedEnemyAI
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
the player) are attached this way, and **`PlayerCombat.gd`** (Zayr's Veyr
Edge combo) and **`PlayerVeyrStep.gd`** (his evasive blink) both follow the
same `physics_update()`-called-from-controller pattern as
`PlayerMovement.gd` — see [COMBAT.md](COMBAT.md) §6–7. `PlayerAbilities.gd`
doesn't exist as a separate file; Veyr Step lives directly in its own
component instead, consistent with how combat already works.

### State Machine

`PlayerController.gd` holds a simple enum-based state machine. Only the
states needed so far are implemented:

```
IDLE, RUN, JUMP, FALL, WALL_SLIDE, DASH, AIR_DASH, ATTACK_1, ATTACK_2, ATTACK_3, VEYR_STEP, DEAD
```

The remaining eventual states (`HEAVY_ATTACK, CHARGING, HURT, EMBER, VEIL`)
are **not** implemented yet. `DEAD` exists but is prototype-minimal: no
animation, just a freeze + timed respawn (see §3.2) — there's no `HURT`
state; i-frames now exist (via `HealthComponent.is_invulnerable`, granted
by Veyr Step — see [COMBAT.md](COMBAT.md) §7) but no knockback/stagger
design does yet, so there's nothing to build a dedicated `HURT` state
from. States are derived from movement/combat/step output each physics
frame — the enum can be extended without restructuring the controller,
since transitions are just a `match` on current velocity/contact/ability
state.

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

### 3.2 Death / Respawn

No save system or game-over flow exists (out of scope — see §8), so
`PlayerController` handles `HealthComponent.died` with the minimal thing
that keeps a combat prototype testable: freeze input for
`RESPAWN_DELAY`, then reset position to wherever Zayr started this scene
(`global_position` captured once in `_ready()`) and call the new
`HealthComponent.revive()`. `revive()` deliberately bypasses the
`is_dead()` guard `take_damage()`/`heal()` use, since undoing that guard
is the entire point of reviving. No animation, no game-over screen, no
persistence across scene reloads.

## 4. Enemy Architecture

Mirrors the player's Controller/component split, and is shared across
every enemy variant via a common AI interface:

- **`scripts/enemies/EnemyAIBase.gd`** — the contract `EnemyController`
  programs against: `facing`, `move_velocity_x`, `is_attacking`, and
  `physics_update()`. `EnemyController` never references a concrete AI
  class, so adding a new enemy variant never requires changing it.
- **`scripts/enemies/EnemyController.gd`** — root controller for every
  enemy. Applies gravity, takes `ai.move_velocity_x`, calls
  `move_and_slide()`, and owns hit-flash / attacking-tint / death-fade
  feedback generically (on `HealthComponent.died`: fade out, then
  `queue_free()`).
- **`scenes/enemies/Enemy.tscn`** + **`scripts/enemies/EnemyAI.gd`** —
  the melee variant. `CharacterBody2D` root (same layout conventions as
  `Player.tscn`: origin at feet, `HealthComponent`, `Hurtbox`, plus a
  `Hitbox` with a `SwingVisual` child). Patrols back and forth within
  `patrol_distance` of its spawn point; switches to chasing the player
  within `detection_range`; performs a telegraphed attack (own `Hitbox`,
  standing still) within `attack_range` on a cooldown.
- **`scenes/enemies/RangedEnemy.tscn`** + **`scripts/enemies/
  RangedEnemyAI.gd`** — the ranged variant. Same body/`HealthComponent`/
  `Hurtbox` setup, but no static `Hitbox` — instead it's stationary and,
  within `detection_range`, winds up then fires a **`Projectile`**
  (`scripts/combat/Projectile.gd`, `scenes/enemies/Projectile.tscn`) at
  the player on a cooldown. `Projectile` extends `Hitbox` (a moving,
  single-use one: travels in a straight line, destroys itself on landing
  a hit or after `lifetime`) and is reusable later for Zayr's own
  "Veyr ranged attack" ([COMBAT.md](COMBAT.md) §3, not implemented). A
  fired projectile is reparented to `get_tree().current_scene` (not left
  under the enemy) so it survives if the enemy dies mid-flight, and has
  its `owner_body` explicitly set to the firing enemy (not left to the
  default `get_parent()`, which would resolve to the scene root after
  reparenting) so the same-owner exclusion in §3.1 still means what it
  should.

**Known limitations, not fixed:**
- No ledge/edge detection — melee patrol/chase relies on clear floor; an
  enemy near a ledge could walk off it (the ranged variant doesn't move,
  so it's unaffected).
- No chase leash/return-to-post on the melee enemy — a player could in
  principle nudge it away from its patrol zone by repeatedly stepping
  just inside then outside `detection_range`.
- `Projectile` doesn't collide with world geometry — it passes through
  walls/floors rather than stopping at them, just expires after
  `lifetime`. Fine for the current arena's clear sightlines, would need
  addressing before placing a ranged enemy behind cover.
- The ranged enemy is stationary — no kiting/repositioning to keep its
  distance if the player closes in.

`BossController` doesn't exist yet.

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
- `aim_up` — W / Up Arrow
- `aim_down` — S / Down Arrow
- `veyr_step` — K

`aim_up`/`aim_down` are purely directional-intent inputs for aiming Veyr
Step (see [COMBAT.md](COMBAT.md) §7) — there's no crouch/look-up, so W/S
were free to repurpose. Combined with `move_left`/`move_right`, they give
the 8-directional input Veyr Step reads.

## 8. Known Gaps / Not Yet Decided

- No save system yet.
- No animation system yet (placeholder geometry only).
- Player death respawns in place (see §3.2) — no game-over screen, no
  persistence, no death animation.
- Falling off the test arena still isn't handled — no bottomless-pit
  detection, so falling off an edge just falls forever rather than
  triggering the death/respawn flow above.
- Two enemy variants exist (melee, ranged) — no `BossController`. See §4
  for their specific known limitations (ledge detection, chase leash,
  projectile/world collision, ranged-enemy kiting).
- Veyr Step (see [COMBAT.md](COMBAT.md) §7) has no particle burst yet
  (trail line only), and no "Perfect Step" precision-timing reward. Its
  diagonal-direction math and wall-clamp were headless-validated but hit
  test-harness timing flakiness on the multi-key-combo cases specifically
  (not the core teleport/invulnerability/cooldown, which validated
  cleanly and consistently) — worth a deliberate manual check of a few
  diagonal directions and stepping straight at a wall.
