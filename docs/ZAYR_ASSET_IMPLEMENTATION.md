# Zayr Gameplay Asset v0.1 — Technical Implementation Planning

> **⚠ PIPELINE CHANGE (superseding notice, see "ZAYR ANIMATEDSPRITE2D
> PIPELINE" section near the end of this document):** the
> `Skeleton2D`/`Bone2D` cutout-rig approach described throughout most of
> this document (§3-14, and the Phase A/B implementation logs below) is
> **SUPERSEDED**. Zayr's approved v0.1 animation method is now
> **full-body frame-based animation via `AnimatedSprite2D`**, not a
> bone-driven rig. Everything below this notice is kept as historical
> record (the reasoning, the real dimension/timing data, and the Phase
> A/B implementation results are all still accurate and still useful),
> but the *rig/Skeleton2D-specific* sections (§3-5, §13-14 in
> particular) no longer describe the plan going forward. The 13-piece
> body-part art produced for that rig (`assets/characters/zayr/base/`)
> is retained as **reference material only** - it is no longer wired
> into `Player.tscn`. See the new pipeline section for the current
> architecture and status.

**Status: planning document only. Nothing in this document has been
implemented.** No scene, script, or gameplay value was changed while
producing it — every number below was read directly from the current
project (`Player.tscn` and its component scripts), not inferred or
carried over from concept art. Where this document proposes something
new (hierarchy, rig, phases), it's explicitly marked **PROPOSED**;
everything else is **CURRENT** (already true today) or a direct
quote/derivation from [ART_BIBLE.md](ART_BIBLE.md) /
[ASSET_AUDIT.md](ASSET_AUDIT.md).

Companion documents: [ART_BIBLE.md](ART_BIBLE.md) (approved visual
direction), [ASSET_AUDIT.md](ASSET_AUDIT.md) (full placeholder catalog
and constraint list — this document narrows that one down to just
Zayr and adds the technical implementation plan), [COMBAT.md](COMBAT.md)
(gameplay timing source of truth).

---

## 1. Current Player — Inspected Architecture

`scenes/player/Player.tscn`, root `Player` (`CharacterBody2D`,
`collision_layer=2`, `collision_mask=1`, group `"player"`):

```
Player (CharacterBody2D)
├── CollisionShape2D              — 28×46 RectangleShape2D, offset (0,-23)
├── Visual (Polygon2D)            — THE current placeholder (see below)
├── Movement (Node)               — PlayerMovement.gd
├── Camera2D                      — CameraController.gd
├── HealthComponent (Node)        — HealthComponent.gd
├── VeyrComponent (Node)          — VeyrComponent.gd
├── Hurtbox (Area2D)               — Hurtbox.gd
│   └── CollisionShape2D          — same 28×46 shape, offset (0,-23)
├── Combat (Node)                 — PlayerCombat.gd
├── RangedAttack (Node)           — PlayerRangedAttack.gd
├── Hitbox (Area2D)               — Hitbox.gd, offset (26,-23), shared by combo/Heavy/Aerial/Charged
│   ├── CollisionShape2D          — 48×32 RectangleShape2D, offset (14,0)
│   └── SwingVisual (Polygon2D)   — placeholder attack shape, hidden by default
├── VeyrStep (Node)               — PlayerVeyrStep.gd
│   └── AudioPlayer (AudioStreamPlayer) — unassigned, silent
├── TrailLine (Line2D)            — top_level=true (world-space, not parented visually)
├── DepartBurst (Polygon2D)       — top_level=true
├── ArriveBurst (Polygon2D)       — top_level=true
├── DepartParticles (GPUParticles2D) — top_level=true
└── ArriveParticles (GPUParticles2D) — top_level=true
```

**The current placeholder** is `Player/Visual`: a flat `Polygon2D`,
`Color(0.55, 0.75, 0.95)`, a 28×46 rectangle (`(-14,-46, 14,-46, 14,0,
-14,0)`) — i.e. it exactly matches the collision box's footprint, no
visual overhang.

### Exactly which code references `Visual`

Only one place: `scripts/player/PlayerController.gd`.

```gdscript
@onready var _debug_visual: Polygon2D = $Visual
...
func _update_debug_visual() -> void:
	if not _debug_visual:
		return
	_debug_visual.color = STATE_DEBUG_COLOR.get(state, Color.WHITE)
	_debug_visual.scale.x = movement.facing
```

That's the entire surface area. No other script anywhere in the project
touches `Player/Visual`. `_update_debug_visual()` is called once per
physics frame from `PlayerController._physics_process()`, right after
`_update_state()` recomputes `state` from every component's flags
(`combat.is_attacking`, `veyr_step.is_stepping`, `movement.is_dashing`,
etc.). This is the **only** integration point the current placeholder
uses, and per its own doc comment it's explicitly designed to be
deleted once a real animation system exists.

`SwingVisual` (the attack shape) is touched only by `PlayerCombat.gd` —
`.visible`, `.color`, `.scale`, `.modulate.a` — one write site per
attack type (`_start_swing`, `_start_heavy_attack`, `_start_aerial_attack`,
`_start_charge`/`_release_charge`).

The Veyr Step VFX nodes (`TrailLine`, `DepartBurst`, `ArriveBurst`,
particles) are touched only by `PlayerVeyrStep.gd`.

**No other script reads or writes any visual property of the player.**
Gameplay logic (`PlayerMovement`, `PlayerCombat`, `PlayerVeyrStep`,
`PlayerRangedAttack`, `HealthComponent`, `VeyrComponent`) never queries
anything from `Visual`/`SwingVisual` — the data flow is one-directional
(gameplay state → visual), confirmed by reading every script, not
assumed.

---

## 2. Gameplay-Authoritative Dimensions

All values below are read directly from `Player.tscn` and the scripts
that own them — cross-checked against [ASSET_AUDIT.md](ASSET_AUDIT.md)
§3, not re-derived independently. **These remain authoritative — this
document proposes no changes to any of them.**

| Quantity | Value | Source |
|---|---|---|
| Player collision (body + Hurtbox) | 28×46px, `RectangleShape2D` | `Player.tscn` |
| Collision/Hurtbox local offset | `(0, -23)` from `CharacterBody2D` origin | `Player.tscn` |
| Player origin / ground contact point | The `CharacterBody2D`'s own origin `(0,0)` — every floor in the project is positioned so its top surface lines up with this point when standing (confirmed convention across `TestArena.tscn` and every `AvarisVerticalSlice.tscn` stage) | `Player.tscn` + every level scene |
| Current placeholder visual size | 28×46px, exactly matches collision (no overhang) | `Player.tscn` |
| Attack `Hitbox` node's own local offset | `(26, -23)` (its resting/scene-default position — repositioned live per attack, see below) | `Player.tscn` |
| `Hitbox`'s `CollisionShape2D` | 48×32px, local offset `(14, 0)` inside the `Hitbox` node | `Player.tscn` |
| Combo hit offset (all 3 swings) | `hit_offset = 26.0` | `PlayerCombat.gd` |
| Heavy Attack hit offset | `heavy_hit_offset = 30.0` | `PlayerCombat.gd` |
| Aerial Attack hit offset | `aerial_hit_offset = 26.0` | `PlayerCombat.gd` |
| Charged Attack hit offset | `charged_hit_offset = 28.0` | `PlayerCombat.gd` |
| Aerial-down variant offset (Heavy/Charged/pre-rework combo only) | `Vector2(0, aerial_down_offset=30.0)` below the player, `Hitbox` rotated 90° | `PlayerCombat.gd` `_position_hitbox()` |
| Ranged Veyr projectile spawn point | `muzzle_offset = Vector2(26.0, -23.0)` from player origin, facing-relative | `PlayerRangedAttack.gd` |
| Veyr Step origin/reference position | No separate reference node — `PlayerVeyrStep._do_step()` reads `body.global_position` directly (the same `CharacterBody2D` origin as everything else) and writes the same field after the safety-clamped teleport. `TrailLine`/bursts are positioned from that same origin, `top_level=true` so they don't inherit the body's own transform. | `PlayerVeyrStep.gd` |
| Camera relationship to player | `Camera2D` is a **direct child** of `Player`, default `zoom = (1,1)`, `position_smoothing_speed = 8.0` (scene override), plus `CameraController.gd`'s own `look_ahead_distance = 60.0` offset (not a position override — added via `offset`, so it doesn't move the actual tracked position) | `Player.tscn`, `CameraController.gd` |
| Facing-direction implementation | `PlayerMovement.facing: float` (`1.0`/`-1.0`), updated from `move_input`; consumed today as `_debug_visual.scale.x = movement.facing` (a **horizontal mirror**, not a separate left/right asset) | `PlayerMovement.gd`, `PlayerController.gd` |

No dimension in this table was inferred from the concept sheets — every
one is a literal value already live in the shipped vertical slice.

---

## 3. Proposed Player Visual Hierarchy (PROPOSED)

```
Player (CharacterBody2D)                    — unchanged, gameplay-owned
├── [existing gameplay components, unchanged: Movement, Camera2D,
│    HealthComponent, VeyrComponent, Hurtbox, Combat, RangedAttack,
│    Hitbox, VeyrStep]
│
└── VisualRoot (Node2D)                     — NEW, replaces "Visual"/"SwingVisual" as the integration point
	 ├── CharacterRig (Node2D)
	 │    ├── Skeleton2D
	 │    │    └── Bone2D chain (see §5)
	 │    └── [body/clothing Sprite2D layers, parented under their bones]
	 │
	 ├── WeaponManifestation (Node2D)       — Veyr Edge, see §9. Empty/hidden at rest.
	 ├── JinnFireLayer (Node2D)             — see §10. Independent of CharacterRig.
	 ├── VeyrLayer (Node2D)                 — Perfect/ordinary distinctions, ambient Veyr accents
	 ├── AbilityVFX (Node2D)                — Veyr Step fragmentation/reconstruction, see §11
	 └── DamageVFX (Node2D)                 — hurt/low-health/defeat exposure layer
```

**Why this shape, specifically for this project** (not just because the
brief's example looked reasonable): the current architecture already
proves the gameplay controller can be 100% ignorant of how the visual
is built — `PlayerController.gd` only ever calls one function
(`_update_debug_visual()`, today; `_update_visual()` under this plan)
and never inspects the visual tree's contents. `VisualRoot` keeps that
property exactly as-is: gameplay scripts continue driving state
(flags/timers/signals), and everything under `VisualRoot` reacts to
that state without gameplay code needing to know the rig exists. This
also directly answers §9/§10/§11's requirement that the weapon, Jinn
Fire, and Veyr layers be *independent* of the character rig proper —
they're siblings under `VisualRoot`, not nested inside `CharacterRig`,
specifically so a rig change never requires touching them and vice
versa.

`SwingVisual` and the current Veyr Step VFX nodes (`TrailLine`,
`DepartBurst`, etc.) map onto `WeaponManifestation` and `AbilityVFX`
respectively under this plan — not deleted concepts, relocated/renamed
ones.

---

## 4. Rig / Layer Breakdown (PROPOSED)

Minimum useful separation for a 46px-tall on-screen character (see §12
for why that number caps how much segmentation is actually worth it).
Marked by treatment:

| Piece | Treatment | Notes |
|---|---|---|
| Head | bone-driven | needed for the "face stays visible and expressive" rule (ART_BIBLE.md §5) |
| Hair | bone-driven + secondary animation | one simple secondary-motion chain is enough at this scale; not a full physics rig |
| Neck | bone-driven (part of head/torso chain, not a separate visible piece) | |
| Torso/chest | bone-driven | |
| Pelvis | bone-driven, **root anchor** — see §5 | |
| Upper arms | bone-driven | |
| Forearms | bone-driven | needed separately from upper arms for the Veyr Edge attach point (§9) and for combat pose readability |
| Hands | bone-driven, minimal detail | at 46-90px on-screen, individual fingers are very unlikely to read — treat as a simple shape, not a segmented hand |
| Thighs | bone-driven | |
| Lower legs | bone-driven | |
| Feet | bone-driven, minimal detail | same reasoning as hands |
| Front cloth | secondary animation (simple pendulum/lag off the pelvis or chest bone) | supports "damaged elegance/asymmetry" without a full cloth sim |
| Rear cloth | secondary animation, same as above | |
| Shoulder material | **sprite-swap candidate**, not bone-driven | if it's meant to show wear/damage discretely rather than deform, swapping is cheaper than rigging |
| Damaged/asymmetric pieces | **VFX, not character texture** | exposed-fire fissures (ART_BIBLE.md §2) belong in `JinnFireLayer`/`DamageVFX`, not baked into the body sprite — this is what makes "low health exposes more fire" achievable without repainting the character |

**Do not over-segment** beyond this list. In particular: no separate
finger/toe bones, no per-strand hair bones, no separate bones for small
accessory geometry — none of it will be legible at the confirmed
on-screen scale (§12), and every extra bone is extra animation-authoring
cost for zero visible return at v0.1.

---

## 5. Pivot / Bone Plan (PROPOSED)

```
Root (matches CharacterBody2D origin — ground contact point, (0,0))
└── Pelvis                         — primary root bone for the visible rig
	 ├── Spine/Chest
	 │    ├── Neck → Head
	 │    ├── Shoulder.L → UpperArm.L → Forearm.L → Hand.L
	 │    └── Shoulder.R → UpperArm.R → Forearm.R → Hand.R
	 ├── Hip.L → Thigh.L → Shin.L → Foot.L
	 └── Hip.R → Thigh.R → Shin.R → Foot.R
```

**Root-to-collision relationship**: the rig's `Root`/`Skeleton2D` origin
must sit at exactly the same point the `CharacterBody2D` already treats
as ground contact — `(0,0)` in player-local space, which is the bottom
edge of the existing 28×46 collision box (`CollisionShape2D` offset
`(0,-23)` means the box spans local Y `[-46, 0]`, so Y=0 is already the
feet line). `VisualRoot` should **not** have its own offset — it sits at
`(0,0)` on the `Player` node, so the rig's `Pelvis` (and everything
above it) is positioned entirely by the rig's own bone chain, not by an
extra transform layered on top. This is what prevents the rig from
visually sliding relative to collision as the character moves — the
two share one coordinate origin by construction, not by tuning.

Pelvis (not Root) is the practical animation-authoring root because
that's where weight shift/hip motion for locomotion actually
originates; `Root`/`Skeleton2D`'s node transform stays fixed at the
ground-contact point as the actual anchor.

---

## 6. Facing Direction (PROPOSED)

**Current method (confirmed)**: `_debug_visual.scale.x = movement.facing`
— a horizontal mirror of the single placeholder polygon. The existing
code comment in `PlayerController.gd` already explains *why* it flips
only the visual and not the `CharacterBody2D` root: "flipping the
root's scale would also mirror the child `Camera2D`'s view."

**Recommendation: keep the same strategy, moved one level down** — flip
`VisualRoot.scale.x` (not `Skeleton2D` individually, not the `Player`
root). This is the simplest robust option and it's a direct continuation
of a pattern already proven correct in this exact project:

- Flipping `VisualRoot` mirrors `CharacterRig`, `WeaponManifestation`,
  `JinnFireLayer`, `VeyrLayer`, `AbilityVFX`, and `DamageVFX` together,
  in one operation, guaranteeing they never desync in facing.
- `Camera2D` stays unaffected (it's a sibling of `VisualRoot`, not a
  descendant), exactly preserving the reason the current code avoids
  flipping the `Player` root.
- No separate left/right art needed for the general case.

**Selective non-flipped VFX**: some effects should visually *not* mirror
even though the character does — e.g. `JinnFireLayer`/`AbilityVFX`
elements that read as ambient/undirected energy rather than part of the
character's pose. Godot supports this per-node via `top_level = true`
(already the exact mechanism the current Veyr Step trail/bursts use to
stay in world space regardless of the player's own transform) — any
node under `VisualRoot` that needs to ignore the flip can opt out this
way without restructuring the tree.

**Flag: asymmetric design vs. mirroring.** ART_BIBLE.md §5 explicitly
calls for "asymmetry" and "damaged elegance" as part of Zayr's approved
visual character, and §2 calls for "subtle fissures" exposing Jinn Fire
underneath. If a specific asymmetric detail (a scar, an exposed-fire
fissure, a damaged shoulder piece) is authored on only one side of the
body, a horizontal mirror flip will put it on the *wrong* side whenever
Zayr faces left instead of right — the damage would appear to switch
sides depending on which way the player is walking, which reads as a
bug, not a character trait. This needs an explicit decision during the
Production Sheet stage: either (a) keep asymmetric damage subtle enough
that it doesn't matter which side it's on, (b) put damage
details in `DamageVFX`/`JinnFireLayer` (independently flip-controlled
per the paragraph above, so they can be pinned to a specific side
regardless of facing), or (c) author true separate left/right art for
whichever specific pieces need to stay fixed-side. Not resolved here —
flagged for the Production Sheet.

---

## 7. Animation Map (PROPOSED mapping; state names are CURRENT)

Every row maps an already-existing gameplay state/flag to a proposed
animation. "Existing state source" cites the exact field this session
verified drives that behavior today.

### Locomotion

| Animation | Existing state source | Loop? | Notes |
|---|---|---|---|
| Idle | `State.IDLE` | loop | |
| Run | `State.RUN` (`move_input != 0 and \|velocity.x\| > 1.0`) | loop | |
| Jump | `State.JUMP` (`velocity.y < 0`, airborne) | one-shot into apex/fall | |
| Apex | *(no dedicated state today — inferred from `velocity.y` crossing zero while airborne)* | one-shot/blend | not a distinct `State` value now; a visual-only refinement, needs a transition rule, not a new gameplay flag |
| Fall | `State.FALL` (`velocity.y >= 0`, airborne) | loop | |
| Landing | *(no dedicated state — `is_on_floor()` transition from FALL)* | one-shot | needs a visual-layer transition detector (edge-triggered on landing), not a new gameplay state |
| Wall slide | `State.WALL_SLIDE` (`movement.is_wall_sliding`) | loop | |
| Wall jump | drives `State.JUMP` via `movement.just_wall_jumped` (one physics-frame pulse) | one-shot | the pulse is only true for a single frame — a visual-layer latch is needed to hold the "wall jump" animation choice for its own duration rather than immediately falling back to generic JUMP |
| Dash / Air Dash | `State.DASH` / `State.AIR_DASH` (`movement.is_dashing`, `dash_is_air`) | one-shot, `dash_duration = 0.16s` | very short — see §8 |

### Combat

| Animation | Existing state source | Notes |
|---|---|---|
| Light attack 1/2/3 | `State.ATTACK_1/2/3` (`combat.combo_index`) | 3 distinct swings, distinct existing durations — see §8 |
| Heavy | `State.ATTACK_HEAVY` | long windup (0.5s) — see §8 |
| Aerial | `State.ATTACK_AERIAL` | very short windup (0.06s) — flagged in §8 as visually difficult |
| Charged start | `State.CHARGING` begins | |
| Charged loop | `State.CHARGING` held (`combat._charge_timer` rising, `charge_max_time = 1.0s`) | variable-length hold, needs a loopable or scrubbable animation, not a fixed one-shot |
| Charged release | `State.ATTACK_CHARGED` | damage/visual scale already lerp from a minimum to maximum by hold duration (`combat._release_charge()`) — see §9 |
| Ranged Veyr | `State.ATTACK_RANGED` | short windup (0.15s), fires a projectile — see §9's Veyr Edge note on whether Ranged Veyr should reuse the same manifestation system |

### Ability

| Animation | Existing state source | Notes |
|---|---|---|
| Veyr Step departure | `State.VEYR_STEP` begins (`veyr_step.is_stepping` true) | current placeholder hides the character (`visual.visible=false`) for the whole `step_duration=0.1s` window — see §11 |
| Veyr Step arrival | end of the same `is_stepping` window | |
| Perfect Step success | `veyr_step._perfect_triggered_this_step` becomes true (mid-step) | reuses the Veyr Step architecture with a distinct visual treatment, not a separate state — see §11 |

### Damage

| Animation | Existing state source | Notes |
|---|---|---|
| Hurt | `State.HURT` (`PlayerController._is_hurt`, `hurt_duration = 0.35s`) | |
| Knockback | same window as Hurt — velocity is set directly (`knockback_force_x/y`), not a separate flag | the *visual* of being knocked back should track actual `velocity`, not a separate gameplay signal — none exists to add one |
| Recovery | end of `_is_hurt` window, returning to normal state | transition, not a distinct gameplay flag today |
| Gameplay defeat | `State.DEAD` (`HealthComponent.died` → `PlayerController._on_died()`, `RESPAWN_DELAY = 1.2s`) | |

**Needing explicit VFX events** (not just a state color/pose, per the
production direction that not every effect belongs inside the rig):
attack windup→active transitions (Veyr Edge manifestation appearing),
attack end (manifestation collapsing), Charged Attack release (burst
scaled by charge %), Ranged Veyr fire (projectile spawn/muzzle flash),
Veyr Step departure/arrival (fragmentation burst — already exists as
`DepartBurst`/`ArriveBurst`), Perfect Step trigger (existing burst-scale
multiplier `perfect_burst_scale_multiplier`), low-health Jinn Fire
exposure (continuous, driven by `HealthComponent.health_changed`, no
existing dedicated "low health" signal — see §10), and gameplay defeat
(Jinn Fire destabilization per ART_BIBLE.md's DamageVFX intent).

---

## 8. Gameplay Timing Integration (values are CURRENT, read from the live scripts)

Per attack, windup / active / recovery, all in `PlayerCombat.gd` unless
noted. **These are authoritative and this document proposes no changes
to any of them** — animation must fit these windows, not the reverse.

| Action | Windup | Active (hitbox open) | Recovery | Total | Cooldown after |
|---|---|---|---|---|---|
| Combo swing 1 | 0.08s | 0.08→0.18s (0.10s) | remainder of 0.35s | 0.35s | 0.1s (after combo ends) |
| Combo swing 2 | 0.07s | 0.07→0.16s (0.09s) | remainder of 0.32s | 0.32s | " |
| Combo swing 3 | 0.10s | 0.10→0.24s (0.14s) | remainder of 0.42s | 0.42s | " |
| Heavy Attack | 0.5s | 0.2s | 0.35s | 1.05s | 0.4s |
| Aerial Attack | **0.06s** | 0.12s | 0.15s | 0.33s | 0.3s |
| Charged Attack | up to 1.0s (held, player-controlled) | 0.15s (starts instantly on release) | 0.3s | variable + 0.45s | 0.4s |
| Ranged Veyr | 0.15s (fires at end) | — (projectile, not a hitbox window) | — | 0.15s + travel | 0.6s |
| Veyr Step | — (instant teleport) | `step_duration = 0.1s` (invulnerable + hidden window) | — | 0.1s | `step_cooldown = 0.55s` |
| Perfect Step | triggered within `perfect_detection_window = 0.1s` of step start | — | — | — | shares Veyr Step's cooldown |
| Normal Dash | — | `dash_duration = 0.16s` (constant velocity) | — | 0.16s | `dash_cooldown = 0.2s` |
| Hitstop (any landed melee hit) | — | `hitstop_duration = 0.06s` @ `hitstop_time_scale = 0.05` | — | — | — |
| Perfect Step hitstop | — | `perfect_hitstop_duration = 0.05s` @ `0.05` scale | — | — | — |
| Hurt / knockback | — | `hurt_duration = 0.35s` | — | 0.35s | — |
| Gameplay defeat | — | `RESPAWN_DELAY = 1.2s` before respawn | — | 1.2s | — |

### Gameplay event → animation phase → VFX phase mapping (PROPOSED)

For every attack in the table: **windup** = manifestation animating in
(Veyr Edge geometry assembling, per §9) + character wind-up pose;
**active** = manifestation held at full form, hitbox is genuinely live
during exactly this window (must match, since the *code* — not the
animation — decides when damage can land); **recovery** = manifestation
collapsing/dissolving + character recovery pose. Hitstop (0.06s/0.05s
scale) should read as a freeze-frame layered on top of whichever phase
the hit landed in, not a separate animation state.

### Timing flagged as visually difficult

- **Aerial Attack's 0.06s windup** is extremely short — at 60fps that's
  ~3-4 physics frames before the hitbox opens. A hand-authored "wind-up"
  pose is unlikely to be perceptible in that window; the Production
  Sheet should probably treat Aerial Attack's manifestation as appearing
  almost instantly (a fast snap-in) rather than budgeting for a
  readable windup pose, or accept that the windup is felt more than seen.
- **Charged Attack's variable hold** (0 to 1.0s, entirely player-
  controlled by how long the button is held) needs either a loopable
  "charging" animation cycle or a scrub-driven animation keyed to
  `combat._charge_timer / combat.charge_max_time` (the same ratio the
  *current* placeholder already uses for its scale/alpha lerp) — a fixed-
  length one-shot won't work here, since release can happen at any
  moment.
- **Combo swing 1/2's active windows are ~0.09-0.10s each** — tight but
  not unusually so for an action game; still worth the Production Sheet
  budgeting real time to iterate on, since a manifestation that
  "pops" rather than reads as a deliberate strike would undercut the
  Veyr Edge concept.
- **Hitstop is global** (`Engine.time_scale`, not per-entity) — any
  animation/VFX with its own internal timers (e.g. a `Tween` not driven
  through the scaled process loop) needs to be time-scale-aware or it
  will visually desync from everything else during the freeze-frame.

---

## 9. Veyr Edge Architecture (PROPOSED)

Confirmed current behavior: `PlayerCombat.gd` never creates or destroys
a weapon node — it repositions/recolors/rescales one shared `Hitbox` +
`SwingVisual` pair for every attack type. There is no "idle held weapon"
concept anywhere in the current implementation, which already matches
ART_BIBLE.md §6's "neutral state: empty hand."

**Proposed representation**: `WeaponManifestation` (see §3), a sibling
of `CharacterRig`, not a child of the hand/arm bone — but **attached to**
the forearm/hand bone's transform each frame (or via a Godot
`RemoteTransform2D`/manual transform copy from `Bone2D.Hand`), so it
visually follows the arm through the swing without being a rendering
child of the skeleton. This split (attached-to but not owned-by) is
what allows different manifestation geometry per attack type without
the character rig itself needing per-attack variants.

