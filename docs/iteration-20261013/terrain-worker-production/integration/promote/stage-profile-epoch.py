"""Revision two: preserve revision one and stage only a capture-epoch correction."""
from pathlib import Path
import difflib
import hashlib
import json

PRIOR = Path(__file__).resolve().parent
OUT = PRIOR / "profile-epoch"
ROOT = PRIOR.parents[3]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def text(data):
    return data.decode("utf-8").replace("\r\n", "\n")


def replace_once(value, old, new):
    if value.count(old) != 1:
        raise ValueError(f"Expected one occurrence: {old!r}")
    return value.replace(old, new)


def save_new(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if path.read_bytes() != data:
            raise ValueError(f"Refusing to overwrite differing bytes: {path}")
    else:
        path.write_bytes(data)


prior_manifest_bytes = (PRIOR / "manifest.json").read_bytes()
manifest = json.loads(prior_manifest_bytes)
prior_patch = (PRIOR / "terrain-worker-promotion.patch").read_bytes()
if sha(prior_patch) != "97e637979ecf1ccbbc0ff4be5fe570ca0ba19007c7a680da90c3ac5cd0c8bc77":
    raise ValueError("Revision-one patch changed")
manifest["schema"] = "hex.terrain-worker-promotion-stage.v2"
manifest["scope"] = "Reviewed worker promotion plus a new diagnostic capture-epoch correction; promoted-source engine qualification remains required."
manifest["previous_stage"] = {"manifest_path": "../manifest.json", "manifest_sha256": sha(prior_manifest_bytes),
    "patch_path": "../terrain-worker-promotion.patch", "patch_sha256": sha(prior_patch), "preserved_unchanged": True}
manifest["mapping"]["behavior_changes"] = "Terrain state transitions, ownership, hashing, joining, reconstruction, upload and readiness remain unchanged. New diagnostic correction: reset_profile advances a main-thread capture epoch; jobs measured before the reset are still validated/joined but their worker interval is excluded from the new capture. No worker mutation or added clocks."
manifest["mapping"]["capture_epoch"] = "profile_epoch pinned at measured dispatch; profile_status.capture_epoch identifies the current epoch; accumulation requires enabled measurement and equal dispatch/current epoch. Main collection elapsed remains current-window work even when the separate prior worker interval is excluded."

patch = []
for record in manifest["files"]:
    path = record["path"]
    before = (PRIOR / "before" / path).read_bytes() if record["before_sha256"] is not None else None
    prior = (PRIOR / "proposed" / path).read_bytes()
    if sha(prior) != record["proposed_sha256"]:
        raise ValueError(f"Prior staged bytes changed: {path}")
    after = prior
    if path == "src/presentation/wellspring_async_terrain_stream.gd":
        value = text(prior)
        value = replace_once(value, 'var _worker_elapsed_usec := 0',
            'var _profile_epoch := 0\nvar _worker_elapsed_usec := 0')
        value = replace_once(value, '\tjob.submitted_pump = _pump_serial',
            '\tjob.submitted_pump = _pump_serial\n\tjob.profile_epoch = _profile_epoch if profile_enabled else -1')
        value = replace_once(value, '\tif profile_enabled and bool(result.get("measured", false)):',
            '\tif profile_enabled and int(job.get("profile_epoch", -1)) == _profile_epoch \\\n\t\t\tand bool(result.get("measured", false)):')
        value = replace_once(value, 'func reset_profile() -> void:\n\tsuper.reset_profile()',
            'func reset_profile() -> void:\n\t# Existing tasks retain their dispatch epoch and ownership. A new capture\n\t# must not inherit a whole worker interval that began before this reset.\n\t_profile_epoch += 1\n\tsuper.reset_profile()')
        value = replace_once(value, '\tresult["backend"] = VALIDATION_BACKEND',
            '\tresult["backend"] = VALIDATION_BACKEND\n\tresult["capture_epoch"] = _profile_epoch')
        value = replace_once(value, 'No sample history."',
            'Worker intervals dispatched before the most recent profile reset are excluded from that capture; current-window collection work is still recorded. No sample history."')
        after = value.replace("\n", "\r\n").encode("utf-8") if b"\r\n" in prior else value.encode("utf-8")
    if before is not None:
        if (ROOT / path).read_bytes() != before:
            raise ValueError(f"Canonical predecessor changed: {path}")
        save_new(OUT / "before" / path, before)
    elif (ROOT / path).exists():
        raise ValueError(f"New canonical path now exists: {path}")
    save_new(OUT / "proposed" / path, after)
    record["revision_one_proposed_sha256"] = record["proposed_sha256"]
    record["proposed_sha256"] = sha(after)
    record["proposed_bytes"] = len(after)
    patch.extend(difflib.unified_diff(text(before or b"").splitlines(keepends=True), text(after).splitlines(keepends=True),
        fromfile="a/" + path if before is not None else "/dev/null", tofile="b/" + path))

patch_bytes = "".join(patch).encode("utf-8")
save_new(OUT / "terrain-worker-promotion.patch", patch_bytes)
manifest["patch"] = {"path": "terrain-worker-promotion.patch", "bytes": len(patch_bytes), "sha256": sha(patch_bytes)}
save_new(OUT / "manifest.json", (json.dumps(manifest, indent=2) + "\n").encode("utf-8"))
print(json.dumps({"stage": str(OUT), "patch_sha256": sha(patch_bytes),
    "async_sha256": manifest["files"][0]["proposed_sha256"], "canonical_writes": False}))
