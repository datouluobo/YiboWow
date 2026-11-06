#Requires -Version 7.2
[CmdletBinding()]
param([string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path)
$ErrorActionPreference = 'Stop'
$builder = Join-Path $WorkspaceRoot 'Tools/Build-ReleasePackages.ps1'
. (Join-Path $WorkspaceRoot 'Tools/Release.Common.ps1')
$runRoot = Join-Path $PSScriptRoot ('Runs/' + [guid]::NewGuid().ToString('N'))
$fixtureWorkspace = Join-Path $runRoot 'workspace'
$fixtureAddon = Join-Path $fixtureWorkspace 'YiboVault'
$output = Join-Path $runRoot 'output'
$script:passed = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:passed++
}
function Write-Fixture {
    param([string]$Relative, [string]$Text)
    $path = Join-Path $fixtureAddon $Relative
    [void](New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force)
    [IO.File]::WriteAllText($path, $Text, [Text.UTF8Encoding]::new($false))
}
function Set-FixtureVersion {
    param([string]$Version)
    Write-Fixture 'Namespace.lua' "local Addon = {}`nAddon.RELEASE_VERSION = `"$Version`"`nAddon.API_VERSION = 1`nAddon.REQUIRED_CORE_API = 13`n"
    Write-Fixture 'YiboVault.toc' "## Interface: 50504`n## Version: $Version-api1`nNamespace.lua`nMain.lua`n"
}
function Assert-Failure {
    param([scriptblock]$Action, [string]$Pattern)
    $caught = $null
    try { & $Action | Out-Null } catch { $caught = $_.Exception.Message }
    Assert-True ($null -ne $caught -and $caught -match $Pattern) "Expected failure '$Pattern', got '$caught'"
}
function Read-Package {
    param([string]$Path)
    $zip = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $names = @($zip.Entries.FullName)
        $reader = [IO.StreamReader]::new($zip.GetEntry('YiboVault/YiboReleaseManifest.json').Open())
        try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        return [pscustomobject]@{ Names = $names; Manifest = $manifest }
    } finally { $zip.Dispose() }
}

Set-FixtureVersion '1.0.0'
Write-Fixture 'Main.lua' 'local answer = 42'
Write-Fixture 'Media/icon.tga' 'synthetic texture fixture'
Write-Fixture 'README.md' 'Public source documentation.'
Write-Fixture 'Retail/Secret.lua' 'local retailOnly = true'
Write-Fixture '_NonRelease/probe.lua' 'local probe = true'
Write-Fixture 'Media/_NonRelease/private.txt' 'private fixture'

$plan = & $builder -Addon YiboVault -Target mists -WorkspaceRoot $fixtureWorkspace -OutputRoot $output -ValidateOnly
Assert-True ($plan.Target -ceq 'Mists') 'Target input is normalized.'
Assert-True ((Split-Path $plan.CurseForge -Leaf) -ceq 'YiboVault-mists-v1.0.0-api1-curseforge.zip') 'Product slug precedes its independent version and API tag.'
Assert-True (-not (Test-Path -LiteralPath $output)) 'ValidateOnly does not create output directories.'
Assert-Failure { & $builder -Addon YiboVault -Target Forever -WorkspaceRoot $fixtureWorkspace -OutputRoot $output } 'No verified build profile'
Assert-Failure { & $builder -Addon YiboVault -Target TBC -WorkspaceRoot $fixtureWorkspace -OutputRoot $output } 'No verified build profile'
Assert-Failure { & $builder -Addon YiboVault -Target Titan -WorkspaceRoot $fixtureWorkspace -OutputRoot $output } 'No verified build profile'
Assert-Failure { & $builder -Addon YiboVault -Target Mist -WorkspaceRoot $fixtureWorkspace -OutputRoot $output } 'Unknown product target'
Assert-Failure { & $builder -Addon YiboUnregistered -WorkspaceRoot $fixtureWorkspace -OutputRoot $output } 'has not joined'
Assert-Failure { & $builder -Addon YiboVault -WorkspaceRoot $fixtureWorkspace -OutputRoot (Join-Path $fixtureAddon 'Builds') } 'outside the addon'

