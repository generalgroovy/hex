# H.E.X. development on Windows

Status: current source-development guide, October 15, 2026. Git contains source and relevant assets/evidence; local exports are separate.

Use the repository root containing `project.godot` and `hex.cmd`. Do not run
development commands from a wrapper folder or an extracted portable. Active
source work is on `codex/hex-breakthrough-20261015`, based on published `aec900a`.
The Circuit, navigation/map and launcher-observer changes are **source candidates;
runtime and delivery qualification are pending**. Desktop Play still selects the
qualified **p61-d6d1bfb9c529** portable. Its
[qualification archive](performance-evidence-20261014/stationary-qualification-d6d1/README.md)
records Full/package/terrain/lifecycle and independent review; those passes do
not qualify later edits. Preserve immediate 6459 and older working fallbacks.

Protocol 61, SessionSnapshot 24, 120 Hz, six ingredients, 63 compositions, eight
deliveries and 504 spells remain the baseline contract. The
[single queue](../.agent/OVERHAUL-IMPLEMENTATION.md) owns current validation; the
[October 13 checkpoint](iteration-20261013/README.md) is historical evidence.
The [resume](../.agent/HEX-RESUME.md) owns exact identities and qualification;
the [specification](../SPECIFICATION.md) owns behavior.

## Select the current working source

The active local branch is `codex/hex-breakthrough-20261015`; `main` remains
`95ca630`. Inspect local changes before switching branches, and preserve them
without a reset, clean or automatic stash:

```powershell
git status --short --branch
git log -1 --format='%H %s'
```

The published `codex/hex-screen-smoothness-20261011` branch is the stable
[Linux handoff](../.agent/LINUX-HANDOFF.md), not an assertion that the newer local
candidate is published or qualified. Follow that handoff for a clean receiving
checkout and compare the exact supplied commit. A pull cannot obtain uncommitted
candidate files. The [product assessment](BREAKTHROUGH-ASSESSMENT-20261015.md)
explains this batch; the single queue owns its current status.

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

For actual player sessions on this PC, always use the **H.E.X. desktop shortcut**,
whose stable target is `C:/Users/sende/Documents/ChatGPT/H.E.X/PLAY-HEX.cmd`.
The commands below are development/validation tools, not an alternative current
playable selection. Root serializes engine work and qualifies a new portable
before changing the default launch target.

```powershell
& 'C:\Users\sende\Documents\ChatGPT\H.E.X\PLAY-HEX.cmd' -Mode Source
.\hex.cmd check
.\hex.cmd assets
.\hex.cmd list-tests
.\hex.cmd test -Tier Focused -Suite movement-hot-path
.\hex.cmd test -Tier Full
```

On another PC, the equivalent checkout source launcher is:

```powershell
pwsh -NoProfile -File scripts/run.ps1 --fullbody-art --pixel-cast
```

The launcher performs the first resource import when required. Source and
portable saves use the compatible `Godot/app_userdata/FLUX 2` directory; keep
personal preferences, progress and weaves out of Git. Automated qualification
uses isolated userdata. The [player guide](PLAYER-GUIDE.md) owns controls.

The new candidate suites are `signature-circuit` (bounded coordinator, result
copy, layout and input) and `signature-circuit-integration` (actual three-rival
controller journey, paid learned-spell reuse and normal-weave restoration).
The integration fixture keeps progression in memory; it does not prove a durable
save/reopen. `local-navigation` and `wellspring-map` cover discovery and compact
pointer/page boundaries. These are validation targets, not a claim of passing
runtime results. Current candidate CI declares the two Circuit suites and map in
its `player-loop` shard. `scripts/test-launcher-profile.ps1` checks Profile argument
construction and the producer's observer-admission guards without starting Godot.

Focused runs require named stable suite IDs. Full runs the complete registry,
import, canonical identity checks and bounded boot. The editor import has a
separate 600-second limit for cold checkouts; the Full suite has a 2700-second
limit, shared with Release because both run the entire registry. Focused suites
and boot retain their 180-second limits. These supervision
budgets are not frame-time allowances. Engine workflows share an execution guard.
Do not start parallel Godot imports, tests, captures, profiles or exports against
one checkout or delete a guard journal to bypass its owner.

Pull-request CI runs the source-only checks, pinned-engine Fast and a named
foundation subset. Manual and main-branch workflows run Full. Local results do
not prove that a remote workflow ran. Console log previews retain the last
2,000 lines with long lines abbreviated; error/warning validation still scans
the original complete logs, which are kept on disk. CI retains top-level run logs
and receipts for fourteen days on success or failure, excluding isolated profiles.

