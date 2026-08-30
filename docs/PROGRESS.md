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

## Milestone: Combat Prototype — Step 10 (Veyr Step)

**Status: implemented, headless-validated for the core mechanics (exact
teleport distance, invulnerability actually blocking damage, cooldown
gating), needs manual play-test — especially the diagonal directions and
wall-clamp, which hit test-harness limitations rather than being fully
proven, see below.**

Previous round I said "continue" with no remaining well-specified
candidate — the only thing left (Veyr Step) was explicitly reserved
future design in the brief with no mechanics decided, so I asked instead
of guessing. User chose to define it directly; the full brief they gave
is preserved in this session's transcript and summarized in
[COMBAT.md](COMBAT.md) §7. This is the first ability in this project
implemented from a user-authored design brief rather than the assistant
picking the next well-scoped increment.

### What changed

- `scripts/player/PlayerVeyrStep.gd` (new) — 8-directional instant blink.
  Reads `move_left`/`move_right` + two new actions added specifically for
  this (`aim_up`/`aim_down`, W/S — the project had no vertical input
  before, being a side-scroller). Falls back to `Movement.facing` with no
  direction held. Teleports by setting `global_position` directly (no
  traveled motion), after a `move_and_collide(motion, true)` test-only
  check clamps the motion short of landing inside a wall. Grants
  `step_duration` of invulnerability and hides Zayr's visual for that
  window, drawing a fading `Line2D` trail between the two positions.
  `step_distance` (90px) is deliberately less than the dash's 130px, and
  `step_duration`/`step_cooldown` are all `@export`-tunable, per the
  brief's explicit "prioritize responsiveness over perfect balancing."
- `scripts/combat/HealthComponent.gd` — added `is_invulnerable` (generic,
  not Veyr-Step-specific), checked by `take_damage()`.
- `scripts/player/PlayerMovement.gd` / `PlayerCombat.gd` — added
  `cancel_dash()` / `cancel_attack()`, called by `PlayerVeyrStep` on
  activation so it can interrupt an in-progress dash or attack (per the
  brief: "emergency repositioning," not a full cancel-window system).
  Each applies the same cooldown a normal end would, so interrupting
  can't be used to bypass recovery.
- `scripts/player/PlayerController.gd` — added `VEYR_STEP` state (highest
  priority in the state derivation, since it can interrupt everything
  else) and wired the new inputs.