[void](New-Item -ItemType Directory -Path $output -Force)
$legacy = Join-Path $output 'YiboVault-v0.9.0-api1-curseforge.zip'
$previousMists = Join-Path $output 'YiboVault-v0.9.1-api1-mists-curseforge.zip'
$retail = Join-Path $output 'YiboVault-v0.9.0-api1-retail-curseforge.zip'
$retailCurrent = Join-Path $output 'YiboVault-retail-v0.9.1-api1-curseforge.zip'
$tbc = Join-Path $output 'YiboVault-tbc-v0.1.0-api1-curseforge.zip'
$titan = Join-Path $output 'YiboVault-titan-v0.2.0-api1-curseforge.zip'
$universal = Join-Path $output 'YiboVault-universal-v0.9.0-api1-curseforge.zip'
$unclassified = Join-Path $output 'YiboVault-v0.9.0-api1-unknown-target-curseforge.zip'
[IO.File]::WriteAllText($legacy, 'previous MoP artifact')
[IO.File]::WriteAllText($previousMists, 'previous target-after-version artifact')
[IO.File]::WriteAllText($retail, 'unrelated retail artifact')
foreach ($otherArtifact in @($retailCurrent, $tbc, $titan)) { [IO.File]::WriteAllText($otherArtifact, 'unrelated target artifact') }
[IO.File]::WriteAllText($universal, 'unrelated universal artifact')
[IO.File]::WriteAllText($unclassified, 'unclassified artifact')
$retailHash = (Get-FileHash -LiteralPath $retail).Hash
$defaultPlan = & $builder -Addon YiboVault -WorkspaceRoot $fixtureWorkspace -OutputRoot $output -ValidateOnly
Assert-True ($null -eq $defaultPlan.GitHub) 'Default build plan excludes the GitHub channel.'
$first = & $builder -Addon YiboVault -WorkspaceRoot $fixtureWorkspace -OutputRoot $output -Channel Both
$cf = Read-Package $first.CurseForge
$gh = Read-Package $first.GitHub
Assert-True ($first.Archived -eq 2) 'Both historical MoP filename formats are archived.'
Assert-True (Test-Path -LiteralPath (Join-Path $output 'Archive/YiboVault/YiboVault-v0.9.0-api1-curseforge.zip')) 'Historical filename is retained.'
Assert-True (Test-Path -LiteralPath (Join-Path $output 'Archive/YiboVault/YiboVault-v0.9.1-api1-mists-curseforge.zip')) 'Target-after-version filename is retained in archive.'
Assert-True ((Get-FileHash -LiteralPath $retail).Hash -eq $retailHash) 'Other target artifact is unchanged.'
foreach ($otherArtifact in @($retailCurrent, $tbc, $titan)) { Assert-True (Test-Path -LiteralPath $otherArtifact) 'Independent target-first streams are retained.' }
Assert-True (Test-Path -LiteralPath $universal) 'Universal artifact is unchanged.'
Assert-True (Test-Path -LiteralPath $unclassified) 'Unclassified artifact is not guessed to be historical MoP.'
Assert-True ('YiboVault/YiboVault.toc' -in $cf.Names) 'Client package uses the default TOC filename.'
Assert-True ('YiboVault/Retail/Secret.lua' -notin $cf.Names) 'Other target source is excluded from CF.'
Assert-True ('YiboVault/Media/icon.tga' -in $cf.Names) 'Dynamic runtime texture is included.'
Assert-True ('YiboVault/README.md' -notin $cf.Names) 'CF contains runtime payload only.'
Assert-True ('YiboVault/Retail/Secret.lua' -in $gh.Names) 'GitHub source archive retains all target source.'
Assert-True (@($gh.Names | Where-Object { $_ -match '_NonRelease' }).Count -eq 0) 'Non-release source is excluded at every level.'
Assert-True ($cf.Manifest.target -eq 'Mists' -and $cf.Manifest.curseForge.flavor -eq 'mists') 'CF target and flavor are explicit.'
Assert-True ($cf.Manifest.curseForge.uploadState -eq 'requires-current-game-version-id-resolution') 'TOC Interface is not used as a CF numeric version ID.'
Assert-True ($gh.Manifest.purpose -eq 'all-target-source-and-public-documentation') 'GitHub archive declares its source purpose.'
Assert-True ($gh.Manifest.registeredTargets[0].minimumCoreAPI -eq 13) 'Archive records minimum Core API.'
Assert-True ($first.GitHub -match '-mists-v1\.0\.0-api1-src\.[0-9a-f]{12}-github\.zip$') 'GitHub archive uses the configured target slug, release and public API versions.'

Set-FixtureVersion '1.0.1'
$second = & $builder -Addon YiboVault -WorkspaceRoot $fixtureWorkspace -OutputRoot $output -Channel CurseForge
Assert-True ($null -eq $second.GitHub -and $second.Archived -eq 1) 'CF-only build replaces one target stream.'
Assert-True (Test-Path -LiteralPath $first.GitHub) 'CF-only build preserves GitHub archive.'
Write-Fixture 'README.md' 'Updated public source documentation.'
$third = & $builder -Addon YiboVault -WorkspaceRoot $fixtureWorkspace -OutputRoot $output -Channel GitHub
Assert-True ($null -eq $third.CurseForge -and $third.Archived -eq 1) 'GitHub-only build replaces one source stream.'
Assert-True (Test-Path -LiteralPath $second.CurseForge) 'GitHub-only build preserves the latest CF artifact.'
Assert-Failure { & $builder -Addon YiboVault -WorkspaceRoot $fixtureWorkspace -OutputRoot $output -Channel CurseForge } 'Package already exists'
Assert-True (Test-Path -LiteralPath $second.CurseForge) 'Duplicate build does not move the current artifact.'

