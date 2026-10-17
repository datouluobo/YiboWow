#Requires -Version 7.2
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
    [string]$OutputRoot,
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
$suiteRoot = Join-Path $workspace 'YiboSuite'
. (Join-Path $workspace 'Tools/Release.Common.ps1')
$suite = Import-PowerShellDataFile -LiteralPath (Join-Path $suiteRoot 'Suite.psd1')
$config = Import-PowerShellDataFile -LiteralPath (Join-Path $workspace 'Tools/ReleaseProfiles.psd1')
if ($suite.Name -cne 'YiboSuite' -or $suite.Target -cne 'Mists' -or $suite.Version -notmatch '^\d+\.\d+\.\d+$') {
    throw 'Invalid Suite identity, version or target.'
}
$addons = @($suite.Addons | Sort-Object -Unique)
$registered = @(@($config.Addons.Keys) + @($config.LegacyBundles.Keys) | Sort-Object -Unique)
if (($addons -join ',') -cne ($registered -join ',')) { throw 'Suite must include exactly all registered release addons.' }
$outputPath = [IO.Path]::GetFullPath($(if ($OutputRoot) { $OutputRoot } else { Join-Path $workspace 'Builds' }))
foreach ($name in @($addons) + 'YiboSuite') {
    $sourceRoot = [IO.Path]::GetFullPath((Join-Path $workspace $name)).TrimEnd([char[]]'\/')
    if ($outputPath -ieq $sourceRoot -or $outputPath.StartsWith($sourceRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'OutputRoot must be outside addon and Suite source directories.'
    }
}
$filename = "YiboSuite-mists-v$($suite.Version)-curseforge.zip"
$final = Join-Path $outputPath $filename
$releaseRoot = Join-Path $suiteRoot "Releases/v$($suite.Version)"
if (-not $ValidateOnly -and ((Test-Path -LiteralPath $final) -or (Test-Path -LiteralPath $releaseRoot))) {
    throw "Suite version already exists: $final or $releaseRoot. Choose a new Suite version or an unused workspace/output location."
}
function Get-SuiteInputEntries {
    foreach ($name in $addons) {
        foreach ($entry in (Get-YiboPublicEntries (Join-Path $workspace $name))) {
            [pscustomobject]@{ Relative = "$name/$($entry.Relative)"; Source = $entry.Source }
        }
    }
    foreach ($relative in @('Tools/Build-ReleasePackages.ps1', 'Tools/Build-LegacyBundle.ps1', 'Tools/Release.Common.ps1', 'Tools/ReleaseProfiles.psd1', 'Tools/Check-Localization.py', 'YiboSuite/Suite.psd1', 'YiboSuite/INSTALL.md', 'YiboSuite/README.md', 'YiboSuite/Tools/Build-Suite.ps1')) {
        [pscustomobject]@{ Relative = $relative; Source = (Resolve-YiboSourceFile $workspace $relative) }
    }
}
$inputDigest = Get-YiboSourceDigest @(Get-SuiteInputEntries)
if ($ValidateOnly) {
    foreach ($name in $addons) {
        & (Join-Path $workspace 'Tools/Build-ReleasePackages.ps1') -Addon $name -WorkspaceRoot $workspace -OutputRoot $outputPath -Channel CurseForge -ValidateOnly | Out-Null
    }
    return [pscustomobject]@{ Suite = $suite.Name; Version = $suite.Version; Components = $addons.Count; SourceSHA256 = $inputDigest; Package = $final; ValidationOnly = $true }
}
$runRoot = Join-Path $workspace ('_NonRelease/Packaging/Suite/' + [guid]::NewGuid().ToString('N'))
$componentOutput = Join-Path $runRoot 'Components'
$stage = Join-Path $runRoot 'Stage'
[void](New-Item -ItemType Directory -Path $stage -Force)
$components = @()
foreach ($name in $addons) {
    Write-Host "Building Suite component: $name"
    $plan = & (Join-Path $workspace 'Tools/Build-ReleasePackages.ps1') -Addon $name -WorkspaceRoot $workspace -OutputRoot $componentOutput -Channel CurseForge
    $package = $plan.CurseForge
    $zip = [IO.Compression.ZipFile]::OpenRead($package)
    try {
        foreach ($entry in $zip.Entries) {
            if (-not $entry.FullName.StartsWith("$name/", [StringComparison]::Ordinal) -or $entry.FullName -match '(^|/)(\.\.|_NonRelease|WTF|SavedVariables)(/|$)') {
                throw "Unsafe component entry: $($entry.FullName)"
            }
        }
    } finally { $zip.Dispose() }
    [IO.Compression.ZipFile]::ExtractToDirectory($package, $stage, $false)
    $tocName = if ($config.LegacyBundles.ContainsKey($name)) { "${name}_Mists.toc" } else { $config.Addons[$name].Targets.Mists.LoadToc }
    $toc = [IO.File]::ReadAllText((Join-Path (Join-Path $stage $name) $tocName))
    $version = Read-YiboRequiredValue $toc '^## Version:\s*([^\r\n]+)' 'component TOC version'
    $required = @()
    $optional = @()
    foreach ($match in [regex]::Matches($toc, '(?m)^## (RequiredDeps|Dependencies|OptionalDeps):\s*([^\r\n]+)')) {
        $values = @($match.Groups[2].Value -split '[,\s]+' | Where-Object { $_ })
        if ($match.Groups[1].Value -eq 'OptionalDeps') { $optional += $values } else { $required += $values }
    }
    foreach ($dependency in $required) { if ($dependency -notin $addons) { throw "Missing Suite dependency: $name -> $dependency" } }
    $componentManifest = Get-Content -LiteralPath (Join-Path (Join-Path $stage $name) 'YiboReleaseManifest.json') -Raw | ConvertFrom-Json
    $target = @($componentManifest.registeredTargets | Where-Object { $_.target -eq 'Mists' })[0]
    $minimumAPI = if ($target.PSObject.Properties.Name -contains 'minimumCoreAPI') { $target.minimumCoreAPI } else { $null }
    $components += [ordered]@{
        addon = $name; version = $version; sourceToc = $tocName
        interface = (Read-YiboRequiredValue $toc '^## Interface:\s*([^\r\n]+)' 'component interface')
        requiredDependencies = @($required); optionalDependencies = @($optional); minimumCoreAPI = $minimumAPI
        sourceSHA256 = $componentManifest.sourceSHA256
        componentPackage = [IO.Path]::GetFileName($package)
        componentPackageSHA256 = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
$core = @($components | Where-Object { $_.addon -eq 'YiboCore' })[0]
$coreManifest = Get-Content -LiteralPath (Join-Path $stage 'YiboCore/YiboReleaseManifest.json') -Raw | ConvertFrom-Json
$coreAPI = [int]$coreManifest.registeredTargets[0].publicAPI
foreach ($component in $components) {
    if ($null -ne $component.minimumCoreAPI -and [int]$component.minimumCoreAPI -gt $coreAPI) { throw "Core API too old for $($component.addon)." }
}
$inventory = @(Get-ChildItem -LiteralPath $stage -File -Recurse | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = [IO.Path]::GetRelativePath($stage, $_.FullName).Replace('\', '/'); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
})
$manifest = [ordered]@{
    schemaVersion = 1; suite = $suite.Name; title = $suite.Title; version = $suite.Version
    target = 'Mists'; supportedTargets = @('Mists'); sourceSHA256 = $inputDigest
    buildTimeUTC = [DateTime]::UtcNow.ToString('o'); uploadState = 'not-uploaded'
    clientAcceptance = 'not-established-by-packaging'; curseForgeConcurrentManagement = 'unverified-not-supported'
    components = @($components); componentFiles = $inventory
}
$lines = @(
    "# $($suite.Title) - v$($suite.Version)", '',
    'Local release candidate / 本地发布候选；not uploaded / 未上传。', '',
    'First Suite snapshot containing all 15 current release addons for Mists of Pandaria Classic. Component versions remain independent.',
    '首个 Suite 快照，包含全部 15 个正式插件的当前打包版本。Suite 与单体分别维护版本。', '',
    "Source snapshot SHA256: $inputDigest", '',
    '## Included components / 本文件包含的具体组件', '',
    '| Addon | Version | Required TOC dependencies / 必须依赖 | Optional TOC dependencies / 可选依赖 | Minimum Core API / 最低 Core API |',
    '|---|---|---|---|---|'
)
foreach ($component in $components) {
    $requiredText = if ($component.requiredDependencies.Count) { $component.requiredDependencies -join ', ' } else { '-' }
    $optionalText = if ($component.optionalDependencies.Count) { $component.optionalDependencies -join ', ' } else { '-' }
    $apiText = if ($null -ne $component.minimumCoreAPI) { [string]$component.minimumCoreAPI } elseif ($component.addon -eq 'YiboCore') { "Provides API $coreAPI" } else { 'Runtime capability check / 以运行时能力检查为准' }
    $lines += "| $($component.addon) | $($component.version) | $requiredText | $optionalText | $apiText |"
}
$lines += @('', '## Installation, removal and update rules / 安装、删减与更新规则', '', [IO.File]::ReadAllText((Join-Path $suiteRoot 'INSTALL.md')), '', '## Component package checksums / 组件安装包校验', '', 'The Suite includes each component package byte-for-byte after extraction. Its manifest records each runtime file checksum.', 'Suite 内组件内容与本次单体包解压内容逐字节一致；清单逐文件记录运行内容校验值。', '')
foreach ($component in $components) { $lines += ('- `{0}`: `{1}`' -f $component.componentPackage, $component.componentPackageSHA256) }
$suiteStage = Join-Path $stage 'YiboSuite'
[void](New-Item -ItemType Directory -Path $suiteStage)
[IO.File]::WriteAllText((Join-Path $suiteStage 'CHANGELOG.md'), ($lines -join "`n"), [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $suiteStage 'YiboSuiteManifest.json'), ($manifest | ConvertTo-Json -Depth 14), [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $suiteRoot 'INSTALL.md') -Destination $suiteStage
if ((Get-YiboSourceDigest @(Get-SuiteInputEntries)) -ne $inputDigest) { throw 'Suite inputs changed during build; intermediates retained, no final package published.' }
[void](New-Item -ItemType Directory -Path $outputPath -Force)
$temporary = $final + '.building-' + [guid]::NewGuid().ToString('N')
[IO.Compression.ZipFile]::CreateFromDirectory($stage, $temporary, [IO.Compression.CompressionLevel]::Optimal, $false)
$expected = @(Get-ChildItem -LiteralPath $stage -File -Recurse)
$zip = [IO.Compression.ZipFile]::OpenRead($temporary)
try {
    if ($zip.Entries.Count -ne $expected.Count) { throw 'Suite ZIP file count mismatch.' }
    foreach ($entry in $zip.Entries) {
        $source = Resolve-YiboSourceFile $stage $entry.FullName
        $stream = $entry.Open()
        try { $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)) } finally { $stream.Dispose() }
        if ($hash -cne (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash) { throw "Suite ZIP checksum mismatch: $($entry.FullName)" }
    }
} finally { $zip.Dispose() }
$profile = [pscustomobject]@{ Addon = 'YiboSuite'; Target = 'Mists'; Config = $config }
$artifact = [pscustomobject]@{ Channel = 'CurseForge'; Final = $final; Temporary = $temporary }
$archived = Publish-YiboPackages $outputPath $profile @($artifact)
[void](New-Item -ItemType Directory -Path $releaseRoot)
foreach ($name in @('CHANGELOG.md', 'INSTALL.md', 'YiboSuiteManifest.json')) {
    Copy-Item -LiteralPath (Join-Path $suiteStage $name) -Destination (Join-Path $releaseRoot $name)
}
return [pscustomobject]@{
    Suite = $suite.Name; Version = $suite.Version; Components = $components.Count; Package = $final
    PackageSHA256 = (Get-FileHash -LiteralPath $final -Algorithm SHA256).Hash.ToLowerInvariant()
    Changelog = (Join-Path $releaseRoot 'CHANGELOG.md'); Manifest = (Join-Path $releaseRoot 'YiboSuiteManifest.json')
    SourceSHA256 = $inputDigest; IntermediateRoot = $runRoot; Archived = $archived; Uploaded = $false
}
