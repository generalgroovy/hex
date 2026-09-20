#!/usr/bin/env python3
"""Generate the complete Wellspring v2 visual-production catalog.

Outputs are deterministic, original pixel art intended for direct Godot use.
Presentation metadata remains downstream of authoritative simulation contracts.
"""
from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont

import generate_visual_assets_v1 as base
from wellspring_catalog_data_v2 import (
    CELL_SIZE, DIRECTIONS, DISTRICTS, ELEMENTS, MATERIALS, MATERIAL_STATES,
    PIVOT, PRESENTATIONS, PROPS, PROP_STATES, RACES, SCHEMA_VERSION,
    SIZE_IDS, SIZE_LABELS, UI_SURFACES, VFX_PHASES, champion_profiles,
)
from wellspring_environment_v2 import (
    MAP_PIXELS, district_layout, make_element_icon_atlas, make_flux_cascade_atlas,
    make_material_atlas, make_prop_atlas, make_tile_atlas, make_ui_skin,
    make_ui_surface_overview, make_vfx_atlas, make_wellspring_overview,
    render_layout,
)
from wellspring_pixel_art_v2 import (
    ATLAS_SIZE, make_animation_keyframe_board, make_character_atlas,
    make_direction_preview, make_portrait, make_selection_icon, rgba, save_png,
)

ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = ROOT / "content/visual/wellspring_visual_catalog_v2.json"
HASH_PATH = ROOT / "content/visual/wellspring_visual_hashes_v2.json"
DOC_PATH = ROOT / "docs/WELLSPRING-VISUAL-PRODUCTION.md"

RACE_ROOT = ROOT / "assets/sprites/races_v2"
CHAMPION_ROOT = ROOT / "assets/sprites/champions_v2"
WELLSPRING_TILE_ROOT = ROOT / "assets/tiles/wellspring"
WELLSPRING_MAP_ROOT = ROOT / "assets/maps/wellspring"
WELLSPRING_EFFECT_ROOT = ROOT / "assets/effects/wellspring"
MATERIAL_ROOT = ROOT / "assets/tiles/materials_v2"
PROP_ROOT = ROOT / "assets/props_v2"
VFX_ROOT = ROOT / "assets/effects/elements_v2"
UI_ROOT = ROOT / "assets/ui/wellspring_v2"
ICON_ROOT = ROOT / "assets/icons/v2"
DISTRICT_CONTENT_ROOT = ROOT / "content/maps/wellspring/districts"

EXEMPLAR_ELEMENTS = {
    "human": ["light", "wind"],
    "dwarf": ["earth", "fire"],
    "gnome": ["charge", "light"],
    "hobbit": ["earth", "wind"],
    "elf": ["wind", "light"],
    "orc": ["earth", "fire"],
    "troll": ["earth", "water"],
    "minotaur": ["earth", "fire"],
    "seakin": ["water", "ice"],
    "wyrmborn": ["fire", "wind"],
    "stoneborn": ["earth", "charge"],
    "treefolk": ["earth", "water"],
    "sylph": ["wind", "charge"],
    "undead": ["dark", "ice"],
    "goblin": ["fire", "charge"],
    "nymph": ["water", "light"],
    "arachnoid": ["dark", "earth"],
    "vampire": ["dark", "wind"],
    "demon": ["fire", "dark"],
    "angel": ["light", "wind"],
    "werewolf": ["earth", "wind"],
}

EXEMPLAR_WEAPONS = {
    "human": "arc_blade", "dwarf": "forge_hammer", "gnome": "charge_gloves",
    "hobbit": "wayfarer_sling", "elf": "wind_rapier", "orc": "stone_maul",
    "troll": "greatbow", "minotaur": "breaker_hammer", "seakin": "tide_conduit",
    "wyrmborn": "ember_lance", "stoneborn": "kiln_shield", "treefolk": "root_gauntlets",
    "sylph": "gale_disc", "undead": "grave_sabre", "goblin": "spark_detonator",
    "nymph": "bloom_orb", "arachnoid": "silk_blade", "vampire": "night_rapier",
    "demon": "rift_blade", "angel": "halo_bracers", "werewolf": "claw_gauntlet",
}

HAIR_BY_PRESENTATION = {
    "masculine": "short_dark",
    "feminine": "long_dark",
}


