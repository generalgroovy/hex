# Illustrated Wellspring and three-body refinement

Status: **integrated source candidate; human visual acceptance pending**. User revision after
the c7c36e2 map/movement checkpoint supersedes the earlier visual approval.
No chemistry or new mechanics until this presentation revision is verified.

| Slice | Outcome | Acceptance |
|---|---|---|
| R1 | Reusable stone, moss, grass, water, roof and timber atlas; coherent planted campus | Live source/overview capture, quiet projectile lanes, no flat schematic district panels |
| R2 | Consistent elevated three-quarter camera grammar | Screen-cardinal floors/input, visible roof/shoulder tops, predictable roof and canopy cutaways; 50/75/100% preserved |
| R3 | Small S. Wayne, middle Oh Tipi, large Red Baron refined in that order | Eight directions for all current pose families; alternating contacts; mass preserved on slide/roll; 58/68/76 upright envelopes and shared feet pivot |
| R4 | Integrated world/character acceptance | Captures at 720p/1080p, reduced effects and pattern pressure; full source checks and host/join; human charm acceptance remains explicit |

Art direction: warm staggered flagstones, dark timber and indigo slate, planted
edges, layered low facades, deep teal water and restrained brass. The visual
camera is approximately 55 degrees above horizontal; this is an art projection,
not a perspective transform applied to gameplay coordinates. Ground navigation,
aim, collisions, resource economy, movement timing and protocol remain unchanged.

Original generated source boards are editable/reproducible inputs under
`reference/art/wellspring_v3`; runtime atlases are packed by
`scripts/build_illustrated_visuals.gd`. No bitmap controls collision or chemistry.
The new source contains eight directional pose families per champion; hit/recovery
uses a bounded neutral-body recoil and sprint's second contact reuses the
opposite walking contact. These are explicit reusable aliases, not claims of
individually drawn frames for every semantic action. Effects/shadows stay separate.

The map floor is compiled once per layout into one cached texture; vegetation
and architecture use bounded shared atlases. No per-frame terrain generation.
Saved concepts remain references, not a giant noninteractive background image.

## Current implementation and evidence

| Area | Implemented | Honest limit |
|---|---|---|
| Map | 16 tiled surfaces, 16 cutout props, cached terrain, planted edges, low textured facades and slate roofs | The six-area collision layout is unchanged; not an exact reproduction of the painted island concept |
| Camera | Shared 55-degree art grammar; screen-cardinal ground, 62px maximum facade, local roof/canopy fading, existing zoom steps | This is original 2D artwork, not a rotatable 3D camera |
| Bodies | 240 runtime cells, three sizes, eight directions, ten pose rows, shared feet baseline, two locomotion contacts, lower slide/roll poses | Eight source pose families; explicit hit and sprint-B reuse; no claim of fully authored multi-frame animation for every semantic action |
| Integrity | 67 suites / 19,717 assertions; clean import and 120 Hz boot; local Farflow journey passes | Human control/feel review, real-time GPU frame budget and final installer distribution remain separate gates |

Inspected actual game captures: `.godot/visual-captures/illustrated-v3-court`
(720p, 75%) and `illustrated-v3-overview` (1080p, 50%). Earlier captures exposed
opaque prop mattes and duplicate labels; those revisions were rejected and
corrected. Follow-up capture evidence is recorded in `.agent/memory.md`.

Final camera/overview evidence is committed under
`docs/evidence/illustrated-wellspring-v1`. The final near-building image shows
gradual roof fading without the old schematic replacement rectangle. Ground
roll capture uses the actual Evade command; an earlier unsupported capture
argument was rejected as roll evidence and the harness was corrected/tested.

The asset pipeline stores original generated boards and prompt specifications
under `reference/art/wellspring_v3`, normalizes source grid/alpha/body isolation,
and pins decoded imported hashes. Terrain setup is measured separately from
steady-state rendering. A movie captured at 120 FPS is not proof of real-time
120 FPS performance on all hardware.

Rollback baseline: c7c36e2. Existing installer is older; do not distribute it as
proof of this source revision.
