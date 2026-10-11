# Preserved README before retro consolidation

Status: historical snapshot, not current launch or acceptance authority.

# H.E.X. — Help, Everything eXploded!

**Latest local playtest — Wellspring playground, September 28:** new Chain
Courtyard, Cover Garden and Open Laboratory, seven real practice walls and a
connected southern return. Movement/projectile streaks and flight residue are
removed; paid impact material and stationary reaction fields remain.
**[Start PLAY-HEX.cmd](exports/hex-playground-20260928/windows/PLAY-HEX.cmd)**
(`p56-d75bac3687a7`; detailed character art enabled).
Full **166 suites / 1,309,268 assertions**, native room/paid impact captures and
export launch/safe shutdown passed. Existing stations, spawn, controls and world
size are preserved. Dense simulation p95 remains about 19ms: **120Hz capacity
still fails; multiplayer remains experimental**. Local solo playtest, no installer
or pinned-checkpoint promotion. [Map previews, evidence and test route](docs/WELLSPRING-PLAYGROUND.md).

**Previous local playtest — fluidity refinement, September 28:** continuous casting
and braking strides, fixed-length casting arms, and shared exact field-path
queries. **[Start PLAY-HEX.cmd](exports/hex-live-motion-20260928/windows/PLAY-HEX.cmd)**
(`p56-89cd9398d967`; detailed character art enabled).
Full **166 suites / 1,233,417 assertions**, 192 native motion frames, seven paid
gameplay frames and Windows export launch/safe close passed. Controls, movement
budgets and smaller stationary reactions are unchanged. Dense simulation p95 is
19.6 ms versus the previous receipt's 27 ms; **120 Hz still fails**, and simultaneous
moving-cast pose CPU remains an open cost. Local solo feel test, not capacity or
multiplayer acceptance. [Preview, evidence and checklist](docs/FLUIDITY-REFINEMENT.md).
Previous builds, installer and pinned checkpoint remain unchanged.

**Previous local playtest — compact stationary reactions, September 28:** all 36
reaction footprints have 25% smaller radius/length and remain fixed at formation.
Steam/Flood/Conflagration radius is 48 px (was 64 px); Freeze and Hailstream use
fixed compact lanes. Pulse timing, damage, player forces, projectile travel and
ingredient deposits are unchanged. **[Start PLAY-HEX.cmd](exports/hex-compact-stationary-20260928/windows/PLAY-HEX.cmd)**
(`p56-b12c954709e2`; detailed character art enabled).
Full **166 suites / 1,213,800 assertions**, native paid gameplay captures and
Windows export launch/safe close passed. Dense simulation p95 is now about 27 ms,
but **still fails the 8.333 ms target**. Local solo feedback only; this is not
multiplayer, rendered-performance or installer acceptance.
[Contract, previews, evidence and playtest checklist](docs/COMPACT-STATIONARY-REACTIONS.md).
Previous builds and the pinned checkpoint are preserved; no commit/push/publication.

**Previous local playtest — retro readability, September 28:** no idle affinity
orbits, no projectile ring halos, ten compact pixel-material motifs, and faster
exact-safe sector queries. **[Start PLAY-HEX.cmd](exports/hex-retro-readability-20260928/windows/PLAY-HEX.cmd)**
(`p56-8ac1fcbd4e8c`; character artwork enabled).
Full **166 suites / 1,186,622 assertions**, native gameplay captures and Windows
export launch/safe close passed. Dense simulation p95 improved from 51–53 ms to
38–39 ms in the paired profile but **still fails the 8.333 ms budget**. This is
a local solo playtest, not multiplayer/capacity acceptance. Controls, damage,
resources, sizes and effect coverage are unchanged.
[Visuals, measurements, limitations and playtest checklist](docs/art/character-motion-20260927/RETRO-READABILITY.md).
Prior portable builds remain intact; no installer or checkpoint-pointer promotion.

**Previous local motion playtest — September 28:** continuous character-pose
interpolation, short natural walk/run/idle settling, and exact hex/wall query
optimizations. **[Start PLAY-HEX.cmd](exports/hex-continuous-motion-20260928/windows/PLAY-HEX.cmd)**
(`p56-4205e5be2616`; detailed character art enabled).
Full **166 suites / 1,182,235 assertions**, native motion/gameplay captures and
exported Windows launch/safe close passed. Input, exposure and movement balance
are unchanged. **Dense-scene 120 Hz still fails**: final simulation p95 was
49.8 / 110.3 ms; this is an animation playtest, not a performance-capacity release.
[Preview, measurements and playtest checklist](docs/art/character-motion-20260927/CONTINUOUS-MOTION.md).
Earlier builds remain preserved for comparison; no installer/checkpoint promotion.

