[CmdletBinding()]
param(
    [string]$OutputDirectory = '',
    [string]$CandidatePackageReceipt = '',
    [string]$CandidatePackageReceiptSha256 = '',
    [switch]$Inspect
)

# Supervised Play route for scripts/launch-hex.ps1. Adapted from the preserved
# portable-lifecycle-7804-passed-a/verify-final-portable-lifecycle.ps1 (f1527a16).
# The desktop front door owns this dispatch; the checked runner owns each game.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-HexLifecycleRequest([string]$Root, [object]$Delivery, [string]$Candidate, [string]$CandidateSha) {
    if (($Delivery.schema_version -isnot [long] -and $Delivery.schema_version -isnot [int]) -or $Delivery.schema_version -ne 1 -or $Delivery.qualified_build_id -isnot [string] -or $Delivery.qualified_build_id -cnotmatch '^p[0-9]+-[0-9a-f]{12}$' -or
        $Delivery.launcher -cnotmatch '^exports/[a-z0-9]+(?:-[a-z0-9]+)*/windows/PLAY-HEX\.cmd$') { throw 'Invalid qualified delivery descriptor.' }
    $rootPath = [IO.Path]::GetFullPath($Root)
    $isCandidate = -not [string]::IsNullOrWhiteSpace($Candidate)
    if ($isCandidate -and $CandidateSha -cnotmatch '^[a-f0-9]{64}$') { throw 'Candidate selection requires its exact package receipt SHA-256.' }
    if (-not $isCandidate -and $CandidateSha) { throw 'A candidate hash requires a candidate receipt.' }
    $receiptInput = if ($isCandidate) { $Candidate } else { $Delivery.launcher.Replace('/windows/PLAY-HEX.cmd', '/receipt.json') }
    $receiptPath = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($receiptInput)) { $receiptInput } else { Join-Path $rootPath $receiptInput }))
    $relative = [IO.Path]::GetRelativePath($rootPath, $receiptPath).Replace('\', '/')
    if ($relative -cnotmatch '^exports/[a-z0-9]+(?:-[a-z0-9]+)*/receipt\.json$') { throw 'Select only one package receipt directly under a repository exports build.' }
    return [pscustomobject]@{
        kind = $(if ($isCandidate) { 'explicit_candidate_package' } else { 'qualified_portable' })
        receipt_path = $receiptPath
        receipt_relative = $relative
        receipt_pin = $CandidateSha
        build_directory = [IO.Path]::GetDirectoryName($receiptPath)
        expected_build_id = $(if ($isCandidate) { '' } else { [string]$Delivery.qualified_build_id })
        qualified_default = [string]$Delivery.qualified_build_id
    }
}

function Assert-HexLifecyclePackageIdentity([object]$Package, [object]$Identity, [object]$BuildState, [string]$ExpectedBuild) {
    if ($Package.status -cne 'passed' -or $Package.build_id -cnotmatch '^p([0-9]+)-([a-f0-9]{12})$' -or
        $Package.runtime_source_sha256 -cnotmatch '^[a-f0-9]{64}$' -or $Package.pack_sha256 -cnotmatch '^[a-f0-9]{64}$') { throw 'A passed, precisely identified export package is required.' }
    $idParts = [regex]::Match($Package.build_id, '^p([0-9]+)-([a-f0-9]{12})$')
    if (-not $Package.runtime_source_sha256.StartsWith($idParts.Groups[2].Value, [StringComparison]::Ordinal)) { throw 'Package short and full source identities disagree.' }
    if ($ExpectedBuild -and $Package.build_id -cne $ExpectedBuild) { throw 'Package differs from the qualified delivery selection.' }
    if (($Identity.schema_version -isnot [long] -and $Identity.schema_version -isnot [int]) -or $Identity.schema_version -ne 1 -or $Identity.scope_id -cne 'production-runtime-source-v1' -or
        $Identity.build_id -cne $Package.build_id -or $Identity.runtime_source_sha256 -cne $Package.runtime_source_sha256 -or
        $Identity.protocol_version -ne [int]$idParts.Groups[1].Value) { throw 'SOURCE-IDENTITY does not match the selected export receipt.' }
    $loaded = $BuildState.state.runtime.build_identity
    if ($BuildState.source_kind -cne 'exported_pack' -or $BuildState.pack_sha256 -cne $Package.pack_sha256 -or
        $loaded.build_id -cne $Identity.build_id -or $loaded.runtime_source_sha256 -cne $Identity.runtime_source_sha256 -or
        $loaded.protocol_version -ne $Identity.protocol_version -or $loaded.snapshot_schema -ne $Identity.snapshot_schema -or
        $loaded.record_count -ne $Identity.record_count -or $loaded.engine_identity -cne $Identity.engine_identity) { throw 'Loaded pack identity does not match its source stamp and receipt.' }
}