def resource(path: Path) -> str:
    return "res://" + path.relative_to(ROOT).as_posix()


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def clean_v2_outputs() -> None:
    for path in (
        RACE_ROOT, CHAMPION_ROOT, WELLSPRING_TILE_ROOT, WELLSPRING_MAP_ROOT,
        WELLSPRING_EFFECT_ROOT, MATERIAL_ROOT, PROP_ROOT, VFX_ROOT, UI_ROOT,
        ICON_ROOT, DISTRICT_CONTENT_ROOT,
    ):
        if path.exists():
            shutil.rmtree(path)
    for path in (CATALOG_PATH, HASH_PATH, DOC_PATH):
        if path.exists():
            path.unlink()


def race_profile(race_id: str, size_id: str, presentation: str, exemplar: bool = False) -> dict[str, Any]:
    race = RACES[race_id]
    profile = {
        "id": f"{race_id}_{size_id}_{presentation}",
        "name": race["exemplar"] if exemplar else f"{SIZE_LABELS[size_id]} {race['name']} {presentation.title()}",
        "ancestry": race_id,
        "size": size_id,
        "presentation": presentation,
        "skin": race["skin"],
        "primary": race["primary"],
        "secondary": race["secondary"],
        "accent": race["accent"],
        "feature": race["feature"],
        "hair": HAIR_BY_PRESENTATION[presentation],
        "weapon": EXEMPLAR_WEAPONS[race_id] if exemplar else "training_bracers",
        "elements": EXEMPLAR_ELEMENTS[race_id] if exemplar else [],
        "status": "production_foundation" if not exemplar else "integrated_candidate",
    }
    if race_id in {"undead", "stoneborn", "treefolk", "arachnoid", "seakin", "wyrmborn", "demon", "angel", "werewolf", "minotaur"}:
        profile["hair"] = "none"
    if race_id == "gnome" and exemplar:
        profile["hair"] = "bald_sides"
    return profile


def canonical_champion_profile(profile: dict[str, Any]) -> dict[str, Any]:
    race = RACES[profile["ancestry"]]
    result = dict(profile)
    result.setdefault("presentation", "neutral")
    result.setdefault("skin", race["skin"])
    result.setdefault("primary", race["primary"])
    result.setdefault("secondary", race["secondary"])
    result.setdefault("accent", race["accent"])
    result.setdefault("feature", race["feature"])
    result.setdefault("hair", "short_dark")
    result.setdefault("weapon", EXEMPLAR_WEAPONS[profile["ancestry"]])
    result.setdefault("elements", EXEMPLAR_ELEMENTS[profile["ancestry"]])
    return result


def animation_contract() -> dict[str, Any]:
    return {
        "cell_size": [CELL_SIZE, CELL_SIZE],
        "pivot": list(PIVOT),
        "atlas_size": list(ATLAS_SIZE),
        "directions": list(DIRECTIONS),
        "animations": [
            {
                "id": animation,
                "block": [block_x, block_y],
                "frames": frame_count,
                "fps": fps,
                "loop": animation in {"idle", "walk", "sprint", "fall", "wall_contact", "slide", "stunned", "rooted"},
            }
            for animation, (block_x, block_y, frame_count, fps) in base.A.items()
        ],
        "anchors": [
            "gameplay_root", "feet_baseline", "shadow", "body_lift", "head",
            "main_hand", "off_hand", "back", "projectile_origin", "cast_origin",
            "effect_origin", "horns", "fins", "wings", "tail", "roots",
            "auxiliary_limbs", "canopy",
        ],
        "authority": "presentation_only; gameplay footprint and simulation remain separate",
    }


