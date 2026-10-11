# Reference and identity refinement evidence

Status: SIX-ELEMENT LOCAL PLAYTEST QUALIFIED, October 9, 2026. The eight-element
phase below is historical. [Current scope](../SIX-ELEMENT-DYNAMIC-REFINEMENT.md).
No public release or human balance acceptance is claimed. The source identity is recorded in
`content/runtime/runtime_build_identity_v1.json`; results below qualify only
their frozen source and stated scope.

The [design record](../REFERENCE-IDENTITY-REFINEMENT.md) explains the decisions
and primary references. The [player field guide](../IDENTITY-PERKS.md) covers all
21 ancestry and 30 personal passives. The root agent serialized engine work;
three workers independently reviewed movement, combat and menu/map changes.

## Current qualified result

**p59-6336a7ba6067** passed the [complete Full gate](full-six-final-v3.json):
227 suites, 5,713,342 assertions, zero failures/error output and successful startup.
Both actual input journeys passed; all 32 final UI and 14 aerial/protection samples
were individually reviewed within their stated limits. The [local portable](../../exports/hex-six-elements-20261009/windows/PLAY-HEX.cmd)
passed export, exact-byte verification, native startup and safe close.
The [integration record](six-integration.md) contains current receipts, hashes,
the preserved failures and remaining human/performance/networking gates.

## Historical scope transition

The later user request changes selectable elements to six and chemistry to all63
nonempty combinations. The earlier Full continuation was stopped; no new package
was promoted from that earlier phase. [Six-element UI handoff](six-element-ui.md) and
[combat contract](six-element-combat.md) describe local source work, peer findings
and integration. [Current integration checks](six-integration.md) record the
resumed engine runs and their exact scope. No Godot or native acceptance result
in the historical section below qualifies the later six-element source.

## Executed history

- [Full v3](full-v3.json): deliberately interrupted by root after the user
  requested the six-element redesign. Only this run's verified Godot child was
  stopped. Its exit code -1 records interruption, not a completed correctness
  pass. Source `p58-cf3998a288c2` was preserved before the migration; no package
  was promoted from this phase.
- `.godot/reference-repaired-v5/suite.log`: six of seven additional repaired
  suites passed. A newly added short-shot test incorrectly inspected an internal
  terminal event after the world had consumed it. The correction uses the real
  public expiration/contact event and retains the exact endpoint/no-wall guard.
- `.godot/reference-repaired-v6/suite.log`: that corrected shared-authority suite
  passed 15,080 assertions, zero failures/stderr.
- `.godot/movement-advanced-reference-identity-v1/receipt.json`: 12 advanced
  input journeys, 7,751 checks, passed. These qualify the pre-six source only.
- `.godot/movement-impact-native-reference-20261009-v2/receipt.json`: all ten
  controlled impact captures passed and were [independently reviewed](native-impact-review.md).
  The first capture hit its 180-second draw-signal watchdog under a minimized
  window. Explicit offscreen redraw, already used by the Gallery harness,
  repaired the harness without changing gameplay or renderer sources.

- [Initial dirty inventory](initial-worktree.txt): inherited work was preserved.
- [Focused v1](focused-v1.json): retained failed run; stale spell expectations,
  invalid map connection widths and invalid snapshot/movement fixtures exposed.
- [Focused v2](focused-v2.json): all eleven previously repaired gameplay/menu
  suites passed; the actual Heavy practice spacing and unconfigured snapshot
  host still failed. These failures were diagnosed and repaired.
- `.godot/identity-map-preflight-v3/suite.log`: both repaired suites passed,
  3,290 identity assertions and 12,081 map assertions, zero failures/stderr.
- [Full v1](full-v1.json): stopped at a literal README wording guard before
  engine execution; wording restored without weakening the guard.
- [Full v2](full-v2.json): failed at the 900-second suite watchdog after
  220 completed suites and 4,839,226 assertions. Sixteen completed suites had
  failures, listed below; the unfiltered success footer and boot were not
  reached. The total receipt duration was 1,184,779 ms, including preparation
  and import, and must not be reported as the suite-engine runtime.
- `.godot/reference-repaired-v4/suite.log`: twelve selected suites completed
  with 280,910 assertions and zero failures, including the inherited complete
  visual catalog, Wellspring visual catalog and replay tail. The error log is
  empty and the selected-suite success footer is present. This targeted run
  does not replace a completed unfiltered Full run and boot.
- `.godot/identity-perks-native-reference-20261009/receipt.json`: root's native
  capture passed all-thirty policy projection, actual-font fit and unchanged
  authority/inspection checks, and produced twelve frames. The independent
  [per-image review](native-perks-review.md) records four 1280 x 720 overview
  passes and eight limited frames: small supporting text at 960 x 540 and
  sentence splitting between Details pages remain explicit limitations.

The map repair preserves validator bounds and existing activities. The target
spacing check includes the actual Heavy contact surface, not just a target's
center. Snapshot fixtures retain a real configured host and all thirty current
identities; production validation was not relaxed. Exact pre-edit copies are
under `.godot/reference-refinement-baseline/`.

