# H.E.X. race sprite production contract

Status: **STAGING / all new production coverage pending**, source snapshot 2026-09-27.
No new sprite, animated set, runtime replacement or human acceptance is claimed by this document.

## Authority and bounded scope

Repository: `C:/Users/sende/Projects/hex`, origin `https://github.com/generalgroovy/hex.git`.
The checkout is already dirty. Preserve every existing source, generated asset, import, reference,
test receipt and unrelated edit. This work owns only `docs/art/race-sprite-production-20260927/`.
The inventory worker makes no source/content/runtime changes, Godot imports/runs,
stat adjustments or live promotion. The lead owns the separate candidate lab and its validation.

Current source-derived authorities:

- Identity, supported races, body roles and explicit genders: `content/champions/champion_roster_plan_v1.json`.
- Playable names, IDs, wires and size: `content/champions/foundation_champions_v1.json`.
- Current rig: `assets/sprites/wireframe_motion_v2/manifest.json`,
  `src/presentation/wireframe_body_presenter.gd`, and the current dirty
  `src/presentation/cartoon_champion_presenter.gd` / `jump_presentation.gd`.
- Reference navigation: `reference/art/CURRENT-CHARACTER-REFERENCE.md`;
  current cast discussion: `docs/CURRENT-CAST.md`; authoring pipeline: `docs/SPRITE-PIPELINE.md`.
- `inventory.json` records source hashes, complete IDs, explicit unknowns, asset locations,
  inherited rig layout, 34 action/review cases and 189 individually pending production entries.

Historical docs headed FLUX are inherited references in this H.E.X. checkout, not proof of a FLUX
or H.E.X. runtime milestone. Revalidate changing files before production; never import a different checkout's roster.

## Scope and gender interpretation

There are **21 races x 3 sizes = 63 race-size pairs**. This contract stages three generic visual
presentations per pair: feminine, masculine and neutral, for **189 variants**.
Those presentations are art-design axes, not new gender identities or playable characters.
Neutral presentation does not mean an existing character is nonbinary.

The actual playable roster has **30 identities, ten per size**. Only six have explicit genders:
Wa Bidi, H. Lenee and Mifu are female; Spai Si, Juul I Yaina and Faab I Yaina are male.
The other 24 remain gender-unspecified, including Sai Laas and Grace Riva.
Do not infer identity gender from names, an old illustration, race or visual presentation.
Named-character production is tracked separately from generic 189-variant coverage.

| Canonical race ID | Current named identities and assigned size | Generic S/M/L x presentations |
| --- | --- | --- |
| human | Jan Wicked (`jan_wicked`, middle, gender unspecified) | 9 pending |
| dwarf | Biggy Bob (`biggy_bob`, middle, gender unspecified); Don Doko Don (`donnok`, middle, gender unspecified) | 9 pending |
| gnome | Waka Aren Si (`nico_lai`, small, gender unspecified) | 9 pending |
| hobbit | S. Wayne (`s_wayne`, small, gender unspecified) | 9 pending |
| elf | Hesus Christo (`hesus_christo`, middle, gender unspecified) | 9 pending |
| orc | Fluup (`fluup`, large, gender unspecified); Joh Haynes (`joh_haynes`, large, gender unspecified) | 9 pending |
| troll | Grimm Bow (`grimm_bow`, large, gender unspecified) | 9 pending |
| minotaur | Ba Djoh (`ba_djoh`, large, gender unspecified) | 9 pending |
| seakin | Oh Tipi (`oh_tipi`, middle, gender unspecified) | 9 pending |
| wyrmborn | Ha Rekt (`ha_rekt`, large, gender unspecified) | 9 pending |
| stoneborn | Dr. Apex (`dr_apex`, large, gender unspecified); Urzh (`urzh`, large, gender unspecified); H. Lenee (`h_le_ne`, middle, female) | 9 pending |
| treefolk | Treevor the Mason (`treevor_mason`, large, gender unspecified); Leaf the Hidden (`leaf_hidden`, middle, gender unspecified); Mifu (`fimu_yashiha`, small, female) | 9 pending |
| sylph | Grace Riva (`grace_reava`, small, gender unspecified) | 9 pending |
| undead | The Red Baron (`red_baron`, large, gender unspecified) | 9 pending |
| goblin | Wa Bidi (`wa_bidi`, small, female); Steezo (`steezo`, small, gender unspecified) | 9 pending |
| nymph | Haara (`haara`, small, gender unspecified); Sai Laas (`sai_laas`, small, gender unspecified) | 9 pending |
| spiderkin | Luuh I Zeh (`luuh_i_zeh`, small, gender unspecified) | 9 pending |
| vampire | Djonah Thaan (`djonah_thaan`, middle, gender unspecified) | 9 pending |
| demon | Spai Si (`spai_si`, middle, male); Juul I Yaina (`juul_i_yaina`, small, male) | 9 pending |
| angel | Faab I Yaina (`faab_i_yaina`, middle, male) | 9 pending |
| werewolf | Oll' I (`oll_i`, large, gender unspecified) | 9 pending |

