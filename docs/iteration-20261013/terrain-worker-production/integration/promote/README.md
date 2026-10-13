# Terrain worker promotion — staged, not applied

`manifest.json` pins seven exact proposed files, their current predecessors and the unchanged synchronous base. `terrain-worker-promotion.patch` is an unapplied patch; root alone applies it and runs engines. The stage generator writes only under this directory and refuses differing existing staged bytes. No measured prototype source or raw receipt is replaced.

The implementation owner is `checkpoint_audit`; independent reviewers are `audit_experience_next` and `audit_gameplay_next`. Root owns the separate registered regression, application, engine qualification, generated UIDs, provenance metadata, runtime identity and delivery.

## Exact integration

1. `wellspring_async_terrain_stream.gd` extends the exact canonical synchronous base (`83c1ee7a…`). It preserves the reviewed prototype's methods, clocks, ownership states, bounds, token retrieval, completed-only joins, immutable-byte hash, reconstruction, publication and cleanup. Only dependency paths, comments and diagnostic labels differ.
2. `terrain_hash_job.gd` is the same reviewed task-local byte/hash/mutex owner with its historical prototype comment removed. No image, scene, ResourceLoader or rendering calls execute on the worker.
3. The illustrated kit retains the base preload for signatures, manifest paths and static/synchronous tooling. One existing `TerrainStream.new()` call becomes `AsyncTerrainStream.new()`. No Bootstrap process, loading trigger, camera, authority, cache budget or player input change is included.
4. The base's eight-path source inventory remains byte-for-byte unchanged. An additive two-path async validation inventory supplies the new stream/task dependencies to the bake and existing source-equivalence test. Both standalone pack verifiers independently enumerate the resulting ten sources. The output manifest is not a hashed input.
5. Status reports `validation_backend = worker_sha256_v1`; optional profiling reports the same `backend`. Main `byte_snapshot` replaces the prototype's overloaded `pixel_validation` label. It measures obtaining detached Image bytes, not a guaranteed physical copy or hashing. Worker hash elapsed/count/max remain separately recorded. No timer positions change.

Whole-pump and nested main intervals measure elapsed calls and can include scheduler or driver waits. They are not measured thread CPU counters. Worker elapsed can overlap main work and cannot be added to a frame total. The 2 ms admission budget does not bound indivisible copy/reconstruction/upload calls. Single-tile polling latency remains a measured limitation.

## Qualification and registration plan

The prototype already passed 162 functional checks, two native stream comparisons (76,844/77,109 checks), and two actual Bootstrap routes in each arm. Those receipts qualify the pinned prototype; they do not substitute for the following promoted-source gates.

1. Root verifies all seven predecessor/new-path guards and applies only this patch plus the separately reviewed test. Register `wellspring-async-terrain-stream` immediately beside `wellspring-terrain-stream` in `tests/run_all.gd`.
2. Root's staged test at `../promoted-test/test_wellspring_async_terrain_stream.gd` preserves ten genuine-worker lifecycle cases with synthetic loader/clock controls. It adds default-off profiling, detached profile result, byte-snapshot versus worker completion counts, reset purity, actual kit backend selection, inherited synchronous pixel validation, refusal to synchronously collect an owned token and normal kit teardown. Its bounded polling is a suite-runner accommodation, not native throughput evidence.
3. Checked parsing/import must succeed on actual promoted paths and generated `.gd.uid` files. Run the new suite and the unchanged-base suite under strict warning/stderr gates. Keep the root test's semaphore-release-before-join cleanup even on failure.
4. Refresh only source-provenance metadata for the changed producer/validator inventory if the independent bake-equivalence gate proves all 132 chunks plus overview unchanged. Record the ten input hashes and verify all 133 exact image payloads. Do not blindly replace image assets. The bake script can reproduce the expanded inventory for future regeneration.
5. Run a bounded native gate against the actual promoted dependency paths: exact full/cropped uploaded bytes, completion-before-publication, genuine cancelled running task/reentry and normal close with every submitted task joined. At least one actual kit/Bootstrap arrival followed immediately by traversal must finish with correct ownership and source guards. Historical timings stay labeled prototype results unless repeated on promoted source.
6. Regenerate/check the coherent runtime identity, run the required focused checks and clean Full, then package and verify standalone terrain/lifecycle receipts against the final identity. A foreground profile is a separate acceptance gate; no 60 fps or physical-input claim follows from this change.

If any promoted-source correctness or normal-close gate fails, retain failed evidence and stop promotion. The runtime selection can return to the base constructor without editing or reconstructing that base. Reconcile provenance and runtime identity for whichever complete source set is retained; do not label an unqualified intermediate package current.

## Evidence limits and actual-route result

The independently archived stream comparison shows lower main-thread elapsed submission and faster larger-view readiness, but both one-tile views wait an extra polling step. Early fixed-camera traces and real camera-follow routes are different coverage. Actual Bootstrap routes retained 480 equal commands and equal endpoints: Garden arrival stayed at 27 paused callbacks; Verdant changed from 17 to 18; neither route paused later walking. These diagnostics used an explicit synthetic application-focus setting and do not establish physical-input, foreground frame pacing or improvement on every route.

See `docs/iteration-20261013/terrain-worker/` and `terrain-worker-bootstrap-walk/` for raw, separately scoped evidence. The current stage is unapplied and has no engine results of its own.
