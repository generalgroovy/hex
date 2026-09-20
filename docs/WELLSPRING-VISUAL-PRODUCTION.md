# The Wellspring visual-production catalog v2 (legacy inventory)

Status: **historical/migration visual inventory**.

This catalog is generated from deterministic source code and is directly usable by
Godot. Rendered pixels never define collision, damage, reach, chemistry or other
simulation authority.

Runtime status: this document preserves the older race/exemplar inventory for
migration and provenance only. The current runtime contract is defined by
`content/visual/foundation_champion_visuals_v1.json` and uses exactly three body
types: `small`, `middle`, and `large`; the body-only S. Wayne/Oh Tipi/Red Baron
V12 atlas is the active foundation candidate and is rebuilt in that
small-to-large template order. Nothing in this legacy catalog may add a fourth
body type or reintroduce baked spells, shadows, props or environment pixels.

## Production status

| Category | Planned | Complete | Candidate | Gated | Validation |
| --- | ---: | ---: | ---: | ---: | --- |
| Race size/presentation foundations | 210 | 210 | 0 | 0 | atlas, dimensions, keyframes, paths |
| Race exemplars | 21 | 21 | 21 | 0 | full package |
| Champion packages | 24 | 24 | 23 | 1 | full package |
| Wellspring districts | 9 | 9 | 9 | 0 | topology layers + preview |
| Elements | 8 | 8 | 0 | 0 | icon + eight phases × four frames |
| Materials | 11 | 11 | 0 | 0 | twelve visual states |
| Props | 20 | 20 | 0 | 0 | eleven interaction states |
| UI surfaces | 20 | 20 | 0 | 0 | 1080p/1440p/4K integer scale contract |

## Race and ancestry catalog

| ID | Name | Status | Legacy source sets | Presentations | Exemplar | Preview |
| --- | --- | --- | --- | --- | --- | --- |
| `human` | Human | production_foundation | 5 | 2 | `Aster Vale` | `res://assets/sprites/races_v2/human/human_size_gender_matrix.png` |
| `dwarf` | Dwarf | production_foundation | 5 | 2 | `Brun Forgehand` | `res://assets/sprites/races_v2/dwarf/dwarf_size_gender_matrix.png` |
| `gnome` | Gnome | production_foundation | 5 | 2 | `Pip Lumen` | `res://assets/sprites/races_v2/gnome/gnome_size_gender_matrix.png` |
| `hobbit` | Hobbit | production_foundation | 5 | 2 | `Mara Mossfoot` | `res://assets/sprites/races_v2/hobbit/hobbit_size_gender_matrix.png` |
| `elf` | Elf | production_foundation | 5 | 2 | `Cael Veyra` | `res://assets/sprites/races_v2/elf/elf_size_gender_matrix.png` |
| `orc` | Orc | production_foundation | 5 | 2 | `Rokka Flint` | `res://assets/sprites/races_v2/orc/orc_size_gender_matrix.png` |
| `troll` | Troll | production_foundation | 5 | 2 | `Murren Deepbow` | `res://assets/sprites/races_v2/troll/troll_size_gender_matrix.png` |
| `minotaur` | Minotaur | production_foundation | 5 | 2 | `Tor Varr` | `res://assets/sprites/races_v2/minotaur/minotaur_size_gender_matrix.png` |
| `seakin` | Seakin | production_foundation | 5 | 2 | `Neria Tidefin` | `res://assets/sprites/races_v2/seakin/seakin_size_gender_matrix.png` |
| `wyrmborn` | Wyrmborn | production_foundation | 5 | 2 | `Kaelith Embercrest` | `res://assets/sprites/races_v2/wyrmborn/wyrmborn_size_gender_matrix.png` |
| `stoneborn` | Stoneborn | production_foundation | 5 | 2 | `Orrun Slate` | `res://assets/sprites/races_v2/stoneborn/stoneborn_size_gender_matrix.png` |
| `treefolk` | Treefolk | production_foundation | 5 | 2 | `Willow Mason` | `res://assets/sprites/races_v2/treefolk/treefolk_size_gender_matrix.png` |
| `sylph` | Sylph | production_foundation | 5 | 2 | `Iri Gale` | `res://assets/sprites/races_v2/sylph/sylph_size_gender_matrix.png` |
| `undead` | Undead | production_foundation | 5 | 2 | `Morrow Ash` | `res://assets/sprites/races_v2/undead/undead_size_gender_matrix.png` |
| `goblin` | Goblin | production_foundation | 5 | 2 | `Zikka Spark` | `res://assets/sprites/races_v2/goblin/goblin_size_gender_matrix.png` |
| `nymph` | Nymph | production_foundation | 5 | 2 | `Luma Bloom` | `res://assets/sprites/races_v2/nymph/nymph_size_gender_matrix.png` |
| `arachnoid` | Arachnoid | production_foundation | 5 | 2 | `Silk Varra` | `res://assets/sprites/races_v2/arachnoid/arachnoid_size_gender_matrix.png` |
| `vampire` | Vampire | production_foundation | 5 | 2 | `Vesper Noct` | `res://assets/sprites/races_v2/vampire/vampire_size_gender_matrix.png` |
| `demon` | Demon | production_foundation | 5 | 2 | `Kara Vex` | `res://assets/sprites/races_v2/demon/demon_size_gender_matrix.png` |
| `angel` | Angel | production_foundation | 5 | 2 | `Aurelia Dawn` | `res://assets/sprites/races_v2/angel/angel_size_gender_matrix.png` |
| `werewolf` | Werewolf | production_foundation | 5 | 2 | `Fen Marr` | `res://assets/sprites/races_v2/werewolf/werewolf_size_gender_matrix.png` |

