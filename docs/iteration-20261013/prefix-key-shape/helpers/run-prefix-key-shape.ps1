param([ValidateSet('forward','reverse')][string[]]$Modes=@('forward','reverse'),[ValidatePattern('^[a-z0-9-]{1,16}$')][string]$RunSuffix='a')
$ErrorActionPreference='Stop'
. ./scripts/flux2-common.ps1
$hexSavedRoaming=$env:APPDATA
$hexHadRoaming=Test-Path Env:APPDATA
try {
    New-Item -ItemType Directory -Path (Join-Path $PWD '.godot/iteration-20261013/prefix-key-shape/runs') -Force | Out-Null
    foreach ($hexMode in $Modes) {
        $hexBase=".godot/iteration-20261013/prefix-key-shape/runs/probe-$hexMode-$RunSuffix"
        foreach ($hexFresh in @($hexBase,"$hexBase.log","$hexBase.log.err","$hexBase-roaming")) {
            if (Test-Path -LiteralPath $hexFresh) { throw "Fresh output required: $hexFresh" }
        }
        $env:APPDATA=Join-Path $PWD "$hexBase-roaming"
        New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
        $hexArguments=@('--path',"$PWD",'--audio-driver','Dummy','--script','res://.godot/iteration-20261013/prefix-key-shape/compare-prefix-key-shape.gd','--','--no-lan-discovery',"--output=res://$hexBase")
        if ($hexMode -eq 'reverse') { $hexArguments+='--reverse-order' }
        Invoke-FluxGodotChecked (Get-FluxGodot) $hexArguments (Join-Path $PWD "$hexBase.log") -TimeoutSeconds 400 -RejectWarnings
        $hexReceipt=Get-Content -LiteralPath "$hexBase/receipt.json" -Raw | ConvertFrom-Json
        if (-not $hexReceipt.passed -or $hexReceipt.errors.Count -gt 0 -or $hexReceipt.cases.Count -ne 22 -or $hexReceipt.timed_cases -ne 12 -or $hexReceipt.pixel_only_cases -ne 10) { throw "Prefix key receipt failed: $hexMode" }
        if ((Get-Item -LiteralPath "$hexBase.log.err").Length -ne 0) { throw 'Unexpected native stderr.' }
        foreach ($hexProperty in $hexReceipt.source_hashes.PSObject.Properties) {
            $hexPath=Join-Path $PWD ($hexProperty.Name -replace '^res://','')
            if ((Get-FileHash -LiteralPath $hexPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $hexProperty.Value) { throw "Source drift: $hexPath" }
        }
        Write-Output "Verified prefix key $hexMode : $($hexReceipt.checks) checks, $($hexReceipt.cases.Count) cases."
        Get-FileHash -LiteralPath "$hexBase/receipt.json" -Algorithm SHA256
    }
} finally { if ($hexHadRoaming) { $env:APPDATA=$hexSavedRoaming } else { Remove-Item Env:APPDATA } }
