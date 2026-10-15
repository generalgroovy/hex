"""Refresh one existing kit provenance digest after reviewed setup-only integration. No engine."""
import argparse
import hashlib
import json
import os
import re
import sys
import uuid
from pathlib import Path

BASELINE_SHA = "b4cced0c281abe73c413581f76d4aad06cf2699ca0814456ea2526074098c090"
KIT_KEY = "res://src/presentation/wellspring_illustrated_kit.gd"
EXPECTED_RESOURCES = {f"chunk_{x:02}_{y:02}.res" for y in range(11) for x in range(12)} | {"overview.res"}


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON key: " + key)
        result[key] = value
    return result


def provenance(raw):
    blocks = list(re.finditer(rb'"source_sha256": \{\r?\n(.*?)\r?\n\}', raw, re.S))
    require(len(blocks) == 1, "Expected one exact provenance block")
    data = json.loads(b"{" + blocks[0][1] + b"}", object_pairs_hook=unique_object)
    require(len(data) == 10 and KIT_KEY in data, "Expected existing ten-source inventory with one kit entry")
    for key, value in data.items():
        require(isinstance(key, str) and key.startswith("res://") and re.fullmatch(r"[a-f0-9]{64}", value) is not None, "Invalid producer pin")
    return data


def sources(root, pins):
    result = {}
    for key in pins:
        path = (root / key.removeprefix("res://")).resolve()
        require(path.is_relative_to(root) and path.is_file(), "Missing or escaped producer: " + key)
        result[key] = sha(path)
    return result


