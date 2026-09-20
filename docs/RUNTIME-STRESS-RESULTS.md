# Runtime pressure audit and first optimization

Status: measured source evidence, 2026-09-06. Windows, Godot 4.7.1, AMD Ryzen 3
7320U with Radeon Graphics. These are headless simulation/serialization timings
on this machine during active development, **not rendered FPS, internet or
arbitrary-hardware performance guarantees**. The supported lobby ceiling stays
eight players; 32/64-actor experiments are deliberately offline.

## Repeatable production-path probe

`tests/scenarios/runtime_stress_probe.gd` runs ordinary `SimWorld.step` updates,
real champion/spell content, authoritative collision, real snapshot codecs and
client packet handling. Each scenario runs twice, reversing command input order
on the second run. Checkpoint and final world hashes must match. It verifies
natural projectile/field expiry, exactly one expiry event per injected object,
pending-cast cleanup and release of the previous tick's event batch.

- Legal journey: eight champions, one elemental Burst each, six seconds of paid
  input taps and movement after one second of warmup. No health refill, cooldown
  bypass or per-tick authoritative-state edits. The observed peak is 40 real
  projectiles; fields are not used in this journey.
- Density fixtures: an initial offline state with 256/1,024 real projectile
  objects and 16/32 real fields, followed by ordinary updates and natural
  cleanup. These deliberately exceed admission limits; they do not represent
  legal casts or supported online loads. No lifetime/collision toy simulation
  substitutes for production code.
- Timings include only `SimWorld.step`, excluding command construction, checks,
  periodic diagnostic hashes and presentation. Snapshot capture/packing is
  measured separately at the 60 Hz transport cadence. Initial-state construction
  and cold content import are not included in either timing.
- Percentiles use nearest rank. Timing excursions are reported, not converted
  into flaky machine-specific test failures. Determinism, cleanup and packet
  invariants are assertions. `--require-network-clear` makes a legal-load
  omission/rejected-packet result fail closed.
- The benchmark calls the same read-only `obstacle_view()` API used by
  presentation before each measured tick. Reading scenery cannot silently opt
  the benchmark out of collision acceleration.

Run from the authoritative checkout:

```powershell
. .\scripts\flux2-common.ps1
$probeGodot = Get-FluxGodot
New-Item -ItemType Directory -Path .godot/runtime-audit -Force | Out-Null
Invoke-FluxGodotChecked -GodotBin $probeGodot -Arguments @(
  '--headless', '--path', (Get-FluxRepoRoot),
  '--script', 'res://tests/scenarios/runtime_stress_probe.gd',
  '--', '--quick', '--require-network-clear'
) -LogPath (Join-Path (Get-FluxRepoRoot) '.godot/runtime-audit/acceptance.log') -RejectWarnings
```

Remove `--quick` to run all five scenarios. Select one with
`--scenario=eight-256-projectiles-16-fields`; add `--linear-obstacles` for the
same-content legacy linear control. `--collision-only` runs the isolated
differential suite without waiting for the shared Full gate. Use distinct log
names for concurrent diagnostics; do not run the shared test wrapper in parallel.

## Before: protocol 38 / snapshot 13

Evidence retained at `.godot/runtime-audit/full.log` and `quick.log`, with empty
stderr files. The complete five-scenario diagnostic finished **8,441 assertions,
zero failures**. The pass means the diagnostic's determinism/lifecycle checks
passed; the printed network-coverage finding was explicitly **not accepted**.

The legal eight-player Burst journey exposed two independent defects:

1. Forty live projectiles were simulated, but only eighteen were serialized:
   **22 active threats omitted**.
2. Even that truncated packet reached **1,848 bytes**, over the 1,392-byte guard.
   The complete snapshot was refused in **246 of 360 sampled frames per repeat**.
   Both repeats reproduced the exact counts. An empty packet is counted as a
   rejection, never as a successful zero-byte transmission.

Timing values below are milliseconds, repeat 1 / repeat 2:

| Scenario | Tick median | Tick p95 | Tick p99 | Tick maximum |
|---|---:|---:|---:|---:|
| 8 actors, legal Bursts, peak 40 projectiles | 1.967 / 1.884 | 5.047 / 4.350 | 7.210 / 8.900 | 23.651 / 17.657 |
| 8 actors, 256 projectiles, 16 fields, open map | 8.623 / 8.845 | 13.169 / 11.622 | 15.644 / 13.429 | 21.379 / 13.803 |
| Same assets, 64 obstacles | 21.301 / 20.916 | 29.779 / 21.955 | 41.083 / 23.250 | 44.375 / 28.610 |
| 32 actors, 256 projectiles, 16 fields, 64 obstacles | 41.532 / 44.144 | 60.023 / 64.524 | 74.848 / 77.762 | 92.391 / 111.127 |
| 64 actors, 1,024 projectiles, 32 fields, 64 obstacles | 264.833 / 245.710 | 676.346 / 347.478 | 772.741 / 782.428 | 814.900 / 873.739 |

