# H.E.X. resume handoff

Status: **PAUSED at the user's request, October 11, 2026.** Do not continue the
improvement task until asked. The user requested “pause and push at next best
state”; this branch is the resulting source checkpoint.

- Checkout: `/home/otp/Projects/hex-improvements-20261011`.
- Branch: `codex/hex-screen-smoothness-20261011`, remote `generalgroovy/hex`.
- Base: `95ca630e20d11eb140405d45aed7c93636dfbdcb`.
- Current runtime: **p60-33606f016138**, 3,392 production records, protocol 60 /
  snapshot 24. The generated manifest contains the full source hash.
- Current implementation, executed checks, cross-reviews, retained evidence and
  next actions: [presentation checkpoint](../docs/presentation-checkpoint-20261011/README.md).
- No newer portable is promoted. Preserve the older builds and both other
  checkouts, especially dirty user work in `/home/otp/Projects/hex`.
- All specialists are frozen. Root serialized engine runs. Resume with the
  recorded unfinished qualification, not another implementation expansion.

## Historical October 10 / early October 11 handoff

The following records qualify **p60-be3efd332e1a only**. Their completed status
and old Windows checkout path do not describe the newer paused branch above.

Status: **current source checkpoint, October 11, 2026.** Gameplay and local performance qualification completed on October 10; the October 11 request authorizes source cleanup, documentation, commit and push.
Current source identity: **p60-be3efd332e1a**, 3,390 canonical production records,
protocol 60 / snapshot 24. Runtime SHA-256:
`be3efd332e1a9cc584a4cdc4e983c2ce9e5de84ed5a179a0d1152f5ef8237e33`.
The source and final portable above have completed Full validation, native pixel
and timing checks, export/terrain verification and actual visible-EXE measurement.
Play the final portable (`exports/hex-smooth-fields-20261010/windows/PLAY-HEX.cmd`, local only).
First-pass **p60-d649c4d1d99c** remains an unchanged fallback.

Repository: `C:/Users/sende/Projects/hex`, remote `generalgroovy/hex`, branch `main`.
The pre-publication baseline was `1559a566e33255c59337c5963f1c3c685d757f1f`;
use Git history for the current commit. Documents/ChatGPT/H.E.X is a local wrapper.
Preserve original art, user changes, profiles, failed receipts and older portables.
Root owns and serializes all Godot imports, tests, profiling and exports.

[Specification](../SPECIFICATION.md) owns rules; [README](../README.md) and
[player guide](../docs/PLAYER-GUIDE.md) own player instructions;
[one closed queue](OVERHAUL-IMPLEMENTATION.md) records this completed work;
[performance report](../docs/performance-implementation-20261010.md) owns this batch's
implementation, measured results, references and limitations.

## Playable contract

30 profiles and 21 ancestry passives use existing controls. Six ingredients form
63 compositions across eight delivery families: 504 spells and twelve equipped
positions. Finite statuses, 30 earned rival signatures, temporary Range loans,
clearly marked Developer tools and the optional introduction are implemented.
Wellspring has seven districts, thirteen named travel arrivals and 63 physical
Element Garden exhibits. All paid budgets, movement timing, collision, chemistry,
status and visibility rules retain simulation authority at 120 Hz.

Menu → Performance adds Low/Standard visual detail and 60/120/unlimited limits.
Low/60 defaults reduce optional presentation. Reduced Motion remains separate.
The launcher uses `--fullbody-art --pixel-cast`; saved controls and weaves keep the
compatible `Godot/app_userdata/FLUX 2` location. Use 1280×720 for supporting text.

## Current qualification

- Implemented: retained Garden and Range geometry; sparse paid material preparation;
  bounded outline/HUD caches; lossless baked terrain and bounded background loading;
  correct departure/exit ownership; bounded character page residency; batched visibility;
  measured simulation fast paths; compact Performance settings; reusable diagnostics.