- **Attachment point**: the `Hand`/`Forearm` bone from §5. The
  *existing* `Hitbox` node's own local offset (26-30px from origin,
  varying per attack per §2's table) should inform where the hand bone
  physically ends up in each attack pose — the manifestation's visual
  reach and the actual (unchanged) hitbox reach should agree, so the
  attack doesn't visually promise more/less range than it has.
- **Per-attack shape**: a data-driven set (e.g. one manifestation
  "look" per attack, selected by the same `State`/attack-kind value
  already driving everything else) rather than one geometry with
  parameters — light/Heavy/Aerial/Charged read as genuinely different
  configurations per ART_BIBLE.md §6, not one shape recolored.
- **Manifest/collapse timing**: keyed directly to each attack's
  windup/recovery windows from §8 — appears during windup, fully formed
  during active, collapses during recovery. This is a straightforward
  reskin of what `PlayerCombat.gd` already does today (it already
  toggles `SwingVisual.visible`/`modulate.a` on exactly this timing) —
  the manifestation system takes over that same responsibility, doesn't
  add a new one.
- **Ranged Veyr**: currently fires the shared `Projectile.tscn` (no
  manifestation at all — the "weapon" is the projectile itself). Worth
  an explicit Production Sheet decision: does Ranged Veyr get a brief
  hand-manifestation before firing (consistent with the melee attacks),
  or does it stay projectile-only (consistent with it being
  architecturally a different primitive — see ASSET_AUDIT.md §5 risk
  about `Projectile.tscn` being shared across three different firers)?
  Not resolved here.

---

## 10. Jinn Fire Architecture (PROPOSED)

Must layer independently from normal character art (ART_BIBLE.md §2:
"subtle fissures... emotional intensity... power usage... Veyr
interaction... destabilization... damaged physical structure" — all
*situational*, not a permanent state).

**Proposed**: `JinnFireLayer` (§3), a sibling of `CharacterRig`. Two
practical sub-approaches, not mutually exclusive:

1. **Attached overlay pieces** — small dedicated VFX nodes positioned at
   specific attach points (matching wherever "fissures/wounds" are
   authored on the character, per the Production Sheet), toggled/faded
   by gameplay signals. Simplest, most controllable, no shader
   requirement — appropriate for v0.1 given the "no shaders yet"
   instruction.
2. **A modulate/visibility-driven mask approach** (e.g. a fire-texture
   layer with an alpha mask matching where fissures should show) —
   more scalable if the number of exposure states grows, but implies
   texture/shader work beyond this planning pass's scope.

**Recommendation for v0.1**: start with (1) — discrete overlay pieces —
since it needs no shader work and every trigger below already has a
concrete existing gameplay signal to drive it:

