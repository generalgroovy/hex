# Shared wireframe melee v1 candidate

This ignored directory prepares one bounded reusable melee-pose candidate for the shared warm-adventurer body. It does not modify a live atlas, runtime manifest, presenter, simulation, named skin, or gameplay timing.

The matrix is fixed at 720 frames: three body sizes, eight latched aim headings, five relative lower-body stances, Punch and Kick, and startup/active/recovery. The five stances are idle, forward, right strafe, backward, and left strafe relative to aim. Moving stances use W2 locomotion phase zero, where both feet are on the ground, as the stable key poses for freely movable attacks. Runtime animation selects the current travel-to-aim relationship independently from attack phase.

`export_rig.gd` reads the current `wireframe_motion_v2/rig-data.json`. Punch changes both arm chains, with the right arm striking and the left arm guarding. Kick changes the right leg and both guarding arms. Every changed limb is solved through `template_v2/pose_guide_model.gd::two_bone`; the exporter asserts all ten limb-bone lengths for every pose. Torso, head, face direction, costume geometry, gait support leg, and the 48/84 registration pivot remain shared W2 data.

`build_candidate.py` imports the existing W2 Pillow rasterizer and its warm-adventurer palette. It bakes three transparent 768x2880 pages with eight direction columns and thirty rows. It checks all 7,200 bones, binary alpha, palette-only nontransparent pixels, exact 58/63/68 visible heights, the shared feet pivot, distinct phases, and distinct active Punch/Kick silhouettes. It writes only this directory.

## Proposed physical-state input

The eventual presenter needs these authoritative fields from the simulation snapshot:

- `physical_kind`: `0` none, `1` Punch, `2` Kick.
- `physical_phase`: `0` none, `1` startup, `2` active, `3` recovery.
- `physical_phase_ticks_remaining` and `physical_phase_ticks_total`: integer timing used to select or blend within an authored phase. This candidate has one key pose per phase and needs no independent presentation clock.
- `physical_aim_x` and `physical_aim_y`: signed fixed-world components latched when the physical sequence begins. Presentation quantizes this pair to one of the existing eight headings and never follows later pointer drift.
- `physical_sequence_id`: monotonic per actor, allowing presentation history to reset exactly once for a new action.

Attacks remain freely movable. The presenter chooses the stored idle/forward/right/back/left stance from the current travel-versus-aim relationship while retaining the latched attack aim. Paid slide, roll, air-dodge, and wall-jump may interrupt the physical chain; that interrupt policy belongs to simulation and must not turn into a free cancel back into attack spam. The candidate supplies pose keys only and does not decide locomotion or cancellation legality.

## Root-only serialized export and offline bake

Run from the checkout root after the current serialized engine lane is free. Use a new log name for every attempt:

```powershell
$ErrorActionPreference = 'Stop'
. .\scripts\flux2-common.ps1
$repo = Get-FluxRepoRoot
$runId = 'v1' # change for every attempt
$runRoot = Join-Path $repo ('.godot/wireframe-melee-' + $runId)
if (Test-Path -LiteralPath $runRoot) { throw "Use a new melee run id: $runId" }
New-Item -ItemType Directory -Path $runRoot | Out-Null
$lease = Enter-FluxEngineRun 'wireframe-melee-v1-export'
$savedMeleeAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $runRoot 'appdata'
    New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
    $log = Join-Path $runRoot 'export.log'
    Invoke-FluxGodotChecked (Get-FluxGodot) @(
        '--headless', '--path', $repo,
        '--script', 'res://art_batches/character_style_v1/wireframe_melee_v1/export_rig.gd'
    ) $log -RejectWarnings
} finally {
    $env:APPDATA = $savedMeleeAppData
    Exit-FluxEngineRun $lease
}
python .\art_batches\character_style_v1\wireframe_melee_v1\build_candidate.py
if ($LASTEXITCODE -ne 0) { throw "Melee candidate bake failed with exit $LASTEXITCODE" }
```

`Invoke-FluxGodotChecked` acquires a nested lease under the explicit outer checkout mutex; this is supported by `scripts/engine-guard.ps1`. The Python bake begins only after the exporter succeeds and the outer lease is released.

## Review gate

The bake produces dark and light native-size review boards for each body, plus a middle-body board covering all five relative stances. Root should inspect those boards and the three raw pages before considering any live integration. Required image review checks are:

1. Punch startup reads as a rearward load, active as a forward hand strike, and recovery as a guarded return in all eight aims.
2. Kick startup reads as a chamber, active as a forward leg extension, and recovery as a retraction in all eight aims.
3. Small, middle, and large retain visibly consistent anatomy at exact 58, 63, and 68 pixel standing heights.
4. Idle, forward, right strafe, backward, and left strafe retain independent lower-body direction while head and chest stay on latched aim; moving composition remains foot-stable when runtime advances travel.
5. Feet do not slide below the shared pivot, limbs do not clip a 96x96 cell, rear headings do not acquire false faces, and no magic or element-colored pixels appear.
6. Startup/active/recovery silhouettes are distinct at native size on both light and dark backgrounds.

The prepared source has not been run through Godot, baked, imported, captured, or human-approved. A successful Python bake would establish offline raster and invariant checks only. Native import, in-game composition, timing, moving foot stability, interrupt behavior, readability during combat, and promotion would remain separate root-owned gates.