## Full v2 diagnostics and fixture repairs

The retained Full v2 suite log is
`.godot/windows-tests/4feb5172546a49ca9f2715231c330968/suite.log`. Its failed
suite summaries are preserved exactly in the receipt:

| Suite | Failed assertions |
| --- | ---: |
| movement-checkpoint1 | 32 |
| unified-prediction | 21 |
| hex-optics | 1 |
| hex-chemistry-snapshot | 2 |
| hex-shared-authority | 8 |
| hex-field-interception | 7 |
| hex-strength | 1 |
| hex-court-presenter | 9 |
| champion-catalog | 1 |
| champion-roster-plan | 25 |
| spell-delivery-expansion | 8 |
| projectile-chemistry-integration | 2 |
| compact-combat-hud | 5 |
| wellspring-architecture-kit | 1 |
| pixel-magic-library | 1 |
| pov-presentation | 1 |

Repairs preserve the current mechanics and strong negative controls. Movement
and prediction fixtures use the current identity and charged movement costs;
projectile fixtures use compiled delivery geometry and current damage; HUD
fixtures use live balance values. The Spray contact fixture derives its radius
from the compiled spell and still distinguishes closed tangency from a
one-fixed-unit clearance with actual damage controls. Directory binding now
compares the complete obstacle identity, shape and traversal flags before and
after binding instead of requiring an obsolete obstacle count.

The pixel-magic source hash was renewed only after two independent reviews
confirmed that the preserved old hash matched the historical guard and that
the chemistry source changed only the emitted damage amount to actual Health
removed. Footprint, quantity, pulse and lifetime behavior were unchanged; the
[exact audit](pixel-magic-source-audit.md) records both hashes and the limit of
that finding. Asset, palette, frame and stale-hash controls remain.

The roster provenance repair preserves the historical candidate JSON and all
non-playstyle fields. It permits only the declared obsolete-denial suffix
replacement for the explicit twenty-five affected identities, requires the
exact old suffix, and compares the entire resulting record against current
content. Unknown copy drift still fails. The five original preserved records
remain exact comparisons. This test repair was frozen after the targeted
repaired-v4 selection and awaits the next complete run.

The twelve repaired-v4 suites were movement-checkpoint1, unified-prediction,
hex-optics, hex-court-presenter, spell-delivery-expansion,
projectile-chemistry-integration, compact-combat-hud,
wellspring-architecture-kit, pixel-magic-library, complete-visual-catalog,
wellspring-visual-catalog and replay. The other Full v2 failures are not
implicitly passed by that selection; the next unfiltered run is the gate.

## Supervision and runtime diagnosis

An independent source review found no this-pass changes to the complete visual
catalog loader, image inspector or its tests. A successful catalog validation
visits 203 image references. The existing negative and positive controls
repeat validation, totaling roughly 1,001 image-inspection calls in that
suite. This is inherited work, and no isolated per-suite timing from Full v2
supports attributing the slowdown specifically to that catalog or to the new
identity policy. The catalog subsequently passed its 99 assertions in the
targeted run, so the observed timeout does not establish a catalog deadlock.

Historical passed Full receipts include preparation and import. Their actual
suite-log filesystem spans were approximately 604 seconds for the October 8
momentum roster run, 677 seconds for the October 8 portrait Gallery run, and
700 seconds for the October 7 core-m3 run. These are coarse write-span
observations, not per-suite benchmarks. Full v2 wrote its last completed suite
at roughly 891 seconds before the 900-second watchdog. The larger run's
assertion count and new passive evaluation warrant measurement, without
assuming either explains the entire difference.

The reviewed supervision change raises only the Full suite watchdog from 900
to 1,200 seconds. The shared function's allowed maximum becomes 1,200; its
default and ordinary import, capture and Focused supervision remain 180.
The runner logs monotonic elapsed time around each existing `suite.run()`.
No suites, assertions, failure checks or required Full success footer were
removed. Those timing lines cannot match the anchored assertion-summary
parser. Root's new unfiltered Full run and boot remain in progress; increasing
a bounded watchdog is not a simulation frame-time or sustained 120 Hz pass.

The first movement-impact native harness reached its 180-second timeout while
awaiting `frame_post_draw` with a minimized Windows root. The test-only repair
flushes queued work and explicitly draws the offscreen viewport, following
the Gallery capture approach. The v2 directory now contains a receipt and ten
frames; root and the assigned visual reviewer own final capture validation.
The failed first capture and Full v2 logs remain retained.

## Acceptance boundary

Deterministic assertions establish the covered simulation and UI contracts.
Native captures establish the rendered samples that were inspected. Scripted
input journeys are not physical controller trials. Portable export, boot and
safe close do not establish different-home Internet play, clean-machine install,
competitive balance or sustained dense-load 120 Hz. Existing art/action-cycle
and human-playtest gates remain separate.
