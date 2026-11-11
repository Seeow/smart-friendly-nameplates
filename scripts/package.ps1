[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$addonName = 'FriendlyGroupCombat'
$addonRoot = Join-Path $projectRoot $addonName
$tocPath = Join-Path $addonRoot "$addonName.toc"
$versionLine = Get-Content -LiteralPath $tocPath | Where-Object { $_ -match '^## Version: ' }
if ($versionLine -notmatch '^## Version: ([0-9]+\.[0-9]+\.[0-9]+)$') {
    throw 'The addon manifest must contain a semantic version.'
}
$version = $Matches[1]
$outputRoot = Join-Path $projectRoot 'dist'
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$archivePath = Join-Path $outputRoot "SmartFriendlyNameplates-$version.zip"

$files = @(
    @{ Source = Join-Path $addonRoot "$addonName.toc"; Name = "$addonName/$addonName.toc" },
    @{ Source = Join-Path $addonRoot "$addonName.lua"; Name = "$addonName/$addonName.lua" },
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
