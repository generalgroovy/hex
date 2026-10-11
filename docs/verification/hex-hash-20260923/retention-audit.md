# H.E.X. snapshot retention audit (read-only source review)

Scope: current `C:\Users\sende\Projects\hex` sources and the exact-EXE responsive lifecycle evidence named below. This is a static ownership/cardinality audit plus an evidence reading. It does not assign a cause to the failed lifecycle, and it did not run Godot, tests, imports, exports, or profiling.

## Finding

There is no application-level history of full 2,766-cell worlds. The network snapshot intentionally omits static topology and carries indexed dynamic chemistry (`src/net/hex_chemistry_snapshot.gd:48-50`); the outer snapshot is limited to 32,768 raw bytes (`src/net/hex_world_snapshot.gd:11-18`, `src/net/session_transport.gd:18-24`). The full cell dictionaries arise when the host validates a capture, when a client reconstructs a replica, and when client prediction deep-copies that replica.

At steady state, a connected client can retain **three** topology-bearing worlds:

1. `trusted_hex_template`, created once on first Hex snapshot and retained by `Bootstrap` (`src/app/bootstrap.gd:142-147`, `4586-4591`, `4567-4571`);
2. the current replica `world.hex_court`, reconstructed by `HexWorldSnapshot.prepare()` and assigned to `world` (`src/app/bootstrap.gd:4591-4608`);
3. `client_prediction.hex_authority`, a deliberate deep copy of every mutable `cells/casts/products/...` dictionary (`src/net/client_prediction.gd:274-296`).

While accepting the next snapshot, source permits a transient **fourth** full topology-bearing world: template + current replica + prior prediction copy + the newly prepared candidate. After `world = candidate`, prediction binding builds its new deep copy before replacing the prior `hex_authority`; the intended steady state returns to three. This is a source cardinality, not a measured live-object or heap count. Other references or allocator retention were not measured.

On the host, the authoritative world is persistent. Each synchronous `HexWorldSnapshot.capture()` also calls `prepare()` before publication (`src/net/hex_world_snapshot.gd:73-85`, `119-147`), and `prepare()` constructs a fresh `HexChemistryWorld` from trusted topology (`src/net/hex_world_snapshot.gd:176-185`, `211-245`; `src/net/hex_chemistry_snapshot.gd:223-241`). Thus the application source exposes one additional transient full world per capture, with no parallel capture/history queue in this call path.

## Retained or transient structures and bounds

| Structure | Can contain a full 2,766-cell world? | Static bound / cadence | Ownership and lifetime |
|---|---:|---|---|
| Host `authoritative_session.world.hex_court` | Yes | One current authority; topology codec cap 4,096 cells (`src/net/hex_chemistry_snapshot.gd:14-26`) | Persistent until an epoch replacement; replacement is built separately and committed after validation (`src/net/authoritative_session.gd:391-430`). |
| Host capture validation candidate | Yes | One synchronous transient per capture | `HexWorldSnapshot.capture()` reconstructs and validates a complete world before returning. It is not stored in a history (`src/net/hex_world_snapshot.gd:142-147`). |
| Serialized Hex authority/envelope | No static topology copy | Snapshot raw cap 32,768 bytes; compressed chemistry lane has a 524,288-byte pre-compression guard (`src/net/hex_world_snapshot.gd:11-18`, `286-299`) | Dynamic rows and hashes only. `wrap_hex()` deep-duplicates authority/session once (`src/net/world_snapshot_envelope.gd:34-48`), creating allocation pressure but not a cell dictionary. |
| Fragment assemblies | No | At most 3 assemblies, at most 32 fragments each, 1,152 payload bytes/fragment, 350 ms timeout (`src/net/session_transport.gd:20-24`, `1088-1119`) | Compressed byte parts; erased on completion before decode (`src/net/session_transport.gd:1120-1141`). |
| Completed incoming envelopes | No static topology copy | At most 2 (`src/net/session_transport.gd:109-112`, `1010-1035`) | `poll_envelopes()` transfers the array and clears the transport slot (`src/net/session_transport.gd:664-667`). The selected envelope is then reconstructed into a full candidate. |
| Client trusted template | Yes | One per `Bootstrap`; no reset assignment was found after first creation | Read-only topology source in this path. It persists across same-process epoch/world changes. |
| Client current replica | Yes | One current `world` | Replaced on each accepted newer epoch/tick (`src/app/bootstrap.gd:4580-4608`). |
| Client prediction authority | Yes | One current prediction copy | Rebound after every accepted Hex snapshot (`src/app/bootstrap.gd:4615-4619`). `reset()` releases it on epoch change (`src/net/client_prediction.gd:100-121`; `src/app/bootstrap.gd:4609-4614`). |
| Prediction input history | No | 48 commands (`src/net/client_prediction.gd:5`, `128-152`) | Commands only. Reconciliation replays the remaining commands; it does not retain world snapshots. |
| Reconciliation queues | No | Transport 2 and application order buffer 2 (`src/net/session_transport.gd:109-112`; `src/net/reconciliation_order_buffer.gd:9-17`, `110-115`) | Packed local-player state/surface packets, not a world. |
| Host pending events | No | 12 events (`src/net/session_snapshot.gd:33-38`), each retained for 4 successfully acknowledged snapshots (`src/net/authoritative_session.gd:7-11`, `499-515`, `547-561`) | Deep-copied event dictionaries only. A failed send does not age them, but the 12-event bound still applies. Client seen-ID memory is 64 integers (`src/net/session_event_inbox.gd:5-23`). |
| `ReplayData` | No | `commands` and `expected_hashes` have no explicit length cap (`src/sim/replay/replay_data.gd:5-23`) | It copies commands and stores one hash per tick. `verify()`/`record()` create one simulation world locally but do not store snapshots or a sequence of worlds (`src/sim/replay/replay_data.gd:26-51`). This unbounded log deserves ordinary input-duration discipline, but it is not a 2,766-cell retention path. |