def generate_races(catalog: dict[str, Any], generated: list[Path]) -> None:
    for race_id, race in RACES.items():
        race_dir = RACE_ROOT / race_id
        variants: dict[str, Any] = {}
        matrix_profiles: list[dict[str, Any]] = []
        for size_id in SIZE_IDS:
            variants[size_id] = {}
            for presentation in PRESENTATIONS:
                profile = race_profile(race_id, size_id, presentation)
                matrix_profiles.append(profile)
                output_dir = race_dir / "bases" / size_id / presentation
                atlas_path = output_dir / "atlas.png"
                save_png(make_character_atlas(profile), atlas_path)
                generated.append(atlas_path)
                variants[size_id][presentation] = {
                    "id": profile["id"],
                    "status": "production_foundation",
                    "atlas": resource(atlas_path),
                    "size": size_id,
                    "presentation": presentation,
                    "animation_count": len(base.A),
                    "direction_count": len(DIRECTIONS),
                    "all_keyframes_included": True,
                }

        matrix_preview = make_race_matrix_preview(race_id, matrix_profiles)
        matrix_path = race_dir / f"{race_id}_size_gender_matrix.png"
        save_png(matrix_preview, matrix_path)
        generated.append(matrix_path)

        exemplar_presentation = "feminine" if race_id in {"hobbit", "sylph", "nymph", "angel", "arachnoid"} else "masculine"
        exemplar_profile = race_profile(race_id, race["default_size"], exemplar_presentation, exemplar=True)
        exemplar_dir = race_dir / "exemplar"
        exemplar_paths = write_character_package(exemplar_profile, exemplar_dir, include_debug=True, generated=generated)

        catalog["races"][race_id] = {
            "name": race["name"],
            "status": race["status"],
            "feature": race["feature"],
            "supported_sizes": list(SIZE_IDS),
            "presentations": list(PRESENTATIONS),
            "base_variants": variants,
            "matrix_preview": resource(matrix_path),
            "subtypes": race.get("subtypes", []),
            "exemplar": {
                "id": f"{race_id}_exemplar",
                "name": race["exemplar"],
                "size": race["default_size"],
                "presentation": exemplar_presentation,
                "elements": EXEMPLAR_ELEMENTS[race_id],
                "status": "integrated_candidate",
                **exemplar_paths,
            },
        }


def write_character_package(profile: dict[str, Any], output_dir: Path, include_debug: bool, generated: list[Path]) -> dict[str, Any]:
    atlas_path = output_dir / "atlas.png"
    direction_path = output_dir / "direction_preview.png"
    keyframe_path = output_dir / "keyframe_board.png"
    selection_path = output_dir / "selection_icon_48.png"
    hud_path = output_dir / "hud_portrait_64.png"
    roster_path = output_dir / "roster_portrait_128.png"
    hero_path = output_dir / "hero_portrait_256.png"

    save_png(make_character_atlas(profile), atlas_path)
    save_png(make_direction_preview(profile), direction_path)
    save_png(make_animation_keyframe_board(profile), keyframe_path)
    save_png(make_selection_icon(profile), selection_path)
    save_png(make_portrait(profile, 64), hud_path)
    save_png(make_portrait(profile, 128), roster_path)
    save_png(make_portrait(profile, 256), hero_path)
    paths = [atlas_path, direction_path, keyframe_path, selection_path, hud_path, roster_path, hero_path]

    result = {
        "atlas": resource(atlas_path),
        "direction_preview": resource(direction_path),
        "keyframe_board": resource(keyframe_path),
        "selection_icon": resource(selection_path),
        "hud_portrait": resource(hud_path),
        "roster_portrait": resource(roster_path),
        "hero_portrait": resource(hero_path),
        "all_keyframes_included": True,
        "animation_count": len(base.A),
        "direction_count": len(DIRECTIONS),
    }
    if include_debug:
        debug_path = output_dir / "debug_atlas.png"
        save_png(make_character_atlas(profile, debug=True), debug_path)
        paths.append(debug_path)
        result["debug_atlas"] = resource(debug_path)
    generated.extend(paths)
    return result


def make_race_matrix_preview(race_id: str, profiles: list[dict[str, Any]]) -> Image.Image:
    cell_w, cell_h = 160, 192
    image = Image.new("RGBA", (len(SIZE_IDS) * cell_w, len(PRESENTATIONS) * cell_h), rgba("#11181d"))
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default()
    for index, profile in enumerate(profiles):
        size_index = SIZE_IDS.index(profile["size"])
        presentation_index = PRESENTATIONS.index(profile["presentation"])
        x = size_index * cell_w
        y = presentation_index * cell_h
        frame = make_portrait(profile, 128)
        image.alpha_composite(frame, (x + 16, y + 16))
        draw.rectangle((x + 4, y + 4, x + cell_w - 5, y + cell_h - 5), outline=rgba(profile["accent"]), width=2)
        draw.text((x + 16, y + 150), f"{SIZE_LABELS[profile['size']]} · {profile['presentation']}", fill=rgba("#e7ddc3"), font=font)
    draw.text((12, 2), f"{RACES[race_id]['name']} — complete size/presentation foundations", fill=rgba("#e7ddc3"), font=font)
    return image


