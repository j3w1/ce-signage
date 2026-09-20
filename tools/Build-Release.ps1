param(
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $repoRoot 'VERSION') -Raw).Trim()

if (-not $version) {
    throw 'VERSION está vacío.'
}

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $repoRoot 'release'
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$packageDir = Join-Path $repoRoot 'package'
if (-not (Test-Path -LiteralPath $packageDir)) {
    throw "No existe package/: $packageDir"
}

$name = "Casa Elida - Anuncios v$version"
$tempRoot = Join-Path $env:TEMP ("ce-signage-" + [Guid]::NewGuid().ToString('N'))
$staging = Join-Path $tempRoot $name
$zipPath = Join-Path $OutputDirectory "$name.zip"

try {
    New-Item -ItemType Directory -Path $staging -Force | Out-Null

    Copy-Item -Path (Join-Path $packageDir '*') -Destination $staging -Recurse -Force

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Compress-Archive -Path $staging -DestinationPath $zipPath -CompressionLevel Optimal

    Write-Host ''
    Write-Host "Release creado: $zipPath" -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
