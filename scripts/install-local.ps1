[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$GameRoot
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $PSBoundParameters.ContainsKey('GameRoot')) {
    $GameRoot = $env:GAME_ROOT
    $envPath = Join-Path $projectRoot '.env'
    if ([string]::IsNullOrWhiteSpace($GameRoot) -and (Test-Path -LiteralPath $envPath -PathType Leaf)) {
        $lineNumber = 0
        foreach ($line in Get-Content -LiteralPath $envPath) {
            $lineNumber++
            $line = $line.Trim()
            if (-not $line -or $line.StartsWith('#')) { continue }
            if ($line -notmatch '^(?<Key>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?<Value>.*)$') {
                throw "Invalid .env assignment on line $lineNumber. Use KEY=value."
            }
            $key = $Matches['Key']
            $value = $Matches['Value'].Trim()
            if ($value.StartsWith('"') -or $value.StartsWith("'")) {
                if ($value.Length -lt 2 -or $value[$value.Length - 1] -cne $value[0]) {
                    throw "Unclosed .env quote on line $lineNumber."
                }
                $value = $value.Substring(1, $value.Length - 2)
            }
            if ($key -ceq 'GAME_ROOT') { $GameRoot = $value }
        }
    }
}
if ([string]::IsNullOrWhiteSpace($GameRoot)) {
    throw 'Run ./scripts/setup.ps1, then set GAME_ROOT in the repository-root .env file. Alternatively, set the GAME_ROOT environment variable or pass -GameRoot.'
}
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
