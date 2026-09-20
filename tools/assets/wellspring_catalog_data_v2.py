#!/usr/bin/env python3
"""Canonical visual-production data for the Wellspring v2 catalog.

This module contains presentation metadata only. Gameplay statistics, collision,
reach, damage and ancestry rules remain authoritative elsewhere.
"""
from __future__ import annotations

from copy import deepcopy
from typing import Any

from generate_complete_visual_catalog_v1 import CHAMPIONS as V1_CHAMPIONS

SCHEMA_VERSION = 2
CELL_SIZE = 64
PIVOT = (32, 56)
DIRECTIONS = (
    "south", "south_east", "east", "north_east",
    "north", "north_west", "west", "south_west",
)

SIZE_IDS = (
    "size_1_tiny",
    "size_2_small",
    "size_3_medium",
    "size_4_large",
    "size_5_huge",
)

SIZE_LABELS = {
    "size_1_tiny": "Tiny",
    "size_2_small": "Small",
    "size_3_medium": "Medium",
    "size_4_large": "Large",
    "size_5_huge": "Huge",
}

PRESENTATIONS = ("masculine", "feminine")

ELEMENTS = (
    "earth", "fire", "water", "wind", "ice", "charge", "light", "dark",
)

ELEMENT_COLORS = {
    "earth": "#9a7d4d",
    "fire": "#f06a32",
    "water": "#3e9ac7",
    "wind": "#a7d8ca",
    "ice": "#9ee7ee",
    "charge": "#55dbe0",
    "light": "#f7e6a3",
    "dark": "#7450a8",
    "spirit": "#d79adf",
}