Set-FixtureVersion '1.0.2'
$conflict = Join-Path $output ('Archive/YiboVault/' + (Split-Path $second.CurseForge -Leaf))
[IO.File]::WriteAllText($conflict, 'archive conflict fixture')
Assert-Failure { & $builder -Addon YiboVault -WorkspaceRoot $fixtureWorkspace -OutputRoot $output -Channel CurseForge } 'Archive package already exists'
Assert-True (Test-Path -LiteralPath $second.CurseForge) 'Archive conflict is detected before moving old artifacts.'
Assert-True (Test-Path -LiteralPath $third.GitHub) 'Archive conflict preserves the other channel.'

Write-Fixture 'YiboVault.toc' "## Interface: 40402`n## Version: 1.0.2-api1`nMain.lua`n"
Assert-Failure { & $builder -Addon YiboVault -WorkspaceRoot $fixtureWorkspace -ValidateOnly } 'Interface does not match'
Write-Fixture 'YiboVault.toc' "## Interface: 50504`n## Version: 9.9.9-api1`nMain.lua`n"
Assert-Failure { & $builder -Addon YiboVault -WorkspaceRoot $fixtureWorkspace -ValidateOnly } 'does not match source'
foreach ($case in @(
    @{ Entry = '../outside.lua'; Error = 'escapes addon root' },
    @{ Entry = 'Missing.lua'; Error = 'file is missing' },
    @{ Entry = 'Retail/Secret.lua'; Error = 'another product target' },
    @{ Entry = '_NonRelease/probe.lua'; Error = 'non-release content' },
    @{ Entry = 'Main.xml'; Error = 'static Lua TOC entries only' }
    @{ Entry = "Main.lua`nMain.lua"; Error = 'Duplicate TOC entry' }
)) {
    Write-Fixture 'YiboVault.toc' "## Interface: 50504`n## Version: 1.0.2-api1`n$($case.Entry)`n"
    Assert-Failure { & $builder -Addon YiboVault -WorkspaceRoot $fixtureWorkspace -ValidateOnly } $case.Error
}
Set-FixtureVersion '1.0.2'
Write-Fixture 'Main.lua' 'local = broken'
Assert-Failure { & $builder -Addon YiboVault -WorkspaceRoot $fixtureWorkspace -ValidateOnly } 'Lua syntax failed'
Write-Fixture 'Main.lua' 'local answer = 42'

# Inject a second-publication failure to verify restoration after a partial move.
$rollbackRoot = Join-Path $runRoot 'rollback'
[void](New-Item -ItemType Directory -Path $rollbackRoot -Force)
$old = Join-Path $rollbackRoot 'YiboVault-v0.1.0-api1-mists-curseforge.zip'
$temporary1 = Join-Path $rollbackRoot 'one.building'
$temporary2 = Join-Path $rollbackRoot 'two.building'
$final1 = Join-Path $rollbackRoot 'YiboVault-mists-v1.0.2-api1-curseforge.zip'
$final2 = Join-Path $rollbackRoot 'YiboVault-src.rollback-github.zip'
foreach ($path in @($old, $temporary1, $temporary2)) { [IO.File]::WriteAllText($path, 'transaction fixture') }
$profile = Get-YiboReleaseProfile $fixtureWorkspace YiboVault Mists
& {
    function Move-Item {
        param([string]$LiteralPath, [string]$Destination)
        if ($Destination -eq $final2) { throw 'injected publication failure' }
        Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination -ErrorAction Stop
    }
    Assert-Failure {
        Publish-YiboPackages $rollbackRoot $profile @(
            [pscustomobject]@{ Channel = 'CurseForge'; Temporary = $temporary1; Final = $final1 },
            [pscustomobject]@{ Channel = 'GitHub'; Temporary = $temporary2; Final = $final2 }
        )
    } 'injected publication failure'
}
Assert-True (Test-Path -LiteralPath $old) 'Failed transaction restores the previous artifact.'
Assert-True (-not (Test-Path -LiteralPath $final1)) 'Failed transaction does not leave a partially published package.'
Assert-True ((Test-Path -LiteralPath $temporary1) -and (Test-Path -LiteralPath $temporary2)) 'Failed transaction retains both intermediates.'

# Target-specific version indexing must ignore an unrelated TOC's different version.
$beastRoot = Join-Path $fixtureWorkspace 'YiboBeastPaths'
[void](New-Item -ItemType Directory -Path $beastRoot -Force)
[IO.File]::WriteAllText((Join-Path $beastRoot 'YiboBeastPaths_Mists.toc'), "## Interface: 50400`n## Version: v1.7.0`n")
[IO.File]::WriteAllText((Join-Path $beastRoot 'YiboBeastPaths_Mainline.toc'), "## Interface: 120007`n## Version: v2.0.0`n")
$index = Get-YiboPackagedAddonVersions $fixtureWorkspace $profile
Assert-True ($index.YiboBeastPaths -eq '1.7.0') 'Core indexes the selected target version without requiring every TOC version to match.'

[pscustomobject]@{ Passed = $script:passed; RunRoot = $runRoot; Cleanup = 'Fixtures and intermediates retained for diagnosis.' }
