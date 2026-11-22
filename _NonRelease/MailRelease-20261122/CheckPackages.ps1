# Inspect built CurseForge zips: hashes, manifest, content rules. (Python is unavailable on this host.)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$W = 'D:\Development\YiboWow'
$pkgs = @(
    @('YiboMail','Mists','Builds\YiboMail-mists-v1.4.0-api1-curseforge.zip'),
    @('YiboMail','Forever','Builds\YiboMail-forever-v0.3.0-api1-curseforge.zip'),
    @('YiboVault','Mists','Builds\YiboVault-mists-v1.3.0-api1-curseforge.zip'),
    @('YiboVault','Forever','Builds\YiboVault-forever-v0.7.0-api1-curseforge.zip'))
$markers = @('_NonRelease','/Tests/','/WTF/','Spec.lua','.md','TocHint','/Docs/')
$allOk = $true
function ReadEntry($zip, $name) {
    $e = $zip.GetEntry($name); $s = New-Object IO.StreamReader($e.Open(), [Text.Encoding]::UTF8); $t = $s.ReadToEnd(); $s.Close(); return $t
}
foreach ($p in $pkgs) {
    $addon, $target, $rel = $p
    $path = Join-Path $W $rel
    $zip = [IO.Compression.ZipFile]::OpenRead($path)
    try {
        $names = @($zip.Entries | Where-Object { -not $_.FullName.EndsWith('/') } | ForEach-Object { $_.FullName })
        $man = (ReadEntry $zip "$addon/YiboReleaseManifest.json") | ConvertFrom-Json
        $toc = ReadEntry $zip "$addon/$addon.toc"
        $tocLines = $toc -split "`r?`n"
        $refs = @($tocLines | Where-Object { $_.Trim() -and -not $_.StartsWith('#') } | ForEach-Object { $_.Trim().Replace('\','/') })
        $tocs = @($names | Where-Object { $_ -match '\.toc$' })
        $tops = @($names | ForEach-Object { $_.Split('/')[0] } | Sort-Object -Unique)
        $other = if ($target -eq 'Mists') { 'Forever' } else { 'Mists' }
        $missing = @($refs | Where-Object { $names -notcontains "$addon/$_" })
        $others = @($names | Where-Object { $_.StartsWith("$addon/$other/") })
        $bad = @($names | Where-Object { $n = $_; @($markers | Where-Object { $n.Contains($_) }).Count -gt 0 })
        $expected = @($man.files | ForEach-Object { "$addon/$_" }) + "$addon/YiboReleaseManifest.json"
        $diff = @(Compare-Object ($names | Sort-Object) ($expected | Sort-Object) | ForEach-Object { $_.InputObject })
        $unref = @($names | Where-Object { $_ -match '\.lua$' -and $refs -notcontains $_.Substring($addon.Length + 1) })
        $hash = (Get-FileHash $path -Algorithm SHA256).Hash
        "== $addon $target : $(Split-Path $path -Leaf)"
        "   size=$((Get-Item $path).Length) sha256=$hash"
        "   manifest target=$($man.target) version=$($man.version) sourceSHA256=$($man.sourceSHA256)"
        foreach ($t in $man.registeredTargets) { "   registered: target=$($t.target) version=$($t.version) publicAPI=$($t.publicAPI) minimumCoreAPI=$($t.minimumCoreAPI) interface=$($t.interfaces -join ',')$($t.interface) state=$($t.validationState)" }
        "   files=$($names.Count) tops=$($tops -join ',') tocs=$($tocs -join ',') tocRefs=$($refs.Count) missingRefs=$($missing -join ',')"
        "   otherTargetFiles=$($others.Count) forbidden=$($bad -join ',') manifestMismatch=$($diff -join ',') unreferencedLua=$($unref -join ',')"
        "   " + (($tocLines | Where-Object { $_ -match '^## (Version|Interface|SavedVariables|RequiredDeps|X-Yibo-Target)' }) -join ' | ')
        $good = ($tops.Count -eq 1 -and $tops[0] -eq $addon -and $tocs.Count -eq 1 -and $tocs[0] -eq "$addon/$addon.toc" -and $missing.Count -eq 0 -and $others.Count -eq 0 -and $bad.Count -eq 0 -and $diff.Count -eq 0 -and $unref.Count -eq 0 -and $man.target -eq $target)
        if ($good) { '   CONTENT_OK' } else { '   CONTENT_FAIL'; $allOk = $false }
    } finally { $zip.Dispose() }
}
if ($allOk) { 'ALL_PACKAGES_OK' } else { 'PACKAGE_CHECK_FAILED' }