RACES: dict[str, dict[str, Any]] = {
    "human": {
        "name": "Human", "feature": "human", "default_size": "size_3_medium",
        "skin": "#b98263", "primary": "#3d5b72", "secondary": "#b99761", "accent": "#55dbe0",
        "exemplar": "Aster Vale", "status": "production_foundation",
    },
    "dwarf": {
        "name": "Dwarf", "feature": "dwarf", "default_size": "size_3_medium",
        "skin": "#ad7554", "primary": "#70412d", "secondary": "#b88438", "accent": "#e58a38",
        "exemplar": "Brun Forgehand", "status": "production_foundation",
    },
    "gnome": {
        "name": "Gnome", "feature": "gnome", "default_size": "size_1_tiny",
        "skin": "#b98968", "primary": "#38707a", "secondary": "#b88438", "accent": "#55dbe0",
        "exemplar": "Pip Lumen", "status": "production_foundation",
    },
    "hobbit": {
        "name": "Hobbit", "feature": "hobbit", "default_size": "size_2_small",
        "skin": "#a97958", "primary": "#55683f", "secondary": "#8b7045", "accent": "#d8e8b3",
        "exemplar": "Mara Mossfoot", "status": "production_foundation",
    },
    "elf": {
        "name": "Elf", "feature": "elf", "default_size": "size_3_medium",
        "skin": "#c18d68", "primary": "#3f6a61", "secondary": "#d7ccb0", "accent": "#a7d8ca",
        "exemplar": "Cael Veyra", "status": "production_foundation",
    },
    "orc": {
        "name": "Orc", "feature": "orc", "default_size": "size_4_large",
        "skin": "#69815b", "primary": "#3d4f39", "secondary": "#7f6345", "accent": "#e58a38",
        "exemplar": "Rokka Flint", "status": "production_foundation",
    },
    "troll": {
        "name": "Troll", "feature": "troll", "default_size": "size_5_huge",
        "skin": "#657060", "primary": "#3c3836", "secondary": "#8b7045", "accent": "#4c9eb2",
        "exemplar": "Murren Deepbow", "status": "production_foundation",
    },
    "minotaur": {
        "name": "Minotaur", "feature": "minotaur", "default_size": "size_5_huge",
        "skin": "#89644b", "primary": "#5b3127", "secondary": "#8b7045", "accent": "#f0d879",
        "exemplar": "Tor Varr", "status": "production_foundation",
    },
    "seakin": {
        "name": "Seakin", "feature": "seakin", "default_size": "size_3_medium",
        "skin": "#63aeb4", "primary": "#24566b", "secondary": "#d7f2e9", "accent": "#55dbe0",
        "exemplar": "Neria Tidefin", "status": "production_foundation",
    },
    "wyrmborn": {
        "name": "Wyrmborn", "feature": "wyrmborn", "default_size": "size_4_large",
        "skin": "#6a8892", "primary": "#38475f", "secondary": "#b4dce2", "accent": "#e58a38",
        "exemplar": "Kaelith Embercrest", "status": "production_foundation",
    },
    "stoneborn": {
        "name": "Stoneborn", "feature": "stoneborn", "default_size": "size_4_large",
        "skin": "#7f837d", "primary": "#4d5554", "secondary": "#b6a477", "accent": "#55dbe0",
        "exemplar": "Orrun Slate", "status": "production_foundation",
    },
    "treefolk": {
        "name": "Treefolk", "feature": "treefolk", "default_size": "size_4_large",
        "skin": "#715b3a", "primary": "#304b27", "secondary": "#66834a", "accent": "#e58a38",
        "exemplar": "Willow Mason", "status": "production_foundation",
    },
    "sylph": {
        "name": "Sylph", "feature": "sylph", "default_size": "size_2_small",
        "skin": "#c68f72", "primary": "#e8e0c4", "secondary": "#4b8191", "accent": "#a7d8ca",
        "exemplar": "Iri Gale", "status": "production_foundation",
    },
    "undead": {
        "name": "Undead", "feature": "undead", "default_size": "size_3_medium",
        "skin": "#b7b1a2", "primary": "#3e3b42", "secondary": "#7d2730", "accent": "#9b65d9",
        "exemplar": "Morrow Ash", "status": "production_foundation",
    },
    "goblin": {
        "name": "Goblin", "feature": "goblin", "default_size": "size_2_small",
        "skin": "#a94137", "primary": "#55202c", "secondary": "#b88438", "accent": "#55dbe0",
        "exemplar": "Zikka Spark", "status": "production_foundation",
    },
    "nymph": {
        "name": "Nymph", "feature": "nymph", "default_size": "size_2_small",
        "skin": "#a66f58", "primary": "#6a3154", "secondary": "#66834a", "accent": "#f3e7a0",
        "exemplar": "Luma Bloom", "status": "production_foundation",
    },
    "arachnoid": {
        "name": "Arachnoid", "feature": "arachnoid", "default_size": "size_3_medium",
        "skin": "#6d596b", "primary": "#2d2635", "secondary": "#8f6d45", "accent": "#d79adf",
        "exemplar": "Silk Varra", "status": "production_foundation",
        "subtypes": ["weaverkin", "scorpionkin", "harvestkin"],
    },
    "vampire": {
        "name": "Vampire", "feature": "vampire", "default_size": "size_3_medium",
        "skin": "#a17873", "primary": "#391f33", "secondary": "#242832", "accent": "#c85149",
        "exemplar": "Vesper Noct", "status": "production_foundation",
    },
    "demon": {
        "name": "Demon", "feature": "demon", "default_size": "size_3_medium",
        "skin": "#85515b", "primary": "#3b2434", "secondary": "#856b45", "accent": "#f06a32",
        "exemplar": "Kara Vex", "status": "production_foundation",
    },
    "angel": {
        "name": "Angel", "feature": "angel", "default_size": "size_3_medium",
        "skin": "#c99a78", "primary": "#e7dfc9", "secondary": "#a9bdc5", "accent": "#f7e6a3",
        "exemplar": "Aurelia Dawn", "status": "production_foundation",
    },
    "werewolf": {
        "name": "Werewolf", "feature": "werewolf", "default_size": "size_4_large",
        "skin": "#8a7362", "primary": "#40352f", "secondary": "#b6a477", "accent": "#f0d879",
        "exemplar": "Fen Marr", "status": "production_foundation",
    },
}

