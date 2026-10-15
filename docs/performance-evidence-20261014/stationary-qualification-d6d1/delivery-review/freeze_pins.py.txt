"""Freeze explicit reviewer inputs only after all producer gates have passed. No engines."""
import argparse
import json
from pathlib import Path
from review_delivery import Review, ReviewError, digest, registered_suites, valid_delivery_checks

OLD_PINS = ".godot/iteration-20261013/delivery-review-7804/pins.json"
OLD_PINS_SHA = "5b51cdbc5fdb235b6423dbdef9d8f5b74556c8c99a47182f18cf26e48d8b3b11"
ADDITIONAL = (
    "scripts/launch-hex.ps1", "scripts/verify-launcher-lifecycle.ps1", "scripts/test-launcher-lifecycle.ps1",
    "scripts/ci-focused-suites.ps1", "scripts/test-ci-focused-suites.ps1",
    "scripts/check-current-delivery.ps1", "scripts/test-current-delivery.ps1",
    "scripts/package-hex.ps1", "scripts/verify-hex-portable.ps1", "scripts/verify-terrain-pack.ps1",
    "scripts/verify-terrain-pack.gd", "scripts/flux2-common.ps1", "scripts/engine-guard.ps1",
    "docs/current-delivery.json", "tests/run_all.gd",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("repo", "full", "build", "fallback", "terrain-directory", "lifecycle", "output"):
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    review = Review(Path(args.repo))
    folder = review.path(args.output)
    allowed = review.repo / ".godot/iteration-20261013/delivery-review-launcher/freezes"
    review.require(folder.is_relative_to(allowed) and folder != allowed and not folder.exists(), "Fresh contained pin-freeze directory required")
    identity = review.document("content/runtime/runtime_build_identity_v1.json")
    full = review.document(args.full)
    full_state = review.document(full["source"]["current_state_path"], full["source"]["current_state_sha256"])
    review.require(full["tier"] == "full" and full["result"] == "passed" and full["failure"] is None
                   and full["requested_suite_ids"] == [] and full["stderr_bytes"] == 0
                   and full_state["runtime"]["build_identity"] == identity, "Terminal passing Full for current identity required before pin creation")
    paths = {"full": review.path(args.full), "package": review.path(args.build) / "receipt.json",
             "delivery": review.path(args.build) / "delivery-files.json",
             "terrain": review.path(args.terrain_directory) / "terrain-pack.json",
             "terrain_provenance": review.path(args.terrain_directory) / "pack-provenance.json",
             "lifecycle": review.path(args.lifecycle), "fallback": review.path(args.fallback) / "receipt.json"}
    docs = {key: review.document(path) for key, path in paths.items()}
    for key in ("package", "delivery", "lifecycle"):
        review.require(docs[key]["status"] == "passed" and docs[key]["build_id"] == identity["build_id"], "Terminal matching producer receipt required: " + key)
    review.require(docs["package"]["runtime_source_sha256"] == identity["runtime_source_sha256"]
                   and docs["lifecycle"]["runtime_source_sha256"] == identity["runtime_source_sha256"], "Producer source identities differ")
    review.require(valid_delivery_checks(docs["delivery"]["checks"]), "Exact eighteen passing archive checks required")
    review.require(docs["terrain"]["status"] == "passed" and docs["terrain"]["error"] == ""
                   and docs["terrain"]["release_identity"] == identity and docs["terrain"]["decoded_image_count"] == 133
                   and docs["terrain_provenance"]["status"] == "passed" and docs["terrain_provenance"]["error"] is None,
                   "Terminal terrain decode and source-copy evidence required")
    life = docs["lifecycle"]
    review.require(life["schema"] == "hex-launcher-lifecycle-v1" and life["failure"] is None and life["failed_case"] is None
                   and life["selection"] == "explicit_candidate_package"
                   and life["shared_isolated_profile_verified"] is True and life["caller_appdata_restored"] is True
                   and life["input_pins_unchanged"] is True and life["default_selection_unchanged"] is True,
                   "Terminal passing new launcher lifecycle required before pin creation")
    review.require([row["case"] for row in life["cases"]] == ["hearth", "garden", "paid-fire", "paid-all-six-mantle", "reopen"], "All five lifecycle producer rows required")
    review.require(docs["fallback"]["status"] == "passed" and docs["fallback"]["build_id"] != identity["build_id"], "Distinct passed fallback required")
    old = review.document(OLD_PINS, OLD_PINS_SHA)
    registry = registered_suites(review.read("tests/run_all.gd"))
    suite_ids = [row[1] for row in registry]
    review.require([row["id"] for row in full["executed"]["suites"]] == suite_ids
                   and full["executed"]["suite_count"] == len(suite_ids), "Full producer did not report the exact current registry")
    sources = set(old["source_sha256"]) | set(ADDITIONAL) | {row[0] for row in registry}
    sources.update(path.removeprefix("res://") for path in docs["terrain"]["source_sha256"])
    here = Path(__file__).resolve().parent
    sources.update((here / name).relative_to(review.repo).as_posix() for name in ("review_delivery.py", "freeze_pins.py", "test_review.py"))
    source_hashes = {path: digest(review.file(path)) for path in sorted(sources)}
    gates = {key: {"path": path.relative_to(review.repo).as_posix(), "sha256": digest(review.file(path))} for key, path in paths.items()}
    record = {"schema": "hex-frozen-launcher-delivery-review-pins-v1", "identity": identity,
              "suite_ids": suite_ids, "source_sha256": source_hashes, "gate_inputs": gates,
              "inventory_predecessor": {"path": OLD_PINS, "sha256": OLD_PINS_SHA},
              "scope": "Input admission only after terminal matching producer receipts. Selected source/gate hashes and exact registry are frozen here; this is not independent delivery acceptance. Run review_delivery.py against these pins for raw log/count/archive/payload/lifecycle proof. Complete runtime identity calculation remains the separately executed source/Full gate. No engines or promotion."}
    for row in list(review.files.values()):
        review.file(row["path"], row["sha256"])
    folder.mkdir(parents=True, exist_ok=False)
    encoded = (json.dumps(record, indent=2) + "\n").encode()
    output = folder / "pins.json"
    with output.open("xb") as stream:
        stream.write(encoded)
    if output.read_bytes() != encoded:
        raise ReviewError("Pin receipt readback failed")
    print(json.dumps({"status": "inputs_frozen_not_reviewed", "build_id": identity["build_id"], "sources": len(source_hashes), "suites": len(suite_ids), "pins": str(output), "sha256": digest(output)}))


if __name__ == "__main__":
    main()
