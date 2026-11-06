#Requires -Version 7.2
$ErrorActionPreference = 'Stop'
$results = @()
foreach ($target in @('Retail','Mists')) {
    $state = Get-Content -LiteralPath (Join-Path $PSScriptRoot "Deployment-$target.json") -Raw | ConvertFrom-Json
    if ($state.phase -ne 'restored') { throw "$target original environment has not been restored." }
    $link = Get-Item -LiteralPath $state.live
    if ($link.LinkType -ne 'Junction' -or @($link.Target)[0] -ne $state.originalTarget) { throw "$target original Junction differs." }
    $currentSaveMatches = $true
    foreach ($save in $state.originalSaves) {
        if ((Get-FileHash -LiteralPath $save.backup).Hash -ine $save.sha256) { throw "$target original backup differs." }
        if ((Get-FileHash -LiteralPath $save.original).Hash -ine $save.sha256) { $currentSaveMatches = $false }
    }
    if ($target -eq 'Mists' -and -not $currentSaveMatches) { throw 'Mists newly restored save differs.' }
    if ($target -eq 'Retail' -and -not $currentSaveMatches) {
        $prior = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Handoff-Retail-Mists.json') -Raw | ConvertFrom-Json
        if ($prior.retail.phase -ne 'restored' -or $prior.retail.saveMismatchCount -ne 0) { throw 'Prior Retail restoration was not verified.' }
    }
    if (Test-Path -LiteralPath $state.probe) { throw "$target acceptance probe still participates in AddOns loading." }
    foreach ($directory in $state.history) {
        foreach ($entry in $directory.hashes.PSObject.Properties) {
            if ((Get-FileHash -LiteralPath (Join-Path $directory.preservedDirectory $entry.Name)).Hash -ine $entry.Value) {
                throw "$target preserved test code differs: $($entry.Name)"
            }
        }
    }
    $results += [ordered]@{target=$target;phase='restored';originalJunctionMatches=$true;
        originalSaveFiles=@($state.originalSaves).Count;originalBackupsMatch=$true;activeSavesMatchOriginalAtThisAudit=$currentSaveMatches;
        laterSaveChangesPreserved=($target -eq 'Retail' -and -not $currentSaveMatches);
        probeAbsentFromAddOns=$true;preservedTestDirectories=@($state.history).Count;preservedCodeHashesMatch=$true}
}
$foreverPath = 'C:/Program Files (x86)/World of Warcraft/_cn_beta_/Interface/AddOns/YiboCore'
$forever = if (Test-Path -LiteralPath $foreverPath) { Get-Item -LiteralPath $foreverPath } else { $null }
$record = [ordered]@{date='2026-10-27';restoredTargets=$results;forever=[ordered]@{
    r4DeploymentExists=(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Deployment-Forever.json'));
    previousTestClientCorePathPresent=($null -ne $forever);coreLinkType=$(if ($forever) {$forever.LinkType} else {$null});
    coreTarget=$(if ($forever) {@($forever.Target)[0]} else {$null});
    clientAcceptance='waiting for server availability; user reports test server closed and production server not open'};
    publication='none'}
$record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'Restoration-Verification.json') -Encoding utf8
Write-Output 'Retail: prior verified restoration retained; current later save changes preserved; original backups and 2 test directories verified.'
Write-Output 'Mists: original Junction and 4 saves restored; 3 test directories preserved and verified.'
Write-Output 'Forever: no R4 deployment; previous test-client Core path currently absent; future client path/build verification required.'
