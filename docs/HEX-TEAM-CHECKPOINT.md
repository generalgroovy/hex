# H.E.X. team play and chemistry follow-through

Status: October 7 locally verified Windows checkpoint `p57-a41d15007f8c`; packaged and ready for human testing, not committed or published.

The runnable fallback is [match refinement](HEX-MATCH-REFINEMENT.md),
`p56-2411d5bf5c95`. Its ZIP and game pack were freshly verified unchanged.
One integration owner runs engines and packaging serially. Specialists own
round authority, presentation, chemistry learning, and independent review.

## Play this checkpoint

[Play without installing](../exports/hex-teams-20261007/windows/PLAY-HEX.cmd) ·
[Windows setup EXE](../exports/hex-setup-teams-20261007/HEX-Setup-p57-a41d15007f8c.exe) ·
[Portable ZIP](../exports/hex-teams-20261007/HEX-p57-a41d15007f8c-Windows-x64.zip).

Setup includes the game and needs no Git or Godot installation. Choose **Install
and play**, then use the H.E.X. shortcut. Updating currently means running a newer
trusted setup; **Previous build** provides verified rollback after an update.
Saved controls/weaves are retained. The setup is unsigned; keep Windows security
enabled and proceed only if you trust the source. No public release, automatic
online update feed or deployed Internet relay is implied by these local files.

## What changes

| Feature | Actual contract |
|---|---|
| Duos / Trios | Exactly four / six connected ready participants; frozen alternating sorted roster; two equal teams |
| Scoring | Enemy knockouts award shared points; first to three, 90-second deadline, simultaneous winning ties draw |
| Departures | Earned points persist; losing every member forfeits; reused IDs are inactive observers, not historical participants |
| Team readability | AMBER/TEAL and YOU/ALLY/ENEMY text; complete rosters, local respawn clock, ready/waiting and explicit team results |
| Damage disclosure | No blanket friendly-fire immunity: shared Fire, Steam and Conflagration can harm allies and self without awarding points |
| Rematch | Return restores Hearth charter teams; next round locks a fresh equal roster; reserved reconnect preserves active/result teams |
| Experiment follow-through | Real paid two-Bolt demo retains observed product, cost, effect/counter and retry instructions from restored weave/current bindings |
| Nonmodal learning | Hover for details; Escape/close dismisses; context changes invalidate stale cards; no refund, kit retention or automatic retry |
| Live service help | Farflow details update from actual session state; sealed Charter still explains damage policy; six-row budget preserves the action |
| Disconnect integrity | Retire departed-owner HEX matter/products/collision through the paid ledger; preserve other owners' products and valid snapshots |
| Movement coaching | Wheel-only Jump correctly explains that wallrun needs a held button binding |
| Less repeated work | One team-marker lookup per draw; unrelated input skips chemistry-card formatting; no measured FPS claim |
| Overlay layering | Local team label clears its character; hidden enemies stay hidden; modal/chemistry cards suppress the LAN browser, not discovery |

Wire compatibility changes to protocol **57**, SessionSnapshot **23**,
SessionRound **2**. Everyone must use the same new package; the prior p56 build
is not a compatible peer. No gameplay tick-rate or player-cap increase.

## Acceptance gates

| Gate | Current state |
|---|---|
| Import / focused tests | [PASS](team-checkpoint-evidence-20261007/focused-v2.json): three focused suites / 727 assertions, zero stderr |
| Final Full / source freeze | [PASS](team-checkpoint-evidence-20261007/full-v3.json): 219 suites / 3,877,314 assertions, zero failures/stderr; import, identity and configured 120 Hz startup passed |
| Native 960x540 / 1280x720 | [Reviewed with limits](team-checkpoint-evidence-20261007/review.json): 48 frames, actual Bootstrap, staged team fixtures and two real paid chemistry casts |
| Same-export Duos | [PASS](team-checkpoint-evidence-20261007/network-duos/receipt.json): four clients, exact identity/team roster, result, Hearth return and second round; zero stderr |
| Same-export Trios | [PASS](team-checkpoint-evidence-20261007/network-trios/receipt.json): six clients, same lifecycle and identity/team checks; zero stderr |
| Existing session lifecycle | [PASS](team-checkpoint-evidence-20261007/network-general.json): three clients, late spectator, movement reconciliation, exact-actor return, rematch and reason-bearing host release; zero stderr |
| Portable / file checks | [Portable PASS](team-checkpoint-evidence-20261007/portable.json); [16 checks PASS](team-checkpoint-evidence-20261007/delivery-files.json), including preserved fallback |
| Installer | [33 checks PASS](team-checkpoint-evidence-20261007/installer-tests.json), including isolated installation of the real payload |
| Installed safe close | [PASS](team-checkpoint-evidence-20261007/installed-smoke/receipt.json): rendered startup and 30-identity admission; launcher/game exit 0, zero stderr, no forced stop |
| Independent handoff audit | [No concrete blockers](team-checkpoint-evidence-20261007/release-audit.json): artifact/receipt/log identities, all ten ZIP entries, 48 PNGs and 99 local documentation links verified |
| Human balance, beginner retry and Internet play | NOT_RUN |
| Dense 120 Hz timing | FAILED historical gate; not repaired or requalified by this feature slice |

