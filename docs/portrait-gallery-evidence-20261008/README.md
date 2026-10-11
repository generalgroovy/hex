# Detailed champion portraits and Gallery inspection

Status: locally verified source checkpoint `p57-30b90507f932`, October 8, 2026.
Ready for human art/UI playtest; no package promotion.

## Player benefit

Every live champion has a detailed individual portrait. Open the Academy's
Champion Gallery, select a champion, and click the portrait or press **P** /
controller **Start**. The enlarged view is read-only; **Esc / B / Back** returns
to the roster before closing the Gallery. **Attune** remains a separate action.
The eight-heading body preview and existing sprite-based cards/HUD remain intact.

Browse all originals without launching the game in the
[offline portrait gallery](../../reference/art/portraits_20261008/index.html).
Search by current name, race or size; click an image to inspect its full source.

## Artwork and runtime boundary

28 new portraits and two previously delivered close-ups cover the exact live
30-character catalog. All are 1254px square original PNGs generated with the
built-in image tool, individually reviewed by their art worker. Current sprite
identity and cast overrides take priority over historical poster labels.
Red Baron, Spai Si, Ba Djoh and Jan Wicked received framing corrections; original
variants remain preserved. Root sampled the identity-sensitive outputs again.
Human style acceptance remains open; these interpret tiny-sprite details and do
not establish 30 complete authored animation sets.

| Resource | Policy |
|---|---|
| Full sources | `reference/art/portraits_20261008`; excluded from engine import/export |
| Runtime copies | `assets/portraits/champions_v1`; unchanged source bytes, ordinary Godot 512px texture imports |
| Loading | On selected-character request, never eagerly decode the full roster at startup |
| Residency | Two-texture LRU; release cached textures when Gallery closes; no runtime image copies or hashing |
| Failure | Missing optional art uses the existing sprite crop; malformed imported texture may still emit engine diagnostics |
| Gameplay | No changes to movement, combat, balance, body sprites, hitboxes, networking or delivery selection |

Two 512px RGBA textures contain 2 MiB of pixel payload; this is not total process,
renderer, import-cache, transient-load memory or frame-time measurement. Packaging
and startup size are not certified by a source import. The full PNG originals
total 71,548,943 bytes; reference and runtime trees intentionally preserve both
the original art provenance and conventional engine source/import separation.

## Evidence ledger

| Gate | Result |
|---|---|
| Offline delivery audit | [Passed](asset-audit.json): 30 exact catalog identities, original/runtime PNG hash equality, dimensions, bounded importer policy, export metadata |
| Offline HTML inventory | 30 exact catalog entries and valid source image paths; no network dependencies |
| Import | v1 original imports and v2 bounded 512px imports passed with empty stderr |
| Focused v1 | FAILED: 7 new-suite assertions cascaded after the fixture clicked the visible Back button while trying to probe a covered old page target; existing Gallery suites passed |
| Fixture correction | Covered Previous-page/card/wheel probes replace the mistaken point; immediate expanded-state assertion added; all original assertions retained; no production change |
| Focused v2 | [Passed](focused-v2.json): 3 suites / 2,619 assertions, zero failures and empty stderr |
| Native presentation | [Fixture passed](native/receipt.json): all 30 selected resources are 512px, two-entry cache bound and eight-heading body seam preserved; 18 actual frames, four representative characters at two viewports plus two explicitly synthetic missing-library fallbacks; world/equipped/request state unchanged |
| Frozen Full | [Passed](full-v1.json): 222 suites / 4,166,699 assertions, import, source identity and configured 120Hz boot; zero failures or stderr; logs retained in `full-v1/` |
| Final source | [p57-30b90507f932](runtime-identity.json), 3,176 canonical production records; SHA256 `30b90507f932d595b030f3d7ab347537120234b1aec687ec8bfc1beb29f0d2bc`; protocol57 / snapshot23. Candidate manifest remains unpromoted; this report records local source acceptance. |
| Static guards | Scope guard plus 105 self-test assertions; historical README delivery summary plus 45 source-only assertions; scoped whitespace check with CRLF permitted. Portrait audit also passed Windows PowerShell5.1. |

[Independent native review](visual-review.json) checked all 18 files against
capture hashes: 8 passed, 10 limited, none failed. No sampled identity mismatch
or unintended panel overlap/clipping was found. The nine 960x540 images preserve
layout but have coarse/tiny secondary text; the 1280x720 synthetic fallback is
also limited evidence. Prefer 1280x720 for playtesting. These are screenshot
observations, not physical-input or human accessibility acceptance.

Actual generation inputs/prompts/provenance:
[batch A](../../reference/art/portraits_20261008/batch-a-prompts.json),
[batch B](../../reference/art/portraits_20261008/batch-b-prompts.json),
[reused pair](../../reference/art/portraits_20261008/reused-portraits.json),
[reused pair prompts](../../reference/art/portraits_20261008/reused-portrait-prompts.md).
These art-worker receipts retain their original pre-integration status.

The preceding verified source is
[combat choices p57-387ff8d5b670](../combat-choices-evidence-20261007/README.md).
Existing installers/portables and `docs/current-checkpoint.json` are unchanged.
Dense sustained 120Hz remains a historical failed timing gate; physical
different-home networking, listening and human gameplay acceptance remain open.

## Quick playtest

1. Run `scripts/run.cmd --pixel-cast` from the repository root.
2. Open Academy / Champion Gallery; compare a Small, Middle and Large portrait
   with the body preview and actual source-derived statistics.
3. Enlarge with mouse/P/Start; change facing with **[ / ]** or controller shoulders;
   return with Esc/B/Back, then switch character. Inspection must not equip it.
4. Use explicit Attune, close the Gallery, and play. Portraits must not replace
   body animation/HUD art or change movement, aiming and casting.

Stop at this art/UI checkpoint for feedback before extending another subsystem.
