# Zayr — Art Bible v0.1

**Status: living document, version 0.1. Visual source of truth for the
funding-quality vertical slice**, alongside [GDD.md](GDD.md) (design)
and [LORE.md](LORE.md) (narrative canon) — those two remain authoritative
for gameplay/story; this one is authoritative for *how things look*.
Same rule as GDD.md/LORE.md: do not silently overwrite an established
decision here — flag the conflict instead.

**This document is planning only.** No asset in this repo has changed
as a result of it — no sprites, textures, shaders, or third-party assets
were sourced or created, no scene or gameplay code was touched, and no
lore beyond what's captured below was invented. See
[ASSET_AUDIT.md](ASSET_AUDIT.md) for what currently exists (all
placeholder geometry) and the exact gameplay constraints (dimensions,
hitbox offsets, timing, camera behavior) any future asset must respect.

The disclaimer in [LORE.md](LORE.md) applies to everything in this
document too: this is fictional worldbuilding inspired by the concept of
Jinn, not a claim about Islamic theology.

## 1. Core Visual Philosophy

**Ancient does not mean primitive.** Human civilization has not yet
begun in this setting, but Jinn civilization has already undergone an
extraordinarily long technological and cultural development —
conceptually: modern humanity, then thousands more years of
advancement, arriving at Avaris. The result should read as a
civilization vastly beyond modern humanity, not an ancient human
kingdom with a coat of paint.

The Jinn are not generic fantasy genies or stereotypical Middle-Eastern
fantasy creatures. This reinforces (does not replace) the direction
already set in [GDD.md](GDD.md) §2 and [LORE.md](LORE.md) §1.

**Avoid defaulting to:**
- desert ruins
- domes/minarets as shorthand
- medieval armor
- conventional swords
- generic genie imagery
- cyberpunk
- neon city aesthetics
- steampunk
- ordinary spaceships
- generic alien architecture
- human modern technology with futuristic decoration

## 2. Jinn Biological Language

Jinn are humanoid **living beings**: recognizable humanoid anatomy, two
arms/two legs, expressive faces, individual facial characteristics,
readable human-like body language, biological rather than robotic
presentation.

They are not human, however — their underlying nature is connected to
**fire**. This is *not* characters permanently engulfed in ordinary
flames. Their stable physical form contains an energetic/fire-born
nature underneath, which may become visible through:

- subtle fissures
- wounds
- emotional intensity
- power usage
- Veyr interaction
- destabilization
- damaged physical structure

The underlying fire should make them feel alive, not like elemental
monsters.

## 3. Jinn Fire

Innate to every Jinn. Visual characteristics: warm, ember-gold,
orange/gold, organic, turbulent, flowing, irregular, biological,
emotionally expressive. It behaves like living energy, not conventional
combustion — it represents something intrinsic to the being.

**Should not resemble:** generic fire spell VFX, constant burning, lava
skin, flame-headed characters.

## 4. Veyr

Visually **distinct** from Jinn Fire. Characteristics: violet /
violet-white, geometric, controlled, precise, mathematical, intentional,
structured, crystalline/light-like where appropriate.

**Core contrast, the single most load-bearing visual rule in this
document:**

| | Jinn Fire | Veyr |
|---|---|---|
| Nature | organic energy | organized energy |
| Feel | biological, turbulent | structured, controlled |

This distinction must stay readable everywhere it appears: characters,
attacks, infrastructure, UI, environmental effects, memory sequences.

**Purple/violet is an accent, not a base.** Do not turn the entire game
purple - see §20's color hierarchy.

## 5. Zayr

The visual anchor of the game. Reads as: humanoid, Jinn, athletic,
agile, expressive, technologically advanced, damaged/weakened, formerly
much more powerful.

**Not:** knight, robot, cyborg, generic fantasy warrior, superhero,
genie, armored human. His face stays visible and emotionally
expressive. His body/equipment should imply a civilization far beyond
modern humanity - clothing/equipment may use advanced adaptive
materials rather than conventional clothing + armor.

**Visual character emphasizes:** mobility, precision, asymmetry, exposed
internal fire, damaged elegance. His present-day appearance should
subtly communicate that he is a diminished version of his former self.
Future memory sequences may show a cleaner, more complete, more stable
version of Zayr (see §12 for the environmental parallel to this same
idea).

## 6. Zayr Weapon Language — the Veyr Edge

