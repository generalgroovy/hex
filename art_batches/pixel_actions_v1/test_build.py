"""Standalone deterministic assembly tests. Never imports/runs Godot or writes assets."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from PIL import Image

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("action_build", HERE / "build.py")
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


def tree_bytes(path):
    return {str(file.relative_to(path)): file.read_bytes() for file in path.rglob("*") if file.is_file()}


class ActionAssemblyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.roster = build.load_roster(build.CATALOG, {})
        cls.wayne = next(entry for entry in cls.roster if entry["id"] == "s_wayne")
        cls.plan = build.prepare([cls.wayne], HERE / "source", build.GROUND, available=True)

    def setUp(self):
        self.owner = tempfile.TemporaryDirectory(prefix="hex-action-builder-test-")
        self.addCleanup(self.owner.cleanup)
        self.temp = Path(self.owner.name)

    def lead_review_fixture(self):
        directory = self.temp / "source" / "s_wayne"
        directory.mkdir(parents=True)
        source = directory / "proportion-repair-v3.png"
        source.write_bytes((HERE / "source" / "s_wayne" / source.name).read_bytes())
        receipt = directory / "receipt.json"
        receipt.write_bytes((HERE / "source" / "s_wayne" / receipt.name).read_bytes())
        value = {"id": "s_wayne", "source_sha256": build.sha(source.read_bytes()),
                 "accepted": True, "reviewer": "integration-lead",
                 "review_scope": "assembled-native-pixel-board", "reason": "Native pixels and all action rows reviewed."}
        path = directory / "lead-review.json"
        path.write_bytes(build.json_bytes(value))
        return directory.parent, path, value

    def test_s_wayne_png_and_rgba_remain_exact(self):
        files, review, report = self.plan
        self.assertEqual(files["s_wayne.png"], (build.OUT / "s_wayne.png").read_bytes())
        self.assertEqual(build.sha(files["s_wayne.png"]), build.LEGACY_PNG)
        with Image.open(io.BytesIO(files["s_wayne.png"])) as atlas:
            self.assertEqual(atlas.size, (1024, 512))
            self.assertEqual(atlas.mode, "RGBA")
            self.assertEqual(build.sha(atlas.tobytes()), build.LEGACY_RGBA)
            self.assertTrue(set(atlas.getchannel("A").getdata()).issubset({0, 255}))
        self.assertEqual(len(report["sources"][0]["cells"]), 32)
        self.assertAlmostEqual(report["sources"][0]["scale"], 58 / 195)
        with Image.open(io.BytesIO(review["boards/s_wayne.png"])) as board:
            self.assertEqual(board.size, (1024, 640))

    def test_manifest_matches_runtime_geometry_and_exact_ids(self):
        files, _, _ = self.plan
        manifest = json.loads(files["manifest.json"])
        self.assertEqual(manifest["id"], "hex-pixel-actions-v1")
        self.assertEqual(manifest["schema_version"], 1)
        self.assertEqual(manifest["cell"], [128, 128])
        self.assertEqual(manifest["pivot"], [64, 104])
        self.assertEqual(manifest["directions"], ["S", "SE", "E", "NE", "N", "NW", "W", "SW"])
        self.assertEqual(manifest["rows"], ["jumpsquat", "rise", "fall", "land"])
        self.assertEqual(manifest["characters"], [{"id": "s_wayne", "body": "small", "atlas": "s_wayne.png", "rgba_sha256": build.LEGACY_RGBA}])

    def test_all_30_catalog_ids_are_unique_and_supported(self):
        self.assertEqual(len({entry["id"] for entry in self.roster}), 30)
        self.assertEqual({entry["body_type"] for entry in self.roster}, set(build.HEIGHTS))

    def test_malformed_recipes_rejected(self):
        invalid = [[], None, {"scale": 2}, {"source_row_count": True}, {"source_row_count": 4.0},
                   {"source_row_count": 17}, {"source_rows": [0, 1, 2]}, {"source_rows": [0, 1, 2, 2]},
                   {"source_rows": [0, 1, 2, 4]}, {"source_columns": [0] * 8}, {"source_columns": list(range(9))},
                   {"source_columns": [False, 1, 2, 3, 4, 5, 6, 7]}, {"column_padding": -1},
                   {"column_padding": 65}, {"columns_by_row": []}, {"columns_by_row": {"4": list(range(8))}},
                   {"columns_by_row": {"0": [0] * 8}}]
        for value in invalid:
            with self.subTest(value=value), self.assertRaises(ValueError):
                build.recipe(value, "oh_tipi")
        with self.assertRaisesRegex(ValueError, "locked"):
            build.recipe({"column_padding": 32}, "s_wayne")

    def test_reviewed_row_and_column_permutations(self):
        config = build.recipe({"source_row_count": 5, "source_rows": [1, 0, 4, 3],
                               "source_columns": [7, 6, 5, 4, 3, 2, 1, 0],
                               "columns_by_row": {"2": list(range(8))}, "column_padding": 20}, "oh_tipi")
        self.assertEqual(config["source_rows"], [1, 0, 4, 3])
        self.assertEqual(config["columns_by_row"]["2"], list(range(8)))

    def test_optional_neutral_calibration_does_not_change_legacy_recipe(self):
        config = build.recipe({}, "oh_tipi")
        self.assertNotIn("calibration_source_row", config)
        self.assertEqual(config, {"source_row_count": 4, "source_rows": [0, 1, 2, 3],
                                 "source_columns": list(range(8)), "columns_by_row": {}, "column_padding": 32})
        self.assertNotIn("calibration", self.plan[2]["sources"][0])
        self.assertEqual(self.plan[0]["s_wayne.png"], (build.OUT / "s_wayne.png").read_bytes())

    def test_invalid_neutral_calibration_rows_rejected(self):
        valid = {"source_row_count": 5, "source_rows": [1, 2, 3, 4], "calibration_source_row": 0}
        for value in [True, False, None, 0.0, "0", -1, 5, 1, 2, 3, 4]:
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "calibration_source_row"):
                build.recipe(dict(valid, calibration_source_row=value), "oh_tipi")
        with self.assertRaisesRegex(ValueError, "locked"):
            build.recipe(valid, "s_wayne")
        with self.assertRaisesRegex(ValueError, "separate neutral"):
            build.recipe({"calibration_source_row": 0}, "oh_tipi")

    @staticmethod
    def neutral_source_fixture():
        # Test geometry only, never saved or presented as artwork. Five disjoint
        # rows have different heights, with a 60px neutral and a 58px fall.
        source = Image.new("RGBA", (800, 400))
        for row, height in enumerate([60, 50, 55, 58, 40]):
            for column in range(8):
                source.paste((80 + row * 20, 120, 160, 255),
                             (column * 100 + 40, row * 80 + 10,
                              column * 100 + 55 + column, row * 80 + 10 + height))
        return source

    def test_neutral_calibration_uses_one_factor_and_measures_all_directions(self):
        config = build.recipe({"source_row_count": 5, "source_rows": [1, 2, 3, 4],
                               "calibration_source_row": 0, "source_columns": list(reversed(range(8)))}, "oh_tipi")
        measurements = {}
        atlas, factor, boxes = build.assemble(self.neutral_source_fixture(), "middle", config, measurements)
        self.assertEqual(factor, 63 / 60)
        self.assertNotEqual(factor, 63 / 58)
        self.assertEqual(measurements["source_row"], 0)
        self.assertEqual(measurements["maximum_source_height"], 60)
        self.assertEqual(measurements["scale"], factor)
        self.assertEqual([cell["direction"] for cell in measurements["cells"]], build.assembly.DIRS)
        self.assertEqual([cell["height"] for cell in measurements["cells"]], [60] * 8)
        self.assertEqual([cell["ink"][2] - cell["ink"][0] for cell in measurements["cells"]], list(range(22, 14, -1)))
        self.assertEqual(atlas.size, build.ATLAS_SIZE)
        self.assertEqual(len(boxes), 32)
        self.assertTrue(all(cell["ink"][3] == 104 for cell in boxes))
        self.assertLess(max(cell["ink"][3] - cell["ink"][1] for cell in boxes if cell["row"] == 2), 63)
        self.assertEqual(len({max(cell["ink"][3] - cell["ink"][1] for cell in boxes if cell["row"] == row)
                              for row in range(4)}), 4)

    def test_neutral_calibration_report_and_review_remain_nonruntime(self):
        identity = "oh_tipi"
        directory = self.temp / "source" / identity
        directory.mkdir(parents=True)
        (directory / "source.png").write_bytes(build.png_bytes(self.neutral_source_fixture()))
        (directory / "receipt.json").write_bytes(build.json_bytes({"test_fixture": True}))
        (directory / "assembly.json").write_bytes(build.json_bytes({"source_row_count": 5,
            "source_rows": [1, 2, 3, 4], "calibration_source_row": 0}))
        champion = next(entry for entry in self.roster if entry["id"] == identity)
        before = tree_bytes(directory)
        _, _, report = build.prepare([champion], directory.parent, build.GROUND, available=True)
        source = report["sources"][0]
        self.assertEqual(source["calibration"]["scale"], 63 / 60)
        self.assertEqual(len(source["calibration"]["cells"]), 8)
        self.assertEqual(source["assembly_sha256"], build.sha((directory / "assembly.json").read_bytes()))
        self.assertIn("explicit neutral", report["registration"])
        self.assertFalse(report["runtime_publication"])
        self.assertEqual(tree_bytes(directory), before)

    def test_neutral_full_review_requires_fresh_raw_assembly_hash(self):
        identity = "oh_tipi"
        directory = self.temp / "source" / identity
        directory.mkdir(parents=True)
        source_data = build.png_bytes(self.neutral_source_fixture())
        recipe_data = build.json_bytes({"source_row_count": 5, "source_rows": [1, 2, 3, 4],
                                        "calibration_source_row": 0})
        (directory / "source.png").write_bytes(source_data)
        (directory / "receipt.json").write_bytes(build.json_bytes({"test_fixture": True}))
        (directory / "assembly.json").write_bytes(recipe_data)
        review_path = directory / "lead-review.json"
        review = {"id": identity, "source_sha256": build.sha(source_data), "accepted": True,
                  "reviewer": "integration-lead", "review_scope": "assembled-native-pixel-board",
                  "reason": "Test geometry only", "assembly_sha256": build.sha(recipe_data)}
        champion = next(entry for entry in self.roster if entry["id"] == identity)
        for value in [None, "0" * 64, True, 1, [], {}]:
            invalid = dict(review)
            if value is None:
                del invalid["assembly_sha256"]
            else:
                invalid["assembly_sha256"] = value
            review_path.write_bytes(build.json_bytes(invalid))
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "assembly_sha256"):
                build.prepare([champion], directory.parent, build.GROUND)
        review_path.write_bytes(build.json_bytes(review))
        _, _, report = build.prepare([champion], directory.parent, build.GROUND)
        self.assertEqual(report["lead_review_gate"], "passed")
        self.assertEqual(report["sources"][0]["assembly_sha256"], review["assembly_sha256"])
        # Semantically equivalent JSON is intentionally still a different review
        # input. Review must bind raw selected bytes, not a normalized recipe.
        (directory / "assembly.json").write_bytes(recipe_data + b"\n")
        with self.assertRaisesRegex(ValueError, "assembly_sha256"):
            build.prepare([champion], directory.parent, build.GROUND)

    def test_alpha_cleanup_threshold_and_hidden_rgb(self):
        image = Image.new("RGBA", (32, 16), (91, 82, 73, 0))
        image.putpixel((3, 4), (12, 34, 56, 127))
        image.putpixel((4, 4), (23, 45, 67, 128))
        cleaned = build.source_image(build.png_bytes(image))
        self.assertEqual(cleaned.getpixel((0, 0)), (0, 0, 0, 0))
        self.assertEqual(cleaned.getpixel((3, 4)), (0, 0, 0, 0))
        self.assertEqual(cleaned.getpixel((4, 4)), (23, 45, 67, 255))

    def test_blank_edge_clipped_and_oversized_sources_rejected(self):
        blank = Image.new("RGBA", (32, 16))
        edge = blank.copy()
        edge.putpixel((0, 4), (1, 2, 3, 255))
        wide = Image.new("RGBA", (8193, 16))
        for source in (blank, edge, wide):
            with self.subTest(size=source.size), self.assertRaises(ValueError):
                build.source_image(build.png_bytes(source))

    def test_duplicate_action_poses_rejected(self):
        cell = Image.new("RGBA", (100, 100))
        cell.paste((90, 120, 150, 255), (35, 5, 65, 95))
        frames = [[cell.copy() for _ in range(8)] for _ in range(4)]
        with mock.patch.object(build, "source_cells", return_value=frames), self.assertRaisesRegex(ValueError, "Duplicate"):
            build.assemble(Image.new("RGBA", (32, 16)), "small", {})

    def test_output_clipping_rejected_before_paste(self):
        cell = Image.new("RGBA", (300, 100))
        cell.paste((90, 120, 150, 255), (1, 5, 299, 95))
        frames = [[cell.copy() for _ in range(8)] for _ in range(4)]
        with mock.patch.object(build, "source_cells", return_value=frames), self.assertRaisesRegex(ValueError, "clipped"):
            build.assemble(Image.new("RGBA", (32, 16)), "large", {})

    def test_changed_inputs_rejected(self):
        source = self.temp / "input.json"
        source.write_bytes(b"one")
        watched = {}
        build.snapshot(source, watched)
        source.write_bytes(b"two")
        with self.assertRaisesRegex(ValueError, "Input changed"):
            build.stable_inputs(watched)

    def test_valid_lead_review_is_watched_and_full_wayne_remains_exact(self):
        source_root, review_path, value = self.lead_review_fixture()
        before = tree_bytes(source_root)
        watched = {}
        files, _, report = build.prepare([self.wayne], source_root, build.GROUND, watched=watched)
        self.assertEqual(files["s_wayne.png"], self.plan[0]["s_wayne.png"])
        self.assertEqual(report["lead_review_gate"], "passed")
        self.assertTrue(report["runtime_publication"])
        self.assertEqual(watched[review_path], build.sha(build.json_bytes(value)))
        self.assertEqual(report["sources"][0]["lead_review_sha256"], watched[review_path])
        self.assertEqual(tree_bytes(source_root), before)

    def test_lead_review_requires_exact_identity_hash_boolean_and_scope(self):
        _, path, valid = self.lead_review_fixture()
        invalid = []
        for key in valid:
            missing = valid.copy()
            del missing[key]
            invalid.append((f"missing {key}", missing))
        for key, values in {
            "id": [None, True, 1, [], {}, "oh_tipi", "s_wayne "],
            "source_sha256": [None, True, 1, [], {}, "0" * 64, valid["source_sha256"].upper()],
            "accepted": [False, None, 0, 1, 1.0, "true", "HOLD", [], {}],
            "reviewer": [None, True, 1, [], {}, "worker", "integration-lead "],
            "review_scope": [None, True, 1, [], {}, "source-sheet", "assembled-native-pixel-board "],
            "reason": [None, True, 1, [], {}, "", " \t\r\n"],
        }.items():
            invalid.extend((f"{key}={value!r}", dict(valid, **{key: value})) for value in values)
        for label, value in invalid:
            path.write_bytes(build.json_bytes(value))
            with self.subTest(case=label), self.assertRaisesRegex(ValueError, "lead-review.json"):
                build.load_lead_review(path, {}, "s_wayne", valid["source_sha256"])

    def test_missing_empty_malformed_and_nonobject_lead_reviews_rejected(self):
        _, path, valid = self.lead_review_fixture()
        path.unlink()
        with self.assertRaisesRegex(ValueError, "Missing"):
            build.load_lead_review(path, {}, "s_wayne", valid["source_sha256"])
        for data in (b"", b"not-json", b"null", b"[]", b"true", b"1", b'"accepted"', b"{}"):
            path.write_bytes(data)
            with self.subTest(data=data), self.assertRaises(ValueError):
                build.load_lead_review(path, {}, "s_wayne", valid["source_sha256"])

    def test_invalid_lead_reviews_fail_before_any_output_staging(self):
        source_root, path, valid = self.lead_review_fixture()
        output, review = self.temp / "runtime", self.temp / "review"
        for target in (output, review):
            target.mkdir()
            (target / "manifest.json").write_bytes(b"working-manifest")
            (target / "s_wayne.png").write_bytes(b"working-png")
        cases = [None, dict(valid, source_sha256="0" * 64), dict(valid, id="oh_tipi"),
                 dict(valid, accepted=False), dict(valid, accepted=1), dict(valid, reason=" "), []]
        for value in cases:
            if value is None:
                path.unlink(missing_ok=True)
            else:
                path.write_bytes(build.json_bytes(value))
            before = tree_bytes(self.temp)
            # Catalog validation has its own tests; isolate the publication gate
            # with one real source and the real main/prepare path.
            with self.subTest(review=value), mock.patch.object(build, "load_roster", return_value=[self.wayne]), \
                    mock.patch.object(build, "publish") as publish, \
                    self.assertRaisesRegex(ValueError, "No output changed.*lead-review.json"):
                build.main(["--source-root", str(source_root), "--output", str(output), "--review-output", str(review)])
            publish.assert_not_called()
            self.assertEqual(tree_bytes(self.temp), before)

    def test_lead_review_change_during_assembly_is_rejected(self):
        source_root, path, valid = self.lead_review_fixture()
        assemble = build.assemble

        def assemble_then_hold(*args):
            result = assemble(*args)
            path.write_bytes(build.json_bytes(dict(valid, accepted=False)))
            return result

        with mock.patch.object(build, "assemble", side_effect=assemble_then_hold), \
                self.assertRaisesRegex(ValueError, "Input changed.*lead-review.json"):
            build.prepare([self.wayne], source_root, build.GROUND)

    def test_lead_review_change_at_commit_preserves_old_outputs(self):
        source_root, path, valid = self.lead_review_fixture()
        watched = {}
        files, reviews, _ = build.prepare([self.wayne], source_root, build.GROUND, watched=watched)
        runtime, review = self.temp / "runtime", self.temp / "review"
        for target in (runtime, review):
            target.mkdir()
            (target / "manifest.json").write_bytes(b"working-manifest")
        before = {target: tree_bytes(target) for target in (runtime, review)}

        def hold_before_commit():
            path.write_bytes(build.json_bytes(dict(valid, accepted=False)))
            build.stable_inputs(watched)

        with self.assertRaisesRegex(ValueError, "Input changed.*lead-review.json"):
            build.publish([(review, reviews, False), (runtime, files, True)], before_commit=hold_before_commit)
        self.assertEqual({target: tree_bytes(target) for target in (runtime, review)}, before)
        self.assertFalse(list(self.temp.glob(".*-stage-*")))

    def test_accepted_lead_review_cannot_override_wayne_png_lock(self):
        source_root, _, _ = self.lead_review_fixture()
        wrong_atlas = Image.new("RGBA", build.ATLAS_SIZE, (1, 2, 3, 255))
        with mock.patch.object(build, "assemble", return_value=(wrong_atlas, 1.0, [])), \
                self.assertRaisesRegex(ValueError, "exact original runtime PNG"):
            build.prepare([self.wayne], source_root, build.GROUND)

    def test_missing_sources_do_not_touch_any_outputs(self):
        output, review = self.temp / "runtime", self.temp / "review"
        for target in (output, review):
            target.mkdir()
            (target / "manifest.json").write_bytes(b"working-manifest")
            (target / "s_wayne.png").write_bytes(b"working-png")
        before = tree_bytes(self.temp)
        with self.assertRaisesRegex(ValueError, "No output changed"):
            build.main(["--source-root", str(self.temp / "missing"), "--output", str(output), "--review-output", str(review)])
        self.assertEqual(tree_bytes(self.temp), before)

    def test_receipt_required_and_malformed_receipt_rejected(self):
        directory = self.temp / "source" / "s_wayne"
        directory.mkdir(parents=True)
        (directory / "proportion-repair-v3.png").write_bytes(b"incomplete-authoring-file")
        for receipt in (None, b"[]", b"{}", b"not-json"):
            if receipt is not None:
                (directory / "receipt.json").write_bytes(receipt)
            with self.subTest(receipt=receipt), self.assertRaisesRegex(ValueError, "No valid"):
                build.prepare([self.wayne], directory.parent, build.GROUND, available=True)

    def test_available_publishes_only_review_bank(self):
        output, review = self.temp / "runtime", self.temp / "review"
        output.mkdir()
        (output / "manifest.json").write_bytes(b"working-manifest")
        before = tree_bytes(output)
        with contextlib.redirect_stdout(io.StringIO()):
            result = build.main(["--available", "--only", "s_wayne", "--output", str(output), "--review-output", str(review)])
        self.assertEqual(result, 0)
        self.assertEqual(tree_bytes(output), before)
        self.assertEqual((review / "s_wayne.png").read_bytes(), self.plan[0]["s_wayne.png"])
        self.assertTrue(json.loads((review / "assembly.json").read_bytes())["partial_review"])
        self.assertTrue((review / "boards/s_wayne.png").is_file())

    def test_available_keeps_missing_stale_and_held_reviews_inspectable_only(self):
        source_root, path, valid = self.lead_review_fixture()
        output, review = self.temp / "runtime", self.temp / "review"
        output.mkdir()
        (output / "manifest.json").write_bytes(b"working-manifest")
        before = tree_bytes(output)
        for value in (None, dict(valid, accepted=False), dict(valid, source_sha256="0" * 64), []):
            if value is None:
                path.unlink(missing_ok=True)
            else:
                path.write_bytes(build.json_bytes(value))
            with self.subTest(review=value), contextlib.redirect_stdout(io.StringIO()):
                result = build.main(["--available", "--only", "s_wayne", "--source-root", str(source_root),
                                     "--output", str(output), "--review-output", str(review)])
            self.assertEqual(result, 0)
            self.assertEqual(tree_bytes(output), before)
            report = json.loads((review / "assembly.json").read_bytes())
            self.assertTrue(report["partial_review"])
            self.assertFalse(report["runtime_publication"])
            self.assertEqual(report["lead_review_gate"], "not_required_partial_review")
            self.assertEqual((review / "s_wayne.png").read_bytes(), self.plan[0]["s_wayne.png"])

    def test_publish_preserves_imports_and_exact_png(self):
        target = self.temp / "bank"
        target.mkdir()
        (target / "s_wayne.png.import").write_bytes(b"existing-import-metadata")
        build.publish([(target, self.plan[0], True)])
        self.assertEqual((target / "s_wayne.png.import").read_bytes(), b"existing-import-metadata")
        self.assertEqual((target / "s_wayne.png").read_bytes(), self.plan[0]["s_wayne.png"])
        self.assertEqual([path.name for path in self.temp.iterdir()], ["bank"])

    def test_failed_second_publication_rolls_back_both_directories(self):
        runtime, review = self.temp / "runtime", self.temp / "review"
        for target in (runtime, review):
            target.mkdir()
            (target / "manifest.json").write_bytes(b"old-manifest")
            (target / "untouched.txt").write_bytes(b"preserve")
        before = tree_bytes(self.temp)
        replace = build.os.replace

        def fail_runtime_install(source, destination):
            if Path(source).name == "next" and Path(destination) == runtime:
                raise OSError("simulated locked runtime directory")
            return replace(source, destination)

        with mock.patch.object(build.os, "replace", side_effect=fail_runtime_install), self.assertRaisesRegex(OSError, "simulated"):
            build.publish([(review, self.plan[1], False), (runtime, self.plan[0], True)])
        self.assertEqual(tree_bytes(self.temp), before)

    def test_validation_after_staging_preserves_old_outputs(self):
        target = self.temp / "runtime"
        target.mkdir()
        (target / "manifest.json").write_bytes(b"old-manifest")
        before = tree_bytes(self.temp)
        with self.assertRaisesRegex(ValueError, "changed"):
            build.publish([(target, self.plan[0], True)], before_commit=lambda: (_ for _ in ()).throw(ValueError("source changed")))
        self.assertEqual(tree_bytes(self.temp), before)

    def test_failed_rollback_retains_recoverable_original(self):
        target = self.temp / "runtime"
        target.mkdir()
        (target / "manifest.json").write_bytes(b"old-manifest")
        replace = build.os.replace

        def fail_install_and_restore(source, destination):
            if Path(destination) == target:
                raise OSError("simulated persistent destination lock")
            return replace(source, destination)

        with mock.patch.object(build.os, "replace", side_effect=fail_install_and_restore), self.assertRaises(OSError):
            build.publish([(target, self.plan[0], True)])
        backups = list(self.temp.glob(".runtime-stage-*/previous/manifest.json"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), b"old-manifest")

    def test_output_overlap_and_unknown_ids_rejected(self):
        for args in (["--available", "--review-output", str(build.OUT)],
                     ["--available", "--review-output", str(build.GROUND)],
                     ["--available", "--review-output", str(self.temp / "bank"), "--output", str(self.temp / "bank")],
                     ["--only", "s_wayne"], ["--available", "--only", "not_a_champion"]):
            with self.subTest(args=args), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                build.main(args)


if __name__ == "__main__":
    unittest.main()
