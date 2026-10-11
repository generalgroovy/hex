"""Build compact runtime art from the reviewed shared-head sources, not new art.

Original layered sources are immutable. This deterministic assembly is explicitly
authorized by the user. No resizing, segmentation or guessed new poses occurs here.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_batches/character_motion_v1/output/motion-common-heads-v3"
KEYS = ROOT / "art_batches/character_motion_v1/output/authored-keys-v2"
OUT = ROOT / "assets/sprites/fullbody_cast_v1"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, separators=(",", ":")) + "\n", encoding="utf-8")


def main():
    manifest = json.loads((SOURCE / "manifest.json").read_text())
    keys = json.loads((KEYS / "manifest.json").read_text())
    key_entries = {entry["id"]: entry for entry in keys["characters"]}
    OUT.mkdir(parents=True, exist_ok=True)
    entries = []
    for character in manifest["characters"]:
        source = SOURCE / character["atlas"]
        assert digest(source) == character["atlas_sha256"], character["id"]
        atlas = Image.open(source).convert("RGBA")
        compact = Image.new("RGBA", (1024, 128))
        entry = {k: character[k] for k in ("id", "body", "race", "display_name")}
        entry["directions"] = {}
        for index, name in enumerate(manifest["directions"]):
            direction = character["directions"][name]
            full = direction["layers"]["fullbody"]
            x, y, w, h = full["rect"]
            ox, oy = full["source_origin"]
            assert 0 <= ox + 16 and ox + 16 + w <= 128
            assert 0 <= oy + 20 and oy + 20 + h <= 128
            compact.paste(atlas.crop((x, y, x+w, y+h)), (index*128+int(ox)+16, int(oy)+20))
            entry["directions"][name] = {
                "anchors": direction["anchors"],
                "bindings": {k: v["binding"] for k, v in direction["layers"].items() if k != "fullbody"},
                "vertices": [[*v["point"], *v["parts"], v["weight"]] for v in direction["mesh_vertices"]],
            }
        leaf = character["id"] + ".png"
        compact.save(OUT / leaf)
        entry.update(atlas=leaf, rgba_sha256=hashlib.sha256(compact.tobytes()).hexdigest())
        if character["id"] in key_entries:
            authored = key_entries[character["id"]]
            path = KEYS / authored["atlas"]
            assert digest(path) == authored["atlas_sha256"]
            image = Image.open(path).convert("RGBA")
            assert image.size == (1024, 1024)
            image.save(OUT / authored["atlas"])
            entry["keys"] = {"atlas": authored["atlas"], "rows": authored["rows"],
                             "rgba_sha256": hashlib.sha256(image.tobytes()).hexdigest()}
        entries.append(entry)
    bank = json.loads((SOURCE / manifest["motion_bank"]).read_text())
    # Compact redundant per-frame depth/contact metadata, retaining exact joints.
    for body in bank["bodies"].values():
        for name, frames in body["clips"].items():
            body["clips"][name] = [{"points": f["points"]} for f in frames]
    write_json(OUT / "motions.json", bank)
    write_json(OUT / "manifest.json", {
        "id": "fullbody-cast-candidate-v1", "cell": [128, 128], "pivot": [64, 104],
        "cranial_target_pixels": 18, "anatomical_heights": {"small": 58, "middle": 63, "large": 68},
        "source_manifest_sha256": digest(SOURCE / "manifest.json"),
        "source_key_manifest_sha256": digest(KEYS / "manifest.json"),
        "motions_sha256": digest(OUT / "motions.json"), "characters": entries,
        "acceptance": "in-game visual candidate; shared rig deformations are not final authored animation cycles",
    })
    print(f"PASS: compacted {len(entries)} identities / 240 directions / {len(key_entries)} key-pose pages")


if __name__ == "__main__":
    main()