**Previous local playtest — September 28:** sharper original-source character
textures, 24px symbol-sized chemistry cells, sparse material storage and exact
geometry optimizations. **[Start PLAY-HEX.cmd](exports/hex-detail-fine-grid-20260928/windows/PLAY-HEX.cmd)**
(`p56-88ff6122c320`; enables the character artwork).
Full 166 suites / 1,164,315 assertions, native captures and Windows safe close
passed. Dense eight-caster simulation improved to about 27ms median / 54–55ms
p95 but **still fails the 8.333ms budget**; this is not multiplayer/capacity
acceptance. Most identities still use shared-rig animation.
[Changes, measurements and open gates](docs/art/character-motion-20260927/DETAIL-FINE-GRID.md).
Earlier portable builds below are preserved as fallbacks.

**Fluid-motion follow-up:** front/back feet now alternate through a fixed-length
leg solve; finer pose sampling, gentler braking strides, live wall-run timing and
shared-rig jump/cast refinements. [Motion preview and validation status](docs/art/character-motion-20260927/FLUID-MOTION.md).
This is a visual refinement, not a change to movement balance or hitboxes.

**Earlier motion test:** [PLAY-HEX.cmd](exports/hex-fluid-motion-20260927/windows/PLAY-HEX.cmd)
— `p56-d5924286dbc9`. Six focused suites / 141,767 assertions, import/boot and
native Windows launch/safe close passed. Full suite not rerun for this slice.
The older exports below remain available for comparison.

**September27 character-art integration candidate:** all30 full-body identity
skins are now connected to gameplay, Gallery and HUD with approximately equal
skull proportions. The opt-in `--fullbody-art` mode retains the established
movement/simulation rules. It is a separate local visual playtest, **not a claim
that all30 animation sets are finished**. See the
[integration handoff](docs/art/character-motion-20260927/IN-GAME-INTEGRATION.md)
for the test launcher, evidence and remaining motion work. The selected movement
checkpoint below is preserved.

**Test the new artwork:**
[`PLAY-HEX.cmd`](exports/hex-character-art-20260927/windows/PLAY-HEX.cmd) —
build`p56-4c48c9f94414`; use this wrapper to enable the character-art mode.
Full165 suites /906,664 assertions and native Windows art launch/safe close passed.
Human animation acceptance and performance/multiplayer acceptance remain open.

