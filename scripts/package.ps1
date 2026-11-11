[CmdletBinding()]
param(
    [string]$Tag
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$addonName = 'FriendlyGroupCombat'
$addonRoot = Join-Path $projectRoot $addonName
$tocPath = Join-Path $addonRoot "$addonName.toc"
$versionLine = Get-Content -LiteralPath $tocPath | Where-Object { $_ -match '^## Version: ' }
if ($versionLine -notmatch '^## Version: ([0-9]+\.[0-9]+\.[0-9]+(?:-(?:alpha|beta)\.[0-9]+)?)$') {
    throw 'The addon manifest must contain a version such as 0.1.10 or 0.1.11-beta.1.'
}
$version = $Matches[1]
$luaSource = Get-Content -LiteralPath (Join-Path $addonRoot "$addonName.lua") -Raw
if ($luaSource -notmatch '(?m)^local VERSION = "([^"]+)"\s*$' -or $Matches[1] -cne $version) {
    throw 'The Lua version and addon manifest version must match.'
}
if ($Tag -and $Tag -cne "v$version") {
    throw "Release tag '$Tag' must match addon version 'v$version'."
}
$outputRoot = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$archivePath = Join-Path $outputRoot "SmartFriendlyNameplates-$version.zip"

$files = @(
    @{ Source = Join-Path $addonRoot "$addonName.toc"; Name = "$addonName/$addonName.toc" },
    @{ Source = Join-Path $addonRoot "$addonName.lua"; Name = "$addonName/$addonName.lua" },
    @{ Source = Join-Path $addonRoot 'Options.lua'; Name = "$addonName/Options.lua" },
    @{ Source = Join-Path $projectRoot 'README.md'; Name = "$addonName/README.md" },
    @{ Source = Join-Path $projectRoot 'LICENSE'; Name = "$addonName/LICENSE" }
)
foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath $file.Source -PathType Leaf)) {
        throw "Missing package input: $($file.Source)"
    }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path -LiteralPath $archivePath) { Remove-Item -LiteralPath $archivePath -Force }
$archive = [System.IO.Compression.ZipFile]::Open($archivePath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in $files) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive, $file.Source, $file.Name, [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
} finally {
    $archive.Dispose()
}
Write-Output $archivePath
