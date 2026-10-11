$ErrorActionPreference = 'Stop'
$loomRoot = 'C:\Users\sende\Projects\hex'
if ((Get-Location).Path -ne $loomRoot) { throw 'HEX checkout required' }
$loomEvidence = 'docs/verification/hex-loom-availability-20260923'
$loomPack = Join-Path $loomRoot 'exports/hex-loom-availability-20260923-v2/windows/hex.pck'
& ./scripts/runtime-build-identity.ps1 -Mode Check -Json *> "$loomEvidence/identity-final-check.out"
& ./scripts/test.ps1 -Tier Full -ReceiptPath "$loomEvidence/full-v2.json" *> "$loomEvidence/full-v2.out"
Write-Output 'PASS: E1 frozen Full gate'
& ./scripts/package-hex.ps1 -RunId hex-loom-availability-20260923-v2 *> "$loomEvidence/package-v2.out"
Write-Output 'PASS: E1 Windows export, identity and native EXE launch/close'
& ./scripts/probe-hex.ps1 -RunId loom-availability-pck-v1 -Script (Join-Path $loomRoot 'tests/diagnostics/loom_availability_journey.gd') -PackPath $loomPack -Rendered -Output (Join-Path $loomRoot '.godot/loom-availability-pck-v1') *> "$loomEvidence/availability-pck-v1.out"
Write-Output 'PASS: E1 exact PCK availability journey and native captures'
& ./scripts/test-movement-cast-journey.ps1 -RunId loom-availability-pck-v1 -PackPath $loomPack *> "$loomEvidence/movement-pck-v1.out"
Write-Output 'PASS: E1 exact PCK movement and paid casting'
& ./scripts/test-movement-cast-journey.ps1 -RunId loom-availability-pck-v1 -PackPath $loomPack -Advanced *> "$loomEvidence/movement-advanced-pck-v1.out"
Write-Output 'PASS: E1 exact PCK advanced movement'
& ./scripts/test-loom-journey.ps1 -RunId loom-availability-pck-v1 -PackPath $loomPack -Restart *> "$loomEvidence/loom-pck-v1.out"
Write-Output 'PASS: E1 exact PCK Loom and separate-process persistence'
& ./scripts/probe-hex.ps1 -RunId loom-availability-water-pck-v1 -Script (Join-Path $loomRoot 'tests/visual/capture_water_pilot.gd') -PackPath $loomPack -Rendered -Output (Join-Path $loomRoot '.godot/water-loom-availability-pck-v1') *> "$loomEvidence/water-pck-v1.out"
Write-Output 'PASS: E1 exact PCK paid Water lifecycle'
& ./scripts/probe-hex.ps1 -RunId loom-availability-terrain-pck-v1 -Script (Join-Path $loomRoot 'tests/visual/capture_terrain_visibility.gd') -PackPath $loomPack -Rendered -Output (Join-Path $loomRoot '.godot/terrain-loom-availability-pck-v1') *> "$loomEvidence/terrain-pck-v1.out"
Write-Output 'PASS: E1 exact PCK terrain/visibility canaries'
