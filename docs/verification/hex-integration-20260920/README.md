# HEX integration evidence — 2026-09-20

Final runtime: p54-8cb4def57da9. Source SHA256:
8cb4def57da9552610662b00b09000055860e5f50f29257de84ea2bc776c1c87.
See ../../HEX-INTEGRATION-CHECKPOINT.md for scope, risks and exact launch paths.
All evidence below was freshly executed during this integration unless explicitly
marked intermediate or baseline. Historical FLUX receipts elsewhere do not prove
this changed source. No human or physical two-PC acceptance is implied.

| Directory/file | Receipt and preserved raw logs | Result |
| --- | --- | --- |
| tests/full-v1 | receipt.json; import.log, suite.log, boot-120.log and .err companions; current-state/asset audit | PASS157 suites/776169 assertions, zero failures/stderr, import/120Hz boot |
| tests/focused-v3 | receipt.json + suite.log/.err | PASS8/5508 |
| tests/focused-p54-v1 | receipt.json + suite.log/.err | PASS5/2516 |
| tests/focused-clash-v2 | receipt.json + suite.log/.err | PASS1/35 actual client apply/cue/dedup |
| network/p54-v1 | receipt.json + host/guest/late-guest logs and .err | PASS256.926s, real source processes, unchanged300s deadline |
| network/baseline-v1 | receipt.json + three process logs | FAILED300s baseline; RESULT reached but countdown starved by snapshot work |
| dense-before, dense-after | receipt.json + profile.log/.err; final identity in dense-after | Matched480-tick seed906190 workload; final2253assertions/zero stderr; capacity FAILED |
| snapshot-stages | per-run receipt.json + probe.log/.err | Five-sample intermediatep53 stages; opt-v3 PASS332. Baseline wrapper FAILED diagnostic stderr after timing; never relabeled clean |
| snapshot-stage-comparison.json | Derived directly from preserved stage receipts | Exact workload and authority hash equality through optimization |
| rendered | receipt.json + profile.log/.err, hardware/guard/identity records | PASS8131; four360-frame runs; normal/reduced authority match; all frames miss16.667ms |
| hex-handoff-v5 | capture-receipt.json,22 native PNGs and terrain diagnostics | Finalp54 capture, zero stderr, paid Steam, UI and held three-size boards |
| hex-contact-pilot-v1 | capture-receipt.json and14PNG A/B pairs | Intermediatep53 legal160-step trace; REJECT live stride promotion; no rig change |
| capture-logs | probe.log/.err per named run | Failed handoffv1-v4 fixtures retained; handoffv5/contact/Steam logs retained |
| hex-steam-balance-v1.json | JSON plus capture-logs/steam-balance-v1 | PASS1101 stdout assertions (JSON1100 before final file assertion); deterministic measurement, no tuning |
| package | receipt.json; export.log, export-smoke.log, runtime-pack.log and .err; BUILD-STATE/SOURCE-IDENTITY; payload-verification.json | PASS actual native EXE safe close, exact PCK build, zero stderr, ZIP entry hash audit; no installer |
| preservation-final.json | Fresh selected-pointer/fallback hash comparison | Original P48 EXE/PCK/ZIP unchanged; pointer byte-identical |
| publication-source-audit.json | Git index blob comparison and bounded content scan | All2791 runtime inputs byte-identical to tested working source; profiles/caches/exports excluded |
| preservation-baseline.json | Original baseline paths and copied hashes | Maps original FLUX fresh dense baseline to this portable evidence directory |

[Actual capture review gallery](review.html) offers Steam phase/terrain/mode and
shared-pose/isolated-stride comparisons. Held poses are not transition acceptance;
modeled gait contacts are not tracked sole pixels. Pilot proposal was rejected.

Receipt path fields retain their original execution locations. In each curated
run directory the referenced log basename is copied unchanged; .err companions
are included even when empty. Original paths remain local under .godot,
docs/evidence or exports. Isolated APPDATA, shader caches, player profiles and
EXE/PCK/ZIP payloads are deliberately not included in the source repository.
Package hashes and local delivery paths remain in its receipt.

Failed early fast/focused receipts are retained under tests. They include an
initial first-import watchdog failure and README/count preflight failures.
These are corrected diagnostics, not passing evidence. The initial stage stderr
failure and capture fixture failures also remain. No failed result is overwritten.

SHA256SUMS.txt covers every file in this evidence directory except the manifest
itself. Git attributes preserve their raw bytes. Recompute SHA256 to compare;
this manifest is an integrity aid, not a signature or security certification.
