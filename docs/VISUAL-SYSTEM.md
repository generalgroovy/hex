# FLUX runtime visual system

Status: **current runtime presentation architecture with labeled historical evidence**, 2026-09-08.

The runtime visual system is presentation-only. It may interpret authoritative
state, but it never decides movement, collision, visibility, resources, spell
membership, damage, cooldowns, score or outcomes.

[SPECIFICATION](../SPECIFICATION.md) owns current scope;
[VISUAL-DIRECTION](VISUAL-DIRECTION.md) owns the current visual contract.
This file explains their presentation boundaries, not a second implementation
queue. The current character checkpoint is
[basic templates, gait, portraits and compact guides](CHARACTER-TEMPLATE-V2-CHECKPOINT.md).
The V0–V6 sections below preserve earlier engineering evidence and are explicitly
historical; their acceptance scores, named spells, map dimensions and production
commands do not override the current contracts.

## Expandable foundation

| Boundary | Canonical source | Responsibility |
| --- | --- | --- |
| Visual tokens | `content/visual/visual_language_v1.json` | Pixel grid, ordered ramps, eight active element identities and four reserved style entries, UI metrics, density budgets, layer order and review thresholds. |
| Validation/API | `src/presentation/visual_language.gd` | Fail-closed loading and typed access without local color invention. |
| Pixel components | `src/presentation/pixel_primitives.gd` | Stepped panels, dividers, material tiles, runes and resource treatments shared by world, spells and GUI. |
| Pixel placement | `src/presentation/pixel_presentation.gd` | Whole-output-pixel translation at 50/75/100% while simulation stays subpixel/fixed-point. |
| Live campus | `src/presentation/sanctum_campus_renderer.gd`, `src/presentation/wellspring_illustrated_kit.gd` | Validated illustrated ground, opaque worldbone structures, stations and readable activity areas; art never owns collision. |
| Body presentation | `src/presentation/cartoon_champion_presenter.gd` | Registered three-size, eight-heading pages, distance-driven contact selection and sprite-derived portraits. |
| Pixel magic | `src/presentation/pixel_magic_library.gd`, `src/presentation/element_chemistry_presenter.gd` | Validated reusable pixel frames clipped to authoritative material coverage and phase; essential material remains at zero optional decoration. |
| Player guides | `src/presentation/player_compendium.gd`, `src/presentation/chemistry_guide_model.gd` | Compact movement table and full 8×8 chemistry matrix with current values and accessible Details. |
| Gate specimen | `src/presentation/visual_specimen.gd` | Live `--visual-specimen` review of tokens and components; it is diagnostic evidence, not gameplay authority. |

Every promoted character, environment, spell and GUI slice must reuse these
boundaries or version them explicitly. A local hard-coded palette, arbitrary
layer, unbounded particle count or renderer-owned rule is a regression.

## Maintained cohesion hierarchy

Existing engineering evidence is not blanket visual acceptance for later
slices. Every touched asset follows the same reading order and is reviewed
inside live gameplay rather than only on an isolated sheet.

| Priority | Live read | Shared rule |
| ---: | --- | --- |
| 1 | Champion and immediate state | Stable 58/68/76 px body envelopes, shared feet pivot, body/clothing-only atlas, ancestry silhouette and no per-action scaling. |
| 2 | Hostile spell geometry | Dark boundary, bright controlled core, ownership shape, bounded size/speed class and unambiguous travel/collision cue. |
| 3 | Interactive matter and major reactions | Tileable native-pixel material shows occupied area and phase; no range circles, perimeter markers or diagnostic outlines. Contextual information stays compact and distinct from material. |
| 4 | Routes, cover and landmarks | Quiet walkable values, visible collision feet/thresholds, large district silhouettes and authored response lanes. |
| 5 | Material texture and ambient life | Warm stone, timber, brass, water and growth detail concentrates at scenic edges and never competes with play. |

Map composition works from large landmark → route/cover → interaction anchor →
ambient detail. Repeated rectangular fill, uniform green/tan fields and local
decorative noise are polish defects even when collision is correct. The
ordinary build hides capture diagnostics and historical labels.

Projectiles use a small validated family of screen-readable size and speed
classes. Visual minimums may protect readability at wide zoom, but simulation
radius, trajectory, timing and collision remain unchanged. Effects are pooled
or simplified only after measurement and may never merge separate hazards into
one unreadable glow.

## Perspective and character read