def generate_champions(catalog: dict[str, Any], generated: list[Path]) -> None:
    portraits: list[tuple[str, Image.Image, str]] = []
    for raw_profile in champion_profiles():
        profile = canonical_champion_profile(raw_profile)
        output_dir = CHAMPION_ROOT / profile["id"]
        package = write_character_package(profile, output_dir, include_debug=True, generated=generated)
        catalog["champions"][profile["id"]] = {
            "name": profile["name"],
            "ancestry": profile["ancestry"],
            "size": profile["size"],
            "presentation": profile.get("presentation", "neutral"),
            "elements": profile.get("elements", []),
            "status": profile.get("status", "integrated_candidate"),
            "feature": profile.get("feature", RACES[profile["ancestry"]]["feature"]),
            "weapon": profile.get("weapon", "none"),
            **package,
        }
        portraits.append((profile["name"], make_portrait(profile, 128), profile["accent"]))

    overview = make_portrait_overview(portraits, columns=6, title="FLUX2 Champion Visual Packages v2")
    overview_path = CHAMPION_ROOT / "champion_roster_overview_v2.png"
    save_png(overview, overview_path)
    generated.append(overview_path)
    catalog["overviews"]["champions"] = resource(overview_path)


def make_portrait_overview(entries: list[tuple[str, Image.Image, str]], columns: int, title: str) -> Image.Image:
    cell_w, cell_h = 176, 176
    rows = (len(entries) + columns - 1) // columns
    image = Image.new("RGBA", (columns * cell_w, rows * cell_h + 32), rgba("#11181d"))
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default()
    draw.text((12, 10), title, fill=rgba("#e7ddc3"), font=font)
    for index, (name, portrait, accent) in enumerate(entries):
        column = index % columns
        row = index // columns
        x = column * cell_w
        y = 32 + row * cell_h
        image.alpha_composite(portrait, (x + 24, y + 8))
        draw.rectangle((x + 8, y + 4, x + cell_w - 9, y + cell_h - 5), outline=rgba(accent), width=2)
        draw.text((x + 16, y + 142), name, fill=rgba("#e7ddc3"), font=font)
    return image


def generate_wellspring(catalog: dict[str, Any], generated: list[Path]) -> None:
    tile_atlas, tile_registry = make_tile_atlas()
    tile_path = WELLSPRING_TILE_ROOT / "wellspring_tiles_v2.png"
    save_png(tile_atlas, tile_path)
    generated.append(tile_path)
    registry_path = WELLSPRING_TILE_ROOT / "wellspring_tiles_v2.json"
    write_json(registry_path, {"schema_version": 2, "tile_size": [16, 16], "tiles": tile_registry})
    generated.append(registry_path)

    cascade_path = WELLSPRING_EFFECT_ROOT / "cosmic_wellspring_cascade_v2.png"
    save_png(make_flux_cascade_atlas(), cascade_path)
    generated.append(cascade_path)

    previews: dict[str, Image.Image] = {}
    for district in DISTRICTS:
        layout = district_layout(district["id"])
        layout_path = DISTRICT_CONTENT_ROOT / f"{district['id']}_v2.json"
        write_json(layout_path, layout)
        generated.append(layout_path)
        preview = render_layout(layout, tile_atlas, tile_registry)
        preview_path = WELLSPRING_MAP_ROOT / district["id"] / "preview_1280x720.png"
        save_png(preview, preview_path)
        generated.append(preview_path)
        previews[district["id"]] = preview
        catalog["wellspring"]["districts"][district["id"]] = {
            "name": district["name"],
            "function": district["function"],
            "landmark": district["landmark"],
            "status": "integrated_candidate",
            "layout": resource(layout_path),
            "preview": resource(preview_path),
            "ordinary_route": next((route["id"] for route in layout["routes"] if route["kind"] == "ordinary"), ""),
            "advanced_route": next((route["id"] for route in layout["routes"] if route["kind"] == "advanced"), ""),
        }

    overview_path = WELLSPRING_MAP_ROOT / "wellspring_overview_2560x1440.png"
    save_png(make_wellspring_overview(previews), overview_path)
    generated.append(overview_path)
    catalog["wellspring"].update({
        "id": "wellspring",
        "name": "The Wellspring",
        "status": "integrated_candidate",
        "tileset": resource(tile_path),
        "tile_registry": resource(registry_path),
        "cosmic_cascade": resource(cascade_path),
        "overview_1440p": resource(overview_path),
        "legacy_aliases": ["sanctum", "living_sanctum"],
    })

    hub_path = ROOT / "content/maps/wellspring_hub_v2.json"
    write_json(hub_path, {
        "schema_version": 2,
        "id": "wellspring",
        "name": "The Wellspring",
        "status": "integrated_candidate",
        "district_order": [district["id"] for district in DISTRICTS],
        "central_landmark": "cosmic_wellspring",
        "visual_catalog": resource(CATALOG_PATH),
        "legacy_aliases": ["sanctum_hub_v1", "sanctum"],
    })
    generated.append(hub_path)
    alias_path = ROOT / "content/maps/sanctum_to_wellspring_alias_v2.json"
    write_json(alias_path, {
        "schema_version": 2,
        "id": "sanctum",
        "status": "deprecated_alias",
        "replacement_id": "wellspring",
        "replacement_path": resource(hub_path),
    })
    generated.append(alias_path)


