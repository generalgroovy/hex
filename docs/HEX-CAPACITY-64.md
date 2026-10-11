# H.E.X. 64-active-player capacity contract

Status: **64 players UNSUPPORTED.** This is a source audit and next-slice contract,
not a capacity implementation, multiplayer pass or performance certificate.
Audited 2026-10-03 in `C:\Users\sende\Projects\hex`, protected dirty `main`,
HEAD `1559a566e33255c59337c5963f1c3c685d757f1f`. Working source differs extensively
from HEAD; timings from older receipts are not timings of this audit's source.
No production cap, authority rule, networking schema or content was changed here.

## What is supported now

| Requested active champions | Current contract | Diagnostic treatment |
|---|---|---|
| 8 | Session APIs and paid fixture support eight; end-to-end capacity is not established | Run unchanged ordinary paid simulation, both input orders |
| 16 | Unsupported session/fixture; Hearth and Round entity packing also cannot represent ID 16 | Record UNSUPPORTED; create no larger fake world |
| 32 | Unsupported, plus legacy affected-player int32 mask boundary | Record UNSUPPORTED |
| 64 | Unsupported, plus full actor rows exceed raw snapshot ceiling and four targets exceed chemistry tracked-actor allowance | Record UNSUPPORTED |

`SimWorld.players` is a general array and `SimWorld.is_valid()` only validates
configuration/policy/error state. Appending 64 actors and passing that method
would not prove a legal 64-player session, snapshot, roster or prediction world.
Neither 64 cast records nor `MAX_TRACKED_ACTORS = 64` means 64-player support.

"64 active" must eventually mean 64 admitted, independently controlled champions
receiving correct authority, not 64 rows, idle spectators, duplicated render
proxies or an eight-player result multiplied by eight. Current paid diagnostic
actors are alive, stationary automated casters; that is less than this target.

## Exact migration dependencies

