# Extract clean/overlay/Core roots for the Mail/Vault API14 release replay. Never deletes anything.
param([string[]]$Only)
$ErrorActionPreference = 'Stop'
$W = 'D:\Development\YiboWow'
function Extract($zip, $dest) {
    if (Test-Path $dest) { throw "Destination exists (refusing to reuse): $dest" }
    New-Item -ItemType Directory $dest | Out-Null
    Expand-Archive -LiteralPath (Join-Path $W $zip) -DestinationPath $dest -Force
}
function Files($root) {
    if (-not (Test-Path $root)) { return @() }
    @(Get-ChildItem $root -Recurse -File | ForEach-Object { $_.FullName.Substring($root.Length + 1).Replace('\','/') })
}
$plan = @(
    @{ Addon='YiboMail'; Dir='MailRelease-20261122'; Target='Mists'; New='Builds\YiboMail-mists-v1.4.0-api1-curseforge.zip'
       Old=@(@('Overlay-Mists','Builds\Archive\YiboMail\YiboMail-mists-v1.3.5-api1-curseforge.zip'),
             @('Overlay-Mists-from-1.3.4','Builds\Archive\YiboMail\YiboMail-mists-v1.3.4-api1-curseforge.zip')) },
    @{ Addon='YiboMail'; Dir='MailRelease-20261122'; Target='Forever'; New='Builds\YiboMail-forever-v0.3.0-api1-curseforge.zip'
       Old=@(@('Overlay-Forever','Builds\Archive\YiboMail\YiboMail-forever-v0.2.0-api1-curseforge.zip'),
             @('Overlay-Forever-from-0.1.5','Builds\Archive\YiboMail\YiboMail-forever-v0.1.5-api1-curseforge.zip')) },
    @{ Addon='YiboVault'; Dir='VaultRelease-20261122'; Target='Mists'; New='Builds\YiboVault-mists-v1.3.0-api1-curseforge.zip'
       Old=@(,@('Overlay-Mists','Builds\Archive\YiboVault\YiboVault-mists-v1.2.6-api1-curseforge.zip')) },
    @{ Addon='YiboVault'; Dir='VaultRelease-20261122'; Target='Forever'; New='Builds\YiboVault-forever-v0.7.0-api1-curseforge.zip'
       Old=@(@('Overlay-Forever','Builds\Archive\YiboVault\YiboVault-forever-v0.6.5-api1-curseforge.zip'),
             @('Overlay-Forever-from-0.6.4','Builds\Archive\YiboVault\YiboVault-forever-v0.6.4-api1-curseforge.zip')) }
)
$cores = @{ Mists = 'Builds\YiboCore-mists-v1.13.0-api14-curseforge.zip'; Forever = 'Builds\YiboCore-forever-v0.3.0-api14-curseforge.zip' }
$cores13 = @{ Mists = 'Builds\Archive\YiboCore\YiboCore-mists-v1.12.14-api13-curseforge.zip'; Forever = 'Builds\Archive\YiboCore\YiboCore-forever-v0.2.4-api13-curseforge.zip' }
foreach ($p in $plan) {
    $base = Join-Path $W "_NonRelease\$($p.Dir)"
    foreach ($kind in @(@('Core', $cores), @('Core13', $cores13))) {
        $d = Join-Path $base "$($kind[0])-$($p.Target)"
        if (-not (Test-Path $d)) { Extract $kind[1][$p.Target] $d; "extracted $($kind[0])-$($p.Target): $($kind[1][$p.Target]) sha256=$((Get-FileHash (Join-Path $W $kind[1][$p.Target])).Hash)" }
    }
    $clean = Join-Path $base "Clean-$($p.Target)"
    if ($Only -and $Only -notcontains "$($p.Addon)/$($p.Target)") { continue }
    if (-not (Test-Path $clean)) { Extract $p.New $clean }
    $newFiles = Files (Join-Path $clean $p.Addon)
    "== $($p.Addon) $($p.Target) clean: $($newFiles.Count) files"
    foreach ($o in $p.Old) {
        $ov = Join-Path $base $o[0]
        $oldRoot = Join-Path $base ("Baseline-" + $o[0].Substring(8))
        Extract $o[1] $oldRoot
        Extract $o[1] $ov
        Expand-Archive -LiteralPath (Join-Path $W $p.New) -DestinationPath $ov -Force
        $oldFiles = Files (Join-Path $oldRoot $p.Addon)
        $overlayFiles = Files (Join-Path $ov $p.Addon)
        $residual = @($oldFiles | Where-Object { $newFiles -notcontains $_ })
        $residualTocs = @($overlayFiles | Where-Object { $_ -match '\.toc$' })
        "-- $($o[0]) from $(Split-Path $o[1] -Leaf) sha256=$((Get-FileHash (Join-Path $W $o[1])).Hash)"
        "   old=$($oldFiles.Count) overlay=$($overlayFiles.Count) residual=$($residual.Count) tocsAfterOverlay=$($residualTocs -join ',')"
        foreach ($r in $residual) { "   residual: $r" }
        # Bytes of new files in overlay must equal the new package
        $mismatch = @($newFiles | Where-Object { (Get-FileHash (Join-Path $ov "$($p.Addon)/$_")).Hash -ne (Get-FileHash (Join-Path $clean "$($p.Addon)/$_")).Hash })
        "   newFilesDifferingInOverlay=$($mismatch.Count)"
    }
}