| Exposure state | Existing gameplay signal to drive it |
|---|---|
| Subtle idle exposure | none needed to be event-driven — a constant low-intensity idle effect, always-on at low opacity |
| Attack exertion | attack windup/active phases (§8's table — same signal already driving `WeaponManifestation`) |
| Damage exposure | `HealthComponent.damaged` signal (already exists, already used by `EnemyController`/`TrainingDummy` for hit-flash) |
| Low health | **no existing dedicated signal** — `HealthComponent.health_changed(current, max)` exists and carries enough data for the *visual* layer to compute its own ratio/threshold itself; no gameplay code change needed, just a subscriber |
| Charged Attack | `combat.is_charging`/`_charge_timer` ratio (same value already driving the placeholder's own scale/alpha lerp) |
| Veyr Step | `veyr_step.is_stepping` (see §11 — this is where Jinn Fire and Veyr geometry are meant to appear together, per ART_BIBLE.md §7's sequence) |
| Gameplay defeat | `HealthComponent.died` signal (already exists, already used by `PlayerController._on_died()`) |

Every trigger in this table already exists as a signal or a readable
value in the current codebase — this layer can be built entirely by
*subscribing* to existing gameplay events, with zero new gameplay code
required.

---

## 11. Veyr Step Architecture (PROPOSED)

**The existing gameplay implementation remains fully authoritative.**
`PlayerVeyrStep._do_step()` already does the actual mechanic — instant
teleport with a `move_and_collide` safety clamp, invulnerability for
`step_duration=0.1s`, Perfect Step detection via the real
`Hurtbox.hit_avoided` signal. Nothing about *that* changes. This section
is purely about what plays on top of it visually.

Proposed mapping of ART_BIBLE.md §7's sequence to concrete technique:

| Stage | Technique | Notes |
|---|---|---|
| Stable | (default rig state) | — |
| Destabilization | character animation (a short rig-level "brace/tense" pose) | begins the instant `is_stepping` starts |
| Jinn Fire exposure | `JinnFireLayer` intensity spike (§10) | shares the same trigger as "Veyr Step" in §10's table — same event, two layers react |
| Veyr geometry | `VeyrLayer`/`AbilityVFX` — geometric shapes forming around the character, distinct visual language from Jinn Fire (ART_BIBLE.md §4's organic-vs-structured contrast applies *within* this one ability, not just across the whole game) | |
| Fragmentation | spawned VFX (particles/geometry) + character visibility change | the *current* placeholder already does the visibility change part (`visual.visible = false` for the step's duration) — that mechanism doesn't need to change, just be joined by richer VFX |
| Displacement | (no visual during this instant — it's the teleport itself, already instant in gameplay) | |
| Reconstruction | spawned VFX (mirror of fragmentation) + character visibility restored | |
| Stable | (default rig state resumes) | — |

**Which parts are which technique**, explicitly per the brief's ask:

- **Character animation**: destabilize/reconstruct poses (rig-level,
  short).
- **Character visibility changes**: hide during the step window (already
  exists) — this is the one piece that's a genuine carry-over from the
  current placeholder, not a new mechanism.
- **Particles**: fragmentation/reconstruction burst detail (extends the
  existing `DepartParticles`/`ArriveParticles` `GPUParticles2D` usage —
  already proven in this project, not a new technology).
- **Geometry**: the Veyr structural shapes themselves (extends the
  existing `DepartBurst`/`ArriveBurst` `Polygon2D` "shatter" star shapes
  — same reasoning as above).
- **Trails**: the existing `TrailLine` (`Line2D`) between departure and
  arrival points — already implemented, already `top_level=true`, no
  change needed to keep using it.
- **Spawned VFX**: any one-shot effect that doesn't need to persist as a
  permanent child (e.g. instanced separately and freed after playing) —
  candidate for the fragmentation/reconstruction geometry bursts if they
  turn out to be cheaper as spawned instances than permanent hidden-
  until-triggered nodes.
- **Shader work**: explicitly deferred — "if eventually appropriate,"
  not for v0.1, matching the brief's "do not implement shaders yet."

**Perfect Step**: reuses this entire architecture, per the brief's
explicit instruction not to make it a separate system. The existing
gameplay difference is exactly one thing —
`perfect_burst_scale_multiplier` (currently `1.6×`) applied to the
existing burst scale, plus a distinct hitstop
(`perfect_hitstop_duration`/`perfect_hitstop_time_scale`, already
separately tuned from the normal hit's hitstop). The **cleaner/more
precise Veyr structure** ART_BIBLE.md §7 asks for should be implemented
as a variant/parameter of the same `VeyrLayer` geometry (e.g. a more
"resolved" or symmetric version of the same shapes), not a second
`AbilityVFX` subsystem.

---

## 12. Art Resolution / Scale Recommendation

Grounding numbers (all confirmed from `project.godot` and this
session's own screenshot captures, not estimated):

- Viewport: **1152×648**, `stretch/mode = "canvas_items"`,
  `stretch/aspect = "expand"` — the game does **not** letterbox on wider
  windows, it shows more world, so there's no fixed "safe frame" to
  design around beyond the base resolution.
- `Camera2D.zoom` is `(1,1)` during all normal gameplay in this project.
  Every zoom adjustment found anywhere in the codebase (`AvarisReveal.gd`,
  `RhaekTeaser.gd`) zooms **out** (0.55-0.85), never in — `1.0` is
  effectively the closest the camera ever gets to the player today.
- Player collision height: **46px**. At `zoom=1.0`, that's the floor for
  "how tall is Zayr's gameplay-relevant silhouette on screen" — roughly
  **46/648 ≈ 7% of the viewport height**.
- A finished character sprite will read taller than the bare collision
  box (natural visual mass beyond the hitbox is normal and already true
  of every placeholder in this project to some degree via the `Visual`
  polygon, though today it's an exact match) — a reasonable planning
  assumption is **roughly 1.3-1.8× the collision height**, i.e. an
  **on-screen rendered height in the neighborhood of 60-85px**, pending
  the actual Production Sheet proportions.

**Recommendation**: do **not** author source art at the concept sheet's
185cm real-world scale literally translated to pixels, and do not target
the ~60-85px on-screen number as the *source* resolution either — that
would produce visibly soft/blurry results the moment the camera zooms
out (0.55-0.85×, already proven to happen in this project) or the
window is resized larger under the `"expand"` stretch mode.

- **Recommended source texture height**: roughly **4-6×** the expected
  on-screen height — in the neighborhood of **320-512px tall** per major
  body piece's texture (not a single monolithic sprite, given the
  layered-rig approach in §3/§4). This is enough oversampling headroom
  for the confirmed zoom-out range and window-resize behavior without
  entering genuinely wasteful territory.
- **Oversampling factor**: ~4-6× is deliberately conservative relative
  to what "high-resolution stylized 2D" might suggest unbounded — going
  significantly higher (e.g. 2048px+ per piece) produces detail that
  cannot be perceived at this game's actual on-screen scale, directly
  contradicting ART_BIBLE.md §21's "quality over quantity" instruction
  and §12's own framing ("without producing detail that cannot be seen
  during gameplay").
- **Texture memory implications**: a multi-layer rig (§4's piece list) at
  ~320-512px per piece is modest in aggregate for a single player
  character — texture memory only becomes a real concern if this same
  resolution budget is later applied to every enemy type and the boss
  without reconsidering per ART_BIBLE.md §21's scoped-to-the-slice
  priority. Not a concern for Zayr alone at v0.1.
- **Downscaling**: yes — author at the higher source resolution, let
  Godot's texture import settings (mipmaps/filter) handle runtime
  presentation rather than hand-producing multiple pre-scaled export
  resolutions. Standard practice, no special handling needed beyond
  Godot's default import pipeline.

This recommendation is intentionally a *range*, not a locked number —
final resolution should be confirmed once the Production Sheet's actual
proportions (and therefore actual on-screen rendered height) are known.

---

## 13. Godot Animation Technology Recommendation

Stock Godot only, no third-party dependencies (per the budget
constraint already established in `GDD.md` §1: "$0 during development —
no paid middleware, plugins, SDKs").

| Technology | Recommended use | Why |
|---|---|---|
| `Skeleton2D` + `Bone2D` | Yes — the `CharacterRig` skeleton (§5) | Standard, well-supported Godot 4 tooling for exactly this kind of 2D cutout/skeletal rig; no reason to avoid it. |
| `AnimationPlayer` | Yes — primary driver for all named animations (locomotion clips, attack clips, ability clips) | Directly matches the existing architecture: `PlayerController.gd` already has one clean function (`_update_debug_visual()` → `_update_visual()`) and one clean `State` enum (§1) to key off of. `AnimationPlayer.play(state_name)` is close to a drop-in replacement for that function's body. |
| `AnimationTree` | **Defer past v0.1** unless hard state-cuts between locomotion clips look bad in practice | Adds real complexity (blend spaces/state machines) for a benefit (smooth blending) that a first pass can live without — the existing `State` enum already changes value discretely, so `AnimationPlayer.play()` on transition is a legitimate v0.1 approach. Revisit if idle↔run or fall↔land reads poorly without blending. |
| `Sprite2D` layers (parented to bones) | Yes — the actual visible art per rig piece from §4 | |
| `Polygon2D` deformation | Only where it's already proven in this project (flat shapes, simple tweened scale/color) — not recommended as a soft-body/mesh-deformation technique for v0.1 | Would be new, unproven territory for this codebase; the rig (Skeleton2D/Bone2D) is the correct tool for character deformation, not `Polygon2D` UV/vertex animation. |
| `GPUParticles2D` | Yes — already proven extensively (Veyr Step bursts, ambient dust/motes across every stage) | No new technology risk. |
| `Line2D` | Yes — already proven (Veyr Step trail) | No new technology risk. |
| Shaders | **Not for v0.1**, per explicit instruction | Every VFX plan above (§9-§11) is achievable with plain nodes/tweens/particles first; shaders are a legitimate *future* upgrade (e.g. a proper Jinn-Fire material, screen-space distortion for Veyr Step) but not required to hit v0.1's goals. |

**Recommended minimum toolset for v0.1**: `Skeleton2D` + `Bone2D` +
`Sprite2D` + `AnimationPlayer` + the already-proven `GPUParticles2D`/
`Line2D`/`Tween` combination this project already uses everywhere else.
Nothing on this list is new to the engine version already in use
(Godot 4.7.2, per `GDD.md` §1), and nothing requires a plugin.

---

## 14. Migration Strategy (PROPOSED)

Adapted from the brief's example phases to this project's actual
structure — same spirit, sequenced against the real integration points
found in §1.

| Phase | Content | Integration point | Playability |
|---|---|---|---|
| **A** | `VisualRoot` infrastructure — restructure `Player.tscn` so today's placeholder `Visual` polygon becomes a child of a new `VisualRoot`, no visible/behavioral change | `PlayerController._update_debug_visual()` retargeted to write into `VisualRoot`'s tree instead of `$Visual` directly | Fully playable, zero visual difference |
| **B** | Temporary rig using simple separated placeholder shapes (a graybox rig, not production art) under `CharacterRig` | Same integration point, now driving bone poses instead of a single polygon's color | Fully playable, tests the rig plumbing risk-free before any art exists |
| **C** | Production character textures replace the placeholder shapes | Content-only swap, no script change if piece naming/attach points match §4/§5 | Fully playable throughout |
| **D** | Locomotion animations (§7's Locomotion table) | `AnimationPlayer` clips wired to `State`; this is where `_update_debug_visual()` is finally fully replaced | Fully playable |
| **E** | Combat animations + `WeaponManifestation` (§9), synced to §8's exact timing table | `PlayerCombat.gd`'s existing attack-start functions gain visual-layer subscribers (no gameplay timing changes) | Fully playable — highest-risk phase for gameplay/animation desync, budget real iteration time here |
| **F** | `JinnFireLayer`/`VeyrLayer`/`DamageVFX` (§10) | Subscribes to existing signals (`HealthComponent.damaged/died/health_changed`, `combat.is_charging`) | Fully playable |
| **G** | `AbilityVFX` — Veyr Step/Perfect Step polish (§11) | `PlayerVeyrStep.gd`'s existing trigger points | Fully playable |

The game remains playable at every phase boundary because every phase
after A only ever *adds* a visual reaction to a gameplay signal that
already exists today — none of them require gameplay code to wait on
art, and none of them can leave the player without *some* valid visual
state (worst case, mid-migration, is "looks unfinished," never "breaks
input/collision/combat").

---

## 15. Fallback Strategy

If the hybrid rig proves too expensive for a solo/small-budget
production, in order of preference (least to most gameplay-visible
compromise):

1. **Reduce cloth piece count** (§4 already scopes this to front/rear
   only — could collapse to a single cloth piece, or none, without
   affecting readability of state/attacks).
2. **Reduce secondary animation** (hair/cloth lag) to a simpler fixed-
   pose-per-state approach — loses some "alive" feeling but costs
   nothing gameplay-wise.
3. **Sprite-swap complex poses instead of rigging them** — e.g. Charged
   Attack's held pose, or Veyr Step's destabilize pose, as hand-drawn
   swapped frames rather than bone-animated — already anticipated by
   the "hybrid" production direction itself (§4 already flags shoulder
   material as a swap candidate; this just extends the same idea to
   specific poses under load).
4. **Simplify VFX** — fewer particle layers in `AbilityVFX`/
   `JinnFireLayer`, collapse Jinn-Fire-exposure states from §10's full
   table down to fewer discrete levels (e.g. "healthy" / "low health"
   only, skip a middle tier).
5. **Limit unique transitional animations** — skip dedicated Apex/
   Landing clips (§7 already flags these as not having a dedicated
   gameplay state today) and let Jump/Fall cover those moments; this is
   the cheapest single cut since it removes work that was never backed
   by a gameplay flag to begin with.

**Do not compromise gameplay readability** — specifically, attack
telegraph clarity (windup must still read as "about to hit") and hurt/
stagger feedback should be the last things simplified, not the first,
since [COMBAT.md](COMBAT.md)'s whole design philosophy depends on
readable telegraphs.

---

## 16. Technical Risks

| Risk | Level | Notes |
|---|---|---|
| 28×46 collision vs. illustrated proportions | **HIGH** | Confirmed on-screen collision height is ~46px (~7% of viewport) at the game's only normal zoom level (1.0) - a "high-resolution stylized" character risks looking either cramped or misleadingly larger than its actual hitbox at that real display size. Needs explicit proportion decisions in the Production Sheet, validated on-screen (§18), not just on the concept canvas. |
| Visual scale mismatch (sprite reads bigger/smaller than collision) | **MEDIUM-HIGH** | Directly follows from the above; standard practice is authoring the sprite to roughly match or slightly exceed the collision box, not the reverse. |
| Attack reach vs. hitbox offsets | **MEDIUM** | §9's constraint - manifestation art needs to visually terminate near the existing 26-30px offsets or players will misjudge range. |
| Mirrored asymmetric design | **HIGH** | §6's flag - ART_BIBLE.md explicitly wants "asymmetry"/"damaged elegance," but the current (and recommended) facing method is a horizontal mirror, which will flip any one-sided detail's side depending on facing direction. Needs an explicit Production Sheet decision, not a default. |
| Cloth clipping | **MEDIUM** | Standard 2D skeletal-rig risk; manageable with conservative bone weighting and limited secondary-motion range - not specific to this project. |
| `Skeleton2D` complexity | **LOW-MEDIUM** | The technology itself is mature/proven in Godot 4; risk is scope creep (over-segmentation per §4) more than the tool. |
| Animation/VFX synchronization with gameplay timing | **HIGH** | §8's timing table includes windows as short as 0.06s (Aerial Attack windup) and a variable-length hold (Charged Attack) - hitting these exactly, without being allowed to adjust the timing values themselves, is real production risk that should be budgeted for explicitly, especially for Phase E in §14. |
| Veyr Step visibility handling | **MEDIUM** | The character is fully hidden for the step's `0.1s` window today; a richer fragmentation effect needs to avoid popping oddly on hide/show - well-understood problem in games generally, not unique risk here. |
| Performance (particles + skeleton + layered sprites simultaneously) | **LOW-MEDIUM** for v0.1 (single player character) | Becomes a bigger concern only if the same rig complexity is later applied to many enemies at once - out of scope for this document per ART_BIBLE.md §21. |
| Texture memory | **LOW** for v0.1 (Zayr only, one character) | Same scaling concern as performance - revisit if/when enemy art reaches similar fidelity. |
| Camera readability of fine detail | **MEDIUM** | Directly tied to §12 - illustrated detail finer than what a ~60-85px on-screen character can convey is wasted effort; needs real screenshot validation (§18), not editor-only judgment. |
| Future skin/outfit changes | **LOW** | Not currently planned/requested; a cleanly layered rig (§3/§4) makes this cheaper later as a side effect of good structure, not a risk to actively design around now. |

---

## 17. Required Art Deliverables

What needs to be produced **before implementation can begin**, based
entirely on the plan above - nothing here has been generated, and this
is not a request to start production, only a manifest of what the
eventual Production Sheet needs to supply:

**Character rig pieces** (§4), each as a separate source layer at the
resolution range recommended in §12:
- Head, hair, torso/chest, pelvis, upper arms (L/R), forearms (L/R),
  hands (L/R), thighs (L/R), lower legs (L/R), feet (L/R), front cloth,
  rear cloth, shoulder material (swap variant(s) if damage states are
  planned).

**Pose/expression variants** implied by §7's animation map, sufficient
for an animator to build the listed clips - exact frame count/method
(skeletal vs. swapped) per piece is a Production Sheet decision, not
fixed here.

**Weapon manifestation art** (§9): at minimum, one distinct geometric
"look" per attack category (Light/Heavy/Aerial/Charged), each with a
form/collapsed silhouette sufficient to animate manifest→hold→collapse.

**Jinn Fire layer art** (§10): base exposure treatment plus enough
variation to distinguish idle/exertion/damage/low-health/charged/Veyr-
Step/defeat intensity levels, in the ember-gold/orange organic language
from ART_BIBLE.md §3.

**Veyr layer art** (§11): the geometric violet structural language from
ART_BIBLE.md §4, sufficient for ordinary Veyr Step, and a distinguishable
"more precise/complete" variant for Perfect Step.

**Damage/hurt pose(s)** and a **gameplay-defeat pose/sequence** (§7's
Damage table).

Everything above should be produced only for what's actually visible in
the funding vertical slice, per ART_BIBLE.md §21 - not a full future
moveset's worth of variants.

---

## 18. Standing Process Rule

**Every major visual implementation must be validated using: real game
camera + real player position + screenshot + manual playtest. Editor
appearance alone is not sufficient.**

This isn't a new rule invented for this document - it's already been
the single most consistently useful lesson from this project's own
development history. Every environment/background composition issue
found across Stages 4 through 7 (camera framing, off-screen content,
colors that don't read as intended) was caught by an actual real-GPU
screenshot at the real gameplay camera position, never by reasoning
about coordinates or colors alone (see [ASSET_AUDIT.md](ASSET_AUDIT.md)
§3 and every matching entry in `PROGRESS.md`). There's no reason to
expect character/rig work to be exempt from the same lesson - if
anything, a rig with bone-driven motion and multiple independently-
triggered VFX layers has *more* ways to look wrong than a static
background silhouette did.

---

## Phase A — Static Visual Integration (Implementation Log)

**Status: ARCHITECTURE READY — ART INPUT REQUIRED.** The VisualRoot
architecture proposed above is now implemented and validated at real
gameplay scale. Zayr's actual production art (Production Sheet 01,
Animation Sheets 01-04, "Gameplay Rig Art — Base Set v0.1") was **not**
integrated, because **no transparent, separated source art files exist
anywhere in this repository** — `assets/characters/` contains only a
`.gitkeep`, and a full repo-wide search found no `.png`/`.jpg`/`.psd`/
`.svg` files besides the default Godot project icon. Whatever the
Production Sheet/Animation Sheets/Rig Art actually look like was never
placed into this project as files this pass could read or use — per
§2's explicit instruction, no attempt was made to reconstruct art from
a reference sheet or fake final art from a screenshot. See "Required
Art Deliverables" below for exactly what's needed to proceed.

### What was implemented

`scenes/player/Player.tscn` now has:

```
Player (CharacterBody2D)
├── CollisionShape2D          — UNCHANGED: 28x46, offset (0,-23)
├── VisualRoot (Node2D)       — NEW, local (0,0), inherits Player's transform normally
│    ├── CharacterRig (Node2D)
│    │    └── BodyPlaceholder (Polygon2D)  — Phase A static placeholder (see below)
│    ├── WeaponManifestation (Node2D)      — empty, per Phase A scope
│    ├── JinnFireLayer (Node2D)            — empty, per Phase A scope
│    ├── VeyrLayer (Node2D)                — empty, per Phase A scope
│    ├── AbilityVFX (Node2D)               — empty, per Phase A scope
│    └── DamageVFX (Node2D)                — empty, per Phase A scope
├── DebugVisual (Polygon2D)   — RENAMED from "Visual", same 28x46 rectangle,
│                                same per-state tint logic, hidden by default
├── Movement, Camera2D, HealthComponent, VeyrComponent, Hurtbox, Combat,
│   RangedAttack, Hitbox, VeyrStep, TrailLine, DepartBurst, ArriveBurst,
│   DepartParticles, ArriveParticles  — UNCHANGED
```

`BodyPlaceholder`: a simple 6-point tapered humanoid silhouette (the
same shape convention already proven in this project by
`RhaekTeaser/Silhouette`, resized/reproportioned - not new invention),
`Color(0.5, 0.5, 0.55)` (a neutral graybox gray, deliberately not any
color from the approved final palette, so it can't be mistaken for
finished art), foot-aligned so its bottom edge sits exactly at local
`Y=0` - the same point the 28x46 collision box already treats as ground
contact. Authored height: **72px** (`-72` to `0` locally), the midpoint
of §12's recommended 60-85px on-screen target range.

### Code changes (minimal, mechanical - no gameplay logic touched)

- **`scripts/player/PlayerController.gd`**: added `show_debug_visual:
  bool` export (default `false`, checked once in `_ready()`, not a live
  toggle - "do not create an elaborate debug framework" per §7);
  `_debug_visual` now points at `$DebugVisual`; added `_visual_root:
  Node2D = $VisualRoot`; `_update_debug_visual()` renamed
  `_update_visual()` (3 call sites updated, same call pattern) and now
  also flips `_visual_root.scale.x` alongside the existing debug-rect
  flip, both driven by the same `movement.facing` value as before.
- **`scripts/player/PlayerVeyrStep.gd`**: the `visual` reference
  (previously `Polygon2D = get_parent().get_node("Visual")`) now points
  at `Node2D = get_parent().get_node("VisualRoot")` - hides/shows the
  whole production visual layer during the step's `0.1s` window,
  functionally identical to what it did before (hide the thing
  representing Zayr's body), just retargeted at the new container.
  **Known Phase A limitation**: if `show_debug_visual` is enabled, the
  debug rectangle does *not* hide during Veyr Step (only `VisualRoot`
  does) - acceptable for a developer-only debug aid, not fixed here per
  the "no elaborate debug framework" instruction.

No other script was touched. `PlayerCombat.gd`, `PlayerRangedAttack.gd`,
`HealthComponent.gd`, `VeyrComponent.gd`, `Hitbox.gd`, `Hurtbox.gd`,
`PlayerMovement.gd`, and every collision/hitbox/timing value are
byte-for-byte unchanged.

### Regression testing (headless, real engine - not just "it compiles")

A throwaway `godot --headless --script` harness (deleted after use, per
established project convention) verified, all passing:

- Project/scene parse: `Player.tscn`, `TestArena.tscn`, and
  `AvarisVerticalSlice.tscn` all load and boot without error.
- `VisualRoot` hierarchy exists exactly as designed; all five ability/VFX
  layers exist and are empty (Phase A scope).
- `BodyPlaceholder` height measured at 72px (in the 60-85px target
  range); its lowest point sits at local `Y=0` (ground contact).
- Collision unchanged: 28x46 at offset `(0,-23)`.
- `VisualRoot.scale.x` correctly mirrors `movement.facing` in both
  directions.
- Real movement (run under held input) still moves the player.
- All four attack hit offsets read back unchanged (26/30/26/28).
- Veyr Step: `VisualRoot` hides on step start, `HealthComponent` reports
  invulnerable during the step, `VisualRoot` becomes visible again and
  `is_stepping` clears after `step_duration`.
- Lethal damage correctly reaches `State.DEAD`; after `RESPAWN_DELAY`
  the player returns to `State.IDLE` at the exact spawn position, with
  `VisualRoot` visible again.

### Real-camera validation (non-headless, real GPU, per §10/§18)

Screenshots captured at the real gameplay camera, real player position,
in `AvarisVerticalSlice.tscn`, for all six requested situations
(Stage 1 awakening, normal traversal, combat beside the melee enemy, the
ranged encounter, the Avaris reveal, and the mini-boss arena). One
methodology note first: the first traversal attempt (x=1000) landed the
player in a level gap and triggered the scene's existing fall-safety
`KillZone` (`AvarisVerticalSlice.gd`, wired since before this pass,
unrelated to Phase A), causing a death/respawn cycle before the
screenshot was taken - a test-targeting mistake, not a bug. Recaptured
at a safe on-floor position (x=600); the result below is from that
retry.

**Findings:**

1. **Silhouette readability**: the tapered `BodyPlaceholder` silhouette
   reads clearly against every environment tested, including the
   darker Avaris-reveal backdrop - it's visually distinct from the flat
   rectangles used everywhere else, confirming the architecture (not
   just the collision math) actually holds up on screen.
2. **Ground contact**: in every situation, Zayr's feet sit exactly on
   the visible floor line - no floating, no sinking. The `VisualRoot`
   local-origin-matches-collision-origin approach (§5 of this document)
   works as designed.
3. **Facing/mirroring**: verified programmatically (see regression
   testing above) - not separately re-verified by screenshot, since the
   current placeholder shape is symmetric and a mirrored screenshot of a
   symmetric shape carries no additional visual information. This
   should be re-checked visually once real (likely asymmetric) art
   exists.
4. **Scale relative to enemies - a real finding requiring a decision**:
   the melee-enemy and mini-boss screenshots both show Zayr's new
   72px-tall placeholder rendering **taller than the enemy placeholders
   next to it**, including the mini-boss. Enemy/mini-boss `Visual`
   nodes were not touched this pass (out of scope) and still match
   their old collision-sized flat rectangles exactly: regular enemy
   46px tall, mini-boss 69px tall. Before this pass, Zayr's own
   placeholder was also 46px, so the mini-boss read as taller than
   Zayr, matching ART_BIBLE.md §14's "substantially larger silhouette"
   intent. **After this pass, at 72px, Zayr is now taller than even the
   mini-boss** - an inversion of that intended relationship, introduced
   as a side effect of scaling only Zayr's placeholder per this task's
   scope. This is flagged, not fixed - see "Anything requiring
   approval" below.
5. **Avaris reveal framing**: at the reveal's zoomed-out camera (an
   existing, pre-built behavior, unchanged by this pass), Zayr's
   placeholder becomes quite small and its neutral gray sits fairly
   close in value to the dark spire silhouettes in the background -
   noticeably lower-contrast there than in the closer-framed situations.
   Worth keeping in mind for final art value/contrast choices, though
   not something graybox color selection can meaningfully solve.
6. **Ranged Veyr projectile origin**: visually confirmed in the ranged-
   encounter screenshot - the projectile (red diamond) travels at a
   height consistent with `muzzle_offset`'s documented values; nothing
   about the new visual layer affects it, as expected (`PlayerRangedAttack.gd`
   was not touched).
7. **Attack reach**: not directly re-validated by screenshot this pass
   (Phase A has no attack animation to trigger visually) - the
   regression test's confirmation that all four hit offsets are
   byte-for-byte unchanged is the relevant check here; a visual
   reach-vs-manifestation check only becomes meaningful once
   `WeaponManifestation` art exists (Phase E).

### Bugs discovered/fixed

- A bug in this pass's own throwaway screenshot script (`root.get_root()`
  called on a `Window`, which has no such method - `Window` already
  *is* the root) caused the first capture attempt to error out after
  one frame. Fixed (`root.get_texture()` directly) and re-run
  successfully. Not a project bug.
- The traversal-screenshot gap/`KillZone` case above - a test-targeting
  mistake (picked an x-coordinate over a gap), not a project bug. The
  `KillZone` itself worked exactly as designed.
- No project/gameplay bugs were found or introduced by the VisualRoot
  integration itself - every regression check above passed on the first
  run after the implementation was written.

### Exact remaining art deliverables

Per §2's instruction, since no separated transparent Zayr art exists in
the repo, here is what's needed to move past Phase A into real
production art integration (Phase B onward, not started):

```
assets/characters/zayr/base/head.png
assets/characters/zayr/base/hair.png
assets/characters/zayr/base/torso.png
assets/characters/zayr/base/pelvis.png
assets/characters/zayr/base/upper_arm.png
assets/characters/zayr/base/forearm.png
assets/characters/zayr/base/hand.png
assets/characters/zayr/base/thigh.png
assets/characters/zayr/base/shin.png
assets/characters/zayr/base/foot.png
assets/characters/zayr/base/cloth_front.png
assets/characters/zayr/base/cloth_rear.png
assets/characters/zayr/base/shoulder_material.png
```

Each file:
- **Format**: PNG, transparent background (alpha channel, no baked-in
  background color).
- **Dimensions**: per §12's recommendation, roughly 320-512px tall for
  the piece's own extent (not the full character - each piece is
  cropped to its own bounding box), pending final Production Sheet
  proportions.
- **Orientation**: authored facing the character's default/right-facing
  pose (mirroring is handled by `VisualRoot.scale.x` at runtime - see
  §6; do not pre-author a separate left-facing version unless a piece is
  specifically flagged asymmetric per that section's open decision).
- **Pivot**: each piece's art should be positioned so its own attach
  point (e.g. the shoulder socket for `upper_arm.png`, the ankle for
  `shin.png`) lands at a predictable, consistent offset within its own
  canvas - exact pivot convention (e.g. "pivot at top-left of canvas" vs
  "pivot at image center") should be confirmed once rigging begins
  (Phase B), not assumed here.
- **Naming**: as listed above, lowercase, matching the rig piece names
  used in §4 of this document.
- **Left/right variants**: not required for most pieces (mirroring
  covers them) - **except** whichever specific piece(s) end up carrying
  the asymmetric damage/exposed-fire detail flagged in §6, which may
  need true separate art depending on which of §6's three resolution
  options is chosen. Not resolved here - flagged for the Production
  Sheet review.

This list is Zayr-only, matching this phase's scope - it does not cover
`WeaponManifestation`, `JinnFireLayer`, or `VeyrLayer` art, which per
§9-§11 come later (Phase E/F) and were explicitly out of scope for
Phase A.

---

## Phase B — Rig-Ready Asset Preparation and Static Assembly

**Status: BLOCKED AT THE ART GATE. No static assembly performed.**

### 1. Phase A re-check

Confirmed clean, no drift: `Player.tscn`'s `VisualRoot` subtree
(`CharacterRig`, `WeaponManifestation`, `JinnFireLayer`, `VeyrLayer`,
`AbilityVFX`, `DamageVFX`), `DebugVisual`, and `PlayerController.gd`'s
`show_debug_visual` toggle all match the Phase A implementation log
exactly. `PlayerVeyrStep.gd`'s `VisualRoot` hide/show reference is
unchanged.

### 2. Available Zayr art — none

`assets/characters/zayr/` **does not exist as a directory.**
`assets/characters/` contains only `.gitkeep`. A full repository search
(every extension: `.png .jpg .jpeg .webp .psd .tga .svg .ai .fig`),
including the folder tree outside the Godot project root, found nothing
but Godot's own default `icon.svg`. None of the 13 planned files
(`head.png` through `shoulder_material.png`, see Phase A's "Required
Art Deliverables") exist. There is no reference sheet or composite
image in the repo either, clean or otherwise - so the "don't blindly
crop a composite" risk this section warns about didn't even arise;
there was nothing to crop from.

**Consequence**: §5 (static assembly), §6 (layer order against real
art), §7 (joint-rotation test), §8 (mirror test of assembled art), and
§9 (real-camera validation of an assembled character) were not
performed - there is nothing to assemble, rotate, mirror, or
screenshot. `VisualRoot/CharacterRig` still contains only Phase A's
`BodyPlaceholder`, untouched. Sections 3, 4, 10, 11, and 13 below are
deliverable without art in hand and were completed as forward
specification, so production art has an exact target to build to.

### 3. Pivot convention

Each piece's PNG canvas has one defined anatomical pivot point, expressed
as pixel coordinates from the canvas's top-left corner (matching Godot's
own `Sprite2D.offset` convention, which is what will position the piece
relative to its node's local origin once assembly begins). The pivot is
where the piece attaches to its parent in the rig chain (§5 of the
original Phase A rig plan):

| Piece | Pivot = attachment point |
|---|---|
| `head.png` | base of neck (bottom-center of the head canvas) |
| `hair.png` | same point as `head.png`'s neck pivot - hair is parented to the head, not independently pivoted |
| `torso.png` | pelvis/root attachment (bottom-center of the torso canvas, where it meets the pelvis) |
| `pelvis.png` | root (bottom-center - this is the rig's actual root per Phase A §5, sitting at the `CharacterBody2D`/collision ground-contact origin) |
| `upper_arm.png` | shoulder (top-center or top-corner of the canvas, matching whichever shoulder socket position the Production Sheet places it at) |
| `forearm.png` | elbow (top-center of the canvas) |
| `hand.png` | wrist (top-center of the canvas) |
| `thigh.png` | hip (top-center of the canvas) |
| `shin.png` | knee (top-center of the canvas) |
| `foot.png` | ankle (top-center or heel-aligned, whichever reads more naturally once the actual foot silhouette exists) |
| `cloth_front.png` | waist (top-center, hangs downward from there) |
| `cloth_rear.png` | waist (top-center, hangs downward from there) |
| `shoulder_material.png` | shoulder/upper torso (attachment point matches wherever `upper_arm.png`'s shoulder pivot sits, so the two can be positioned together) |

Kept deliberately simple, per the instruction not to invent unnecessary
complexity: one pivot per piece, no multi-point pivots, no separate
"visual centerpoint vs. attachment point" distinction. This directly
becomes each `Sprite2D`'s `offset` value once real files exist -
`centered = false` with `offset` set to the pivot coordinates above (in
that piece's own pixel space) is the concrete Godot-side implementation,
so a piece's node `position` in the rig always equals its actual joint
location, not its texture's geometric center.

### 4. Canvas/padding rules

- **Minimum transparent padding**: ~10-15px of transparent margin (at
  the ~320-512px source scale from Phase A §12) around the piece's
  *non-joint* edges (outer silhouette edges - the side facing away from
  any neighboring piece) - enough that anti-aliased edge pixels aren't
  flush against the canvas boundary, which can cause a hard clipped
  look at import. This is a minor technical margin, not a design
  requirement.
- **Joint overlap allowance** (the real requirement, distinct from the
  padding above): each piece should extend **past** its pivot point by
  roughly 15-25% of its own length/width into the space its parent
  piece already occupies (e.g. the top of `forearm.png` should visually
  overlap into where `upper_arm.png` ends, not butt up exactly against
  it). This is what prevents a visible gap from opening up at a joint
  when pieces rotate relative to each other during animation (Phase C+)
  - confirmed as the correct approach, though it can only be verified
  visually once §7's joint-rotation test can actually run against real
  art.
- **Pieces may extend behind neighboring pieces**: yes, deliberately -
  see above. `z_index`/draw order (§6) is what keeps this invisible,
  not clipping the art itself.
- **Consistent source scale**: all 13 pieces must be authored at the
  same real-world-to-pixel ratio, on the same canvas DPI/scale
  assumption, so that when assembled at their documented pivots the
  proportions read as one coherent body - not individually "nice
  looking" crops at inconsistent scales. This has to be enforced during
  art production (Production Sheet proportions, already approved,
  should already guarantee this) - it cannot be corrected after the
  fact by resizing individual `Sprite2D` nodes without also breaking
  the pivot math above.
- **Filtering/import**: see §11 below.

### 10. 72px scale decision

Per direction: **keep Zayr's target at approximately 72px**, unchanged
from Phase A. The earlier flag about Zayr reading taller than the
graybox mini-boss (69px) is resolved - not a blocker. No change made,
since `BodyPlaceholder` is already authored at 72px; this stays the
target for the real assembled character once art exists.

### 11. Import settings (forward specification - no texture imported yet, since none exist)

Recommended Godot 4 import configuration for these pieces, once they
exist, consistent with "illustrated 2D, not pixel art" and "avoid
excessive texture memory":

| Setting | Value | Why |
|---|---|---|
| Filter | Linear (with mipmaps) | This is hand-illustrated stylized art, not pixel art - `Nearest` filtering would make edges/gradients look crunchy and aliased, contradicting the explicit instruction. |
| Mipmaps | Enabled | The character is displayed at a large downscale from its ~320-512px source to a ~72px rendered height (4-7x), and the Avaris Reveal beat zooms the camera further out (0.55-0.85x) on top of that - mipmaps prevent shimmering/moiré at those reduction factors. |
| Repeat | Disabled | Character pieces are never tiled. |
| Compress Mode | **Lossless** | At this per-piece resolution (~320-512px tall, RGBA with transparency and soft gradients), `VRAM Compressed` formats (e.g. BC7/ETC2) introduce visible blocking/banding on illustrated gradients and semi-transparent edges - exactly the "unnecessarily crunchy" result to avoid. `Lossless` keeps full quality; total texture memory for 13 pieces at this scale stays modest (see §12) even without VRAM compression, so there's no real memory pressure forcing a lossy tradeoff at v0.1's single-character scope. |
| `2D/normal` import preset base | Godot's default 2D texture preset, with the above overrides | No reason to deviate further; this project already uses default import behavior everywhere else (see ASSET_AUDIT.md - zero custom import presets exist anywhere yet). |

### 12. Performance (N/A - nothing added this pass)

No `Sprite2D` nodes were added (no source textures exist to reference).
Zero change to draw calls, texture memory, or node count versus Phase A.
Once art exists: 13 pieces × roughly 320-512px-tall RGBA textures is a
modest budget even uncompressed (order of a few MB total for one
character) - not remotely enough to justify atlas packing at this
stage. Revisit atlas packing only if/when many similarly-detailed
character types (enemies, bosses) exist simultaneously - premature for
a single character.

### 13. DebugVisual

Unchanged and still functional - confirmed via the code re-check in
§1. `show_debug_visual` still toggles between it and `VisualRoot`
exactly as Phase A implemented.

### 14. Regression test

Re-ran the same headless regression battery from Phase A (scene boot,
`VisualRoot` hierarchy shape, collision/hitbox values, facing mirroring,
movement, Veyr Step hide/show + invulnerability, hurt/death/respawn).
All passed - expected, since no gameplay or scene code changed this
pass.

### 16-17. Required to proceed

Blocked on exactly one thing: **the 13 transparent PNG files listed in
Phase A's "Required Art Deliverables," now with the exact pivot (§3)
and padding/overlap (§4) rules above.** Once those exist in
`assets/characters/zayr/base/`, static assembly (§5-9 of this phase's
original brief) can run in a single pass - the specification work here
means that shouldn't require another round-trip once files arrive.

---

## Phase B Resumed — Rig-Ready Asset Preparation and Static Assembly (Results)

**Status: STATIC ASSEMBLY COMPLETE for 11 of 13 pieces. `head.png` used
with one documented minor defect. `hair.png` and `forearm.png`
excluded - genuinely unusable as delivered, need regeneration.**

### 1. Per-file audit results

All 13 files inspected with a real per-pixel alpha audit (not visual
guessing) - histogram bands, content bounding boxes, and red/green
background-composite bleed tests (Pillow, at
`assets/characters/zayr/base/`). Full data:

| File | Size | Content bbox padding | Alpha profile | Verdict |
|---|---|---|---|---|
| head.png | 203x195 | 13px, consistent | normal (20.4% at exactly 255) | **Usable, one defect** - see below |
| torso.png | 317x367 | 13px | normal (60.1% at 255) | Clean |
| pelvis.png | 403x400 | 13px | normal (52.2% at 255) | Clean |
| upper_arm.png | 200x355 | 13px | normal (37.0% at 255) | Clean |
| hand.png | 174x231 | 13px | normal (31.4% at 255) | Clean |
| thigh.png | 216x288 | 13px | normal (40.6% at 255) | Clean |
| shin.png | 166x287 | 13px | normal (38.0% at 255) | Clean |
| foot.png | 220x214 | 13px | normal (42.7% at 255) | Clean |
| cloth_front.png | 251x459 | 13px | normal (45.4% at 255) | Clean |
| cloth_rear.png | 251x414 | 13px | normal (50.6% at 255) | Clean |
| shoulder_material.png | 194x434 | 13px | normal (44.9% at 255) | Clean |
| **hair.png** | **1484x1060** | **0px (touches top edge)** | **anomalous - 0.0% at exactly 255, peaks at 250-254** | **EXCLUDED** |
| **forearm.png** | **1274x1235** | **0px (touches left edge)** | **anomalous - 0.0% at exactly 255, peaks at 250-254** | **EXCLUDED** |

**No checkerboard-baked-into-pixels or brown/background contamination**
was found on any of the 13 files (confirmed via red-vs-green background
composite testing - opaque regions showed 0% color bleed on all 13,
meaning the alpha channel is genuine, not a flattened fake). No
mislabeled/text-contaminated files. No accidental Jinn Fire/Veyr
effects baked into any piece.

### 2. Scale coherence

**11 of 13 files share one consistent, coherent scale and export
convention** - identical 13px transparent padding on every side,
alpha statistics consistent with a single clean export pipeline, and
content-bbox proportions that are anatomically plausible relative to
each other (confirmed by successfully assembling them into a single
proportioned figure - see §5 below). This batch passes the scale-
coherence check.

**`hair.png` and `forearm.png` do not belong to that batch.** Both:
- are 3-6x larger in raw canvas dimension than every other piece (1274-
  1484px vs. 166-403px for everything else),
- have their actual content touching a canvas edge with **zero**
  padding (violating the established convention every other file
  follows exactly),
- have a measurably different alpha profile (literally zero pixels at
  exactly alpha=255, versus 20-60% for every other file - indicating a
  different, lossier export step),
- are file-dated ~5 hours after the other 11 (20:35 vs. 01:49-01:50),
  consistent with having come from a separate, later generation pass,
- render in a visibly higher-gloss/higher-fidelity style inconsistent
  with the flatter illustrated look of the other 11 pieces.

Reconciling either into the same assembled character would require
scaling them down by roughly 4-8x relative to their own canvas - well
past ordinary import scaling and into the "extreme arbitrary resizing"
this phase's brief said to stop and report rather than force. **Per
that instruction, both are excluded from assembly, not forced in.**

`forearm.png` has a second, independent, disqualifying problem beyond
scale: **it has a complete hand (fingers, thumb, wrist cuff) rendered
as part of the same piece** - directly duplicating `hand.png`'s own
content. Using both would double-render the hand; using `forearm.png`
alone would break the documented reusable-limb-piece architecture
(§5 of this document) and still carry the scale problem above. This
piece cannot be used as "forearm-only" without being re-exported.

### 3. head.png's one defect

A small gold necklace/collar fragment is present near the jaw,
disconnected from the rest of the piece's own silhouette - it
duplicates detail `torso.png` already provides at its own collar
(neighboring-component contamination from the original artwork, not
fully separated by the background-removal pass). In the assembled
result (§5) this fragment happens to align closely with the torso's
own collar and reads as a plausible continuation rather than an
obvious error, but it is not part of `head.png`'s own intended content
and should be cleaned up in a future correction pass. **Everything else
about `head.png` (the profile face, hair fringe, ear, jaw) is clean and
usable** - confirmed via composite testing against gray/black/white
backgrounds, which also ruled out an initial, incorrect impression that
the hairline read as "torn"; against black and white specifically, the
fringe reads as intentional spiky-hair styling, not damage.

### 4-5. Layer order and pivots (as implemented)

`VisualRoot/CharacterRig/BodyPlaceholder` was removed and replaced with
16 `Sprite2D` nodes (11 unique textures; `upper_arm`, `hand`, `thigh`,
`shin`, and `foot` each instanced twice - once per side, the rear copy
horizontally mirrored via `scale.x = -0.058` rather than a duplicate
texture, per the brief's explicit "canonical limb PNGs are reusable"
instruction). No `forearm`/`hair` nodes exist, matching their exclusion
above.

Z-index (back to front), determined from the actual assembled art, not
the brief's example order:

```
-6  ClothRear
-5  RearUpperArm
-4  RearThigh, RearShin, RearFoot
-3  Pelvis
-2  Torso
-1  FrontThigh, FrontShin, FrontFoot
 1  FrontUpperArm
 2  ShoulderMaterial
 3  ClothFront
 4  RearHand
 5  FrontHand
 6  Head
```

This mostly matches the brief's example (rear cloth/limbs → torso/
pelvis → front limbs → shoulder material/cloth → head), with one
deliberate deviation: **both hands are drawn in front of everything,
including the front cloth**, rather than behind it. With no
`forearm.png` to bridge them to the upper arms, the hands' actual
attachment point is already an open question (see §9) - burying them
behind the cloth at a "plausible-looking" default z-index would have
hidden that gap from the validation screenshots instead of surfacing
it. Once a corrected `forearm.png` exists, this ordering should be
revisited alongside real elbow/wrist placement.

Pivots were applied exactly per this document's earlier §3 convention
(top-center for shoulder/elbow/wrist/hip/knee/ankle/waist, bottom-
center for the head's neck attachment), implemented as each `Sprite2D`'s
`offset` (with `centered = false`) so the documented pivot pixel lands
exactly on the node's `position`.

### 5. Static assembly - transform derivation and validation

Because precisely deriving joint positions/scale analytically proved
unreliable (first-pass hand math alone overshot the 72px target by
~55%), the actual transform values were derived and verified through
**an exact Python replica of Godot's own `Sprite2D` transform math**
(`centered=false` + `offset` + `scale` + `position`, including the
signed-scale mirroring formula) rendered against the real source PNGs,
then transcribed into `Player.tscn` and confirmed in the real engine.
This is the same "verify for real, don't trust the math alone"
discipline this project has used for camera/composition work all
session, applied here to character assembly instead.

**Result**: `GLOBAL_SCALE = 0.058` applied uniformly to all 11 pieces
(preserving their relative proportions, not independently normalizing
them, per this phase's explicit instruction). Measured standing height
(ground to crown, via alpha-diff bounding box): **72.3px** - within
rounding of the approved ~72px target. Measured ground contact: feet
sit at exactly world Y=0, **0.0px** offset from the ground line - no
floating, no sinking.

### 8-9. Joint stress test and mirror test

Performed via the same transform-faithful renderer (fast iteration,
same math as the real engine), at the requested angles, both
directions: head ±10°, upper_arm ±20°, hand ±15°, thigh ±15°,
shin ±20°, foot ±10°. (Elbow/wrist-to-forearm rotation is not
testable - no forearm exists.)

**All tested joints passed** - no holes, no exposed transparency, no
broken anatomy, no seam breaks, at any tested angle in either
direction. This held up mainly because (a) every piece shares the same
generous 13px padding, so nothing crops hard at a rotation boundary,
and (b) the pelvis/cloth pieces provide wide coverage that hides the
hip joint across the whole tested thigh-rotation range regardless of
angle. The one already-known issue (the hand/upper-arm gap from the
missing forearm) is present at every angle, unchanged by rotation - not
a new joint-test finding, the same pre-existing gap.

**Mirror test**: confirmed two ways - programmatically, the regression
suite verifies `VisualRoot.scale.x` flips to exactly `-1.0`/`1.0` on
facing change (real engine, not simulated); visually, the same
transform-faithful renderer was run with every position/scale mirrored,
matching what `VisualRoot.scale.x = -1` actually produces. Only one
asymmetry-related observation: `torso.png` has a diagonal sash/scarf
baked into its own art, which necessarily flips sides along with
everything else when mirrored. This reads as a normal garment drape in
both directions, not as an error - no readability problem was observed
in either facing direction. Per this project's standing rule (Phase A
§6), this remains something to watch if a future *lore-specific*
asymmetric detail (e.g. a fixed-side scar) is ever added - that would
need to live in a non-mirrored VFX layer, not the base rig art. No such
detail exists yet, so nothing is unresolved here today.

### 12. Real-camera validation

Real-GPU, real-camera, real-player-position screenshots captured in
`AvarisVerticalSlice.tscn` at all six requested situations: Stage 1
awakening, normal traversal, Stage 2 melee combat, the Veyr/ranged
encounter, the Avaris reveal, and the mini-boss arena. All six show
Zayr's silhouette reading clearly against its backdrop and sitting
exactly on the visible ground line. Compared with Phase A's flat gray
placeholder, the assembled character is dramatically more legible as
"a specific character" rather than "a colored box," even at the small
on-screen scale this game renders at. Against the Avaris reveal's dark
spire backdrop specifically, the white cloth portions of the outfit
provide most of the readability - the darker portions blend somewhat
into the dark background, similar to (not worse than) the contrast
concern already flagged in Phase A.

A dedicated in-engine close-up (zoomed Camera2D, both facings side by
side) was attempted but failed due to a camera-zoom timing bug in the
throwaway validation script itself (the character ended up outside the
captured frame) - not a defect in the game. Given facing/mirroring was
already confirmed both programmatically and via the transform-faithful
renderer above, this wasn't worth a second real-engine round trip to
fix; flagged here for transparency rather than silently dropped.

### 9 (attack/hitbox relationship - visual assessment)

Not re-screenshotted mid-attack this pass (no `WeaponManifestation` art
exists yet to make an attack pose visually meaningful - see Phase A
§9). Attack hit offsets (26-30px) were confirmed unchanged by the
regression suite. Relative to the now-real 72.3px standing height,
26-30px reach is roughly 36-42% of standing height, which reads as a
plausible melee range for a "precision, agile" character per
ART_BIBLE.md §5 - nothing about the assembled proportions makes the
existing reach numbers look obviously dishonest. A real judgment on
this needs actual manifestation art and an attack-pose screenshot,
which is Phase E's job, not this phase's.

### 10-11. Import settings and performance

Confirmed via the generated `.import` files: `compress/mode=0`
(Lossless) was already Godot's default, unchanged; `mipmaps/generate`
was flipped from `false` to `true` for the 11 used textures (matching
this document's earlier Phase B specification); texture filtering
inherits the project's engine-default Linear mode (no pixel-art
`Nearest` filtering anywhere in this project). Performance: 16
`Sprite2D` draw calls for one Zayr instance (only one exists - the
player), 11 unique textures ranging 166px-434px per side, well under a
few MB total even uncompressed. No atlas packing was built - not
justified at this scale, per instruction.

### 13-14. Debug visual and regression

`DebugVisual` and the `show_debug_visual` toggle are unchanged from
Phase A and still functional - confirmed by re-reading
`PlayerController.gd` (untouched this phase) before starting.

Full regression battery (movement, jump, dash, combo/heavy/aerial/
charged-attack starts, ranged Veyr windup, Veyr Step hide/show +
invulnerability, hurt, death, respawn) - **33/33 checks passed.** One
false failure was found and root-caused during this pass: an initial
version of the throwaway regression script drove `_physics_process()`
directly many times without ever yielding a real engine frame after
`Input.action_press/release()` calls, which left a stale "just pressed
dash" signal that spuriously re-fired ~70 frames later, during the
post-respawn window - a test-harness artifact (Godot's `Input`
singleton needs a real frame tick to flush action state when driven
from script), not a gameplay or Phase B regression. Confirmed by
isolating the exact sequence, then confirming the failure disappears
entirely once a single `await process_frame` follows the dash release.
`PlayerMovement.gd` and `PlayerController.gd`'s death/respawn/dash
logic were not touched this phase, which is consistent with this being
a test-only issue rather than something this phase introduced.

### 17. Assets requiring correction/regeneration

1. **`hair.png`** - needs re-export at the same scale/padding/style
   convention as the other 11 pieces (13px padding, content not
   touching canvas edges, matching alpha-quality profile, matching
   flatter illustrated rendering style).
2. **`forearm.png`** - needs re-export the same way, **and** must end
   at the wrist (no hand baked in) so it doesn't duplicate `hand.png`.
3. **`head.png`** - minor, non-blocking: remove the stray disconnected
   gold collar/necklace fragment near the jaw (contamination from
   neighboring torso artwork).

### Anything requiring approval

- Whether to proceed toward Phase C leaving Zayr **without hair and
  with a visible arm gap** until corrected `hair.png`/`forearm.png`
  arrive, or hold further visual work until those two files are fixed.
- The hand/upper-arm attachment (z-index and position) was placed
  provisionally, deliberately visible rather than hidden - worth a
  proper pass once a corrected forearm exists to actually bridge them.
- `shoulder_material.png`'s placement is a first-pass guess (positioned
  at the shoulder point) and wasn't clearly distinguishable from the
  shoulder pauldron already baked into `upper_arm.png` in review -
  worth a follow-up look once more of the rig is finalized, not
  blocking.

### Correction pass — arm/hand placement fixed against a reference pose

The first assembly pass above was flagged as reading badly at actual
gameplay scale - not just from the known forearm gap, but because the
arm/hand transform values (derived from generic figure-proportion
estimates, §5) put both hands up near shoulder height instead of
hanging at the hip. The user supplied the original full-body reference
artwork these 13 pieces were cut from, which gave real ground truth
instead of estimated proportions.

Comparing the assembly against that reference identified the actual
bug: `FrontHand`/`RearHand` were positioned via a proportion estimate
(§5's generic 7.5-head-figure math), not the reference's actual pose,
landing them ~10-15px too high and too far out to the side. Corrected
in `Player.tscn`:

| Node | Was | Now |
|---|---|---|
| `FrontUpperArm` / `RearUpperArm` | `(±11, -58.45)` | `(±9, -56.5)` |
| `FrontHand` / `RearHand` | `(±13, -38.0)` | `(±7, -29.0)` |
| `Torso` | `(0, -63.4)` | `(0, -61.0)` |

Re-verified in the real engine (not just the Python simulator) via an
isolated, non-smoothed high-zoom camera - hands now rest near the
hip/thigh, matching the reference pose, instead of floating near the
shoulder. Full regression battery re-run after the change: all checks
still pass (no collision/hitbox/facing/Veyr-Step/respawn regression -
this was a pure transform-value change, no structural change).

**Still true, not fixed by this pass**: the hand-to-upper-arm gap
itself remains (still no `forearm.png` to bridge them - see the
correction list above), and at actual ~72px gameplay scale, the
head/neck connection and fine costume detail are still hard to read
clearly, even after this fix - a real, open legibility concern
distinct from the position bug just corrected, worth the user's own
in-editor judgment before deciding whether 72px is final.

---

## ZAYR ANIMATEDSPRITE2D PIPELINE — PHASE 1 (IDLE ONLY)

**Status: architecture implemented, no idle art exists yet.** The
`Skeleton2D`/cutout-rig direction above is superseded (see the notice
at the top of this document). Approved direction going forward:
full-body, hand-authored frame animation via `AnimatedSprite2D`, with
Veyr Edge / Jinn Fire / Veyr / ability VFX staying independent visual
layers exactly as already planned (§3, §9-11 above - none of that
changes, only the *character body* rendering method does).

### New architecture (implemented)

```
Player (CharacterBody2D)
├── CollisionShape2D          — UNCHANGED: 28x46, offset (0,-23)
├── VisualRoot (Node2D)       — UNCHANGED
│    ├── CharacterSprite (Node2D)          — NEW, replaces CharacterRig
│    │    └── AnimatedSprite2D             — NEW, empty (no SpriteFrames yet)
│    ├── WeaponManifestation (Node2D)      — UNCHANGED, still empty
│    ├── JinnFireLayer (Node2D)            — UNCHANGED, still empty
│    ├── VeyrLayer (Node2D)                — UNCHANGED, still empty
│    ├── AbilityVFX (Node2D)               — UNCHANGED, still empty
│    └── DamageVFX (Node2D)                — UNCHANGED, still empty
├── DebugVisual (Polygon2D)   — UNCHANGED node, but now ALSO the
│                                automatic fallback (see below)
├── [Movement, Camera2D, HealthComponent, VeyrComponent, Hurtbox,
│    Combat, RangedAttack, Hitbox, VeyrStep, TrailLine, DepartBurst,
│    ArriveBurst, DepartParticles, ArriveParticles]  — UNCHANGED
```

`CharacterRig` and its 16 `Sprite2D` children (the Phase B static
assembly) were removed from `Player.tscn`, along with the 11 now-unused
`Texture2D` `ext_resource` entries that referenced
`assets/characters/zayr/base/*.png` - those files remain on disk
unchanged, just no longer wired into the live scene. They stay useful
as **reference material** for whoever authors the new frame-based idle
art (same character design, same proportions, same color/material
language), but nothing in `Player.tscn` reads them anymore.

### Automatic fallback (no idle art exists yet)

Since `AnimatedSprite2D.sprite_frames` is currently unset (genuinely
empty - not a fake placeholder), `PlayerController.gd` was extended
with two small helpers:

- `_no_idle_art()`: true whenever `CharacterSprite/AnimatedSprite2D`
  has no `SpriteFrames`, or a `SpriteFrames` without an `"idle"`
  animation.
- `_apply_visual_fallback()`: forces `DebugVisual` visible (and
  `VisualRoot` hidden) whenever `_no_idle_art()` is true, regardless of
  the existing `show_debug_visual` export - production art not existing
  should never leave the player invisible. Called once from `_ready()`
  and every frame from `_update_visual()` (needed because
  `PlayerVeyrStep._end_step()` directly sets `VisualRoot.visible = true`
  when a step ends - without re-asserting the fallback every frame,
  `VisualRoot` would pop back on after a Veyr Step even with nothing in
  it to show; caught by regression testing, see below).

Once real idle frames exist and are assigned to a `SpriteFrames`
resource with an `"idle"` animation, this fallback automatically stops
firing and `CharacterSprite`/`AnimatedSprite2D` takes over as the
visible character - no code change needed at that point, just dropping
in the art and a `SpriteFrames` resource.

### Idle animation requirements (spec, no frames exist yet)

Per direction: full-body frames, transparent PNG, same character/
proportions/colors in every frame, no baked background, no baked Veyr
Edge/Veyr particles/damage effects, consistent foot contact, calm/
controlled motion (breathing, slight cloth settling, subtle hair
movement - not exaggerated), seamless loop. Jinn Fire only if it's
already part of the approved base visual at rest - otherwise it stays
in `JinnFireLayer`, not baked into the body frames.

### Asset organization (recommendation)

```
assets/characters/zayr/animations/idle/
    idle_01.png
    idle_02.png
    idle_03.png
    idle_04.png
```

Individual numbered PNGs, not a spritesheet, for v0.1: this project has
zero existing atlas/spritesheet tooling anywhere (confirmed in
ASSET_AUDIT.md), individual files are trivial to inspect, replace, or
reorder one at a time in Godot's `SpriteFrames` editor, and at 4-6
frames the difference in import convenience is negligible. Revisit only
if frame counts grow large enough that file-count management itself
becomes the bottleneck - not a concern at this scale.

### Frame count and FPS (recommendation)

**4-6 frames**, matching the direction's own target - not treated as
final until real-game testing (per instruction). For a calm, restrained
idle (breathing + slight cloth/hair settling, not a snappy loop), a
conservative **6-8 FPS** is recommended for a 4-6 frame loop - slow
enough that individual hand-authored frames don't read as jittering,
fast enough that the loop doesn't feel like a slideshow. This is a
starting recommendation to validate against real playback once frames
exist, not a locked number. Animation speed is intentionally decoupled
from gameplay state timing (no gameplay system reads or depends on the
`AnimatedSprite2D`'s playback rate) - matching the explicit instruction
not to tie them together.

### Scale / ground-origin handling

Unchanged from the established convention: **72px approximate rendered
standing height** at `Camera2D` zoom 1.0 remains the target (per the
prior approval - not reopened here), source frames should be authored
significantly larger than 72px (same ~4-6x oversampling logic as
Phase A §12) and scaled down at import, and the **28x46 collision box
stays exactly as-is** - collision was not touched by this pass and
isn't proposed to change. Ground contact (`AnimatedSprite2D`'s own
`offset`/`centered` properties, analogous to the `Sprite2D.offset`
convention used for the retired rig pieces) must keep each frame's feet
landing at local Y=0, matching every other entity's "origin at feet"
convention already established project-wide.

### Facing

Unchanged: `VisualRoot.scale.x` mirroring (driven by
`movement.facing`, already implemented, confirmed still working by
regression) continues to be the only facing mechanism. Only one
directional set of idle frames should be authored - no separate
left-facing frames, per instruction.

### Real-camera validation

**Not yet meaningful** - no idle frames exist, so there is nothing
character-specific to evaluate at Stage 1/4/5 beyond confirming the
fallback renders correctly (it does - screenshot-confirmed: `DebugVisual`
shows the same per-state-tinted rectangle used since Phase A, correctly
positioned and grounded, in `AvarisVerticalSlice.tscn`'s Stage 1). Real
scale/contrast/readability/motion evaluation against Stage 1/4/5 is
deferred until actual idle frames exist - re-running that validation
against a placeholder rectangle would tell us nothing new.

### Regression

Full battery re-run after the architecture change (movement, jump,
dash, facing mirror, attack hit offsets, combo start, Veyr Step
hide/show + invulnerability, hurt/death/respawn) - **all passed**,
including one real bug caught and fixed during this pass (not a
pre-existing issue): `PlayerVeyrStep._end_step()` unconditionally sets
`VisualRoot.visible = true`, which - before the fix - left `VisualRoot`
visible again after a Veyr Step even while there's no idle art in it to
show, alongside `DebugVisual` also being visible (violating "never both
visible at once"). Fixed by re-asserting the fallback every frame (see
above), not by changing `PlayerVeyrStep.gd` - `VisualRoot` toggling
`visible` around its own step window is still correct behavior once
real idle art exists, so the fix belongs in the fallback logic, not the
ability code.

### Exact art files required

```
assets/characters/zayr/animations/idle/idle_01.png
assets/characters/zayr/animations/idle/idle_02.png
assets/characters/zayr/animations/idle/idle_03.png
assets/characters/zayr/animations/idle/idle_04.png
```

(4 files minimum per the target range; up to `idle_06.png` if 6 frames
end up feeling right once tested.) Each: transparent PNG, full body,
same character design/proportions/colors across every frame, source
resolution well above 72px (oversampled, per §12's existing logic),
consistent foot placement across all frames so the loop doesn't
"shuffle" at the ground line. No spritesheet needed for v0.1 (see
asset-organization recommendation above).

### Anything requiring approval

- The 6-8 FPS idle-speed recommendation and 4-6 frame count are
  starting points, not locked - real playback testing once frames
  exist may call for adjustment.
- Whether Jinn Fire should have ANY subtle presence in the idle frames
  themselves (per ART_BIBLE.md §2's "may become visible through...
  emotional intensity" - arguably not applicable to a calm idle) or
  stay strictly absent from the body frames and live only in
  `JinnFireLayer` - leaning toward "absent from idle, `JinnFireLayer`
  only," but this is a design call, not decided here.
- The retired 13-piece rig art's future: kept as reference only per
  instruction, no action needed, but flagging in case there's a
  preference to relocate/rename those files now that they're no longer
  part of the active pipeline (not done here - no file moves, per not
  touching anything beyond what was asked).

---

## Phase 1 Integration — IDLE v0.1 (Results)

**Status: IDLE v0.1 implemented and validated. Real production idle
animation is now the default player visual.**

### Asset audit

All four frames (`idle_01.png`-`idle_04.png`, `assets/characters/zayr/animations/idle/`)
audited the same way as the earlier rig pieces (Pillow: alpha
histograms, content bounding boxes, red/green background-composite
bleed tests) plus direct visual inspection:

- Genuine transparency confirmed on all 4 - 0% background bleed at the
  a≥250 threshold (same test used on the earlier rig art).
- No checkerboard or baked background on any frame.
- No neighboring-content contamination (no stray fragments, unlike the
  earlier `head.png` issue).
- Same character design, face, costume, and proportions across all 4 -
  confirmed by direct visual comparison, a dramatic quality step up
  from the earlier 13-piece rig extraction (full coherent front-facing
  illustrations, not segmented body parts).
- No cropped anatomy, no differing costume/anatomy between frames.
- One minor technical note, not a defect: `idle_03.png`'s canvas is
  1035px tall vs. the other three's 1024px, though all four share an
  identical 20px bottom-padding margin. At the ~72px final render
  scale this produces at most a 0.8px foot-position deviation on that
  one frame (measured precisely, see below) - imperceptible, not
  corrected, canvases left untouched.

No serious asset problem found - proceeded with integration.

### AnimatedSprite2D configuration

`Player.tscn`: `VisualRoot/CharacterSprite/AnimatedSprite2D` now has a
`SpriteFrames` resource with one animation, `"idle"` (`loop = true`,
`speed = 6.0` fps), referencing `idle_01.png`-`idle_04.png` directly
(no spritesheet, per the recommendation). Node transform:
`centered = false`, `scale = (0.073, 0.073)`, `offset = (-212, -1004)` -
`offset` derived from the frames' shared pivot convention (feet at
source row ~1004, horizontally centered around source column 212 in
the three consistently-sized frames).

### Scale / measured height

Precisely measured (Pillow, exact alpha bounding box, not estimated)
for all four frames with the transform above:

| Frame | Standing height | Foot Y (should be 0) |
|---|---|---|
| idle_01 | 71.47px | 0.00px |
| idle_02 | 67.09px | 0.00px |
| idle_03 | 71.83px | 0.80px |
| idle_04 | 68.62px | 0.00px |

All within the approved ~72px target. The 67-72px range across frames
is the hair silhouette's own volume changing frame to frame (the
intended "subtle hair movement"), not a scale error - confirmed by the
body/torso/leg silhouette staying pixel-stable across frames (see loop
grid, below) while only the hair extent varies.

### Ground contact

3 of 4 frames land feet at exactly Y=0.00 (pixel-exact). `idle_03`
lands at Y=0.80 (sub-pixel deviation from its 11px-taller canvas) -
confirmed via direct screenshot comparison (see loop grid) that this
is not visible: a red reference line held at a fixed screen row lines
up with the boot soles identically across all six sampled frames
(idle_01 through idle_04 and a second loop of idle_01/idle_02).

### Facing / mirror

Confirmed both directions via the existing `VisualRoot.scale.x`
mechanism (unchanged this pass) - `facing = 1.0` → `scale.x = 1.0`,
`facing = -1.0` → `scale.x = -1.0`. No separate left-facing frames were
created, per instruction.

### Loop quality

Captured all 4 frames plus a second pass over frames 1-2 at 6x zoom,
fixed non-smoothed camera, for direct comparison (`loop_grid.png` -
see report). Body/legs/feet are pixel-stable across every sample; all
visible motion is concentrated in the hair silhouette, reading as
calm, subtle movement, not exaggerated - matches the brief's intent
well. No visible cloth-settling motion distinct from the hair (the
white/black tassets look essentially static across frames) - not a
defect, just an observation; hair alone is carrying the "breathing"
read successfully.

**The `idle_04 -> idle_01` wrap specifically**: measured objectively
(Pillow pixel-difference, all four frames aligned to a shared canvas
using the actual `Player.tscn` offset, mean absolute RGB difference per
transition) rather than judged by eye alone:

| Transition | Mean abs. pixel difference |
|---|---|
| idle_01 → idle_02 | 20.5 |
| idle_02 → idle_03 | 12.1 |
| idle_03 → idle_04 | 19.3 |
| **idle_04 → idle_01 (loop wrap)** | **26.0** |

The loop wrap is the single largest frame-to-frame jump in the
sequence - about 27% larger than the next-biggest transition
(`idle_01→idle_02`) and more than double the smallest
(`idle_02→idle_03`). This is a real, measurable asymmetry, not
imagined. Checked whether reordering the same 4 frames could reduce it:
the best alternative ordering (`01→02→04→03→01`) lowers the worst-case
jump from 26.0 to 22.8 (~12% better) but *raises* the total motion
across the full loop (80.6 vs. 77.9) - a genuine trade-off (a smaller
peak jump vs. more evenly-distributed motion throughout), not a clear
win either way. **Not applied** - reported per instruction rather than
silently changed, and no interpolation frames were manufactured in
code. This is worth judging against real-time playback (which this
static/screenshot-based validation methodology cannot fully substitute
for) before deciding whether it's worth reordering, retiming, or
leaving as-is - at 6 FPS (167ms/frame) the practical perceptibility of
this specific delta is genuinely an open question.

### Veyr Step interaction

Confirmed via both the regression suite and a real screenshot taken
immediately after a step completes: `VisualRoot` correctly hides during
the step (unchanged `PlayerVeyrStep.gd` behavor), and immediately after
`_end_step()` restores it, the idle animation is already playing
(`anim.is_playing() == true`, `anim.animation == "idle"`) - **no blank
player frame after reform**, confirmed both structurally and visually
(screenshot shows Zayr fully rendered, standing, idle pose, with the
existing depart/arrive Veyr burst VFX still fading out alongside him,
exactly as designed).

### Regression

Full battery re-run (movement, jump, wall-slide/jump code paths, dash,
combo/heavy/charged-attack starts, ranged Veyr windup, Veyr Step
hide/show + invulnerability + Perfect Step trigger, hurt, death,
respawn) - **26/26 checks passed.** No gameplay, collision, or timing
regression. As expected/instructed, run/jump/fall/dash/combat/hurt/
death all continue showing the idle animation (no dedicated animations
for those states were built this pass).

### Source frames needing correction

None required. The `idle_03.png` canvas-height note above is cosmetic
and sub-pixel at render scale - not flagged as needing correction. The
loop-wrap timing/ordering question above is a judgment call for real
playback, not a defect requiring art correction.

---

## Phase 1 — RUN v0.1 Integration (Results)

**Status: RUN v0.1 implemented and validated. APPROVED for continued
production**, after one real, disqualifying defect was found, reported,
and corrected mid-pass (see below).

### Asset audit

All six frames (`run_01.png`-`run_06.png`,
`assets/characters/zayr/animations/run/`) audited with the same method
as idle - Pillow alpha histograms/bleed tests, plus (new for this pass,
since this art has more edge-touching content than idle) **connected-
component analysis** to explicitly catch disconnected/extra anatomy,
per this task's specific instruction to compare "hands, legs, boots
between frames" for AI-generated art.

**One serious, disqualifying defect found**: `run_05.png` (as
originally delivered) contained a **fully disconnected duplicate boot
fragment** - a second, unattached foot floating in the bottom-left
margin, ~90px from the actual character, confirmed via 8-connected-
component labeling to have zero pixel-adjacency to the real figure
(main character: 80,327px; stray fragment: 615px, isolated). This is
exactly the "accidental extra anatomy" the audit was told to watch for.
**Stopped and reported per instruction rather than silently
compensating** - a code-side attempt to mask or crop this
programmatically was considered and rejected as against the explicit
"do not hide bad source artwork with code" instruction. A direct,
surgical fix (deleting only the isolated 615px component, zero pixels
of the actual character touched) was prepared but its execution was
correctly blocked by the permission system pending explicit approval -
exactly the right outcome, since modifying a shipped source asset
should not be a unilateral decision. **The user corrected and re-supplied
`run_05.png` directly**; re-audited after the update - confirmed clean
(2 connected components: the 80,327px main figure, unchanged, plus a
single harmless 1px anti-aliasing speck, same category of negligible
noise present in every other frame). Integration proceeded with all
six frames.

All other checks passed on every frame: genuine transparency (0%
background bleed), same canonical character/face/hair/costume across
all six (directly cross-referenced against the approved idle frames -
same design), no missing limbs, no accidental Veyr Edge, no baked Jinn
Fire/Veyr VFX, sensible stride-cycle progression frame to frame. One
negligible note: `run_02.png` has an 8x11px sliver (35px area) at its
right canvas edge - at final render scale this is sub-pixel
(~1x1.5px), not visible, not flagged as needing correction.

### SpriteFrames "run" configuration

Added as a second animation on the same `SpriteFrames` resource
(`VisualRoot/CharacterSprite/AnimatedSprite2D`) already holding
`"idle"`: 6 frames (`run_01`-`run_06`), `loop = true`, `speed = 10.0`
fps. `idle` is unchanged (4 frames, 6 fps, loop) - confirmed via
regression, not touched this pass.

### Animation-state integration

`PlayerController._update_character_animation()` (called every frame
from the existing `_update_visual()`): `"run"` while
`state == State.RUN` (using the existing, unmodified state machine -
grounded + horizontal velocity, per `_update_state()`'s existing
logic), `"idle"` for every other state. This means jump/fall/wall-
slide/dash/combat/hurt/death all correctly fall back to idle, per
instruction - no new states, no PlayerController architecture changes.
Purely visual: reads `state`, never writes to it; never touches
`movement`/`combat`/collision.

### Scale (a real correction made mid-pass)

**First hypothesis (0.073, same as idle) was wrong and corrected after
measurement, not by eye.** Reasoning: idle and run frames come from
visibly different canvas conventions (idle: tall portrait canvas,
mostly-vertical standing pose; run: square canvas, dynamic diagonal
sprint lunge) - a `Sprite`-family node has one shared `scale`/`offset`
for whichever animation is playing, so this needed a deliberate,
measured choice, not an assumption that "same scale" would look right
just because it was the same character.

At the initial 0.073 guess, precise measurement (Pillow bbox, plus a
direct pixel-count check against the actual rendered screenshot,
**not** just eyeballing the screenshot - which had looked "fine" at a
glance and would have shipped a real bug) showed the running character
rendering at only **~36-38px tall - roughly half the idle height**,
confirmed both analytically and empirically (measured 38px in an
actual screenshot). This is well beyond normal "lunge pose is shorter
than standing" compression (typically 75-90% of standing height for a
running lean) and would have read as a visible scale-pop between idle
and run. A native-pixel side-by-side of `idle_01.png` and `run_01.png`
also showed the run art's head/shoulders drawn larger relative to its
own canvas than idle's - the two batches don't share one "camera
distance" convention, so no single scale factor could have been
assumed correct without checking.

**Corrected to `scale = 0.13`** (from 0.073), landing all six frames in
a 59-66px range (82-92% of idle's ~72px) - a plausible natural running-
lean compression, not a scale mismatch. Re-verified via fresh
screenshots after the correction: consistent apparent character size
across all six frames and against the already-validated idle scale.
`offset = (-256, -512)` (canvas-center X, canvas-bottom-edge Y, matching
the majority ground-contact convention - see below) - both values
stored in `PlayerController.gd`'s `ANIM_TRANSFORM` dict and swapped in
alongside the animation itself in `_update_character_animation()`,
purely visual, never touching physics/collision.

### Ground contact

Per instruction, not normalized on head height - grounded on the
majority foot-contact convention instead. 4 of 6 frames (`run_01`-`04`)
have their lowest point exactly at their own canvas's bottom edge (zero
padding); `run_06` sits 16px higher in source space (~2px at render
scale) and `run_05` sits 20px higher (~2.6px at render scale) - both
read, on inspection of the actual stride-cycle screenshots, as
plausible "foot lifted / mid-stride" moments rather than errors, not a
float/sink defect. Real screenshots (TestArena, 5x zoom, all six frames
sampled against a fixed reference line) confirm: natural alternating
ground-contact pattern consistent with an actual running gait, no
excessive bouncing, no visible floating.

### Facing / direction change

Confirmed via the existing `VisualRoot.scale.x` mechanism, unchanged
this pass: `facing = 1.0 -> scale.x = 1.0`, `facing = -1.0 -> scale.x =
-1.0`, verified both via regression and real screenshots (running
right, then switching to running left mid-sequence) - mirroring stayed
clean, `"run"` kept playing through the direction change (no
interruption, no animation restart), no separate left-facing frames
created.

### Idle <-> run transitions

Confirmed via regression: `state == State.RUN` and moving -> `"run"`
plays; releasing movement -> reverts to `"idle"` once
`absf(velocity.x) <= 1.0` (the existing, unmodified `_update_state()`
threshold) drops state back to `IDLE`. No scale/vertical/horizontal pop
observed in testing beyond the expected one-time transform swap (scale
0.073<->0.13, offset change) that happens exactly at the moment the
animation itself switches - inherent to the two art batches using
different canvas conventions, not an integration bug. `play()` is only
called when the target animation actually differs from the current one
(`if _character_sprite.animation != desired`), so continuous running
does not restart the animation repeatedly.

### Real-camera validation

Real-GPU, real-camera screenshots captured while continuously running
(120 physics frames each, ~2 real-time seconds) through Stage 1, Stage
2, Stage 3, Stage 4 (Avaris reveal), and Stage 5 (mini-boss arena) -
`state == RUN` and `anim == "run"` confirmed at every stage via direct
inspection during capture. Zayr remains clearly readable while moving
in all five, including Stage 4's dark/detailed spire backdrop
specifically flagged for attention - the white costume portions
continue to carry most of the contrast, same as they did for idle.

### Regression

Full battery re-run after both the initial integration and the scale
correction: **32/32 checks passed** both times (collision, facing,
run-state reached, run/idle transform switching, direction-change
mirroring, jump/dash/combo/heavy/charged/ranged-Veyr starts, Veyr Step
hide/show + invulnerability + Perfect Step trigger, hurt, death,
respawn). No collision, timing, or physics regression - confirmed the
animation-selection code only ever reads `state`/`movement.facing`,
never writes to gameplay state.

### Frames needing correction

None remaining. `run_05.png` needed and received a correction (the
disconnected boot fragment, described above) - already resolved by the
user's updated file, re-audited clean. No other frame requires
correction; the `run_02.png` edge sliver and the `run_05`/`run_06`
ground-contact-height notes above are both sub-visible at render scale,
not flagged.

---

## Phase 1 — JUMP/FALL v0.1 Integration (Results)

**Status: JUMP v0.1 and FALL v0.1 implemented and validated. APPROVED
for continued production.**

### Re-audit of corrected assets

Both sets re-audited with the same method (alpha/bleed test +
connected-component analysis + direct visual inspection) that first
found the contamination (see the earlier pre-integration audit report
delivered directly to the user, not filed in this document at the
time). **All previously reported contamination is confirmed gone**:

| Frame | Before | After |
|---|---|---|
| `jump_01.png` | clean (unchanged) | clean, byte-identical main figure (49,697px) |
| `jump_02.png` | 2 fragments (365px, 150px) | **clean** - single component, 51,897px |
| `jump_03.png` | 1 fragment (267px) | **clean** - main figure 59,581px + only negligible noise |
| `jump_04.png` | clean (unchanged) | clean, byte-identical main figure (62,331px) |
| `fall_01.png` | 2 fragments (249px, 331px) | **clean** - main figure 55,197px + only negligible noise |
| `fall_02.png` | 1 fragment (760px - the largest found) | **clean** - main figure 60,634px + only negligible noise |
| `fall_03.png` | 1 fragment (419px) | **clean** - main figure 61,098px + only negligible noise |

Every main-character pixel count is **byte-identical** to the original
pre-correction measurement, confirming only the stray fragments were
removed and no character content was altered. Visually re-confirmed:
complete head/hair, both arms/hands, both legs/boots, all cloth panels
present on all 7 frames; same canonical Zayr design/costume/face as
idle/run. Genuine transparency (0% background bleed) on all 7. No
detached anatomy, no neighboring-pose fragments remaining. Integration
proceeded.

### SpriteFrames configuration

Two more animations added to the same `SpriteFrames` resource (now 4
total: idle, run, jump, fall):
- **`jump`**: 4 frames, **`loop = false`**, `speed = 12.0` fps.
- **`fall`**: 3 frames, `loop = true`, `speed = 6.0` fps.

`idle` and `run` untouched - confirmed via regression (frame counts,
speeds, loop flags all still exactly as approved).

### State selection (reused, not rebuilt)

`_update_character_animation()` extended to also read `State.JUMP` and
`State.FALL` - both already existed and were already computed correctly
by the pre-existing, untouched `_update_state()`:
`state = State.JUMP if velocity.y < 0.0 else State.FALL` while airborne.
No new state logic was written - jump/fall selection is a direct,
one-line reuse of gameplay state that already encoded "rising" vs.
"descending" before this pass began. `RUN`→`"run"`, `JUMP`→`"jump"`,
`FALL`→`"fall"`, everything else (including grounded+stationary)
→`"idle"`.

### Jump hold-last-frame behavior

Implemented by relying on Godot's own built-in non-looping-animation
behavior rather than new code: `loop=false` means once `AnimatedSprite2D`
reaches frame 4, `is_playing()` becomes `false` but the frame index
does not reset - combined with the existing `if
_character_sprite.animation != desired: play(desired)` guard (unchanged
from the run pass), the jump animation is never re-triggered while
`state` stays `JUMP`, so it naturally holds on the final frame for as
long as the ascent continues past the animation's own duration. No new
"hold" logic was needed.

### Scale (measured independently for each set - corrected once, after real playtest feedback)

**First pass (`scale = 0.08`) was wrong and was corrected after the
user reported jump/fall reading "a lot smaller" than run in actual
play.** The original reasoning - a native-pixel side-by-side showing
jump/fall's *head* size comparable to idle's, so a modest scale close
to idle's 0.073 should look right - was too narrow a check. A fixed-
window side-by-side of idle/run/jump/fall heads confirmed head size
*was* comparable, but that was the wrong metric: jump/fall's tucked,
coiled poses have a much shorter *total silhouette* (27-40px at 0.08)
than idle/run's 60-72px, and a viewer judges "how big does Zayr look"
by overall silhouette presence, not head width in isolation - so a
correct head size at the wrong overall scale still reads as a visibly
smaller character. This is exactly what got reported.

**Corrected to `scale = 0.13`** (recomputing all 7 per-frame offsets to
match, keeping the same `TARGET_CORE_Y = -45` core-anchor logic) -
landing the extended airborne poses (`jump_02-04`, all of `fall_01-03`)
at 57-66px, squarely inside idle/run's 59-72px range;
`jump_01`'s coiled launch crouch still reads shorter (40px), which is
correct and expected for a distinctly crouched pose, not a bug.
Notably, `0.13` is the same scale value `run` already uses - plausibly
because run/jump/fall share one dynamic-action art convention distinct
from idle's calmer portrait framing, though not confirmed as
deliberate.

Re-verified via a direct four-way comparison screenshot (idle/run/jump/fall
captured at the identical camera zoom, cropped to the same window) -
all four now read as consistently-sized. Full regression re-run after
the change: all checks passed, including explicit assertions that the
new `0.13` scale is actually applied for both `jump` and `fall` and
that collision/respawn are unaffected.

### Ground/core anchoring (a deliberate departure from idle/run's method)

Per instruction, **not** foot-anchored. Jump's 4 frames range 27-40px
in raw content height (a >30% swing) and fall's are more consistent
(~40px each) but neither behaves like a standing/running pose where
"feet at a fixed baseline" is a meaningful anchor - a coiled launch
crouch and a fully-extended airborne reach don't share a stable "foot
position" the way idle/run's grounded poses do.

Instead, each of the 7 frames gets **its own offset**, computed so that
frame's own content-bbox *center* (used as a practical stand-in for
torso/center-of-mass, since precise per-frame skeletal landmarks aren't
available) lands at the same fixed world Y (`-45`, roughly torso/chest
height) regardless of pose. This required extending the transform
system beyond what idle/run used (a single offset for the whole
animation) - added `ANIM_FRAME_SCALE`/`ANIM_FRAME_OFFSETS` plus a
`frame_changed` signal connection (`PlayerController._apply_frame_transform()`,
called on every `play()` and every frame change) so the per-frame
offset re-applies continuously during playback, not just once per
animation switch. `idle`/`run` are untouched - they still use the
original single-offset `ANIM_TRANSFORM` path.

Verified analytically: computed world-space bbox-center for all 7
frames using their actual chosen offsets - **spread across frames was
exactly 0.000px** (by construction, since the offsets were solved for
this). Verified visually: a captured jump frame (the coiled `jump_01`
launch pose) and a captured fall frame from the same jump arc, compared
directly - the torso sits at visibly the same on-screen height in both,
despite the pose being dramatically different (crouched vs. extended);
no teleporting observed.

### Jump FPS - corrected once, using the actual physics constants

Initial default assumption (10 fps, matching run) was checked against
the real ascent duration before committing to it, not assumed: ascent
time to peak = `|jump_velocity| / gravity` = `500 / 1400` ≈ **0.357s**
(`PlayerMovement.gd`'s actual exported values, not estimated). At 10
fps, the 4-frame jump animation's total duration (0.4s) is *longer*
than the real ascent - meaning frame 4 would almost never actually be
reached before the state switches to `FALL`, undermining both "the
four jump frames represent progression through ascent" and the
explicit hold-last-frame instruction (nothing to hold if frame 4 is
essentially never shown). **Corrected to `speed = 12.0` fps** -
4 frames ÷ 12 fps = 0.333s, safely inside the 0.357s ascent with a
~24ms margin for the final frame to actually display before the
transition to fall. This is the *minimum* fps at which all 4 frames
fit the real ascent window - checked, not guessed.

One methodology note: exact frame-by-frame timing could not be
precisely verified through the scripted headless test harness -
`AnimatedSprite2D` frame advancement is driven by real engine
process-time, not the manually-stepped physics delta this project's
throwaway test scripts use, so short animations sampled that way drift
out of sync with the simulated physics timeline (confirmed by
comparing results with and without disabling the player's automatic
`_physics_process`, which changed the measured ascent duration
significantly). The `speed = 12.0` choice is grounded in the actual
gameplay physics constants directly, not in this imprecise timing
measurement.

### Fall FPS

Per instruction, not copied from run's 10 fps. Started conservative at
**6 fps** (matching idle's cadence) since fall duration varies with
airtime and loops rather than needing to fit a fixed window the way
jump does - real screenshots (below) at this rate read as clearly
airborne and dynamic without feeling frantic. Not adjusted further this
pass.

### Transitions

Confirmed via regression (structural) and real screenshots (visual):
`idle→jump`, `run→jump` (jump takes over correctly even when already
moving), `jump→fall` (automatic the instant `velocity.y` crosses zero,
via the untouched `_update_state()` logic), `fall→idle` and `fall→run`
on landing (whichever the grounded state naturally resolves to from
existing move input). No scale pop, no horizontal pop, no restart-while-
still-airborne observed. The only transform change that happens at a
transition is the deliberate one (the scale/offset swap between
animations with different canvas/anchoring conventions) - not an
artifact.

### Direction change while airborne

Confirmed via regression: `movement.facing`-driven `VisualRoot.scale.x`
mirroring (unchanged mechanism) works correctly mid-air, including
switching direction while jumping/falling - the animation itself
doesn't interrupt or restart when facing flips, only the mirror scale
changes, exactly as it does for idle/run.

### Real-camera validation

Real-GPU screenshots captured for: a full jump-then-fall arc (isolated,
non-smoothed camera, core-anchoring visually confirmed as described
above), and actual in-game jumps at Stage 1, Stage 3, Stage 4 (Avaris
reveal - specifically flagged for attention), and Stage 5 (mini-boss
arena), each captured precisely at `state == JUMP` and, in a second
dedicated pass, precisely at `state == FALL` (the first attempt's fall
captures overshot into landing due to a fixed-wait timing choice in the
throwaway script - corrected by waiting for the actual state
transition instead of a frame count). Zayr reads as a clearly airborne,
identifiable figure in all cases, including against Stage 4's dark
spire backdrop. The dramatic windswept-hair/wing-like-cloth styling
(distinct from idle/run's calmer look, noted in the pre-integration
audit) is visible but reads as dynamic energy rather than clutter at
actual render scale - a closer call than idle/run's cleaner silhouettes
but not judged distracting.

### Regression

Full battery re-run (structurally covering movement, jump, dash, all
four attack types, ranged Veyr, Veyr Step + Perfect Step + invulnerability,
hurt, death, respawn, collision, gravity/jump-velocity/run-speed
constants, idle↔run unaffected, facing mirror both grounded and
airborne) - **40/40 checks passed**, both before and after the fps
correction. No collision, timing, gravity, jump velocity, or movement
speed changed - confirmed by direct assertion in the regression script,
not just absence of visible symptoms.

### Frames needing correction

None. All 7 corrected frames passed the full re-audit.

---

## Phase 1 — WALL SLIDE v0.1 Integration (Results)

**Status: WALL SLIDE v0.1 implemented and validated. APPROVED for
continued production.**

### Asset audit

Same method as run/jump/fall (alpha/bleed test + connected-component
analysis + direct visual inspection) applied to all 3 frames before any
integration work began. **Result: clean on first delivery** - unlike
run/jump/fall, no correction round was needed here. Every "extra"
connected component found was 1-2px isolated interior noise (18-6
scattered single/double pixels per frame, none edge-adjacent, none
exceeding the "significant" 10px threshold used throughout this
project's audits) - a materially different, harmless signature from the
100s-of-pixels edge-contamination fragments found and corrected in
run/jump/fall. 0% background bleed on all 3. Visually confirmed:
complete head/hair, both hands (one gripping the wall, one trailing),
both legs/boots, all cloth panels, same canonical Zayr
design/costume/face as every prior animation, no baked Veyr Edge, no
baked Jinn Fire/Veyr VFX. Integration proceeded without needing to stop
or report a defect.

One structural note distinct from every prior set: **the wall surface
itself is baked into the artwork** - a vertical wall edge is visibly
rendered near the right side of all three frames, with the character's
contact hand and foot pressed against it. This directly shapes the
scale/anchor approach below (the baked wall edge has to line up with
the real game wall, not just the character's own silhouette).

### SpriteFrames configuration

Fourth non-idle animation added: **`wall_slide`**, 3 frames,
`loop = true`, `speed = 6.0` fps (the instructed starting point,
unchanged after real playback testing - felt appropriate, not adjusted
further). `idle`/`run`/`jump`/`fall` all confirmed unchanged via
regression.

### State integration

`_update_character_animation()` extended with one more branch:
`State.WALL_SLIDE` → `"wall_slide"`, reusing the existing, untouched
`is_wall_sliding` logic in `PlayerMovement.gd` (`on_wall and not
on_floor and velocity.y > 0.0`) - no new gameplay state, no changed
wall-detection/physics/collision, exactly as instructed.

### Visual orientation - a real architecture gap found and closed correctly

Per instruction §4, checked whether `movement.facing` reliably
corresponds to which side is walled, rather than assuming it does.
**It does not**: `is_wall_sliding` triggers on wall contact alone (see
above) with no input-direction requirement, while `facing` only updates
when `move_input != 0.0` - meaning `facing` can be stale, or reflect
input that has nothing to do with which wall is currently touched. The
correct source of truth was already being computed
(`body.get_wall_normal().x`) but stored in a **private**
`_wall_normal_x`, unreadable outside `PlayerMovement.gd`.

Per the instruction's own guidance ("report it instead of altering
gameplay logic unnecessarily"), this was **not** worked around by
misusing `facing`. Instead, `_wall_normal_x` was renamed to a public
`wall_normal_x` (removing the underscore) - a pure visibility change,
identical in spirit to how `facing` itself is already documented as
"Public so other components... can read Zayr's current facing." Zero
behavior change: the same two assignment sites
(`wall_normal_x = body.get_wall_normal().x` on wall contact,
`body.velocity.x = wall_normal_x * wall_jump_horizontal_speed` on wall
jump) do exactly what `_wall_normal_x` already did, just under a
readable name. `PlayerController._update_visual()` now computes mirror
as `-movement.wall_normal_x` specifically during `State.WALL_SLIDE`
(the art's unmirrored default has the wall on Zayr's right, i.e.
`wall_normal_x < 0` - hence the negation) and `movement.facing` for
every other state, unchanged.

### Scale - measured independently, checked against the jump/fall lesson before committing

Content bbox heights (all 3 frames, uniform 550×1030 canvas) are
719-828px raw - much closer in magnitude to idle's own raw content
height (840-990px) than jump/fall's had been, so a scale near idle's
0.073 was tried as a starting hypothesis rather than jump/fall's
original (wrong) 0.08 guess. Before committing, ran the same fixed-
window native-pixel head comparison that caught the jump/fall bug
(idle/run/jump/wall_slide heads cropped to an identical window and
viewed side by side) - wall_slide's head read as comparable in size,
consistent with the raw-content-height reasoning. **`scale = 0.075`**
was chosen and gives 70.1-72.2px across all three frames - landing
inside idle/run's 59-72px range on the first attempt, not requiring a
post-hoc correction this time.

### Wall/body visual anchor

Two-part anchor, solved together:
- **X**: each frame's baked-in wall-edge column was located directly
  (a persistent near-vertical run of opaque pixels near the right
  content edge, distinct from the hand/foot which are only locally
  opaque) - found at source columns 510/480/449 for frames 1/2/3. Each
  frame's offset.x was solved so that column lands at **world X = 14**,
  the player's actual 28-wide collision box's right edge
  (`CollisionShape2D` offset `(0,-23)`, half-width 14) - i.e. the exact
  point real gameplay collision touches a wall on Zayr's right, the
  art's default orientation. Verified analytically (recomputing world X
  for the wall column at the chosen offset returns exactly 14.00 for
  all three frames) and visually (screenshots below show the hand/foot
  contact point sitting almost exactly on the real wall's rendered
  edge, both sides).
- **Y**: same bbox-center core-anchor convention as jump/fall
  (`TARGET_CORE_Y = -45`), so the torso doesn't jump around between the
  three slide-pose frames.

A small presentation-only offset from the physics body was accepted
here (the anchor targets a specific pixel column of baked-in wall art
landing at the collision edge, not the character's own silhouette
edge) - the collision body itself was never moved, only the
visual's offset/scale, exactly as instructed.

### Left/right wall results

Verified via real, physics-driven wall contact (not just direct state
assignment) in both `TestArena.tscn`'s wall-jump corridor and
`AvarisVerticalSlice.tscn`'s Stage 3 shaft:

- **Right wall** (`wall_normal_x = -1.0`): `VisualRoot.scale.x = 1.0`
  (unmirrored, matching the art's default) - confirmed correct via
  screenshot, hand/foot pressed against the real wall surface.
- **Left wall** (`wall_normal_x = +1.0`): `VisualRoot.scale.x = -1.0`
  (mirrored) - confirmed correct via screenshot, contact side correctly
  flips to the character's left along with the mirror.

One test-methodology note, same category as the earlier jump-timing
issue: an initial attempt at a real-physics wall-contact test produced
an inconsistent result (right-wall contact appeared to fail) traced to
the same double-processing artifact found during jump-arc testing
(the player node's own automatic `_physics_process` running alongside
manually-driven calls) - resolved by disabling automatic processing on
the test player node, after which both sides behaved identically and
correctly. Not a gameplay bug; a test-harness quirk specific to this
project's throwaway-script methodology, now a known, documented pattern
in this project's testing history.

### Hand-to-wall stability

The X-anchor is a single fixed value per frame (not a live per-frame
recompute during play), so there is no frame-to-frame jitter possible
by construction - confirmed visually across the loop, the contact
point does not visibly shift.

### Loop quality / playback

Held for an extended run (multiple loop cycles at 6 fps). Torso stable
(same core-anchor construction as jump/fall). Hair reads as dramatically
windswept (even more than jump/fall, consistent with "sliding fast
against a wall" as a design choice) but not distracting at real render
scale. 6 fps read as appropriate for a sustained, held state (unlike
jump's tight timing constraint against a fixed physics window, wall
slide has no such constraint since it can be held indefinitely) - not
adjusted from the instructed starting point.

### jump/fall → wall-slide, wall-slide → wall-jump

Both transitions confirmed via real physics-driven testing: touching a
wall while falling correctly switches `fall`→`wall_slide`; wall-jumping
off correctly switches `wall_slide`→`jump`→`fall` (reusing the existing
jump/fall animations, exactly as instructed - no wall-jump-specific
animation was built). The detachment reads cleanly in a captured
screenshot - no lingering wall-slide pose after leaving the wall, no
blank frame.

### Is a dedicated wall-jump animation needed?

**Not for v0.1.** The existing jump animation immediately taking over
on wall-jump reads as an acceptable, clean transition in real testing -
the character visibly pushes off and arcs away, and jump's own frame 1
(the compact "just launched" pose) works reasonably as a stand-in for
a wall-jump-specific launch frame. Worth reconsidering later if a
future polish pass specifically wants the push-off direction/emphasis
to read more distinctly from a normal ground jump, but not a gap
blocking approval now.

### Rapid interaction

Touch-then-immediately-reverse-away-from-the-wall tested directly:
correctly falls through to `fall` state/animation afterward, no stuck
`wall_slide` state, no incorrect restart.

### Real-camera validation (Stage 3)

Real-GPU screenshot captured in `AvarisVerticalSlice.tscn`'s actual
Stage 3 vertical-shaft geometry (`ShaftWallLeft`/`ShaftWallRight`, the
same 40×240 wall convention as `TestArena.tscn`'s corridor) - confirmed
`is_wall_sliding = true`, `state = WALL_SLIDE`, `anim = "wall_slide"`
via real physics contact, not simulated. Zayr reads clearly as
wall-sliding at actual gameplay scale, pressed visibly between the two
shaft walls, black/white/gold costume providing good contrast against
the dark backdrop.

### Existing animation regression

`idle`/`run`/`jump`/`fall` frame counts, speeds, and loop flags all
confirmed unchanged via direct assertion. `idle→run`, `run→jump`,
`jump→fall`, `fall→idle` chain re-verified working exactly as before -
adding `wall_slide` did not disturb any of it.

### Gameplay regression

Full battery re-run: **38/38 checks passed**, including explicit
assertions that `wall_slide_speed`, `wall_jump_velocity_y`,
`wall_jump_horizontal_speed`, `gravity`, `jump_velocity`, and collision
dimensions are all unchanged - not just absence of visible symptoms.

### Frames needing correction

None - all three passed audit clean on first delivery.

## Phase 1 — DASH v0.1 Integration (Results)

**Status: DASH v0.1 implemented and validated. APPROVED for continued
production.**

### Asset audit

Same method as every prior set (alpha/bleed composite test +
connected-component analysis at the established 10px significance
threshold + direct visual inspection) applied to all 4 delivered frames
(`dash_01.png`-`dash_04.png`) before any integration work began.
**Result: all 4 clean.** 0% background bleed on every frame. Largest
stray connected component found across the set was 9px - under the
10px threshold, consistent with harmless anti-aliasing noise, not
contamination.

Special attention was paid to **`dash_03.png`** per instruction, since
it was flagged as a corrected re-delivery (later file timestamp than
the other three: 17:34 vs 17:23) after an earlier extraction had cut
off Zayr's head. Confirmed on this pass: complete, undamaged head/hair/
face present, no surrounding fragments left behind by the cleanup, no
other part of the figure disturbed by the correction. `dash_03.png` is
also a different canvas size than its siblings (930×664 vs 762×550 for
01/02/04) - a byproduct of the correction crop, handled correctly by
measuring `dash_03`'s scale/offset independently rather than assuming
canvas parity with the other three (see Scale section below).

All 4 frames show complete anatomy (head, hair, both arms/hands, both
legs/boots, full cloth/costume), the same canonical Zayr design as
every prior animation, and no baked VFX (no motion streak, no dust, no
Jinn-Fire/Veyr accent baked into the source art) - confirmed clean for
the "VFX stays out of the body art" requirement before any integration
code was written.

### SpriteFrames configuration and FPS derivation

Fifth non-idle animation added: **`dash`**, 4 frames, `loop = false`.
Per instruction, FPS was **not** assumed at 14-16fps - it was derived
from the actual gameplay dash duration, read directly from
`PlayerMovement.gd`: `dash_duration = 0.16s` (unchanged, confirmed via
regression below). Fitting 4 frames across 0.16s real-time gives
`4 / 0.16 = 25fps` as the exact fit; **`speed = 30.0`** fps was chosen
(slightly faster than the exact fit) so the animation completes at or
just before the gameplay dash ends rather than getting cut off
mid-frame by `dash_04` never being reached - the sequence finishes in
`4/30 ≈ 0.133s`, comfortably inside the real 0.16s window, then holds
on `dash_04` for the remaining ~0.027s (see hold-behavior below).
`idle`/`run`/`jump`/`fall`/`wall_slide` all confirmed unchanged via
regression.

### State integration

`_update_character_animation()` extended with one more branch:
both `State.DASH` (grounded) and `State.AIR_DASH` (airborne,
`movement.dash_is_air`) map to the single `"dash"` animation - no
separate air-dash art exists or was requested. Animation selection is
purely visual: `dash_distance`, `dash_duration`, `dash_cooldown`,
`dash` input handling, collision, invulnerability, and all
state-transition timing in `PlayerMovement.gd` were read for reference
only, never modified (confirmed byte-for-byte unchanged via regression
below).

### Dash completion / hold behavior

Because `loop = false`, `AnimatedSprite2D` holds on the last frame
(`dash_04`) once playback reaches it rather than restarting - verified
directly: the animation does not restart mid-dash, and since the
4-frame sequence at 30fps (~0.133s) finishes slightly before the real
0.16s dash ends, `dash_04` is held for the remaining ~0.027s exactly as
instructed ("hold dash_04 if gameplay outlasts 4 frames"). No gameplay
timing was adjusted to fit the animation - only the animation's own FPS
was chosen to fit gameplay, per instruction.

### Scale / anchor - measured independently, not copied

Per instruction, Dash's scale was **not** copied from Idle/Run/Jump/
Fall/Wall Slide, and raw bounding-box height was **not** trusted as the
primary signal (Dash's pose is markedly more horizontal/compact than
any prior animation, and jump/fall's own scale bug had already
demonstrated bbox-height is misleading for non-upright poses). Instead,
head size, torso width, and leg/boot thickness were compared directly
against the already-approved Run and Jump art via the same fixed-window
native-pixel head-comparison method established after the jump/fall
correction. Result: **`scale = 0.13`** (matching Run/Jump/Fall) read as
correct on the **first attempt** - confirmed both by the fixed-window
comparison before committing and by a direct side-by-side screenshot
comparison against a live Run reference afterward (`dash_compare_grid.png`),
which showed no visible size mismatch across any of the 4 dash frames.

Anchor uses the same core-anchor convention as jump/fall/wall_slide's Y
axis: `offset.x = -bbox_center_x`, `offset.y = TARGET_CORE_Y/scale -
bbox_center_y` with `TARGET_CORE_Y = -45.0`, computed independently per
frame (including `dash_03` at its different canvas size). This anchors
each frame's visual-content-bbox center at a fixed world position
regardless of pose/canvas differences between frames, so the torso does
not visibly teleport across the highly dynamic dash pose. Verified
analytically: core-Y position across all 4 frames has **0.000px
spread** by construction. The sprite is permitted to extend well behind
the 28-wide collision box (hair/cloth trail past the collision edge, as
instructed) - the collision body itself was never moved or resized.

### Direction / mirroring

Tested dash both directions using the existing `VisualRoot.scale.x`
mirror convention (no duplicate left-facing art, as instructed):
- **Facing right** (`facing = 1.0`): unmirrored, `VisualRoot.scale.x =
  1.0` - dash travels right, matching the unmirrored art's own forward
  lean.
- **Facing left** (`facing = -1.0`): mirrored, `VisualRoot.scale.x =
  -1.0` - dash travels left, pose correctly flips to lean the opposite
  direction.

Confirmed both via the regression battery's direct state assertions
and via a live screenshot (`3_dash_left.png`). Zayr visually travels in
the direction the dash pose leans/faces in both cases - no
facing/velocity mismatch.

### Transitions

Tested via both the regression battery's structural assertions and a
dedicated visual transition script capturing frame sequences across
each boundary:
- **idle → dash → idle**: clean pose swap into the dash lean, clean
  return to idle after the hold-frame period, no stuck dash frame, no
  one-frame idle flash mid-dash.
- **run → dash → run**: dash overrides run cleanly; releasing dash
  while still holding the move input resumes run immediately at
  matching scale, no pop.
- **jump → air-dash → fall**: reaches `State.AIR_DASH` correctly on
  press, `"dash"` plays, and resolves cleanly to `fall` once the dash
  animation's hold period ends and gravity resumes - no torso jump, no
  scale pop across the transition (see `jump_airdash_fall_grid.png`).
- **fall → dash → fall/landing**: same clean behavior falling into a
  dash and out of it into a continued fall, through to landing
  (`fall_dash_land_grid.png`) - no stuck pose, no scale/position pop at
  the landing frame.
- **wall-slide → dash**: reachable only when `air_dash_available` is
  still true (i.e., the air dash has not already been spent since the
  last landing) - gameplay-correct, not an animation defect; not
  separately re-tested beyond the existing air-dash transition coverage
  above, since wall-slide's own approved integration is unchanged and
  dash's transition-out behavior is identical regardless of which
  airborne state preceded it.

No scale pop, torso teleport, incorrect facing, animation restart, or
stuck frame was observed in any tested transition.

### Continuous gameplay test

Chained 5 grounded dashes back-to-back through real `TestArena.tscn`
geometry (a wide flat runway, each dash confirmed to start grounded via
direct assertion). Playback read as consistent across all 5 reps -
same pose progression, same hair/cloth trail shape, no costume flicker,
no body/head instability between reps. Dash reads as substantially
faster than Run by design (130px covered in 0.16s vs Run's continuous
240px/s), and the visual lean/streak of the pose reinforces that
impression even with no VFX yet. 4 frames were judged sufficient for
v0.1's short dash duration - the pose progression (compact launch →
full horizontal extension → sustained lean → landing-ready pose) reads
clearly at 30fps without feeling like missing frames. No additional
effects were implemented this pass, as instructed.

### VFX architecture (non-goal, confirmed as reportable finding)

No motion streak, ground dust, or Jinn-Fire accent was implemented this
pass, per instruction. Confirmed nothing was baked into
`CharacterSprite`/`AnimatedSprite2D` - the dash body art is clean,
identical in architecture to every other animation (a `SpriteFrames`
entry plus the existing transform system). `VisualRoot/AbilityVFX`
remains the designated (currently empty) node for any future dash VFX
work. Normal Dash currently reads as visually distinct from Veyr Step
by construction: Veyr Step hides `VisualRoot` entirely and drives its
own particle/burst/trail nodes (`DepartParticles`, `ArriveParticles`,
`TrailLine`, etc., all pre-existing and untouched), while Dash keeps
`VisualRoot` visible and plays the new `"dash"` body animation with no
particle systems active - the two abilities cannot be visually confused
in their current form.

### Real-camera validation (Stages 1, 3, 4, 5)

Real-GPU screenshots captured at all four requested locations in
`AvarisVerticalSlice.tscn`: Stage 1 (`(20, 400)`), Stage 3
(`(3400, 200)`), Stage 4 Avaris Reveal (`(5040, 100)`), and Stage 5
arena (`(7500, 400)`). All four correctly reached `State.AIR_DASH` /
`anim = "dash"` at capture time and Zayr reads clearly and legibly at
each location despite the highly horizontal pose - the
black/white/gold costume keeps good contrast against every tested
backdrop (dim vertical shaft, Avaris's angular geometry, and the open
arena).

One test-harness artifact was found and fixed during this validation,
same general category as the previously-documented double-processing
issue: the capture script did not reset `air_dash_available` between
the four scripted situations, so Stage 5's scripted dash press was
silently ignored (gameplay-correct behavior - air dash had already been
spent at Stage 4 and the script's post-capture landing-wait loop didn't
always land the player within its window) and the captured frame showed
a normal `fall` pose instead of `dash`. This was **not** a gameplay or
animation defect - re-running with `air_dash_available` explicitly
reset per situation produced the correct `AIR_DASH`/`"dash"` capture at
all four stages on the next attempt. Documented here as a known
test-methodology gotcha, alongside the existing double-processing note.

### Existing animation regression

`idle`/`run`/`jump`/`fall`/`wall_slide` frame counts, speeds, and loop
flags all confirmed unchanged via direct assertion. Normal locomotion
(idle/run/jump/fall/wall-slide) re-verified working exactly as before
after repeatedly entering and exiting Dash - adding `dash` did not
disturb any of it.

### Gameplay regression

Full battery re-run: **45/45 checks passed**, including explicit
byte-for-byte assertions that `dash_distance`, `dash_duration`,
`dash_cooldown`, `air_dash_enabled`, plus every previously-asserted
constant (gravity, jump velocity, wall slide speed, wall jump
velocities, collision dimensions, combat hit offsets, combo/heavy/
charged/ranged attack starts, Veyr Step + Perfect Step, hurt/death/
respawn) are all unchanged. Combat, Veyr Step, hurt, and death/respawn
all re-verified working exactly as before.

### Frames needing correction

None on this pass - all 4 frames (including the re-delivered
`dash_03`) passed audit clean.

## Phase 1 — LIGHT ATTACK 1 BODY v0.1 Integration (Results)

**Status: LIGHT ATTACK 1 BODY v0.1 implemented and validated. APPROVED
for continued production.**

A path discrepancy was found and is noted here rather than silently
worked around: the task described the corrected assets as delivered to
`assets/characters/zayr/animations/combat/light_1/`, but on disk they
remained at the original `assets/characters/zayr/animations/light_1/`.
File timestamps confirmed the correction itself did happen (`light_1_02/
04/05.png` timestamped ~39 minutes after `light_1_01/03/06.png`) - this
was purely a path mismatch, not a missing-correction problem, so
integration proceeded from the actual on-disk location rather than
guessing at a file move.

### Re-audit (all 6 frames)

Same method as every prior set (alpha/bleed composite test +
connected-component analysis at the 10px significance threshold +
direct visual inspection). **Result: all 6 clean.** 0% background bleed
on every frame. No stray connected component reached the 10px
threshold on any frame (largest was 9px, consistent with harmless
anti-aliasing noise). Canvas sizes are **not** uniform across the set -
`light_1_01/03/06` are 552×537, while the three corrected frames
(`light_1_02` 732×577, `light_1_04` 684×582, `light_1_05` 768×501) grew
to accommodate the previously-clipped hand - each frame's scale/anchor
was measured independently against its own canvas rather than assuming
canvas parity (same lesson already established by `dash_03`'s own
resize during its correction).

### 02/04/05 hand-fix verification

Zoomed crops of each corrected hand were inspected directly:
- **`light_1_02`** (extended punching fist): forearm gauntlet band
  connects continuously into a complete, correctly-formed fist: no
  duplicated fingers, no gap at the wrist.
- **`light_1_04`** (raised guard fist + reaching open hand): both hands
  checked - the raised fist's glove/forearm read cleanly, and the
  previously-incomplete reaching hand now shows a complete open palm
  (four separated fingers plus thumb, correct fingerless-glove
  rendering), wrist-to-forearm transition natural.
- **`light_1_05`** (reaching open hand): same result - complete open
  hand, natural wrist connection, no fragment or duplication.

No neighboring-pose fragments were pulled in by any of the three
corrections, and no other part of Zayr (head, torso, legs, cloth) was
disturbed by the cleanup.

### Remaining contamination / clipping

None found on any of the 6 frames.

### Design consistency

All 6 frames show the same canonical Zayr costume/palette/anatomy as
every previously-approved animation. No weapon rendered in-hand (the
body animation is unarmed by design this pass), no baked Veyr Edge, no
baked slash-trail/attack VFX of any kind.

### Gameplay timing (read from `PlayerCombat.gd`, unchanged by this pass)

Swing 1 (`combo_index = 0`) of the existing 3-hit combo:
- **Windup**: `hitbox_start_times[0] = 0.08s`
- **Active/hitbox duration**: `hitbox_end_times[0] - hitbox_start_times[0]
  = 0.18 - 0.08 = 0.10s` (hitbox open from t=0.08s to t=0.18s)
- **Recovery** (post-hitbox-close portion of the swing itself):
  `swing_durations[0] - hitbox_end_times[0] = 0.35 - 0.18 = 0.17s`
- **Total swing duration**: `swing_durations[0] = 0.35s`
- **Combo-chain window**: not a narrow end-of-swing buffer - a press at
  *any* point while `is_attacking` is true sets `_queued_next = true`,
  resolved with zero gap the instant the current swing's duration ends
  (`_advance_or_end_combo()`). Confirmed both via the regression battery
  and a dedicated, cleanly frame-bounded isolated test (see Transitions
  below) that a single press during swing 1 chains to swing 2 exactly
  once, with no further un-pressed advance to swing 3.
- **Cooldown** (only applies if the combo ends without chaining):
  `attack_cooldown = 0.1s`
- **Hitbox reach**: `hit_offset = 26.0` (Hitbox node placement) +
  `CollisionShape2D` local offset `14.0` + half-width `24.0` ≈ **64px**
  from Zayr's collision origin in his facing direction - the hitbox
  itself is `48×32` (`RectangleShape2D_hitbox`, unchanged).

None of these values were altered.

### SpriteFrames configuration

Sixth animation added: **`light_1`**, 6 frames, `loop = false`. Per
instruction, FPS was **not** assumed - it was derived from the real
0.35s swing duration. Exact fit for 6 frames is `6/0.35 ≈ 17.14fps`;
**`speed = 18.0`** was chosen (a small margin above the exact fit, the
same reasoning already used for Dash's 25→30fps) so the sequence
finishes at `6/18 ≈ 0.333s`, comfortably inside the real 0.35s swing,
then holds on `light_1_06` for the remaining ~0.017s rather than
risking the last frame being cut off. `idle`/`run`/`jump`/`fall`/
`wall_slide`/`dash` all confirmed unchanged via regression.

### Final animation FPS / timing

`speed = 18.0`, `loop = false`, confirmed via the regression battery
and via direct real-time playback capture that the animation plays
once per swing and does not restart mid-attack.

### Scale / core-anchor stability

Per instruction, scale was measured independently rather than copied
from Idle/Run/Jump/Fall/Wall Slide/Dash, and raw bounding-box height
was **not** trusted (Light Attack 1's forward-lunging pose varies
bbox shape significantly frame to frame, the same trap that caused the
original jump/fall scale bug). Head, torso, and limb proportions were
compared against approved Run art via the fixed-window native-pixel
comparison method, then confirmed with a direct bottom-aligned render
of both animations at the candidate scale side by side. **`scale =
0.13`** (matching Run/Jump/Fall/Dash) read as correct on this
comparison - head size, torso width, and leg/boot thickness all landed
within the same range as Run's already-approved art, no adjustment
needed.

Anchor reuses the jump/fall/dash bbox-center core-anchor convention
(`TARGET_CORE_Y = -45`, X centered at world 0), computed independently
per frame including the three differently-sized corrected frames.
Per instruction ("do NOT foot-lock every combat frame"), this
deliberately does not pin the feet to a fixed ground line - it keeps
each frame's visual-content center anchored at Zayr's gameplay
core/torso instead, so the torso doesn't visibly teleport as the
pose's limb/cloth extension changes drastically frame to frame.
Verified both analytically (0.000px core-Y spread by construction) and
visually (the 6-frame sequence and the real-time playback capture both
show a stable torso position with no popping).

### Six-frame phase mapping

Based on the approved pose read (01 guard/ready → 02 forward jab fully
extended → 03 twisting follow-through → 04 low reaching lunge → 05
crouched wind-down → 06 return to guard) and the real 18fps timing
computed above:

| Frame | Time span (real gameplay) | Phase |
|---|---|---|
| 1 (`light_1_01`) | 0.000-0.056s | ANTICIPATION / WINDUP |
| 2 (`light_1_02`) | 0.056-0.111s | ACTIVE STRIKE begins (hitbox opens at t=0.08s, inside this frame) |
| 3 (`light_1_03`) | 0.111-0.167s | ACTIVE STRIKE (fully inside the 0.08-0.18s hitbox window) |
| 4 (`light_1_04`) | 0.167-0.222s | ACTIVE STRIKE ends (hitbox closes at t=0.18s, inside this frame) / FOLLOW-THROUGH begins |
| 5 (`light_1_05`) | 0.222-0.278s | FOLLOW-THROUGH / RECOVERY |
| 6 (`light_1_06`) | 0.278s-swing end | RECOVERY (held) |

A manually-driven test harness measurement of this same correlation
(polling `AnimatedSprite2D.frame` alongside `PlayerCombat._attack_timer`)
initially disagreed with this table by roughly one frame's worth of
lag - traced to `AnimatedSprite2D`'s own frame advance being driven by
the engine's real per-process delta (further distorted, in one specific
run, by `Engine.time_scale` briefly dropping during hitstop from a
landed hit on `TestArena`'s training dummy), which is **not** the same
clock this script's manually-supplied combat-timer delta uses. In real
gameplay both are driven by the same physics delta every frame and
stay exactly in sync, so the table above (computed directly from the
`speed=18.0` FPS and the real hitbox timing) is what actually happens
during play - this discrepancy is a documented test-harness measurement
artifact, not a gameplay or animation timing bug. Recorded here
alongside this project's other known manual-stepping quirks (see
Transitions below for a second, related discovery this pass).

### Frames overlapping the ACTIVE gameplay window

Per the table above: **frame 2 (from t=0.08s) and frame 3 (fully)**,
with frame 4 catching the closing instant (t=0.18s). This was also
checked visually - frame 2's fully-extended punching fist sits directly
adjacent to/overlapping the debug hitbox polygon in a real-time capture
of the live swing (frame index 1, i.e. the 2nd frame, at the moment the
hitbox opens), which is a good sign the body art's own point of visual
impact already roughly agrees with the real hitbox window without any
adjustment.

### Right-facing result

Confirmed via regression and screenshot: unmirrored (`VisualRoot.scale.x
= 1.0`), swing plays and travels/strikes in Zayr's forward (right)
direction, matching the art's default orientation.

### Left-facing result

Confirmed via regression and screenshot: mirrored (`VisualRoot.scale.x
= -1.0`) using the existing `VisualRoot` mirror convention - no separate
left-facing art was created, per instruction.

### Hitbox / art alignment

The existing debug `SwingVisual` polygon (already present, unrelated to
this pass) was used to visualize the real hitbox live during playback.
The striking fist's extension direction visibly agrees with the
hitbox's forward placement at the frames identified above as the active
window - the art does **not** suggest a substantially different reach
than the real ~64px hitbox. No hitbox dimensions or offsets were
touched.

### Transition results

Tested via the regression battery's structural assertions plus a
dedicated visual transition capture:
- **idle → light_1 → idle**: clean pose swap into the guard/strike
  sequence and clean return to idle once the swing (plus its held last
  frame) ends, no stuck frame, no scale/position pop. (One instance of
  this exact transition inside the combined visual-capture script
  failed to trigger - traced to leftover state from an unrelated
  earlier section in that same long throwaway script, not a real
  animation/gameplay issue; a fresh, isolated re-run of just this
  transition confirmed it works correctly.)
- **run → light_1 → run/idle**: clean interrupt of the run cycle and
  clean resume afterward, matching scale, no pop.
- **light_1 → movement**: after the swing (and its cooldown) ends,
  normal idle/run resumes correctly.
- **jump/fall interaction**: attacking while airborne does **not**
  play `light_1` - it correctly routes to the pre-existing, separate
  Aerial Attack instead (confirmed via `State.ATTACK_AERIAL`, distinct
  green `SwingVisual` color, and `anim != "light_1"`), exactly matching
  existing gameplay restrictions. This is expected, pre-existing
  behavior, not something this pass changed.
- **light_1 → light_2 combo-chain path**: verified using the *existing*
  behavior, with no light_2 art created. A single queued press during
  swing 1 correctly chains to swing 2 exactly once (`combo_index`
  0→1, `State.ATTACK_2`, `is_attacking` stays true with no gap) - the
  character's visual falls back to the idle pose during swing 2 purely
  because no `light_2` SpriteFrames animation exists yet (state itself
  never passes through `IDLE` in between; this is an art gap, not a
  state-machine flash). **A second, previously-undocumented
  manual-test-harness gotcha was found and fixed while verifying this**:
  `Input.is_action_just_pressed()` does not clear on its own between
  manually-driven `_physics_process()` calls unless a real engine frame
  (`await process_frame`) elapses in between - polling it repeatedly
  after a single `action_press()`/`action_release()` pair with no
  intervening awaited frame can read the same logical press as "just
  pressed" many times over. This caused one throwaway script's combo
  test to show an unintended, spurious chain all the way to swing 3.
  A clean, properly frame-bounded isolated test (press → `await
  process_frame` → step with no further presses) confirmed the real
  chain logic is correct: swing 1 → swing 2 only, no runaway
  advancement. Documented alongside this project's other known
  manual-stepping test quirks (double-processing, hitstop/time_scale
  affecting `AnimatedSprite2D` timing above).

### Real-camera observations (Stages 1, 3, 4, 5)

Captured in `AvarisVerticalSlice.tscn` at all four requested locations,
adjusted to genuinely grounded positions for Stage 3 (`(3335, 250)`,
centered on the level's own `CombatFloor` node - the originally-listed
`(3400, 200)` never reliably reached a floor within a generous 5-second
fall window, and Light Attack 1 is grounded-only unlike Dash's airborne
validation) and given a generous landing-settle budget at every stage
so the swing is genuinely grounded before capture. Zayr reads clearly
at all four locations, hitbox polygon visible and well-aligned with the
striking arm, good silhouette contrast against the combat floor, the
Avaris tower backdrop, and the arena's spike geometry alike.

One test-harness-only issue was found and fixed during this
validation: the player's own `CameraController`'s `position_smoothing`
only advances via real per-process ticks, which this manually-stepped
harness barely provides - large instant position teleports between
stage test positions left the camera visually lagging far behind the
player (rendering an empty background with no character in three of
the four stage screenshots on the first attempt). Disabling
`position_smoothing_enabled` for this specific diagnostic capture
resolved it; real gameplay never teleports the player like this, so
this was never an actual smoothing problem in play.

### Existing animation regression

`idle`/`run`/`jump`/`fall`/`wall_slide`/`dash` frame counts, speeds, and
loop flags all confirmed unchanged via direct assertion. Normal
locomotion, dash, and wall-slide all re-verified working exactly as
before after repeatedly entering and exiting Light Attack 1.

### Gameplay regression

Full battery re-run: **47/47 checks passed**, including explicit
assertions that `swing_durations[0]`, `hitbox_start_times[0]`,
`hitbox_end_times[0]`, every attack hit-offset, `attack_cooldown`, and
every previously-tracked gameplay constant (gravity, jump velocity,
wall slide speed, dash constants, collision dimensions) are unchanged,
alongside the full combat/Veyr Step/Perfect Step/hurt/death/respawn
suite. (Two of the three initial "failures" on the first run were a
`PackedFloat32Array` float32-vs-double comparison artifact, fixed by
switching those three checks to `is_equal_approx()`; the regression
script itself also needed `player.set_physics_process(false)` added,
per this project's established double-processing-artifact precedent,
once a real instance of it was found in the combo-chain check.)

### Veyr Edge manifestation requirements (plan only - not implemented)

Derived from the approved body animation and the real hitbox geometry
above, for a future pass:
- **Origin / controlling hand**: Zayr's right hand/forearm - the same
  limb performing the forward jab in frames 2-4, already the combo's
  active striking limb.
- **Approximate visual length**: roughly matching the ~64px total
  hitbox reach from Zayr's collision origin - the edge should extend
  from the fist to approximately the hitbox's outer boundary, not
  dramatically past it (so the visual doesn't promise more reach than
  the real hitbox delivers).
- **Orientation during the strike**: aligned with the punching arm's
  own extension angle each frame (slightly upward-forward in frame 2,
  more horizontal in frames 3-4), tracking the arm rather than staying
  fixed.
- **Manifestation frame**: frame 2 (`light_1_02`) - at/just before the
  hitbox opens (t=0.08s), so the edge doesn't visibly lag behind an
  already-live hit.
- **Disappearance frame**: end of frame 4 (`light_1_04`) - matching the
  hitbox's close at t=0.18s, so the edge doesn't linger visibly through
  the follow-through/recovery frames (5-6) once the strike is over.
- **Frames needing slash-trail VFX**: frames 2-4, the manifestation
  window above - the arm's actual striking arc.

No weapon asset was created and no `WeaponManifestation` code was
written this pass, per instruction.

### Frames requiring correction

None on this pass - all 6 frames (including the three re-delivered
hand corrections) passed the re-audit clean.

## Phase 1 — VEYR EDGE v0.1 / Light Attack 1 Manifestation (Results)

**Status: VEYR EDGE v0.1 implemented and validated. APPROVED for
continued production.**

### Asset audit

`assets/characters/zayr/weapons/veyr_edge.png` (1525×1024) was audited
with the same methodology as every character animation frame, adapted
for a glow-heavy VFX asset. **Result: clean.** The alpha channel shows
a genuine soft radial falloff (histogram: ~86% of pixels below alpha
25, ~9% above alpha 230, a smooth gradient in between) rather than a
hard-edged cutout - confirmed visually by compositing the asset over
both solid red and solid green backgrounds side by side: the glow
blends identically in shape/intensity against both, with no leftover
halo or fringe, ruling out a baked-in background. (The default preview
renders this asset against black rather than the white seen for every
character sprite - purely a viewer choice based on image content, not
evidence of anything baked in; the composite test is what actually
verifies transparency.) Connected-component analysis found 3 components
with 0 stray fragments over the 10px threshold. Complete blade tip
(top-right, brightest point) and complete ornate hilt/base (bottom-left,
gold ring around a dark core) present - no cut-off geometry. No Zayr
body/hand baked into the art, no slash-trail effect baked in - a clean,
standalone weapon asset.

### WeaponManifestation hierarchy

Added as `VisualRoot/WeaponManifestation/VeyrEdge`, a plain `Sprite2D`
(the minimum node needed - no custom shader, no particle system, per
instruction), `visible = false` by default, `centered = false` with
`offset = Vector2(-304, -832)` so the texture's own hilt/grip point
(found via gold-pixel-color segmentation) sits at the node's local
origin - positioning the node then places the grip, not some arbitrary
texture corner. Never baked into `CharacterSprite`; `WeaponManifestation`
was already the designated (previously empty) layer for exactly this.
Because it's a plain child of `VisualRoot`, it inherits the same
`scale.x` mirror the body already uses - no separate mirroring logic
needed anywhere.

### Visibility: gameplay-timing-driven, not frame-driven

Per instruction ("gameplay timing remains authoritative"), visibility
is computed each frame as `state == State.ATTACK_1 and
combat.hitbox.monitoring` - the same boolean the real hit-detection
uses - rather than from `light_1`'s decorative frame index. This
matters in practice: `AnimatedSprite2D`'s own frame advance is driven
by the engine's real per-process delta, which is not the same clock as
`PlayerCombat`'s manually-fed-in-tests `_attack_timer`, so at real
gameplay framerates the currently-showing body frame can occasionally
sit just outside the transform table's frames 2-4 while the hitbox is
still genuinely open. `_update_weapon_manifestation()` clamps the
transform lookup to the nearest defined frame (1..3, 0-indexed) rather
than hiding whenever this happens, so the weapon stays visible for the
entire true active window instead of flickering - discovered and fixed
after an initial version (correctly hiding on an undefined frame
index) visibly dropped the weapon for most of a real-time test
playback capture, even though the underlying hitbox window was
unaffected the whole time.

### Final weapon scale

**`Vector2(0.028, 0.028)`**, applied uniformly across all three active
frames rather than varying per frame - chosen because a real weapon
doesn't change size mid-swing; only the arm's position/angle should
change how it reads frame to frame. At this scale the blade's native
1378.8px tip-to-hilt length renders at ~38.6 world units - short
relative to Zayr's own ~60-70px height, deliberately: since the
punching fist is already extended close to the real hitbox's own reach
by the time it would wield the edge, a short glowing accent extending
from the fist reads as manifested energy rather than needing to be a
full separate sword.

### Effective visible reach

Measured directly from real-time playback screenshots (hitbox debug
polygon vs. the weapon's own glow, both converted from screen pixels to
world units via the known 3.0x camera zoom): at the earlier active
frame the tip landed ~3px short of the hitbox's 64px outer edge; at the
later active frame it landed ~16px past it. See "Hitbox-tip mismatch in
pixels" below for the full breakdown - reach is not perfectly constant
across the swing (expected, since the arm's own angle changes the
blade's effective horizontal projection), but stays in the same general
neighborhood as the real 64px hitbox reach throughout.

### Right-hand attachment result

The blade's grip anchors to the punching fist's own per-frame world
position (found via the same bbox/offset math as `light_1`'s own
core-anchor table), computed from the *right* hand/forearm specifically
- the limb performing the combo's forward jab in frames 2-4. Confirmed
visually: the blade convincingly emerges from the fist in every active
frame rather than floating disconnected beside it.

### Frame 2 transform

`position = Vector2(46.0, -63.3)`, `rotation = 24.28°` (node rotation;
combined with the source art's own native ~-34.28° diagonal, this
renders the blade pointing at approximately -10° from horizontal - a
nearly-horizontal punch-aligned angle, matching this frame's fully
extended jab).

### Frame 3 transform

`position = Vector2(27.4, -29.8)`, `rotation = -0.72°` (renders at
approximately -35° from horizontal, angled more steeply up-and-back,
matching this frame's twisting/retracting pose).

### Frame 4 transform

`position = Vector2(41.3, -30.9)`, `rotation = 49.28°` (renders at
approximately +15° from horizontal, angled down-and-forward, matching
this frame's low reaching-lunge pose).

### Manifest timing

Frame-number-independent by construction (see Visibility above) - the
weapon becomes visible the instant `combat.hitbox.monitoring` goes
true, which is exactly `t = 0.08s` (the real windup-to-active
transition), not an approximation of it.

### Disappear timing

Same mechanism in reverse - visible for as long as
`combat.hitbox.monitoring` stays true, hidden the instant it goes
false at `t = 0.18s`. Confirmed no visible lag or lingering frame in
either direction across multiple real-time captures.

### Right-facing result

Confirmed via regression and screenshot: unmirrored
(`VisualRoot.scale.x = 1.0`), blade points and travels with the
forward punch.

### Left-facing result

Confirmed via regression and screenshot: mirrored
(`VisualRoot.scale.x = -1.0`) using the existing convention - no
separate left-facing texture created, per instruction. The blade
correctly stays attached to the (now-left-facing) fist and points in
the mirrored punch direction.

### Hitbox-tip mismatch in pixels

Measured directly from real-time playback screenshots by locating the
debug hitbox polygon's screen-space center and the weapon glow's
screen-space tip, then converting the relative offset to world units
via the camera's known 3.0x zoom:
- **Earlier active frame** (transform table index 1): tip landed
  ~20.8 world-px right and ~28.8 world-px above the hitbox's center -
  i.e. **~3px short of the hitbox's 64px outer edge** in reach, but
  sitting **~13px above** the hitbox's own vertical span.
- **Later active frame** (transform table index 3): tip landed
  ~39.8 world-px right and ~1.8 world-px above the hitbox's center -
  i.e. **~16px past** the 64px outer edge, and **within 2px** of the
  hitbox's vertical center - the closest match of the two measured
  points.

No hitbox dimensions or gameplay timing were changed to chase a tighter
fit, per instruction - these are reported as measured, not corrected
further.

### Interruption behavior

All three tested paths hide the weapon immediately, verified via a
dedicated regression pass:
- **HURT**: a real hit through `Hurtbox.receive_hit()` (not
  `HealthComponent.take_damage()` directly, which bypasses the
  interrupt path entirely and was caught as a test-methodology mistake
  before being corrected) correctly triggers
  `PlayerController._enter_hurt()` → `combat.cancel_attack()` →
  `hitbox.deactivate()`, and the weapon hides on the very next frame.
- **Veyr Step**: already calls `combat.cancel_attack()` on entry (no
  code changed here) - weapon hides immediately, and stays hidden after
  the step ends since the attack was fully cancelled, not just paused.
- **Death**: `_on_died()` clears `combat.is_attacking` and sets
  `state = State.DEAD`; since the weapon's visibility check requires
  `state == State.ATTACK_1`, it hides immediately regardless. (One
  pre-existing, unrelated detail noted along the way: `_on_died()`
  doesn't itself call `hitbox.deactivate()`, so
  `combat.hitbox.monitoring` can be observed still `true` immediately
  after death - harmless here since the weapon's own visibility check
  has state as a second, independent gate, but flagged since it wasn't
  obvious before this pass. Not changed, per instruction not to modify
  cancellation rules.)

No stuck weapon and no one-frame weapon flash during idle were observed
in any tested transition.

### Transition behavior

`idle → light_1`, `run → light_1`, `light_1 → idle/run`, and the
`light_1 → light_2` combo chain were all re-verified with the weapon
in place: the weapon shows only during swing 1's own genuine active
window and stays correctly hidden through swing 2 (which has no
`light_2` art and its own different hitbox timing), never leaks into
idle, run, or the post-combo settle.

### Real-camera observations

Captured at Stages 1, 3, 4, and 5 in `AvarisVerticalSlice.tscn`
(reusing the grounded Stage 3 position established during the
LIGHT ATTACK 1 pass). At Zayr's actual gameplay scale, the weapon reads
clearly as a compact glowing energy accent at every location - good
contrast against the dim shaft, the combat floor, the Avaris tower
silhouettes, and the arena's spike geometry alike. It does **not**
overwhelm Zayr's own silhouette (if anything it reads as modestly
sized relative to the character, consistent with the deliberately
short-reach scale choice above) and reads convincingly as manifested
energy rather than a normal held sword, satisfying the pass's own
evaluation criteria.

### Existing animation regression

`idle`/`run`/`jump`/`fall`/`wall_slide`/`dash`/`light_1` frame counts,
speeds, and loop flags all confirmed unchanged via direct assertion.

### Gameplay regression

Full battery re-run: **39/39 checks passed**, including explicit
assertions that `swing_durations[0]`, `hitbox_start_times[0]`,
`hitbox_end_times[0]`, every attack hit-offset, `attack_cooldown`, dash
constants, jump/gravity, wall-slide speed, and collision dimensions are
all unchanged. One test-only issue was found and fixed while building
this battery: chaining a HURT-interrupt test immediately into a
Veyr-Step-interrupt test, both entirely inside a purely-synchronous
manual `_physics_process()` loop with no intervening `await
process_frame`, let a `call_deferred()`-scheduled invulnerability grant
from the HURT event sit unflushed until well after its matching
timer-based removal had already (harmlessly, since nothing had been
granted yet) fired - the deferred call then landed *later*, during the
Veyr Step section, leaving one extra invulnerability source
permanently stuck and blocking a subsequent lethal-damage check
entirely. Root-caused by tracing the exact `_invulnerability_sources`
count line by line; fixed by adding a single `await process_frame`
immediately after triggering the HURT interrupt, matching how a real
frame's deferred-call flush actually happens in real gameplay. Not a
gameplay bug - `HealthComponent`/`PlayerController` were not modified -
and documented alongside this project's other manual-test-harness
quirks (`AnimatedSprite2D` real-clock timing, stale
`is_action_just_pressed()`, camera `position_smoothing` lag).

### Frames requiring correction

None - `veyr_edge.png` passed audit clean on first delivery.

## PixelLab Full-Body Re-Integration (Results)

**Status: implemented and validated. APPROVED for continued
production.** This pass replaced every prior hand-painted illustration
animation (idle/run/jump/fall/wall_slide/dash/light_1, all superseded)
with the finalized PixelLab pixel-art set, and added ten animations
that didn't exist before: combat_idle, light_2, light_3, heavy, aerial,
ranged, charged_start, charged_hold, charged_release, hurt, death - 18
animations total, 122 frames.

### Asset audit

Every animation's `east/` frame set was audited with the established
method (alpha/bleed composite test, connected-component analysis,
direct visual inspection), batch-run across all 122 frames at once
given the much smaller, uniform canvas sizes (idle/combat_idle: 64×64;
everything else: 88×88 - a real structural difference from the old
set's wildly varying multi-hundred/thousand-pixel canvases). **Result:
all 122 frames clean.** 0% background bleed on every single frame.
Only one frame (`light_1`'s frame 6) showed more than one connected
component (3), and even there the extras were under the 10px
significance threshold - anti-aliasing noise, not contamination.
Filenames (`frame_000.png`...`frame_00N.png`) gave an unambiguous
chronological order; no frames were discarded. The obsolete
`Running_Jump` folder was left in place, untouched, per instruction -
not deleted, since the custom `jump` animation is authoritative and
nothing references `Running_Jump`.

One audit finding worth flagging explicitly:
- **`light_2`, `light_3`, and `aerial` have a weapon/energy effect baked
  directly into their later body frames** (`light_2` frames 4-5: a
  blue/white energy blade; `light_3` frames 6-8: a curved blue slash
  arc; `aerial` frames 5-6: a visible blade in hand) - contradicting the
  stated expectation that "PixelLab body sprites intentionally contain
  NO weapon." `light_1`, heavy, ranged, charged_release, hurt, and death
  have no such baked effect - confirmed clean. Per instruction
  ("integrate it first... document the exact problem"), this art was
  integrated exactly as delivered; nothing was masked, cropped, or
  edited out. See "Art issues found" in the final report below.

### Sprite integration

Continued the existing `AnimatedSprite2D`/`SpriteFrames` architecture
unchanged - no Skeleton2D, no new node type. The one structural change:
the `SpriteFrames` resource, previously built as an inline
`sub_resource` inside `Player.tscn`, is now a standalone resource at
`assets/characters/zayr/ZayrSpriteFrames.tres`, referenced by a single
`ext_resource`. This isn't an architecture change (still the same
node/resource types) - it's a scale accommodation: 122 frames across 18
animations would have meant ~122 individual `ext_resource` lines plus a
very large inline block directly in the scene file. Splitting it out
keeps `Player.tscn` readable and avoids one giant scene file mixing
node-tree structure with 122 texture references.

**Facing**: every animation's `ANIM_FRAME_SCALE` entry uses positive
`Vector2(1.0, 1.0)` - no correction needed. The delivered "east" art
faces screen-*right* natively, matching the folder name, composing
correctly as-is with `VisualRoot`'s existing `mirror = movement.facing`
logic (untouched): facing right (`mirror=1`) shows the raw art
directly; facing left (`mirror=-1`) flips it.

A negative `Vector2(-1.0, 1.0)` correction was applied here for part of
this pass, based on an audit-time misreading of `dash`'s and `ranged`'s
contact sheets - the character's cloth/hair streaming toward one edge
of the frame (a normal consequence of trailing *behind* a forward-
leaning pose) was mistaken for the character leaning/facing that way.
That inverted correctly-facing art, and was caught only once a user
testing in-editor reported Zayr visibly facing away from his actual
travel direction. Root-caused by rendering the raw source PNG directly
(bypassing the engine/code entirely) and comparing it side by side with
real in-game screenshots of Zayr actually running left and right (a
zoomed crop on the face/head specifically, not just checking that
`movement.facing`/`VisualRoot.scale.x` agreed with each other
internally - they did, consistently, the whole time; the bug was in
which way the *art itself* pointed, not in the mirror logic reading it,
so a purely code/data-level check couldn't have caught it). Reverted;
confirmed correct in both directions afterward via the same zoomed
real-screenshot method plus a live regression asserting
`movement.facing`, `velocity.x`, and `VisualRoot.scale.x` agree on
direction for real `move_left`/`move_right` key events specifically
(not just direct property assignment, which this bug had already
passed).

**Scale**: `1.0` (i.e., native pixel-for-pixel, no up/downscaling) for
every animation - this is real pixel art at a small native resolution,
unlike the old set's large hand-painted illustrations that needed
heavy downscaling. Confirmed via a real-camera screenshot with the
28×46 collision box overlaid: the character's silhouette reads at a
well-proportioned size relative to the hitbox, feet properly grounded,
head extending a natural amount above the box.

**Anchoring**: per-frame offsets for every animation (not a single
fixed offset for any of them, even idle/run) since even idle's own
bbox shifts a pixel or two frame to frame at this native resolution -
free to do per-frame given the same `_apply_frame_transform()`
mechanism already existed. Two conventions, the same split used for the
old art: **foot-anchor** (`offset.y = -bbox_bottom`, pose's lowest
pixel always at world Y=0) for every grounded animation (idle,
combat_idle, run, all six attacks, hurt, death), and **core-anchor**
(`offset.y = TARGET_CORE_Y - bbox_center_y`) for the airborne ones
(jump, fall, wall_slide, dash, aerial) where there's no ground
reference and foot-anchoring would make the torso visibly teleport as
each pose's bbox height changes. `offset.x = -bbox_center_x` for every
animation, foot- or core-anchored alike.

`TARGET_CORE_Y` needed its own value for this art - reusing the old
set's `-45` directly (initially tried, since it was already sitting in
the codebase) rendered every airborne animation floating well above the
collision box, caught immediately via a real-camera screenshot with the
collision box overlaid and corrected before commit. The right value,
**`-30`**, was derived from where idle/run's own foot-anchored poses
naturally center (averaging -29.75 and -30.56 across their frames
respectively) - i.e., calibrated from this art's own proportions rather
than carried over from the old set's.

New PixelLab `wall_slide` has no baked-in wall surface in the art
itself (unlike the old hand-painted set, which required solving for a
specific wall-edge pixel column) - core-anchor alone is sufficient,
with the real wall contact coming entirely from `PlayerMovement.gd`'s
existing wall-detection physics, unchanged.

### Animation behavior / FPS derivation

Every animation uses the complete exported frame sequence - no frames
discarded. Loop flags exactly match the instructed list (idle,
combat_idle, run, fall, wall_slide, charged_hold loop; everything else
does not).

FPS was derived from real gameplay timing wherever gameplay timing
exists, read directly from `PlayerCombat.gd`/`PlayerMovement.gd`/
`PlayerRangedAttack.gd` (never guessed, never assumed from frame
count):

| Animation | Frames | Gameplay timing source | Result |
|---|---|---|---|
| jump | 7 | ascent time `\|jump_velocity\|/gravity` ≈ 0.357s | 20fps, finishes at 0.35s |
| dash | 5 | `dash_duration = 0.16s` | 32fps, finishes at 0.156s |
| light_1 | 7 | `swing_durations[0] = 0.35s` (windup 0.08s / active+recovery 0.27s) | see phase-split below |
| light_2 | 7 | `swing_durations[1] = 0.32s` (windup 0.07s / active+recovery 0.25s) | see phase-split below |
| light_3 | 9 | `swing_durations[2] = 0.42s` (windup 0.10s / active+recovery 0.32s) | see phase-split below |
| heavy | 9 | `heavy_startup+active+recovery = 0.5+0.2+0.35 = 1.05s` | see phase-split below |
| aerial | 7 | `aerial_windup+active+recovery = 0.06+0.12+0.15 = 0.33s` | see phase-split below |
| ranged | 7 | `windup = 0.15s` (no separate active phase - the projectile is a separate object) | 48fps, finishes at 0.146s |
| charged_release | 9 | `charged_active_duration+recovery = 0.15+0.3 = 0.45s` | see phase-split below |
| hurt | 5 | `hurt_duration = 0.35s` | 15fps, finishes at 0.333s |
| idle / combat_idle / run / fall / wall_slide / charged_start / charged_hold / death | - | no gameplay-timing constraint (purely visual pacing) | 6/8/12/9/8/20/8/11fps respectively |

**Phase-split timing** (light_1/2/3, heavy, aerial, charged_release):
a uniform fps across all of an attack's frames was tried first and
rejected - it visually misaligned the art's own windup/strike content
with the real gameplay windup/active split (e.g., light_1's uniform-fps
first attempt put the real t=0.08-0.18s active window on animation
frames 1-3, which are still a neutral ready stance in the art; the
actual punch-extension only appears in the art's own frames 4-6).
Instead, each frame was bucketed into "windup-looking" vs
"extended/impact-looking" by where its content bbox width visibly
jumps (a proxy for "the swing has started moving" - cross-checked
against each animation's own contact sheet), and each bucket was given
its own per-frame `duration` multiplier so bucket 1 fits exactly inside
the real windup and bucket 2 fits exactly inside the real active+
recovery span:

| Animation | Windup frames | Active+recovery frames | Fit |
|---|---|---|---|
| light_1 | 0-3 (4) | 4-6 (3) | 0.08s / 0.27s, exact |
| light_2 | 0-3 (4) | 4-6 (3) | 0.07s / 0.25s, exact |
| light_3 | 0-4 (5) | 5-8 (4) | 0.10s / 0.32s, exact |
| heavy | 0-4 (5) | 5-8 (4) | 0.50s / 0.55s, exact |
| aerial | 0-2 (3) | 3-6 (4) | 0.06s / 0.27s, exact |
| charged_release | 0-3 (4) | 4-8 (5) | 0.15s / 0.30s (charged_release has no windup of its own - the hitbox opens instantly, charging itself was the windup) |

A real consequence of this: `light_1`'s real active hitbox window
(t=0.08-0.18s) now lands on animation frames 4-5 (0-indexed), not
1-3 like the old art - this directly fed into the Veyr Edge
recalibration below.

**Charged sequence**: uses the existing charge state machine
unmodified. `charged_start` plays once on entering `State.CHARGING`;
the handoff to the looping `charged_hold` is detected by
`charged_start` finishing its own non-loop playback
(`AnimatedSprite2D.is_playing()` going false) rather than a new
hardcoded timer, so retuning `charged_start`'s own speed later never
needs a matching code change. `charged_release` plays once on
`State.ATTACK_CHARGED`. No new charge mechanic - `PlayerCombat.gd` was
not touched.

**combat_idle**: imported and available (`ZayrSpriteFrames.tres` has
the animation, all 8 frames, looping) but never selected by
`_update_character_animation()` - per instruction, this project's state
machine has no combat-idle concept, so no new state logic was added
just to use it.

### Gameplay timing is authoritative - confirmed unchanged

No combat timing, hitbox timing/size/position, movement speed,
acceleration, gravity, jump velocity, wall-slide physics, dash
behavior, knockback, state-transition logic, Veyr costs/regeneration,
damage values, combo logic, or input handling was changed. Every value
above was *read*, never edited - see the regression section for the
explicit byte-for-byte assertions.

### Veyr Edge recalibration

The existing Veyr Edge system (from the prior pass) was recalibrated
for the new body art's hand position and light_1's re-split timing -
the manifestation logic/architecture itself was not rebuilt.
`VEYR_EDGE_TRANSFORM`'s frame-index keys moved from `1..3` to `3..6`
(clamped) to match where light_1's real active window now actually
falls (frames 4-5, with 3 and 6 as safety margin against
`AnimatedSprite2D`'s real-clock drift - see the existing comment in
code). Position/rotation were recomputed from the new art's own
attacking-fist location per frame (the fist's *rightmost* extent per
frame, matching the art's real - not the initially-misread - native
right-facing orientation; see the facing note above) and a new
`VEYR_EDGE_SCALE = 0.03` (previously 0.028 - close, since the
underlying hitbox reach is unchanged). Visibility still gates purely on
`combat.hitbox.monitoring`, not frame number - untouched.
Position/rotation/scale only - the hitbox itself was never touched.
No Veyr Edge (or any other VFX) was added for light_2/3/heavy/aerial/
ranged/charged - per instruction, this pass didn't invent new VFX
architecture beyond recalibrating what already existed for light_1.

### Ranged projectile

`PlayerRangedAttack.gd`'s projectile spawn/gameplay logic was not
touched. `muzzle_offset` (visual-only spawn point) was not recalibrated
this pass - the new `ranged` body animation's casting-hand position is
close enough to the old offset's assumption that no visible mismatch
was found in testing; worth revisiting if a future close-up pass shows
otherwise.

### Pixel art rendering quality

`texture_filter = 1` (Nearest) was set directly on the
`AnimatedSprite2D` node in `Player.tscn` - a local, per-node override,
not a project-wide rendering setting change, per instruction to prefer
a local fix. Import settings for the new PNGs use `compress/mode = 0`
(Lossless, Godot's own default, matching project convention) and
`mipmaps/generate = false` (left at Godot's default - appropriate for
pixel art rendered at or near native resolution, unlike the old
illustration set which deliberately enabled mipmaps for its own
different scale-down needs).

### Testing

A full regression battery (121 checks) confirmed: every gameplay
constant listed above byte-for-byte unchanged; all 18 animations
present with correct frame count and loop flag; facing right/left both
mirror correctly; idle/run/jump/fall/dash/wall_slide/light_1 all
verified via real-camera screenshot at a well-proportioned scale
against the collision box; the light_1→light_2→light_3 combo chain
plays the correct animation at each step and Veyr Edge is visible only
during light_1's real active window; heavy, aerial (airborne attack
correctly bypasses the grounded combo), ranged, and the full
charged_start→charged_hold→charged_release sequence all play their
correct animation; HURT (via a real `Hurtbox.receive_hit()`, not
`HealthComponent.take_damage()` directly) correctly cancels any
in-progress attack, hides Veyr Edge, applies knockback, and plays the
hurt animation; Veyr Step interruption hides `VisualRoot` and cancels
attacks exactly as before; death plays the death animation, hides Veyr
Edge, and respawns cleanly to idle at the spawn position. The death
collapse sequence was independently force-rendered frame-by-frame with
the collision box overlaid to directly confirm the "does the death pose
float above/below ground" concern from the task instructions - it
doesn't; the foot-anchor formula keeps the collapsing body's lowest
point grounded throughout, including the final prone frame.

Four manually-driven-script timing artifacts were found and worked
around during testing, none of them gameplay bugs (`PlayerController.gd`
and every gameplay script were not touched to work around any of
them) - three are the same categories already documented earlier in
this file (`AnimatedSprite2D` real-clock frame advance vs. this test
harness's manually-supplied physics delta; stale
`Input.is_action_just_pressed()` across un-frame-bounded manual steps;
`Engine.time_scale` left distorted by a hitstop deferred-call race).
The fourth is new to this pass: a `SceneTree.current_scene` that's
never set by a raw throwaway test script (only real gameplay's normal
scene-loading flow sets it automatically) caused
`PlayerRangedAttack._fire()`'s `get_tree().current_scene.add_child(...)`
to throw a null-reference error the first time a ranged shot was
actually fired all the way through in one of these scripts - fixed by
explicitly setting `current_scene` in the test script itself, not in
`PlayerRangedAttack.gd` (whose assumption is entirely correct for how
the game actually runs).
