# Idle/action anatomical continuity pilot

Status: October 3 Oh Tipi repair v2 assembled and ACCEPTED for bounded static
and native anatomical-scale improvement. Full179/3,155,510 and package validation pass;
current engine boards and the SW in-world motion fixture pass their limited gates.
Human acceptance is NOT_RUN. Other 29 action identities and all 30 ground/cast
banks remain unchanged; this is **not an all-cast anatomical fix**.

Preserve the scale/performance `p56-90e292bc8237` portable and cast-motion
`p56-f41a016ccac4` fallback. Receipts do not validate later source changes.
The lead owns assembly, imports, engine tests, captures and export.

## Selected Oh Tipi v2 and next acceptance

The selected `art_batches/pixel_actions_v1/source/oh_tipi/` source, five-row recipe, and lead review
now use neutral row 0 plus action rows `[1,2,3,4]`. One source-wide scale is
`63/149 = 0.4228187919463087`; no pose is independently fitted. Original and v1
candidates remain preserved. V1 was held for its overly long rise; v2 corrects
that while retaining the improved head mass.

| Item | Selected/inspected identity |
|---|---|
| Source PNG SHA256 | `fb2297c75fdd091032048aad9fcf4cab60181da3cc270dad371d4abfd68cc78a` |
| Raw recipe SHA256 | `c9b604b3c2454ec909470018fe3e68073038d3febe738386b9d935ae3002ef27` |
| V2 review action PNG SHA256 | `163f814058a864a0241ebe2db2a7090eeb4faef2c00e2082c74088110e803f38` |
| Unchanged ground PNG SHA256 | `c89258d7c76b180ba4b167832364e7735f13ed5ac461b13f4a16e287708e40fa` |

Lead and independent static review accept the pilot's improved head/torso mass,
compressed anticipation and tucked rise. No new gross clipping, missing part,
detached tail or anatomical scale jump was seen across eight assembled headings.
Native presenter boards and representative actual Wellspring frames also pass
bounded lead/independent review: four boards/192 queries,31 in-world frames,
one paid airborne Spray release,16 fixed-aircast ticks and2 landing-key ticks.
World motion covers SW, not all8 directions; it is not human approval.

| Pose | Idle / v1 reference | V2 height range across eight headings |
|---|---:|---:|
| Existing idle | 62–63 px | 62–63 px, unchanged |
| Jumpsquat | v1 61–63 px | 54–55 px |
| Rise | v1 67–72 px | 58–62 px |
| Fall | v1 64–67 px | 64–70 px |
| Land | v1 53 px | 53–54 px |

Front-facing upper skull/crest/fin width is 34 px in idle, 23 px in the original
fall and 31 px in both v1 and v2 fall. Reproducible manually selected local bands
stop before collar/shoulder intrusion: idle `y=[41,64)` gives alpha bounds
`[51,41,85,64]`; original fall `y=[41,60)` gives `[53,41,76,60]`; v2 fall
`y=[33,55)` gives `[49,33,80,55]`. Allow about ±1 px contour-selection uncertainty.
These are identified upper-head widths, not complete skull-height/torso metrics;
do not reuse one fixed band for crouched poses with raised shoulders.

Remaining limits are explicit: NE remains profile-like; anticipation and landing
have only 0–2 px total-height separation; fall extends to 70 px with downward
feet/toes. No strict eight-heading or complete choreography approval is implied.

Assembly confirms exact RGBA preservation of the other29 action sheets; all
ground banks are unchanged. Focused/Full and150 exact source/export image checks
pass; native Windows launch/safe close and selected-build hashes are verified.
Only after native feedback should Red Baron,
Fluup and Haara receive individual continuity pilots; do not regenerate all 30.

The same implementation slice also contains renderer culling and new-source-only
field-contact scheduling under their own correctness/performance gates. Neither
this art repair nor those optimizations establish dense120Hz or more players.
`HEX-CAPACITY-64.md` records 8 as the current session/fixture-supported count,
with end-to-end capacity unproven and 16/32/64 UNSUPPORTED. The next representation
candidate is immutable topology plus sparse dynamic snapshots at eight players,
before a separately versioned cap/ID/mask/snapshot migration.

## Pre-pilot finding

**The original banks already matched silhouette height without reliably matching
anatomy.** A neutral standing figure and a soft-knee descending figure are not
the same measuring stick. Extending a leg, shifting a cape, pitching a head, or
lowering a wing changes the occupied bounding box without changing the intended
character scale. A smaller head can therefore pass the current height contract.

