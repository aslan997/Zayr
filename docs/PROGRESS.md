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

## Milestone: Combat Prototype — Step 4 (First Veyr Edge Attack)

**Status: implemented, headless-validated end-to-end (walk → attack →
damage → hitstop through the real engine loop), needs manual play-test.**

User said "continue" without picking between the two offered options
(Veyr Step vs. a first Veyr Edge attack). Went with the Veyr Edge attack:
Veyr Step's mechanics aren't specified beyond its name in the brief, so
building it now would mean inventing design rather than implementing
agreed design — against the project's own rules. The Veyr Edge attack, by
contrast, already has real spec in [COMBAT.md](COMBAT.md) (appears on
attack, dissolves when inactive, geometric/energetic, "Edge" is one of its
named forms) and the Hitbox/Hurtbox primitives from Step 3 were built
exactly for this.

### What changed

- `scripts/player/PlayerCombat.gd` — new sibling component (same
  `physics_update()`-from-controller pattern as `PlayerMovement`). Reads
  `attack` input, drives a windup/active/recovery timeline, positions and
  activates the `Hitbox` in Zayr's facing direction, fades a placeholder
  swing visual, and applies a brief hitstop (`Engine.time_scale` dip,
  auto-restored) on a landed hit.
- `scenes/player/Player.tscn` — added a `Combat` node and a `Hitbox` (with
  a `SwingVisual` polygon child — the "Edge" form only, per
  [COMBAT.md](COMBAT.md) §2: not all forms are implemented at once).
- `scripts/player/PlayerController.gd` — added `ATTACK_1` state, reads the
  `attack` input; the debug-visual facing flip now uses
  `movement.facing` instead of instantaneous velocity, so it's correct
  even while standing still and attacking.
