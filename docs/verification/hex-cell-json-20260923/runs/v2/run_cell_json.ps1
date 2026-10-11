param([ValidateSet('v1','v2','v3')][string]$Version = 'v1')
$ErrorActionPreference = 'Stop'
if ((Get-Location).Path -ne 'C:\Users\sende\Projects\hex') { throw 'HEX checkout required' }
if (@(Get-Process -Name hex,Godot* -ErrorAction SilentlyContinue).Count -gt 0) { throw 'An engine/game is running; preserve it and defer profiling' }
$cellJsonEvidence = 'docs/verification/hex-cell-json-20260923'
python .godot/freeze_cell_json.py $Version
if ($LASTEXITCODE -ne 0) { throw 'Candidate freeze failed' }
& ./scripts/probe-hex.ps1 -RunId "cell-json-candidate-$Version" -Script res://tests/performance/profile_hex_cell_json_candidate.gd -Output "res://.godot/hex-cell-json-candidate-$Version.json" *> "$cellJsonEvidence/probe-$Version.out"
Write-Output "PASS: D10 cell JSON candidate $Version"
