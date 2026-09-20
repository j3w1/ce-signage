param([Parameter(Mandatory = $true)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$archivo = Join-Path $OutputDirectory ("Casa Elida - Anuncios v$version.zip")
if (-not (Test-Path -LiteralPath $archivo)) { throw "Falta ZIP de release: $archivo" }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $archivo).Path)
try {
    $nombres = @($zip.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    foreach ($requerido in @(
        'CONTROLES PARA ESCRITORIO/ANUNCIOS.cmd',
        'CONTROLES PARA ESCRITORIO/START ANUNCIOS.cmd',
        'CONTROLES PARA ESCRITORIO/STOP ANUNCIOS.cmd',
        'CONTROLES PARA ESCRITORIO/STATUS ANUNCIOS.cmd',
        'sistema/Identidad de Procesos.ps1',
        'sistema/Estado de Anuncios.ps1',
        'sistema/Verificar Descarga.ps1',
        'sistema/Control de Anuncios.ps1',
        'sistema/Casa Elida - Anuncios.ps1'
    )) {
        if (@($nombres | Where-Object { $_.EndsWith($requerido) }).Count -eq 0) {
            throw "Falta en el ZIP: $requerido"
        }
    }
    if (@($nombres | Where-Object { $_ -match '(^|/)(config[.]json|estado[.]json|registro[.]log|cache/|[.]git/)' }).Count -gt 0) {
        throw 'El ZIP contiene estado local o archivos de desarrollo.'
    }
}
finally { $zip.Dispose() }
Write-Host 'OK: release ZIP contiene todos los controles y scripts.' -ForegroundColor Green
