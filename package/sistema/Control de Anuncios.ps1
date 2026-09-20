param(
    [ValidateSet('Menu', 'Iniciar', 'Detener', 'Estado')]
    [string]$Accion = 'Menu'
)

$ErrorActionPreference = 'Stop'

$InstallDir = 'C:\ProgramData\Casa Elida\Anuncios'
$ControllerPath = Join-Path $InstallDir 'Casa Elida - Anuncios.ps1'
$LauncherPath = Join-Path $InstallDir 'Lanzador Casa Elida - Anuncios.ps1'
$ConfigPath = Join-Path $InstallDir 'config.json'
$StatePath = Join-Path $InstallDir 'estado.json'
$ControllerPidPath = Join-Path $InstallDir 'controlador.pid'
$VlcPidPath = Join-Path $InstallDir 'vlc.pid'
$LogPath = Join-Path $InstallDir 'registro.log'
$StartupLogPath = Join-Path $InstallDir 'arranque.log'
$StartupErrorPath = Join-Path $InstallDir 'arranque-error.log'
. (Join-Path $PSScriptRoot 'Identidad de Procesos.ps1')
. (Join-Path $PSScriptRoot 'Estado de Anuncios.ps1')
$script:EnMenu = $false

try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $Host.UI.RawUI.WindowTitle = 'Casa Elida - Anuncios'
}
catch {}

function Mostrar-Cabecera {
    param([string]$Subtitulo)

    Clear-Host
    Write-Host ''
    Write-Host '  Casa Elida | Anuncios' -ForegroundColor Cyan
    Write-Host ('  {0}' -f $Subtitulo) -ForegroundColor White
    Write-Host '  ----------------------------------------' -ForegroundColor DarkGray
}

function Esperar-Cierre {
    Write-Host ''
    if ($script:EnMenu) {
        [void](Read-Host '  Presione ENTER para volver al menú')
    }
    else {
        [void](Read-Host '  Presione ENTER para cerrar')
    }
}

function Obtener-ProcesoDesdePid {
    param([string]$ArchivoPid, [string]$NombreEsperado)
    return (Obtener-ProcesoControlado -ArchivoPid $ArchivoPid -NombreEsperado $NombreEsperado)
}

function Obtener-Datos {
    $r = [ordered]@{
        Instalado = ((Test-Path -LiteralPath $ControllerPath) -and (Test-Path -LiteralPath $LauncherPath))
        ConfigValida = $false
        ErrorConfig = ''
        EstadoValido = $false
        EstadoActualizado = $null
        Pantallas = 0
        SegundaPantalla = $false
        ArchivosOriginales = 0
        ArchivosPreparados = 0
        ArchivosConError = 0
        ResolucionObjetivo = ''
        EstadoPreparacion = ''
        Detalle = ''
        Controlador = $null
        Vlc = $null
        Tarea = 'No encontrada'
        Carpeta = 'C:\Users\windows\Desktop\anuncios'
        SalidaVlc = ''
        SiempreEncima = $false
        Ffmpeg = $false
    }

    if (-not $r.Instalado) { return [pscustomobject]$r }

    try {
        $config = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if (-not $config.CarpetaMultimedia -or -not $config.RutaFfmpeg -or -not $config.RutaVlc) {
            throw 'Faltan rutas obligatorias.'
        }
        $r.Carpeta = [string]$config.CarpetaMultimedia
        $r.SalidaVlc = [string]$config.SalidaVideoVlc
        if ($null -ne $config.SiempreEncimaVlc) { $r.SiempreEncima = [bool]$config.SiempreEncimaVlc }
        $r.Ffmpeg = Test-Path -LiteralPath ([string]$config.RutaFfmpeg)
        $r.ConfigValida = $true
    }
    catch { $r.ErrorConfig = $_.Exception.Message }

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $pantallas = @([System.Windows.Forms.Screen]::AllScreens)
        $r.Pantallas = $pantallas.Count
        $r.SegundaPantalla = ($pantallas.Count -ge 2)
    }
    catch { $r.Detalle = 'No se pudieron consultar las pantallas.' }

    try {
        $estado = Get-Content -LiteralPath $StatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $r.ArchivosOriginales = [int]$estado.ArchivosOriginales
        $r.ArchivosPreparados = [int]$estado.ArchivosPreparados
        $r.ArchivosConError = [int]$estado.ArchivosConError
        $r.ResolucionObjetivo = [string]$estado.ResolucionObjetivo
        $r.EstadoPreparacion = [string]$estado.EstadoGeneral
        $r.Detalle = [string]$estado.Detalle
        if (-not $r.EstadoPreparacion -or -not $estado.Actualizado) { throw 'Estado incompleto.' }
        $r.EstadoActualizado = [datetime]::Parse([string]$estado.Actualizado)
        $r.EstadoValido = $true
    }
    catch {
        if (-not $r.Detalle) { $r.Detalle = 'Estado no disponible; espere o revise registro.log.' }
        if (Test-Path -LiteralPath $r.Carpeta) {
            $r.ArchivosOriginales = @(Get-ChildItem -LiteralPath $r.Carpeta -File -Recurse -ErrorAction SilentlyContinue).Count
        }
    }

    $r.Controlador = Obtener-ProcesoDesdePid -ArchivoPid $ControllerPidPath -NombreEsperado 'powershell'
    $r.Vlc = Obtener-ProcesoDesdePid -ArchivoPid $VlcPidPath -NombreEsperado 'vlc'

    try {
        $tarea = Get-ScheduledTask -TaskName 'Casa Elida - Anuncios' -ErrorAction Stop
        $r.Tarea = [string]$tarea.State
    }
    catch {}

    return [pscustomobject]$r
}