| Area and source | Current dependency | Required acceptance before raising capacity |
|---|---|---|
| `src/net/session_transport.gd` | `MAX_PLAYERS = 8`, ENet `MAX_REMOTE_CLIENTS = 7`, entity allocation 2..8, admission/assignment/release guards, roster/reservation accounting | One explicit negotiated capacity; IDs through 64; full-room refusal; expired/resumed reservations; no duplicate IDs; 63 accepted remotes plus host |
| `src/net/session_charter.gd` | `MAX_SUPPORTED_PLAYERS = 8`; Open Commons 8, Sparring Circle 4, Duel Knot 2 | Deliberate new/updated charter and content hash; smaller charter policies remain intact, not silently widened |
| `src/net/authoritative_session.gd` | Registration/input guards use transport limit; seven `SPAWN_OFFSETS`; `_spawn_position()` clamps any larger index to the final offset | Unique deterministic legal spawn selection for actual roster; test blocked anchors and no-clearance fallback; no stacked guests from clamping |
| `src/net/session_hearth.gd` | Max 8; entity mask `0x0f`, status starts at bit 4, ready bit 6; count/capacity header fields are eight bits | Versioned packing: IDs 1..64 require seven bits if directly encoded. Prefer explicit bounded int32 fields or shift all dependent fields together; roundtrip ID 15/16/31/32/63/64, status and ready |
| `src/net/session_round.gd` | Max 8; entity mask `0x0f`; score starts at bit 4; roster/score/winner/spawn-count guards | Versioned score entries; all participants, knockout/respawn/winner/dropout paths and complete second round |
| `src/content/sanctum_campus_layout.gd`, `content/maps/sanctum_campus_g2_v1.json`, `src/app/bootstrap.gd` | Exactly eight arena and eight Hearth anchors; gathering rejects insufficient anchors; ordinary round requires enough spawns | Authored or deterministic verified 64-player placement and clearance, including late spectators and gather/return; do not simply repeat eight anchors |
| `src/net/session_snapshot.gd` | Max 8; ID/owner/event/target/roster validators; fields serialize affected IDs into one `PackedInt32Array` mask, validator requires nonnegative `< (1 << MAX_PLAYERS)` | Versioned actor-set representation. Single signed int32 cannot represent positive bit 31; `1 << 64` is not a valid fix. Use sorted unique IDs or explicitly bounded multiple words; malformed/boundary cases reject |
| `src/net/hex_world_snapshot.gd` | Max 8 champions + 4 targets; 166 int32 values per actor; strict actor ownership/projectile/source relations | Preserve every required field and relation; actor count and budget must agree with accepted tier. IDs remain distinct from target IDs 900..903 |
| `src/net/world_snapshot_envelope.gd` | Names limited by legacy codec's max; names/Hearth/Round must agree with actual champions; raw cap 32,768 bytes | One atomic full session+world state; correct 64 names and admin/round state; no truncation of roster or authority to fit |
| `src/net/hex_chemistry_snapshot.gd` | `MAX_TRACKED_ACTORS = 64` bounds exposure rows; `MAX_FLOW_ROWS = MAX_PRODUCTS * 64`; `_decode_product_states()` separately rejects contact counts above **12**; owner ID allowance 10,000 is not a capacity guarantee | At least the declared total tracked actors, including up to four practice targets, with exact exposure/flow/contact membership; do not drop zero/history rows without canonical semantics |
| `src/net/session_steward.gd`, `src/app/spectator_focus.gd` | Selection/filtering uses eight-player constants; steward cycles the connected roster | Correct release confirmation for final slot; selection removal/reconnect; spectator focus of all actors. Sixty-three sequential guest selections needs a separately accepted usable roster UI |
| `src/app/character_weave_coordinator.gd` | `remember_actor` explicitly rejects entity IDs above 8 | Player 64 can save/reopen/restore its confirmed weave, without cross-player persistence |
| `src/net/client_prediction.gd`, `src/app/bootstrap.gd` | Configure/reconciliation IDs limited to transport max; replica prepares full world; prediction owns a complete chemistry copy | ID 64 reconciles; same epoch/tick geometry, all timed effects and local movement history; failed bind keeps prior context |
| `src/net/lan_lobby.gd`, runtime summary and UI | Lobby clamps capacity/count to transport maximum; summary publishes it | Discovery, actual capacity and UI agree; no advertised tier unsupported by authority |

The chemistry interaction masks in projectile rows (`MASK_LOW_BITS = 31`, five
upper bits in the hex codec) encode 36 chemistry pairs, not player membership.
Do not widen those as a player-count "fix". Distinguish them from the legacy
field affected-player mask above.

### Snapshot byte and workload budgets

Current full actor payload alone, excluding typed-array metadata, session,
projectiles and compressed chemistry:

| Champions | `champions * 166 * 4` bytes |
|---|---:|
| 8 | 5,312 |
| 16 | 10,624 |
| 32 | 21,248 |
| 64 | 42,496 |

Four targets add another 2,656 bytes. Thus 64 actors already exceed 32,768 bytes
before compression can help: the world, envelope and transport all check raw
size. Transport additionally limits fragments to 32 x 1,152 payload bytes,
three incomplete assemblies, a 350 ms assembly timeout and two queued complete
snapshots. A bigger raw limit alone neither establishes delivery nor bounds
loss recovery appropriately. Each accepted peer receives the same full snapshot
packet set; fan-out cost grows with peer count even if capture happens once.
`bootstrap.gd` currently requests snapshots at 60 Hz.

Unchanged gameplay budgets are global 128 projectiles, 16 projectiles per owner,
32 fields, 64 hex cast records and 32 hex products. More importantly,
`HexChemistryWorld._product_capacity_after_cast()` reserves a product slot for
each live unspent cast. Thirty-two product/reservation slots can constrain paid
admissions long before 64 simultaneous casts. Measure attempted/paid/released
casts, refusal reasons and fairness by owner; a room with 64 alive rows is not
proof everyone can cast. Any change to these budgets is an explicit gameplay
and resource-budget decision, not an incidental optimization.

## Practical topology/snapshot migration

