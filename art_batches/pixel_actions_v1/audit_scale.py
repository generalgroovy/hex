"""Read-only idle/action continuity diagnostics; never assembles or edits images.

Full silhouettes are pose-dependent and cannot establish anatomical scale.
Optional hash-bound landmark spans must be selected by a reviewer. This tool
does not discover heads, approve anatomy, or prescribe a runtime multiplier.
"""
import argparse
import hashlib
import json
from pathlib import Path
import statistics

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DIRECTIONS = ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
ACTIONS = ["jumpsquat", "rise", "fall", "land"]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def cell_bounds(image, row):
    """Return local alpha bounds, never RGB bounds or an anatomy estimate."""
    if image.size != (1024, 512) or image.mode != "RGBA":
        raise ValueError("Expected an existing 1024x512 RGBA atlas")
    result = []
    for column, direction in enumerate(DIRECTIONS):
        tile = image.getchannel("A").crop((column * 128, row * 128,
                                           (column + 1) * 128, (row + 1) * 128))
        box = tile.getbbox()
        if box is None:
            raise ValueError(f"Blank required cell: {row}/{direction}")
        result.append({"direction": direction, "bounds": list(box),
                       "width": box[2] - box[0], "height": box[3] - box[1],
                       "bottom_from_pivot": box[3] - 104})
    return result


def measured_span(value):
    """A manually reviewed scalar pixel span and its stated uncertainty."""
    if not isinstance(value, dict) or set(value) != {"pixels", "uncertainty"}:
        raise ValueError("Span needs pixels and uncertainty")
    pixels, uncertainty = value["pixels"], value["uncertainty"]
    if (type(pixels) not in (int, float) or type(uncertainty) not in (int, float)
            or not 0 < pixels <= 128 or not 0 <= uncertainty < pixels):
        raise ValueError("Invalid finite pixel span or uncertainty")
    return pixels, uncertainty


def compare_landmarks(record, ground_hash, action_hash):
    """Compare identified anatomy; no silhouette-derived recommendation.

    Overlapping ratio intervals indicate only whether one uniform scale could
    satisfy the measured spans. They cannot certify unmeasured views/poses.
    """
    if not isinstance(record, dict):
        raise ValueError("Landmark record must be an object")
    if record.get("ground_sha256") != ground_hash or record.get("action_sha256") != action_hash:
        raise ValueError("Landmarks are stale or refer to different atlas bytes")
    if not isinstance(record.get("reviewer"), str) or not record["reviewer"].strip():
        raise ValueError("Landmarks require an identified reviewer")
    measurements = record.get("measurements")
    if not isinstance(measurements, list) or not measurements:
        raise ValueError("At least one explicit anatomical span is required")
    comparisons = []
    for measurement in measurements:
        if not isinstance(measurement, dict):
            raise ValueError("Measurement must be an object")
        if (not isinstance(measurement.get("name"), str) or not measurement["name"].strip()
                or not isinstance(measurement.get("definition"), str) or not measurement["definition"].strip()
                or measurement.get("direction") not in DIRECTIONS
                or measurement.get("action") not in ACTIONS):
            raise ValueError("Describe each anatomical span, facing, and action")
        ground, ground_error = measured_span(measurement.get("idle"))
        action, action_error = measured_span(measurement.get("posed"))
        comparisons.append({"name": measurement["name"], "definition": measurement["definition"],
                            "direction": measurement["direction"], "action": measurement["action"],
                            "idle_over_action": ground / action,
                            "ratio_interval": [(ground - ground_error) / (action + action_error),
                                               (ground + ground_error) / (action - action_error)]})
    lower = max(item["ratio_interval"][0] for item in comparisons)
    upper = min(item["ratio_interval"][1] for item in comparisons)
    return {"reviewer": record["reviewer"], "comparisons": comparisons,
            "median_ratio": statistics.median(item["idle_over_action"] for item in comparisons),
            "common_ratio_interval": [lower, upper] if lower <= upper else None,
            "uniform_scale_feasibility": "NOT_ESTABLISHED_SINGLE_SPAN" if len(comparisons) < 2 else
                ("MEASURED_SPANS_ONLY" if lower <= upper else "CONFLICTING_ANATOMICAL_SPANS"),
            "native_motion_acceptance": "NOT_RUN", "automatic_correction": False}


def inspect_pair(identity, body, ground_path, action_path, landmarks=None):
    ground_hash, action_hash = digest(ground_path), digest(action_path)
    with Image.open(ground_path) as ground, Image.open(action_path) as action:
        idle = cell_bounds(ground, 0)
        rows = {name: cell_bounds(action, row) for row, name in enumerate(ACTIONS)}
    idle_max = max(cell["height"] for cell in idle)
    fall_max = max(cell["height"] for cell in rows["fall"])
    result = {"id": identity, "body": body, "ground_sha256": ground_hash,
              "action_sha256": action_hash, "idle": idle, "actions": rows,
              "maximum_idle_height": idle_max, "maximum_fall_height": fall_max,
              "maximum_height_difference": fall_max - idle_max,
              "anatomical_scale": "NOT_MEASURED", "automatic_correction": False}
    if landmarks is not None:
        result["anatomical_scale"] = compare_landmarks(landmarks, ground_hash, action_hash)
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--landmarks", type=Path,
                        help="Optional JSON object keyed by character id; measured spans and exact atlas hashes")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    roster = json.loads((root / "content/champions/foundation_champions_v1.json").read_text(encoding="utf-8"))["champions"]
    identities = [entry["id"] for entry in roster]
    if len(identities) != 30 or len(set(identities)) != 30:
        raise ValueError("Audit requires the exact 30-identity catalog")
    landmarks = json.loads(args.landmarks.read_text(encoding="utf-8")) if args.landmarks else {}
    if not isinstance(landmarks, dict) or set(landmarks) - set(identities):
        raise ValueError("Landmarks must be keyed only by current catalog identities")
    characters = [inspect_pair(entry["id"], entry["body_type"],
                              root / "assets/sprites/pixel_cast_v1" / (entry["id"] + ".png"),
                              root / "assets/sprites/pixel_actions_v1" / (entry["id"] + ".png"),
                              landmarks.get(entry["id"])) for entry in roster]
    print(json.dumps({"scope": "read-only atlas/optional manual-landmark diagnostics",
                      "anatomical_acceptance": "NOT_ESTABLISHED", "automatic_correction": False,
                      "equal_maximum_idle_fall_height_count": sum(
                          entry["maximum_height_difference"] == 0 for entry in characters),
                      "character_count": len(characters), "characters": characters}, indent=2))


if __name__ == "__main__":
    main()