## Measure changes

Run profiles alone after source identity is frozen and import is complete:

```powershell
& 'C:\Users\sende\Documents\ChatGPT\H.E.X\PLAY-HEX.cmd' -Mode Profile -OutputDirectory .godot/profile-full-new
& 'C:\Users\sende\Documents\ChatGPT\H.E.X\PLAY-HEX.cmd' -Mode Profile -LightObserver -OutputDirectory .godot/profile-light-new
.\scripts\test-launcher-profile.ps1
.\scripts\test-gameplay-profile.ps1
```

Prepared native diagnostics also use this desktop launcher with `-Mode Diagnostic`,
an explicit contained `-DiagnosticRunner`, its reviewed `-DiagnosticRunnerSha256`,
a fixed `-DiagnosticCase`, and a fresh `-OutputDirectory` in that experiment's
`runs` directory. `-Inspect` validates the selection without launching. A timing
runner can additionally require `-DiagnosticQualificationSha256` for its passed
functional prerequisite. The runner owns isolated data, input pins and the engine
guard; this route preserves the normal qualified play selection.

Profile mode selects Low/60 FPS at 1280×720, immediate campus drawing, and the
Garden, sustained Fire Bolt and sustained all-six Mantle cases, 15 seconds each.
The default Full observer retains `AllFixedSteps` detailed completed-step
attribution. The candidate's `-LightObserver` keeps those workload settings but
omits `AllFixedSteps` and detailed stage observation; the producer rejects their
combination. Light is valid only with `-Mode Profile`. `-Inspect` reports the
selected observer and `profile_all_fixed_steps` without launching.

Both modes wait for manual foreground Start and accept no extra game arguments.
Use fresh output directories and run them serially; reverse observer order in a
matched comparison. Their results are source diagnostics, not packaged FPS,
GPU/present timing, input latency or physical-player acceptance. Neither the
qualified d6d1 build nor this candidate inherits the older 6459
[source performance review](performance-evidence-20261014/foreground-6459-b/review.json).
Current-build foreground performance and portable FPS remain unmeasured.

Each output directory must be new. The wrapper validates the owned native window,
physical client dimensions, foreground state and paid workload as well as source
identity before and after. Preserve a failed admission check as failed evidence.
A configured 60 FPS limit and a 120 Hz
simulation are separate from measured presentation intervals.

The lower-level profiler supports longer soaks and alternative fixed cases for
engineering comparisons; on this PC, expose any such experiment explicitly
through the launcher before using it for a player/performance session. Sustained
cases do not refill resources or bypass cooldowns. Compare admitted
casts, active/idle intervals, visible-field draw costs, process/draw stages,
streaming counters and actual simulated ticks. A finite twelve-shot burst
followed by idle frames is not sustained pressure. Cold startup/travel rows
stay separate from warmed play. Match renderer, actual dimensions, quality,
observer mode, frame limit, focus and fixture route when comparing runs.
Report attempts, admissions and refusals separately: ordinary finite resources
can legitimately refuse some Mantle attempts. The
[historical smoothness evidence](smoothness-20261012/performance.md) separates the
qualified 845f baseline, intermediate 46fca full-observer comparison and
light-observer control. Court/world batching and its style memo were later
withdrawn after slower isolated native measurements; preserve those results
and qualify the resulting source separately. The final `p60-be680e20d70e`
foreground attempt expired before Start and recorded no gameplay cases;
its setup timeout and wrapper duration are not performance measurements.
That source's [clean Full regression](smoothness-20261012/full-final.json)
passed independently; it does not close the foreground-performance gate.
The newer [1e084 foreground record](iteration-20261012/foreground-current-record.json)
passes manual Start, exact client size, sampled focus and unchanged-source checks.
Its five-minute setup allowance gives the player time to start; measured focus
requirements are unchanged. Warm Garden/Fire/Mantle p95 engine intervals remain
29.420/49.174/51.784 ms, so this is not sustained 60 FPS acceptance. The
[October 12 ledger](iteration-20261012/README.md) owns that portable's Full/package status.
The [historical 500be source review](iteration-20261013/foreground-500be-allsteps/review.json)
reconciles every completed step with `-AllFixedSteps`: Garden/default-spawn
Fire/Mantle p95 intervals are 24.743/28.217/39.999 ms at ten seconds per warm case.
The older Fire route, duration and observer differ, so these are not matched
speedup measurements. The twelve-second sustained follow-up expired without
Start and never instantiated gameplay. Preserve its failure independently.
Newer source does not inherit these measurements. The
[October 13 iteration](iteration-20261013/README.md) preserves that earlier boundary;
the single queue and resume own current gates.
`-AllFixedSteps` records all successful catch-up work and zero-step groups;
it cannot be combined with `-LightObserver`. Compare its explicit observer cost,
failed-step counts and world/epoch continuity instead of treating a last-step
sample as the entire process cost.
`-ReferenceCampus` selects the immediate campus drawing path for an identical
workload comparison. The source profiler explicitly opts into retained drawing
otherwise. Ordinary game/portable launches keep immediate drawing; opt into the
unqualified experiment with `--retained-campus`. Full observation separately records retained-child draw work;
`-LightObserver` bounds instrumentation overhead. Neither a lower parent draw
timer nor equal simulation hashes establishes faster presented frames.

