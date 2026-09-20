param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Iniciar', 'Detener', 'Estado')]
    [string]$Accion
)

$ErrorActionPreference = 'SilentlyContinue'

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

try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $Host.UI.RawUI.WindowTitle = 'Casa Elida - Anuncios'
    $Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(110, 3000)
    $Host.UI.RawUI.WindowSize = New-Object Management.Automation.Host.Size(110, 34)
}
catch {}

function Mostrar-Cabecera {
    param([string]$Subtitulo)

    Clear-Host
    Write-Host ''
    Write-Host '  ╔══════════════════════════════════════════════════════════════════════════════════════════════╗' -ForegroundColor DarkCyan
    Write-Host '  ║                                         CASA ELIDA                                           ║' -ForegroundColor Cyan
    Write-Host '  ╚══════════════════════════════════════════════════════════════════════════════════════════════╝' -ForegroundColor DarkCyan
    Write-Host ''

    $banner = @'
        █████╗ ███╗   ██╗██╗   ██╗███╗   ██╗ ██████╗██╗ ██████╗ ███████╗
       ██╔══██╗████╗  ██║██║   ██║████╗  ██║██╔════╝██║██╔═══██╗██╔════╝
       ███████║██╔██╗ ██║██║   ██║██╔██╗ ██║██║     ██║██║   ██║███████╗
       ██╔══██║██║╚██╗██║██║   ██║██║╚██╗██║██║     ██║██║   ██║╚════██║
       ██║  ██║██║ ╚████║╚██████╔╝██║ ╚████║╚██████╗██║╚██████╔╝███████║
       ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚═╝ ╚═════╝ ╚══════╝
'@
    Write-Host $banner -ForegroundColor Yellow
    Write-Host ''
    Write-Host ("                                   {0}" -f $Subtitulo) -ForegroundColor White
    Write-Host ''
    Write-Host '  ──────────────────────────────────────────────────────────────────────────────────────────────' -ForegroundColor DarkGray
    Write-Host ''
}

function Esperar-Cierre {
    Write-Host ''
    Write-Host '  Presione ENTER para cerrar esta ventana...' -ForegroundColor DarkGray
    [void](Read-Host)
}

function Obtener-ProcesoDesdePid {
    param(
        [string]$ArchivoPid,
        [string]$NombreEsperado
    )

    if (-not (Test-Path -LiteralPath $ArchivoPid)) {
        return $null
    }

    try {
        $pidObjetivo = [int](Get-Content -LiteralPath $ArchivoPid -ErrorAction Stop | Select-Object -First 1)
        $proceso = Get-Process -Id $pidObjetivo -ErrorAction SilentlyContinue

        if ($proceso -and $proceso.ProcessName -like "$NombreEsperado*") {
            return $proceso
        }
    }
    catch {}

    return $null
}

function Obtener-Datos {
    $r = [ordered]@{
        Instalado = $false
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

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        return [pscustomobject]$r
    }

    $r.Instalado = $true

    try {
        $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
        $r.Carpeta = [string]$config.CarpetaMultimedia
        $r.SalidaVlc = [string]$config.SalidaVideoVlc

        if ($null -ne $config.SiempreEncimaVlc) {
            $r.SiempreEncima = [bool]$config.SiempreEncimaVlc
        }

        $r.Ffmpeg = (Test-Path -LiteralPath ([string]$config.RutaFfmpeg))
    }
    catch {}

    try {
        Add-Type -AssemblyName System.Windows.Forms
        $pantallas = @([System.Windows.Forms.Screen]::AllScreens)
        $r.Pantallas = $pantallas.Count
        $r.SegundaPantalla = ($pantallas.Count -ge 2)
    }
    catch {}

    try {
        if (Test-Path -LiteralPath $StatePath) {
            $estado = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
            $r.ArchivosOriginales = [int]$estado.ArchivosOriginales
            $r.ArchivosPreparados = [int]$estado.ArchivosPreparados
            $r.ArchivosConError = [int]$estado.ArchivosConError
            $r.ResolucionObjetivo = [string]$estado.ResolucionObjetivo
            $r.EstadoPreparacion = [string]$estado.EstadoGeneral
            $r.Detalle = [string]$estado.Detalle
        }
        elseif (Test-Path -LiteralPath $r.Carpeta) {
            $r.ArchivosOriginales = @(Get-ChildItem -LiteralPath $r.Carpeta -File -Recurse -ErrorAction SilentlyContinue).Count
        }
    }
    catch {}

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
    param(
        [string]$Etiqueta,
        [string]$Valor,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )

    Write-Host ('  {0,-28}' -f ($Etiqueta + ':')) -NoNewline -ForegroundColor DarkGray
    Write-Host $Valor -ForegroundColor $Color
}

