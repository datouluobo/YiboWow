#Requires -Version 7.2
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Addon,
    [string]$Target='Universal',
    [ValidateSet('Both','CurseForge','GitHub')][string]$Channel='Both',
    [string]$WorkspaceRoot=(Split-Path $PSScriptRoot -Parent),
    [string]$OutputRoot,
    [string]$Version,
    [switch]$ValidateOnly,
    [switch]$KeepStaging
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Release.Common.ps1')
$config=Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'ReleaseProfiles.psd1')
if (-not $config.LegacyBundles.ContainsKey($Addon) -or $Target -ne 'Universal') { throw 'No configured legacy multi-TOC bundle for this addon/target.' }
$definition=$config.LegacyBundles[$Addon]
if ($definition.SourceTocs.Count -ne $definition.TocTargets.Count -or $definition.SourceTocs.Count -ne $definition.Interfaces.Count -or
    (@($definition.TocTargets | Sort-Object -Unique) -join ',') -ne (@($definition.SupportedTargets | Sort-Object -Unique) -join ',')) {
    throw 'Legacy TOC mapping must exactly cover the declared supported targets.'
}
$root=(Resolve-Path -LiteralPath (Join-Path $WorkspaceRoot $Addon)).Path
$bundleVersions=@()
$targetStates=@()
for ($i=0;$i -lt $definition.SourceTocs.Count;$i++) {
    $relative=$definition.SourceTocs[$i]
    $text=[IO.File]::ReadAllText((Resolve-YiboSourceFile $root $relative))
    foreach($line in ($text -split '\r?\n')) {
        $reference=$line.Trim()
        if(-not $reference -or $reference.StartsWith('#') -or $reference -match '^_NonRelease[\\/]') {continue}
        [void](Resolve-YiboSourceFile $root $reference)
    }
    $bundleVersions+=(Read-YiboRequiredValue $text '^## Version:\s*([^\r\n]+)' 'TOC version').TrimStart('v','V')
    $interface=[int](Read-YiboRequiredValue $text '^## Interface:\s*(\d+)' 'TOC Interface')
    if ($interface -ne $definition.Interfaces[$i]) { throw "Legacy bundle Interface changed: $relative" }
    $targetStates+=@{target=$definition.TocTargets[$i];slug=$config.Targets[$definition.TocTargets[$i]].Slug;gameVersionNames=@();sourceToc=$relative;interface=$interface;validationState=$definition.ValidationState}
}
$versions=@($bundleVersions | Select-Object -Unique)
if ($versions.Count -ne 1) { throw 'Legacy bundle TOC versions differ.' }
$releaseVersion=$versions[0]
if ($Version -and $Version.TrimStart('v','V') -ne $releaseVersion) { throw 'Requested version differs from source version.' }
$publicEntries=@(Get-YiboPublicEntries $root | Where-Object { (Split-Path $_.Relative -Leaf) -ne 'PRODUCT.md' })
$hashEntries=$publicEntries + [pscustomobject]@{Relative='build-config/ReleaseProfiles.psd1';Source=(Join-Path $PSScriptRoot 'ReleaseProfiles.psd1');Content=$null}
$sourceHash=Get-YiboSourceDigest $hashEntries
$names=Get-YiboPackageNames -Addon $Addon -Slug $definition.Slug -Version $releaseVersion -PublicAPI $null -VersionIncludesAPI $false -SourceHash $sourceHash -SourceTargets @($targetStates)
$outputPath=[IO.Path]::GetFullPath($(if ($OutputRoot) {$OutputRoot} else {Join-Path $WorkspaceRoot 'Builds'}))
if ($outputPath -ieq $root -or $outputPath.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'OutputRoot must be outside the addon source directory.' }
$runtimeEntries=@($publicEntries | Where-Object {
    $_.Relative -notmatch '^(Screenshots/|Media/v\d+/)' -and
    (-not $_.Relative.EndsWith('.toc') -or $_.Relative -in $definition.SourceTocs)
})
# Preserve the maintenance package's existing multi-TOC/XML contents and strip
# non-release TOC references as its previous packager did.
foreach ($entry in $publicEntries) {
    if ($entry.Relative.EndsWith('.toc')) {
        $text=[IO.File]::ReadAllText($entry.Source)
        $entry.Content=(($text -split '\r?\n' | Where-Object { $_ -notmatch '^\s*_NonRelease[\\/]' }) -join "`n")
    }
}
Test-YiboLuaEntries $runtimeEntries '5.1'
$plan=[pscustomobject]@{Addon=$Addon;Target='Universal';SupportedTargets=@($definition.SupportedTargets);Version=$releaseVersion;APIVersion=$null;SourceSHA256=$sourceHash;
    CurseForge=$(if($Channel -in @('Both','CurseForge')) {Join-Path $outputPath $names.CurseForge} else {$null});
    GitHub=$(if($Channel -in @('Both','GitHub')) {Join-Path $outputPath $names.GitHub} else {$null});Archived=0;ValidationOnly=[bool]$ValidateOnly}
if ($ValidateOnly) { return $plan }
$artifacts=@()
foreach ($selected in @('CurseForge','GitHub')) {
    if ($Channel -notin @('Both',$selected)) { continue }
    $entries=if($selected -eq 'CurseForge') {$runtimeEntries} else {$publicEntries}
    $manifest=@{schemaVersion=1;addon=$Addon;channel=$selected;sourceSHA256=$sourceHash;bundle='existing-multi-toc';slug=$definition.Slug;version=$releaseVersion;supportedTargets=@($definition.SupportedTargets);
        registeredTargets=$targetStates;files=@($entries.Relative);purpose=$(if($selected -eq 'GitHub') {'all-target-source-and-public-documentation'} else {'existing-maintenance-installation-bundle'})}
    $entries+= [pscustomobject]@{Relative='YiboReleaseManifest.json';Source=$null;Content=($manifest | ConvertTo-Json -Depth 10)}
    $final=$plan.$selected
    if (Test-Path -LiteralPath $final) { throw "Package already exists: $final" }
    $artifacts+=[pscustomobject]@{Channel=$selected;Final=$final;Temporary=($final+'.building-'+[guid]::NewGuid().ToString('N'));Entries=$entries}
}
[void](New-Item -ItemType Directory -Path $outputPath -Force)
foreach($artifact in $artifacts) { New-YiboPackage $artifact.Temporary $Addon $artifact.Entries }
if ((Get-YiboSourceDigest $hashEntries) -ne $sourceHash) { throw 'Legacy source changed during packaging; intermediates retained.' }
$profile=[pscustomobject]@{Addon=$Addon;Target='Universal';Config=$config}
$plan.Archived=Publish-YiboPackages $outputPath $profile $artifacts
return $plan