For isolated renderer work, require exact pixels against a frozen predecessor
for appearance-preserving changes and separate visual review for intended
simplification. Alternate measured callback order explicitly and verify the
actual order; moving scene-tree children alone does not establish redraw order.
Keep native helpers unchanged while queued/running and preserve their exact
executed bytes if a later scope correction is necessary. The
[presentation evidence](smoothness-20261012/experience.md) records bounded
actual-path trails, projectile/glyph submission costs and a paid sampled route;
its helper timings and declared sampling cadence are not measured gameplay FPS.

Packaged measurements must use the actual verified release executable. On this
PC, expose them through a reviewed desktop `-Mode Diagnostic` runner; do not
bypass the front door. The lower-level producer form for another Windows PC is:

```powershell
.\scripts\measure-portable.ps1 -PackDirectory exports/<RunId>/windows `
  -OutputDirectory .godot/portable-new-run `
  -Cases hearth,garden-entry,paid-fire-bolt,paid-all-six-mantle `
  -CloseAfterSeconds 45 -VisibleWindow
```

Replace `<RunId>` with the actual package folder. The optional normal-close mode
sends a close request only to its owned child, requires the application's safe-close
marker, and preserves strict warning/error and watchdog checks. Without
`-CloseAfterSeconds`, the existing engine-iteration limit remains the default.
Paid cases must record all twelve attempts and at least one admitted cast.
The emitted one-second FPS samples include finite casting and idle periods;
they are not frame-present intervals or sustained-load certification. The receipt
records focus observations and payload/helper hashes. Preserve failed exit-path
results alongside successful normal-close evidence.

`balance-audit` exercises all spell records and twenty ordinary paid scenarios.
The report reconciles direct, ground and status losses with target Health;
its six-second cast window plus three-second drain does not rank long-term DPS
or establish competitive balance. Signature, recovery, district-route and
admission-deadline regressions use their corresponding stable suite IDs. The
joined signature journey covers optional lessons, a real protected projectile
crossing, three district victories, saved rewards, reload and ordinary paid use.
Prepared passive fixtures exercise all 51 passives; their setup is not a claim
about how frequently those conditions arise in a match.

`current-world-replay` checks a bounded trusted-map snapshot plus exact commands,
per-tick hashes and the first divergence. Developer recording is optional, local
and limited to 60 seconds. Continuous cheats are refused; out-of-tick changes
stop recording. `network-impairment` uses actual two/eight-player ENet loopback
with injected delays, loss and outage; it does not replace a physical Internet test.

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
automatic update. The [qualified d6d1 archive](performance-evidence-20261014/stationary-qualification-d6d1/README.md)
separates that source, export, payload and normal-close qualification. The single
queue records candidate work; earlier checkpoints retain their original limits.

## Evidence and history

Keep runtime source, original assets, import recipes, required baked resources,
independent test oracles and useful passing/failing evidence. Remove a retired
producer or duplicate only after proving its dependency boundary and preserving
needed provenance. A filename containing `legacy`, `reference` or an old date
does not establish that it is unused.

The [single queue](../.agent/OVERHAUL-IMPLEMENTATION.md) owns current checks.
The [October 13 iteration](iteration-20261013/README.md) and
[October 12 checkpoint](iteration-20261012/README.md) retain their own frozen evidence.
The earlier [presentation checkpoint](presentation-checkpoint-20261011/README.md)
keeps its failed complete run and corrected focused run as historical evidence. The
[previous performance report](performance-implementation-20261010.md) links the be3
Full, native, package and visible-window receipts, including remaining
heavy-field/cold-loading limits. Those are measurements of frozen bytes, not
claims about a later source change.

The [exact earlier developer reference](archive/source-publication-20261011/DEVELOPMENT.md)
retains old Linux, 60 Hz, protocol-32 and harness notes for provenance. It is not
the current setup guide. Use the [documentation map](README.md) to find current
contracts instead of restarting historical implementation plans.
