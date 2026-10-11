# Element material readability refinement

Status: integrated and lead-validated in `p56-ae1c09164b5b`; see
[current checkpoint](../HEX-BUILDING-DIRECTORIES.md) for Full/native/export results,
failed timing target and remaining human/dense-scene acceptance. Delegate-owned
validation notes below describe the original handoff, not the final gate.

## Scope

The 24 px grid made the existing 9 px centered stamps appear roughly 7 screen
pixels wide at the fixed 75% camera. Steam combined a faint fill with warm-colored
highlights, making its vapor identity weaker than the existing saturated Water.

| Material | Presentation refinement |
|---|---|
| Water | Existing verified authored blue wave sheet and phase rows preserved |
| Earth | Larger loose-rock clusters; steady pose, not an implied solid pillar |
| Fire | Three restrained forked-flame silhouettes; ignition and cooling cues preserved |
| Air | Larger split green current motif, distinct from Water crests and Ice crystals |
| Ice | Enlarged cyan crystal; slow highlight cadence |
| Charge | Larger yellow broken bolt; faster localized highlight changes |
| Light | Warm pale diamond, with a measured highlight cadence |
| Dark | Violet inward crescent, with a slow cadence |
| Steam | Stronger pale vapor bed and three chunky vapor poses; separate warm ground vents indicate authoritative harm |
| Mud / Magma / Vortex | Existing pixel identities use the same larger clipped-cell adapter |

## Preserved boundaries

Each larger motif is clipped by the supplied authoritative six-vertex polygon.
No radius, cell selection, amount, cost, damage, lifetime or phase is changed.
There are no new moving fields, trails, orbit/range circles or per-cell particle
objects. Fire's formation/cooling and Steam's harmless/active/decaying state
still come from authority. Steam is an exposure hazard, **not smoke occlusion**;
its vapor remains in the ground presentation layer and does not hide actors.

Reduced Effects holds a stable representative pose and retains Steam's complete
coverage and harm contrast. Steam formation/decay lower the fill and motif
opacity; cosmetic heat never creates a harmful region.

## Bounded implementation

The shared texture cache remains capped at 192 entries. Padded material textures
are only 11 × 11 pixels, use three palette entries and transparent padding, and
are reused across cells. Animation has three bounded poses and element-specific
cadence; no per-cell emitters or unbounded texture growth were introduced. The
clip adapter does bounded six-vertex UV work per drawn occupied region; it does
not scan empty topology or create new coverage.

## Validation handoff

Run `hex-court-presenter`, `hex-water-pilot`, `hex-shared-presenter` and
`hex-handoff-presentation` with the existing authority regressions. Native review
must compare paid Water, Fire and Steam at normal gameplay zoom in both effects
modes, then inspect the eight ingredients and larger reaction fields. Confirm
vapor is recognizable, warm vents mean harm, and characters remain unobscured.
No engine, import, tests, profiles, captures or exports were run by this worker.
