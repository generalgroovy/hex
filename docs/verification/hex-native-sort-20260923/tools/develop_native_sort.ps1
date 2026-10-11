$ErrorActionPreference = 'Stop'
if ((Get-Location).Path -ne 'C:\Users\sende\Projects\hex') { throw 'HEX checkout required' }
if (@(Get-Process -Name hex,Godot* -ErrorAction SilentlyContinue).Count -gt 0) { throw 'An engine/game is running; preserve it' }
$sortEvidence = 'docs/verification/hex-native-sort-20260923'
& ./scripts/runtime-build-identity.ps1 -Mode Generate -Force -Json *> "$sortEvidence/identity-integration-v1.out"
python .godot/freeze_native_integration.py
if ($LASTEXITCODE -ne 0) { throw 'Integration freeze failed' }
& ./scripts/test.ps1 -Tier Focused -Suite @('hex-hash-specialization','hex-canonical-sort','hex-snapshot-optimization','hex-world-snapshot','hex-chemistry-snapshot','unified-prediction','unified-reconciliation-order','replay') -ReceiptPath "$sortEvidence/focused-v1.json" *> "$sortEvidence/focused-v1.out"
Write-Output 'PASS: D9 focused production hash/snapshot/replay checks'
& ./scripts/probe-hex.ps1 -RunId native-sort-integrated-v1 -Script res://tests/performance/profile_hex_native_sort_integrated.gd -Output res://.godot/hex-native-sort-candidate-integrated-v1.json *> "$sortEvidence/integrated-v1.out"
Write-Output 'PASS: D9 actual integrated public hash measurement'
& ./scripts/probe-hex.ps1 -RunId native-sort-stages-v1 -Script res://tests/performance/profile_hex_snapshot_stages.gd -Output res://.godot/hex-snapshot-stages-native-sort-v1.json *> "$sortEvidence/stages-v1.out"
Write-Output 'PASS: D9 unchanged paid snapshot-stage probe'