The wire already omits static cell geometry: chemistry snapshots send a topology
fingerprint and sparse cast/product allocations by stable cell index. The
remaining expensive representation is local: every world carries a dictionary
for every eligible cell, even when its record is just terrain/elevation/structure.
Capture scans and orders it, rebuilds index/topology bytes, hashes the full
canonical world, and prepares a detached full world before publication.
`_copy_trusted_geometry()` caches one exact template but deep-copies its entire
cell dictionary on restore. Prediction repeats a full deep copy of `cells` and
all mutable lanes in `bind_hex_world()`.

The following is a bounded representation migration, not an ECS rewrite or an
interest-management proposal:

1. **Trusted immutable topology object.** Build from locally validated map and
   geometry at world admission. Own origin, numeric x/y ordered coordinates,
   coordinate-to-index membership, terrain/elevation/structure, collision identity,
   exact existing topology bytes and fingerprint. Retain the separate legacy
   string-key hash order: it is not the same contract as numeric snapshot order.
   Recursively freeze nested collections or keep them private with read-only
   access; a caller-owned mutable dictionary plus a revision counter is not
   immutable. Changing map/origin/metadata creates a new topology and world epoch.
2. **Sparse mutable state.** Own material entries only for occupied cells, with
   existing casts, products, pending, sources, exposure, flow remainder, counters
   and paid ledgers unchanged. Route material writes through `set_cell_amount`
   and `erase_cell_amount`; convert all direct cell readers and validators before
   removing the compatibility view. Allocation clearing, provenance and strict
   reverse membership remain authoritative. Keep static structure separate from
   dynamic product-created collision surfaces.
3. **Prepare atomically with shared topology, detached state.** Incoming snapshots
   resolve only an already admitted local topology ID/hash; never accept geometry
   supplied by a peer. Validate all lane widths/counts/indices/IDs, positivity,
   timing, conservation, provenance, actor/source/projectile relationships and
   canonical hash into a candidate; swap only on full success. Restore and
   prediction may share topology but never materials, ledgers, exposure or flow
   dictionaries. Snapshot failure leaves both replica and prediction unchanged.
4. **Preserve full prediction meaning.** Current prediction advances only local
   movement, but it expires/fractures/moves products and applies timed effects
   against a full chemistry context. Share static topology and copy sparse mutable
   lanes. Preserve complete dynamic context initially: omitting distant products
   could change movement/collision, timers or flow. AOI/deltas would require a
   separate dependency-closure and baseline/loss-recovery design.
5. **Version canonical meaning deliberately.** An initial adapter can reproduce
   the old canonical cell stream exactly for oracle comparison, but streaming
   that whole legacy document still costs bytes/time proportional to topology.
   Do not claim O(active state) hashing from an unchanged full-cell hash. A later
   canonical format can hash the immutable topology identity plus sorted sparse
   dynamic lanes with explicit domain/version tags; bump all affected protocol,
   snapshot/hash identities and reject mixed clients. Keep a test-only legacy
   projection to prove equal semantic state across the migration.

Do not remove producer roundtrip or incoming checks merely to improve the probe.
Once immutability is enforced and validated at construction, avoiding repeated
validation of shared static objects is a sound new invariant; bypassing checks
on today's public mutable `cells` dictionary is not.

## Cheapest high-impact next slice

**Historical proposal, superseded October 4:** E4–E13 have since implemented
bounded immutable topology, sparse ownership, collision reuse, strict lane
decoding, exact canonical-byte reuse and adjacent transport work reductions.
See [current engineering evidence](HEX-SEALED-TOPOLOGY.md) and the single active
queue. The proposal below is retained as rationale, not an instruction to repeat
completed work. Its sustained-load and actual 16/32/64-player gates still apply.

First implement an **eight-player, non-shipping topology-plus-sparse snapshot
candidate** in test/support code, fed by the existing paid fixture and compared
to the production codec. Retain all production limits and full dynamic authority.
This isolates representation cost from the much larger player/protocol change
and targets the known bottleneck before authorizing new tiers.