The pre-pilot idle/action comparison boards, the four priority original action
sources, and the native-sized all-roster comparison were inspected. Oh Tipi,
Red Baron, Fluup and Haara visibly lose head/face mass relative to their idle
references. This corroborates the already-recorded continuity issue; it is not
a new claim that other characters pass anatomical continuity.

### Reproducible source facts

- `art_batches/pixel_cast_v1/build.py` fits the largest selected **idle** ink
  height to 58/63/68 px for new sources. The three pilot identities are lossless
  repacks of the previous pilot bank, not newly normalized ground art.
- The existing `art_batches/pixel_actions_v1/build.py:assemble` default independently fits the
  largest selected **fall** ink height to the same 58/63/68 px. It applies that
  single factor to all four rows. Ground PNGs are loaded later for comparison;
  they do not contribute a head, torso, or limb calibration measurement.
  The opt-in neutral-row extension described below changes only new recipes
  that explicitly select it; this finding describes the pre-pilot action bank
  and the unchanged 29-character legacy path.
- The action assembler uses the source grid center and a row-wide bottom at
  pivot `(64,104)`. Individual headings can end a few pixels above the pivot.
  This registration detail is separate from anatomical scale.
- The priority prompts name the current ground bank as primary canon but also
  impose a generic one-third head/standing-height target: Oh Tipi 19–21/60,
  Red Baron 20–22/66, Fluup 20–21/64, Haara 18–20/58. These are generation
  instructions, **not measured results**. The existing character-specific
  idle head envelopes are visually not interchangeable with this common rule.
- `source/s_wayne/proportion-repair-v3.png` and the resulting action PNG are
  explicitly hash-locked. A blanket recalibration cannot silently exempt or
  overwrite that preservation contract.

### Pre-pilot exact atlas measurements

Read-only analysis before selecting Oh Tipi v2 covered all 60 PNGs / 1,200 cells (8 idle
and 32 action cells per character) found 29/30 exact maximum-height matches.
Leaf the Hidden is the sole one-pixel exception: idle 63, fall 64. Every other
character is 58/58, 63/63, or 68/68 according to its existing body tier.

The priority figures below are **whole alpha bounds**, not head/torso estimates.
`S` is the front-facing cell; a half-open bound `[x0,y0,x1,y1]` includes pixels
from `x0` through `x1-1` and `y0` through `y1-1`.

| Character | Max idle / fall height | S idle bounds | S fall bounds | S width idle → fall |
|---|---:|---|---|---:|
| Oh Tipi | 63 / 63 | `[41,41,95,104]` | `[43,41,89,101]` | 54 → 46 |
| Red Baron | 68 / 68 | `[41,37,96,104]` | `[35,37,94,101]` | 55 → 59 |
| Fluup | 68 / 68 | `[37,38,100,104]` | `[36,38,95,103]` | 63 → 59 |
| Haara | 58 / 58 | `[46,46,85,104]` | `[51,48,93,102]` | 39 → 42 |

Arms, ears, fins, hair and capes contribute to those widths. Red Baron and
Haara are useful counterexamples: their fall silhouette is already wider than
idle, while their head still reads smaller. These numbers must not be converted
into an automatic global width/height multiplier.

## Reusable method for subsequent one-character pilots

1. Preserve current art and work in a separate candidate directory. The first
   Oh Tipi pilot is selected above; do not reopen a roster-wide batch. Measure
   comparable front and profile skull/crest-to-chin spans,
   skull width, torso length/width and a visible boot/hand on idle and the four
   action rows. Exclude tail/cape/hanging hair from anatomical dimensions and
   record uncertain/occluded spans instead of inventing them. Use the exact
   inspected PNG hashes and at least two independent anatomical spans.
2. If head, torso and limb ratios agree within stated pixel uncertainty, review
   a **single source-wide calibration factor**. Keep squat/rise/fall/land
   naturally different in height. A factor is a review candidate, not a
   automatic runtime correction; verify clipping, pivot and every heading.
3. If those ratios conflict, or would produce an implausibly tall/broad body,
   this is an **authored proportion repair**, not an assembler scale fix.
   Preserve identity-specific idle anatomy instead of prescribing one-third
   heads for every character. Prefer a new source containing one neutral idle
   calibration row plus the four action rows, all drawn at a common scale.
   Match the neutral row's anatomy to existing idle; calibrate on that neutral
   row and reuse the scale for every posed row. Do not fit the fall row again.