def generate_support_assets(catalog: dict[str, Any], generated: list[Path]) -> None:
    material_path = MATERIAL_ROOT / "material_states_v2.png"
    save_png(make_material_atlas(), material_path)
    generated.append(material_path)
    catalog["materials"] = {
        "path": resource(material_path),
        "materials": list(MATERIALS),
        "states": list(MATERIAL_STATES),
        "cell_size": [32, 32],
        "status": "production_foundation",
    }

    prop_path = PROP_ROOT / "interaction_props_v2.png"
    save_png(make_prop_atlas(), prop_path)
    generated.append(prop_path)
    catalog["props"] = {
        "path": resource(prop_path),
        "props": list(PROPS),
        "states": list(PROP_STATES),
        "cell_size": [48, 48],
        "status": "production_foundation",
    }

    vfx_path = VFX_ROOT / "element_vfx_v2.png"
    save_png(make_vfx_atlas(), vfx_path)
    generated.append(vfx_path)
    catalog["element_vfx"] = {
        "path": resource(vfx_path),
        "elements": list(ELEMENTS),
        "phases": list(VFX_PHASES),
        "frames_per_phase": 4,
        "cell_size": [32, 32],
        "status": "production_foundation",
    }

    icon_path = ICON_ROOT / "element_icons_v2.png"
    save_png(make_element_icon_atlas(), icon_path)
    generated.append(icon_path)
    catalog["icons"] = {
        "elements": resource(icon_path),
        "cell_size": [32, 32],
        "status": "production_foundation",
    }

    skin_path = UI_ROOT / "wellspring_ui_skin_v2.png"
    overview_path = UI_ROOT / "ui_surface_overview_v2.png"
    save_png(make_ui_skin(), skin_path)
    save_png(make_ui_surface_overview(), overview_path)
    generated.extend((skin_path, overview_path))
    catalog["ui"] = {
        "skin": resource(skin_path),
        "surface_overview": resource(overview_path),
        "surfaces": list(UI_SURFACES),
        "virtual_viewport": [640, 360],
        "integer_scales": {"1920x1080": 3, "2560x1440": 4, "3840x2160": 6},
        "status": "production_foundation",
    }


def generate_docs(catalog: dict[str, Any], generated: list[Path]) -> None:
    text = build_visual_document(catalog)
    DOC_PATH.parent.mkdir(parents=True, exist_ok=True)
    DOC_PATH.write_text(text, encoding="utf-8")
    generated.append(DOC_PATH)

    folder_readmes = {
        RACE_ROOT / "README.md": race_readme(catalog),
        CHAMPION_ROOT / "README.md": champion_readme(catalog),
        WELLSPRING_MAP_ROOT / "README.md": wellspring_readme(catalog),
        UI_ROOT / "README.md": ui_readme(catalog),
    }
    for path, content in folder_readmes.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        generated.append(path)

    migrate_wellspring_docs(generated)
    update_root_readme(catalog)


def table(headers: list[str], rows: list[list[Any]]) -> str:
    result = ["| " + " | ".join(headers) + " |", "| " + " | ".join("---" for _ in headers) + " |"]
    result.extend("| " + " | ".join(str(value) for value in row) + " |" for row in rows)
    return "\n".join(result)


