[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$GameRoot = 'C:\Program Files (x86)\World of Warcraft\_forever_'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$addonName = 'SmartFriendlyNameplates'
$sourceRoot = Join-Path $projectRoot $addonName
$addonsRoot = Join-Path $GameRoot 'Interface/AddOns'
if (-not (Test-Path -LiteralPath $addonsRoot -PathType Container)) {
    throw "The game's AddOns directory does not exist: $addonsRoot"
}
$addonsRoot = (Resolve-Path -LiteralPath $addonsRoot).Path
$destination = Join-Path $addonsRoot $addonName
$files = @(Get-ChildItem -LiteralPath $sourceRoot -File)
$files += Get-Item -LiteralPath (Join-Path $projectRoot 'README.md')
$files += Get-Item -LiteralPath (Join-Path $projectRoot 'LICENSE')
if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot "$addonName.toc") -PathType Leaf)) {
    throw 'The addon source manifest is missing.'
}

if ($PSCmdlet.ShouldProcess($destination, 'Install the current addon and verify every copied file')) {
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    foreach ($file in $files) {
        $target = Join-Path $destination $file.Name
        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
        $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        if ($sourceHash -cne $targetHash) { throw "Installed file does not match its source: $target" }
    }
    Write-Output "Installed and verified $($files.Count) files in $destination"
    Write-Output 'Use /reload in game to load the updated addon.'
}
