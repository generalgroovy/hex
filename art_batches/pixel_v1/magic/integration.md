# FLUX magic candidate pack

This is an **authored, exported candidate pack**, not an integrated runtime change.
All files belong to `art_batches/pixel_v1/magic/`. The simulation, production
presenters, shared manifests, character/map assets, README and working branch
were not edited to make the pack. No installer or production build is claimed.

## Source and precedence

The verified local reference is `286bd8f`, on `main`. `source/authority_snapshot.json`
records byte hashes for the inspected GDScript, reaction catalog, visual language
and spell manifests. The 36 reaction identities match the catalog, but geometry,
lifetimes and behavior come from `src/sim/chemistry/element_chemistry_system.gd`.
Legacy catalog prose about ramps, terrain mutation, fuel, extra optical rays or
movement changes is not part of this pack's compatibility claim.

Original integer pixel drawings in `source/author.py` and editable per-frame
`source/frames/*.json` provide the artwork. No third-party pixels or sequences
were copied. The broad [Penusbmic reference](https://penusbmic.itch.io/) informed
the requested emphasis on silhouette, key poses and economical material motion.
The palette is the user's eight exact ramps, existing warm-stone/deep-water
tokens for movement/information, plus a separate neutral Steam material ramp.

## Import and authoring

- Import `export/magic_00.png` through `magic_02.png` as **RGBA8, nearest sampling,
  no mipmaps, no texture filtering or lossy compression**. Three 1024×1024 pages
  decode to **12 MiB**. Each rectangle has a two-pixel transparent RGBA-zero gutter.
- Read each asset's `frames[].rect`, `duration_ticks`, `pivot_px`, `loop`,
  `end_behavior`, attachment and layer role from `manifest.json`. Rectangles
  exclude padding. Do not trim cells independently or recalculate pivots from
  visible bounds. Importing via a tool that repacks textures must preserve gutters.
- A logical authored pixel is one world pixel at 100% camera zoom. The existing
  32 px terrain cells and 58/68/76 px body envelopes are references, not resized
  assets in this pack. At 50/75%, nearest sampling necessarily drops/duplicates
  some logical pixels. Actual camera shimmer remains a runtime acceptance item.
- Bodies and all ordinary material cores stay upright on the approximately
  55-degree art elevation. Ground stamps attach to ground positions, independently
  of sprite lift. Bare-hand preparation/release attach to the existing hand anchor;
  this pack contains no hands, weapons, staffs, character bodies or physical props.
- Tail/connector textures labelled `east` have local +X orientation. An integrator
  may rotate the **cosmetic sampling basis** continuously using nearest sampling.
  Never quantize real aim, endpoints, velocity or collision to directional art.
  Billboard cores retain their asymmetric material silhouette without rotation.
- Every sprite's authored alpha is binary. Global opacity is applied at composition
  time, not baked into fuzzy/fringed PNG edges. Keep essential information at full
  contrast independently of decorative material opacity.

The exporter reads editable frame JSON, **not the authoring script**. To adjust
one pose, edit its palette-index rows in `source/frames`, then re-export. Running
`author.py` deliberately recreates the initial source set and overwrites hand edits;
do so only when intentionally regenerating this candidate from its source code.

```powershell
python art_batches/pixel_v1/magic/source/export_pack.py
python art_batches/pixel_v1/magic/source/validate_pack.py
python art_batches/pixel_v1/magic/source/build_previews.py
```

Pillow 11.3.0 and Python 3.14.2 were used. No dependencies were installed. PNG
source reconstruction is checked pixel for pixel. The preview generator uses
Windows Consolas for readable preview labels; those labels are never game assets.

## Timing and attachment

Select a frame by **absolute phase age in 120 Hz ticks**. Loop only when `loop` is
true; never increment frames once per draw. Positional interpolation continues
independently while a pixel pose holds. Sample all current authority flags first:

1. Reject unborn, expired, interrupted or mismatched effects immediately.
2. Select the current formation/active/decay sequence from authority state.
3. Compute phase-relative elapsed ticks; accumulate declared frame durations.
4. For loops, wrap by the sum of durations. For one shots, honor `end_behavior`:
   `hide` ends the cosmetic sequence; `hold_until_authority_phase_end` retains its
   last pose only while the same authoritative phase remains valid.
5. Draw at the interpolated anchor using the declared pivot and mask.

Preparation animation does not schedule release or add windup. Impact shards
are harmless point-contact decoration, not an extra area hit. Protection badge,
corners, Float wings and budget marks use current state directly, have no fade
on exit and may never appear in an afterimage.

Existing deposit lifetimes remain: Earth **600**, Fire **360**, Water **480**,
Wind **240**, Ice **480**, Charge **240**, Light **360**, Dark **360** ticks.
The deposit sequences loop inside that lifespan; their durations cannot extend it.

## Variable geometry

The exported reaction frames are **composable material cells**, not complete
fixed-size reaction sprites. `manifest.reactions` binds their three phases and
normal/reduced variants to the live geometry vocabulary. `source/geometry.py`
is a fixed-point reference port for preview masks and regression checks; integrate
against the actual game predicates and returned geometry, not a second simulation.

| Source shape | Composition rule |
|---|---|
| Disk, flow, veil, node, fracture, observation, border | Tile/stamp material only inside current authority radius; independent occupied edge. The source `border` currently occupies a disk, not merely a perimeter. |
| Ring / annulus | Subtract `state.length` as the **inner radius**. Conflagration and Vortex centres remain empty and safe. Render both occupied edges. |
| Front / corridor / growing strip / bands / reveal line | Capsule from actual position to actual endpoint, including rounded end coverage; repeat connectors, clip caps, never stretch a fixed panel across unrelated geometry. |
| Cover / plane / lens | Capsule perpendicular to direction, with endpoints at `position ± normal * length/2` and thickness `2 * radius`. Tiles describe material; no camera-height hitbox is invented. |
| Water path / frost path / branch | Draw only actual `path_points` and valid links. Unlinked Water path retains its real local disk. Unlinked Frost path and Plasma branch have no occupied connection. Open socket means unconnected. |
| Hailstream | One moving 25 px disk intersected with the actual lane capsule. Period is 54 ticks / 450 ms. The warning lane and the active pulse are different information; never draw a string of active hail projectiles. |

Steam uses radius 30→90 px over 108 active ticks; Freeze uses length 20→140 px
over 144 active ticks. Moving fronts and Ion Storm follow actual state positions,
including collision-blocked motion. Do not recompute movement from a visual loop.

Crystal Prism, Lightbend and Crystal Lens facets contain **no rays**. Read the
actual ray-interaction return value for continuation origins/endpoints. Reflection
starts at the real entry point. Lightbend uses the admitted +15-degree turn;
Lens may expose ±15-degree continuations only when gameplay actually returned
them. Capacity, element eligibility and split damage remain simulation concerns.

For each reaction the exact phase milliseconds, ceiling-rounded tick counts,
shape, radius, length, source speed and pulse interval are included in the
manifest. Steam concealment ends **350 ms before decay**; Shadowdraft concealment
alternates in **300 ms bands**. Reveal/conceal overlays must therefore use actual
state separately from the looping material. Reduced mode cannot hide that change.

The game also applies collision clearance/visibility when determining affected
actors. These empty-world previews contain no map. The integrator must clip or
qualify effective warnings using the actual collision/line-of-sight information;
the candidate mask alone does not prove effective damage or sight through cover.

## Spell and movement components

| Form | Components and constraints |
|---|---|
| Beam | Tile `beam_body` along continuous segment direction; `beam_start` / `beam_end` are separately clipped caps. Entry/exit connector pixels are verified identical. Never repeat caps at every tile. |
| Spray | Sparse `spray_grain` stamps inside the exact source cone; grains do not define separate hits. Keep the real cone warning and remaining lanes readable. |
| Burst | `burst_release` is hand decoration; reuse the flight core once per admitted projectile. It does not manufacture a new fan or change projectile count. |
| Field | World-locked `field_tile` beneath bodies, clipped to exact occupied geometry. Suggested material alpha: 0.12 normal / 0.06 reduced. |
| Takeoff / landing | Hand-authored stepped floor marks plus dust with stable feet pivots. They communicate contact, not immunity. |
| Slide | Directional short trail and dust, tied to continuous real travel; suppress at rest. |
| Wallrun / walljump | Short angular sparks and dust burst at the actual collision contact. Stop sustained sparks immediately on detach. |
| Air dash | `air_dash_afterimage_mask` multiplies the caller's **body-only** texture alpha. Two normal copies at 0.16/0.08 opacity, one reduced copy. Apply to the three existing body envelopes; no replacement body pixels are included. Clear on dash end; exclude hands and protection. |
| Float / protection | Static corners, shield badge, wings and budget mark. Show/hide from current authoritative protection; size-specific Float cap and remaining time come from gameplay, not the pack. |

## Reduced effects and budgets

Every sequence has a normal/reduced entry. Essential boundary, link-state and
protection frames are pixel-identical across variants. Flight cores remain
distinct by silhouette as well as color; reduce tails, satellite grains and material
stamp density first. Canonical material cells can be clipped, cropped and reused;
do not allocate a scene node or particle system for every grain.

Suggested global decorative budget is 192 material stamps normal / 96 reduced,
with per-asset limits in the manifest. These are **unprofiled candidate budgets**,
not changes to the actual 128-deposit / 32-reaction authority limits. Render every
admitted projectile core and essential boundary even after decorative budget
exhaustion. The browser pressure fixture is not a Godot performance benchmark.

## Acceptance boundary

Open `previews/index.html` for all eight kits, forms, all 36 selectable reactions,
individual animation playback, movement, dense overlap, backgrounds, zoom,
reduced effects and grayscale/color-vision approximations. Four GIFs provide
portable moving Fire/Water/Steam samples. The PNG sheets are supplemental.

Source/atlas integrity and reference geometry are tested. Gameplay-scale candidate
previews are visually reviewable. Actual live rendering, real-camera diagonal
shimmer, cover occlusion, multiplayer, sustained performance, human charm and
user acceptance still require integration/playtesting. This pack grants none of
those statuses and changes no shared production acceptance record.
