# H.E.X. — Help, Everything eXploded!

Status: **current source p60-be3efd332e1a**, with the October 10, 2026 gameplay/performance qualification and October 11 source-publication cleanup. Dense overlapping fields still miss the 60 FPS budget. See the [implementation and measurements](docs/performance-implementation-20261010.md).

A movement-led elemental combat sandbox in Godot. Move and aim independently,
build a twelve-slot spell weave, combine finite elemental effects, and learn a
rival's signature by defeating them. Start with a short optional introduction,
then experiment in a Range that can lend every spell. Explore seven Wellspring
districts and use the compact world map to travel between thirteen named places.

[Player guide](docs/PLAYER-GUIDE.md) · [Documentation map](docs/README.md) ·
[Design contract](SPECIFICATION.md) · [Qualification and known limits](docs/performance-implementation-20261010.md)

## Install or play on Windows

This Git repository contains the game source, required art, tests and qualification
evidence. Exported EXE/PCK/ZIP files and local profiles are excluded from Git;
cloning the repository does not download a prebuilt portable.

To run a checkout, install **PowerShell 7.2 or later** and the pinned
**Godot 4.7.1 stable Windows runtime**. Open PowerShell in the repository and point
the helper at your downloaded executable:

```powershell
$env:FLUX2_GODOT_BIN = 'C:\path\to\Godot_v4.7.1-stable_win64.exe'
.\hex.cmd doctor
.\hex.cmd play --fullbody-art --pixel-cast
```

The helper checks the exact engine identity, `4.7.1.stable.official.a13da4feb`.
The first source launch imports the art and can take several minutes; it shows
progress and reuses the prepared resources on later launches.
For an independent portable, install matching Windows export templates and run
`.\hex.cmd package -PixelCast`. Each run creates a fresh folder under `exports/`.
See [development and verification](docs/DEVELOPMENT.md) for checks and packaging.

The locally qualified October 10 portable is preserved at
`exports/hex-smooth-fields-20261010/windows/PLAY-HEX.cmd`; its ZIP is
`exports/hex-smooth-fields-20261010/HEX-p60-be3efd332e1a-Windows-x64.zip`
(153.5 MiB). These are local artifact paths, not GitHub download links. Earlier
d649 performance, October 9 expansion and p59 animation builds remain local
fallbacks with their original evidence.

The portable needs no Git, Godot installation or administrator permission.
Keep `hex.exe` and `hex.pck` together. The launcher enables the reviewed pixel
presentation; opening the EXE directly retains skeleton mode. Use **1280×720**
for comfortable supporting text. Menus also fit **960×540**, where small text
and fine glyphs remain compact.

Extract each version into its own folder. Saved controls and personal weaves
use the compatible `Godot/app_userdata/FLUX 2` location. Older elemental weaves
receive a slot-by-slot migration preview; Apply preserves the original-file
backup, while inspection or cancellation does not replace saved data.

## Start with five minutes

1. Choose **Introduction / F5**. Move, release a prepared jump, pay for a cast,
   watch Flux recover, then try a mixture. **Skip guide / F5** ends it at any time.
   Lessons observe your actions; they never move, cast or equip for you.
2. Open **Spell Range / F6**. Start with a single element, then a pair. Read the
   ingredients, cost, timing, on-hit status, field effect and counter. Equip a
   temporary loaner in slot 1 and cast it yourself. Reset/refill tools are explicit.
3. Use **Menu → World map** to reach the Academy, then open **Spell Loom** at its
   door to build your own twelve-position weave.
   Combine ingredient filters; **More Forms** reveals the four additional
   deliveries. Read Swap/Replace before confirming, or drag a card onto a slot.
4. Open **Signature Challenges / Shift+F6**. Read the rival's spell and counter,
   then defeat them through normal combat to learn it. **Esc / controller Back**
   returns; the challenge card keeps the other useful shortcuts visible.
