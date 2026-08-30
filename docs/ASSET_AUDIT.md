# Zayr — Placeholder Asset Audit

Prepared ahead of the Art Direction + Asset Production Pipeline phase.
This is a **technical audit only** — no assets sourced, generated, or
changed; no scenes or gameplay code touched; nothing about the
placeholder visuals was redesigned. Every claim below was verified by
reading the actual current `.tscn`/`.gd` files (this session), not
recalled from memory.

**The headline finding**: this project has **zero imported art or audio
assets**. `assets/audio/`, `assets/characters/`, `assets/environments/`,
and `assets/fonts/` all exist but contain only a `.gitkeep` each — no
sprite, texture, model, or sound file exists anywhere in the repo. The
only file under `assets/` is `assets/vfx/particle_dot.tres`, a
*procedural* `GradientTexture2D` (a radial white→transparent gradient
baked to a resource file, not a bitmap). Every visual in the project —
player, enemies, boss, every stage's environment, every VFX — is a flat-
color `Polygon2D`/`ColorRect`, a `PointLight2D` using that one procedural
falloff texture, or a `GPUParticles2D` also using that one texture. There
is no `AnimationPlayer`, no `AnimatedSprite2D`, no `Sprite2D`, and no
`AudioStream` assigned anywhere (`PlayerVeyrStep.gd` has a ready
`AudioStreamPlayer` + an exported `perfect_audio_cue: AudioStream = null`
hook, silent by design — see §11).

## 1. Architecture Review Summary

The project already separates "what state is this entity in" from "how
does that state look" cleanly enough that this is a genuinely favorable
starting point for an art pass, not a liability:

- **Player**: `PlayerController.gd` maintains an explicit `enum State`
  (`IDLE, RUN, JUMP, FALL, WALL_SLIDE, DASH, AIR_DASH, ATTACK_1, ATTACK_2,
  ATTACK_3, ATTACK_HEAVY, ATTACK_RANGED, ATTACK_AERIAL, CHARGING,
  ATTACK_CHARGED, VEYR_STEP, HURT, DEAD`) and a single function,
  `_update_debug_visual()`, that's the **only** place touching the
  visual (`STATE_DEBUG_COLOR` dict → `_debug_visual.color`, plus
  `_debug_visual.scale.x = movement.facing` for the facing-flip). Its own
  doc comment already says it's "safe to delete once an
  AnimationPlayer/AnimatedSprite drives visuals instead." This state
  enum is effectively a ready-made animation-state list.
- **Enemies/Boss**: `EnemyController._physics_process()` has the
  equivalent single function — a priority chain (hurt-flash white →
  stagger tint → "currently attacking" tint → base color) plus
  `visual.scale.x = ai.facing`. `BossController.gd` adds exactly one
  thing on top: swapping `_base_color` to `phase2_color` once.
