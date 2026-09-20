# H.E.X. / FLUX — PERF integration handoff

Date: 2026-09-20  
Status: Conditional experiment specification; source-specific implementation blocked by missing evidence.

## 1. Source basis

The only current assignment file received was `Pasted text.txt` (173 physical lines, 11,046 bytes). It contains the specialist assignment brief, not the referenced design contract, active implementation queue, checkpoint, profiles, source, or event logs. Targeted Library searches did not locate matching current PERF evidence. Historical launcher instructions were not adopted as implementation evidence.

Attachment SHA-256: `1eb74d936e6a5819c65cb4fc8a0637993e23434c1a11a9c9ab7364b1bff3c3e5`.

**Source commit / build identifier: NOT_SUPPLIED.** The attachment digest identifies the brief, not a game build.

Source references below use the supplied attachment's physical line numbers:

- S1, lines 9–19: evidence, checkpoint and missing-input rules.
- S1, lines 21–31: established gameplay/runtime boundaries.
- S1, lines 51–64: selected PERF assignment and event-accounting requirements.
- S1, lines 164–173: integration handoff and prohibition on project writes/publication.

Observed implementation facts: none established from source or profiles. Documented intentions: snapshot preparation, prediction cloning, metadata hashing and retained events are the requested investigation areas. The brief reports retained-event evictions and unencodable diagnostics/cues, but supplies no instances, counts, field types, timing samples or causes.

All three candidates below are hypotheses and proposed experiments. Their order is an investigation priority based on proposed change scope, not a measured hotspot ranking. No speedup or multiplayer root cause is claimed.

## 2. Recommended first candidate: cache unchanged metadata bytes and digest

**Hypothesis.** The same metadata may be canonicalized, copied, encoded or hashed repeatedly during snapshot preparation. Reuse could remove work only if the relevant block actually stays unchanged and contributes material cost. Neither condition is established.

**Ownership and invalidation.** Select one metadata block whose complete writers and consumers are visible. The snapshot-preparation layer would own a bounded cache of the existing canonical bytes and existing digest. The original authoritative owner remains responsible for the data. Cached contents must be deeply immutable or privately owned: a read-only outer wrapper alone is not a proof that nested state cannot change.

Use a local cache identity covering the block, serialization schema, content generation and restore/session epoch. Every relevant update, insertion, deletion, replacement and reload must invalidate it. Clear or safely re-key it after restore/rollback and round/session changes where identities or generations can be reused. Include peer-dependent inputs, or exclude peer-dependent blocks from this first cache. A tick number alone is not a sufficient content identity. Cache tokens are bookkeeping, not a new gameplay authority or replacement state hash.

Preserve canonical ordering, field coverage, codec and digest algorithm. Do not re-hash the entire source to validate each production hit; that would defeat the experiment. An uncached oracle is appropriate in validation, not in timed candidate runs.

**Minimal experiment.** Instrument and cache just that block. Compare old and new canonical bytes and digest on unchanged reads, every supported mutation, deletion/recreation, restore and context change. After equivalence passes, time the uncached and cached paths separately on the same recorded workload. Keep a cache-disabled path for comparison and rollback.

**Required before/after measurements.** Canonicalization, encoding and hashing call counts and time; input/output bytes; hits, misses and invalidations; rebuild spikes; cache size; total snapshot-preparation and authoritative-tick tails.

**Principal tradeoff.** Saved repeated computation in exchange for retained memory and a complete invalidation obligation. **Strongest counterargument:** metadata may already be cached, cheap, frequently changing or peer-specific. Reject the candidate if the source/profile shows this, rather than adding a cache for its own sake.

## 3. Second candidate: exclude proven-immutable data from prediction copies

**Hypothesis.** Prediction cloning may copy definitions or snapshot backing data that predictions only read. This is unverified; the existing implementation might already exclude or share those fields.

