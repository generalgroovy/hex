$ErrorActionPreference = 'Stop'
if ((Get-Location).Path -ne 'C:\Users\sende\Projects\hex') { throw 'HEX checkout required' }
$galleryEvidence = 'docs/verification/hex-gallery-availability-20260923'
& ./scripts/runtime-build-identity.ps1 -Mode Generate -Force -Json *> "$galleryEvidence/identity-development-v1.out"
python .godot/freeze_gallery_availability.py development-v1
if ($LASTEXITCODE -ne 0) { throw 'Freeze failed' }
& ./scripts/test.ps1 -Tier Focused -Suite @('character-selection-grid','character-selection-model','character-gallery-integration','session-request-policy','weave-acknowledgement') -ReceiptPath "$galleryEvidence/focused-v1.json" *> "$galleryEvidence/focused-v1.out"
Write-Output 'PASS: E2 Focused checks'
& ./scripts/probe-hex.ps1 -RunId gallery-availability-after-v1 -Script res://tests/diagnostics/gallery_availability_journey.gd -Rendered -Output C:\Users\sende\Projects\hex\.godot\gallery-availability-after-v1 *> "$galleryEvidence/after-v1.out"
Write-Output 'PASS: E2 source native Gallery journey'