Required receipt:

- Same admitted local topology and ordinary paid distributed/dense workload,
  normal and reversed input order; exact per-tick semantic state and event trace.
- Cold setup, warm capture, mutating-state capture, prepare, prediction binding,
  hash and packet packing measured separately. Record sample counts, p50/p95/p99,
  maxima, bytes and live allocations. Never add nested inclusive quantiles.
- Compare old and candidate in alternating order on the same states; include
  empty, sparse, legal dense, changed topology, removed source and malformed lanes.
  Synthetic dense hash stress is labeled separately, not counted as paid capacity.
- Wrong topology/map/epoch, stale tick, malformed counts, duplicate IDs, bad
  source/actor ownership, orphan matter and broken conservation reject without
  mutation. Attempted nested topology mutation fails; restored/predicted mutable
  lanes cannot affect the source or one another.
- No new protocol/production path until the candidate shows an absolute cost
  that can fit a declared host/render/snapshot budget. A 50% improvement from
  hundreds of milliseconds still does not approach a 16.667 ms snapshot interval.
- Then integrate one representation slice, run full correctness and unchanged
  paid replay, and repeat same-export lifecycle before any physical/network claim.

After this passes, separately authorize/version the 16 -> 32 -> 64 migration:
ID packing and charter, spawn/layout, actor/byte/event budgets, actual sessions,
prediction/reconnect/rematch/stewardship, and finally rendered/networked human
acceptance. Do not require 64 unique champion art assets merely to represent 64
players; champion catalog choice and actor identity are different concepts.

## Next-bottleneck implementation queue (source-audited, not implemented)

**Historical queue:** implementation status is now owned by the October 4
E9–E13 section and `.agent/OVERHAUL-IMPLEMENTATION.md`. Some representation and
hash work below has shipped in bounded local checkpoints; broader capacity,
protocol migration, sustained cadence and physical internet acceptance have not.

This queue is separate from the current eight-player contact/render optimization
slice. Ship or reject that slice on its own correctness and performance evidence;
do not bundle topology, hash, player-limit or protocol changes into it. The eight
subslices below remain proposed work. Each needs its own bounded implementation,
review and fresh receipt. No new measurements were made for this extension.

### Current cost boundary and representation facts

The current source routes capture through
`HexWorldSnapshot.capture()` ->
`HexChemistrySnapshot._capture_for_outer_roundtrip()` -> wire packing/DEFLATE ->
`HexWorldSnapshot.prepare()` for the complete producer roundtrip. Incoming prepare
also validates map/transition identity, reconstructs chemistry, clones base
collision, rebuilds dynamic surfaces, validates cross-authority relations, and
verifies the outer hash. Existing verified inner-hash reuse and removal of a
redundant nested roundtrip are already present; do not propose them as new work.

| Current representation/call site | Migration consequence |
|---|---|
| `HexWorldDefinition.from_campus()/create_authority()` builds locally validated eligible coordinates; `configure_geometry()` allocates three metadata keys for every cell | Reuse the admitted definition, but introduce an enforced immutable value before sharing cell/index/hash data |
| `HexChemistrySnapshot._trusted_cells()`, `_topology_bytes()` and `_capture_for_outer_roundtrip()` inspect/order all cell records and reconstruct coordinate-to-index mapping | Cache these only behind immutable topology ownership, not `value_revision` or a mutable `cells` object identity |
| `_copy_trusted_geometry()` caches one blank template by exact topology bytes, then `duplicate(true)` copies all blank cells on every hit | A cache hit still costs topology-sized allocation; shared topology plus sparse material maps is the relevant next representation change |
| `HexChemistryWorld._state_hash_bytes()` serializes the complete canonical cell lane; the dense fallback also does so | Unchanged hash bytes retain topology-sized work even after blank-record allocation is removed |
| `HexSnapshotWirePacking._pack_sparse_plane()` already uses a two-byte count plus six bytes per positive allocation: u16 row index, cell index and quantity | There is no dense cell plane to remove from the wire; preserve these lanes initially. Count/index/amount widths become separate gates if chemistry budgets change |
| `_decode_cast_parts()` and `_decode_product_states()` reconstruct zero-quantity covered cells from canonical part/state rows, then cross-check the positive compatibility plane | Sparse means no wholly unused cell entry, **not** no zero quantities. Coverage, provenance and inverse owner membership survive even where integer allocation is zero |
| `ClientPrediction.bind_hex_world()` deep-copies `cells`, casts, products, pending, sources, exposure, flow and metrics | Share only admitted static topology; copy every mutable lane and retain the full dynamic world, not camera-visible state |

