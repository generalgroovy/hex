"""Deterministic, reviewed atlas assembly; never generates or deforms artwork.

The original image-generator outputs are preserved in source/. The user approved
alpha cleanup, registration and atlas assembly. One uniform scale per source
sheet; no per-pose fitting, mesh baking, invented limbs or mirrored facings.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
OUT = ROOT / "assets/sprites/pixel_body_pilot_v1"
DIRS = ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
ROWS = ["idle", "walk_contact_a", "walk_pass_a", "walk_contact_b", "walk_pass_b", "cast"]
CASES = [
    ("s_wayne", "small", 58, 93, "s-wayne.png", 5),
    ("oh_tipi", "middle", 63, 94, "oh-tipi.png", 4),
    ("red_baron", "large", 68, 96, "red-baron.png", 4),
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def clean(path):
    image = Image.open(path).convert("RGBA")
    # Transparent pixels may carry generated background RGB. Zero them rather
    # than letting hidden RGB bleed into import/mip filters; no shape erosion.
    image.putdata([(r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
                   for r, g, b, a in image.getdata()])
    return image


def bands(image, expected):
    alpha = image.getchannel("A")
    occupied = [y for y in range(image.height)
                if alpha.crop((0, y, image.width, y + 1)).getbbox()]
    groups = []
    for y in occupied:
        if not groups or y - groups[-1][-1] > 4:
            groups.append([])
        groups[-1].append(y)
    if len(groups) != expected:
        raise ValueError(f"Expected {expected} rows; observed {len(groups)}")
    return [(g[0], g[-1] + 1) for g in groups]


def cells(image, columns, expected_rows):
    found = bands(image, expected_rows)
    result = []
    for top, bottom in found:
        row = []
        for col in range(columns):
            # Small authored overhang (notably an open casting hand) may cross
            # a nominal grid boundary into the empty gutter. Preserve it.
            left, right = round(col * image.width / columns) - 12, round((col + 1) * image.width / columns) + 12
            crop = image.crop((left, top, right, bottom))
            crop = isolate_character(crop)
            bbox = crop.getbbox()
            if bbox is None or bbox[0] <= 0 or bbox[2] >= crop.width:
                raise ValueError(f"Empty/clipped cell {col}, row {len(result)}: {bbox}")
            row.append(crop)
        result.append(row)
    return result


def isolate_character(image):
    """Reject neighbouring-cell fragments; never redraw missing source pixels."""
    pixels = image.load()
    pending = {(x, y) for y in range(image.height) for x in range(image.width) if pixels[x, y][3]}
    components = []
    while pending:
        seed = pending.pop()
        stack, component = [seed], [seed]
        while stack:
            x, y = stack.pop()
            for point in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                if point in pending:
                    pending.remove(point)
                    stack.append(point)
                    component.append(point)
        components.append(component)
    if not components:
        return image
    largest = max(components, key=len)
    x0, x1 = min(x for x, _ in largest), max(x for x, _ in largest)
    y0, y1 = min(y for _, y in largest), max(y for _, y in largest)
    result = Image.new("RGBA", image.size)
    target = result.load()
    for component in components:
        # Retain detached outline pixels within the character's envelope.
        if all(x0-2 <= x <= x1+2 and y0-2 <= y <= y1+2 for x, y in component):
            for point in component:
                target[point] = pixels[point]
    return result


def registered(source, factor):
    # Full source cell width retains authored horizontal registration, including
    # asymmetric tails/arms. All rows share one scale, never bbox-fit to canvas.
    box = source.getbbox()
    size = (round(source.width * factor), round(source.height * factor))
    resized = source.resize(size, Image.Resampling.NEAREST)
    ink = resized.getbbox()
    result = Image.new("RGBA", (128, 128))
    result.paste(resized, (64 - size[0] // 2, 104 - ink[3]))
    assert result.getbbox() and result.getbbox()[1] > 0
    return result


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    review = WORK / "review"
    review.mkdir(exist_ok=True)
    entries, provenance = [], []
    board = Image.new("RGBA", (1024, 768), "#31473e")
    for case_index, (identity, body, height, waist, leaf, count) in enumerate(CASES):
        source_path = WORK / "source" / leaf
        source = clean(source_path)
        frames = cells(source, 8, count)
        idle_heights = [frame.getbbox()[3] - frame.getbbox()[1] for frame in frames[0]]
        factor = height / max(idle_heights)
        atlas = Image.new("RGBA", (1024, 768))
        # This bounded pilot has two distinct painted contacts and neutral
        # passing frames, not four newly authored contact poses. State it openly.
        source_rows = [0, 1, 0, 2, 0, count - 1]
        for row, source_row in enumerate(source_rows):
            for facing in range(8):
                frame = registered(frames[source_row][facing], factor)
                atlas.paste(frame, (facing * 128, row * 128))
        if identity == "oh_tipi":
            correction_path = WORK / "source" / "oh-tipi-rear.png"
            correction = cells(clean(correction_path), 2, 4)
            scale = height / max(c.getbbox()[3] - c.getbbox()[1] for c in correction[0])
            for row, source_row in enumerate([0, 1, 0, 2, 0, 3]):
                for source_col, facing in [(0, 3), (1, 5)]:
                    frame = registered(correction[source_row][source_col], scale)
                    atlas.paste(frame, (facing * 128, row * 128))
            provenance.append({"file": "source/oh-tipi-rear.png", "sha256": sha(correction_path.read_bytes()),
                               "role": "explicit rear-diagonal corrections", "uniform_scale": scale})
        atlas.save(OUT / f"{identity}.png")
        entries.append({"id": identity, "body": body, "display_height": height,
                        "waist_y": waist, "atlas": f"{identity}.png", "rgba_sha256": sha(atlas.tobytes())})
        provenance.append({"file": "source/" + leaf, "sha256": sha(source_path.read_bytes()),
                           "source_rows": count, "runtime_source_rows": source_rows, "uniform_scale": factor})
        # Only neutral + two contact rows; full atlas is retained separately.
        for row, actual in enumerate([0, 1]):
            board.alpha_composite(atlas.crop((0, actual * 128, 1024, (actual + 1) * 128)),
                                  (0, (case_index * 2 + row) * 128))
    manifest = {"id": "hex-pixel-body-pilot-v1", "schema_version": 1,
                "cell": [128, 128], "pivot": [64, 104], "directions": DIRS, "rows": ROWS,
                "characters": entries,
                "acceptance": "pilot only; unsupported movement actions retain previous renderer; human acceptance open"}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (review / "assembly.json").write_text(json.dumps({"sources": provenance, "characters": entries,
        "pass_pose_reuse": "Neutral authored frame at both passing beats, not invented intermediate geometry",
        "alpha": "Threshold128 and clear hidden RGB; originals untouched"}, indent=2) + "\n", encoding="utf-8")
    board.save(review / "three-sizes.png")
    print(f"Assembled {len(entries)} pilot banks; 6 runtime rows with explicit neutral passing reuse; no mesh baking")


if __name__ == "__main__":
    main()
