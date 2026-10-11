# Whole-prepare ordered-geometry A/B probe brief

## Decision

Do not implement the D9 harness under the current no-production-change boundary. The present source has no sound test-only injection seam at the one call that D7 needs to replace.

`HexWorldSnapshot.prepare()` statically calls `HexChemistrySnapshot._prepare(detached, trusted_world.hex_court)` (`src/net/hex_world_snapshot.gd:178-220`). `_prepare()` then creates the exact base `HexChemistryWorld` and directly invokes `prepared.configure_geometry(topology.origin, ordered_cells)` (`src/net/hex_chemistry_snapshot.gd:223-238`). The snapshot codecs are static/preloaded scripts. Passing a derived trusted topology cannot affect the fresh base instance, subclassing either codec cannot alter the preload used by `HexWorldSnapshot`, and the fresh world has no injectable factory.

Therefore, a test-only script can currently do only one of the following, neither acceptable:

- copy most or all of `HexChemistrySnapshot._prepare()` and `HexWorldSnapshot.prepare()`, creating a divergent candidate that no longer proves full public preparation differs only at `configure_geometry`; or
- estimate a whole-prepare result by subtracting the isolated public-constructor timing and adding D7's candidate timing, which is not an actual operation and cannot measure allocation, validation, cache, or interaction effects.

D7 established only its frozen constructor result: 40 fresh 2,766-cell samples per arm, exact output/ownership, production p50 52,125 microseconds, candidate p50 44,866 microseconds, and a 7,259-microsecond isolated median difference (`ordered-geometry-handoff.md:64-86`; `ordered-geometry-review.md:43-59`). Its own disposition correctly defers integration until an actual full-prepare comparison. This brief does not extrapolate that difference.

## Smallest sound seam, if the integration slice is later chosen

The smallest sound design is two internal delegating functions in the existing codec scripts. Public methods and their default behavior remain unchanged.

1. In `src/net/hex_chemistry_snapshot.gd`, retain:

   ```gdscript
   static func _prepare(snapshot: Dictionary, topology: HexChemistryWorld) -> HexChemistryWorld:
       return _prepare_with_geometry_constructor(snapshot, topology, Callable())
   ```

   Move the current `_prepare()` body without semantic edits into `_prepare_with_geometry_constructor(snapshot, topology, constructor)`. At only the current lines 235–238, use the constructor when it is valid; otherwise execute the present `World.new()` plus public `configure_geometry()` path. Require the injected result to be non-null and `get_script() == World` before continuing. All shape/size checks, `_trusted_cells()`, topology hash, detached decoders, relation validation, and final authority hash remain in this one shared body.

2. In `src/net/hex_world_snapshot.gd`, retain:

   ```gdscript
   static func prepare(snapshot: Dictionary, trusted_world: SimWorld) -> SimWorld:
       return _prepare_with_geometry_constructor(snapshot, trusted_world, Callable())
   ```

   Move the current `prepare()` body without semantic edits into `_prepare_with_geometry_constructor(snapshot, trusted_world, constructor)`. Change only its current chemistry call at line 220 to forward the constructor to the chemistry internal function. All public outer decoding, trusted-world checks, collision clone, dynamic surfaces, `SimWorld` construction, player/projectile assignment, relation validation, and outer hash remain shared and in their current order.

This is production-source plumbing even though the empty-callable public path is behaviorally unchanged. It therefore expands D9 from an isolated test probe into a runtime integration and maintenance decision that root would have to own and review. The work is already ordinarily authorized; the reason to defer is that this persistent API surface and review burden exceed the evidence value of the currently isolated candidate. Do not expose the constructor as a new optional parameter on public `prepare()`: that would turn an internal test seam into a caller-controlled public reconstruction path. Do not use a mutable static factory/setter: it would introduce cross-call, reentry, cleanup, and concurrent-test state.

The candidate arm would pass one exact callable that returns `OrderedGeometryCandidate.construct(origin, ordered_cells)`. The D7 helper creates the exact base script, requires strict `HexGrid._cell_less` order, repeats all current constructor bounds/state checks, deep-duplicates the complete empty-cell shape per cell, and falls back to the public method outside its specialization (`tests/support/hex_ordered_geometry_candidate.gd:10-42`). `_trusted_cells()` already validates every retained topology record and returns that strict order immediately before construction (`src/net/hex_chemistry_snapshot.gd:810-841`). No ordered list, world, hash, or constructor result may survive the one prepare call.

The injected callable creates one extra callback point in the test path. Constrain the seam to an internal underscore method, require an exact-base return, record exactly one invocation, and use only the frozen D7 callable. This still measures the callable's dispatch overhead; that small bias must be reported. An arbitrary callable could mutate inputs or re-enter, so it must never become a public production option.

## Proposed test-only ownership

If root later chooses that expanded integration slice and implements the two internal seams, D9 needs only one new test-owned file:

- `tests/performance/profile_hex_whole_prepare_ordered_geometry.gd` — fixture, A/B oracle, alternating measurements, receipt, source/identity guards.

Reuse without editing:

- `tests/support/hex_ordered_geometry_candidate.gd` — frozen D7 constructor candidate;
- `tests/performance/profile_unified_wellspring.gd` — the existing legal eight-actor fixture and command helpers;
- current codec/runtime sources — the actual operation under test.

Do not add a copied snapshot codec, candidate `HexWorldSnapshot`, alternate `HexChemistrySnapshot`, or second support implementation. Root owns any changes to `src/net/hex_world_snapshot.gd` and `src/net/hex_chemistry_snapshot.gd`, test registration, engine scheduling, receipts, identity, and integration decision.