FLUX uses top-down cardinal floors with tilted facades, not a diamond isometric
grid. Walkable tiles remain visually square; horizontal/vertical inputs map to
horizontal/vertical screen movement; wall feet, cover footprints, door
thresholds and elevation transitions stay visible. Art uses a 55-degree
illustration angle while floors stay unrotated; facades may rise up to 0.85 of
their readable footprint. Current worldbone structures remain opaque and stable:
no proximity fade or replacement with a flat footprint. Preserve readable
routes through composition and silhouette placement rather than making solid
structures disappear. The retained `cutaway` layer and archived architecture
helpers are compatibility/history, not permission to restore that behavior.

The original Oh Tipi artwork is the current character style authority, as
recorded by the [template contract](../art_batches/character_style_v1/template_v2/contract.json).
Champions use sensible anatomy and expressive nonphotorealistic pixel rendering:
an ordinary head/skull at 20–23% of total body height, clear torso and limbs,
body-and-clothing-only pixels, 1–2-pixel outlines, 3–5 colors per material and a
separate grounded shadow. Hair, fins, horns and ancestry crowns are silhouette
features rather than cranium size. Hands cast magic; weapons, spell effects,
auras, shadows and environment are not baked into character pixels.

| Shared body rule | Current contract |
| --- | --- |
| Sizes | Small / Middle / Large at exactly 58 / 68 / 76 px standing height |
| Registration | 96×96 cells; common 48/84 foot pivot; one calibrated scale per body across every action |
| Eight headings | `S/SE/E/NE/N/NW/W/SW`; symmetric front, centered back, true side profiles, distinct front/back quarter views |
| Ten rows per heading | `grounded`, `jump`, `cast`, `hit`, `walk`, `sprint`, `slide`, `roll`, `walk_b`, `sprint_b` |
| Gait | Anatomical left/right support alternates with opposing arms; real locomotion distance advances a shared phase without turning correction offsets into footsteps |
| Portrait | Exact top third of occupied South-grounded sprite bounds, full width, nearest proportional fit into transparent 32×32; shared by HUD and Gallery |
| Gameplay boundary | Three sizes retain distinct stats and hurtboxes but share wall clearance; neither is derived from sprite pixels |

All 80 heading/action cells must be readable. Rear diagonals show the back and
rear skull rather than a side-on face; adjacent headings must remain
distinguishable. Existing Jan diagonals still need raster correction. A
different pixel hash or recolored trousers does not prove alternating anatomy.
Travel and aim remain continuous; presentation does not quantize simulation or
change movement controls. Current walking still has two authored contacts, not
a completed multi-frame walk cycle.

**Production gate: basic Small → Middle → Large templates first, then user
acceptance of all three together.** Only then may named-character repair or
remaining-cast generation resume. Construction guides and a Small South-only
technical proof are not approved neutral runtime atlases. Existing playable
pages stay usable while new candidate promotion requires exact-hash review.
Follow [ADDING-VISUAL-ASSETS](ADDING-VISUAL-ASSETS.md) and the
[template production guide](../art_batches/character_style_v1/template_v2/README.md),
not archived generation commands below.

Older concept boards remain composition references, not replacements for the
original Oh Tipi authority or the current camera/template contract.

## Element identity and acceptance boundary

The eight active families are Earth, Fire, Water, Wind, Ice, Charge, Light and
Dark. Spirit, Chaos, Gravity and Time remain reserved palette/glyph entries for
compatibility only; they do not enable additional spells or chemistry.
The specimen and player-facing current overviews show active elements only.
Each active family must read through color, shape, value and motion together;
do not recolor an existing validated pixel pack without reviewing its sprites
and preserving source/atlas provenance.

Plain terminal matter from Bolt, Heavy, Rapid and Wave is finite and harmless
by itself; Beam, Spray and Field do not supply chemistry deposits. The 36
first-grade recipes act only during their authoritative active windows. Steam
uses billowing concealment material, not an implied damaging Water cloud;
stone deposits are not automatically walking walls. Reaction cover blocks
shots/rays rather than walking. Material animation shows actual coverage with
world-anchored, clipped pixel tiles, including in reduced effects.

Source checks, actual renders, packaged boot, human style/feel acceptance and a
published installer are separate gates. No historical score proves current
template acceptance, internet play or sustained 120 FPS; the simulation target
is authoritative 120 Hz.

Run the current diagnostic token specimen on Windows:

```powershell
scripts/run.cmd --visual-specimen --pov-mode=full --camera-zoom=75
```

## Historical evidence ledger

The V0–V6 narratives below describe their recorded checkpoints, including older
cutaway behavior, character production paths, spell profiles and campus size.
Past-tense scope applies throughout these sections even where the original
record uses “now” or “live.” Retain them for provenance and architectural
context; use the contracts above and the active implementation queue for new
work. Their engineering acceptance does not reopen the current basic-template
user gate.

