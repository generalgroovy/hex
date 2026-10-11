# H.E.X. — Help, Everything eXploded!

**Current local review candidate: `p55-aeefbd4a5e7b` (September 23).** Spell Loom
and Character Gallery now explain when their final actions are unavailable before
sending a request. Browse spells, starter previews, character details and facing;
Assign/Apply/Attune follow the current station, round and action rules. Confirmed
selection, saved weaves, close, movement and paid casting remain protected.

Launch `exports/hex-gallery-availability-20260923/windows/PLAY-HEX.cmd`.
Full validation, exact-PCK player journeys, paid Water and visibility captures,
native EXE launch/close and archive integrity pass. Read
[the current handoff](docs/verification/hex-gallery-availability-20260923/HANDOFF.md),
[single queue](.agent/OVERHAUL-IMPLEMENTATION.md) and
[36-reaction evaluation](docs/verification/hex-design-20260923/reaction-decisions.md).
Water pixel crests, strict character concealment and earlier measured validation,
hashing and drawing improvements are preserved. Dense performance remains over
budget and multiplayer acceptance is still open. No proposed reaction mechanics
or smaller live grid are introduced. Complete-map32/24px experiments exceed the
current cell cap. The E1 package is the operational fallback at
`exports/hex-loom-availability-20260923-v2/windows/PLAY-HEX.cmd`.

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

## Current checkpoint

Frozen runtime **`p55-aeefbd4a5e7b`** uses protocol55 / SessionSnapshot21 /
HexWorldSnapshot3 / chemistry3 / envelope1. Full validation passed **160 suites /
805,165 assertions**, zero failures/stderr, import, asset audit and configured
120Hz boot. Gallery journeys each pass77checks/9native frames in source and exact
PCK, with all9 fixed-pose control RGBA pairs equal. Exact packaged character switch/return/custom
weave, movement/casting, Loom/save/restart, Water and terrain visibility pass.
The native EXE launches and closes cleanly; all seven ZIP entries match the
delivery payload. [The handoff](docs/verification/hex-gallery-availability-20260923/HANDOFF.md)
separates source, PCK, native EXE, historical performance and human acceptance.

Earlier performance evidence remains historical: validator median59.083→27.010ms;
legal hash80.370→62.854ms; matched draw preparation savings8.314–9.989ms.
D6 evolving stress still missed all1,440 frame deadlines. E2 is a usability slice
and establishes no new stress or full multi-EXE lifecycle pass. Human feel,
Water/style/motion and physical networking remain open.

**Current local portable:** `exports/hex-gallery-availability-20260923/windows/PLAY-HEX.cmd`.
**Local ZIP:** `exports/hex-gallery-availability-20260923/HEX-p55-aeefbd4a5e7b-Windows-x64.zip`.
Extract the entire archive and keep EXE/PCK together. Packages are local; no release,
installer/updater or selected-checkpoint promotion occurred.
**Operational fallback:** `exports/hex-loom-availability-20260923-v2/windows/PLAY-HEX.cmd`.
D6, hash and responsive packages are also preserved. Do not use
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