CHAMPION_OVERRIDES: dict[str, dict[str, Any]] = {
    "s_wayne": {"ancestry": "human", "size": "size_3_medium", "feature": "vampire_cloak"},
    "oll_i": {"ancestry": "minotaur", "size": "size_5_huge", "feature": "minotaur"},
    "wa_bidi": {"ancestry": "sylph", "size": "size_2_small", "feature": "sylph"},
    "grace_reava": {"ancestry": "nymph", "size": "size_2_small", "feature": "nymph"},
    "spai_si": {"ancestry": "elf", "size": "size_3_medium", "feature": "elf", "hair": "short_dark"},
    "haara": {"ancestry": "gnome", "size": "size_2_small", "feature": "gnome", "hair": "short_dark"},
    "hesus_christo": {"ancestry": "wyrmborn", "size": "size_4_large", "feature": "wyrmborn"},
    "unnamed_angel": {"ancestry": "angel", "status": "placeholder_unapproved"},
}


def champion_profiles() -> list[dict[str, Any]]:
    """Return canonicalized v2 champion presentation profiles."""
    profiles = deepcopy(V1_CHAMPIONS)
    for profile in profiles:
        profile.update(CHAMPION_OVERRIDES.get(profile["id"], {}))
        profile["feature"] = profile.get("feature") or RACES[profile["ancestry"]]["feature"]
        profile["status"] = profile.get("status", "integrated_candidate")
        if profile["id"] != "unnamed_angel":
            profile["status"] = "integrated_candidate"
    return profiles


DISTRICTS: tuple[dict[str, str], ...] = (
    {"id": "source_court", "name": "Source Court", "function": "arrival, onboarding and central attunement", "landmark": "Cosmic Wellspring"},
    {"id": "farflow_concourse", "name": "Farflow Concourse", "function": "host, join, teams, travel and expeditions", "landmark": "Farflow Gates"},
    {"id": "movement_gardens", "name": "Movement Gardens", "function": "movement training and traversal trials", "landmark": "Momentum Arbor"},
    {"id": "elemental_proving_grounds", "name": "Elemental Proving Grounds", "function": "aim, bots, destruction and chemistry", "landmark": "Eightfold Basins"},
    {"id": "living_archive", "name": "Living Archive", "function": "codex, lore, replays and analytics", "landmark": "Oracular Dome"},
    {"id": "restoration_grove", "name": "Restoration Grove", "function": "recovery, interaction and low-pressure crafting", "landmark": "Heartroot Garden"},
    {"id": "deep_foundry", "name": "Deep Foundry", "function": "fabrication and transmutation", "landmark": "Flux Crucible"},
    {"id": "starward_crown", "name": "Starward Crown", "function": "settings, accessibility and diagnostics", "landmark": "Twin Astrolabes"},
    {"id": "seasonal_reaches", "name": "Seasonal Reaches", "function": "biome pockets, events and private trials", "landmark": "Fourfold Orrery"},
)

MATERIALS = (
    "empty", "worldbone", "stone", "brick", "wood", "water", "oil",
    "fire", "steam", "ice", "rubble",
)

MATERIAL_STATES = (
    "base", "cracked", "damaged", "wet", "heated", "burning",
    "cooling", "frozen", "melting", "charged", "soot", "residue",
)

PROPS = (
    "door", "switch", "relay", "capacitor", "pump", "sluice", "furnace",
    "prism", "mirror", "lift", "crane", "trap", "portal", "movable_cover",
    "training_dummy", "target", "rail", "launch_surface", "grapple_anchor",
    "service_station",
)

PROP_STATES = (
    "idle", "focused", "disabled", "pending", "active", "success",
    "failure", "damaged", "blocked", "team_owned", "reset",
)

VFX_PHASES = (
    "startup", "cast", "travel", "field", "impact", "residue", "status",
    "reduced_motion",
)

UI_SURFACES = (
    "combat_hud", "champion_select", "race_select", "roster", "loadout",
    "profile", "appearance", "map", "wellspring_travel", "codex", "settings",
    "accessibility", "input_remap", "host_join", "teams", "readiness",
    "diagnostics", "pause", "save_quit", "offline_error",
)
