# HEX

A movement-led elemental sandbox in Godot for Windows. Learn paid, chainable
movement, aim independently, configure twelve spell positions, and combine
finite elemental effects throughout the shared Wellspring.

HEX continues FLUX. The game/repository name changes; **Flux remains the spell
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
| Movement | Continuous movement/projectiles, independent eight-direction aim, three body sizes |
| Presentation | Readable whole-cell boundaries, transparent scalding Steam, reduced-effects mode |

Whole-hex behavior is user-approved. Chemistry works on eligible ground anywhere
in Wellspring, without a dummy. Each cast has a finite paid material budget;
connected visuals do not merge lifetimes or create material. Rapid remains
trail-free. Spell strengths remain Rapid1 / Spray3 / Bolt5 / Heavy15.

## Current checkpoint

HEX integration source is `p54-8cb4def57da9`, protocol54 / SessionSnapshot21 /
HexWorldSnapshot3 / chemistry3 / envelope1. Fresh Full passed **157 suites /
776,169 assertions**, zero failures/stderr, import and 120 Hz boot. The actual
Windows portable passed native launch, exact PCK identity and safe close.
This is a human-playtest candidate; dense performance remains unaccepted.

See [the integration checkpoint](docs/HEX-INTEGRATION-CHECKPOINT.md) for fresh
results, known failures, exact package paths and evidence. The new clash-feedback
wire kind is deliberate: old peers fail version and exact-build checks. No
profile migration or gameplay rebalance accompanies it. Simulation capacity,
rendered performance, localhost networking, physical two-PC and human acceptance
are separate evidence categories.

Source repository: [generalgroovy/hex](https://github.com/generalgroovy/hex).

Portable launcher: `exports/hex-p54-20260920/windows/PLAY-HEX.cmd`.
Portable ZIP: `exports/hex-p54-20260920/HEX-p54-8cb4def57da9-Windows-x64.zip`.
These locally verified payloads are preserved outside Git; no GitHub release or
installer was created.

## Run the latest source

```powershell
Set-Location C:\Users\sende\Projects\hex
.\scripts\run.cmd
```

Or open `hex.cmd` from the repository root. It defaults to `play` and invokes the
same launcher. Existing FLUX EXEs contain older builds. For a portable package,
use the exact `PLAY-HEX.cmd` and ZIP in the integration checkpoint, keep
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

Follow [the five-minute playtest](docs/HEX-PLAYTEST.md). The added Source Court,
Crucible and connecting-route labels use the existing campus; the supplied world
maps remain composition references, not new playable continents.

## Host and join

Both players need the exact same HEX build. These source commands use port24892:

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
work from proposal-only targets. [Curated receipts](docs/verification/hex-integration-20260920/)
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
