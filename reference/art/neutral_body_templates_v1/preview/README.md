# Neutral body reference viewer

This independent Godot project previews source body sheets. It does **not** load or modify the main game, current champions, player preferences, saves, or networking. The `120 FPS` setting is a rendering cap, not a performance acceptance claim.

## Open

Open this folder's `project.godot` with Godot 4.7.1 and press **Run**, or launch the pinned engine with `--path` pointing to this `preview` directory. The viewer reads `../runtime/small.png`, `middle.png`, and `large.png` by absolute filesystem path; no copying or Godot resource import is needed for those sheets. Missing or invalid sheets are labeled visibly; **Reload sheets** retries after export from the source workflow.

| Control | Purpose |
|---|---|
| Action / direction | Pick the exact reference pose and direction |
| 1x / 2x / 3x | Nearest-neighbor enlargement, identical scale for all three sizes |
| Compare sizes | Three sizes sharing the same ground baseline and `(48,84)` pivot |
| 8-direction grid | All directions for every size; scroll at enlarged scales |
| Pause / frame arrows | Inspect the supplied contact poses individually |
| Preview poses/sec | Viewer-only cadence for two-pose walk/sprint; not gameplay tuning |
| Export all source rows | Render all 240 source cells to a new PNG under `preview/exports/` |

Keyboard: **Space** pause/play, **Left/Right** step, **1/2/3** scale, **F5** reload. Dropdowns retain normal keyboard focus behavior.

## Exact source contract

| Property | Contract |
|---|---|
| Each PNG | 768 x 960, RGBA8 |
| Cell / pivot | 96 x 96 / `(48,84)`; no trimming, resampling, or inferred pivots |
| Rows | grounded, jump, cast, hit, walk, sprint, slide, roll, walk_b, sprint_b |
| Columns | S, SE, E, NE, N, NW, W, SW |
| Two-frame sequences | Walk uses `walk`/`walk_b`; sprint uses `sprint`/`sprint_b` |
| All other actions | One static source pose, explicitly labeled in the viewer |
| Reference aliases | Float/air dodge/wall kick use jump; wallrun/wave dash use slide; defend/interact/taunt use grounded (gallery poses only); defeated uses hit |

Aliases are convenient inspection labels, **not proof of dedicated animations or gameplay support**. The viewer adds no jump translation, blending, anatomy edits, magic, or fake in-between frames. Checkerboard cells reveal transparent versus opaque backgrounds.

## Verification and unattended export

Run the engine against this folder with `--headless --script res://test_viewer.gd` for model/layout tests. Add `-- --check` to a normal or headless viewer launch to validate all three actual sheets and exit (`0` loaded, `2` missing/invalid). Add `-- --export-contact-sheet` to a graphics-capable launch to export once and exit; export refuses missing sheets and never overwrites a source file.
