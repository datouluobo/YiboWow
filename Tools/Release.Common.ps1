Set-StrictMode -Version Latest

function Resolve-YiboSourceFile {
    param([string]$Root, [string]$Relative)
    if ([IO.Path]::IsPathRooted($Relative)) { throw "Absolute source path is not allowed: $Relative" }
    $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd([char[]]'\/')
    $path = [IO.Path]::GetFullPath((Join-Path $rootPath $Relative))
    if (-not $path.StartsWith($rootPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Source path escapes addon root: $Relative"
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Source file is missing: $Relative" }
    $item = Get-Item -LiteralPath $path
    while ($item.FullName -ne $rootPath) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Source link is not allowed: $Relative" }
        $item = Get-Item -LiteralPath (Split-Path $item.FullName -Parent)
    }
    return $path
}

function Read-YiboRequiredValue {
    param([string]$Text, [string]$Pattern, [string]$Label)
    $matches = [regex]::Matches($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::Multiline)
    if ($matches.Count -ne 1) { throw "Expected one $Label declaration; found $($matches.Count)." }
    return $matches[0].Groups[1].Value.Trim()
}

function Get-YiboReleaseProfile {
    param([string]$WorkspaceRoot, [string]$Addon, [string]$Target)
    $config = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'ReleaseProfiles.psd1')
    if ($config.SchemaVersion -ne 1) { throw 'Unsupported release profile schema.' }
    if (-not $config.Targets.ContainsKey($Target)) { throw "Unknown product target: $Target" }
    if (-not $config.Addons.ContainsKey($Addon)) { throw "Addon has not joined the shared packager: $Addon" }
    $addonProfile = $config.Addons[$Addon]
    if (-not $addonProfile.Targets.ContainsKey($Target)) {
        throw "No verified build profile for $Addon / $Target. Register its source TOC, Interface and client metadata first."
    }
    $targetProfile = $addonProfile.Targets[$Target]
    $targetID = @($config.Targets.Keys | Where-Object { $_ -ieq $Target })[0]
    $addonID = @($config.Addons.Keys | Where-Object { $_ -ieq $Addon })[0]
    $root = [IO.Path]::GetFullPath((Join-Path $WorkspaceRoot $addonID))
    $standardToc = "${addonID}_${targetID}.toc"
    if ($targetProfile.SourceToc -cne $standardToc -and
        -not ($targetID -eq 'Mists' -and $targetProfile.SourceToc -ceq "$addonID.toc")) {
        throw "Source TOC must follow the product naming standard: $standardToc"
    }
    $tocPath = Resolve-YiboSourceFile $root $targetProfile.SourceToc
    if ($targetProfile.LoadToc -cne "$addonID.toc") { throw 'Independent packages must use the default addon TOC name.' }
    $tocText = [IO.File]::ReadAllText($tocPath)
    $interfaceText = Read-YiboRequiredValue $tocText '^## Interface:\s*([^\r\n]+)' 'TOC Interface'
    $interfaces = @($interfaceText.Split(',') | ForEach-Object { [int]$_.Trim() } | Sort-Object -Unique)
    $expected = @($targetProfile.Interfaces | Sort-Object -Unique)
    if (($interfaces -join ',') -ne ($expected -join ',')) { throw "TOC Interface does not match profile: $Addon / $targetID" }
    $versionFile = if ($targetProfile.ContainsKey('VersionFile')) { $targetProfile.VersionFile } else { $addonProfile.VersionFile }
    $versionText = [IO.File]::ReadAllText((Resolve-YiboSourceFile $root $versionFile))
    $releaseVersion = Read-YiboRequiredValue $versionText $addonProfile.VersionPattern 'source version'
    $apiVersion = [int](Read-YiboRequiredValue $versionText $addonProfile.APIPattern 'source API version')
    $version = if ($addonProfile.VersionIncludesAPI) { "$releaseVersion-api$apiVersion" } else { $releaseVersion }
    $tocVersion = Read-YiboRequiredValue $tocText '^## Version:\s*([^\r\n]+)' 'TOC version'
    if ($tocVersion -ne $version) { throw "TOC version '$tocVersion' does not match source version '$version'." }
    if ($version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)*$') { throw "Unsafe package version: $version" }
    $requiredCoreAPI = if ($addonProfile.ContainsKey('RequiredCorePattern')) {
        [int](Read-YiboRequiredValue $versionText $addonProfile.RequiredCorePattern 'required Core API')
    } else { $null }
    return [pscustomobject]@{
        Config = $config; Addon = $addonID; Target = $targetID; Root = $root
        Definition = $addonProfile; Client = $targetProfile; Slug = $config.Targets[$targetID].Slug
        TocPath = $tocPath; TocText = $tocText; Version = $version; APIVersion = $apiVersion
        RequiredCoreAPI = $requiredCoreAPI; Interfaces = $interfaces
    }
}

