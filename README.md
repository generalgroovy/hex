# H.E.X. — Help, Everything eXploded!

Status: **active improvement pass; clean Windows Full passed; Rival Circuit source candidate is not packaged or promoted.**
Status updated **October 16, 2026**.
Stop before 20,000 credits remain.
The [product assessment](docs/BREAKTHROUGH-ASSESSMENT-20261015.md) prioritizes a
coherent rival → earned spell → next fight loop. Candidate work on
`codex/hex-breakthrough-20261015` adds an optional three-rival Circuit, explicit
temporary learned-spell reuse, a compact-map control fix and launcher observer
selection. Candidate source does not replace the qualified portable automatically.
Candidate **p61-6618873387e2** passed [clean Windows CI Full 38817305452](https://github.com/generalgroovy/hex/actions/runs/38817305452)
at pushed commit **932f5974fe17a8d2432d8f82873eb86faf564543**: **267 suites /
7,576,123 assertions / zero failures**, all three stderr files empty, and a
correct **120 Hz boot**. The [independent CI review](docs/breakthrough-evidence-20261015/ci-full-38817305452/independent-review.json)
reconciles the complete source validation. This candidate has **not been packaged
or promoted**; desktop Play remains on qualified d6d1.
The earlier local [Full-a](docs/breakthrough-evidence-20261015/full-a/tests.json)
remains failed: 112 of 267 suites completed, 5,280,932 assertions and nine failures,
then a 2,700-second timeout; 155 suites did not complete and boot did not run.
Three test-only follow-ups were applied; seven-suite `focused-review-a` passed
**65,133 assertions, zero failures/stderr**, in **264,217 ms**. Local outage
diagnostics A/B passed **6,478 / 0** and **6,465 / 0**, each with 241 trace rows.
Neither those reruns nor the later CI pass establish the historical capture
failure's cause or retroactively pass local Full-a. See the [candidate evidence](docs/breakthrough-evidence-20261015/README.md).
The [cross-reviewed overhaul proposal](docs/OVERHAUL-DESIGN-20261015.md) targets
the selected illustrated 2.5D animated-sprite direction, clear spell areas,
tall enterable architecture, compact learning and measured optimization.
It is a design deliverable; its runtime changes are not implemented.

**Restoring the published Linux handoff:** clone or pull `codex/hex-screen-smoothness-20261011`, then
read the [Linux CLI handoff](.agent/LINUX-HANDOFF.md). It contains the restore
commands, current state, validation limits and receiving prompt. The complete
checkpoint is carried by Git; the older ZIP overlay is no longer needed. Windows
product work has since resumed on the separate candidate branch named above.

The qualified local portable remains **p61-d6d1bfb9c529**. It includes the reviewed
stationary movement optimization and the preceding depth/clarity improvements:
six wall treatments, taller masonry facades on two existing buildings,
independent camera look-ahead, Range status observations and earned-spell guidance.
The [qualified checkpoint](docs/performance-evidence-20261014/stationary-qualification-d6d1/README.md) records this delivery;
the [depth and clarity record](docs/depth-clarity-20261013.md) retains the prior batch.

[Full validation](docs/performance-evidence-20261014/stationary-qualification-d6d1/full/tests.json) passed **265 suites /
7,574,524 assertions**, with zero failures/error output and a 120 Hz boot.
Package, all 18 portable checks, 133 exact terrain images and five supervised
normal-close/reopen cases passed. The [delivery review](docs/performance-evidence-20261014/stationary-qualification-d6d1/delivery-review/review.json)
passed **4,076 checks** linking exact source and package bytes.
**p61-64590c45c7a5** is the immediate fallback; 7804 and older builds remain preserved.
`main` is unchanged.

**Current-build foreground performance and portable FPS remain unmeasured.**
The [previous-build 6459 source performance review](docs/performance-evidence-20261014/foreground-6459-b/review.json)
retains Profile B: warm Garden/sustained Fire/Mantle engine interval mean / p95
**62.105 / 73.910, 92.595 / 117.084, 87.840 / 110.507 ms**. Those full-observer
source results belong to 6459, not this build. Host memory pressure and observer
cost remain limits; no causal cross-build speedup or smooth 60 FPS is established.
The [earlier setup attempt](docs/performance-evidence-20261014/foreground-setup-a/review.json)
expired before Start and measured no gameplay.

[Casting-stage measurements](docs/performance-evidence-20261014/casting-stage-attribution/README.md)
identified ordinary actor movement as the largest measured child during short
Fire and all-six casts. The [retained stationary optimization](docs/performance-evidence-20261014/stationary-ground/README.md)
passed four native comparisons, saving roughly 6–11% of isolated whole-step time
in those stationary scenarios; this is not a gameplay FPS gain. It is now qualified
in the current delivery. The [Garden marker-budget trial](docs/performance-evidence-20261014/garden-sample-budget/README.md)
and [Low-detail overlapping-Fire decoration trial](docs/performance-evidence-20261014/conflagration-decoration-coalescing/README.md)
were withdrawn after failing their cost gates. Neither renderer change was applied.

The [single queue](.agent/OVERHAUL-IMPLEMENTATION.md) separates delivered depth,
clarity and maintenance capabilities from the next ranked product and acceptance
gates, with an implementer and independent reviewer for each point. The [resume handoff](.agent/HEX-RESUME.md) records the current delivery;
the [closed iteration record](docs/iteration-20261013/README.md) retains earlier
completed, withdrawn and deferred work. User saves, original art, older working
builds and useful failed evidence remain preserved.

A movement-led elemental combat sandbox in Godot. Move and aim independently,
build a twelve-slot spell weave, combine finite elemental effects, and learn a
rival's signature by defeating them. Start with a short optional introduction,
then experiment in a Range that can lend every spell. Explore seven Wellspring
districts and use the compact world map to travel between thirteen named places.

[Player guide](docs/PLAYER-GUIDE.md) · [Design goals and implementation state](docs/CORE-GAME-DESIGN.md) ·
[Design contract](SPECIFICATION.md) · [Current checks and remaining work](.agent/OVERHAUL-IMPLEMENTATION.md) ·
[Documentation map](docs/README.md)

## Install or play on Windows

On this PC, use the **H.E.X. desktop shortcut** for all player sessions. Its
stable launcher is `C:/Users/sende/Documents/ChatGPT/H.E.X/PLAY-HEX.cmd` and selects
the qualified portable. Source testing uses the repository tools below; candidate
source is not automatically substituted for the qualified play build.

To inspect the **source candidate, not yet packaged, on this PC**, use the same wrapper
with its explicit Source mode from PowerShell:

```powershell
& 'C:/Users/sende/Documents/ChatGPT/H.E.X/PLAY-HEX.cmd' -Mode Source
```

Open **Menu** with **Esc / controller Back / click Menu**; **Rival Circuit** is
selected first. Press **Enter / A**, or click it. Custom bindings still take
priority; the visible Menu button remains the fallback. Normal desktop **Play**
continues to select qualified d6d1. This local Source route is separate from the
fresh-PC portable instructions below.

This Git repository contains the game source, required art, tests and qualification
evidence. Exported EXE/PCK/ZIP files and local profiles are excluded from Git;
cloning the repository does not download a prebuilt portable.

The current source candidate is on `codex/hex-breakthrough-20261015`, based on
the published `codex/hex-screen-smoothness-20261011` handoff at `aec900a`.
`main` remains at `95ca630`
with the earlier be3 runtime. Use the [development guide](docs/DEVELOPMENT.md)
to select and update the intended branch before launching from source.

For a checkout on another PC, install **PowerShell 7.2 or later** and the pinned
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

The qualified local portable is **p61-d6d1bfb9c529**:

- [Launch H.E.X.](exports/hex-performance-20261014-d6d1/windows/PLAY-HEX.cmd)
- [Windows x64 ZIP](exports/hex-performance-20261014-d6d1/HEX-p61-d6d1bfb9c529-Windows-x64.zip) — **153.7 MiB** (161,194,910 bytes). Extract before launching.

The [package and archive evidence](docs/performance-evidence-20261014/stationary-qualification-d6d1/README.md) records all 18 portable
checks and 2,064 exported-terrain checks over 133 exact images. Five
supervised lifecycle cases cover Hearth, Garden, paid Fire, paid all-six Mantle
and reopening with unchanged isolated preferences. Fire and Mantle each complete
twelve paid starts and releases with zero refusals. These gates establish their
recorded content/lifecycle properties; frame pacing and human acceptance remain separate.

The immediate **p61-64590c45c7a5** fallback retains its
[launcher](exports/hex-depth-clarity-20261014-6459/windows/PLAY-HEX.cmd) and
[qualification](docs/depth-clarity-evidence-20261014/delivery-review/review.json).
The older **p61-7804a23eb300** [launcher](exports/hex-checkpoint-20261013-7804/windows/PLAY-HEX.cmd)
and [qualification](docs/iteration-20261013/delivery-review-7804/review.json) remain preserved.
The [documentation map](docs/README.md) links earlier builds.
These are local artifact paths, not GitHub downloads.

The portable needs no Git, Godot installation or administrator permission.
Keep `hex.exe` and `hex.pck` together. The launcher enables the reviewed pixel
presentation; opening the EXE directly retains skeleton mode. In the current
build, **1280×720** offers the wider spell overview. At **960×540**, supported
reading panels reflow. A 200% reading size and separate movement/aim deadzones
are available in Controls.

Extract each version into its own folder. Saved controls and personal weaves
use the compatible `Godot/app_userdata/FLUX 2` location. Older elemental weaves
receive a slot-by-slot migration preview; Apply preserves the original-file
backup, while inspection or cancellation does not replace saved data.

## Start with five minutes

Shortcuts below are defaults. If you remap F5 or F6 to gameplay, use the Menu
route shown by the guide; the game hides convenience hints that no longer work.

1. Choose **Introduction / F5**. Move, release a prepared jump, pay for a cast,
   watch Flux recover, then try a mixture. **Skip guide / F5** ends it at any time.
   Lessons observe your actions; they never move, cast or equip for you.
2. Open **Spell Range / F6**. Start with a single element, then a pair. Read the
   ingredients, cost, timing, on-hit status, field effect and counter. Equip a
   temporary loaner in slot 1 and cast it yourself. Reset/refill tools are explicit.
3. Use **Menu → World map** to reach the Academy, then open **Spell Loom** at its
   door to build your own twelve-position weave.
   Combine ingredient filters. In the wide overview, **More Forms** reveals
   the additional deliveries and cards can be dragged onto slots. The compact
   reading view uses **Options** for form arrows and **Browse** at the smallest
   layout; choose a spell/slot and use **Assign**.
   Read Swap/Replace before confirming.
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
| Deliveries | Bolt, Heavy, Rapid, Spray, **Mantle** contact/paid trail, **Fuse** delayed area blast, **Split** bounded branches and **Rebound** wall banks |
| Statuses | Fractured Focus, Burning, Chilled, Gusted, Revealed and Withered; finite duration, explicit hit admission and bounded refresh |
| Chemistry | 63 bounded reactions, each named and finite, covering self-pairs and every distinct combination from two through six elements; situational effects and counters |
| Practice and progression | Optional introduction, all-spell Range, 30 earned rival signatures and clearly marked offline Developer tools |
| World | Seven Wellspring districts with **59,466 eligible chemistry cells**; familiar services and practice courts plus Tideglass Quays, Verdant Reaches, Basalt Foundry and Starward Terraces |
| Navigation | One compact Menu, a world overview, current location and thirteen named travel destinations; offline free-exploration travel preserves resources, cooldowns and weave |
| Element Garden | 63 physical plots in Tideglass show six raw materials plus all 63 finite reaction identities; harmless bounded loops with nearby explanations, while player spells remain live |
| Presentation | Slower held poses, tucked non-flying jumps, clear wall contact/protection, screen-wide sight with cover, stable terrain handoffs, faceted spells with grounded shadows, district floor motifs and distinct sound |
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
**Menu → Display & text size** selects Low/Standard visual detail,
a 60/120/unlimited frame limit and 100/125/150/200% text. Low and 60 FPS are the defaults; movement and
spell simulation remain at 120 Hz. Reduced-motion accessibility is separate.
Compact Gallery/Compendium **Options / O / controller Back** reveals browsing
controls and the focused ingredient; Back returns to reading and B closes.
Separate movement/aim deadzones and optional digital aim bindings live in Controls.

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

The [October 12 iteration record](docs/iteration-20261012/README.md)
retains that historical batch's code changes, independent reviews, completed checks and remaining
acceptance work.
The [preserved October 11 audit](docs/audit-implementation-20261011/README.md)
retains the qualified d8 source and portable evidence. The
[resume](.agent/HEX-RESUME.md) identifies the exact runtime and local portable.
Complete-suite results, native timing measurements, visual checks and package
checks have separate evidence; none substitutes for player acceptance.

Three specialist agents and the integration owner reviewed one another's work.
The preceding comprehensive work added shared spell comparisons, paid encounter and learning
journeys, readable input routes, rolling save recovery and bounded diagnostics.
Its reading repair keeps the selected spell name visible in wider Loom
layouts, names both comparison sides before their values, and uses a fitting
Aim cue label in enlarged Controls. Its 196-frame native gate and
185,185-assertion final focused UI gate passed; these do not establish physical
input acceptance or smooth frame times.
The preserved October 11 audit also retains a failed native baseline that rendered
1290×730 instead of its requested size; that failure remains diagnostic evidence.
Current profiling validates actual dimensions and window observations throughout
each measured case; the implementation record distinguishes valid measurements
from attempts that fail those conditions.

The [design basis](docs/implementation-20261012/README.md#design-basis-and-acceptance)
connects those choices to established game-development practice. The current
[technical audit](docs/iteration-20261012/technical-audit.md) records the Garden
staging precedent, measured tradeoffs and deferred profiling work. The earlier
[composition and progression decisions](docs/element-expansion-evidence-20261009/integration.md)
and [map decisions](docs/large-wellspring-evidence-20261009/map-overview.md)
retain their original rationale. Magicka/Noita composition, Mega Man signature
learning, movement-shooter controls and readable action presentation are
references to adapt and test, not proof of H.E.X. balance or fun.

- **Balance, movement feel and wayfinding need human play.** Finite budgets and complete definition coverage do not establish equal competitive usefulness or intuitive routes.
- **The simulation is 2D with depth presentation.** Thirty identities have held action keys; complete authored cycles for every action remain unfinished. Native protection/jump fixtures test presentation correctness separately.
- **Current-build foreground performance and portable FPS remain unmeasured.** The [previous-build 6459 measurement](docs/performance-evidence-20261014/foreground-6459-b/review.json) retains Garden/sustained Fire/Mantle p95 engine intervals of 73.910/117.084/110.507 ms with full observation. Those figures do not measure d6d1 or establish a causal speedup. GPU/present latency and steady 60 FPS remain unqualified. [Older evidence](docs/iteration-20261013/foreground-500be-allsteps/review.json) retains its unmatched source/workload scope. Retained campus drawing remains opt-in after its moving-Garden comparison regressed.
- **Multiplayer is experimental.** All participants need the same exact build. Eight players is a cap, not dense-capacity certification; physical two-PC and different-home acceptance remain open. No Internet relay is deployed.
- **The portable remains local and unsigned.** Source, tests, documentation and relevant receipts are checkpointed on the presentation branch; exported binaries and personal profiles remain excluded. Original assets and earlier working builds are preserved.

The [earlier presentation checkpoint](docs/presentation-checkpoint-20261011/README.md)
and [October 10 performance report](docs/performance-implementation-20261010.md)
keep their own Full attempts, native measurements and package receipts. Those
historical results do not qualify later changes.

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
and [the implementation queue](.agent/OVERHAUL-IMPLEMENTATION.md) owns remaining
acceptance work. The [audit record](docs/audit-implementation-20261011/README.md)
links implemented changes, independent reviews and qualification.
[The playtest route](docs/HEX-PLAYTEST.md) covers physical input, movement,
counterplay and experimental host/join use. [All 30 portraits](reference/art/portraits_20261008/index.html)
remain available offline.

The [source-publication record](docs/source-publication-20261011/README.md)
describes the retained source, removed redundant files, exact-byte evidence rules
and checkout validation. Git history identifies the publication commit;
the runtime identity in the resume identifies the game independently of documentation edits.

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
