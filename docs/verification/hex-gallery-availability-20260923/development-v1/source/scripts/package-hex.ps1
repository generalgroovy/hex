param([ValidatePattern('^[a-z0-9-]+$')][string]$RunId = ('hex-' + (Get-Date -Format 'yyyyMMdd-HHmmss')))
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$hexLease = Enter-FluxEngineRun 'package-hex-portable'
$hexSavedAppData = $env:APPDATA
try {
 $hexRoot=Get-FluxRepoRoot
 $hexOutput=Join-Path $hexRoot "exports/$RunId"
 if(Test-Path -LiteralPath $hexOutput){throw 'Fresh export RunId required; existing builds are preserved'}
 & (Join-Path $PSScriptRoot 'doctor.ps1') -RequireExportTemplates -ExportTarget Windows
 & (Join-Path $PSScriptRoot 'runtime-build-identity.ps1') -Mode Check
 $hexIdentity=Get-Content (Join-Path $hexRoot 'content/runtime/runtime_build_identity_v1.json') -Raw | ConvertFrom-Json
 $hexPayload=Join-Path $hexOutput 'windows'
 $hexLogs=Join-Path $hexOutput 'logs'
 New-Item -ItemType Directory -Path $hexPayload,$hexLogs | Out-Null
 $hexExe=Join-Path $hexPayload 'hex.exe'
 Invoke-FluxGodotChecked (Get-FluxGodot) @('--headless','--path',$hexRoot,'--export-release','Windows x86_64',$hexExe) (Join-Path $hexLogs 'export.log') -RejectWarnings -TimeoutSeconds 900 | Out-Null
 # Export may rescan scripts after the Full gate; require canonical class paths
 # again before trying to boot a package that excludes evidence directories.
 & (Join-Path $PSScriptRoot 'check-script-class-cache.ps1') -Json | Set-Content -LiteralPath (Join-Path $hexLogs 'script-class-cache.json')
 $env:APPDATA=Join-Path $hexLogs 'isolated-roaming'
 New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
 & (Join-Path $PSScriptRoot 'runtime-state.ps1') -PackPath (Join-Path $hexPayload 'hex.pck') -OutputPath (Join-Path $hexPayload 'BUILD-STATE.json')
 Push-Location -LiteralPath $hexPayload
 try { Invoke-FluxGodotChecked $hexExe @('--windowed','--resolution','1280x720','--','--safe-quit-smoke','--no-lan-discovery') (Join-Path $hexLogs 'export-smoke.log') -RejectWarnings -TimeoutSeconds 120 | Out-Null } finally { Pop-Location }
 $hexSmoke=Get-Content (Join-Path $hexLogs 'export-smoke.log') -Raw
 if(-not $hexSmoke.Contains($hexIdentity.build_id) -or -not $hexSmoke.Contains('safe quit: local state flushed and network peer closed')) {throw 'Export did not prove expected identity and safe close'}
 [IO.File]::WriteAllText((Join-Path $hexPayload 'PLAY-HEX.cmd'), "@echo off`r`ncd /d `"%~dp0`"`r`nstart `"H.E.X.`" `"%~dp0hex.exe`" -- %*`r`n", [Text.UTF8Encoding]::new($false))
 Copy-Item -LiteralPath (Join-Path $hexRoot 'content/runtime/runtime_build_identity_v1.json') -Destination (Join-Path $hexPayload 'SOURCE-IDENTITY.json')
 [IO.File]::WriteAllText((Join-Path $hexPayload 'README-FIRST.txt'), "H.E.X. $($hexIdentity.build_id)`r`nOpen PLAY-HEX.cmd. Keep hex.exe and hex.pck together.`r`nLOCAL SOLO TEST CANDIDATE. The broader player-interface/asset acceptance milestone is incomplete.`r`nMultiplayer is EXPERIMENTAL: the previous same-export lifecycle FAILED with resource/allocation errors under its unchanged300-second configuration. Read the acceptance handoff for this build's exact result; this package is not friends-ready.`r`nSame build required;8 players maximum. Configured120Hz does not certify measured capacity.`r`nProfiles retain the legacy Godot/app_userdata/FLUX 2 directory. The Water material pilot is integrated; other asset packs remain staged. Spell Loom Assign/Apply and Gallery Attune show current contextual availability before sending requests. Gallery browsing/facing/details/close remain usable while attunement is unavailable; pending confirmation semantics are preserved. Existing cooldowns, confirmation and saved weaves are preserved. Previous snapshot/hash/rendering improvements, Water material and visibility fixes remain. Performance remains unaccepted. See docs/verification/hex-gallery-availability-20260923/HANDOFF.md in the checkout.`r`n",[Text.UTF8Encoding]::new($false))
 $hexHashes=@(Get-ChildItem -LiteralPath $hexPayload -File | Sort-Object Name | ForEach-Object {"$(Get-FluxFileSha256 $_.FullName)  $($_.Name)"})
 [IO.File]::WriteAllLines((Join-Path $hexPayload 'SHA256SUMS.txt'),[string[]]$hexHashes,[Text.UTF8Encoding]::new($false))
 $hexZip=Join-Path $hexOutput "HEX-$($hexIdentity.build_id)-Windows-x64.zip"
 Compress-Archive -LiteralPath (Get-ChildItem -LiteralPath $hexPayload -File | ForEach-Object FullName) -DestinationPath $hexZip -CompressionLevel Optimal
 [ordered]@{status='passed';build_id=$hexIdentity.build_id;runtime_source_sha256=$hexIdentity.runtime_source_sha256;executable=$hexExe;pack_sha256=(Get-FluxFileSha256 (Join-Path $hexPayload 'hex.pck'));zip=$hexZip;zip_sha256=(Get-FluxFileSha256 $hexZip);export_smoke='native launch plus source identity and safe close';logs=$hexLogs;installer='NOT_RUN';checkpoint_promoted=$false} | ConvertTo-Json | Set-Content (Join-Path $hexOutput 'receipt.json') -Encoding utf8
 Write-Output "PASS: H.E.X. portable $hexZip"
} finally {$env:APPDATA=$hexSavedAppData;Exit-FluxEngineRun $hexLease}
