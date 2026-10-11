"""Lossless-source native-frame assembly; slowed inspection GIF, not timing proof."""
import argparse
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("source", type=Path)
parser.add_argument("output", type=Path)
parser.add_argument("--samples", type=int, choices=(24, 48), default=24)
parser.add_argument("--actions", nargs="+", choices=("walk", "sprint", "wallrun", "moving_cast"), default=("walk", "sprint", "wallrun"))
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
for action in args.actions:
    destination = args.output / f"{action}-inspection.gif"
    if destination.exists():
        raise SystemExit(f"Preserving existing output: {destination}")
    frames = []
    for index in range(args.samples):
        with Image.open(args.source / f"{action}-{index:02}.png") as image:
            if image.size != (1024, 420):
                raise ValueError("Unexpected native viewport dimensions")
            frames.append(image.convert("RGB"))
    # One shared palette avoids per-frame palette shimmer; no resizing/filtering.
    palette = frames[0].quantize(colors=256)
    frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    frames[0].save(destination, save_all=True, append_images=frames[1:],
                   duration=960 // args.samples, loop=0, disposal=2, optimize=False)
    print(destination)
