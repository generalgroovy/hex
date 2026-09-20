param(
    [switch]$Check,
    [switch]$Json,
    [switch]$Quiet,
    [string]$OutputPath = ''
)

. (Join-Path $PSScriptRoot 'flux2-common.ps1')

$repoRoot = Get-FluxRepoRoot
if ($Check) {
    & (Join-Path $PSScriptRoot 'check-current-scope.ps1') -Quiet
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot '.godot\reports\current-state.json'
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $repoRoot $OutputPath
}
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$issues = [System.Collections.Generic.List[string]]::new()

function Read-FluxJson([string]$RelativePath) {
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required current-state input is missing: $RelativePath"
    }
    return Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
}

function Read-FluxText([string]$RelativePath) {
    $path = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required current-state input is missing: $RelativePath"
    }
    return Get-Content -Raw -LiteralPath $path
}

function Get-FluxSourceInteger([string]$RelativePath, [string]$ConstantName) {
    $text = Read-FluxText $RelativePath
    $pattern = 'const\s+' + [regex]::Escape($ConstantName) + '\s*:\s*int\s*=\s*([0-9_]+)'
    $match = [regex]::Match($text, $pattern)
    if (-not $match.Success) {
        throw "Cannot resolve integer constant $ConstantName from $RelativePath"
    }
    return [int]($match.Groups[1].Value.Replace('_', ''))
}

function Get-FluxProjectInteger([string]$SettingName) {
    $text = Read-FluxText 'project.godot'
    $match = [regex]::Match($text, '(?m)^' + [regex]::Escape($SettingName) + '=([0-9]+)[ \t]*\r?$')
    if (-not $match.Success) {
        throw "Cannot resolve project setting $SettingName"
    }
    return [int]$match.Groups[1].Value
}

function Get-FluxGitValue([string[]]$Arguments) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
    $value = & git -C $repoRoot @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return (($value | Out-String).Trim())
}

function Add-FluxIssue([bool]$Condition, [string]$Message) {
    if (-not $Condition) { $issues.Add($Message) }
}

