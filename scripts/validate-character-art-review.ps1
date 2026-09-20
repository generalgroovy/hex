param(
    [string]$CandidatePath,
    [string]$ReceiptPath,
    [switch]$Inspect,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FluxReviewField($Object, [string]$Name) {
    if ($null -eq $Object -or $null -eq $Object.PSObject.Properties[$Name]) { return $null }
    return ,$Object.PSObject.Properties[$Name].Value
}

function Test-FluxCharacterArtReview {
    param($Receipt, [string]$Candidate, [string]$ExpectedChampion, [string]$ExpectedBody, [string]$EvidenceRoot)
    $issues = [Collections.Generic.List[string]]::new()
    $rows = @('grounded','jump','cast','hit','walk','sprint','slide','roll','walk_b','sprint_b')
    $directions = @('south','south_east','east','north_east','north','north_west','west','south_west')
    $contacts = @{ walk = 'left'; walk_b = 'right'; sprint = 'left'; sprint_b = 'right' }
    $heights = @{ small = 58; middle = 68; large = 76 }
    $approvedCount = 0
    $pendingCount = 0
    $heldCount = 0
    try {
        $version = Get-FluxReviewField $Receipt 'schema_version'
        if (($version -isnot [int] -and $version -isnot [long]) -or $version -ne 1) { $issues.Add('schema_version must be integer1.') }
        if ((Get-FluxReviewField $Receipt 'contract_id') -cne 'flux-three-body-art-production-v2') { $issues.Add('Wrong production contract.') }
        if ((Get-FluxReviewField $Receipt 'champion_id') -cne $ExpectedChampion) { $issues.Add('Champion identity does not match the requested canonical profile.') }
        if (-not $heights.ContainsKey($ExpectedBody) -or (Get-FluxReviewField $Receipt 'body_type') -cne $ExpectedBody) { $issues.Add('Body must match one canonical Small/Middle/Large profile.') }
        $status = Get-FluxReviewField $Receipt 'status'
        if ($status -cnotin @('approved','held','pending')) { $issues.Add('Unknown receipt status.') }
        $hash = Get-FluxReviewField $Receipt 'candidate_sha256'
        if ($hash -isnot [string] -or $hash -cnotmatch '^[0-9a-f]{64}$') { $issues.Add('Candidate needs an exact lowercase SHA256.') }
        if (-not (Test-Path -LiteralPath $Candidate -PathType Leaf)) { $issues.Add('Candidate PNG is absent.') }
        else {
            if ((Get-FileHash -LiteralPath $Candidate -Algorithm SHA256).Hash.ToLowerInvariant() -cne $hash) { $issues.Add('Candidate bytes changed; review is stale.') }
            $stream = [IO.File]::OpenRead([IO.Path]::GetFullPath($Candidate))
            try {
                $header = New-Object byte[] 24
                $read = $stream.Read($header, 0, 24)
                if ($read -ne 24 -or [BitConverter]::ToString($header[0..7]) -cne '89-50-4E-47-0D-0A-1A-0A') { $issues.Add('Candidate is not a PNG.') }
                else {
                    $width = [int64]$header[16] * 16777216 + [int64]$header[17] * 65536 + [int64]$header[18] * 256 + $header[19]
                    $height = [int64]$header[20] * 16777216 + [int64]$header[21] * 65536 + [int64]$header[22] * 256 + $header[23]
                    if ($width -ne 768 -or $height -ne 960) { $issues.Add('Candidate header must describe a768x960 page.') }
                }
            } finally { $stream.Dispose() }
        }
        $reviewer = Get-FluxReviewField $Receipt 'reviewer'
        if ((Get-FluxReviewField $reviewer 'kind') -cnotin @('agent_visual_review','human_visual_review')) { $issues.Add('Reviewer kind must distinguish agent from human review.') }
        if ([string]::IsNullOrWhiteSpace([string](Get-FluxReviewField $reviewer 'id'))) { $issues.Add('Reviewer ID is required.') }
        $attestation = Get-FluxReviewField $Receipt 'visual_attestation'
        if ($attestation -isnot [bool]) { $issues.Add('Visual attestation must be a JSON boolean, not a string or number.') }
        if ($status -ceq 'approved' -and ($attestation -isnot [bool] -or -not $attestation)) { $issues.Add('Approved review needs an explicit true visual attestation.') }
        $reviewTime = Get-FluxReviewField $Receipt 'reviewed_at_utc'
        # PowerShell7 may decode ISO JSON strings as DateTime; Windows5 keeps strings.
        if ($reviewTime -is [datetime] -and $reviewTime.Kind -eq [DateTimeKind]::Utc) { $reviewTime = $reviewTime.ToString('yyyy-MM-ddTHH:mm:ssZ') }
        elseif ($reviewTime -is [datetimeoffset] -and $reviewTime.Offset -eq [TimeSpan]::Zero) { $reviewTime = $reviewTime.ToString('yyyy-MM-ddTHH:mm:ssZ') }
        $parsedTime = [DateTimeOffset]::MinValue
        if ($reviewTime -isnot [string] -or $reviewTime -cnotmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$' -or -not [DateTimeOffset]::TryParse($reviewTime, [ref]$parsedTime)) { $issues.Add('Use a real UTC review timestamp YYYY-MM-DDTHH:MM:SSZ.') }
        $cells = Get-FluxReviewField $Receipt 'cells'
        $slots = @{}
        if ($cells -isnot [array] -or $cells.Count -ne 80) { $issues.Add('Exactly80 per-cell reviews are required.') }
        foreach ($cell in @($cells)) {
            $row = Get-FluxReviewField $cell 'state'
            $direction = Get-FluxReviewField $cell 'direction'
            if ($row -cnotin $rows -or $direction -cnotin $directions) { $issues.Add('Cell has unknown state/direction.'); continue }
            $key = "$row/$direction"
            if ($slots.ContainsKey($key)) { $issues.Add("Duplicate cell: $key"); continue }
            $slots[$key] = $cell
            $decision = Get-FluxReviewField $cell 'decision'
            $heading = Get-FluxReviewField $cell 'heading'
            $volume = Get-FluxReviewField $cell 'body_volume'
            $support = Get-FluxReviewField $cell 'support_leg'
            $arms = Get-FluxReviewField $cell 'arm_counter_swing'
            if ($decision -cnotin @('approved','held','pending')) { $issues.Add("Unknown decision: $key") }
            if ($heading -cnotin @('readable','ambiguous','unreviewed')) { $issues.Add("Unknown heading review: $key") }
            if ($volume -cnotin @('stable','unstable','unreviewed')) { $issues.Add("Unknown volume review: $key") }
            if ($support -cnotin @('left','right','unreviewed','not_applicable')) { $issues.Add("Unknown anatomical contact: $key") }
            if ($arms -cnotin @('opposed','incorrect','unreviewed','not_applicable')) { $issues.Add("Unknown counter-swing review: $key") }
            if ($decision -ceq 'approved') {
                $approvedCount++
                if ($heading -cne 'readable' -or $volume -cne 'stable') { $issues.Add("Approved cell contains held/unreviewed heading or volume: $key") }
                if ($contacts.ContainsKey($row) -and ($support -cne $contacts[$row] -or $arms -cne 'opposed')) { $issues.Add("Approved gait needs anatomical $($contacts[$row]) plant and opposing arm swing: $key") }
            } elseif ($decision -ceq 'held') { $heldCount++ } elseif ($decision -ceq 'pending') { $pendingCount++ }
            if (-not $contacts.ContainsKey($row) -and ($support -cne 'not_applicable' -or $arms -cne 'not_applicable')) { $issues.Add("Non-locomotion contact claims must be not_applicable: $key") }
            if ($contacts.ContainsKey($row) -and ($support -ceq 'not_applicable' -or $arms -ceq 'not_applicable')) { $issues.Add("Locomotion requires a reviewed or explicitly unreviewed contact: $key") }
            if ($decision -cne 'approved' -and [string]::IsNullOrWhiteSpace([string](Get-FluxReviewField $cell 'note'))) { $issues.Add("Pending/held cell needs an actionable note: $key") }
        }
        if ($slots.Count -ne 80) { $issues.Add('Review does not cover all80 unique canonical slots.') }
        if ($status -ceq 'approved' -and $approvedCount -ne 80) { $issues.Add('Approved receipt cannot hide held or pending cells.') }
        if ($status -ceq 'held' -and $heldCount -eq 0) { $issues.Add('Held receipt must identify at least one held cell.') }
        if ($status -ceq 'pending' -and $pendingCount -eq 0) { $issues.Add('Pending receipt must identify at least one pending cell.') }
        $evidence = Get-FluxReviewField $Receipt 'evidence'
        if ($evidence -isnot [array]) { $issues.Add('Evidence must be a JSON array.') }
        $evidenceKinds = @{}
        $seenEvidence = @{}
        foreach ($item in @($evidence)) {
            if ($null -eq $item) { continue }
            $kind = Get-FluxReviewField $item 'kind'
            $path = Get-FluxReviewField $item 'path'
            $evidenceHash = Get-FluxReviewField $item 'sha256'
            if ($kind -cnotin @('native_light_contacts','native_dark_contacts','native_gait_review','in_game_review','portrait_review')) { $issues.Add('Unknown evidence kind.'); continue }
            if ($path -isnot [string] -or [string]::IsNullOrWhiteSpace($path) -or [IO.Path]::IsPathRooted($path) -or $path -match '(^|[\\/])\.\.([\\/]|$)' -or $path.Contains(':')) { $issues.Add('Evidence paths must be relative and contained.'); continue }
            $rootPath = [IO.Path]::GetFullPath($EvidenceRoot).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
            $evidencePath = [IO.Path]::GetFullPath((Join-Path $EvidenceRoot $path))
            if (-not $evidencePath.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)) { $issues.Add('Evidence escapes the review directory.'); continue }
            if ($seenEvidence.ContainsKey($evidencePath)) { $issues.Add('One artifact cannot stand in for several distinct review views.'); continue }
            $seenEvidence[$evidencePath] = $true
            if ($evidenceHash -isnot [string] -or $evidenceHash -cnotmatch '^[0-9a-f]{64}$' -or -not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) { $issues.Add("Missing/hashless evidence: $path"); continue }
            if ((Get-FileHash -LiteralPath $evidencePath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $evidenceHash) { $issues.Add("Stale evidence: $path"); continue }
            $evidenceKinds[$kind] = $true
        }
        if ($status -ceq 'approved') {
            foreach ($kind in @('native_light_contacts','native_dark_contacts','native_gait_review','in_game_review','portrait_review')) {
                if (-not $evidenceKinds.ContainsKey($kind)) { $issues.Add("Approved receipt requires $kind evidence.") }
            }
        }
    } catch { $issues.Add('Malformed or unreadable review input: ' + $_.Exception.Message) }
    $valid = $issues.Count -eq 0
    return [pscustomobject]@{
        metadata_valid = $valid
        promotion_ready = ($valid -and (Get-FluxReviewField $Receipt 'status') -ceq 'approved' -and $approvedCount -eq 80)
        approved_cells = $approvedCount
        held_cells = $heldCount
        pending_cells = $pendingCount
        diagnostics = @($issues.ToArray())
        evidence_boundary = 'Checks hashes and explicit reviewer attestations only; no automated anatomy, facing, foot-contact, charm, or human-feel certification. Does not modify any live registry.'
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if ([string]::IsNullOrWhiteSpace($CandidatePath) -or [string]::IsNullOrWhiteSpace($ReceiptPath)) { throw 'Use -CandidatePath <PNG> -ReceiptPath <JSON>; -Inspect permits a valid held/pending report without approving promotion.' }
    $receiptFullPath = [IO.Path]::GetFullPath($ReceiptPath)
    $receipt = Get-Content -LiteralPath $receiptFullPath -Raw | ConvertFrom-Json
    $identity = Get-FluxReviewField $receipt 'champion_id'
    $repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $catalog = Get-Content -LiteralPath (Join-Path $repoRoot 'content/champions/foundation_champions_v1.json') -Raw | ConvertFrom-Json
    $matching = @($catalog.champions | Where-Object { $_.id -ceq $identity })
    $body = if ($matching.Count -eq 1) { $matching[0].body_type } elseif ($identity -cin @('template_small','template_middle','template_large')) { $identity.Substring(9) } else { '' }
    $result = Test-FluxCharacterArtReview $receipt $CandidatePath $identity $body ([IO.Path]::GetDirectoryName($receiptFullPath))
    if ($AsJson) { $result | ConvertTo-Json -Depth 12 } else { $result | Format-List }
    if (-not $result.metadata_valid -or (-not $Inspect -and -not $result.promotion_ready)) { exit 2 }
}
