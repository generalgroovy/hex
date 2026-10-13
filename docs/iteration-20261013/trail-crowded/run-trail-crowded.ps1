param(
    [ValidateSet('functional','forward','reverse')][string[]]$Modes=@('functional','forward','reverse'),
    [ValidatePattern('^[a-z0-9-]{1,16}$')][string]$RunSuffix='a'
)
$ErrorActionPreference='Stop'
. ./scripts/flux2-common.ps1
$hexSavedRoaming=$env:APPDATA
try {
    New-Item -ItemType Directory -Path (Join-Path $PWD '.godot/iteration-20261013/trail-crowded/runs') -Force | Out-Null
    foreach ($hexMode in $Modes) {
        $hexBase=".godot/iteration-20261013/trail-crowded/runs/probe-$hexMode-$RunSuffix"
        if (Test-Path -LiteralPath "$hexBase.json") { throw "Fresh output required: $hexBase" }
        $env:APPDATA=Join-Path $PWD "$hexBase-roaming"
        $hexArguments=@('--path',"$PWD",'--audio-driver','Dummy','--script','res://.godot/iteration-20261013/trail-crowded/compare-trail-crowded.gd')
        if ($hexMode -eq 'functional') { $hexArguments=@('--headless')+$hexArguments }
        $hexArguments+=@('--',"--output=res://$hexBase.json")
        if ($hexMode -eq 'functional') { $hexArguments+='--correctness-only' }
        if ($hexMode -eq 'reverse') { $hexArguments+='--reverse-order' }
        Invoke-FluxGodotChecked -GodotBin (Get-FluxGodot) -Arguments $hexArguments -LogPath (Join-Path $PWD "$hexBase.log") -TimeoutSeconds 600 -RejectWarnings
        $hexReceipt=Get-Content -LiteralPath "$hexBase.json" -Raw | ConvertFrom-Json
        $hexExpectedCases=if ($hexMode -eq 'functional') { 1 } else { 2 }
        if (-not $hexReceipt.passed -or $hexReceipt.errors.Count -gt 0 -or $hexReceipt.cases.Count -ne $hexExpectedCases) { throw "Trail receipt failed: $hexMode" }
        foreach ($hexProperty in $hexReceipt.sources.PSObject.Properties) {
            $hexPath=Join-Path $PWD ($hexProperty.Name -replace '^res://','')
            if ((Get-FileHash -LiteralPath $hexPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $hexProperty.Value) { throw "Source drift: $hexPath" }
        }
        Write-Output "Verified trail $hexMode : $($hexReceipt.checks) checks, $($hexReceipt.cases.Count) cases."
        Get-FileHash -LiteralPath "$hexBase.json" -Algorithm SHA256
    }
} finally { $env:APPDATA=$hexSavedRoaming }
