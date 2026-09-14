param([string]$Version = "1.0.0")
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$addon = Join-Path $root 'YiboAutoOpen'; $builds = Join-Path $root 'Builds'
New-Item -ItemType Directory -Force $builds | Out-Null
$temporary = Join-Path ([System.IO.Path]::GetTempPath()) ('YiboAutoOpen-' + [guid]::NewGuid())
New-Item -ItemType Directory -Force (Join-Path $temporary 'YiboAutoOpen') | Out-Null
$runtime = @('YiboAutoOpen.toc','Bootstrap.lua','Defaults.lua','Database.lua','Catalog.lua','ItemResolver.lua','BagAdapter.lua','Safety.lua','Queue.lua','Commands.lua','Settings.lua','CoreIntegration.lua','Media')
foreach ($item in $runtime) { Copy-Item -Recurse -Force (Join-Path $addon $item) (Join-Path $temporary 'YiboAutoOpen') }
Compress-Archive -Path (Join-Path $temporary 'YiboAutoOpen') -DestinationPath (Join-Path $builds "YiboAutoOpen-v$Version-curseforge.zip") -Force
Copy-Item -Recurse -Force (Join-Path $addon 'README.md'),(Join-Path $addon 'CHANGELOG.md'),(Join-Path $addon 'CURSEFORGE_DESCRIPTION.md'),(Join-Path $addon 'TEST_CHECKLIST.md') (Join-Path $temporary 'YiboAutoOpen')
Compress-Archive -Path (Join-Path $temporary 'YiboAutoOpen') -DestinationPath (Join-Path $builds "YiboAutoOpen-v$Version-github.zip") -Force
Remove-Item -LiteralPath $temporary -Recurse -Force