Topology ordering has two contracts: numeric x/y order determines snapshot cell
indices and collision face IDs (`FACE_ID_BASE + index * 8 + face`), whereas the
published chemistry hash sorts dictionary keys by their formatted string. A
single newly sorted array cannot replace both without changing bytes or wall
attachment identity.

### S1. Freeze an eight-player semantic oracle and paired cost receipt

Files: `tests/performance/probe_unified_snapshot_cost.gd`,
`tests/performance/profile_unified_wellspring.gd`,
`tests/unit/test_hex_snapshot_optimization.gd`,
`tests/unit/test_hex_chemistry_snapshot.gd`,
`tests/unit/test_hex_world_snapshot.gd`, and new test/support candidate code only.

Use the existing ordinary paid distributed/dense fixture and a detached candidate
projection; do not replace live authority or increase actor/chemistry caps.
Preserve a frozen legacy canonical projection independent of candidate helpers.
Extend the existing three-call inclusive probe with alternating old/candidate
samples and exclusive stage boundaries: topology admission, capture, packing,
prepare, hash, collision preparation, prediction binding, packet construction and
disposal. Record topology count, occupied cells including zero-quantity coverage,
allocation rows, actors, products, bytes and allocation/peak-memory observations.

Gate: identical complete semantic state and event order on paid replay; exact old
snapshot/hash bytes for compatibility stages; malformed data refuses without
mutation. Report cold, quiet warm and mutating states separately. Include legal
dense state and isolated synthetic density stress, without labeling the latter
paid gameplay. Source-identify both arms and do not sum nested stage percentiles.

### S2. Admit one immutable topology value, without changing wire or hash

Files: proposed `src/sim/hex/hex_topology.gd`,
`src/sim/hex/hex_world_definition.gd`,
`src/sim/hex/hex_chemistry_world.gd`, and topology tests alongside
`tests/unit/test_hex_shared_authority.gd` / `test_hex_snapshot_optimization.gd`.

The value owns origin, numeric coordinate order, stable coordinate-to-index lookup,
terrain/elevation/structure, legacy hash order, exact existing topology bytes and
fingerprint, plus the admitted map/definition identity. Keep metadata width at the
existing signed-64-bit topology-byte contract; do not silently narrow it to int32.
Freeze nested collections where supported; never return writable references to
owned packed buffers or metadata. A getter returning the original mutable object
does not establish this invariant. Metadata or coordinate changes create a new
topology value; a live replacement requires explicit world/epoch handling.

Initially attach this value to a candidate/adapter while legacy production remains
the oracle. Do not share today's mutable `CollisionWorld` merely because it is
called static: retain its existing clone until its own construction and mutation
boundary is enforced.

Gate: exact legacy topology bytes, numeric indices and hash order; independently
admitted identical maps agree; reordered input agrees; changed metadata/origin/map
refuses reuse; attempted nested mutation cannot affect any sharer. Keep the old
direct-mutation tests as oracle/import-boundary tests rather than deleting them
to bless a stale topology cache.

### S3. Separate topology membership from sparse mutable material membership

Files: `src/sim/hex/hex_chemistry_world.gd`,
`src/sim/hex/hex_trail_emitter.gd`, `src/sim/hex/hex_collision_world.gd`,
`src/presentation/hex_court_presenter.gd`, and chemistry snapshot readers/writers.

