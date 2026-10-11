# H.E.X. contextual Spell Loom availability — September 23

Status: **E1 p55-c5d0f6accb97 is verified and locally packaged for human review.**
D6 p55-1b26a51136d1 remains the preserved operational fallback. The selected
checkpoint pointer is unchanged; no publication or promotion occurred.

## Outcome and acceptance

Players can inspect all spells and preview a starter kit anywhere the Loom is
offered. Final Assign/Apply must explain when current authority would reject the
request: station/round/action eligibility, cooldown removal or pending confirmation.
Do not send a known-unavailable request. Eligible assignments must still pass the
ordinary request/confirmation/save path, close safely, resume movement and allow
a paid cast. Keep the offline Hex Court exception and Gallery station eligibility.
No content, saved IDs, cooldown semantics, movement, combat or networking changes.

## Ownership and preserved baseline

Root is the sole integration/engine owner and owns the native diagnostic,
orchestration, evidence, documentation and generated identity. The bounded worker
owns only Bootstrap, CharacterWeavePolicy, SpellLoomEditor, SpellLoomPresenter and
their three existing unit suites. Independent Astra review owns only review.md.
No overlapping runtime edits or worker engine execution.

baseline.json records dirty main, origin/HEAD, no staged changes, fifteen original
files and39 protected hashes. Original bytes are in baseline-source. The D6 PCK,
ZIP, older fallbacks, art, profiles and selected checkpoint are retained.

## Fresh development evidence

- Before-v1 (LIMITED, superseded): preserved D6 Windows PCK, ordinary Chemistry Matrix -> Spell Loom,
  station Interact, assignment, movement and paid Water Heavy. PASS42 checks,
  nine native frames, zero failures/stderr. It reproduces active assignment
  controls and requests subsequently refused for distance/action/cooldown.
  Its round fixture omitted participants and decoded to the Hearth fallback;
  that row does not prove active-round refusal. Arranged state locks, pending state and positions are fixtures;
  this does not prove live multiplayer or physical input. Logs, script and PNGs
  are preserved in runs/loom-availability-before-v1.

- Focused-v1 PASS5 suites/5277 assertions/zero failures/stderr on regenerated
  p55-c5d0f6accb97. Source identity contains2800 production records; protocol55,
  SessionSnapshot21 and all chemistry/network schema versions stay unchanged.
- After-v1 FAILED3 of65 checks, ten frames. It correctly exposed the invalid
  root-owned round fixture above; source policy returned Hearth availability.
  The diagnostic was repaired with a valid two-participant round packet and an
  explicit decoded-phase assertion. No production change was made for this failure.
- Before-v2 PASS53 checks/nine frames/zero failures/stderr. Every refused attempt
  now checks the matching authority refusal event and unchanged saved-file hash.
- After-v2 PASS78 checks/ten frames/zero failures/stderr. Six unavailable paths
  send no request and emit no authority event or saved-weave write. Native
  captures include distance, action, round, stale preview, cooldown and pending
  states; eligible assignment confirms/saves, closes, moves and pays Water Heavy.
  Its raw Flux delta18000 is18 Flux in fixed-point units. This is injected input
  and arranged eligibility state, not physical input or network lifecycle proof.
- Modal availability query:128 raw samples per state,10 states. Source p50
  1–89microseconds and p95 2–119microseconds. This excludes drawing, simulation
  and transport; it is not evidence of frame-rate improvement or stress capacity.

- Final Full-v1 PASS160 suites/805129 assertions/zero failures/stderr,243972ms.
  Import, asset audit and configured120Hz boot pass on the frozen runtime identity.
  This includes the existing single-engine localhost ENet suites; it is not the
  separate multi-EXE lifecycle or physical two-PC acceptance.
- Package-v1 FAILED exact-EXE launch: export rescanning selected three verbatim
  class declarations under this evidence directory, which is excluded from PCK.
  Missing-type parse errors prevented Bootstrap initialization and the120-second
  safe-quit watchdog expired. Full-v1 remains valid source evidence, not package
  acceptance. The failed export has a DO-NOT-USE marker and remains preserved.
  class-cache-failed-v1.cfg records the incorrect paths. The repair adds .gdignore
  to this evidence root and a canonical-class-path check immediately after export.
  Production source/identity is unchanged. Full-v2 and a separate v2 export
  below provide the repaired playable delivery.
- Full-v2 PASS160 suites/805129 assertions/zero failures/stderr,225352ms, after
  the evidence-import repair. Import, canonical registry, assets and120Hz boot
  pass. The three Loom classes again resolve to their canonical src paths.

- Exact Windows v2 EXE launch/safe close PASS, correct runtime identity; canonical
  post-export registry151/151 with zero violations. Seven ZIP entries pass CRC
  and byte-for-byte payload comparison. Native EXE smoke is separate from the
  following pinned-engine diagnostic runs against its exact mounted PCK.
