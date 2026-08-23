# Zayr — Game Design Document

Status: living document. Source of truth for high-level design decisions.
Do not silently overwrite established canon here — flag conflicts instead.

## 1. Overview

- **Working title:** Zayr
- **Genre:** 2D Metroidvania / Action Adventure
- **Engine:** Godot 4.x (GDScript)
- **Target playtime:** 4–5 hours normal playthrough, 6–7 hours for completionists
- **Target platform:** PC first, Steam eventual target
- **Budget:** $0 during development — no paid middleware, plugins, SDKs, backend
  services, multiplayer infrastructure, or analytics platforms
- **Team:** Solo developer using AI assistance

## 2. Core Creative Vision

Zayr is an ancient Jinn who awakens long after the fall of his civilization. The
Jinn civilization existed before humanity, was vastly more advanced, and does
**not** resemble stereotypical Middle Eastern fantasy (no Arabian architecture,
desert kingdoms, sand-covered temples, medieval castles, conventional fantasy
villages, or European medieval architecture).

Jinn architecture and technology should feel:
- enormous, geometric, technologically advanced
- vertically integrated, impossible-looking, elegant
- alien but beautiful
- built around manipulation of Veyr, blurring science/engineering/supernatural ability

## 3. Core Gameplay Loop

```
Explore → Fight → Discover → Remember → Gain ability →
Reach previously inaccessible areas → Encounter someone from Zayr's past →
Boss → Major memory → Continue
```

Priorities: movement, combat, exploration, environmental storytelling,
memories, boss encounters.

**Explicitly excluded:** multiplayer, crafting, weapon inventory, randomized
loot, gear score, procedural generation, complicated RPG systems, online
backend, account systems.

## 4. Player Character — Zayr

### Movement (eventual full set)
- Running, jumping, falling
- Wall sliding, wall jumping
- Dash, air dash
- Later: Aether-based aerial movement

### Combat (eventual full set)
- Veyr Edge attacks, 3-hit combo, heavy attack, charged attack
- Aerial attacks
- Veyr ranged attack
- Veyr Step, Perfect Step

### Later major abilities (unlock progression)
1. Veyr Step
2. Ember Form
3. Aether Flight
4. Veil

Abilities are introduced incrementally, not all at once. Order and gating are
determined by world design as it is built.

## 5. Resource System

- **Health**
- **Veyr** — not conventional mana. Regenerates primarily through active
  combat (successful attacks, skilled defensive actions, environmental Veyr
  sources). Exact balance TBD.

## 6. Combat Philosophy

Fast, responsive, readable, deliberate, rewarding. Not Soulslike punishment —
players should feel powerful while still being rewarded for learning enemy
patterns. See [COMBAT.md](COMBAT.md) for implementation detail.

## 7. World Structure

One interconnected civilization, not disjointed fantasy biomes:

1. Avaris — Fallen Capital
2. Ember Depths
3. Sky Citadel
4. Drowned City
5. Celestial Threshold
6. Final Memory / Ending

See [LORE.md](LORE.md) for narrative and world canon.

## 8. Major Characters

Protagonist: **Zayr**
Major characters/bosses (canon names, do not rename): **Rhaek, Seyra, Vael,
Nayra, Auren**. Characterization and boss mechanics are specified later —
not yet defined.

## 9. Current Scope

See [PROGRESS.md](PROGRESS.md) for what is actually implemented right now.
This GDD describes the eventual full-game vision; implementation proceeds
incrementally through validated milestones.
