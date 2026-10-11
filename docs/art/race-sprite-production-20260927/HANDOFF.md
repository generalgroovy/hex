# Race sprite factory checkpoint — September 27, 2026

## Decision

The reusable sprite factory and Seakin candidate are **staged for inspection**.
They do not replace game characters. The playable movement build remains
`p56-5dc9b5f3bdc0`; a fresh source identity check passed all 2,800 canonical records.
No new game export, installer, commit, push or selected-checkpoint promotion.

## What is being delivered

| Item | Status / boundary |
| --- | --- |
| Delegation prompt | `.agent/RACE-SPRITE-PRODUCTION.md`; exclusive inventory, factory and viewer ownership |
| Scope inventory | 21 races, 3 sizes, 3 generic appearance presentations = 189 families; 30 named identities remain separate |
| Source art | Hash-preserved generated Seakin heads and sleeveless costume parts, based on the user's `styleref1.png` |
| Factory | Deterministic offline part assembly on the existing motion rig; no new runtime paper-doll system |
| Seakin pilot | Nine candidate families, each with 80 base cells + 512 walk + 512 sprint logical frames |
| Art lab | Native Godot viewer; independent movement/aim, one family resident at a time; isolated settings and owned-process cleanup |
| Live game | Existing three shared size bodies and gameplay remain unchanged |

The 189-family inventory is a **production backlog**, not a completion counter.
Generic appearance options do not assign genders to named characters.

## Reproducible inputs and outputs

- Factory: `art_batches/race_sprite_factory_v1/factory.py`.
- Current candidate recipe: `art_batches/race_sprite_factory_v1/seakin-v3.recipe.json`.
- Original and edited generated sources: `art_batches/race_sprite_factory_v1/reference/`.
- Final generation/edit prompts: adjacent `seakin-*-prompt.md` files.
- Durable candidate output: `art_batches/race_sprite_factory_v1/output/seakin-v3/`.
- Inventory and style contract: this directory's `inventory.json` and `contract.md`.

Use the built-in image generation tool for art changes; deterministic crop,
explicit alpha normalization, nearest-neighbour transforms and assembly preserve
source provenance. No background-color keying, invented raster headings or
per-frame body-size fitting. Reference and output folders are excluded from
automatic Godot imports; the lab reads PNG data explicitly.

## Review findings and remaining work

The first generated costume had long lower hems. The v2 sample exposed 57/144
slide/roll frames that would cross the fixed ground boundary; it deliberately
used a recorded old-body fallback instead of clipping. The corrected source ends
at the belt. V3's 216 standing/slide/roll samples have **zero such fallbacks**.
Keep those prior source/sample receipts as useful failure evidence.

The current candidate is **not a finished Oh Tipi skin**:

| Visual issue | Next bounded correction |
| --- | --- |
| Generic mechanical arms, legs and boots | Author reusable race limb/foot parts, preserving existing joint and foot-contact geometry |
| Missing Seakin tail / body fins | Add independently attached near/far anatomy layers with explicit occlusion and bounds tests |
| Rear-quarter faces too similar to side views | Correct authored 45-degree head views, then inspect all eight facings at native size |
| Reference's compact charm not fully matched | Review head/body material and silhouette together before expanding to another race |
| Roll/slide pose readability | Inspect actual transitions, not merely individual static pose cells |
| Named identity differentiation | Add named costume/face details only after the generic family is accepted |

A full logical grid is not evidence of eight perfectly readable yaw angles or
dedicated animation clips for every gameplay semantic. Jumpsquat, flight,
wallrun, moving casts and interruptions still require integrated motion review.
No gameplay balance, stats, hurtboxes or wall clearance changed in this slice.

## Inspect locally

Run `art_batches/race_sprite_factory_v1/preview.cmd` from this checkout.
Controls: **1/2/3** size; **N/M/F** neutral/masculine/feminine presentation;
**Tab** action; **WASD** travel; **mouse** aim; **Space** pause;
**Right Arrow** step phase; **Esc** close. This is an art lab, not a gameplay mode.

For the unchanged playable game, run
`exports/hex-movement-c1-20260926/windows/PLAY-HEX.cmd`.

## Evidence ledger

| Fresh check | Result | Evidence |
| --- | --- | --- |
| Offline factory unit suite | PASS, 17 tests | `tests/art/test_race_sprite_factory.py`; rerun September27 |
| Full v3 geometry preflight | PASS, 9,936 frames, zero fallbacks | Candidate `review-samples/preflight-receipt.json` |
| Independent candidate integrity | PASS, nine families | Candidate `receipt.json` |
| Native viewer contract | PASS, 1,080 checks | `evidence/viewer-contract.log` |
| Native v3 decoding and frame hashes | PASS, 9,936 logical records | `evidence/v3-native-validation.log` |
| Native rendered sample boards | PASS, three boards | `evidence/v3-native-capture.log`; candidate `native-captures-v2/` |
| Lead visual sample review | REVIEWED / HELD, not accepted | 80 base + 64 walk + 64 sprint cells of Middle/Neutral; gait phase2 only |
| Production source identity | PASS, unchanged p56-5dc9b5f3bdc0 / 2,800 records | `scripts/runtime-build-identity.ps1 -Mode Check`, September27 |

All three successful native-run stderr files are empty and copied beside these
logs. The first native capture failed because Godot cannot hide its main Window
using `root.hide()`; `evidence/capture-v1-failed.err` is preserved. Removing that
unsupported call fixed capture. The interactive mouse-aim origin was also fixed
to match the sprite anchor and covered by tests. Earlier parser and JSON
numeric-type failures were fixed and retained in `.godot/race-sprite-preview/`.

Rendered review found no opaque matte or cropped body in the sampled boards.
It confirmed the visual holds above: uniform mechanical legs/gloves, compressed
roll silhouettes and insufficiently distinct rear-quarter heads. Native capture
validates rendering, not live gameplay integration or all-phase animation feel.

Each family atlas decodes to 38.8125 MiB of RGBA pixels; the lab releases the
previous family before loading the next. This is an asset-size calculation, not
a measured RAM/VRAM performance result. Do not load all 189 families eagerly.

No human visual approval, live-game sprite integration, physical multiplayer,
rendered gameplay performance or full all-race completion is established here.
