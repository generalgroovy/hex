[CmdletBinding()]
param(
    [ValidateSet('Play', 'Source', 'Profile')][string]$Mode = 'Play',
    [string]$OutputDirectory = '',
    [switch]$Inspect,
    [switch]$Lifecycle,
    [string]$CandidatePackageReceipt = '',
    [string]$CandidatePackageReceiptSha256 = '',
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$GameArguments = @()
)

# One front door for the desktop shortcut. Play is always the qualified portable;
# Source and Profile are explicit developer choices and never promote a build.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$launchRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$delivery = Get-Content -LiteralPath (Join-Path $launchRoot 'docs/current-delivery.json') -Raw | ConvertFrom-Json
if ($delivery.schema_version -ne 1 -or $delivery.qualified_build_id -cnotmatch '^p[0-9]+-[0-9a-f]{12}$' -or
    $delivery.launcher -cnotmatch '^exports/[a-z0-9-]+/windows/PLAY-HEX\.cmd$') {
    throw 'Invalid current delivery descriptor. Inspect docs/current-delivery.json.'
}
$portableLauncher = Join-Path $launchRoot $delivery.launcher
if ($Lifecycle -and ($Mode -ne 'Play' -or $GameArguments.Count -gt 0)) { throw 'Lifecycle is a fixed supervised Play route and accepts no game arguments.' }
if (-not $Lifecycle -and ($CandidatePackageReceipt -or $CandidatePackageReceiptSha256)) { throw 'Candidate package selection is only valid for supervised Lifecycle.' }
if ($Mode -ne 'Profile' -and -not $Lifecycle -and $OutputDirectory) { throw 'OutputDirectory is only valid for Profile or Lifecycle.' }
if ($Mode -eq 'Profile' -and $GameArguments.Count -gt 0) { throw 'Profile uses a fixed comparable workload and accepts no game arguments.' }
foreach ($argument in $GameArguments) {
    if ($argument -cnotmatch '^--[a-z][a-z0-9-]*(=[A-Za-z0-9_,./:-]+)?$') {
        throw 'Use complete --name or --name=value game options without shell operators.'
    }
}
if ($Lifecycle) {
    & (Join-Path $PSScriptRoot 'verify-launcher-lifecycle.ps1') -OutputDirectory $OutputDirectory `
        -CandidatePackageReceipt $CandidatePackageReceipt -CandidatePackageReceiptSha256 $CandidatePackageReceiptSha256 -Inspect:$Inspect
    return
}
if ($Inspect) {
    [ordered]@{
        mode = $Mode
        qualified_build_id = $delivery.qualified_build_id
        selected_launcher = $portableLauncher
        portable_available = Test-Path -LiteralPath $portableLauncher -PathType Leaf
        source_root = $launchRoot
        profile_scope = 'Explicit native source diagnostic; not packaged-release FPS or GPU/present/input-latency acceptance.'
        default_selection_unchanged = $true
    } | ConvertTo-Json
    return
}
switch ($Mode) {
    'Play' {
        if (-not (Test-Path -LiteralPath $portableLauncher -PathType Leaf)) {
            throw 'The qualified portable is unavailable on this PC. See README.md for setup; source is never substituted silently.'
        }
        & $portableLauncher @GameArguments
        if ($LASTEXITCODE -ne 0) { throw "Portable launcher failed with exit code $LASTEXITCODE." }
    }
    'Source' {
        & (Join-Path $PSScriptRoot 'run.ps1') -GameArguments (@('--fullbody-art', '--pixel-cast') + $GameArguments)
    }
    'Profile' {
        if (-not $OutputDirectory) { throw 'Profile requires a fresh OutputDirectory for its evidence.' }
        Write-Output 'H.E.X. source diagnostic: Garden and sustained Fire/Mantle. Click Start and leave the game in front until it closes.'
        & (Join-Path $PSScriptRoot 'profile-gameplay.ps1') -OutputDirectory $OutputDirectory `
            -Profiles @('low') -Cases @('garden_middle', 'paid_fire_bolt_sustained', 'paid_all_six_mantle_sustained') `
            -SecondsPerCase 15 -FrameLimit 60 -Width 1280 -Height 720 -AllFixedSteps `
            -ReferenceCampus -WaitForForeground -TimeoutSeconds 600
    }
}