def resources(directory, root):
    files = sorted(directory.glob("*.res"))
    require({path.name for path in files} == EXPECTED_RESOURCES, "Native resource inventory is not exact132 chunks and overview")
    result = {}
    for path in files:
        require(path.resolve().is_relative_to(root) and path.is_file(), "Native resource escaped repository")
        result[path.name] = {"bytes": path.stat().st_size, "sha256": sha(path)}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--expected-kit-sha256", required=True)
    parser.add_argument("--apply", action="store_true", help="Explicit canonical mutation after root approves the final kit")
    parser.add_argument("--output", default="", help="Required fresh contained runs/<leaf> directory for --apply")
    args = parser.parse_args()
    root = Path(args.repo).resolve()
    folder = Path(__file__).resolve().parent
    require(folder == root / ".godot/iteration-20261013/architecture-provenance", "Helper is not in its reviewed checkout location")
    require(re.fullmatch(r"[a-f0-9]{64}", args.expected_kit_sha256) is not None, "Exact final kit SHA256 required")
    baseline_dir = folder / "baseline"
    baseline_path = baseline_dir / "baseline.json"
    require(sha(baseline_path) == BASELINE_SHA, "Preserved baseline record changed")
    baseline = json.loads(baseline_path.read_bytes(), object_pairs_hook=unique_object)
    require(baseline["schema"] == "hex-architecture-provenance-baseline-v1" and baseline["resource_count"] == 133, "Wrong baseline schema/count")
    old = (baseline_dir / "manifest.tres").read_bytes()
    require(hashlib.sha256(old).hexdigest() == baseline["manifest_sha256"], "Preserved manifest bytes changed")
    require(sha(baseline_dir / "wellspring_illustrated_kit.gd") == baseline["kit_sha256"], "Preserved kit bytes changed")
    pins = provenance(old)
    require(pins == baseline["source_sha256"] and pins[KIT_KEY] == baseline["kit_sha256"], "Baseline manifest/source record differs")
    manifest = (root / baseline["manifest_path"]).resolve()
    require(manifest == root / "assets/environment/wellspring_ground_v1/manifest.tres", "Unexpected manifest target")
    require(manifest.read_bytes() == old, "Current manifest is not the exact preserved baseline; no overwrite allowed")
    actual = sources(root, pins)
    require(actual[KIT_KEY] == args.expected_kit_sha256, "Current kit differs from explicitly approved final hash")
    expected = dict(pins)
    expected[KIT_KEY] = args.expected_kit_sha256
    require(actual == expected, "A different producer changed; this helper may refresh only the kit")
    require(resources(manifest.parent, root) == baseline["resources"], "Native resources changed since baseline")
    pattern = rb'(?m)^"' + re.escape(KIT_KEY.encode()) + rb'": "([a-f0-9]{64})"[,]?\r?$'
    matches = list(re.finditer(pattern, old))
    require(len(matches) == 1 and matches[0][1].decode() == baseline["kit_sha256"], "One exact old kit-hash entry required")
    match = matches[0]
    replacement = args.expected_kit_sha256.encode()
    after = old[:match.start(1)] + replacement + old[match.end(1):]
    require(len(after) == len(old) and after[:match.start(1)] == old[:match.start(1)] and after[match.end(1):] == old[match.end(1):], "Non-hash manifest bytes changed")
    require(provenance(after) == expected, "Resulting full provenance differs")
    record = {"schema": "hex-architecture-provenance-refresh-v1", "status": "checked_not_applied", "failure": None,
              "baseline_sha256": BASELINE_SHA, "manifest_path": baseline["manifest_path"],
              "manifest_sha256_before": baseline["manifest_sha256"], "manifest_sha256_after": hashlib.sha256(after).hexdigest(),
              "kit_sha256_before": baseline["kit_sha256"], "kit_sha256_after": args.expected_kit_sha256,
              "source_sha256": expected, "resources": baseline["resources"], "resource_count": 133,
              "changed_byte_span": [match.start(1), match.end(1)], "helper_sha256": sha(Path(__file__)),
              "scope": "One existing kit SHA256 provenance value only. All other manifest bytes and all133 native resource file bytes remain exact. No bake, image decoding, signature calculation, source qualification or engine; native composition/bake-equivalence and isolated exported-pack gates remain required."}
    if not args.apply:
        require(not args.output, "Check-only mode writes no output; omit --output")
        print(json.dumps({key: value for key, value in record.items() if key not in ("resources", "source_sha256")}))
        return 0
    require(args.expected_kit_sha256 != baseline["kit_sha256"], "No kit change to apply")
    require(bool(args.output), "Explicit apply needs fresh output")
    output = Path(args.output)
    output = (output if output.is_absolute() else root / output).resolve()
    allowed = folder / "runs"
    require(output.is_relative_to(allowed) and output != allowed and not output.exists(), "Fresh contained application output required")
    output.mkdir(parents=True, exist_ok=False)
    (output / "manifest-before.tres").write_bytes(old)
    temporary = manifest.with_name(manifest.name + ".architecture-" + uuid.uuid4().hex + ".tmp")
    require(not temporary.exists() and temporary.parent == manifest.parent, "Fresh same-directory staging file required")
    try:
        require(manifest.read_bytes() == old and sources(root, pins) == expected, "Manifest/source changed before replacement")
        require(resources(manifest.parent, root) == baseline["resources"], "Resource drift before replacement")
        with temporary.open("xb") as stream:
            stream.write(after)
            stream.flush()
            os.fsync(stream.fileno())
        require(temporary.read_bytes() == after, "Staged bytes differ")
        require(manifest.read_bytes() == old, "Manifest changed at replacement boundary")
        os.replace(temporary, manifest)
        record["status"] = "manifest_written_checks_pending"
        require(manifest.read_bytes() == after and sources(root, pins) == expected, "Post-replacement manifest/source drift")
        require(resources(manifest.parent, root) == baseline["resources"], "Post-replacement native resource drift")
        (output / "manifest-after.tres").write_bytes(after)
        record["status"] = "applied"
    except Exception as error:
        record["failure"] = type(error).__name__ + ": " + str(error)
        record["status"] = "failed_" + record["status"]
    finally:
        # Only this exact fresh temporary file is owned. Never roll back another writer's manifest.
        if temporary.exists():
            temporary.unlink()
        encoded = (json.dumps(record, indent=2) + "\n").encode()
        receipt = output / "receipt.json"
        with receipt.open("xb") as stream:
            stream.write(encoded)
        require(receipt.read_bytes() == encoded, "Application receipt readback failed")
    print(json.dumps({"status": record["status"], "failure": record["failure"], "receipt": str(receipt), "receipt_sha256": sha(receipt)}))
    return 1 if record["failure"] else 0


if __name__ == "__main__":
    sys.exit(main())
