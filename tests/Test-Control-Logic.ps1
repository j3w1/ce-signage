$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'package\sistema\Estado de Anuncios.ps1')
. (Join-Path $root 'package\sistema\Identidad de Procesos.ps1')
. (Join-Path $root 'package\sistema\Verificar Descarga.ps1')

function Datos-Prueba {
    return [pscustomobject]@{
        Instalado = $true; ConfigValida = $true; SegundaPantalla = $true
        Controlador = $true; Vlc = $true; EstadoValido = $true
        EstadoPreparacion = 'LISTO'; EstadoActualizado = (Get-Date)
        ArchivosPreparados = 2; ArchivosConError = 0; Ffmpeg = $true
    }
}

function Exigir-Estado {
    param([object]$Datos, [string]$Esperado)
    $actual = (Resolver-EstadoAnuncios -Datos $Datos).Codigo
    if ($actual -ne $Esperado) { throw "Estado esperado $Esperado, recibido $actual" }
}

$d = Datos-Prueba; Exigir-Estado $d 'FUNCIONANDO'
$d = Datos-Prueba; $d.Instalado = $false; Exigir-Estado $d 'NO_INSTALADO'
$d = Datos-Prueba; $d.ConfigValida = $false; Exigir-Estado $d 'CONFIG_ERROR'
$d = Datos-Prueba; $d.SegundaPantalla = $false; Exigir-Estado $d 'SIN_PANTALLA'
$d = Datos-Prueba; $d.Controlador = $false; Exigir-Estado $d 'DETENIDO'
$d = Datos-Prueba; $d.EstadoPreparacion = 'ERROR_FATAL'; Exigir-Estado $d 'ERROR'
$d = Datos-Prueba; $d.EstadoValido = $false; Exigir-Estado $d 'SIN_ESTADO'
$d = Datos-Prueba; $d.EstadoPreparacion = 'PREPARANDO'; Exigir-Estado $d 'PREPARANDO'
$d = Datos-Prueba; $d.EstadoActualizado = (Get-Date).AddMinutes(-2); Exigir-Estado $d 'ESTADO_ANTIGUO'
$d = Datos-Prueba; $d.Vlc = $false; Exigir-Estado $d 'ESPERANDO_VLC'
$d = Datos-Prueba; $d.ArchivosPreparados = 0; Exigir-Estado $d 'SIN_ANUNCIOS'
$d = Datos-Prueba; $d.ArchivosConError = 1; Exigir-Estado $d 'PARCIAL'
$d = Datos-Prueba; $d.Ffmpeg = $false; Exigir-Estado $d 'SIN_FFMPEG'

$temporal = Join-Path $env:TEMP ('ce-signage-test-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporal | Out-Null
$pidFile = Join-Path $temporal 'controlador.pid'
$descarga = Join-Path $temporal 'descarga.zip'
$hash = Join-Path $temporal 'descarga.sha256'
try {
    [System.IO.File]::WriteAllText($descarga, 'fixture', [System.Text.Encoding]::ASCII)
    $correcto = (Get-FileHash -LiteralPath $descarga -Algorithm SHA256).Hash
    [System.IO.File]::WriteAllText($hash, $correcto, [System.Text.Encoding]::ASCII)
    Confirmar-Sha256 -Archivo $descarga -ArchivoSha256 $hash
    [System.IO.File]::WriteAllText($hash, ('0' * 64), [System.Text.Encoding]::ASCII)
    $rechazado = $false
    try { Confirmar-Sha256 -Archivo $descarga -ArchivoSha256 $hash } catch { $rechazado = $true }
    if (-not $rechazado) { throw 'Se aceptó un checksum incorrecto.' }

    $proceso = Get-Process -Id $PID -ErrorAction Stop
    Guardar-PidControlado -ArchivoPid $pidFile -Proceso $proceso
    if (-not (Obtener-ProcesoControlado -ArchivoPid $pidFile -NombreEsperado 'powershell')) {
        throw 'PID y hora de inicio válidos no fueron aceptados.'
    }
    if (Obtener-ProcesoControlado -ArchivoPid $pidFile -NombreEsperado 'vlc') {
        throw 'Se aceptó un proceso con nombre incorrecto.'
    }
    [System.IO.File]::WriteAllText($pidFile, ('{0}|{1}' -f $PID, 1), [System.Text.Encoding]::ASCII)
    if (Obtener-ProcesoControlado -ArchivoPid $pidFile -NombreEsperado 'powershell') {
        throw 'Se aceptó un PID reutilizado.'
    }
    [System.IO.File]::WriteAllText($pidFile, [string]$PID, [System.Text.Encoding]::ASCII)
    if (-not (Obtener-ProcesoControlado -ArchivoPid $pidFile -NombreEsperado 'powershell')) {
        throw 'Un PID legado válido fue rechazado.'
    }
    [System.IO.File]::SetLastWriteTimeUtc($pidFile, $proceso.StartTime.ToUniversalTime().AddSeconds(-10))
    if (Obtener-ProcesoControlado -ArchivoPid $pidFile -NombreEsperado 'powershell') {
        throw 'Se aceptó un PID legado anterior al proceso.'
    }
}
finally { Remove-Item -LiteralPath $temporal -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host 'OK: estados y procedencia de procesos.' -ForegroundColor Green
