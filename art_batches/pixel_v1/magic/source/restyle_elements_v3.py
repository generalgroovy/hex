"""Bounded original pixel-source restyle, never an authority/timing generator.

Edits only pixels in 8 elements x 7 roles x 2 variants. Existing frame metadata,
palettes, IDs, cells, pivots and durations remain byte-value identical. Originals
are archived before first application. No vector shapes, imagegen pixel edits,
simulation inputs, atlas exports or authority refreshes are performed here.
"""
from pathlib import Path
import hashlib
import json
import zipfile
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT.parents[1] / "magic_style_v3"
ELEMENTS = ["fire", "water", "earth", "wind", "charge", "ice", "light", "dark"]
ROLES = ["flight", "flight_tail", "impact", "deposit_formation", "deposit_active", "deposit_decay", "field_tile"]

# Every row is an authored integer-pixel silhouette, not a rasterized primitive.
# d/b/h use the unchanged element shadow, midtone and warm/light accent ramps.
CORES = {
    "fire": """........b...
.......bh...
...b..bhb...
..bh..bh....
..bhbbhb....
.bbhhbhbb...
.bhhhhhhb...
bbhhbhhhbb..
bhhbbbhhhb..
bhhbddbhhbb.
.bhhbbhhhbd.
..bbbbbbdd..
...ddddd....""",
    "water": """.....hhhh...
...hhbbbbh..
..hbbddbbh..
.hbbd..dbh..
.hbbd...bh..
hbbbd...d...
hbbbbd......
hbbbbbd.hh..
.hbbbbbbbh..
.hhbbbbbhd..
..hhhhhdd...
...dddd.....""",
    "earth": """....hhhh....
..hhbbbbh...
.hbbbbbbbd..
hbbbddbbbd..
hbbdddbbbbd.
hbbddbhbbbd.
.dbbhbbddbd.
.dbbbbbddbd.
..dbbddbbd..
...dddddd...""",
    "wind": """.....hhhh...
...hhbbbbh..
..hbbddd.bh.
.hbd.....bh.
.hb..hhh.hb.
..b..hbb.h..
.....hbd....
hh...hbd....
hbhhhbd.....
.dbbbd......
..ddd.......""",
    "charge": """........hh..
.......hbh..
......hbh...
..h..hbh....
.hb.hhbh....
.hbhbbbhh...
..hbbhbbbh..
...dhbhhh...
....hbh.....
...hbh..h...
..hbh...h...
..hh........""",
    "ice": """.....h......
....hbh.....
....hbh..h..
.h..hbh.hbh.
hbh.hbh.hbh.
hbhhbhbhbhh.
.hbbhbhbbh..
.hbbhbhbdh..
..hbbbhbd...
..hbbhbd....
...dddd.....""",
    "light": """.....h......
....hbh.....
.h..hbh..h..
..hhbbbhh...
..hbhhhbh...
hhbbhhhbbhh.
..hbhhhbh...
..hhbbbhh...
.h..hbh..h..
....hbh.....
.....h......""",
    "dark": """.......b....
......bh....
...bb.bhb...
..bhbbhbb...
.bhbdddhbb..
bhbdddddbb..
bhbdddddbh..
.bhbdddbhb..
.bbhbbhbb...
..bbbbbd....
...dddd.....""",
}
GRAINS = {
    "fire": "..b../.bh../bhhb./bhhbb/.bbd.",
    "water": "..hh../.hbbh./hbbbd./.hhd..",
    "earth": ".hhh../hbbbd./hbd bd/.dddd.",
    "wind": ".hhhh/hbdd./hb.../.bb..",
    "charge": "...hh/..hb./.hbhh/..hbh/.hh..",
    "ice": "..h../.hbh./.hbhh/hbbhd/.ddd.",
    "light": "..h../.hbh./hb hbh/.hbh./..h..",
    "dark": "...b../..bhb./.bddbh/bbdbh./.bbd..",
}
GROUNDS = {
    "fire": """....b......b....
...bh.....bh....
..bhb..b.bhb....
..bhb.bhbbhbb...
.bbhhbbhhhhhb...
bhhhhbhhbhhhbb..
bhhbddbhbbhhhbd.
.bbbbbdbbbbbdd..
..dddddddddd....""",
    "water": """....hhhhh.......
..hhbbbbbh.hh...
.hbbbbbbbhhbbh..
hbbddbbbbbbbbbhd
hbbbbbhhhbbbbbhd
.hhbbbbbbbbbhhd.
...hhhhhhhhdd...
.....dddddd.....""",
    "earth": """...hhh...hhh....
..hbbbd.hbbbd...
.hbbdbbdhbbbd...
.hbbddbd.ddd.hh.
..dddddhhhh.hbbd
.hhh..hbbbbdhbbd
hbbbd.hbbdbd.dd.
.ddd...dddd.....""",
    "wind": """......hhhhh.....
....hhbbddbh....
...hbd....bh....
....bb....h.....
.hhh....hhh.....
hbbbhhhhbb......
.ddbbbbdd.......
...dddd.........""",
    "charge": """...hh.......h...
..hbh......hbh..
...hbhhh..hbh...
...hbbbhhhbh....
.hhbhhbbbhh.....
hbbh...hbh......
.hh.....hh......
................""",
    "ice": """....h......h....
...hbh....hbh...
...hbh.h..hbh...
.h.hbhhbh.hbh.h.
hbhhbbhbhhbbhhbh
hbbhbbhbbhbbhbbh
.hbbddhbbddbbhd.
..dddddddddddd..""",
    "light": """....h......h....
...hbh....hbh...
..hbbbh..hb bh..
hhbhhhbhhhhhhbhh
..hbbbh..hbbbh..
...hbh....hbh...
....h......h....
................""",
    "dark": """.....bb...bb....
...bbhb..bhb....
..bhddbbbbhbb...
.bhddddddddbhb..
bhddddddddddbhb.
.bhbdddddbbbhb..
..bbhbbbhbbbdd..
....dddddddd....""",
}


