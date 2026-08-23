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

## Milestone: Combat Prototype — Step 2 (Dash / Air Dash)

**Status: implemented, headless-validated, needs manual play-test in editor.**

Player-validated Step 1 first ("feels right"), then chose this as the next
step from three options (dash/air dash, combat primitives skeleton, or a
first Veyr Edge attack) — dash/air dash picked as the lowest-risk way to
finish the core movement set before touching combat.

### What changed

- `scripts/player/PlayerMovement.gd` — added ground dash and a single-charge
  air dash. Horizontal burst using the brief's values (130px distance,
  0.16s duration → constant velocity for the duration, gravity suspended).
  Air dash charge resets on landing. New `@export_group("Dash")`: dash
  distance/duration, `dash_cooldown` (ground-dash anti-spam, not specified
  in the brief), `air_dash_enabled`.
- `scripts/player/PlayerController.gd` — added `DASH`/`AIR_DASH` states and
  debug tint colors; reads the new `dash` input action.
- `project.godot` — added `dash` input action (Left Shift).
- `scenes/regions/TestArena.tscn` — additively extended past the existing
  end ledge with a dash-practice zone: a gap floor and a higher ledge
  positioned just beyond a plain jump's reach, so reaching it meaningfully
  exercises the air dash. Nothing in the Step 1 geometry was moved. Camera
  `limit_right` widened from 2080 to 2780 to cover it.

See [ARCHITECTURE.md](ARCHITECTURE.md) §3 ("Dash / Air Dash") for the
implementation notes and the two inferred defaults (`dash_cooldown`, and
that post-dash momentum decays naturally rather than hard-resetting).

### How to test

1. Run the project (F5).
2. Left Shift dashes in the current facing direction; on the ground it can
   be repeated (after a short cooldown), in the air it works once until you
   touch the floor again.
3. Past the original end ledge, a new gap + elevated ledge (cyan) requires
   jump + air dash together to reach.
4. The debug rectangle flashes white on a ground dash and yellow on an air
   dash.

### Validation performed by the assistant

- `godot --headless --path . --import` — clean, no errors, all three
  scripts still register as global classes.
- `godot --headless --path . --quit-after 60` — clean, no runtime errors.
- Wrote a throwaway headless test scene (not committed) that ran the dash
  through the **real** engine `_physics_process` loop and logged position
  on every `is_dashing` state transition: ground dash covered 135.4px in
  10 physics frames (target 130px — the ~4% difference is expected
  frame-quantization since 0.16s doesn't divide evenly by the 60Hz physics
  tick, not a bug). Air dash correctly consumed its single charge and
  refused a second attempt while airborne.
- Also tried validating dash distance by calling `PlayerMovement.
  physics_update()` manually in a tight synthetic loop (bypassing the
  engine's real physics scheduling). That approach produced wildly
  inconsistent `move_and_slide()` displacement (up to ~9x expected) and is
  **not** a trustworthy test methodology — confirmed as a harness artifact,
  not a real bug, by cross-checking against the real-loop test above. Noting
  this so a future session doesn't waste time re-deriving it: don't drive
  `CharacterBody2D.move_and_slide()` via manual synchronous calls outside
  the engine's actual physics tick when testing headless; use a
  `SceneTree._process()` override and real input events instead.
- **Not yet verified:** actual dash "feel" (commitment, cooldown pacing,
  whether the momentum-carry after a dash ends feels right) — needs a
  manual play session.

## Milestone: Combat Prototype — Step 3 (Combat Primitives Skeleton)

**Status: implemented, headless-validated (including a real-engine-loop
functional test of the damage flow), needs manual play-test in editor.**

Player confirmed Step 2 ("slide and dash working fine"), then chose this
as the next step from three options (combat primitives skeleton, Veyr
Step, or jumping straight to a Veyr Edge attack) — this one picked as the
foundational, lowest-risk choice.

### What changed

- `scripts/combat/HealthComponent.gd` — generic health pool
  (`take_damage`, `heal`, `is_dead`, `health_changed`/`damaged`/`died`
  signals). Not player-specific — reusable for enemies/bosses later.
- `scripts/combat/VeyrComponent.gd` — Veyr resource pool (`spend`, `add`,
  `veyr_changed` signal). **No regeneration logic** — the brief's "Veyr
  regenerates through active combat" isn't specific enough to implement
  yet (exact balance explicitly TBD per [COMBAT.md](COMBAT.md) §4); adding
  regen rules now would mean inventing a mechanic, not implementing a
  specified one. Flagging this rather than guessing.
- `scripts/combat/Hitbox.gd` / `Hurtbox.gd` — `Area2D` primitives. Hitbox
  starts disabled, only deals damage inside an `activate()`/`deactivate()`
  window, and can't multi-hit the same Hurtbox within one window. Hurtbox
  reports hits to its owner's `HealthComponent` via an exported NodePath.
- `project.godot` — added collision layers 3 (`hitbox`) and 4 (`hurtbox`).
- `scenes/player/Player.tscn` — added `HealthComponent`, `VeyrComponent`,
  and a `Hurtbox` (wired to the `HealthComponent`) as sibling nodes, per
  [ARCHITECTURE.md](ARCHITECTURE.md)'s composition pattern. **No `Hitbox`
  anywhere yet** — nothing exists to trigger one (that's the Veyr Edge
  milestone, out of scope here). No enemies exist either, so none of this
  is reachable from actual play yet — it's foundation only.

### How to test

Nothing is player-visible yet — there's no attack, no enemy, no UI showing
health/Veyr. Running the project should look identical to Step 2. The
components exist and are wired correctly (verified below); the next combat
milestone is what will make them observable in play.

### Validation performed by the assistant

- `godot --headless --path . --import` — clean; `HealthComponent`,
  `VeyrComponent`, `Hitbox`, `Hurtbox` all register as global classes.
- `godot --headless --path . --quit-after 60` — clean, no runtime errors
  (confirms the new Player.tscn nodes and the Hurtbox's NodePath to
  HealthComponent resolve correctly).
- Wrote a throwaway headless test (not committed, following the
  real-engine-loop lesson from Step 2) that spawned the actual Player
  scene plus a standalone `Hitbox`, overlapped it with Zayr's `Hurtbox`,
  and drove `activate()`/`deactivate()` through real physics frames:
  health went 100 → 75 after a 5-frame-long activation window (one hit of
  25 damage, not five — confirms the multi-hit guard works), then → 50 on
  a second activation while still overlapping (confirms reactivation
  correctly allows a fresh hit).

## Next Milestone (not started, awaiting direction)

To be defined — likely candidates: Veyr Step, or a first Veyr Edge attack
(which would now build on the Hitbox/Hurtbox primitives above). Do not
start without explicit approval.
