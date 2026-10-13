"""Read-only linkage audit of frozen HEX delivery evidence; never launches an engine."""
import argparse
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path


class ReviewError(Exception):
    pass


DELIVERY_CHECKS = set("packageReceiptPassed runtimeIdentity packHash zipHash payloadInventory zipInventory launcherPixelFlags instructionsPixelChoice instructionsInteraction instructionsAttune instructionsLimits instructionsExtract instructionsSeparateFolders instructionsStandalone instructionsPerformance instructionsPerformanceRules fallbackPackUnchanged fallbackZipUnchanged".split())


def valid_delivery_checks(checks):
    return isinstance(checks, dict) and set(checks) == DELIVERY_CHECKS and all(value is True for value in checks.values())


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def suite_rows(text):
    return [{"id": name, "assertions": int(count), "failures": int(failed)}
            for name, count, failed in re.findall(
                r"^([^:\r\n]+): ([0-9]+) assertions, ([0-9]+) failures$", text, re.M)]


def cast_rows(text):
    rows = []
    pattern = r"^FLUX2 spell capture: tick ([0-9]+) pending [0-9]+/[0-9]+ projectiles [0-9]+ fields [0-9]+ events (.+)$"
    previous_tick = -1
    for line in text.splitlines():
        if not line.startswith("FLUX2 spell capture:"):
            continue
        match = re.fullmatch(pattern, line)
        if match is None:
            raise ReviewError("Malformed capture record")
        tick, raw = match.groups()
        if int(tick) <= previous_tick:
            raise ReviewError("Capture ticks repeat or go backward")
        previous_tick = int(tick)
        events = json.loads(raw)
        if not isinstance(events, list):
            raise ReviewError("Capture event payload is not an array")
        for event in events:
            if event["type"] in ("cast_started", "cast_refused"):
                if type(event.get("wire_id")) is not int:
                    raise ReviewError("Cast outcome lacks an integer wire_id")
                rows.append({"tick": int(tick), "type": event["type"], "wire_id": event["wire_id"]})
    return rows


