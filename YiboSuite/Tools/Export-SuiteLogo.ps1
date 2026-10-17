#Requires -Version 7.2
[CmdletBinding()]
param(
    [ValidateSet('Mists', 'TBC', 'ClassicEra', 'Retail')][string]$Target = 'Mists',
    [string]$OutputRoot
)
$ErrorActionPreference = 'Stop'
$suiteRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutputRoot) { $OutputRoot = Join-Path $suiteRoot "Media/$Target" }
$stem = "YiboSuite-$Target-Logo"
$master = Join-Path $OutputRoot "$stem-master.svg"
foreach ($name in @("$stem-master.svg", "$stem-512.png", "$stem-1024.png")) {
    if (Test-Path -LiteralPath (Join-Path $OutputRoot $name)) { throw "Logo output already exists: $name" }
}
[void](New-Item -ItemType Directory -Path $OutputRoot -Force)
& (Join-Path $suiteRoot 'Design/Build-LogoPreview.ps1') -Target $Target -OutputPath $master | Out-Host
# Rasterize the approved SVG composition, retaining its transparent canvas.
@'
import sys
from pathlib import Path
import cairosvg
from PIL import Image

master = Path(sys.argv[1])
stem = sys.argv[2]
for size in (512, 1024):
    output = master.parent / f'{stem}-{size}.png'
    cairosvg.svg2png(url=str(master), write_to=str(output), output_width=size, output_height=size)
    with Image.open(output) as image:
        if image.mode != 'RGBA' or image.size != (size, size):
            raise RuntimeError(f'Unexpected output format: {output}')
        alpha = image.getchannel('A')
        if alpha.getextrema() != (0, 255):
            raise RuntimeError(f'Missing transparent/opaque alpha values: {output}')
        edges = (alpha.crop((0, 0, size, 1)), alpha.crop((0, size-1, size, size)),
                 alpha.crop((0, 0, 1, size)), alpha.crop((size-1, 0, size, size)))
        if any(edge.getextrema()[1] != 0 for edge in edges):
            raise RuntimeError(f'Canvas edge is not fully transparent: {output}')
        # The center of the upper hexagon void must remain transparent.
        probe = (round(170 / 350 * size), round(105 / 350 * size))
        if alpha.getpixel(probe) != 0:
            raise RuntimeError(f'Core negative space is not transparent: {output}')
    print(f'{output}: {size}x{size}, RGBA, transparent edges and interior')
'@ | python - $master $stem
if ($LASTEXITCODE -ne 0) { throw 'Logo raster export failed; retained outputs for inspection.' }
