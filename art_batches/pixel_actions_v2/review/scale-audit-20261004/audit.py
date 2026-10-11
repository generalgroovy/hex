"""Read current approved/runtime pixels; compose inspection-only comparisons.

No assembly, source fitting, alpha cleanup, pose generation or runtime writes.
Only pixel-exact crops, nearest-neighbour inspection magnification, and labels.
"""
from hashlib import sha256
import json
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent
ROOT = Path(__file__).resolve().parents[4]
GROUND = ROOT / "assets/sprites/pixel_cast_v1"
ACTION = ROOT / "assets/sprites/pixel_actions_v1"
DIRECTIONS = ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
POSES = ["idle", "anticipation", "rise", "fall", "landing"]
BG = "#30463d"


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def inspect_cell(cell):
    alpha = cell.getchannel("A")
    box = alpha.getbbox()
    return {
        "bounds": list(box) if box else None,
        "width": box[2] - box[0] if box else 0,
        "height": box[3] - box[1] if box else 0,
        "ink_pixels": sum(value > 0 for value in alpha.getdata()),
        "solid_pixels": sum(value == 255 for value in alpha.getdata()),
        "rgba_sha256": sha256(cell.tobytes()).hexdigest(),
    }


def main():
    manifests = {}
    entries = {}
    for name, directory in [("ground", GROUND), ("actions", ACTION)]:
        path = directory / "manifest.json"
        manifest = json.loads(path.read_text(encoding="utf-8"))
        assert manifest["directions"] == DIRECTIONS
        assert manifest["cell"] == [128, 128]
        manifests[name] = {"path": str(path), "sha256": digest(path)}
        entries[name] = {row["id"]: row for row in manifest["characters"]}
    assert len(entries["ground"]) == len(entries["actions"]) == 30
    assert set(entries["ground"]) == set(entries["actions"])
    report = {"scope": "Current runtime PNG pixels against approved first-row idle; inspection only", "manifests": manifests, "characters": []}
    pages = []
    ground_pages = []
    for number, identity in enumerate(entries["ground"]):
        ground_path = GROUND / entries["ground"][identity]["atlas"]
        action_path = ACTION / entries["actions"][identity]["atlas"]
        with Image.open(ground_path) as src:
            ground = src.convert("RGBA")
        with Image.open(action_path) as src:
            action = src.convert("RGBA")
        assert ground.size == action.size == (1024, 512)
        assert sha256(ground.tobytes()).hexdigest() == entries["ground"][identity]["rgba_sha256"]
        assert sha256(action.tobytes()).hexdigest() == entries["actions"][identity]["rgba_sha256"]
        # Same approved 128px cell and pivot for every pose, without content fit.
        board = Image.new("RGBA", (1024, 664), BG)
        board.alpha_composite(ground.crop((0, 0, 1024, 128)), (0, 24))
        board.alpha_composite(action, (0, 152))
        draw = ImageDraw.Draw(board)
        draw.text((8, 6), identity + " | idle / anticipation / rise / fall / landing", fill="white")
        for column, direction in enumerate(DIRECTIONS):
            draw.text((column * 128 + 106, 9), direction, fill="#f6d984")
        board.save(OUT / (identity + "-native.png"))
        cells = [[ground.crop((col * 128, 0, (col + 1) * 128, 128)) for col in range(8)]]
        cells += [[action.crop((col * 128, row * 128, (col + 1) * 128, (row + 1) * 128)) for col in range(8)] for row in range(4)]
        ground_cells = [[ground.crop((col * 128, row * 128, (col + 1) * 128, (row + 1) * 128)) for col in range(8)] for row in range(4)]
        measurements = [{"pose": POSES[row], "directions": {DIRECTIONS[col]: inspect_cell(cells[row][col]) for col in range(8)}} for row in range(5)]
        report["characters"].append({
            "id": identity,
            "body": entries["ground"][identity]["body"],
            "ground_png_sha256": digest(ground_path),
            "action_png_sha256": digest(action_path),
            "measurements": measurements,
            "ground_measurements": [{"pose": ["idle", "walk_a", "walk_b", "cast"][row], "directions": {DIRECTIONS[col]: inspect_cell(ground_cells[row][col]) for col in range(8)}} for row in range(4)],
        })
        page_number = number // 5
        if page_number == len(pages):
            pages.append(Image.new("RGBA", (1280, 5 * 280), BG))
            ground_pages.append(Image.new("RGBA", (1024, 5 * 280), BG))
        page = pages[page_number]
        top = number % 5 * 280
        labels = ImageDraw.Draw(page)
        labels.text((12, top + 5), identity + " | " + entries["ground"][identity]["body"] + " | SOUTH pixels at 2x; no per-pose fitting", fill="white")
        for row, pose in enumerate(POSES):
            thumb = cells[row][0].resize((256, 256), Image.Resampling.NEAREST)
            page.alpha_composite(thumb, (row * 256, top + 20))
            labels.text((row * 256 + 8, top + 22), pose, fill="#f6d984")
        ground_page = ground_pages[page_number]
        ground_labels = ImageDraw.Draw(ground_page)
        ground_labels.text((12, top + 5), identity + " | GROUND/Cast SOUTH at 2x; no per-pose fitting", fill="white")
        for row, pose in enumerate(["idle", "walk_a", "walk_b", "cast"]):
            ground_page.alpha_composite(ground_cells[row][0].resize((256, 256), Image.Resampling.NEAREST), (row * 256, top + 20))
            ground_labels.text((row * 256 + 8, top + 22), pose, fill="#f6d984")
    for number, page in enumerate(pages, 1):
        page.save(OUT / ("south-page-%02d.png" % number))
        ground_pages[number - 1].save(OUT / ("ground-page-%02d.png" % number))
    (OUT / "snapshot.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for item in report["characters"]:
        measurements = item["measurements"]
        idle = measurements[0]["directions"]["S"]
        fall = measurements[3]["directions"]["S"]
        print(item["id"], "front heights", [row["directions"]["S"]["height"] for row in measurements], "fall/idle ink", round(fall["ink_pixels"] / idle["ink_pixels"], 3))
    print("PASS: 30 current ground/action pairs match their runtime manifest RGBA hashes; 30 native boards and 6 front pages written only to", OUT)


if __name__ == "__main__":
    main()