def build_visual_document(catalog: dict[str, Any]) -> str:
    race_rows = []
    for race_id, entry in catalog["races"].items():
        race_rows.append([
            f"`{race_id}`", entry["name"], entry["status"], "5", "2",
            f"`{entry['exemplar']['name']}`", f"`{entry['matrix_preview']}`",
        ])
    champion_rows = []
    for champion_id, entry in catalog["champions"].items():
        champion_rows.append([
            f"`{champion_id}`", entry["name"], entry["ancestry"], SIZE_LABELS[entry["size"]],
            ", ".join(entry["elements"]), entry["status"], f"`{entry['atlas']}`", f"`{entry['hero_portrait']}`",
        ])
    district_rows = []
    for district_id, entry in catalog["wellspring"]["districts"].items():
        district_rows.append([
            entry["name"], entry["function"], entry["landmark"], entry["ordinary_route"],
            entry["advanced_route"], entry["status"], f"`{entry['layout']}`",
        ])
    animation_rows = []
    for animation in catalog["character_contract"]["animations"]:
        animation_rows.append([
            f"`{animation['id']}`", animation["frames"], animation["fps"], animation["loop"], animation["block"],
        ])
    material_rows = [[material] + ["✓" for _ in MATERIAL_STATES] for material in MATERIALS]
    prop_rows = [[prop, len(PROP_STATES), "✓", "production_foundation"] for prop in PROPS]
    ui_rows = [[surface, "640×360 virtual", "keyboard/mouse/controller", "shape + value + color", "production_foundation"] for surface in UI_SURFACES]

    return f"""# The Wellspring visual-production catalog v2

This catalog is generated from deterministic source code and is directly usable by
Godot. Rendered pixels never define collision, damage, reach, chemistry or other
simulation authority.

## Production status

| Category | Planned | Complete | Candidate | Gated | Validation |
| --- | ---: | ---: | ---: | ---: | --- |
| Race size/presentation foundations | {len(RACES) * len(SIZE_IDS) * len(PRESENTATIONS)} | {len(RACES) * len(SIZE_IDS) * len(PRESENTATIONS)} | 0 | 0 | atlas, dimensions, keyframes, paths |
| Race exemplars | {len(RACES)} | {len(RACES)} | {len(RACES)} | 0 | full package |
| Champion packages | {len(catalog['champions'])} | {len(catalog['champions'])} | {len(catalog['champions']) - 1} | 1 | full package |
| Wellspring districts | {len(DISTRICTS)} | {len(DISTRICTS)} | {len(DISTRICTS)} | 0 | topology layers + preview |
| Elements | {len(ELEMENTS)} | {len(ELEMENTS)} | 0 | 0 | icon + eight phases × four frames |
| Materials | {len(MATERIALS)} | {len(MATERIALS)} | 0 | 0 | twelve visual states |
| Props | {len(PROPS)} | {len(PROPS)} | 0 | 0 | eleven interaction states |
| UI surfaces | {len(UI_SURFACES)} | {len(UI_SURFACES)} | 0 | 0 | 1080p/1440p/4K integer scale contract |

## Race and ancestry catalog

{table(['ID', 'Name', 'Status', 'Sizes', 'Presentations', 'Exemplar', 'Preview'], race_rows)}

Every race includes Tiny, Small, Medium, Large and Huge foundations in masculine
and feminine presentations. These are presentation foundations, not automatic
gameplay permission for every race/size combination.

## Champion and exemplar roster

{table(['ID', 'Name', 'Race', 'Size', 'Affinities', 'Status', 'Atlas', 'Hero portrait'], champion_rows)}

## Animation keyframes

{table(['Animation', 'Frames', 'FPS', 'Loop', 'Atlas block'], animation_rows)}

All listed animations are present for all eight directions in every base-race,
race-exemplar and champion atlas.

## The Wellspring districts

{table(['District', 'Function', 'Landmark', 'Ordinary route', 'Advanced route', 'Status', 'Layout'], district_rows)}

The Wellspring is built around the Cosmic Wellspring: a vertical, eight-current
Flux cascade feeding the Source Basin and branching Fluxways. Each district is a
modular 80×45-tile package with visual, collision, worldbone, navigation and
elevation layers. Simulation systems remain authoritative when loaded in game.

## Elements

{table(['Element', 'Icon', 'Startup', 'Cast', 'Travel', 'Field', 'Impact', 'Residue', 'Status'], [[element, '✓', '✓', '✓', '✓', '✓', '✓', '✓', '✓'] for element in ELEMENTS])}

## Materials

{table(['Material'] + [state.replace('_', ' ').title() for state in MATERIAL_STATES], material_rows)}

## Prop families

{table(['Prop', 'States', 'Atlas', 'Status'], prop_rows)}

## UI surfaces

{table(['Surface', 'Virtual size', 'Input', 'Accessibility', 'Status'], ui_rows)}

## Validation matrix

| Asset group | File checks | Godot import | Gameplay zoom | Grayscale | 1080p | 1440p | 4K |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Characters | ✓ | ✓ | ✓ | generated review | 3× | 4× | 6× |
| Wellspring | ✓ | ✓ | ✓ | generated review | 3× | 4× | 6× |
| VFX | ✓ | ✓ | ✓ | shape-first | 3× | 4× | 6× |
| UI | ✓ | ✓ | ✓ | shape + value | 3× | 4× | 6× |

## Main asset paths

| Category | Source/runtime path | Registry |
| --- | --- | --- |
| Race foundations | `assets/sprites/races_v2/` | `content/visual/wellspring_visual_catalog_v2.json` |
| Champions | `assets/sprites/champions_v2/` | `content/visual/wellspring_visual_catalog_v2.json` |
| Wellspring tiles/maps | `assets/tiles/wellspring/`, `assets/maps/wellspring/` | `content/maps/wellspring/` |
| Materials | `assets/tiles/materials_v2/` | visual catalog |
| Props | `assets/props_v2/` | visual catalog |
| VFX | `assets/effects/elements_v2/` | visual catalog |
| UI | `assets/ui/wellspring_v2/` | visual catalog |

## Commands

```bash
python tools/assets/generate_wellspring_visual_catalog_v2.py
python tools/assets/validate_wellspring_visual_catalog_v2.py
scripts/test.sh
```
"""


