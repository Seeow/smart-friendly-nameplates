[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $projectRoot '.env'
$examplePath = Join-Path $projectRoot '.env.example'

if (Test-Path -LiteralPath $envPath) {
    if (-not (Test-Path -LiteralPath $envPath -PathType Leaf)) {
        throw 'The repository-root .env path exists but is not a file.'
    }
    Write-Output '.env already exists; the existing configuration was preserved.'
    return
}
if (-not (Test-Path -LiteralPath $examplePath -PathType Leaf)) {
    throw 'The repository-root .env.example file is missing.'
}

if ($PSCmdlet.ShouldProcess($envPath, 'Create .env from .env.example')) {
    Copy-Item -LiteralPath $examplePath -Destination $envPath
    Write-Output 'Created .env from .env.example.'
    Write-Output 'Set GAME_ROOT in .env to your game client directory, then run ./scripts/install-local.ps1.'
}