function Get-FluxCharacterArtCoverage($Root, $Catalog, $Visual, $Overrides, [bool]$OverridePresent = $true) {
    # Source-only audit. Never query resident textures/recipe flags: an override
    # also replaces a foundation identity, while template aliases keep old pages.
    $diagnostics = [System.Collections.Generic.List[object]]::new()
    function Field($Value, [string]$Name) {
        if ($null -eq $Value) { return $null }
        if ($Value -is [System.Collections.IDictionary]) { return $Value[$Name] }
        $property = $Value.PSObject.Properties[$Name]
        if ($null -ne $property) { return $property.Value }
        return $null
    }
    function ObjectValue($Value) { return ($Value -is [pscustomobject] -or $Value -is [System.Collections.IDictionary]) }
    function Keys($Value) {
        if ($Value -is [System.Collections.IDictionary]) { return @($Value.Keys) }
        if ($Value -is [pscustomobject]) { return @($Value.PSObject.Properties.Name) }
        return @()
    }
    function Problem([string]$Code, [string]$Identity, [string]$Message) {
        $diagnostics.Add([ordered]@{ code = $Code; champion_id = $Identity; message = $Message })
    }
    function ExactArray($Actual, $Expected, [bool]$Numeric = $false) {
        if ($Actual -isnot [System.Collections.IList] -or $Actual.Count -ne $Expected.Count) { return $false }
        for ($i = 0; $i -lt $Expected.Count; $i++) {
            if ($Numeric -and ($Actual[$i] -is [string] -or $Actual[$i] -is [bool] -or $null -eq $Actual[$i])) { return $false }
            if ($Actual[$i] -cne $Expected[$i]) { return $false }
        }
        return $true
    }
    function ExactNumber($Value, $Expected) {
        return ($null -ne $Value -and $Value -isnot [string] -and $Value -isnot [bool] -and $Value -eq $Expected)
    }
    function CheckSource($Page, [string]$Identity, [int]$Width, [int]$Height) {
        $before = $diagnostics.Count
        if (-not (ObjectValue $Page)) { Problem 'page_object' $Identity 'Page descriptor must be an object.'; return $false }
        foreach ($name in @('sha256', 'imported_rgba_sha256')) {
            if ([string](Field $Page $name) -cnotmatch '^[0-9a-f]{64}$') { Problem 'page_digest' $Identity "Invalid $name declaration." }
        }
        $resource = [string](Field $Page 'path')
        $parts = $resource -split '/'
        if (-not $resource.StartsWith('res://assets/sprites/champions_v3/', [StringComparison]::Ordinal) -or
            -not $resource.EndsWith('.png', [StringComparison]::Ordinal) -or $resource.Contains('\') -or
            @($parts | Select-Object -Skip 3 | Where-Object { $_ -in @('', '.', '..') -or $_.Contains(':') }).Count -gt 0) {
            Problem 'page_path' $Identity "PNG path is not a canonical contained character asset: $resource"
            return $false
        }
        try {
            $assetRoot = [IO.Path]::GetFullPath((Join-Path $Root 'assets/sprites/champions_v3'))
            $path = [IO.Path]::GetFullPath((Join-Path $Root $resource.Substring(6)))
        } catch { Problem 'page_path' $Identity 'PNG path cannot be resolved safely.'; return $false }
        if (-not $path.StartsWith($assetRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            Problem 'page_path' $Identity 'PNG escapes the character asset directory.'; return $false
        }
        # Lexical containment alone does not contain directory junctions.
        $cursor = $path
        while ($cursor -and $cursor.Length -ge $assetRoot.Length) {
            if (Test-Path -LiteralPath $cursor) {
                if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                    Problem 'page_path' $Identity 'PNG path traverses a reparse point.'; return $false
                }
            }
            $cursor = Split-Path -Parent $cursor
        }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Problem 'page_missing' $Identity "Missing raw source PNG: $resource"; return $false }
        try {
            $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($actual -cne [string](Field $Page 'sha256')) { Problem 'page_sha256' $Identity "Raw source PNG SHA-256 mismatch: $resource" }
            $stream = [IO.File]::OpenRead($path)
            try { $header = [byte[]]::new(24); $read = $stream.Read($header, 0, 24) } finally { $stream.Dispose() }
            if ($read -ne 24 -or ([BitConverter]::ToString($header[0..15])) -cne '89-50-4E-47-0D-0A-1A-0A-00-00-00-0D-49-48-44-52') {
                Problem 'page_png_header' $Identity 'Source is not a PNG with an IHDR header.'
            } else {
                $actualWidth = [uint64]$header[16] * 16777216 + [uint64]$header[17] * 65536 + [uint64]$header[18] * 256 + $header[19]
                $actualHeight = [uint64]$header[20] * 16777216 + [uint64]$header[21] * 65536 + [uint64]$header[22] * 256 + $header[23]
                if ($actualWidth -ne $Width -or $actualHeight -ne $Height) { Problem 'page_dimensions' $Identity "Source PNG header is ${actualWidth}x${actualHeight}; expected ${Width}x${Height}." }
            }
        } catch { Problem 'page_read' $Identity $_.Exception.Message }
        return ($diagnostics.Count -eq $before)
    }

    $catalogById = [System.Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $baseline = [System.Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $fallbackIds = [System.Collections.Generic.List[string]]::new()
    $entries = @(Field $Catalog 'champions')
    foreach ($entry in $entries) {
        $id = [string](Field $entry 'id')
        if (-not (ObjectValue $entry) -or -not $id -or $catalogById.ContainsKey($id)) { Problem 'catalog_identity' $id 'Catalog identity is empty or duplicated.'; continue }
        $catalogById.Add($id, $entry)
        if ([string](Field $entry 'art_status') -ceq 'temporary_body_template') { $fallbackIds.Add($id) }
    }
    $directions = @('south','south_east','east','north_east','north','north_west','west','south_west')
    $states = @('grounded','jump','cast','hit','walk','sprint','slide','roll','walk_b','sprint_b')
    $atlas = Field $Visual 'atlas'
    $foundationIds = @(Field $atlas 'champions')
    $recipes = Field $Visual 'champions'
    $extensions = Field $Visual 'extension_atlases'
    $templates = Field (Field $Visual 'body_template_contract') 'templates'
    if (-not (ExactNumber (Field $Visual 'schema_version') 15) -or (Field $Visual 'id') -cne 'foundation-champion-visuals-v15-motion-facing' -or
        (Field $Visual 'authority') -cne 'presentation only; hitboxes, movement, casts and outcomes remain authoritative elsewhere' -or
        (Field $Visual 'atlas_role') -cne 'body_and_clothing_only' -or -not (ExactArray $foundationIds @('oh_tipi','s_wayne','red_baron')) -or
        -not (ExactArray (Field $Visual 'cell') @(96,96) $true) -or -not (ExactArray (Field $Visual 'pivot') @(48,84) $true) -or
        -not (ExactArray (Field $atlas 'directions') $directions) -or -not (ExactArray (Field $atlas 'states') $states) -or
        (Field $atlas 'row_layout') -cne 'champion_major_state_minor' -or -not (ObjectValue $recipes) -or -not (ObjectValue $extensions)) {
        Problem 'baseline_contract' '' 'Baseline art identity, geometry or recipe/page mapping is unsupported.'
    }
    $atlasValid = CheckSource $atlas 'foundation-atlas' 768 ($foundationIds.Count * 960)
    $extensionPaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($id in @(Keys $recipes)) {
        $recipe = Field $recipes $id
        if (-not $catalogById.ContainsKey($id)) { Problem 'baseline_identity' $id 'Baseline recipe has no live catalog identity.'; continue }
        $body = [string](Field $catalogById[$id] 'body_type')
        $height = Field (Field $templates $body) 'reference_height'
        $valid = $true
        if (-not $height -or (Field $recipe 'body_type') -cne $body -or -not (ExactNumber (Field $recipe 'height') $height)) {
            Problem 'baseline_body' $id 'Baseline body/height differs from the catalog and body guide.'; $valid = $false
        }
        if ($foundationIds -ccontains $id) {
            if ((Field $recipe 'atlas_row') -ne [Array]::IndexOf($foundationIds, $id)) { Problem 'baseline_row' $id 'Foundation atlas row does not match its identity.'; $valid = $false }
            $valid = $valid -and $atlasValid
            $pagePath = [string](Field $atlas 'path')
        } else {
            $page = Field $extensions $id
            $pagePath = [string](Field $page 'path')
            if (-not $extensionPaths.Add($pagePath)) { Problem 'baseline_page_duplicate' $id 'Extension identities share a source page.'; $valid = $false }
            if (-not (CheckSource $page $id 768 960)) { $valid = $false }
        }
        if ($valid) {
            $baselinePage = $(if ($foundationIds -ccontains $id) { $atlas } else { $page })
            $baseline.Add($id, [ordered]@{ path = $pagePath; body_type = $body; extension = ($foundationIds -cnotcontains $id); sha256 = Field $baselinePage 'sha256'; imported_rgba_sha256 = Field $baselinePage 'imported_rgba_sha256' })
        }
    }
    foreach ($id in $foundationIds + @(Keys $extensions)) {
        if (-not (Field $recipes $id)) { Problem 'baseline_recipe_missing' $id 'Atlas identity lacks a matching baseline recipe.' }
    }
    foreach ($id in $catalogById.Keys) {
        if (Field $recipes $id) { continue }
        $entry = $catalogById[$id]
        $templateId = [string](Field $entry 'template_source_id')
        if ([string](Field $entry 'art_status') -cne 'temporary_body_template' -or (Field $entry 'unique_runtime_art_approved') -isnot [bool] -or
            (Field $entry 'unique_runtime_art_approved') -ne $false -or $foundationIds -cnotcontains $templateId -or -not $baseline.ContainsKey($templateId) -or
            (Field $entry 'body_type') -cne (Field (Field $recipes $templateId) 'body_type')) {
            Problem 'template_registration' $id 'Catalog alias lacks an explicit same-body foundation template.'
        }
    }

    $registryStart = $diagnostics.Count
    $declaredIds = @()
    $checkedIds = [System.Collections.Generic.List[string]]::new()
    if ($OverridePresent) {
        $pages = Field $Overrides 'pages'
        if (-not (ExactNumber (Field $Overrides 'schema_version') 1) -or (Field $Overrides 'id') -cne 'champion-complete-page-overrides-v1' -or
            (Field $Overrides 'authority') -cne (Field $Visual 'authority') -or (Field $Overrides 'atlas_role') -cne 'body_and_clothing_only' -or
            -not (ExactNumber (Field $Overrides 'frame_count') 80) -or (Field $Overrides 'row_layout') -cne 'state_major_direction_minor' -or
            (Field $Overrides 'timing') -cne 'existing_minimal_champion_motion' -or (Field $Overrides 'sampling') -cne 'nearest_no_mipmaps' -or
            -not (ExactArray (Field $Overrides 'cell') @(96,96) $true) -or -not (ExactArray (Field $Overrides 'pivot') @(48,84) $true) -or
            -not (ExactArray (Field $Overrides 'dimensions') @(768,960) $true) -or -not (ExactArray (Field $Overrides 'runtime_scale') @(1,1) $true) -or
            -not (ExactArray (Field $Overrides 'directions') $directions) -or -not (ExactArray (Field $Overrides 'states') $states) -or -not (ObjectValue $pages)) {
            Problem 'override_contract' '' 'Override registry identity, geometry, timing or pages object is invalid.'
        }
        $declaredIds = @(Keys $pages | Sort-Object)
        if ($declaredIds.Count -gt $catalogById.Count) { Problem 'override_capacity' '' 'Override declarations exceed the live catalog.' }
        $seenPaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $seenSources = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $seenPixels = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($id in $declaredIds) {
            $pageStart = $diagnostics.Count
            $page = Field $pages $id
            if (-not $catalogById.ContainsKey($id)) { Problem 'override_identity' $id 'Override identity is absent from the playable catalog.' }
            else {
                $body = [string](Field $catalogById[$id] 'body_type')
                if ((Field $page 'body_type') -cne $body -or -not (ExactNumber (Field $page 'reference_height') (Field (Field $templates $body) 'reference_height'))) {
                    Problem 'override_body' $id 'Override body/height disagrees with the catalog body guide.'
                }
            }
            if ((Field $page 'status') -cne 'reviewed_complete_runtime_page' -or (Field $page 'visible_feet_y') -is [string] -or (Field $page 'visible_feet_y') -notin @(83,84)) {
                Problem 'override_registration' $id 'Override approval declaration or feet registration is invalid.'
            }
            if (-not $seenPaths.Add([string](Field $page 'path')) -or -not $seenSources.Add([string](Field $page 'sha256')) -or -not $seenPixels.Add([string](Field $page 'imported_rgba_sha256'))) {
                Problem 'override_duplicate' $id 'Override path, raw digest or declared decoded-pixel digest duplicates another override.'
            }
            foreach ($baselineId in $baseline.Keys) {
                if ($baselineId -ceq $id -or -not $baseline[$baselineId].extension) { continue }
                $prior = $baseline[$baselineId]
                if ([StringComparer]::OrdinalIgnoreCase.Equals([string](Field $page 'path'), [string]$prior.path) -or
                    (Field $page 'sha256') -ceq $prior.sha256 -or (Field $page 'imported_rgba_sha256') -ceq $prior.imported_rgba_sha256) {
                    Problem 'override_baseline_duplicate' $id "Override duplicates another baseline extension identity: $baselineId."
                    break
                }
            }
            $null = CheckSource $page $id 768 960
            if ($diagnostics.Count -eq $pageStart) { $checkedIds.Add($id) }
        }
    }
    $registryValid = $diagnostics.Count -eq $registryStart
    $effective = [System.Collections.Generic.List[object]]::new()
    $individualIds = [System.Collections.Generic.List[string]]::new()
    $templateIds = [System.Collections.Generic.List[string]]::new()
    if ($diagnostics.Count -eq 0) {
        foreach ($id in @($catalogById.Keys | Sort-Object)) {
            if ($checkedIds.Contains($id)) {
                $kind = 'individual_override'; $sourceId = $id; $sourcePath = Field (Field (Field $Overrides 'pages') $id) 'path'; $individualIds.Add($id)
            } elseif ($baseline.ContainsKey($id)) {
                $kind = 'individual_baseline'; $sourceId = $id; $sourcePath = $baseline[$id].path; $individualIds.Add($id)
            } else {
                $kind = 'body_template'; $sourceId = [string](Field $catalogById[$id] 'template_source_id'); $sourcePath = $baseline[$sourceId].path; $templateIds.Add($id)
            }
            $effective.Add([ordered]@{ champion_id = $id; body_type = Field $catalogById[$id] 'body_type'; classification = $kind; source_identity = $sourceId; source_path = $sourcePath })
        }
    }
    return [ordered]@{
        schema_version = 1
        evidence = 'Source catalog/manifest metadata, contained raw PNG SHA-256 and PNG-header dimensions only. Not imported-RGBA, cell/alpha validation, human art approval, texture residency, or release acceptance. Cross-baseline extension comparisons include declared pixel digests; cropped/recompressed foundation identity requires runtime decoded checks.'
        decoded_identity_uniqueness_verified = $false
        source_validation_passed = ($diagnostics.Count -eq 0)
        playable_count = $catalogById.Count
        catalog_fallback_declaration_count = $fallbackIds.Count
        catalog_fallback_declared_ids = @($fallbackIds | Sort-Object)
        baseline_source_checked_individual_count = $baseline.Count
        baseline_source_checked_individual_ids = @($baseline.Keys | Sort-Object)
        override_registry_present = $OverridePresent
        override_registry_source_validation_passed = $registryValid
        override_declared_ids = $declaredIds
        override_declared_count = $declaredIds.Count
        override_source_checked_page_ids = @($checkedIds)
        override_source_checked_page_count = $checkedIds.Count
        validated_registry_declared_override_ids = @(if ($registryValid) { $declaredIds })
        effective_individual_count = $(if ($diagnostics.Count -eq 0) { $individualIds.Count } else { $null })
        effective_template_count = $(if ($diagnostics.Count -eq 0) { $templateIds.Count } else { $null })
        effective_individual_ids = @($individualIds)
        effective_template_ids = @($templateIds)
        effective_identities = @($effective)
        diagnostics = @($diagnostics)
    }
}

function Get-FluxActiveCharacterArtCoverage($Root, $Catalog, $Manifest, [string]$PresenterSource, [string]$BodyPresenterSource, [string]$BootstrapSource, $LegacyArt) {
    # Keep the independent legacy audit intact; its totals describe opt-in old
    # pages, not the source-default wireframe presentation used by bootstrap.
    $diagnostics = [Collections.Generic.List[object]]::new()
    function Field($Value, [string]$Name) {
        if ($null -eq $Value) { return $null }
        if ($Value -is [Collections.IDictionary]) { return $Value[$Name] }
        $property = $Value.PSObject.Properties[$Name]
        if ($null -ne $property) { return $property.Value }
        return $null
    }
    function Keys($Value) {
        if ($Value -is [Collections.IDictionary]) { return @($Value.Keys) }
        if ($Value -is [pscustomobject]) { return @($Value.PSObject.Properties.Name) }
        return @()
    }
    function Problem([string]$Code, [string]$Identity, [string]$Message) {
        $diagnostics.Add([ordered]@{ code = $Code; champion_id = $Identity; message = $Message })
    }
    function ExactNumber($Value, $Expected) {
        return ($null -ne $Value -and $Value -isnot [string] -and $Value -isnot [bool] -and $Value -eq $Expected)
    }
    function ExactArray($Actual, $Expected, [bool]$Numeric = $false) {
        if ($Actual -isnot [Collections.IList] -or $Actual.Count -ne $Expected.Count) { return $false }
        for ($i = 0; $i -lt $Expected.Count; $i++) {
            if ($Numeric -and -not (ExactNumber $Actual[$i] $Expected[$i])) { return $false }
            if ($Actual[$i] -cne $Expected[$i]) { return $false }
        }
        return $true
    }
    $manifestPath = 'res://assets/sprites/wireframe_motion_v2/manifest.json'
    $bindingRecognized = $PresenterSource -match '(?m)^var wireframe_mode:\s*bool\s*=\s*true\s*\r?$' -and
        $PresenterSource -match '(?m)^func configure\([^\r\n]*use_wireframe:\s*bool\s*=\s*true\)' -and
        $PresenterSource -match '(?m)^\s+wireframe_mode = use_wireframe\s*\r?$' -and
        $PresenterSource -match '(?m)^\s+if not wireframe_body\.configure\(\):\s*\r?$' -and
        $BodyPresenterSource -match ('(?m)^const DEFAULT_PATH := "' + [regex]::Escape($manifestPath) + '"\s*\r?$') -and
        $BootstrapSource -match '(?m)^\s*if not cartoon_champion_presenter\.configure\(visual_language\):\s*\r?$'
    if (-not $bindingRecognized) { Problem 'wireframe_source_binding' '' 'Default presenter/manifest/bootstrap binding is not the recognized wireframe source path; active totals withheld.' }
    $directions = @('south','south_east','east','north_east','north','north_west','west','south_west')
    $states = @('grounded','jump','cast','hit','walk','sprint','slide','roll','walk_b','sprint_b')
    $layout = Field $Manifest 'locomotion'
    $sizes = Field $Manifest 'sizes'
    if (-not (ExactNumber (Field $Manifest 'schema_version') 2) -or
        -not (ExactArray (Field $Manifest 'cell') @(96,96) $true) -or -not (ExactArray (Field $Manifest 'pivot') @(48,84) $true) -or
        -not (ExactArray (Field $Manifest 'directions') $directions) -or -not (ExactArray (Field $Manifest 'base_rows') $states) -or
        -not (ExactNumber (Field $layout 'columns') 16) -or -not (ExactNumber (Field $layout 'rows') 32) -or
        -not (ExactNumber (Field $layout 'phases') 8) -or (Field $layout 'index_formula') -cne '((travel*8+aim)*8+phase)' -or
        (Field $layout 'gait_policy') -cne 'distinct_walk_sprint_fixed_bone_banks' -or
        -not (ExactArray @(Keys $sizes | Sort-Object) @('large','middle','small'))) {
        Problem 'wireframe_manifest_contract' '' 'Wireframe schema 2 must retain three sizes, distinct walk/sprint banks, 64 direction pairs and eight phases.'
    }
    $heights = [ordered]@{ small = 58; middle = 68; large = 76 }
    $checkedPages = [Collections.Generic.List[object]]::new()
    foreach ($body in $heights.Keys) {
        $size = Field $sizes $body
        if (-not (ExactNumber (Field $size 'reference_height') $heights[$body])) { Problem 'wireframe_body' $body 'Wireframe height differs from its fixed size guide.' }
        foreach ($kind in @('base','locomotion','sprint')) {
            $before = $diagnostics.Count
            $dimensions = $(if ($kind -eq 'base') { @(768,960) } else { @(1536,3072) })
            $expectedResource = "res://assets/sprites/wireframe_motion_v2/$body-$kind.png"
            $resource = [string](Field $size $kind)
            if ($resource -cne $expectedResource) { Problem 'wireframe_page_path' $body "Noncanonical $kind source path."; continue }
            if (-not (ExactArray (Field $size ($kind + '_dimensions')) $dimensions $true)) { Problem 'wireframe_page_dimensions' $body "Invalid $kind declared dimensions." }
            foreach ($suffix in @('_sha256','_rgba_sha256')) {
                if ([string](Field $size ($kind + $suffix)) -cnotmatch '^[0-9a-f]{64}$') { Problem 'wireframe_page_digest' $body "Malformed $kind$suffix declaration." }
            }
            $path = [IO.Path]::GetFullPath((Join-Path $Root $resource.Substring(6)))
            $assetRoot = [IO.Path]::GetFullPath((Join-Path $Root 'assets/sprites/wireframe_motion_v2'))
            $unsafePath = $false
            for ($cursor = $path; $cursor -and $cursor.Length -ge $assetRoot.Length; $cursor = Split-Path -Parent $cursor) {
                if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { $unsafePath = $true; break }
            }
            if ($unsafePath) { Problem 'wireframe_page_path' $body 'Source PNG traverses a reparse point.'; continue }
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Problem 'wireframe_page_missing' $body "Missing raw source PNG: $resource"; continue }
            try {
                $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($actualHash -cne [string](Field $size ($kind + '_sha256'))) { Problem 'wireframe_page_sha256' $body "Raw source PNG SHA-256 mismatch: $resource" }
                $stream = [IO.File]::OpenRead($path)
                try { $header = [byte[]]::new(24); $read = $stream.Read($header, 0, 24) } finally { $stream.Dispose() }
                if ($read -ne 24 -or [BitConverter]::ToString($header[0..15]) -cne '89-50-4E-47-0D-0A-1A-0A-00-00-00-0D-49-48-44-52') {
                    Problem 'wireframe_page_png_header' $body 'Source is not a PNG with an IHDR header.'
                } else {
                    $width = [uint64]$header[16] * 16777216 + [uint64]$header[17] * 65536 + [uint64]$header[18] * 256 + $header[19]
                    $height = [uint64]$header[20] * 16777216 + [uint64]$header[21] * 65536 + [uint64]$header[22] * 256 + $header[23]
                    if ($width -ne $dimensions[0] -or $height -ne $dimensions[1]) { Problem 'wireframe_page_dimensions' $body 'Source PNG header dimensions differ from the required atlas.' }
                }
                if ($diagnostics.Count -eq $before) { $checkedPages.Add([ordered]@{ body_type = $body; kind = $kind; path = $resource; sha256 = $actualHash; dimensions = $dimensions }) }
            } catch { Problem 'wireframe_page_read' $body $_.Exception.Message }
        }
    }
    $identities = [Collections.Generic.List[object]]::new()
    $seenIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $counts = [ordered]@{ small = 0; middle = 0; large = 0 }
    foreach ($entry in @(Field $Catalog 'champions')) {
        $id = [string](Field $entry 'id'); $body = [string](Field $entry 'body_type')
        if (-not $id -or -not $seenIds.Add($id)) { Problem 'wireframe_catalog_identity' $id 'Catalog identity is empty or duplicated.'; continue }
        if (-not $counts.Contains($body)) { Problem 'wireframe_catalog_body' $id 'Catalog identity has no shared wireframe body.'; continue }
        $counts[$body]++
        $identities.Add([ordered]@{ champion_id = $id; body_type = $body; classification = 'shared_size_wireframe'; source_identity = $body; source_path = Field (Field $sizes $body) 'base'; locomotion_path = Field (Field $sizes $body) 'locomotion'; sprint_path = Field (Field $sizes $body) 'sprint' })
    }
    if ($identities.Count -eq 0 -or @($counts.Values | Where-Object { $_ -eq 0 }).Count -gt 0) { Problem 'wireframe_catalog_coverage' '' 'Live catalog must map to all three shared body sizes.' }
    $activeValid = $diagnostics.Count -eq 0
    $allValid = $activeValid -and [bool]$LegacyArt.source_validation_passed
    return [ordered]@{
        schema_version = 2
        evidence = 'Source-default binding, catalog mappings, contained raw PNG SHA-256 and IHDR dimensions only. Not executed presentation, imported-RGBA validation, human motion acceptance, or release acceptance.'
        source_validation_passed = $allValid
        playable_count = $seenIds.Count
        active_presentation = [ordered]@{
            mode = $(if ($bindingRecognized) { 'wireframe_body' } else { 'unrecognized_source_binding' })
            source_validation_passed = $activeValid
            source_default_binding_recognized = $bindingRecognized
            manifest_path = $manifestPath
            manifest_schema_version = Field $Manifest 'schema_version'
            shared_body_count = $(if ($activeValid) { 3 } else { $null })
            shared_texture_count = $(if ($activeValid) { $checkedPages.Count } else { $null })
            individual_live_skin_count = $(if ($activeValid) { 0 } else { $null })
            size_profile_counts = $counts
            source_checked_pages = @($checkedPages)
        }
        effective_individual_count = $(if ($allValid) { 0 } else { $null })
        effective_template_count = $(if ($allValid) { $identities.Count } else { $null })
        effective_identities = @(if ($allValid) { $identities })
        legacy_provenance_scope = 'Historical catalog/baseline/override facts and opt-in legacy-mode coverage only; nested effective counts are not the current default live presentation. Legacy validation remains mandatory.'
        legacy_provenance = $LegacyArt
        diagnostics = @($LegacyArt.diagnostics) + @($diagnostics)
    }
}

function Get-FluxDocumentStatuses {
    $result = [ordered]@{}
    $docsRoot = Join-Path $repoRoot 'docs'
    foreach ($file in Get-ChildItem -LiteralPath $docsRoot -Filter '*.md' -File | Sort-Object Name) {
        $head = (Get-Content -LiteralPath $file.FullName -TotalCount 10) -join "`n"
        $match = [regex]::Match($head, '(?m)^Status:\s*(.+)$')
        $relative = 'docs/' + $file.Name
        if ($match.Success) {
            $result[$relative] = $match.Groups[1].Value.Trim()
        } else {
            $result[$relative] = 'MISSING'
            $issues.Add("Current documentation lacks an explicit status: $relative")
        }
    }
    return $result
}

$projectText = Read-FluxText 'project.godot'
$abilityPath = 'content/abilities/foundation_abilities_v1.json'
$reactionPath = 'content/reactions/first_eight_element_reactions_v1.json'
$playableChampionPath = 'content/champions/foundation_champions_v1.json'
$plannedAffinityPath = 'content/champions/champion_affinities_first_eight_v1.json'
$rosterPlanPath = 'content/champions/champion_roster_plan_v1.json'
$bodyPath = 'content/champions/body_type_profiles_v1.json'
$campusPath = 'content/maps/sanctum_campus_g2_v1.json'
$wellspringPath = 'content/maps/wellspring_hub_v2.json'
$motionPath = 'content/visual/minimal_champion_motion_v1.json'

$abilities = Read-FluxJson $abilityPath
$reactions = Read-FluxJson $reactionPath
$playableChampions = Read-FluxJson $playableChampionPath
$plannedAffinities = Read-FluxJson $plannedAffinityPath
$rosterPlan = Read-FluxJson $rosterPlanPath
$bodyProfiles = Read-FluxJson $bodyPath
$campus = Read-FluxJson $campusPath
$wellspring = Read-FluxJson $wellspringPath
$motion = Read-FluxJson $motionPath
$characterVisualPath = 'content/visual/foundation_champion_visuals_v1.json'
$characterOverridePath = 'content/visual/champion_page_overrides_v1.json'
$characterVisual = $null
$characterOverrides = $null
$overridePresent = Test-Path -LiteralPath (Join-Path $repoRoot $characterOverridePath) -PathType Leaf
try { $characterVisual = Read-FluxJson $characterVisualPath } catch { $issues.Add("Character art baseline JSON: $($_.Exception.Message)") }
if ($overridePresent) {
    try { $characterOverrides = Read-FluxJson $characterOverridePath } catch { $issues.Add("Character art override JSON: $($_.Exception.Message)") }
}
$legacyCharacterArt = Get-FluxCharacterArtCoverage $repoRoot $playableChampions $characterVisual $characterOverrides $overridePresent
$wireframeManifestPath = 'assets/sprites/wireframe_motion_v2/manifest.json'
$wireframeManifest = $null
try { $wireframeManifest = Read-FluxJson $wireframeManifestPath } catch { $issues.Add("Active wireframe manifest JSON: $($_.Exception.Message)") }
$characterArt = Get-FluxActiveCharacterArtCoverage $repoRoot $playableChampions $wireframeManifest (Read-FluxText 'src/presentation/cartoon_champion_presenter.gd') (Read-FluxText 'src/presentation/wireframe_body_presenter.gd') (Read-FluxText 'src/app/bootstrap.gd') $legacyCharacterArt
foreach ($diagnostic in $characterArt.diagnostics) { $issues.Add("Character art [$($diagnostic.code)] $($diagnostic.champion_id): $($diagnostic.message)") }

$protocolVersion = Get-FluxSourceInteger 'src/sim/core/sim_config.gd' 'PROTOCOL_VERSION'
$simulationHz = Get-FluxSourceInteger 'src/sim/core/sim_config.gd' 'TICK_RATE'
$snapshotSchema = Get-FluxSourceInteger 'src/net/session_snapshot.gd' 'SCHEMA_VERSION'
$preferencesSchema = Get-FluxSourceInteger 'src/app/player_preferences.gd' 'SCHEMA_VERSION'
$snapshotHz = Get-FluxSourceInteger 'src/app/bootstrap.gd' 'SNAPSHOT_RATE'
$maximumPlayers = Get-FluxSourceInteger 'src/net/session_transport.gd' 'MAX_PLAYERS'
$projectPhysicsHz = Get-FluxProjectInteger 'common/physics_ticks_per_second'
$projectMaximumFps = Get-FluxProjectInteger 'run/max_fps'
$presentationBaseHz = [int]$motion.base_hz
$runtimeWireIds = @($abilities.runtime_wire_ids | ForEach-Object { [int]$_ })
$matrixExtensions = @($abilities.spell_matrix.extensions)
$abilityCount = @($abilities.abilities).Count + $matrixExtensions.Count
$abilityWireIds = @($abilities.abilities | ForEach-Object { [int]$_.wire_id }) + @($matrixExtensions | ForEach-Object { [int]$_.wire_id })
$bodyRoleIds = @($bodyProfiles.profiles.PSObject.Properties.Name)
$playableIds = @($playableChampions.champions | ForEach-Object { [string]$_.id })
$plannedIds = @($rosterPlan.champions | ForEach-Object { [string]$_.id })
$affinityIds = @($plannedAffinities.champions | ForEach-Object { [string]$_.id })
$documentStatuses = Get-FluxDocumentStatuses

Add-FluxIssue ($simulationHz -eq 120) "Simulation rate is $simulationHz Hz; current authority requires 120 Hz"
Add-FluxIssue ($projectPhysicsHz -eq $simulationHz) "Project physics rate $projectPhysicsHz disagrees with simulation rate $simulationHz"
Add-FluxIssue ($projectMaximumFps -eq 120) "Project frame cap is $projectMaximumFps; current Windows target requires 120"
Add-FluxIssue ($projectText -match 'simulation/supported_tick_rates=PackedInt32Array\(120\)') 'Project exposes a gameplay tick rate other than the single supported 120 Hz cadence'
Add-FluxIssue ($protocolVersion -eq 54) "Protocol is $protocolVersion; bounded remote hex-clash cues require 54"
Add-FluxIssue ($snapshotSchema -eq 21) "Snapshot schema is $snapshotSchema; bounded hex-clash feedback requires 21"
Add-FluxIssue ($preferencesSchema -eq 11) "Preferences schema is $preferencesSchema; current documentation requires 11"
Add-FluxIssue ($snapshotHz -eq 60) "Transport snapshot cadence is $snapshotHz Hz; current contract requires 60 Hz"
Add-FluxIssue ($presentationBaseHz -eq 60) "Presentation sample base is $presentationBaseHz Hz; current contract requires 60"
Add-FluxIssue ($maximumPlayers -eq 8) "Session capacity is $maximumPlayers; current tested cap requires 8"
Add-FluxIssue ($abilityCount -eq 62) "Effective authored ability count is $abilityCount; current contract requires 62"
Add-FluxIssue ($runtimeWireIds.Count -eq 32) "Runtime-selectable spell count is $($runtimeWireIds.Count); current four-delivery contract requires 32"
Add-FluxIssue (($abilities.spell_matrix.column_order -join ',') -ceq 'bolt,heavy,rapid,spray') 'Playable matrix must expose exactly Bolt, Heavy, Rapid, Spray'
Add-FluxIssue (@($runtimeWireIds | Sort-Object -Unique).Count -eq $runtimeWireIds.Count) 'Runtime spell wire IDs are not unique'
Add-FluxIssue (@($runtimeWireIds | Where-Object { $abilityWireIds -notcontains $_ }).Count -eq 0) 'Runtime spell order references a missing authored ability wire ID'
Add-FluxIssue (@($reactions.reactions).Count -eq 36) "Reaction definition count is $(@($reactions.reactions).Count); first-eight coverage requires 36"
Add-FluxIssue ([bool]$reactions.runtime_enabled -and $reactions.status -eq 'bounded_level_one') 'Reaction runtime must identify the bounded first-grade promotion'
Add-FluxIssue ($playableIds.Count -eq 30) "Playable champion count is $($playableIds.Count); current foundation requires 30"
Add-FluxIssue ($plannedIds.Count -eq 30) "Planned champion count is $($plannedIds.Count); current roster plan requires 30"
Add-FluxIssue (($plannedIds -join ',') -eq ($affinityIds -join ',')) 'Planned roster and affinity catalogs have different identity/order sets'
Add-FluxIssue (($bodyRoleIds -join ',') -eq 'small,middle,large') "Body-role IDs are $($bodyRoleIds -join ','); expected small,middle,large"
Add-FluxIssue (@($campus.stations).Count -eq 12) "Wellspring station count is $(@($campus.stations).Count); current map contract requires 12"
Add-FluxIssue (@($wellspring.district_order).Count -eq 9) "Wellspring district count is $(@($wellspring.district_order).Count); current map contract requires 9"

foreach ($champion in $plannedAffinities.champions) {
    $affinities = @($champion.affinities)
    $pointProperties = @($champion.affinity_points.PSObject.Properties)
    $pointTotal = 0
    foreach ($property in $pointProperties) { $pointTotal += [int]$property.Value }
    Add-FluxIssue ($affinities.Count -ge 2 -and $affinities.Count -le 3) "Planned champion $($champion.id) must have two or three affinities"
    Add-FluxIssue ($pointProperties.Count -eq $affinities.Count) "Planned champion $($champion.id) affinity list/point map disagree"
    Add-FluxIssue ($pointTotal -eq 3) "Planned champion $($champion.id) spends $pointTotal affinity points instead of 3"
}
foreach ($champion in $rosterPlan.champions) {
    $isPlayable = [string]$champion.availability -eq 'playable'
    Add-FluxIssue ($isPlayable -eq ($playableIds -contains [string]$champion.id)) "Roster availability disagrees with the playable catalog: $($champion.id)"
    $affinityEntry = @($plannedAffinities.champions | Where-Object { [string]$_.id -eq [string]$champion.id })
    Add-FluxIssue ($affinityEntry.Count -eq 1) "Roster identity lacks one affinity entry: $($champion.id)"
    if ($affinityEntry.Count -eq 1) {
        Add-FluxIssue ([string]$affinityEntry[0].display_name -eq [string]$champion.display_name) "Roster and affinity display names disagree: $($champion.id)"
    }
}

$readme = Read-FluxText 'README.md'
Add-FluxIssue ($readme -match '62 validated effective records; 32 have runtime wire IDs') 'README does not distinguish 62 preserved effective abilities from 32 runtime spells'
Add-FluxIssue ($readme -match '36 symmetric first-grade reactions') 'README does not report the bounded first-grade reaction contract'
Add-FluxIssue ($readme -match '30 playable entries; 30 identities') 'README does not describe the current all-playable roster'
Add-FluxIssue ($readme -match '120 Hz authoritative simulation; 60 Hz transport snapshots') 'README does not distinguish simulation and snapshot cadences'

$branch = Get-FluxGitValue @('branch', '--show-current')
$head = Get-FluxGitValue @('rev-parse', 'HEAD')
$canonicalHead = Get-FluxGitValue @('rev-parse', '--verify', 'refs/remotes/origin/main')
$compatibilityHead = Get-FluxGitValue @('rev-parse', '--verify', 'refs/remotes/origin/codex/continuous-overhaul')
$statusText = Get-FluxGitValue @('status', '--porcelain=v1', '--untracked-files=all')
$dirtyEntryCount = if ($statusText) { @($statusText -split "`r?`n").Count } else { 0 }
$package = $null
try {
    $package = (& (Join-Path $PSScriptRoot 'current-checkpoint.ps1') -Json -ReportOnly | Out-String) | ConvertFrom-Json
    # A source-only checkout can lack ignored local exports. Report that as
    # unavailable, never verified; malformed or changed existing bytes are drift.
    Add-FluxIssue ($package.status -ne 'invalid') 'Current checkpoint pointer or existing payload/evidence identity is invalid'
} catch {
    $package = [ordered]@{status = 'invalid'; passed = $false; issues = @($_.Exception.Message)}
    $issues.Add("Current checkpoint report failed: $($_.Exception.Message)")
}

$runtimeIdentity = $null
try {
    $runtimeIdentity = (& (Join-Path $PSScriptRoot 'runtime-build-identity.ps1') -Mode Check -Json | Out-String) | ConvertFrom-Json
} catch {
    $issues.Add("Runtime build identity check failed: $($_.Exception.Message)")
}

$state = [ordered]@{
    schema_version = 1
    generated_at_utc = [DateTime]::UtcNow.ToString('o')
    authority = 'generated read-only report; executed source, catalogs, tests and packages remain primary'
    git = [ordered]@{
        canonical_branch = 'main'
        current_branch = $branch
        head = $head
        remote_main = $canonicalHead
        remote_compatibility = $compatibilityHead
        dirty = ($dirtyEntryCount -gt 0)
        dirty_entry_count = $dirtyEntryCount
    }
    runtime = [ordered]@{
        product = 'FLUX 2'
        platform_acceptance = 'Windows'
        godot = '4.7.1.stable.official.a13da4feb'
        protocol = $protocolVersion
        build_identity = $runtimeIdentity
        snapshot_schema = $snapshotSchema
        preferences_schema = $preferencesSchema
        simulation_hz = $simulationHz
        project_physics_hz = $projectPhysicsHz
        maximum_fps = $projectMaximumFps
        transport_snapshot_hz = $snapshotHz
        presentation_sample_base_hz = $presentationBaseHz
        maximum_players = $maximumPlayers
    }
    content = [ordered]@{
        abilities_authored = $abilityCount
        spells_runtime_selectable = $runtimeWireIds.Count
        runtime_spell_wire_ids = $runtimeWireIds
        reactions_defined = @($reactions.reactions).Count
        reaction_mutation_enabled = [bool]$reactions.runtime_enabled
        champions_playable = $playableIds.Count
        playable_champion_ids = $playableIds
        champions_planned = $plannedIds.Count
        body_roles = $bodyRoleIds
        legacy_visual_size_paths = 5
        wellspring_districts = @($wellspring.district_order).Count
        wellspring_stations = @($campus.stations).Count
        hashes = [ordered]@{
            abilities = Get-FluxFileSha256 (Join-Path $repoRoot $abilityPath)
            reactions = Get-FluxFileSha256 (Join-Path $repoRoot $reactionPath)
            playable_champions = Get-FluxFileSha256 (Join-Path $repoRoot $playableChampionPath)
            planned_affinities = Get-FluxFileSha256 (Join-Path $repoRoot $plannedAffinityPath)
            roster_plan = Get-FluxFileSha256 (Join-Path $repoRoot $rosterPlanPath)
            body_roles = Get-FluxFileSha256 (Join-Path $repoRoot $bodyPath)
            champion_visuals = $(if (Test-Path -LiteralPath (Join-Path $repoRoot $characterVisualPath) -PathType Leaf) { Get-FluxFileSha256 (Join-Path $repoRoot $characterVisualPath) } else { $null })
            champion_page_overrides = $(if ($overridePresent) { Get-FluxFileSha256 (Join-Path $repoRoot $characterOverridePath) } else { $null })
            active_wireframe_manifest = $(if (Test-Path -LiteralPath (Join-Path $repoRoot $wireframeManifestPath) -PathType Leaf) { Get-FluxFileSha256 (Join-Path $repoRoot $wireframeManifestPath) } else { $null })
            wellspring = Get-FluxFileSha256 (Join-Path $repoRoot $campusPath)
        }
    }
    character_art = $characterArt
    documents = $documentStatuses
    package = $package
    check = [ordered]@{
        passed = ($issues.Count -eq 0)
        issue_count = $issues.Count
        issues = @($issues)
    }
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$stateJson = $state | ConvertTo-Json -Depth 12
[System.IO.File]::WriteAllText($OutputPath, $stateJson + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))

if ($Json) {
    Write-Output $stateJson
} elseif (-not $Quiet) {
    Write-Output ("FLUX state: protocol {0}, 120 Hz, {1}/{2} runtime/authored abilities, {3} reactions ({4}), {5}/{6} playable/planned champions, {7} players." -f $protocolVersion, $runtimeWireIds.Count, $abilityCount, @($reactions.reactions).Count, $(if ($reactions.runtime_enabled) { 'enabled' } else { 'gated' }), $playableIds.Count, $plannedIds.Count, $maximumPlayers)
    if ($characterArt.source_validation_passed) {
        Write-Output ("Character art (source default): {0} profiles mapped to {1} shared size wireframes ({3} base/walk/sprint textures); {2} individual live skins. Not executed/imported-RGBA or human approval." -f $characterArt.playable_count, $characterArt.active_presentation.shared_body_count, $characterArt.effective_individual_count, $characterArt.active_presentation.shared_texture_count)
        Write-Output ("Legacy provenance only: {0} catalog fallback declarations; {1} registered overrides; opt-in old-page coverage {2} individual / {3} template. These are not current live totals." -f $legacyCharacterArt.catalog_fallback_declaration_count, $legacyCharacterArt.override_declared_ids.Count, $legacyCharacterArt.effective_individual_count, $legacyCharacterArt.effective_template_count)
    } else { Write-Output "Character art: INVALID source coverage; effective totals withheld. Inspect character_art.diagnostics in the report." }
    Write-Output "Pinned current portable: $($package.current_portable.status); historical installer: $($package.historical_installer.status). Source validation is not delivery acceptance."
    Write-Output "Report: $OutputPath"
}

if ($Check -and $issues.Count -gt 0) {
    foreach ($issue in $issues) { Write-Error $issue }
    throw "Current-state drift check failed with $($issues.Count) issue(s)."
}
if ($Check -and -not $Quiet) {
    Write-Output 'PASS: current runtime, content and documentation invariants agree.'
}