The configured simulation rate is only 120 Hz (`src/sim/core/sim_config.gd:11`, `22-27`). `SNAPSHOT_RATE` is 60 and the interval is `tick_rate / SNAPSHOT_RATE`, so the host attempts a full capture every 2 simulation ticks, nominally 60 captures/s (`src/app/bootstrap.gd:16`, `1053-1061`, `4215-4219`). The lifecycle trace prints only when `world.tick % 30 == 0`; those log rows are a 4 Hz sample of a 60 Hz capture path, not the send cadence (`src/app/bootstrap.gd:1055-1058`). Event redundancy of four successful snapshots therefore spans a nominal 66.7 ms, though slow or failed sends extend wall-clock retention.

## Mutation and ownership hazards

Prediction must not alias the replica or trusted template as a shortcut. `bind_hex_world()` deep-copies all mutable chemistry dictionaries and builds independent collision state (`src/net/client_prediction.gd:274-296`), while `_step_prediction()` mutates that authority through expiry, fracture, product movement, and product effects (`src/net/client_prediction.gd:231-271`). Sharing any of those dictionaries would let unacknowledged local inputs mutate the displayed replica or the trusted topology used to validate later snapshots.

The envelope and queue layers are safer optimization candidates only after allocation evidence. Their dictionaries are deep-duplicated at the envelope boundary, but they do not contain the 2,766-cell static topology. Removing a duplicate without establishing a single-owner handoff could let caller mutation invalidate a queued packet. Likewise, reuse of a prepared chemistry world across replica and prediction would violate the current explicit mutation separation.

## Evidence, with limits

The isolated responsive-stage receipt measured the genuine 2,766-cell topology and reported `world_capture` p50 406.548 ms/max 496.395 ms, `world_prepare` p50 266.051 ms/max 269.142 ms, and `prediction_bind` p50 71.460 ms/max 79.310 ms (`docs/verification/hex-responsive-20260923/runs/hex-snapshot-stages-responsive-stages-v1.json:40`, `113-164`, `168`). These are five isolated repetitions against one fixed workload; they establish cost, not retention or the 300-second failure cause.

The exact-EXE lifecycle receipt is failed after 385,848 ms with a 300-second requested timeout (`docs/verification/hex-responsive-20260923/network/network-responsive-final-v1.json:2-9`). Its 24 sampled host capture/send rows range from 315,119 to 2,509,669 microseconds (`docs/verification/hex-responsive-20260923/runs/hex-network-responsive-final-v1/host.log:13-66`). Host stderr contains JSON parse and allocation errors, while guests contain JSON parse errors (`host.log.err:1-6`, `guest.log.err:1-8`). Those errors are observations only: the current evidence does not prove that retained Hex worlds, serialized snapshots, log capture, or another owner exhausted resources.

## One bounded follow-up after D2 hash specialization

Run a **retention-waterline diagnostic**, without changing 120 Hz simulation, 60 Hz snapshot cadence, workload, topology, queue limits, timeout, or network shape:

1. Under the existing rematch-smoke trace flag, sample once at the existing 30-tick trace interval on each client: process/static memory bytes; `trusted_hex_template.hex_court.cells.size()`; current `world.hex_court.cells.size()`; `client_prediction.hex_authority.cells.size()`; incoming completed-envelope count; pending fragment-assembly count; and the elapsed microseconds separately for `HexWorldSnapshot.prepare()` and `client_prediction.bind_hex_world()` at `src/app/bootstrap.gd:4580-4619`. On the host, record memory immediately before capture, after `capture_envelope()`, and after `broadcast_envelope()` at `src/app/bootstrap.gd:1053-1061`. If instance-lifetime evidence is needed, test-only instrumentation may record instance IDs plus weak references for only the `HexChemistryWorld` instances created by those prepare/bind calls. It must never retain a strong reference, and its report must name that limited tracked population; it cannot account for worlds created elsewhere.
2. Execute the same exact-EXE 300-second localhost host/guest/late-guest lifecycle and externally sample each PID's private bytes/working set once per second. Preserve the existing lifecycle verdict independently of this diagnostic.
3. Interpret only the bounded ownership question: the three known client fields should each report 2,766 cells after apply, with source permitting a transient fourth world during replacement. Summing those known fields cannot count unreachable worlds, worlds retained by other owners, or prove that an object leaked. A monotonic memory slope with stable known-field cardinality is only a signal for the next narrow probe; it does not prove allocator, serialization, engine, or retention causality. Weak-reference expiry can establish lifetime only for the explicitly tracked prepare/bind instances. Do not optimize by sharing prediction dictionaries unless later evidence isolates that allocation and a replacement preserves independent mutation.

This diagnostic observes the known source-backed multi-world boundary after hash work and can bound the lifetime of explicitly tracked instances without retaining them. It is preferable to changing cadence or retention because those changes would hide the production workload; its result must remain diagnostic and cannot by itself distinguish a leak from high synchronous allocation churn.