def race_readme(catalog: dict[str, Any]) -> str:
    rows = [[race_id, entry["name"], "5", "2", entry["exemplar"]["name"], entry["status"]] for race_id, entry in catalog["races"].items()]
    return "# Race visual foundations v2\n\n" + table(["ID", "Name", "Sizes", "Presentations", "Exemplar", "Status"], rows) + "\n"


def champion_readme(catalog: dict[str, Any]) -> str:
    rows = [[entry["name"], entry["ancestry"], SIZE_LABELS[entry["size"]], ", ".join(entry["elements"]), entry["status"]] for entry in catalog["champions"].values()]
    return "# Champion visual packages v2\n\n" + table(["Champion", "Race", "Size", "Affinities", "Status"], rows) + "\n"


def wellspring_readme(catalog: dict[str, Any]) -> str:
    rows = [[entry["name"], entry["function"], entry["landmark"], entry["status"]] for entry in catalog["wellspring"]["districts"].values()]
    return "# The Wellspring map visuals v2\n\n" + table(["District", "Function", "Landmark", "Status"], rows) + "\n"


def ui_readme(catalog: dict[str, Any]) -> str:
    rows = [[surface, "640×360", "3× / 4× / 6×", "production_foundation"] for surface in catalog["ui"]["surfaces"]]
    return "# Wellspring UI assets v2\n\n" + table(["Surface", "Virtual viewport", "Integer scales", "Status"], rows) + "\n"


def migrate_wellspring_docs(generated: list[Path]) -> None:
    migrations = (
        (ROOT / "docs/SANCTUM-HUB.md", ROOT / "docs/WELLSPRING-HUB.md"),
        (ROOT / "docs/SANCTUM-V1-ACCEPTANCE.md", ROOT / "docs/WELLSPRING-V1-ACCEPTANCE.md"),
    )
    for source, target in migrations:
        if not source.is_file():
            continue
        text = source.read_text(encoding="utf-8")
        text = text.replace("Living Sanctum", "Living Wellspring")
        text = text.replace("The Sanctum", "The Wellspring")
        text = text.replace("the Sanctum", "the Wellspring")
        text = text.replace("Sanctum", "Wellspring")
        text = text.replace("sanctum", "wellspring")
        target.write_text(text, encoding="utf-8")
        generated.append(target)