**Ownership and invalidation.** Keep authoritative mutable state separate. Each prediction branch retains independent ownership of every writable value, including any nested actor, projectile, chemistry, event, timer and RNG state that the actual source contains. Share only proven-immutable blocks and keep them alive while a snapshot or prediction references them. Publish a replacement block on change rather than mutating shared contents. Invalidate/rebind dependent prediction state according to the existing restore and reconciliation contract.

This is not permission to shallow-copy the world. A metadata change must not turn an old snapshot into a view of new state. Avoid introducing whole-world copy-on-write machinery before measuring this smaller split.

**Correctness/replay/network risks.** Hidden aliases can alter authority or sibling predictions; mixed-generation reads can corrupt reconciliation; retained old blocks can increase memory. Preserve state capture boundaries, iteration order and RNG behavior.

**Minimal experiment.** Remove one verified-immutable block from the clone path. Fork two predictions from the same source, exercise each actual mutable field category in one branch, and verify that the source and sibling remain unchanged. Exercise restore and metadata replacement while an old snapshot remains alive. Compare authoritative state and replay results with the uncached/reference path.

**Required before/after measurements.** Clone calls and time, copied bytes and allocations where measurable, prediction depth, reconciliation time, live snapshot counts, old-block lifetime and peak memory. Reject the change if sharing only shifts the cost into retained memory or reconciliation.

## 4. Third candidate: reuse immutable retained-event encodings

**Hypothesis.** Unchanged retained events may be re-encoded for repeated snapshots or consumers. Whole-history eligibility scans may also be redundant, but the current selector and retention representation are unknown.

**Ownership and invalidation.** Keep the authoritative retained-event store and its retention rules unchanged for the first experiment. A separate bounded cache may own encoded payloads for events whose contents are proven immutable. Identify entries using actual event identity, relevant epoch, payload/schema generation and every encoding context that affects the bytes. Keep peer-specific envelopes separate unless they are proven identical.

Invalidate on supported payload changes, event identity reuse, schema changes and restore/reset. Bound cache bytes independently of gameplay retention. Evicting a cache entry must only cause a later re-encode, never remove a gameplay event. Repeated required delivery is not a duplicate to suppress.

Initially retain the existing eligibility selector. Range-based access is a later substep only if source and measurements prove that the existing selection is representable as a bounded interval with identical ordering and inclusion. Do not invent acknowledgment rules, delta protocols, interest management or a shorter retention window.

**Minimal experiment.** Cache one immutable, successfully encoded event class while preserving all existing output and error handling. Compare selected event identities/order and encoded payloads with the reference path. Include the original pressure workload, late-reader cases supported by the harness, and just-below/at/above the actual retention threshold.

**Required before/after measurements.** Retained/scanned/selected event counts, encode calls and time by event class, emitted bytes, cache hits/bytes, eviction counts and reasons, encode failures and affected event identities. Failed encodes remain explicit failures; they must not become cached empty payloads or successful omissions.

**Risk/counterargument.** Event encoding may depend on mutable or peer-specific context, or encoding may be cheap relative to selection and transport. A cache could consume memory without improving end-to-end cost.

## 5. Mandatory eviction and unencodable-cue accounting

The brief reports these issues; their severity and cause cannot be reconstructed from the brief alone (S1, line 64).

For each retained-event store, reconcile opening and closing populations against all actual insertions/restorations and mutually exclusive removal reasons. Record event identity/type, originating tick where present, removal reason, and retention-policy context. Separate normal expiry, capacity pressure, consumption-related removal and reset; do not assume those categories already exist or are semantically equivalent. Counts alone are insufficient: compare the actual eligible event identities and order per consumer.

For unencodable diagnostics/cues, record event type, schema, failing field path/type and error category without dumping sensitive payload values. Compare completed encode attempts, successes and failures, with cache hits counted separately. Preserve the original failure handling in the performance-only slice.

Do not reclassify a cue as disposable because encoding fails. Determine from source/contract whether each item is authoritative, required presentation, diagnostic-only, or unresolved. Any encoding/schema repair is an explicit correctness change, not an invisible performance improvement. Do not hide existing loss by lowering event volume, clearing history early or suppressing error counters.