5. Visit **Menu → World map → Element Garden** to walk all 63 ground exhibits.
   The six single-element plots alternate raw matter and matching-source reactions;
   use the Range for full-footprint combat tests. Use **F4 / Compendium** for movement chains and all 63 chemistry outcomes.
   The paid chemistry demos provide a retained result/counter card for a manual retry.

![Range explains an all-six Mantle before it is equipped](docs/element-expansion-evidence-20261009/native/03-range-six-element-mantle-1280x720.png)

## What is playable

Current source: 30 playable profiles, 504 spells.

| System | Current game |
|---|---|
| Movement | Sprint, carve/brake a slide, gather/release jumps, roll, air-dodge, wallrun and chain paid techniques while aiming independently |
| Characters | 30 profiles, three body sizes, 21 ancestry passives and 30 personal passives through existing controls; flying ancestries use a deliberate second airborne Jump to start finite flight |
| Ingredients | Water with Ice effects, Fire with Charge effects, Air, Earth, Light and Dark |
| Spells | 63 nonempty ingredient sets × eight deliveries = **504 spells**; twelve equipped positions, four buttons across normal/Ctrl/Alt layers |
| Deliveries | Bolt, Heavy, Rapid, Spray, **Mantle** contact/trail, **Fuse** delayed area blast, **Split** bounded branches and **Rebound** wall banks |
| Statuses | Fractured Focus, Burning, Chilled, Gusted, Revealed and Withered; finite duration, explicit hit admission and bounded refresh |
| Chemistry | 63 bounded reactions, each named and finite, covering self-pairs and every distinct combination from two through six elements; situational effects and counters |
| Practice and progression | Optional introduction, all-spell Range, 30 earned rival signatures and clearly marked offline Developer tools |
| World | Seven Wellspring districts with **59,466 eligible chemistry cells**; familiar services and practice courts plus Tideglass Quays, Verdant Reaches, Basalt Foundry and Starward Terraces |
| Navigation | One compact Menu, a world overview, current location and thirteen named travel destinations; offline free-exploration travel preserves resources, cooldowns and weave |
| Element Garden | 63 physical plots in Tideglass show six raw materials plus all 63 finite reaction identities; harmless bounded loops with nearby explanations, while player spells remain live |
| Presentation | Slower held poses, tucked non-flying jumps, clearer wall contact and protection, elevated spell/character cues, terrain contact and shadows |
| Engine | 120 Hz authoritative simulation; 60 Hz transport snapshots; configured cadence, not measured performance |

All 30 sandbox characters are already available. Thirty particular signature
spells require clean rival victories; the Range can borrow them first. The
original 24 spell identities and saved twelve-slot positions remain stable.

Extra ingredients increase Flux cost and shorten status duration. They do not
multiply direct damage or material. Mixed terminals can form their named field;
a singleton self-reaction needs another matching paid source. Mantle is an
attack, not armor; Fuse's landed warning is harmless until its real detonation.
The Range explains these differences at selection time.

## Default controls

Saved custom bindings take priority. **Controls** shows keyboard/controller
equivalents and supports rebinding, sound, Reduced Effects/Motion and an aim arrow.
**Menu → Performance** selects Low/Standard visual detail and
a 60/120/unlimited frame limit. Low and 60 FPS are the defaults; movement and
spell simulation remain at 120 Hz. Reduced-motion accessibility is separate.

| Action | Keyboard / mouse |
|---|---|
| Move / aim | WASD / mouse |
| Sprint / slide | Shift / C |
| Jump | Space: press to gather, release to launch |
| Evade / technique | B / V; the action depends on grounded/airborne state |
| Spell positions | 1–4, Ctrl+1–4, Alt+1–4 |
| Service interaction | F at the door |
| Menu / world map | Esc / controller Back / click Menu; M opens the map |
| Compendium | F4 or Menu → Compendium; its Map action uses M / L3 |
| Introduction / skip | F5 or its visible menu action |
| Spell Range / Signature Challenges | F6 / Shift+F6 |
| Developer tools | Shift+F5; offline session only |

