# Wellspring service doors and compact cards
Status: helper and twelve solid worldbone facades integrated and lead-validated
in `p56-168a6c987ad5`; [checkpoint evidence](../HEX-RETRO-REFINEMENT.md).
Grouped directories and human usability acceptance remain open. Original handoff follows.

## Contract

Replace station sign/lectern visuals with small service-building facades. The original station ID, interaction radius, command, authority and confirmation behavior remain canonical. Twelve `service_facade` buildings (IDs 201–212, `service_station` links) now register the helper's footprint as solid worldbone: buildings must never be walk-through illustrations. Six access points move locally to keep all existing ordinary routes at their promised width. Existing host/join/ready/parting actions are not automatically activated or merged.

| View group | Commands retained | Compact titles |
| --- | --- | --- |
| Academy | movement_guide, configure_controls, champion_switch, configure_spells | Movement, Controls, Champions, Spell Loom |
| Farflow | host_session, join_session, session_charter, session_hearth | Host, Join, Rules, Ready |
| Company | session_ledger, session_parting | Company, Parting |
| Practice | training_reset, impact_practice | Restore, Impact |

`WellspringServiceBuildings.footprint(station)` gives ground colliders: usually 72 x 20 px with its front edge 20 px above the interaction anchor; the ready/hearth door uses 48 x 14 px to preserve all eight gather positions. Roof depth is presentation-only, not a second collision surface. A six-sided threshold, compact static doorway and emblem replace range circles and signs. Service facades are not wallrun practice surfaces.

| Locally relocated service | New access point | Reason |
| --- | --- | --- |
| Movement | 1248, 640 | Preserve the west Commons loop's full width |
| Host | 1248, 1008 | Preserve the west Commons loop's full width |
| Impact | 704, 1008 | Keep the garden ordinary loop free |
| Company | 2112, 1056 | Leave the main processional and east loop open |
| Parting | 2112, 1248 | Leave the east loop open |
| Restore | 1808, 1280 | Stay outside the chemistry pad and south return |

No route, connection, target, gather anchor, practice wall, floor-guide descriptor or map boundary changed. Read-only four-pixel route sampling found no new facade/full-width ordinary-route conflicts; canonical Godot validation remains the lead's gate. Historical map fingerprint tests explicitly restore only these six coordinates and two public copy changes after excluding the new facades. A separate current-state test requires all twelve solid matching footprints and clear front approaches.

## Integration corrections

The first full gate identified the old Momentum Chime's fixed northward launch hitting its own new facade. `SanctumStationModel.impact_launch_direction` now chooses the outward cardinal direction from actual canonical facade bounds and the admitted player's fixed-point position. The front threshold launches south; side/rear approaches launch away from the building. The 540,000 impulse, 320 ms duration, recovery decision, steering and stamina cost are unchanged. Integration coverage retains the greater-than-100 px travel requirement and exercises every eligible side, instead of weakening the launch-lane assertion.

The retained architecture-kit contract now includes a reusable `service_facade` profile with six-sided roof, existing stone/indigo palette and the same live service renderer. It validates each association and exact solid/art footprint match. No new bitmap assets, generic-tower fallback or engine-owned geometry are introduced.

## Integration API

- `definition_for(station)`: compact title, hint, glyph, color and grouping; unknown commands fail closed.
- `draw_service(canvas, station, active, show_title, title_alpha)`: hex-roof service facade, still doorway and threshold; uses no tick, trails, orbiting elements or command execution.
- `commands_for_group(group, stations)`: copies the existing action metadata without changing authority or location; use only through existing validated dispatch.
- `card_rectangles(area, count)`, `hit_card(point, rectangles)`, `draw_card(...)`: shared responsive render/hit geometry; returns no cards when paging is necessary instead of clipping.
- Instance `update_focus(id, delta, immediate=false)` waits 280 ms for hover detail; keyboard/controller deliberate focus may reveal immediately. `clear_focus()` closes stale detail on menu change.
- `WellspringInteractionPresenter.station_rect(...)` is the single shared render/hover rectangle. Collapsed prompts are one 40 px icon/title/key row instead of two-line cards; expanded guidance keeps its existing validated budget and safe-area behavior.

Do not merge destructive Parting into Company activation, or combine Join/Host into one implicit networking action. Group directories can eventually share a building, but that requires explicit active selection plus existing authority and proximity checks, not dispatching every command in a group.

## Validation ownership

New `test_wellspring_service_buildings.gd` covers command coverage, unchanged authority, threshold accessibility, hearth gather clearance, card bounds, hit geometry, short delay and fail-closed unknown actions. Existing interaction-presenter tests additionally cover compact height, actor avoidance and expanded line limits. Campus tests now require 35 solid structures and verify the twelve service associations, no overlapping footprints, front approaches and exact relocations. No engine/import/test/export was run by this delegated agent; the lead serializes those. Scope did not modify bootstrap, map renderer, runtime identity or shared suite registration.
