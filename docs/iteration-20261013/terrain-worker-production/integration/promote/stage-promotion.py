"""Prepare reviewed terrain-worker promotion; never write canonical paths."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PROTO = HERE.parent


def sha(data):
    return hashlib.sha256(data).hexdigest()


def replace_once(value, old, new):
    if value.count(old) != 1:
        raise ValueError(f"Expected one occurrence: {old!r}")
    return value.replace(old, new)


def save_new(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if path.read_bytes() != data:
            raise ValueError(f"Refusing to overwrite differing staged bytes: {path}")
    else:
        path.write_bytes(data)


def as_text(data):
    return data.decode("utf-8").replace("\r\n", "\n")


def source_bytes(text, original):
    return text.replace("\n", "\r\n").encode("utf-8") if b"\r\n" in original else text.encode("utf-8")


BASE = "src/presentation/wellspring_terrain_stream.gd"
ASYNC = "src/presentation/wellspring_async_terrain_stream.gd"
JOB = "src/presentation/terrain_hash_job.gd"
base_bytes = (ROOT / BASE).read_bytes()
if sha(base_bytes) != "83c1ee7a896ca60a92f2b691c9c7cfd54faff32fffdc33d84181e38ccdcdf0ca":
    raise ValueError("Canonical synchronous predecessor is no longer the reviewed exact base")

worker_bytes = (PROTO / "worker_terrain_stream.gd").read_bytes()
job_bytes = (PROTO / "hash_job.gd").read_bytes()
if sha(worker_bytes) != "0369b3cef8655c16a075396faa617e3fb06818543d92eaf520fd7edb0a4b7548":
    raise ValueError("Worker prototype changed")
if sha(job_bytes) != "6bcc7df8106bbfefca56bc674a257415dd9d0254c917e7f9db0e1b716eb8179e":
    raise ValueError("Hash job prototype changed")

worker = as_text(worker_bytes)
worker = replace_once(worker,
    'extends "res://.godot/iteration-20261013/T8-before/wellspring_terrain_stream.gd"',
    f'extends "res://{BASE}"')
worker = replace_once(worker,
    '## Ignored experiment against exact predecessor 83c1ee7a..., not a live change.',
    '## Exact terrain validation on bounded worker tasks. Images, residency and\n## rendering remain owned by the main thread.')
worker = replace_once(worker,
    'const HashJob = preload("res://.godot/iteration-20261013/terrain-worker/hash_job.gd")',
    f'const HashJob = preload("res://{JOB}")\nconst VALIDATION_BACKEND := "worker_sha256_v1"\n# Additive provenance for the asynchronous runtime selection; the base tooling\n# inventory stays intact and the output manifest is deliberately absent.\nconst VALIDATION_SOURCE_PATHS: Array[String] = [\n\t"res://{ASYNC}",\n\t"res://{JOB}",\n]')
if worker.count('&"pixel_validation"') != 2:
    raise ValueError("Unexpected snapshot timing call count")
worker = worker.replace('&"pixel_validation"', '&"byte_snapshot"')
worker = replace_once(worker,
    '"H.E.X exact terrain SHA-256 prototype"', '"H.E.X exact terrain SHA-256"')
worker = replace_once(worker,
    '\tresult["worker_elapsed_usec"] = _worker_elapsed_usec',
    '\tresult["backend"] = VALIDATION_BACKEND\n\tresult["worker_elapsed_usec"] = _worker_elapsed_usec')
worker = replace_once(worker,
    'Ignored worker experiment. Eight fixed main-thread CPU interval keys; pixel_validation is detached byte-copy work, not the hash. Worker hash elapsed is separately observed and may include descheduling; never sum it into a frame or subtract it as a speedup. Texture creation includes driver submission, not GPU execution. Normal collection polls then joins completed tasks only; final teardown may wait. Source Image and exact-byte reconstruction remain main-thread. No sample history.',
    'Worker SHA-256 validation. Eight fixed main-thread elapsed interval keys, not thread CPU counters; scheduling and driver waits may be included. byte_snapshot measures obtaining detached Image bytes, not hashing or a guaranteed physical copy. Worker hash elapsed is separately observed and may overlap main work or include descheduling; never add it to a frame total or subtract it as a speedup. Texture creation measures submission, not GPU execution. Normal collection polls then joins completed tasks only; final teardown may wait. Source Image and exact-byte reconstruction remain main-thread. No sample history.')
worker = replace_once(worker,
    'result.merge({"worker_prototype": true, "worker_generation": _generation,',
    'result.merge({"validation_backend": VALIDATION_BACKEND, "worker_generation": _generation,')

job = replace_once(as_text(job_bytes),
    '## Ignored prototype. One immutable byte owner and one task-local hash context.',
    '## One immutable byte owner and one task-local hash context.')

changes = {
    ASYNC: (None, source_bytes(worker, worker_bytes)),
    JOB: (None, source_bytes(job, job_bytes)),
}


def existing(path, transform):
    before = (ROOT / path).read_bytes()
    after = source_bytes(transform(as_text(before)), before)
    if before == after:
        raise ValueError(f"No intended change: {path}")
    changes[path] = (before, after)


def kit_change(text):
    text = replace_once(text,
        f'const TerrainStream = preload("res://{BASE}")',
        f'const TerrainStream = preload("res://{BASE}")\nconst AsyncTerrainStream = preload("res://{ASYNC}")')
    return replace_once(text, '\t\tvar stream := TerrainStream.new()', '\t\tvar stream := AsyncTerrainStream.new()')


def bake_change(text):
    text = replace_once(text,
        f'const Stream = preload("res://{BASE}")',
        f'const Stream = preload("res://{BASE}")\nconst AsyncStream = preload("res://{ASYNC}")')
    return replace_once(text, 'for source_path: String in Stream.BAKE_SOURCE_PATHS:',
        'for source_path: String in Stream.BAKE_SOURCE_PATHS + AsyncStream.VALIDATION_SOURCE_PATHS:')


def pack_gd_change(text):
    text = replace_once(text, f'\t"res://{BASE}",',
        f'\t"res://{BASE}",\n\t"res://{ASYNC}",\n\t"res://{JOB}",')
    return replace_once(text, 'expected provenance must contain exactly all eight producers',
        'expected provenance must contain the exact independent terrain source inventory')


def pack_ps_change(text):
    return replace_once(text, f"        '{BASE}',",
        f"        '{BASE}',\n        '{ASYNC}',\n        '{JOB}',")


def existing_test_change(text):
    text = replace_once(text, f'const Stream = preload("res://{BASE}")',
        f'const Stream = preload("res://{BASE}")\nconst AsyncStream = preload("res://{ASYNC}")')
    text = replace_once(text,
        'equal(provenance.size(), Stream.BAKE_SOURCE_PATHS.size(), "bake records the exact complete source provenance inventory")',
        'equal(provenance.size(), Stream.BAKE_SOURCE_PATHS.size() + AsyncStream.VALIDATION_SOURCE_PATHS.size(), "bake records the exact complete source provenance inventory")')
    return replace_once(text, 'for source_path: String in Stream.BAKE_SOURCE_PATHS:',
        'for source_path: String in Stream.BAKE_SOURCE_PATHS + AsyncStream.VALIDATION_SOURCE_PATHS:')


existing("src/presentation/wellspring_illustrated_kit.gd", kit_change)
existing("scripts/bake_wellspring_terrain.gd", bake_change)
existing("scripts/verify-terrain-pack.gd", pack_gd_change)
existing("scripts/verify-terrain-pack.ps1", pack_ps_change)
existing("tests/unit/test_wellspring_terrain_stream.gd", existing_test_change)

patch = []
records = []
for path, (before, after) in changes.items():
    if before is None and (ROOT / path).exists():
        raise ValueError(f"New canonical path already exists: {path}")
    if before is not None:
        save_new(HERE / "before" / path, before)
    save_new(HERE / "proposed" / path, after)
    patch.extend(difflib.unified_diff(
        as_text(before or b"").splitlines(keepends=True),
        as_text(after).splitlines(keepends=True),
        fromfile="a/" + path if before is not None else "/dev/null",
        tofile="b/" + path,
    ))
    records.append({"path": path, "before_sha256": sha(before) if before is not None else None,
        "before_bytes": len(before) if before is not None else None,
        "proposed_sha256": sha(after), "proposed_bytes": len(after),
        "canonical_unchanged_or_absent": (ROOT / path).read_bytes() == before if before is not None else not (ROOT / path).exists()})

patch_bytes = "".join(patch).encode("utf-8")
save_new(HERE / "terrain-worker-promotion.patch", patch_bytes)
manifest = {
    "schema": "hex.terrain-worker-promotion-stage.v1", "status": "UNAPPLIED",
    "scope": "Exact reviewed worker ownership algorithm promoted through path and metadata transforms; source tests and engine qualification have not run on these proposed bytes.",
    "unchanged_base": {"path": BASE, "bytes": len(base_bytes), "sha256": sha(base_bytes)},
    "prototype_sources": [
        {"path": str((PROTO / "worker_terrain_stream.gd").relative_to(ROOT)).replace("\\", "/"), "sha256": sha(worker_bytes)},
        {"path": str((PROTO / "hash_job.gd").relative_to(ROOT)).replace("\\", "/"), "sha256": sha(job_bytes)}],
    "mapping": {
        "base_path": "ignored pinned predecessor -> exact same canonical synchronous base",
        "worker_path": ASYNC, "task_path": JOB,
        "selection": "existing prebaked illustrated-kit TerrainStream.new() -> AsyncTerrainStream.new(); synchronous load_immediate and static validators inherited unchanged",
        "status": "worker_prototype:true -> validation_backend:worker_sha256_v1",
        "profile": "pixel_validation main interval -> byte_snapshot; backend:worker_sha256_v1 added; separate worker_elapsed_usec/worker_maximum_usec/worker_measured_completions unchanged",
        "provenance": "base eight source paths remain unchanged; AsyncStream.VALIDATION_SOURCE_PATHS adds exactly worker and task files; independent pack-verifier inventory adds the same two explicitly",
        "behavior_changes": "None in state transitions, ownership, hashing, polling, joining, reconstruction, upload, cancellation, bounds, error handling, counters or clock placement; only public diagnostic labels/description and dependency paths change."},
    "patch": {"path": "terrain-worker-promotion.patch", "bytes": len(patch_bytes), "sha256": sha(patch_bytes)},
    "files": records,
    "canonical_writes": False,
    "not_included": ["new registered asynchronous-stream regression owned by root", "tests/run_all.gd registration", "generated .gd.uid files", "terrain manifest provenance metadata refresh", "runtime identity regeneration", "engine/native/Full/package gates"],
}
save_new(HERE / "manifest.json", (json.dumps(manifest, indent=2) + "\n").encode("utf-8"))
print(json.dumps({"stage": str(HERE), "files": len(records), "patch_sha256": sha(patch_bytes), "canonical_writes": False}))
