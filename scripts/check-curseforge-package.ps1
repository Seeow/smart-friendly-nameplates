[CmdletBinding()]
param(
    [string]$PackageRoot = '.release'
)

$ErrorActionPreference = 'Stop'
$outputRoot = (Resolve-Path -LiteralPath $PackageRoot).Path
$addonName = 'FriendlyGroupCombat'
$addonRoot = Join-Path $outputRoot $addonName
$directories = @(Get-ChildItem -LiteralPath $outputRoot -Directory -Force)
if ($directories.Count -ne 1 -or $directories[0].Name -cne $addonName) {
    throw "The package must have exactly one addon folder: $addonName."
}
if (@(Get-ChildItem -LiteralPath $addonRoot -Directory -Force).Count -ne 0) {
    throw 'The addon folder must be flat, without a nested wrapper or development folders.'
}
$expectedFiles = @("$addonName.toc", "$addonName.lua", 'Options.lua', 'README.md', 'LICENSE')
foreach ($name in $expectedFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $addonRoot $name) -PathType Leaf)) {
        throw "Missing package file: $addonName/$name"
    }
}
foreach ($file in Get-ChildItem -LiteralPath $addonRoot -File -Force) {
    if ($file.Name -cnotin $expectedFiles) {
        throw "Unexpected package file: $($file.Name)"
    }
}
$toc = Get-Content -LiteralPath (Join-Path $addonRoot "$addonName.toc") -Raw
if ($toc -notmatch '(?m)^## Interface: 16001\s*$') {
    throw 'The package must target WoW Forever, interface 16001.'
}
if ($toc -notmatch '(?m)^## X-Curse-Project-ID: 1798982\s*$') {
    throw 'The package must point to CurseForge project 1798982.'
}
Write-Output 'CurseForge package layout verified.'