No retired unnamed Angel is added. Preserve stable IDs `h_le_ne`, `fimu_yashiha`,
`nico_lai`, `donnok` and `grace_reava` despite updated display names.
The historical race-matrix directory `arachnoid` is a reference label for current `spiderkin`,
not an additional twenty-second race.

## Style and reference boundary

The user's selected **styleref1** is the requested style authority. The lead resolved and inspected
the extensionless PNG at `C:/Users/sende/Pictures/styleref1`, SHA256
`c0fb63c912718d64ca061ccd85817869ffc3348a3c81a910962df57066279fd4`.
The user's later `C:/Users/sende/Pictures/styleref1.png` attachment was verified
byte-identical on September27; it confirms rather than replaces this style input.
It is an older 18-cast parchment group; its weapons, effects and labels are not body/roster authority.
Follow its rendering grammar and material treatment, not printed old roster labels.
Do not replace it silently with another historical style board.

The checked-in label-free `reference/art/cast_proportions_v5/flux-current-cast-final.png`
is the current available 30-identity reference. Original Oh Tipi, H. Lenee/Mifu source portraits
and all 21 race-size-gender matrices remain available as secondary anatomy/identity references;
availability is not proof of accepted animation. The v5 current-reference document explicitly says
the group sheet is not an atlas. Historical H. Le-ne/Fimu Yashiha labels and old Fire affinities
do not override current H. Lenee/Mifu names or Mifu's Air affinity.

Preserve S. Wayne's dark skin, Biggy Bob's brown hair, Juul's curly dark hair,
Faab's bald head and documented H. Lenee/Mifu identity cues.
Use distinct race anatomy (fins, horns, bark, stone joints, folded auxiliary limbs,
anatomical wings) without treating them as new mechanical abilities.

Feminine/masculine/neutral variation is modest and non-sexualized: practical covered outfits,
face/hair/garment-cut differences and restrained silhouette changes. Preserve readable limbs,
consistent mass and established rig landmarks. No exaggerated sexual anatomy, nudity or
gender-coded stat/size assumptions. Race recognition must not rely only on palette swaps.

## Inherited rig and motion coverage

| Item | Required inheritance |
| --- | --- |
| Cell / feet pivot | 96 x 96 / (48, 84) |
| Size IDs | small, middle, large; no tiny/huge or new medium ID |
| Source heights | 58 / 68 / 76 px |
| Baked visible heights | 58 / 63 / 68 px |
| Facing order | S, SE, E, NE, N, NW, W, SW |
| Base rows | grounded, jump, cast, hit, walk, sprint, slide, roll, walk_b, sprint_b |
| Base coverage | 8 directions x 10 rows = 80 cells per variant |
| Walk bank | 8 travel x 8 aim x 8 phases = 512 cells |
| Sprint bank | Separate 8 x 8 x 8 bank = 512 cells |
| Complete inherited page set | 1,104 cells per variant; three pages |
| Full 189-variant authored coverage | 208,656 cells if fully baked; not a runtime residency proposal |

The current shared cast uses nine textures / 3,312 cells across three sizes; duplicating all
189 complete sets into simultaneous residency is not authorized or recommended. Uncompressed
RGBA for 208,656 96px cells alone is approximately 7.16 GiB, excluding other runtime costs.
A memory/residency plan and importer/presenter changes would be a separate integration task.
An attractive front-view or nine-model matrix is only a concept checkpoint.

Preserve fixed bones, feet registration, volume, camera projection, current timing and distinct
walk/sprint contacts. Body/pelvis/head follow aim together; travel controls leg motion,
including backpedal and side shuffle. No fake raster rotation to invent a new heading,
no drifting feet, per-frame body scaling, mirrored asymmetry errors or frozen repeated contact frames.

Retain every semantic mapping in the inventory: idle, walk, sprint, jump, double_jump, slide,
slide_jump, air_dodge, wave_dash, wall_kick, vault, superglide, launched, grappled, charging,
stunned, rooted, slowed, fast_fall, wall_skim, impact_recovery, roll, cast, cast_recovery,
attack_primary, defend, interact, taunt and defeated. These are 29 declared presentation
semantics; declaration is not a claim that all 29 are independently reachable player actions
or have dedicated animated clips.

