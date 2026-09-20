# HEX unified sight checkpoint

Status: VERIFIED LOCAL PLAYTEST CANDIDATE, paused for human testing, September 20, 2026.

Historical checkpoint: the current build and publication status are in
[HEX-SMALL-GRID-CHECKPOINT.md](HEX-SMALL-GRID-CHECKPOINT.md). Results below apply
to the preserved protocol54 sight build, not the later 48 px grid.

Worktree: `C:\Users\sende\Projects\hex`, dirty main based on
`843d9efadb62b2dbbea9fc320e862e4ea494e3a5`. Original FLUX is preserved.
Runtime: **p54-6dc4e976f925**;
SHA256 `6dc4e976f925497b1009200757410c4b1a7834ae32bf2bbb31d24396b5de6f31`.
Protocol54 / SessionSnapshot21 / HexWorldSnapshot3 / chemistry3 / envelope1.

## Outcome and acceptance

The user selected one always-on, 360-degree character-centered view. Its common
range is 720 ground units under the existing 55-degree ground projection. Aim,
camera zoom and old vision settings cannot grant extra sight. Opaque authored
buildings and active solid hex cover hide other bodies, names, health, speech
and attached feedback. Low cover and transparent unified Steam retain their
existing policy. Spectators use their followed living character's sight.
Missing/dead viewpoints fail closed. The living viewpoint owner's exact body
pixels remain readable above fog; this does not reveal surrounding world pixels.

Characters and LOS use the same interpolated ground positions. Contact sounds
and interception feedback use the shared predicate. Beam/spray cues additionally
check their endpoints. Existing Full/cone and custom sight values migrate to
Relative/360/720, preserving controls, camera zoom, movement reference, audio
and custom weaves. F8/F9/F10 no longer switch vision. Compatibility binding
metadata remains. In-game F4 help documents the new rule.

This is local presentation visibility, not server-side information redaction.
Supported snapshots still contain world state. No simulation, spell, movement,
cost, chemistry, collision, networking schema or character-art changes.

## Evidence

- Final Focused v4: PASS, seven suites / 4,780 assertions, zero failures/stderr.
- Before: freshly captured preserved `p54-8cb4def57da9` PCK in legacy Full mode;
  twelve native frames. This is an old-runtime comparison, not a new-source gate.
- Final after v2: twelve native frames, PASS / zero stderr. All 65 trace hashes
  and all twelve captured-state hashes match the before run. Normal/reduced
  actor visibility and authority are identical. Final images are byte-identical
  to the visually reviewed development capture; comparison.json records checks.
- Independent code review corrected lane-source and anchored-cue interpolation
  mismatches, added ingestion regressions, then found no further blocking issue.
- Frozen Full v2: PASS, 157 suites / 775,578 assertions, zero failures/stderr,
  import, asset audit and 120Hz boot; 212.700s. All registered suites ran.
- Fixture Focused v5: PASS, two suites / 3,301 assertions, zero failures/stderr.
- Windows portable: PASS, exact executed PCK identity, actual native EXE launch,
  safe close, zero stderr; every ZIP entry matches the payload bytes.
  PCK SHA256 `f335da6277e5e6138b5c59e0d868d0f0328dec452a5a0fe8d68aad83012d59d2`.
  ZIP SHA256 `a6a6e8121bf4ffe9e6a4e42064bff4e92b9ca94a69711a339282765ef58bdc6f`.

Raw receipts: `docs/evidence/hex-vision-20260920/`; referenced logs remain under
their recorded `.godot` paths. Final curated receipts, logs and frames are
in `docs/verification/hex-vision-20260920/`. Failed attempts are retained:
v1 preflight found the previous reaction review lacked an explicit Status line;
v2 had 48 repeated test-oracle errors expecting removal of the intentional
owned-body overlay. No runtime defect was hidden by the corrected assertion:
v3 verifies the repaint contains only the living viewpoint owner and excludes
the dead viewpoint owner. Remaining visibility assertions passed in v2 and v3. Full v1 exposed two
older test assumptions: feedback without session initialization and an exact
indentation check for the body fallback. Test-only fixes passed Focused v5 and
Full v2; no game bytes changed. The lower Full assertion total reflects replacing
retired cone-mode cases with unified-sight coverage, not filtering suites.

## Playtest and limits

Open `C:\Users\sende\Projects\hex\exports\hex-vision-20260920\windows\PLAY-HEX.cmd`
for the verified portable. Share/extract
`exports/hex-vision-20260920/HEX-p54-6dc4e976f925-Windows-x64.zip`; keep EXE/PCK
beside each other. Current source: run `scripts/run.cmd` from the HEX checkout.
Old EXEs contain older sight behavior. Walk around
the Recovery Grove pavilion with another character across it. Check concealment
behind the wall, reveal at the corner and clear sight behind your facing. Turn
aim without moving and repeat with reduced effects and each body size. F8-F10
must not change sight; zoom may change framing only. Check your saved controls
and twelve-position weave. Human visual/feel acceptance is still required.

Operational fallback:
`exports/hex-p54-20260920/windows/PLAY-HEX.cmd` (old Full/cone build).
Older selected p48 remains in the original FLUX checkout. Neither is promoted
or overwritten. No commit, push, release, installer or selected-pointer change
is incidental to this correction.

Historical integration evidence remains in HEX-INTEGRATION-CHECKPOINT.md:
localhost lifecycle passed 256.926s, but dense host p95 348.571ms and rendered
frame p95 153-192ms failed their capacity gates. Those are previous-build
measurements, not performance results for this correction. NOT RUN here:
dense performance, fresh networking fixtures, physical two-PC/Internet,
export multiplayer, installer/updater, human acceptance. Presentation filtering
does not establish anti-cheat protection, 120Hz capacity or 120FPS rendering.
