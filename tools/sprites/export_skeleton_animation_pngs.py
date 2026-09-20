#!/usr/bin/env python3
"""Export one transparent PNG per skeleton size and animation.

The committed atlases remain the Godot runtime source. This tool produces simple
per-animation sheets for editing, review, mods, or external pipelines.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from PIL import Image


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    repo = args.repo.resolve()
    manifest_path = repo / "content/animations/skeleton_animation_manifest_v1.json"
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    cell_w, cell_h = data["cell_size"]
    block_w, block_h = data["atlas_layout"]["block_size"]
    for size_id, size in data["sizes"].items():
        atlas_path = repo / size["atlas"].removeprefix("res://")
        atlas = Image.open(atlas_path).convert("RGBA")
        target = args.output / size_id
        target.mkdir(parents=True, exist_ok=True)
        for animation_id, animation in data["animations"].items():
            column, row = animation["block"]
            frames = animation["frames"]
            left = column * block_w
            top = row * block_h
            sheet = atlas.crop((left, top, left + frames * cell_w, top + block_h))
            sheet.save(target / f"{animation_id}.png", optimize=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
