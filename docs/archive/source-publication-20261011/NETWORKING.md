# Friend-session networking

Status: current Windows x64 source contract, updated 2026-09-13. Protocol 48 /
snapshot schema 18 is an unexported integration candidate. The selected Chemistry
P3 portable uses protocol 47; use `docs/current-checkpoint.json` and its referenced
checkpoint document for the exact playable payload and executed acceptance.
This document describes behavior and limits. The single implementation queue in
`.agent/OVERHAUL-IMPLEMENTATION.md` owns outstanding work.

## Host and join

Open a company at Host Farflow in Wellspring; find a LAN host at Join Farflow or
enter the host's address. Controls and session access remain available from the
Wellspring route. The host listens on UDP 24872 by default. LAN discovery uses
UDP 24873 and lists up to 24 recently advertised hosts; a host expires after
3.5 seconds without an advertisement. Reopening Join retries discovery and an
empty browser reports discovery errors instead of keeping a vanished host row.
Direct joining remains available when discovery is unavailable.

The protocol-48 candidate displays a short source-derived build ID. Both players
must extract the same complete portable ZIP into a new folder and launch that
copy directly. An installed shortcut can still start an older build. A mismatch
is refused before roster admission; it is not repaired by relaxing compatibility.
The full runtime source digest, protocol and semantic signature are authoritative;
the short ID is for comparison. A missing or invalid generated identity prevents
network admission. Physical two-PC use remains a separate acceptance gate.

## Authority and bounded input

One host simulates up to eight same-build travellers at 120 Hz. Presentation is
independent; bounded transport snapshots are sent at 60 Hz. A client predicts only
its own movement and reconciles against host state. Damage, costs, collision,
chemistry, station actions, score and outcomes remain host-owned.

The transport processes at most 64 packets per poll. Each of seven remote peers
has up to four queued input records inside a 28-record total. When that peer's
lane fills, the newest continuous state replaces its newest queued record while
carrying displaced action edges. Earlier records remain ordered. Consumption
coalesces edges into one authoritative command per traveller per tick; queued
packets never create extra simulation time. Repeated edges for one action may
coalesce during a hitch. Held input, independent aim and latest movement state
survive; stale/duplicate sequences are discarded. A disconnect purges the old
peer's queued records before a returned actor accepts new input.

The host polls between bounded catch-up ticks. If polling replaces the world or
ends hosting, catch-up exits immediately. The frame loop separately records time
lost to the 100 ms frame clamp and to the eight-step catch-up bound. Neither is
hidden by a simulation-throughput or rendered-FPS claim. Remote continuous input
expires after 250 ms without an update.

## Snapshots and feedback

Snapshot schema 18 carries at most eight players, 128 projectiles, 32 fields,
128 deposits, 32 reactions, four targets and twelve semantic events. Gameplay
admission uses the bounded runtime capacities. Complete snapshots may occupy
multiple MTU-sized fragments: up to 32 fragments with 1,152-byte payloads, inside
a 32,768-byte expansion cap and three pending assemblies. The 1,392-byte ENet MTU
is a datagram boundary, not a promise that an entire full snapshot fits one packet.

Semantic events carry stable IDs and remain pending for four acknowledged
captures. Clients keep a bounded 64-ID inbox to avoid replaying repeated feedback.
When the twelve-event lane fills, exact existing event catalogs prioritize
session/refusal/round confirmations, then outcomes, then cosmetics. Equal-tier
pressure removes the oldest eligible item. Valid capacity evictions/discards
increment saturating snapshot overflow slot 2; invalid events do not. Further
pressure refreshes a four-snapshot quiet window. New event mutation invalidates
an outstanding capture acknowledgement, so unsent events do not age prematurely.

This counter describes pending-lane pressure, not a known number of cues missed
by a player. Some evicted events may already have been delivered. The candidate
shows a brief FEEDBACK BUSY suffix while preserving ordinary session/score text;
projectile overflow remains distinct. This changes feedback selection and
visibility, not host damage, chemistry or resource state.

## Shared play and continuity

| Charter | Places | Traveller damage | Practice Bell |
| --- | ---: | --- | --- |
| Open Commons | 8 | Off; common team | Any traveller |
| Sparring Circle | 4 | On; individual teams | Any traveller |
| Duel Knot | 2 | On; individual teams | Host only |

The host seals the charter before opening the company. The Session Hearth tracks
readiness and begins a synchronized court countdown. Host-authorized station
requests manage practice, champion attunement and twelve configurable spell
positions. The library request lane has 64 bounded indices; the host resolves
actual selectable records from the current catalog.

Court scoring, knockout, respawn, results and return to the Hearth are
host-authoritative. A late guest observes the current round with movement and
combat authority disabled, then participates after the shared Hearth return.
The Company Ledger selects guests; Parting Bell removal and host closure require
a second confirming action. Administrative removal clears return permission.

An ordinary connection loss reserves the actor for 15 seconds. Return uses a
memory-only, endpoint/build-scoped random capability and matching name; successful
return rotates it. Expiry removes the reservation. Restarting the client does
not preserve that capability. Tokens do not appear in rosters, snapshots or logs.
Player names are bounded to 15 safe characters. Speech defaults to T on keyboard;
the new controller layout uses Start, while P3 retains its earlier binding.

## Identity and evidence

The generated `content/runtime/runtime_build_identity_v1.json` fingerprints
canonical production source and resource records, protocol, snapshot schema and
the pinned engine identity. It excludes itself and non-runtime tests/evidence.
`scripts/runtime-build-identity.ps1 -Mode Check` independently recomputes it;
current-state and export validation reject drift. Generation belongs to the
integration owner before source freeze. A displayed build ID is neither a release
label nor proof of human acceptance.

The semantic compatibility signature also covers fixed tick rate, movement,
action transitions, map, abilities, champions, charter/reaction catalogs and
snapshot world-boundary rules. HELLO and ACCEPT validate the full identities;
structured rejection codes produce bounded local recovery text.

The integration owner alone runs `scripts/smoke-farflow.ps1` and other Godot
wrappers in this checkout. The maintained lifecycle fixture exercises join,
movement reconciliation, shared Hearth/court entry, observation, return, rematch
and stewardship using isolated local processes. A fresh exact-export localhost
pass is separate from unit tests, physical two-PC/WAN play, rendered performance,
portable packaging, installer/updater work and human acceptance. Historical
receipts remain attached to their original checkpoints and do not verify changed
source. Windows x64 is the active platform; no publication is automatic.