### Historical V0 baseline

Historical baseline captures were recorded on 2026-08-13 from commit `e996610`
at 1280x720 and 1920x1080, camera 50/75/100%, full view, fixed 60 Hz. They are
comparison evidence, not a supported current runtime. The 75% frame
demonstrates the primary failure clearly: flat schematic surfaces, tiny actor
scale and a text-heavy top HUD preserve rules but do not meet FLUX's charm,
material, silhouette or overview targets.

The specimen froze vocabulary; it did not itself open the visual gate. V1–V6
recorded the subsequent character, environment, spell, GUI and integrated
engineering evidence; the current queue supersedes that historical sequence.

### Historical V1 renderer foundation

The Wellspring renderer now refuses to boot without the validated visual
language and derives its water, stone, timber, brass, roof, garden, focus and
text colors from the shared ramps. Quiet floors expose square screen-cardinal
cells, paths carry transverse seams rather than implied diagonal tiles, and
building art preserves its complete authored footprint plus an external door
threshold.

Decorative roofs and facades never own collision. A deterministic
presentation-only proximity mask replaces architecture with its cardinal
footprint near the observed actor, easing across a bounded 26-unit band. Cone
visibility continues to use the separate authoritative building bounds. The
same renderer, camera transform and cutaway calculation read the authoritative
120 Hz state; none of them write simulation state.

V1 captures at 1280x720 and 1920x1080 confirm alignment at the default 75%
overview. They remain internal evidence under `.godot/visual-gate-v1/`: the
live map is still schematic and the v2 character atlases are still too small
and crude. V2 therefore begins with compact cartoon production candidates for
Oh Tipi and S. Wayne before further environment beautification.

### Historical V2 foundation champions and minimal motion

S. Wayne, Oh Tipi and The Red Baron now draw from one promoted 768×2880
body-only runtime atlas with 96×96 cells and a 48×84 ground pivot. Each champion
owns grounded, jump, empty-hand cast, hit/recovery, walk, sprint, slide and roll
art in all eight directions, plus alternate walk/sprint contacts. Source art
remains provenance-only and is excluded from exports. Atlas and decoded-pixel
hashes are pinned by
`content/visual/foundation_champion_visuals_v1.json` and
`assets/sprites/champions_v3/foundation/provenance.json`; the manifest also
requires the canonical body type and explicitly excluded baked layers.

`scripts/build_cardinal_champion_atlas.py` and
`scripts/build_red_baron_foundation_atlas.py` are the deterministic promotion
boundary. They proportionally slice the source boards, remove only
edge-connected matte, keep one scale per champion across all actions, align
the shared pivot, apply the Red-Baron-led mature proportion grammar in strict
`small` → `middle` → `large` order, and pack champion-major/state-minor rows. This prevents pose
changes from changing apparent body scale and lets artists replace one source
sheet without adding renderer branches.

Walk and sprint select their dedicated rows immediately; Slide, Wave Dash and
Wall Skim share the low directional body row while Roll selects the compact
tuck. Air Dodge remains on the airborne row. Reusable clocked motion, wakes,
chevrons, receiving-surface shadows and intangibility contours remain separate
layers and never extend collision or invulnerability.

Animation is deliberately reusable rather than baked into gameplay code.
`content/visual/minimal_champion_motion_v1.json` declares bounded idle, walk,
sprint, low-profile, airborne, cast and hit keyframes for two motion profiles,
plus one restrained visual accent for every advanced movement family. The live
presenter derives pose selection only from authoritative state and samples a
rate-independent presentation phase from 120 Hz state. Offsets stay within four
pixels, squash/stretch within 6%, reduced motion damps all three channels, and
the `--debug-overlay` diagnostic proves the sprite never owns its hitbox.

### Historical V3 natural-map and modular-campus candidate

`content/visual/natural_map_kit_v1.json` is the editable environment recipe.
It declares bounded district vocabularies, density, material ramps, seeded
edge props, ground variation and walk/sprint/slide/air contact marks.
`NaturalMapKit` validates the recipe, produces deterministic natural variation,
smooths visual route polylines without changing authored endpoints, and never
modifies collision, elevation, route metadata or simulation state. Actors and
training targets render after environmental detail so decorative growth cannot
hide gameplay information.

Use the deterministic movement review harness on Windows, changing the final
mode through `walk`, `sprint`, `slide`, `jump`, `air_dodge` and `technique`:

