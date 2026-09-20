"""Bounded static verification for the shared-template attachment/layer contract."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import re
import sys
from pathlib import Path, PurePosixPath
from typing import Any


HERE = Path(__file__).resolve().parent
DEFAULT_CONTRACT = HERE / "attachment-layer-contract.v1.json"
MAX_JSON_BYTES = 1_048_576
MAX_RIG_JSON_BYTES = 16_777_216
MAX_PROVENANCE_FILES = 16
MAX_JOINTS = 64
IDENTIFIER = re.compile(r"^[a-z][a-z0-9_]{0,63}$")
TOKEN = re.compile(r"[a-z0-9]+")


class ContractError(ValueError):
    pass


def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ContractError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json(path: Path, maximum_bytes: int = MAX_JSON_BYTES) -> dict[str, Any]:
    size = path.stat().st_size
    if size > maximum_bytes:
        raise ContractError(f"JSON exceeds {maximum_bytes} bytes: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=reject_duplicate_keys)
    except (OSError, UnicodeError, json.JSONDecodeError, RecursionError) as exc:
        raise ContractError(f"cannot read bounded JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ContractError(f"top-level JSON must be an object: {path}")
    return value


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def repo_root() -> Path:
    for candidate in (HERE, *HERE.parents):
        if (candidate / "project.godot").is_file() and (candidate / ".git").exists():
            return candidate.resolve()
    raise ContractError("repository root not found above verifier")


def exact_keys(value: dict[str, Any], expected: set[str], label: str) -> None:
    actual = set(value)
    if actual != expected:
        raise ContractError(f"{label} fields differ; missing={sorted(expected-actual)}, unknown={sorted(actual-expected)}")


def verify_contract(contract: dict[str, Any]) -> None:
    root = repo_root()
    expected_top = {
        "schema_version", "id", "status", "authority", "source_provenance",
        "registration", "sizes", "rig", "layer_declaration",
        "forbidden_layer_families", "approval_gate",
    }
    exact_keys(contract, expected_top, "contract")
    if contract["schema_version"] != 1 or contract["id"] != "flux-shared-template-attachment-layers-v1":
        raise ContractError("unsupported contract identity or schema")
    if contract["status"] != "preparation_only_pending_human_shared_template_approval":
        raise ContractError("contract status must remain preparation-only")

    registration = contract["registration"]
    if registration.get("cell") != [96, 96] or registration.get("feet_pivot") != [48, 84] or registration.get("last_opaque_y") != 83:
        raise ContractError("registration drifted from fixed 96px/pivot48,84/opaque-y83 contract")

    expected_sizes = {
        "small": (58, 58, "58/58"),
        "middle": (68, 63, "63/68"),
        "large": (76, 68, "68/76"),
    }
    sizes = contract["sizes"]
    if set(sizes) != set(expected_sizes):
        raise ContractError("body sizes must be exactly small, middle, large")
    for body, (source_height, display_height, ratio) in expected_sizes.items():
        entry = sizes[body]
        exact_keys(entry, {"rig_source_height", "display_height", "presentation_scale", "exact_scale_ratio"}, f"sizes.{body}")
        if entry["rig_source_height"] != source_height or entry["display_height"] != display_height or entry["exact_scale_ratio"] != ratio:
            raise ContractError(f"size values drifted for {body}")
        if not math.isclose(entry["presentation_scale"], display_height / source_height, rel_tol=0.0, abs_tol=1e-15):
            raise ContractError(f"presentation scale is not display/source for {body}")

    provenance = contract["source_provenance"]
    if not isinstance(provenance, list) or not 1 <= len(provenance) <= MAX_PROVENANCE_FILES:
        raise ContractError("source_provenance count is outside the bounded range")
    seen_paths: set[str] = set()
    source_by_role: dict[str, dict[str, str]] = {}
    for index, entry in enumerate(provenance):
        if not isinstance(entry, dict):
            raise ContractError(f"source_provenance[{index}] must be an object")
        exact_keys(entry, {"role", "path", "sha256"}, f"source_provenance[{index}]")
        relative = PurePosixPath(entry["path"])
        if relative.is_absolute() or ".." in relative.parts or "\\" in entry["path"]:
            raise ContractError(f"unsafe provenance path: {entry['path']}")
        source = (root / Path(*relative.parts)).resolve()
        if root not in source.parents or not source.is_file() or source.is_symlink():
            raise ContractError(f"missing, external, or linked provenance source: {entry['path']}")
        if entry["path"] in seen_paths:
            raise ContractError(f"duplicate provenance path: {entry['path']}")
        seen_paths.add(entry["path"])
        actual_hash = sha256(source)
        if actual_hash != entry["sha256"]:
            raise ContractError(f"provenance hash mismatch for {entry['path']}: expected {entry['sha256']}, got {actual_hash}")
        source_by_role[entry["role"]] = entry

    required_roles = {
        "current_cast_proportions_authority", "three_body_construction_contract",
        "fixed_bone_pose_model", "rig_export_schema", "rig_export_snapshot",
        "current_fixed_bone_raster_baker", "current_character_style_pack_assembler",
    }
    if set(source_by_role) != required_roles:
        raise ContractError("provenance roles differ from the reviewed bounded source set")

    rig_entry = source_by_role["rig_export_snapshot"]
    rig_data = load_json(root / Path(*PurePosixPath(rig_entry["path"]).parts), MAX_RIG_JSON_BYTES)
    rig_contract = contract["rig"]
    if rig_data.get("schema_version") != rig_contract.get("schema_version"):
        raise ContractError("rig schema version mismatch")
    if rig_data.get("cell") != registration["cell"] or rig_data.get("pivot") != registration["feet_pivot"]:
        raise ContractError("rig registration differs from layer registration")
    if rig_data.get("directions") != rig_contract.get("directions") or rig_data.get("base_rows") != rig_contract.get("base_rows"):
        raise ContractError("rig direction or base-row vocabulary mismatch")
    if rig_data.get("heights") != {body: values[0] for body, values in expected_sizes.items()}:
        raise ContractError("rig source heights differ from reviewed values")
    if rig_data.get("rig_sha256") != source_by_role["fixed_bone_pose_model"]["sha256"]:
        raise ContractError("rig snapshot does not point to the reviewed pose model hash")

    joints = rig_contract.get("joint_names")
    if not isinstance(joints, list) or not 1 <= len(joints) <= MAX_JOINTS or len(joints) != len(set(joints)):
        raise ContractError("joint_names must be a small unique list")
    expected_joints = set(joints)
    poses = rig_data.get("poses")
    if not isinstance(poses, list) or len(poses) != 3312:
        raise ContractError("reviewed rig snapshot must contain exactly 3312 poses")
    for index, pose in enumerate(poses):
        if set(pose.get("points", {})) != expected_joints or set(pose.get("landmarks", {})) != expected_joints:
            raise ContractError(f"pose {index} joint vocabulary differs from contract")
        for chain in pose.get("chains", []):
            if not set(chain.get("keys", [])).issubset(expected_joints):
                raise ContractError(f"pose {index} chain contains an unknown joint")

    declaration = contract["layer_declaration"]
    required_layer_fields = ["id", "semantic", "depth_band", "anchors", "texture"]
    if declaration.get("required_layer_fields") != required_layer_fields:
        raise ContractError("layer declaration fields drifted")
    if declaration.get("template_ids") != ["template_small", "template_middle", "template_large"]:
        raise ContractError("template IDs must remain generic and size-only")
    if declaration.get("maximum_layers") != 64 or declaration.get("maximum_anchors_per_layer") != 8:
        raise ContractError("layer declaration bounds drifted")
    forbidden = contract["forbidden_layer_families"]
    if not isinstance(forbidden, list) or not {"weapon", "magic", "shadow"}.issubset(forbidden):
        raise ContractError("required leakage families are missing")


def string_tokens(value: str) -> set[str]:
    return set(TOKEN.findall(value.lower()))


def verify_candidate(candidate: dict[str, Any], contract: dict[str, Any], label: str) -> None:
    exact_keys(candidate, {"schema_version", "contract_id", "template_id", "body_type", "layers"}, label)
    if candidate["schema_version"] != 1 or candidate["contract_id"] != contract["id"]:
        raise ContractError(f"{label}: unsupported schema or contract_id")
    body = candidate["body_type"]
    expected_template = f"template_{body}"
    if body not in contract["sizes"] or candidate["template_id"] != expected_template:
        raise ContractError(f"{label}: template_id must be the generic size template {expected_template}")
    layers = candidate["layers"]
    maximum_layers = contract["layer_declaration"]["maximum_layers"]
    if not isinstance(layers, list) or not 1 <= len(layers) <= maximum_layers:
        raise ContractError(f"{label}: layers must contain 1..{maximum_layers} entries")

    required = set(contract["layer_declaration"]["required_layer_fields"])
    semantics = set(contract["layer_declaration"]["allowed_semantics"])
    depth_bands = set(contract["layer_declaration"]["allowed_depth_bands"])
    known_anchors = set(contract["rig"]["joint_names"])
    forbidden = set(contract["forbidden_layer_families"])
    maximum_anchors = contract["layer_declaration"]["maximum_anchors_per_layer"]
    seen_ids: set[str] = set()
    seen_textures: set[str] = set()

    for index, layer in enumerate(layers):
        layer_label = f"{label}.layers[{index}]"
        if not isinstance(layer, dict):
            raise ContractError(f"{layer_label} must be an object")
        exact_keys(layer, required, layer_label)
        layer_id = layer["id"]
        if not isinstance(layer_id, str) or not IDENTIFIER.fullmatch(layer_id) or layer_id in seen_ids:
            raise ContractError(f"{layer_label}: invalid or duplicate id")
        seen_ids.add(layer_id)
        if layer["semantic"] not in semantics:
            raise ContractError(f"{layer_label}: forbidden or unknown semantic {layer['semantic']!r}")
        if layer["depth_band"] not in depth_bands:
            raise ContractError(f"{layer_label}: unknown depth_band {layer['depth_band']!r}")
        anchors = layer["anchors"]
        if not isinstance(anchors, list) or not 1 <= len(anchors) <= maximum_anchors or len(anchors) != len(set(anchors)):
            raise ContractError(f"{layer_label}: anchors must be a small unique nonempty list")
        unknown = set(anchors) - known_anchors
        if unknown:
            raise ContractError(f"{layer_label}: unknown anchors {sorted(unknown)}")
        texture = layer["texture"]
        if not isinstance(texture, str):
            raise ContractError(f"{layer_label}: texture must be a string")
        texture_path = PurePosixPath(texture)
        if texture_path.is_absolute() or ".." in texture_path.parts or "\\" in texture or texture_path.suffix.lower() != ".png":
            raise ContractError(f"{layer_label}: unsafe or non-PNG texture path")
        if texture in seen_textures:
            raise ContractError(f"{layer_label}: duplicate texture path")
        seen_textures.add(texture)
        checked_strings = [layer_id, layer["semantic"], layer["depth_band"], texture, *anchors]
        leaked = set().union(*(string_tokens(value) for value in checked_strings)) & forbidden
        if leaked:
            raise ContractError(f"{layer_label}: forbidden layer-family leakage {sorted(leaked)}")


def self_test(contract: dict[str, Any]) -> None:
    safe = {
        "schema_version": 1,
        "contract_id": contract["id"],
        "template_id": "template_small",
        "body_type": "small",
        "layers": [{
            "id": "plain_clothing_front",
            "semantic": "plain_clothing",
            "depth_band": "front",
            "anchors": ["neck", "pelvis", "shoulder_l", "shoulder_r"],
            "texture": "layers/plain-clothing-front.png",
        }],
    }
    verify_candidate(safe, contract, "self_test.safe")
    failures = {
        "unknown_anchor": ("anchors", ["neck", "hat_socket"]),
        "weapon_leakage": ("id", "weapon_front"),
        "magic_leakage": ("texture", "layers/magic-front.png"),
        "shadow_leakage": ("semantic", "shadow"),
    }
    for name, (field, value) in failures.items():
        bad = copy.deepcopy(safe)
        bad["layers"][0][field] = value
        try:
            verify_candidate(bad, contract, f"self_test.{name}")
        except ContractError:
            continue
        raise ContractError(f"self-test failed to reject {name}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidates", nargs="*", type=Path, help="candidate layer declaration JSON files")
    parser.add_argument("--contract", type=Path, default=DEFAULT_CONTRACT)
    parser.add_argument("--self-test", action="store_true", help="prove bounded safe/unknown-anchor/weapon/magic/shadow cases")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        contract = load_json(args.contract.resolve())
        verify_contract(contract)
        if args.self_test:
            self_test(contract)
        for candidate_path in args.candidates:
            verify_candidate(load_json(candidate_path.resolve()), contract, str(candidate_path))
    except (ContractError, OSError, TypeError, KeyError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    checks = ["contract", "provenance", "3312-pose-anchor-vocabulary"]
    if args.self_test:
        checks.append("safe-plus-4-rejection-self-tests")
    if args.candidates:
        checks.append(f"{len(args.candidates)}-candidate-file(s)")
    print("PASS: " + "; ".join(checks))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
