#Requires -Version 7.2
$ErrorActionPreference='Stop'
$workspacePath=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $workspacePath 'Tools/Release.Common.ps1')
$config=Import-PowerShellDataFile (Join-Path $workspacePath 'Tools/ReleaseProfiles.psd1')
$script:checks=0
function Assert-True($Condition,[string]$Message) { $script:checks++; if(-not $Condition) {throw $Message} }
function Assert-Throws([scriptblock]$Action,[string]$Message) {
    $threw=$false;try { & $Action | Out-Null } catch {$threw=$true};Assert-True $threw $Message
}
$plans=@()
foreach($addon in ($config.Addons.Keys | Sort-Object)) {
    $scriptName=if($addon -eq 'YiboLegendary') {'Build-CurseForgePackage.ps1'} else {'Build-ReleasePackages.ps1'}
    $entry=Join-Path $workspacePath "$addon/_NonRelease/Tools/$scriptName"
    Assert-True (Test-Path -LiteralPath $entry) "Missing entry: $addon"
    $plan=& $entry -ValidateOnly
    $githubPlan=& $entry -Channel GitHub -ValidateOnly
    Assert-True ($null -eq $plan.GitHub) "Default build generated a GitHub package: $addon"
    $expectedVersion=$plan.Version
    if($addon -eq 'YiboCore') {$expectedVersion+='-api13'}
    Assert-True ((Split-Path $plan.CurseForge -Leaf) -ceq "$addon-mists-v$expectedVersion-curseforge.zip") "Wrong install name: $addon"
    $sourceTargets=if($addon -eq 'YiboCore') {'forever-mists'} else {'mists'}
    Assert-True ((Split-Path $githubPlan.GitHub -Leaf) -cmatch ('^'+$addon+'-'+$sourceTargets+'-v'+[regex]::Escape($expectedVersion)+'-src\.[0-9a-f]{12}-github\.zip$')) "Wrong source name: $addon"
    if($addon -notin @('YiboCore','YiboMail','YiboVault')) {
        Assert-True ($null -eq $plan.APIVersion -and $plan.CurseForge -notmatch '-api\d+') "Dependency API leaked into own version: $addon"
    }
    $plans+=$plan
    $plans+=$githubPlan
}
$beastEntry=Join-Path $workspacePath 'YiboBeastPaths/_NonRelease/Tools/Build-CurseForgePackages.ps1'
$bundle=& $beastEntry -ValidateOnly
$bundleGitHub=& $beastEntry -Channel GitHub -ValidateOnly
Assert-True ($null -eq $bundle.GitHub) 'Default legacy build generated a GitHub package'
Assert-True ((Split-Path $bundle.CurseForge -Leaf) -eq 'YiboBeastPaths-universal-v1.8-curseforge.zip') 'Legacy multi-TOC name'
Assert-True ((@($bundle.SupportedTargets | Sort-Object) -join ',') -eq 'Mists,Retail') 'BeastPaths must support exactly Retail and Mists'
Assert-True (($config.LegacyBundles.YiboBeastPaths.TocTargets -join ',') -eq 'Retail,Retail,Mists') 'Default and Mainline TOCs must both belong to Retail'
Assert-True ((Split-Path $bundleGitHub.GitHub -Leaf) -match '^YiboBeastPaths-mists-retail-v1\.8-src\.[0-9a-f]{12}-github.zip$') 'Legacy source name'
$dispatched=& (Join-Path $workspacePath 'Tools/Build-ReleasePackages.ps1') -Addon YiboBeastPaths -ValidateOnly
Assert-True ($dispatched.Target -eq 'Universal' -and $dispatched.CurseForge -eq $bundle.CurseForge) 'Root entry did not dispatch the legacy bundle'
$plans+=$bundle
$plans+=$bundleGitHub
Assert-True (@($plans | Where-Object { $_.Addon -ne 'YiboBeastPaths' }).Count -eq 28) 'Every standard root plugin must expose default and GitHub channel plans'
Assert-True (@($plans | Where-Object { $_.Addon -eq 'YiboBeastPaths' }).Count -eq 2) 'Legacy package must expose default and GitHub channel plans'
$allNames=@($plans.CurseForge | Where-Object { $_ })+@($plans.GitHub | Where-Object { $_ })
Assert-True (@($allNames|Select-Object -Unique).Count -eq 30) 'Package names collided'
$rep=Join-Path $workspacePath 'YiboReputation/_NonRelease/Tools/Build-ReleasePackages.ps1'
$cf=& $rep -Channel CurseForge -ValidateOnly
$gh=& $rep -Channel GitHub -ValidateOnly
Assert-True ($null -eq $cf.GitHub -and $null -eq $gh.CurseForge) 'Channel selection'
Assert-True ($cf.SourceSHA256 -eq $gh.SourceSHA256) 'Source hash differs across channels'
Assert-Throws { & $rep -Target Retail -ValidateOnly } 'Unconfigured target must fail'
Assert-Throws { & $rep -Version 9.9.9 -ValidateOnly } 'Explicit version mismatch must fail'
Assert-Throws { & $beastEntry -Target Mists -ValidateOnly } 'Legacy bundle must not silently become a single-target package'
$hash='a'*64
$sourceTargets=@(@{slug='mists';gameVersionNames=@('5.5.4');interface=@(50504)})
$name=Get-YiboPackageNames -Addon YiboMail -Slug mists -Version 1.2.15-api1 -PublicAPI 1 -VersionIncludesAPI $true -SourceHash $hash -SourceTargets $sourceTargets
Assert-True ($name.CurseForge -notmatch '-api1-api1') 'Duplicate API suffix'
Assert-Throws { Get-YiboPackageNames -Addon YiboMail -Slug mists -Version 1.2.15-api2 -PublicAPI 1 -VersionIncludesAPI $true -SourceHash $hash -SourceTargets $sourceTargets } 'Mismatched API suffix'
Assert-Throws { Get-YiboPackageNames -Addon YiboReputation -Slug mists -Version 1.7.1-api13 -PublicAPI $null -VersionIncludesAPI $false -SourceHash $hash -SourceTargets $sourceTargets } 'Undeclared API suffix'
Assert-Throws { Get-YiboPackageNames -Addon '../bad' -Slug mists -Version 1.7.1 -SourceHash $hash -SourceTargets $sourceTargets } 'Unsafe filename input'

