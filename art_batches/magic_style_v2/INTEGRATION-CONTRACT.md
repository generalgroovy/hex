# Integration contract — magic style v2

Status: mandatory future promotion gates; none of the runtime gates below are completed by this reference sheet.

## Authority boundary

The sheet is visual direction, not simulation data. Production artwork must derive placement and age from the existing authoritative state and events. It cannot change cast costs, damage, ownership, projectile paths, speed, hitboxes, reaction centers, radii, lengths, phases, lifetimes, collision, visibility or network outcomes. No new mechanics are implied by any flame tongue, shard, spark, ripple or star drawn here.

Maintain existing physics/network behavior and the 120 Hz authority boundary. Render cadence must not advance gameplay or animation lifetime. Use authoritative phase age, stable pivots and the applicable actual geometry; do not turn a large decorative burst into a larger hit area.

## Production requirements by role

| Role | Required production work before runtime use |
| --- | --- |
| Projectile | Author clean transparent cells, a stable core pivot, the required direction/frame coverage and trail limits. Align core position/path to actual projectile state; decorative tails cannot imply extra collision reach. |
| Contact burst | Author a short sequence driven only by a real contact event, with clear start/peak/decay, bounded life and scale. Do not use a reference burst as proof that a hit or reaction occurred. |
| Ground deposit | Reauthor a genuinely tileable top-down material cell with explicit padding and tested repeat seams. Clip/tile to the real active radius, capsule, beam path, cover and visibility masks as applicable; the square reference swatch is not a gameplay footprint. |

## Required acceptance gates

1. **Pixel source:** editable deterministic native-resolution cells; intentional color clusters and nearest-neighbor sampling. The generated board is not proof of a consistent pixel grid or exact palette membership.
2. **Transparency and extraction:** genuine alpha, no slate background, labels, grid lines, halos or baked square swatch boundaries. Preserve a clean silhouette and inspect against light and dark backgrounds.
3. **Palette and identity:** map to approved element ramps and verify distinguishability without color alone, especially Water/Wind/Ice and Fire/Charge/Light.
4. **Atlas contract:** explicit cell sizes, stable pivots, padding, row/frame/direction metadata and image/source hashes. Every region stays in bounds and cannot sample a neighbor.
5. **Phases and looping:** complete authored anticipation/active/decay sequences where applicable; deterministic selection from source state, no extra preparatory hit claim, no stale effects after expiry/interruption. Check loops at the boundary, not only interior frames.
6. **Ground seams:** repeat each production tile across a larger surface; compare opposing edges and verify no obvious square repetition or isolated-border artifact. The generated 2×2 arrangements do not satisfy this test.
7. **Geometry and visibility:** verify small and large authoritative extents, cover clipping, bent/reflected paths where applicable, offscreen/occluded states and harmless/inactive phases. Art cannot reveal hidden opponents or reactions.
8. **Budgets and reduced effects:** reuse current budgets and provide bounded lower-density variants. Preserve important contact/identity cues while reducing particles, not gameplay rules. Avoid screen-filling bloom.
9. **Evidence:** exact state/event/hash equivalence for presentation-only integration, focused import/atlas tests, real rendered normal/reduced cases, and representative multi-player cost measurements. A generated sheet or isolated atlas test is not gameplay acceptance.
10. **Human review:** assess the intended charming/readable style, impact readability, clutter and motion feel in actual play before promotion. No automatic approval from this concept board.

## Scope of this delivery

Only new files under `art_batches/magic_style_v2/` were added. There are no runtime imports, content registrations, altered magic manifests, source hashes repinned elsewhere or modifications to the existing pixel-magic pack. The images must not be described as shipped effects, finished animations, verified seamless textures or ready-to-use transparent sprites.