Prefer a coordinate-keyed sparse `cell -> layer -> owner -> amount` reverse index
first: existing footprints, cast parts and products already use `Vector2i` keys.
Use topology indices at serialization boundaries; migrating every geometry caller
to integer handles simultaneously would widen this slice. Retain casts/products
and their part/coverage maps as they are. Route writes through the existing
`set_cell_amount()/erase_cell_amount()` boundary and read topology membership via
an explicit accessor. An empty eligible cell remains traversable/admissible even
when absent from the material dictionary. Remove a sparse cell only after its last
owner entry is erased, not when the sum of its quantities happens to be zero.

Convert conservation's reverse-membership checks and every topology `.cells`
consumer together. `HexTrailEmitter` tests eligibility, collision enumerates full
topology, and the presenter expects blank-cell views; none may substitute active
material keys for all eligible cells. Preserve geometry/presentation revisions and
independent dynamic product surfaces. A detached legacy projection is acceptable
for tests/hash compatibility, but retaining a live duplicate full-cell map defeats
the memory objective.

Gate: exact old semantic/hash projection, allocation removal, ownership and zero
coverage tests; every active reverse entry has a matching cast/product allocation
and vice versa. Recheck sparse **and dense** CPU/memory: dictionary indirection and
duplicated reverse indices can cost more than flat storage at high occupancy.
Select any later dense fallback only from measurement, not an invented threshold.

### S4. Share topology in detached restore and complete prediction binding

Files: `src/net/hex_chemistry_snapshot.gd` (`_prepare`, restore, geometry copying),
`src/net/hex_world_snapshot.gd` (prepare/restore),
`src/net/client_prediction.gd` (`bind_hex_world`),
`src/sim/hex/hex_collision_world.gd`, `src/app/bootstrap.gd`
(`_apply_world_envelope`), and `tests/unit/test_unified_prediction.gd`.

Prepare a candidate with the admitted topology reference and new sparse dynamic
maps. Continue decoding and validating every ledger, part, provenance, timer,
allocation and actor/projectile relation. Clone all mutable products, contacts,
exposure, flow carry, counters and metrics for prediction. Its `_step_prediction`
expires/fractures/moves products, rebuilds cover, applies movement modifiers and
timed product effects; retaining only visible or nearby effects is not equivalent.
Keep actor-local collision exemptions, faces and moving-product surfaces detached.

Make replica-plus-prediction publication transactional. Today bootstrap assigns
`world = candidate` and subsequently calls `bind_hex_world()` without checking its
return; binding itself preserves its previous context on failure. The migration
must stage both contexts before publishing them, including epoch reset and
reconciliation-buffer consequences, so failure cannot pair a new replica with an
old prediction world. Spectator publication remains an explicit separate case.

Gate: two restores and two predictors can mutate independently while sharing the
same topology; wrong map/topology/epoch/tick and failed collision/binding leave all
prior published contexts intact. Exact six-face attachment IDs, stale-wall-contact
clearing, pillar formation/decay, moving flows, pulses and pending-input replay
match the full-world oracle. Keep the producer's full validation roundtrip.

### S5. Version topology-plus-dynamic canonical hashing, as a separate break

Files: `src/sim/hex/hex_chemistry_world.gd`, `src/sim/core/sim_world.gd`,
`src/net/hex_chemistry_snapshot.gd`, `src/net/hex_world_snapshot.gd`,
`src/net/hex_snapshot_wire_packing.gd`, `src/sim/core/sim_config.gd`,
`src/net/session_transport.gd`, and `src/app/runtime_content_summary.gd`.

Only after S2-S4 pass, replace the full-cell canonical lane with an explicit
domain/version, immutable topology identity and deterministically ordered complete
dynamic lanes. Initially include the sparse reverse material index and validate
it; omitting it as derived data needs a separately proved reconstruction invariant.
Keep zero-valued contact/exposure/flow/coverage records where currently meaningful.
Use typed integer/length framing with specified ordering; do not hash dictionary
insertion order or a cached hash of publicly mutable data. A later serializer
optimization may avoid redundant positive allocation planes, but only with the
same validation coverage and a measured benefit; it is not required by this slice.