function Mostrar-EstadoActual {
    $d = Obtener-Datos

    if (-not $d.Instalado) {
        Fila 'Sistema' 'NO INSTALADO' Red
        Write-Host ''
        Write-Host '  Avise al administrador. Falta la instalación de Casa Elida - Anuncios.' -ForegroundColor Red
        return $d
    }

    Fila 'Sistema' 'INSTALADO' Green

    if ($d.SegundaPantalla) {
        Fila 'Segunda pantalla' "CONECTADA ($($d.Pantallas) pantallas detectadas)" Green
    }
    else {
        Fila 'Segunda pantalla' 'NO CONECTADA' Red
    }

    Fila 'Archivos en anuncios' "$($d.ArchivosOriginales)" Cyan

    if ($d.ArchivosPreparados -gt 0) {
        Fila 'Listos para reproducir' "$($d.ArchivosPreparados)" Green
    }
    else {
        Fila 'Listos para reproducir' "$($d.ArchivosPreparados)" Yellow
    }

    if ($d.ArchivosConError -gt 0) {
        Fila 'Omitidos / con error' "$($d.ArchivosConError)" Red
    }
    else {
        Fila 'Omitidos / con error' '0' Green
    }

    if ($d.ResolucionObjetivo) {
        Fila 'Resolución preparada' $d.ResolucionObjetivo White
    }

    if ($d.Ffmpeg) {
        Fila 'Normalizador FFmpeg' 'OK' Green
    }
    else {
        Fila 'Normalizador FFmpeg' 'NO DISPONIBLE' Red
    }

    Fila 'Modo de video VLC' "$($d.SalidaVlc) + decodificación por software" Cyan

    if ($d.SiempreEncima) {
        Fila 'Siempre encima' 'ACTIVADO' Green
    }
    else {
        Fila 'Siempre encima' 'DESACTIVADO' Yellow
    }

    if ($d.Controlador) {
        Fila 'Controlador' "ACTIVO - PID $($d.Controlador.Id)" Green
    }
    else {
        Fila 'Controlador' 'DETENIDO' Yellow
    }

    if ($d.Vlc) {
        Fila 'Reproductor VLC' "REPRODUCIENDO - PID $($d.Vlc.Id)" Green
    }
    else {
        Fila 'Reproductor VLC' 'DETENIDO' Yellow
    }

    Fila 'Inicio automático' $d.Tarea Cyan
    Fila 'Carpeta' $d.Carpeta White

    if ($d.EstadoPreparacion) {
        Fila 'Preparación multimedia' $d.EstadoPreparacion $(if ($d.EstadoPreparacion -match 'ERROR') { 'Red' } elseif ($d.EstadoPreparacion -eq 'PREPARANDO') { 'Yellow' } else { 'Green' })
    }

    if ($d.Detalle) {
        Write-Host ''
        Write-Host '  Detalle:' -ForegroundColor DarkGray
        Write-Host "  $($d.Detalle)" -ForegroundColor White
    }

    Write-Host ''
    Write-Host '  ──────────────────────────────────────────────────────────────────────────────────────────────' -ForegroundColor DarkGray

    if (-not $d.SegundaPantalla) {
        Write-Host '  ESTADO GENERAL: REVISAR SEGUNDA PANTALLA' -ForegroundColor Red
    }
    elseif ($d.EstadoPreparacion -match 'ERROR') {
        Write-Host '  ESTADO GENERAL: HAY UN PROBLEMA DE PREPARACIÓN' -ForegroundColor Red
    }
    elseif ($d.Controlador -and $d.Vlc) {
        Write-Host '  ESTADO GENERAL: FUNCIONANDO CORRECTAMENTE' -ForegroundColor Green
    }
    elseif (-not $d.Controlador -and -not $d.Vlc) {
        Write-Host '  ESTADO GENERAL: ANUNCIOS DETENIDOS' -ForegroundColor Yellow
    }
    else {
        Write-Host '  ESTADO GENERAL: INCOMPLETO - USE START ANUNCIOS' -ForegroundColor Yellow
    }

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

    if (-not $antes.SegundaPantalla) {
        Write-Host '  NO SE PUEDE INICIAR.' -ForegroundColor Red
        Write-Host ''
        Write-Host '  Windows no detecta una segunda pantalla.' -ForegroundColor Red
        Write-Host '  Revise que el monitor de anuncios esté encendido y conectado.' -ForegroundColor Yellow
        Esperar-Cierre
        return
    }

    if ($antes.Controlador -and $antes.Vlc) {
        Write-Host '  Los anuncios ya están funcionando correctamente.' -ForegroundColor Green
        Write-Host ''
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
    Mostrar-Cabecera 'DETENER PANTALLA DE ANUNCIOS'

    $datos = Obtener-Datos

    if (-not $datos.Instalado) {
        Write-Host '  ERROR: El sistema de anuncios no está instalado.' -ForegroundColor Red
        Esperar-Cierre
        return
    }

    Write-Host '  Deteniendo anuncios...' -ForegroundColor Cyan

    $controlador = Obtener-ProcesoDesdePid -ArchivoPid $ControllerPidPath -NombreEsperado 'powershell'
    if ($controlador) {
        Stop-Process -Id $controlador.Id -Force -ErrorAction SilentlyContinue
    }

    Start-Sleep -Milliseconds 500

    $vlc = Obtener-ProcesoDesdePid -ArchivoPid $VlcPidPath -NombreEsperado 'vlc'
    if ($vlc) {
        Stop-Process -Id $vlc.Id -Force -ErrorAction SilentlyContinue
    }

    Remove-Item -LiteralPath $ControllerPidPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $VlcPidPath -Force -ErrorAction SilentlyContinue

    Registrar-EventoManual "PARADA MANUAL solicitada por $env:USERNAME."

    Write-Host ''
    Write-Host '  ANUNCIOS DETENIDOS.' -ForegroundColor Green
    Write-Host ''
    Write-Host '  Permanecerán detenidos hasta usar START ANUNCIOS' -ForegroundColor White
    Write-Host '  o hasta el próximo inicio de sesión de Windows.' -ForegroundColor White

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

switch ($Accion) {
    'Iniciar' { Iniciar-Anuncios }
    'Detener' { Detener-Anuncios }
    'Estado'  { Estado-Anuncios }
}
