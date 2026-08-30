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
│   ├── bosses/          MiniBoss.tscn
│   ├── regions/         Level/region scenes: TestArena.tscn (combat prototype
│   │                     sandbox), and regions/avaris/vertical_slice/
│   │                     AvarisVerticalSlice.tscn (the first vertical slice - see
│   │                     PROGRESS.md and §10)
│   ├── ui/               HUD.tscn, ResourceBar.tscn
│   └── interactables/   Interactable object scenes (not yet populated)
│
├── scripts/
│   ├── player/          PlayerController, PlayerMovement, ...
│   ├── combat/          HealthComponent, VeyrComponent, Hitbox, Hurtbox, Projectile
│   ├── enemies/         EnemyController, EnemyAIBase, EnemyAI, RangedEnemyAI
│   ├── bosses/          BossController, BossAI
│   ├── systems/         Cross-cutting systems: CameraController, PlayerTrigger
│   │                     (generic "player entered" signal), MemorySequence,
│   │                     RhaekTeaser (see §10) - save/dialogue not implemented yet
│   └── ui/              HUD, ResourceBar
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
Edge combo **and** heavy attack — see below) and **`PlayerVeyrStep.gd`**
(his evasive blink) both follow the same `physics_update()`-called-from-
controller pattern as `PlayerMovement.gd` — see [COMBAT.md](COMBAT.md)
§6–8. `PlayerAbilities.gd` doesn't exist as a separate file; Veyr Step
lives directly in its own component instead, consistent with how combat
already works.

