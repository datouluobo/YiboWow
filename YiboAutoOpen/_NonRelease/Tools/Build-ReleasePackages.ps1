param([string]$Version = "1.2.1")
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$addon = Join-Path $root 'YiboAutoOpen'; $builds = Join-Path $root 'Builds'
New-Item -ItemType Directory -Force $builds | Out-Null
$temporary = Join-Path ([System.IO.Path]::GetTempPath()) ('YiboAutoOpen-' + [guid]::NewGuid())
try {
    $packageRoot = Join-Path $temporary 'YiboAutoOpen'
    $runtime = @('YiboAutoOpen.toc','Bootstrap.lua','Defaults.lua','Database.lua','Catalog.lua','ItemResolver.lua','BagAdapter.lua','Safety.lua','Queue.lua','BindConfirmAssist.lua','Commands.lua','Settings.lua','CoreIntegration.lua')
    New-Item -ItemType Directory -Force $packageRoot | Out-Null
    foreach ($item in $runtime) { Copy-Item -Recurse -Force (Join-Path $addon $item) $packageRoot }
    $releaseMedia = Join-Path $packageRoot 'Media'
    New-Item -ItemType Directory -Force $releaseMedia | Out-Null
    Copy-Item -Force (Join-Path $addon 'Media\YiboAutoOpenIcon-v2.tga') $releaseMedia

    $stagedCurseForge = Join-Path $temporary "YiboAutoOpen-v$Version-curseforge.zip"
    $stagedGitHub = Join-Path $temporary "YiboAutoOpen-v$Version-github.zip"
    Compress-Archive -Path $packageRoot -DestinationPath $stagedCurseForge
    Copy-Item -Recurse -Force (Join-Path $addon 'README.md'),(Join-Path $addon 'CHANGELOG.md'),(Join-Path $addon 'CURSEFORGE_DESCRIPTION.md'),(Join-Path $addon 'TEST_CHECKLIST.md') $packageRoot
    Compress-Archive -Path $packageRoot -DestinationPath $stagedGitHub

    $archive = Join-Path $builds 'Archive'
    New-Item -ItemType Directory -Force $archive | Out-Null
    foreach ($oldPackage in Get-ChildItem -LiteralPath $builds -File -Filter 'YiboAutoOpen-v*.zip') {
        $archiveName = $oldPackage.Name
        $archiveTarget = Join-Path $archive $archiveName
        if (Test-Path -LiteralPath $archiveTarget) {
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
            $archiveName = $oldPackage.BaseName + '-archived-' + $stamp + $oldPackage.Extension
            $archiveTarget = Join-Path $archive $archiveName
        }
        Move-Item -LiteralPath $oldPackage.FullName -Destination $archiveTarget
    }
    Move-Item -LiteralPath $stagedCurseForge -Destination (Join-Path $builds "YiboAutoOpen-v$Version-curseforge.zip")
    Move-Item -LiteralPath $stagedGitHub -Destination (Join-Path $builds "YiboAutoOpen-v$Version-github.zip")
}
finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Recurse -Force }
}
