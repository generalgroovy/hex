param([Parameter(Mandatory)][string]$ExpectedBuildId)
$ErrorActionPreference='Stop'
$hexRoot='C:/Users/sende/Projects/hex'
$hexBuild=Join-Path $hexRoot 'exports/hex-refinement-20261005'
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
$hexChecks.instructionsLimits=$hexReadme.Contains('Internet relay is not') -and $hexReadme.Contains('not an installer/updater')
$hexChecks.fallbackPackUnchanged=(Get-FileHash -LiteralPath (Join-Path $hexRoot 'exports/hex-throughput-20261005/windows/hex.pck')).Hash.ToLowerInvariant() -eq '58f327d427ded2a2f535cf98fd6095adf741145a0517f192adca8a5791cd4f8c'
$hexChecks.fallbackZipUnchanged=(Get-FileHash -LiteralPath (Join-Path $hexRoot 'exports/hex-throughput-20261005/HEX-p56-4c82db23d160-Windows-x64.zip')).Hash.ToLowerInvariant() -eq 'e58bfe807031b7547768b0b56cf41247ab00ed4cfd842dfb195b5fca483d9238'
$hexPassed=@($hexChecks.Values | Where-Object {$_ -ne $true}).Count -eq 0
$hexResult=[ordered]@{status=$(if($hexPassed){'passed'}else{'failed'});build_id=$hexPackage.build_id;checks=$hexChecks;zip_bytes=(Get-Item -LiteralPath $hexPackage.zip).Length;zip_entries=$hexZipRows;scope='Payload and archive bytes, unique ZIP membership, launcher instructions, preserved fallback; not installer or physical networking acceptance'}
[IO.File]::WriteAllText($hexOut,($hexResult | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
$hexChecks | ConvertTo-Json
if(-not $hexPassed){throw 'Delivery file verification failed'}