- `scripts/player/PlayerMovement.gd` — `_facing` renamed to public
  `facing` so `PlayerCombat` (and the controller's debug flip) can read
  Zayr's aim direction. No behavior change.
- `project.godot` — added `attack` input action (J).
- `scenes/regions/TestArena.tscn` — added a **training dummy** test
  fixture (`TrainingDummy`, with its own embedded/inline script, not a
  reusable class) near the player's spawn: a `HealthComponent` +
  `Hurtbox` target that flashes on hit and resets its own health, purely
  so the new attack has something to visibly land on. This is explicitly
  a debug fixture, not a real enemy/interactable — delete it when actual
  enemies exist.

### Known simplification

The attack doesn't lock or interrupt movement/dash — both systems run
independently right now. Combo/interrupt rules aren't designed yet
(see [COMBAT.md](COMBAT.md) §6), so this wasn't invented; revisit when
they are.

### How to test

1. Run the project (F5).
2. Walk right to the red training dummy near the start.
3. Press J to swing — a cyan blade shape flashes in Zayr's facing
   direction, the debug rectangle turns teal, and on a landed hit the game
   briefly slows (hitstop) and the dummy flashes white before its color
   returns to red (health is invisible for now — no UI yet).
4. Facing works stationary too: turn to face the dummy without moving,
   then attack.

### Validation performed by the assistant

- `godot --headless --path . --import` — clean; all 8 classes (including
  the new `PlayerCombat`) register as global classes.
- `godot --headless --path . --quit-after 60` — clean, no runtime errors.
- Wrote a throwaway full-stack headless test (not committed) that loaded
  the **actual `TestArena.tscn`**, held `move_right` (reacting to
  `player.position.x` rather than a fixed frame count — see the Step 2
  lesson about idle/physics frame decoupling in headless mode) until Zayr
  was in range of the dummy, pressed `attack`, and measured results
  through the real engine loop: dummy health went exactly 60 → 48 (the
  scene's configured 12 damage, once, not more), `Engine.time_scale`
  dipped to the configured 0.05 during the hit and was confirmed restored
  to 1.0 afterward.
- **Not yet verified:** attack "feel" (windup/active/recovery timing,
  hitstop strength/duration, whether independent dash/attack feels wrong
  in practice) — needs a manual play session.

## Milestone: Combat Prototype — Step 5 (3-Hit Combo)

**Status: implemented, headless-validated end-to-end (all 3 swings chained
through the real engine loop with cumulative damage), needs manual
play-test.**

User said "continue" again without picking between the three offered
options (3-hit combo, Veyr Step, or a first enemy). Picked the combo:
it's explicitly named in the brief/COMBAT.md and extends the already-
approved, already-validated attack system with no new architecture,
unlike Veyr Step (mechanics still unspecified — same reason it was
skipped last time) or a first enemy (would need a new EnemyController/
EnemyAI subsystem, and enemies were explicitly out of scope in the
original project brief until called for on their own).

### What changed

- `scripts/player/PlayerCombat.gd` — reworked from a single swing into a
  3-swing combo. Per-swing timing/damage/color are now parallel
  `@export` arrays (`swing_durations`, `hitbox_start_times`,
  `hitbox_end_times`, `damages`, `swing_colors`) sized 3, keeping every
  swing individually tunable in the Inspector rather than hand-editing
  code. Pressing attack again during a swing queues the next one,
  resolved with no gap the instant the current swing ends. Reaching the
  end of the combo (or a stray press after it) resets to swing 1 and
  requires the normal `attack_cooldown` — no instant self-loop.
- `scripts/player/PlayerController.gd` — `ATTACK_1` state split into
  `ATTACK_1`/`ATTACK_2`/`ATTACK_3`, mapped from `PlayerCombat.combo_index`.

### How to test

1. Run the project (F5), walk to the training dummy.
2. Press J up to three times in a row (a little ahead of each swing
   finishing, not simultaneously) to chain the full combo — the debug
   rectangle should step through three different colors (teal → blue →
   violet) and the dummy should flash on each of the three hits.
3. Press J once and then wait — only swing 1 should play; the combo does
   not auto-continue without input.
4. Immediately after a full 3-hit combo, try pressing J again right away —
   it should NOT restart instantly; there should be a brief, deliberate
   pause (`attack_cooldown`) first.

### Validation performed by the assistant

- `godot --headless --path . --import` / `--quit-after 60` — both clean,
  no errors.
- Wrote a throwaway full-stack headless test (not committed) that walked
  Zayr to the dummy and pressed attack mid-swing three times: dummy health
  went 60 → 48 → 36 → 16, exactly matching the configured 12+12+20
  damage. Confirmed `combo_index` reset to 0 and `is_attacking` was false
  after the combo ended, and that pressing attack again on the very next
  frame did **not** restart the attack (cooldown correctly gated it) —
  specifically checking for the self-loop exploit this design intends to
  avoid.
- **Not yet verified:** combo "feel" (chain timing tightness, whether 3
  swings in a row reads well with only color as feedback, hitstop
  stacking across 3 hits) — needs a manual play session.

## Milestone: Combat Prototype — Step 6 (First Enemy)

**Status: implemented, headless-validated end-to-end (player takes a hit,
kills the enemy, enemy is actually removed from the tree), needs manual
play-test.**

User said "continue" a third time without picking between the two
remaining options (Veyr Step or a first enemy). Went with the enemy:
Veyr Step still has no defined mechanics beyond its name (same reason it
was skipped in Steps 4 and 5); `EnemyController`/`EnemyAI` were already
named in the project's declared architecture, and this is a generic,
unnamed enemy — no lore/characters invented, those stay reserved. Note
that the *original* project brief explicitly excluded enemies from "this
milestone" — but that exclusion was scoped to the movement-only first
pass, and the project has since grown into full Veyr combat with explicit
approval at every step (dash → combat primitives → first attack → 3-hit
combo); an enemy to actually use that combat on is the natural next piece,
not scope creep past what's been agreed along the way.

### What changed

- `scripts/combat/Hitbox.gd` / `Hurtbox.gd` — **bug fix**: added
  `owner_body` tracking so a `Hitbox` never hits a `Hurtbox` belonging to
  the same entity. Not reachable before (only the player had both), but
  became a real risk the moment a second entity has both — fixed
  proactively rather than waiting to see it happen. See
  [ARCHITECTURE.md](ARCHITECTURE.md) §3.1.
- `scripts/enemies/EnemyController.gd`, `EnemyAI.gd` (new) +
  `scenes/enemies/Enemy.tscn` (new) — the first enemy. Stationary, detects
  the player via the `"player"` group within `detection_range`, and
  performs a telegraphed attack (windup → active → recovery, reusing
  `Hitbox`) within `attack_range` on a cooldown, all `@export`-tunable, no
  values from the brief (placeholder balance, flagged). On death
  (`HealthComponent.died`): brief fade, then `queue_free()`.
- `scenes/player/Player.tscn` — added to the `"player"` group so `EnemyAI`
  can find it without a hardcoded path.
- `scripts/player/PlayerController.gd` — added a brief white hit-flash on
  the debug visual when Zayr's own `HealthComponent` takes damage, so an
  enemy hit is visible (no hurt animation/UI yet).
- `project.godot` — added collision layer 5 (`enemy`) for the enemy's
  physical body (collides with `world` only, not the player).
- `scenes/regions/TestArena.tscn` — placed the enemy on FloorB, past the
  jump gap from the dash/movement testing.

### Known gap (flagged, not fixed here)

Player death has no handling — `HealthComponent.died` works (verified via
the enemy), but nothing is connected to it on the player. Out of scope for
this pass; noted in [ARCHITECTURE.md](ARCHITECTURE.md) §8 so it isn't
forgotten.

### How to test

1. Run the project (F5), walk right — hop over the gap after the training
   dummy to reach FloorB.
2. A purple enemy stands further along. Get close enough and it'll wind
   up (visible delay) then swing an orange-red blade — if it connects,
   Zayr's debug rectangle flashes white.
3. Fight back with the combo (J, chained) — the enemy flashes on each
   hit and, once its health is depleted, fades out and disappears.

### Validation performed by the assistant

- `godot --headless --path . --import` — clean; `EnemyController` and
  `EnemyAI` register as global classes alongside the existing 8.
- `godot --headless --path . --quit-after 90` — clean, no runtime errors
  with the enemy present and idling.
- Wrote a throwaway full-stack headless test (not committed) that walked
  Zayr across the FloorA→FloorB gap (state-reactive jump timing, not a
  fixed frame count — the gap-crossing bug this test itself hit on the
  first attempt, see below), into the enemy's range: the enemy attacked
  first (player health 100 → 90, matching its configured damage), then
  Zayr's combo killed it (enemy health 40 → 28 → 16 → dead), and the test
  confirmed the enemy node was actually gone (`is_instance_valid` false)
  afterward, not just visually hidden.
- **Debugging note kept for future reference:** the test's first two
  attempts failed because the test itself walked straight through the
  movement-testing gap without jumping, dropping the player thousands of
  pixels into the void — a test bug, not a game bug, but worth remembering
  that any future headless test walking toward FloorB needs to clear that
  gap.
- **Not yet verified:** enemy encounter "feel" (telegraph readability,
  whether the cooldown/pacing feels fair, whether fighting near the gap
  edge causes movement issues) — needs a manual play session.

## Milestone: Combat Prototype — Step 7 (Enemy Patrol / Chase)

**Status: implemented, headless-validated through the real engine loop,
needs manual play-test.**

User said "continue" a fourth time without picking between the three
remaining options (Veyr Step, enemy movement, or a second enemy variant).
Went with enemy movement: `EnemyAI.gd`'s own docstring already flagged
"No movement/chase/patrol yet" as deliberately deferred scope, so this
finishes something already declared rather than starting something new —
lower-risk than a second enemy variant (new content to design) and, as
always, Veyr Step still has no defined mechanics beyond its name.

### What changed

- `scripts/enemies/EnemyAI.gd` — now patrols back and forth within
  `patrol_distance` of wherever it spawns (computed at `_ready()`, so
  `Enemy.tscn` stays placement-agnostic — the patrol center isn't
  hardcoded), switches to chasing the player once they're within
  `detection_range`, and attacks (as before) once within `attack_range`.
  Standing still while attacking is preserved. Exposes `move_velocity_x`
  instead of touching the body directly.
- `scripts/enemies/EnemyController.gd` — applies `ai.move_velocity_x` to
  `velocity.x` each physics frame, before gravity/`move_and_slide()`.

### Known limitations (flagged, not fixed)

- No ledge/edge detection — patrol and chase both assume clear floor. The
  test arena's placement (`patrol_distance = 110` around `x = 850` on
  `FloorB`, which spans `720`–`1900`) is safe, but this would need
  addressing before placing an enemy near a platform edge.
- No chase leash or return-to-post — a player repeatedly stepping just
  inside then outside `detection_range` (140px) could in principle nudge
  the enemy away from its patrol zone over time. Not fixed; not likely to
  matter until levels are less contrived than this test arena.

### How to test

1. Run the project (F5), walk to the enemy on FloorB — it should be
   visibly pacing back and forth near where it used to just stand still.
2. Approach until it notices you (it turns and moves toward you) before
   it's close enough to actually swing.
3. Back away past its detection range — it should stop chasing and
   resume patrolling rather than following forever or freezing in place.

### Validation performed by the assistant

- `godot --headless --path . --import` / `--quit-after 120` — both clean,
  no errors, with the enemy patrolling for the full boot window.
- Wrote a throwaway real-engine-loop test (not committed): watched the
  enemy patrol on its own (player kept far away) and confirmed it reached
  close to its right patrol bound (~957 of an expected ~960) and reversed
  direction; teleported the player to within `detection_range` but
  outside `attack_range` and confirmed the enemy's velocity switched to
  moving toward the player; teleported the player far away again and
  confirmed the enemy kept moving (not frozen) rather than getting stuck
  in a chase state — consistent with the code's `to_player_dist <=
  detection_range` check correctly falling through to patrol.
- **Not yet verified:** movement "feel" (patrol pacing readability, chase
  speed relative to the player, whether being chased while also fighting
  the training dummy or standing near the gap edge causes any issue) —
  needs a manual play session.

## Milestone: Combat Prototype — Step 8 (Player Death / Respawn)

**Status: implemented, headless-validated end-to-end through the real
engine loop, needs manual play-test.**

User said "continue" a fifth time without picking between the three
remaining options (Veyr Step, a second enemy variant, or player death
handling). Went with death handling: it was an explicit flagged gap
(`HealthComponent.died` already worked, just wasn't wired up on the
player) rather than new invention, and it matters now that the enemy from
Step 6/7 can actually put the player at risk during play-testing — dying
mid-session with zero feedback or recovery would make further testing
confusing.

### What changed

- `scripts/combat/HealthComponent.gd` — added `revive(to_amount := -1.0)`,
  which resets health (full by default) and deliberately bypasses the
  `is_dead()` guard `take_damage()`/`heal()` use. Generic, not
  player-specific.
- `scripts/player/PlayerController.gd` — added a `DEAD` state. On
  `HealthComponent.died`: freeze (zero velocity, ignore all input,
  clear any in-progress dash/attack flags) for `RESPAWN_DELAY` (1.2s),
  then reset to the position Zayr started this scene at (captured once in
  `_ready()`) and call `health.revive()`. No animation, no game-over UI,
  no persistence — see [ARCHITECTURE.md](ARCHITECTURE.md) §3.2 for why
  this is deliberately minimal (no save system exists to build a real
  game-over flow on top of).

### How to test

1. Run the project (F5) and let the enemy hit you a few times (or just
   stand in its attack range) until Zayr's debug rectangle goes dark
   gray — that's death.
2. Confirm input does nothing for about a second — you can't move, dash,
   or attack.
3. Confirm Zayr then reappears at the arena's start position, rectangle
   back to normal color, fully controllable again.

### Validation performed by the assistant

- `godot --headless --path . --import` / `--quit-after 90` — both clean,
  no errors.
- Wrote a throwaway real-engine-loop test (not committed) that killed the
  player directly (`health.take_damage(9999)`), then: confirmed `state`
  became `DEAD` immediately; held `move_right` for 30 frames and confirmed
  position never changed by even one pixel (input is fully inert while
  dead, not just slowed); then waited and confirmed Zayr respawned at
  exactly the original spawn x-position with `current_health` back to 100
  and `state` back to `IDLE` — a complete, working death → freeze →
  respawn cycle, not just "it doesn't crash."
- **Not yet verified:** respawn "feel" (whether 1.2s freeze is too
  long/short, whether respawning at the arena start — rather than a
  closer checkpoint — is annoying given the walk back to the enemy) —
  needs a manual play session.

## Milestone: Combat Prototype — Step 9 (Ranged Enemy + Projectile)

**Status: implemented, headless-validated end-to-end through the real
engine loop, needs manual play-test.**

User said "continue" a sixth time without picking between the last two
options (Veyr Step or a second enemy variant). Went with the enemy
variant: Veyr Step is explicitly named as reserved future design in the
original brief ("Later major abilities") with no mechanics decided, so
building it would mean inventing a major system the brief says not to
invent. A second enemy type isn't reserved content anywhere, and building
a ranged one produces a reusable `Projectile` primitive the brief already
calls for on the player's side too ("Veyr ranged attack") — not wasted
scope.

### What changed

- **Refactor for reuse:** `scripts/enemies/EnemyAIBase.gd` (new) is the
  interface `EnemyController` now programs against (`facing`,
  `move_velocity_x`, `is_attacking`, `physics_update()`), instead of the
  concrete `EnemyAI` class. `EnemyAI.gd` now extends it. This was
  necessary, not incidental — Godot's static `@onready` typing meant
  `EnemyController` couldn't host a second AI class without it.
  `EnemyController.gd` also gained a shared attacking-tint (yellow pulse)
  whenever `ai.is_attacking`, so both enemy variants get a telegraph
  beyond just their own attack-specific visual — improves the melee
  enemy's readability too, not just the new one's.
- `scripts/combat/Projectile.gd` (new) — extends `Hitbox`: a moving,
  single-use hitbox that travels in a straight line and destroys itself
  on landing a hit or after `lifetime`. Written generically (not
  enemy-specific) since the brief's future player "Veyr ranged attack"
  will want the same primitive.
- `scripts/enemies/RangedEnemyAI.gd` (new) — stationary; within
  `detection_range` it winds up then instantiates+fires a `Projectile`
  toward the player on a cooldown. Explicitly sets the projectile's
  `owner_body` to itself after reparenting it to the scene root (not left
  as the auto-detected `get_parent()`, which would be wrong post-reparent)
  so the Step 6 same-owner exclusion still works correctly.
- `scenes/enemies/RangedEnemy.tscn`, `scenes/enemies/Projectile.tscn`
  (new) — the ranged enemy (fewer HP than the melee one — a placeholder
  "glass cannon" balance choice, not from the brief) and its shot.
- `scenes/regions/TestArena.tscn` — placed the ranged enemy further along
  FloorB past the melee one.

### How to test

1. Run the project (F5), walk past the melee enemy on FloorB.
2. A teal enemy stands further along — approach and it should flash
   yellow (windup) then fire an orange projectile at you.
3. Fight back with the combo — it has less health than the melee enemy,
   should go down faster.
4. Watch the melee enemy's own windup too — it should now also flash
   yellow before swinging, in addition to its blade visual appearing.

### Validation performed by the assistant

- `godot --headless --path . --import` / `--quit-after 150` — both clean,
  no errors, with both enemies present (ranged one idling, out of range).
- Wrote a throwaway real-engine-loop test (not committed) that placed the
  player within the ranged enemy's `detection_range`: confirmed a
  `Projectile` appeared in the scene tree at the expected spawn position
  (computed by hand against `muzzle_offset`/facing and matched exactly),
  confirmed the player's health dropped by exactly the configured 8
  damage on hit, and confirmed the projectile was gone from the tree
  afterward (not just invisible).
- Re-ran the existing `--import`/`--quit-after` checks after the
  `EnemyAIBase` refactor specifically to confirm the melee enemy (`Enemy.
  tscn`) still works unchanged through the new shared interface.
- **Not yet verified:** ranged-encounter "feel" (whether the projectile
  is easy to read/dodge, whether facing two enemy types with different
  threats at once — dummy, melee, ranged, all reachable without leaving
  FloorB — is too much at once for a prototype) — needs a manual play
  session.

## Next Milestone (not started, awaiting direction)

To be defined — the only remaining candidate from prior rounds is Veyr
Step, which still needs its mechanics actually defined (not just
implemented) before it can be built without inventing major-system
design. Do not start without explicit approval.