function Get-YiboTocEntries {
    param($Profile)
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($line in ($Profile.TocText -split '\r?\n')) {
        $relative = $line.Trim().Replace('\', '/')
        if (-not $relative -or $relative.StartsWith('#')) { continue }
        if ($relative -match '[\[\]]' -or $relative -notmatch '\.lua$') {
            throw "Shared packager currently accepts static Lua TOC entries only: $relative"
        }
        $source = Resolve-YiboSourceFile $Profile.Root $relative
        $relative = [IO.Path]::GetRelativePath($Profile.Root, $source).Replace('\', '/')
        foreach ($id in $Profile.Config.Targets.Keys) {
            if ($id -ne $Profile.Target -and $relative.StartsWith($Profile.Config.Targets[$id].Directory + '/', [StringComparison]::OrdinalIgnoreCase)) {
                throw "TOC loads another product target: $relative"
            }
        }
        if ($relative -match '(^|/)(?:_NonRelease|Tests|Builds|dist|tmp|\.git)/') { throw "TOC loads non-release content: $relative" }
        if (-not $seen.Add($relative)) { throw "Duplicate TOC entry: $relative" }
        [pscustomobject]@{ Relative = $relative; Source = $source; Content = $null }
    }
}

function Get-YiboPublicEntries {
    param([string]$Root)
    foreach ($file in (Get-ChildItem -LiteralPath $Root -Recurse -File | Sort-Object FullName)) {
        $relative = [IO.Path]::GetRelativePath($Root, $file.FullName).Replace('\', '/')
        if ($relative -match '(^|/)(?:_NonRelease|\.git|\.svn|\.hg|Builds|dist|tmp|__pycache__|\.pytest_cache)/' -or
            $file.Name -eq 'AGENTS.md' -or $file.Extension -in @('.pyc', '.pyo') -or $file.Name -match '\.building(?:-|$)') { continue }
        [pscustomobject]@{ Relative = $relative; Source = (Resolve-YiboSourceFile $Root $relative); Content = $null }
    }
}

function Get-YiboSourceDigest {
    param([object[]]$Entries)
    $lines = foreach ($entry in ($Entries | Sort-Object Relative)) {
        "{0}  {1}" -f (Get-FileHash -LiteralPath $entry.Source -Algorithm SHA256).Hash.ToLowerInvariant(), $entry.Relative
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Get-YiboPackagedAddonVersions {
    param([string]$WorkspaceRoot, $Profile)
    $versions = [ordered]@{}
    foreach ($directory in (Get-ChildItem -LiteralPath $WorkspaceRoot -Directory -Filter 'Yibo*' | Sort-Object Name)) {
        if ($directory.Name -eq 'YiboCore') { continue }
        $toc = $null
        if ($Profile.Config.Addons.ContainsKey($directory.Name) -and $Profile.Config.Addons[$directory.Name].Targets.ContainsKey($Profile.Target)) {
            $toc = Join-Path $directory.FullName $Profile.Config.Addons[$directory.Name].Targets[$Profile.Target].SourceToc
        } elseif ($Profile.Target -eq 'Mists') {
            $toc = Join-Path $directory.FullName ($directory.Name + '_Mists.toc')
            if (-not (Test-Path -LiteralPath $toc -PathType Leaf)) { $toc = Join-Path $directory.FullName ($directory.Name + '.toc') }
        }
        if (-not $toc -or -not (Test-Path -LiteralPath $toc -PathType Leaf)) { continue }
        $text = [IO.File]::ReadAllText($toc)
        if ($Profile.Target -eq 'Mists' -and $text -notmatch '(?m)^## Interface:\s*5\d{4}(?:\s|,|$)') { continue }
        $versions[$directory.Name] = (Read-YiboRequiredValue $text '^## Version:\s*([^\r\n]+)' 'indexed addon version').TrimStart('v', 'V')
    }
    return $versions
}

function Test-YiboLuaEntries {
    param([object[]]$Entries, [string]$LuaVersion)
    $compiler = Get-Command 'luac' -ErrorAction SilentlyContinue
    if (-not $compiler) { throw "Lua $LuaVersion compiler is required for package validation." }
    $version = (& $compiler.Source -v 2>&1 | Out-String)
    if ($version -notmatch ('Lua ' + [regex]::Escape($LuaVersion) + '(?:\.|\s)')) { throw "Expected Lua $LuaVersion, found: $version" }
    foreach ($entry in $Entries) {
        if (-not $entry.Relative.EndsWith('.lua', [StringComparison]::OrdinalIgnoreCase)) { continue }
        if ($null -ne $entry.Content) { $diagnostic = ($entry.Content | & $compiler.Source -p - 2>&1 | Out-String) }
        else { $diagnostic = (& $compiler.Source -p $entry.Source 2>&1 | Out-String) }
        if ($LASTEXITCODE -ne 0) { throw "Lua syntax failed for $($entry.Relative): $diagnostic" }
    }
}

function New-YiboPackage {
    param([string]$Path, [string]$Addon, [object[]]$Entries)
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew)
    try {
        $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $false)
        try {
            foreach ($entry in $Entries) {
                $name = "$Addon/$($entry.Relative)"
                if (-not $names.Add($name)) { throw "Duplicate archive entry: $name" }
                if ($null -eq $entry.Content) {
                    [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $entry.Source, $name, [IO.Compression.CompressionLevel]::Optimal)
                } else {
                    $zipEntry = $zip.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
                    $writer = [IO.StreamWriter]::new($zipEntry.Open(), [Text.UTF8Encoding]::new($false))
                    try { $writer.Write($entry.Content) } finally { $writer.Dispose() }
                }
            }
        } finally { $zip.Dispose() }
    } finally { $stream.Dispose() }
    $readZip = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        if ($readZip.Entries.Count -ne $Entries.Count) { throw "Archive file count mismatch: $Path" }
        foreach ($entry in $readZip.Entries) {
            if (-not $names.Contains($entry.FullName)) { throw "Unexpected archive entry: $($entry.FullName)" }
        }
    } finally { $readZip.Dispose() }
}

function Publish-YiboPackages {
    param([string]$OutputRoot, $Profile, [object[]]$Artifacts)
    $outputPath = [IO.Path]::GetFullPath($OutputRoot).TrimEnd([char[]]'\/')
    $archiveRoot = [IO.Path]::GetFullPath((Join-Path (Join-Path $outputPath 'Archive') $Profile.Addon))
    if (-not $archiveRoot.StartsWith($outputPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid archive root.' }
    $oldFiles = [Collections.Generic.List[object]]::new()
    foreach ($file in (Get-ChildItem -LiteralPath $outputPath -File -Filter ($Profile.Addon + '-*.zip'))) {
        $selected = $false
        foreach ($artifact in $Artifacts) {
            if ($artifact.Channel -eq 'GitHub' -and $file.Name.EndsWith('-github.zip')) { $selected = $true }
            if ($artifact.Channel -eq 'CurseForge' -and $file.Name.EndsWith('-curseforge.zip')) {
                $fileTarget = $null
                foreach ($id in $Profile.Config.Targets.Keys) {
                    $slug = $Profile.Config.Targets[$id].Slug
                    $prefix = $Profile.Addon + '-' + $slug + '-v'
                    if ($file.Name.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or
                        $file.Name.EndsWith('-' + $slug + '-curseforge.zip', [StringComparison]::OrdinalIgnoreCase)) { $fileTarget = $id; break }
                }
                if ($file.Name.StartsWith($Profile.Addon + '-universal-v', [StringComparison]::OrdinalIgnoreCase) -or
                    $file.Name.EndsWith('-universal-curseforge.zip', [StringComparison]::OrdinalIgnoreCase)) { $fileTarget = 'Universal' }
                $legacyPattern = '^' + [regex]::Escape($Profile.Addon) + '-v\d+\.\d+\.\d+(?:-(?:test|alpha|beta|rc)(?:[.-][0-9A-Za-z]+)*)?(?:-api\d+)?-curseforge\.zip$'
                if ($null -eq $fileTarget -and $file.Name -match $legacyPattern) { $fileTarget = 'Mists' }
                if ($fileTarget -eq $Profile.Target) { $selected = $true }
            }
        }
        if ($selected) {
            $destination = Join-Path $archiveRoot $file.Name
            if (Test-Path -LiteralPath $destination) { throw "Archive package already exists: $destination" }
            $oldFiles.Add([pscustomobject]@{ Source = $file.FullName; Destination = $destination })
        }
    }
    foreach ($artifact in $Artifacts) {
        foreach ($path in @($artifact.Final, $artifact.Temporary)) {
            if ((Split-Path ([IO.Path]::GetFullPath($path)) -Parent) -ine $outputPath) { throw "Artifact path is outside OutputRoot: $path" }
        }
        if (Test-Path -LiteralPath $artifact.Final) { throw "Package already exists: $($artifact.Final)" }
        if (-not (Test-Path -LiteralPath $artifact.Temporary -PathType Leaf)) { throw "Completed package is missing: $($artifact.Temporary)" }
    }
    $moved = [Collections.Generic.List[object]]::new()
    $published = [Collections.Generic.List[object]]::new()
    try {
        if ($oldFiles.Count) { [void](New-Item -ItemType Directory -Path $archiveRoot -Force) }
        foreach ($move in $oldFiles) { Move-Item -LiteralPath $move.Source -Destination $move.Destination; $moved.Add($move) }
        foreach ($artifact in $Artifacts) { Move-Item -LiteralPath $artifact.Temporary -Destination $artifact.Final; $published.Add($artifact) }
    } catch {
        $failure = $_
        $rollbackErrors = [Collections.Generic.List[string]]::new()
        for ($i = $published.Count - 1; $i -ge 0; $i--) {
            try { Move-Item -LiteralPath $published[$i].Final -Destination $published[$i].Temporary }
            catch { $rollbackErrors.Add("$($published[$i].Final): $($_.Exception.Message)") }
        }
        for ($i = $moved.Count - 1; $i -ge 0; $i--) {
            try { Move-Item -LiteralPath $moved[$i].Destination -Destination $moved[$i].Source }
            catch { $rollbackErrors.Add("$($moved[$i].Destination): $($_.Exception.Message)") }
        }
        if ($rollbackErrors.Count) { throw "Publication failed: $failure. Rollback incomplete: $($rollbackErrors -join '; ')" }
        throw $failure
    }
    return $moved.Count
}
