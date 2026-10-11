# Fixed framing and ground-facing marker

Status: integrated and lead-validated in `p56-168a6c987ad5`; see
[checkpoint evidence](../HEX-RETRO-REFINEMENT.md). Human feel remains pending.
The module handoff details below record the original delegation boundary.

## Contract

`PlayerCameraRig` is presentation-only, with no simulation writes, raycasts, per-frame dictionaries, dynamic zoom, trails or shake. Gameplay zoom is **75%**: at1280×720 the visible ground spans approximately1707×960 world pixels; current58/63/68-pixel bodies remain43.5/47.25/51pixels tall and24-pixel hexes18pixels wide. This preserves existing legibility while bounded framing exposes room ahead. It is a candidate for visual/feel acceptance, not a performance claim.

| Framing | Behavior |
|---|---|
| Player following | Use interpolated feet directly, without stacking a second position-lag filter. |
| Look-ahead | Up to72world pixels from raw screen-space pointer intent or controller aim. |
| Velocity lead |0.16seconds ahead, limited to72world pixels; combined lead capped112pixels. |
| Smoothing | Exact exponential offset response,120ms half-life; held intent is invariant to render sample rate. |
| Reduced motion | Centered feet following, no anticipatory pan. |
| Modal / unfocused | Freeze; rebase immediately on resume. |
| Teleport / focus switch | Snap above192pixels per sample or via explicit `force_snap`; never pan through intervening rooms. |
| Edge / small arena | Clamp to bounds; center any arena smaller than the viewport. |
| Arrow | One unanimated three-vertex triangle close to ground shadow; actual continuous aim, not movement/slide-facing. |

## Lead integration (shared files intentionally untouched)

1. Preload/instantiate `src/presentation/player_camera_rig.gd` in bootstrap; register `tests/unit/test_player_camera_rig.gd` in the unit-suite registry. Only the integration owner runs Godot imports/tests/captures/exports.
2. Freeze zoom to75% for ordinary gameplay. Preserve historical preference values on disk if desired, but do not expose a nonfunctional cycling control. Existing `--camera-zoom` capture tooling needs an explicit diagnostic-only policy, rather than accidentally overriding gameplay. Existing tests asserting F11 cycles zoom and50/100percent saved values must be reviewed separately, not silently deleted.
3. Advance the rig exactly once per rendered frame at the frame boundary, using interpolated focus feet, velocity in pixels/second, viewport size and world bounds. Bootstrap currently calls `_camera_origin` from `_draw`, physics-command sampling and effect culling; all must become read-only queries of one stored frame origin. Do not advance the rig in those queries.
4. Mouse framing intent comes from `mouse_look_intent(mouse_screen_position, viewport, reserved_ui_top)`; controller framing uses raw stick intent or the accepted controller aim, never mouse-derived world aim. Actual spell aim uses `screen_to_world(pointer, frozen_origin)` so screen and world aim invert the same snapped transform. Do not feed this world aim back into camera framing.
5. Frame consistency matters: use one origin for rendering and input associated with that frame. After simulation catch-up, do not recalculate input aim repeatedly with a future camera origin. Focus/spectator target, scene and fast-travel changes explicitly `clear()` or `force_snap`; pass modal/focus loss as `suspended` and existing reduced-motion accessibility as `reduced_motion`.
6. Add a persisted boolean preference `show_aim_indicator`, default true, a working accessibility/controls toggle and migration tests. Do not reuse an unrelated preference. Bootstrap can draw `ground_arrow(shadow_center, Vector2(state.aim_x,state.aim_y), preference)` with a dark outline and pale-gold fill at the ground anchor, not elevated sprite anchor. Keep it visible after the local-observer redraw/POV overlay, without exposing other actors; hide for absent actor/spectator as appropriate. Arrow placement above the body/POV requires native visual review in all8aim directions and jump/slide poses.
7. Maintain existing pixel-snapped rendering. Camera position remains floating-point internally; no rounding fed back into simulation, motion history or the smooth framing offset.

## Acceptance the lead must execute

New unit suite covers fixed zoom, bounds/translated small arenas, look dead zone and cap, backwards aiming while running, exact held-intent30/60/120/240Hz parity, immediate feet following, modal/resume/teleport/reduced-motion behavior, invalid positions, snapped input inverse and8direction arrows/toggle. No engine execution was performed by this delegate. Native review must cover edges, resize, fast travel, remote spectator switch, menu open/close, stationary pointer with sprint/reversals, all8arrow headings and reduced motion. The pure module alone does not deliver a working preference or camera integration.
