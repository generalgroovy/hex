"""Preserve passed 7804 delivery evidence without copying binaries or profiles."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

ROOT = Path("C:/Users/sende/Projects/hex").resolve()
DOCS = ROOT / "docs/iteration-20261013"
HERE = Path(__file__).resolve().parent
EXPECTED_REVIEW = "6044f6f84fd212a45dea53b9feeeeed270a8e2a96a169c2f66ae8adcd0a6a01c"
EXPECTED_CHECKER = "aa83565d5628860c627b8adeba28b3acaa76b8f1242de11a7b11391ad60ccabe"
HELPER = ROOT / "docs/iteration-20261013/portable-lifecycle-harness/verify-final-portable-lifecycle.ps1"
BUILD = ROOT / "exports/hex-checkpoint-20261013-7804"
LIFE = ROOT / ".godot/iteration-20261013/portable-lifecycle-7804-a"
REVIEW = ROOT / ".godot/iteration-20261013/delivery-review/runs/checkpoint-7804-a/review.json"
REPEAT = ROOT / ".godot/iteration-20261013/delivery-review/runs/checkpoint-7804-independent-a/review.json"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def file_sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def obj(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def encoded(value):
    return (json.dumps(value, indent=2, ensure_ascii=True) + "\n").encode("utf-8")


def record(path):
    return {"path": path.relative_to(ROOT).as_posix(), "bytes": path.stat().st_size, "sha256": file_sha(path)}


def archive(name, sources, generated):
    dest = DOCS / name
    assert not dest.exists(), "Fresh archive required: " + str(dest)
    data = {path: source.read_bytes() for path, source in sources.items()}
    assert not set(data).intersection(generated)
    data.update(generated)
    dest.mkdir(parents=True, exist_ok=False)
    rows = []
    for path, value in sorted(data.items()):
        target = dest / path
        assert target.resolve().is_relative_to(dest.resolve())
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as stream:
            stream.write(value)
        assert target.read_bytes() == value
        row = {"path": path, "bytes": len(value), "sha256": sha(value)}
        if path in sources:
            assert sources[path].read_bytes() == value
            row["source"] = sources[path].relative_to(ROOT).as_posix()
        rows.append(row)
    result = {"schema": "hex-evidence-archive-manifest-v1", "build_id": "p61-7804a23eb300",
              "runtime_source_sha256": "7804a23eb300582ede154ca1083664f6c4200a51fa6539c6ddb2810068972120",
              "payload_count": len(rows), "payload_bytes": sum(row["bytes"] for row in rows),
              "profile_contents_archived": False, "binary_payloads_archived": False, "files": rows}
    blob = encoded(result)
    with (dest / "manifest.json").open("xb") as stream:
        stream.write(blob)
    assert (dest / "manifest.json").read_bytes() == blob
    print(json.dumps({"archive": name, "payload_count": len(rows), "payload_bytes": result["payload_bytes"], "manifest_sha256": sha(blob)}))


def main():
    assert sha(REVIEW.read_bytes()) == EXPECTED_REVIEW and REPEAT.read_bytes() == REVIEW.read_bytes()
    combined = obj(REVIEW)
    assert combined["status"] == "passed" and combined["failure"] is None and combined["checks"] == 3789
    assert sha((HERE / "review_delivery.py").read_bytes()) == EXPECTED_CHECKER
    for row in combined["inputs"]:
        path = (ROOT / row["path"]).resolve()
        assert path.is_relative_to(ROOT) and path.stat().st_size == row["bytes"] and file_sha(path) == row["sha256"]
    receipt = obj(LIFE / "receipt.json")
    assert receipt["status"] == "passed" and receipt["failure"] is None
    assert file_sha(HELPER) == receipt["script_sha256"] == "f1527a16db7b90c6f771a8a942ceaf30c78d5922609aff765d72c2f6f5c3cd0e"
    for filename, expected in receipt["package_hashes_before"].items():
        assert file_sha(BUILD / "windows" / filename) == expected
    runtime_line = "FLUX2 runtime build: " + receipt["build_id"] + " | " + receipt["runtime_source_sha256"]
    case_reviews = []
    life_sources = {"receipt.json": LIFE / "receipt.json", "verify-final-portable-lifecycle.ps1": HELPER}
    for row in receipt["cases"]:
        name = row["case"]
        log_path = Path(row["log"])
        assert log_path.parent == LIFE and file_sha(log_path) == row["log_sha256"]
        text = log_path.read_text(encoding="utf-8-sig")
        error_path = Path(str(log_path) + ".err")
        assert error_path.read_bytes() == b""
        assert text.count(runtime_line) == text.count("safe quit: window requested;") == text.count("safe quit: local state flushed and network peer closed") == 1
        assert not re.search(r"^(?:SCRIPT ERROR|ERROR|WARNING|FAIL):", text, re.M)
        captures = []
        previous_tick = -1
        for line in text.splitlines():
            if not line.startswith("FLUX2 spell capture:"):
                continue
            match = re.fullmatch(r"FLUX2 spell capture: tick ([0-9]+) pending [0-9]+/[0-9]+ projectiles [0-9]+ fields [0-9]+ events (.+)", line)
            assert match is not None
            tick = int(match.group(1))
            events = json.loads(match.group(2))
            assert tick > previous_tick and isinstance(events, list)
            previous_tick = tick
            captures.append((tick, events))
        counts = Counter(event["type"] for _, events in captures for event in events)
        starts = [(tick, event) for tick, events in captures for event in events if event["type"] == "cast_started"]
        releases = [(tick, event) for tick, events in captures for event in events if event["type"] == "projectile_spawned"]
        refused = [(tick, event) for tick, events in captures for event in events if event["type"] == "cast_refused"]
        wire = row["paid_wire"]
        if wire:
            stride, startup = (32, 8) if wire == 145 else (193, 12)
            assert wire in (145, 1319) and len(starts) == len(releases) == 12 and not refused
            assert [tick for tick, _ in starts] == [2 + stride * i for i in range(12)]
            assert [tick for tick, _ in releases] == [2 + startup + stride * i for i in range(12)]
            assert all(event["wire_id"] == wire and event["entity_id"] == 1 for _, event in starts)
            assert all(event["wire_id"] == wire and event["owner_id"] == 1 for _, event in releases)
            assert [event["projectile_id"] for _, event in releases] == list(range(1000, 1012))
        else:
            assert not captures
        assert len(starts) == row["accepted_casts"] and len(refused) == row["refused_casts"]
        case_reviews.append({"case": name, "capture_rows": len(captures), "event_counts": dict(sorted(counts.items())),
            "accepted": len(starts), "refused": len(refused), "admission_ticks": [tick for tick, _ in starts],
            "release_ticks": [tick for tick, _ in releases], "release_ids": [event["projectile_id"] for _, event in releases],
            "identity_markers": 1, "window_close_markers": 1, "flushed_markers": 1, "stderr_bytes": 0,
            "log": record(log_path), "stderr": record(error_path)})
        life_sources[name + ".log"] = log_path
        life_sources[name + ".log.err"] = error_path
    profile_root = LIFE / "isolated-roaming/Godot/app_userdata/FLUX 2"
    files = receipt["cases"][-1]["profile_files"]
    assert all(row["profile_files"] == files for row in receipt["cases"])
    assert {p.name for p in profile_root.iterdir() if p.is_file()} == {row["name"] for row in files}
    for row in files:
        path = profile_root / row["name"]
        assert path.stat().st_size == row["bytes"] and file_sha(path) == row["sha256"]
    assert obj(profile_root / "player_preferences_v1.json")["schema_version"] == 11
    life_review = {"schema": "hex-independent-lifecycle-review-v1", "status": "passed", "reviewer": "checkpoint_audit",
        "build_id": receipt["build_id"], "runtime_source_sha256": receipt["runtime_source_sha256"],
        "receipt": record(LIFE / "receipt.json"), "executed_helper": record(HELPER), "cases": case_reviews,
        "total_accepted": 24, "total_refused": 0, "all_five_same_profile_inventory": True, "final_profile_bytes_checked": True,
        "package_hashes_before_equal_current": receipt["package_hashes_before"], "caller_appdata_restored_receipt": receipt["caller_appdata_restored"],
        "independent_gameplay_review": "Gameplay separately reproduced the exact five raw case counts, schedules, wires, unique releases, normal-close/identity markers, empty stderr, final profile inventory and package hashes.",
        "scope": "Actual release executable in one fresh isolated profile across five normal close/reopen cases. Exact paid admissions and releases are observed; ordinary payment follows the source path, not a logged ledger dump. Preference boundary hashes are contemporaneous receipt claims checked against final bytes, not historical file snapshots. No per-tick conservation, full finite expiry, foreground focus, FPS, physical input, audible audio quality, earned progression recovery or leak-proof soak claim. Safe-close markers precede full teardown; checked-runner completion and separate native ownership gates supply the wider lifecycle evidence."}

    # Keep the previous archive immutable; reuse only its explicit safe source inventory.
    before_manifest = obj(DOCS / "delivery-500be/manifest.json")
    delivery_sources = {}
    for row in before_manifest["files"]:
        source = row["source"].replace("exports/hex-iteration-20261013-500be", "exports/hex-checkpoint-20261013-7804").replace("terrain-pack-500be-a", "terrain-pack-7804-a")
        assert source != row["source"]
        delivery_sources[row["path"]] = ROOT / source
    assert len(delivery_sources) == 22
    delivery_review = {"schema": "hex-delivery-archive-review-v1", "status": "passed", "build_id": receipt["build_id"],
        "combined_review": "../delivery-review-7804/review.json", "combined_review_sha256": EXPECTED_REVIEW,
        "independent_repeat_byte_identical": True, "checks_per_execution": 3789,
        "package": combined["sections"]["package"], "terrain": combined["sections"]["terrain"], "standalone_checks": 18,
        "fallback": "exports/hex-iteration-20261013-500be", "fallback_hashes_verified": True,
        "metadata_scope": "Raw package checkpoint_promoted=false and runtime identity candidate_generated_not_promoted are preserved generation-time fields. Later independent qualification is recorded alongside them without rewriting historical receipts. Installer remains NOT_RUN.",
        "scope": "Package payload and ZIP membership/hash/linkage, all18 standalone checks, isolated PCK mount and exact133 terrain images are accepted. No binary payload, profile contents or engine cache is copied; Full and five-case lifecycle retain separate archives. No installer, physical networking, foreground FPS, human feel or audio-quality acceptance."}
    archive("delivery-7804", delivery_sources, {
        "review.json": encoded(delivery_review),
        "README.md": ("# Qualified 7804 portable delivery\n\nThe exact p61-7804a23eb300 portable passed package export/smoke, all 18 standalone archive checks, "
            "and isolated exported-terrain verification (132 chunks plus overview; 2,064 native checks). Two independent executions of the frozen checker each pass 3,789 checks "
            "and produce the same [combined review](../delivery-review-7804/review.json). [Full](../full-7804/README.md) and the [five-case lifecycle](../portable-lifecycle-7804-passed-a/review.json) passed separately.\n\n"
            "The preserved fallback is exports/hex-iteration-20261013-500be. The new package is exports/hex-checkpoint-20261013-7804. Raw receipt generation fields, "
            "including checkpoint_promoted=false and installer NOT_RUN, remain unchanged. Qualification is an accompanying evidence decision, not a rewrite of those fields.\n\n"
            "This archive preserves only exact metadata, scripts and logs; it contains no binary payload or profile contents. manifest.json records all source paths and hashes. "
            "Physical input, foreground FPS, stressed casting smoothness, audible audio quality, installer and physical networking remain separate.\n").encode("utf-8")})
    archive("portable-lifecycle-7804-passed-a", life_sources, {
        "review.json": encoded(life_review),
        "profile-hashes.json": encoded({"schema": "hex-profile-boundary-hashes-v1", "profile_contents_archived": False,
            "boundary_claims": [{"case": row["case"], "files": row["profile_files"]} for row in receipt["cases"]],
            "final_actual_files": [record(profile_root / row["name"]) for row in files], "final_schema_version": 11,
            "scope": "Hashes, sizes and names only; historical per-case files were not separately snapshotted."}),
        "README.md": ("# Passed 7804 shared-profile portable lifecycle\n\nFive sequential actual release-executable cases completed by normal owned-window close: Hearth, Garden, finite paid Fire, "
            "finite paid all-six Mantle, then reopen. Each paid case records exactly 12 admissions and 12 unique releases, with zero refusals or foreign outcomes. "
            "All five logs identify 7804, have empty stderr and normal close/flush markers. Main preferences and their pre-S4 backup retain identical hashes and sizes "
            "at every recorded boundary and in the final actual two-file profile.\n\n"
            "The exact executed f1527a16 helper is archived. Package bytes and all logs were independently checked, including a separate gameplay recount. "
            "Only profile hashes are archived; no profile contents. This proves the declared lifecycle path, not foreground focus/FPS, physical input, full authority ledgers, "
            "earned progression recovery, audible audio quality or a leak-proof soak. Earlier failed 500be attempts remain preserved separately.\n").encode("utf-8")})
    review_sources = {"review.json": REVIEW, "independent-repeat-review.json": REPEAT,
        "review_delivery.py": HERE / "review_delivery.py", "pins.json": HERE / "pins.json",
        "provenance.json": HERE / "provenance.json", "checker-README.md": HERE / "README.md",
        "archive_delivery_7804.py": Path(__file__).resolve()}
    validation = {"schema": "hex-delivery-independent-repeat-v1", "status": "passed", "checks_per_execution": 3789,
        "root_execution": record(REVIEW), "independent_execution": record(REPEAT), "byte_identical": True,
        "checker": record(HERE / "review_delivery.py"), "pins": record(HERE / "pins.json"),
        "current_input_hashes_rechecked": len(combined["inputs"]), "selected_source_pins": 291, "ordered_suite_ids": 265,
        "pin_semantics_peer_review": "Gameplay independently verified all291 current pins, exact265 registry order, same key inventory and five documented changes; checker bytes are unchanged aa83565d.",
        "scope": "Both checks are read-only evidence reviews; neither launches an engine or regenerates runtime identity. Exact source/package/lifecycle bytes were rechecked at the closing archive boundary."}
    archive("delivery-review-7804", review_sources, {
        "independent-validation.json": encoded(validation),
        "README.md": ("# Independent 7804 delivery linkage review\n\nThe unchanged aa83565d checker ran twice independently against only the new 7804 Full, package, terrain and five-case lifecycle receipts. "
            "Both executions passed 3,789 checks and produced byte-identical review.json (SHA6044f6f84fd212a45dea53b9feeeeed270a8e2a96a169c2f66ae8adcd0a6a01c). "
            "The 291 refreshed selected source pins and ordered265 suite IDs were independently peer-reviewed; the complete runtime identity has3444 records.\n\n"
            "Raw source and result paths are preserved by the manifest and independent-validation.json. The old500be checker/pins/evidence remain unchanged. "
            "Profile entries in the combined review are hashes and names only. No engine, source-identity regeneration, new performance measurement or profile-content archival occurred. "
            "Receipt booleans alone are insufficient: actual raw suite sums, payload/ZIP members and hashes, terrain mount/provenance, paid outcome logs and final profile bytes are checked.\n").encode("utf-8")})


if __name__ == "__main__":
    main()