def update_root_readme(catalog: dict[str, Any]) -> None:
    path = ROOT / "README.md"
    if not path.is_file():
        return
    text = path.read_text(encoding="utf-8")
    replacements = {
        "**Chapter 2 — [The Sanctum](#the-sanctum)**": "**Chapter 2 — [The Wellspring](#the-wellspring)**",
        "Living Sanctum V1": "Living Wellspring V1",
        "The Sanctum is": "The Wellspring is",
        "The Sanctum itself": "The Wellspring itself",
        "the Sanctum itself": "the Wellspring itself",
        "The Sanctum is the persistent": "The Wellspring is the persistent",
        "## The Sanctum": "## The Wellspring",
        "[the Sanctum contract](docs/SANCTUM-HUB.md)": "[the Wellspring contract](docs/WELLSPRING-HUB.md)",
        "[Living Sanctum V1 acceptance contract](docs/SANCTUM-V1-ACCEPTANCE.md)": "[Living Wellspring V1 acceptance contract](docs/WELLSPRING-V1-ACCEPTANCE.md)",
        "[map definition](content/maps/sanctum_hub_v1.json)": "[map definition](content/maps/wellspring_hub_v2.json)",
        "![Expanded Sanctum visual direction]": "![Expanded Wellspring visual direction]",
        "Sanctum districts": "Wellspring districts",
        "Sanctum friend": "Wellspring friend",
        "in Sanctum/activity": "in Wellspring/activity",
        "accepted Sanctum art/topology": "accepted Wellspring art/topology",
        "Living Sanctum friend presence": "Living Wellspring friend presence",
        "The target hub direction": "The target Wellspring direction",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)

    begin = "<!-- BEGIN WELLSPRING_VISUAL_V2 -->"
    end = "<!-- END WELLSPRING_VISUAL_V2 -->"
    section = f"""{begin}
## Wellspring visual-production v2

| Asset family | Complete |
| --- | ---: |
| Race foundations: {len(RACES)} races × 5 sizes × 2 presentations | {len(RACES) * len(SIZE_IDS) * len(PRESENTATIONS)} |
| Complete race exemplars | {len(RACES)} |
| Complete champion visual packages | {len(catalog['champions'])} |
| Wellspring district packages | {len(DISTRICTS)} |
| Enabled element VFX families | {len(ELEMENTS)} |
| Material/state cells | {len(MATERIALS) * len(MATERIAL_STATES)} |
| Prop/state cells | {len(PROPS) * len(PROP_STATES)} |

See [the complete tabular visual catalog](docs/WELLSPRING-VISUAL-PRODUCTION.md).
{end}"""
    if begin in text and end in text:
        prefix, remainder = text.split(begin, 1)
        _, suffix = remainder.split(end, 1)
        text = prefix + section + suffix
    else:
        text = text.rstrip() + "\n\n" + section + "\n"
    path.write_text(text, encoding="utf-8")


def create_hash_manifest(generated: list[Path]) -> None:
    entries = []
    for path in sorted(set(generated)):
        if not path.is_file() or path == HASH_PATH:
            continue
        entries.append({
            "path": path.relative_to(ROOT).as_posix(),
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        })
    write_json(HASH_PATH, {"schema_version": 2, "files": entries})


def main() -> int:
    clean_v2_outputs()
    generated: list[Path] = []
    catalog: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "id": "wellspring-visual-catalog-v2",
        "name": "The Wellspring visual catalog v2",
        "status": "integrated_candidate",
        "style": {
            "name": "charming clustered-outline fantasy pixel art",
            "virtual_viewport": [640, 360],
            "primary_display": [2560, 1440],
            "integer_scaling": True,
            "nearest_neighbour": True,
            "reference_role": "quality, charm, silhouette and density target; all output remains original",
        },
        "character_contract": animation_contract(),
        "races": {},
        "champions": {},
        "wellspring": {"districts": {}},
        "materials": {},
        "props": {},
        "element_vfx": {},
        "icons": {},
        "ui": {},
        "overviews": {},
    }

    generate_races(catalog, generated)
    generate_champions(catalog, generated)
    generate_wellspring(catalog, generated)
    generate_support_assets(catalog, generated)
    write_json(CATALOG_PATH, catalog)
    generated.append(CATALOG_PATH)
    generate_docs(catalog, generated)
    generated.append(ROOT / "README.md")
    create_hash_manifest(generated)

    print("Wellspring visual catalog v2 generated")
    print(f"{len(RACES)} races x {len(SIZE_IDS)} sizes x {len(PRESENTATIONS)} presentations")
    print(f"{len(RACES)} race exemplars, {len(catalog['champions'])} champions")
    print(f"{len(DISTRICTS)} Wellspring districts, {len(ELEMENTS)} element families")
    print(f"catalog: {CATALOG_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
