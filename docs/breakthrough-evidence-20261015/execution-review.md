# Circuit execution and native UI review

Status: PASS within the scopes below; no required issue found. Independent readback by the technical reviewer on 2026-10-15. No engine or tests were run for this review.

## Focused execution

The terminal producer receipt at `.godot/iteration-20261015/breakthrough/runs/integration-a/tests.json` has SHA-256 `32235ec37743bc036eebed53f5d08be0c92677d71d3c341793e3c02c1a877470`.

The two ordered rows independently parsed from `.godot/windows-tests/4cf69aa6f6814f8ea635af995e0d087b/suite.log` are `signature-circuit: 488 assertions, 0 failures` and `signature-circuit-integration: 60 assertions, 0 failures`. Their sum is exactly 548 assertions and zero failures, matching the receipt and final selected-suite marker. The raw log SHA-256 is `55fcb93e48647443775d3b7621811def948e9095086aed3a05f9d115fe4d4e95`, matching the receipt; `suite.log.err` is zero bytes. Reported suite durations are 337 ms and 22,866 ms. The producer's 186,992 ms duration also includes its preflight work.

The recorded current-state file hashes to `91f38361e379069396225b8e2aa885a9643e2236f08db224dd3837a79ad29ae3`, matching the receipt. It reports a successful check with zero issues and candidate `p61-6618873387e2`, 3,450 records, runtime SHA-256 `6618873387e2b62744f54ab845a03031dea83c7baa1506a2cab8de4c2cce715d`. The receipt declares a dirty checkout on `codex/hex-breakthrough-20261015`, based at `aec900adeea74bc9c16bb5807ef8758d73696edb`. It records current-state/doctor/suite execution and restored caller APPDATA; it does not claim fresh import, asset inventory, standalone boot, Full, or package acceptance.

## What the integration assertions establish

Source readback of `tests/unit/test_signature_circuit_integration.gd` is SHA-256 `aea93c1f794caa51016ab7422563f1e25abccb953f3be23e9c753936df40c941`. The passing suite uses the actual trial fixture, controller, challenge session, finite world stepping and ordinary counterplay for its three positive legs. It requires actual rival `cast_started` events, victory, a valid real challenge reward, exactly one additional learned signature per leg, and an unchanged result after a duplicate observer callback (lines 34-67).

In legs 2 and 3 it presses the previous learned signature through the ordinary command path and requires both its local `cast_started` and its owned projectile/spray release event (lines 43-58). It checks temporary slot selection, fresh encounter health and unchanged normal session weave; completion cannot add a fourth rival. Range receives the final signature, and the real return transition restores the original weave while all three learned signatures survive (lines 69-81).

Network ownership, nonstandard tick rate, premature advance, invalid-rival admission, unqualified result, retry and external cancellation are covered. The later direct health edit is an explicitly separate negative control: it must not counterfeit an earned reward or advance the route (lines 82-94).

This is executed assertion evidence, not a raw per-tick combat trace. Persistence is intentionally disabled: the test verifies honest session-earned/unsaved behavior and weave restoration, not disk save/reopen, physical input, difficulty, pacing or player enjoyment. The 488 model/panel assertions are prepared state and UI controls, distinct from the 60 production integration assertions.

Reviewed production source hashes: model `acac15eb5206b3877a760092ccc7c08d36591453d88db5839018abfb339b6bdd`; controller `af19015e3af46e024b01872d57b8f11ab03a726186668a358fca651ef35c8226`; panel `d06f71ecd467d8f1e7e893fc0ca816791e849c5501982fc963f0fd596c29a0c2`. These are readback pins; the runtime identity above supplies the producer's runtime qualification boundary.

## Corrected native captures

`capture-c/capture.log` under `.godot/iteration-20261015/breakthrough/runs/` hashes to `64493910c41007aaad31d406f23e6cd34732d24f21cb7099078c62de8dedc685`, ends with the explicit eight-capture PASS marker, and has an empty stderr file. All eight PNG headers report 960 by 540 pixels. The helper SHA-256 is `bd4f8fd36d72aa0da46a84546c4a3312931e1bfa6f764bb052e2e4330c6dbd52`; it explicitly sets the root content canvas to 960 by 540 and uses a 480 by 270 logical surface at scale 2.

The following requested 200% images were visually inspected:

| Image | SHA-256 | Finding |
| --- | --- | --- |
| `circuit-2-scale-2.png` | `bc06493c82d7e73eba456dcc74b5231d3d85bab3ef3bec934b0730b1ff186c94` | Rival result, unsaved reward, learned-spell next action, ordinary next/leave, save retry and footer fit without overlap or clipping. |
| `circuit-3-scale-2.png` | `92b4741eaef8757546c9ac1be0d8666a6b9be5b60d08dbb6cae52a86604ed741` | Completion, total encounter time, reward, Range action, replay/leave and footer fit without overlap or clipping. |
| `map-scale-2.png` | `c54974f31f703eb44a58cafc4a16e90bd8e5d11289c34fb6452af7437e447da1` | Compact list, paging controls, details, Travel and Close occupy separate readable regions. |

These are actual native draws of prepared UI states. They do not establish a complete gameplay render, physical pointer/controller interaction, full localization coverage, performance, or persistent progression. No required visual correction was identified in the three inspected images. Full and subsequent delivery qualification remain separate root-owned gates.
