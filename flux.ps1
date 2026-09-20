param(
    [Parameter(Position = 0)]
    [string]$Task = 'play',

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$TaskArguments = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scriptsRoot = Join-Path $PSScriptRoot 'scripts'

function Show-FluxTasks {
    Write-Output 'FLUX Windows developer tasks:'
    Write-Output '  .\flux.cmd play [game arguments]'
    Write-Output '  .\flux.cmd check'
    Write-Output '  .\flux.cmd assets'
    Write-Output '  .\flux.cmd test [-Tier Focused|Fast|Full|Release] [-Suite id[,id]]'
    Write-Output '  .\flux.cmd list-tests'
    Write-Output '  .\flux.cmd doctor'
    Write-Output '  .\flux.cmd package'
    Write-Output ''
    Write-Output 'Players use the one-file exports\release\FLUX.exe instead.'
}

function Invoke-FluxTaskScript([string]$Name, [string[]]$PrefixArguments = @()) {
    $scriptPath = Join-Path $scriptsRoot $Name
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $scriptPath @PrefixArguments @TaskArguments
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$normalizedTask = $Task.Trim().ToLowerInvariant()
switch ($normalizedTask) {
    'play' {
        Invoke-FluxTaskScript 'run.ps1'
    }
    'check' {
        Invoke-FluxTaskScript 'current-state.ps1' @('-Check')
    }
    'assets' {
        Invoke-FluxTaskScript 'asset-inventory.ps1' @('-Check')
    }
    'test' {
        Invoke-FluxTaskScript 'test.ps1'
    }
    'list-tests' {
        if ($TaskArguments.Count -gt 0) { throw 'list-tests accepts no additional arguments.' }
        Invoke-FluxTaskScript 'test.ps1' @('-ListSuites')
    }
    'doctor' {
        Invoke-FluxTaskScript 'doctor.ps1'
    }
    'package' {
        Invoke-FluxTaskScript 'package.ps1' @('-Target', 'Windows')
    }
    { $_ -in @('help', '-h', '--help', '/?') } {
        if ($TaskArguments.Count -gt 0) { throw 'help accepts no additional arguments.' }
        Show-FluxTasks
    }
    default {
        Show-FluxTasks
        throw "Unknown FLUX task '$Task'."
    }
}