The legacy race inventory contains five historical source sets in masculine and
feminine presentations. They are retained for migration only: `tiny` maps to
`small`, `medium` maps to `middle`, and `huge` maps to `large`. New content,
selectors and runtime validators must use only the three canonical IDs.

## Champion and exemplar roster

| ID | Name | Race | Body type (migrated) | Affinities | Status | Atlas | Hero portrait |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `oh_tipi` | Oh Tipi | seakin | Middle | water, ice, charge | integrated_candidate | `res://assets/sprites/champions_v2/oh_tipi/atlas.png` | `res://assets/sprites/champions_v2/oh_tipi/hero_portrait_256.png` |
| `s_wayne` | S. Wayne | hobbit | Small | dark, light | integrated_candidate | `res://assets/sprites/champions_v2/s_wayne/atlas.png` | `res://assets/sprites/champions_v2/s_wayne/hero_portrait_256.png` |
| `red_baron` | The Red Baron | undead | Large | fire, ice | superseded_by_v9 | `res://assets/sprites/champions_v2/red_baron/atlas.png` | `res://assets/sprites/champions_v2/red_baron/hero_portrait_256.png` |
| `steezo` | Steezo | goblin | Small | fire, charge, light | integrated_candidate | `res://assets/sprites/champions_v2/steezo/atlas.png` | `res://assets/sprites/champions_v2/steezo/hero_portrait_256.png` |
| `treevor_mason` | Treevor the Mason | treefolk | Large | earth, wind, fire | integrated_candidate | `res://assets/sprites/champions_v2/treevor_mason/atlas.png` | `res://assets/sprites/champions_v2/treevor_mason/hero_portrait_256.png` |
| `oll_i` | Oll' I | minotaur | Large | earth, fire, light | integrated_candidate | `res://assets/sprites/champions_v2/oll_i/atlas.png` | `res://assets/sprites/champions_v2/oll_i/hero_portrait_256.png` |
| `fluup` | Fluup | orc | Large | charge, wind, ice | integrated_candidate | `res://assets/sprites/champions_v2/fluup/atlas.png` | `res://assets/sprites/champions_v2/fluup/hero_portrait_256.png` |
| `wa_bidi` | Wa Bidi | sylph | Small | charge, wind, fire | integrated_candidate | `res://assets/sprites/champions_v2/wa_bidi/atlas.png` | `res://assets/sprites/champions_v2/wa_bidi/hero_portrait_256.png` |
| `grace_reava` | Grace Reava | nymph | Small | wind, water, light | integrated_candidate | `res://assets/sprites/champions_v2/grace_reava/atlas.png` | `res://assets/sprites/champions_v2/grace_reava/hero_portrait_256.png` |
| `nico_lai` | Nico Lai | gnome | Small | charge, light | integrated_candidate | `res://assets/sprites/champions_v2/nico_lai/atlas.png` | `res://assets/sprites/champions_v2/nico_lai/hero_portrait_256.png` |
| `spai_si` | Spai Si | elf | Middle | wind, light, earth | integrated_candidate | `res://assets/sprites/champions_v2/spai_si/atlas.png` | `res://assets/sprites/champions_v2/spai_si/hero_portrait_256.png` |
| `leaf_hidden` | Leaf the Hidden | treefolk | Middle | water, earth, light | integrated_candidate | `res://assets/sprites/champions_v2/leaf_hidden/atlas.png` | `res://assets/sprites/champions_v2/leaf_hidden/hero_portrait_256.png` |
| `ha_rekt` | Ha Rekt | wyrmborn | Large | ice, wind, fire | integrated_candidate | `res://assets/sprites/champions_v2/ha_rekt/atlas.png` | `res://assets/sprites/champions_v2/ha_rekt/hero_portrait_256.png` |
| `dr_apex` | Dr. Apex | stoneborn | Large | earth, light, water | integrated_candidate | `res://assets/sprites/champions_v2/dr_apex/atlas.png` | `res://assets/sprites/champions_v2/dr_apex/hero_portrait_256.png` |
| `haara` | Haara | gnome | Small | light, wind, spirit | integrated_candidate | `res://assets/sprites/champions_v2/haara/atlas.png` | `res://assets/sprites/champions_v2/haara/hero_portrait_256.png` |
| `hesus_christo` | Hesus Christo | wyrmborn | Large | earth, water | integrated_candidate | `res://assets/sprites/champions_v2/hesus_christo/atlas.png` | `res://assets/sprites/champions_v2/hesus_christo/hero_portrait_256.png` |
| `grimm_bow` | Grimm Bow | troll | Large | dark, earth, water | integrated_candidate | `res://assets/sprites/champions_v2/grimm_bow/atlas.png` | `res://assets/sprites/champions_v2/grimm_bow/hero_portrait_256.png` |
| `biggy_bob` | Biggy Bob | dwarf | Middle | earth, fire, light | integrated_candidate | `res://assets/sprites/champions_v2/biggy_bob/atlas.png` | `res://assets/sprites/champions_v2/biggy_bob/hero_portrait_256.png` |
| `jan_wicked` | Jan Wicked | human | Middle | ice, dark, charge | integrated_candidate | `res://assets/sprites/champions_v2/jan_wicked/atlas.png` | `res://assets/sprites/champions_v2/jan_wicked/hero_portrait_256.png` |
| `ba_djoh` | Ba Djoh | minotaur | Large | earth, fire, water | integrated_candidate | `res://assets/sprites/champions_v2/ba_djoh/atlas.png` | `res://assets/sprites/champions_v2/ba_djoh/hero_portrait_256.png` |
| `urzh` | Urzh | stoneborn | Large | earth, fire, charge | integrated_candidate | `res://assets/sprites/champions_v2/urzh/atlas.png` | `res://assets/sprites/champions_v2/urzh/hero_portrait_256.png` |
| `donnok` | Donnok | dwarf | Middle | earth, fire, water | integrated_candidate | `res://assets/sprites/champions_v2/donnok/atlas.png` | `res://assets/sprites/champions_v2/donnok/hero_portrait_256.png` |
| `djonah_thaan` | Djonah Thaan | vampire | Middle | dark, charge, fire | integrated_candidate | `res://assets/sprites/champions_v2/djonah_thaan/atlas.png` | `res://assets/sprites/champions_v2/djonah_thaan/hero_portrait_256.png` |
| `unnamed_angel` | Unnamed Angel | angel | Middle | wind, light, spirit | placeholder_unapproved | `res://assets/sprites/champions_v2/unnamed_angel/atlas.png` | `res://assets/sprites/champions_v2/unnamed_angel/hero_portrait_256.png` |

