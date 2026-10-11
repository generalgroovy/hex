$ErrorActionPreference = 'Stop'
$galleryRoot = 'C:\Users\sende\Projects\hex'
if ((Get-Location).Path -ne $galleryRoot) { throw 'HEX checkout required' }
$galleryEvidence = 'docs/verification/hex-gallery-availability-20260923'
$galleryPack = Join-Path $galleryRoot 'exports/hex-gallery-availability-20260923/windows/hex.pck'
& ./scripts/runtime-build-identity.ps1 -Mode Check -Json *> "$galleryEvidence/identity-final-check.out"
& ./scripts/test.ps1 -Tier Full -ReceiptPath "$galleryEvidence/full-v1.json" *> "$galleryEvidence/full-v1.out"
Write-Output 'PASS: E2 frozen Full'
& ./scripts/package-hex.ps1 -RunId hex-gallery-availability-20260923 *> "$galleryEvidence/package-v1.out"
Write-Output 'PASS: E2 export, registry, exact EXE launch/close'
& ./scripts/probe-hex.ps1 -RunId gallery-availability-pck-v1 -Script (Join-Path $galleryRoot 'tests/diagnostics/gallery_availability_journey.gd') -PackPath $galleryPack -Rendered -Output (Join-Path $galleryRoot '.godot/gallery-availability-pck-v1') *> "$galleryEvidence/availability-pck-v1.out"
Write-Output 'PASS: E2 exact PCK Gallery availability'
& ./scripts/probe-hex.ps1 -RunId gallery-availability-character-pck-v1 -Script (Join-Path $galleryRoot 'tests/diagnostics/loom_character_journey.gd') -PackPath $galleryPack -Rendered -Output (Join-Path $galleryRoot '.godot/gallery-character-pck-v1.json') *> "$galleryEvidence/character-pck-v1.out"
Write-Output 'PASS: E2 exact PCK character switch/return/custom weave'
& ./scripts/test-movement-cast-journey.ps1 -RunId gallery-availability-pck-v1 -PackPath $galleryPack *> "$galleryEvidence/movement-pck-v1.out"
Write-Output 'PASS: E2 exact PCK movement and paid casting'
& ./scripts/test-movement-cast-journey.ps1 -RunId gallery-availability-pck-v1 -PackPath $galleryPack -Advanced *> "$galleryEvidence/movement-advanced-pck-v1.out"
Write-Output 'PASS: E2 exact PCK advanced movement'
& ./scripts/test-loom-journey.ps1 -RunId gallery-availability-pck-v1 -PackPath $galleryPack -Restart *> "$galleryEvidence/loom-pck-v1.out"
Write-Output 'PASS: E2 exact PCK Loom and separate-process persistence'
& ./scripts/probe-hex.ps1 -RunId gallery-availability-water-pck-v1 -Script (Join-Path $galleryRoot 'tests/visual/capture_water_pilot.gd') -PackPath $galleryPack -Rendered -Output (Join-Path $galleryRoot '.godot/water-gallery-availability-pck-v1') *> "$galleryEvidence/water-pck-v1.out"
Write-Output 'PASS: E2 exact PCK paid Water lifecycle'
& ./scripts/probe-hex.ps1 -RunId gallery-availability-terrain-pck-v1 -Script (Join-Path $galleryRoot 'tests/visual/capture_terrain_visibility.gd') -PackPath $galleryPack -Rendered -Output (Join-Path $galleryRoot '.godot/terrain-gallery-availability-pck-v1') *> "$galleryEvidence/terrain-pck-v1.out"
Write-Output 'PASS: E2 exact PCK terrain/visibility'