Every density fixture maintained its complete requested load through the 120-tick
measurement window. Every injected object then expired naturally, with exactly
256/16 or 1,024/32 expiry events. Both repeats produced equal checkpoints/final
hashes. No network attempt is made above eight actors; zeros in those network
columns mean **not attempted**, not an eight-player packet-capacity result.

Adding 64 distant obstacles to the same eight-actor fixture increased median
simulation cost approximately 2.4 times. This measured full-array collision
work, not allocation speculation, selected the first CPU optimization.

## After: complete bounded threat transport

The integration workstream introduced protocol 39 / snapshot 14 and a complete
bounded threat envelope with atomic multi-datagram reconstruction. The updated
probe exercises `SessionTransport._snapshot_wire_packets` and passes reversed
datagrams through the actual client `_handle_packet` path. No partial frame may
publish before the final piece arrives; the one reconstructed dictionary must
equal the source snapshot exactly.

Executed `.godot/runtime-audit/protocol39-quick.log`:

- **6,319 assertions, zero failures, zero stderr**, with
  `--quick --require-network-clear`.
- Same legal peak of **40 projectiles**, **zero omitted threats**, and
  **zero rejected snapshots out of 360 samples in each repeat**.
- At most **three datagrams per sampled frame**, each at most **1,324 bytes**.
  The full raw snapshot reached 7,832 bytes. The former single-packet equivalent
  would reach 2,388 bytes; that diagnostic value is not the actual datagram size.
- Simulation median **1.887 / 1.885 ms**, p95 **3.023 / 2.932 ms**, p99
  **3.599 / 3.684 ms**, maximum **11.766 / 4.687 ms**. One first-repeat tick
  exceeded 8.333 ms, none in the second.
- Snapshot capture/packing median **2.160 / 2.153 ms**, p95 **3.029 / 2.995 ms**.
  Receiver reconstruction/assertions are outside that timer.
- Both final hashes:
  `032837806e930c42a035ce1c75a58215521fc8185495d971d9dc16b46027498d`.

This proves the codec/client reconstruction route under this journey, not an
eight-computer physical network test. The integration lead separately owns paid
cast admission, authoritative quotas, actual Farflow transport and Full gates.
Brief feedback events remain bounded and can report overflow; active projectile
or field omission is treated separately as a gameplay-coverage failure.

## Deterministic obstacle broadphase

`CollisionWorld` now builds a bounded 256-unit grid for maps with at least 16
obstacles. One conservative swept bounding box supplies candidates for the
unchanged X-then-Y narrow-phase resolver. Candidates retain original array-index
order, preserving wall ownership, normals and collision ties. `can_occupy` uses
the same conservative lookup with its original strict overlap rules.

- Small maps retain the original linear path. The current 14-building campus
  does not gain a claimed acceleration from this threshold.
- Geometry-property signals invalidate the cache immediately. Insertion and
  replacement also invalidate it. Build/query work has fixed bounds; huge or
  degenerate geometry and long sweeps fall back to the original linear path.
- `obstacle_view()` returns a cached shallow read-only array for presentation and
  read-only movement queries. Referenced geometry remains signal-observed.
- Legacy callers may still obtain and retain the mutable `obstacles` array.
  That world permanently selects linear fallback, preserving direct replacement,
  removal, reorder and clear semantics without silently stale collision state.

The new `collision-broadphase` suite passed **21,781 assertions, zero failures,
zero stderr** in `.godot/runtime-audit/collision-differential.log`. It compares
against a frozen pre-index resolver across 4,000 seeded movement/occupancy traces,
contact/axis/tangent/overlapping-start cases, mutable geometry, retained-array
mutations, exact normals/wall IDs, small maps and bounded fallbacks.

The registered integration selection also passed **30,453 assertions** across
`collision-broadphase`, `movement`, `movement-revision` and `combat`, with zero
failures/stderr in `.godot/runtime-audit/collision-integrated.log`. The read-only
consumers in movement and bootstrap were migrated by the integration lead.

Same-protocol control, eight actors / 256 projectiles / 16 fields / 64 obstacles:

| Path | Median ms, repeats 1 / 2 | p95 ms, repeats 1 / 2 | p99 ms, repeats 1 / 2 | Maximum ms, repeats 1 / 2 |
|---|---:|---:|---:|---:|
| Forced original linear control | 21.384 / 21.049 | 28.083 / 21.736 | 52.231 / 22.271 | 57.211 / 22.755 |
| Indexed | 11.721 / 11.899 | 17.426 / 17.822 | 27.493 / 21.280 | 32.598 / 21.798 |

Evidence: `linear-control-eight.log` (2,146 assertions) and `indexed-eight.log`
(2,144 assertions), both zero failures/stderr. The median reduction is about
**44%**, not a universal speedup claim. Checkpoints and the final world hash were
identical across both paths and all repeats:
`d5cc128af8a4fd1eee4851b6a1b0aef25c02dbfbc0bf2603ee2dc2304eddfe13`.
Every one of the 256 projectiles and 16 fields still expired exactly once.

