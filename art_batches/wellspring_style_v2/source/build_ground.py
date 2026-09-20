#!/usr/bin/env python3
"""Terrain-only integer-pixel derivative; never writes the historical pixel pack."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
ORIGINAL = REPO / "art_batches/pixel_v1/map"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    spec = importlib.util.spec_from_file_location("original_map_pixels", ORIGINAL / "source/build_kit.py")
    kit = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(kit)
    palette = json.loads((ROOT / "source/palette.json").read_text())
    kit.P = {name: tuple(bytes.fromhex(value.lstrip("#"))) + (255,) for name, value in palette.items()}

    def material(family, variant=0):
        base, edge, light = kit.MATERIAL[family]
        im = Image.new("RGBA", (32, 32), kit.P[base])
        draw = ImageDraw.Draw(im)
        rng = random.Random(8713 + kit.FAMILIES.index(family) * 91 + variant * 37)
        if family == "paving":
            # Two staggered courses, chipped joints, broad quiet slab faces.
            # The shared two-pixel collar retains original autotile seams.
            for row in range(2):
                y = 2 + row * 14
                for left in [-16, 16] if row else [0]:
                    x0, x1 = max(2, left + 1), min(29, left + 31)
                    if x1 < x0:
                        continue
                    fill = kit.P[["pave", "pave_warm", "pave_cool"][(row + variant + (left > 0)) % 3]]
                    draw.rectangle((x0, y, x1, y + 11), fill=fill)
                    draw.line((x0, y + 12, x1, y + 12), fill=kit.P[edge])
                    draw.line((x0 + 2, y, min(x1, x0 + 12), y), fill=kit.P[light])
                    if x0 > 2:
                        draw.line((x0, y + 1, x0, y + 11), fill=kit.P[edge])
            if variant in (1, 3):
                draw.line((8 + variant, 7, 11 + variant, 7), fill=kit.P["pave_wear"])
            if variant == 2:
                draw.line((24, 24, 27, 24), fill=kit.P["moss_seam"])
        elif family == "grass":
            for index in range(9):
                x, y = rng.randrange(4, 25), rng.randrange(4, 26)
                tint = kit.P[["grass", "grass_dark", "grass_light"][index % 3]]
                draw.rectangle((x, y, x + rng.randrange(2, 5), y + 1), fill=tint)
                if index % 3 == 2:
                    draw.line((x + 1, y - 2, x + 1, y), fill=tint)
        elif family == "earth":
            for index in range(7):
                x, y = rng.randrange(4, 25), rng.randrange(4, 26)
                tint = kit.P["soil_dark" if index % 3 == 0 else "soil_light"]
                draw.rectangle((x, y, x + rng.randrange(2, 5), y + 1), fill=tint)
            if variant == 1:
                draw.line((13, 13, 15, 12), fill=kit.P["moss_seam"])
        elif family == "worldbone":
            draw.line((3, 16, 28, 16), fill=kit.P[edge])
            draw.line((4, 17, 17, 17), fill=kit.P[light])
            draw.line((17, 4, 17, 15), fill=kit.P[edge])
            draw.line((9, 18, 9, 28), fill=kit.P[edge])
        else:
            for x, y, length in [(5, 9, 8), (18, 22, 6)]:
                draw.line((x, y, x + length, y), fill=kit.P[light])
                draw.line((x + 2, y + 1, x + length - 1, y + 1), fill=kit.P[edge])
        return im

    kit.inner_texture = material
    original = json.loads((ORIGINAL / "manifest.json").read_text())
    atlas_meta = next(item for item in original["atlases"] if item["group"] == "terrain")
    atlas = Image.new("RGBA", tuple(atlas_meta["size_px"]), (0, 0, 0, 0))
    tiles = []
    for asset in original["assets"]:
        if asset["group"] != "terrain":
            continue
        tile = asset["autotile"]
        family = tile["family"]
        if "mask" in tile:
            pixels = kit.terrain_tile(family, tile["mask"])
        elif "variant" in tile:
            pixels = material(family, tile["variant"])
        else:
            pixels = kit.corner_image(family, tile["corner"].upper(), tile["kind"])
        rect = asset["atlas_frames"][0]["rect"]
        atlas.paste(pixels, tuple(rect[:2]))
        tiles.append({"id": asset["id"], "rect": rect})
    runtime = ROOT / "runtime"
    runtime.mkdir(parents=True, exist_ok=True)
    path = runtime / "terrain.png"
    atlas.save(path, optimize=True)
    manifest = {
        "schema_version": 1,
        "authority": "presentation_only",
        "base_manifest_sha256": digest(ORIGINAL / "manifest.json"),
        "base_source_sha256": digest(ORIGINAL / "source/build_kit.py"),
        "palette_sha256": digest(ROOT / "source/palette.json"),
        "generator_sha256": digest(Path(__file__)),
        "atlas": "res://art_batches/wellspring_style_v2/runtime/terrain.png",
        "size": list(atlas.size),
        "png_bytes": path.stat().st_size,
        "png_sha256": digest(path),
        "rgba_sha256": hashlib.sha256(atlas.tobytes()).hexdigest(),
        "tiles": tiles,
        "scope": "135 terrain tiles only; original cardinal/corner contracts; no architecture, props, collision, navigation or material authority",
    }
    (runtime / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    # Independent pixel contract: binary alpha, identical original alpha masks,
    # and matching fill collars. No resized/rasterized vector source is used.
    original_atlas = Image.open(ORIGINAL / atlas_meta["path"]).convert("RGBA")
    checks = 0
    for entry in tiles:
        x, y, w, h = entry["rect"]
        old = original_atlas.crop((x, y, x + w, y + h))
        new = atlas.crop((x, y, x + w, y + h))
        assert old.getchannel("A").tobytes() == new.getchannel("A").tobytes(), entry["id"]
        assert set(new.getchannel("A").getdata()) <= {0, 255}, entry["id"]
        checks += 2
    for family in kit.FAMILIES:
        for variant in range(4):
            pixels = material(family, variant)
            for offset in range(32):
                assert pixels.getpixel((0, offset)) == pixels.getpixel((31, offset))
                assert pixels.getpixel((offset, 0)) == pixels.getpixel((offset, 31))
                checks += 2
    receipt = {"status": "passed", "checks": checks, "tiles": len(tiles), "decoded_atlas_bytes": atlas.width * atlas.height * 4,
               "runtime_draws_added": 0, "human_acceptance": "not_run", "renderer_validation": "not_run_by_python"}
    (ROOT / "source/build-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"PASS: {len(tiles)} terrain tiles; {checks} alpha/seam checks; {atlas.width}x{atlas.height}; isolated source derivative")


if __name__ == "__main__":
    main()
