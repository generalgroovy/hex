# H.E.X. match integrity and presentation checkpoint

Status: October 7 local checkpoint `p56-2411d5bf5c95` passed the final source,
native review, package, installer, installed safe-close and localhost gates.
Ready for human testing; no commit, push or publication.

[Play now](../exports/hex-match-refinement-20261007/windows/PLAY-HEX.cmd) ·
[Windows setup, 110.7 MiB](../exports/hex-setup-match-refinement-20261007/HEX-Setup-p56-2411d5bf5c95.exe) ·
[Portable ZIP, 110.6 MiB](../exports/hex-match-refinement-20261007/HEX-p56-2411d5bf5c95-Windows-x64.zip) ·
[Verified fallback](../exports/hex-actor-reuse-20261006/windows/PLAY-HEX.cmd) ·
[Playtest guide](HEX-PLAYTEST.md).

This batch integrates the preceding aspect-refinement work and divides mode
design into separate Duel, Duos, Trios, FFA and offline-activity specialists.
One root owns shared integration and serialized engine runs. Specialists do
not run competing engines or independently rewrite the same round machinery.

## Implemented checkpoint

| Slice | Change | Evidence required |
|---|---|---|
| Fair match outcome | Count all valid defeats from the same completed tick before resolving a score-limit winner; a tied winning trade draws | Both event orders, duplicates, deadline coincidence and exactly one outcome |
| Safe result | Retire pending/flight/ground/product HEX state with existing paid-ledger expiry; clear actor startup and refresh collision | Paid positive controls, immediate strict snapshot restore, harmless RESULT interval, conservation and topology preservation |
| Stable reconnect | Existing ACTIVE/RESULT participants retain their round-owned team; Hearth and observers retain charter behavior | Six sparse IDs, pending respawn, result, observer and rematch invariants |
| Readable FFA | Stable P# labels, YOU marker, all standings, authority-derived local respawn timer, final standings retained | Duplicate names, narrow text lane, native four-player view, observers and no-point notices |
| Contextual map | Cached unseen terrain switches between ordinary court and Solo Duel objective only on activity transition | Real start/retry/leave hooks; unchanged state must not recapture continuously |
| Character rhythm | Full-cast contact poses hold 5/16 each; neutral passes 3/16 each, using existing registered pixels | Boundary/wrap, all headings, casting, size anchors, 30 FPS sampling and non-quarter native board |

No mesh deformation, new combat cost, balance tuning, lobby-cap increase,
protocol change, trail, moving reaction field or orbital effect is introduced.
The gait change is a feel candidate; subjective improvement needs play feedback.
Authored slide/roll/strafe/airborne cycles are not declared complete by timing a
different existing frame. The older 14-aspect fixes are documented separately
in [aspect refinement](HEX-ASPECT-REFINEMENT.md).

## Honest mode support

| Activity | Actual current contract | Next meaningful acceptance |
|---|---|---|
| 1v1 Duel Knot | Two-place charter; first to 3, 90 seconds, 1.8s respawn, 1.2s protection, explicit tie | Two humans judge pressure, escapes, spawn fairness and rematch clarity |
| FFA Sparring Circle | Four-place charter with individual scoring and the same court rules | Four humans inspect score identification and spawn pressure |
| 2v2 | Not implemented; four-player FFA is not teams | Exact-four locked 2+2 roster, team score/result/schema/UI and lifecycle |
| 3v3 | Not implemented; six actors in a regression is not a supported team mode | Exact-six locked 3+3 roster, rendered readability and full lifecycle |
| Solo Duel | Offline paid-command rival, one defeat objective, 72s total including 4s ready, retry and restored return | Human readability and feel; native capture separate from deterministic scripted win |
| Open Commons / free practice | Up to eight configured slots, shared-world practice and menu services; capacity is not dense performance acceptance | Physical Internet friend setup and simultaneous interaction |
| Movement practice | Contextual coaching and bounded trace comparison, no scored progression | Discoverability and repeatable useful practice route |
| Chemistry bench | Free experiments plus finite paid two-Bolt guided demo with clear refusal/abort and weave restoration | Player understands ingredient, location, resulting cells and counters |

Shared Fire, Steam and Conflagration can harm allies or self; some direct attacks
and other products exclude allies. Future team help must explain this actual
policy instead of promising blanket friendly-fire immunity.

## Shared team implementation contract

One owner implements team machinery; separate Duos and Trios agents write
independent acceptance fixtures. Lock teams from sorted roster positions, not
entity-ID parity. Preserve assignment across reserved reconnect; preserve team
points after a scorer leaves; score only hostile-team knockouts; resolve when
one team is empty; expose explicit team totals and a team result. Gate exact
participant count before countdown and preserve late-observer/rematch behavior.
Use the existing alternating west/east authored spawn slots as the candidate,
then test room for six-player escape and dynamic cover before redesigning it.
Do not expose either charter until its schema, UI, admission, damage policy,
disconnect and same-export network gates pass together.