That injected 256-projectile load remains above the 128-projectile admission
envelope and still exceeds the 8.333 ms simulation budget. Its explicit overflow
is expected for an illegal initial fixture, not hidden as online acceptance.

## Canonical-byte encoding optimization at the admitted envelope

The admitted-envelope fixture contains eight actors, 128 projectiles, 32 fields
and 64 obstacles. `CanonicalBytes.append_i64` now reserves eight bytes and calls
native `PackedByteArray.encode_s64` instead of performing eight interpreted
shift/mask/append operations. No field order, signedness, endianness, hash,
protocol or snapshot semantic changed.

The new `canonical-bytes` suite passed **4,808 assertions**, including signed
64-bit minimum/maximum, negative values, unaligned/nonzero append offsets,
preservation of existing bytes, 4,096 seeded full-width values, UTF-8 byte-length
prefixes and complete canonical payloads from 100 real `SimWorld` steps with
projectiles and fields. Both complete payload bytes and actual world hashes are
compared against a frozen copy of the original byte-by-byte implementation.
Variable-length graze and affected-actor histories also remain exact.

The clean focused gate passed **5,097 assertions across five suites**:
`canonical-bytes`, `core`, `replay`, `session-snapshot` and `client-prediction`.
Evidence: `.godot/runtime-audit/canonical-focused-clean.log`, with zero failures
and an explicitly checked zero-byte stderr file. The initial test fixture tried
an unsupported NUL string, which produced a Godot Unicode warning; that fixture
was corrected before this clean gate. Binary NUL bytes remain covered in the
byte-buffer prefix tests.

Within the clean run, the non-gating append microbenchmark measured **4,634 us
legacy versus 2,044 us native** for 8,192 values (median of five measured repeats
after warmup), approximately **56% less encoding time**. Both buffers were
byte-identical in every timed repeat. This is a local operation benchmark, not
a rendered-frame claim.

The actual admitted-envelope scenario was executed before and after the change:

| Measurement, milliseconds | Before repeats 1 / 2 | After repeats 1 / 2 |
|---|---:|---:|
| Snapshot capture/pack median | 4.116 / 4.324 | 3.238 / 2.972 |
| Snapshot capture/pack p95 | 4.649 / 4.660 | 4.693 / 4.241 |
| Snapshot capture/pack p99 / maximum | 5.067 / 5.160 | 5.942 / 36.841 |
| Simulation median | 5.234 / 5.398 | 5.953 / 5.392 |
| Simulation p95 | 5.700 / 5.803 | 7.978 / 6.162 |

Evidence: `.godot/runtime-audit/canonical-before.log` and `canonical-after.log`;
each run passed **2,144 assertions**, zero failures and zero stderr. Snapshot
capture/packing medians improved **21-31%**. Scheduling outliers remain, and the
simulation-only timer is not accelerated by changing serialization. Do not infer
a 120 Hz worst-case guarantee from these medians.

All four before/after traces have identical checkpoints and final world hash:
`8be99212d6fba0be8f58d5608ccb6852192dc74c20326a91d682f453e05ab157`.
Raw snapshot size remains **16,516 bytes**, the measured single-envelope
equivalent remains **4,180 bytes**, and actual transport uses at most **four
datagrams of 1,296 bytes each**. No threat overflow or snapshot rejection occurred.
Every projectile and field expired naturally, with exactly **128/32** expiry
events. A separate comparison of the two result logs checked checkpoint/hash,
raw/compressed byte-size and admission equality across every repeat.

**Pause checkpoint:** this bounded optimization is complete and the runtime
workstream is frozen at the user's request. The integration lead owns final
Full/Farflow verification and consolidation. The queue below is future work,
not permission to start another slice during the pause.

## Remaining acceptance and safest next work

1. Complete the integration lead's paid global/per-owner capacity admission,
   with whole-Burst reservations before resource spend; do not remove existing
   dangerous state or partially release a paid five-lane cast.
2. Re-run the strict legal-eight journey and Full/Farflow gates after the final
   integrated content/admission changes. Increasing a display cap alone was
   insufficient; authority and the complete bounded transport envelope must
   remain one contract.
3. The admitted 128-projectile/32-field boundary is now measured headlessly and
   canonical encoding is improved as recorded above. After the pause, measure
   dense actor contact on the real campus and isolate remaining actor/projectile
   lookup or snapshot costs before introducing pooling or dependencies.
4. Rendered fluidity, sprite/asset density, physical eight-PC behavior, packet
   loss under real sockets and unsupported larger lobbies require separate
   acceptance. No such result is claimed by this headless probe.

All timing runs recorded ability source SHA-256
`60113f2fd3f1323b2048f75787ccd5855d9851c691a0cb538a27af201f9467c7`
and champion source SHA-256
`c7763c063e3e7cbf171c7250ae44aa508ba557b2a37c8f74c27649357df40982`.
These hashes identify this tuning checkpoint; rerun after changing content.
