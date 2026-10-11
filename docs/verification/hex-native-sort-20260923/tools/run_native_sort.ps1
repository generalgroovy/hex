param([ValidateSet('v1','v2','v3')][string]$Version = 'v1')
$ErrorActionPreference = 'Stop'
if ((Get-Location).Path -ne 'C:\Users\sende\Projects\hex') { throw 'HEX checkout required' }
$sortProcesses = @(Get-Process -Name hex,Godot* -ErrorAction SilentlyContinue)
if ($sortProcesses.Count -gt 0) { throw 'An engine/game is running; preserve it and defer profiling' }
$sortEvidence = 'docs/verification/hex-native-sort-20260923'
python .godot/freeze_native_sort.py $Version
if ($LASTEXITCODE -ne 0) { throw 'Candidate freeze failed' }
& ./scripts/probe-hex.ps1 -RunId "native-sort-candidate-$Version" -Script res://tests/performance/profile_hex_native_sort_candidate.gd -Output "res://.godot/hex-native-sort-candidate-$Version.json" *> "$sortEvidence/probe-$Version.out"
Write-Output "PASS: D9 native-sort candidate $Version"