## Artwork gate

Two new six-frame landing-contact raster candidates were generated using the
imagegen workflow and preserved with prompts and measured QA under
[art-direction-20261006](art-direction-20261006/landing-contact-candidate-spec.json).
Both failed hard-pixel palette, alpha and frame-registration requirements.
They remain reference-only, excluded from runtime. Existing approved art stays
active. Next asset work should focus on a single corrected native contact or
action cycle with stable foot/head anchors, not another unreviewed full-cast
replacement.

## Acceptance ledger

| Gate | Current state |
|---|---|
| Independent code/assertion review | No actionable P0/P1/P2 finding; runtime execution remains separate |
| Focused | 16 suites executed; one obsolete contact-boundary fixture failed, corrected without production changes |
| Full, import and configured 120Hz boot | PASS: 214 suites / 3,873,725 assertions, zero failures or stderr; 667.963s; source identity `p56-2411d5bf5c95` |
| Native HUD and non-quarter gait review | PASS: 10 frames, 48 contact checks; independent exact-hash and static visual review |
| Portable / file delivery | PASS: exported identity/native startup/safe close; all 16 file checks, fallback ZIP/PCK unchanged |
| Installer | PASS: 33 checks, including isolated real payload installation; unsigned, remote update feed not configured |
| Installed safe close | PASS: rendered startup and 30-identity pixel admission; launcher/game exit 0, zero stderr, no forced stop |
| Same-export localhost | PASS: three-process join, movement, round, late spectator, reconnect, rematch and reason-bearing release; all stderr empty |
| Human feel / listening / physical Internet | Open |
| Sustained dense 120Hz / 16–64 players | Existing timing failure remains; no capacity expansion |

The failed focused run and first Full run remain in the evidence folder. The
focused failure was an old gait-phase fixture; Full attempt 1 found an obsolete
terrain-call source-string expectation. Both fixtures were corrected without
changing production behavior, then the entire Full gate was rerun. Native
capture and independent review cover the same final runtime identity.
[Full receipt](match-refinement-evidence-20261007/full-v2.json) ·
[Native review](match-refinement-evidence-20261007/review.json) ·
[Portable](match-refinement-evidence-20261007/portable.json) ·
[Delivery](match-refinement-evidence-20261007/delivery-files.json) ·
[Installer](match-refinement-evidence-20261007/installer-tests.json) ·
[Installed smoke](match-refinement-evidence-20261007/installed-smoke/receipt.json) ·
[Localhost](match-refinement-evidence-20261007/network-v1.json).

The native contact board is a static boundary review, not timed animation
acceptance; narrow 960x540 text remains coarse. The network harness shuts down
its owned headless processes after required markers; normal shutdown is proven
separately by the installed smoke. No fresh sustained-load benchmark was run.

## Exact package identity

| Artifact | SHA256 |
|---|---|
| Canonical runtime source, 3,105 records | `2411d5bf5c95af3dd89ef48ee2b2015397d192313bf3e0bd401bfce383f21067` |
| PCK | `da0deb44cd81b8f1ac273d407dca6cdc44eb4627889c75d441a1b788323dfb64` |
| Portable ZIP, 116,000,400 bytes | `2b998053de931245b2f736074d9ef62ae3bff17d3a197df016cd53ecd688b49c` |
| Setup, 116,030,464 bytes | `a2d71f0006e52ef4ed29e2411545be6744fff4d92a256632e3ae4a52eb0056ed` |

## Next narrow work

1. Retain the chemistry demo's actual terminal result in a dismissible learning
   card; resolve retry instructions against restored spells and bindings.
2. Implement shared team round/schema/UI machinery with one owner, then run
   independent 2v2 and 3v3 admission/scoring/lifecycle/network acceptance.
3. Author one accepted native-pixel action cycle with stable anchors and test it
   at play scale before extending all identities; do not promote failed art.
4. Profile canonical chemistry publication on paid dense fixtures; keep strict
   incoming validation and unchanged outcomes. Dense timing is still a blocker.

Preserve useful failed receipts and original assets. No commit, push,
publication, hosting change, user-profile installation or personal-memory edit
is part of this local checkpoint.

Cleanup removed only the agent-owned duplicate installer staging `payload.zip`
(116,000,400 bytes) after matching it against both the retained portable ZIP
and the installer's embedded-payload receipt. It is recoverable from those
retained artifacts. Original assets, evidence and previous working builds remain.