- Final shared rendering adds exact fixed-to-pixel geometry, shared fill/layout,
  compatible same-cell boundary deduplication and retained Standard glow, with
  bounded caches and original drawing fallback. Live field inputs stay fresh.
- Import and generated source identity checks passed. **Full v5 passed 244 suites /
  6,880,581 assertions, zero failures and zero stderr, followed by the 120 Hz boot.**
  [Final source receipt](../docs/performance-qualification-20261010/full-v5.json).
- Four focused suites passed **154,856 assertions**, including 5,506 paid-field
  checks. The independent native comparison passed **614 exact RGBA comparisons**,
  including 176 real paid-field phase comparisons and retained/overflow glow.
  [Focused log](../docs/performance-qualification-20261010/shared-paid-focused.log),
  [pixel receipt](../docs/performance-qualification-20261010/shared-paid-equivalence.json).
- Final native v3 completed **25 records / 18 warm rows**, with source unchanged and
  clean wrapper checks. Low mean intervals: Hearth 17.35 ms, Garden entry/middle
  17.44/17.91 ms, all-six Mantle 28.17 ms / 36.25 ms p95, close Fire 25.75 ms /
  39.51 ms p95. Standard Mantle was 27.58 / 33.35 ms; close Fire 24.86 / 39.21 ms.
  Warm rows recorded zero unfocused frames and dropped/clamped time, with about
  119.88–120.42 simulation ticks per wall second.
- Both 60-second Garden loops, Mantle rows and close-Fire rows had no intervals
  above 50 ms. Low distant Fire still had seven of 438 intervals above 50 ms.
  Close Fire includes empty post-expiry time and caches warmed by prior cases;
  it is not a sustained-battle or isolated causal speedup result. Range firing
  produced no occupied paid-ground cells. Startup took 5.54 seconds; Garden
  travel reached 140–177 ms intervals; Range preparation took 1.31–1.32 seconds.
  [Final native receipt](../docs/performance-qualification-20261010/native-final-v3.json),
  [independent raw audit](../docs/performance-qualification-20261010/native-final-v3-audit.json).
- Historical first-pass evidence remains separate: Full v4 243 suites / 6,875,075
  assertions; 440 outline/material/HUD plus 101 complete Range pixel comparisons;
  Performance menu navigation and 1280x720/960x540 layout checks.
- First-pass portable p60-d649c4d1d99c was built at exports/hex-smooth-20261010/windows;
  native startup/safe quit and ZIP byte comparisons passed. Original EXE/PCK
  remain unchanged during diagnostics. All 132 terrain chunks and the overview
  passed exact PCK pixel/provenance verification. Visible portable Hearth averaged
  59.77 FPS and Garden entry 57.57 FPS, against 24.57 and 2.75 in the old visible
  portable. These are sequential engine-FPS observations, not controlled GPU timings.
- Rapid nearby twelve-cast Fire exposed first-pass 11 FPS samples. The matched
  native case averaged 32.80 ms / 70.70 ms p95 with up to 150 visible paid regions.
  Intermediate geometry/palette/layout source p60-6980b3dcafec passed 3,249 focused assertions and
  606 native pixel comparisons, with close Fire improving to 27.27 ms mean /
  48.51 ms p95. These earlier finite measurements do not replace the final native
  source matrix above or prove the final export's performance.
- Final be3 export passed native boot, pixel-bank admission and safe quit. The
  standalone verifier passed **18 checks**, with exact **ten-entry ZIP inventory**,
  payload hashes and unchanged d64 fallback PCK/ZIP. The **153.5 MiB** final ZIP
  and its executable reside under `exports/hex-smooth-fields-20261010`.
  [Package receipt](../docs/performance-qualification-20261010/package-final.json),
  [ZIP verification](../docs/performance-qualification-20261010/zip-verification-final.json).
