"""Pure parser/strict-workload regressions. No engine, files, or native work."""
import json
import unittest
from copy import deepcopy
from review_delivery import ReviewError, cast_summary, require_cast_workload, registered_suites, valid_delivery_checks, DELIVERY_CHECKS


def line(tick, events):
    return f"FLUX2 spell capture: tick {tick} pending 0/0 projectiles 0 fields 0 events " + json.dumps(events)


def paid(wire=145):
    rows = []
    for index in range(12):
        rows.append(line(index * 32 + 2, [{"type": "cast_started", "entity_id": 1, "wire_id": wire}]))
        rows.append(line(index * 32 + 10, [{"type": "projectile_spawned", "owner_id": 1, "projectile_id": index + 1000, "wire_id": wire}]))
    return "\n".join(rows)


class ParserChecks(unittest.TestCase):
    def test_paid_and_idle(self):
        for wire in (145, 1319):
            summary = cast_summary(paid(wire))
            require_cast_workload(summary, wire)
            self.assertEqual(summary["capture_rows"], 24)
        require_cast_workload(cast_summary(""), 0)

    def test_capture_rejections(self):
        valid = paid()
        cases = [valid + "\nFLUX2 spell capture: malformed", valid + "\n" + valid.splitlines()[0],
                 valid.replace('"wire_id": 145', '"wire_id": true', 1),
                 valid.replace('"entity_id": 1', '"entity_id": 2', 1),
                 valid.replace('"owner_id": 1', '"owner_id": 2', 1),
                 valid.replace('"projectile_id": 1000', '"projectile_id": false', 1),
                 line(1, {})]
        for case in cases:
            with self.subTest(case=case[:80]), self.assertRaises(ReviewError):
                cast_summary(case)

    def test_strong_workload_rejections(self):
        original = cast_summary(paid())
        cases = []
        for lane in ("starts", "releases"):
            changed = deepcopy(original); changed[lane].pop(); cases.append(changed)
            changed = deepcopy(original); changed[lane].append(deepcopy(changed[lane][-1])); cases.append(changed)
        changed = deepcopy(original); changed["refusals"].append({"tick": 400, "wire": 145}); cases.append(changed)
        changed = deepcopy(original); changed["releases"][1]["projectile_id"] = 1000; cases.append(changed)
        changed = deepcopy(original); changed["releases"][0]["wire"] = 140; cases.append(changed)
        changed = deepcopy(original); changed["releases"][0]["tick"] = 2; cases.append(changed)
        for case in cases:
            with self.subTest(case=case), self.assertRaises(ReviewError):
                require_cast_workload(case, 145)
        with self.assertRaises(ReviewError):
            require_cast_workload(original, 0)
        with self.assertRaises(ReviewError):
            require_cast_workload(cast_summary(line(1, [])), 0)

    def test_exact_archive_check_set(self):
        expected = {key: True for key in DELIVERY_CHECKS}
        self.assertTrue(valid_delivery_checks(expected))
        for value in ({}, {next(iter(expected)): True}, dict(expected, extra=True), dict.fromkeys(expected, 1), dict.fromkeys(expected, False)):
            self.assertFalse(valid_delivery_checks(value))

    def test_registry_exactness(self):
        valid = 'const SUITES: Array[Script] = [\n\tpreload("res://tests/unit/test_first.gd"),\n]\nreturn filename.trim_prefix("test_").replace("_", "-")'
        self.assertEqual(registered_suites(valid), [("tests/unit/test_first.gd", "first")])
        for source in ("", valid.replace('\n]', '\n# omitted\n]'), valid.replace('\n]', '\n\tpreload("res://tests/unit/test_first.gd"),\n]'), valid.replace('trim_prefix("test_")', 'trim_prefix("other_")')):
            with self.assertRaises(ReviewError):
                registered_suites(source)


if __name__ == "__main__":
    unittest.main()
