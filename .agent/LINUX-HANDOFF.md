# H.E.X. Linux CLI handoff — October 15, 2026

Current status updated **October 16, 2026**.

Historical publication checkpoint: `aec900a` on the presentation branch. The user
subsequently resumed Windows product work on `codex/hex-breakthrough-20261015`.
This handoff still restores the published baseline; read the current branch's
[resume](HEX-RESUME.md) and [single queue](OVERHAUL-IMPLEMENTATION.md) before
coordinating new work across computers. Do not assume the two branches are identical.

At the published `aec900a` handoff, Windows work had stopped at a stable
documentation checkpoint after the three agents completed their audits and
reciprocal reviews. That historical pause does not describe the later local
candidate work. **p61-6618873387e2** now passed clean Windows source Full,
but is **not packaged or promoted**. The earlier local
[Full-a](../docs/breakthrough-evidence-20261015/full-a/tests.json) remains failed:
112 of 267 suites, 5,280,932 assertions and nine failures before the
2,700-second timeout; 155 suites incomplete and boot not run. Three test-only
follow-ups were applied; seven-suite `focused-review-a` passed **65,133 / 0**
in **264,217 ms**, with empty stderr. Separate outage A/B passed **6,478 / 0**
and **6,465 / 0**, each with 241 trace rows; its historical capture cause
remains unresolved.
Pushed commit **932f5974fe17a8d2432d8f82873eb86faf564543** on
`codex/hex-breakthrough-20261015` passed [Windows CI Full 38817305452](https://github.com/generalgroovy/hex/actions/runs/38817305452):
**267 suites / 7,576,123 assertions / zero failures**, three empty stderr files
and correct **661887 / 120 Hz / protocol 61** boot; [independent CI review](../docs/breakthrough-evidence-20261015/ci-full-38817305452/independent-review.json).
This validates the clean Windows source checkout, not a Linux checkout or a
replacement package. Selected desktop d6d1 and its fallbacks are preserved.
Agents are not live processes to migrate; recreate
bounded workers in the receiving CLI.

## Restore from Git

Repository: https://github.com/generalgroovy/hex.git
Historical baseline branch: `codex/hex-screen-smoothness-20261011`
Current candidate branch: `codex/hex-breakthrough-20261015`, source checkpoint `932f597`
Pre-handoff base: `38f1bc3a130eba66e4bd174128311289a94b738a`

The user authorized publishing the complete checkpoint on this branch: current
source, art manifests, tests, launcher tools, qualification evidence, design and
handoff instructions. The commit containing this document replaces the earlier
ZIP-overlay transfer route. **Do not apply the older overlay over this Git
checkpoint.** `main` and the qualified Windows playable selection are unchanged.

The commands below deliberately restore the historical baseline. To continue
the pushed candidate instead, use `codex/hex-breakthrough-20261015` in the same
clone/fetch/switch procedure and verify checkpoint `932f597` or a later explicitly
reported commit. Neither branch provides qualified native Linux evidence.

For a new Linux checkout, choose an unused destination:

```bash
git clone --branch codex/hex-screen-smoothness-20261011 --single-branch https://github.com/generalgroovy/hex.git hex-linux
cd hex-linux
git status --short
git log -1 --format='%H %s'
```

For an existing checkout, first inspect `git status --short` and preserve any
local work. Only in a clean checkout, fetch, switch to the handoff branch and
fast-forward it:

```bash
git fetch origin
git switch codex/hex-screen-smoothness-20261011
git pull --ff-only origin codex/hex-screen-smoothness-20261011
git status --short
git log -1 --format='%H %s'
```

If the branch is not local yet, use
`git switch --track origin/codex/hex-screen-smoothness-20261011` instead of the
plain switch. If work is dirty or histories diverge, use a separate fresh clone;
do not reset, clean, stash automatically or overwrite it. Compare the resulting
commit to the exact published SHA supplied by the sending agent. A later commit
needs its own review; the old base alone is not this checkpoint.

Git contains the required project assets and archived evidence. Local exported
Windows packages, Godot caches, personal saves, Codex credentials/session stores
and original image generation output outside the repository remain on Windows.
The archived evidence describes its original Windows environment. Cloning does
not install Godot, provide a prebuilt Linux game or migrate the live conversation.

## Read in order

1. This file, then [resume](HEX-RESUME.md) for exact current state and limits.
2. [Single queue](OVERHAUL-IMPLEMENTATION.md).
3. [Complete overhaul design](../docs/OVERHAUL-DESIGN-20261015.md).
4. [Implemented contract](../SPECIFICATION.md), [design overview](../docs/CORE-GAME-DESIGN.md)
   and [development guide](../docs/DEVELOPMENT.md).

The user chose **illustrated 2.5D with smooth animated sprites**. Their requested
overhaul covers professional/charming natural art; complete smooth motion;
circular glowing, distinguishable projectiles; truthful AoE rules; all map/practice
walls and buildings at least twice the approved largest standing sprite height;
self visibility without hidden-enemy information; genuine purposeful interiors;
compact relevant menus, optional teaching and plug-and-play delivery.

The October 15 deliverable is a cross-reviewed design, not implemented overhaul
code. Its next implementation stages are baseline/contracts, then one integrated
pilot with three representative character sizes/anatomies, all delivery motifs,
six elements, one tall enterable building, cutaways, HUD and a short lesson.
Keep future rules changes, such as simultaneous finite-AoE allocation, explicitly
separate from visual-only changes and version/migrate them appropriately.

## Current runnable state and evidence

Qualified Windows local portable: **p61-d6d1bfb9c529**, runtime SHA
`d6d1bfb9c5292d8dffbeade6e1cf460cd3a23ee54a655da7069d75e4cb572d44`.
Protocol 61 / snapshot 24; 120 Hz simulation / 60 Hz transport.
Immediate qualified fallback: **p61-64590c45c7a5**.
Full: 265 suites / 7,574,524 assertions; portable/terrain/lifecycle and independent
delivery review passed. Details are linked from the resume.

Current-build foreground performance and portable FPS are **unmeasured**. The
6–11% stationary optimization result is isolated whole-simulation-step timing,
not FPS. The 6459 full-observer recording is historical and had substantial host
memory pressure. Preserve withdrawn experiments; do not revive them speculatively.
Source Full/Light observer calibration remains pending and is distinct from
packaged presented-frame measurement. Linux results do not qualify Windows GPU,
launcher, focus, physical-input or frame-pacing acceptance.

## Work rules on Linux

- Preserve dirty work, source/art originals, saves, fallbacks and useful failed
  evidence. No reset/clean/force-push or blanket cleanup. Keep one active queue.
- Each domain has an implementer and an independent reviewer. Root integrates
  and serializes Godot/import/test/capture/export processes; parallel agents can
  read, design and edit disjoint files within the agreed contracts.
- Use launcher paths for all game sessions. Windows uses the desktop wrapper
  at `C:/Users/sende/Documents/ChatGPT/H.E.X/PLAY-HEX.cmd`; that Windows shortcut
  cannot be invoked natively on this separate Linux computer. Inspect existing
  Linux scripts and qualify a platform-appropriate launcher with equivalent
  production defaults before Linux player sessions. Do not silently launch a
  different presentation mode via a direct executable.
- Inspect pinned Godot/tool versions and existing Linux doctor/test scripts
  before running them. Do not assume historical FLUX Linux support qualifies
  current H.E.X. or replace platform-specific evidence with Linux results.
  The existing `scripts/run.sh`, `doctor.sh`, `test.sh` and `install-godot.sh`
  are stored with CRLF and mode `100644`. Review and repair Linux script line
  endings and invocation/permissions before native use. Keep that platform repair
  separate from production source and archived evidence; do not bulk-normalize
  the repository, whose qualified inputs preserve exact bytes.
- The user requires stopping **before 20,000 credits remain**. Last observed
  account balance was 43,756.065178, not a guaranteed current balance. Recheck at
  stage boundaries. If the CLI cannot read credit balance, do not claim automatic
  enforcement: ask the user to monitor it and avoid an unattended long run.
- This checkpoint's Git publication is authorized. Future changes still require
  their own scope and validation; restoring it does not authorize a binary release,
  a new qualified Windows pointer or claims of new runtime acceptance.

## Receiving prompt

Resume H.E.X. from this Git handoff. First verify the published commit and clean checkout,
read the documents above, inspect the Linux checkout/tooling, and summarize the
restored state plus the next bounded stage. Recreate Gameplay, Experience and
Technical workers with independent cross-review. Preserve the selected visual
direction and all constraints. Do not repeat completed research or claim the new
overhaul is implemented. Establish the Linux launcher/validation boundary and
retain Windows-specific qualification gaps. Wait for the user's instruction to
begin the next implementation stage after reporting restoration.