function Get-HexLifecycleCastSummary([string[]]$Lines) {
    $starts = @(); $refusals = @(); $releases = @(); $lastTick = -1L; $captureRows = 0
    foreach ($line in $Lines) {
        if (-not $line.StartsWith('FLUX2 spell capture:', [StringComparison]::Ordinal)) { continue }
        if ($line -cnotmatch '^FLUX2 spell capture: tick ([0-9]+) pending [0-9]+/[0-9]+ projectiles [0-9]+ fields [0-9]+ events (\[.*\])$') { throw 'Malformed spell capture row.' }
        $tick = [long]$Matches[1]; $eventText = $Matches[2]
        if ($tick -le $lastTick) { throw 'Spell capture ticks must increase strictly.' }
        $lastTick = $tick; $captureRows++
        $events = ConvertFrom-Json -InputObject $eventText -NoEnumerate
        if ($events -isnot [Array]) { throw 'Spell capture events must be an array.' }
        foreach ($event in $events) {
            if ($null -eq $event -or $null -eq $event.PSObject.Properties['type'] -or $event.type -isnot [string]) { throw 'Malformed spell capture event.' }
            if ($event.type -cnotin @('cast_started', 'cast_refused', 'projectile_spawned')) { continue }
            if ($null -eq $event.PSObject.Properties['wire_id'] -or ($event.wire_id -isnot [long] -and $event.wire_id -isnot [int])) { throw 'Cast outcome lacks an integer spell wire.' }
            $row = [ordered]@{tick=$tick; wire=[long]$event.wire_id}
            if ($event.type -ceq 'cast_started') { $starts += $row }
            elseif ($event.type -ceq 'cast_refused') { $refusals += $row }
            else {
                if ($null -eq $event.PSObject.Properties['owner_id'] -or $event.owner_id -ne 1 -or
                    $null -eq $event.PSObject.Properties['projectile_id'] -or ($event.projectile_id -isnot [long] -and $event.projectile_id -isnot [int])) { throw 'Invalid owned projectile release.' }
                $row.projectile_id = [long]$event.projectile_id
                $releases += $row
            }
        }
    }
    return [pscustomobject]@{capture_rows=$captureRows; starts=@($starts); refusals=@($refusals); releases=@($releases)}
}

function Assert-HexLifecycleCasts([object]$Summary, [int]$Wire) {
    $expected = if ($Wire -eq 0) { 0 } else { 12 }
    if ($Summary.starts.Count -ne $expected -or $Summary.refusals.Count -ne 0 -or $Summary.releases.Count -ne $expected) { throw 'Expected exactly twelve accepted/released casts with zero refusals, or no casts in an idle case.' }
    if (@($Summary.starts | Where-Object {$_.wire -ne $Wire}).Count -gt 0 -or @($Summary.releases | Where-Object {$_.wire -ne $Wire}).Count -gt 0) { throw 'Unexpected spell wire in the finite workload.' }
    if (@($Summary.releases | ForEach-Object {$_.projectile_id} | Sort-Object -Unique).Count -ne $expected) { throw 'Duplicate projectile release in finite workload.' }
}

