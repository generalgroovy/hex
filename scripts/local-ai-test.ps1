#Requires -Version 7.4
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$askScript = Join-Path $PSScriptRoot 'local-ai-ask.ps1'
$passed = 0

function Expect-Rejection([string]$Name, [scriptblock]$Operation, [string]$Pattern) {
    $caught = $null
    try { & $Operation | Out-Null } catch { $caught = $_.Exception.Message }
    if (-not $caught -or $caught -notmatch $Pattern) {
        throw "FAIL ${Name}: expected rejection /$Pattern/; got '$caught'"
    }
    Write-Host "PASS $Name"
    $script:passed++
}

foreach ($path in @($askScript, (Join-Path $PSScriptRoot 'local-ai-setup.ps1'), $PSCommandPath)) {
    $parseTokens = $null
    $parseErrors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($path, [ref]$parseTokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw "Parse failure: $path $parseErrors" }
    Write-Host "PASS syntax: $(Split-Path -Leaf $path)"
    $passed++
}

# Every functional case must fail before reading model weights or starting a process.
Expect-Rejection 'blank prompt' { & $askScript -Prompt '  ' } 'Prompt must contain'
Expect-Rejection 'oversized text' { & $askScript -Prompt ('a' * 1537) } 'Prompt must contain'
Expect-Rejection 'UTF-8 byte limit' { & $askScript -Prompt ([string][char]0x20ac * 513) } 'Prompt must contain'
Expect-Rejection 'bounded generation' { & $askScript -Prompt 'test' -MaxTokens 193 } 'MaxTokens'
Expect-Rejection 'bounded timeout' { & $askScript -Prompt 'test' -TimeoutSeconds 181 } 'TimeoutSeconds'
Expect-Rejection 'low-memory gate' {
    function Get-CimInstance { [pscustomobject]@{ FreePhysicalMemory = 1024 * 1024 } }
    & $askScript -Prompt 'test'
} 'at least 1.5 GiB is required'
Expect-Rejection 'active Godot gate' {
    function Get-CimInstance { [pscustomobject]@{ FreePhysicalMemory = 3 * 1024 * 1024 } }
    function Get-Process { [pscustomobject]@{ ProcessName = 'Godot'; Id = 1 } }
    & $askScript -Prompt 'test'
} 'Godot or local-inference process is active'

Write-Output "Local AI guard tests: $passed passed; no downloads, model inference, or repository edits performed."