## Exact oracle relation

For every case, call the unchanged public `HexWorldSnapshot.prepare(snapshot, trusted)` as the old arm and the internal shared-body method with the frozen D7 constructor as the candidate arm. Give each arm an independent deep duplicate of the same frozen snapshot; use the same unchanged trusted world. Compare:

1. identical success/null result;
2. on success, identical full `state_hash()`, tick/IDs, player/projectile/event lanes, chemistry hash, value revision, collision/dynamic-surface validity, and exact `HexWorldSnapshot.capture(result)` Dictionary plus `var_to_bytes` outside timing;
3. identical next legal command result, combat events, and next state hash from independently prepared worlds;
4. snapshot bytes and trusted world/chemistry hashes unchanged before and after each arm;
5. fresh ownership: the two results and trusted world have distinct chemistry, collision, player, projectile, cell, and nested material dictionaries; mutating one accepted result cannot change the other result or trusted input;
6. candidate constructor call count exactly one only after preparation reaches the geometry-construction point, zero for earlier rejections, and no retained candidate world after a late rejection.

The public baseline and candidate must execute the same shared body. A comparison against hand-written expected values, isolated constructor bytes, or a reconstructed partial world is insufficient.

## Supported functional cases

Keep the full-prepare probe bounded; D7 already owns exhaustive constructor equivalence and existing unit tests own broad snapshot rejection. Before timing, require these paired cases:

- the genuine 2,766-cell dense-crucible fixture after the existing 120 neutral plus first 40 paid ticks: eight actors, positive admitted/paid chemistry, conservation valid, one captured whole snapshot;
- an ordinary legal low-occupancy whole snapshot on the same topology;
- early outer rejection: missing/wrong snapshot shape or epoch, where the constructor must not run;
- packed-Hex rejection: valid compression framing with one required packed lane removed, where both arms return null;
- topology and chemistry rejection: forged topology fingerprint and forged chemistry authority hash;
- late outer rejection: forged outer state hash and one structurally valid stale player/projectile or relation lane, proving a locally constructed candidate is discarded;
- direct snapshot mutation between consecutive calls and direct trusted metadata/material-shape mutation between consecutive calls, proving no validation/order cache hides changes;
- a trusted world whose Hex topology object is a test-derived `HexChemistryWorld`, proving the injected constructor does not invoke or depend on the trusted object's `configure_geometry` override;
- accepted-result ownership and identical next-command continuation as described above.

For every rejection, compare exact input snapshot bytes and trusted hashes before/after. Public `prepare()` has no mutation target, so atomicity means null plus unchanged caller-owned snapshot/trusted state. Run the existing snapshot/unit suite separately if integration is later proposed; this probe does not replace it.

## Matched measurement

Measure one successful case only: the unchanged 2,766-cell, eight-actor, paid dense-crucible snapshot. Snapshot construction, source/identity hashing, warmups, state/hash/byte checks, continuation, and object release remain outside timers. Each timed sample begins immediately before the whole prepare entry and ends immediately after it returns, so it includes outer decoding, chemistry decoding, topology validation/hash, fresh geometry allocation, authority hash, collision clone/surface binding, fresh `SimWorld`, relation checks, and outer hash.

Use two untimed warmups per arm, followed by four order-balanced cycles: ABBA for even cycles and BAAB for odd cycles. Use three batch-size-one samples per block. This yields 24 actual whole-prepare samples per arm and 48 total, with the exact cycle/block/arm order and raw positive microsecond rows in the receipt. Hold only the current prepared world during validation, then release it before the next sample; receipt rows retain numbers, not worlds. Percentiles are computed from the raw per-arm arrays and are never added or inferred from D7.

The process is headless and isolated: no rendering, sockets, prediction bind, snapshot cadence, simulation during timing, import, export, or package work. Use a fresh output contract such as `res://.godot/hex-whole-prepare-ordered-geometry-*.json`. Guard all measured source hashes and parsed runtime identity before warmup and after the last sample; refuse the receipt on any change.

Bound the run to one process and one performance fixture. At the previously recorded roughly 259-ms whole-prepare context, 48 timed calls imply about 12.5 seconds of raw timed work. Allow a 90-second script-level elapsed budget checked between blocks and a 120-second root wrapper timeout for setup, warmups, oracles, hashing, allocation release, and machine variance. On either bound, stop without a valid PASS receipt. This is not a soak.

## Acceptance and limitations

A valid receipt requires every paired functional case, exact output/continuation/ownership oracles, 24 samples per arm, exact balanced block order, unchanged source/identity guards, zero failures, and zero stderr. Report the full-prepare absolute and relative deltas with all tails, but require no invented threshold in the probe itself. Root can decide afterward whether the complete-operation change justifies production integration and a full regression/package cycle.

The result would cover one local headless whole-prepare operation on one machine and frozen legal state. It would not establish producer capture, public transport validation, prediction bind, networking, snapshot cadence, memory peak, long-run allocation behavior, rendering, capacity, package, or release acceptance. It would include the test callable dispatch absent from a direct production integration. A null or noisy result leaves D7 deferred.

Under the current isolated-probe scope, the correct disposition is **DEFER**. This is an integration-cost decision, not a missing-permission gate: there is no honest test-only implementation that both exercises the actual whole `HexWorldSnapshot.prepare()` body and changes only its interior `configure_geometry()` call, and introducing permanent runtime plumbing only for this experiment is not justified by D7's isolated result.