Also explicitly review current live **jumpsquat, crouch, float, flight and wallrun** conditions.
Jumpsquat uses grounded silhouette plus anticipation; double jump inherits jump; flight/float
inherit airborne jump body; WALL_SKIM in the live eligible silhouette path uses sprint,
overriding the older semantic alias wall_skim -> slide. Do not blindly implement only the
historical alias table. Test rising, apex, falling, landing, wall attachment, directional transitions,
moving casts and interruptions as transitions, not as newly invented mechanics.
Only current sylph/wyrmborn/angel/demon profiles are flight-capable; wings in art never unlock flight.

Body pixels exclude weapons, magical foci, spell/projectile/VFX, aura, halo, ground shadow,
UI labels, backgrounds and scenery. Anatomical appendages must have reviewed attachment pivots
and near/far occlusion. Spell hands remain aligned with existing cast attachments.

## Fail-closed staging and review gates

1. Resolve and hash styleref1; pin source hashes and catalog snapshot. Stop on repository mismatch,
   conflicting identity evidence, missing reference, overlapping write ownership or source drift.
2. Stage one race at a time in a lead-assigned new directory. Start with a small bounded contact/
   direction pilot, then all three sizes/presentations. Preserve immutable generation originals.
3. Review genuine alpha and matte edges on light/dark grounds, native pixel size and nearest 2x/4x;
   inspect front/side/rear-quarter anatomy, unique silhouette, pivot/gutters and feet contact.
4. Complete every base cell, both full locomotion banks and all applicable live action/transition
   checks. Store exact prompts, source hashes, deterministic assembly/masks and defect lists.
   Do not use blanket background-color thresholds or overwrite source images.
   Explicit binary-alpha normalization of an already-transparent source is
   allowed when its threshold, source hash and reviewed crop bounds are recorded.
5. Separate GENERATED, STATIC_CHECKED, VISUALLY_REVIEWED, USER_ACCEPTED and RUNTIME_VERIFIED.
   A filled grid, source hash or headless test does not establish visual acceptance.
   Missing or ambiguous cases remain pending/failed and cannot promote.
6. Preserve current shared bodies until replacement quality and integration gates are met.
   The user authorized implementation; do not mistake that for visual approval of unseen results.
   Existing neutral-template human acceptance is still open. Partial anatomy and unresolved
   heading/pose defects must remain staged rather than silently replacing working characters.

No gameplay changes: retain stats, affinities, kits, wire IDs, movement timing, finite air budgets,
hurt radii 17/18/19 px, common wall clearance 18 px, hit registration and network behavior.
Historical docs mentioning 15/18/21 radii or five size bands are not current authority.

## Concise bounded delegation prompt

> In verified H.E.X. checkout C:/Users/sende/Projects/hex (origin generalgroovy/hex), produce only
> the lead-assigned race's staged sprites under your exclusive new output directory. Read this
> contract and inventory first. Use the lead-resolved/hash-locked styleref1 for visual style and
> current catalogs for identity; preserve originals and all unrelated dirty files. Stage Small,
> Middle and Large in feminine/masculine/neutral visual presentations without inventing named
> identity genders. Keep practical modest clothing, race-specific anatomy and documented
> character constraints. Inherit the fixed 96px cell, (48,84) pivot, 58/63/68 visible heights,
> eight headings, all 80 base cells, 512 walk and 512 sprint cells, independent travel/aim, and
> every applicable current semantic/transition including jumpsquat, double jump, flight and
> wallrun. No stats, hurtboxes, source/runtime files, Godot imports, registry changes or promotion.
> Begin with one bounded native-size pilot; report evidence and unresolved defects before
> scaling. Deliver prompts, immutable sources/hashes, assembly provenance, complete coverage
> ledger and light/dark/native/flipbook review. Fail closed on missing cells, drift, contact/yaw
> defects or ownership conflict. Generated concepts are not complete animated runtime sets.
> Budget memory: do not eagerly load the full approximately 7.16 GiB expanded set; preserve bounded
> residency and reuse accepted rig construction. Only the lead controls shared validation and any
> separately authorized integration.

## Recommended immediate sequence

Use the resolved styleref1 to stage a bounded generated raster-part pilot suitable for the existing
rig, then assemble and review one Small variant's eight-heading/contact proof and full motion
coverage under separate lead ownership. A design board may support review but cannot substitute
for that integration pilot. Advance to Middle/Large and the remaining families after pilot review.
Keep the 189-variant production ledger honest throughout; do not call a whole-race style board
all-race animation completion.

