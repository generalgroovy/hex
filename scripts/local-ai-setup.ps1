#Requires -Version 7.4
[CmdletBinding()]
param([switch]$Download)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows -or -not [Environment]::Is64BitProcess) {
    throw 'This portable bundle requires Windows x64 and 64-bit PowerShell 7.4 or newer.'
}

# Explicit pins: never silently upgrade a runtime or model on a setup rerun.
$taskRoot = Join-Path $env:LOCALAPPDATA 'FLUX-dev\local-ai'
$runtimeTag = 'b10809'
$runtimeCommit = '5266f24da75dc449bd56cbed7addb9c8e4a6a73e'
$runtimeArchiveName = 'llama-b10809-bin-win-cpu-x64.zip'
$runtimeSha = '9df3158ed228a641a4b127942d7f459f24c9e13f04682659d05c00c80099b6b5'
$runtimeUrl = "https://github.com/ggml-org/llama.cpp/releases/download/$runtimeTag/$runtimeArchiveName"
$modelRevision = 'f86cb2c1fa58255f8052cc32aeede1b7482d4361'
$modelName = 'qwen2.5-coder-1.5b-instruct-q4_k_m.gguf'
$modelSha = 'cc324af070c2ecbfd324a30884d2f951a7ff756aba85cb811a6ec436933bb046'
$modelBase = "https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/$modelRevision"
$runtimeRoot = Join-Path $taskRoot "runtime\$runtimeTag"
$modelRoot = Join-Path $taskRoot "models\Qwen2.5-Coder-1.5B-Instruct\$modelRevision"
$archivePath = Join-Path $taskRoot "downloads\$runtimeArchiveName"
$modelPath = Join-Path $modelRoot $modelName
# In this release llama-cli starts an internal HTTP server. Completion is the
# direct in-process runner and is intentionally used to avoid listening sockets.
$cliPath = Join-Path $runtimeRoot 'llama-completion.exe'

function Assert-FileHash([string]$Path, [string]$Expected, [long]$Size) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing: $Path" }
    if ($Size -gt 0 -and (Get-Item -LiteralPath $Path).Length -ne $Size) {
        throw "Unexpected length: $Path (existing file preserved)."
    }
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Expected) {
        throw "SHA-256 mismatch: $Path (existing file preserved; do not execute)."
    }
}

function Get-PinnedFile([string]$Url, [string]$Path, [string]$Sha, [long]$Size) {
    if (Test-Path -LiteralPath $Path) {
        Assert-FileHash $Path $Sha $Size
        Write-Host "Verified existing: $Path"
        return
    }
    $partialPath = "$Path.partial"
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    Write-Host "Downloading pinned file ($Size bytes): $Url"
    # curl downloads bytes only. No installer, remote source script, or model code is run.
    & curl.exe --fail --location --silent --show-error --retry 2 --connect-timeout 30 --max-time 1800 --continue-at - --output $partialPath $Url
    if ($LASTEXITCODE -ne 0) { throw "Download failed; resumable partial retained: $partialPath" }
    Assert-FileHash $partialPath $Sha $Size
    Move-Item -LiteralPath $partialPath -Destination $Path
}

if ($Download) {
    Get-PinnedFile $runtimeUrl $archivePath $runtimeSha 18407457
    Get-PinnedFile "$modelBase/$modelName" $modelPath $modelSha 1117320768
    if (-not (Test-Path -LiteralPath $runtimeRoot)) {
        New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
        $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
        try {
            $allowedRoot = [IO.Path]::GetFullPath($runtimeRoot).TrimEnd('\') + '\'
            foreach ($entry in $archive.Entries) {
                $entryPath = [IO.Path]::GetFullPath((Join-Path $runtimeRoot $entry.FullName))
                if (-not $entryPath.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
                    throw "Unsafe archive entry: $($entry.FullName)"
                }
            }
        } finally { $archive.Dispose() }
        Expand-Archive -LiteralPath $archivePath -DestinationPath $runtimeRoot
    }
    foreach ($license in @(
        @{ Url = "$modelBase/LICENSE"; Path = (Join-Path $modelRoot 'LICENSE') },
        @{ Url = "https://raw.githubusercontent.com/ggml-org/llama.cpp/$runtimeCommit/LICENSE"; Path = (Join-Path $runtimeRoot 'LICENSE-llama.cpp') }
    )) {
        if (-not (Test-Path -LiteralPath $license.Path)) {
            Invoke-WebRequest -Uri $license.Url -OutFile $license.Path -TimeoutSec 60
        }
    }
}

Assert-FileHash $archivePath $runtimeSha 18407457
Assert-FileHash $modelPath $modelSha 1117320768
if (-not (Test-Path -LiteralPath $cliPath -PathType Leaf)) { throw "Missing CLI: $cliPath" }
# Verify extracted bytes against the already hash-verified official archive.
# A modified DLL or executable must never be trusted just because the ZIP remains intact.
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $allowedRoot = [IO.Path]::GetFullPath($runtimeRoot).TrimEnd('\') + '\'
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name)) { continue }
        $entryPath = [IO.Path]::GetFullPath((Join-Path $runtimeRoot $entry.FullName))
        if (-not $entryPath.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Unsafe archive entry: $($entry.FullName)"
        }
        $entryStream = $entry.Open()
        try { $entryHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($entryStream)) }
        finally { $entryStream.Dispose() }
        Assert-FileHash $entryPath $entryHash $entry.Length
    }
} finally { $archive.Dispose() }
$stream = [IO.File]::OpenRead($modelPath)
try {
    $header = New-Object byte[] 4
    [void]$stream.Read($header, 0, 4)
    if ([Text.Encoding]::ASCII.GetString($header) -ne 'GGUF') { throw 'Model is not a GGUF file.' }
} finally { $stream.Dispose() }

$manifest = [ordered]@{
    schemaVersion = 1
    verifiedAtUtc = [DateTime]::UtcNow.ToString('o')
    runtime = [ordered]@{
        tag = $runtimeTag; commit = $runtimeCommit; archive = $archivePath
        source = $runtimeUrl; sha256 = $runtimeSha; license = 'MIT'
        executable = $cliPath
        executableSha256 = (Get-FileHash -LiteralPath $cliPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    model = [ordered]@{
        id = 'Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF'; revision = $modelRevision
        file = $modelPath; source = "$modelBase/$modelName"; bytes = 1117320768
        sha256 = $modelSha; license = 'Apache-2.0'; quantization = 'Q4_K_M'
    }
    use = 'Offline advisory text only. No tools, repository edits, server, service, or global PATH changes.'
}
if ($Download) {
    $manifestPath = Join-Path $taskRoot 'installed-manifest.json'
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    Write-Host "Installation manifest: $manifestPath"
}
$manifest | ConvertTo-Json -Depth 5