- Final exported terrain passed **2,062 checks** for all **132 chunks plus the
  overview**, including exact pixels, dimensions, provenance and identity from
  the isolated mounted PCK. [Terrain receipt](../docs/performance-qualification-20261010/terrain-pack-final.json),
  [mount provenance](../docs/performance-qualification-20261010/terrain-pack-provenance-final.json).
- Actual visible final-EXE mean reported FPS: Hearth **57.64** (14 observations,
  46–60); Garden **59.00** (14, 56–61); nearby twelve-Fire sequence **49.125**
  (16, 21–60); all-six Mantle **38.714** (21, 36–50). Both spell cases admitted
  twelve casts with zero refusals; EXE/PCK hashes stayed unchanged and stderr was
  empty. These finite samples include idle after casting/expiry, not sustained
  battle, physical presentation or a flat 60 FPS result.
  [Final visible portable receipt](../docs/performance-qualification-20261010/portable-visible-final.json).
- Repaired terrain lifecycle focused suite: 285 assertions, zero failures. The first
  run exposed two destructive rejection guards; its failed evidence is retained.
- The profiler's completed matrix initially failed PowerShell completion-line counting;
  its original failure is preserved, data independently revalidated and the fixed
  wrapper passed a native check. Current evidence labels that distinction explicitly.

[Qualification evidence](../docs/performance-qualification-20261010/) retains original
failures and exact comparison receipts. Measurements of debug/native callbacks are
separate from packaged engine FPS, GPU duration and physical input/presentation.

## Final package and preserved fallbacks

- Final portable (`exports/hex-smooth-fields-20261010/windows/PLAY-HEX.cmd`, local only): p60-be3efd332e1a.
- Final ZIP (`exports/hex-smooth-fields-20261010/HEX-p60-be3efd332e1a-Windows-x64.zip`, local only): 153.5 MiB.
  ZIP SHA-256: `79c7511324725e6b6661810e7eccac6696388a758be704e287e44ed5057afbd4`.
  PCK SHA-256: `4d75c71cc68845da6053733653f1de405ce69bd897d01402f80709a7a44ea812`.
- First-pass fallback (`exports/hex-smooth-20261010/windows/PLAY-HEX.cmd`, local only):
  p60-d649c4d1d99c, preserved with its own separate receipts.

- October 9 portable (`exports/hex-element-expansion-20261009/windows/PLAY-HEX.cmd`, local only):
  p60-6d80c3bce71e, before this performance work.
- October 9 ZIP (`exports/hex-element-expansion-20261009/HEX-p60-6d80c3bce71e-Windows-x64.zip`, local only),
  with [its own complete evidence](../docs/element-expansion-evidence-20261009/integration.md).
- Earlier animation fallback (`exports/hex-animation-20261009/windows/PLAY-HEX.cmd`, local only):
  p59-a289f67c1acf, with its older spell catalogue and qualification.

## Closure and boundaries

This implementation and local qualification queue is closed. Final be3 package
receipts qualify its own bytes; first-pass receipts remain historical evidence.
Measured heavy-field frame times and cold-load costs above remain real limits,
not an automatic open-ended optimization backlog. The original hidden-window portable
run averaged only 33 FPS at Hearth; the visible run averaged 59.77 FPS with
foreground/visibility observations, so the launch condition is material.
Preserve both receipts and old packages. The October 11 user request explicitly
authorizes committing and pushing the current source and relevant evidence.
See the [publication record](../docs/source-publication-20261011/README.md).
The source push does not create a binary release or installer. Portable builds,
personal profiles, caches and recovery copies remain outside Git.

Human learning, balance, wayfinding, physical input feel, complete authored animation,
dense sustained performance and physical multiplayer remain separate product acceptance;
they do not reopen this completed implementation queue without a new request.
Earlier integration history is linked above; do not restart its completed work as a new queue.
`docs/current-checkpoint.json` remains the historical September FLUX delivery pointer.
