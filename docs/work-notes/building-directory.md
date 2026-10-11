# Existing-building service directories
Status: directory model, cards and integration regression source complete; engine validation owned by lead (not run by delegated owner).

Lead completion: final Full 171-suite gate, 52 native captures and separate Windows
export passed; timing still fails the 120 Hz budget. See
[current checkpoint](../HEX-BUILDING-DIRECTORIES.md) for exact evidence and limits.

Standalone menu huts are removed from the design. Existing campus buildings contain related services; a doorway opens a directory and only an explicit card selection asks the existing dispatcher to execute one existing action.

| Existing building | Group | Door anchor | Services |
| --- | --- | --- | --- |
| Routekeeper Lodge, 101 | training | 328, 328 | Movement, Controls |
| Wellspring Academy, 104 | academy | 1536, 392 | Champions, Spell Loom |
| Farflow Hall, 109 (existing Workshop Store) | farflow | 1984, 344 | Host, Join, Rules, Ready, Company, Parting |
| Verdant Rest Pavilion, 103 | practice | 360, 1288 | Impact practice, Restore |

The lead validates these anchors against actual building collision, practice lanes and gathers. No menu opening, navigation or hover starts a lobby, changes rules, resets practice, readies players or dismisses anyone. Parting still uses the existing second-confirmation rule; it is not merged into Company selection.

## Integration contract

`WellspringServiceBuildings` now owns group/card metadata, responsive card geometry, short detail delay and an optional small hex doorway marker. It contains **no hut renderer or hut footprint**. `draw_service(...)` is retained only as a marker-compatible signature; draw it once per group rather than once for every child command. Actual buildings already have their own art and collision.

```gdscript
directory.open_group(group_id, campus_layout.data["stations"], preferred_station_id, availability)
directory.update(delta, pointer_in_ui_coordinates, ui_viewport_size)
var requested_station_id := directory.handle_event(event, pointer_in_ui_coordinates, ui_viewport_size)
directory.draw(canvas, ui_viewport_size)
```

`open_group` returns false for unknown/empty groups or duplicate commands. `selected_station_id()` exposes current focus. `handle_event` returns either one explicit existing station ID or an empty string; it does not dispatch. `close()` releases modal state. `availability` optionally maps station ID to `{enabled: bool, reason: String}`. It is a UI hint, not authorization; the existing host/local policy must always recheck the request.

Live caller-owned presentation fields: refresh `availability_by_station` from current host/round policy; set `card_overrides_by_station = {station_id: {title: String, hint: String}}` for contextual Host/Ready labels; set `status_text` to a short current lobby/rule/confirmation status. `group_title()` and `group_hint()` return stable group copy. Changes do not mutate canonical station definitions. Direct actions may keep the directory open and selection unchanged for confirmation; child-modal actions close it first, then the caller may reopen it with the previous preferred child ID.

Lead hooks:

1. On Interact at an existing building door, open its group directory without executing a child action.
2. While open, block gameplay inputs, route modal input first, call update/draw in scaled UI coordinates, and keep the cursor visible.
3. After a non-empty request, preserve that selected child ID, recheck current proximity/permissions, close the directory before opening any child modal, and dispatch through the existing action path.
4. Shared door coordinates mean alphabetical `nearest_station_id()` alone cannot authorize the selected sibling action. Authorize the actual requested station within its canonical distance/building group; do not forge focus or skip permissions. Maintain selected-child focus until the dispatch boundary.
5. Close safely on Back, loss of door eligibility, session/map change or replacement modal. Apply the normal gameplay-input guard to prevent the menu-opening key leaking into combat.

## Input and layout

- Mouse hover reveals details after280ms; click selects an action. Close button is explicit.
- Arrows or WASD navigate; Tab/Shift-Tab step; Enter/Space or the currently bound Interact action activates; Escape backs out. Reserved UI navigation/back take priority over conflicting gameplay bindings.
- Controller D-pad or deliberate left-stick flick navigates; A activates, B/Back closes. Stick hysteresis prevents repeat spam; neutral noise never takes focus from mouse.
- Four supported group sizes are2/2/6/2. Farflow renders a3x2 grid at supported640x480 and larger viewports. There are no extra paragraphs on cards: short title/hint, full existing guidance in the detail area.
- Layout is cached by viewport and card count; input and rendering share exact rectangles. No simulation state or per-world-object work is introduced.

## Validation

New `test_wellspring_service_directory.gd` covers non-mutating opening, canonical metadata preservation, explicit selection, separate destructive action, keyboard/controller/stick input, mouse timing/hit geometry, disabled options, viewport bounds and invalid content. Existing service-card tests now require four actual campus buildings rather than fabricated facade footprints. No engine/import/export was run by the delegated implementation owner; the lead serializes validation.

`test_building_directory_integration.gd` additionally runs production bootstrap focus, directory input, dispatch checks, actual Gallery/Spell Loom/Controls/Movement child panels, selected-child parent return and gameplay command quarantine against current campus data. It covers keyboard, scaled mouse coordinates, controller accept, mapped Interact, wrong-group/stale-distance rejection, per-action radii, front-door eligibility, disabled host-only services and confirmation during a round-phase transition before the next frame update. Network and mutating session endpoints are explicit spies: this suite proves routing and modal boundaries, **not** lobby/network acceptance or destructive confirmation behavior. It starts no socket, changes no saved preferences and performs no simulation step.