## Animation keyframes

| Animation | Frames | FPS | Loop | Atlas block |
| --- | --- | --- | --- | --- |
| `idle` | 4 | 6 | True | [0, 0] |
| `walk` | 4 | 10 | True | [1, 0] |
| `sprint` | 6 | 14 | True | [2, 0] |
| `hop` | 4 | 12 | False | [3, 0] |
| `double_jump` | 4 | 14 | False | [4, 0] |
| `rise` | 2 | 10 | False | [0, 1] |
| `fall` | 2 | 10 | True | [1, 1] |
| `land` | 3 | 12 | False | [2, 1] |
| `wall_contact` | 2 | 8 | True | [3, 1] |
| `wall_kick` | 4 | 14 | False | [4, 1] |
| `air_dodge` | 4 | 16 | False | [0, 2] |
| `wavedash` | 4 | 16 | False | [1, 2] |
| `slide` | 4 | 14 | True | [2, 2] |
| `slide_jump` | 4 | 14 | False | [3, 2] |
| `vault` | 5 | 14 | False | [4, 2] |
| `superglide` | 5 | 16 | False | [0, 3] |
| `attack_primary` | 4 | 12 | False | [1, 3] |
| `cast` | 5 | 10 | False | [2, 3] |
| `defend` | 3 | 8 | False | [3, 3] |
| `hit` | 2 | 12 | False | [4, 3] |
| `stunned` | 3 | 6 | True | [0, 4] |
| `rooted` | 2 | 6 | True | [1, 4] |
| `defeated` | 4 | 8 | False | [2, 4] |
| `interact` | 3 | 8 | False | [3, 4] |
| `taunt` | 4 | 8 | False | [4, 4] |

