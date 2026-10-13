$ErrorActionPreference = 'Stop'
. ./scripts/flux2-common.ps1
$stage = Join-Path $PWD '.godot/iteration-20261013/terrain-worker/promote'
$out = Join-Path $stage 'production-reset-a'
if (Test-Path -LiteralPath $out) { throw 'Preserve existing production reset evidence.' }
New-Item -ItemType Directory -Path $out | Out-Null
$target = Join-Path $PWD 'src/presentation/wellspring_async_terrain_stream.gd'
$fixed = [IO.File]::ReadAllBytes($target)
if ((Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant() -cne '2bf2835dc76eaeb0aa4d2cb5964ec15169c430391f4cd58c16c4ed007caa526b') { throw 'Unexpected reviewed production source.' }
$old = Join-Path $stage 'proposed/src/presentation/wellspring_async_terrain_stream.gd'
if ((Get-FileHash -LiteralPath $old).Hash.ToLowerInvariant() -cne '18d9ef02d074fedc786fcc31151a9dde22a3a0d23be72b4b0b1185025ddb4399') { throw 'Unexpected old diagnostic source.' }
$savedAppData = $env:APPDATA
$hadAppData = Test-Path Env:APPDATA
$args = @('--headless','--path',"$PWD",'--script','res://tests/run_all.gd','--','--no-lan-discovery','--suite=wellspring-async-terrain-stream')
try {
    $env:APPDATA = Join-Path $out 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    [IO.File]::WriteAllBytes($target,[IO.File]::ReadAllBytes($old))
    $rejected = $false
    try { Invoke-FluxGodotChecked (Get-FluxGodot) $args (Join-Path $out 'old-reset.log') -RejectWarnings -TimeoutSeconds 300 | Out-Null }
    catch { $rejected = $true; [IO.File]::WriteAllText((Join-Path $out 'old-reset-wrapper.txt'),$_.Exception.Message) }
    $oldText = Get-Content -Raw -LiteralPath (Join-Path $out 'old-reset.log')
    if (-not $rejected -or $oldText -notmatch 'FAIL: Pre-reset worker intervals cannot be charged to the new capture' -or $oldText -notmatch 'FAIL: 1 assertion\(s\) failed' -or (Get-Item -LiteralPath (Join-Path $out 'old-reset.log.err')).Length -ne 0) { throw 'Old diagnostic source did not reproduce exactly the expected single assertion.' }
    [IO.File]::WriteAllBytes($target,$fixed)
    Invoke-FluxGodotChecked (Get-FluxGodot) $args (Join-Path $out 'fixed-reset.log') -RejectWarnings -TimeoutSeconds 300
    if ((Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant() -cne '2bf2835dc76eaeb0aa4d2cb5964ec15169c430391f4cd58c16c4ed007caa526b') { throw 'Reviewed production source changed.' }
    Write-Output 'PASS: old capture reset failed only the targeted regression; reviewed correction passes.'
} finally {
    [IO.File]::WriteAllBytes($target,$fixed)
    if ($hadAppData) { $env:APPDATA = $savedAppData } else { Remove-Item Env:APPDATA }
}