Zayr does not carry a conventional sword (reinforces the existing rule
in [LORE.md](LORE.md) §2: "skilled Jinn do not use manufactured
weapons"). The Veyr Edge is a **manifested structure**:

- **Neutral state**: empty hand, no conventional weapon.
- **Attack**: a Veyr structure manifests from/around the arm and hand.
- **After attack**: the manifestation collapses.

Different attacks may produce different geometric configurations:

| Attack | Manifestation character |
|---|---|
| Light (combo) | thin / fast / precise |
| Heavy | broader / denser |
| Charged | larger, synchronized geometric structure |
| Aerial | orientation adapted for aerial attack |

The Veyr Edge should visually belong to the same system as Veyr Step
and environmental Veyr technology - one consistent geometric-violet
visual language, not a separate "weapon FX" style.

## 7. Zayr's Veyr Step

Target eventual read (sequence, not simultaneous):

1. physical form destabilizes
2. underlying Jinn Fire briefly becomes visible
3. Veyr imposes geometric structure
4. body fragments/dissolves
5. displacement
6. body reconstructs

Not generic teleport particles. Perfect Step may briefly show a more
precise/complete Veyr structure than an ordinary Veyr Step, reinforcing
that it represents mastery (see [COMBAT.md](COMBAT.md) §7 for the
gameplay side of this reward).

## 8. Avaris

One of the game's primary visual characters in its own right. Should
communicate: immense scale, extraordinary technological advancement,
civilization, beauty, infrastructure, history, loss.

Architecture should feel unfamiliar without becoming random - the
player should still recognize the *concepts* (places people lived,
public spaces, infrastructure, transportation, gathering areas,
monumental architecture) even though their implementation looks vastly
beyond modern human engineering.

## 9. Avaris Material Language

| Tier | Materials |
|---|---|
| Primary | white / off-white advanced materials, pale stone-like composites, ceramic-like advanced surfaces, light metallic materials |
| Secondary | restrained gold detailing, dark structural interiors, natural greenery |
| Accent | violet Veyr, warm Jinn Fire / illumination |

Includes a **restrained** solarpunk influence - not a conventional
solarpunk city. Expressed through integration with nature, greenery,
clean materials, open light, optimistic architecture, environmental
harmony, while keeping the civilization's unique Jinn/Veyr identity
dominant.

## 10. Living Avaris

At its height, should feel: luminous, clean, enormous, inhabited,
sophisticated, ordered, alive, aspirational.

**Use**: white, gold, greenery, warm illumination, controlled Veyr,
active infrastructure, distant movement.

**Avoid**: overwhelming neon, dark cyberpunk streets, industrial grime,
human automobiles, recognizable contemporary technology.

## 11. Ruined Avaris

The present preserves the **same architecture** as Living Avaris - not
an unrelated "ruins tileset." They must clearly read as the same
civilization, before and after.

Present Avaris: weathered pale surfaces, broken structures, exposed
dark interiors, inactive infrastructure, collapsed sections, dead Veyr
conduits, occasional surviving Veyr remnants, vegetation/reclamation
where appropriate, enormous empty spaces.

The tragedy comes from recognizing what these ruins used to be - the
contrast is the point, not either state alone.

## 12. Memory Visual Language

Memory sequences temporarily reveal fragments of living Avaris, ideally
by reusing the **same environment geometry**, not swapping to an
unrelated scene:

```
RUINS
  ↓
infrastructure reconnects
  ↓
illumination returns
  ↓
Veyr activates
  ↓
movement appears
  ↓
civilization becomes visible
```

This contrast (§11 ↔ this section) is a major visual/storytelling
pillar, not a one-off effect. **This is already how the current
graybox Memory Sequence is built** (see [PROGRESS.md](PROGRESS.md)'s
Stage 6 enhancement entry) - existing nearby ruin geometry retints in
place, rather than swapping in separate "memory-only" set dressing -
confirming the current implementation already matches this pillar
structurally, even though its actual materials/colors are still
graybox.

## 13. Fallen Enemies

Basic enemies should visually belong to Avaris - avoid generic
monsters. Some may represent former protectors, former citizens,
surviving/corrupted Jinn, damaged constructs, or other remnants of
Avaris. **Do not canonize specific origins for every enemy yet.**

Fallen Jinn visual language: damaged advanced materials, broken
elegance, unstable Jinn Fire, fractured Veyr, traces of former
civilization. The player should occasionally be able to think "this
thing wasn't always a monster."

## 14. Current Vertical-Slice Enemy Language

| Enemy | Visual priorities |
|---|---|
| Melee enemy | readable aggressive silhouette; damaged Avaris-era material; unstable Veyr manifestation; recognizable former sophistication |
| Ranged enemy | clearer Veyr-channeling identity; surviving advanced technology; readable ranged silhouette; geometric Veyr focus |
| Mini-boss | substantially larger silhouette; more surviving advanced equipment; greater Veyr instability; stronger presence |

The mini-boss is the first major remnant of a genuinely dangerous
former warrior/protector - but remains a **generic** prototype
character (matches [PROGRESS.md](PROGRESS.md)'s Stage 5 instruction:
"the existing generic MiniBoss should remain a prototype character...
do NOT turn it into one of the canonical named bosses"). Do not treat
it as a major canon character.

## 15. Rhaek

Not visually a generic villain. He and Zayr must clearly originate from
the same civilization, but read as visually distinct individuals.

| | Zayr | Rhaek |
|---|---|---|
| Build | agile, lean, asymmetric | broader, grounded |
| Presence | damaged, exposed internal fire | composed, authoritative, controlled |
| Reads as | mobility / precision | stability / command |

Remains recognizably humanoid and emotionally expressive; his face must
be visually distinct from Zayr's - approved direction includes a
noticeably different facial structure, jaw, hair silhouette, facial
hair where applicable, and age/presence.

**Past Rhaek**: pristine, white/light advanced materials, restrained
gold, controlled Veyr, admirable/authoritative appearance.

**Present Rhaek**: same recognizable person, darker/damaged materials,
visible consequences of the fall, greater Veyr instability, emotionally
burdened.

**Do not** reduce this to "good guy wears white → evil guy wears
black." He is morally/narratively ambiguous at this stage - this
matches [LORE.md](LORE.md) §5's explicit "not yet specified, treat as
reserved" status for his relationship to Zayr, and §4's "do not invent
specifics ahead of [story milestones]." The current graybox teaser
(a featureless dark silhouette, see [PROGRESS.md](PROGRESS.md) Stage 7)
deliberately shows neither Past nor Present detail yet - it's a
placeholder shadow, not a statement about which version he is.

## 16. Character Face Rule

Major characters must have visually distinct faces. Do not reuse the
same facial proportions, jaw structure, hairstyle, nose, eye structure,
facial hair, or age cues with only minor cosmetic changes between them.
The cast should remain recognizable even without armor, without Veyr,
and without color coding.

## 17. Technology Language

Avoid treating Jinn technology as human technology plus futuristic
decoration. The civilization is extremely advanced; some technology may
blur boundaries between material, energy, biology, architecture, and
computation. Technology still needs visual rules, though: Veyr-based
systems use the established geometric language (§4), and **every major
glowing structure should appear to have a purpose** - not surfaces
filled with meaningless glowing lines. (Matches the existing "activated
vs. dormant" Veyr-infrastructure motif already built into Stage 4/5/6's
graybox - see [ASSET_AUDIT.md](ASSET_AUDIT.md)'s Veyr/environment
effects section.)

## 18. Transportation

May appear in memories/backgrounds later. Do not design literal
"flying cars." Use abstract advanced transit concepts instead -
suspended movement systems, geometric transit forms, infrastructure-
based movement, controlled floating structures. The player should
understand "people are moving through the city" without necessarily
understanding the machine.

## 19. UI Direction

UI should eventually inherit the world's design language - avoid
generic fantasy UI. Potential language: clean geometry, restrained Veyr
motifs, light structural lines, excellent readability, minimal
ornament. **Gameplay readability overrides decorative worldbuilding.**
Final UI design remains open (§24).

## 20. Color Discipline

Avoid monochromatic world design. Broad hierarchy (guidelines, not
strict universal color codes):

| Color | Meaning |
|---|---|
| White / pale | Avaris civilization / material identity |
| Gold | prestige / structure / detail |
| Green | life / ecological integration |
| Ember / orange | Jinn Fire / biological energy |
| Violet | Veyr |
| Dark charcoal | damage / exposed structures / present-day contrast |

## 21. Funding Vertical Slice Priority

The current production objective is **not** to build the entire game's
asset library - it's a highly polished 10-15 minute funding-quality
vertical slice. Art production should prioritize assets actually
visible in that slice. Do not prematurely create dozens of enemy types,
later regions, complete NPC populations, every major boss, or entire
game tilesets. **Quality over quantity.**

## 22. Asset Production Principles

Future art must respect the gameplay constraints already documented in
[ASSET_AUDIT.md](ASSET_AUDIT.md), especially: collision dimensions,
attack hitbox positions, animation timing, camera assumptions, enemy
scale, VFX attachment requirements.

**Visual art must not silently change gameplay.** Collision remains
gameplay-authoritative unless explicitly redesigned.

## 23. Visual Validation Rule

Standing production rule: **never approve an environment/background
asset solely because it looks correct in the editor.** This vertical
slice's own development repeatedly demonstrated that theoretically
correct geometry can be invisible or poorly framed from the actual
gameplay camera - four separate times across Stages 4-7, per
[ASSET_AUDIT.md](ASSET_AUDIT.md) §3's camera-assumptions note and every
matching entry in [PROGRESS.md](PROGRESS.md). Every significant
environment composition must eventually be validated through: **real
game camera + real player position + screenshot/playtest.**

## 24. Currently Locked vs. Open

**Locked direction:**
- humanoid Jinn
- fire-born biological identity
- Jinn Fire vs. Veyr distinction
- geometric violet Veyr
- ancient ≠ primitive
- highly advanced pre-human civilization
- white/light Avaris material direction
- restrained gold
- restrained solarpunk influence
- greenery/environmental integration
- Zayr's broad visual identity
- manifested Veyr Edge concept
- Fallen-enemy visual philosophy
- Rhaek's broad Past/Present direction
- distinct major-character faces
- Living vs. Ruined Avaris contrast

**Still open** (do not silently treat as finalized):
- exact production sprite style
- exact sprite resolution
- skeletal vs. frame-by-frame vs. hybrid animation
- final character proportions
- final enemy designs
- final mini-boss design
- exact environmental modular kit
- final UI
- final VFX implementation
- final lighting
- shaders
- audio
- music
- final animation production pipeline

## 25. Next Production Milestone

After this document is reviewed: **Zayr Production Sheet** - translates
this approved concept into an asset that can actually replace the
player placeholder. Not started as part of this pass.
