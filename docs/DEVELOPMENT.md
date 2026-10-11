# H.E.X. development on Windows

Status: current source-development guide, October 11, 2026. Git contains source and relevant assets/evidence; local exports are separate.

Use the repository root containing `project.godot` and `hex.cmd`. Do not run
development commands from a wrapper folder or an extracted portable. Current
qualified gameplay source is **p60-be3efd332e1a**: protocol 60, SessionSnapshot 24,
120 Hz, six ingredients, 63 compositions, eight deliveries and 504 spells.
The [resume](../.agent/HEX-RESUME.md) owns exact identities and qualification;
the [specification](../SPECIFICATION.md) owns behavior.

## Prerequisites

- Windows x64 and **PowerShell 7.2 or later** (`pwsh.exe`, not Windows PowerShell 5.1).
- The pinned official **Godot 4.7.1** engine: `4.7.1.stable.official.a13da4feb`.
- Git for repository-aware checks. Matching Windows export templates are
  needed only when creating a portable.

Scripts use modern .NET APIs. The `hex.cmd`/`hex.ps1` front door requires
PowerShell 7 and reports a missing or incompatible host. For direct script
invocation, use `pwsh`; do not substitute `powershell.exe`.

Set `FLUX2_GODOT_BIN` to the engine executable when it is not available through
the supported local cache or `godot4`/`godot` on PATH. This is a process-local
environment variable, not a request to change machine policy:

```powershell
$env:FLUX2_GODOT_BIN = 'C:\path\to\Godot_v4.7.1-stable_win64.exe'
.\hex.cmd doctor
```

`doctor` checks the actual executable's exact version. A different Godot build is
not the qualified baseline. No engine executable or export payload is obtained
merely by cloning this repository.

## Run and test source

```powershell
.\hex.cmd play --fullbody-art --pixel-cast
.\hex.cmd check
.\hex.cmd assets
.\hex.cmd list-tests
.\hex.cmd test -Tier Focused -Suite movement-hot-path
.\hex.cmd test -Tier Full
```

The equivalent explicit source launcher is:

```powershell
pwsh -NoProfile -File scripts/run.ps1 --fullbody-art --pixel-cast
```

The launcher performs the first resource import when required. Source and
portable saves use the compatible `Godot/app_userdata/FLUX 2` directory; keep
personal preferences, progress and weaves out of Git. Automated qualification
uses isolated userdata. The [player guide](PLAYER-GUIDE.md) owns controls.

Focused runs require named stable suite IDs. Full runs the complete registry,
import, canonical identity checks and bounded boot. The editor import has a
separate 600-second limit for cold checkouts; the Full suite has an 1800-second
limit. Focused suites and boot retain their 180-second limits. These supervision
budgets are not frame-time allowances. Engine workflows share an execution guard.
Do not start parallel Godot imports, tests, captures, profiles or exports against
one checkout or delete a guard journal to bypass its owner.

## Identity and asset preparation

`hex.cmd check` and `hex.cmd assets` create/check current reports under `.godot`.
Canonical gameplay identity is checked independently:

```powershell
pwsh -NoProfile -File scripts/runtime-build-identity.ps1 -Mode Check
```

Only after an intentional production edit, prepare affected assets and run
`-Mode Generate` before the new qualification boundary. Never regenerate a
different identity simply to make a stale test or package appear current.
Documentation, tests and scripts are outside this identity scope, but script
inputs to baked assets still have their own provenance checks.

The 132 terrain chunks, overview and manifest under
`assets/environment/wellspring_ground_v1/` are required lossless runtime assets.
Do not remove them as cache files. After changing a map or a declared producer,
the explicit preparation command is:

```powershell
& $env:FLUX2_GODOT_BIN --headless --path . --script res://scripts/bake_wellspring_terrain.gd
```

Run that job alone after the editor has imported the project, then regenerate
runtime identity and repeat relevant gates. Ordinary source runs consume the
checked-in prepared assets; they do not need a new terrain bake. The
[terrain stream](../src/presentation/wellspring_terrain_stream.gd) declares
producer paths and validates the manifest; generated `.godot` imports are local.

## Build a local Windows portable

After freezing and qualifying the intended source, use a **fresh** run ID:

```powershell
.\hex.cmd package -RunId hex-local-20261011 -PixelCast
```

The direct form is:

```powershell
pwsh -NoProfile -File scripts/package-hex.ps1 -RunId hex-local-20261011 -PixelCast
```

`-PixelCast` includes fullbody artwork. The script requires matching templates,
exports to `exports/<RunId>/windows/`, creates `PLAY-HEX.cmd` and a ZIP, and checks
the candidate's identity, art admission and safe close. It refuses an existing
output directory. Keep `hex.exe` and `hex.pck` together and extract the entire ZIP.
An export smoke does not replace Full, packaged-resource verification, actual
rendered measurements or human acceptance.

`exports/`, `.godot/` and local profiles are intentionally excluded from Git.
Links to old local packages describe preserved local artifacts, not GitHub
downloads. A source commit/push is not a GitHub binary release, installer or
automatic update. The October 11 request authorizes source cleanup/publication;
record the actual remote commit result separately from earlier game validation.

## Evidence and history

Keep runtime source, original assets, import recipes, required baked resources,
independent test oracles and useful passing/failing evidence. Remove a retired
producer or duplicate only after proving its dependency boundary and preserving
needed provenance. A filename containing `legacy`, `reference` or an old date
does not establish that it is unused.

The [performance report](performance-implementation-20261010.md) links the be3
Full, native, package and visible-window receipts, including remaining
heavy-field/cold-loading limits. Those are measurements of frozen bytes, not
claims about a later source change.

The [exact earlier developer reference](archive/source-publication-20261011/DEVELOPMENT.md)
retains old Linux, 60 Hz, protocol-32 and harness notes for provenance. It is not
the current setup guide. Use the [documentation map](README.md) to find current
contracts instead of restarting historical implementation plans.