**Movement checkpoint ready for local solo playtest: `p56-5dc9b5f3bdc0` (September26).**
Launch `exports/hex-movement-c1-20260926/windows/PLAY-HEX.cmd`; keep `hex.exe`
and `hex.pck` together. Portable archive:
`exports/hex-movement-c1-20260926/HEX-p56-5dc9b5f3bdc0-Windows-x64.zip`.
Full validation passed164 suites /835139 assertions; final-source and exact-PCK
input journeys, native launch/safe close and movement captures passed. This is
not human, multiplayer or sustained-frame-rate acceptance. No new installer.
[Evidence and limits](docs/verification/hex-movement-c1-20260926/HANDOFF.md) |
[Five-minute playtest](docs/HEX-PLAYTEST.md). Movement implementation stops here for feedback.
Ground Jump prepares on press and launches on release; non-fliers get one double
jump, while sylph/wyrmborn/angel/demon use finite held flight. Airborne held Jump
can attach to suitable walls; release walljumps. Slide facing follows travel
independently of aim. Height/low profile avoid appropriate attacks, not all
damage; wallrun remains exposed. See the [current contract](SPECIFICATION.md#active-checkpoint-1-movement-and-height).
Protocol56 / SessionSnapshot22 / HexWorldSnapshot4 require matching builds.
No smaller-grid or major map expansion is bundled into this checkpoint.

**Artwork sources and earlier workbench evidence (September27):** full-body artwork
now uses a [shared-head proportion rule](docs/art/character-motion-20260927/SHARED-HEAD-UPDATE.md):
approximately18px anatomical skulls for all three sizes, body mass carrying the
difference. All30 layered candidates are rebuilt; Wa Bidi, Jan Wicked and Fluup
add192 authored action keyposes. Earlier three-pilot poses remain separately
preserved pending recalibration. The broader artwork pipeline
now targets all 30 current identities, with eight standing directions each and
volume-first Small/Middle/Large templates. The next [motion checkpoint](docs/art/character-motion-20260927/HANDOFF.md)
adds anatomical calibration for all 30, editable full-body layers and 24 active
action candidates. Native review rejected unrestricted generic skinning for
large motions; 192 authored corrective keyposes for S. Wayne, Oh Tipi and The
Red Baron are staged in the [motion workbench](art_batches/character_motion_v1/README.md).
Previous art checkpoint: 67 tests and21 boards. The shared-head update passed
96 art tests, all30 native loads and42 native review captures. Exact heading readability and complete animation
cycles are still pending; these counts are not a visual-acceptance claim.
See the [standing cast checkpoint](docs/art/character-cast-20260927/HANDOFF.md)
and [native art gallery](art_batches/character_cast_v1/README.md). These standing
views are not complete movement animation sets. The prior Seakin component pilot
is retained as pipeline evidence. Default/previous builds still use shared moving
bodies; the new opt-in character-art candidate uses identity-specific skins.

**Preserved pre-movement review candidate: `p55-dd2ab169dcfa` (September23).** Native
cell-key sorting reduces the cost of chemistry hashing while preserving exact
canonical bytes and gameplay. Contextual Spell Loom and Gallery availability,
confirmed selections, saved weaves, movement and paid casting remain protected.

Fallback: `exports/hex-native-sort-20260923/windows/PLAY-HEX.cmd`. Historical Full validation, exact Windows
player journeys, Water/visibility captures, EXE launch/close and archive integrity
passed. Read [the D9 handoff](docs/verification/hex-native-sort-20260923/HANDOFF.md),
[single queue](.agent/OVERHAUL-IMPLEMENTATION.md) and
[36-reaction evaluation](docs/verification/hex-design-20260923/reaction-decisions.md).
Performance and multiplayer remain unaccepted. No proposed reaction mechanics
or smaller live grid are introduced. The E2 Gallery/Loom operational fallback is
`exports/hex-gallery-availability-20260923/windows/PLAY-HEX.cmd`.

**Preserved September 21 fallback:** the offline Spell Loom lock is repaired
and packaged as `p55-a0952919d4d5`, with executed assignment, movement/casting and
isolated save/restart evidence. Full validation and automated EXE launch/close pass;
the later interactive EXE test was interrupted. See [the acceptance handoff](docs/verification/hex-acceptance-20260921/HANDOFF.md)
for that fallback's Windows package and historical results. This is a bounded P0
repair, not completion of the broader acceptance milestone. Multiplayer's last
same-export lifecycle FAILED with resource/allocation errors under the unchanged
300-second configuration; the current candidate has no complete-EXE lifecycle pass. Treat multiplayer
as experimental. The 32 catalog spells and 30 profiles are not a claim of fully
accepted player journeys or 30 finished skins. Apart from the Water pilot, new art
packs remain staged. The preserved C1 visibility package is also available at
`exports/hex-visibility-20260923/windows/PLAY-HEX.cmd`.

A movement-led elemental sandbox in Godot for Windows. Learn paid, chainable
movement, aim independently, configure twelve spell positions, and combine
finite elemental effects throughout the shared Wellspring.

H.E.X. continues FLUX. The game/repository name changes; **Flux remains the spell
resource**. Existing Windows preferences and custom weaves retain the compatible
`Godot/app_userdata/FLUX 2` profile directory. Original FLUX source, assets and
fallback packages remain in `C:\Users\sende\Projects\flux`.

**Current source: 30 playable profiles, 32 spells.** All identities currently use
three shared size templates; these are not thirty finished individual skins.
The roster has 30 playable entries; 30 identities. The preserved ability catalogue
has 62 validated effective records; 32 have runtime wire IDs. Retired deliveries
and passive/gated records remain metadata, not additional selectable spells.

| System | Current contract |
| --- | --- |
| Engine | 120 Hz authoritative simulation; 60 Hz transport snapshots; Godot 4.7.1 |
| Sessions | Same-build, host-authoritative, maximum eight players |
| Spells | Eight elements; Bolt, Heavy, Rapid and Spray; twelve configurable positions |
| Chemistry | 36 symmetric first-grade reactions with finite budgets; ten Water/Earth/Fire/Air pairs integrated into Wellspring |
| Coverage | Exact impact geometry selects whole hexes; selected cells are fully affected |
| Grid | 48 px face-to-face; 2,766 eligible Wellspring cells; unchanged world and character scale |
| Movement | Continuous movement/projectiles, independent eight-direction aim, three body sizes |
| Presentation | Readable whole-cell boundaries, transparent scalding Steam, reduced-effects mode |

Whole-hex behavior is user-approved. Chemistry works on eligible ground anywhere
in Wellspring, without a dummy. Each cast has a finite paid material budget;
connected visuals do not merge lifetimes or create material. Rapid remains
trail-free. Spell strengths remain Rapid1 / Spray3 / Bolt5 / Heavy15.

## Historical D9 checkpoint (preserved fallback)

Frozen runtime **`p55-dd2ab169dcfa`** uses protocol55 / SessionSnapshot21 /
HexWorldSnapshot3 / chemistry3 / envelope1. Fresh Full passed **160 suites /
805,217 assertions**, zero failures/stderr, import, asset audit and configured
120Hz boot. Exact PCK Gallery passes77checks/9frames; all9 controlled-pose images
match the preserved E2 export. Packaged character switch/return/custom weave,
movement/casting, Loom/save/restart, Water and terrain visibility pass. Native
EXE launch/close and all seven ZIP payload entries pass.

The matched prototype legal whole-hash median improves68.323 to52.151ms (23.67%).
The separately measured integrated path has49.300ms median; it is not another
old/new comparison. Every measured hash call remains above both timing budgets.
Fresh evolving rendered stress passes7,991correctness assertions but misses
1,440/1,440 frame deadlines. Full multi-EXE lifecycle, physical networking,
controls, human Water/style/motion and capacity acceptance remain open.

**Current local portable:** `exports/hex-native-sort-20260923/windows/PLAY-HEX.cmd`.
**Local ZIP:** `exports/hex-native-sort-20260923/HEX-p55-dd2ab169dcfa-Windows-x64.zip`.
Extract the entire archive and keep EXE/PCK together. No publication, installer/
updater or selected-checkpoint promotion occurred.
**Operational fallback:** `exports/hex-gallery-availability-20260923/windows/PLAY-HEX.cmd`.
E1 v2, D6 and earlier packages remain preserved. Do not use
`exports/hex-loom-availability-20260923/`: its first export failed validation.

## Historical smaller-grid checkpoint

Preserved smaller-grid build is **`p55-c7b7694f8d23`**: protocol55 /
SessionSnapshot21 / HexWorldSnapshot3 / chemistry3 / envelope1. Hexes are
25% narrower (64 to 48 px); the map, actors, wall clearance and world-space
spell radii retain their scale. Old protocol54 clients cannot join this build.

The completed sight correction is included: always-on, 360-degree
character-centered sight at a common 720 ground-unit range, with opaque
building and active solid-hex occlusion. Aim and zoom do not expand sight.
Spectators follow the same rules. Legacy Full/cone settings migrate without
resetting controls, camera, movement reference, audio or saved weaves; F8-F10
no longer change sight. This is presentation filtering, not network redaction.

Its historical Full: **157 suites / 803,865 assertions**, zero failures/stderr, import,
asset audit and 120 Hz configured boot. Seven native gameplay frames cover
paid Water/Fire casts, Steam, whole-cell contact and normal/reduced effects.
Actual Windows EXE/PCK launch, identity, safe close and ZIP byte audit passed.
See [the smaller-grid checkpoint](docs/HEX-SMALL-GRID-CHECKPOINT.md) for the
exact networking result, evidence, remaining risks and playtest instructions.
**Multiplayer lifecycle is not accepted:** the same-export localhost run timed
out at its unchanged 300-second deadline before the second round completed.
Connection, movement reconciliation, reconnect and late spectating were
observed, but that does not pass the complete Host/Join gate.

**Historical portable:** `exports/hex-small-grid-20260921/windows/PLAY-HEX.cmd`.
**Historical ZIP:** `exports/hex-small-grid-20260921/HEX-p55-c7b7694f8d23-Windows-x64.zip`
(98.3 MB; extract the entire archive). These payloads are local, not included
in the Git source download or published as a GitHub release.

Source repository: [generalgroovy/hex](https://github.com/generalgroovy/hex).
The prior [sight checkpoint](docs/HEX-VISION-CHECKPOINT.md) and its protocol54
portable remain available as a fallback. The historical selected delivery
pointer is unchanged; no installer/updater is produced by this source slice.
Dense performance, physical two-PC/Internet play and human acceptance remain
open. A 120 Hz configured simulation is not a sustained 120 FPS claim.

## Run the latest source

```powershell
Set-Location C:\Users\sende\Projects\hex
.\scripts\run.cmd
```

Or open `hex.cmd` from the repository root. It defaults to `play` and invokes the
same launcher. Existing FLUX EXEs contain older builds. For a portable package,
use the exact `PLAY-HEX.cmd` and ZIP above, keep
`hex.exe` with `hex.pck`, and extract the ZIP before launching.

The launcher uses pinned Godot4.7.1. `hex.cmd doctor` checks the local toolchain;
first launch imports source resources. [The design contract](SPECIFICATION.md)
and [single queue](.agent/OVERHAUL-IMPLEMENTATION.md) describe current work.

## Play and configure

Move with WASD and aim with the mouse by default. Numbered spell bindings attack;
LMB/RMB's staged Punch/Kick mechanics are still unavailable. Open the F4
compendium for runtime-derived movement and chemistry rules. Controls Lectern
provides bindings; Spell Loom configures the twelve positions and all32 spells.
Saved custom controls take precedence over defaults. The Loom now displays the
effective keyboard chord, and distinguishes Empty, Not bound and Unavailable.

Steam builds scald exposure during occupation and decays after leaving. Its hot
vents indicate the active whole hexes; terminal brackets signal expiry. Normal
and reduced effects use identical coverage. Short repeated visits may intersect
more pressure pulses than the same total contact in one visit; no coefficient
was tuned from the external handoff's untested targets.
The finer grid can spread the same finite budget across more cells, reducing
per-cell Fire/Steam pressure. Coefficients are unchanged; density-normalized
balance is a measured follow-up, not silently compensated in this slice.

Follow [the five-minute playtest](docs/HEX-PLAYTEST.md). The added Source Court,
Crucible and connecting-route labels use the existing campus; the supplied world
maps remain composition references, not new playable continents.

## Host and join

Both players need the exact same H.E.X. build. These source commands use port24892:

```powershell
# Host
.\scripts\run.cmd --farflow=host --session-port=24892
# Join; replace HOST_IP with the host's address
.\scripts\run.cmd --farflow=join --join-address=HOST_IP --session-port=24892
```

For the portable use `PLAY-HEX.cmd` followed by the same game arguments.
The launcher supplies Godot's argument separator. If invoking the EXE directly,
place `--` before game arguments. The in-world Farflow stations provide the same
host/join workflow. See the checkpoint for the exact tested networking scope;
localhost tests do not prove physical two-PC or Internet play.

## Development and evidence

```powershell
.\hex.cmd check
.\hex.cmd test -Tier Full
pwsh -NoProfile -File scripts/test.ps1 -Tier Focused -Suite session-snapshot
```

One integration owner serializes engine imports, tests, captures, profiles and
exports through repository wrappers and isolated test profiles. Build identity
hashes exact runtime source bytes; Git preserves those bytes and required import
recipes. No generated `.godot` cache or private test profile is published.

[Handoff decisions](docs/HEX-HANDOFF-RECONCILIATION.md) distinguish adopted source
work from proposal-only targets. [Current curated receipts](docs/verification/hex-small-grid-20260921/)
preserve logs and evidence limits. The [historical README](docs/archive/README-FLUX-before-HEX.md)
retains earlier instructions and receipts without presenting them as current proof.

## Preserved fallback

The selected pointer has not been promoted. Its original payload remains in
`C:\Users\sende\Projects\flux\exports\windows-overnight-p48-20260913`.
The generated descriptor below is historical delivery metadata; its relative
payload links resolve only where those old exports are present.

<!-- BEGIN CURRENT BUILD SUMMARY: generated by scripts/current-build-summary.ps1 -->
**Current local portable selected by [the exact pointer](docs/current-checkpoint.json):** `overnight-p48-20260913`.
Open [flux2.exe](exports/windows-overnight-p48-20260913/windows/flux2.exe) with its adjacent [flux2.pck](exports/windows-overnight-p48-20260913/windows/flux2.pck), or extract the [complete current portable ZIP](exports/windows-overnight-p48-20260913/release/FLUX2-Windows-x86_64.zip). Keep the EXE and PCK together.
Pinned PCK SHA-256: `ddce9451e871096ca02190deb9092cba71db96bd8d732cd2181fd7c5cd452083`
Pinned ZIP SHA-256: `5e49c599f026453917e3eb8201456e86089e9fe0d794efe3b9bcebe1385c041f`
Pointer boundaries: publication `not_published`; human acceptance `pending`; physical two-PC acceptance `pending`; sustained rendered 120 FPS `not_certified`; current installer `not_attempted_prior_policy_block`.
This generated summary validates pointer metadata only; it does not read or hash local payloads or repeat runtime acceptance. For exact local byte and receipt checks, run `pwsh -NoProfile -File scripts/current-checkpoint.ps1 -ReportOnly`.
<!-- END CURRENT BUILD SUMMARY -->
