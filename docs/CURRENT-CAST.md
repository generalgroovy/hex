# FLUX current cast contract

Status: September14,2026 local source candidate; **30 playable characters,30 identities,no placeholders**.
There are ten Small,ten Middle and ten Large profiles. The unnamed Angel is
retired from current catalogs; Faab I Yaina remains the named playable Angel.
Historic artwork is preserved, not exposed as another selectable character.

## Style and runtime boundary

![Current cast without names or effects](../reference/art/cast_proportions_v5/flux-current-cast-final.png)

The [new reference](../reference/art/cast_proportions_v5/README.md) owns the compact,
sturdy fantasy target: approximately4–4.5 heads tall, short necks, readable limbs,
practical clothing, empty-hand casting. S. Wayne stays dark-skinned; Biggy Bob
brown-haired. Spell effects, auras, shadows and scenery never become body pixels.

All characters currently use the matching **shared body**, including in the
Gallery and front-model top-third portrait. The new group illustration does not
constitute30 unique in-game skins. Named/race skins remain after shared-template
playback and human acceptance. Five retained individual source sets and previous
override pages are historical; they are not silently loaded in this mode.

The shared rig preserves fixed limb lengths,96px cells,pivot(48,84),eight facing
directions and separate travel/aim with eight cyclic walk and sprint phases.
Nine textures contain3312 cells for the entire cast. Source authoring heights
58/68/76px remain separate from visible58/63/68px. Constant per-size baking,
not per-frame fitting, preserves scale during actions. Hurtboxes depend only on
size, not race, skin, aiming direction or animation. All sizes have18px wall clearance.

The current slide_v1 review candidate changes only the24 shared slide cells with
a fixed-bone seated/reclining pose. Standing proportions and all gait pixels stay
unchanged. See the current checkpoint for before/after evidence and remaining
North/NE, wallrun and transition limits. This is not full human template approval.

## Current roster

Affinities spend three points across two or three first-eight elements; these
levels do not automatically multiply damage or grant racial passives. Air keeps
the internal ID `wind`. Alphabetically sorted race columns group the Gallery;
hover/selection previews show source-derived details and eight facing steps.

| Champion | Race | Body | Affinity levels | Live art |
| --- | --- | --- | --- | --- |
| Oh Tipi | Seakin | Middle | Water 2 · Charge 1 | Shared middle body |
| S. Wayne | Hobbit | Small | Dark 2 · Light 1 | Shared small body |
| The Red Baron | Undead | Large | Fire 2 · Ice 1 | Shared large body |
| Grace Riva | Sylph | Small | Air 1 · Water 1 · Light 1 | Shared small body |
| Wa Bidi | Goblin | Small | Charge 1 · Air 1 · Fire 1 | Shared small body |
| Steezo | Goblin | Small | Charge 1 · Fire 1 · Light 1 | Shared small body |
| Treevor the Mason | Treefolk | Large | Earth 1 · Air 1 · Fire 1 | Shared large body |
| Oll' I | Werewolf | Large | Earth 1 · Fire 1 · Light 1 | Shared large body |
| Fluup | Orc | Large | Air 1 · Charge 1 · Ice 1 | Shared large body |
| Waka Aren Si | Gnome | Small | Charge 2 · Light 1 | Shared small body |
| Spai Si | Demon | Middle | Air 1 · Earth 1 · Light 1 | Shared middle body |
| Leaf the Hidden | Treefolk | Middle | Water 1 · Earth 1 · Light 1 | Shared middle body |
| Ha Rekt | Wyrmborn | Large | Ice 1 · Air 1 · Fire 1 | Shared large body |
| Dr. Apex | Stoneborn | Large | Earth 1 · Light 1 · Water 1 | Shared large body |
| Haara | Nymph | Small | Light 2 · Air 1 | Shared small body |
| Hesus Christo | Elf | Middle | Earth 2 · Water 1 | Shared middle body |
| Grimm Bow | Troll | Large | Earth 2 · Water 1 | Shared large body |
| Biggy Bob | Dwarf | Middle | Earth 1 · Fire 1 · Light 1 | Shared middle body |
| Jan Wicked | Human | Middle | Ice 1 · Dark 1 · Charge 1 | Shared middle body |
| Ba Djoh | Minotaur | Large | Earth 1 · Fire 1 · Water 1 | Shared large body |
| Urzh | Stoneborn | Large | Earth 1 · Fire 1 · Charge 1 | Shared large body |
| Don Doko Don | Dwarf | Middle | Earth 1 · Fire 1 · Water 1 | Shared middle body |
| Djonah Thaan | Vampire | Middle | Dark 1 · Charge 1 · Fire 1 | Shared middle body |
| Luuh I Zeh | Spiderkin | Small | Dark 2 · Water 1 | Shared small body |
| Juul I Yaina | Demon | Small | Ice 2 · Air 1 | Shared small body |
| Faab I Yaina | Angel | Middle | Fire 2 · Light 1 | Shared middle body |
| Joh Haynes | Orc | Large | Earth 2 · Charge 1 | Shared large body |
| H. Lenee | Stoneborn | Middle | Earth 1 · Air 1 · Fire 1 | Shared middle body |
| Mifu | Treefolk | Small | Water 1 · Air 1 · Light 1 | Shared small body |
| Sai Laas | Nymph | Small | Air 2 · Fire 1 | Shared small body |

