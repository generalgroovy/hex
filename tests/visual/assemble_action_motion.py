"""Assemble paid-trajectory captures without changing their native pixel dimensions.
APNG follows the captured timebase; GIF centisecond rounding is explicit. A contact
sheet selects actual frames by phase and is an index, never animation proof.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("source", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
receipt_path = args.source / "receipt.json"
receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
fps = int(receipt["fps"])
if fps not in (30, 60) or int(receipt["authority_hz"]) != 120:
    raise SystemExit("Unsupported capture timebase")
args.output.mkdir(parents=True, exist_ok=True)
summary = {"source_receipt_sha256": hashlib.sha256(receipt_path.read_bytes()).hexdigest(),
           "fps": fps, "reduced": receipt["reduced"], "clips": [],
           "limits": "Native frames, capture timebase; not physical input or performance proof. GIF timing rounds to centiseconds; APNG uses frame milliseconds."}
for scenario in receipt["scenarios"]:
    name = scenario["name"]
    actors = scenario["actors"]
    records = actors[0]["frames"]
    if len(records) != int(scenario["samples"]) or any(actor.get("coverage") for actor in actors):
        raise ValueError("Incomplete scenario coverage")
    for suffix in (".png", ".gif", "-filmstrip.png"):
        if (args.output / (name + suffix)).exists():
            raise SystemExit("Preserving existing output: " + name + suffix)
    frames = []
    for index, record in enumerate(records):
        if int(record["tick"]) != (index + 1) * (120 // fps):
            raise ValueError("Capture frame omitted or retimed")
        image_path = args.source / record["image"]
        if image_path.parent.resolve() != args.source.resolve():
            raise ValueError("Image leaves capture directory")
        with Image.open(image_path) as frame:
            if frame.size != (960, 300):
                raise ValueError("Unexpected native viewport dimensions")
            frames.append(frame.convert("RGBA"))
    ms = [round((i + 1) * 1000 / fps) - round(i * 1000 / fps) for i in range(len(frames))]
    destination = args.output / (name + ".png")
    frames[0].save(destination, save_all=True, append_images=frames[1:], duration=ms, loop=0, disposal=0, blend=0)
    # Pillow GIF accepts milliseconds but stores centiseconds; distribute the
    # rounding rather than silently playing 60FPS footage at 100FPS.
    gif_ms = [(round((i + 1) * 100 / fps) - round(i * 100 / fps)) * 10 for i in range(len(frames))]
    palette = frames[0].convert("RGB").quantize(colors=256)
    gifs = [frame.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    gifs[0].save(args.output / (name + ".gif"), save_all=True, append_images=gifs[1:], duration=gif_ms, loop=0, disposal=2, optimize=False)
    # First appearances of actual paid poses/boundaries, plus beginning/end.
    chosen = {0, len(frames) - 1}
    seen = set()
    for i in range(len(records)):
        signature = tuple((row["frames"][i]["pose"], row["frames"][i]["hands"], row["frames"][i]["protection"]) for row in actors)
        if signature not in seen:
            chosen.add(i)
            seen.add(signature)
    picks = sorted(chosen)
    sheet = Image.new("RGB", (960, 324 * len(picks)), "#101c23")
    draw = ImageDraw.Draw(sheet)
    for row, index in enumerate(picks):
        sheet.paste(frames[index].convert("RGB"), (0, row * 324))
        draw.text((12, row * 324 + 304), f"tick {records[index]['tick']} / frame {index} / {index / fps:.3f}s", fill="#eadfc3")
    sheet.save(args.output / (name + "-filmstrip.png"))
    summary["clips"].append({"scenario": name, "frames": len(frames), "duration_ms": sum(ms), "filmstrip_frames": picks,
                             "apng_sha256": hashlib.sha256(destination.read_bytes()).hexdigest()})
(args.output / "assembly.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
print(json.dumps({"assembled": len(summary["clips"]), "fps": fps, "output": str(args.output.resolve())}))
