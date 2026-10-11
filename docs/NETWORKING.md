# H.E.X. friend-session networking

Status: current source boundary, October 11, 2026; experimental friend-session support, not physical Internet acceptance.

The current gameplay source is **p60-be3efd332e1a**, using protocol **60** and
SessionSnapshot schema **24**. Sessions have an eight-player cap, a 120 Hz
authoritative simulation and 60 Hz transport snapshots. Rendering is independent
of those rates. The [specification](../SPECIFICATION.md#authority-and-scope)
owns the full wire contract; the [resume](../.agent/HEX-RESUME.md) identifies
qualified source/packages and measured limits.

## Joining the same game

Host Farflow and Join Farflow are reached through Wellspring's normal navigation.
Both players must use the same complete build. A historical installer shortcut
or another extracted folder can launch different bytes even when its name looks
similar. Compare the displayed build ID; full source/content compatibility
checks remain authoritative. Incompatible clients are refused, not repaired by
relaxing validation.

LAN discovery and direct-address joining are available. Discovery is not an
Internet relay, hosted account service or proof of NAT traversal. Do not change
router, firewall or trust settings implicitly. The
[player guide](PLAYER-GUIDE.md) and [playtest route](HEX-PLAYTEST.md) describe
player-facing checks and their current limitations.

## Authority and transport

| Boundary | Current owner |
|---|---|
| Host admission, commands, epochs and peer lifecycle | [SessionTransport](../src/net/session_transport.gd) |
| Actor/projectile snapshot layout and validation | [SessionSnapshot](../src/net/session_snapshot.gd) |
| Complete world snapshot transaction | [WorldSnapshotEnvelope](../src/net/world_snapshot_envelope.gd) |
| Local movement prediction and reconciliation | [ClientPrediction](../src/net/client_prediction.gd) |

Clients send bounded semantic commands. The host owns paid admission, movement,
projectile contacts, chemistry, damage, statuses, match results and accepted
equipment changes. Local prediction improves response without becoming a
separate authority. Snapshot preparation must validate the complete candidate
before applying it; malformed, stale or incompatible data cannot partly replace
the live world.

The current state includes six finite status channels and expanded delivery
state, in addition to movement, resources and chemistry provenance. Tests must
retain those suffixes rather than hand-build an old shorter row. Transport
packing may compress or fragment a logical snapshot. An MTU claim concerns
every actual transmitted datagram, not the size of an uncompressed dictionary.
Complete state and epoch/refusal checks must survive the round trip.

## Evidence and remaining boundaries

The be3 [Full receipt](performance-qualification-20261010/full-v5.json) includes
the registered networking, snapshot, prediction and real local-process tests.
Those checks establish their named fixtures; they do not certify sustained
eight-player frame time, a second physical PC, Internet reachability or human
multiplayer acceptance. The [performance report](performance-implementation-20261010.md)
also records heavy-field and cold-loading limits relevant to play.

When network/state behavior changes, preserve strict validation and deterministic
replay, run affected suites, and perform the appropriate real-process journey
against the same candidate. Import, source identity, native rendering, exported
bytes, localhost and physical network tests are separate results. Do not reuse
an older pass for changed protocol or gameplay bytes.

Source commit/push authorized on October 11 does not itself create a binary
release or qualify Internet play. Local exports remain ignored build artifacts.
The [exact previous networking document](archive/source-publication-20261011/NETWORKING.md)
preserves protocol-48/schema-18 details as history. `current-checkpoint.json`
remains the September FLUX delivery pointer, not the current H.E.X. recommendation.