$sourceName=Get-YiboPackageNames -Addon YiboCore -Slug mists -Version 1.12.6 -PublicAPI 13 -VersionIncludesAPI $false -SourceHash $hash -SourceTargets $sourceTargets
Assert-True ($sourceName.GitHub -eq ('YiboCore-mists-v1.12.6-api13-src.'+$hash.Substring(0,12)+'-github.zip')) 'Source target or addon/API version missing'
$multi=@(@{slug='retail';gameVersionNames=@('12.0.7');interface=@(120007)},$sourceTargets[0],$sourceTargets[0])
Assert-True ((Get-YiboSourceTargetLabel $multi) -eq 'mists-retail') 'Source full-target sorting/deduplication'
Assert-True ((Get-YiboSourceTargetLabel @($multi[1],$multi[0])) -eq (Get-YiboSourceTargetLabel $multi)) 'Selected build target must not change source name'
Assert-Throws { Get-YiboSourceTargetLabel @(@{slug='../bad';gameVersionNames=@('5.5.4');interface=@(50504)}) } 'Unsafe target slug accepted'
Assert-True ((Get-YiboSourceTargetLabel @(@{slug='mists';gameVersionNames=@();interface=@()})) -eq 'mists') 'Source target label must not require patch or Interface metadata'

# Generated archive fixtures remain under _NonRelease; nothing is recursively removed.
$fixtures=Join-Path $PSScriptRoot ('Archive-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $fixtures)
foreach($name in @('YiboReputation-v1.7.1-curseforge.zip','YiboReputation-retail-v0.1.0-curseforge.zip','YiboReputation-src.old-github.zip')) {
    Set-Content -LiteralPath (Join-Path $fixtures $name) -Value 'fixture'
}
$profile=[pscustomobject]@{Addon='YiboReputation';Target='Mists';Config=$config}
$final=Join-Path $fixtures 'YiboReputation-mists-v1.7.1-curseforge.zip'
$temp=$final+'.building-test';Set-Content -LiteralPath $temp -Value 'new fixture'
$artifacts=@([pscustomobject]@{Channel='CurseForge';Final=$final;Temporary=$temp})
$moved=Publish-YiboPackages $fixtures $profile $artifacts
Assert-True ($moved -eq 1) 'Only selected legacy target/channel must be archived'
Assert-True (Test-Path (Join-Path $fixtures 'YiboReputation-retail-v0.1.0-curseforge.zip')) 'Other target was archived'
Assert-True (Test-Path (Join-Path $fixtures 'YiboReputation-src.old-github.zip')) 'Unselected source channel was archived'
Assert-True (Test-Path (Join-Path $fixtures 'Archive/YiboReputation/YiboReputation-v1.7.1-curseforge.zip')) 'Legacy install was not archived'
Assert-True ((Get-Content -LiteralPath $final -Raw).Trim() -eq 'new fixture') 'New artifact not published'
$conflict=Join-Path $fixtures 'Conflict';[void](New-Item -ItemType Directory -Path (Join-Path $conflict 'Archive/YiboReputation') -Force)
Set-Content (Join-Path $conflict 'YiboReputation-v1.7.1-curseforge.zip') 'old'
Set-Content (Join-Path $conflict 'Archive/YiboReputation/YiboReputation-v1.7.1-curseforge.zip') 'archive'
$newFinal=Join-Path $conflict 'YiboReputation-mists-v1.7.1-curseforge.zip'
Set-Content ($newFinal+'.building-test') 'intermediate'
Assert-Throws { Publish-YiboPackages $conflict $profile @([pscustomobject]@{Channel='CurseForge';Final=$newFinal;Temporary=($newFinal+'.building-test')}) } 'Archive conflict must fail'
Assert-True (Test-Path (Join-Path $conflict 'YiboReputation-v1.7.1-curseforge.zip')) 'Conflict moved old package'
Assert-True (-not (Test-Path $newFinal)) 'Conflict published a partial package'
$plans | Select-Object Addon,Target,Version,APIVersion,CurseForge,GitHub | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'UniformNames-Report.json')
Write-Output "PASS: $script:checks checks; 15 addon entry points, 30 names, API rules, channel selection and archive isolation"