The heavy attack, the charged attack, and the Aerial Attack (all
[COMBAT.md](COMBAT.md) §8/§15/§14) live inside `PlayerCombat.gd` rather
than separate components: all three reuse the same `Hitbox`/
`SwingVisual` as the combo and need mutual-exclusion state with it
(can't start one while another is active), which separate components
would have had to reach across a component boundary for on every shared
action. The Aerial Attack specifically takes over what the tap-based
`attack` button does while airborne (own timing/damage/color, not the
combo's own values repositioned — see [COMBAT.md](COMBAT.md) §14's
revision note for why that changed); the `aim_down`-while-airborne
downward-strike positioning it shares with Heavy Attack and the charged
attack is a separate, smaller piece — a modifier on where any of the
three's `Hitbox` goes, not an attack type of its own.

**`PlayerRangedAttack.gd`** (Zayr's Veyr ranged attack) is a separate
component, unlike the other three, precisely because it doesn't share
`PlayerCombat`'s `Hitbox` — it fires a moving `Projectile` (the same
primitive `RangedEnemyAI`/`BossAI` already use), which is mechanically
different enough to warrant its own file. It's still mutually exclusive
with the combo/heavy/charged/aerial attack, just via a symmetric
cross-component guard instead of shared internal state:
`PlayerRangedAttack` checks `not combat.is_attacking and not
combat.is_heavy_attacking and not combat.is_charging and not
combat.is_charged_attacking and not combat.is_aerial_attacking` before
starting, and `PlayerCombat` checks `not ranged_attack.is_attacking` before
starting any of its own attacks. It's the first ability that actually
spends `VeyrComponent`'s pool in normal play — see docs/COMBAT.md and
docs/PROGRESS.md for the design (cost paid only at the moment of firing,
not at windup start, so an interrupted windup doesn't waste it).

### State Machine

`PlayerController.gd` holds a simple enum-based state machine. Only the
states needed so far are implemented:

```
IDLE, RUN, JUMP, FALL, WALL_SLIDE, DASH, AIR_DASH, ATTACK_1, ATTACK_2, ATTACK_3, ATTACK_HEAVY, VEYR_STEP, HURT, DEAD
```

The remaining eventual states (`CHARGING, EMBER, VEIL`) are **not**
implemented yet. `DEAD` and `HURT` are both prototype-minimal: no
animation, just a freeze (`DEAD`: timed respawn, see §3.2; `HURT`: a
knockback velocity impulse + timed control return, see §3.3). States are
derived from movement/combat/step output each physics frame — the enum
can be extended without restructuring the controller, since transitions
are just a `match` on current velocity/contact/ability state (`HURT` and
`DEAD` bypass that `match` entirely via an early return, same pattern for
both).

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

`Hurtbox` also emits `hit_avoided(damage, hitbox)` when a hit lands while
its owner's `HealthComponent.is_invulnerable` is true — a generic fact
about the Hurtbox, not tied to any one invulnerability source. Perfect
Step ([COMBAT.md](COMBAT.md) §7.1) is what currently listens for it.

`Hitbox` also carries a `stability_damage` field (0 by default) and
`Hurtbox` an optional `stability_component_path` — see
[COMBAT.md](COMBAT.md) §9's `StabilityComponent` — following the same
generic-primitive, specific-behavior-lives-elsewhere pattern as
`hit_avoided`.

### 3.2 Death / Respawn

No save system or game-over flow exists (out of scope — see §9), so
`PlayerController` handles `HealthComponent.died` with the minimal thing
that keeps a combat prototype testable: freeze input for
`RESPAWN_DELAY`, then reset position to wherever Zayr started this scene
(`global_position` captured once in `_ready()`) and call the new
`HealthComponent.revive()`. `revive()` deliberately bypasses the
`is_dead()` guard `take_damage()`/`heal()` use, since undoing that guard
is the entire point of reviving. No animation, no game-over screen, no
persistence across scene reloads.

### 3.3 HURT State

On the player's own `Hurtbox.hit_received` (filtered to hits that
actually landed — not dead, not already hurt, not invulnerable),
`PlayerController` enters `HURT`: a one-time knockback velocity impulse,
`PlayerMovement.cancel_dash()`/`PlayerCombat.cancel_attack()`, then input
is fully inert (an early return before any input is read, applying only
gravity + `move_and_slide()` directly) for `hurt_duration`, after which
normal control resumes. See [COMBAT.md](COMBAT.md) §10 for the full
design and a real bug this surfaced (post-hit invulnerability racing
against the triggering hit's own damage application, fixed with
`call_deferred()`).

`HealthComponent.is_invulnerable` is now reference-counted
(`add_invulnerability()`/`remove_invulnerability()`) rather than a plain
bool, specifically so `HURT`'s optional post-hit grace window can't
prematurely cancel Veyr Step's own invulnerability (or vice versa) when
both happen to be active — see [COMBAT.md](COMBAT.md) §10 for why this
was necessary rather than incidental scope creep.

## 4. Enemy Architecture

Mirrors the player's Controller/component split, and is shared across
every enemy variant via a common AI interface:

- **`scripts/enemies/EnemyAIBase.gd`** — the contract `EnemyController`
  programs against: `facing`, `move_velocity_x`, `is_attacking`,
  `physics_update()`, and `cancel_attack()` (a no-op base — each concrete
  AI overrides it to clean up its own attack state; see
  [COMBAT.md](COMBAT.md) §9). `EnemyController` never references a
  concrete AI class, so adding a new enemy variant never requires
  changing it.
- **`scripts/enemies/EnemyController.gd`** — root controller for every
  enemy. Applies gravity, takes `ai.move_velocity_x`, calls
  `move_and_slide()`, and owns hit-flash / attacking-tint / stagger-tint /
  death-fade feedback generically (on `HealthComponent.died`: fade out,
  then `queue_free()`). Also owns the `StabilityComponent` integration —
  see [COMBAT.md](COMBAT.md) §9: while staggered, it simply doesn't call
  `ai.physics_update()` at all that frame, so no per-AI-script
  stagger-awareness code is needed anywhere.
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
- The ranged enemy is stationary — no kiting/repositioning to keep its
  distance if the player closes in.
- Every enemy now has a `StabilityComponent` and can be staggered — see
  [COMBAT.md](COMBAT.md) §9 for what that does and doesn't cover yet
  (single stagger tier, no Perfect Step interaction, freezes movement as
  well as attacks — flagged there as worth reviewing).
- `Projectile` now stops at world geometry instead of passing through it
  — see [COMBAT.md](COMBAT.md) §11 for the fix and the `monitorable`
  engine quirk it uncovered.

### 4.1 Mini-Boss

**`scenes/bosses/MiniBoss.tscn`**, **`scripts/bosses/BossController.gd`**,
and **`BossAI.gd`** — a generic (unnamed) mini-boss, not one of the reserved
canon characters ([LORE.md](LORE.md) §5 — their characterization and boss
mechanics are still explicitly deferred). Combines the two existing enemy
attack patterns in one entity rather than inventing a new one:

- `BossController` **extends `EnemyController`** (not a from-scratch
  controller) — the boss is still just a body with gravity/velocity from
  its `EnemyAIBase`-conforming AI and the same generic hit-flash/
  attacking-tint/death-fade feedback. It only adds one thing: a base-color
  shift when `BossAI.phase2_started` fires.
- `BossAI` (`extends EnemyAIBase`, same interface as `EnemyAI`/
  `RangedEnemyAI`) — stationary until `detection_range`, then melees
  (own `Hitbox`, like `EnemyAI`) within `melee_range` or fires a
  `Projectile` (like `RangedEnemyAI`) beyond it. Below
  `phase2_health_ratio` (default 50%) it permanently shortens both attack
  cooldowns by `phase2_cooldown_multiplier` and emits `phase2_started`
  once — numeric escalation, not a new mechanic.
- The HUD (§8) gained a third bar specifically for whatever's in the
  `"boss"` group, hidden unless one exists in the scene.

**Known limitations:** single phase-2 threshold only (no phase 3), no
enrage/timer mechanic, no unique "boss-only" attack beyond combining the
two existing patterns — deliberately proportionate to the "mini" in
mini-boss rather than a full spectacle encounter.

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
- `attack` — J / Left Click
- `aim_up` — W / Up Arrow
- `aim_down` — S / Down Arrow
- `veyr_step` — Ctrl (moved off K specifically so it's reachable
  without leaving the mouse mid-fight, now that attack/heavy attack are
  on mouse buttons)
- `heavy_attack` — L / Right Click (L is a leftover prototype-testing
  keybind from before mouse buttons were added — right click is the
  deliberate one)
- `ranged_attack` — Q (kept off the mouse deliberately — the user
  specifically asked not to use middle mouse, since it "can have
  issues" — Q sits right next to WASD so it's reachable without moving
  the movement hand off, same reasoning as `veyr_step`'s move to Ctrl)
- `charged_attack` — E (same reachability reasoning as Q; a dedicated
  hold-to-charge input, deliberately not overloading `attack`, which
  would need tap/hold disambiguation against the 3-hit combo)

`aim_up`/`aim_down` are purely directional-intent inputs for aiming Veyr
Step (see [COMBAT.md](COMBAT.md) §7) — there's no crouch/look-up, so W/S
were free to repurpose. Combined with `move_left`/`move_right`, they give
the 8-directional input Veyr Step reads.

## 8. UI

- **`scripts/ui/ResourceBar.gd`** + **`scenes/ui/ResourceBar.tscn`** — a
  generic current/max bar (flat-color `ColorRect`s, matching the
  project's placeholder-geometric visual language rather than a themed
  `ProgressBar`). `set_value(current, max)` resizes the fill; knows
  nothing about health or Veyr specifically, so it's reusable for either
  (or any future resource). Its root `Control`'s `size` is the actual
  source of truth for width — `_ready()` propagates it to the child
  `Background`/`Fill` rects, so a per-instance override (e.g. the wider
  boss bar below) genuinely resizes, not just reports a different value.
- **`scripts/ui/HUD.gd`** + **`scenes/ui/HUD.tscn`** — a `CanvasLayer`
  with a `ResourceBar` each for the player's health and Veyr, plus a
  third, wider one for whatever's in the `"boss"` group (hidden if none
  exists). The boss bar only shows while the player is within
  `vicinity_range` (`@export`, default 320px) of the boss — checked each
  `_process()` frame by distance, not just "does a boss exist somewhere
  in the scene" — and hides again ~1s after the boss's
  `HealthComponent.died`, regardless of proximity (`_boss_dead` guards
  the per-frame distance check so death-hiding isn't fought by the
  player standing close when it dies). Finds player/boss via those
  groups (the same lookup `EnemyAI`/`BossAI` use to find the player) in
  `call_deferred()`'d connections, so it doesn't need manual per-region
  wiring — instancing `HUD.tscn` in a region is enough. `TestArena.tscn`
  and the vertical slice both do this.
- No numeric text (just bars), no low-health warning state, no damage-
  number popups. Deliberately minimal per what was asked for.

## 9. Known Gaps / Not Yet Decided

- No save system yet.
- No animation system yet (placeholder geometry only).
- Player death respawns in place (see §3.2) — no game-over screen, no
  persistence, no death animation.
- Falling off the test arena still isn't handled — no bottomless-pit
  detection, so falling off an edge just falls forever rather than
  triggering the death/respawn flow above.
- Two enemy variants exist (melee, ranged) plus one mini-boss. See §4/
  §4.1 for their specific known limitations (ledge detection, chase
  leash, ranged-enemy kiting, boss single-phase-2-only).
- Veyr Step's diagonal-direction math and wall-clamp were
  headless-validated but hit test-harness timing flakiness on the
  multi-key-combo cases specifically (not the core teleport/
  invulnerability/cooldown, which validated cleanly and consistently) —
  worth a deliberate manual check of a few diagonal directions and
  stepping straight at a wall. Perfect Step ([COMBAT.md](COMBAT.md) §7.1)
  is implemented and headless-validated cleanly, including the negative
  case (no false trigger with nothing to avoid).
- No player HURT-state knockback decay (fixed-velocity slide for the
  whole `hurt_duration`, not an impulse-with-drag system), and no
  hitstop on the player taking a hit (only on Zayr's own attacks) — see
  [COMBAT.md](COMBAT.md) §10.
- An undocumented-seeming Godot 4.7 `Area2D` behavior was found while
  fixing projectile world collision: `monitorable = false` blocks
  `body_entered` entirely, not just detection-by-other-areas as the
  property name suggests. Worth remembering if any future `Area2D`
  needs to detect a `PhysicsBody2D` and mysteriously doesn't — see
  [COMBAT.md](COMBAT.md) §11.
- Same class of issue again, found while building the vertical slice's
  Memory trigger (§10): `PlayerTrigger` tried to set its own
  `monitoring = false` synchronously from inside the `body_entered`
  signal it was handling — Godot 4.7.2 blocks mutating monitoring state
  from within the signal that's driving it (`ERROR: Function blocked
  during in/out signal`), the same category of problem as the post-hit
  invulnerability race in §3.3. Fixed with `set_deferred("monitoring",
  false)`. Worth remembering for any future one-shot `Area2D` trigger.
- Testing gotcha (not a game bug, but has bitten more than one throwaway
  headless test): `RangedEnemyAI`/`BossAI` fire projectiles via
  `get_tree().current_scene.add_child(...)`. Godot sets `current_scene`
  automatically when it loads a scene as the actual running scene, but a
  throwaway `SceneTree`-script test that just does `root.add_child(scene)`
  does **not** get that for free — `current_scene` stays null, and the
  first test to actually exercise a projectile-firing code path crashes.
  Set `current_scene = scene` explicitly in any such test's setup.
- Testing capability discovered during the art pass (§11): headless mode
  (`--headless`) uses Godot's **dummy** rendering driver — `Viewport.
  get_texture().get_image()` returns null there, so screenshots aren't
  possible headless. Running the **same** kind of throwaway `SceneTree`
  script **without** `--headless` (just `godot --path . --script res://
  scripts/_tmp_x.gd`) uses the real GPU renderer and screenshots work
  fine (`root.get_texture().get_image().save_png(...)`), while still
  being a fully scripted, non-interactive, `--quit()`-terminated run —
  not a manual play session. This closes a real gap: several earlier
  milestones (Stage 1's chamber lighting, Stage 4's reveal composition)
  had to flag "can't verify visually, needs manual play" for exactly
  this reason. It's still not a substitute for actual human playtesting
  (no input feel, no motion, single frames only), but it means visual
  regressions/mistakes (like the initial glow overshoot in §11) can now
  be caught and fixed before asking for a play session, not just guessed
  at from code.
- Testing gotcha found reusing the screenshot technique for Stage 5
  ([PROGRESS.md](PROGRESS.md) Stage 5 Enhancement): `Camera2D`'s
  `position_smoothing_enabled` (set by `CameraController.gd`) means a
  raw `player.global_position =` teleport across a large distance (e.g.
  jumping a test straight from one stage to another thousands of pixels
  away) does **not** move the camera there immediately - a screenshot
  taken a handful of frames later still shows wherever the camera was
  smoothing *from*, not the new position, which looks like completely
  wrong content in frame (a Stage 4 screenshot request appeared to
  render Stage 3). Fixed by calling `Camera2D.reset_smoothing()`
  immediately after any large teleport in a screenshot-taking test, or
  waiting substantially longer than the smoothing needs to catch up -
  `reset_smoothing()` is the reliable one.
- Testing gotcha found while validating the charged attack
  ([COMBAT.md](COMBAT.md) §15):
  scripting `Input.action_press(action)` → `Input.action_just_pressed()`
  wait → `Input.action_release(action)` → **`Input.action_press(action)`
  again within the same throwaway test run** can fail to register the
  second press as a fresh `is_action_just_pressed()` edge — observed as
  a held-charge action getting stuck at exactly one physics tick's worth
  of accumulated time and never resuming, even though
  `Input.is_action_pressed()` correctly showed `true` throughout.
  Confirmed as a test-harness artifact, not a game bug, by re-running the
  same scenario as an **isolated** script with a single fresh press and
  no prior release in that run — it worked perfectly (exact expected
  value). If a throwaway test needs to press the same action twice with
  a release in between, run the second scenario as its own separate
  script invocation rather than re-pressing within one run.
- Two more testing gotchas found while reworking the Aerial Attack
  ([COMBAT.md](COMBAT.md) §14):
  1. `CharacterBody2D.is_on_floor()` reads **stale** state immediately
     after a raw `global_position =` teleport — it's a cached result
     from the last `move_and_slide()` call, not re-evaluated until the
     next physics tick actually runs one. A test that teleports a player
     into the air and immediately checks `is_on_floor()` can see `true`
     (leftover from wherever they were before) for one or more ticks.
     Wait a few ticks after any teleport before trusting the floor state.
  2. A per-attack cooldown timer (e.g. `_aerial_cooldown_timer`) reads
     `0.0` both *before* an attack has ever set it and *after* it's
     fully elapsed — checking `timer <= 0.0` alone to decide "safe to
     attack again" is ambiguous if the previous attack might still be
     mid-flight (hasn't reached the point where it sets the timer yet).
     Also check the attack's own `is_*_attacking` flag is `false`, not
     just the cooldown timer, before attempting a second attack in the
     same test run. Both gotchas compounded on a real-engine-loop test
     that needed to trigger the same attack twice in one run; solved by
     explicitly waiting for `not is_*_attacking` (not just a cooldown
     timer) between attempts, and — for a case where input-timing
     fragility persisted even after fixing both — by isolating the
     specific thing at risk (positioning/damage math) via a direct
     method call (`PlayerCombat._start_aerial_attack()`) with a
     controlled position, bypassing simulated input entirely rather than
     continuing to fight input-timing noise for a question input timing
     wasn't actually relevant to.

## 10. Scripted Sequences / Narrative Triggers

Introduced for the vertical slice ([PROGRESS.md](PROGRESS.md) Stages 1,
6, 7) — a small, deliberately minimal pattern for one-off environmental
beats, not a general event/quest/dialogue framework:

- **`scripts/systems/PlayerTrigger.gd`** — a generic `Area2D` that emits
  `triggered` when the `"player"` group enters it. `@export var
  one_shot` (default `true`; the vertical slice's `KillZone` sets it
  `false` since it needs to fire every fall, not just the first). That's
  its entire API — it knows nothing about what happens when it fires.
  Each usage site connects `triggered` and does its own small thing.
- **`scripts/systems/MemorySequence.gd`** / **`RhaekTeaser.gd`** — both
  follow the same shape: an `@export var trigger_path: NodePath` to a
  sibling `PlayerTrigger` (same convention as `Hurtbox.
  health_component_path`), a `_played`/one-shot guard, and an `await`-
  chained sequence of `Tween`s and `SceneTreeTimer`s staging a multi-part
  beat (fade in → hold → fade out, or presence → attention → departure)
  over real time rather than an instant state change. Neither freezes,
  disables, or takes over player control — both are purely atmospheric,
  layered on top of normal play. Neither introduces dialogue, cutscene
  camera control, or new characters/plot specifics; `RhaekTeaser`
  specifically reveals nothing about Rhaek beyond "a distant, reactive
  presence" (see [LORE.md](LORE.md)/[GDD.md](GDD.md) §5 — still reserved,
  uncharacterized canon).
- A scene-wide mood shift (used by `MemorySequence`) is done via a plain
  `CanvasModulate` node tweened between colors — simplest way to tint
  everything rendered without a shader or per-sprite modulation pass.
- Region scripts that need this kind of wiring (the vertical slice's
  `AvarisVerticalSlice.gd` connecting its `KillZone` to the player's
  existing damage/respawn flow) stay minimal — one `_ready()` connection,
  no accumulated logic. `TestArena.tscn` still has no root script at all;
  it doesn't need one.

## 11. Art Pass / Visual Polish

Started per [PROGRESS.md](PROGRESS.md) "Art Pass" — procedural/engine
visual polish layered onto the existing graybox geometry, explicitly
**not** new sprite/texture assets (no image-generation tool is
available). Scoped to the vertical slice scene only; `TestArena.tscn`
is untouched (though it does inherit polish from shared components like
`PlayerVeyrStep.gd` — see below).

- **Glow/bloom** — one `WorldEnvironment` on `AvarisVerticalSlice.tscn`
  (`glow_enabled = true`, `glow_intensity = 0.5`, `glow_bloom = 0.03`,
  `glow_hdr_threshold = 1.0`, `glow_blend_mode = 2` (Screen)). Deliberately
  gentle values — see the calibration note below.
- **HDR color overshoot convention**: to make specific elements catch the
  glow without affecting anything else, their `Color`/`modulate` values
  are pushed *slightly* above 1.0 on one or more channels (Godot 2D
  `CanvasItem` colors accept values >1.0 as valid HDR overshoot — this is
  intentional, not a typo, wherever you see it). Only the established
  Veyr-violet motif elements are boosted this way: the Awakening/Closing
  chamber conduits, the Memory sequence's bridges/windows, Zayr's own
  `PlayerVeyrStep.gd` trail/burst color, and `RhaekTeaser.gd`'s attention
  pulse/departure burst. Everything else (floors, walls, enemies, the
  Stage 4 backdrop spires) stays at normal ≤1.0 values and is unaffected.
  The HUD's Veyr bar was recolored to match the same violet hue but
  **kept at normal (non-glowing) brightness** — a persistent UI resource
  meter needs to stay legible, so it wasn't included in the glow-boost
  treatment even though it's part of the same visual motif.
- **Calibration matters more than it looks like it should**: the first
  attempt boosted colors by ~2.4x (e.g. the conduit's `Color(0.55, 0.4,
  1.0)` became `Color(1.3, 0.95, 2.4)`) with `glow_intensity = 0.9`. A
  screenshot (see the testing-capability note in §9) showed this
  **desaturating thin/small shapes toward white** instead of producing a
  colored glow — bloom's blur+additive stacking blows out small bright
  features disproportionately. Fixed by both reducing the color boost to
  a gentle ~1.3x overshoot (e.g. `Color(0.72, 0.53, 1.3)`) and lowering
  `glow_intensity`/`glow_bloom`. If extending this to new elements, boost
  gently and check a screenshot before assuming it looks like the numbers
  suggest — a Color three times brighter does not look three times as
  colorful, it looks white.
- **Ambient lighting (Stage B)**: Godot 2D `Light2D`s are purely
  *additive* — they don't create darkness on their own. To get real
  contrast (a lit spot standing out against a dim area), the base scene
  has to actually be dimmed first. `AvarisVerticalSlice.tscn` has exactly
  one `CanvasModulate` (owned by `MemorySequence.gd`, tweened between
  `present_tint`/`past_tint` for the Memory beat) — rather than adding a
  second one (Godot only meaningfully respects one active `CanvasModulate`
  per canvas, so two would conflict), Stage B reuses it: the scene
  instance overrides `present_tint` to a dim cool tone
  (`Color(0.5, 0.5, 0.62, 1)`) and `past_tint` to a *brighter*, richer
  violet (`Color(0.85, 0.75, 1.0, 1)`) instead of the original's similar-
  brightness color shift. This does thematic double duty for free: the
  Memory beat's present→past→present already reads as "dim fallen
  present" → "the city alive and lit" → back, reinforcing the ARCHITECTURE.md
  §10 beat with the ambient level itself, not just hue.
- `PointLight2D` needs a `texture` defining its falloff shape - there's
  no built-in default. Since no image-generation tool exists, the shared
  falloff shape is a procedural `GradientTexture2D` (`fill = 1` /
  `FILL_RADIAL`, wrapping a two-stop white→transparent `Gradient`) — a
  resource defined entirely in `.tscn` data, not a bitmap asset. Reused
  by every light in the scene (`ChamberLight`, `ShaftLight`,
  `WindowLight`, `RhaekTeaser`'s `Light`).
- Lights are placed at the same deliberate spots the vertical slice
  already cares about, not scattered decoratively: the Awakening
  chamber's `Conduit` (violet), the wall-jump shaft's orange walls (a
  warm accent reinforcing the existing "this wall is wall-jumpable"
  color language), the Memory sequence's lit windows (parented *under*
  `MemoryOnly`, so it inherits that node's existing visibility toggle for
  free - no extra wiring), and `RhaekTeaser`'s silhouette (explicitly
  toggled on/off in the script alongside the silhouette's own presence/
  departure fades, rather than left always-on).
- No shadow-casting (`LightOccluder2D`) — deliberately out of scope for
  this pass; every floor/wall would need occluder polygons authored for
  comparatively marginal benefit in a graybox scene. Lights are purely
  additive glow pools, not directional/shadowed lighting.
- **Surface gradients (Stage C)**: `Polygon2D.vertex_colors` (one Color
  per polygon vertex, interpolated across the fill) replaces flat
  `color` fills on every floor/wall/platform surface — confirmed via
  screenshot that `vertex_colors` genuinely overrides `color` for
  rendering rather than multiplying with it, so the vertex colors are
  the actual final values, not `color`-relative. Every floor/wall in
  this project uses the same 4-point axis-aligned rectangle convention
  (`polygon = PackedVector2Array(-halfW, -halfH, halfW, -halfH, halfW,
  halfH, -halfW, halfH)`, i.e. top-left/top-right/bottom-right/bottom-
  left in that order), so one `vertex_colors` array (light, light, dark,
  dark) per distinct base color applies correctly regardless of that
  node's actual size — this is what made batch-applying it across ~24
  surfaces via a handful of exact-string `replace_all` edits (one per
  base color, not per node) tractable rather than 24 individual edits.
  Gradients are gentle (top ~20% lighter, bottom ~20% darker than the
  original flat color) and read as "vaguely top-lit," working with
  Stage B's point lights rather than against them.
- **Particle VFX (Stage D)**: `assets/vfx/particle_dot.tres` — a small
  shared `GradientTexture2D` (radial, white→transparent), the particle
  equivalent of §11's light falloff texture, same reasoning (no image-
  generation tool, so procedural resource data instead of a bitmap).
  Deliberately **additive**, not a replacement: Zayr's Veyr Step and
  Rhaek's dissolve already had tested, working burst effects
  (`PlayerVeyrStep.gd`/`RhaekTeaser.gd` manually tweening a `Polygon2D`'s
  `scale`/`modulate.a` each frame, including Perfect Step's burst-size
  multiplier). Rewriting that to be fully particle-driven would have
  meant reworking already-validated gameplay-adjacent code for cosmetic
  gain — instead, a `GPUParticles2D` (`one_shot = true`,
  `explosiveness = 1.0`, short lifetime, small scale so it reads as
  "sparks" alongside the star-shaped polygon rather than "bubbles"
  competing with it) fires via `restart()` at the same moment the
  existing polygon burst starts, sharing its `global_position`. Perfect
  Step's burst-size bonus does **not** currently affect these particles
  (it's applied to the polygon burst continuously as it animates; the
  particle burst is instantaneous and already fully emitted before a
  perfect trigger could be known) — flagged as a known/accepted gap, not
  silently unhandled.
- Two ambient (continuous, non-one-shot) `GPUParticles2D` were added
  purely for atmosphere: `ChamberDust` (Awakening chamber, `Geometry`)
  and `VistaMotes` (Stage 4 reveal, `Geometry`). Both use `emission_shape
  = 1` (`BOX`) with `emission_box_extents` sized to spread across an
  area rather than emit from a single point, and `preprocess` set to
  roughly one full particle lifetime so they're already mid-cycle the
  moment the scene loads, not visibly "starting from nothing."
- **Post-processing (Stage E, final)**: `Environment` (the
  `WorldEnvironment` above) has no built-in vignette property in Godot 4,
  so `shaders/Vignette.gdshader` (a small `canvas_item` shader, screen-
  space via `SCREEN_UV` so it's resolution-independent) darkens toward
  the viewport edges. Applied via a full-screen `ColorRect` in its own
  `CanvasLayer` (`VignetteLayer`, `layer = 1`) — not a child of the world
  scene, so it always covers the viewport regardless of camera position/
  zoom. `mouse_filter = 2` (`IGNORE`) is required, not optional — a
  full-screen `Control` that blocked input would swallow every left/
  right mouse click, which are the actual attack/heavy-attack bindings
  now. `HUD.tscn`'s `CanvasLayer` was given an explicit `layer = 2`
  (previously unset/default) specifically so it reliably draws above the
  vignette rather than depending on tree-order tiebreaking between
  same-layer canvases. Also enabled the `Environment`'s `adjustment_*`
  properties for gentle global color grading (contrast 1.08, saturation
  0.92) — subtle enough to not fight the HUD's own legibility, same
  reasoning as keeping the Veyr bar's brightness un-boosted earlier.
- Calibration mattered again here: the vignette's first-pass values
  (`intensity 0.55`) crushed the corners toward black in a screenshot —
  reduced to `0.32` with a larger `radius`/`softness` for a genuinely
  subtle effect. Same lesson as the Stage A glow overshoot: check a
  screenshot before trusting the numbers.
