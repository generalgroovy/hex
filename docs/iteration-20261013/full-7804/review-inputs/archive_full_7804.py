"""Archive the terminal root-executed Full gate; no engine or source changes."""
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path("C:/Users/sende/Projects/hex").resolve()
HERE = Path(__file__).resolve().parent
DEST = ROOT / "docs/iteration-20261013/full-7804"
SOURCE_RECEIPT = ROOT / ".godot/iteration-20261013/ui-integration/full-7804-a.json"
EXPECTED_HELPER = "aa83565d5628860c627b8adeba28b3acaa76b8f1242de11a7b11391ad60ccabe"
EXPECTED_PINS = "5b51cdbc5fdb235b6423dbdef9d8f5b74556c8c99a47182f18cf26e48d8b3b11"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, indent=2, ensure_ascii=True) + "\n").encode("utf-8")


def main():
    if DEST.exists():
        raise RuntimeError("Fresh Full archive required")
    helper = HERE / "review_delivery.py"
    pins_path = HERE / "pins.json"
    assert sha(helper.read_bytes()) == EXPECTED_HELPER
    assert sha(pins_path.read_bytes()) == EXPECTED_PINS
    spec = importlib.util.spec_from_file_location("frozen_delivery_review_7804", helper)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    review = module.Review(ROOT)
    review.pins = review.document(pins_path, EXPECTED_PINS)
    review.expected = review.pins["identity"]
    review.runtime_line = "FLUX2 runtime build: " + review.expected["build_id"] + " | " + review.expected["runtime_source_sha256"]
    review.require(review.expected["build_id"] == "p61-7804a23eb300", "Wrong source identity")
    review.require(len(review.pins["source_sha256"]) == 291 and len(review.pins["suite_ids"]) == 265, "Wrong frozen inventory")
    for path, expected in review.pins["source_sha256"].items():
        review.file(path, expected)
    review.identity(review.document("content/runtime/runtime_build_identity_v1.json"))
    review.full(SOURCE_RECEIPT)
    receipt = review.document(SOURCE_RECEIPT)
    log_root = review.path(receipt["source"]["current_state_path"]).parent
    review.require((log_root / "receipt.json").read_bytes() == SOURCE_RECEIPT.read_bytes(), "Receipt copies differ")
    review.require(receipt["executed"]["assertion_count"] == 7573807, "Unexpected raw assertion total")
    review.document(log_root / "script-class-cache.json")
    for row in list(review.files.values()):
        review.file(row["path"], row["sha256"])

    sources = {
        "full-7804-a.json": SOURCE_RECEIPT,
        "runtime_build_identity_v1.json": ROOT / "content/runtime/runtime_build_identity_v1.json",
        "review-inputs/pins.json": pins_path,
        "review-inputs/provenance.json": HERE / "provenance.json",
        "review-inputs/review_delivery.py": helper,
        "review-inputs/archive_full_7804.py": Path(__file__).resolve(),
    }
    for name in ("receipt.json", "current-state.json", "asset-inventory.json", "script-class-cache.json",
                 "import.log", "import.log.err", "boot-120.log", "boot-120.log.err", "suite.log", "suite.log.err"):
        sources["logs/" + name] = log_root / name
    blobs = {name: source.read_bytes() for name, source in sources.items()}
    raw = [{"path": name, "source": source.relative_to(ROOT).as_posix(), "bytes": len(blobs[name]), "sha256": sha(blobs[name])}
           for name, source in sources.items()]
    result = {
        "schema": "hex-full-independent-review-v1", "status": "passed", "checks": review.checks,
        "identity": review.expected, "suite_count": len(receipt["executed"]["suites"]),
        "assertion_count": sum(row["assertions"] for row in receipt["executed"]["suites"]),
        "failure_count": sum(row["failures"] for row in receipt["executed"]["suites"]),
        "stderr_bytes": 0, "duration_ms": receipt["duration_ms"],
        "raw_log_rows_equal_receipt": True, "raw_log_ids_and_timing_ids_equal_frozen_registry": True,
        "full_completion_marker_count": 1, "source_pins_checked": 291,
        "headless_worker_suite": next(row for row in receipt["executed"]["suites"] if row["id"] == "wellspring-async-terrain-stream"),
        "reviewer_script": "review-inputs/review_delivery.py", "reviewer_script_sha256": EXPECTED_HELPER,
        "pins_sha256": EXPECTED_PINS, "raw": raw,
        "scope": "Independent read-only recount, hash and linkage review of root-executed Full, using only the Full section of the frozen delivery checker. The exact ordered 265-suite registry, raw assertion sum, all three log hashes and empty stderr files, import/current-state/assets, post-import identity flag, restored APPDATA and 120 Hz boot are required. The 291 selected input pins complement the complete 3444-record runtime identity. No engine, identity regeneration, package or lifecycle check was run by this archive operation. Package, exported terrain, portable lifecycle, physical input, foreground performance and audio quality remain separate."
    }
    blobs["review.json"] = encoded(result)
    blobs["README.md"] = ("# Full gate for p61-7804a23eb300\n\n"
        "Root's terminal Full run passed 265 suites and 7,573,807 assertions with zero failures and empty stderr. "
        "The independent review reproduces the exact ordered suite rows and sum from the raw log, validates all three log hashes, "
        "current-state/assets and identity linkage, verifies 120 Hz boot, and rechecks 291 frozen source/dependency pins.\n\n"
        "Raw bytes and original paths are listed in review.json; manifest.json hashes every payload. "
        "review-inputs preserves the unchanged aa83565d checker, new source pins/provenance and this archival operation. "
        "script-class-cache.json is gate metadata; no profiles, engine cache or portable binaries are archived. "
        "The gate ran against an intentionally dirty reviewed UI integration atop b5745146; the runtime identity is authoritative for source linkage.\n\n"
        "This is headless Full evidence. New package, archive, exported-terrain and five-case portable lifecycle qualification are separate. "
        "The qualified 500be package remains the fallback until those gates pass.\n").encode("utf-8")
    DEST.mkdir(parents=True, exist_ok=False)
    for name, data in blobs.items():
        target = DEST / name
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as stream:
            stream.write(data)
        if target.read_bytes() != data:
            raise RuntimeError("Archive readback differs: " + name)
    for name, source in sources.items():
        if source.read_bytes() != blobs[name]:
            raise RuntimeError("Source changed during archive: " + str(source))
    rows = [{"path": name, "bytes": len(data), "sha256": sha(data)} for name, data in sorted(blobs.items())]
    manifest = {"schema": "hex-evidence-archive-manifest-v1", "payload_count": len(rows),
                "payload_bytes": sum(row["bytes"] for row in rows), "files": rows}
    manifest_bytes = encoded(manifest)
    with (DEST / "manifest.json").open("xb") as stream:
        stream.write(manifest_bytes)
    assert (DEST / "manifest.json").read_bytes() == manifest_bytes
    print(json.dumps({"status": "passed", "checks": review.checks, "suites": result["suite_count"],
                      "assertions": result["assertion_count"], "payload_count": len(rows), "payload_bytes": manifest["payload_bytes"],
                      "review_sha256": sha(blobs["review.json"]), "manifest_sha256": sha(manifest_bytes)}))


if __name__ == "__main__":
    main()
