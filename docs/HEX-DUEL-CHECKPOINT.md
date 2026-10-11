# H.E.X. Wellspring Duel checkpoint

Status: October 6 build `p56-f7b4ad690503` is ready for local human testing.

[Install and play](../exports/hex-setup-duel-20261006/HEX-Setup-p56-f7b4ad690503.exe) ·
[Portable play](../exports/hex-duel-20261006/windows/PLAY-HEX.cmd) ·
[Portable ZIP](../exports/hex-duel-20261006/HEX-p56-f7b4ad690503-Windows-x64.zip) ·
[Playtest guide](HEX-PLAYTEST.md) ·
[Preserved previous build](../exports/hex-engagement-20261005/windows/PLAY-HEX.cmd).

## What changed

| Area | Playable behavior | Boundary |
|---|---|---|
| Solo Duel Trial | Normal HUD entry or Rest Pavilion service; briefing, four-second countdown, paid combat, results, retry and return | Offline only; existing 72-second opponent schedule and combat rules |
| Objective | Defeat Oh Tipi before the deadline; inspect time, health, paid casts and successful enemy-shot interceptions | Death, timeout and leaving the marked court fail; mutual defeat is not a win |
| Loaner and recovery | Disclosed S. Wayne practice weave with actual saved binding labels; original selected champion/weave restored on return | No loaner save, free resources, mid-run resets or leaking held inputs |
| Wellspring floor | Authored stone and soil continue across exact existing hex ownership, with quiet district finishes | No changed map, collision, field reach, camera, scenery or gameplay balance |
| Runtime experiment | Bounded canonical coordinate-leaf prototype, independent oracle and real paid-load diagnostics | Not promoted: paid fixtures contain packed provenance outside the prototype admission boundary |

The trial is a short repeatable practice encounter, not an adaptive opponent,
campaign or balance certification. An ordinary paid aggressive test cleared it
in 8.18 seconds including the four-second countdown, with 19 paid casts and 11
direct hits. This proves reachability, not an appropriate difficulty curve.

## Evidence and limitations

Final focused checks passed six suites / 483,834 assertions, including 499 against
the actual inherited Bootstrap frame loop. The latter covers neutral countdown,
paid opponent admission, release/repress handling, ordinary movement court exit,
exact terminal freeze and return without saving the loaner weave.

The trial capture contains eleven production-drawing SubViewport images,
including compact 960x540 and 1280x720 layouts. Victory and boundary loss come
from ordinary commands; defeat and timeout captures are explicitly staged layout
fixtures. These are synthetic inputs, not physical input or human acceptance.

Full passed **208 suites / 3,765,007 assertions** with zero failures or stderr,
including source/asset preflight, import, exact runtime identity and configured
120 Hz boot, in 610.079 seconds. All 23 final native PNGs were reviewed: eleven
duel screens and twelve quiet/paid-contact terrain views. Initial terrain review
found dark soil-repeat bars; native interior repetition corrected them and all
twelve final frames passed review. Portable startup/safe close and thirteen
delivery checks pass. Thirty-two native-stub installer checks plus real-payload
verification pass; the isolated installed launcher and rendered game each exit
zero with full safe-close markers, thirty-character art admission and empty stderr.
The same-export three-process localhost lifecycle passed in 54.279 seconds under
the unchanged 120-second watchdog, with all three stderr logs empty. The October 5
setup and portable remain the freshly verified fallback.

| Delivery evidence | File |
|---|---|
| Portable / exact files | [Package](duel-evidence-20261006/package-v1.json), [delivery checks](duel-evidence-20261006/delivery-files-v1.json) |
| Setup / installed play | [Build](duel-evidence-20261006/installer-build-v1.json), [33 checks](duel-evidence-20261006/installer-tests-v1.json), [rendered installed safe close](duel-evidence-20261006/installed-smoke-v1.json) |
| Localhost | [Receipt and log hashes](duel-evidence-20261006/network-v1.json) |

| Artifact | SHA256 |
|---|---|
| Runtime source | `f7b4ad6905032c9f484ed45a94992274596c15c8fae0ede7ac56be1a11325d5a` |
| Game PCK | `0e9fd2e9abb0ec76181f9104c38866cbcf05f0370768a03e45ad93557c69599a` |
| Portable ZIP, 115,987,557 bytes | `0cee80e38ac07d3efca488458521d4d8a3b06cb49a52448d628f124f630efead` |
| Setup EXE, 116,017,664 bytes | `e3711381bc0d565d68811773b7e0efdcb662b43fe6b98a6d1866c5ba965a3a6b` |

Removed only the duplicate 115,987,557-byte installer staging ZIP after proving
it byte-identical to the retained portable ZIP; embedded setup and prior builds
remain. Original assets, starting dirty changes and failed diagnostic receipts
are preserved. No commit, push, publication or historical pointer promotion.

[Full receipt](duel-evidence-20261006/full-v1.json) ·
[Trial capture](duel-evidence-20261006/trial/trial-receipt.json) ·
[Ground capture](duel-evidence-20261006/ground/receipt.json) ·
[Visual review and known nits](duel-evidence-20261006/review.json).

Known minor presentation residue: the background court still labels its normal
mode FIRST 3 and the rival's world label is TRAVELLER 2; the trial UI correctly
specifies Oh Tipi and a single-defeat objective. These are queued clarity fixes,
not evidence of a different scoring rule.

The three paid performance fixtures all selected the prototype's unchanged
fallback because their strength ledger contains PackedInt64Array provenance.
The corrected diagnostic passed 2,603 checks plus 261 independent unit assertions.
No allocation savings or speed improvement are claimed. A future experiment
must first demonstrate actual admission and exact bytes, then full-path benefit;
do not promote helper-only results. Production serialization was never changed.

Dense 120 Hz remains unaccepted. The configured limit remains eight players;
16/32/64 are unsupported. Authored advanced animation cycles, physical two-PC
Internet play, deployed relay, signing, public release and automatic online
updates remain open. The existing bundled Windows setup supports offline
installation/update and verified rollback, not an online update feed.

## Next feedback

Can a new player find and understand the trial without this document? Is the
loaner kit clear? Does the marked boundary feel fair? Which is more engaging:
closing in aggressively, intercepting, or using cover? Check that your original
champion and spell weave return unchanged. Difficulty tuning should follow
human answers, not be inferred from an automated clear.