function Fila {
    param([string]$Etiqueta, [string]$Valor, [ConsoleColor]$Color = [ConsoleColor]::White)
    Write-Host ('  {0,-24}' -f ($Etiqueta + ':')) -NoNewline -ForegroundColor DarkGray
    Write-Host $Valor -ForegroundColor $Color
}

function Mostrar-EstadoActual {
    param([switch]$Resumido)

    $d = Obtener-Datos
    $resumen = Resolver-EstadoAnuncios -Datos $d
    Write-Host ''
    Write-Host ('  {0}' -f $resumen.Titulo) -ForegroundColor $resumen.Color
    Write-Host ('  {0}' -f $resumen.Paso) -ForegroundColor White

    if ($Resumido) {
        Fila 'Listos / omitidos' ("$($d.ArchivosPreparados) / $($d.ArchivosConError)")
        return $d
    }

    Write-Host ''
    Fila 'Segunda pantalla' $(if ($d.SegundaPantalla) { 'Conectada' } else { 'No detectada' }) $(if ($d.SegundaPantalla) { 'Green' } else { 'Red' })
    Fila 'Archivos originales' ([string]$d.ArchivosOriginales)
    Fila 'Listos / omitidos' ("$($d.ArchivosPreparados) / $($d.ArchivosConError)")
    Fila 'Controlador' $(if ($d.Controlador) { "Activo (PID $($d.Controlador.Id))" } else { 'Detenido' })
    Fila 'Reproductor VLC' $(if ($d.Vlc) { "Activo (PID $($d.Vlc.Id))" } else { 'Detenido' })
    Fila 'Inicio automático' $d.Tarea
    Fila 'FFmpeg' $(if ($d.Ffmpeg) { 'Disponible' } else { 'No disponible' })
    if ($d.ResolucionObjetivo) { Fila 'Resolución' $d.ResolucionObjetivo }
    if ($d.SalidaVlc) { Fila 'Salida VLC' $d.SalidaVlc }
    Fila 'Siempre encima' $(if ($d.SiempreEncima) { 'Activado' } else { 'Desactivado' })
    Fila 'Carpeta' $d.Carpeta
    if ($d.EstadoActualizado) { Fila 'Actualizado' ($d.EstadoActualizado.ToString('yyyy-MM-dd HH:mm:ss')) }
    if ($d.ErrorConfig) { Fila 'Configuración' $d.ErrorConfig Red }
    if ($d.Detalle) { Fila 'Detalle' $d.Detalle }
    return $d
}

function Registrar-EventoManual {
    param([string]$Mensaje)

    try {
        $fecha = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -LiteralPath $LogPath -Value "[$fecha] $Mensaje" -Encoding UTF8
    }
    catch {}
}

