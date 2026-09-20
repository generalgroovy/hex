"""Build the reviewed FLUX body-only champion atlas.

Core and movement sources are four-column by four-row cardinal matte sheets.
Optional diagonal-core sources are four-column by three-row matte sheets for
grounded, empty-hand cast, and hit/recovery; optional diagonal-locomotion
sources are four-column by two-row sheets for walk and sprint. An optional
paired locomotion phase-B source is four columns by two rows for the opposite
walk/sprint contacts, while its diagonal action source is four columns by five
rows for opposite walk, opposite sprint, jump, slide, and roll. Generated
canvases need not divide evenly, so cell edges are derived proportionally
instead of dropping border pixels. Source cells are normalized to a shared
four-column width before one scale is calculated per champion from its south
idle pose and bounded against every included pose; action changes never resize
the body.

Spell, aura, shadow, environment, equipment, and gameplay state are excluded.
"""

from __future__ import annotations

import argparse
from math import isclose
from pathlib import Path

from PIL import Image

from build_foundation_champion_sprites import remove_edge_matte


SOURCE_COLUMNS = 4
CANONICAL_SOURCE_WIDTH = 1254
CARDINAL_SOURCE_ROWS = 4
DIAGONAL_SOURCE_ROWS = 3
DIAGONAL_LOCOMOTION_SOURCE_ROWS = 2
DIAGONAL_ACTION_SOURCE_ROWS = 5
OUTPUT_CELL = 96
OUTPUT_PIVOT_Y = 84
CARDINAL_DIRECTIONS = ("south", "east", "north", "west")
DIAGONAL_DIRECTIONS = ("south_east", "north_east", "north_west", "south_west")
EIGHT_DIRECTIONS = (
    "south", "south_east", "east", "north_east",
    "north", "north_west", "west", "south_west",
)
BASE_STATES = ("grounded", "jump", "cast", "hit")
MOVEMENT_STATES = ("walk", "sprint", "slide", "roll")
DIAGONAL_CORE_STATES = ("grounded", "cast", "hit")
DIAGONAL_LOCOMOTION_STATES = ("walk", "sprint")
DIAGONAL_ACTION_STATES = ("walk_b", "sprint_b", "jump", "slide", "roll")
LOCOMOTION_PHASE_B_STATES = ("walk_b", "sprint_b")
CHAMPIONS = ("oh_tipi", "s_wayne")
TARGET_IDLE_HEIGHTS = (68, 58)
MAX_SPRITE_EXTENT = 92


def proportional_bounds(index: int, count: int, extent: int) -> tuple[int, int]:
    """Return adjacent rounded boundaries that retain the complete source."""
    return round(index * extent / count), round((index + 1) * extent / count)


def isolated_sprite(
    source: Image.Image,
    row: int,
    column: int,
    source_rows: int,
) -> Image.Image:
    left, right = proportional_bounds(column, SOURCE_COLUMNS, source.width)
    top, bottom = proportional_bounds(row, source_rows, source.height)
    transparent = remove_edge_matte(source.crop((left, top, right, bottom)))
    # Hidden RGB under zero alpha is still present in generated source PNGs.
    # Only visible alpha may define a reusable character template footprint.
    visible_alpha = transparent.getchannel("A").point(
        lambda value: 255 if value >= 48 else 0
    )
    bounds = visible_alpha.getbbox()
    if bounds is None:
        raise ValueError(f"source cell {row},{column} contains no isolated sprite")
    return transparent.crop(bounds)


def champion_scale(sprites: list[list[Image.Image]], target_idle_height: int) -> float:
    idle = sprites[0][0]
    scale = target_idle_height / idle.height
    widest = max(sprite.width for row in sprites for sprite in row)
    tallest = max(sprite.height for row in sprites for sprite in row)
    return min(scale, MAX_SPRITE_EXTENT / widest, MAX_SPRITE_EXTENT / tallest)


def fit_sprite(sprite: Image.Image, scale: float) -> Image.Image:
    size = (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale)))
    return sprite.resize(size, Image.Resampling.LANCZOS)