H. Lenee retains `h_le_ne`/wire28 (female Stoneborn,Middle), while Mifu retains
`fimu_yashiha`/wire29 (female Treefolk,Small). Mifu's Fire is replaced by Air and
her starter Spray becomes Squall. H. Lenee already has Air and retains Earth/Air/Fire.
Sai Laas uses `sai_laas`/wire30: Small Nymph,Air2/Fire1,gender unspecified.
Small and the2/1 split are conservative defaults within the existing three-point rule.

Juul I Yaina is a male Demon with curly dark hair; Faab I Yaina is a bald male
Angel; Spai Si is male; Wa Bidi female. Stable technical IDs `grace_reava`,
`nico_lai` and `donnok` retain their current player-facing names.
The old H. Le-ne/Fimu Yashiha portrait labels and removed placeholder are historical
reference content, not current roster authority.

## Size baselines

| Body | Count | Visible height | Hurt radius | Health | Flux | Stamina | Baseline recovery/s | Speed |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Small (S. Wayne) | 10 | 58px | 17px | 90 | 123.2 | 620 | 28 | 1.06× |
| Middle (Oh Tipi) | 10 | 63px | 18px | 108 | 114.4 | 660 | 30 | 0.98× |
| Large (Red Baron) | 10 | 68px | 19px | 132 | 105.6 | 700 | 32 | 0.91× |

All members of a size share its stamina maximum and hurt radius. Existing health,
Flux,speed,recovery and finite movement/protection timings are preserved.
Small Grace Riva and Wa Bidi retain their distinct29/32 stamina recovery per second.
Small/Large stamina differs from Middle by approximately6%; hurt radius by5.6%;
visual height by7.9%. These are candidate tuning values,not proof of competitive balance.

## Spells and selection

32 spells are available: eight elements × Bolt/Heavy/Rapid/Spray, freely configurable
into12 positions at the Spell Loom, regardless of character. New starter kits use
existing Bolt/Heavy plus another-affinity Spray; Sai uses Gale Needle/Pressure Shell/
Ember Sweep. Disabled historical families are not available through new kits.

Host-confirmed character switching preserves resource percentages but replaces the
starter loadout; the Gallery warns about this. Selecting the current character is
a no-op preserving custom spells,cooldowns and accounting. Attunement requires the
Gallery in Wellspring/HEARTH and a living grounded free actor without an active
cast,movement commitment,protection or impact recovery.

## Acceptance and next production step

Fresh results belong to [the proportion/roster checkpoint](PROPORTION-CAST-CHECKPOINT.md).
Historical test totals and old portable builds are not verification of the new source.

| Layer | Boundary |
| --- | --- |
| Identity/affinity/size | 30 source-linked profiles; no new racial abilities |
| Shared animation |3312 generated cells,8 directions,independent travel/aim; runtime and visual evidence reported separately |
| Character-specific detail | Group reference supplied; individual30-skin production not completed |
| Human acceptance | Proportions,motion readability and relative size feel awaiting playtest |
| Next | Review Small,then Middle,then Large in gameplay; retain registered actions,then complete race/character layers one at a time |

Earlier construction and named-art history remain in
[character template](CHARACTER-TEMPLATE-V2-CHECKPOINT.md),
[character pages](CHARACTER-PAGES-CHECKPOINT.md) and
[Gallery](CAST-GALLERY-CHECKPOINT.md) checkpoints. Do not promote a portrait or
cutout as a complete animation set. Preserve original source artwork and require
reviewed pose/contact coverage before replacing shared bodies.
