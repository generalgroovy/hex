# H.E.X. smaller-grid handoff

Status: CODE SLICE COMPLETE; local playtest candidate, multiplayer gate FAILED.
Date: September 21, 2026. Stop for human playtesting after the authorized source
push; do not start further mechanics or silently promote a release.

| Authority | Value |
| --- | --- |
| Checkout | `C:\Users\sende\Projects\hex` (the old FLUX checkout is preserved) |
| Repository / branch | Public `https://github.com/generalgroovy/hex`, `main`; check Git for exact publication state |
| Frozen runtime | `p55-c7b7694f8d23` |
| Runtime SHA256 | `c7b7694f8d23a6ca1c7b069729760302a6c11a7ef6f6ff53e16548a832c937b5` |
| Schemas | Protocol 55 / SessionSnapshot21 / HexWorldSnapshot3 / chemistry3 / envelope1 |
| Usage boundary | Stop before 33% weekly remaining; last successful check 42% remaining, no credits redeemed |
| Effort | High through code/validation; Medium is sufficient for final branding/docs/push; current-turn effort cannot be changed by available tools |

The user requested smaller hexes and the public H.E.X. rename. The already
created HEX repository is authoritative; do not recreate it or force-push.
The completed dirty vision work is included, not reverted. Original source,
assets, user profiles and earlier packages remain untouched.

Hex width is 48 px, previously 64, with 2,766 eligible cells under the 4,096 cap.
World bounds, obstacles, character visuals/hurtboxes, 18 px common wall clearance,
spell radii/costs and authored damage coefficients stay fixed. Radius selects
whole cells; material remains finite. Fire/Steam pressure uses per-cell density,
so finer coverage can lower pressure. Do not silently multiply material or tune
damage to hide that consequence. Protocol 55 rejects old geometry peers/replays.

Vision remains character-centered 360/720 under 55-degree projection, independent
of aim/zoom. Opaque buildings and actual solid hex cover occlude other actors and
attached feedback; own body stays visible. Legacy profiles migrate without
resetting controls or twelve-slot weaves. This is rendering, not state redaction.
All 30 playable profiles still use three shared size templates, not 30 finished skins.

| Fresh evidence | Result |
| --- | --- |
| Geometry Focused v3 | PASS 9 suites / 62,515 assertions / zero stderr |
| Chemistry/branding Focused v5 | PASS 7 / 7,741; all ten first-four pairs, both orders and three paid trigger paths |
| Full v3 | PASS 157 / 803,865; zero failures/stderr; import, asset audit,120 Hz configured boot |
| Native Wellspring | PASS 7 reviewed frames; paid Water/Fire without dummy, Steam/contact, normal/reduced |
| Windows portable | PASS exact PCK/source identity, actual EXE launch, safe close, zero stderr and 7-entry ZIP byte audit |
| Same-export localhost lifecycle | FAILED 300 s deadline (300,939 ms including cleanup); first round/reconnect/spectating observed, second-round completion/stewardship not established |

Use `scripts/run.cmd` for source, or open
`exports/hex-small-grid-20260921/windows/PLAY-HEX.cmd`.
ZIP: `exports/hex-small-grid-20260921/HEX-p55-c7b7694f8d23-Windows-x64.zip`.
Previous protocol 54 fallback: `exports/hex-vision-20260920/windows/PLAY-HEX.cmd`.
Never mix builds. Payloads are local, not in Git or a new GitHub release.

Routes: `SPECIFICATION.md` -> `.agent/OVERHAUL-IMPLEMENTATION.md` ->
`docs/HEX-SMALL-GRID-CHECKPOINT.md`. Curated receipts/logs/frames:
`docs/verification/hex-small-grid-20260921/`. Earlier success/failure attempts
are retained. Full fixture corrections did not change gameplay coefficients.
Historical vision/integration evidence is separately labeled.

Next authorized engineering priority: profile and reduce snapshot/topology cost
on the identical 48 px workload until the unchanged lifecycle and 8.333 ms capacity
gates pass. Current host trace samples spend about 0.4-0.6s capturing/sending a
snapshot; these are trace samples, not a new p95 benchmark. Do not enlarge the
timeout, drop authority or relax validation to manufacture acceptance. Then
measure density-normalized balance and close focused Vortex/Mistcurrent oracles.

No current dense/rendered performance certification, physical two-PC/Internet
acceptance, installer/updater, human art/feel acceptance or pointer promotion.
`docs/current-checkpoint.json` retains its historical P48 delivery in original FLUX.
One integration owner serializes Godot work through isolated-profile wrappers.
Preserve raw runtime/evidence bytes and their Git `-text` rules. Close only owned
helpers; never delete original assets, working evidence, fallbacks or user data.