def load_sprite_rows(
    source_path: Path,
    source_rows: int = CARDINAL_SOURCE_ROWS,
) -> list[list[Image.Image]]:
    source = Image.open(source_path).convert("RGB")
    if source.width < 4 or source.height < 4:
        raise ValueError(f"source sheet is too small: {source_path} {source.size}")
    rows = [
        [isolated_sprite(source, row, column, source_rows) for column in range(SOURCE_COLUMNS)]
        for row in range(source_rows)
    ]
    # Generated sheets may use a different canvas size while preserving their
    # equal four-column grid. Normalize by source-cell width before the one
    # champion-wide atlas scale is selected; action changes then cannot inherit
    # accidental canvas-size changes.
    source_scale = float(CANONICAL_SOURCE_WIDTH) / float(source.width)
    if isclose(source_scale, 1.0, rel_tol=0.0, abs_tol=0.000001):
        return rows
    return [
        [
            sprite.resize(
                (
                    max(1, round(sprite.width * source_scale)),
                    max(1, round(sprite.height * source_scale)),
                ),
                Image.Resampling.LANCZOS,
            )
            for sprite in row
        ]
        for row in rows
    ]


def build(
    source_paths: tuple[Path, Path],
    output_path: Path,
    movement_source_paths: tuple[Path, Path] | None = None,
    diagonal_core_source_paths: tuple[Path, Path] | None = None,
    diagonal_locomotion_source_paths: tuple[Path, Path] | None = None,
    locomotion_phase_b_source_paths: tuple[Path, Path] | None = None,
    diagonal_action_source_paths: tuple[Path, Path] | None = None,
) -> None:
    if diagonal_locomotion_source_paths is not None and diagonal_core_source_paths is None:
        raise ValueError("diagonal locomotion requires diagonal core sources")
    if (locomotion_phase_b_source_paths is None) != (diagonal_action_source_paths is None):
        raise ValueError("phase-B cardinal and diagonal action sources are required together")
    if diagonal_action_source_paths is not None and diagonal_core_source_paths is None:
        raise ValueError("diagonal actions require diagonal core sources")
    if locomotion_phase_b_source_paths is not None and movement_source_paths is None:
        raise ValueError("phase-B locomotion requires cardinal movement sources")
    states = BASE_STATES + (MOVEMENT_STATES if movement_source_paths else ())
    if locomotion_phase_b_source_paths:
        states += LOCOMOTION_PHASE_B_STATES
    has_diagonals = diagonal_core_source_paths is not None or diagonal_locomotion_source_paths is not None
    directions = EIGHT_DIRECTIONS if has_diagonals else CARDINAL_DIRECTIONS
    atlas = Image.new(
        "RGBA",
        (len(directions) * OUTPUT_CELL, len(CHAMPIONS) * len(states) * OUTPUT_CELL),
    )
    for champion_index, source_path in enumerate(source_paths):
        sprites = load_sprite_rows(source_path)
        if movement_source_paths:
            sprites.extend(load_sprite_rows(movement_source_paths[champion_index]))
        if locomotion_phase_b_source_paths:
            sprites.extend(load_sprite_rows(
                locomotion_phase_b_source_paths[champion_index],
                DIAGONAL_LOCOMOTION_SOURCE_ROWS,
            ))
        diagonal_by_state: dict[str, list[Image.Image]] = {}
        if diagonal_core_source_paths:
            diagonal_rows = load_sprite_rows(
                diagonal_core_source_paths[champion_index],
                DIAGONAL_SOURCE_ROWS,
            )
            diagonal_by_state = dict(zip(DIAGONAL_CORE_STATES, diagonal_rows))
        if diagonal_locomotion_source_paths:
            if not movement_source_paths:
                raise ValueError("diagonal locomotion requires cardinal movement sources")
            diagonal_rows = load_sprite_rows(
                diagonal_locomotion_source_paths[champion_index],
                DIAGONAL_LOCOMOTION_SOURCE_ROWS,
            )
            diagonal_by_state.update(dict(zip(DIAGONAL_LOCOMOTION_STATES, diagonal_rows)))
        if diagonal_action_source_paths:
            diagonal_rows = load_sprite_rows(
                diagonal_action_source_paths[champion_index],
                DIAGONAL_ACTION_SOURCE_ROWS,
            )
            diagonal_by_state.update(dict(zip(DIAGONAL_ACTION_STATES, diagonal_rows)))
        scale_rows = sprites + list(diagonal_by_state.values())
        scale = champion_scale(scale_rows, TARGET_IDLE_HEIGHTS[champion_index])
        for state_index, row in enumerate(sprites):
            atlas_row = champion_index * len(states) + state_index
            for cardinal_index, sprite in enumerate(row):
                direction_index = cardinal_index * 2 if has_diagonals else cardinal_index
                fitted = fit_sprite(sprite, scale)
                x = direction_index * OUTPUT_CELL + (OUTPUT_CELL - fitted.width) // 2
                y = atlas_row * OUTPUT_CELL + OUTPUT_PIVOT_Y - fitted.height
                atlas.alpha_composite(fitted, (x, y))
            state_id = states[state_index]
            if state_id in diagonal_by_state:
                for diagonal_index, sprite in enumerate(diagonal_by_state[state_id]):
                    direction_index = diagonal_index * 2 + 1
                    fitted = fit_sprite(sprite, scale)
                    x = direction_index * OUTPUT_CELL + (OUTPUT_CELL - fitted.width) // 2
                    y = atlas_row * OUTPUT_CELL + OUTPUT_PIVOT_Y - fitted.height
                    atlas.alpha_composite(fitted, (x, y))

    alpha = atlas.getchannel("A").point(lambda value: 255 if value >= 48 else 0)
    atlas = atlas.convert("RGB").quantize(
        colors=48,
        method=Image.Quantize.FASTOCTREE,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    atlas.putalpha(alpha)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output_path, optimize=True)
    print(
        f"built {output_path} {atlas.width}x{atlas.height}; "
        f"columns={','.join(directions)}; states={','.join(states)}"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("oh_tipi_source", type=Path)
    parser.add_argument("s_wayne_source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--oh-tipi-movement", type=Path)
    parser.add_argument("--s-wayne-movement", type=Path)
    parser.add_argument("--oh-tipi-diagonal-core", type=Path)
    parser.add_argument("--s-wayne-diagonal-core", type=Path)
    parser.add_argument("--oh-tipi-diagonal-locomotion", type=Path)
    parser.add_argument("--s-wayne-diagonal-locomotion", type=Path)
    parser.add_argument("--oh-tipi-locomotion-phase-b", type=Path)
    parser.add_argument("--s-wayne-locomotion-phase-b", type=Path)
    parser.add_argument("--oh-tipi-diagonal-actions", type=Path)
    parser.add_argument("--s-wayne-diagonal-actions", type=Path)
    arguments = parser.parse_args()
    movement_sources: tuple[Path, Path] | None = None
    if (arguments.oh_tipi_movement is None) != (arguments.s_wayne_movement is None):
        parser.error("both movement source sheets are required together")
    if arguments.oh_tipi_movement is not None:
        movement_sources = (arguments.oh_tipi_movement, arguments.s_wayne_movement)
    diagonal_sources: tuple[Path, Path] | None = None
    if (arguments.oh_tipi_diagonal_core is None) != (arguments.s_wayne_diagonal_core is None):
        parser.error("both diagonal core source sheets are required together")
    if arguments.oh_tipi_diagonal_core is not None:
        diagonal_sources = (
            arguments.oh_tipi_diagonal_core,
            arguments.s_wayne_diagonal_core,
        )
    diagonal_locomotion_sources: tuple[Path, Path] | None = None
    if (arguments.oh_tipi_diagonal_locomotion is None) != (arguments.s_wayne_diagonal_locomotion is None):
        parser.error("both diagonal locomotion source sheets are required together")
    if arguments.oh_tipi_diagonal_locomotion is not None:
        diagonal_locomotion_sources = (
            arguments.oh_tipi_diagonal_locomotion,
            arguments.s_wayne_diagonal_locomotion,
        )
    if diagonal_locomotion_sources is not None and diagonal_sources is None:
        parser.error("diagonal locomotion requires paired diagonal core sources")
    locomotion_phase_b_sources: tuple[Path, Path] | None = None
    if (arguments.oh_tipi_locomotion_phase_b is None) != (arguments.s_wayne_locomotion_phase_b is None):
        parser.error("both phase-B locomotion source sheets are required together")
    if arguments.oh_tipi_locomotion_phase_b is not None:
        locomotion_phase_b_sources = (
            arguments.oh_tipi_locomotion_phase_b,
            arguments.s_wayne_locomotion_phase_b,
        )
    diagonal_action_sources: tuple[Path, Path] | None = None
    if (arguments.oh_tipi_diagonal_actions is None) != (arguments.s_wayne_diagonal_actions is None):
        parser.error("both diagonal action source sheets are required together")
    if arguments.oh_tipi_diagonal_actions is not None:
        diagonal_action_sources = (
            arguments.oh_tipi_diagonal_actions,
            arguments.s_wayne_diagonal_actions,
        )
    if (locomotion_phase_b_sources is None) != (diagonal_action_sources is None):
        parser.error("phase-B cardinal and diagonal action sources are required together")
    build(
        (arguments.oh_tipi_source, arguments.s_wayne_source),
        arguments.output,
        movement_sources,
        diagonal_sources,
        diagonal_locomotion_sources,
        locomotion_phase_b_sources,
        diagonal_action_sources,
    )


if __name__ == "__main__":
    main()
