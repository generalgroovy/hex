$ErrorActionPreference = 'Stop'
if ((Get-Location).Path -ne 'C:\Users\sende\Projects\hex') { throw 'HEX checkout required' }
$loomEvidence = 'docs/verification/hex-loom-availability-20260923'
& ./scripts/runtime-build-identity.ps1 -Mode Generate -Force -Json *> "$loomEvidence/identity-development-v1.out"
& ./scripts/runtime-build-identity.ps1 -Mode Check -Json *> "$loomEvidence/identity-check-development-v1.out"
& ./scripts/test.ps1 -Tier Focused -Suite @('spell-loom-editor','character-weave-policy','character-weave-integration','weave-acknowledgement','session-request-policy') -ReceiptPath "$loomEvidence/focused-v1.json" *> "$loomEvidence/focused-v1.out"
Write-Output 'PASS: E1 Focused development checks'
& ./scripts/probe-hex.ps1 -RunId loom-availability-after-v1 -Script res://tests/diagnostics/loom_availability_journey.gd -Rendered -Output C:\Users\sende\Projects\hex\.godot\loom-availability-after-v1 *> "$loomEvidence/after-v1.out"
Write-Output 'PASS: E1 source native UI journey'
