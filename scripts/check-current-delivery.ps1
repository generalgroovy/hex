param([string]$Root = (Split-Path -Parent $PSScriptRoot))

# Metadata/link consistency only. This never opens a payload or compares the
# working candidate's runtime identity with the separately qualified portable.
$ErrorActionPreference = 'Stop'

function Get-HexCurrentDeliverySummary([object]$Pointer) {
    if ($Pointer.schema_version -isnot [long] -and $Pointer.schema_version -isnot [int]) { throw 'Delivery schema must be an integer.' }
    if ($Pointer.schema_version -ne 1 -or $Pointer.qualified_build_id -isnot [string] -or $Pointer.qualified_build_id -cnotmatch '^p[0-9]+-[0-9a-f]{12}$') { throw 'Invalid qualified portable identity.' }
    if ($Pointer.launcher -isnot [string] -or $Pointer.launcher -cnotmatch '^exports/[a-z0-9]+(?:-[a-z0-9]+)*/windows/PLAY-HEX\.cmd$') { throw 'Delivery launcher must be a contained portable path.' }
    if ($Pointer.qualification -isnot [string] -or $Pointer.qualification -cnotmatch '^docs/(?:[a-zA-Z0-9]+(?:-[a-zA-Z0-9]+)*/)+review\.json$') { throw 'Delivery review must be a contained source-evidence path.' }
    if ($Pointer.working_status -cnotin @('active_candidate', 'paused_qualified')) { throw 'Unknown working-status meaning.' }
    if ($Pointer.performance_status -cnotin @('current_build_not_measured', 'source_measured_portable_unmeasured')) { throw 'Unknown performance evidence scope.' }
    $performanceEvidence = if ($null -ne $Pointer.PSObject.Properties['performance_evidence']) { $Pointer.performance_evidence } else { '' }
    if ($Pointer.performance_status -ceq 'source_measured_portable_unmeasured') {
        if ($performanceEvidence -isnot [string] -or $performanceEvidence -cnotmatch '^docs/(?:[a-zA-Z0-9]+(?:-[a-zA-Z0-9]+)*/)+review\.json$') { throw 'Measured source requires a contained independent source review.' }
    } elseif ($performanceEvidence) { throw 'An unmeasured selection cannot retain a current performance-evidence pointer.' }
    $buildDirectory = $Pointer.launcher.Substring(0, $Pointer.launcher.Length - '/windows/PLAY-HEX.cmd'.Length)
    return [pscustomobject]@{
        qualified_build_id = $Pointer.qualified_build_id
        launcher = $Pointer.launcher
        zip = "$buildDirectory/HEX-$($Pointer.qualified_build_id)-Windows-x64.zip"
        qualification = $Pointer.qualification
        working_status = $Pointer.working_status
        performance_status = $Pointer.performance_status
        performance_evidence = $performanceEvidence
    }
}

function Assert-HexPerformanceEvidence([object]$Summary, [object]$Review) {
    if ($Review.schema -cne 'hex-foreground-source-review-v1' -or $Review.status -cne 'passed' -or
        $Review.source_build_id -cne $Summary.qualified_build_id -or $Review.source_sha256 -cnotmatch '^[a-f0-9]{64}$' -or
        -not $Review.source_build_id.EndsWith($Review.source_sha256.Substring(0, 12), [StringComparison]::Ordinal) -or
        $Review.errors -isnot [Array] -or $Review.errors.Count -ne 0) { throw 'Source performance review is failed, incomplete or identifies a different build.' }
}

function Assert-HexDeliveryLink([string]$Text, [string]$Label, [string]$Target) {
    $links = [regex]::Matches($Text, '\[' + [regex]::Escape($Label) + '\]\(([^)\r\n]+)\)')
    if ($links.Count -ne 1 -or $links[0].Groups[1].Value -cne $Target) { throw "Current delivery link differs: $Label" }
}

function Assert-HexCurrentDeliveryText([object]$Summary, [string]$Readme, [string]$Guide) {
    $readmeLead = ($Readme -split '(?m)^## ', 2)[0]
    $guideLead = ($Guide -split '(?m)^## ', 2)[0]
    $readmeIds = [regex]::Matches($readmeLead, 'The qualified local portable remains\s+\*\*(p[0-9]+-[0-9a-f]{12})\*\*')
    $guideIds = [regex]::Matches($guideLead, 'the qualified playable build is (p[0-9]+-[0-9a-f]{12})\.')
    foreach ($ids in @($readmeIds, $guideIds)) {
        if ($ids.Count -ne 1 -or $ids[0].Groups[1].Value -cne $Summary.qualified_build_id) { throw 'An active document header names a different qualified portable.' }
    }
    $readmeStatus = if ($Summary.working_status -ceq 'active_candidate') { '(?m)^Status: \*\*active improvement pass' } else { '(?mi)^Status: \*\*paused' }
    $guideStatus = if ($Summary.working_status -ceq 'active_candidate') { '(?m)^Status: \*\*development is active;' } else { '(?m)^Status: \*\*development is paused;' }
    if ($readmeLead -cnotmatch $readmeStatus -or $guideLead -cnotmatch $guideStatus) { throw 'Active document status differs from the delivery descriptor.' }
    Assert-HexDeliveryLink $Readme 'Launch H.E.X.' $Summary.launcher
    Assert-HexDeliveryLink $Readme 'Windows x64 ZIP' $Summary.zip
    Assert-HexDeliveryLink $Readme 'delivery review' $Summary.qualification
    Assert-HexDeliveryLink $Guide 'Windows x64 ZIP' ('../' + $Summary.zip)
    Assert-HexDeliveryLink $Guide 'independent delivery review' $Summary.qualification.Substring('docs/'.Length)
    if ($Summary.performance_status -ceq 'source_measured_portable_unmeasured') {
        Assert-HexDeliveryLink $Readme 'source performance review' $Summary.performance_evidence
        Assert-HexDeliveryLink $Guide 'source performance review' $Summary.performance_evidence.Substring('docs/'.Length)
    }
}

$deliveryCheckRoot = [IO.Path]::GetFullPath($Root)
$pointer = Get-Content -Raw -LiteralPath (Join-Path $deliveryCheckRoot 'docs/current-delivery.json') | ConvertFrom-Json
$summary = Get-HexCurrentDeliverySummary $pointer
if (-not (Test-Path -LiteralPath (Join-Path $deliveryCheckRoot $summary.qualification) -PathType Leaf)) { throw 'The referenced delivery review is absent from source.' }
Assert-HexCurrentDeliveryText $summary (Get-Content -Raw -LiteralPath (Join-Path $deliveryCheckRoot 'README.md')) (Get-Content -Raw -LiteralPath (Join-Path $deliveryCheckRoot 'docs/PLAYER-GUIDE.md'))
if ($summary.performance_status -ceq 'source_measured_portable_unmeasured') {
    $performancePath = Join-Path $deliveryCheckRoot $summary.performance_evidence
    if (-not (Test-Path -LiteralPath $performancePath -PathType Leaf)) { throw 'The source performance review is absent.' }
    Assert-HexPerformanceEvidence $summary (Get-Content -LiteralPath $performancePath -Raw | ConvertFrom-Json)
}
Write-Output "PASS: README and player guide match qualified portable $($summary.qualified_build_id); source metadata only, no fresh payload/performance qualification."