```powershell
scripts/run.cmd --capture-spawn=300,720 --capture-pointer=900,720 --capture-movement=slide --champion=oh_tipi
```

`content/visual/wellspring_architecture_kit_v1.json` adds the next reusable
environment boundary. Seven building profiles, ten station-furniture profiles,
five landmark frames and one source-court profile validate against the live
campus before rendering. Material-textured facades, roof facets/dormers/domes,
visible doors, planted pavers, shallow water channels and landmark furniture
reuse the approved `SanctumRuntimeKit`; reference/concept pixels never enter the
runtime path.

The source-court profile now carries six bounded decoration anchors. Lanterns
mark the lateral approaches, planters soften the lower corners, and elemental
runes bookend the north/south lanes. Anchors are validated against the court
interior, use shared language ramps, and draw after pavers with reduced-effects
alpha; they are presentation-only and cannot occlude actors, alter collision, or
change station interaction radii.

The architecture kit remains presentation-only. Authored campus data still owns
topology, collision, route endpoints, elevation, station commands and interaction
radii; the existing deterministic cutaway still uses the canonical footprint.
Final engineering captures under `.godot/v3-acceptance-*` cover the garden,
Nexus and proving quarter; Nexus at 50/75/100%; and a deterministic partial
building cutaway. Scenic-edge props remain legible at overview zoom, nearby
waypoint labels yield the actor-readable lane, paths remain above decoration and
the compact HUD preserves its play-space budget. This completes V3's engineering
slice and opens V4; subjective final cohesion is still scored at integrated V6.

The post-unification review on 2026-08-26 extended this evidence with truthful
1280×720 captures at 50%, 75% and 100%, a 1920×1080 capture at 75%, and a
20-frame 1280×720/75% startup-and-chain cast run, plus four-frame
high-contrast and reduced-effects runs. The source court's six decoration
anchors remain visible at overview and detail scales. These captures prove
dimensions, launchability, and alignment only; the V6 rubric still needs
interactive two-player and subjective cohesion review.

### Historical V4 foundation-spell presentation

The five profiles below are historical presentation evidence, not the current
57-spell catalog. Their dual-element wording, freeze/ring descriptions and
residue claims must not be used as current spell or chemistry rules.

`content/visual/foundation_spell_visuals_v1.json` is the exact five-spell visual
contract. It is validated against the ability catalog at boot: stable wire ID,
shape, element and residue must match, every spell must own one distinct startup
silhouette, and the effect/lane/curve budgets remain bounded. A catalog mismatch
stops startup rather than silently rendering a misleading spell.

`FoundationSpellPresenter` reads only authoritative presentation state. Pending
cast ticks drive startup progress; projectile and field entities drive their
existing geometry/lifetime; semantic beam, spray, hit, trigger and refusal events
drive short feedback. It cannot change a cast's range, radius, collision, cost,
cooldown, damage, control, material result or outcome.

`content/visual/spell_animation_skeletons_v1.json` is the reusable delivery
grammar shared by those profiles. It defines five bounded phases—startup,
release, travel, impact and residue—for projectile, beam, spray and field
shapes, with explicit draw-family and readability-cue tokens. The
`SpellAnimationSkeletonLibrary` loader rejects missing, overlapping, reordered or
unbounded phases; `FoundationSpellPresenter` refuses a profile whose
`skeleton_id` does not match its authoritative delivery shape. This keeps
hand-origin anticipation, lane/endpoint reads and quiet residue editable data
while simulation continues to own the actual timeline and result. The presenter
now renders the shared startup origin ring and release flash from those first
two phase IDs before each spell's specific silhouette, giving every cast a
consistent readable hand beat without adding a gameplay event.

The manifest is registered in `content/visual/visual_asset_registry_v1.json`
and its SHA-256 is printed in the Windows bootstrap diagnostic next to the
foundation profile hash. A capture or handoff that shows a different skeleton
hash is a different visual build, even when simulation content is unchanged.

| Spell | Startup | Action/trail | Impact/residue |
| --- | --- | --- | --- |
| Rillshot | Gathered Water drop | Faceted drop with split rill wake | Expanding splash ring; no residue |
| Tideline | Rising three-crest fan | Seven curling lanes and bounded fan | Breaker arc; no residue |
| Rimewake | Six-ray frost sigil | Persistent crystal/snowflake field | Freeze star; field is the residue |
| Eclipse Disc | Paired orbiting crescents | Dark/Light disc with orbit echo and bounce pips | Split crescent break; no residue |
| Pocket Eclipse | Converging Light/Dark focus rails | Paired cover-bounded beam | Revealed endpoint diamond; no residue |