class Review:
    def __init__(self, repo):
        self.repo = repo.resolve()
        self.checks = 0
        self.files = {}
        self.sections = {}

    def require(self, condition, message):
        self.checks += 1
        if not condition:
            raise ReviewError(message)

    def path(self, value):
        value = str(value).removeprefix("res://")
        path = Path(value)
        path = (path if path.is_absolute() else self.repo / path).resolve()
        self.require(path.is_relative_to(self.repo), "Evidence path escapes repository: " + str(path))
        return path

    def file(self, value, expected=None):
        path = self.path(value)
        self.require(path.is_file(), "Missing evidence file: " + str(path))
        actual = digest(path)
        if expected is not None:
            self.require(isinstance(expected, str) and re.fullmatch(r"[a-f0-9]{64}", expected) is not None,
                         "Invalid SHA pin: " + str(path))
            self.require(actual == expected, "SHA mismatch: " + str(path))
        key = path.relative_to(self.repo).as_posix()
        row = {"path": key, "bytes": path.stat().st_size, "sha256": actual}
        self.require(key not in self.files or self.files[key] == row, "Evidence changed during review: " + key)
        self.files[key] = row
        return path

    def read(self, value, expected=None):
        return self.file(value, expected).read_text(encoding="utf-8-sig")

    def document(self, value, expected=None):
        return json.loads(self.read(value, expected))

    def log(self, value, expected=None):
        text = self.read(value, expected)
        error = self.file(str(self.path(value)) + ".err")
        self.require(error.stat().st_size == 0, "Nonempty stderr: " + str(error))
        self.require(not re.search(r"^(?:SCRIPT ERROR|ERROR|WARNING|FAIL):", text, re.M),
                     "Unexpected error/warning/failure heading: " + str(value))
        return text

    def identity(self, value):
        self.require(value == self.expected, "Identity differs from the frozen candidate")

    def full(self, value):
        receipt = self.document(value)
        self.require(receipt["tier"] == "full" and receipt["result"] == "passed" and receipt["failure"] is None,
                     "Complete successful Full receipt required")
        self.require(receipt["requested_suite_ids"] == [] and receipt["stderr_bytes"] == 0,
                     "Full cannot have selected suites or stderr")
        source, executed = receipt["source"], receipt["executed"]
        state = self.document(source["current_state_path"], source["current_state_sha256"])
        assets = self.document(source["asset_inventory_path"], source["asset_inventory_sha256"])
        self.identity(state["runtime"]["build_identity"])
        for report in (state, assets):
            self.require(report["check"]["passed"] is True and report["check"]["issues"] == [],
                         "Full source/asset report has issues")
        for flag in ("current_state_check", "asset_inventory", "doctor", "import", "post_import_identity_check",
                     "deterministic_suite_runner", "boot_120_hz"):
            self.require(executed[flag] is True, "Full omitted " + flag)
        self.require(receipt["isolation"]["caller_appdata_restored"] is True, "Full did not restore APPDATA")
        logs = {Path(row["path"]).name: self.log(row["path"], row["sha256"]) for row in receipt["logs"]}
        self.require(len(receipt["logs"]) == 3 and set(logs) == {"import.log", "suite.log", "boot-120.log"},
                     "Full log inventory differs")
        rows = suite_rows(logs["suite.log"])
        self.require(rows == executed["suites"], "Raw suite rows differ from receipt")
        self.require([row["id"] for row in rows] == self.pins["suite_ids"], "Full did not execute exact frozen registry")
        self.require(all(row["assertions"] > 0 and row["failures"] == 0 for row in rows), "Suite failures/empty suite")
        self.require(len(rows) == executed["suite_count"] and sum(row["assertions"] for row in rows) == executed["assertion_count"],
                     "Full counts do not reproduce")
        timing_ids = re.findall(r"^SUITE TIMING: ([^ ]+) [0-9]+ ms$", logs["suite.log"], re.M)
        self.require(timing_ids == self.pins["suite_ids"] and logs["suite.log"].count("PASS: all FLUX2 headless suites") == 1,
                     "Full timing/completion inventory differs")
        self.require(self.runtime_line in logs["boot-120.log"] and "FLUX2 match initialized at 120 Hz" in logs["boot-120.log"],
                     "Boot does not identify current runtime at 120 Hz")
        self.sections["full"] = {"suites": len(rows), "assertions": sum(row["assertions"] for row in rows), "stderr_bytes": 0}

    def package(self, build_value, fallback_value):
        build = self.path(build_value)
        package = self.document(build / "receipt.json")
        payload = build / "windows"
        self.require(package["status"] == "passed" and package["build_id"] == self.expected["build_id"]
                     and package["runtime_source_sha256"] == self.expected["runtime_source_sha256"], "Package identity/status differs")
        self.require(self.path(package["executable"]) == payload / "hex.exe", "Package EXE points elsewhere")
        self.identity(self.document(payload / "SOURCE-IDENTITY.json"))
        self.pack = self.file(payload / "hex.pck", package["pack_sha256"])
        state = self.document(payload / "BUILD-STATE.json")
        self.require(state["source_kind"] == "exported_pack" and state["pack_sha256"] == package["pack_sha256"],
                     "BUILD-STATE is not this exported PCK")
        self.identity(state["state"]["runtime"]["build_identity"])
        runtime = state["state"]["runtime"]
        self.require(runtime["protocol"] == self.expected["protocol_version"] and runtime["simulation_hz"] == 120
                     and runtime["preferences_schema"] == 11, "Package runtime contract differs")
        hashes = {}
        for line in self.read(payload / "SHA256SUMS.txt").splitlines():
            match = re.fullmatch(r"([a-f0-9]{64})  ([^/\\]+)", line)
            self.require(match is not None, "Malformed payload hash line")
            sha, name = match.groups()
            self.require(name.casefold() not in {x.casefold() for x in hashes}, "Duplicate payload name")
            self.file(payload / name, sha)
            hashes[name] = sha
        names = {p.name for p in payload.iterdir() if p.is_file()}
        self.require(names == set(hashes) | {"SHA256SUMS.txt"}, "Payload inventory mismatch")
        self.require(all(p.is_file() for p in payload.iterdir()), "Unexpected payload subdirectory")
        archive = self.file(package["zip"], package["zip_sha256"])
        delivery = self.document(build / "delivery-files.json")
        self.require(delivery["status"] == "passed" and delivery["build_id"] == self.expected["build_id"]
                     and delivery["mode"] == "standalone", "Standalone delivery receipt missing")
        zip_rows = []
        with zipfile.ZipFile(archive) as zipped:
            members = zipped.infolist()
            self.require(len(members) == len(names) and len({x.filename.casefold() for x in members}) == len(members),
                         "ZIP membership count/uniqueness mismatch")
            self.require({x.filename for x in members} == names, "ZIP includes missing/extra/nested members")
            for member in members:
                with zipped.open(member) as stream:
                    actual = hashlib.file_digest(stream, "sha256").hexdigest()
                path = self.file(payload / member.filename, actual)
                self.require(path.stat().st_size == member.file_size, "ZIP member size differs")
                zip_rows.append({"name": member.filename, "bytes": member.file_size, "sha256": actual})
        self.require(delivery["zip_bytes"] == archive.stat().st_size
                     and sorted(delivery["zip_entries"], key=lambda x: x["name"]) == sorted(zip_rows, key=lambda x: x["name"]),
                     "Delivery ZIP rows differ from actual bytes")
        self.require(valid_delivery_checks(delivery["checks"]), "Delivery check set is missing, extra or failed")
        launcher = self.read(payload / "PLAY-HEX.cmd")
        readme = self.read(payload / "README-FIRST.txt")
        self.require("--fullbody-art --pixel-cast %*" in launcher, "Launcher lacks tested presentation flags")
        required_text = ("Starting hex.exe directly retains skeleton mode.", "Interact with buildings: F", "Academy > Champions > Attune",
                         "saved weave; uncustomized characters use their starter kit.", "Internet relay is not", "portable local playtest",
                         "Extract the whole ZIP first; do not run from inside the archive.", "PLAY-HEX.cmd to use this build's tested presentation settings.",
                         "Extract each portable into its own folder.", "Keep the previous working folder", "until you have tried the replacement.",
                         "Saved controls and personal weaves are preserved.", "This archive is ready to run; no Godot", "installation or administrator permission is required.",
                         "It contains no installer", "or automatic updater.", "PERFORMANCE", "Menu > Display & text size selects Low or Standard visual detail, a 60, 120 or",
                         "unlimited frame limit, and 100/125/150/200 percent text.", "Low and 60 FPS are the", "defaults. Low trims decorative",
                         "glow and Garden samples while keeping complete spell areas and danger cues.", "Movement, collision and paid spell rules still run at 120 Hz. Reduced Motion",
                         "remains a separate accessibility option.", "Far travel prepares its destination", "before offline movement resumes; saved controls and weaves are retained.")
        self.require(all(text in readme for text in required_text)
                     and not any(text in readme for text in ('Skeleton mode is the default.', '"Install and play"', '"Update and play"')),
                     "Actual portable instructions differ from the reviewed standalone contract")
        self.log(build / "logs/export.log")
        smoke = self.log(build / "logs/export-smoke.log")
        self.require(self.runtime_line in smoke and "safe quit: local state flushed and network peer closed" in smoke,
                     "Package smoke lacks current identity/close")
        fallback = self.path(fallback_value)
        self.require(fallback != build, "Fallback equals candidate")
        old = self.document(fallback / "receipt.json")
        self.require(old["status"] == "passed" and old["build_id"] != self.expected["build_id"], "Preserved fallback receipt invalid")
        self.file(fallback / "windows/hex.pck", old["pack_sha256"])
        self.file(old["zip"], old["zip_sha256"])
        self.payload = payload
        self.sections["package"] = {"payload_files": len(names), "zip_bytes": archive.stat().st_size,
                                    "pack_sha256": package["pack_sha256"], "zip_sha256": package["zip_sha256"]}

    def terrain(self, directory):
        directory = self.path(directory)
        receipt = self.document(directory / "terrain-pack.json")
        provenance = self.document(directory / "pack-provenance.json")
        isolated = directory / "isolated-project"
        self.require(receipt["status"] == "passed" and receipt["error"] == "" and type(receipt["checks"]) is int
                     and receipt["checks"] > 0, "Terrain receipt unsuccessful")
        self.identity(receipt["release_identity"])
        pack_hash = self.sections["package"]["pack_sha256"]
        self.require(receipt["pack_sha256"] == pack_hash and provenance["status"] == "passed" and provenance["error"] is None,
                     "Terrain provenance/status differs")
        for key in ("source_sha256_before", "source_sha256_after", "isolated_sha256_before", "isolated_sha256_after"):
            self.require(provenance[key] == pack_hash, "Terrain copy hash differs: " + key)
        self.require(self.path(provenance["source_pack_path"]) == self.pack, "Terrain source points to another PCK")
        self.file(provenance["isolated_pack_path"], pack_hash)
        self.file(directory / "terrain-pack.json", provenance["decoded_terrain_receipt_sha256"])
        self.file("scripts/verify-terrain-pack.ps1", provenance["wrapper_sha256"])
        self.file("scripts/verify-terrain-pack.gd", receipt["verification_script_sha256"])
        self.file(isolated / "verify-terrain-pack.gd", receipt["verification_script_sha256"])
        for key, name in (("expected-identity", "expected-identity.json"), ("expected-manifest", "expected-terrain-manifest.tres"),
                          ("expected-provenance", "expected-provenance.json")):
            self.file(isolated / name, receipt["expectation_sha256"][key])
        self.identity(self.document(isolated / "expected-identity.json"))
        text = self.read(isolated / "expected-terrain-manifest.tres")
        self.require(text == self.read("assets/environment/wellspring_ground_v1/manifest.tres"), "Terrain manifest copy differs")
        self.require(text.count("Array[Dictionary](") == 1 and text.count('}]),\n"overview"') == 1, "Unsupported terrain descriptor syntax")
        descriptor = json.loads(text.split("descriptor = ", 1)[1].replace("Array[Dictionary](", "", 1).replace('}]),\n"overview"', '}],\n"overview"', 1))
        self.require(receipt["verified_chunks"] == descriptor["chunks"] and receipt["verified_overview"] == descriptor["overview"]
                     and receipt["signature"] == descriptor["signature"], "Native decoded records differ from exact manifest")
        self.require(receipt["source_sha256"] == descriptor["source_sha256"] == self.document(isolated / "expected-provenance.json"),
                     "Terrain source pin sets differ")
        for path, sha in receipt["source_sha256"].items():
            self.file(path, sha)
        images = descriptor["chunks"] + [descriptor["overview"]]
        self.require(len(images) == receipt["decoded_image_count"] == 133
                     and sum(x["size"][0] * x["size"][1] * 4 for x in images) == receipt["decoded_rgba_bytes"], "Terrain image/byte counts differ")
        mount = receipt["mount"]
        self.require(mount["method"] == "ProjectSettings.load_resource_pack" and mount["success"] is True
                     and mount["replace_files"] is False and mount["target_resources_absent_before_mount"] == 136,
                     "Terrain isolated mount contract differs")
        self.require(self.path(mount["path"]) == self.path(provenance["isolated_pack_path"]), "Mount points elsewhere")
        self.file(isolated / "project.godot", mount["minimal_project_sha256"])
        self.require(provenance["minimal_project_sha256_before"] == provenance["minimal_project_sha256_after"] == mount["minimal_project_sha256"],
                     "Minimal project changed")
        self.require(not any((isolated / name).exists() for name in ("assets", "src", "content", "override.cfg")), "Loose terrain fallback exists")
        log = self.log(directory / "engine.log")
        self.require(log.count("TERRAIN_PACK_VERIFY_PASSED ") == 1, "Terrain completion marker missing/duplicated")
        self.sections["terrain"] = {"images": len(images), "native_checks": receipt["checks"], "source_pins": len(receipt["source_sha256"])}

    def lifecycle(self, value, helper):
        receipt = self.document(value)
        self.require(receipt["status"] == "passed" and receipt["failure"] is None and receipt["build_id"] == self.expected["build_id"]
                     and receipt["runtime_source_sha256"] == self.expected["runtime_source_sha256"], "Lifecycle identity/status differs")
        self.file(helper, receipt["script_sha256"])
        expected_hashes = {name: digest(self.file(self.payload / name)) for name in ("hex.exe", "hex.pck", "SOURCE-IDENTITY.json", "BUILD-STATE.json")}
        self.require(receipt["package_hashes_before"] == expected_hashes, "Lifecycle package inputs differ from current payload")
        expected_cases = [("hearth", 0, 20), ("garden", 0, 25), ("paid-fire", 145, 45), ("paid-all-six-mantle", 1319, 45), ("reopen", 0, 20)]
        rows = receipt["cases"]
        self.require([row["case"] for row in rows] == [row[0] for row in expected_cases], "Lifecycle case order/count differs")
        common_root, main_pin, backups, observed = None, None, {}, []
        previous_start = ""
        for row, (name, wire, delay) in zip(rows, expected_cases):
            log_path = self.path(row["log"])
            common_root = log_path.parent if common_root is None else common_root
            self.require(log_path.parent == common_root and log_path.name == name + ".log", "Lifecycle logs do not share one run")
            self.require(row["started_utc"] > previous_start, "Lifecycle order timestamps differ")
            previous_start = row["started_utc"]
            self.require(row["status"] == "passed" and row["paid_wire"] == wire and row["scheduled_close_seconds"] == delay
                         and row["exit_mode"] == "owned-process-normal-window-close" and row["stderr_bytes"] == 0, "Lifecycle case contract differs")
            log = self.log(log_path, row["log_sha256"])
            self.require(log.count(self.runtime_line) == 1 and log.count("safe quit: local state flushed and network peer closed") == 1
                         and "safe quit: window requested;" in log, "Lifecycle lacks exact identity/normal-close markers")
            outcomes = cast_rows(log)
            self.require(all(x["wire_id"] == wire for x in outcomes), "Unexpected cast wire/input in lifecycle case")
            accepted = sum(x["type"] == "cast_started" for x in outcomes)
            refused = sum(x["type"] == "cast_refused" for x in outcomes)
            self.require(accepted == row["accepted_casts"] and refused == row["refused_casts"], "Paid event counts differ from raw log")
            self.require((accepted + refused == 12 and accepted > 0) if wire else not outcomes, "Exact finite paid case gate failed")
            files = {x["name"]: x for x in row["profile_files"]}
            self.require(len(files) == len(row["profile_files"]) and "player_preferences_v1.json" in files, "Profile row missing/duplicated")
            main = files["player_preferences_v1.json"]
            main_pin = main if main_pin is None else main_pin
            self.require(main == main_pin and type(main["bytes"]) is int and main["bytes"] > 0, "Main preferences changed between cases")
            self.require(set(backups).issubset(files), "Previously persisted preference backup disappeared")
            for filename, profile in files.items():
                self.require(Path(filename).name == filename and "/" not in filename and "\\" not in filename, "Invalid profile name")
                if filename.startswith("player_preferences_v1.json."):
                    self.require(filename == "player_preferences_v1.json.pre_s4_controls.bak", "Unreviewed preference backup kind")
                    self.require(profile["sha256"] == main["sha256"] and profile["bytes"] == main["bytes"], "Backup differs from unchanged main preferences")
                    self.require(filename not in backups or backups[filename] == profile, "Immutable preference backup changed")
                    backups[filename] = profile
            observed.append({"case": name, "accepted": accepted, "refused": refused, "preferences_sha256": main["sha256"]})
        profile_root = common_root / "isolated-roaming/Godot/app_userdata/FLUX 2"
        for profile in rows[-1]["profile_files"]:
            path = self.file(profile_root / profile["name"], profile["sha256"])
            self.require(path.stat().st_size == profile["bytes"], "Final profile size differs")
        self.require(self.document(profile_root / "player_preferences_v1.json")["schema_version"] == 11, "Final preferences schema differs")
        self.require(receipt["shared_isolated_profile_verified"] is True and receipt["caller_appdata_restored"] is True,
                     "Lifecycle shared-profile/restoration report failed")
        self.sections["lifecycle"] = {"cases": observed, "shared_profile_root": str(profile_root), "backup_names": sorted(backups)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("repo", "full", "build", "fallback", "terrain-directory", "lifecycle", "lifecycle-helper", "output"):
        parser.add_argument("--" + name, required=True)
    args = parser.parse_args()
    review = Review(Path(args.repo))
    output = review.path(args.output)
    allowed = review.repo / ".godot/iteration-20261013/delivery-review/runs"
    review.require(output.is_relative_to(allowed) and output != allowed and not output.exists(), "Fresh owned output directory required")
    output.mkdir(parents=True, exist_ok=False)
    failure = None
    try:
        helper = Path(__file__).resolve()
        review.file(helper)
        review.pins = review.document(helper.with_name("pins.json"))
        review.expected = review.pins["identity"]
        review.runtime_line = "FLUX2 runtime build: " + review.expected["build_id"] + " | " + review.expected["runtime_source_sha256"]
        for path, sha in review.pins["source_sha256"].items():
            review.file(path, sha)
        review.identity(review.document("content/runtime/runtime_build_identity_v1.json"))
        review.full(args.full)
        review.package(args.build, args.fallback)
        review.terrain(args.terrain_directory)
        review.lifecycle(args.lifecycle, args.lifecycle_helper)
        for row in list(review.files.values()):
            review.file(row["path"], row["sha256"])
    except Exception as error:
        failure = type(error).__name__ + ": " + str(error)
    result = {"schema": "hex-independent-delivery-review-v1", "status": "failed" if failure else "passed",
              "failure": failure, "checks": review.checks, "sections": review.sections,
              "inputs": list(review.files.values()),
              "scope": "Read-only linkage/count/hash review of already executed gates. No engines, source identity regeneration, PCK pixel decoding, physical input/focus/FPS, earned-progress recovery or leak-proof soak. Per-case preference hashes are contemporaneous receipt claims checked for consistency and against final on-disk bytes; historical per-case files are not snapshots. The checked-runner invocation and source/native teardown gates supply process/ownership evidence beyond the safe-close log marker."}
    encoded = (json.dumps(result, indent=2, ensure_ascii=True) + "\n").encode("utf-8")
    path = output / "review.json"
    with path.open("xb") as stream:
        stream.write(encoded)
    if path.read_bytes() != encoded:
        raise ReviewError("Receipt readback differs")
    print(json.dumps({"status": result["status"], "checks": review.checks, "failure": failure,
                      "receipt": str(path), "sha256": digest(path)}))
    return 1 if failure else 0


if __name__ == "__main__":
    sys.exit(main())