Saved gameplay bindings retain priority over Esc/M and F5/F6 convenience keys.
Menu shows the relevant activities; in the Range it includes Spell Loom,
Characters, Reset practice court and Return to Wellspring. Selecting a map pin
only highlights it; **Travel / Enter / A** confirms. Travel is unavailable during
rounds, challenges, isolated practice or active combat actions; its reason stays
inside the map. Controller Start keeps its existing emote action. During a
challenge the Menu button hides and Esc retains its exit behavior. Menus consume
navigation input without casting.

Developer mode offers all-spell access, protection, infinite resources,
cooldown resets and rival-input control. Overrides remain visibly marked and
never grant earned progress. Entering Developer mode makes that challenge
attempt ineligible for rewards even if the mode is switched off before victory.
Temporary Range/Developer weaves do not overwrite the player's saved weave.

## Evidence, design and limits

The final build's [Full v5 gate](docs/performance-qualification-20261010/full-v5.json)
passed **244 suites / 6,880,581 assertions**, with zero failures and zero
stderr. The final field-rendering pass matched **614 exact RGBA comparisons**,
including actual paid overlapping fields and retained glow. Earlier material/HUD
and complete 469-cell Range comparisons retain their separate 541-case evidence.
The compact Performance menu was inspected at 1280×720 and 960×540. The final
portable passed native launch/safe close, exact ZIP membership and hashes, and
all **132 terrain chunks plus the overview** decoded exactly from its PCK.

Visible release measurements on this Ryzen 3 7320U/Radeon PC, at 1280×720 with
Low detail and a 60 FPS limit, recorded the following engine-FPS observations:

| Workload | October 9 portable mean | Final portable mean | Final observed range |
|---|---:|---:|---:|
| Hearth | 24.57 FPS | 57.64 FPS | 46–60 FPS |
| Element Garden entry | 2.75 FPS | 59.00 FPS | 56–61 FPS |
| Twelve nearby paid Fire Bolts | Not measured in this comparison | 49.13 FPS | 21–60 FPS |
| Twelve paid all-six Mantles | Not measured in this comparison | 38.71 FPS | 36–50 FPS |

These sequential runs include every one-second engine observation, finite casting
and subsequent idle time. Durations and background load differ; the table is not
a controlled speedup ratio, sustained-battle average or physical frame-present
trace. The [performance report](docs/performance-implementation-20261010.md)
records the raw evidence, native frame-time tails, package checks and limits.

The preceding October 9 expansion has its own historical qualification:
237 suites / 6,615,478 assertions, an integrated teaching journey with
125 checkpoints, a map journey with 6,766 checkpoints and 96 reviewed native
images. Those are retained as [expansion history](docs/element-expansion-evidence-20261009/integration.md),
not presented as new captures of the performance build. Full tests use a
bounded suite watchdog; test duration does not establish a gameplay frame budget.