def parse(pattern):
    return [list(row.replace(" ", ".")) for row in pattern.replace("/", "\n").splitlines()]


def stamp(dst, pattern, cx, cy, flip=False):
    rows = parse(pattern) if isinstance(pattern, str) else pattern
    width = max(map(len, rows))
    for y, row in enumerate(rows):
        for x, color in enumerate(row):
            px = cx - width // 2 + (width - x - 1 if flip else x)
            py = cy - len(rows) // 2 + y
            if color != "." and 1 <= px < 31 and 1 <= py < 31:
                dst[py][px] = color


def outlined(grid):
    # Four-neighbour, element-coloured ink. Keep holes and open curl silhouettes.
    result = [row[:] for row in grid]
    for y in range(1, 31):
        for x in range(1, 31):
            if grid[y][x] != ".":
                for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
                    if grid[y + dy][x + dx] == ".":
                        result[y + dy][x + dx] = "d"
    return result


def motif(element, phase):
    pattern = parse(CORES[element])
    if element in ["fire", "water", "wind", "dark"]:
        # One-pixel tip curl only; the contact/body anchor never jitters.
        shift = [0, 1, 0, -1][phase % 4]
        width = max(map(len, pattern))
        for y in range(min(4, len(pattern))):
            row = pattern[y] + ["."] * (width - len(pattern[y]))
            pattern[y] = [row[x - shift] if 0 <= x - shift < width else "." for x in range(width)]
    elif phase % 2:
        # Hard materials change a facet glint, not their mass or their pivot.
        for y, row in enumerate(pattern):
            for x, color in enumerate(row):
                if color == "b" and (x + y) % 7 == phase % 4:
                    row[x] = "h"
    return pattern


