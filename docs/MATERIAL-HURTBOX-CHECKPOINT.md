# Material footprints and body hurtboxes

Status: verified local source checkpoint, 2026-09-08; human visual/balance acceptance remains open.

The user's final clarification controls: body sizes retain different core stats
and different hurtboxes, but identical wall clearance. Earlier shared-hurtbox
wording is superseded.

| Body | Art guide | Combat radius | Wall clearance |
| --- | ---: | ---: | ---: |
| Small | 58 px | 15 px | 18 px |
| Middle | 68 px | 18 px | 18 px |
| Large | 76 px | 21 px | 18 px |

Validated body profiles set the combat radius on champion application. The
existing serialized PlayerState.radius now explicitly owns combat, not physical
navigation. Movement, wallrun contact, spawns, arena bounds, chemistry push,
projectile origins and body/shadow anchors use the shared clearance. Existing
core stats, Float limits, movement timing and spell costs are unchanged.
Hurtboxes never resize with animation. Protocol47/snapshot18 remain unchanged;
content compatibility hashes change, so friends must use the same source build.

## Material-defined area

No separate chemistry perimeter lines/markers, Field range circles or Spray
cone outlines. Existing native pixel frames repeat inside authoritative clipped
shapes; optional-budget exhaustion does not remove the essential footprint.
Formation, expiry, obstacle cuts and Steam concealment windows stay authoritative.
Earth matter does not become walking collision merely because it resembles rock.
Geometry is cached in64 entries, with native-cell spacing capped at32px; longest
current linked-shape coverage is regression-tested. This is not a120fps benchmark.

![Live normal material footprint fixture](evidence/material-hurtbox-v1/materials-normal.png)

[Reduced Field/Spray/Steam capture](evidence/material-hurtbox-v1/materials-reduced.png).
These are actual renderer fixtures, not a live remote concealment test. Regular
tile repetition is still visible; Field material remains faint in reduced mode.
Those are open visual-acceptance issues, not finished art polish.

## Verification and handoff

Full:87 suites /419,354 assertions, zero failures and stderr, strict import and
actual120Hz boot;84.792seconds. [Receipt](evidence/material-hurtbox-v1/full-receipt.json).
Hurtbox focused:8 suites /55,868 assertions; material focused:3 suites /70,868.
All27 characters,22 serialized modes and8 facings cover exact hit tangents and
common wall contact; real damage admission, eight cast origins, canonical hash,
snapshot round-trip and prediction-copy checks pass. Legacy enum coverage does
not activate retired moves. Source kernel pin was renewed for the single shared
clearance displacement change; magic atlas pixels were not regenerated.

No new complete character-style page exists: five individual runtime sets and
22 labeled temporary aliases remain. S.Wayne is12/80 review-only cells, not live
replacement art. Next art gate: complete/review his remaining68 cells, then
Middle/Large and one unique identity at a time. Do not pad sheets with portraits.

Stopped feature expansion at the reported75% weekly allowance floor. No installer
rebuild, commit, push, publication or human playtest claim. Existing installer
does not contain these changes. Run this source from the repository:

```powershell
.\flux.cmd play
```

Test Small/Middle/Large at Gallery, compare near-miss shots and identical wall
passages; exercise all directions/actions. Try deposits/reactions, Field and
Spray with reduced effects on/off and check that their material shows the area.
