# H.E.X. friend-session networking

Status: current source boundary, October 12, 2026; experimental friend-session
support. Current local impairment evidence is separate from physical Internet
acceptance and frame-rate qualification.

The current audit implementation retains protocol **60** and
SessionSnapshot schema **24**. Sessions have an eight-player cap, a 120 Hz
authoritative simulation and 60 Hz transport snapshots. Rendering is independent
of those rates. The [specification](../SPECIFICATION.md#authority-and-scope)
owns the full wire contract; the [resume](../.agent/HEX-RESUME.md) identifies
qualified source/packages and measured limits.

The [runtime manifest](../content/runtime/runtime_build_identity_v1.json) is the
generated production-byte identity; it must be regenerated and checked after
source freeze before a changed build is qualified. The preserved
`p60-d8e6ea1cd808` portable precedes the
[October 12 implementation](implementation-20261012/README.md). Its Full receipt
and historical FPS do not qualify these changes. Matching protocol numbers alone
do not make different source builds compatible.

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

Unadmitted ENet connections now have a five-second HELLO deadline. A silent
peer cannot occupy one of the seven guest slots indefinitely. Admission removes
the deadline; ordinary disconnect/reconnect reservations retain their behavior.
The first successfully sent refusal receives one bounded delivery grace so a
client can read the reason even at the deadline. Repeated malformed HELLOs do
not renew that grace. Expiry creates neither an actor nor a return reservation.
The `session-admission-deadline` test fills all seven real local ENet slots,
checks refusal delivery and reclamation, then admits an ordinary guest.

## Evidence and remaining boundaries

The current [network impairment fixture](../tests/network/test_network_impairment.gd)
uses real ENet loopback and the concrete Wellspring publication path. It runs
four deterministic profiles at both **two and eight players**: delay, jitter,
unreliable snapshot/correction loss, and an outage followed by recovery and an
actual reconnect. Tick-based delay/loss is injected before the real socket-send
boundary; reliable command order is preserved. Actors step ordinary paid combat.

After recovery, every client must match the host's complete canonical world hash
and local predicted actor scalars, acknowledge the final input sequence and empty
its pending inputs. The fixture records transient prediction-history overflow
before reconciliation can clear it, requires the outage to exercise that bound,
checks bounded injected queues, and rejects actual socket-send failures. Reconnect
must retain the same actor identity. Root's strict focused run passed **34,192
assertions with empty stderr** across those eight cases.

These are bounded local correctness and recovery witnesses. Injected simulation
ticks are not measured Internet RTT, localhost runs are not a second physical PC,
and capture/send timings are not frame time or sustained eight-player throughput.
The current candidate still needs its own Full and packaged journey gates; older
[d8 qualification](audit-implementation-20261011/README.md) and
[be3 Full receipt](performance-qualification-20261010/full-v5.json) remain historical.

An experimental producer-only encoded-size witness preserved exact packet bytes
but showed no reliable timing benefit in the controlled probe. It was rejected
and the production patch reverted: producer consumption still validates the
current snapshot's encoded size. No network speedup is claimed from this work.

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