4. After native feedback, repeat the accepted method on Red Baron, Fluup and Haara; inspect mild
   secondary cases S. Wayne, Oll' I, Waka Aren Si and Dr. Apex. Review all 30
   before calling the bank continuous; do not regenerate 30 sources blindly.
5. Only after source and assembled-board approval should the lead publish an
   opted-in calibration recipe. Bind approval to **source + calibration + ground reference**
   bytes: the legacy lead gate binds only the source PNG; the new neutral-row
   gate additionally binds exact raw recipe bytes. Preserve immutable
   originals, use a separate candidate path, test stale/mismatched calibration
   rejection, and retain all current all-roster/rollback safeguards.

Oh Tipi is the simplest priority pilot because its front face/crest and gold
torso landmarks are visible and it has no cape or long hanging hair. Red Baron
requires distinguishing the crown/skull from cape spread; Fluup requires head
and shoulder/boot checks; Haara requires excluding hanging hair and rechecking
face placement. Oh Tipi's selected neutral factor is a bounded pilot decision,
not a transferable multiplier or approval for the rest of the roster.

Actual in-game idle → squat → rise → fall → land → idle playback at ordinary
camera size, plus matching source/export bytes, remains lead-owned acceptance.
The analysis/helper work does not run Godot, refresh runtime identity or export;
integration/publication remains lead-owned and its status is recorded above.

## Opt-in neutral-row builder support

At the lead's request, the action builder now supports the optional
`calibration_source_row` integer. For a five-row pilot, select source rows
`[1,2,3,4]` as the actions and row `0` as the neutral reference. One scale is
calculated from the maximum neutral-row ink height and applied to every action;
no pose-specific fitting or image deformation is introduced. The report records
the neutral source row, per-direction pre-resize bounds/heights and factor.

Rows outside the source, booleans/fractions, calibration also selected as an
action, and any S. Wayne calibration override are refused. Existing recipes
retain their normalized shape, fall-fit branch, action PNGs and S. Wayne lock.
Neutral-row full publication also requires a matching `assembly_sha256` in the
lead review, bound to raw recipe bytes; a missing/stale hash fails before output
staging. Available-mode inspection deliberately bypasses the lead gate.
Fresh isolated builder result: **31 tests passed**, including exact S. Wayne
PNG/RGBA preservation, the neutral factor/bounds, malformed or overlapping rows,
and missing/stale/fresh raw-recipe approval hashes. No runtime bank was published
by these tests; publication fixtures use their own temporary directories.
The new source's neutral row must still be visually judged against idle; the
builder cannot discover whether a neutral head is anatomically correct.

## Read-only audit helper

```powershell
python -B art_batches/pixel_actions_v1/audit_scale.py
python -B -m unittest discover -s art_batches/pixel_actions_v1 -p test_audit_scale.py -v
```

The helper prints JSON to stdout and has no output/publish/image-write path.
Every character is `anatomical_scale: NOT_MEASURED` unless a reviewer supplies
an explicit hash-bound landmark record. Equal silhouettes never become PASS.
Fresh isolated result: **7 tests passed**; the all-30 read-only audit completed.
These tests verify diagnostic logic, not artistic quality.

Optional `--landmarks <path>` accepts an object keyed by catalog identity. Each
record has `ground_sha256`, `action_sha256`, nonblank `reviewer`, and a nonempty
`measurements` array. A measurement includes a `name`, a precise `definition`,
`direction` (`S` through `SW`), `action` (`jumpsquat`, `rise`, `fall`, `land`),
and `idle`/`posed` objects with numeric `pixels` and `uncertainty`. Stale hashes,
missing definitions, booleans, nonfinite values and invalid uncertainty fail.

The helper reports the idle/action ratio interval for each measured span and
their common interval, if any. Conflicting intervals are explicitly reported
as `CONFLICTING_ANATOMICAL_SPANS`; one span alone cannot establish a uniform
scale. Even agreement is `MEASURED_SPANS_ONLY`, never native/human approval.
Complete multi-landmark anatomical annotation has **not** been completed; only
the explicitly selected Oh Tipi upper-head comparison above is measured. The
tool deliberately does not disguise a top-of-bounds heuristic as a head.
