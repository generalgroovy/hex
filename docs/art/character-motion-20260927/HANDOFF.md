# Full-body motion and proportion checkpoint

**Newer steering:** [Shared-head update](SHARED-HEAD-UPDATE.md) supersedes the
older head/body ratio and default preview paths below. All sizes target roughly
18px skulls; all30 layered candidates are rebuilt, and the next three characters
have192 authored action keys. Historical evidence below stays historical.

## User request and authority

Refine and unify proportions between Small/Middle/Large and expand all30 named
characters through relevant movement/action animations. User explicitly approved
separating approved full-body artwork into reusable layers and skeletal animation
with reviewed authored corrections. Work only in generalgroovy/hex; gameplay and
the p56-5dc9b5f3bdc0 playable checkpoint remain unchanged.

## Implemented foundation

| Layer | Current state |
| --- | --- |
| Anatomy calibration | All30 front skull-crown/core/sole estimates; first3 pilots also all8 directional joint annotations |
| Size contract | 58/63/68 anatomical pixels; volume/depth differences; do not measure crowns, horns, wings as body height |
| Editable source layers | All30 x8 source views,18 named body/appendage layers; every original opaque pixel conserved once before corrections |
| Shared motion | 24 active action candidates; 8640 shared samples across3 sizes; separate8x8 walk/sprint aim/travel matrix |
| Candidate renderer | Rigid layers with dynamic depth order and foot-target IK; experimental connected texture cage for comparison |
| Corrective artwork | S. Wayne authored sleeve/trouser hidden-joint underlays, original visible identity preserved |
| Native inspection | All30 load and28,800 action/heading/phase samples have finite transforms; three-size critical-action captures |

These counts are NOT30 finished animated playable characters. Logical pose
coverage, successful loading and source-pixel conservation do not prove attractive
skin deformation, natural gait, exact45-degree direction readability or performance.

## Visual gate: failed candidates must not enter production

Native review exposed costume fragments and open joints in rigid partitions.
The continuous cage keeps the garment connected but stretches tails, capes and
hands in larger actions. Neither generic method alone is acceptable for full-cast
production. Do not promote either on the strength of passing automated tests.

Required corrections: actual hidden limb surfaces; authored low slides and tucked
rolls; explicit cape/tail/wing masks; correct depth exchange; preserved planted
feet; aim/travel mapping for low and airborne casts; wall-contact side binding.
The connected mesh ignores separate corrective underlays and cannot solve limb
occlusion. It is a diagnostic comparison, not a completed animation solution.

## Sources and tools

- `art_batches/character_motion_v1/proportions.json`: anatomy targets.
- `calibration_overrides.json`: editable source-locked anatomical registrations.
- `layers.py`: lossless body-part ownership and mask overrides.
- `poses.py`: fixed-bone sampler; no world jump lift or gameplay edits.
- `motion_contract.json`: active state/clock/direction mapping; unavailable punch,
  kick, vault and superglide are excluded from required shipped-art coverage.
- `corrections.py`: S. Wayne authored underlays; generated sources and exact
  built-in image-generation prompts preserved in `reference/` and `prompts/`.
- `build.py`: contained versioned candidate generation.
- `motion_view.gd` / `preview.gd` / `preview.cmd`: isolated native workbench.

Candidate: `art_batches/character_motion_v1/output/motion-v2/manifest.json`.
Left/Right character; Up/Down action;1-8 aim;T travel;C cast;M compare mesh/layers;
Space pause;B background;Esc exit. This is not the game launcher.

## Validation ledger

Fresh combined Python suite: **56 tests passed** in40.899s before authored action
key assembly. Native v2 load: **30characters/28,800samplings**, empty stderr.
Native three-size capture: **21boards**, empty stderr after mesh RID-lifetime fix.
Visual acceptance: **FAILED for unrestricted generic skinning**, as described
above. Keep earlier failure logs/captures as diagnostic evidence.

### Authored-key checkpoint

Three pilots now have **192 genuine full-body action keyposes**, not finished
animation cycles: S. Wayne (Small), Oh Tipi (Middle), The Red Baron (Large).
Rows are slide entry/hold, roll anticipation/tuck, jumpsquat, jump rise, fall,
and landing. One fixed scale per identity preserves compression between poses.
Sources, exact image-generation prompts and editable registration recipes are
retained. All assembly uses nearest-neighbour sampling and binary alpha.

Oh Tipi's slide-hold source has overlapping rectangular bounds but disconnected
opaque silhouettes. Explicit component masks conserve all thresholded opaque
pixels with disjoint ownership; no character pixel is clipped or painted out.

Fresh final combined suite: **67 tests passed in 44.011s**. Native validation:
30 characters / 28,800 finite transform samples, log directory
`.godot/character-motion/20260927-130631-3ece6e12`. Native authored-key capture:
21 boards, empty stderr, log directory
`.godot/character-motion/20260927-130723-0ec7d4a4`.
After restricting authored keys to their actual action names, final native
validation passed again with empty stderr at
`.godot/character-motion/20260927-131213-b815a618`.
Review images: `art_batches/character_motion_v1/output/motion-v2/native-authored-key-review/`.

Lead visually inspected Oh Tipi slide, Red Baron jump, S. Wayne roll and the
complete Oh Tipi action board. Whole-body authored poses avoid the generic
joint-gap failure. **Visual acceptance remains partial**: some SE/E/NE headings
are too similar, some frontal poses are oblique, and transitions/full cycles
are absent. No human approval, production timing or performance claim.

The workbench uses these keys only for their corresponding basic actions;
it does not relabel them as completed wallrun, wavedash, flight or moving-cast
art. Other actions deliberately retain the visible procedural review warning.
The older `motion-v2/manifest.json` freezes its original build inputs, while
`docs/art/character-motion-20260927/final-inputs.json` records the final viewer,
builder and correction input hashes separately. The builder now includes
correction provenance for subsequent builds; no historical receipt was rewritten.

Readonly runtime identity check: **p56-5dc9b5f3bdc0 / 2,800 production records**
unchanged. No game export, live sprite replacement, commit, push, installer or
checkpoint-pointer update was performed.

## Bounded next acceptance sequence

1. Complete one Small full-body pilot with authored correction poses and actual
   gait/hand/foot/costume review, then Middle and Large; no new generic recolors.
2. Use anatomical measurements consistently across standing and action sources,
   keeping one scale per identity and appendage limits separate from core body.
3. Apply the accepted per-size and per-costume attachment rules to all30; track
   missing authored poses explicitly rather than displaying a static fallback.
4. Verify transitions, arbitrary walk/run aim/travel and moving cast overlays;
   add low/air cast projection and wall side, then complete performance review.
5. Only then integrate actor, selection, portrait and afterimage consumers and
   run production/gameplay/package acceptance. Keep current game available.