def drawing(element, role, phase, reduced):
    grid = [["."] * 32 for _ in range(32)]
    grain = GRAINS[element]
    core = motif(element, phase)
    if role == "flight":
        stamp(grid, core, 16, 16)
    elif role == "flight_tail":
        stamp(grid, grain, 22, 16)
        if not reduced:
            stamp(grid, grain, 12 + [0, 1, 0, -1][phase % 4], 16, True)
            grid[16][5 + phase % 2] = "b"
    elif role == "impact":
        # A full, irregular contact bloom. Retain mass through snap/expansion,
        # then resolve into separated chips. Never a circular painted decal.
        if phase < 4:
            stamp(grid, GROUNDS[element], 16, 17 + min(phase, 2))
        if phase < 3:
            stamp(grid, core, 16, 14 + phase)
        spread = [6, 8, 10, 11, 12, 12][phase]
        points = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        if not reduced:
            points += [(-1, 0), (1, 0)]
        for index, (dx, dy) in enumerate(points):
            if phase == 5 and index % 2:
                continue
            stamp(grid, grain, 16 + dx * spread, 16 + dy * (spread - 2), index % 2 == 1)
    elif role.startswith("deposit_"):
        stage = role.removeprefix("deposit_")
        stamp(grid, GROUNDS[element], 16, 23)
        if stage == "active" or (stage == "formation" and phase >= 2) or (stage == "decay" and phase == 0):
            if element in ["fire", "wind", "dark"]:
                stamp(grid, grain, 16 + [0, 2, 0, -2][phase % 4], 15 - phase % 2)
            if not reduced:
                stamp(grid, grain, 5, 25, True)
                stamp(grid, grain, 26, 22)
        if stage == "formation":
            cutoff = [24, 21, 18, 0][phase]
            grid = [[c if y >= cutoff else "." for c in row] for y, row in enumerate(grid)]
        elif stage == "decay":
            if phase >= 1:
                for y in range(32):
                    for x in range(32):
                        if y < 19 + phase or ((x // 3 + y // 2) % 4 < phase):
                            grid[y][x] = "."
    else:  # Ground tile: several real matter lobes, no fill disk or warning ring.
        stamp(grid, GROUNDS[element], 13, 11)
        if not reduced:
            stamp(grid, grain, 24 + phase % 2, 24)
            stamp(grid, grain, 7, 26, True)
    # Highlights advance independently inside ground cells without reanchoring.
    if role.startswith("deposit_") or role == "field_tile":
        for y, row in enumerate(grid):
            for x, color in enumerate(row):
                if color == "b" and (x + y + phase * 3) % 17 == 0:
                    row[x] = "h"
    grid = outlined(grid)
    if not any(c != "." for row in grid for c in row):
        stamp(grid, grain, 16, 24)
    return ["".join(row) for row in grid]


def image(source, frame_index):
    frame = source["frames"][frame_index % len(source["frames"])]["pixels"]
    result = Image.new("RGBA", (len(frame[0]), len(frame)))
    result.putdata([tuple(bytes.fromhex(source["palette"][c])) for row in frame for c in row])
    return result


def preview(before, after, variant):
    roles = ["flight", "impact", "deposit_active", "field_tile"]
    board = Image.new("RGBA", (1000, 796), "#202b2b")
    draw = ImageDraw.Draw(board)
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 15)
    draw.text((16, 12), f"ELEMENT ART V3 / {variant.upper()} / OLD > NEW / 3x integer pixels", font=font, fill="#fff1c7")
    for col, role in enumerate(roles):
        draw.text((145 + col * 210, 45), role, font=font, fill="#fff1c7")
    for row, element in enumerate(ELEMENTS):
        y = 84 + row * 88
        draw.text((12, y + 28), element.upper(), font=font, fill="#fff1c7")
        for col, role in enumerate(roles):
            sid = f"magic.{element}.{role}.{variant}"
            for version, sources in enumerate([before, after]):
                tile = image(sources[sid], 1).resize((96, 96), Image.Resampling.NEAREST)
                board.alpha_composite(tile, (110 + col * 210 + version * 98, y - 12))
    board.save(OUT / f"before-after-{variant}-3x.png")


def motion_preview(after, variant):
    frames = []
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 13)
    for sample in range(32):
        board = Image.new("RGBA", (650, 620), "#202b2b")
        draw = ImageDraw.Draw(board)
        draw.text((12, 10), f"V3 / {variant} / authored preview, not gameplay", font=font, fill="#fff1c7")
        draw.text((120, 36), "FLIGHT         FINITE CONTACT       FINITE MATTER", font=font, fill="#fff1c7")
        for row, element in enumerate(ELEMENTS):
            y = 62 + row * 67
            draw.text((12, y + 20), element.upper(), font=font, fill="#fff1c7")
            roles = [("flight", sample % 4), ("impact", min(5, sample // 3)),
                     ("deposit_formation", sample) if sample < 4 else ("deposit_active", sample % 4) if sample < 24 else ("deposit_decay", min(3, (sample - 24) // 2))]
            for column, (role, phase) in enumerate(roles):
                if (column == 1 and sample >= 18) or (column == 2 and sample >= 31):
                    continue
                sid = f"magic.{element}.{role}.{variant}"
                tile = image(after[sid], phase).resize((64, 64), Image.Resampling.NEAREST)
                board.alpha_composite(tile, (120 + column * 170, y))
        frames.append(board.convert("RGB"))
    # Deliberately labelled authoring sequence; not a simulation clock/capture.
    frames[0].save(OUT / f"authored-motion-{variant}-2x.gif", save_all=True, append_images=frames[1:], duration=80, loop=0, disposal=2)


def phase_preview(after):
    board = Image.new("RGBA", (1160, 676), "#202b2b")
    draw = ImageDraw.Draw(board)
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 13)
    draw.text((12, 12), "V3 / NORMAL / all contact + material transition poses / 2x integer pixels", font=font, fill="#fff1c7")
    draw.text((115, 43), "CONTACT 0..5                              FORMATION 0..3             DECAY 0..3", font=font, fill="#fff1c7")
    for row, element in enumerate(ELEMENTS):
        y = 72 + row * 74
        draw.text((10, y + 23), element.upper(), font=font, fill="#fff1c7")
        column = 0
        for role, count in [("impact", 6), ("deposit_formation", 4), ("deposit_decay", 4)]:
            for phase in range(count):
                tile = image(after[f"magic.{element}.{role}.normal"], phase).resize((64, 64), Image.Resampling.NEAREST)
                board.alpha_composite(tile, (105 + column * 74, y))
                column += 1
    board.save(OUT / "all-transition-poses-normal-2x.png")


def main():
    OUT.mkdir(exist_ok=True)
    paths = [ROOT / "source/frames" / f"magic.{e}.{r}.{v}.json" for e in ELEMENTS for r in ROLES for v in ["normal", "reduced"]]
    archive = OUT / "original-element-frames.zip"
    if not archive.exists():
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
            for path in paths:
                z.writestr(path.name, path.read_bytes())
    with zipfile.ZipFile(archive) as z:
        before = {Path(name).stem: json.loads(z.read(name)) for name in z.namelist()}
    after = {}
    proofs = []
    for path in paths:
        source = json.loads(path.read_text(encoding="utf-8"))
        original = before[source["id"]]
        role = source["id"].split(".")[2]
        for index, frame in enumerate(source["frames"]):
            frame["pixels"] = drawing(source["element_id"], role, index, source["variant"] == "reduced")
        def metadata(src):
            return {**src, "frames": [{k: v for k, v in f.items() if k != "pixels"} for f in src["frames"]]}
        assert metadata(source) == metadata(original), source["id"] + ": metadata changed"
        for frame in source["frames"]:
            assert len(frame["pixels"]) == 32 and all(len(row) == 32 for row in frame["pixels"])
            assert all(c in source["palette"] for row in frame["pixels"] for c in row)
        path.write_text(json.dumps(source, indent=2) + "\n", encoding="utf-8", newline="\n")
        after[source["id"]] = source
        proofs.append({"id": source["id"], "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "metadata_identical": True, "frames": len(source["frames"])})
    for variant in ["normal", "reduced"]:
        preview(before, after, variant)
        motion_preview(after, variant)
    phase_preview(after)
    contact_checks = []
    for variant in ["normal", "reduced"]:
        silhouettes = set()
        for element in ELEMENTS:
            flight = image(after[f"magic.{element}.flight.{variant}"], 0)
            impact = image(after[f"magic.{element}.impact.{variant}"], 0)
            count = lambda im: sum(1 for p in im.getdata() if p[3])
            assert count(impact) > count(flight), element + ": contact must be fuller than flight"
            silhouettes.add(impact.getchannel("A").tobytes())
            contact_checks.append({"element": element, "variant": variant, "flight_opaque_pixels": count(flight), "opening_contact_opaque_pixels": count(impact), "contact_bbox": impact.getbbox()})
        assert len(silhouettes) == 8, "contact identities must differ in shape, not just color"
    (OUT / "source-proof.json").write_text(json.dumps({"status": "source-authored-metadata-preserved-see-integration-receipt", "sequences": len(proofs), "frames": sum(p["frames"] for p in proofs), "original_archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(), "contact_checks": contact_checks, "assets": proofs}, indent=2) + "\n", encoding="utf-8")
    print(f"AUTHORED {len(proofs)} sequences / {sum(p['frames'] for p in proofs)} frames; IDs/palettes/timing/pivots unchanged; no atlas or authority writes")


if __name__ == "__main__":
    main()
