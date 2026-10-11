# H.E.X. material frame preparation — September 23

Status: D6 bounded rendering optimization COMPLETE; Windows functional checks
PASS, rendered timing FAILED, broader capacity and human acceptance OPEN.
Runtime is frozen at
`p55-1b26a51136d1` (SHA256
`1b26a51136d12142fe8c745e334d57af3f73a8ea4244d3ea2ac4bbb004f650b5`,2800 records).
Focused v2 PASS:7 suites/2074 assertions/zero failures or stderr, including84
new production checks across16 guarded equivalence cases. Independent static
and Focused review found no blocker. The current solo review package is
`exports/hex-render-frame-20260923/windows/PLAY-HEX.cmd`. Operational fallback:
`exports/hex-hash-20260923/windows/PLAY-HEX.cmd`, p55-a9837cac9e8c.
This is evidence for the single active queue, not a second implementation plan.

Outcome: reduce CPU work preparing whole-hex material views and regions for one
draw while preserving the exact resulting pixels and all gameplay authority.
The implementation computes each populated material's regions once,
derives its view from that result, and keeps existing preparation validation,
ordering and independently owned output. It retains the original path for
generic/subclass courts and renderable unusual record shapes. It has no cache
across calls and must observe direct authority mutations on the next call.

Acceptance: actual integrated production against the frozen old preparation
oracle; malformed/generic/subclass, phase, order and ownership regressions;
fresh focused and Full checks; rendered pixel equivalence; unchanged evolving
stress workload; exact Windows identity, launch/close, movement/casting, Loom
save/restart, Water, labels and visibility evidence. Performance capacity and
human feel/style remain distinct, unaccepted gates.

Pre-integration evidence is sealed in
`../hex-hash-20260923/d6-sealed-evidence-map.json` (262 files). The headless
prototype passed976 assertions/21 cases/two legal workloads. The native
alternating comparison passed1968 assertions and448 exact RGBA8 frame checks.
All eight saved images match by both file bytes and decoded pixels; four
candidate views were independently inspected. Matched total-draw medians save
8.314–9.989ms, remaining26.914–32.653ms. Dense reduced draw/presentation maxima
and dense normal presentation maxima regress. These observations establish no
GPU, sustained cadence, network, evolving-stress or human acceptance.

Those old/new comparisons are historical prototype evidence: after integration,
their `super.draw_ground` baseline resolves to the new code and must not be
rerun or described as another old/new measurement. Fresh integrated validation
will use the old oracle and preserved baseline images explicitly.

Root owns registration, identity, all engine work, evidence and documentation.
Sol High exclusively owns the presenter implementation and regression suite;
Astra High performs independent read-only review. Each worker preserves others'
dirty edits. `baseline.json` records the checkout/dirty boundary and27 protected
hashes; `baseline-source/` preserves the three changing source files plus the
packaging helper before integration. Source froze before the final gate.

Focused v1 failed the stale-identity preflight before suites. The first identity
generation refused to replace an existing manifest without explicit intentional
pre-Full regeneration; the next authorized attempt used `-Force` and passed.
Full v1 imported successfully, then the registry guard rejected two unused
test-helper global class names before suites. Their original bytes and the
first freeze are preserved. Only those declarations were removed; executable
bodies, production source and runtime identity are unchanged. The registry guard
remains strict. Full v2 passed against the amended test-source freeze.

The fresh source, rendered, export and packaged results follow below. The previous exact-EXE
300-second lifecycle failure with resource/allocation/JSON errors remains
unresolved. Physical controls, native spectators, physical two-PC/Internet,
installer/update and human Water/motion acceptance remain separate.

No gameplay tuning, cadence, cap, map, profile, named skin, approved reaction,
commit/push/publication or selected-checkpoint promotion is part of this slice.

Later D7 follow-up: `whole-prepare-probe-brief.md` found no existing test-only
constructor injection point through the two static snapshot codecs. Proving the
complete public prepare path would require a broader codec refactor or a copied
implementation with a narrower claim. Integration remains deferred: the isolated
7.259ms constructor saving does not justify adding a runtime test hook by itself.
This is an engineering scope decision, not a missing permission or human gate.

## Fresh integrated evidence

| Check | Executed result |
| --- | --- |
| Full v2 | PASS160 suites /805098 assertions /zero failures and stderr; import, asset inventory and configured120Hz boot;242542ms. |
| Integrated native component capture | PASS2095 assertions, four frozen views/32 samples each, all12 images byte-identical to preserved D5 PNGs and RGBA8; same authority/accounting. |
| Evolving rendered workload | PASS7991 correctness assertions, identical25 authority/workload fields and trace hashes against D2, zero draw-authority mutations; timing FAILED1440/1440frames. |
| Exact PCK basic movement and casting | PASS27 cases /11601 checks, including192 input-router samples and24 paid routes. |
| Exact PCK earned advanced movement | PASS9 routes /5909 checks covering Float, dodge/fastfall and wall actions. |
| Exact PCK Spell Loom | PASS ordinary interaction, twelve-slot assignment, Escape close, movement, paid cast, save and separate-process restoration. |
| Exact PCK Water | PASS32 frames /888 checks; paid launch/travel/impact/full-cell occupation/expiry; normal/reduced and zoom views. |
| Exact PCK station labels | PASS27 checks /12 gameplay frames, including nearby live-title positive control. |
| Exact PCK terrain/live visibility | PASS31 capture cases /165 checks. |
| Native EXE and artifact | PASS launch, expected identity, safe close; PCK/ZIP hashes and all7 ZIP entries match the payload. |