Three specialist agents and the integration owner reviewed one another's work.
The [decision records](docs/element-expansion-evidence-20261009/integration.md#ownership-and-independent-review)
connect the implementation to Magicka/Noita composition, Mega Man signature
learning, Capcom practice modes, movement-shooter controls and readable action
presentation. They distinguish established examples from H.E.X. tuning hypotheses.
The [map design and review record](docs/large-wellspring-evidence-20261009/map-overview.md)
connects named destinations and explicit travel to established map navigation,
while preserving the limits of scripted native evidence.

- **Balance and feel need human playtesting.** Coverage and finite budgets do not establish equal competitive viability across every combination or character.
- **Wayfinding needs human playtesting.** Native maps, arrival checks and scripted walks do not establish that all seven districts are interesting or easy to learn.
- **The simulation is 2D with depth presentation.** Thirty identities have held action keys, not complete authored animation cycles for every action.
- **Heavy fields still miss 60 FPS.** In the final instrumented native test, all-six Mantle averaged 28.17 ms between process starts on Low, with a 36.25 ms p95. At 150 visible region records, nearby Fire still averaged about 38 ms. The report distinguishes these intervals from actual portable FPS and physical presentation; the 120 Hz simulation contract is unchanged.
- **Startup and travel still prepare assets.** Final native startup took about 5.54 seconds and Garden travel contained 140–177 ms frame intervals. Terrain is baked and streamed within explicit budgets; warm-play measurements exclude cold preparation.
- **Multiplayer is experimental.** Everyone must use the same exact build. Eight players is a configured cap, not dense-capacity certification; physical two-PC and different-home acceptance remain open. Internet relay is not deployed.
- **Delivery is local and unsigned.** No public release, new installer or automatic updater was created.

## Development and documentation

The ability catalog retains **542 validated effective records; 504 have runtime wire IDs**.
The other records preserve disabled historical definitions. The champion catalog
has **30 playable entries; 30 identities**; presentation residency does not reduce
the playable roster.

Use the pinned **Godot 4.7.1** runtime from the actual repository root:

```powershell
.\hex.cmd doctor
.\hex.cmd play --fullbody-art --pixel-cast
.\hex.cmd check
.\hex.cmd test -Tier Full
```

[Specification](SPECIFICATION.md) owns current rules, [the player guide](docs/PLAYER-GUIDE.md)
owns teaching, [the resume](.agent/HEX-RESUME.md) owns exact source/package state,
and [the implementation record](.agent/OVERHAUL-IMPLEMENTATION.md) records this
completed batch and separate product-acceptance boundaries.
[The playtest route](docs/HEX-PLAYTEST.md) covers physical input, movement,
counterplay and experimental host/join use. [All 30 portraits](reference/art/portraits_20261008/index.html)
remain available offline.

The [source-publication record](docs/source-publication-20261011/README.md)
describes the retained source, removed redundant files, exact-byte evidence rules
and checkout validation. Git history identifies the publication commit;
the runtime identity above identifies the game independently of documentation edits.

Superseded element contracts and continuation plans now point to the current
documents and retain exact historical copies. Preserve dirty work, original art,
profiles, failed receipts and working packages. The historical FLUX delivery
pointer below is unchanged and does not select this H.E.X. playtest.

<details>
<summary>Historical delivery-pointer metadata — not the current playable build</summary>

The old pointer is unchanged. Its FLUX p48 payloads are unavailable in this
checkout; recorded paths below are archival text, not working launch links.

```text
<!-- BEGIN CURRENT BUILD SUMMARY: generated by scripts/current-build-summary.ps1 -->
**Pointer-selected delivery metadata ([descriptor](docs/current-checkpoint.json), not fresh availability):** `overnight-p48-20260913`.
Recorded paths (not verified download links): game `exports/windows-overnight-p48-20260913/windows/flux2.exe`; pack `exports/windows-overnight-p48-20260913/windows/flux2.pck`; portable `exports/windows-overnight-p48-20260913/release/FLUX2-Windows-x86_64.zip`. Use the verified playtest link at the top of this README.
Pinned PCK SHA-256: `ddce9451e871096ca02190deb9092cba71db96bd8d732cd2181fd7c5cd452083`
Pinned ZIP SHA-256: `5e49c599f026453917e3eb8201456e86089e9fe0d794efe3b9bcebe1385c041f`
Pointer boundaries: publication `not_published`; human acceptance `pending`; physical two-PC acceptance `pending`; sustained rendered 120 FPS `not_certified`; current installer `not_attempted_prior_policy_block`.
This generated summary validates pointer metadata only; it does not read or hash local payloads or repeat runtime acceptance. For exact local byte and receipt checks, run `pwsh -NoProfile -File scripts/current-checkpoint.ps1 -ReportOnly`.
<!-- END CURRENT BUILD SUMMARY -->
```

</details>