Cooldown and Flux remain honest in the compact authoritative HUD; failed casts
retain their text reason and gain a closed-sigil cue without faking an action.
Target impacts render above the practice effigy, while fields remain below actors
and all alpha/effect budgets preserve collision and silhouette reads.

Default-75% 720p evidence for all five spells is under
`.godot/v4-acceptance-720-*`. These captures are ignored test artifacts, not
runtime assets. V4 is engineering-complete, while integrated
charm/accessibility scoring remains mandatory at V6. The V5 sandbox capture
harness now supplies truthful 1080p evidence without rewriting the live project.

### Historical V5 compact HUD and Wellspring interaction language

`content/visual/compact_hud_v1.json` now owns the bounded combat-HUD geometry.
The live frame keeps only champion/location, session state, Health, Flux,
Stamina, the active Plain/Ctrl/Alt layer and exactly four active spell cells.
Detailed controls, mechanics and configuration remain at the existing
translucent Wellspring stations instead of permanently consuming navigation
space. The HUD remains under the shared 19% screen-coverage budget and does
not introduce a fifth spell button.

`content/visual/wellspring_interaction_language_v1.json` owns the presentation
profiles for the exact ten live station kinds plus bounded compact, expanded,
social and notice layouts. `WellspringInteractionPresenter` validates that
coverage against the authored campus and fails closed on missing or duplicate
styles. It draws only screen-space information: a localized current-key
capsule, source tether, station crest, named social bubble and top-center
notice. Commands, activation radii, simulation state and network authority stay
in their existing owners.

The HUD uses stepped old-world frames, miniature champion portraits,
element-shape glyphs and resource tick marks so shape and position carry state
alongside color. Its logical 1280×720 design space scales to 1920×1080 while
camera zoom remains a world-view choice; station prompts and social bubbles
therefore keep the same readable screen relationship at 50/75/100% zoom.

Run `scripts/capture-visual.ps1` on Windows for truthful 1280×720 or 1920×1080
evidence. The wrapper makes a unique system-temporary sandbox, imports there,
changes only that copy's viewport, checks every frame's count and dimensions,
and cleans only the verified sandbox. Reviewed V5 evidence is under ignored
`.godot/visual-captures/v5-acceptance-*-final` directories.

### Historical V6 integrated accessibility and Farflow acceptance

`content/visual/accessibility_profiles_v1.json` owns the exact visual profiles,
their labels, provenance and one-pass budget. `VisualAccessibilityFilter`
validates that contract and the shader before use. Standard play hides the
overlay entirely; high contrast is player-facing, while grayscale,
protanopia, deuteranopia and tritanopia are review simulations for detecting
hue-only information. They are not medical correction profiles.

The Controls Lectern exposes reduced effects with M/controller L3 and high
contrast with H/controller R3 while open. Reduced effects damp champion,
environment, spell, field, projectile, cue and reconciliation presentation but
retain authoritative duration, radius, lane, target, cooldown and resource
truth. High contrast uses the same bounded one-pass filter and never changes
visibility or simulation.

Capture-only flags are exact: `--capture-visual-profile=grayscale|protanopia|
deuteranopia|tritanopia|high_contrast` and `--capture-reduced-effects`. Normal
CLI movement, POV, angle, range and camera overrides are also transient: capture
or diagnostic exit never persists them over the player's saved profile.

Reviewed evidence lives under ignored `.godot/visual-captures/v6-acceptance-*`:
standard and grayscale at 1280×720; common color-vision simulations; high
contrast; reduced-effects Rimewake; geometry/POV alignment; and a 1920×1080
visual-host Farflow pair with two real processes, two visible champions, host
`2/8` state and a network-verified guest greeting. The integrated engineering
scores are cohesion 4.5, silhouette 4.5, material identity 4.5, world overview
5.0, HUD clarity 5.0, animation response 4.0 and spell readability 4.5 (mean
4.57). That clears V6 while identifying animation response as the first
continuing visual-polish target.

`content/visual/wellspring_wayfinding_v1.json` makes the 2560×1440 campus read
as a group of destinations: Movement Conservatory, Recovery Grove, Living
Archive, Wellspring Looms, Settings House, Farflow Gates, Dueling Court and
Elemental Crucible. `WellspringWayfinding` validates each point against its
authored district, shows at most four nearby labels and only draws
presentation-only brass/element markers. The renderer also gives each large
quarter a quiet identity motif—garden terraces, Nexus plaza rings or proving
targets—without changing collision, routes, elevation, visibility or authority.