These are fresh results for the frozen integrated source. The earlier D2 Full
and prototype D6 experiments remain historical receipts. Full includes the
single-engine eight-participant localhost ENet fixture; it is not a complete
multi-EXE lifecycle or physical two-PC acceptance. Scripted application-input
journeys are not a claim about physical controller feel or every offered action.

The integrated native diagnostic has total-draw p50/p95/p99 in microseconds:

| Frozen view | Total CPU draw | Present elapsed, separately measured |
| --- | --- | --- |
| Distributed normal |25366 /28615 /28985|65350 /70613 /72235|
| Distributed reduced |25241 /32142 /32818|66536 /80504 /89303|
| Dense reduced |32196 /41341 /41840|76768 /86982 /88923|
| Dense normal |33275 /49396 /57800|80315 /110771 /116580|

This confirms the integrated path's current cost and exact baseline pixels.
Sequential D5 observations are not another matched A/B speedup. The actual
pre-integration alternating comparison remains the evidence for8.314–9.989ms
median savings. Its worse dense maxima remain preserved, not omitted.

The unchanged evolving stress produced these fresh timings in milliseconds:

| Workload/mode | Present p50 /p95 /p99 | CPU draw p95 | Two-tick simulation p95 | Misses |
| --- | --- | --- | --- | --- |
| Distributed normal |211.695 /301.223 /401.104|142.448|97.056|360/360|
| Distributed reduced |209.740 /290.993 /401.674|139.523|97.727|360/360|
| Dense reduced |131.039 /202.998 /238.072|98.857|168.337|360/360|
| Dense normal |126.031 /187.711 /235.284|94.530|167.707|360/360|

CPU draw and present timings overlap and must not be added. The two-tick
simulation measurement is not a single120Hz tick measurement. The stress frame
deadline is16.667ms, not120FPS acceptance. Hardware/backend: Windows,
Godot4.7.1, AMD Ryzen3 7320U/8logical processors, gl_compatibility/ANGLE D3D11,
1280x720. GPU cost and per-call allocations were not measured. No capacity gain
is inferred from simpler preparation or successful exports.

## Package, evidence and test route

Launch the frozen candidate:
`C:\Users\sende\Projects\hex\exports\hex-render-frame-20260923\windows\PLAY-HEX.cmd`.
For current source use `scripts/run.cmd` from the HEX checkout. Earlier EXEs
contain earlier builds. Keep EXE and PCK together when extracting the local ZIP:
`exports/hex-render-frame-20260923/HEX-p55-1b26a51136d1-Windows-x64.zip`.

- PCK SHA256:`affbbb58a4b490cdd2b465709bbe45a1225bf9652ae0d19cd717ea6ccec29211`.
- ZIP SHA256:`60c7668db7233c76dfd7349d473957aea712742a486a76e530f6f02bee2bfd85`.
- `evidence-map.json` preserves262 evidence files with referenced logs/images.
- `preservation-audit.json` verifies40 frozen/protected hashes; older packages,
  original assets, profiles, dirty work and selected checkpoint are preserved.
- `integration-review.md` records independent source, receipt and rendered review.
- `integrated-pixel-equivalence.json` and `stress-workload-equivalence.json`
  distinguish exact output/workload equality from measured timing claims.

Suggested human route: equip Water Heavy/Tide Shell at Loom, close, move and aim
independently while casting, then compare normal/reduced effects and50/75/100%
zoom through impact and expiry. Change body size, test movement transitions and
saved controls, walk around the pavilion to check character concealment, and
restart to check saved weave. Default Evade isB;Q is unassigned. Water remains a
harmless ingredient until an implemented reaction makes an active effect.

NOT RUN for this exact D6 build: full multi-EXE localhost lifecycle, physical
keyboard/controller acceptance, native spectator acceptance, physical two-PC,
Internet networking, installer/updater. The earlier300-second lifecycle failed
with resource/allocation/JSON errors and remains unresolved. Human Water style,
motion/template acceptance and proposed reaction redesign approvals remain open.

## Continuing independent work

D7 is test-only: checked canonical-order geometry construction passed270
assertions/22 equivalence cases/zero stderr. The40-sample-per-arm alternating
comparison measures complete fresh2766-cell construction: old p50/p95/p99
52.125/56.279/85.624ms versus candidate44.866/48.299/48.991ms. The7.259ms median
saving is not an integrated snapshot-prepare, simulation or frame gain. Source
and identity stayed stable. Independent review in `ordered-geometry-review.md`
verified all blocks, values and hashes and recommends deferring production until
an actual whole-snapshot-prepare comparison proves complete-operation benefit.
No D7 runtime code is in this package.

`offscreen-draw-audit.md` identifies a possible next test-only material-submission
candidate. Full preparation, validation, semantic edge counts and cover regions
must precede any conservative viewport rejection. It is unimplemented and
unmeasured. The single queue owns prioritization; human gates remain explicit.
