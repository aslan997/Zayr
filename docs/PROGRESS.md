# Zayr — Progress

Current implementation status and next milestones. Update this after every
implementation pass.

## Milestone: Combat Prototype — Step 1 (Movement & Arena)

**Status: implemented, headless-validated, needs manual play-test in editor.**

### What exists now

- Full project folder structure per [ARCHITECTURE.md](ARCHITECTURE.md)
  (`scenes/`, `scripts/`, `assets/`, `shaders/`, `data/`, `docs/`), with
  `.gitkeep` placeholders in directories not yet populated.
- Documentation set: `GDD.md`, `ARCHITECTURE.md`, `COMBAT.md`, `LORE.md`,
  `PROGRESS.md` (this file), seeded from the agreed design brief.
- `scenes/player/Player.tscn` — `CharacterBody2D` with collision shape,
  placeholder rectangle visual, `Movement` component, and a `Camera2D`.
- `scripts/player/PlayerController.gd` — input + state machine
  (`IDLE, RUN, JUMP, FALL, WALL_SLIDE`), delegates physics to `Movement`.
- `scripts/player/PlayerMovement.gd` — run/accel/decel, gravity, jump,
  coyote time, jump buffering, wall slide, wall jump. All tuning values
  exposed via `@export` using the brief's starting numbers.
- `scripts/systems/CameraController.gd` — smooth follow (built-in
  `position_smoothing`) + directional look-ahead.
- `scenes/regions/TestArena.tscn` — graybox arena: starting floor, a jump
  gap, a 3-step ascending staircase, a wall-jump corridor (two facing
  walls), and an end ledge. Camera limits overridden per-instance for this
  arena.
- Project settings: input map (`move_left`, `move_right`, `jump`), 2D
  physics layer names (`world` = layer 1, `player` = layer 2), main scene
  set to `TestArena.tscn`.

### How to test

1. Open the project in Godot 4.7 (`project.godot` at the repo root).
2. Run the project (F5). It should launch directly into the test arena.
3. Verify manually:
   - A/D or arrow keys move Zayr left/right with acceleration/deceleration
   - Space jumps; jumping just after walking off a ledge still works
     (coyote time); pressing jump slightly before landing still triggers a
     jump (buffered input)
   - Falling off the starting floor into the gap and jumping across it
   - Climbing the 3-step staircase
   - Sliding down the orange walls of the corridor (wall slide) and wall
     jumping between them to climb up
   - Camera follows smoothly and leans slightly ahead in the movement
     direction
   - The placeholder rectangle changes color per state (temporary debug aid
     — see [ARCHITECTURE.md](ARCHITECTURE.md) §3) as a quick sanity check
     that the state machine is transitioning correctly

### Validation performed by the assistant

- `godot --headless --path . --import` — project imports and parses with
  no errors; `PlayerController`, `PlayerMovement`, `CameraController`
  register correctly as global classes.
- `godot --headless --path . --quit-after 60` — game runs 60 frames
  headless with the player resting on the starting floor; no runtime
  errors (confirms node paths, `@onready` references, collision setup,
  and `move_and_slide()` all work with zero input).
- **Not yet verified:** actual input-driven feel (jump arc, wall-jump
  chaining, coyote/buffer timing "feel") — headless mode has no input
  simulation. This needs a manual play session in the editor, which the
  assistant cannot perform. Please play-test and report anything that
  feels off so tuning values can be adjusted.

### Known limitations

- No death/respawn handling — falling off the arena's edges drops the
  player into open space indefinitely. Out of scope until health/save
  systems exist.
- `wall_jump_horizontal_speed` was not specified in the design brief (only
  vertical wall jump velocity was given); a placeholder value equal to
  `run_speed` (240) was chosen and exposed as `@export` for tuning —
  flagging per the "don't invent, flag gaps" rule.
- No animations — placeholder polygon + debug state-color tint only.
- No combat, enemies, bosses, story, dialogue, memories, save system, or
  final art, per this milestone's explicit scope.

## Next Milestone (not started, awaiting direction)

To be defined — likely candidates per the GDD's incremental scope: dash /
air dash, or a first pass at the Veyr Edge combat primitives (Hitbox/
Hurtbox, HealthComponent). Do not start without explicit approval.
