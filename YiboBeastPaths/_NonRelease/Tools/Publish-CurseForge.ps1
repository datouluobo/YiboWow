[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ApiToken = $env:CURSEFORGE_API_TOKEN,
    [int]$ProjectId = 1575919,
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$FilePath,
    [string]$BaseUrl = "https://wow.curseforge.com",
    [string]$ReleaseType = "release",
    [string]$DisplayName,
    [string]$ChangelogPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\Docs")).Path "CurseForge-Changelog-v1.3.md"),
    [switch]$ManualRelease
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ApiToken)) {
    throw "Missing CurseForge API token. Pass -ApiToken or set CURSEFORGE_API_TOKEN."
}

if ([string]::IsNullOrWhiteSpace($FilePath)) {
    $buildRoot = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path "Builds"
    $FilePath = Get-ChildItem -Path $buildRoot -Filter "YiboBeastPaths-v*-curseforge.zip" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

if (-not $FilePath) {
    throw "Release zip not found. Run Build-CurseForgePackages.ps1 first or pass -FilePath."
}

$filePath = (Resolve-Path $FilePath).Path

if ([string]::IsNullOrWhiteSpace($DisplayName)) {
    $DisplayName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
}

if (-not (Test-Path $ChangelogPath)) {
    throw "Changelog file not found: $ChangelogPath"
}

$changelog = Get-Content -LiteralPath $ChangelogPath -Raw
$metadata = [ordered]@{
    changelog = $changelog
    changelogType = "markdown"
    displayName = $DisplayName
    releaseType = $ReleaseType
}

if ($ManualRelease.IsPresent) {
    $metadata.isMarkedForManualRelease = $true
}

$metadataJson = $metadata | ConvertTo-Json -Depth 8 -Compress

$uri = "{0}/api/projects/{1}/upload-file" -f $BaseUrl.TrimEnd('/'), $ProjectId

$fileStream = [System.IO.File]::OpenRead($filePath)
try {
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.DefaultRequestHeaders.Add("X-Api-Token", $ApiToken)

    $content = [System.Net.Http.MultipartFormDataContent]::new()

    $metadataContent = [System.Net.Http.StringContent]::new($metadataJson, [System.Text.Encoding]::UTF8, "application/json")
    $content.Add($metadataContent, "metadata")

    $fileContent = [System.Net.Http.StreamContent]::new($fileStream)
    $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/zip")
    $content.Add($fileContent, "file", [System.IO.Path]::GetFileName($filePath))

    $response = $client.PostAsync($uri, $content).GetAwaiter().GetResult()
    $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    if (-not $response.IsSuccessStatusCode) {
        throw "CurseForge upload failed: HTTP $([int]$response.StatusCode) $($response.ReasonPhrase)`n$body"
    }

    $body | ConvertFrom-Json
}
finally {
    if ($null -ne $client) {
        $client.Dispose()
    }
    $fileStream.Dispose()
}
