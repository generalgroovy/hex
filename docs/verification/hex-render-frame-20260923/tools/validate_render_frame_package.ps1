$ErrorActionPreference = 'Stop'
$frameRoot = 'C:\Users\sende\Projects\hex'
if ((Get-Location).Path -ne $frameRoot) { throw 'HEX checkout required' }
$frameEvidence = Join-Path $frameRoot 'docs/verification/hex-render-frame-20260923'
$framePack = Join-Path $frameRoot 'exports/hex-render-frame-20260923/windows/hex.pck'

& ./scripts/package-hex.ps1 -RunId hex-render-frame-20260923 *> (Join-Path $frameEvidence 'package-v1.out')
Write-Output 'PASS: package/identity/native launch and safe close'
& ./scripts/test-movement-cast-journey.ps1 -RunId render-frame-pck-v1 -PackPath $framePack *> (Join-Path $frameEvidence 'movement-pck-v1.out')
Write-Output 'PASS: exact PCK basic movement and paid casting'
& ./scripts/test-movement-cast-journey.ps1 -RunId render-frame-pck-v1 -PackPath $framePack -Advanced *> (Join-Path $frameEvidence 'movement-advanced-pck-v1.out')
Write-Output 'PASS: exact PCK earned advanced movement'
& ./scripts/test-loom-journey.ps1 -RunId render-frame-pck-v1 -PackPath $framePack -Restart *> (Join-Path $frameEvidence 'loom-pck-v1.out')
Write-Output 'PASS: exact PCK Loom and separate-process persistence'
& ./scripts/probe-hex.ps1 -RunId render-frame-water-pck-v1 -Script (Join-Path $frameRoot 'tests/visual/capture_water_pilot.gd') -PackPath $framePack -Rendered -Output (Join-Path $frameRoot '.godot/water-render-frame-pck-v1') *> (Join-Path $frameEvidence 'water-pck-v1.out')
Write-Output 'PASS: exact PCK paid Water lifecycle capture'
& ./scripts/probe-hex.ps1 -RunId render-frame-station-pck-v1 -Script (Join-Path $frameRoot 'tests/visual/capture_station_fog_labels.gd') -PackPath $framePack -Rendered -Output (Join-Path $frameRoot '.godot/station-labels-render-frame-pck-v1') *> (Join-Path $frameEvidence 'station-pck-v1.out')
Write-Output 'PASS: exact PCK station fog labels'
& ./scripts/probe-hex.ps1 -RunId render-frame-terrain-pck-v1 -Script (Join-Path $frameRoot 'tests/visual/capture_terrain_visibility.gd') -PackPath $framePack -Rendered -Output (Join-Path $frameRoot '.godot/terrain-render-frame-pck-v1') *> (Join-Path $frameEvidence 'terrain-pck-v1.out')
Write-Output 'PASS: exact PCK visibility canaries'