Current identities are protocol 56, chemistry schema 3, hex-world schema 4,
world-envelope schema 1, legacy session schema 22, and Hearth/Round schema 1.
`HexSnapshotWirePacking.validate_structure()` also contains a literal chemistry
schema check. Bump the affected canonical/schema/protocol/runtime identities as a
coordinated compatibility change; leave unrelated schemas alone. Do not regenerate
the old baseline and call new hash bytes equivalent: compare old/new semantic
projections and retain separate versioned replay expectations.

Gate: complete old/new semantic equality and equal event traces; mixed-version
handshake/wire rejection before publication; every mutable authority lane changes
the new hash; topology admission cost reported separately from warm hashing.
Claim active-state scaling only if no compatibility full-cell scan remains on the
measured capture/prepare/hash path.

### S6. Migrate actor IDs and player sets while admission remains eight

Files: `src/net/session_hearth.gd`, `src/net/session_round.gd`,
`src/net/session_snapshot.gd`, `src/net/world_snapshot_envelope.gd`,
`src/net/hex_world_snapshot.gd`, `src/net/hex_chemistry_snapshot.gd`,
`src/net/client_prediction.gd`, and their focused unit suites.

Separate representable actor IDs from admitted session capacity. Prefer explicit
bounded ID/status/ready and ID/score fields over extending the existing four-bit
packing. For legacy affected-player membership choose a sorted unique bounded ID
lane; it avoids signed-bit-31 and shift-by-64 ambiguity and represents IDs rather
than an implicit dense slot. Give it a schema-defined length and validate every
member. If a fixed 64-slot bitmap is selected instead, specify slot-to-actor mapping
and unsigned-word encoding explicitly; it is not interchangeable with entity IDs.

Unify actor-dependent bounds: champions plus up to four targets, exposure, flow
rows, and the hardcoded **12-contact** product-state decoder. Audit roster/names,
events, reconciliation, target IDs 900..903 and owners together. Preserve the
unrelated 36-chemistry-pair projectile mask. Wider codec fixtures do not authorize
transport admission or fake a legal larger simulation world.

Gate: 1/8/15/16/31/32/63/64 ID boundaries, all statuses/scores, malformed and
duplicate sets, target separation, high-ID owner/source links, and full contact
history roundtrip. New packet schemas reject old layouts explicitly. Admission,
charters, cast limits and advertised capacity remain eight until S7-S8 pass.

### S7. Establish complete-snapshot byte and delivery budgets before new tiers

Files: `src/net/hex_world_snapshot.gd`, `src/net/hex_snapshot_wire_packing.gd`,
`src/net/world_snapshot_envelope.gd`, `src/net/session_transport.gd`,
`src/net/authoritative_session.gd`, `src/net/reconciliation_order_buffer.gd`,
and transport/envelope/prediction tests and paired diagnostics.

Retain all 166 actor values initially. Measure complete legal payloads with actors,
targets, paid chemistry, projectile grazes, names, events, Hearth and Round state.
Actor rows alone for 64 plus four targets are 45,152 bytes, so the current 32,768
raw-byte guard cannot admit that representation. Choose a reviewed bounded raw
budget or a versioned lossless typed actor codec; dropping remote state needed by
prediction is not a compression strategy. Full snapshots remain independently
decodable. Sparse local storage does not itself reduce these already-sparse wire
lanes, and inner DEFLATE plus outer FASTLZ needs measurement, not assumed savings.

Review all three raw caps, decompression limits, fragment count/payload, assembly
count/lifetime, latest-complete queue policy, snapshot cadence and per-peer fan-out
together. Preserve epoch/tick ordering and complete-envelope acceptance under
loss/reorder/duplicate fragments. Raising bytes or changing cadence requires an
explicit latency/memory/bandwidth budget; it is not a free implementation detail.
The current 12-event feedback cap and four-snapshot redundancy/overflow contract
also need per-owner observability at larger tiers; reliable complete authority
does not by itself establish that all players receive useful combat feedback.

