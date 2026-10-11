[CmdletBinding(SupportsShouldProcess)]
param(
 [Parameter(Mandatory)][ValidateCount(2,2)][string[]]$KeepBuild,
 [Parameter(Mandatory)][ValidateCount(2,2)][string[]]$KeepSetup,
 [switch]$Apply
)

# Read-only plan by default. Fixture junctions and retained payload.zip staging
# are deliberately excluded and require separate, exact-file cleanup plans.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$hexRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$hexExportRoot = Join-Path $hexRoot 'exports'
$hexRetentionRoot = Join-Path $hexRoot 'docs/build-retention'
$hexRunId = 'prune-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)

function Assert-HexPlainPath([string]$Path) {
 $hexCheck = [IO.Path]::GetFullPath($Path)
 while ($hexCheck) {
  if (Test-Path -LiteralPath $hexCheck) {
   if ((Get-Item -LiteralPath $hexCheck -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw "Refuse reparse point or reparse ancestor: $hexCheck"
   }
  }
  $hexCheck = [IO.Path]::GetDirectoryName($hexCheck)
 }
}

function Get-HexPlainFiles([string]$Path) {
 Assert-HexPlainPath $Path
 $hexPending = [Collections.Generic.Stack[string]]::new()
 $hexPending.Push($Path)
 while ($hexPending.Count -gt 0) {
  foreach ($hexEntry in Get-ChildItem -LiteralPath $hexPending.Pop() -Force) {
   if ($hexEntry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refuse linked bundle content: $($hexEntry.FullName)" }
   if ($hexEntry.PSIsContainer) { $hexPending.Push($hexEntry.FullName) } else { $hexEntry }
  }
 }
}

function Get-HexHash([string]$Path) {
 (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-HexByteTotal([AllowEmptyCollection()][object[]]$Items, [string]$Property) {
 $hexTotal = 0L
 foreach ($hexItem in $Items) {
  $hexValue = $hexItem.PSObject.Properties[$Property]
  if ($null -eq $hexValue -or $null -eq $hexValue.Value -or [long]$hexValue.Value -lt 0) {
   throw "Missing or invalid byte accounting property: $Property"
  }
  $hexTotal += [long]$hexValue.Value
 }
 $hexTotal
}

function Assert-HexHash([string]$Path, [string]$Expected) {
 if ($Expected -notmatch '^[0-9a-f]{64}$' -or (Get-HexHash $Path) -ne $Expected) { throw "Invalid or mismatched SHA256: $Path" }
}

function Assert-HexManifest([string]$Directory) {
 $hexSeen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
 foreach ($hexLine in Get-Content -LiteralPath (Join-Path $Directory 'SHA256SUMS.txt')) {
  if ($hexLine -notmatch '^([0-9a-f]{64})  ([A-Za-z0-9_.-]+)$') { throw "Invalid payload manifest: $Directory" }
  $hexExpected = $Matches[1]; $hexLeaf = $Matches[2]
  if (-not $hexSeen.Add($hexLeaf)) { throw "Duplicate payload manifest entry: $hexLeaf" }
  Assert-HexHash (Join-Path $Directory $hexLeaf) $hexExpected
 }
 if ($hexSeen.Count -eq 0) { throw "Empty payload manifest: $Directory" }
}

function Get-HexPortable([string]$Path) {
 $hexReceipt = Get-Content -LiteralPath (Join-Path $Path 'receipt.json') -Raw | ConvertFrom-Json
 if ($hexReceipt.status -ne 'passed' -or $hexReceipt.build_id -notmatch '^p[0-9]+-[0-9a-f]{12}$') { throw "Not a passed portable: $Path" }
 $hexWindows = Join-Path $Path 'windows'
 $hexZip = Join-Path $Path ('HEX-' + $hexReceipt.build_id + '-Windows-x64.zip')
 if ([IO.Path]::GetFullPath($hexReceipt.executable) -ne (Join-Path $hexWindows 'hex.exe') -or
     [IO.Path]::GetFullPath($hexReceipt.zip) -ne $hexZip) { throw "Portable receipt escapes its bundle: $Path" }
 Assert-HexManifest $hexWindows
 Assert-HexHash (Join-Path $hexWindows 'hex.pck') $hexReceipt.pack_sha256
 Assert-HexHash $hexZip $hexReceipt.zip_sha256
 $hexIdentity = Get-Content -LiteralPath (Join-Path $hexWindows 'SOURCE-IDENTITY.json') -Raw | ConvertFrom-Json
 if ($hexIdentity.build_id -ne $hexReceipt.build_id -or $hexIdentity.runtime_source_sha256 -ne $hexReceipt.runtime_source_sha256) {
  throw "Portable source identity mismatch: $Path"
 }
 $hexSmoke = Get-Content -LiteralPath (Join-Path $Path 'logs/export-smoke.log') -Raw
 if (-not $hexSmoke.Contains($hexReceipt.build_id) -or -not $hexSmoke.Contains('safe quit: local state flushed and network peer closed')) {
  throw "Native safe-close evidence missing: $Path"
 }
 $hexReceipt
}

function Get-HexSetup([string]$Path) {
 $hexReceipt = Get-Content -LiteralPath (Join-Path $Path 'build-receipt.json') -Raw | ConvertFrom-Json
 if ($hexReceipt.status -ne 'built_not_gameplay_certified' -or $hexReceipt.build_id -notmatch '^p[0-9]+-[0-9a-f]{12}$') {
  throw "Unrecognized setup receipt: $Path"
 }
 $hexInstaller = Join-Path $Path ('HEX-Setup-' + $hexReceipt.build_id + '.exe')
 if ([IO.Path]::GetFullPath($hexReceipt.installer) -ne $hexInstaller) { throw "Setup receipt escapes its bundle: $Path" }
 Assert-HexHash $hexInstaller $hexReceipt.installer_sha256
 Assert-HexManifest $Path
 if (Test-Path -LiteralPath (Join-Path $Path 'payload.zip') -PathType Leaf) {
  Assert-HexHash (Join-Path $Path 'payload.zip') $hexReceipt.embedded_payload_sha256
 }
 $hexReceipt
}

function Assert-HexIdle {
 $hexActive = @(Get-CimInstance Win32_Process | Where-Object {
  $_.ProcessId -ne $PID -and (
   ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($hexExportRoot + '\', [StringComparison]::OrdinalIgnoreCase)) -or
   ($_.CommandLine -and $_.CommandLine.IndexOf($hexExportRoot + '\', [StringComparison]::OrdinalIgnoreCase) -ge 0) -or
   ($_.CommandLine -and $_.CommandLine.IndexOf($hexExportRoot.Replace('\','/') + '/', [StringComparison]::OrdinalIgnoreCase) -ge 0)
  )
 })
 if ($hexActive.Count -gt 0) { throw "An exports executable is running (PID $($hexActive.ProcessId -join ', ')); close it first." }
}

function Assert-HexInventory($Bundle) {
 $hexNow = @(Get-HexPlainFiles $Bundle.path)
 if ($hexNow.Count -ne $Bundle.files.Count) { throw "Bundle inventory changed: $($Bundle.name)" }
 $hexExpected = @{}
 foreach ($hexFile in $Bundle.files) { $hexExpected[$hexFile.relative_path] = $hexFile }
 foreach ($hexFile in $hexNow) {
  $hexRelative = $hexFile.FullName.Substring($Bundle.path.Length + 1).Replace('\','/')
  if (-not $hexExpected.ContainsKey($hexRelative)) { throw "Unexpected new file: $($hexFile.FullName)" }
  $hexPinned = $hexExpected[$hexRelative]
  if ($hexFile.Length -ne $hexPinned.bytes) { throw "Bundle file length changed: $($hexFile.FullName)" }
  Assert-HexHash $hexFile.FullName $hexPinned.sha256
 }
}

# Preflight every candidate and retained bundle before writes or deletions.
Assert-HexPlainPath $hexExportRoot
Assert-HexPlainPath $hexRetentionRoot
if (-not (Test-Path -LiteralPath $hexExportRoot -PathType Container)) { throw 'Export root missing' }
if (@($KeepBuild | Select-Object -Unique).Count -ne 2 -or @($KeepSetup | Select-Object -Unique).Count -ne 2) {
 throw 'Two distinct portable builds and two distinct setups are required'
}
$hexKeepNames = @($KeepBuild) + @($KeepSetup)
if (@($hexKeepNames | Select-Object -Unique).Count -ne 4) { throw 'All four retained directory names must differ' }
foreach ($hexName in $hexKeepNames) {
 if ($hexName -notmatch '^hex-[A-Za-z0-9-]+$') { throw "Invalid retained name: $hexName" }
 $hexPath = Join-Path $hexExportRoot $hexName
 if (-not (Test-Path -LiteralPath $hexPath -PathType Container)) { throw "Retained bundle missing: $hexName" }
 $null = @(Get-HexPlainFiles $hexPath)
}
Assert-HexIdle
$hexTracked = @(& git -C $hexRoot ls-files -- exports)
if ($LASTEXITCODE -ne 0 -or $hexTracked.Count -gt 0) { throw 'Tracked exports or failed tracked-file inspection; refuse cleanup' }
$hexPortableReceipts = @{}
foreach ($hexName in $KeepBuild) { $hexPortableReceipts[$hexName] = Get-HexPortable (Join-Path $hexExportRoot $hexName) }
if (@($hexPortableReceipts.Values.build_id | Select-Object -Unique).Count -ne 2) { throw 'Retained portable identities must differ' }
$hexMatchedBuilds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($hexName in $KeepSetup) {
 $hexSetupReceipt = Get-HexSetup (Join-Path $hexExportRoot $hexName)
 $hexMatch = @($KeepBuild | Where-Object { $hexPortableReceipts[$_].build_id -eq $hexSetupReceipt.build_id })
 if ($hexMatch.Count -ne 1 -or -not $hexMatchedBuilds.Add($hexSetupReceipt.build_id)) { throw "Setup does not uniquely match a retained portable: $hexName" }
 $hexPortable = $hexPortableReceipts[$hexMatch[0]]
 $hexWindows = Join-Path (Join-Path $hexExportRoot $hexMatch[0]) 'windows'
 if ($hexSetupReceipt.embedded_payload_sha256 -ne $hexPortable.zip_sha256 -or [IO.Path]::GetFullPath($hexSetupReceipt.package_dir) -ne $hexWindows) {
  throw "Retained setup/portable payload mismatch: $hexName"
 }
 Assert-HexHash (Join-Path $hexWindows 'SHA256SUMS.txt') $hexSetupReceipt.manifest_sha256
}

# Pin all retained bytes, not just a receipt that could change during archiving.
$hexProtected = @()
foreach ($hexName in $hexKeepNames) {
 $hexPath = Join-Path $hexExportRoot $hexName
 $hexInventory = @(foreach ($hexFile in Get-HexPlainFiles $hexPath) {
  [pscustomobject][ordered]@{ relative_path=$hexFile.FullName.Substring($hexPath.Length + 1).Replace('\','/')
   bytes=[long]$hexFile.Length; sha256=(Get-HexHash $hexFile.FullName) }
 })
 $hexProtected += [pscustomobject][ordered]@{ name=$hexName; path=$hexPath; files=$hexInventory }
}

$hexTargets = @(); $hexRefused = @()
foreach ($hexDirectory in Get-ChildItem -LiteralPath $hexExportRoot -Directory -Force | Sort-Object Name) {
 if ($hexDirectory.Name -in $hexKeepNames -or $hexDirectory.Name -eq 'hex-installer-tests') { continue }
 if ($hexDirectory.Name -notmatch '^hex-[A-Za-z0-9-]+$' -or ($hexDirectory.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
  $hexRefused += [pscustomobject][ordered]@{ name=$hexDirectory.Name; reason='Unknown name or linked directory; untouched' }; continue
 }
 $hexPath = [IO.Path]::GetFullPath($hexDirectory.FullName)
 if ([IO.Path]::GetDirectoryName($hexPath) -ne $hexExportRoot) { throw "Unsafe export target: $hexPath" }
 $hexIsPortable = (Test-Path -LiteralPath (Join-Path $hexPath 'receipt.json') -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $hexPath 'windows') -PathType Container)
 $hexIsSetup = Test-Path -LiteralPath (Join-Path $hexPath 'build-receipt.json') -PathType Leaf
 if ($hexIsPortable -eq $hexIsSetup) {
  $hexRefused += [pscustomobject][ordered]@{ name=$hexDirectory.Name; reason='Missing or ambiguous generated-bundle receipt; untouched' }; continue
 }
 $hexFiles = @(Get-HexPlainFiles $hexPath)
 if ($hexIsPortable) { $hexReceipt = Get-HexPortable $hexPath; $hexKind = 'portable' }
 else { $hexReceipt = Get-HexSetup $hexPath; $hexKind = 'setup' }
 $hexAllowedPayloads = if ($hexIsPortable) {
  @('windows/hex.exe','windows/hex.pck',('HEX-' + $hexReceipt.build_id + '-Windows-x64.zip'))
 } else { @(('HEX-Setup-' + $hexReceipt.build_id + '.exe'),'payload.zip') }
 $hexInventory = @()
 foreach ($hexFile in $hexFiles) {
  $hexRelative = $hexFile.FullName.Substring($hexPath.Length + 1).Replace('\','/')
  $hexIsBinary = $hexFile.Extension.ToLowerInvariant() -in @('.exe','.pck','.zip')
  if ($hexIsBinary -and $hexRelative -notin $hexAllowedPayloads) { throw "Unrecognized binary output: $($hexFile.FullName)" }
  $hexInventory += [pscustomobject][ordered]@{ relative_path=$hexRelative; bytes=[long]$hexFile.Length; sha256=(Get-HexHash $hexFile.FullName)
   action=$(if ($hexIsBinary) { 'delete_generated_payload' } else { 'archive_record' }) }
 }
 $hexArchive = Join-Path (Join-Path $hexRetentionRoot $hexDirectory.Name) $hexRunId
 Assert-HexPlainPath $hexArchive
 if (Test-Path -LiteralPath $hexArchive) { throw "Archive exists; refuse overwrite: $hexArchive" }
 $hexTargets += [pscustomobject][ordered]@{ name=$hexDirectory.Name; kind=$hexKind; build_id=$hexReceipt.build_id; path=$hexPath; archive_path=$hexArchive
  bytes=(Get-HexByteTotal -Items $hexInventory -Property 'bytes')
  payload_bytes=(Get-HexByteTotal -Items @($hexInventory | Where-Object action -EQ 'delete_generated_payload') -Property 'bytes')
  record_bytes=(Get-HexByteTotal -Items @($hexInventory | Where-Object action -EQ 'archive_record') -Property 'bytes')
  files=$hexInventory; status='planned' }
}
if ($hexTargets.Count -eq 0) {
 [ordered]@{ mode='no_changes'; candidate_count=0; payload_bytes=0L; archived_record_bytes=0L
  retained_portable=$KeepBuild; retained_setup=$KeepSetup; candidates=@(); refused_unknown=$hexRefused
  note='No recognized obsolete bundles found; no files written or deleted.' } | ConvertTo-Json -Depth 8
 return
}
$hexManifestPath = Join-Path $hexRetentionRoot ($hexRunId + '.json')
if (Test-Path -LiteralPath $hexManifestPath) { throw 'Manifest exists; refuse overwrite' }
$hexPlan = [ordered]@{ schema_version=2; run_id=$hexRunId; created_utc=[DateTime]::UtcNow.ToString('o'); mode='plan_only'; root=$hexRoot
 retained_portable=$KeepBuild; retained_setup=$KeepSetup; retained_inventory=$hexProtected; installer_fixtures='excluded'; refused_unknown=$hexRefused
 candidate_count=$hexTargets.Count; payload_bytes=(Get-HexByteTotal -Items $hexTargets -Property 'payload_bytes')
 archived_record_bytes=(Get-HexByteTotal -Items $hexTargets -Property 'record_bytes')
 removed_directory_bytes=0L; reclaimed_payload_bytes=0L; manifest_path=$hexManifestPath; targets=$hexTargets }
if (-not $Apply -or -not $PSCmdlet.ShouldProcess($hexExportRoot, "Archive all records and permanently remove $($hexTargets.Count) obsolete bundles")) {
 [ordered]@{ mode='plan_only'; candidate_count=$hexPlan.candidate_count; payload_bytes=$hexPlan.payload_bytes
  archived_record_bytes=$hexPlan.archived_record_bytes; retained_portable=$KeepBuild; retained_setup=$KeepSetup
  candidates=@($hexTargets.name); refused_unknown=$hexRefused; note='No files written or deleted. Review before explicitly using -Apply.' } | ConvertTo-Json -Depth 8
 return
}

# Archive and hash-check ALL records in ALL targets before the first deletion.
$hexPlan.mode = 'archiving'
New-Item -ItemType Directory -Path $hexRetentionRoot -Force | Out-Null
$hexPlan | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $hexManifestPath -Encoding utf8
try {
 foreach ($hexTarget in $hexTargets) {
  foreach ($hexFile in $hexTarget.files | Where-Object action -EQ 'archive_record') {
   $hexDestination = Join-Path $hexTarget.archive_path $hexFile.relative_path
   Assert-HexPlainPath $hexDestination
   if (Test-Path -LiteralPath $hexDestination) { throw "Refuse evidence overwrite: $hexDestination" }
   New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($hexDestination)) -Force | Out-Null
   Copy-Item -LiteralPath (Join-Path $hexTarget.path $hexFile.relative_path) -Destination $hexDestination
   Assert-HexHash $hexDestination $hexFile.sha256
  }
  $hexTarget.status = 'records_archived_and_verified'
 }
 foreach ($hexTarget in $hexTargets) { Assert-HexInventory $hexTarget }
 foreach ($hexBundle in $hexProtected) { Assert-HexInventory $hexBundle }
 foreach ($hexName in $hexKeepNames) { $null = @(Get-HexPlainFiles (Join-Path $hexExportRoot $hexName)) }
 foreach ($hexName in $KeepBuild) { $null = Get-HexPortable (Join-Path $hexExportRoot $hexName) }
 foreach ($hexName in $KeepSetup) { $null = Get-HexSetup (Join-Path $hexExportRoot $hexName) }
 Assert-HexIdle
 $hexTracked = @(& git -C $hexRoot ls-files -- exports)
 if ($LASTEXITCODE -ne 0 -or $hexTracked.Count -gt 0) { throw 'Tracked export status changed; refuse deletion' }
 $hexPlan.mode = 'applying'
 $hexPlan | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $hexManifestPath -Encoding utf8
 foreach ($hexTarget in $hexTargets) {
  Assert-HexIdle
  Assert-HexInventory $hexTarget
  if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($hexTarget.path)) -ne $hexExportRoot -or $hexTarget.name -in $hexKeepNames) { throw 'Unsafe target' }
  $hexTarget.status = 'deletion_started'
  $hexPlan | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $hexManifestPath -Encoding utf8
  Remove-Item -LiteralPath $hexTarget.path -Recurse -Force
  if (Test-Path -LiteralPath $hexTarget.path) { throw "Bundle removal incomplete: $($hexTarget.path)" }
  $hexTarget.status = 'removed_records_archived'
  $hexPlan.removed_directory_bytes += $hexTarget.bytes
  $hexPlan.reclaimed_payload_bytes += $hexTarget.payload_bytes
  $hexPlan | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $hexManifestPath -Encoding utf8
 }
 $hexPlan.mode = 'complete'
} catch {
 $hexPlan.mode = 'failed'; $hexPlan['failure'] = $_.Exception.Message
 throw
} finally {
 $hexPlan | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $hexManifestPath -Encoding utf8
}
[ordered]@{ mode=$hexPlan.mode; removed_bundles=$hexTargets.Count; reclaimed_payload_bytes=$hexPlan.reclaimed_payload_bytes
 archived_record_bytes=$hexPlan.archived_record_bytes; manifest_path=$hexManifestPath
 retained_portable=$KeepBuild; retained_setup=$KeepSetup; refused_unknown=$hexRefused } | ConvertTo-Json -Depth 8