- Exact PCK availability PASS78checks/10frames; all10 source/PCK RGBA pairs match.
  Query p50 1–86us, p95 2–118us over128samples/state; not a frame/capacity measure.
- Exact PCK basic movement PASS11601checks,192router samples,24paid cast routes,
  all three sizes, focus loss and low Flux cases. Advanced movement PASS5909checks,
  nine Float/air-dodge-fastfall/wall routes. These use injected input.
- Exact PCK Loom assignment, close, movement and paid18Flux Water Heavy PASS;
  confirmed saved weave restores in a separate process with the same isolated profile.
- Exact PCK Water lifecycle PASS888checks/32frames; terrain visibility PASS165
  assertions/31cases. These preserve existing bounded visual/authority checks.
- Curation PASS260 preserved files,53 frozen/protected hashes,7 ZIP entries.
  Source/PCK image equality and raw modal timings are in modal-cost-and-pixels.json.
  Logs and receipts are co-preserved and indexed by evidence-map.json. Original
  isolated test profiles are retained; personal profiles were never substituted.
Historical D6/D8 receipts do not validate changed E1 source. The final-freeze-v1
directory retains all ten source/test/package files and their hashes; development
freezes and failed capture sources/logs/images remain separately preserved.
final-freeze-v2 differs only in the guarded package wrapper; all runtime and test
bytes remain identical. Evidence directories containing script copies must be
ignored by Godot before imports/exports, as this failed attempt demonstrates.

## Delivery and exact identity

Run `exports/hex-loom-availability-20260923-v2/windows/PLAY-HEX.cmd` from the HEX
checkout. For current source run `scripts/run.cmd`. D6 fallback:
`exports/hex-render-frame-20260923/windows/PLAY-HEX.cmd`.
Do not use the failed `exports/hex-loom-availability-20260923/` directory.

- Runtime: p55-c5d0f6accb97; source SHA256
  c5d0f6accb97756c003bf3e72203b430883a178c745342c9b269864be5e91619.
- PCK SHA256: 8102d44fae3d79040bb54e111462e8bf3dbdc5ba1c465ea7f5a9861720014057.
- ZIP: exports/hex-loom-availability-20260923-v2/HEX-p55-c5d0f6accb97-Windows-x64.zip.
  SHA256: a380edd4dfa51a99293b77fb70042a6bd08ae3c64da6e68cc1b84322c20631d9.
- Protocol55 / SessionSnapshot21 / HexWorldSnapshot3 / chemistry3 / envelope1;
  2800 production records. Main HEAD1559a566e33255c59337c5963f1c3c685d757f1f remains dirty.

## Remaining gates and NOT_RUN

E1 does not rerun evolving dense stress or the complete multi-EXE lifecycle.
Historical D6 stress missed1440/1440 frame deadlines; the earlier300s lifecycle
failed with resource/allocation/JSON errors. Neither has a newly established pass.
Full's single-engine localhost tests are separate. Physical two-PC, Internet,
native spectators, physical keyboard/controller feel, human Water/motion/style,
installer/updater and all32spells ×12slots ×30characters remain unaccepted or
NOT_RUN as applicable. The arranged ACTIVE/pending fixture is not a live network
transition. No proposed reaction redesign, balance or named-skin approval occurred.
No commit, push, publication, personal-profile replacement or selected-pointer change.

Next: other bounded action-availability work or a different measured dense-cost
hypothesis. D8 remains deferred after three passes; human gates block only their
branches. Independent review is recorded in review.md.

## Bounded action coverage

| Condition/action | Intended result | Fresh development evidence |
| --- | --- | --- |
| Chemistry Matrix -> Loom away from stations | Inspect all32; preview starter; Assign/Apply disabled with station reason | Native before-v2/after-v2 |
| Free actor at Spell Loom | Confirm selected assignment, save, close, move, paid cast | Native after-v2 and exact PCK; separate-process restart |
| Free actor at Gallery | Existing whole-weave admission remains available | Focused policy/UI fixture |
| Active round/action, dead actor | Disable with current reason | Native round/action; Focused dead actor |
| Removed cooling non-legacy spell | Disable until expiry; retain timers and saved weave | Native cooldown; Focused pure policy |
| Retained cooling spell moved between slots | Keep assignment available and timer attached to spell | Focused pure policy |
| Stale starter preview | Disable final Apply; Cancel/reopen required | Native stale-weave preview and Focused fixture |
| Pending confirmation | Block repeat submission; close without revoking request | Native pending; existing acknowledgement Focused cases |
| Exhausted request sequence | Disable with session-restart instruction | Focused fixture |
| Isolated offline Hex Court | Keep existing station-free exception | Focused fixture; not a fresh native Hex Court journey |

This table is only E1 coverage. It does not certify every spell/slot combination,
all characters, live client failure recovery, controller feel or physical input.
