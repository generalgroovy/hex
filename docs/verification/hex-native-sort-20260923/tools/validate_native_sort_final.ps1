$ErrorActionPreference = 'Stop'
$sortRoot = 'C:\Users\sende\Projects\hex'
if ((Get-Location).Path -ne $sortRoot) { throw 'HEX checkout required' }
$sortEvidence = 'docs/verification/hex-native-sort-20260923'
$sortPack = Join-Path $sortRoot 'exports/hex-native-sort-20260923/windows/hex.pck'
function Assert-SortEngineIdle {
    if (@(Get-Process -Name hex,Godot* -ErrorAction SilentlyContinue).Count -gt 0) { throw 'An engine/game is running; preserve it and defer this phase' }
}
Assert-SortEngineIdle
& ./scripts/runtime-build-identity.ps1 -Mode Check -Json *> "$sortEvidence/identity-final-check.out"
& ./scripts/test.ps1 -Tier Full -ReceiptPath "$sortEvidence/full-v1.json" *> "$sortEvidence/full-v1.out"
Write-Output 'PASS: D9 frozen Full integration gate'
Assert-SortEngineIdle
& ./scripts/probe-hex.ps1 -RunId native-sort-stress-v1 -Script res://tests/performance/profile_unified_wellspring_rendered.gd -Rendered -Output res://.godot/unified-wellspring-render-profile-native-sort-v1.json *> "$sortEvidence/rendered-stress-v1.out"
Write-Output 'COMPLETE: D9 evolving rendered stress; timing acceptance separate'
Assert-SortEngineIdle
& ./scripts/package-hex.ps1 -RunId hex-native-sort-20260923 *> "$sortEvidence/package-v1.out"
Write-Output 'PASS: D9 Windows export, registry, exact EXE identity/launch/close'
Assert-SortEngineIdle
& ./scripts/probe-hex.ps1 -RunId native-sort-gallery-pck-v1 -Script (Join-Path $sortRoot '.godot/gallery_pose_control.gd') -PackPath $sortPack -Rendered -Output (Join-Path $sortRoot '.godot/gallery-native-sort-pck-v1') *> "$sortEvidence/gallery-pck-v1.out"
Write-Output 'PASS: D9 exact PCK Gallery fixed-pose journey'
Assert-SortEngineIdle
& ./scripts/probe-hex.ps1 -RunId native-sort-character-pck-v1 -Script (Join-Path $sortRoot 'tests/diagnostics/loom_character_journey.gd') -PackPath $sortPack -Rendered -Output (Join-Path $sortRoot '.godot/character-native-sort-pck-v1.json') *> "$sortEvidence/character-pck-v1.out"
Write-Output 'PASS: D9 exact PCK character switch/return/custom weave'
Assert-SortEngineIdle
& ./scripts/test-movement-cast-journey.ps1 -RunId native-sort-pck-v1 -PackPath $sortPack *> "$sortEvidence/movement-pck-v1.out"
Write-Output 'PASS: D9 exact PCK movement and paid casting'
Assert-SortEngineIdle
& ./scripts/test-movement-cast-journey.ps1 -RunId native-sort-pck-v1 -PackPath $sortPack -Advanced *> "$sortEvidence/movement-advanced-pck-v1.out"
Write-Output 'PASS: D9 exact PCK advanced movement'
Assert-SortEngineIdle
& ./scripts/test-loom-journey.ps1 -RunId native-sort-pck-v1 -PackPath $sortPack -Restart *> "$sortEvidence/loom-pck-v1.out"
Write-Output 'PASS: D9 exact PCK Loom and separate-process persistence'
Assert-SortEngineIdle
& ./scripts/probe-hex.ps1 -RunId native-sort-water-pck-v1 -Script (Join-Path $sortRoot 'tests/visual/capture_water_pilot.gd') -PackPath $sortPack -Rendered -Output (Join-Path $sortRoot '.godot/water-native-sort-pck-v1') *> "$sortEvidence/water-pck-v1.out"
Write-Output 'PASS: D9 exact PCK paid Water lifecycle'
Assert-SortEngineIdle
& ./scripts/probe-hex.ps1 -RunId native-sort-terrain-pck-v1 -Script (Join-Path $sortRoot 'tests/visual/capture_terrain_visibility.gd') -PackPath $sortPack -Rendered -Output (Join-Path $sortRoot '.godot/terrain-native-sort-pck-v1') *> "$sortEvidence/terrain-pck-v1.out"
Write-Output 'PASS: D9 exact PCK terrain/visibility'
