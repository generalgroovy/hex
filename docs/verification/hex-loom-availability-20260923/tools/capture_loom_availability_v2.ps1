$ErrorActionPreference = 'Stop'
$loomRoot = 'C:\Users\sende\Projects\hex'
if ((Get-Location).Path -ne $loomRoot) { throw 'HEX checkout required' }
$loomEvidence = 'docs/verification/hex-loom-availability-20260923'
& ./scripts/probe-hex.ps1 -RunId loom-availability-before-v2 -Script (Join-Path $loomRoot 'tests/diagnostics/loom_availability_journey.gd') -PackPath (Join-Path $loomRoot 'exports/hex-render-frame-20260923/windows/hex.pck') -Rendered -Output (Join-Path $loomRoot '.godot/loom-availability-before-v2') -ExtraArguments @('--baseline') *> "$loomEvidence/before-v2.out"
Write-Output 'PASS: corrected D6 baseline with positive refusal events'
& ./scripts/probe-hex.ps1 -RunId loom-availability-after-v2 -Script res://tests/diagnostics/loom_availability_journey.gd -Rendered -Output (Join-Path $loomRoot '.godot/loom-availability-after-v2') *> "$loomEvidence/after-v2.out"
Write-Output 'PASS: corrected E1 native source availability journey'