function Iniciar-Anuncios {
    Mostrar-Cabecera 'INICIAR PANTALLA DE ANUNCIOS'

    if (-not (Test-Path -LiteralPath $ControllerPath) -or -not (Test-Path -LiteralPath $LauncherPath)) {
        Write-Host '  ERROR: El sistema de anuncios no está instalado correctamente.' -ForegroundColor Red
        Write-Host '  Avise al administrador.' -ForegroundColor Red
        Esperar-Cierre
        return
    }

    $antes = Obtener-Datos

    if (-not $antes.ConfigValida) {
        Write-Host '  No se puede iniciar: la configuración falta o es inválida.' -ForegroundColor Red
        Write-Host '  Avise al administrador.' -ForegroundColor White
        Esperar-Cierre
        return
    }

    if (-not $antes.SegundaPantalla) {
        Write-Host '  NO SE PUEDE INICIAR.' -ForegroundColor Red
        Write-Host ''
        Write-Host '  Windows no detecta una segunda pantalla.' -ForegroundColor Red
        Write-Host '  Revise que el monitor de anuncios esté encendido y conectado.' -ForegroundColor Yellow
        Esperar-Cierre
        return
    }

    if ($antes.Controlador) {
        Write-Host '  El controlador ya está activo.' -ForegroundColor Cyan
        Mostrar-EstadoActual | Out-Null
        Esperar-Cierre
        return
    }

    if (-not $antes.Controlador) {
        Remove-Item -LiteralPath $ControllerPidPath -Force -ErrorAction SilentlyContinue
    }

    if (-not $antes.Vlc) {
        Remove-Item -LiteralPath $VlcPidPath -Force -ErrorAction SilentlyContinue
    }

    Write-Host '  Iniciando Casa Elida - Anuncios...' -ForegroundColor Cyan
    Write-Host '  Los archivos nuevos pueden necesitar unos segundos para prepararse.' -ForegroundColor DarkGray

    $powershellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

    try {
        Remove-Item -LiteralPath $StartupErrorPath -Force -ErrorAction SilentlyContinue

        # EncodedCommand avoids all quoting ambiguity caused by paths with spaces.
        $comando = "& '$LauncherPath' -SinEsperaInicial"
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($comando)
        $encoded = [Convert]::ToBase64String($bytes)

        $procesoArranque = Start-Process `
            -FilePath $powershellExe `
            -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $encoded" `
            -WindowStyle Hidden `
            -PassThru

        Registrar-EventoManual "INICIO MANUAL solicitado por $env:USERNAME."
    }
    catch {
        Write-Host ''
        Write-Host '  ERROR: No se pudo crear el proceso de arranque.' -ForegroundColor Red
        Write-Host "  Detalle: $($_.Exception.Message)" -ForegroundColor DarkRed
        Esperar-Cierre
        return
    }

    # Hasta 15 segundos para que el controlador aparezca.
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 500
        $actual = Obtener-Datos

        if ($actual.Controlador) {
            break
        }

        if ($procesoArranque.HasExited) {
            break
        }
    }

    Write-Host ''
    $resultadoInicio = Mostrar-EstadoActual

    if (-not $resultadoInicio.Controlador) {
        Write-Host ''
        Write-Host '  NO SE PUDO MANTENER ACTIVO EL CONTROLADOR.' -ForegroundColor Red
        Write-Host '  El sistema encontró un error de arranque.' -ForegroundColor Red

        if (Test-Path -LiteralPath $StartupErrorPath) {
            Write-Host ''
            Write-Host '  ERROR DE ARRANQUE' -ForegroundColor Yellow
            Write-Host '  ─────────────────' -ForegroundColor DarkGray
            Get-Content -LiteralPath $StartupErrorPath -Tail 14 -ErrorAction SilentlyContinue |
                ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
        }
        elseif (Test-Path -LiteralPath $LogPath) {
            Write-Host ''
            Write-Host '  ÚLTIMAS LÍNEAS DEL REGISTRO' -ForegroundColor Yellow
            Write-Host '  ───────────────────────────' -ForegroundColor DarkGray
            Get-Content -LiteralPath $LogPath -Tail 14 -ErrorAction SilentlyContinue |
                ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
        }

        Write-Host ''
        Write-Host '  Use STATUS ANUNCIOS para volver a revisar el estado.' -ForegroundColor White
    }

    Esperar-Cierre
}

function Detener-Anuncios {
    Mostrar-Cabecera 'Detener anuncios'
    $datos = Obtener-Datos

    if (-not $datos.Instalado) {
        Write-Host '  El sistema no está instalado. Avise al administrador.' -ForegroundColor Red
        Esperar-Cierre
        return
    }

    if ($script:EnMenu) {
        $confirmacion = Read-Host '  ¿Detener anuncios? Escriba S para confirmar'
        if ($confirmacion -ine 'S') {
            Write-Host '  Operación cancelada.' -ForegroundColor Yellow
            Esperar-Cierre
            return
        }
    }

    $inciertos = New-Object System.Collections.Generic.List[string]
    foreach ($par in @(
        @{ Ruta = $ControllerPidPath; Nombre = 'powershell'; Etiqueta = 'controlador' },
        @{ Ruta = $VlcPidPath; Nombre = 'vlc'; Etiqueta = 'VLC' }
    )) {
        if (-not (Test-Path -LiteralPath $par.Ruta)) { continue }
        $proceso = Obtener-ProcesoDesdePid -ArchivoPid $par.Ruta -NombreEsperado $par.Nombre
        if (-not $proceso) {
            $inciertos.Add($par.Etiqueta)
            continue
        }
        try {
            Stop-Process -Id $proceso.Id -Force -ErrorAction Stop
            Start-Sleep -Milliseconds 300
            if (Get-Process -Id $proceso.Id -ErrorAction SilentlyContinue) {
                $inciertos.Add($par.Etiqueta)
            }
            else {
                Remove-Item -LiteralPath $par.Ruta -Force -ErrorAction Stop
            }
        }
        catch { $inciertos.Add($par.Etiqueta) }
    }

    Registrar-EventoManual "PARADA MANUAL solicitada por $env:USERNAME."
    Write-Host ''
    if ($inciertos.Count -gt 0) {
        Write-Host '  No se pudo confirmar la parada completa.' -ForegroundColor Yellow
        Write-Host ('  Revise: {0}. Avise al administrador.' -f ($inciertos -join ', ')) -ForegroundColor White
    }
    else {
        Write-Host '  Anuncios detenidos.' -ForegroundColor Green
        Write-Host '  Volverán a iniciar al próximo inicio de sesión de Windows.' -ForegroundColor White
    }
    Esperar-Cierre
}

function Estado-Anuncios {
    Mostrar-Cabecera 'ESTADO DE LA PANTALLA DE ANUNCIOS'
    Mostrar-EstadoActual | Out-Null

    if (Test-Path -LiteralPath $StartupErrorPath) {
        Write-Host ''
        Write-Host '  ÚLTIMO ERROR DE ARRANQUE' -ForegroundColor Red
        Write-Host '  ────────────────────────' -ForegroundColor DarkGray
        Get-Content -LiteralPath $StartupErrorPath -Tail 12 -ErrorAction SilentlyContinue |
            ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
    }

    if (Test-Path -LiteralPath $LogPath) {
        $avisos = @(
            Get-Content -LiteralPath $LogPath -Tail 60 -ErrorAction SilentlyContinue |
                Where-Object { $_ -match 'ERROR|FATAL|OMITIDO|no hay segunda pantalla|No se encontró' } |
                Select-Object -Last 5
        )

        if ($avisos.Count -gt 0) {
            Write-Host ''
            Write-Host '  ÚLTIMOS AVISOS DEL SISTEMA' -ForegroundColor Yellow
            Write-Host '  ──────────────────────────' -ForegroundColor DarkGray

            foreach ($linea in $avisos) {
                Write-Host "  $linea" -ForegroundColor DarkYellow
            }
        }
    }

    Esperar-Cierre
}

function Menu-Anuncios {
    $script:EnMenu = $true
    while ($true) {
        Mostrar-Cabecera 'Control de la pantalla de anuncios'
        Mostrar-EstadoActual -Resumido | Out-Null
        Write-Host ''
        Write-Host '  1  Iniciar anuncios' -ForegroundColor White
        Write-Host '  2  Detener anuncios' -ForegroundColor White
        Write-Host '  3  Ver estado y avisos' -ForegroundColor White
        Write-Host '  0  Salir' -ForegroundColor DarkGray
        Write-Host ''
        $opcion = Read-Host '  Elija una opción'
        switch ($opcion) {
            '1' { Iniciar-Anuncios }
            '2' { Detener-Anuncios }
            '3' { Estado-Anuncios }
            '0' { return }
            default {
                Write-Host '  Opción no válida. Use 1, 2, 3 o 0.' -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
        }
    }
}

switch ($Accion) {
    'Menu'    { Menu-Anuncios }
    'Iniciar' { Iniciar-Anuncios }
    'Detener' { Detener-Anuncios }
    'Estado'  { Estado-Anuncios }
}
