# Source-only observation-policy tests: no engine, Win32 calls or files written.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'measurement-observation.ps1')
$windowAssertions = 0
function Check-Window([bool]$Condition, [string]$Message) {
    $script:windowAssertions++
    if (-not $Condition) { throw "FAIL: $Message" }
}
function New-WindowSample([long]$At) {
    return [ordered]@{
        elapsed_ms = $At; process_id = 91; main_window_available = $true; main_window_handle = 'FEED'; availability_reason = 'available'
        main_window_process_id = 91; main_window_process_matches = $true; client_width = 1290; client_height = 730
        client_size_scope = 'physical_pixels_per_monitor_v2'; foreground_process_matches = $true; foreground_window_matches = $true
        main_window_visible = $true; main_window_minimized = $false; process_private_bytes = 1200L; process_working_set_bytes = 1800L; error = $null
    }
}
function New-WindowFixture {
    @(
        [ordered]@{ elapsed_ms = 0; main_window_available = $false; availability_reason = 'window_unavailable'; error = $null },
        (New-WindowSample 500), (New-WindowSample 1000), (New-WindowSample 1500),
        [ordered]@{ elapsed_ms = 2000; main_window_available = $false; availability_reason = 'process_exited'; error = $null }
    )
}
$fixture = New-WindowFixture
$before = $fixture | ConvertTo-Json -Depth 16 -Compress
$valid = Get-MeasurementWindowAssessment $fixture 1290 730
Check-Window $valid.qualified_samples 'Unavailable startup/shutdown handles are counted and excluded, with three actual owned foreground samples.'
Check-Window ($valid.counts.boundary_unavailable -eq 2 -and $valid.counts.available -eq 3 -and $valid.counts.foreground -eq 3 -and $valid.observed_span_ms -eq 1000) 'Excluded boundaries do not inflate focus or window coverage.'
Check-Window (($fixture | ConvertTo-Json -Depth 16 -Compress) -ceq $before) 'Admission leaves original evidence untouched.'
Check-Window ($valid.process_memory.max_private_bytes -eq 1200 -and $valid.process_memory.max_working_set_bytes -eq 1800) 'Process memory uses separate retained working-set and private-byte observations.'
foreach ($mutation in @('interior_missing', 'unfocused', 'unknown_foreground', 'other_same_process_window', 'wrong_width', 'wrong_height', 'wrong_owner', 'unknown_owner', 'minimized', 'invisible', 'query_error', 'virtual_pixels', 'unordered', 'long_gap', 'boundary_query_error', 'boundary_missing_reason')) {
    $bad = New-WindowFixture
    switch ($mutation) {
        'interior_missing' { $bad[2].main_window_available = $false; $bad[2].availability_reason = 'window_unavailable' }
        'unfocused' { $bad[2].foreground_process_matches = $false }
        'unknown_foreground' { $bad[2].foreground_process_matches = $null }
        'other_same_process_window' { $bad[2].foreground_window_matches = $false }
        'wrong_width' { $bad[2].client_width = 1280 }
        'wrong_height' { $bad[2].client_height = 720 }
        'wrong_owner' { $bad[2].main_window_process_id = 92 }
        'unknown_owner' { $bad[2].main_window_process_matches = $null }
        'minimized' { $bad[2].main_window_minimized = $true }
        'invisible' { $bad[2].main_window_visible = $false }
        'query_error' { $bad[2].error = 'query failed' }
        'virtual_pixels' { $bad[2].client_size_scope = 'virtualized' }
        'unordered' { $bad[2].elapsed_ms = 500 }
        'long_gap' { $bad[2].elapsed_ms = 2601; $bad[3].elapsed_ms = 3101; $bad[4].elapsed_ms = 3601 }
        'boundary_query_error' { $bad[0].error = 'query failed' }
        'boundary_missing_reason' { $bad[0].availability_reason = '' }
    }
    $assessment = Get-MeasurementWindowAssessment $bad 1290 730
    Check-Window (-not $assessment.qualified_samples -and $assessment.errors.Count -gt 0) "Fail closed without discarding raw evidence: $mutation"
}
Check-Window (-not (Get-MeasurementWindowAssessment @() 1290 730).qualified_samples) 'Missing observations never prove foreground or size.'
Check-Window (-not (Get-MeasurementWindowAssessment @((New-WindowSample 0), (New-WindowSample 500)) 1290 730).qualified_samples) 'Two observations are insufficient, even if both look correct.'
$bad = New-WindowFixture
$bad[2].Remove('process_private_bytes')
$bad[2].Remove('process_working_set_bytes')
Check-Window ((Get-MeasurementWindowAssessment $bad 1290 730).qualified_samples) 'Unavailable optional process memory cannot masquerade as missing window proof or invalidate otherwise valid dimensions/focus.'
$oversize = @(for ($i = 0; $i -lt 3602; $i++) { New-WindowSample ($i * 500L) })
Check-Window (-not (Get-MeasurementWindowAssessment $oversize 1290 730).qualified_samples) 'Imported records cannot exceed the runner watchdog storage bound.'
$activation = [ordered]@{ elapsed_ms = 499L; process_id = 91; window_process_id = 91; window_handle = 'FEED'; requested = $true; native_returned_success = $true; error = $null }
Check-Window (@(Get-MeasurementActivationErrors $false @() $fixture).Count -eq 0) 'Default callers make no foreground request.'
Check-Window (@(Get-MeasurementActivationErrors $true @($activation) $fixture).Count -eq 0) 'One explicitly opted-in owned-HWND request precedes the available samples.'
Check-Window (@(Get-MeasurementActivationErrors $false @($activation) $fixture).Count -gt 0) 'Unexpected foreground activation fails even when window observations look valid.'
Check-Window (@(Get-MeasurementActivationErrors $true @($activation, $activation) $fixture).Count -gt 0) 'A second foreground request cannot be hidden.'
Check-Window (@(Get-MeasurementActivationErrors $true @() $fixture).Count -gt 0) 'Opt-in cannot claim a request without evidence.'
foreach ($mutation in @('wrong_owner', 'wrong_handle', 'late', 'not_requested', 'query_failed')) {
    $badActivation = $activation | ConvertTo-Json | ConvertFrom-Json
    switch ($mutation) {
        'wrong_owner' { $badActivation.window_process_id = 92 }
        'wrong_handle' { $badActivation.window_handle = 'BEEF' }
        'late' { $badActivation.elapsed_ms = 501 }
        'not_requested' { $badActivation.requested = $false }
        'query_failed' { $badActivation.error = 'query failed' }
    }
    Check-Window (@(Get-MeasurementActivationErrors $true @($badActivation) $fixture).Count -gt 0) "Invalid activation witness fails: $mutation"
}
$refusedActivation = $activation | ConvertTo-Json | ConvertFrom-Json
$refusedActivation.native_returned_success = $false
Check-Window (@(Get-MeasurementActivationErrors $true @($refusedActivation) $fixture).Count -eq 0) 'Native refusal is retained separately; only actual window samples can prove foreground, including an already foreground window.'
Write-Output "measurement-observation: $windowAssertions assertions passed"