Current source tests distinguish paid contact from score injection, strict
packet restoration from mere encoding, absent historical rows from live actors,
and actual input/draw integration from standalone text helpers. Native team
screenshots stage scores/positions for inspection and do not prove earned
victories, human clarity, capacity or physical networking.

Frozen runtime identity: **p57-a41d15007f8c**, 3,109 canonical production records,
SHA-256 `a41d15007f8c03e9dff3968703793cfbe2afacdd7172dfaf4ef04fadccf34c2f`.
The final Full run took 633,379 ms; that is test-run duration, not gameplay timing.
The source/asset audit and native hashes identify the tested implementation;
package identity is separately verified by the delivery receipts. Duos took
71,648 ms and Trios 98,848 ms to complete their scripted local lifecycle; these
are process/marker wall-clock durations, not measured tick throughput or latency.
Both runs isolate each participant's profile and stop only their owned headless
children after completion. Normal closing is proven separately by installed smoke.

## Artifact identity and cleanup

| Artifact | Size / SHA-256 |
|---|---|
| Game pack | `03a4f84402b250c216ead90d96baaf8e4e5d7fa9ab502350772285b90576eff5` |
| Portable ZIP | 116,031,843 bytes; `b711a9418fe549cab370a8708d1e534342be2c855da05e081be72d39e6f1a49b` |
| Setup EXE | 116,062,208 bytes; `6550effbe1aca6cf594813095744a9c1de967b7917527eb0ffabb0bd3d442e5d` |

Removed only this run's hash-identical installer-staging `payload.zip`
(116,031,843 bytes); its complete contents remain in the retained portable ZIP
and embedded setup. The evidence folder is ignored by Godot, and its 48
regenerable screenshot-import sidecars were removed. Screenshots, failed and
successful receipts, original assets, user edits and working packages remain.

The first Full attempt was deliberately interrupted for the local-label draw
correction. The second completed with three failed assertions and directory
fixture errors: an obsolete inline label call, a RESULT packet missing its
required reason, and a harness that omitted the real SessionSteward normally
created by `_ready`. Test-only corrections preserve and strengthen the intended
checks. The first corrected focused attempt then exposed CRLF-sensitive source
inspection; normalization fixes that portability issue. Only the final fresh
passing Full run may count as complete acceptance.

At 960x540, world labels still have coarse thin strokes; static inspection is
not human readability acceptance. Defeated local players intentionally have no
living POV observer during respawn, so the empty court view is not a missing-
sprite defect. Native records explicitly distinguish hidden living actors from
defeated actors. No new character-art or completed-action-cycle claim is made.

## Five-minute playtest after packaging

1. Check every participant has the same build. Before hosting, choose Duos or
   Trios in Farflow; fill exactly four or six places and mark everyone ready.
2. Start at the Hearth. Identify teammates using text and color, land enemy
   knockouts, inspect the team score, then return and rematch.
3. Check shared Fire/Steam damage deliberately with a teammate; self/ally
   knockouts must not award points. A late joiner observes until next match.
4. Offline, run a paid first-four chemistry demonstration. Read its retained
   result, hover for details, and reproduce it with the displayed current keys.
5. Close normally. Setup/portable behavior must preserve controls and weaves.

No commit, push, public release, relay deployment, account change or historical
checkpoint-pointer promotion was performed. The legacy `current-checkpoint.json`
does not select this package; the current README, playtest and resume documents do.
