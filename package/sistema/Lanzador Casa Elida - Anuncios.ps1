param(
    [switch]$SinEsperaInicial
)

$ErrorActionPreference = 'Stop'

$InstallDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ControllerPath = Join-Path $InstallDir 'Casa Elida - Anuncios.ps1'
$StartupLog = Join-Path $InstallDir 'arranque.log'
$StartupError = Join-Path $InstallDir 'arranque-error.log'

function Registrar-Arranque {
    param([string]$Mensaje)

    try {
        $fecha = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -LiteralPath $StartupLog -Value "[$fecha] $Mensaje" -Encoding UTF8
    }
    catch {}
}

try {
    Remove-Item -LiteralPath $StartupError -Force -ErrorAction SilentlyContinue

    Registrar-Arranque "Lanzador iniciado. Usuario=$env:USERNAME SinEsperaInicial=$SinEsperaInicial"

    if (-not (Test-Path -LiteralPath $ControllerPath)) {
        throw "No existe el controlador: $ControllerPath"
    }

    if ($SinEsperaInicial) {
        & $ControllerPath -SinEsperaInicial
    }
    else {
        & $ControllerPath
    }

    Registrar-Arranque 'El controlador terminó sin lanzar una excepción.'
}
catch {
    $mensaje = $_ | Out-String

    try {
        $fecha = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Set-Content -LiteralPath $StartupError -Value "[$fecha] ERROR DE ARRANQUE`r`n$mensaje" -Encoding UTF8
    }
    catch {}

    Registrar-Arranque "ERROR DE ARRANQUE: $($_.Exception.Message)"
    exit 1
}
