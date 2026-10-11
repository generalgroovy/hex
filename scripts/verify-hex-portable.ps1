param(
 [Parameter(Mandatory)][string]$BuildDir,
 [Parameter(Mandatory)][string]$ExpectedBuildId,
 [Parameter(Mandatory)][string]$FallbackBuildDir,
 [switch]$Standalone
)
$ErrorActionPreference='Stop'
$hexRoot=Split-Path -Parent $PSScriptRoot
$hexBuild=[IO.Path]::GetFullPath($BuildDir)
$hexFallback=[IO.Path]::GetFullPath($FallbackBuildDir)
$hexPrevious=Get-Content -LiteralPath (Join-Path $hexFallback 'receipt.json') -Raw | ConvertFrom-Json
if($hexPrevious.status -ne 'passed'){throw 'Fallback must have passed its package gate'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$hexPayload=Join-Path $hexBuild 'windows'
$hexPackage=Get-Content -LiteralPath (Join-Path $hexBuild 'receipt.json') -Raw | ConvertFrom-Json
$hexOut=Join-Path $hexBuild 'delivery-files.json'
if(Test-Path -LiteralPath $hexOut){throw 'Fresh verification output required'}
$hexChecks=[ordered]@{}
$hexChecks.packageReceiptPassed=$hexPackage.status -eq 'passed'
$hexChecks.runtimeIdentity=$hexPackage.build_id -eq $ExpectedBuildId
$hexChecks.packHash=(Get-FileHash -LiteralPath (Join-Path $hexPayload 'hex.pck')).Hash.ToLowerInvariant() -eq $hexPackage.pack_sha256
$hexChecks.zipHash=(Get-FileHash -LiteralPath $hexPackage.zip).Hash.ToLowerInvariant() -eq $hexPackage.zip_sha256
$hexManifest=@{}
foreach($hexLine in Get-Content -LiteralPath (Join-Path $hexPayload 'SHA256SUMS.txt')) {
 if($hexLine -notmatch '^([a-f0-9]{64})  ([^/\\]+)$'){throw 'Malformed payload hash line'}
 $hexName=$Matches[2];$hexHash=$Matches[1]
 if($hexManifest.ContainsKey($hexName)){throw 'Duplicate manifest name'}
 $hexManifest[$hexName]=$hexHash
 if((Get-FileHash -LiteralPath (Join-Path $hexPayload $hexName)).Hash.ToLowerInvariant() -ne $hexHash){throw "Payload mismatch: $hexName"}
}
$hexFiles=@(Get-ChildItem -LiteralPath $hexPayload -File)
$hexChecks.payloadInventory=$hexFiles.Count -eq $hexManifest.Count+1
$hexArchive=[IO.Compression.ZipFile]::OpenRead($hexPackage.zip)
$hexZipRows=@()
$hexZipNames=@{} # Case-insensitive: duplicate members cannot hide a missing Windows payload file.
try {
 foreach($hexEntry in $hexArchive.Entries) {
  if($hexEntry.FullName -ne $hexEntry.Name -or -not (Test-Path -LiteralPath (Join-Path $hexPayload $hexEntry.Name) -PathType Leaf)){throw 'Unexpected ZIP member'}
  if($hexZipNames.ContainsKey($hexEntry.Name)){throw "Duplicate ZIP member: $($hexEntry.Name)"}
  $hexZipNames[$hexEntry.Name]=$true
  $hexStream=$hexEntry.Open();$hexSha=[Security.Cryptography.SHA256]::Create()
  try {$hexEntryHash=[Convert]::ToHexString($hexSha.ComputeHash($hexStream)).ToLowerInvariant()} finally {$hexSha.Dispose();$hexStream.Dispose()}
  $hexLocalHash=(Get-FileHash -LiteralPath (Join-Path $hexPayload $hexEntry.Name)).Hash.ToLowerInvariant()
  if($hexEntryHash -ne $hexLocalHash){throw "ZIP bytes differ: $($hexEntry.Name)"}
  $hexZipRows += [ordered]@{name=$hexEntry.Name;bytes=$hexEntry.Length;sha256=$hexEntryHash}
 }
 $hexChecks.zipInventory=$hexArchive.Entries.Count -eq $hexFiles.Count -and $hexZipNames.Count -eq $hexFiles.Count
} finally {$hexArchive.Dispose()}
$hexReadme=Get-Content -LiteralPath (Join-Path $hexPayload 'README-FIRST.txt') -Raw
$hexLauncher=Get-Content -LiteralPath (Join-Path $hexPayload 'PLAY-HEX.cmd') -Raw
$hexChecks.launcherPixelFlags=$hexLauncher.Contains('--fullbody-art --pixel-cast %*')
$hexChecks.instructionsPixelChoice=$hexReadme.Contains('Starting hex.exe directly retains skeleton mode.') -and -not $hexReadme.Contains('Skeleton mode is the default.')
$hexChecks.instructionsInteraction=$hexReadme.Contains('Interact with buildings: F')
$hexChecks.instructionsAttune=$hexReadme.Contains('Academy > Champions > Attune') -and $hexReadme.Contains("saved weave; uncustomized characters use their starter kit.")
$hexChecks.instructionsLimits=$hexReadme.Contains('Internet relay is not') -and $hexReadme.Contains('portable local playtest')
if($Standalone) {
 $hexChecks.instructionsExtract=$hexReadme.Contains('Extract the whole ZIP first; do not run from inside the archive.') -and $hexReadme.Contains('PLAY-HEX.cmd to use this build''s tested presentation settings.')
 $hexChecks.instructionsSeparateFolders=$hexReadme.Contains('Extract each portable into its own folder.') -and $hexReadme.Contains('Keep the previous working folder') -and $hexReadme.Contains('until you have tried the replacement.') -and $hexReadme.Contains('Saved controls and personal weaves are preserved.')
 $hexChecks.instructionsStandalone=$hexReadme.Contains('This archive is ready to run; no Godot') -and $hexReadme.Contains('installation or administrator permission is required.') -and $hexReadme.Contains('It contains no installer') -and $hexReadme.Contains('or automatic updater.') -and -not $hexReadme.Contains('"Install and play"') -and -not $hexReadme.Contains('"Update and play"')
 $hexChecks.instructionsPerformance=$hexReadme.Contains('PERFORMANCE') -and $hexReadme.Contains('Menu > Performance selects Low or Standard visual detail and a 60, 120 or') -and $hexReadme.Contains('unlimited frame limit. Low and 60 FPS are the defaults.') -and $hexReadme.Contains('Low trims decorative') -and $hexReadme.Contains('glow and Garden samples while keeping complete spell areas and danger cues.')
 $hexChecks.instructionsPerformanceRules=$hexReadme.Contains('Movement, collision and paid spell rules still run at 120 Hz. Reduced Motion') -and $hexReadme.Contains('remains a separate accessibility option.') -and $hexReadme.Contains('Far travel prepares its destination') -and $hexReadme.Contains('before offline movement resumes; saved controls and weaves are retained.')
} else {
 $hexChecks.instructionsInstall=$hexReadme.Contains('"Install and play"') -and $hexReadme.Contains('H.E.X. shortcut to open the installed launcher.')
 $hexChecks.instructionsUnsigned=$hexReadme.Contains('This local setup is unsigned;') -and $hexReadme.Contains('Keep Windows security protections enabled.')
 $hexChecks.instructionsUpdateRecovery=$hexReadme.Contains('Close H.E.X. normally before running a newer trusted HEX-Setup') -and $hexReadme.Contains('"Update and play"') -and $hexReadme.Contains('"Previous build"') -and $hexReadme.Contains('your saved settings are not removed.')
}
$hexChecks.fallbackPackUnchanged=(Get-FileHash -LiteralPath (Join-Path $hexFallback 'windows/hex.pck')).Hash.ToLowerInvariant() -eq $hexPrevious.pack_sha256
$hexChecks.fallbackZipUnchanged=(Get-FileHash -LiteralPath $hexPrevious.zip).Hash.ToLowerInvariant() -eq $hexPrevious.zip_sha256
$hexPassed=@($hexChecks.Values | Where-Object {$_ -ne $true}).Count -eq 0
$hexResult=[ordered]@{mode=$(if($Standalone){'standalone'}else{'installer-instructions'});status=$(if($hexPassed){'passed'}else{'failed'});build_id=$hexPackage.build_id;checks=$hexChecks;zip_bytes=(Get-Item -LiteralPath $hexPackage.zip).Length;zip_entries=$hexZipRows;scope='Payload and archive bytes, unique ZIP membership, launcher instructions, preserved fallback; not installer or physical networking acceptance'}
[IO.File]::WriteAllText($hexOut,($hexResult | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
$hexChecks | ConvertTo-Json
if(-not $hexPassed){throw 'Delivery file verification failed'}