Gate: worst accepted tier/workload fits declared bounds with refusal before
oversized allocation; malformed/decompression/fragment stress stays bounded;
reconnect receives a complete baseline; snapshot and reconciliation epochs/ticks
match. Record CPU, bytes, fragments, queue age and host fan-out separately. Host
capture-once does not make 63 outbound deliveries cost-free. No tier is enabled
from a serializer-only result.

### S8. Admit 16, then 32, then 64 only through complete session gates

Files: `src/net/session_transport.gd`, `src/net/session_charter.gd`,
`src/net/authoritative_session.gd`, `src/net/session_round.gd`,
`src/net/session_steward.gd`, `src/net/lan_lobby.gd`,
`src/content/sanctum_campus_layout.gd`, authored map/charter content,
`src/app/bootstrap.gd`, `src/app/spectator_focus.gd`,
`src/app/character_weave_coordinator.gd`, and capacity diagnostics.

Enable each explicit charter/tier only after its codec and complete-state budget
passes. Replace clamped/repeated spawn offsets with deterministic distinct legal
anchors, preserve target IDs and smaller charter rules, and migrate all final-slot
selection/persistence guards. Separately decide admission fairness under unchanged
32 product/reservation slots and other paid budgets; more players does not grant
more simultaneous paid casts. Never silently enlarge those gameplay limits to
make a benchmark look active.

Gate per tier: real admission/full-room refusal, ordinary paid activity and refusal
accounting per owner, input-order replay, latest-slot prediction, return/resume,
spectating/stewardship, knockout/respawn, full rematch/second round and weave
persistence. Then same-export rendered/networked lifecycle and physical human
acceptance at that tier. Until those pass, advertise only the last independently
accepted tier and keep higher counts explicitly unsupported in diagnostics.

## Diagnostic helper and evidence status

Added `tests/performance/profile_capacity_tiers.gd`. It inherits the existing
paid fixture and command scheduler, accepts `--players=8,16,32,64` (or a subset)
and `--ticks=720` or `7200`, and requires a new
`--output=res://.godot/capacity-tiers-<run-id>.json` path. The engine owner can use:

```powershell
& $GodotConsole --headless --path C:\Users\sende\Projects\hex --script res://tests/performance/profile_capacity_tiers.gd -- --players=8,16,32,64 --ticks=720 --output=res://.godot/capacity-tiers-<fresh-run-id>.json
```

Use the repository's existing verified engine path for `$GodotConsole`; the
placeholder is not a request to install or discover a different engine. An
unsupported-only run such as `--players=64` constructs no gameplay fixture.
The helper never widens a limit. Even after future production support changes,
the fixed eight-actor fixture gate remains until a reviewed larger fixture exists.

The measured eight-player path times only `SimWorld.step`; records both command
orders, per-tick state/event trace, ordinary paid admission/refusal/release counts,
alive-actor ticks, active-cell/projectile/cast/product peaks and 8.333 ms misses.
Hashing/accounting is outside each timer but can affect later cache/allocation
behavior. No snapshots, publication queue, cleanup, sockets, rendering, input or
physical clients are exercised. `PASS` means diagnostic correctness only;
`sim_budget_status` and `performance_acceptance` remain separate.

This audit did **not** launch Godot, import, execute tests, profile, capture or
export. Helper parser/runtime verification and fresh measurements are **NOT_RUN**
here; the sole engine owner must record them. No 16/32/64 measurement exists.

Historical context only: the 2026-09-30 accepted-source snapshot probe reported
380.085 / 353.259 ms full capture and 69.668 / 59.392 ms world hash (distributed /
dense), three calls per component. The subsequent 293.197 / 280.552 ms typed-cache
experiment was explicitly rejected and removed; do not use it as shipping cost
or a completed fix. See `headroom-evidence-20260930/friends-readiness/README.md`.
The snapshot-reuse and headroom docs contain older valid scoped correctness
evidence, not current 64-player or full-frame acceptance.
