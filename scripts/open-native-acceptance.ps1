param([Parameter(Mandatory)][string]$Executable, [Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$RunId, [string[]]$GameArguments = @())
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$nativeLease = Enter-FluxEngineRun 'native-player-acceptance'
$nativeSavedAppData = $env:APPDATA
try {
    $nativeRoot = Get-FluxRepoRoot
    $nativeOutput = Join-Path $nativeRoot "docs/verification/hex-acceptance-20260921/$RunId"
    if (Test-Path -LiteralPath $nativeOutput) { throw 'Fresh native RunId required' }
    New-Item -ItemType Directory -Path $nativeOutput | Out-Null
    $env:APPDATA = Join-Path $nativeRoot ".godot/native-$RunId/isolated-roaming"
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    $nativeArgs = @('--windowed','--resolution','1280x720','--','--no-lan-discovery') + $GameArguments
    # User-requested native playtest needs a targetable visible game window.
    $nativeProcess = Start-FluxOwnedProcess @{FilePath=(Resolve-Path -LiteralPath $Executable).Path; ArgumentList=$nativeArgs; RedirectStandardOutput=(Join-Path $nativeOutput 'game.log'); RedirectStandardError=(Join-Path $nativeOutput 'game.err'); WindowStyle='Normal'}
    if (-not $nativeProcess.WaitForExit(300000)) { $nativeProcess.Kill(); throw 'Owned native game reached watchdog' }
    $nativeLog = Get-Content (Join-Path $nativeOutput 'game.log') -Raw
    if (-not $nativeLog.Contains('safe quit: local state flushed and network peer closed')) { throw 'Native run did not prove safe close' }
    if ((Get-Item (Join-Path $nativeOutput 'game.err')).Length -ne 0) { throw 'Native stderr is nonempty' }
} finally { $env:APPDATA = $nativeSavedAppData; Exit-FluxEngineRun $nativeLease }
