#Requires -Version 5.1
# Yibo Addon Suite builder: one Suite package per game target (Mists, Forever).
# Components are built by the unified per-addon builder and merged byte-for-byte.
[CmdletBinding()]
param(
    [ValidateSet('Mists', 'Forever')][string]$Target = 'Mists',
    [string]$WorkspaceRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
    [string]$OutputRoot,
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName 'System.IO.Compression'
Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
$workspace = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
$suiteRoot = Join-Path $workspace 'YiboCore for MoP'
. (Join-Path $workspace 'Tools/Release.Common.ps1')
$suite = Import-PowerShellDataFile -LiteralPath (Join-Path $suiteRoot 'Suite.psd1')
$config = Import-PowerShellDataFile -LiteralPath (Join-Path $workspace 'Tools/ReleaseProfiles.psd1')
if ($suite.Name -cne 'Yibo-Addon-Suite' -or -not $suite.Targets.ContainsKey($Target)) { throw 'Invalid Suite identity or target.' }
$targetSuite = $suite.Targets[$Target]
if ($targetSuite.Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid Suite version.' }
$slug = $config.Targets[$Target].Slug
$version = $targetSuite.Version
$addons = @($targetSuite.Addons | Sort-Object -Unique)
# A Suite for a target contains exactly every release addon that declares that target.
$registered = @($config.Addons.Keys | Where-Object { $config.Addons[$_].Targets.ContainsKey($Target) })
if ($Target -eq 'Mists') { $registered += @($config.LegacyBundles.Keys) }
$registered = @($registered | Sort-Object -Unique)
if (($addons -join ',') -cne ($registered -join ',')) { throw "Suite $Target must include exactly all release addons registered for $Target." }

function Get-Sha256Hex([IO.Stream]$Stream) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Stream))).Replace('-', '') } finally { $sha.Dispose() }
}
function Get-RelativePath([string]$Root, [string]$Path) { return $Path.Substring($Root.TrimEnd('\', '/').Length + 1).Replace('\', '/') }

$outputPath = [IO.Path]::GetFullPath($(if ($OutputRoot) { $OutputRoot } else { Join-Path $workspace 'Builds' }))
foreach ($sourceRootPath in (@($addons | ForEach-Object { Join-Path $workspace $_ }) + $suiteRoot)) {
    $sourceRoot = [IO.Path]::GetFullPath($sourceRootPath).TrimEnd([char[]]'\/')
    if ($outputPath -ieq $sourceRoot -or $outputPath.StartsWith($sourceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'OutputRoot must be outside addon and Suite source directories.'
    }
}
$filename = "$($suite.Name)-$slug-v$version-curseforge.zip"
$final = Join-Path $outputPath $filename
$releaseRoot = Join-Path $suiteRoot "Releases/$slug-v$version"
if (-not $ValidateOnly -and ((Test-Path -LiteralPath $final) -or (Test-Path -LiteralPath $releaseRoot))) {
    throw "Suite version already exists: $final or $releaseRoot. Choose a new Suite version."
}
function Get-SuiteInputEntries {
    foreach ($name in $addons) {
        foreach ($entry in (Get-YiboPublicEntries (Join-Path $workspace $name))) {
            [pscustomobject]@{ Relative = "$name/$($entry.Relative)"; Source = $entry.Source }
        }
    }
    foreach ($relative in @('Tools/Build-ReleasePackages.ps1', 'Tools/Build-LegacyBundle.ps1', 'Tools/Release.Common.ps1', 'Tools/ReleaseProfiles.psd1', 'YiboCore for MoP/Suite.psd1', 'YiboCore for MoP/INSTALL.md', 'YiboCore for MoP/Tools/Build-Suite.ps1')) {
        [pscustomobject]@{ Relative = $relative; Source = (Resolve-YiboSourceFile $workspace $relative) }
    }
}
$inputDigest = Get-YiboSourceDigest @(Get-SuiteInputEntries)
function Invoke-ComponentBuild([string]$Name, [string]$Output, [switch]$Validate) {
    $builder = Join-Path $workspace 'Tools/Build-ReleasePackages.ps1'
    if ($config.LegacyBundles.ContainsKey($Name)) {
        return & $builder -Addon $Name -WorkspaceRoot $workspace -OutputRoot $Output -Channel CurseForge -ValidateOnly:$Validate
    }
    return & $builder -Addon $Name -Target $Target -WorkspaceRoot $workspace -OutputRoot $Output -Channel CurseForge -ValidateOnly:$Validate
}
if ($ValidateOnly) {
    foreach ($name in $addons) { Invoke-ComponentBuild $name $outputPath -Validate | Out-Null }
    return [pscustomobject]@{ Suite = $suite.Name; Target = $Target; Version = $version; Components = $addons.Count; SourceSHA256 = $inputDigest; Package = $final; ValidationOnly = $true }
}
$runRoot = Join-Path $workspace ('_NonRelease/Packaging/Suite/' + [guid]::NewGuid().ToString('N'))
$componentOutput = Join-Path $runRoot 'Components'
$stage = Join-Path $runRoot 'Stage'
[void](New-Item -ItemType Directory -Path $stage -Force)
$components = @()
foreach ($name in $addons) {
    Write-Host "Building Suite component ($Target): $name"
    $plan = Invoke-ComponentBuild $name $componentOutput
    $package = $plan.CurseForge
    $zip = [IO.Compression.ZipFile]::OpenRead($package)
    try {
        foreach ($entry in $zip.Entries) {
            if (-not $entry.FullName.StartsWith("$name/", [StringComparison]::Ordinal) -or $entry.FullName -match '(^|/)(\.\.|_NonRelease|WTF|SavedVariables)(/|$)') {
                throw "Unsafe component entry: $($entry.FullName)"
            }
        }
    } finally { $zip.Dispose() }
    [IO.Compression.ZipFile]::ExtractToDirectory($package, $stage)
    $tocName = if ($config.LegacyBundles.ContainsKey($name)) { "${name}_$Target.toc" } else { $config.Addons[$name].Targets[$Target].LoadToc }
    $toc = [IO.File]::ReadAllText((Join-Path (Join-Path $stage $name) $tocName))
    $componentVersion = Read-YiboRequiredValue $toc '^## Version:\s*([^\r\n]+)' 'component TOC version'
    $required = @(); $optional = @()
    foreach ($match in [regex]::Matches($toc, '(?m)^## (RequiredDeps|Dependencies|OptionalDeps):\s*([^\r\n]+)')) {
        $values = @($match.Groups[2].Value -split '[,\s]+' | Where-Object { $_ })
        if ($match.Groups[1].Value -eq 'OptionalDeps') { $optional += $values } else { $required += $values }
    }
    foreach ($dependency in $required) { if ($dependency -notin $addons) { throw "Missing Suite dependency: $name -> $dependency" } }
    $componentManifest = Get-Content -LiteralPath (Join-Path (Join-Path $stage $name) 'YiboReleaseManifest.json') -Raw | ConvertFrom-Json
    $targetEntry = @($componentManifest.registeredTargets | Where-Object { $_.target -eq $Target })[0]
    $minimumAPI = if ($targetEntry -and $targetEntry.PSObject.Properties.Name -contains 'minimumCoreAPI') { $targetEntry.minimumCoreAPI } else { $null }
    $stream = [IO.File]::OpenRead($package)
    try { $packageHash = (Get-Sha256Hex $stream).ToLowerInvariant() } finally { $stream.Dispose() }
    $components += [ordered]@{
        addon = $name; version = $componentVersion; sourceToc = $tocName
        interface = (Read-YiboRequiredValue $toc '^## Interface:\s*([^\r\n]+)' 'component interface')
        requiredDependencies = @($required); optionalDependencies = @($optional); minimumCoreAPI = $minimumAPI
        sourceSHA256 = $componentManifest.sourceSHA256
        componentPackage = [IO.Path]::GetFileName($package); componentPackageSHA256 = $packageHash
    }
}
$coreManifest = Get-Content -LiteralPath (Join-Path $stage 'YiboCore/YiboReleaseManifest.json') -Raw | ConvertFrom-Json
$coreTarget = @($coreManifest.registeredTargets | Where-Object { $_.target -eq $Target })[0]
$coreAPI = [int]$coreTarget.publicAPI
foreach ($component in $components) {
    if ($null -ne $component.minimumCoreAPI -and "$($component.minimumCoreAPI)" -ne '' -and [int]$component.minimumCoreAPI -gt $coreAPI) { throw "Core API too old for $($component.addon)." }
}
$inventory = @(Get-ChildItem -LiteralPath $stage -File -Recurse | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = (Get-RelativePath $stage $_.FullName); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
})
$clientName = @{ Mists = 'Mists of Pandaria Classic'; Forever = 'Forever' }[$Target]
$clientNameZh = @{ Mists = '熊猫人之谜怀旧服'; Forever = '无限服' }[$Target]
$manifest = [ordered]@{
    schemaVersion = 2; package = $suite.Name; title = $suite.Title; target = $Target; slug = $slug; version = $version
    supportedTargets = @($Target); sourceSHA256 = $inputDigest
    buildTimeUTC = [DateTime]::UtcNow.ToString('o'); uploadState = 'not-uploaded'
    clientAcceptance = 'not-established-by-packaging'; curseForgeConcurrentManagement = 'unverified-not-supported'
    components = @($components); componentFiles = $inventory
}
$lines = @(
    "# $($suite.Title) - $clientName - v$version", '',
    'Local release candidate / 本地发布候选；not uploaded / 未上传。', '',
    "Suite snapshot containing all $($components.Count) Yibo addons released for $clientName. Component versions remain independent.",
    "本整合包包含 $clientNameZh 已发布的全部 $($components.Count) 个 Yibo 插件。整合包与各插件分别维护版本号。", '',
    "Source snapshot SHA256: $inputDigest", '',
    '## Included components / 本文件包含的具体组件', '',
    '| Addon | Version | Required TOC dependencies / 必须依赖 | Optional TOC dependencies / 可选依赖 | Minimum Core API / 最低 Core API |',
    '|---|---|---|---|---|'
)
foreach ($component in $components) {
    $requiredText = if ($component.requiredDependencies.Count) { $component.requiredDependencies -join ', ' } else { '-' }
    $optionalText = if ($component.optionalDependencies.Count) { $component.optionalDependencies -join ', ' } else { '-' }
    $apiText = if ($null -ne $component.minimumCoreAPI -and "$($component.minimumCoreAPI)" -ne '') { [string]$component.minimumCoreAPI } elseif ($component.addon -eq 'YiboCore') { "Provides API $coreAPI" } else { 'Runtime capability check / 以运行时能力检查为准' }
    $lines += "| $($component.addon) | $($component.version) | $requiredText | $optionalText | $apiText |"
}
$lines += @('', '## Installation, removal and update rules / 安装、删减与更新规则', '', [IO.File]::ReadAllText((Join-Path $suiteRoot 'INSTALL.md')), '', '## Component package checksums / 组件安装包校验', '', 'The Suite includes each component package byte-for-byte after extraction. Its manifest records each runtime file checksum.', 'Suite 内组件内容与本次单体包解压内容逐字节一致；清单逐文件记录运行内容校验值。', '')
foreach ($component in $components) { $lines += ('- `{0}`: `{1}`' -f $component.componentPackage, $component.componentPackageSHA256) }
$cfLines = @("$($suite.Title) v$version - $clientName", '', '| Addon | Version |', '|---|---|')
foreach ($component in $components) { $cfLines += "| $($component.addon) | $($component.version) |" }
if ((Get-YiboSourceDigest @(Get-SuiteInputEntries)) -ne $inputDigest) { throw 'Suite inputs changed during build; intermediates retained, no final package published.' }
[void](New-Item -ItemType Directory -Path $outputPath -Force)
$temporary = $final + '.building-' + [guid]::NewGuid().ToString('N')
# ZipFile.CreateFromDirectory on .NET Framework writes backslash entry names;
# write each entry explicitly with forward slashes (ZIP specification).
$zipStream = [IO.File]::Open($temporary, [IO.FileMode]::CreateNew)
try {
    $archive = New-Object IO.Compression.ZipArchive($zipStream, [IO.Compression.ZipArchiveMode]::Create, $false)
    try {
        foreach ($file in (Get-ChildItem -LiteralPath $stage -File -Recurse | Sort-Object FullName)) {
            $entry = $archive.CreateEntry((Get-RelativePath $stage $file.FullName), [IO.Compression.CompressionLevel]::Optimal)
            $entryStream = $entry.Open(); $fileStream = [IO.File]::OpenRead($file.FullName)
            try { $fileStream.CopyTo($entryStream) } finally { $fileStream.Dispose(); $entryStream.Dispose() }
        }
    } finally { $archive.Dispose() }
} finally { $zipStream.Dispose() }
$expected = @(Get-ChildItem -LiteralPath $stage -File -Recurse)
$zip = [IO.Compression.ZipFile]::OpenRead($temporary)
try {
    if ($zip.Entries.Count -ne $expected.Count) { throw 'Suite ZIP file count mismatch.' }
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName.Contains([string][char]92)) { throw "Suite ZIP entry uses a backslash: $($entry.FullName)" }
        $source = Resolve-YiboSourceFile $stage $entry.FullName
        $stream = $entry.Open()
        try { $hash = Get-Sha256Hex $stream } finally { $stream.Dispose() }
        if ($hash -cne (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash) { throw "Suite ZIP checksum mismatch: $($entry.FullName)" }
    }
} finally { $zip.Dispose() }
$profile = [pscustomobject]@{ Addon = $suite.Name; Target = $Target; Config = $config }
$artifact = [pscustomobject]@{ Channel = 'CurseForge'; Final = $final; Temporary = $temporary }
$archived = Publish-YiboPackages $outputPath $profile @($artifact)
[void](New-Item -ItemType Directory -Path $releaseRoot)
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $releaseRoot 'CHANGELOG.md'), ($lines -join "`n"), $utf8)
[IO.File]::WriteAllText((Join-Path $releaseRoot 'CURSEFORGE_CHANGELOG.md'), ($cfLines -join "`n"), $utf8)
Copy-Item -LiteralPath (Join-Path $suiteRoot 'INSTALL.md') -Destination $releaseRoot
[IO.File]::WriteAllText((Join-Path $releaseRoot 'YiboAddonSuiteManifest.json'), ($manifest | ConvertTo-Json -Depth 14), $utf8)
return [pscustomobject]@{
    Suite = $suite.Name; Target = $Target; Version = $version; Components = $components.Count; Package = $final
    PackageSHA256 = (Get-FileHash -LiteralPath $final -Algorithm SHA256).Hash.ToLowerInvariant()
    Changelog = (Join-Path $releaseRoot 'CHANGELOG.md'); Manifest = (Join-Path $releaseRoot 'YiboAddonSuiteManifest.json')
    SourceSHA256 = $inputDigest; IntermediateRoot = $runRoot; Archived = $archived; Uploaded = $false
}