- **Naming convention**: every entity (`Player`, `Enemy`, `RangedEnemy`,
  `MiniBoss`, `TestArena`'s `TrainingDummy`) has its single visual
  representation as a direct child literally named `Visual`, referenced
  via `@onready var visual: Polygon2D = $Visual`. Swapping the *node*
  under that name (e.g. to `AnimatedSprite2D`) is mechanical but not
  free — see §7.

## 2. Asset Categories

### Player

| Element | Node | Owning script | Notes |
|---|---|---|---|
| Body | `Player/Visual` (`Polygon2D`) | `PlayerController.gd` (`_update_debug_visual`) | Flat rectangle, `Color(0.55,0.75,0.95)` base, retinted per `State` via `STATE_DEBUG_COLOR`. Flipped via `scale.x`, never the root (root flip would also mirror the child `Camera2D`). |
| Attack swing shape | `Player/Hitbox/SwingVisual` (`Polygon2D`) | `PlayerCombat.gd` | One shared node reused by combo/Heavy/Aerial/Charged - repositioned, rotated, recolored, and rescaled per attack (see §3). |
| Veyr Step trail | `Player/TrailLine` (`Line2D`) | `PlayerVeyrStep.gd` | `top_level = true` - manually positioned in world space at step start/end, not attached to the player's transform. |
| Veyr Step burst shapes | `Player/DepartBurst`, `Player/ArriveBurst` (`Polygon2D`) | `PlayerVeyrStep.gd` | Same 8-point "shatter" star polygon reused for both; `top_level = true`. |

### Player animation

**None exist.** There is no `AnimationPlayer` or `AnimatedSprite2D`
anywhere in `Player.tscn`. "Animation" today is entirely: (a) instant
color swaps per `State`, (b) `Tween`-driven scale/alpha/color changes on
the flat shapes above (charge-up scaling, hit-flash, fade in/out), and
(c) the body polygon's static silhouette never changes shape regardless
of state (idle and mid-swing look identical except for tint). This is
the single biggest gap an Art Bible needs to plan for.

### Player VFX

| Effect | Nodes | Owning script | Notes |
|---|---|---|---|
| Veyr Step depart/arrive burst | `DepartBurst`/`ArriveBurst` (`Polygon2D`) + `DepartParticles`/`ArriveParticles` (`GPUParticles2D`) | `PlayerVeyrStep.gd` | Particles are *additive* to the polygon burst, not a replacement (see ARCHITECTURE.md §11). Perfect Step multiplies burst scale by `perfect_burst_scale_multiplier`. |
| Charged Attack telegraph | `SwingVisual` scale/alpha tween while charging | `PlayerCombat.gd` (`is_charging` branch) | Grows `0.7→1.5` scale, `0.35→1.0` alpha as charge builds; lands at up to `1.6×` scale on release. No separate node - reuses the attack swing shape. |
| Hitstop | `Engine.time_scale` dip (no node) | `PlayerCombat.gd` (`_apply_hitstop`), `PlayerVeyrStep.gd` (`_apply_perfect_hitstop`) | Global engine-wide slowdown, not per-entity - affects everything on screen briefly. Two independently-tuned durations/scales (normal hit vs. Perfect Step). |
| Ranged Veyr projectile | `Projectile.tscn` (see Enemies) | `PlayerRangedAttack.gd` | Recolors the shared enemy `Projectile` scene's `Visual` to `Color(0.55,0.4,1.0,1.0)` at fire time so Zayr's shot doesn't look like a copy of an enemy's. |

### Enemies

| Element | Node | Owning script | Notes |
|---|---|---|---|
| Melee enemy body | `Enemy/Visual` | `EnemyController.gd` | `Color(0.5,0.2,0.6)` base (violet). |
| Ranged enemy body | `RangedEnemy/Visual` | `EnemyController.gd` | `Color(0.3,0.6,0.8)` base (teal). |
| Melee attack swing | `Enemy/Hitbox/SwingVisual` | `EnemyAI.gd` | Same shape convention as the player's, different polygon points/color (`Color(1,0.3,0.2)`, red). |
| Projectile (shared) | `Projectile.tscn` root `Visual` | `Projectile.gd` / fired by `RangedEnemyAI.gd`, `BossAI.gd`, `PlayerRangedAttack.gd` | One scene, reused by every ranged attacker in the game (see §7 - this is the single highest-leverage shared asset). Diamond shape, base color `Color(1,0.35,0.2)`. |

### Mini-boss

| Element | Node | Owning script | Notes |
|---|---|---|---|
| Body | `MiniBoss/Visual` | `BossController.gd` (extends `EnemyController.gd`) | `Color(0.7,0.15,0.15)` base (crimson), larger than a regular enemy (69 tall vs. 46 - see §4). |
| Phase 2 shift | same node | `BossController._on_phase2_started` | Instant `_base_color` swap to `Color(0.9,0.25,0.1)`, not tweened - shows through the same hurt-flash/attacking-tint priority chain as everything else. |
| Melee swing | `MiniBoss/Hitbox/SwingVisual` | `BossAI.gd` | Own polygon (wider than a regular enemy's), `Color(1,0.4,0.15)`. |
| Ranged shot | shared `Projectile.tscn` | `BossAI._fire_projectile` | Uses the *default* projectile color (unlike the player's, which recolors it) - a boss shot currently looks identical to a regular ranged enemy's shot. |
| Boss HUD bar | `HUD/BossBar` | `HUD.gd` | Only shows within `vicinity_range` of a `"boss"`-group node; tracks health via signal. |

### Environment

Every floor/wall/platform across every scene (`TestArena.tscn`'s
`FloorA/B`, `Platform1-3`, `WallLeft/Right`, `LedgeEnd`, `DashGapFloor`,
`HighLedge`; `AvarisVerticalSlice.tscn`'s ~30 floor/wall/platform pieces
across all 7 stages) follows one convention: a `StaticBody2D` with a
`RectangleShape2D` collision shape and a child `Visual` `Polygon2D` of
the *exact same size*, filled with a flat or `vertex_colors`-gradient
color (top ~20% lighter, bottom ~20% darker - the "vaguely top-lit"
convention from the art pass, ARCHITECTURE.md §9/§C). No textures, no
tiling, no grid system - each piece is authored with bespoke
width/height per spot, though several `RectangleShape2D` **sub-
resources are reused across many instances** (`Shape_Step`, 160×24, is
the most common - used for nearly every small platform/step across
Stages 1-7 as well as `TestArena.tscn`'s `Platform1-3`).

### Background

Stage 4-7 only (`AvarisVerticalSlice.tscn`). Layered, non-collision
`Polygon2D` silhouettes under `Geometry/Backdrop` (Stage 4) and loose
under `Geometry` (Stage 5's `RuinPillarA/B`, Stage 7's `EndSpire`/
`ClosingSpire`): spires, ruin fragments, the split "Megastructure"
landmark, `FarSpireA-C`. Depth is communicated entirely through
`z_index` layering (-1 near, -2 far, -3 extreme) plus color
desaturation/alpha - there is **no parallax-scroll system**; background
elements are static world-space geometry like everything else, just
drawn behind gameplay and de-emphasized by color.

### Veyr/environment effects

| Element | Nodes | Owner | Notes |
|---|---|---|---|
| Static glowing conduits | `Conduit`/`ClosingConduit` (Ch. 1/7), `DormantConduitA/B` + `VeyrRemnant` (Stage 4), `LivingConduit` (Stage 6) | plain scene geometry / `MemorySequence.gd` | Thin rectangle `Polygon2D`s, HDR-overshoot violet colors (values >1.0, relies on `WorldEnvironment` glow - see §5). |
| Point lights | `ChamberLight`, `ShaftLight`, `WindowLight`, `ConduitLight`, `RhaekTeaser/Light` | scene-local, all `PointLight2D` | **All share one texture**: the inline `LightFalloff` `GradientTexture2D` sub-resource (radial white→transparent) defined once in `AvarisVerticalSlice.tscn` and reused by every light in the file. No shadow-casting (`LightOccluder2D`) anywhere - deliberately out of scope per ARCHITECTURE.md §9. |
| Ambient particles | `ChamberDust`, `VistaMotes` (Stage 1/4 atmosphere), `DriftFormA/B/C` (Stage 6 "inhabited motion", tween-driven position not particle-driven) | scene-local / `MemorySequence.gd` | `ChamberDust`/`VistaMotes` use `ParticleProcessMaterial`s with the shared `particle_dot.tres` texture. `DriftFormA/B/C` are **not** particles - plain `Polygon2D`s whose `position` is tweened back and forth by `MemorySequence._start_drift()`. |
| `WorldEnvironment` | `AvarisVerticalSlice.tscn` root-level | scene data only, no script | `glow_enabled=true`, `adjustment_*` (contrast/saturation nudges). The *only* place any bloom/glow happens - `TestArena.tscn` has none. |
| `CanvasModulate` | `MemorySequence/CanvasModulate` | `MemorySequence.gd` | **Exactly one exists in the whole project.** Doubles as the scene's ambient-lighting baseline (dimming the world so `PointLight2D`s read as actually lighting something) *and* the Memory beat's present/past tint shift - see §7, this is a shared resource with two jobs. |
| Vignette | `VignetteLayer/Vignette` (`ColorRect` + `Vignette.gdshader`) | scene data only | Screen-space, resolution-independent (`SCREEN_UV`-based), permanent (not a transition effect). Only in `AvarisVerticalSlice.tscn`. |

### UI

| Element | Node/Scene | Script | Notes |
|---|---|---|---|
| Health/Veyr/Boss bars | `HUD.tscn` → 3× `ResourceBar.tscn` instances | `HUD.gd`, `ResourceBar.gd` | Two stacked flat `ColorRect`s (`Background` + `Fill`), no texture, no icon, no border art, no numeric readout. `Fill.size.x` is resized directly (not a shader/`ProgressBar`). |
| End-of-slice fade + label | `EndLayer/EndFade` (`ColorRect`), `EndLayer/EndLabel` (`Label`) | `RhaekTeaser.gd` (`_close_slice`) | **The only `Label` node in the entire project** - default Godot theme/font (no custom font resource exists anywhere, confirmed by search: zero `.ttf`/`.otf`/`Theme`/`FontFile` resources in the repo). |

### Memory sequence

Covered under Environment/Background/Veyr effects above (`MemoryOnly`'s
children: `BridgeAC/CD`, `WindowA-C` + `WindowLight`, `LivingConduit` +
`ConduitLight`, `DistantFigureA-C`, `DriftFormA-C`) plus the
`CanvasModulate` tint shift. One thing specific to this sequence: the
"activation" mechanic (`MemorySequence.activation_paths`) directly
retints **existing** Stage 5 geometry (`RuinPillarA/B`) via `NodePath`,
rather than owning separate assets - an art pass replacing those pillars
with real sprites needs to either keep them tint-able (a `modulate`/
shader-param swap) or `MemorySequence.gd` needs a different activation
mechanism for that specific pair of objects.

### Rhaek teaser

`RhaekTeaser.tscn` subtree (all under the `RhaekTeaser` node in
`AvarisVerticalSlice.tscn`): `Silhouette` (`Polygon2D`, near-black
`Color(0.12,0.1,0.18)`, a 6-point tapered humanoid silhouette, ~74px
tall), `DepartBurst` (`Polygon2D`, same 8-point star shape as the
player's Veyr Step bursts - deliberately reused visual language, not
identical geometry), `Light` (`PointLight2D`, shared falloff texture),
`DepartParticles` (`GPUParticles2D`, shared `particle_dot.tres`). No
`Hitbox`, no `HealthComponent`, no `CharacterBody2D` - confirmed
structurally incapable of combat (see docs/PROGRESS.md Stage 7
enhancement testing).

### Audio/SFX

**Nothing exists.** Exactly one `AudioStreamPlayer` node in the entire
project (`Player/VeyrStep/AudioPlayer`), referenced by
`PlayerVeyrStep.gd`'s `perfect_audio_cue: AudioStream = null` export -
a ready hook, explicitly documented as silent until a stream is
assigned. No hit sounds, footsteps, ambient loops, UI sounds, or voice
of any kind exist or are referenced anywhere, including for the boss,
enemies, or any of the narrative beats (Memory, Rhaek).

### Music

**Nothing exists.** No `AudioStreamPlayer`/`AudioStreamPlayer2D` intended
for music anywhere, no music resource, no music-related code. The only
documented *intent* is prose, not implementation: `docs/PROGRESS.md`'s
Stage 6 write-up records a future audio-contrast direction (present =
sparse ambience, memory = fuller/alive, return = collapses back) as an
explicit "documentation only, no assets sourced" note per that pass's
instructions.

## 3. Technical Constraints for Future Art

### Player dimensions

- Body collision (`CollisionShape2D`, `Hurtbox/CollisionShape2D`,
  identical shape reused for both): **28×46px**, local offset `(0,-23)`
  from the `CharacterBody2D` origin - i.e. the origin is at the
  character's *feet*, the box extends straight up. Every entity in the
  project (enemies, boss, training dummy) uses this same "origin at
  feet" convention, so environment `y`-positions consistently line up
  with a standing character regardless of type.
- Attack `Hitbox` shape: **48×32px**, at local offset `(14,0)` inside
  the `Hitbox` node - the `Hitbox` node itself is repositioned per
  attack (see below), so its *effective* world position moves.

### Attack hitbox positions (all measured from the player's own origin, `facing`-relative)

| Attack | Horizontal offset | Notes |
|---|---|---|
| Combo (all 3 swings) | `hit_offset` = 26px | Shared value across all three swings. |
| Heavy Attack | `heavy_hit_offset` = 30px | |
| Aerial Attack | `aerial_hit_offset` = 26px | |
| Charged Attack | `charged_hit_offset` = 28px | |
| Any of the above while airborne + holding aim-down | rotated 90°, placed at `(0, aerial_down_offset=30)` below the player | Shared `_position_hitbox()` logic - reused by Heavy/Charged/the pre-aerial-rework combo, **not** the current dedicated Aerial Attack, which always uses its own horizontal placement. |

**This matters for animation**: attack "reach" is currently defined
entirely in code (`PlayerCombat._position_hitbox()`), not by any sprite
content. A future attack animation's visual reach should be authored to
roughly match these existing offsets, or these numbers will need
updating alongside the new art (a code change - out of scope for this
audit, flagged for planning only).

### Animation timing dependencies (exact values, all in `PlayerCombat.gd`/`BossAI.gd`/`EnemyAI.gd`/`RangedEnemyAI.gd`/`PlayerVeyrStep.gd`)

These are hard synchronization points - whatever eventually drives
visuals (`AnimationPlayer`, sprite frame events, etc.) needs its
"impact frame" to land inside the existing active window, or these
numbers need to move together with the new art:

| Action | Windup/startup | Active (hitbox open) | Recovery | Cooldown |
|---|---|---|---|---|
| Combo swing 1 | 0.08s | 0.08-0.18s | rest of 0.35s | `attack_cooldown` 0.1s after combo ends |
| Combo swing 2 | 0.07s | 0.07-0.16s | rest of 0.32s | " |
| Combo swing 3 | 0.10s | 0.10-0.24s | rest of 0.42s | " |
| Heavy Attack | 0.5s | 0.2s | 0.35s | 0.4s |
| Aerial Attack | 0.06s | 0.12s | 0.15s | 0.3s |
| Charged Attack | up to 1.0s (held, variable) | 0.15s (starts instantly on release) | 0.3s | 0.4s |
| Ranged Veyr | 0.15s (fires at end) | n/a (projectile, not a hitbox window) | - | 0.6s |
| Melee enemy attack | 0.4s | 0.15s | 0.3s | 0.6s |
| Ranged enemy attack | 0.35s (fires at end) | n/a | - | 1.1s |
| Boss melee | 0.35s (0.228s in phase 2) | 0.18s | 0.25s | 0.5s (0.325s phase 2) |
| Boss ranged | 0.4s (fires at end) | n/a | - | 1.0s (0.65s phase 2) |
| Veyr Step | teleport is instant | player invisible for `step_duration` = 0.1s | - | 0.55s |
| Normal Dash | - | `dash_duration` = 0.16s at constant velocity (`dash_distance/dash_duration` = 812.5px/s) | - | 0.2s |
| Hitstop (any landed hit) | - | 0.06s @ 5% time scale | - | - |
| Perfect Step hitstop | - | 0.05s @ 5% time scale | - | - |

### Enemy/boss dimensions

- Regular enemy (melee + ranged) body: **28×46px**, same as the player.
  Melee enemy `Hitbox`: 40×28px at 24px offset. Boss `Hitbox`: 58×40px
  at 30px offset.
- Mini-boss body: **42×69px** (taller/wider than a regular enemy),
  collision offset `(0,-34.5)` (half its own height, same "feet at
  origin" convention scaled up).
- Projectile (shared by all three ranged sources): 14×14px collision,
  travels at a constant `speed` with **no vertical aim component** -
  see the hard constraint below.

### Camera assumptions (the session's single most-repeated lesson)

Both scenes' cameras use `CameraController.gd` (smooth-follow +
directional look-ahead, `look_ahead_distance` 60px) with per-scene
`Camera2D.limit_*` overrides:

- `TestArena.tscn`: `limit_left=-50, limit_top=-100, limit_right=2780,
  limit_bottom=650`.
- `AvarisVerticalSlice.tscn`: `limit_left=-180, limit_top=-400,
  limit_right=9700, limit_bottom=720`.

**Hard-won constraint, discovered independently four separate times
this session (Stages 4, 5, 6, 7)**: placing background/narrative
geometry at a world position that looks reasonable on paper does **not**
mean it's actually visible from where the player's camera normally sits
- the visible vertical range from a ground-standing player position is
roughly 100-450px of world space *above* the player, not the full
`limit_top` allowance, unless a scene-local camera zoom-out is active
(as Stage 7's `RhaekTeaser.gd` now does, `zoom = 0.55` while Rhaek is
present). **Every properly-visible background element in this project
was only confirmed correct via an actual real-GPU screenshot, never by
trusting the coordinate math alone** (see ARCHITECTURE.md §9's
screenshot-technique note and every Stage 4-7 entry in
docs/PROGRESS.md). Any future art/composition work should budget for
the same screenshot-verification step, not skip it.

### Platform/grid dimensions

No grid/tile system exists. All placement is freeform per-instance
`position` + a `RectangleShape2D` size. The closest thing to a
recurring unit is `Shape_Step` (160×24px), reused for most small
platforms across every stage - if a tile-based art pipeline is adopted
later, this is the de facto most common existing platform footprint,
not an enforced standard.

### VFX attachment points

- **Attached to the entity's own transform** (moves/rotates/flips with
  it): the attack `Hitbox`/`SwingVisual` (repositioned per-attack by
  code, see above), enemy/boss `Hitbox`/`SwingVisual`.
- **`top_level = true` - manually positioned in world space, not
  attached**: `Player`'s `TrailLine`, `DepartBurst`, `ArriveBurst`,
  `DepartParticles`, `ArriveParticles` (all Veyr Step VFX). `RhaekTeaser`'s
  equivalents are **not** `top_level` (they're static at one world
  position the whole time, since Rhaek never moves).
- **Shared single instance reused by everything of that kind**: the
  `Projectile.tscn` scene (one asset, three different firers), the
  `LightFalloff` gradient texture (every `PointLight2D` in the project),
  `particle_dot.tres` (every `GPUParticles2D` in the project).

## 4. Safely Replaceable Without Touching Gameplay Code

These can be swapped for real art/audio as pure **content** changes -
new `.tscn`/resource data, no `.gd` edits required:

- Every `Visual` `Polygon2D`'s `color`/`vertex_colors`/`polygon` shape
  data (as long as the replacement stays the same node *type* -
  `Polygon2D` - and the same node *name*, `Visual`; see §5 for what
  happens if the node type changes).
- All background/environment `Polygon2D` silhouettes (Stage 4-7
  spires, ruins, the Megastructure, Memory's bridges/windows/figures) -
  none of these have collision, none are referenced by gameplay logic
  beyond `MemorySequence`'s `activation_paths` color-tween (which reads
  `.color`, a property any `Polygon2D` still has).
- `ResourceBar`'s `Background`/`Fill` `ColorRect`s - purely visual,
  `ResourceBar.gd` only ever touches `.color` and `.size`.
- `particle_dot.tres` and `LightFalloff` (the two shared procedural
  textures) - any texture of appropriate shape can replace them as
  drop-in resource swaps, referenced by path from many `.tscn` files.
- Adding an `AudioStream` to `PlayerVeyrStep.gd`'s `perfect_audio_cue`
  export, or to the currently-empty `AudioStreamPlayer` node - the hook
  already exists and is silent by design until filled.
- The `EndLabel`'s font/theme (currently default Godot theme) - a
  `Theme` resource or `theme_override_font` can be assigned without
  touching `RhaekTeaser.gd`.
- `Vignette.gdshader`'s tunable uniforms (`intensity`/`radius`/
  `softness`) and the `WorldEnvironment`'s glow/adjustment values - both
  are scene data, not script-driven.

## 5. Where Replacing Placeholder Art Could Accidentally Affect Gameplay

Flagged for the Art Bible/pipeline planning - **none of these were
touched during this audit**, they're risk notes only:

1. **Changing a `Visual` node's *type*** (e.g. `Polygon2D` →
   `AnimatedSprite2D`/`Sprite2D`) requires a matching one-line type
   change in the owning script's `@onready var visual: Polygon2D = ...`
   annotation (`EnemyController.gd`, `PlayerController.gd` via
   `_debug_visual`, `BossController.gd` inherits `EnemyController`'s).
   `Polygon2D`-specific properties (`.color`, `.vertex_colors`,
   `.polygon`) don't exist on `Sprite2D`/`AnimatedSprite2D` - the
   existing tint/hurt-flash/stagger-tint logic would need to become
   `.modulate` assignments instead, and any animation-driven visual
   needs a `play()`/state-name call added somewhere in that same
   function. This is mechanical, not a redesign, but it *is* a code
   change - not something to do without an explicit go-ahead.
2. **The player's attack reach is code-defined, not art-defined** (see
   §3's hitbox offset table). New attack art with a visually different
   reach than the current placeholder swing shapes will *look*
   mismatched from the actual (unchanged) hitbox unless the numbers are
   updated to match, or the new art is authored to match the existing
   numbers.
3. **`Projectile.tscn` is shared by three different attackers** (player
   Ranged Veyr, `RangedEnemyAI`, `BossAI`) with **no vertical aim** at
   all (see COMBAT.md §19) - a real sprite/animation for it needs to
   either respect that constraint (purely horizontal flight) or the
   underlying `direction: float` would need to become a `Vector2`,
   updating every firing call site - a real, project-wide change, well
   beyond an art swap.
4. **The `CanvasModulate` is a single shared resource with two
   simultaneous jobs** (ambient lighting baseline *and* the Memory
   beat's present/past tint) - any lighting-related art change that
   wants a second independent tint layer needs a different mechanism;
   Godot only meaningfully respects one active `CanvasModulate` per
   canvas (already noted in ARCHITECTURE.md §9).
5. **`MemorySequence.activation_paths` reads `.color` directly off
   `RuinPillarA`/`RuinPillarB`** by `NodePath` - if those become sprites
   with a texture instead of a flat-color polygon, a plain `.color`
   tween may not produce a visible "lighting up" effect the same way
   (depends on the sprite's own alpha/luminosance); may need to become
   a `.modulate` tween or a shader parameter instead.
6. **HDR-overshoot colors** (values >1.0, e.g. `Color(1.1,1.04,1.3)`)
   are load-bearing for the `WorldEnvironment` bloom to actually catch
   Veyr-related elements (conduits, Rhaek's departure burst, Perfect
   Step's trail tint) - real textures/sprites intended to glow the same
   way need either an equivalently boosted `.modulate` or a dedicated
   glow/emission approach; a plain 0-1 range texture won't bloom.
7. **Collision dimensions must not be silently changed by new art.** If
   a new player/enemy sprite's visual silhouette is authored
   noticeably larger or smaller than the current 28×46/42×69 boxes,
   gameplay fairness (what a hitbox visually "should" reach) shifts
   even though no collision code changed - standard practice is to keep
   sprite art roughly matched to (or intentionally slightly larger
   than, for readability) the existing collision box, not the reverse.
8. **Every properly-authored background element in this project needed
   a real screenshot to confirm visibility** (§3, Camera assumptions) -
   new background art dropped in at "reasonable-looking" coordinates
   without a render check has a demonstrated, repeated history of being
   invisible in actual play in this specific project.

## 6. Summary for the Art Bible

- Nothing to source or generate yet - this document is inputs for that
  decision, not a request for it.
- The **cleanest, lowest-risk starting point** is the player's own
  visual: `PlayerController._update_debug_visual()` is a single,
  already-isolated function driven by an already-complete `State` enum
  - replacing it with an `AnimationPlayer`/`AnimatedSprite2D` state
  machine is closer to "plug in" than "redesign," once the Art Bible
  defines what each state should actually look like.
- The **highest-leverage shared asset** is `Projectile.tscn` - one
  sprite/animation would visually upgrade the player's Ranged Veyr, both
  enemy types, and the boss's ranged attack simultaneously (subject to
  constraint #3 above).
- **Audio is a completely blank slate** with exactly one ready hook
  (Perfect Step's cue) - there's no existing audio architecture to
  preserve or work around, which simplifies that half of the pipeline
  considerably compared to the visual half.
- The camera-visibility lesson (§3) should probably become a standing
  process step for whoever composes background art next, not just a
  note in this document.
