$ErrorActionPreference = 'Stop'
$hashRoot = 'C:\Users\sende\Projects\hex'
if ((Get-Location).Path -ne $hashRoot) { throw 'HEX checkout required' }
$hashEvidence = Join-Path $hashRoot 'docs/verification/hex-hash-20260923'
$hashPack = Join-Path $hashRoot 'exports/hex-hash-20260923/windows/hex.pck'

& ./scripts/package-hex.ps1 -RunId hex-hash-20260923 *> (Join-Path $hashEvidence 'package-v1.out')
Write-Output 'PASS: package/identity/native launch and safe close'
& ./scripts/test-movement-cast-journey.ps1 -RunId hash-pck-v1 -PackPath $hashPack *> (Join-Path $hashEvidence 'movement-pck-v1.out')
Write-Output 'PASS: exact PCK basic movement and paid casting'
& ./scripts/test-movement-cast-journey.ps1 -RunId hash-pck-v1 -PackPath $hashPack -Advanced *> (Join-Path $hashEvidence 'movement-advanced-pck-v1.out')
Write-Output 'PASS: exact PCK earned advanced movement'
& ./scripts/test-loom-journey.ps1 -RunId hash-pck-v1 -PackPath $hashPack -Restart *> (Join-Path $hashEvidence 'loom-pck-v1.out')
Write-Output 'PASS: exact PCK Loom and separate-process persistence'
& ./scripts/probe-hex.ps1 -RunId hash-water-pck-v1 -Script (Join-Path $hashRoot 'tests/visual/capture_water_pilot.gd') -PackPath $hashPack -Rendered -Output (Join-Path $hashRoot '.godot/water-hash-pck-v1') *> (Join-Path $hashEvidence 'water-pck-v1.out')
Write-Output 'PASS: exact PCK paid Water lifecycle capture'
& ./scripts/probe-hex.ps1 -RunId hash-station-pck-v1 -Script (Join-Path $hashRoot 'tests/visual/capture_station_fog_labels.gd') -PackPath $hashPack -Rendered -Output (Join-Path $hashRoot '.godot/station-labels-hash-pck-v1') *> (Join-Path $hashEvidence 'station-pck-v1.out')
Write-Output 'PASS: exact PCK station fog labels'
& ./scripts/probe-hex.ps1 -RunId hash-terrain-pck-v1 -Script (Join-Path $hashRoot 'tests/visual/capture_terrain_visibility.gd') -PackPath $hashPack -Rendered -Output (Join-Path $hashRoot '.godot/terrain-hash-pck-v1') *> (Join-Path $hashEvidence 'terrain-pck-v1.out')
Write-Output 'PASS: exact PCK visibility canaries'
