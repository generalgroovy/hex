"""Build the three-template foundation atlas with Red Baron's body grammar.

The source board contains one transparent pose for each of FLUX's fixed eight
directions. This deterministic builder normalizes those poses to the shared
96px cell and feet pivot, then derives bounded action contacts without ever
resizing the character between states. Pose, contact and lean may change;
canonical body mass, scale and feet pivot may not. The final bounded proportion
pass is deliberately evaluated in reusable-template order: small S. Wayne,
middle Oh Tipi, then large Red Baron. It reduces the first two champions'
oversized head treatment while keeping their authored total height and the
shared feet pivot. Spell, aura, shadow, equipment, and world pixels remain
excluded.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter


CELL = 96
PIVOT = (48, 84)
DIRECTION_COUNT = 8
STATE_ORDER = (
    "grounded", "jump", "cast", "hit", "walk", "sprint", "slide", "roll",
    "walk_b", "sprint_b",
)
TARGET_HEIGHT = 68
MAX_WIDTH = 90
STYLE_REFERENCE_CHAMPION = "red_baron"
OUTLINE_RADIUS = 1
TEMPLATE_BUILD_ORDER = ("small", "middle", "large")
TEMPLATE_ROWS = {
    "small": 1,   # S. Wayne
    "middle": 0,  # Oh Tipi
    "large": 2,   # The Red Baron
}
TEMPLATE_EXEMPLARS = {
    "small": "s_wayne",
    "middle": "oh_tipi",
    "large": "red_baron",
}
UPRIGHT_STATES = {
    "grounded", "jump", "cast", "hit", "walk", "sprint", "walk_b", "sprint_b",
}
PROPORTION_PROFILES = {
    # Fractions include hair/ancestry crowns; the manifest's ordinary-head
    # ratio excludes those silhouette features. Each remap preserves the full
    # cell's visible height and its bottom alignment.
    "small": {"source_head_fraction": 0.50, "target_head_fraction": 0.37, "head_width_scale": 0.82},
    "middle": {"source_head_fraction": 0.55, "target_head_fraction": 0.41, "head_width_scale": 0.84},
    "large": {"source_head_fraction": 0.42, "target_head_fraction": 0.42, "head_width_scale": 1.00},
}
TEMPLATE_STATE_HEIGHTS = {
    "small": {"upright": 58, "slide": 42, "roll": 41},
    "middle": {"upright": 68, "slide": 52, "roll": 44},
    "large": {"upright": 76, "slide": 76, "roll": 76},
}


def proportional_bounds(index: int, count: int, extent: int) -> tuple[int, int]:
    return round(index * extent / count), round((index + 1) * extent / count)


def source_poses(source: Image.Image) -> list[Image.Image]:
    poses: list[Image.Image] = []
    for index in range(DIRECTION_COUNT):
        left, right = proportional_bounds(index, DIRECTION_COUNT, source.width)
        pose = source.crop((left, 0, right, source.height))
        # Generated PNGs retain RGB values under transparent pixels. Cropping
        # all channels would make invisible canvas padding shrink the runtime
        # body and violate the large-template contract.
        visible_alpha = pose.getchannel("A").point(
            lambda value: 255 if value >= 48 else 0
        )
        bounds = visible_alpha.getbbox()
        if bounds is None:
            raise ValueError(f"Red Baron source direction {index} is empty")
        poses.append(pose.crop(bounds))
    scale = min(
        TARGET_HEIGHT / poses[0].height,
        TARGET_HEIGHT / max(pose.height for pose in poses),
        MAX_WIDTH / max(pose.width for pose in poses),
    )
    return [
        pose.resize(
            (max(1, round(pose.width * scale)), max(1, round(pose.height * scale))),
            Image.Resampling.LANCZOS,
        )
        for pose in poses
    ]


def paste_at_pivot(canvas: Image.Image, pose: Image.Image, pivot_y: int = PIVOT[1]) -> None:
    x = PIVOT[0] - pose.width // 2
    y = pivot_y - pose.height
    canvas.alpha_composite(pose, (x, y))


def sheared_pose(pose: Image.Image, amount: int) -> Image.Image:
    padding = abs(amount) + 2
    output = Image.new("RGBA", (pose.width + padding * 2, pose.height))
    for y in range(pose.height):
        progress = 1.0 - float(y) / max(1.0, float(pose.height - 1))
        offset = round(amount * progress)
        strip = pose.crop((0, y, pose.width, y + 1))
        output.alpha_composite(strip, (padding + offset, y))
    return output


def alternate_boot_contact(cell: Image.Image, phase: int, intensity: int) -> Image.Image:
    result = cell.copy()
    top = 72
    left = cell.crop((20, top, PIVOT[0], CELL))
    right = cell.crop((PIVOT[0], top, 76, CELL))
    result.paste((0, 0, 0, 0), (20, top, 76, CELL))
    left_y = top - intensity if phase == 0 else top + 1
    right_y = top + 1 if phase == 0 else top - intensity
    result.alpha_composite(left, (19 if phase == 0 else 21, left_y))
    result.alpha_composite(right, (PIVOT[0] + 1 if phase == 0 else PIVOT[0] - 1, right_y))
    return result


def action_cell(pose: Image.Image, state: str, direction_index: int) -> Image.Image:
    cell = Image.new("RGBA", (CELL, CELL))
    horizontal_sign = 1 if direction_index in (1, 2, 3) else -1 if direction_index in (5, 6, 7) else 0
    if state == "jump":
        paste_at_pivot(cell, pose, PIVOT[1] - 3)
    elif state == "cast":
        paste_at_pivot(cell, sheared_pose(pose, horizontal_sign * 2 if horizontal_sign else 1))
    elif state == "hit":
        paste_at_pivot(cell, sheared_pose(pose, -horizontal_sign * 4 if horizontal_sign else 3))
    elif state == "slide":
        paste_at_pivot(cell, sheared_pose(pose, horizontal_sign * 5 if horizontal_sign else 4), PIVOT[1] + 1)
    elif state == "roll":
        paste_at_pivot(cell, sheared_pose(pose, -horizontal_sign * 6 if horizontal_sign else -5), PIVOT[1])
    elif state in ("sprint", "sprint_b"):
        contact_phase = 0 if state == "sprint" else 1
        paste_at_pivot(cell, sheared_pose(pose, horizontal_sign * 3))
        cell = alternate_boot_contact(cell, contact_phase, 3)
    elif state in ("walk", "walk_b"):
        contact_phase = 0 if state == "walk" else 1
        paste_at_pivot(cell, pose)
        cell = alternate_boot_contact(cell, contact_phase, 2)
    else:
        paste_at_pivot(cell, pose)
    return cell


def remap_mature_proportions(cell: Image.Image, template: str) -> Image.Image:
    """Reduce head dominance without changing total pose height or feet."""
    profile = PROPORTION_PROFILES[template]
    if template == "large":
        return cell.copy()
    alpha = cell.getchannel("A").point(lambda value: 255 if value >= 48 else 0)
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError(f"{template} template contains an empty animation cell")
    left, top, right, bottom = bounds
    width = right - left
    height = bottom - top
    if width < 4 or height < 12:
        raise ValueError(f"{template} template cell is too small to proportion safely: {bounds}")

    source_head_height = max(3, round(height * profile["source_head_fraction"]))
    source_head_height = min(source_head_height, height - 4)
    target_head_height = max(3, round(height * profile["target_head_fraction"]))
    target_head_height = min(target_head_height, height - 4)
    split = top + source_head_height
    head = cell.crop((left, top, right, split))
    body = cell.crop((left, split, right, bottom))

    target_head_width = max(3, round(width * profile["head_width_scale"]))
    head = head.resize((target_head_width, target_head_height), Image.Resampling.NEAREST)
    # The lower band expands only into space released by the head. Overall pose
    # height, cell, centre line and ground alignment remain stable.
    target_body_height = height - target_head_height + 1
    body = body.resize((width, target_body_height), Image.Resampling.NEAREST)

    output = Image.new("RGBA", cell.size)
    body_y = bottom - target_body_height
    output.alpha_composite(body, (PIVOT[0] - width // 2, body_y))
    output.alpha_composite(head, (PIVOT[0] - target_head_width // 2, top))
    return output


def normalize_state_height(cell: Image.Image, target_height: int, template: str, state: str) -> Image.Image:
    """Remove legacy source-sheet scale drift while preserving state elevation."""
    alpha = cell.getchannel("A").point(lambda value: 255 if value >= 48 else 0)
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError(f"{template}/{state} template contains an empty animation cell")
    left, top, right, bottom = bounds
    width = right - left
    height = bottom - top
    target_width = max(3, round(width * target_height / height))
    if target_width > CELL - 2:
        raise ValueError(f"{template}/{state} cannot fit canonical height {target_height}: {bounds}")
    pose = cell.crop(bounds).resize((target_width, target_height), Image.Resampling.NEAREST)
    output = Image.new("RGBA", cell.size)
    output.alpha_composite(pose, (PIVOT[0] - target_width // 2, bottom - target_height))
    return output


def normalize_body_templates(atlas: Image.Image) -> Image.Image:
    """Apply and validate the canonical small-to-large production order."""
    output = atlas.copy()
    for template in TEMPLATE_BUILD_ORDER:
        champion_row = TEMPLATE_ROWS[template]
        for state_index, state in enumerate(STATE_ORDER):
            for direction_index in range(DIRECTION_COUNT):
                bounds = (
                    direction_index * CELL,
                    (champion_row * len(STATE_ORDER) + state_index) * CELL,
                    (direction_index + 1) * CELL,
                    (champion_row * len(STATE_ORDER) + state_index + 1) * CELL,
                )
                cell = atlas.crop(bounds)
                if cell.getchannel("A").getbbox() is None:
                    raise ValueError(
                        f"{template}/{TEMPLATE_EXEMPLARS[template]}/{state}/{direction_index} is empty"
                    )
                height_kind = state if state in ("slide", "roll") else "upright"
                cell = normalize_state_height(
                    cell,
                    TEMPLATE_STATE_HEIGHTS[template][height_kind],
                    template,
                    state,
                )
                if state in UPRIGHT_STATES:
                    cell = remap_mature_proportions(cell, template)
                output.paste((0, 0, 0, 0), bounds)
                output.alpha_composite(cell, (bounds[0], bounds[1]))
        print(f"proportioned {template}:{TEMPLATE_EXEMPLARS[template]}")
    return output


def red_baron_outline_colour(atlas: Image.Image, red_baron_y: int) -> tuple[int, int, int, int]:
    """Derive one shared ink colour from Red Baron's darkest visible clusters."""
    reference = atlas.crop((0, red_baron_y, atlas.width, atlas.height)).convert("RGBA")
    visible = [
        pixel for pixel in reference.getdata()
        if pixel[3] >= 48
    ]
    if not visible:
        raise ValueError("Red Baron reference contains no visible style pixels")
    visible.sort(key=lambda pixel: pixel[0] * 299 + pixel[1] * 587 + pixel[2] * 114)
    sample = visible[:max(1, len(visible) // 10)]
    sample.sort(key=lambda pixel: (pixel[0], pixel[1], pixel[2]))
    median = sample[len(sample) // 2]
    return median[0], median[1], median[2], 255


def apply_shared_outline(cell: Image.Image, ink: tuple[int, int, int, int]) -> Image.Image:
    """Add one bounded exterior pixel of Red-Baron-derived ink per atlas cell."""
    alpha = cell.getchannel("A").point(lambda value: 255 if value >= 48 else 0)
    expanded = alpha.filter(ImageFilter.MaxFilter(OUTLINE_RADIUS * 2 + 1))
    outline_alpha = ImageChops.subtract(expanded, alpha)
    outline = Image.new("RGBA", cell.size, ink)
    outline.putalpha(outline_alpha)
    output = Image.new("RGBA", cell.size)
    output.alpha_composite(outline)
    output.alpha_composite(cell)
    return output


def harmonize_champion_style(atlas: Image.Image, red_baron_y: int) -> Image.Image:
    """Apply one outline grammar without rescaling or merging body identities."""
    ink = red_baron_outline_colour(atlas, red_baron_y)
    output = Image.new("RGBA", atlas.size)
    for row in range(3 * len(STATE_ORDER)):
        for column in range(DIRECTION_COUNT):
            bounds = (
                column * CELL,
                row * CELL,
                (column + 1) * CELL,
                (row + 1) * CELL,
            )
            output.alpha_composite(
                apply_shared_outline(atlas.crop(bounds), ink),
                (bounds[0], bounds[1]),
            )
    return output


def build(base_path: Path, source_path: Path, output_path: Path) -> None:
    base = Image.open(base_path).convert("RGBA")
    if base.size != (DIRECTION_COUNT * CELL, 2 * len(STATE_ORDER) * CELL):
        raise ValueError(f"expected 768x1920 foundation atlas, got {base.size}")
    source = Image.open(source_path).convert("RGBA")
    poses = source_poses(source)
    atlas = Image.new("RGBA", (DIRECTION_COUNT * CELL, 3 * len(STATE_ORDER) * CELL))
    atlas.alpha_composite(base, (0, 0))
    red_baron_y = base.height
    for state_index, state in enumerate(STATE_ORDER):
        for direction_index, pose in enumerate(poses):
            cell = action_cell(pose, state, direction_index)
            atlas.alpha_composite(cell, (direction_index * CELL, red_baron_y + state_index * CELL))

    atlas = normalize_body_templates(atlas)
    atlas = harmonize_champion_style(atlas, red_baron_y)

    alpha = atlas.getchannel("A").point(lambda value: 255 if value >= 48 else 0)
    atlas = atlas.convert("RGB").quantize(
        colors=64,
        method=Image.Quantize.FASTOCTREE,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    atlas.putalpha(alpha)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output_path, optimize=True)
    print(
        f"built {output_path} {atlas.width}x{atlas.height}; "
        f"champions=oh_tipi,s_wayne,red_baron; states={','.join(STATE_ORDER)}; "
        f"template_order={','.join(TEMPLATE_BUILD_ORDER)}; "
        f"style_reference={STYLE_REFERENCE_CHAMPION}; outline={OUTLINE_RADIUS}px"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("base", type=Path)
    parser.add_argument("red_baron_source", type=Path)
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()
    build(arguments.base, arguments.red_baron_source, arguments.output)


if __name__ == "__main__":
    main()