function Assert-HexLifecyclePhysicalPath([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Lifecycle inputs and outputs require physical paths without reparse points.' }
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
}

function Get-HexLifecycleSha([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Lifecycle input is absent: $Path" }
    Assert-HexLifecyclePhysicalPath $Path
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-HexLifecyclePins([Collections.IDictionary]$Pins) {
    foreach ($path in $Pins.Keys) { if ((Get-HexLifecycleSha $path) -cne $Pins[$path]) { throw "Lifecycle input changed: $path" } }
}

$hexRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$deliveryPath = Join-Path $hexRoot 'docs/current-delivery.json'
$delivery = Get-Content -Raw -LiteralPath $deliveryPath | ConvertFrom-Json
$request = Get-HexLifecycleRequest $hexRoot $delivery $CandidatePackageReceipt $CandidatePackageReceiptSha256
$pins = [ordered]@{}
$pins[$request.receipt_path] = Get-HexLifecycleSha $request.receipt_path
if ($request.receipt_pin -and $pins[$request.receipt_path] -cne $request.receipt_pin) { throw 'Candidate package receipt hash changed or is incorrect.' }
$package = Get-Content -Raw -LiteralPath $request.receipt_path | ConvertFrom-Json
$payload = Join-Path $request.build_directory 'windows'
$manifestPath = Join-Path $payload 'SHA256SUMS.txt'
$pins[$manifestPath] = Get-HexLifecycleSha $manifestPath
$payloadHashes = [ordered]@{}
foreach ($line in [IO.File]::ReadLines($manifestPath)) {
    if ($line -cnotmatch '^([a-f0-9]{64})  ([A-Za-z0-9][A-Za-z0-9_.-]*)$') { throw 'Malformed package payload manifest.' }
    $name = $Matches[2]; $hash = $Matches[1]
    if ($payloadHashes.Contains($name)) { throw 'Duplicate package payload name.' }
    $path = Join-Path $payload $name
    if ((Get-HexLifecycleSha $path) -cne $hash) { throw "Package payload hash mismatch: $name" }
    $payloadHashes[$name] = $hash; $pins[$path] = $hash
}
foreach ($required in @('hex.exe', 'hex.pck', 'SOURCE-IDENTITY.json', 'BUILD-STATE.json', 'PLAY-HEX.cmd', 'README-FIRST.txt')) {
    if (-not $payloadHashes.Contains($required)) { throw "Package manifest lacks $required" }
}
if (@(Get-ChildItem -LiteralPath $payload -File -Force).Count -ne $payloadHashes.Count + 1 -or @(Get-ChildItem -LiteralPath $payload -Directory -Force).Count -ne 0) { throw 'Unexpected payload inventory.' }
$identity = Get-Content -Raw -LiteralPath (Join-Path $payload 'SOURCE-IDENTITY.json') | ConvertFrom-Json
$buildState = Get-Content -Raw -LiteralPath (Join-Path $payload 'BUILD-STATE.json') | ConvertFrom-Json
Assert-HexLifecyclePackageIdentity $package $identity $buildState $request.expected_build_id
$exe = Join-Path $payload 'hex.exe'
if ([IO.Path]::GetFullPath($package.executable) -ine $exe -or $payloadHashes['hex.pck'] -cne $package.pack_sha256) { throw 'Receipt executable or pack hash differs from its derived payload.' }
$zip = Join-Path $request.build_directory ('HEX-' + $package.build_id + '-Windows-x64.zip')
if ([IO.Path]::GetFullPath($package.zip) -ine $zip -or $package.zip_sha256 -cnotmatch '^[a-f0-9]{64}$' -or (Get-HexLifecycleSha $zip) -cne $package.zip_sha256) { throw 'Package archive path or hash disagrees.' }
$pins[$zip] = $package.zip_sha256
if (-not ([IO.File]::ReadAllText((Join-Path $payload 'PLAY-HEX.cmd')).Contains('--fullbody-art --pixel-cast %*'))) { throw 'Lifecycle requires the selected package pixel presentation flags.' }
foreach ($relative in @('docs/current-delivery.json', 'scripts/launch-hex.ps1', 'scripts/verify-launcher-lifecycle.ps1', 'scripts/flux2-common.ps1', 'scripts/engine-guard.ps1')) {
    $path = Join-Path $hexRoot $relative; $pins[$path] = Get-HexLifecycleSha $path
}
if ($Inspect) {
    [ordered]@{mode='Play'; lifecycle=$true; selection=$request.kind; build_id=$package.build_id; runtime_source_sha256=$package.runtime_source_sha256; package_receipt=$request.receipt_relative; package_receipt_sha256=$pins[$request.receipt_path]; executable=$exe; qualified_default=$request.qualified_default; default_selection_unchanged=$true; scope='Validated selection only; no engine or lifecycle run.'} | ConvertTo-Json
    return
}
if (-not $OutputDirectory) { throw 'Lifecycle requires a fresh output directory.' }
$output = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $hexRoot $OutputDirectory }))
$outputRelative = [IO.Path]::GetRelativePath($hexRoot, $output).Replace('\', '/')
if (-not $outputRelative.StartsWith('.godot/', [StringComparison]::Ordinal) -or $outputRelative -match '(^|/)\.\.?(/|$)' -or (Test-Path -LiteralPath $output)) { throw 'Lifecycle output must be a fresh child of this repository .godot directory.' }
Assert-HexLifecyclePhysicalPath $output
. (Join-Path $PSScriptRoot 'flux2-common.ps1')
$hadAppData = Test-Path Env:APPDATA
$savedAppData = $env:APPDATA
$lease = $null; $outputOwned = $false; $failure = $null; $failedCase = $null
$rows = [Collections.Generic.List[object]]::new()
$mainPreferenceHash = ''; $caseName = ''
$cases = @(
    @{name='hearth';seconds=20;wire=0;extra=@('--capture-spawn=1536,880')},
    @{name='garden';seconds=25;wire=0;extra=@('--capture-spawn=4880,720')},
    @{name='paid-fire';seconds=45;wire=145;extra=@('--capture-spawn=1536,880','--capture-pointer=1736,880','--capture-spell-wires=145','--capture-cast-slot=1','--capture-spell-sequence=1,1,1,1,1,1,1,1,1,1,1,1')},
    @{name='paid-all-six-mantle';seconds=45;wire=1319;extra=@('--capture-spawn=1536,880','--capture-pointer=1736,880','--capture-spell-wires=1319','--capture-cast-slot=1','--capture-spell-sequence=1,1,1,1,1,1,1,1,1,1,1,1')},
    @{name='reopen';seconds=20;wire=0;extra=@('--capture-spawn=1536,880')}
)
try {
    $lease = Enter-FluxEngineRun 'desktop-launcher-lifecycle'
    New-Item -ItemType Directory -Path $output -ErrorAction Stop | Out-Null
    $outputOwned = $true
    $env:APPDATA = Join-Path $output 'isolated-roaming'
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    Write-Output "H.E.X. supervised lifecycle: $($request.kind), $($package.build_id). Leave the five windows untouched; each closes normally."
    foreach ($case in $cases) {
        $caseName = $case.name
        Assert-HexLifecyclePins $pins
        $log = Join-Path $output ($caseName + '.log')
        $arguments = @('--windowed','--resolution','1280x720','--','--fullbody-art','--pixel-cast','--no-lan-discovery') + $case.extra
        $started = [DateTime]::UtcNow.ToString('o')
        Push-Location -LiteralPath $payload
        try { Invoke-FluxGodotChecked $exe $arguments $log -RejectWarnings -TimeoutSeconds 120 -CloseAfterSeconds $case.seconds -VisibleWindow | Out-Null }
        finally { Pop-Location }
        $lines = [IO.File]::ReadAllLines($log)
        $identityLine = 'FLUX2 runtime build: ' + $package.build_id + ' | ' + $package.runtime_source_sha256
        if (@($lines | Where-Object {$_ -ceq $identityLine}).Count -ne 1 -or @($lines | Where-Object {$_.StartsWith('FLUX2 runtime build:', [StringComparison]::Ordinal)}).Count -ne 1) { throw 'Unexpected runtime identity in lifecycle log.' }
        if (@($lines | Where-Object {$_ -cmatch '^FLUX2 safe quit: window requested; notified [0-9]+ guest\(s\)$'}).Count -ne 1 -or
            @($lines | Where-Object {$_ -ceq 'FLUX2 safe quit: local state flushed and network peer closed'}).Count -ne 1) { throw 'Missing exact normal window-close and flush markers.' }
        if ((Get-Item -LiteralPath ($log + '.err')).Length -ne 0) { throw 'Nonempty lifecycle stderr.' }
        $casts = Get-HexLifecycleCastSummary $lines
        Assert-HexLifecycleCasts $casts $case.wire
        $profileRoot = Join-Path $env:APPDATA 'Godot/app_userdata/FLUX 2'
        $profileRows = @()
        foreach ($file in @(Get-ChildItem -LiteralPath $profileRoot -File | Where-Object {$_.Name -match '\.(json|bak)$'} | Sort-Object Name)) {
            $profileRows += [ordered]@{name=$file.Name;bytes=$file.Length;sha256=Get-HexLifecycleSha $file.FullName}
        }
        $expectedProfiles = @('player_preferences_v1.json','player_preferences_v1.json.pre_s4_controls.bak')
        if (($profileRows.name -join ',') -cne ($expectedProfiles -join ',')) { throw 'Unexpected isolated profile inventory.' }
        $preferences = Get-Content -Raw -LiteralPath (Join-Path $profileRoot $expectedProfiles[0]) | ConvertFrom-Json
        if ($preferences.schema_version -ne 11 -or $profileRows[0].bytes -le 0) { throw 'Invalid persisted preferences.' }
        if (-not $mainPreferenceHash) { $mainPreferenceHash = $profileRows[0].sha256 }
        if (@($profileRows | Where-Object {$_.sha256 -cne $mainPreferenceHash -or $_.bytes -ne $profileRows[0].bytes}).Count -gt 0) { throw 'Preferences or migration backup changed across the shared-profile route.' }
        Assert-HexLifecyclePins $pins
        $rows.Add([ordered]@{case=$caseName;status='passed';started_utc=$started;scheduled_close_seconds=$case.seconds;exit_mode='front-door-supervised-owned-process-normal-window-close';safe_close_marker=$true;stderr_bytes=0;paid_wire=$case.wire;accepted_casts=$casts.starts.Count;refused_casts=$casts.refusals.Count;released_casts=$casts.releases.Count;cast_rows=$casts;profile_files=$profileRows;log=$log;log_sha256=Get-HexLifecycleSha $log;stderr_sha256=Get-HexLifecycleSha ($log+'.err')})
        Write-Output "PASS lifecycle: $caseName; accepted=$($casts.starts.Count) refused=$($casts.refusals.Count) released=$($casts.releases.Count)"
    }
    Assert-HexLifecyclePins $pins
}
catch { $failure = $_.Exception.Message; $failedCase = $caseName }
finally {
    if ($hadAppData) { $env:APPDATA = $savedAppData } else { Remove-Item Env:APPDATA -ErrorAction SilentlyContinue }
    try { if ($null -ne $lease) { Exit-FluxEngineRun $lease } } catch { $failure = "Lease cleanup failed: $($_.Exception.Message); prior: $failure" }
    if ($outputOwned) {
        $pinsUnchanged = $true
        try { Assert-HexLifecyclePins $pins } catch { $pinsUnchanged = $false; $failure = "Final input pin check failed: $($_.Exception.Message); prior: $failure" }
        $restored = (Test-Path Env:APPDATA) -eq $hadAppData -and (-not $hadAppData -or $env:APPDATA -ceq $savedAppData)
        if (-not $restored) { $failure = "APPDATA restoration failed; prior: $failure" }
        $result = [ordered]@{schema='hex-launcher-lifecycle-v1';status=$(if($failure){'failed'}else{'passed'});failure=$failure;failed_case=$failedCase;build_id=$package.build_id;runtime_source_sha256=$package.runtime_source_sha256;selection=$request.kind;package_receipt=$request.receipt_relative;package_receipt_sha256=$pins[$request.receipt_path];qualified_default=$request.qualified_default;default_selection_unchanged=$pinsUnchanged;input_pins_unchanged=$pinsUnchanged;completed_utc=[DateTime]::UtcNow.ToString('o');input_hashes=$pins;payload_hashes_before=$payloadHashes;cases=$rows.ToArray();shared_isolated_profile_verified=($rows.Count -eq 5 -and -not $failure);caller_appdata_restored=$restored;script_sha256=$pins[$PSCommandPath];desktop_wrapper_evidence='External caller must record the actual shortcut/wrapper route and unchanged bytes; this receipt pins the repository dispatcher, not desktop files.';scope='Supervised launcher route release executable: one fresh shared isolated profile, five sequential normal-close/reopen cases, exactly twelve ordinary accepted and released Fire/Mantle casts, zero refusals or foreign casts in recorded outcomes. Profile rows are recorded boundary hashes, not archived profile contents. No foreground, FPS, physical input, earned progression, damaged-save recovery or replay-export acceptance.'}
        $receiptPath = Join-Path $output 'receipt.json'
        $body = ($result | ConvertTo-Json -Depth 16) + [Environment]::NewLine
        $stream = [IO.File]::Open($receiptPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $bytes = [Text.UTF8Encoding]::new($false).GetBytes($body); $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
        if ([IO.File]::ReadAllText($receiptPath) -cne $body) { throw 'Lifecycle receipt readback failed.' }
    }
}
if ($failure) { throw $failure }