- `project.godot` — added `aim_up`, `aim_down`, `veyr_step` (K) actions.
- `scenes/player/Player.tscn` — added the `VeyrStep` component and a
  `TrailLine` (`Line2D`, `top_level = true` so its points stay in world
  space regardless of Zayr's own transform).

### Known gap (flagged, not built)

The brief asked for Zayr to "dissolve into geometric Veyr particles" —
only the fading trail line is implemented; there's no separate particle/
shard burst at the departure and arrival points. Also no "Perfect Step"
(a named, separate ability in the brief for rewarding precise
invulnerability timing specifically) — Veyr Step grants i-frames for its
whole duration, nothing beyond that yet.

### How to test

1. Run the project (F5). Press K to blink — try it standing still
   (steps in your facing direction), while holding a direction, and while
   holding a diagonal (e.g. D+W for up-right).
2. Confirm it works in the air too (jump, then step).
3. Try it against a wall (e.g. the wall-jump corridor) — it should not
   teleport you through solid geometry.
4. Try triggering it mid-dash and mid-attack-swing — both should cut off
   cleanly rather than continuing to play out.
5. Try timing a step through an enemy's attack — you should see the
   brief invulnerability actually prevent the hit if timed right.

### Validation performed by the assistant

- `godot --headless --path . --import` / `--quit-after 150` — both clean,
  no errors.
- Wrote a throwaway real-engine-loop test (not committed) that
  consistently and cleanly confirmed, across repeated runs: a no-input
  step travels exactly `step_distance` (90.0px) in the facing direction;
  `HealthComponent.take_damage()` is fully blocked while stepping and
  works normally again immediately after; an immediate re-press is
  correctly refused for the full cooldown (held 60 frames / ~1s, well
  past the 0.55s cooldown, and never triggered).
- The diagonal-direction case (holding two movement keys + the step key
  at once) and the wall-clamp case were **inconsistently reproducible**
  in the same throwaway test — this reflects a known limitation of
  driving multi-key input through this project's custom headless
  `SceneTree` test scripts (idle-frame vs. physics-tick timing decouples
  further with more simultaneously-held actions, a sharper version of the
  lesson already recorded from Step 2), not evidence of a bug. One run
  did complete cleanly: holding right+up produced a position delta of
  `(64.1, -63.7)` against an expected `(63.6, -63.6)` — matching the
  8-directional normalization math almost exactly. Given the core
  teleport/invulnerability/cooldown logic (which the diagonal and
  wall-clamp cases both build on directly) is proven solid, and the
  direction math checks out in code review plus that one clean run, this
  is recorded as **plausibly correct but not fully proven** — call this
  out specifically during manual testing rather than assuming it's
  already covered.

## Milestone: Combat Prototype — Step 11 (Minimal HUD)

**Status: implemented, headless-validated end-to-end through the real
engine loop, needs manual play-test (purely visual — layout/readability
can't be judged headless).**

Same situation as last round: nothing well-specified left on the list, so
asked rather than guessing. User picked the UI pass over finishing Veyr
Step's flagged gaps, defining a new ability, or something else.

### What changed

- `scripts/ui/ResourceBar.gd` + `scenes/ui/ResourceBar.tscn` (new) — a
  generic current/max bar (flat-color `ColorRect`s, not a themed
  `ProgressBar` — matches the project's existing placeholder-geometric
  visual language). Knows nothing about health or Veyr specifically, just
  `set_value(current, max)`; reusable for either.
- `scripts/ui/HUD.gd` + `scenes/ui/HUD.tscn` (new) — a `CanvasLayer` with
  a health bar and a Veyr bar. Finds the player via the `"player"` group
  (same lookup `EnemyAI` already uses) instead of a hardcoded path, so it
  doesn't need per-region wiring beyond instancing the scene.
- `scenes/regions/TestArena.tscn` — instanced `HUD.tscn`.
- No numeric text, no low-health warning, no damage-number popups —
  deliberately minimal, matching what was actually asked for.

### How to test

Run the project (F5) — a red bar (health) and blue bar (Veyr) should sit
in the top-left corner from the start, both full. Take a hit from an
enemy and confirm the red bar visibly shrinks; nothing currently spends
Veyr yet (no ability costs Veyr — see [COMBAT.md](COMBAT.md) §4, still
TBD), so the blue bar won't move in normal play — that's expected, not a
bug in the UI.

### Validation performed by the assistant

- `godot --headless --path . --import` / `--quit-after 150` — both clean,
  no errors.
- Wrote a throwaway real-engine-loop test (not committed) that read the
  HUD's bars directly: confirmed both start at full width, then called
  `HealthComponent.take_damage(50)` (on 100 max) and
  `VeyrComponent.spend(30)` (on 100 max) and confirmed the fill widths
  updated to **exactly** 50% and 70% of the bar's full pixel width,
  respectively — the binding is correct, not just present.
- Not attempting to headless-validate visual layout/readability (position
  on screen, whether it overlaps anything, color contrast) — that's
  inherently a manual-play concern, flagged rather than claimed covered.

## Milestone: Combat Prototype — Step 12 (Veyr Step Particle Burst)

**Status: implemented, headless-validated end-to-end through the real
engine loop, needs manual play-test.**

User said "continue" once more with no new selection. Unlike the last two
times, picked this one myself rather than asking again: the particle
burst was an already-specified requirement from the user's own Step 10
brief ("dissolve into geometric Veyr particles... reform at the
destination"), explicitly flagged as a known gap — completing it is
finishing agreed design, not inventing new design, so it didn't need
another round of confirmation. Skipped the other flagged options
(Perfect Step, a new named ability) since those genuinely do need user
design input, same as Veyr Step did before this session.

### What changed

- `scripts/player/PlayerVeyrStep.gd` — added `depart_burst`/
  `arrive_burst` (`Polygon2D`, `top_level`): on activation, the departure
  burst appears at the pre-step position at `burst_start_scale` and
  shrinks to `burst_end_scale` (a "shatter"); the arrival burst appears
  at the destination at `burst_end_scale` and grows to `burst_start_scale`
  (a "reform") — both fading out over `step_duration` alongside the
  existing trail, both hidden again once the step ends. Both `@export`
  scales are tunable.
- `scenes/player/Player.tscn` — added `DepartBurst`/`ArriveBurst`, each an
  8-pointed star polygon (a small geometric "spark" shape, consistent
  with the project's existing placeholder-VFX language — no textures or
  a real particle system).

### How to test

Press K to Veyr Step and watch closely — you should see a small star
shape shrink and fade where Zayr was standing, and a matching star grow
and fade in at his new position, alongside the existing trail line.

### Validation performed by the assistant

- `godot --headless --path . --import` / `--quit-after 150` — both clean,
  no errors.
- Wrote a throwaway real-engine-loop test (not committed) that triggered
  a step and confirmed: both bursts spawn at the exact expected world
  positions (pre-step and post-step respectively) and become visible;
  their starting scales match the configured `burst_start_scale`/
  `burst_end_scale` exactly; sampled mid-step scale values confirmed the
  departure burst shrinks toward `burst_end_scale` while the arrival
  burst grows toward `burst_start_scale` (opposite directions, as
  intended); both are hidden again once the step ends.

## Milestone: Combat Prototype — Step 13 (Perfect Step)

**Status: implemented, headless-validated end-to-end through the real
engine loop (including the negative/no-false-trigger case), needs manual
play-test.**

User gave a full design brief for Perfect Step and explicitly asked to
inspect the current implementation and propose the integration *before*
making changes. Did that as a distinct step (findings + a concrete
signal-based plan, confirmed via a yes/no check) before writing any code
— the first time in this session a change was gated on an explicit
pre-approval rather than "explain briefly, then proceed."

### What changed

- `scripts/combat/Hurtbox.gd` — added a generic `hit_avoided(damage,
  hitbox)` signal, emitted from `receive_hit()` when a hit lands while
  the owner's `HealthComponent.is_invulnerable` is true. This is a fact
  about `Hurtbox` itself (not Perfect-Step-specific), per the brief's
  explicit instruction to use the existing Hitbox/Hurtbox architecture
  rather than building a separate detection system.
- `scripts/player/PlayerVeyrStep.gd` — listens for its own `Hurtbox`'s
  `hit_avoided`. Triggers Perfect Step only if currently stepping, only
  once per step, and only within a separately-configurable
  `perfect_detection_window`. On trigger: a separate hitstop (own
  exports, not shared with `PlayerCombat`'s), a `perfect_burst_scale_
  multiplier` applied to the existing depart/arrive bursts for the rest
  of the step, and `VeyrComponent.add(perfect_veyr_restore)`. All new
  values are `@export`s on `PlayerVeyrStep` only — nothing hardcoded into
  `Hurtbox`, `HealthComponent`, or elsewhere.
- Audio: checked first — there is no audio system anywhere in this
  project (no `AudioStreamPlayer` usage, `assets/audio/` empty). Per the
  brief's own "if the audio system is already available" condition, none
  was built. Added an `AudioStreamPlayer` child + an exported
  `perfect_audio_cue: AudioStream` (defaults to `null`) — a ready hook,
  silent until a sound asset is assigned.
- `scenes/player/Player.tscn` — added the `AudioPlayer` node under
  `VeyrStep`.

### How to test

Time a Veyr Step so it carries you through an enemy's attack at the
moment it would land (the melee enemy's telegraphed swing is the easiest
to practice against — step just as the blade activates). A normal dodge
(stepping when nothing was actually about to hit you) should feel like
before; a genuinely perfectly-timed one should feel distinctly stronger —
a small extra freeze-frame and a bigger burst — and the Veyr bar should
tick up slightly.

### Validation performed by the assistant

- `godot --headless --path . --import` / `--quit-after 150` — both clean,
  no errors.
- Wrote a throwaway real-engine-loop test (not committed) covering both
  the positive and negative case:
  - A step with nothing nearby to avoid: confirmed `_perfect_triggered_
    this_step` stayed `false` and the burst multiplier stayed `1.0` — no
    false-positive from merely using Veyr Step.
  - A step engineered to land exactly on a live, activated enemy-owned
    `Hitbox`: confirmed the perfect trigger fired exactly once, the burst
    multiplier matched the configured `1.6`, `Engine.time_scale` dipped
    to the configured `0.05` and was confirmed restored to `1.0`
    afterward, Veyr increased by exactly the configured `15.0` (50 → 65),
    and — critically — `current_health` was unchanged throughout,
    confirming this is genuinely layered on top of a normal (undamaging)
    Veyr Step rather than a separate mechanic.
- **Not yet verified:** the "feel" of the reward in an actual timed
  encounter against the real (not engineered) enemy AI, and the optional
  audio path (untestable without an actual sound asset — the hook is
  wired but silent).

## Milestone: Combat Prototype — Step 14 (Mini-Boss)

**Status: implemented, headless-validated end-to-end through the real
engine loop, needs manual play-test.**

User gave a high-level roadmap for the project rather than picking from
the offered options: "Movement → Veyr Step → Perfect Step → Enemy →
Combat → Mini-boss → Vertical slice → Art." Everything before "Mini-boss"
was already built, so that's the next step in their own stated sequence —
proceeded directly (stating scope first) rather than opening another
options round, since the direction itself was no longer ambiguous.

The boss is deliberately **generic/unnamed** — none of the five reserved
canon characters ([LORE.md](LORE.md) §5: Rhaek, Seyra, Vael, Nayra,
Auren) were used or characterized; their "characterization and boss
mechanics" stay explicitly deferred per the original brief. This is
combat-prototype content, not story content.

### What changed

- `scripts/bosses/BossAI.gd` (new, `extends EnemyAIBase`) — combines the
  two existing enemy attack patterns instead of inventing a new one:
  melees (own `Hitbox`, like `EnemyAI`) within `melee_range`, or fires a
  `Projectile` (like `RangedEnemyAI`) beyond it, up to `detection_range`.
  Below a configurable health ratio (default 50%), permanently shortens
  both attack cooldowns and emits `phase2_started` once — a numeric
  escalation, not a new mechanic.
- `scripts/bosses/BossController.gd` (new, **`extends EnemyController`**)
  — deliberately does *not* duplicate `EnemyController`; the boss is
  still just a body with gravity/velocity from its AI and the same
  generic hit-flash/attacking-tint/death-fade feedback. The only addition
  is a base-color shift on `phase2_started`.
- `scenes/bosses/MiniBoss.tscn` (new) — bigger body/collision (1.5x a
  regular enemy), 150 HP, crimson placeholder color, both a `Hitbox` (for
  melee) and a `projectile_scene` reference (for ranged) on its `AI`.
- `scripts/ui/HUD.gd` / `scenes/ui/HUD.tscn` — added a third, wider
  `ResourceBar` for whatever's in a new `"boss"` group, hidden unless one
  exists, shown once connected, hidden again ~1s after the boss dies (so
  the bar is seen hitting zero, not just vanishing).
- `scripts/ui/ResourceBar.gd` — **bug fix, caught before it shipped**:
  the bar's `Background`/`Fill` children had hardcoded sizes independent
  of the root `Control`'s `size`, so the wider boss-bar override
  wouldn't have actually rendered wider. `_ready()` now propagates `size`
  to both children.
- `scenes/regions/TestArena.tscn` — placed the boss on the platform past
  the dash-practice zone, as a natural "final challenge" after the
  arena's existing gauntlet.

### How to test

Work through the arena to the far platform past the dash-practice
zone — a larger crimson enemy. Approach and it should melee up close or
fire projectiles from range depending on distance. Below ~50% of its
health it should visibly darken/shift color and attack noticeably faster.
A red bar should appear top-center of the screen tracking its health, and
disappear a moment after it's defeated.

### Validation performed by the assistant

- `godot --headless --path . --import` — clean; `BossAI`, `BossController`
  register as global classes.
- `godot --headless --path . --quit-after 150` — clean, no runtime errors
  with the boss present and idling.
- Wrote a throwaway real-engine-loop test (not committed) that: confirmed
  the boss bar becomes visible with the correct starting value once the
  HUD connects; positioned the player within `melee_range` and confirmed
  the boss's `Hitbox` activated (melee chosen); repositioned beyond
  `melee_range` but within `detection_range` and confirmed a `Projectile`
  appeared (ranged chosen); dealt damage to cross the 50% threshold and
  confirmed `phase2_started` fired and the controller's color updated to
  the configured `phase2_color`; killed the boss and confirmed it was
  actually removed from the tree (not just hidden) and that the HUD boss
  bar hid itself afterward.
- **Not yet verified:** encounter "feel" (attack pacing, whether melee/
  ranged switching reads clearly, phase 2 difficulty spike, whether the
  boss bar's top-center position actually looks right at the project's
  runtime resolution — computed against the default 1152×648 viewport
  but not visually confirmed in-editor).

## Prototype Review (no implementation)

Before starting the vertical slice, user asked for a pause: a concise
implementation-status audit against a checklist (Movement, Veyr/Mobility,
Combat, Enemies, Boss System, Technical), explicitly with no files
modified. Delivered as a status table, not a doc edit — see this
conversation's transcript for the full report. Two items came back
**PARTIALLY IMPLEMENTED**: 8-directional Veyr Step (logic correct, but
diagonal directions never got a clean headless confirmation — a
test-harness limitation noted since Step 10, not a suspected bug) and the
mini-boss's phase system (one phase transition only, by design). Two
items came back **NOT IMPLEMENTED**: Heavy Attack and Enemy Stability/
Stagger. The audit also surfaced two combat gaps not on the user's
checklist: no player HURT state, and `Projectile` not colliding with
world geometry. All four became this milestone.

## Milestone: Combat Prototype — Step 15 (Core Combat Gaps)

**Status: implemented, headless-validated end-to-end through the real
engine loop for all four systems — including catching and fixing two
real bugs along the way, described below. Needs manual play-test.**

User asked for exactly four systems, explicitly pausing before the
vertical slice: **Heavy Attack**, **Enemy Stability/Stagger**, **Player
HURT state**, **Projectile world collision**. Full design briefs given
for each — see [COMBAT.md](COMBAT.md) §8–11 for the paraphrased briefs
and implementation detail; this entry covers what changed, test results,
and decisions worth flagging.

### Files changed

- `scripts/player/PlayerCombat.gd` — heavy attack, folded into the
  existing combo component rather than a new one (shares the `Hitbox`/
  `SwingVisual`, needs mutual-exclusion state with the combo).
- `scripts/player/PlayerController.gd` — new `HURT` state: knockback,
  input lockout for `hurt_duration`, optional post-hit invulnerability.
  Also wires the new `heavy_attack` input into `PlayerCombat`. Removed
  the old ad-hoc hurt-flash timer (now redundant — `HURT`'s own debug
  color covers it).
- `scripts/combat/StabilityComponent.gd` (new) — the stagger system.
- `scripts/combat/Hitbox.gd` — added `stability_damage` (0 default).
- `scripts/combat/Hurtbox.gd` — added optional `stability_component_path`
  and applies stability damage alongside health damage when both are set.
- `scripts/combat/HealthComponent.gd` — `is_invulnerable` refactored from
  a plain bool to reference-counted (`add_invulnerability()`/
  `remove_invulnerability()`) — see "Design decisions" below.
- `scripts/player/PlayerVeyrStep.gd` — its two direct
  `health.is_invulnerable = true/false` assignments updated to the new
  `add_invulnerability()`/`remove_invulnerability()` calls. **No other
  change** — same trigger moments, same duration, same effect; this was
  the "unless absolutely necessary" exception the architecture rules
  allow, not a rewrite.
- `scripts/combat/Projectile.gd` — `body_entered` handling for world
  collision, plus the `monitorable` fix below.
- `scripts/enemies/EnemyAIBase.gd` — added virtual `cancel_attack()`.
- `scripts/enemies/EnemyAI.gd`, `RangedEnemyAI.gd`, `scripts/bosses/
  BossAI.gd` — each: a `cancel_attack()` override, and `stability_damage`
  set on their own attack's `Hitbox`/`Projectile`.
- `scripts/enemies/EnemyController.gd` — the stagger enforcement point
  (see "Stability" below) and a `stagger_color` tint.
- Scenes: `Enemy.tscn`, `RangedEnemy.tscn`, `MiniBoss.tscn` each gained a
  `StabilityComponent` node (40/30/100 max stability respectively — the
  boss also gets a longer 2.0s `stagger_duration` vs. the 1.5s default) and
  a `stability_component_path` wired on their `Hurtbox`. `Projectile.tscn`
  — `collision_mask` widened from `8` to `9` (added the world layer).
- `project.godot` — new `heavy_attack` input action (L).

### Design decisions that may need your approval

1. **Stagger freezes movement, not just attacks.** The brief says a
   staggered enemy "temporarily cannot perform normal attacks" — this
   implementation also freezes patrol/chase movement, since the cleanest
   and most reusable enforcement point turned out to be "don't call
   `ai.physics_update()` at all while staggered" in the shared
   `EnemyController`, which necessarily stops movement too. A
   staggered-but-still-moving enemy would need stagger-awareness added to
   every individual AI script instead. Flagging this since it goes
   slightly beyond the literal brief.
2. **`HealthComponent.is_invulnerable` is now reference-counted**, not a
   plain bool. This was necessary, not a style choice: without it, the
   HURT state's optional post-hit grace window and Veyr Step's own
   invulnerability window are two independent sources that could overlap
   in time, and whichever one happened to end first would incorrectly
   cancel the other's. `PlayerVeyrStep.gd` needed a 2-line update to match
   (its behavior is otherwise identical). This touches a system the
   instructions asked not to rewrite "unless absolutely necessary" — this
   was that case.
3. **Heavy attack got its own dedicated input (L)**, not a hold-to-charge
   on the existing attack button — matches "do not create a complicated
   charge system," but is a specific input-binding choice worth knowing
   about if a different scheme was pictured.
4. All new numeric values (heavy attack damage/timing, per-attack
   stability damage, stability pool sizes, hurt duration/knockback/
   invuln) are placeholders **not** derived from any brief — each is
   `@export`-tunable and called out as such in code comments and
   [COMBAT.md](COMBAT.md).

### Two real bugs found and fixed (not assumed away)

- **Post-hit invulnerability was blocking its own triggering hit's
  damage.** `PlayerController._on_hit_received` fires synchronously
  *inside* `Hurtbox.receive_hit()`, *before* that same call reaches its
  own `_health.take_damage(damage)` line. Granting invulnerability
  synchronously in the hit-received handler meant the hit that was
  supposed to start the grace period was already blocked by it. Fixed
  with `call_deferred()` so the grant applies only after the current hit
  finishes processing. Caught by the real-engine-loop test below (player
  health didn't move on the first run), not assumed correct.
- **`Area2D.monitorable = false` silently blocks `body_entered` entirely**
  in this Godot version (4.7.2) — confirmed via an isolated minimal
  reproduction (a bare `Area2D` overlapping a bare `StaticBody2D`, with
  `monitorable` as the only variable changed between a failing and
  passing run), not merely inferred. The base `Hitbox._ready()` sets
  `monitorable = false` (correct for melee attacks, which never need
  body detection) — `Projectile` inherits that and now explicitly
  overrides it back to `true` after `super._ready()`, scoped to
  `Projectile` only.

### How to test

1. **Heavy attack**: press L — a longer windup than the combo, then a
   stronger orange swing. Try it on the melee enemy: one heavy hit should
   visibly stagger it (40 stability damage on its 40 max).
2. **Stability**: land a few normal combo hits on an enemy without
   staggering it (small stability damage), then land a heavy attack and
   watch it flash pale/gold, stop moving and attacking, then recover a
   couple seconds later.
3. **Player HURT**: let an enemy hit you — Zayr should flash red, get
   knocked back and briefly lose control, then recover.
4. **Projectile collision**: get the ranged enemy or boss to fire at you
   while you're behind part of the arena's geometry — the shot should
   vanish at the wall instead of continuing through.

### Validation performed by the assistant

- `godot --headless --path . --import` / `--quit-after 200` — both clean,
  no errors, with both enemies and the boss present.
- Wrote a throwaway real-engine-loop test (not committed) covering all
  four systems together against a standalone test target (a bare
  `HealthComponent`+`StabilityComponent`+`Hurtbox`, deliberately with no
  AI/`Hitbox` of its own, so it couldn't hit the player back and
  contaminate the HURT-state test) plus the real player/arena:
  - Heavy attack: confirmed the `Hitbox` stays inactive through the full
    `heavy_startup` and only opens after, confirmed exact damage (32) and
    exact stability damage (40, staggering a 40-max target in one hit —
    "break enemy defenses," confirmed literally), confirmed stagger
    recovery back to max stability.
  - Player HURT: confirmed exact damage (15) after the invulnerability-
    race fix, confirmed knockback velocity direction/magnitude, confirmed
    `HURT` state clears and normal movement input works again afterward.
  - Projectile: confirmed a shot aimed at a real arena wall (`WallLeft`)
    is removed on contact rather than continuing through — reproduced the
    failure first (projectile sailed straight through, `overlapping_
    bodies` staying empty for 200+ frames), root-caused it via the
    isolated `monitorable` reproduction above, then confirmed the fix.
- Two of my own test-authoring mistakes were caught and corrected during
  this pass (not game bugs): setting a `NodePath` export after
  `add_child()` instead of before (same "node setup order" lesson from
  earlier milestones, re-learned), and checking a staggered enemy's state
  too late — after its short `stagger_duration` had already elapsed and
  auto-recovered, making a real effect look like a no-op. Both are noted
  here so a future session doesn't waste time re-deriving them.
- **Not yet verified:** "feel" of any of the four systems in real
  play — stagger pacing, heavy attack commitment/risk, hurt-state
  knockback distance, whether projectiles disappearing at walls reads
  clearly. All four are functionally confirmed, not feel-tuned.

## Vertical Slice — Stage 1 (Awakening + Movement Introduction)

**Status: implemented, headless-validated end-to-end through the real
engine loop (full traversal + fall-safety kill zone), needs manual
play-test in editor. Explicitly scoped to Stage 1 only per user
instruction — stopped here to report and await approval before Stage 2.**

User gave a full 13-step vertical-slice brief (Awakening → Movement Intro
→ Combat → Veyr Step → Avaris Reveal → Exploration → Ranged Enemy →
Mini-Boss → Memory → Rhaek Teaser → End) with explicit absolute scope
exclusions (no full region, no final art, no new abilities, no inventory/
save/dialogue/audio systems) and a 7-stage implementation order, each
gated on approval before the next. This entry covers **Stage 1 only**:
the root scene, the Awakening chamber, and the Movement Introduction
section. No combat, no Veyr Step, no reveal/exploration/enemies/boss/
memory/Rhaek content exists yet — those are Stages 2–7.

### Files created

- `scripts/systems/PlayerTrigger.gd` (new) — small generic `Area2D` that
  emits a `triggered` signal when the player (`"player"` group) enters it,
  with an `@export var one_shot` (default `true`). Deliberately minimal
  per explicit instruction — not a general event/quest/sequence framework;
  each usage site connects `triggered` and does its own small thing.
  Reused here for the fall-safety kill zone (`one_shot = false`, so it
  fires every time); Stages 2–7 will likely reuse it for narrative cues.
- `scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.gd` (new) —
  root script. Single responsibility: connects the `KillZone`'s
  `triggered` signal to `player.health.take_damage(9999.0)`, reusing the
  existing HURT-state-free death → freeze → respawn flow from
  `PlayerController` (Step 8) rather than building anything new. No
  checkpoints, per the approved plan.
- `scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.tscn` (new) —
  the Stage 1 scene. Follows `TestArena.tscn`'s exact established
  conventions (HUD instance, Player instance with per-scene `Camera2D`
  limit overrides, `StaticBody2D`+`CollisionShape2D`+`Polygon2D` graybox
  geometry under a `Geometry` node).

### What was implemented

**Awakening chamber** — an enclosed starting room (`ChamberFloor`,
`ChamberLeftWall`, `ChamberCeiling`), open on the right where it flows
into the movement section (the ceiling stops short of the opening so the
space visibly widens/opens up, rather than a hard cut). Two non-collision
decorative `Polygon2D`s satisfy the "placeholder lighting/mood" ask
without adding unverifiable `Light2D` nodes I can't visually confirm
headless (flagged explicitly below): a tall tapered spire against the
left wall, and a thin Veyr-violet conduit line embedded in the floor
using the established `Color(0.55, 0.4, 1.0)` from Veyr Step's own trail.

**Movement Introduction** — one continuous rightward path (not isolated
test rooms), reusing already-validated distances/heights from
`TestArena.tscn` wherever the mechanic repeats:

- A floor continuation out of the chamber, then a 130px gap + 40px rise
  onto a raised platform (introduces jump).
- A walk-off ledge drop (100px, no obstacle) onto a lower floor
  (introduces falling/landing with no precision required).
- A 3-step ascending staircase up to wall-top height, leading onto a
  110px-wide, 240px-tall wall-jump shaft (identical gap width and wall
  height to `TestArena`'s already-validated corridor) — entered from
  above by walking off the first wall's top edge and falling in, exited
  the same way `TestArena`'s does, onto an `ExitLedge`.
- A ~155px flat dash gap (matching `TestArena`'s own dash-gap distance)
  onto a final `DashLandingPlatform`.
- One wide `PlayerTrigger`-based kill zone spanning the full stage
  horizontally, well below every floor, dealing 9999 damage on contact
  (`one_shot = false`) — reuses the existing death/respawn flow, no new
  checkpoint or fall-damage system.
- Camera `limit_*` overridden on this scene's `Player/Camera2D` instance
  (left -180, top -100, right 2750, bottom 700), same per-scene-override
  pattern as `TestArena.tscn`.

### A real level-design bug found and fixed during testing

My first pass placed the wall-jump shaft's walls flush against the floor
below them (matching what I *thought* `TestArena`'s corridor did), which
made the shaft physically unenterable — a player walking along the floor
just collides with the solid wall's face and stops; there's no way to
get "inside" a gap between two floor-flush walls from the side. Testing
through the real engine loop caught this immediately (the player got
stuck at the wall face, positionally frozen). Re-inspecting `TestArena.
tscn`'s actual coordinates showed its corridor is entered **from above**:
an approach platform (`Platform3`) sits at exactly the same height as the
walls' top surface, so the player walks onto the wall's top and falls
into the gap from there, then wall-jumps back up and out the other side.
Rebuilt Stage 1's shaft entry to match this proven pattern (added
`StepA`/`StepB`/`StepC`, a 3-step staircase up to wall-top height, plus
an `ExitLedge` on the far side) — not a new invention, just correctly
reusing an existing, already-working design instead of a superficially
similar but non-functional guess at it.

### Flagged interpretation (not fully covered by the brief)

The brief's "placeholder lighting establishing mood" was interpreted as
deliberate cool violet/slate color choices for the chamber rather than
actual `Light2D`/`PointLight2D` nodes — I can't visually verify rendering
quality headless, and didn't want to add unverifiable visual complexity
without being able to confirm it looks right. Flagging this explicitly:
if actual dynamic lighting was intended, that's a follow-up, not
something silently skipped.

### How to test (manual, in-editor)

1. Open the project, run `AvarisVerticalSlice.tscn` directly (it is not
   yet wired as the main scene — `TestArena.tscn` still is, unchanged).
2. From the Awakening chamber, walk right into the Movement Introduction
   section.
3. Confirm: the first gap is jumpable, the ledge drop feels like a safe
   fall (not a forced death), the staircase leads onto the wall-jump
   shaft correctly (walk off the top edge, fall in, wall-jump climb out
   using the same feel as `TestArena`'s corridor), the final gap requires
   a dash.
4. Deliberately fall off the path (e.g. from the raised platform or the
   shaft) and confirm the kill zone triggers the normal death → 1.2s
   freeze → respawn-at-chamber-start flow.

### Validation performed by the assistant

- `godot --headless --path . --import` — clean; `PlayerTrigger` registers
  as a global class alongside the existing 15.
- `godot --headless --path . AvarisVerticalSlice.tscn --quit-after 60` —
  clean boot, no runtime errors (confirms node paths, the `KillZone`
  signal connection, and all new geometry resolve correctly).
- Wrote a throwaway real-engine-loop test (not committed, deleted after)
  that drove the player through the **entire Stage 1 path** via real
  input (`move_right`, `jump`, `dash`) reacting to actual position/state
  changes rather than fixed frame counts (per the established lesson):
  cleared the first jump gap, landed the ledge drop onto the lower floor,
  climbed the entry staircase and walked off the wall's top edge into the
  shaft, confirmed `is_wall_sliding` actually engages inside the gap and
  a wall-jump lifts the player clear of the shaft floor (proving this
  gap's specific width/height are consistent with the already-validated
  wall-jump mechanic — this is what caught the entry-geometry bug above),
  crossed the final dash gap and landed on `DashLandingPlatform`, then
  confirmed the kill zone deals lethal damage and the player respawns at
  the exact chamber spawn position with full health.
- **Not fully automated, needs a human's hands:** the exact zigzag
  button sequence for climbing out of the wall-jump shaft onto `ExitLedge`
  specifically (the test proved the climb *engages and works* inside the
  gap, then placed the player on `ExitLedge` directly to test the dash
  gap and landing platform in isolation, rather than scripting a fragile
  precise zigzag — the underlying wall-jump mechanic itself was already
  engine-validated against these exact wall dimensions during the
  Movement milestone, Step 1).
- **Not yet verified (needs manual play):** overall pacing/"feel" of the
  Awakening → Movement flow as a continuous experience (not a checklist
  of isolated tests), whether the chamber reads as an enclosed space
  visually, whether the movement section's difficulty curve (jump → fall
  → wall-jump → dash) feels smooth, and whether the placeholder-lighting
  color choice actually conveys mood without real `Light2D` nodes.

## Vertical Slice — Stage 2 (First Combat + Combat Encounter)

**Status: implemented, headless-validated end-to-end through the real
engine loop, needs manual play-test.**

User approved Stage 1 and said "continue." Stage 2 extends the path
rightward from `DashLandingPlatform` with the First Combat and Combat
Encounter beats from the 13-step brief. Deliberately scene-only — no new
scripts, no new enemy type, no ability changes. Reuses `Enemy.tscn`
(melee) exactly as-is, since it's already engine-validated from Steps 6–7
and 15; a ranged/boss encounter is explicitly later steps (9–10), not
this one.

### Files changed

- `scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.tscn` —
  added one continuous `CombatFloor` (1400px, flush with
  `DashLandingPlatform`'s top height, same as every other Stage 1 floor
  transition) carrying three `Enemy.tscn` instances: `FirstCombatEnemy`
  alone near the start (a single, forgiving introduction — nothing else
  around to split the player's attention), then `EncounterEnemyA`/`
  EncounterEnemyB` placed close together further along (a real two-at-
  once fight). Each enemy's default `patrol_distance` (110px) fits
  comfortably within the floor with room to spare on both sides — no
  ledge nearby for the "no edge detection" limitation (Step 7) to matter.
  Extended the existing `KillZone`'s width (3200 → 4500) and the
  `Camera2D` `limit_right` override (2750 → 4100) to cover the new floor
  instead of adding a second kill zone — keeping it the one wide trigger
  the approved plan called for, just widened as the stage grows.

### How to test

1. Open `AvarisVerticalSlice.tscn`, run it directly (still not the main
   scene).
2. From `DashLandingPlatform`, walk right onto the new combat floor — a
   single purple enemy should notice and engage first.
3. Defeat it with the combo, continue right, and you'll meet two enemies
   close together — a genuinely harder fight than anything in Stage 1.
4. Confirm the extended kill zone still catches a fall anywhere along the
   new floor (e.g. deliberately walk off the far end).

### Validation performed by the assistant

- `godot --headless --path . --import` / `AvarisVerticalSlice.tscn
  --quit-after 90` — both clean, no errors, all three enemies idling.
- Wrote a throwaway real-engine-loop test (not committed, deleted after)
  that teleported the player onto the new floor and drove combat through
  real input: confirmed `FirstCombatEnemy` engages and attacks first
  (player health 100 → 90, matching its configured damage), confirmed the
  combo actually kills it (`is_instance_valid` false afterward, not just
  hidden), confirmed both encounter enemies engage and can be fought down
  together (health dropped further to 60, expected from facing two
  attackers at once), and confirmed the widened kill zone still deals
  lethal damage and respawns correctly at the chamber spawn far off to
  the left.
- **Two of my own test-authoring mistakes caught and fixed, not game
  bugs:** (1) held `move_right` across a phase transition without
  releasing it, so the player sprinted through the fight and off the far
  end of the floor into an unbounded fall — caught immediately by the
  resulting absurd position (`x≈7800, y≈14000`), not a physics bug. (2)
  teleported the player in `_initialize()` before `PlayerController.
  _ready()` had actually fired (same deferred-`_ready`-after-`add_child`
  timing noted in Stage 1's report), which meant `_spawn_position`
  captured the test's teleport target instead of the scene's authored
  chamber spawn — fixed by waiting for an `@onready` field to be non-null
  before teleporting. Both noted here so a future session doesn't
  re-diagnose them.
- **Not yet verified (needs manual play):** whether the single-enemy
  introduction actually reads as forgiving/teachable in practice, whether
  the two-enemy encounter's difficulty is fair without Veyr Step yet
  (that's Stage 3), and general pacing of arriving at a fight right after
  the dash-gap landing.

## Vertical Slice — Stage 3 (Veyr Step Encounter + Perfect Step Opportunity)

**Status: implemented, headless-validated end-to-end through the real
engine loop, needs manual play-test.**

User said "continue" once more. Stage 3 extends the path from the end of
Stage 2's combat floor with the two remaining early beats from the
13-step brief. Per the approved plan's explicit correction, the Veyr Step
introduction is **not** a "dash can't cross this" traversal gate — Veyr
Step is introduced through combat instead, where it's genuinely useful
but never mandatory (a player can still fight or reposition without it).
Scene-only again — no script changes, still reusing `Enemy.tscn` as-is.

### Files changed

- `scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.tscn`:
  - Added `VeyrEncounterFloor` (1000px, flush with `CombatFloor`'s end at
    x=4035, same top height as every floor since `DashLandingPlatform`).
  - `FlankEnemyLeft`/`FlankEnemyRight` — two `Enemy.tscn` instances 200px
    apart (x=4350/4550). Walking into the middle puts the player within
    both enemies' `detection_range` (140px) simultaneously — a flanking
    moment that rewards Veyr Step's instant repositioning without
    requiring it; the fight is still winnable with plain movement + combo
    alone, matching the "not gated" correction.
  - `PerfectStepEnemy` — a single, isolated `Enemy.tscn` instance
    (x=4850) with open clear space on both sides: a clean, low-pressure
    1v1 specifically for practicing a Veyr Step dodge timed against its
    telegraphed swing, the same setup Step 13 called "the easiest to
    practice against."
  - Extended `KillZone`'s width (4500 → 5500) and `Camera2D` `limit_right`
    (4100 → 5150) to cover the new floor, same "widen the one zone"
    approach as Stage 2 (not a second kill zone).

### How to test

1. Open `AvarisVerticalSlice.tscn`, run it directly.
2. Past Stage 2's two-enemy fight, continue right into two more enemies
   spaced apart — walking between them should get you attacked from both
   sides at once. Try using Veyr Step (K) to reposition out of the pincer
   before continuing the fight normally.
3. Past that, a single isolated enemy stands alone. Let it wind up its
   swing (the blade telegraph) and try timing a Veyr Step through the hit
   right as it lands — a precisely-timed one should trigger Perfect Step
   (bigger burst, a stronger freeze-frame, a small Veyr refund).
4. Confirm the kill zone still catches a fall anywhere along this new
   stretch too.

### Validation performed by the assistant

- `godot --headless --path . --import` / `AvarisVerticalSlice.tscn
  --quit-after 90` — both clean, no errors, all five enemies idling.
- Wrote a throwaway real-engine-loop test (not committed, deleted after)
  that: walked the player into the flanking pair and confirmed **both**
  enemies actually entered their attack state (proving the simultaneous-
  engagement moment genuinely happens, not just in theory), defeated both
  with the combo, triggered a Veyr Step mid-fight and confirmed it
  engages and resolves cleanly with no crash or stuck state on this open
  floor, then approached `PerfectStepEnemy`, waited for its `Hitbox` to
  actually become active (`monitoring == true`, i.e. windup elapsed) and
  triggered a Veyr Step at that exact instant: health was unchanged
  before and after (70 → 70) — the dodge fully blocked the hit, proving
  this placement gives clean room to evade. Also confirmed the widened
  kill zone still deals lethal damage and respawns correctly.
- **Deliberately not re-validated here:** whether that scripted dodge
  counts as a "Perfect" step specifically (`_perfect_triggered_this_step`
  came back `false` in the automated run) — Perfect Step's own trigger
  logic was already proven correct end-to-end in Step 13 via a
  deliberately engineered overlap; whether a fixed 90px teleport lands
  back inside a ~40px-wide enemy hitbox at the exact right instant is a
  genuine timing/skill question for a human player, not something to fake
  by scripting a "perfect" input sequence. Re-using Step 13's own
  precedent (it flagged the same kind of precise-timing case as
  needing manual play, not headless proof) rather than inventing new
  false confidence here.
- **Not yet verified (needs manual play):** whether the flanking moment
  actually reads as a deliberate "use Veyr Step here" invitation rather
  than just two enemies that happen to be close together, and — the real
  open question — whether a human can actually land a Perfect Step
  against this specific enemy placement at a comfortable, fair rate, or
  whether the encounter needs more space/a slower enemy/a different
  approach angle to make that opportunity feel achievable rather than
  lucky.

## Vertical Slice — Stage 4 (Avaris Reveal + Exploration)

**Status: implemented, headless-validated end-to-end through the real
engine loop, needs manual play-test — especially the reveal's visual
composition, which is inherently a "does it look right" question I
can't verify headless.**

User said "continue." Stage 4 covers the reveal and exploration beats.
Per the approved plan's explicit corrections: the reveal is
**composition-driven**, not a camera-zoom trick — real background
geometry sells the scale — and exploration has **one primary route and
one optional route**, plus deliberate **calm moments**. Scene-only
change again; no scripts touched.

### Files changed

- `scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.tscn`:
  - **The reveal**: `RevealLedge` past `VeyrEncounterFloor`, opening onto
    a `Backdrop` (`Node2D`, `z_index = -1` so it renders behind all
    gameplay geometry) holding four non-collision `Polygon2D` silhouette
    spires (`SpireA`–`D`), heights 300–650px, geometric tapered
    trapezoids — deliberately angular, not organic/dune-like, per
    Avaris's art-direction rules (no Middle Eastern/desert/medieval
    read). Cool slate-blue palette for three of them; `SpireC` (the
    tallest, 650px, a monumental focal landmark near the path) uses a
    violet-tinted variant of the same palette and a distinct
    truncated-peak silhouette, tying it to the established Veyr color
    language (`Color(0.55, 0.4, 1.0)`) without literally reusing it. This
    is what makes the reveal composition-driven — the vista exists in the
    level geometry itself, not just a wider camera limit (though the
    camera limits were also widened — `limit_top` -100 → -400,
    `limit_right` → 6350 — specifically so the tall spires are actually
    visible, not clipped).
  - **Optional route**: `OverlookPlatform`, a violet-tinted ledge reached
    by a single jump from `RevealLedge`'s edge, dead-ending at a quiet
    vantage point with the best view of the spire cluster — no combat, no
    mechanical reward, purely a "calm moment" per the brief. Falling/
    jumping back off it lands directly on the primary route below
    (`ExplorationStep1`), so visiting it costs a short detour, not a
    forced full backtrack.
  - **Primary route**: `ExplorationStep1` → `ExplorationStep2` →
    `ExplorationFloor`, a gentle 3-stage descent (small, safe ~72-76px
    drops each, well within the falling comfort already established in
    Stage 1) leading toward where Stage 5 will begin. No enemies
    anywhere in this entire section — the whole point is a breather after
    Stage 3's two fights.
  - Extended `KillZone` (5500 → 6750 width) and `Camera2D` `limit_right`/
    `limit_bottom` again, same "widen the one zone" approach as prior
    stages.

### How to test

1. Open `AvarisVerticalSlice.tscn`, run it directly.
2. Past Stage 3's isolated enemy, walk onto the ledge at the end of the
   floor — the camera should reveal a skyline of tall geometric spires
   rather than just more graybox floor. Confirm it reads as "alien
   monumental architecture," not desert/organic — flag it if it doesn't,
   since I can't judge that visually myself.
3. Try the optional jump up to the violet-tinted overlook ledge — confirm
   it's a genuine quiet dead-end (no enemy, nothing mechanical), then
   drop back down and confirm you land back on the descending stairs
   rather than needing to backtrack.
4. Follow the primary descent down to the floor at the bottom — confirm
   none of the drops feel risky or damage you.

### Validation performed by the assistant

- `godot --headless --path . --import` / `AvarisVerticalSlice.tscn
  --quit-after 90` — both clean, no errors.
- Wrote a throwaway real-engine-loop test (not committed, deleted after)
  that walked the player onto `RevealLedge`, jumped the optional route
  onto `OverlookPlatform`, confirmed falling back off it lands on the
  primary descending stairs (not open air), continued down through both
  steps onto `ExplorationFloor`, and confirmed the further-extended kill
  zone still deals lethal damage and respawns correctly at the chamber
  spawn, now several thousand pixels away.
- **Not verifiable headless, flagged explicitly:** whether the
  backdrop composition actually *reads* as a believable, monumental,
  technologically-advanced alien vista rather than "some colored
  triangles" — I can confirm the geometry exists, is positioned behind
  gameplay elements, and doesn't block any collision, but whether it
  achieves the intended visual/emotional effect is a manual-play
  judgment call only a human can make. Same limitation already noted for
  Stage 1's chamber lighting.
- **Not yet verified (needs manual play):** overall pacing of the calm
  section after two fights (does it feel like a deliberate breather or
  just empty space), whether the optional route feels rewarding enough
  to bother with, and whether the reveal's timing (right as the ledge is
  reached) lands well or would benefit from being staged in differently.

## Vertical Slice — Stage 5 (Ranged Enemy + Mini-Boss Arena)

**Status: implemented, headless-validated for structure and correctness
(both attack types, phase 2, defeat, arena bounds), but with an honest,
not-glossed-over difficulty finding below — needs manual play-test before
this pacing is trusted.**

User said "continue." Stage 5 covers the last two combat beats: a ranged
encounter and the mini-boss arena. Scene-only again, reusing
`RangedEnemy.tscn` and `MiniBoss.tscn` exactly as validated in Steps 9
and 14 — no rebalancing, no new scripts.

### Files changed

- `scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.tscn`:
  - `RangedFloor` (800px, flush with `ExplorationFloor`) carrying
    `RangedSentry`, a single stationary `RangedEnemy.tscn` instance
    positioned to force an approach through its line of fire.
  - `BossArenaFloor` (1200px, flush with `RangedFloor`) carrying
    `MiniBoss` with generous room on both sides of its position relative
    to its own `melee_range` (55) and `detection_range` (220), so both
    its attack patterns can actually occur rather than being cramped into
    always-melee or always-ranged. No capping wall on the far end —
    left open for Stage 6/7 to continue from, same as every prior stage
    transition.
  - Extended `KillZone` (6750 → 8850 width) and `Camera2D` `limit_right`
    (6350 → 8350), same pattern as every prior stage.

### How to test

1. Open `AvarisVerticalSlice.tscn`, run it directly.
2. Past the exploration descent, a teal sentry fires from range — close
   the distance (or fight from range with your own approach) and defeat
   it with the combo.
3. Continue into the arena — a larger crimson mini-boss should melee up
   close or fire projectiles from range depending on distance, and
   visibly darken/speed up once below ~50% health.
4. **This is the one to pay closest attention to during playtesting**: try
   the fight arriving at whatever health the ranged sentry left you at,
   with no artificial buffer. See "Difficulty finding" below for why.

### Validation performed by the assistant

- `godot --headless --path . --import` / `AvarisVerticalSlice.tscn
  --quit-after 90` — both clean, no errors.
- Wrote a throwaway real-engine-loop test (not committed, deleted after)
  that fought through both encounters via real input. Confirmed: the
  ranged sentry engages and is defeatable by the combo; the boss engages
  with a **ranged** attack first when approached from outside
  `melee_range` (confirmed at distance ≈219, correctly beyond the 55px
  melee threshold); closing distance triggers its **melee** attack too;
  `phase2_started` fires as health crosses 50%; a full boss kill
  correctly frees the node (`is_instance_valid` false) and lets the HUD/
  kill-zone/respawn flow continue working at the new, further-extended
  arena bounds.
- **Two of my own test-authoring mistakes caught and fixed, not game
  bugs** (both documented in the deleted test's comments so they're not
  silently lost): (1) `RangedEnemyAI`/`BossAI` fire projectiles via
  `get_tree().current_scene`, which this throwaway `SceneTree` harness
  never sets by default (only Godot's own scene loader sets it
  automatically) — the very first Stage 5 run to actually exercise a
  projectile-firing code path crashed on this, fixed by explicitly
  setting `current_scene` after `add_child()`. (2) An early version of
  the test tried scripting a "smart" Veyr-Step dodge reacting to
  `is_attacking` — diagnostics showed this was actively harmful against
  the *ranged* attack specifically: `is_attacking` goes false again the
  instant the projectile is fired (windup ends), so the dodge's 0.1s
  invulnerability window was reacting to the wrong signal and expiring
  long before the projectile actually arrived, while the forced retreat
  it triggered kept preventing the player from ever closing to melee
  range at all. Removed the scripted dodge entirely in favor of a plain
  facetank-and-combo approach — same reasoning as Stage 3's Perfect Step:
  scripting fake-precise reactive timing isn't a trustworthy proxy for
  real player skill, so don't pretend to have proven it.

### Difficulty finding — flagged, not silently passed

With the scripted dodge removed, a plain "close distance and combo,
tank whatever lands" approach starting at the health left over from the
ranged sentry fight (84/100 in every run) **won only 1 of 3 back-to-back
identical scripted attempts** — the other two died with the boss at very
low remaining health (~single-digit-to-low-double-digit HP on both
sides, decided by a hair). Per-tick health logging showed near-identical
damage trajectories across all three runs (health tracking within a few
points of each other at every checkpoint), meaning this isn't test
flakiness — it's a genuinely tight fight at this starting health with
zero mitigation. This does **not** mean the encounter is unfair: a real
player has tools this simplistic script deliberately wasn't scripted to
use well (actual reactive dodging with correct timing, Veyr Step used
defensively rather than my broken attempt at it, retreating to bait the
slower ranged attack, etc.) — Steps 14/15 already validated the boss's
combat math is sound in isolation at full health. What Stage 5 adds that
wasn't tested before is the **sequencing**: arriving at the boss already
chipped by the ranged sentry, with no rest/heal in between (no
checkpoint system exists, per the approved plan). Flagging this
explicitly rather than quietly reporting "boss defeated, all good" —
please specifically judge during manual play whether that chip damage
plus the boss's difficulty feels fair, or whether the ranged sentry
encounter needs more room to be fought/dodged without guaranteed damage
before reaching the arena.

## Vertical Slice — Stage 6 (Memory Sequence)

**Status: implemented, headless-validated end-to-end through the real
engine loop (including catching and fixing a real, previously-latent
engine bug), needs manual play-test.**

User said "continue." Stage 6 covers the Memory beat. Per the approved
plan's explicit correction, this is staged as **PRESENT → PAST →
PRESENT**, not an instant palette swap — a real transition with duration,
a held middle state, and a transition back, plus actual new geometry
appearing (not just existing geometry recoloring).

### Files created/changed

- `scripts/systems/MemorySequence.gd` (new) — orchestrates the three
  phases: fades a `CanvasModulate` from a normal tint to a violet "past"
  tint over `fade_duration` (default 1.2s), holds for `hold_duration`
  (4.0s) with a `MemoryOnly` node made visible, then fades back and hides
  it again. Fires once (guarded by `_played`), connects to a sibling
  `PlayerTrigger` via an exported `NodePath` (matching the existing
  `Hurtbox.health_component_path` convention). Deliberately does **not**
  freeze or alter player control — it's atmospheric only, layered over
  normal play rather than taking it away. No dialogue, no new characters,
  no cutscene system.
- `scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.tscn` —
  added `MemoryFloor` (700px, flush past `BossArenaFloor`), a
  `MemoryTrigger` (`PlayerTrigger`, `one_shot = true` — the first
  one-shot use of this component anywhere in the project; every prior
  use was the always-on `KillZone`), and the `MemorySequence` node with
  its `CanvasModulate` and `MemoryOnly` children. The memory-only content
  is two thin "bridge" `Polygon2D`s connecting the Stage 4 reveal's
  skyline spires (`SpireA`↔`SpireC`, `SpireC`↔`SpireD`) plus three small
  lit "windows" on the tallest spire — implying the same Avaris skyline
  intact and inhabited, before The Fall (`docs/LORE.md`), using only
  already-established lore, no invented plot specifics. Extended
  `KillZone`/`Camera2D.limit_right` again, same pattern as every prior
  stage.

### A real, previously-latent engine bug found and fixed

`PlayerTrigger._on_body_entered` set `monitoring = false` directly when
`one_shot` fires — this is exactly the "mutating state synchronously
inside the signal that's driving it" problem already documented once
before (Step 15's post-hit invulnerability fix), and Godot 4.7.2 blocks
it outright (`ERROR: Function blocked during in/out signal`). It was
never caught earlier because **every prior use of `PlayerTrigger` in this
project has been the always-on `KillZone` (`one_shot = false`)** — this
is the first time a `one_shot = true` trigger has actually fired end to
end. Fixed with `set_deferred("monitoring", false)`, mirroring the exact
fix pattern already used for the invulnerability case. This is a fix to
the shared, reusable `PlayerTrigger.gd` component itself, so it also
retroactively protects any future one-shot trigger use in Stage 7.

### How to test

1. Open `AvarisVerticalSlice.tscn`, run it directly.
2. Past the mini-boss arena, continue onto a short floor and walk into
   the marked threshold — the whole scene should slowly tint violet, and
   after a beat, two glowing bridges and three lit windows should appear
   connecting the distant skyline spires from the Stage 4 reveal, held
   for a few seconds, then fade back to normal (bridges/windows
   disappearing again).
3. Confirm you can still move/act freely throughout the sequence — it
   shouldn't freeze or restrict you.
4. Walk out and back into the same spot — it should not replay.

### Validation performed by the assistant

- `godot --headless --path . --import` / `AvarisVerticalSlice.tscn
  --quit-after 90` — both clean, no errors (post-fix).
- Wrote a throwaway real-engine-loop test (not committed, deleted after)
  that walked the player into the trigger and confirmed, through real
  elapsed time (not an instant check): the tint genuinely progresses
  toward the past color rather than snapping to it, the memory-only
  geometry becomes visible while held, the player's own input still
  produces normal movement velocity mid-sequence (proving control isn't
  taken away), the tint and geometry both correctly return to their
  present state afterward, and that walking back into the same trigger
  zone a second time does **not** replay the sequence (confirming
  `one_shot` actually holds — which is what surfaced the engine bug
  above in the first place). Also confirmed the further-extended kill
  zone and respawn still work.
- **Not yet verified (needs manual play):** whether the fade timing
  (1.2s in/out, 4s hold) reads as deliberate and well-paced rather than
  too slow or too abrupt, whether the violet tint level is legible
  without being disorienting, and whether the memory content (intact
  bridges + lit windows on the already-seen skyline) actually lands as
  "this place used to be alive" without any text/dialogue to make that
  explicit — a purely visual storytelling bet that's inherently a human
  judgment call.

## Vertical Slice — Stage 7 (Rhaek Teaser + End Marker)

**Status: implemented, headless-validated end-to-end through the real
engine loop, needs manual play-test. This is the final stage of the
vertical slice.**

User said "continue." Stage 7 covers the last two beats: the Rhaek
teaser and an end-of-slice marker. Per the approved plan's explicit
correction, the teaser is **staged as presence → attention → departure**,
not a static silhouette. Rhaek stays a reserved, uncharacterized canon
character throughout ([LORE.md](LORE.md)/[GDD.md](GDD.md) §5) — nothing
about who they are is shown, stated, or implied beyond "a distant figure
that notices you and leaves."

### Files created/changed

- `scripts/systems/RhaekTeaser.gd` (new) — same self-contained,
  `PlayerTrigger`-driven pattern as `MemorySequence.gd`. Three timed
  phases: **presence** (the silhouette fades into view over 0.6s),
  **attention** (after a 1.4s beat, it turns to face the player's actual
  position and briefly brightens to the established Veyr-violet color
  before returning to its own base color — the turn alone would be
  subtle at this distance, so the color pulse is what actually
  communicates "it noticed you"), **departure** (after another 1.6s
  beat, it dissolves via the same violet burst/fade visual language as
  Zayr's own Veyr Step — implying a shared nature through the *visual
  language itself*, not through anything stated). Never freezes or
  alters player control, same as `MemorySequence`. No dialogue, no
  approach, no combat with it — it's on `EndSpire`, an unreachable
  background structure with no collision.
- `scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.tscn`:
  - `EndFloor` (past `MemoryFloor`), `EndSpire` (tall, non-collision,
    the distant perch Rhaek's silhouette stands on), a `RhaekTrigger`
    (`PlayerTrigger`, `one_shot = true`), and the `RhaekTeaser` node
    with its `Silhouette` and `DepartBurst` children.
  - `EndWall` + `ClosingSpire` + `ClosingConduit` — a deliberate
    **bookend** to the Awakening chamber that opened the slice: the same
    tapered-spire-against-a-wall silhouette and the same thin
    Veyr-violet conduit line embedded in the floor
    (`Color(0.55, 0.4, 1.0)`), marking the current end of the vertical
    slice's content architecturally rather than with any text (no UI/
    dialogue system exists to display "the end"). Unlike every prior
    stage's open-ended floor edge (left open for the next stage to
    extend), this one is capped — there's no Stage 8.
  - Extended `KillZone`/`Camera2D.limit_right` one final time.

### How to test

1. Open `AvarisVerticalSlice.tscn`, run it directly.
2. Past the memory sequence, continue to the final stretch — a distant,
   dark silhouette should fade into view on a tall spire, too far away to
   reach or fight.
3. After a beat, it should turn toward you and flash violet briefly,
   then after another beat dissolve in a small violet burst, like a
   smaller/darker echo of Zayr's own Veyr Step.
4. Confirm you can move/act freely the whole time.
5. Continue to the end — a wall and a matching spire/conduit should
   visually close out the space, echoing the Awakening chamber you
   started in.

### Validation performed by the assistant

- `godot --headless --path . --import` / `AvarisVerticalSlice.tscn
  --quit-after 90` — both clean, no errors.
- Wrote a throwaway real-engine-loop test (not committed, deleted after)
  that walked the player into the trigger and confirmed all three phases
  through real elapsed time: the silhouette's opacity genuinely rises to
  full over the presence fade (not an instant appearance), it turns to
  face the player's actual side (`scale.x` correctly negative when the
  player is to its left), the color genuinely pulses to the Veyr-violet
  attention color and back, it genuinely dissolves back to zero opacity
  with the departure burst appearing then hiding again, player input
  still produced normal movement velocity throughout (control never
  taken away), re-entering the trigger zone afterward does **not**
  replay it (`one_shot` holds correctly — same `PlayerTrigger` component
  fixed during Stage 6, confirmed still solid here), and the final kill
  zone extent still deals lethal damage and respawns correctly.
- One of my own test-authoring mistakes caught and fixed (not a script
  bug): the test initially checked the silhouette's facing direction
  right after the presence fade completed, before the attention phase
  (which is what actually performs the turn) had even started — moved
  the check to the correct phase and confirmed it passes.
- **Not yet verified (needs manual play):** whether the silhouette reads
  as "a distant figure" rather than "an unfinished asset" at this
  graybox fidelity, whether the pacing (0.6s presence / 1.4s / 0.4s pulse
  / 1.6s / 0.5s dissolve — roughly 4.5s total) feels like a deliberate
  beat or drags, and whether the Awakening-chamber bookend at the very
  end actually reads as an intentional close rather than just "the level
  stopped."

## Vertical Slice — Complete (Stages 1-7)

All seven stages of the approved plan are implemented and individually
headless-validated. `scenes/regions/avaris/vertical_slice/
AvarisVerticalSlice.tscn` now contains the full path: Awakening chamber →
Movement Introduction → First Combat → Combat Encounter → Veyr Step
Encounter (flanking pair) → Perfect Step Opportunity (isolated enemy) →
Avaris Reveal (composition-driven skyline) → Exploration (primary +
optional route) → Ranged Enemy → Mini-Boss Arena → Memory Sequence
(staged PRESENT→PAST→PRESENT) → Rhaek Teaser (staged presence→attention→
departure) → End Marker (bookending the Awakening chamber). `TestArena.
tscn` remains the project's main scene, untouched throughout — the
vertical slice is a separate, directly-run scene.

**Two real, previously-latent engine bugs were found and fixed along the
way** (both now protect all future use of the shared components they're
in, not just this scene): `PlayerController._on_hit_received`'s
same-frame invulnerability race (Step 15, predates the slice but is what
the slice's HURT-state reuse depends on) and `PlayerTrigger`'s
synchronous `monitoring` mutation inside its own signal (Stage 6 — never
caught before because every prior use was the always-on kill zone, not a
one-shot trigger).

**The Stage 5 difficulty finding has since been addressed** — see
"Stage 5 Difficulty Fix" below.

**Nothing in this milestone has been manually play-tested by a human.**
Every stage's headless validation proves the systems function correctly
through the real engine loop, but "does it feel right" — pacing, combat
feel, whether the reveal/memory/teaser land emotionally, whether the
Stage 5 difficulty finding is actually a problem — is explicitly outside
what headless testing can answer, and is called out per-stage above.

**Not yet done, and not started without direction:** `docs/GDD.md` and
`docs/ARCHITECTURE.md` were not touched during any of the seven stages
(only `docs/PROGRESS.md`, per the stage-by-stage validation record). Now
that the full slice exists, it may be worth a short pass adding the new
reusable systems (`PlayerTrigger`, `MemorySequence`, `RhaekTeaser`) to
`ARCHITECTURE.md` and noting the vertical slice's existence in `GDD.md`
— flagging this as a natural next step rather than doing it unprompted.

## Stage 5 Difficulty Fix (Mini-Boss Damage Tuned Down, Scene-Local)

**Status: implemented, headless-validated (5/5 wins with a comfortable
margin, up from 1/3), needs manual play-test to confirm it feels right.**

User picked this as the next thing to work on. Fix, not a rebalance of
the shared boss: `MiniBoss.tscn`'s `AI` node (`BossAI.gd`) is instanced
in **two** places — `TestArena.tscn` (where the player always arrives at
full 100 health, already validated fair in Steps 14/15) and this vertical
slice (where the player arrives chipped to 84/100 by the ranged sentry
fight immediately before it, with no rest/heal in between — the specific
new factor Stage 5 introduced). Changing `MiniBoss.tscn`'s base values
would have also changed `TestArena.tscn`'s already-validated encounter,
which isn't broken and wasn't asked for. Instead, overrode the exported
values on **this scene's specific `MiniBoss` instance only**, using
Godot's standard per-instance child override syntax (`[node name="AI"
parent="MiniBoss"]` with just the two changed properties) — the same
mechanism already used throughout this project for scene-local Camera2D
limits, Hitbox damage, etc. `MiniBoss.tscn` itself is untouched.

### What changed

- `scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.tscn` — the
  `MiniBoss` instance now overrides `AI.melee_damage` (14.0 → 10.0) and
  `AI.ranged_damage` (10.0 → 7.0). Sized directly from the Stage 5
  diagnostic data, not guessed: the original per-tick health log showed
  the player took ~82 damage total across ~7-8 hits over the course of a
  winning fight, against a starting buffer of only 84 — a ~2 HP margin at
  best. A ~3-4 point reduction per hit across that many hits removes
  roughly 25-30 HP of total incoming damage, which was the specific
  target: shift the typical finish from "coin-flip, ~0-4 HP remaining"
  to a comfortable double-digit buffer, without changing attack
  telegraphs, cooldowns, patterns, or phase 2's escalation - the fight
  should still look and play the same, just hit a bit less hard.

### Validation performed by the assistant

- `godot --headless --path . --import` / `AvarisVerticalSlice.tscn
  --quit-after 90` — both clean, no errors.
- Re-ran the **exact same** plain facetank-and-combo scripted approach
  from the original Stage 5 finding (no dodging, same engagement logic)
  five times in a row via a throwaway real-engine-loop test (not
  committed, deleted after): **5/5 wins**, finishing with player health
  at 16, 26, 26, 26, 26 respectively (three runs landed on an identical
  trajectory, one varied slightly - consistent with the same real-time
  scheduling variance already documented elsewhere in this project, not
  a bug). Every run's per-tick log showed a steady, predictable damage
  race with a real buffer throughout, not a near-death finish. This is
  a large, unambiguous improvement over the original 1/3 win rate with a
  0-4 HP margin.
- Did **not** re-test `TestArena.tscn`'s boss encounter, since nothing
  about it changed - the override is scoped entirely to this one scene's
  instance.
- **Not yet verified (needs manual play):** whether the fight still
  *feels* appropriately threatening at the new damage values, or whether
  it now reads as too easy - a scripted win-rate number can't judge
  "feels fair," only "is survivable." Please specifically confirm this
  during your playtest.

## Main Scene Switched to the Vertical Slice

**Status: done, headless boot-validated.**

User's next "continue" was taken as approval to finish the last flagged
open item: `project.godot`'s `run/main_scene` now points to
`scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.tscn` instead
of `scenes/regions/TestArena.tscn`. Pressing Play (F5) now launches the
vertical slice directly — no more needing to open the scene and press F6
each time. `TestArena.tscn` is untouched and still fully runnable
on-demand (F6 with it open) if it's ever needed again as the isolated
combat-prototype sandbox.

Validated via `godot --headless --path . --quit-after 90` **with no
scene argument** (i.e. using whatever `project.godot` actually points
to) — clean boot, no errors, confirming the config change resolves
correctly through Godot's own scene-loading path, not just via an
explicit `--path`-plus-scene invocation.

## Art Pass — Stage A (Glow / Bloom)

**Status: implemented, visually verified via real (non-headless)
screenshot capture — a new testing capability discovered this pass, see
[ARCHITECTURE.md](ARCHITECTURE.md) §9/§11 — needs manual play-test for
actual in-motion feel.**

User approved a 5-stage procedural art pass (Glow/Bloom → Ambient
Lighting → Surface Gradients → Particle VFX → Post-Processing), one
stage at a time. First flagged and confirmed a real constraint: no
image-generation tool is available, so this is entirely Godot rendering
features on the existing geometric shapes, not new sprite/texture
assets. Scoped to the vertical slice only.

### What changed

- `scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.tscn` — added
  a `WorldEnvironment` with `glow_enabled = true`. Boosted the already-
  established Veyr-violet elements (chamber `Conduit`/`ClosingConduit`,
  the Memory sequence's `BridgeAC`/`BridgeCD`/`WindowA-C`, `RhaekTeaser`'s
  `DepartBurst`) with a gentle HDR color overshoot so they catch the glow
  — see [ARCHITECTURE.md](ARCHITECTURE.md) §11 for the exact convention
  and values. Nothing else in the scene was touched.
- `scripts/player/PlayerVeyrStep.gd` — `trail_color` default boosted the
  same way, so Zayr's own step trail/bursts glow too (this is a shared
  component, so `TestArena.tscn` picks up the same polish as a side
  effect — harmless, not a scope violation, since the file itself wasn't
  touched).
- `scripts/systems/RhaekTeaser.gd` — `attention_color` default boosted
  to match.
- `scenes/ui/HUD.tscn` — the Veyr bar's color changed from an unrelated
  blue to the established violet hue, **kept at normal brightness**
  (deliberately not glow-boosted — a persistent resource meter needs to
  stay legible, judged a higher priority than visual consistency here).

### A real calibration mistake, found and fixed via a new testing technique

First attempt (~2.4x color boost, `glow_intensity = 0.9`) looked fine on
paper but a screenshot showed thin/small glowing shapes (the conduit
line, Rhaek's silhouette) **desaturating to near-white** instead of
glowing violet — bloom disproportionately blows out small bright
features. This is exactly the kind of mistake the project's own repeated
"can't verify visually, needs manual play" caveat was about — except
this time it didn't need to wait for manual play: `--headless` uses
Godot's dummy renderer (`Viewport.get_texture()` returns null there),
but running the **same** throwaway `SceneTree`-script technique
**without** `--headless` uses the real GPU renderer and screenshots work
fine, while still being scripted/non-interactive/`--quit()`-terminated —
not a manual play session, just a new way to close part of the "can't
see it" gap. Recalibrated to a gentle ~1.3x overshoot with lower
`glow_intensity`/`glow_bloom`, re-screenshotted, confirmed it now reads
as a soft violet glow rather than a white blowout across all four
target categories (chamber conduit, memory bridges/windows, Veyr Step
trail/burst, Rhaek's silhouette).

### Validation performed by the assistant

- `godot --headless --path . --import` — clean, no errors.
- `godot --headless --path . --quit-after 90` (vertical slice) and
  `godot --headless --path . scenes/regions/TestArena.tscn --quit-after
  150` — both clean, confirming the shared-component changes
  (`PlayerVeyrStep.gd`, `HUD.tscn`) don't break the other scene.
- Captured and visually inspected 4 real screenshots (not committed,
  deleted after) via throwaway non-headless `SceneTree` scripts: the
  Awakening chamber (conduit), the Memory sequence's bridges/windows
  (forced on directly, camera repositioned manually since there's no
  floor up near the skyline to stand on), a live Veyr Step mid-flight,
  and Rhaek's silhouette at its attention color. All four confirmed
  correct after recalibration.
- **Not yet verified (needs manual play):** how the glow looks in
  motion (screenshots are single static frames — flicker, motion blur
  interaction, and general "does it read well while actually playing"
  are unverified), and whether the glow intensity should be stronger or
  weaker as a matter of taste once seen in real play rather than a still
  frame.

## Art Pass — Stage B (Ambient Lighting)

**Status: implemented, visually verified via real screenshot capture
(chamber, wall-jump shaft, and a present/past brightness comparison of
the memory sequence), needs manual play-test.**

User said "continue," approving Stage B. Godot 2D `Light2D`s are
additive only — they don't create darkness by themselves — so getting
real lit-vs-dim contrast meant actually dimming the base scene first.
Reused `MemorySequence.gd`'s existing (and only) `CanvasModulate` rather
than adding a conflicting second one — see
[ARCHITECTURE.md](ARCHITECTURE.md) §11 for the full technical writeup.

### What changed

- `AvarisVerticalSlice.tscn` — `MemorySequence`'s `present_tint`/
  `past_tint` overridden to a dim baseline (`Color(0.5, 0.5, 0.62, 1)`)
  and a *brighter* past (`Color(0.85, 0.75, 1.0, 1)`), which does
  thematic double duty for free: present now reads dimmer/"fallen,"
  past reads brighter/"alive," reinforcing the Memory beat through
  ambient light level, not just hue.
- Added 4 `PointLight2D`s, all sharing one procedural `GradientTexture2D`
  falloff shape (radial gradient, defined as `.tscn` data — no image
  assets): `ChamberLight` (violet, at the Awakening chamber's conduit),
  `ShaftLight` (warm orange, matching the existing wall-jump affordance
  color), `WindowLight` (parented under the Memory sequence's
  `MemoryOnly`, so it inherits that node's existing show/hide for free),
  and a `Light` under `RhaekTeaser`, explicitly toggled on/off in the
  script alongside the silhouette's own presence/departure.
- `scripts/systems/RhaekTeaser.gd` — added the `light` reference and two
  toggle lines (on at presence, off after departure).
- `scripts/systems/MemorySequence.gd` — doc comment updated to note
  `present_tint`/`past_tint` now double as the scene's ambient-lighting
  baseline.

### A real bug caught while implementing this, unrelated to lighting itself

While reviewing the color-boosted elements for this pass, found that
`RhaekTeaser`'s `DepartBurst` still had the **original, too-intense**
pre-recalibration glow color from Stage A (`Color(1.3, 0.95, 2.4, 1)`) —
Stage A's recalibration used three `replace_all` passes keyed on exact
alpha values (`0.75`/`0.85`/`0.95`), and this one node's alpha was `1`,
so it silently didn't match any of them. Never actually visually
confirmed before now, since Stage A's Rhaek screenshot only checked the
silhouette's attention color, not a live departure burst. Fixed to match
the same gentle ~1.3x overshoot as everything else.

### Validation performed by the assistant

- `godot --headless --path . --import` / `--quit-after 150` — both
  clean, no errors.
- Captured and inspected 4 real screenshots (not committed, deleted
  after): the dimmed chamber with its violet conduit glow, the wall-jump
  shaft with a warm glow pooling on the floor beneath the orange walls,
  the memory sequence at "past" (bridges/windows/light visible, brighter
  ambient), and the same camera position at "present" for direct
  comparison — confirmed the present/past brightness contrast is clearly
  visible, not subtle to the point of being missed.
- Hit and solved a real test-harness issue getting these screenshots:
  manually setting `Camera2D.global_position` didn't stick because
  `CameraController.gd`'s own `_ready()` (which re-enables
  `position_smoothing_enabled`) hadn't fired yet when the test tried to
  disable it (the same deferred-`_ready`-after-`add_child` timing noted
  repeatedly elsewhere in this project), so the camera kept smoothing
  back toward the player. Fixed by giving the smoothing far more frames
  to settle (~35-40) rather than assuming a near-instant snap — noting
  this here so a future screenshot test doesn't have to rediscover it.
- **Not yet verified (needs manual play):** how the lighting reads in
  motion and at normal gameplay zoom (screenshots used zoomed-out/
  repositioned cameras to frame specific elements clearly), and whether
  the dimmed baseline is a good default brightness for actually playing
  through, not just for judging a static comparison shot.

## Art Pass — Stage C (Surface Gradients)

**Status: implemented, visually verified via real screenshot capture,
needs manual play-test.**

User said "next stage." Swapped flat single-color floor/wall/platform
fills for subtle vertical gradients using `Polygon2D.vertex_colors`
(top ~20% lighter, bottom ~20% darker than the original flat color) —
pure data changes to existing nodes, no new nodes, no new scripts.

### What changed

- `AvarisVerticalSlice.tscn` — added `vertex_colors` to 24 floor/wall/
  platform `Polygon2D` "Visual" nodes across every stage: plain floors,
  steps/platforms, chamber/end walls, the wall-jump shaft's orange walls,
  and the cyan dash-landing/exit-ledge platforms. Applied via one
  `replace_all` edit per distinct base color (5 colors covering all 24
  nodes) rather than editing each node individually, since every floor/
  wall in this project shares the same 4-point axis-aligned rectangle
  polygon convention regardless of size — one `(light, light, dark,
  dark)` vertex-color array is correct for any node using that base
  color, independent of that node's actual dimensions. Decorative
  elements (backdrop spires, the chamber/closing Spire silhouettes) were
  deliberately left flat — they're meant to read as clean silhouettes,
  not shaded surfaces.

### Validation performed by the assistant

- `godot --headless --path . --import` / `--quit-after 150` — both
  clean, no errors or vertex-count-mismatch warnings.
- Before batch-applying, verified on a single node (the Awakening
  chamber floor) via screenshot that `vertex_colors` actually overrides
  `color` for rendering (genuinely renders the gradient, not a
  double-tinted or ignored result) — confirmed correct, then proceeded
  to batch the rest with confidence rather than guessing.
- Screenshotted the wall-jump shaft after the full batch: the orange
  walls, the cyan `ExitLedge`, and the floor all show a clear top-lighter
  /bottom-darker gradient, combining naturally with Stage B's
  `ShaftLight` glow rather than fighting it.
- **Not yet verified (needs manual play):** how the gradients read at
  normal gameplay zoom and in motion (screenshots used a closer/wider
  camera than default to inspect the effect clearly), and whether the
  gradient direction (top-lit) reads as intentional or arbitrary without
  an actual light source consistently overhead.

## Art Pass — Stage D (Particle VFX)

**Status: implemented, functionally and visually verified, needs manual
play-test.**

User said "continue." A scope adjustment from the original Stage D
description worth calling out explicitly: rather than *upgrading* the
existing star-shaped burst polygons (Veyr Step, Rhaek's dissolve) to
real `GPUParticles2D`, added particle bursts **alongside** them — the
existing polygons drive tested, working gameplay-adjacent animation
logic (including Perfect Step's burst-size multiplier), and rewriting
that for cosmetic gain carried real risk for comparatively little
benefit. This is a deliberate, flagged deviation from the original
5-stage plan's wording, not a silent scope cut.

### What changed

- `assets/vfx/particle_dot.tres` (new) — a small shared
  `GradientTexture2D` (procedural radial gradient, no image asset)
  used as every particle's sprite.
- `scenes/player/Player.tscn` + `scripts/player/PlayerVeyrStep.gd` —
  added `DepartParticles`/`ArriveParticles` (`GPUParticles2D`,
  one-shot, small violet sparks), triggered via `restart()` in
  `_do_step()` at the same moment and position as the existing polygon
  bursts. Shared file with `TestArena.tscn`, so it picks up the same
  polish as a side effect (same reasoning as Stage A's trail color).
- `scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.tscn` +
  `scripts/systems/RhaekTeaser.gd` — added a `DepartParticles` burst to
  Rhaek's dissolve, same pattern. Also added two **ambient** (continuous)
  particle systems: `ChamberDust` in the Awakening chamber and
  `VistaMotes` at the Stage 4 reveal, both spread across an area (not a
  single point) and pre-warmed via `preprocess` so they're already
  mid-cycle when the scene loads.
- Particle scale was tuned down from an initial pass (`0.5-1.3`) to
  `0.2-0.55` after a screenshot showed the larger scale reading as
  "bubbles" rather than "sparks" — the established Veyr Step burst is a
  star/shard shape, and round particles that large visually competed
  with that geometric language instead of complementing it.

### Validation performed by the assistant

- `godot --headless --path . --import` / `--quit-after 150` (both
  scenes) — clean, no errors; `PlayerVeyrStep`/`RhaekTeaser` re-registered
  correctly after the script changes.
- Wrote a throwaway real-engine-loop test (not committed, deleted after)
  that called `_do_step()` directly and confirmed both
  `depart_particles.emitting`/`arrive_particles.emitting` become `true`,
  and called `RhaekTeaser._run_sequence()` directly and confirmed it
  starts without error.
- Captured and inspected 3 screenshots (not committed, deleted after):
  the chamber's ambient dust (a small subtle drifting cluster), the
  Veyr Step burst (confirmed the re-scaled "spark" look after the
  bubble-sized first attempt), and the reveal vista's motes near the
  skyline spires.
- **Known, accepted gap, not silently unhandled:** Perfect Step's burst-
  size bonus does not currently affect the new particle bursts — see
  [ARCHITECTURE.md](ARCHITECTURE.md) §11 for why (timing: the particle
  burst is fully emitted before a perfect trigger could be detected).
- **Not yet verified (needs manual play):** how the particle bursts read
  in actual motion (screenshots are single frames early in a short-lived
  burst), and whether the ambient dust/motes are noticeable enough to
  register at normal gameplay zoom without being distracting.

## Art Pass — Stage E (Post-Processing) — Art Pass Complete

**Status: implemented, visually verified via real screenshot capture,
needs manual play-test. This is the final stage of the originally-
approved 5-stage art pass.**

User said "continue." Added a subtle vignette and gentle global color
grading — the last of the 5 planned stages.

### What changed

- `shaders/Vignette.gdshader` (new) — a small screen-space `canvas_item`
  shader darkening toward the viewport edges, resolution-independent.
- `AvarisVerticalSlice.tscn` — a `VignetteLayer` `CanvasLayer` +
  full-screen `ColorRect` applying that shader; `mouse_filter` explicitly
  set to `IGNORE` (this matters more than usual — a blocking full-screen
  `Control` would have swallowed every left/right mouse click, which are
  now the attack/heavy-attack inputs). The existing `WorldEnvironment`'s
  `Environment` gained `adjustment_enabled` with gentle contrast (1.08)
  and saturation (0.92) tweaks.
- `scenes/ui/HUD.tscn` — explicit `layer = 2` on its `CanvasLayer` (was
  unset/default before) so it reliably draws above the new vignette
  layer regardless of tree order.

### Validation performed by the assistant

- `godot --headless --path . --import` / `--quit-after 150` (both
  scenes) — clean, no errors.
- Screenshotted the result: first pass (`intensity 0.55`) crushed the
  corners toward black — recalibrated to `0.32` with a larger radius/
  softness for a genuinely subtle effect, same lesson as Stage A's glow
  overshoot. Confirmed the HUD bars stay crisp and fully legible on top
  of the vignette (the explicit layer ordering works).
- **Not yet verified (needs manual play):** whether the vignette and
  color grading read as intentional mood-setting during actual play, or
  as an unwanted "screen looks slightly off" impression — this is
  exactly the kind of subtle effect that's easy to misjudge from a
  single still frame.

## Art Pass — Summary (Stages A-E, all complete)

All 5 originally-approved stages are implemented and individually
screenshot-verified: **A** Glow/Bloom, **B** Ambient Lighting, **C**
Surface Gradients, **D** Particle VFX, **E** Post-Processing. Two real
bugs were caught and fixed along the way (Stage A's initial glow
overshoot desaturating small shapes to white; Stage B's discovery that
Rhaek's departure burst had silently kept the pre-recalibration Stage A
color). One deliberate scope adjustment was flagged, not silently made
(Stage D: additive particles alongside the existing tested burst
animations, not a full rewrite of them). Everything is scoped to the
vertical slice scene (`AvarisVerticalSlice.tscn`) plus a few shared
components (`PlayerVeyrStep.gd`, `HUD.tscn`) that also benefit
`TestArena.tscn` as a harmless side effect — no gameplay logic,
balance, or level geometry was touched by any of it.

**Nothing in this art pass has been seen by a human yet.** Every stage's
verification was screenshot-based (see [ARCHITECTURE.md](ARCHITECTURE.md)
§9 for the technique) — real, but static single frames, not actual play.
Please play through `AvarisVerticalSlice.tscn` and report anything that
feels off: too dark, too bright, distracting, or just not landing as
intended.

## Combat Prototype — Ranged Veyr Attack

**Status: implemented, headless-validated end-to-end through the real
engine loop, needs manual play-test.**

User asked to add aerial attacks, ranged Veyr, and/or charged attacks —
all three were previously just named in the GDD with no mechanical
detail, same situation Heavy Attack and Perfect Step were in before a
design brief existed. Asked which to prioritize; user picked the ranged
Veyr attack. Proposed a full design (component, mechanics, Veyr cost,
input) before writing any code, per the established process for
unspecified named abilities, and got it approved (with one correction:
no middle mouse button — the user wants keyboard, near WASD, so it stays
reachable without leaving the movement hand — landed on Q).

Full design, implementation detail, tuning values, and validation are in
[COMBAT.md](COMBAT.md) §13 rather than duplicated here. Short version:
new `scripts/player/PlayerRangedAttack.gd` component fires the existing
`Projectile` primitive (reused from the enemy ranged attack, exactly the
reuse it was originally built for) in Zayr's facing direction, costs 15
Veyr (spent only on actual fire, not a cancelled windup) — the first
ability that gives the previously-inert Veyr bar an actual purpose in
normal play — and is mutually exclusive with the melee combo/heavy
attack in both directions. Bound to **Q**.

Headless-validated through the real engine loop against `TestArena.tscn`
(fires, hits for exact configured damage, Veyr cost timing, mutual
exclusion both directions, Veyr Step cancellation without wasting Veyr,
correct refusal when Veyr is insufficient) — see COMBAT.md §13 for the
full validation writeup. **Not yet verified (needs manual play):**
whether the windup/cost/cooldown feel right, and whether the lack of any
Veyr regeneration makes this feel like a fair limited resource or a
frustrating dead end in an actual fight.

## Combat Prototype — Aerial Attacks

**Status: implemented, headless-validated end-to-end through the real
engine loop, needs manual play-test.**

User picked this as the next of the three from the earlier ask. Before
proposing anything, checked whether airborne attacking already did
something — no code gates it to grounded-only — and confirmed via a
real-engine test that it technically works but is barely useful: the
`Hitbox` is horizontal-only at Zayr's own height, so a swing while
airborne above a ground-level enemy simply misses vertically even at
correct horizontal range. Reported that finding before proposing a fix.

Full design/implementation/tuning/validation detail is in
[COMBAT.md](COMBAT.md) §14. Short version: not a new attack — holding
aim-down (S) while airborne repositions the existing combo/heavy
attack's `Hitbox` below Zayr and rotates it to point downward, reusing
every existing damage/timing/cooldown value verbatim. Grounded attacks
and airborne attacks without aim-down are completely unchanged. All in
`PlayerCombat.gd`, no new component needed (unlike the ranged attack,
which did need one).

Headless-validated: grounded attack regression check, airborne-without-
aim-down unchanged (confirms opt-in, not a silent behavior change),
airborne-with-aim-down correctly hits a ground-level target (the actual
fix), and no lingering rotation state after landing. **Not yet verified
(needs manual play):** whether the 30px reach and the aim-down input
feel discoverable/right in an actual fight.

## Combat Prototype — Charged Attack

**Status: implemented, headless-validated end-to-end through the real
engine loop, needs manual play-test.**

User confirmed "continue" from the original three-option ask, completing
it — this was the last of aerial attacks/ranged Veyr/charged attack.
Proposed a concrete, deliberately simple design before implementing
(Heavy Attack's own brief explicitly warned against "a complicated
charge system"), and got it approved as-is.

Full design/implementation/tuning/validation detail is in
[COMBAT.md](COMBAT.md) §15. Short version: hold **E** to charge for up
to 1 second, release to strike with damage linearly scaled from 14 to 38
based on how long it was held (one `lerp`, not tiers). Lives inside
`PlayerCombat.gd` alongside the combo/heavy attack (shares the same
`Hitbox`), gets the aerial-down variant for free, no Veyr cost by
default, cancellable by Veyr Step at any point without wasting a Veyr
cost that was never actually spent.

Headless-validated: a near-instant release deals ~minimum damage, an
actual full-second hold deals exactly the configured maximum (confirms
the scaling works across its full range, not just guessed), mutual
exclusion with melee holds, and Veyr Step cancels a held charge with
zero damage dealt. Hit and solved a real test-harness gotcha along the
way (re-pressing the same scripted action within one test run can fail
to register — see [ARCHITECTURE.md](ARCHITECTURE.md) §9); confirmed via
isolated single-press test runs instead. **Not yet verified (needs
manual play):** whether a full-second hold feels responsive or
punishing in an actual fight, and whether the damage curve reads as
meaningfully rewarding.

## Combat Prototype — Ranged Veyr / Aerial / Charged Requirements Audit

**Status: audited against a formal written spec, one real gap found and
fixed, headless-validated end-to-end through the real engine loop
(including a full regression pass), needs manual play-test.**

After confirming Stage 2 combat played well enough to proceed, the user
gave a formal written requirement spec for all three abilities (ranged
Veyr, aerial attack, charged attack), explicitly asking each be treated
as "a distinct combat tool rather than simply another damage source,"
and to audit the existing implementations against it rather than assume
they already qualified. Full line-by-line audit against every bullet is
in [COMBAT.md](COMBAT.md) §16.

Ranged Veyr and Charged Attack were already compliant — no changes
needed. **Aerial Attack was not**: its original design (documented above)
was a purely positional/rotational variant of the combo/heavy attack,
reusing their exact damage and timing. That fails the spec's explicit
"should have its own hitbox/timing" and "should feel meaningfully
different from simply performing the ground attack in the air"
requirements. Reported this gap to the user before reworking anything.

Reworked Aerial Attack into a genuinely distinct move in
`PlayerCombat.gd`: its own `@export_group` of tuning values (windup,
active duration, recovery, cooldown, damage, stability damage, hit
offset, color — no longer borrowed from combo/heavy), and it now takes
over the light-attack button entirely while airborne (does not chain
into or interrupt the grounded combo). Heavy Attack and Charged Attack
keep their own pre-existing aim-down-while-airborne capability unchanged
and separate. Added `State.ATTACK_AERIAL` (own debug color) to
`PlayerController.gd`'s state machine, replacing the reused combo/heavy
states it previously borrowed. Full detail in COMBAT.md §14 (rewritten).

Headless-validated via a direct-method-call isolation test (bypassing
simulated input to isolate positioning/damage math after input-timing
noise made an input-driven version of this specific scenario unreliable
— see the two new ARCHITECTURE.md §9 gotchas this surfaced: stale
`is_on_floor()` immediately after a teleport, and a cooldown timer alone
being ambiguous at `0.0`) confirming the reworked attack hits a real
enemy for its own configured damage, not the combo/heavy's. Followed by
a full regression pass confirming zero regressions across the combo,
Heavy Attack, ranged Veyr attack, Charged Attack, Veyr Step, and Perfect
Step, plus confirming HURT-state interruption still correctly cancels an
in-progress attack with the new aerial/charged states included.

Per explicit instruction, Stage 3 was not begun and the vertical slice
level (`AvarisVerticalSlice.tscn`) was not modified — only
`scripts/player/PlayerCombat.gd`, `PlayerController.gd`,
`PlayerRangedAttack.gd`, and docs were touched this pass.

## Combat Prototype — Veyr Regeneration

**Status: implemented, headless-validated end-to-end through the real
engine loop, needs manual play-test.**

Picked as the next item from three open threads offered to the user
(Veyr regen / next vertical-slice milestone / hold for playtest). Came
with an explicit combat-economy brief: Veyr should come back through
aggressive, skilled melee play — not passive waiting — so that spending
it on the ranged attack means temporarily stepping back from the thing
that refills it (melee -> gain Veyr -> spend on Veyr tools -> re-engage
in melee -> gain Veyr). Perfect Step's refund should be the standout
"mastery" reward in the kit.

Full design/implementation/tuning/validation detail is in
[COMBAT.md](COMBAT.md) §17. Short version: a successful hit from the
combo, Heavy Attack, Aerial Attack, or Charged Attack now restores a
small, per-attack-type amount of Veyr via a new
`_restore_veyr_on_hit()` in `PlayerCombat.gd`'s existing
`_on_hitbox_hit_landed()` handler (already connected to the shared
`Hitbox.hit_landed` signal, previously used only for hitstop). Perfect
Step's existing refund (`PlayerVeyrStep.gd`, implemented in an earlier
pass) needed no changes and remains the largest single Veyr gain in the
kit. The ranged attack deliberately never restores Veyr — not a special
case, but a direct consequence of it firing a separate `Projectile`
Hitbox instance whose `hit_landed` was never wired to `veyr.add()`, so
a self-sustaining ranged loop is structurally impossible, not just
discouraged. `VeyrComponent` itself stays an inert pool (`spend()`/
`add()`, clamped to max) — no passive regeneration, no timer, no
`_process()` — every gain is triggered at its own event's call site.

Headless-validated: all four melee-hit restores confirmed exact
(including a genuine miss restoring nothing), the ranged attack's cost
spent at fire and confirmed NOT refunded on a real landed projectile
hit (not just a missed shot), Perfect Step's refund confirmed via the
same engineered real-overlap technique used in the Aerial Attack pass,
taking damage confirmed to restore nothing, Veyr confirmed clamped at
exactly its configured maximum rather than overshooting, and a light
regression pass re-confirmed the combo and Veyr Step still function
normally. One test-harness-only bug was hit and fixed along the way
(the throwaway test script's `SceneTree.current_scene` was never set,
so the ranged attack's projectile had nowhere to spawn into — not a
game bug, not written to ARCHITECTURE.md since it's specific to
hand-built test scripts, not a general methodology gotcha).

## Vertical Slice — Stage 3 Enhancement (Verticality, Ranged Cross-Pressure, Repeatable Perfect Step)

**Status: implemented, headless-validated end-to-end through the real
engine loop (34/34 checks passing after several genuine bugs found and
fixed along the way), needs manual play-test.**

User asked to "return to vertical-slice development" and proceed with
Stage 3. Stage 3 already existed from an earlier pass (see the entry
above) as a simpler encounter: a flat floor, two melee enemies flanking
the player, and an isolated melee enemy for a Perfect Step opportunity.
The user's new, much more detailed Stage 3 spec asked for verticality
(platforms, diagonal Step opportunities), a ranged enemy for a second
pressure angle, and a Perfect Step opportunity that survives being
missed once. Rather than silently rebuilding the whole encounter against
a spec that assumed it didn't exist yet, this was flagged to the user
directly; they chose to keep the existing encounter and layer in only
the three missing pieces, not a full rework.

### What changed

- `scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.tscn`:
  - `VeyrStepPlatform` - a new raised platform (reusing the existing
    `Shape_Step` resource) positioned above/between the two flanking
    enemies, at a height that's both walkable-under at ground level and
    reachable by a single jump - see "Bugs discovered/fixed" below for
    how tight that margin actually is in this project. Gives the
    encounter real elevation for the first time, inviting (not
    requiring) diagonal/vertical Veyr Step usage: blink up out of a
    pincer, blink back down into it from an advantageous angle.
  - `VeyrEncounterRangedFlanker` - a `RangedEnemy.tscn` instance placed
    between the melee pair and the isolated Perfect Step enemy, close
    enough to the flanking pair's engagement zone to draw the player
    into cross-pressure from a third angle while dealing with the
    pincer, without crowding the existing (already-validated) Perfect
    Step enemy's own clear space.
  - `PerfectStepEnemy` gained a scene-local `HealthComponent` override
    (40 -> 90 max health), same per-instance-override convention already
    used for the Stage 5 difficulty fix. Reused reasoning: at the base
    40 HP, a player who simply fights instead of dodging can kill it in
    a single combo before it even completes one attack cycle, meaning a
    missed first dodge attempt could be the only attempt that ever
    existed. 90 HP guarantees multiple real attack cycles - multiple
    genuine Perfect Step windows - survive ordinary combat pressure.

### How Veyr Step is taught / how Perfect Step is exposed

Unchanged in principle from the original Stage 3 pass (see above): Veyr
Step is introduced through combat, not a traversal gate, and is never
required to progress. What's new is that the encounter now also
teaches directional (not just horizontal) Step usage through its own
geometry, and gives the ranged flanker's presence a reason to duck
behind/above the melee fight rather than just trade hits with it.
Perfect Step's opportunity is the same isolated, low-pressure 1v1 as
before, now guaranteed to offer more than one real swing to time
against.

### Temporary graybox limitations

Still graybox - flat colored polygons, no real art. The new platform
uses the established Veyr-violet color language (matching
`OverlookPlatform`'s existing convention) purely as a readability cue,
not real art.

### Bugs discovered/fixed

All in this test pass, all in the new scene content or the throwaway
test harness - no shared script was touched.

1. **A genuine platform-placement bug, found and fixed.** The first
   placement attempt for `VeyrStepPlatform` had the vertical-clearance
   inequality backwards - it *lowered* the platform to try to give more
   room underneath, which actually moved its solid collision body
   further **down into** the player's own standing collision height,
   physically blocking ground movement through that stretch of floor
   entirely. Root cause once diagnosed: with this project's actual jump
   height (~89px) and player collision height (46px), there is only
   about 43px of slack total to split between "jump margin" and "walk
   clearance" for a 24px-thick platform - tighter than it looks at a
   glance. Fixed by repositioning so the platform's solid region sits
   entirely above the player's standing head height (rise 78px, ~8px of
   walk clearance, ~11px of jump margin) rather than lowering it.
   Verified via a real walked-through-at-full-speed check and several
   directional Veyr Step attempts confirming the player is never placed
   inside the platform's or the floor's own solid geometry (requirement
   #7's exact ask) - see [COMBAT.md](COMBAT.md) for the full validation
   writeup.
2. **A real, pre-existing behavioral discovery, not fixed (out of
   scope) but worth recording.** `EnemyAI`'s detection/attack-range
   checks only ever compare X distance, never Y. Luring the two flanking
   enemies toward one spot and then escaping straight up onto the new
   platform leaves them "locked on" to the player's X position even
   though the player is actually vertically unreachable - they end up
   standing almost on top of each other, still trying to attack a
   target they can't reach, and since `Hitbox` has no same-faction
   exclusion, they can end up damaging each other. Not a Veyr Step bug -
   the step itself always lands safely and the player was never at risk
   in any test that hit this. Not fixed: this is a general trait of the
   shared `EnemyAI`/`Hitbox` architecture, not something scoped to
   Stage 3, and the instruction was explicit about not changing enemy
   architecture without a genuine Stage-3-blocking bug. See
   [COMBAT.md](COMBAT.md) for the full writeup and reasoning.
3. **Two test-harness-only bugs**, both fixed in the throwaway test
   script, neither a game bug: (a) calling `PlayerMovement.physics_update()`
   directly on the live player node fights the identical automatic call
   `PlayerController._physics_process()` already makes from real `Input`
   state every tick - one call's velocity gets partially undone by the
   other's zero-input deceleration each frame. Fixed by driving
   sustained movement through real `Input.action_press()`/`release()`
   instead of a second manual call. (b) The engineered Perfect Step
   positive-case test positioned the player *within* the target enemy's
   attack reach before its windup even finished, so a real (non-dodged)
   hit landed and consumed the `Hitbox`'s one-shot per-activation hit
   record before the engineered dodge ever got a chance to matter. Fixed
   by keeping the player out of reach until after the windup completes.

### Testing performed

Full real-engine-loop validation (`godot --headless`), 34 checks, all
passing after the fixes above: Stage 1/2 sanity (existing enemies
untouched and still functional), platform ground-clearance and all four
directional Veyr Step cases against the new platform (none embed the
player in solid geometry), the widened kill zone, exit continuity into
the still-undeveloped section past Stage 3, the pincer encounter cleared
both with and without Veyr Step (the Step-escape case took ~0 damage;
the no-Step case cleared all three enemies and finished around 80/100
health - both genuinely survivable), Perfect Step's positive case (a
real avoided hit triggers it, restores Veyr, the enemy survives),
negative cases (stepping during an enemy's windup before its hitbox is
even active, and an ordinary reposition far from any enemy, neither
triggers it or restores Veyr), the opportunity repeating for a second
real swing after the first, and the enemy being fully defeatable via
normal combat with zero Perfect Steps ever triggered (confirms it's
genuinely optional). Both `--import` and a 150-frame boot of the
vertical slice are clean with no errors.

**Not yet verified (needs manual play):** whether the flanking-plus-
ranged pressure reads as inviting Veyr Step rather than just harder;
whether the new platform's jump timing feels reliable given how tight
its margins are; and whether a human can land a genuine Perfect Step
against this enemy at a comfortable rate now that it survives more than
one swing.

## Next: awaiting direction

All three original abilities (aerial attacks, ranged Veyr, charged
attack) plus Veyr regeneration and this Stage 3 enhancement pass are
implemented and validated. Per explicit instruction, Stage 4 was not
begun. Open questions: manual playtest feedback across all of the
above, whether the EnemyAI vertical-blind-chase/friendly-fire finding
is worth a future fix, and whatever comes after (documentation pass,
the Stage 5 difficulty finding, or Stage 4 itself once approved).

## Vertical Slice — Stage 4 Enhancement (Avaris Reveal Composition)

**Status: implemented, headless- and real-GPU-validated (15/15 checks
passing), composition visually reviewed via real screenshots (not just
"can't verify headless" as originally flagged), needs manual play-test
for in-motion feel.**

User asked to enhance Stage 4 "the same way" as Stage 3, then gave a
detailed brief once asked to clarify what that meant for a stage
explicitly designed as a non-combat breather. Core constraint honored
throughout: no enemies, no combat, no new mechanics, no new canonical
lore, no increase to the stage's actual footprint/duration - the goal
was making the *existing* graybox space read as enormous, alien, and
only a fragment of a larger city, not building more level.

### What changed

- `scripts/systems/AvarisReveal.gd` (new) - a small one-shot script
  following the exact same `PlayerTrigger`-driven pattern already
  established by `RhaekTeaser.gd`/`MemorySequence.gd`: on trigger, eases
  the player's `Camera2D.zoom` out briefly, holds, eases back to normal.
  Deliberately tweens `zoom` only - `CameraController.gd` (look-ahead/
  offset) is untouched and can't conflict with it, and this is not a new
  cinematic-camera framework, just the same small-tween convention this
  project already uses for its other narrative beats.
- `scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.tscn`:
  - `RevealTrigger` + `AvarisReveal` node, firing right as the player
    steps onto `RevealLedge`.
  - `MegastructureLeft`/`Right` - the "visual landmark" (a single
    dominant, unnamed distant structure, split into two suspended
    halves with a gap between them, implying it's held apart rather
    than physically supported - visible from both the primary route and
    the optional overlook, deliberately never explained or reachable).
  - `FarSpireA`/`B`/`C` - a smaller, hazier skyline cluster extending
    the reveal further into the distance than the original four spires
    alone.
  - `NearRuinLeft`/`Right` - large asymmetric near-foreground fragments
    framing the reveal moment and making `OverlookPlatform` read as a
    broken shelf of a bigger structure rather than a floating gameplay
    platform.
  - `LowerRuinA`/`B`/`C` - background ruin silhouettes behind
    `ExplorationStep1`/`2`/`Floor`, added after a screenshot showed the
    *descent* half of the stage still read as bare floating platforms
    in flat grey void even after the reveal itself was dressed - see
    "Bugs/issues found" below.
  - `DormantConduitA`/`B` (dim, dead) + `VeyrRemnant` (one small violet-
    glowing accent, reusing the project's established Veyr-glow color
    language) - the "Veyr was integrated into the city, but the
    civilization is dead" motif from the brief, contrast via one live
    accent against mostly-inert infrastructure.
  - All of the above are plain `Polygon2D` nodes with no collision
    shape and no physics body - confirmed by test, not just by
    intention (see Testing below).

### How scale is communicated

Layered depth via z-index + color/alpha only (no parallax-scroll
system - out of scope, would be overbuilding for a graybox pass):
near ruins (z -1, opaque, drawn in front) → the original mid-distance
spires (z -1, drawn behind near) → the new far cluster (z -2, smaller,
lower-alpha) → the megastructure landmark (z -3, furthest back). The
landmark is tall enough (~950px) to exceed the camera's own pan limit
(`limit_top = -400`) - even at maximum camera pan-up its top stays
above the frame, so it always reads as "continuing beyond what you can
see," per the brief's exact ask.

### Architectural shapes / Veyr infrastructure

Kept to the brief's explicit rules: no Arabian/Islamic/desert/Egyptian/
medieval/cyberpunk/generic-sci-fi read. Every new shape is an angular,
asymmetric, jagged-edged polygon (no organic curves, no domes/arches).
The megastructure's two-halves-with-a-gap silhouette is the one
"physically impossible by human engineering standards" element, per the
brief's own suggested shape language - left deliberately unexplained.
Veyr infrastructure is mostly dim/grey (dead) with exactly one small
violet accent for contrast, not "everything glows."

### Optional overlook

Unchanged mechanically (still a plain jump-up dead-end, still no
reward beyond the view, still lands back on the primary stairs). Its
composition is now visibly richer than the main route's lower vantage -
confirmed via screenshot, not just claimed: from `OverlookPlatform` the
violet-tinted `SpireC` and the pale, hazy megastructure behind it are
both clearly visible and read as more distant/atmospheric than the
darker near-ruin silhouettes in front of them.

### Camera behavior

One-shot, ~3.4s total (ease out 1.1s, hold 1.2s, ease in 1.1s), zoom
1.0 → 0.85 → 1.0. Fires once via the existing one-shot `PlayerTrigger`
convention. No control taken from the player beyond the brief zoom
change - movement and input are never disabled during it.

### Bugs/issues found

1. **A real composition mistake, found via screenshot and fixed.** The
   megastructure's first color attempt (`Color(0.38, 0.42, 0.52, 0.35)`)
   was *darker* than the mid-distance spires in front of it, so despite
   being meant as the haziest, most-distant element, it rendered as the
   most solid-looking shape in frame - low alpha over a dark background
   doesn't read as "hazy," it just looks dark and half-hidden. Fixed by
   using a *lighter* color (`Color(0.62, 0.65, 0.74, 0.3)`) - atmospheric
   haze needs to be pale against a dark background, not merely
   transparent. This is the same category of lesson §11's bloom-color
   finding already recorded in ARCHITECTURE.md (a Color number doesn't
   look like what the math suggests - a screenshot has to confirm it).
2. **A real composition gap, found via screenshot and fixed.** The
   initial pass only dressed the backdrop *above* the ground line (the
   reveal itself). The primary route's actual descent
   (`ExplorationStep1`/`2`/`Floor`) sits *below* that line and had no
   backdrop at all - screenshots showed it still reading as bare
   floating platforms in empty grey space, missing the brief's "move
   THROUGH the architecture" ask for exactly the part of the route where
   the player spends the most time. Fixed by adding the three
   `LowerRuin*` fragments.
3. **A pre-existing, unrelated collision quirk, found, not fixed.**
   `OverlookPlatform` (built in the original Stage 4 pass, untouched by
   this one) has the same kind of ground-level walk-under overlap this
   project already fixed once for Stage 3's new platform - its collision
   bottom edge sits 14px into the player's standing head-height range.
   It was never actually a problem because the real path never asks the
   player to walk under it in a straight line (`RevealLedge` ends and
   drops to `ExplorationStep1` before reaching that x-range) - the
   platform was only ever meant to be reached by jumping up to it,
   already validated as working. Not fixed: it's outside this pass's
   scope (an already-validated platform, not new content), doesn't
   block the documented path, and the fix pattern is already recorded
   from Stage 3 if it's ever worth revisiting.

### Testing performed

Two passes: a `--headless` boot/parse check (clean), and a **real-GPU,
non-headless** scripted run (per the technique in ARCHITECTURE.md §9/
§11 - a `SceneTree` script run without `--headless`, fully scripted and
`quit()`-terminated, not a manual session) covering 15 checks: Stage 3
still functional, the reveal trigger fires exactly once on reaching
`RevealLedge`, the camera zoom genuinely eases out then returns to
exactly 1.0, every new backdrop node confirmed to be a plain `Polygon2D`
with no physics body, the real intended path (walk off the ledge, drop
onto the stairs, continue down) reaches past the new backdrop's
footprint alive and unstuck, the overlook is reachable, the widened
kill zone still catches a fall, and the Stage 5 entrance area stays
reachable and grounded. Three screenshots were captured (the reveal
moment, the main route mid-descent, the optional overlook) and visually
reviewed - this is what caught both real issues in "Bugs/issues found"
above, fixed, then re-verified with fresh screenshots before reporting.

**Not yet verified (needs manual play):** whether the composition reads
as intended *in motion* rather than in static screenshots (parallax-
free 2D backgrounds can read differently while moving vs. paused);
whether the reveal's camera zoom timing lands well; whether the
`VeyrRemnant` accent is noticeable enough to register as "a small
remnant of Veyr activity" rather than blending into `SpireC`'s own
existing violet tint - it reads as intended in the overlook screenshot
but is subtle; and the always-present "does this actually feel
enormous and alien" judgment a screenshot alone can't fully answer.

## Next: awaiting direction

## Vertical Slice — Stage 5 Enhancement (Ranged Cover Encounter + Mini-Boss Arena)

**Status: implemented, headless-validated (33/33 functional checks
passing after several genuine bugs found and fixed, plus a full real-
Input Stage 4→6 traversal reaching the Stage 6 boundary at full health),
visually reviewed via real screenshots, needs manual play-test for feel.**

User asked to enhance the existing Stage 5 (ranged encounter + mini-
boss arena) the same incremental way as Stages 3 and 4 - preserve
working content, no rebuild, no new systems, no Stage 6 changes, no
turning the generic mini-boss into a named canon character.

### What changed

- `scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.tscn`:
  - `CoverBlock` - a real, jumpable (70px, well under the ~89px max
    jump height) wall between the approach and `RangedSentry`, tall
    enough to fully block its projectile's fixed flight height. Creates
    an actual choice: shelter behind it (safe, but the sentry keeps
    firing while you wait), or commit to closing distance / jumping
    past it (exposed, faster).
  - `SentryPerch` - a small optional platform for the *player* to use
    for a different angle, positioned between the cover and the sentry.
    Originally this was meant to elevate the sentry itself ("elevated
    ranged enemy" was one of the brief's suggested options) - see "Bugs
    discovered/fixed" below for why that broke the encounter entirely
    and was reverted.
  - `ArenaOmen` - a large, very dark background silhouette right at the
    Stage 5→boss-arena transition, foreshadowing "something bigger is
    ahead" before the boss is actually visible, per the brief's pacing
    ask. Purely visual, no collision.
  - `RuinPillarA`/`B` + `ArenaSidePlatform` - modest arena dressing
    (background scale silhouettes, one small optional side platform
    kept well outside the boss's own `detection_range` so it can't
    interfere with fight readability) - avoiding the "completely empty
    rectangle" the brief explicitly warned against, without cluttering
    the actual fight space.
  - No changes to `MiniBoss`'s tuning, `BossAI.gd`, `StabilityComponent`,
    or any shared script - the brief was explicit about reusing the
    existing boss architecture as-is, and testing found no evidence it
    needed changing (see below).

### Ranged encounter design

Multiple viable approaches confirmed via test, none mandatory: fighting
from behind cover (sentry can't land a hit), closing distance and
meleeing it down, sniping it with Ranged Veyr from beyond the cover,
and jumping past the cover entirely. Veyr Step remains reliable near
the new geometry (confirmed not to place the player inside `CoverBlock`
or `SentryPerch`'s collision from either direction).

### Cover/verticality design

`CoverBlock` fully blocks the sentry's projectile (confirmed: a player
positioned behind it while the sentry is actively engaged takes zero
damage) while staying jumpable. `SentryPerch` is the "modest vertical
variation" - optional, no mechanical requirement to use it.

### Mini-boss arena changes

Background dressing + one optional side platform only; the boss's own
melee/detection radius area was kept clear, per the brief's readability
priority.

### Phase 1 behavior

Unchanged, confirmed still functions: melee attack lands on a close
player, ranged attack lands on a player beyond melee range but within
detection, both via the real Hitbox/Projectile paths (not mocked).

### Phase 2 behavior

Unchanged, confirmed via the real attack-finish code path (not
recomputed by the test): a completed phase-2 melee attack cycle sets a
cooldown of ~0.258s vs. phase 1's base 0.5s (the existing
`phase2_cooldown_multiplier = 0.65` applied for real), and the existing
color-shift to `phase2_color` fires correctly once the boss's own
transient hit-flash/attacking tint clears.

### Stagger/Charged Attack interaction

This is the one interaction the brief asked for particular attention
on, and it tests well: the boss's `stagger_duration` is 2.0s (already
longer than the 1.5s default, a pre-existing per-instance tune). A
full-charge Charged Attack takes ~1.15s (1.0s charge + 0.15s active),
leaving a real ~0.85s margin - confirmed by landing an actual full
`charged_max_damage` (38.0) hit on a staggered boss with time to spare,
not a rushed or impossible window. Stagger is not trivially spammable
into a stunlock: `StabilityComponent.regen_delay`/`recovery_rate` are
unchanged and untouched by this pass.

### Perfect Step behavior

Confirmed via the same engineered-real-overlap technique used for
Stage 3: a real avoided hit against the boss's own melee `Hitbox`
correctly triggers Perfect Step and restores Veyr. Not artificially
widened - the boss's existing melee timing already provides a real
window, so no tuning was needed here (matching the brief's "only widen
it if current tuning makes it practically impossible" instruction).

### Veyr economy observations

Reported honestly, not tuned, per instruction. A scripted worst-case
fight (basic combo only, no Heavy/Charged/Aerial/Ranged Veyr, no Veyr
Step, real chase movement when the boss repositions) defeated the boss
in ~1050 real physics frames (~17.5s) at 13/100 player health remaining
- a genuinely close fight using none of the kit's advanced tools, which
matches the brief's "harder than ordinary, not brutally difficult"
target reasonably well. **Limitation of this specific observation**:
Veyr stayed pinned at its starting maximum (100) the entire fight in
every sample, because this conservative script never actually *spends*
Veyr (no Ranged Veyr casts, no optional Veyr-cost abilities enabled) -
it only ever gains from landed hits, so a flat reading here proves
regeneration keeps up with zero demand, not that the full spend/regen
loop is sustainable under real mixed play. A manual session that
actually uses Ranged Veyr and Veyr Step during the fight is needed for
a real read on that loop - not attempted here per "we will balance
later."

### Boss HUD / death behavior

Confirmed the boss bar appears once the player is within `vicinity_range`
and tracks health via the real `health_changed` signal - both pre-
existing, unmodified, still working correctly at the new arena geometry.
Death handling untouched (no loot/upgrade/dialogue added, per
instruction).

### Full traversal/playtest results

A real-Input-driven run (held movement + periodic jump toggling +
basic-swing attacks whenever off cooldown, no isolated method calls)
starting from the end of Stage 4 reached the Stage 6 memory-trigger
boundary in 679 physics frames (~11.3s) at full health, confirming the
whole path - cover, perch, sentry, transition, arena, side platform,
into the boss and out the far side - is traversable end-to-end with no
softlocks, on top of the isolated mechanic checks above.

### Bugs discovered/fixed

1. **A real, encounter-breaking design bug, found and fixed.** The
   first attempt elevated `RangedSentry` onto a 40px perch (the
   brief's own suggested "elevated ranged enemy" option). This silently
   broke the sentry's ability to hit a grounded player **at any
   distance**: `Projectile` only ever flies perfectly horizontally at a
   fixed height matching its firer's own muzzle position (no vertical
   aim at all, a deliberate existing simplification - see
   [COMBAT.md](COMBAT.md) §19, new). Once the shooter's height no
   longer matched a standing player's collision range, every shot sailed
   over their head regardless of range. Caught immediately by a real-
   engine test (the "sentry can hit an exposed player" check started
   failing). Fixed by reverting the sentry to ground level and moving
   the "modest verticality" to a separate, player-only platform instead.
2. Several test-authoring mistakes in the throwaway script, not game
   bugs, all fixed: firing the "Ranged Veyr vs. sentry" test shot from a
   position that put the *player's own* shot behind the very cover being
   tested (correctly blocked, but testing the wrong thing); a GDScript
   closure gotcha (a lambda mutating a captured `bool` doesn't propagate
   back to the outer scope - fixed with a 1-element `Array` instead,
   the reference-type workaround); checking the boss's post-phase-2
   visual color while the player was still standing in its melee range
   from a previous test, so the real AI had already started a fresh
   attack and the check caught the shared "currently attacking" tint
   instead of the settled base color; and an initial "fight the boss"
   test that only ever stood still and swung, never chasing, which
   isn't a fair "normal play" baseline against a boss that can reposition
   for its ranged attack the way Stage 3's largely-stationary flankers
   couldn't - fixed by adding real chase movement to the test.
3. **A new testing-methodology gotcha, recorded in
   [ARCHITECTURE.md](ARCHITECTURE.md) §9**: reusing the real-GPU
   screenshot technique from the Stage 4 pass, a large teleport-based
   camera jump didn't actually move the camera in time for the
   screenshot, due to `Camera2D` smoothing - fixed with
   `reset_smoothing()`.

### Difficulty observations

The scripted worst-case fight (see Veyr economy above) is close but
winnable with zero advanced-tool usage, ending at 13/100 health. A real
player using Heavy/Charged finishers, Ranged Veyr chip damage, actual
reactive dodging, and Veyr Step would very plausibly do meaningfully
better - this script deliberately proves the floor, not the ceiling,
consistent with how every other combat validation in this project has
been framed. Combined with the real-Input full traversal finishing at
**full health** in one run, the encounter reads as within the brief's
"harder than ordinary, not brutally difficult, testing combat quality
not difficulty prestige" target, but this is still not a substitute for
an actual human attempting it fresh.

### Anything requiring approval

Nothing blocking. Same standing open item as before: the EnemyAI
vertical-blind-spot/friendly-fire finding from the Stage 3 pass -
documented technical debt, explicitly not urgent per the user.

## Next: awaiting direction

Stages 3, 4, and 5 have all now had a focused enhancement pass on top
of the original 7-stage build; Stage 6 has not, and was not begun or
modified per explicit instruction. Open questions: manual playtest
feedback across everything above (combat kit, Veyr regen, and now all
three enhanced stages), whether the EnemyAI vertical-blind-chase finding
or the Veyr economy's spend-side sustainability are worth a future
pass, and whether to continue the same enhancement approach into
Stage 6+ or move to something else.

## Vertical Slice — Stage 6 Enhancement (Memory Sequence)

**Status: implemented, headless-validated (22/22 checks passing on the
first full functional run, after two real issues found and fixed during
visual review), visually confirmed via real screenshots showing the
transformation actually reads, needs manual play-test for emotional
impact.**

User asked to enhance the existing Stage 6 memory beat - a brief,
fragmented glimpse of Avaris when it was alive, not a lore dump, not a
cutscene, no dialogue, no naming which (if any) distant silhouette is a
canon character.

### Existing Stage 6 behavior before enhancement

`MemorySequence.gd` already staged PRESENT -> PAST -> PRESENT correctly
in principle: a one-shot `PlayerTrigger` fires `play()`, which fades a
whole-scene `CanvasModulate` tint and reveals a `MemoryOnly` container
(bridges + lit windows) for a hold, then fades back. It never restricted
player control. Total original duration was already a reasonable 6.4s
(1.2s fade + 4.0s hold + 1.2s fade), not the 30-60s the brief worried
about.

**But a real screenshot (not just reading the code) found the actual
problem**: the `MemoryOnly` content - the only visible evidence of "this
place was alive" - was positioned near the Stage 4 reveal (x≈5150-6000),
while the trigger that plays it sits at x=8500, deep in Stage 5/6
territory. From the player's real position when the memory plays, that
content is thousands of pixels off-screen - **completely invisible**.
The tint shift alone was the only thing a player would ever actually
see. This is exactly the "existing implementation fundamentally
prevents the intended sequence" case the brief's "don't rebuild unless"
clause anticipated, though the fix needed was additive (new content
positioned where the player actually is), not a rebuild.

### Files changed

- `scripts/systems/MemorySequence.gd`: added `activation_paths` (existing
  nearby world geometry that temporarily brightens to `activation_color`
  and reverts - see below), `drift_paths` (a handful of `MemoryOnly`
  children that drift back and forth during the hold, then reset to
  their authored position), and a `_destabilize()` step (a brief alpha
  flicker) inserted between the hold and the final fade-out. The core
  PRESENT->PAST->PRESENT structure and the "never touches player
  control" behavior are unchanged.
- `scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.tscn`:
  - `MemorySequence`'s `activation_paths` now points at Stage 5's
    `RuinPillarA`/`RuinPillarB` - existing nearby ruin geometry the
    player can already see, reused rather than duplicated, satisfying
    "reuse existing Stage 4/Avaris silhouettes where practical" with
    geometry that's actually in view instead of the far-away original.
  - `LivingConduit` + `ConduitLight` - one new bright, active Veyr
    conduit near the trigger (the "previously dormant shapes gaining a
    controlled Veyr accent" beat, done with new geometry since nothing
    dormant already existed at this specific spot).
  - `DistantFigureA`/`B`/`C` - three small, plain dark silhouette
    shapes standing together atop the (now-lit) `RuinPillarB`, visible
    only during the memory. Abstract shapes only - no anatomy, no named
    character implied either way, per the brief's explicit rule against
    suggesting Rhaek/Seyra/Vael/Nayra/Auren.
  - `DriftFormA`/`B`/`C` - three small abstract shapes that drift
    slowly during the hold via the new `drift_paths` mechanism, implying
    quiet distant activity without depicting any vehicle/technology.
  - No changes to `MemoryFloor`, `MemoryTrigger`'s position, or anything
    in Stage 7 (`RhaekTrigger`, `RhaekTeaser`, `EndFloor`, `EndWall`,
    etc.) - confirmed untouched and still reachable, see Testing below.

### Memory trigger behavior

Unchanged mechanically (still a one-shot `PlayerTrigger`, still fires
only on real body-zone entry). Confirmed the boss dying does **not**
itself trigger anything - the player still has to walk the real distance
from the arena to the trigger, which is what actually provides "a
little room to breathe" rather than an instant flashback; no artificial
delay was added inside the script itself because the level geometry
already provides it.

### Present → living Avaris transformation

Confirmed via direct property checks *and* real screenshots (not
property inspection alone, per instruction): the previously dark,
dormant `RuinPillarB` visibly brightens to a pale lit violet during the
memory and reverts to its exact original dark color afterward - a
legible "this specific ruin you're standing next to was once alive"
moment, not just a global tint shift.

### How civilization/activity is implied

The `LivingConduit` (a bright, glowing structural line) and three
`DriftFormA/B/C` shapes (small, simple, silently drifting) - both
confirmed genuinely moving during the hold via a real screenshot taken
twice a second apart, showing visible displacement, not just present in
the scene tree. No vehicles, no technology names, no anatomy - abstract
geometry only, per instruction.

### Distant figure implementation

Implemented: three small, flat, dark silhouette shapes standing
together atop `RuinPillarB`, visible only while `MemoryOnly` is shown.
No new script or system was needed - they're ordinary `MemoryOnly`
children, getting the existing visibility toggle for free. Deliberately
ambiguous: no face, no name, no indication of identity, and nothing in
code or naming implies any of them is a specific canon character.

### Memory destabilization

New `_destabilize()` step: ~0.9s of rapid alpha flicker (`MemoryOnly`
oscillating between ~20% and 100% opacity, tweened, not a shader) runs
after the hold and before the final fade-out - confirmed via test that
the alpha genuinely dips mid-sequence, then confirmed restored to fully
opaque once the memory ends (so a later replay-adjacent state, if this
sequence is ever re-entered some other way, wouldn't start from a
half-flickered state).

### Sequence duration

~8.3s total (1.2s fade-in + 5.0s hold + 0.9s destabilize + 1.2s
fade-out) - within the brief's 8-15s target, up from the original 6.4s
(the hold was extended from 4.0s to 5.0s specifically to give the newly
visible activity/figures a moment to actually register, and the
destabilize beat is new time on top of that).

### Return-to-player-control behavior

Player control was never actually restricted by this sequence in either
version - confirmed via a real held-`Input` movement test both *during*
the memory (the player visibly moved) and *after* it ends. All memory-
only visuals (activated ruin colors, `MemoryOnly` visibility, drift
shape positions, alpha) confirmed restored to their exact pre-memory
state once it ends - no leftover collision (none of the new nodes have
any - confirmed via a real walk-through test earlier in Stage 5/6's
combined geometry), no leftover tint, no leftover displaced shapes.

### Visual validation performed

Two real screenshots (per ARCHITECTURE.md §9/§11's GPU-rendering
technique, not property inspection alone) - immediately caught two real
issues before they shipped:

1. Confirmed the "before" state showed nothing unusual - until the
   first attempt revealed the distant figures were visible in the
   *present* screenshot too. Root cause: turned out to be a test-
   authoring mistake (teleporting the player directly onto
   `MemoryTrigger`'s own collision zone caused the real trigger to fire
   naturally before the test's own explicit trigger call), not a game
   bug - confirmed by re-testing from a position outside the trigger
   zone instead, which showed the correct hidden state.
2. The first placement of `LivingConduit` and the three `DriftForm`
   shapes put them far too high (`y` around -150 to -340) to actually
   be inside the camera's visible range from the player's real position
   at the trigger - the same category of "verify the real visible
   range, don't assume coordinates" lesson from the Stage 4 pass.
   Confirmed empirically (the distant figures, positioned near the
   visible edge already, were the only new content showing up in the
   screenshot) and fixed by repositioning everything to roughly
   `y = 100` to `320`, which a follow-up screenshot confirmed reads
   clearly.

### Bugs discovered/fixed

Both items above. Neither was a shared-script/architecture bug - one
was a test-authoring mistake, the other was scene content positioned
outside the realistic camera range, same class of issue as Stage 4's
platform-clearance and Stage 5's elevated-sentry findings this session
keeps surfacing: **coordinate math needs a real screenshot to confirm,
not just be trusted.**

### Performance observations

7 new nodes total (`LivingConduit`, `ConduitLight`, 3 distant figures,
3 drift forms - one of which, `ConduitLight`, is a `PointLight2D`, the
only non-`Polygon2D` addition), plus 2 new small `Array[NodePath]`
exports on the existing `MemorySequence` script. All memory-only content
was already being hidden/shown via the pre-existing `MemoryOnly.visible`
toggle, so the change adds no new visibility-management code paths.
Nothing about scene boot time changed.

### Anything requiring approval

Nothing blocking. Documented, not implemented, per instruction: the
future audio contrast intent - present state carries sparse ambience,
the memory should expand toward fuller music/ambience conveying an
alive civilization, and the return to present should collapse the sound
back toward emptiness alongside the visual fade. No audio assets were
sourced or generated this pass.

## Next: awaiting direction

## Vertical Slice — Stage 7 Enhancement (Rhaek Teaser + End of Vertical Slice)

**Status: implemented, headless-validated (26/26 checks passing after a
handful of test-timing fixes, no real code bugs beyond one genuine
visibility issue found via screenshot), visually confirmed via real
screenshots, full Stage 4->End real-Input walkthrough completes at full
health. This is the final stage of the graybox vertical slice - no
Stage 8 or further gameplay content was begun.**

User asked to enhance the existing Rhaek Teaser + end-of-slice beat:
mystery and recognition, not a boss reveal - Rhaek appears at a
distance, is seen but not fought, and vanishes, closing the slice with
a fade and a developer-facing "Vertical Slice Complete" marker.

### Existing Stage 7 behavior before enhancement

`RhaekTeaser.gd` already did almost everything right in principle: a
one-shot trigger stages presence -> attention (turn + brief color
pulse) -> departure (burst/dissolve), no dialogue, no health, no
Hitbox, no AI - purely a `Polygon2D` + light + particles. Total original
timing (~4.5s) was already within the brief's 4-8s target.

**But a real screenshot (per the brief's explicit "do not assume
coordinates mean something is visible" instruction) found Rhaek's
silhouette was not actually visible from the player's real position at
the trigger** - his position (chosen to read as "elevated, unreachable")
put him well above the camera's normal framing, the same category of
issue Stages 4/5/6 each independently ran into this session. There was
also no "end of vertical slice" fade/marker at all - nothing existed to
close the slice out, and no quiet-interval guarantee between Stage 6's
memory (which never restricts player movement) finishing and Rhaek's
trigger firing, meaning a fast player could physically reach Rhaek's
trigger while the memory was still visually playing.

### Files changed

- `scripts/systems/MemorySequence.gd`: added a `finished` signal and an
  `is_finished` flag, emitted/set once the full PRESENT->PAST->PRESENT
  cycle actually completes (not when it starts).
- `scripts/systems/RhaekTeaser.gd`: added `wait_for_path` (an optional
  gate - `play()` now waits for another sequence's `finished` signal,
  skipped if already finished, before actually starting), an inlined
  camera zoom-out/hold/return (same "ease out, hold, ease back" idea as
  `AvarisReveal.gd`, written directly into this sequence rather than a
  second reused node, so it stays synchronized with Rhaek's own timing
  instead of running on an independent schedule), and `_close_slice()` -
  a short stillness, then a fade to black and a developer-facing end
  marker. Core presence/attention/departure logic and "no combat, no
  new sequencing framework" are unchanged.
- `scenes/regions/avaris/vertical_slice/AvarisVerticalSlice.tscn`:
  wired `RhaekTeaser`'s new exports (`wait_for_path` -> `MemorySequence`,
  `camera_path` -> the player's `Camera2D`, `end_fade_path`/
  `end_label_path` -> two new nodes); added `EndLayer` (a `CanvasLayer`
  above the HUD, matching the existing `VignetteLayer`/`HUD` layering
  convention) containing `EndFade` (a full-rect black `ColorRect`,
  alpha 0 initially) and `EndLabel` (a centered `Label`, hidden
  initially, default theme - no font/text infrastructure existed
  anywhere in the project before this, confirmed by search). No changes
  to `RhaekTeaser`'s own silhouette/position/color, `EndFloor`,
  `EndWall`, `EndSpire`, `ClosingSpire`, or `ClosingConduit`.

### Transition from Stage 6

Fixed the real race condition found above: `RhaekTeaser.play()` now
waits for `MemorySequence.finished` before actually starting its own
sequence, confirmed via a real test where a player who holds movement
continuously reaches Rhaek's trigger zone (frame ~180) **well before**
the memory visually finishes (frame ~539) - Rhaek's silhouette
measurably stays at zero alpha the whole time until the memory actually
resolves, then starts fading in. No artificial delay was added on top
of that - the gate itself is the fix.

### Rhaek placement/composition

Position unchanged (still elevated, still separated from the player by
open space, still unreachable - no collision was ever added to him).
What changed is that he's now actually visible: the camera eases out to
`zoom = 0.55` for the duration of his presence (not just a brief peek -
it holds through attention and departure, since he needs to stay
visible for the whole beat, not just the reveal moment), confirmed via
screenshot to produce exactly the "ZAYR — [space] — RHAEK" composition
the brief asked for, and returns to `zoom = 1.0` once he's gone.

### Recognition sequence

Unchanged mechanically - no dialogue was added or was ever present.
Confirmed via test that the attention beat's color pulse genuinely
fires (silhouette measurably approaches `attention_color` mid-sequence,
not just scheduled to).

### Rhaek disappearance

Unchanged - the existing burst/particle dissolve, confirmed via test to
actually fire (not just present in the tree) and to fully resolve
(silhouette back to zero alpha, burst hidden again) before the camera
eases back.

### Camera behavior

Inlined into `RhaekTeaser.gd` rather than a second `AvarisReveal`
instance specifically so it can hold for the entire presence-through-
departure span and only unwind afterward - confirmed via test that zoom
returns to exactly `1.0`, not left offset.

### Sequence timing

Rhaek's own beat is unchanged (~4.5s, within the 4-8s target). New on
top of that: `end_stillness_duration` (1.5s) before the fade begins,
`end_fade_duration` (1.2s) for the fade itself - both within the
brief's "1-2 seconds of stillness, then fade" ask.

### End-of-slice behavior

New: `EndLayer`'s black `ColorRect` fades in, then a plain
"Vertical Slice Complete" `Label` becomes visible - confirmed via
screenshot and via test that both actually happen once the sequence
completes. No credits, no title screen, no CTA - exactly what was asked
for.

### Visual validation performed

Real GPU screenshots (per ARCHITECTURE.md §9/§11's technique) at every
major beat - presence (confirmed the ZAYR/space/RHAEK composition
genuinely reads), departure, the fade, and the final label. This is
what caught the one real issue (Rhaek's original position being outside
normal camera framing) before it shipped, exactly as the brief
anticipated based on the last three stages' pattern.

### Full-slice regression results

A real-Input walkthrough (movement + periodic jump + attack-when-
possible, the same technique used for the Stage 5 pass) starting from
Stage 4's beginning and running uninterrupted through Stage 5's ranged
encounter and mini-boss, Stage 6's memory, and all of Stage 7, reached
the "Vertical Slice Complete" label at **full health** in ~32.3s of
simulated play. Stage 1-3's core enemy nodes were confirmed still
present and unmodified (a structural spot-check, not a full re-walk -
each was already dedicated-tested in its own pass this session, and
this pass touched nothing in that code). No issues found in any earlier
stage during this check.

### Bugs discovered/fixed

One real, pre-existing bug (Rhaek's silhouette not actually visible
from the real camera position, fixed with the inlined zoom) and one
real, newly-introduced-by-this-pass race condition (a fast player could
reach Rhaek's trigger before Stage 6's memory finished playing, fixed
with the `wait_for_path` gate) - both found before being reported as
done, via real screenshots and real-Input tests respectively, not
assumed from reading the code. Several test-timing bugs in the
throwaway validation script itself (chained fixed-duration waits
drifting out of sync with the sequence's actual internal timing, and an
early version of the full-walkthrough test holding movement into
`EndWall` for several seconds after reaching the end, which eventually
let the player clip past it - fixed by releasing movement once inside
the Rhaek trigger's zone, matching how a real player would actually
behave) - none of these were game bugs.

### Anything requiring approval

Nothing blocking. This completes the planned enhancement pass across
Stages 3 through 7. Same standing open items as before, none urgent:
the EnemyAI vertical-blind-chase finding (Stage 3) and the Veyr
economy's spend-side sustainability under real mixed play (Stage 5).

## Milestone: Graybox Lock + Art Direction Phase

Stages 3 through 7 have each now had a focused enhancement pass on top
of the original 7-stage build. Per explicit instruction, no Stage 8 or
further gameplay content was begun - the vertical-slice enhancement
pass ends there, and the project entered **GRAYBOX LOCK**: no new
abilities/enemies/bosses/systems/stages/progression/lore/level content
unless requested after manual playtesting identifies a genuine need.

Documentation produced during this phase (all planning-only, no assets
sourced, no scenes/gameplay code touched at the time): `docs/ASSET_AUDIT.md`
(full placeholder-asset technical audit), `docs/ART_BIBLE.md` v0.1 (25-section
visual-direction document), `docs/ZAYR_ASSET_IMPLEMENTATION.md` (technical
implementation plan for Zayr's production visual architecture). See those
files for full detail.

## Milestone: Zayr Gameplay Asset v0.1 — Phase A (Static Visual Integration)

**Status: architecture implemented and validated. ARCHITECTURE READY —
ART INPUT REQUIRED.** Zayr's placeholder visual is no longer a bare
debug rectangle - it's now a dedicated `VisualRoot` architecture ready
to receive production art, but no production art exists in the repo
yet, so Zayr is still visually a graybox shape. See
[ZAYR_ASSET_IMPLEMENTATION.md](ZAYR_ASSET_IMPLEMENTATION.md)'s "Phase A"
section for the full implementation log - this entry summarizes it.

### What changed

`scenes/player/Player.tscn`: the old `Visual` `Polygon2D` (a flat 28x46
rectangle, tinted per gameplay state) is now `DebugVisual` - same node,
same behavior, hidden by default. In its place, a new `VisualRoot`
subtree carries `CharacterRig` (containing a static tapered-humanoid
placeholder shape, 72px tall, foot-aligned to the same ground-contact
point the 28x46 collision box already uses) plus five empty sibling
layers (`WeaponManifestation`, `JinnFireLayer`, `VeyrLayer`,
`AbilityVFX`, `DamageVFX`) reserved for later phases. `PlayerController.gd`
gained a `show_debug_visual` export (default off) to switch between the
two without ever showing both at once; `PlayerVeyrStep.gd`'s
hide-during-step logic now targets `VisualRoot` instead of the old
`Visual` node. No collision, hitbox, timing, or other gameplay value
changed - see the implementation log for the full diff summary.

### Testing performed

Headless regression (scene boot, hierarchy shape, collision/hitbox
values, facing mirroring, movement, Veyr Step hide/show + invulnerability,
hurt/death/respawn) - all passed on first run. Real-GPU, real-camera
screenshots at six representative gameplay situations (awakening,
traversal, melee combat, ranged encounter, Avaris reveal, mini-boss
arena) per the standing visual-validation rule - all six confirm clean
ground contact and readable silhouette; see the implementation log for
the one real finding that came out of this (Zayr's new placeholder now
renders taller than the still-unchanged mini-boss placeholder - flagged,
not fixed, this pass).

### Bugs discovered/fixed

None in the gameplay/project code. Two issues in this pass's own
throwaway test tooling (a `get_root()` typo in the screenshot script,
and one screenshot position that landed in a level gap and tripped the
scene's existing `KillZone`) - both were test-methodology mistakes,
fixed by correcting the script/target position, not project bugs.

### Anything requiring approval

**Zayr's placeholder height (72px) vs. enemy/mini-boss scale.** Before
this pass, Zayr and the regular enemy placeholder were both 46px tall,
and the mini-boss (69px) read as the largest of the three, matching
ART_BIBLE.md §14's "substantially larger silhouette" intent for the
mini-boss. Enemy/mini-boss visuals were out of scope for this pass and
are unchanged - so now, at 72px, Zayr reads taller than the mini-boss.
This needs a decision: keep 72px and plan to also revisit enemy/boss
placeholder scale relatively soon, or move Zayr's target toward the
lower end of the approved 60-85px range (e.g. ~62px) to preserve the
mini-boss's current relative dominance until its own art pass happens.
Not resolved here.

No other approval-blocking items. Per explicit instruction, Phase B
(rigging), animation, enemy art, and environment art were not started.

## Milestone: Zayr Gameplay Asset v0.1 — Phase B (blocked)

**Status: BLOCKED AT THE ART GATE.** Phase B ("Rig-Ready Asset
Preparation and Static Assembly") was requested on the premise that
Zayr's separated production art (13 transparent PNGs: head, hair,
torso, pelvis, upper_arm, forearm, hand, thigh, shin, foot, cloth_front,
cloth_rear, shoulder_material) was ready. A full search confirmed
`assets/characters/zayr/` doesn't exist (only `.gitkeep` under
`assets/characters/`), and no image file of any kind exists anywhere in
the repo or its parent folder except Godot's default `icon.svg`. Per
this phase's own instruction ("if clean individual source assets are
missing, report that clearly and STOP before rigging"), no static
assembly was performed - `VisualRoot/CharacterRig` still contains only
Phase A's `BodyPlaceholder`, untouched.

What *was* delivered this pass (pure specification, doesn't require art
in hand): a pixel-space pivot convention for all 13 pieces, a padding/
joint-overlap convention, and a recommended Godot import configuration
(Linear filter + mipmaps + Lossless compression - illustrated art, not
pixel art). All written into
[ZAYR_ASSET_IMPLEMENTATION.md](ZAYR_ASSET_IMPLEMENTATION.md)'s new
Phase B section, so static assembly can proceed in one pass once the
PNGs actually exist. Re-ran the full regression battery (facing,
movement, attack offsets, Veyr Step, hurt/death/respawn) - all passed,
as expected since no gameplay or scene code changed this pass.

**Blocking on**: the 13 PNG files, authored to the pivot/padding
convention above, placed at `assets/characters/zayr/base/`.

## Milestone: Zayr AnimatedSprite2D Pipeline — Phase 1 (Idle Only)

**Status: pipeline change implemented, no idle art exists yet.**
Direction changed: the `Skeleton2D`/`Bone2D` cutout-rig plan (Phase B
above) is **superseded** - Zayr's approved v0.1 animation method is now
full-body, hand-authored frame animation via `AnimatedSprite2D`, not a
bone-driven rig. See
[ZAYR_ASSET_IMPLEMENTATION.md](ZAYR_ASSET_IMPLEMENTATION.md)'s new
"ZAYR ANIMATEDSPRITE2D PIPELINE" section for full detail - this entry
summarizes it.

`Player.tscn`'s `VisualRoot/CharacterRig` (the 16-`Sprite2D` static
assembly from Phase B) was removed and replaced with
`VisualRoot/CharacterSprite/AnimatedSprite2D`. The 11 texture
`ext_resource` entries for the retired rig pieces were removed from the
scene; the source PNGs themselves are untouched on disk and remain
available as reference art for whoever authors the new idle frames.
`WeaponManifestation`, `JinnFireLayer`, `VeyrLayer`, `AbilityVFX`,
`DamageVFX`, and `DebugVisual` are all unchanged.

No idle frames exist yet, so `AnimatedSprite2D.sprite_frames` is
genuinely empty (not faked). `PlayerController.gd` gained a small
fallback (`_no_idle_art()` / `_apply_visual_fallback()`) that forces
`DebugVisual` on and `VisualRoot` off whenever there's no `"idle"`
animation available, so the player is never left invisible while
waiting on art - confirmed via screenshot (Stage 1, the same
per-state-tinted rectangle used since Phase A, correctly grounded).
This fallback re-asserts every frame rather than once at `_ready()`,
which caught and fixed one real bug: `PlayerVeyrStep._end_step()`
unconditionally shows `VisualRoot` again when a step ends, which -
before the fix - popped `VisualRoot` back on with nothing in it,
alongside `DebugVisual`. Fixed in the fallback logic, not in
`PlayerVeyrStep.gd` (that node's own hide/show behavior is still
correct once real art exists).

Full regression battery re-run: all passed. Recommended asset
organization (individual numbered PNGs under
`assets/characters/zayr/animations/idle/`, not a spritesheet - no atlas
tooling exists in this project and isn't justified at 4-6 frames),
4-6 frame count and a conservative 6-8 FPS were proposed pending real
playback testing once frames exist. 72px target height and the 28x46
collision box are both unchanged - this pass touched neither.

**Blocking on**: `idle_01.png` through `idle_04.png` (up to `_06.png`),
full-body transparent frames per the spec in
ZAYR_ASSET_IMPLEMENTATION.md's new pipeline section, at
`assets/characters/zayr/animations/idle/`.

## Milestone: Zayr AnimatedSprite2D Pipeline — Phase 1 Integration (IDLE v0.1)

**Status: IDLE v0.1 implemented and validated - APPROVED to continue
production.** The four idle frames arrived at
`assets/characters/zayr/animations/idle/` and are a dramatic quality
step up from the earlier 13-piece rig extraction: full coherent
front-facing illustrations (not segmented body parts), genuine
transparency (0% background bleed, same audit method used on the
earlier rig art), no contamination, consistent character/costume/
proportions across all four. See
[ZAYR_ASSET_IMPLEMENTATION.md](ZAYR_ASSET_IMPLEMENTATION.md)'s "Phase 1
Integration" section for full detail - this entry summarizes it.

`VisualRoot/CharacterSprite/AnimatedSprite2D` now has a real
`SpriteFrames` resource (`"idle"`, 6 fps, looping) and is the default
player visual - `DebugVisual`'s auto-fallback (added last pass)
correctly stepped aside now that real art exists, confirmed by
regression. Measured standing height across the 4 frames: 67-72px
(within the approved ~72px target; the range itself is the hair
silhouette's own volume changing frame to frame, not a scale error -
body/legs/feet stay pixel-stable). Ground contact: 3 of 4 frames exact,
one 0.8px sub-pixel deviation from a slightly taller source canvas -
imperceptible, confirmed via direct screenshot comparison. Facing
mirror confirmed both directions via the existing (unchanged)
`VisualRoot.scale.x` mechanism.

Real-camera screenshots captured and reviewed at Stage 1, Stage 4
(Avaris reveal), and Stage 5 (mini-boss arena) - Zayr now reads as a
clearly legible, color-blocked humanoid silhouette in all three, a
major legibility improvement over every prior placeholder/rig attempt
this project has tried. Veyr Step confirmed both structurally and via
screenshot: idle animation is already playing the instant `VisualRoot`
becomes visible again after a step - no blank frame on reform.

One real finding, not a defect: the `idle_04 → idle_01` loop wrap is
objectively the largest frame-to-frame jump in the 4-frame cycle
(measured via pixel-difference analysis, not just eyeballed) - about
27% bigger than the next-largest transition. A reordering was checked
and found to be a genuine trade-off (smaller peak jump, more evenly-
distributed total motion) rather than a clear improvement, so nothing
was changed - flagged for a real-time playtest judgment call rather
than decided here.

Full regression battery re-run: 26/26 passed, including Perfect Step
and the Veyr Step→idle-resume path specifically. No collision/timing
regression. Run/jump/dash/combat/hurt/death all correctly continue
showing idle art, as expected - none of those animations were built
this pass.

**Next**: run animation (explicitly not started this pass, per
instruction).

## Milestone: Zayr AnimatedSprite2D Pipeline — RUN v0.1 Integration

**Status: RUN v0.1 implemented and validated - APPROVED for continued
production.** The six run frames arrived at
`assets/characters/zayr/animations/run/`. Audited with the same method
as idle plus connected-component analysis (new this pass, to explicitly
catch disconnected/extra anatomy in AI-generated frames per
instruction). See
[ZAYR_ASSET_IMPLEMENTATION.md](ZAYR_ASSET_IMPLEMENTATION.md)'s "RUN
v0.1 Integration" section for full detail.

**One real, disqualifying defect was found and handled correctly**:
`run_05.png` as originally delivered had a fully disconnected duplicate
boot fragment (615px, confirmed via 8-connected-component labeling to
have zero contact with the actual 80,327px character) floating in the
canvas margin - exactly the kind of "accidental extra anatomy" the
audit exists to catch. Reported per instruction rather than silently
worked around; a prepared surgical fix (touching only the isolated
fragment) was correctly blocked by the permission system pending
approval, since editing a shipped source asset shouldn't be a
unilateral call. The user then corrected and re-supplied the file
directly; re-audited clean (character content byte-identical, stray
fragment gone) before integration proceeded.

`SpriteFrames` gained a second animation, `"run"` (6 frames, 10 fps,
looping), alongside the unchanged `"idle"` (4 frames, 6 fps).
`PlayerController._update_character_animation()` (new, called from the
existing `_update_visual()`) selects `"run"` while `state == State.RUN`
and `"idle"` for every other state, using the existing unmodified state
machine - purely visual, never writes to gameplay state.

**A real scale bug was caught by measurement, not by eye**: the initial
assumption (reuse idle's 0.073 scale) rendered the running character at
only ~36-38px - roughly half of idle's ~72px, confirmed both
analytically and by direct pixel-count against an actual screenshot
that had otherwise looked "fine" at a glance. Root cause: idle and run
are on different canvas/framing conventions (confirmed via a native-
pixel side-by-side comparison), so no shared scale could be assumed.
Corrected to `scale = 0.13`, landing all six frames at 59-66px (82-92%
of idle's height - a plausible running-lean compression, not a
mismatch). Re-verified via fresh screenshots after the fix.

Ground contact uses the majority foot-contact convention (4 of 6 frames
share an identical canvas-bottom-edge baseline); the other two sit
slightly higher in a way that reads as natural mid-stride lift, not a
float/sink defect, confirmed via direct screenshot review across all
six frames. Facing/direction-change confirmed via the existing
(unchanged) `VisualRoot.scale.x` mechanism, including switching
direction mid-run without interrupting the animation. Real-camera
screenshots confirmed Zayr stays readable while running through Stages
1-5, including the dark Avaris reveal backdrop specifically called out
for attention.

Full regression re-run twice (before and after the scale fix): 32/32
passed both times. No collision, timing, or physics regression.

**Next**: jump/fall/wall-slide/dash/combat/hurt/death animations
(explicitly not started this pass, per instruction) - all currently
correctly fall back to idle.

## Milestone: Zayr AnimatedSprite2D Pipeline — JUMP/FALL v0.1 Integration

**Status: APPROVED for continued production.** Before integration, a
standalone pre-check audit (same method as run - alpha/bleed +
connected-component analysis) found real contamination in 5 of 7
delivered frames: `jump_02`/`jump_03` and **all three** fall frames had
disconnected duplicate-anatomy fragments, `fall_02`'s (760px) larger
than the original `run_05` defect. Reported to the user rather than
worked around. The user corrected and re-supplied all seven files;
re-audit confirmed every fragment gone and every main-character pixel
count byte-identical to the pre-correction measurement (only the
contamination was removed). See
[ZAYR_ASSET_IMPLEMENTATION.md](ZAYR_ASSET_IMPLEMENTATION.md)'s
"JUMP/FALL v0.1 Integration" section for full detail.

`SpriteFrames` gained `"jump"` (4 frames, `loop=false`) and `"fall"` (3
frames, `loop=true`), alongside the unchanged `idle`/`run`. Animation
selection extended to read the existing, untouched `State.JUMP`/
`State.FALL` (already computed correctly by `_update_state()`'s
`velocity.y` check before this pass began - no new state logic
written). Jump's "hold the final frame while still ascending" behavior
came for free from Godot's own non-looping-animation semantics
combined with the existing don't-restart-if-already-playing guard - no
new code needed for it.

**A real, deliberate architecture extension**: jump/fall poses vary too
much in bounding-box height (27-40px) for a single foot-anchored offset
like idle/run use - doing that would visibly "teleport" the torso
between frames. Instead each of the 7 frames gets its own offset,
solved so that frame's bbox-center lands at the same world Y regardless
of pose (a torso/core anchor instead of a foot anchor), via new
`ANIM_FRAME_SCALE`/`ANIM_FRAME_OFFSETS` dictionaries and a
`frame_changed` signal connection - additive, doesn't touch idle/run's
existing single-offset path. Verified analytically (0.000px core-Y
spread across frames, by construction) and visually (a captured jump
frame and fall frame compared directly show the torso at the same
on-screen height despite a dramatically different pose).

Scale initially set to `0.08` for both, based on a head-size comparison
- **wrong, and corrected after real playtest feedback**: the user
reported jump/fall looking "a lot smaller" than run in actual play.
Head size alone was the wrong metric - jump/fall's tucked/coiled poses
have a much shorter total silhouette than idle/run even with a
correctly-sized head, and that's what a viewer actually judges "size"
by. Corrected to **`scale = 0.13`** (same value `run` uses), landing
the extended airborne poses at 57-66px, matching idle/run's 59-72px
range; the coiled launch-crouch frame still reads shorter, correctly.
Re-verified via a direct four-way idle/run/jump/fall comparison
screenshot at identical zoom - all four now read as consistently sized.
Regression re-run clean after the fix.

**Jump FPS was corrected once, before it could become a bug**: the
initial guess (10 fps, matching run) was checked against the real
ascent duration (`|jump_velocity|/gravity` = 500/1400 ≈ 0.357s, the
actual project constants) before being committed - at 10 fps the
4-frame animation's own total duration (0.4s) is longer than the real
ascent, meaning the 4th frame would almost never actually be seen.
Corrected to `12 fps` (0.333s total, fitting inside the real ascent
with a small margin) - the minimum rate at which the full animation
actually plays out during a normal jump. Fall stayed at a conservative
6 fps per instruction (not copied from run's 10).

Real-camera screenshots confirmed correct scale, stable core-anchoring,
and readability at Stage 1, Stage 3, Stage 4 (Avaris reveal - flagged
for attention), and Stage 5, in both jump and fall states specifically
(a first capture attempt's fall shots accidentally overshot into
landing due to a fixed-wait timing choice in the throwaway test script;
corrected by waiting for the actual state transition). The dramatic
windswept-hair/cloth-flare styling on these two animations reads as
dynamic rather than distracting at real render scale, though it's a
closer call than idle/run's calmer look.

Full regression re-run twice (before and after the fps correction):
40/40 passed both times, including explicit assertions that collision,
gravity, jump velocity, and run speed are unchanged - not just absence
of visible symptoms.

**Next**: wall-slide/dash/combat/hurt/death animations (explicitly not
started this pass, per instruction) - all currently correctly fall
back to idle.

## Milestone: Zayr AnimatedSprite2D Pipeline — WALL SLIDE v0.1

**Status: APPROVED for continued production.** Unlike run/jump/fall,
the pre-integration audit (same alpha/bleed + connected-component
method) found all 3 delivered frames **clean on first delivery** - no
correction round needed. Every stray connected-component was 1-2px
isolated interior noise, none edge-adjacent, none exceeding this
project's established 10px "significant" threshold. See
[ZAYR_ASSET_IMPLEMENTATION.md](ZAYR_ASSET_IMPLEMENTATION.md)'s "WALL
SLIDE v0.1 Integration" section for full detail.

Notable structural difference from every prior set: **the wall surface
itself is baked into the art** - the character's hand/foot press
against a rendered wall edge visible in all three frames. `SpriteFrames`
gained `"wall_slide"` (3 frames, `loop=true`, `speed=6.0` fps, the
instructed starting point and unchanged after testing).
`idle`/`run`/`jump`/`fall` confirmed unchanged.

**A real architecture gap was found and closed correctly, per
instruction**: `movement.facing` does not reliably indicate which side
is walled (wall-sliding triggers on contact alone, no input-direction
check, so `facing` can be stale). The correct value
(`body.get_wall_normal().x`) was already being computed but stored
privately. Rather than misuse `facing` or alter wall-detection logic,
`_wall_normal_x` was renamed to a public `wall_normal_x` - a pure
visibility change (same pattern `facing` itself already uses), zero
behavior change. Mirroring now uses `-wall_normal_x` specifically
during `WALL_SLIDE`, `facing` for every other state.

Scale (`0.075`) landed inside idle/run's range on the first attempt -
checked via the same fixed-window head-comparison method that caught
the jump/fall scale bug, this time confirming the hypothesis before
committing rather than after a user report. Anchoring solved two
things together: X so the art's own baked-in wall edge lands exactly
at world X=14 (the real collision box's contacted edge - verified
0.00px error), Y via the same bbox-center core-anchor convention as
jump/fall. Confirmed via real physics-driven wall contact (not just
direct state assignment) in both `TestArena.tscn`'s corridor and
Stage 3's actual shaft: both wall sides mirror correctly, hand/foot
contact visibly lines up with the rendered wall in screenshots,
wall-jump cleanly hands off to the existing jump/fall animations (no
dedicated wall-jump art needed for v0.1), and rapid touch/release
doesn't get stuck.

One test-harness note, same category as the jump-timing issue: an
initial physics-driven wall-contact test gave an inconsistent result,
traced to the same double-processing artifact (the player's own
automatic `_physics_process` running alongside manual test calls) -
resolved by disabling automatic processing on the test node, not a
gameplay bug.

Full regression re-run: 38/38 passed, including explicit assertions
that `wall_slide_speed`, `wall_jump_velocity_y`,
`wall_jump_horizontal_speed`, gravity, jump velocity, and collision are
all unchanged.

**Next**: dash/combat/hurt/death animations (explicitly not started
this pass, per instruction) - all currently correctly fall back to
idle.

## Milestone: Zayr AnimatedSprite2D Pipeline — DASH v0.1

**Status: APPROVED for continued production.** Pre-integration audit
(same alpha/bleed + connected-component method) found all 4 delivered
frames clean, including special verification that the re-delivered
`dash_03.png` (corrected after an earlier extraction cut off Zayr's
head) now has a complete, undamaged head with no leftover fragments.
See [ZAYR_ASSET_IMPLEMENTATION.md](ZAYR_ASSET_IMPLEMENTATION.md)'s
"DASH v0.1 Integration" section for full detail.

`SpriteFrames` gained `"dash"` (4 frames, `loop=false`, `speed=30.0`
fps) - FPS was derived from the real gameplay `dash_duration=0.16s`
(read from `PlayerMovement.gd`, not assumed at the commonly-expected
14-16fps), chosen so the 4-frame sequence finishes just inside the real
dash window and holds on the last frame for the remainder, never
restarting mid-dash. Both `State.DASH` (grounded) and `State.AIR_DASH`
(airborne) map to this single animation - no separate air-dash art
exists. `idle`/`run`/`jump`/`fall`/`wall_slide` confirmed unchanged.

Scale (`0.13`, matching Run/Jump/Fall) was measured independently via
the fixed-window head-comparison method and landed correctly on the
**first attempt** - not copied from any other animation, and not
trusted to raw bounding-box height (Dash's pose is markedly more
horizontal than any prior set). Anchoring reuses the jump/fall/
wall-slide core-anchor convention, verified at 0.000px core-Y spread
across all 4 frames including the differently-sized corrected
`dash_03`.

Both dash directions, and all tested transitions (idle↔dash, run↔dash,
jump→air-dash→fall, fall→dash→landing) read cleanly with no scale pop,
torso teleport, stuck frame, or incorrect facing - confirmed via both
the regression battery and dedicated visual transition captures. A
continuous 5-dash chain through real `TestArena.tscn` geometry played
consistently rep-to-rep. No VFX (motion streak/dust/Jinn-Fire accent)
was implemented this pass, per instruction; Dash currently reads as
visually distinct from Veyr Step by construction (Veyr Step hides
`VisualRoot` and drives its own particle system, Dash keeps
`VisualRoot` visible with no particles active). Real-camera validation
at Stages 1/3/4/5 in `AvarisVerticalSlice.tscn` confirmed Zayr stays
readable against every tested backdrop despite the horizontal pose.

One test-harness artifact (not a gameplay/animation bug) was found and
fixed during Stage validation: the capture script wasn't resetting
`air_dash_available` between scripted situations, causing one stage's
dash press to be silently (and correctly) ignored since the air dash
had already been spent without an intervening landing. Documented
alongside the existing double-processing test-methodology note.

Full regression re-run: 45/45 passed, including explicit byte-for-byte
assertions that `dash_distance`, `dash_duration`, `dash_cooldown`, and
`air_dash_enabled` are unchanged, alongside every previously-tracked
gameplay constant and the full combat/Veyr Step/hurt/death/respawn
suite.

**Next**: combat animations and Dash VFX (explicitly not started this
pass, per instruction).

## Milestone: Zayr Gameplay Asset v0.1 — Phase B Resumed (Static Assembly)

**Status: static assembly complete for 11 of 13 delivered pieces.**
The 13 PNGs arrived at `assets/characters/zayr/base/`. A real per-pixel
audit (Pillow: alpha histograms, content bounding boxes, red/green
background-composite bleed tests - not visual guessing) found 11 pieces
clean and mutually consistent (identical 13px padding, consistent alpha
profile, anatomically coherent relative scale), one (`head.png`) usable
with a minor documented defect, and two (`hair.png`, `forearm.png`)
genuinely unusable as delivered: both are 3-6x larger in scale than the
rest of the batch, both have content touching a canvas edge with zero
padding, both carry a measurably different (worse) alpha profile, and
both are file-dated ~5 hours after the other 11 - clear evidence of a
separate, lower-quality export pass. `forearm.png` additionally bakes
in a complete hand that duplicates `hand.png`'s own content, an
architecture-breaking redundancy independent of the scale problem. Per
this phase's own instruction, neither was forced into the assembly -
see [ZAYR_ASSET_IMPLEMENTATION.md](ZAYR_ASSET_IMPLEMENTATION.md)'s
Phase B Resumed section for the full per-file audit table.

`VisualRoot/CharacterRig/BodyPlaceholder` was replaced with 16 `Sprite2D`
nodes (11 unique textures, 5 mirrored-and-reused for the opposite limb,
per the brief's explicit "canonical limb PNGs are reusable"
instruction). Transform values (position/scale/z-index per piece) were
derived and verified through an exact Python replica of Godot's own
`Sprite2D` transform math rendered against the real source art, then
transcribed into `Player.tscn` and confirmed in the real engine - first
analytical hand-math overshot the height target by ~55%, so this
render-and-measure approach was adopted instead, the same "verify for
real" discipline this project has used all session for camera/
composition work. Result: measured standing height 72.3px (vs. the
approved ~72px target), exact ground contact (0.0px offset).

Joint-rotation stress test (head ±10°, upper_arm ±20°, hand ±15°,
thigh ±15°, shin ±20°, foot ±10°, both directions) passed cleanly at
every tested joint - no holes, gaps, or broken anatomy, mainly thanks
to consistent padding and generous cloth coverage at the hip. Mirror
test passed both programmatically (regression suite confirms
`VisualRoot.scale.x` flips correctly in the real engine) and visually
(transform-faithful mirrored render) - the only asymmetry note is
`torso.png`'s baked-in diagonal sash flipping sides with the character,
which reads fine in both directions, not an error.

Real-GPU, real-camera screenshots captured across all six requested
gameplay situations (awakening, traversal, melee combat, Veyr/ranged
encounter, Avaris reveal, mini-boss arena) - Zayr reads clearly and
sits exactly on the ground line in all six, a dramatic legibility
improvement over Phase A's flat placeholder. A dedicated close-up
mirror screenshot failed due to a camera-zoom timing bug in the
throwaway validation script (not a game defect); not re-attempted since
mirroring was already confirmed by the two methods above.

Full regression battery re-run: 33/33 passed. One false failure was
found and root-caused mid-pass: a test-harness artifact (driving
`_physics_process()` directly without ever yielding a real engine frame
after `Input.action_press/release()` left a stale dash-input signal
that spuriously re-fired ~70 frames later) - confirmed not a gameplay
or Phase B issue since `PlayerMovement.gd`/`PlayerController.gd` were
untouched this phase, and the failure vanished once a single
`await process_frame` was added after the input release.

**Assets needing correction before Phase B can be considered fully
resolved**: `hair.png` and `forearm.png` need re-export at the same
scale/padding/style convention as the other 11 pieces (`forearm.png`
must also end at the wrist, no hand baked in); `head.png` has a minor,
non-blocking stray gold collar fragment worth cleaning up. Until then,
the assembled Zayr is visibly missing hair and has a visible gap where
the forearm should bridge upper arm to hand - documented and left
visible rather than hidden, per instruction.

## Milestone: Zayr AnimatedSprite2D Pipeline — LIGHT ATTACK 1 BODY v0.1

**Status: APPROVED for continued production.** Re-audit of all 6
frames (same alpha/bleed + connected-component method) found everything
clean, including targeted verification of the three re-delivered
corrected frames (`light_1_02/04/05.png`): each previously-incomplete
hand now reads as complete, with a natural wrist-to-forearm connection
and no duplicated anatomy or leftover fragments. See
[ZAYR_ASSET_IMPLEMENTATION.md](ZAYR_ASSET_IMPLEMENTATION.md)'s "LIGHT
ATTACK 1 BODY v0.1 Integration" section for full detail. (Note: the
task described the corrected files as delivered to a new `combat/
light_1/` subfolder, but they were actually still at the original
`animations/light_1/` path - timestamps confirmed the correction had
genuinely happened, so this was a path-description mismatch, not a
missing-correction problem, and integration proceeded from the real
location.)

`SpriteFrames` gained `"light_1"` (6 frames, `loop=false`, `speed=18.0`)
mapped to `State.ATTACK_1`. FPS was derived from the real swing 1
duration read from `PlayerCombat.gd` (`0.35s` total, `0.08s` windup,
`0.10s` active hitbox window, `26px` hit offset ≈ `64px` total reach) -
not assumed - so the sequence finishes just inside the real swing and
holds its last frame rather than being cut off or restarting.
Scale (`0.13`, matching Run/Jump/Fall/Dash) was measured independently
via the same fixed-window comparison method used since the jump/fall
scale bug, confirmed correct on the first attempt via both a head-crop
comparison and a direct bottom-aligned render against Run. Anchoring
reuses the jump/fall/dash bbox-center core-anchor convention rather
than foot-locking, since the pose's limb/cloth extension varies
drastically frame to frame - verified at 0.000px core-Y spread
including the three differently-sized corrected frames.

Both facing directions, hitbox/art alignment (the punching fist's
extension visibly agrees with the real ~64px hitbox reach at the
frames identified as the active window), and every tested transition
(idle↔light_1, run↔light_1, airborne attacks correctly routing to the
separate pre-existing Aerial Attack instead, and the light_1→light_2
combo chain advancing exactly once per press using existing behavior)
all read cleanly. Real-camera validation at Stages 1/3/4/5 in
`AvarisVerticalSlice.tscn` confirmed Zayr and the hitbox stay readable
against every backdrop.

**Two previously-undocumented manual-test-harness quirks were found
and fixed while validating this pass**, both added alongside this
project's existing double-processing/hitstop-timing notes: (1)
`AnimatedSprite2D`'s own frame advance is driven by the engine's real
per-process delta rather than a script's manually-supplied physics
delta, so `Engine.time_scale` dropping during hitstop (from a swing
landing on a nearby training dummy) measurably distorted one timing
measurement without affecting anything else; (2) `Input.
is_action_just_pressed()` does not clear between manually-driven
`_physics_process()` calls unless a real engine frame elapses in
between, which caused one throwaway combo-chain test to read a single
press as several and chain further than intended - a clean,
frame-bounded isolated re-test confirmed the real gameplay chain logic
only ever advances once per press. A third, unrelated harness issue
(the player's own camera's `position_smoothing` never catching up to
large instant test-position teleports, since smoothing likewise only
advances on real frames) was found and fixed during the Stage 1/3/4/5
capture.

Full regression re-run: 47/47 passed, including explicit assertions
that `swing_durations[0]`, `hitbox_start_times[0]`, `hitbox_end_times[0]`,
every attack hit-offset, `attack_cooldown`, and every previously-tracked
gameplay constant are unchanged.

A Veyr Edge manifestation **plan** (origin hand, ~64px length matching
the real hitbox reach, manifestation/disappearance frames, which frames
need slash-trail VFX) was derived from the approved body animation and
documented for a future pass - no weapon asset or `WeaponManifestation`
code was created this pass, per instruction.

**Next**: Light Attack 2/3, other combat animations, and Veyr Edge art
(explicitly not started this pass, per instruction) - all currently
correctly fall back to idle.

## Milestone: Zayr AnimatedSprite2D Pipeline — VEYR EDGE v0.1 / Light Attack 1 Manifestation

**Status: APPROVED for continued production.** `veyr_edge.png` audit
found genuine soft-glow transparency (confirmed by compositing over
both red and green backgrounds), complete blade tip and hilt, no baked
Zayr body parts or slash trail. See
[ZAYR_ASSET_IMPLEMENTATION.md](ZAYR_ASSET_IMPLEMENTATION.md)'s "VEYR
EDGE v0.1" section for full detail.

Added as a plain `Sprite2D` under the existing (previously empty)
`VisualRoot/WeaponManifestation/VeyrEdge`, never baked into
`CharacterSprite`. Visibility is driven directly by
`combat.hitbox.monitoring` rather than by `light_1`'s animation frame
number, per instruction that gameplay timing stays authoritative - this
mattered in practice, since `AnimatedSprite2D`'s frame advance runs on
the engine's real per-process clock, not the same clock driving
`PlayerCombat`'s attack timer, so the two can drift a frame apart;
clamping the per-frame transform lookup to the nearest defined active
frame keeps the weapon visible for the whole true 0.08-0.18s window
instead of flickering. Position/rotation for frames 2-4 track the
punching fist's own per-frame world position and the arm's own angle;
scale is a single constant value (a real weapon doesn't resize itself
mid-swing). Measured tip reach lands close to the real ~64px hitbox
edge across the active frames (roughly -3px to +16px depending on the
frame), reported rather than force-fit, per instruction not to retune
gameplay to match the art.

Both facing directions, all tested transitions (idle/run/light_1, the
light_1→light_2 combo chain correctly hiding the weapon during swing 2
since it has no art/different timing), and all three interruption paths
(HURT, Veyr Step, death) hide the weapon cleanly with no stuck frame.
Real-camera validation at Stages 1/3/4/5 confirmed the weapon reads as
a modest, readable energy accent that doesn't overwhelm Zayr's own
silhouette at any tested location.

Full regression: 39/39 passed. One test-only issue was found and fixed
while building the interruption-path checks: chaining a HURT interrupt
directly into a Veyr Step interrupt inside a purely-synchronous manual
test loop let a deferred invulnerability grant from the HURT event
land late (after its own timer-based removal had already fired on
nothing), leaving one invulnerability source permanently stuck and
blocking a later lethal-damage check - fixed by adding a single
`await process_frame` right after the HURT trigger, matching how a real
game frame actually flushes deferred calls. Not a gameplay bug -
`HealthComponent`/`PlayerController` untouched - and documented
alongside this project's other manual-test-harness quirks.

**Next**: Light Attack 2/3, other combat animations, and slash-trail
VFX (explicitly not started this pass, per instruction) - Light Attack
1 remains the only combo swing with both body art and a manifested
weapon.

## Milestone: Zayr PixelLab Full-Body Re-Integration

**Status: APPROVED for continued production.** Replaced every prior
hand-painted illustration animation (idle/run/jump/fall/wall_slide/
dash/light_1) with the finalized PixelLab pixel-art set, and newly
wired ten animations that had no art before: combat_idle, light_2,
light_3, heavy, aerial, ranged, charged_start, charged_hold,
charged_release, hurt, death - 18 animations, 122 frames total. See
[ZAYR_ASSET_IMPLEMENTATION.md](ZAYR_ASSET_IMPLEMENTATION.md)'s
"PixelLab Full-Body Re-Integration" section for full detail.

Audit found all 122 frames clean (0% bleed, no significant stray
fragments). One real art finding worth flagging: `light_2`/`light_3`/
`aerial` have a weapon or energy-effect baked directly into their later
body frames, contrary to the stated "no weapon in body art" expectation
- integrated exactly as delivered, not edited, and reported rather than
resolved unilaterally.

**Facing bug found and fixed after this milestone shipped**: the
delivered "east" art was misjudged during audit as facing screen-left
(dash's/ranged's trailing cloth streaming toward one frame edge was
mistaken for the character leaning that way) and "corrected" with a
`Vector2(-1, 1)` sprite scale - which actually inverted correctly-
facing art. A user testing in-editor reported Zayr visibly facing away
from his real movement direction; `movement.facing`/`VisualRoot.scale.x`
were internally consistent with each other the whole time (a pure
code/data check wouldn't have caught this), so it took rendering the
raw source PNG directly and comparing a zoomed real-screenshot crop of
Zayr's face against his actual travel direction to find. Reverted to
`Vector2(1, 1)`; the art faces right natively, matching the folder
name. Veyr Edge's light_1 attach points (which used the same wrong
"leftmost = forward" assumption) were recomputed from the fist's
correct rightmost extent. See
[ZAYR_ASSET_IMPLEMENTATION.md](ZAYR_ASSET_IMPLEMENTATION.md)'s facing
note for the full account.

Continued the existing `AnimatedSprite2D`/`SpriteFrames` architecture
unchanged (no Skeleton2D) - the one structural change is that
`SpriteFrames` now lives in its own resource file
(`ZayrSpriteFrames.tres`) instead of inline in `Player.tscn`, purely to
keep the scene file readable at 122 frames. Scale is `1.0` (real pixel
art, no downscaling); anchoring reuses the established foot-anchor
(grounded animations) / core-anchor (airborne ones) split, but
`TARGET_CORE_Y` needed recalibrating from `-45` to `-30` for this art's
own proportions - the old value, copied over unchanged on the first
attempt, rendered every airborne animation floating above the collision
box, caught via a real-camera screenshot with the collision box
overlaid and fixed before commit.

FPS was derived from real gameplay timing throughout, never assumed
from frame count. Attacks with a real windup/active/recovery split
(light_1/2/3, heavy, aerial, charged_release) use a two-phase per-frame
duration scheme rather than a single uniform fps, so the art's own
windup-vs-strike content lines up with the real gameplay phases instead
of just fitting the total duration arithmetically - light_1's real
active hitbox window now falls on frames 4-5 instead of 1-3, which fed
directly into recalibrating Veyr Edge's attach points and clamp range
for the new hand position. No gameplay value (combat timing, hitboxes,
movement, physics, Veyr costs, damage, combo logic, input) was changed
- confirmed via 121 regression assertions, all passing, including
byte-for-byte checks against every constant listed above.

Old hand-painted source PNGs (idle/run/jump/fall/wall_slide/dash/
light_1's flat files, not the `east/` folders) were removed after
confirming no scene/script anywhere still referenced them. The obsolete
`Running_Jump` folder was left untouched, per instruction.

**Next**: regenerate `light_2`/`light_3`/`aerial`'s baked weapon frames
if a clean unarmed body-only pass is wanted for those (currently
integrated as delivered); Veyr Edge or other manifestations for
light_2/3/heavy/aerial/ranged/charged, if desired (none exist yet, per
instruction not to build new VFX architecture this pass).

## Milestone: Combo Chain Window - Feel Tuning

**Status: implemented and tested.** Direct feedback: chaining the
3-hit combo required clicking attack again unreasonably fast. The old
behavior only let a press queue the next swing while the *current*
swing was still actively playing (`swing_durations[combo_index]` -
0.32-0.42s); missing that instant-narrow window reset the whole combo
back to swing 1.

`PlayerCombat.gd` now grants a `combo_chain_window` (new `@export`,
default **1.0s**) grace period *after* a swing ends with nothing
queued yet - a press inside that window still continues the combo
(advances to the next swing, or loops back to swing 1 if the 3rd swing
just finished) instead of being treated as a fresh, `attack_cooldown`-
gated start. The original instant-chain path (pressing while a swing is
still playing) is untouched - it still needs no buffering since the
press lands while `is_attacking` is already true. Only a press that
misses the *entire* 1-second window resets the combo and requires the
normal `attack_cooldown` (0.1s) before a new swing 1 can start, so
spamming the button still can't skip recovery indefinitely - it just
has a far more forgiving reaction window than the old ~0.35s.

No hitbox timing, damage, per-swing windup/active windows, or any other
combat value was touched - `swing_durations`, `hitbox_start_times`,
`hitbox_end_times`, `damages`, `hit_offset`, and `attack_cooldown` are
all exactly as before. Tested: the instant-chain path during an active
swing still works with no gap; a buffered press at ~0.5s into the
window correctly continues to the next swing; a buffered press after
the 3rd swing correctly loops back to swing 1 without waiting through
`attack_cooldown`; a press that arrives after the full window expires
correctly resets to a fresh, cooldown-gated swing 1; `light_2`/`light_3`
play correctly on a buffered chain and the animation settles to idle
during the grace period rather than hanging on the last swing's pose;
Veyr Edge and every other attack (heavy/aerial/ranged/charged) and HURT
are unaffected.
