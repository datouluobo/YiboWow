#Requires -Version 7.2
[CmdletBinding()]
param(
    [ValidateSet('Mists', 'TBC', 'ClassicEra', 'Retail')][string]$Target = 'Mists',
    [string]$Label,
    [string]$OutputPath,
    [string]$FontFamily = 'Arial',
    [single]$FontSize = 32
)
$ErrorActionPreference = 'Stop'
$themes = Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'Client-Themes.psd1')
$theme = $themes[$Target]
if (-not $Label) { $Label = $theme.Label }
if ($Label -notmatch '^[A-Za-z0-9]+$') { throw 'Label must contain only ASCII letters and digits.' }
if (-not $OutputPath) { $OutputPath = Join-Path $PSScriptRoot "$Target-主题预览.svg" }
Add-Type -AssemblyName System.Drawing
$workspace = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$source = Join-Path $workspace 'YiboCore/Media/YiboCoreIcon-512.png'
$bitmap = [Drawing.Bitmap]::new($source)
try {
    # Use a stable alpha threshold to measure the visible frame; retain source pixels unchanged.
    $right = -1; $bottom = -1
    for ($y = 0; $y -lt $bitmap.Height; $y++) {
        for ($x = 0; $x -lt $bitmap.Width; $x++) {
            if ($bitmap.GetPixel($x, $y).A -ge 128) {
                if ($x -gt $right) { $right = $x }
                if ($y -gt $bottom) { $bottom = $y }
            }
        }
    }
    if ($right -lt 0 -or $bottom -lt 0) { throw 'Core mark has no visible alpha bounds.' }
    $anchorX = 10 + ($right + 1) * 330.0 / $bitmap.Width
    $anchorY = 10 + ($bottom + 1) * 330.0 / $bitmap.Height
} finally { $bitmap.Dispose() }
$family = [Drawing.FontFamily]::new($FontFamily)
$path = [Drawing.Drawing2D.GraphicsPath]::new()
$format = [Drawing.StringFormat]::GenericTypographic
try {
    $path.AddString($Label, $family, [int][Drawing.FontStyle]::Bold, $FontSize, [Drawing.PointF]::new(0, 0), $format)
    $bounds = $path.GetBounds()
    $stroke = 2.4
    $offsetX = $anchorX - $bounds.Right - $stroke / 2
    $offsetY = $anchorY - $bounds.Bottom - $stroke / 2
    $points = $path.PathPoints; $types = $path.PathTypes
    $commands = [Collections.Generic.List[string]]::new()
    function Number([double]$value) { $value.ToString('0.#####', [Globalization.CultureInfo]::InvariantCulture) }
    for ($i = 0; $i -lt $points.Count; $i++) {
        $type = $types[$i] -band 7
        if ($type -eq 0) { $commands.Add("M$(Number $points[$i].X),$(Number $points[$i].Y)") }
        elseif ($type -eq 1) { $commands.Add("L$(Number $points[$i].X),$(Number $points[$i].Y)") }
        elseif ($type -eq 3) {
            $commands.Add("C$(Number $points[$i].X),$(Number $points[$i].Y) $(Number $points[$i+1].X),$(Number $points[$i+1].Y) $(Number $points[$i+2].X),$(Number $points[$i+2].Y)")
            $i += 2
        } else { throw 'Unexpected font outline command.' }
        if ($types[$i] -band 128) { $commands.Add('Z') }
    }
    $data = [Convert]::ToBase64String([IO.File]::ReadAllBytes($source))
    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="350" height="350" viewBox="0 0 350 350">
<title>YiboSuite $Label</title>
<image x="10" y="10" width="330" height="330" xlink:href="data:image/png;base64,$data"/>
<g aria-label="$Label" transform="translate($(Number $offsetX),$(Number $offsetY))">
<path d="$($commands -join ' ')" fill="none" stroke="#102322" stroke-width="$stroke" stroke-linejoin="round"/>
<path d="$($commands -join ' ')" fill="$($theme.TextColor)" fill-rule="evenodd"/>
</g>
</svg>
"@
    [IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath), $svg, [Text.UTF8Encoding]::new($false))
    [pscustomobject]@{ Target = $Target; Label = $Label; TextColor = $theme.TextColor; AnchorX = $anchorX; AnchorY = $anchorY; Output = [IO.Path]::GetFullPath($OutputPath) }
} finally { $format.Dispose(); $path.Dispose(); $family.Dispose() }
