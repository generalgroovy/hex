# H.E.X. runtime optimization checkpoint

Status: Historical performance checkpoint; current playtest is the
[October 7 match refinement](HEX-MATCH-REFINEMENT.md), `p56-2411d5bf5c95`.
The measurements below remain historical, not a new performance qualification.

Status at completion: October 6 local Windows checkpoint `p56-460db467f9cd` passed Full,
complete-publication comparison, portable, installer, installed safe-close and
same-export localhost checks. Verified `p56-a4d859501f56` remains the fallback.

[Play now](../exports/hex-actor-reuse-20261006/windows/PLAY-HEX.cmd) ·
[Windows setup, 110.6 MiB](../exports/hex-setup-actor-reuse-20261006/HEX-Setup-p56-460db467f9cd.exe) ·
[Portable ZIP](../exports/hex-actor-reuse-20261006/HEX-p56-460db467f9cd-Windows-x64.zip) ·
[Five-minute test](HEX-PLAYTEST.md).

## Changes

Snapshot capture previously constructed and validated detached players, discarded
them, then reconstructed and validated them again. The concrete callback-free
path now retains those already checked objects within that one capture call.
Every incoming player row is still strictly decoded; outer headers, actor sets,
projectiles, chemistry relations and full authority hashes remain checked.
No live actor alias, persistent player cache or caller-supplied trust flag exists.
Extension callbacks retain their previous path. Gameplay, wire bytes and the
eight-player cap are unchanged.

The engine workflow guard now recognizes a departed game PID reused by a
differently named protected process without querying inaccessible properties.
Matching or unknown names remain fail closed when identity is unavailable.
This fixes test-workflow recovery without stopping system or unrelated processes.

The [execution prompt](../.agent/OVERHAUL-PROMPT.md) now directs measured,
independently reviewed optimization through a playable checkpoint, with one
engine owner and disjoint worker ownership.

## Measured results

Four separate processes ran original/candidate/candidate/original. Each used
seven warm samples on every actual eight-character, 11,337-cell fixture.
These are fourteen samples per arm, measuring complete owned capture through
encoded packets, including production admission but excluding sends and rendering.

| Fixture | Original median | Candidate median | Reduction |
|---|---:|---:|---:|
| Empty campus | 16.561 ms | 14.560 ms | 12.09% |
| Distributed paid chemistry | 55.113 ms | 53.464 ms | 2.99% |
| Dense paid chemistry | 29.011 ms | 27.471 ms | 5.31% |
| Active Rampart | 26.966 ms | 24.996 ms | 7.30% |

Every sample is retained. Baseline variation is greater in empty/distributed cases;
the distributed sample ranges overlap. All authority, trace, envelope, session
and packet identities match, and receiver reconstruction and ownership checks pass.
Across 194 recorded dependencies, only the intended production file differs.
See [independent comparison and raw receipts](actor-reuse-evidence-20261006/comparison.json).

Candidate process-global observations increased by 10,556 static bytes and
42,832 peak bytes. This is not a memory reduction or leak-freedom result.
Warm diagnostic improvements do not establish sustained 120 Hz, rendered FPS,
fanout, capacity or Internet acceptance. The dense timing gate remains open.

## Verification

| Fresh gate | Result |
|---|---|
| [Focused](actor-reuse-evidence-20261006/actor-focused-oct6-v2.json) | 7 suites / 19,456 assertions, empty stderr |
| [Full](actor-reuse-evidence-20261006/full-v1.json) | 211 suites / 3,767,675 assertions, zero failures/stderr; import, identity and configured 120 Hz boot pass |
| Publication comparison | Four runs, each 3,230 assertions / zero failures; exact outcomes and receiver restoration |
| [Engine guard](actor-reuse-evidence-20261006/engine-guard.json) | 25 synthetic identity and real isolated PowerShell ownership checks pass |
| [Portable](actor-reuse-evidence-20261006/portable.json) / [files](actor-reuse-evidence-20261006/delivery-files.json) | Export/native startup/safe close, 13 delivery checks and fallback hashes pass |
| [Installer](actor-reuse-evidence-20261006/installer-tests.json) | 33 mechanism/real-payload checks pass |
| [Installed game](actor-reuse-evidence-20261006/installed-smoke/receipt.json) | Game and launcher exit 0, empty stderr, no forced stop |
| [Localhost](actor-reuse-evidence-20261006/network-v1.json) | Same-export lifecycle passes in 58.667 seconds; all three stderr logs empty |

Full elapsed 668.024 seconds is validation duration, not gameplay performance.
The existing paid duel still clears in 1,895 ticks with 28 casts, ten direct hits
and 44.138/90 health. No new art or visual behavior was introduced.
The preceding 17 reviewed native frames are historical presentation evidence,
not new rendered-performance or human acceptance.

Early preflight refusals remain recorded: the first profile output name did not
meet its scoped-path rule, and Focused refused stale build identity before any
suite ran. Both were corrected before successful gates.

## Preserved foundations and next target

The prior bounded rule cache and world-space HEAVY countdown remain intact.
Their separate measurements and native review are retained in
[the previous evidence](optimization-evidence-20261006/review.json).
This continuation does not count those earlier changes as new work.

Next measure canonical chemistry assembly and reconstruction, which remain the
larger costs. A one-shot canonical witness is only a deferred hypothesis: retaining
and comparing bytes may cost more than recomputing the digest. Require actual
paid-path admission and complete-path gains before any integration. Keep strict
incoming validation, deterministic output, independent mutable worlds and current
capacity. Human feel, full animation cycles and physical Internet play remain open.

No commit, push, public release, relay deployment or personal-profile installation.
Original assets, unrelated dirty work and prior playable builds remain preserved.
Only the hash-identical setup staging payload.zip was removed, reclaiming
115,994,846 bytes; the portable ZIP and embedded setup retain its contents.
Setup remains unsigned; online auto-updates and Internet relay are not configured.

| Artifact | SHA256 |
|---|---|
| Source, 3,103 records | `460db467f9cd51c9a6de245f811f5c4fa2135bf43d22887cb85a8f243ac490e0` |
| PCK | `d113d93958afd0d9ae41c01efb1e5343224889a85f8e31139039bc98c037b01b` |
| Portable ZIP | `7d7489e6eafdacacfb705e6ff8a385dd1e1bdda6b1f5dbdfdcbd1436945160c4` |
| Setup EXE | `bfe802c17aa29a070b04b12cfcd086d4e5ba64a37293c08bbbe4974eb95efc08` |
