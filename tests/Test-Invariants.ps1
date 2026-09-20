$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$controllerPath = Join-Path $repoRoot 'package\sistema\Casa Elida - Anuncios.ps1'
$installerPath = Join-Path $repoRoot 'package\sistema\Instalar Casa Elida - Anuncios.ps1'
$controlPath = Join-Path $repoRoot 'package\sistema\Control de Anuncios.ps1'

$controller = Get-Content -LiteralPath $controllerPath -Raw
$installer = Get-Content -LiteralPath $installerPath -Raw
$control = Get-Content -LiteralPath $controlPath -Raw

$failures = New-Object System.Collections.Generic.List[string]

function Require-Text {
    param(
        [string]$Text,
        [string]$Expected,
        [string]$Description
    )

    if ($Text.IndexOf($Expected, [System.StringComparison]::Ordinal) -lt 0) {
        $failures.Add("$Description -> falta: $Expected")
    }
}

Require-Text $controller "'--video-on-top'" 'VLC siempre encima'
Require-Text $controller "'--no-audio'" 'Audio desactivado'
Require-Text $controller "'--random'" 'Orden aleatorio'
Require-Text $controller "'--loop'" 'Loop infinito'
Require-Text $controller "'--avcodec-hw=none'" 'Decodificación por software'
Require-Text $controller '"--qt-fullscreen-screennumber=$indicePantalla"' 'Pantalla objetivo VLC'
Require-Text $controller '"--vout=$salidaVideo"' 'Salida VLC configurable'
Require-Text $installer "IndicePantallaVlc = 1" 'Segunda pantalla por defecto'
Require-Text $installer "DuracionImagenSegundos = 10" 'Duración de imagen'
Require-Text $installer "SiempreEncimaVlc = `$true" 'video-on-top habilitado por defecto'
Require-Text $installer "SalidaVideoVlc = 'direct3d9'" 'Direct3D9 por defecto'
Require-Text $control "'Siempre encima'" 'Estado TUI de video-on-top'
Require-Text $installer "C:\Users\windows\Desktop\anuncios" 'Carpeta de anuncios'

$allText = $controller + "`n" + $installer + "`n" + $control
if ($allText -match 'CasaElida') {
    $failures.Add('Se encontró la marca incorrecta "CasaElida". Debe usarse "Casa Elida".')
}

if ($failures.Count -gt 0) {
    Write-Host 'FALLARON INVARIANTES:' -ForegroundColor Red

    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Yellow
    }

    throw 'Fallaron uno o más invariantes.'
}

Write-Host 'OK: invariantes principales de Casa Elida - Anuncios.' -ForegroundColor Green