All listed animations are present for all eight directions in every base-race,
race-exemplar and champion atlas.

## The Wellspring districts

| District | Function | Landmark | Ordinary route | Advanced route | Status | Layout |
| --- | --- | --- | --- | --- | --- | --- |
| Source Court | arrival, onboarding and central attunement | Cosmic Wellspring | source_ring | eightfold_fluxways | integrated_candidate | `res://content/maps/wellspring/districts/source_court_v2.json` |
| Farflow Concourse | host, join, teams, travel and expeditions | Farflow Gates | gate_ring | concourse_roofline | integrated_candidate | `res://content/maps/wellspring/districts/farflow_concourse_v2.json` |
| Movement Gardens | movement training and traversal trials | Momentum Arbor | ordinary_training_loop | wall_vault_superglide_loop | integrated_candidate | `res://content/maps/wellspring/districts/movement_gardens_v2.json` |
| Elemental Proving Grounds | aim, bots, destruction and chemistry | Eightfold Basins | basin_ring | reaction_rim | integrated_candidate | `res://content/maps/wellspring/districts/elemental_proving_grounds_v2.json` |
| Living Archive | codex, lore, replays and analytics | Oracular Dome | archive_walk | stack_vaults | integrated_candidate | `res://content/maps/wellspring/districts/living_archive_v2.json` |
| Restoration Grove | recovery, interaction and low-pressure crafting | Heartroot Garden | grove_walk | canopy_route | integrated_candidate | `res://content/maps/wellspring/districts/restoration_grove_v2.json` |
| Deep Foundry | fabrication and transmutation | Flux Crucible | foundry_floor | machine_line | integrated_candidate | `res://content/maps/wellspring/districts/deep_foundry_v2.json` |
| Starward Crown | settings, accessibility and diagnostics | Twin Astrolabes | crown_bridge | astrolabe_ring | integrated_candidate | `res://content/maps/wellspring/districts/starward_crown_v2.json` |
| Seasonal Reaches | biome pockets, events and private trials | Fourfold Orrery | seasonal_walk | changing_surface_route | integrated_candidate | `res://content/maps/wellspring/districts/seasonal_reaches_v2.json` |

The Wellspring is built around the Cosmic Wellspring: a vertical, eight-current
Flux cascade feeding the Source Basin and branching Fluxways. Each district is a
modular 80×45-tile package with visual, collision, worldbone, navigation and
elevation layers. Simulation systems remain authoritative when loaded in game.

## Elements

| Element | Icon | Startup | Cast | Travel | Field | Impact | Residue | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| earth | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| fire | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| water | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| wind | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| ice | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| charge | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| light | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| dark | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

## Materials

| Material | Base | Cracked | Damaged | Wet | Heated | Burning | Cooling | Frozen | Melting | Charged | Soot | Residue |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| empty | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| worldbone | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| stone | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| brick | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| wood | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| water | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| oil | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| fire | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| steam | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| ice | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| rubble | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

## Prop families

| Prop | States | Atlas | Status |
| --- | --- | --- | --- |
| door | 11 | ✓ | production_foundation |
| switch | 11 | ✓ | production_foundation |
| relay | 11 | ✓ | production_foundation |
| capacitor | 11 | ✓ | production_foundation |
| pump | 11 | ✓ | production_foundation |
| sluice | 11 | ✓ | production_foundation |
| furnace | 11 | ✓ | production_foundation |
| prism | 11 | ✓ | production_foundation |
| mirror | 11 | ✓ | production_foundation |
| lift | 11 | ✓ | production_foundation |
| crane | 11 | ✓ | production_foundation |
| trap | 11 | ✓ | production_foundation |
| portal | 11 | ✓ | production_foundation |
| movable_cover | 11 | ✓ | production_foundation |
| training_dummy | 11 | ✓ | production_foundation |
| target | 11 | ✓ | production_foundation |
| rail | 11 | ✓ | production_foundation |
| launch_surface | 11 | ✓ | production_foundation |
| grapple_anchor | 11 | ✓ | production_foundation |
| service_station | 11 | ✓ | production_foundation |

## UI surfaces

| Surface | Virtual size | Input | Accessibility | Status |
| --- | --- | --- | --- | --- |
| combat_hud | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| champion_select | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| race_select | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| roster | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| loadout | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| profile | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| appearance | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| map | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| wellspring_travel | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| codex | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| settings | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| accessibility | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| input_remap | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| host_join | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| teams | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| readiness | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| diagnostics | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| pause | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| save_quit | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |
| offline_error | 640×360 virtual | keyboard/mouse/controller | shape + value + color | production_foundation |

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