Matching an existing unexplained loss does not establish runtime acceptance. An eviction is only acceptable when the current contract proves the affected event is no longer required; legitimate expiry is not automatically a defect.

## 6. Shared measurement and acceptance protocol

Use the same verified source checkpoint plus explicitly recorded patch, Windows build configuration, Godot version, hardware, map, assets, seeded inputs, session schedule, durations and retained-event settings. Record local source differences. Preserve the actual snapshot cadence; 120 Hz is the simulation target, not evidence of 120 snapshots per second. Eight-player operation is a target, not verified capacity (S1, lines 21–31).

Instrument snapshot preparation, prediction cloning, metadata canonicalization/encoding/hashing, event selection/encoding and final serialization separately. Record counts and p50/p95/p99/max where the sample size supports them; retain raw sample counts. Distinguish inclusive from exclusive spans and worker CPU from critical-path wall time so nested/parallel work is not double-counted. Report allocation metrics as NOT_MEASURED when no reliable profiler measurement is available.

Run paired repetitions of the identical eight-player trace, preserving pressure and lifecycle phases; report steady-state, cold-start, invalidation and burst windows separately. Keep instrumentation comparable in both runs and measure its overhead. Shadow/reference comparison is for correctness runs; disable the extra oracle work in timed candidate runs. Predeclare an acceptance margin from measured baseline repeatability rather than selecting a favorable threshold after seeing the result.

At 120 Hz the nominal step interval is 1000/120 = approximately 8.333 ms. This is not an allocated snapshot-only budget and is not a claim that the current build meets its target.

### First-candidate acceptance

- Every tested cached result matches the uncached canonical bytes and digest exactly; existing authoritative/replay comparisons remain equal.
- An unchanged cache hit makes zero calls to that block's canonicalization, encoding and hash computation.
- Every relevant mutation/context transition causes a miss before stale data can be consumed; restore and reused identities are explicitly covered.
- Event selection, order, retention decisions, encoding failures and required presentation remain unchanged and accounted for. Known defects stay visible.
- Measured cache memory stays within a limit declared before comparison. Snapshot benefit exceeds measured run-to-run noise, with no authoritative-tick/reconciliation tail regression beyond the declared repeatability margin.

Failure or an absent measurable benefit rejects the optimization. No gameplay feature, workload, simulation frequency, whole-hex chemistry behavior, finite-strength rule, movement or authority boundary is changed to obtain a result.

## 7. Evidence needed for a source-specific patch

Provide the current design contract, active implementation queue and checkpoint/build manifest, including source commit, local diff and engine/export configuration; the profiler export plus the exact workload; and the files or complete function excerpts containing snapshot construction/callers, prediction cloning and state types, metadata serialization/hash plus all writers, retained-event insertion/selection/eviction and the event codec/error path. Include the log excerpts around evictions/unencodable items and the existing replay/performance harness or invocation.

No repository paths, function names or current data structures have been invented.

## 8. Concise integration handoff

| Item | Handoff |
|---|---|
| Source basis | S1 only; brief digest above. Game commit/build NOT_SUPPLIED. |
| Recommended contribution | One verified-immutable metadata block's existing canonical-byte/digest cache, conditional on source review and profiling. |
| Artifact produced | This conditional PERF experiment and acceptance specification. No code patch. |
| Proposed contract changes | None. |
| Checks executed | Full supplied brief review; targeted Library searches; attachment byte count, physical line count and SHA-256 computation. |
| NOT_RUN | Source audit, profiling, patch application, allocation measurement, unit/replay tests, eight-player runs, Windows/Godot runtime and release acceptance. |
| Unresolved risks | Unknown metadata mutability/dependencies, prediction aliasing, event retention semantics, encoding failures and actual hotspot cost. |
| Smallest next integration slice | Map one metadata block's complete writers/consumers, add phase counters and an uncached-versus-cached validation oracle; use the acceptance gates above before promotion. If immutability/cost is not supported, stop that candidate rather than expanding the redesign. |

No repository files were changed, committed or published. Runtime testing, authoritative integration and packaging remain with the owning Codex task.
