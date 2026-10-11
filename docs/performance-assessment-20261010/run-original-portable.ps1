$ErrorActionPreference = 'Stop'
. ./scripts/flux2-common.ps1
$hexPortable = Join-Path (Get-Location).Path 'exports/hex-element-expansion-20261009/windows'
$hexLease = Enter-FluxEngineRun 'original-portable-performance-assessment-20261010'
$hexSavedAppData = $env:APPDATA
try {
    foreach ($hexCase in @(@{ Name = 'hearth'; Frames = 360; Extra = @() }, @{ Name = 'garden'; Frames = 40; Extra = @('--capture-spawn=4880,720') })) {
        $hexCaseOut = Join-Path (Get-Location).Path ('.godot/original-portable-assessment-20261010-' + $hexCase.Name)
        if (Test-Path -LiteralPath $hexCaseOut) { throw "Receipt already exists: $hexCaseOut" }
        $env:APPDATA = Join-Path $hexCaseOut 'isolated-roaming'
        New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
        $hexArgs = @('--print-fps', '--windowed', '--resolution', '1280x720', '--quit-after', [string]$hexCase.Frames, '--', '--fullbody-art', '--pixel-cast', '--no-lan-discovery') + $hexCase.Extra
        $hexWatch = [Diagnostics.Stopwatch]::StartNew()
        Push-Location -LiteralPath $hexPortable
        try {
            Invoke-FluxGodotChecked (Join-Path $hexPortable 'hex.exe') $hexArgs (Join-Path $hexCaseOut 'engine.log') -RejectWarnings -TimeoutSeconds 150 | Out-Null
        } finally { Pop-Location }
        $hexWatch.Stop()
        [pscustomobject]@{ case = $hexCase.Name; process_wall_seconds = $hexWatch.Elapsed.TotalSeconds; iterations = $hexCase.Frames; arguments = $hexArgs; scope = 'Unmodified original EXE and PCK. Engine one-second FPS reports, including startup; not presentation timestamp trace, not input-latency or sustained performance certification.' } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $hexCaseOut 'run.json') -Encoding utf8
        Write-Output "Original portable case finished: $($hexCase.Name)"
    }
} finally {
    $env:APPDATA = $hexSavedAppData
    Exit-FluxEngineRun $hexLease
}
