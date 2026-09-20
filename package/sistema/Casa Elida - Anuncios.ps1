param(
    [switch]$SinEsperaInicial
)

$ErrorActionPreference = 'Stop'

$InstallDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $InstallDir 'config.json'
$PlaylistPath = Join-Path $InstallDir 'lista.m3u8'
$BlankImagePath = Join-Path $InstallDir 'negro.png'
$CacheDir = Join-Path $InstallDir 'cache'
$LogPath = Join-Path $InstallDir 'registro.log'
$StatePath = Join-Path $InstallDir 'estado.json'
$ControllerPidPath = Join-Path $InstallDir 'controlador.pid'
$VlcPidPath = Join-Path $InstallDir 'vlc.pid'

function Escribir-Log {
    param([string]$Mensaje)

    try {
        if (Test-Path -LiteralPath $LogPath) {
            $log = Get-Item -LiteralPath $LogPath -ErrorAction SilentlyContinue
            if ($log -and $log.Length -gt 8MB) {
                $old = Join-Path $InstallDir 'registro-anterior.log'
                Remove-Item -LiteralPath $old -Force -ErrorAction SilentlyContinue
                Move-Item -LiteralPath $LogPath -Destination $old -Force -ErrorAction SilentlyContinue
            }
        }

        $fecha = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -LiteralPath $LogPath -Value "[$fecha] $Mensaje" -Encoding UTF8
    }
    catch {}
}

function Guardar-Estado {
    param(
        [string]$EstadoGeneral,
        [int]$Originales = 0,
        [int]$Preparados = 0,
        [int]$Errores = 0,
        [int]$Ancho = 0,
        [int]$Alto = 0,
        [string]$Detalle = ''
    )

    try {
        $resolucion = ''
        if ($Ancho -gt 0 -and $Alto -gt 0) {
            $resolucion = "${Ancho}x${Alto}"
        }

        $estadoObjeto = [ordered]@{
            Actualizado = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            EstadoGeneral = $EstadoGeneral
            ArchivosOriginales = $Originales
            ArchivosPreparados = $Preparados
            ArchivosConError = $Errores
            ResolucionObjetivo = $resolucion
            Detalle = $Detalle
        }

        $estadoObjeto |
            ConvertTo-Json -Depth 4 |
            Set-Content -LiteralPath $StatePath -Encoding UTF8
    }
    catch {
        try {
            Escribir-Log "No se pudo escribir estado.json: $($_.Exception.Message)"
        }
        catch {}
    }
}

function Buscar-Vlc {
    param([string]$RutaConfigurada)

    $candidatos = @()
    if ($RutaConfigurada) { $candidatos += $RutaConfigurada }

    if ($env:ProgramFiles) {
        $candidatos += (Join-Path $env:ProgramFiles 'VideoLAN\VLC\vlc.exe')
    }

    $pf86 = ${env:ProgramFiles(x86)}
    if ($pf86) {
        $candidatos += (Join-Path $pf86 'VideoLAN\VLC\vlc.exe')
    }

    try {
        $reg = Get-ItemProperty 'HKLM:\SOFTWARE\VideoLAN\VLC' -ErrorAction SilentlyContinue
        if ($reg -and $reg.InstallDir) {
            $candidatos += (Join-Path $reg.InstallDir 'vlc.exe')
        }
    }
    catch {}

    try {
        $reg32 = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\VideoLAN\VLC' -ErrorAction SilentlyContinue
        if ($reg32 -and $reg32.InstallDir) {
            $candidatos += (Join-Path $reg32.InstallDir 'vlc.exe')
        }
    }
    catch {}

    foreach ($candidato in ($candidatos | Select-Object -Unique)) {
        if ($candidato -and (Test-Path -LiteralPath $candidato)) {
            return $candidato
        }
    }

    return $null
}

function Obtener-Sha256Texto {
    param([string]$Texto)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Texto)
        return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    }
    finally {
        $sha.Dispose()
    }
}

function Obtener-TipoMedio {
    param(
        [System.IO.FileInfo]$Archivo,
        [string[]]$ExtensionesImagen,
        [string[]]$ExtensionesVideo,
        [string]$Ffprobe
    )

    $ext = $Archivo.Extension.ToLowerInvariant()

    if ($ExtensionesImagen -contains $ext) {
        # GIF/WEBP pueden ser animados: si ffprobe detecta una duración clara,
        # se preparan como video para conservar la animación.
        if ($ext -in @('.gif', '.webp')) {
            try {
                $duracionRaw = & $Ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $Archivo.FullName 2>$null
                $duracion = 0.0
                if ([double]::TryParse(($duracionRaw | Select-Object -First 1), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$duracion)) {
                    if ($duracion -gt 0.30) { return 'video' }
                }
            }
            catch {}
        }
        return 'imagen'
    }

    if ($ExtensionesVideo -contains $ext) {
        return 'video'
    }

    # Para extensiones desconocidas, intentamos descubrir si realmente
    # contienen una pista de video. Esto permite aceptar archivos válidos
    # aunque alguien los haya guardado con una extensión poco común.
    try {
        $salida = & $Ffprobe -v error -select_streams v:0 -show_entries stream=codec_type -of default=noprint_wrappers=1:nokey=1 $Archivo.FullName 2>$null
        if (($salida | Select-Object -First 1) -eq 'video') {
            return 'video'
        }
    }
    catch {}

    return 'desconocido'
}

function Preparar-Imagen {
    param(
        [string]$Ffmpeg,
        [System.IO.FileInfo]$Origen,
        [string]$Destino,
        [int]$Ancho,
        [int]$Alto
    )

    $temporal = "$Destino.tmp.png"
    Remove-Item -LiteralPath $temporal -Force -ErrorAction SilentlyContinue

    $filtro = "scale=${Ancho}:${Alto}:force_original_aspect_ratio=decrease,pad=${Ancho}:${Alto}:(ow-iw)/2:(oh-ih)/2:black,setsar=1,format=rgb24"

    $salida = & $Ffmpeg `
        -y `
        -nostdin `
        -hide_banner `
        -loglevel error `
        -i $Origen.FullName `
        -frames:v 1 `
        -vf $filtro `
        $temporal 2>&1

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $temporal)) {
        throw ("FFmpeg no pudo preparar la imagen. " + (($salida | Out-String).Trim()))
    }

    Move-Item -LiteralPath $temporal -Destination $Destino -Force
}

function Preparar-Video {
    param(
        [string]$Ffmpeg,
        [System.IO.FileInfo]$Origen,
        [string]$Destino,
        [int]$Ancho,
        [int]$Alto
    )

    $temporal = "$Destino.tmp.mp4"
    Remove-Item -LiteralPath $temporal -Force -ErrorAction SilentlyContinue

    $filtro = "scale=${Ancho}:${Alto}:force_original_aspect_ratio=decrease,pad=${Ancho}:${Alto}:(ow-iw)/2:(oh-ih)/2:black,setsar=1,fps=30,format=yuv420p"

    $salida = & $Ffmpeg `
        -y `
        -nostdin `
        -hide_banner `
        -loglevel error `
        -i $Origen.FullName `
        -map 0:v:0 `
        -an `
        -vf $filtro `
        -c:v libx264 `
        -preset veryfast `
        -crf 20 `
        -movflags +faststart `
        $temporal 2>&1

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $temporal)) {
        throw ("FFmpeg no pudo preparar el video. " + (($salida | Out-String).Trim()))
    }

    Move-Item -LiteralPath $temporal -Destination $Destino -Force
}

function Preparar-Multimedia {
    param(
        [System.IO.FileInfo[]]$Archivos,
        [object]$Config,
        [int]$Ancho,
        [int]$Alto
    )

    New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null

    $ffmpeg = [string]$Config.RutaFfmpeg
    $ffprobe = [string]$Config.RutaFfprobe

    if (-not (Test-Path -LiteralPath $ffmpeg)) {
        throw "No se encontró FFmpeg en: $ffmpeg"
    }

    if (-not (Test-Path -LiteralPath $ffprobe)) {
        throw "No se encontró FFprobe en: $ffprobe"
    }

    $imagenes = @($Config.ExtensionesImagen)
    $videos = @($Config.ExtensionesVideo)

    $listos = New-Object System.Collections.Generic.List[string]
    $errores = New-Object System.Collections.Generic.List[string]
    $cacheEnUso = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $total = $Archivos.Count
    $indice = 0

    foreach ($archivo in $Archivos) {
        $indice++

        try {
            $tipo = Obtener-TipoMedio `
                -Archivo $archivo `
                -ExtensionesImagen $imagenes `
                -ExtensionesVideo $videos `
                -Ffprobe $ffprobe

            if ($tipo -eq 'desconocido') {
                throw 'Formato no reconocido como imagen o video.'
            }

            $huella = '{0}|{1}|{2}|{3}x{4}|{5}' -f `
                $archivo.FullName.ToLowerInvariant(), `
                $archivo.Length, `
                $archivo.LastWriteTimeUtc.Ticks, `
                $Ancho, `
                $Alto, `
                $tipo

            $clave = Obtener-Sha256Texto -Texto $huella

            if ($tipo -eq 'imagen') {
                $destino = Join-Path $CacheDir "$clave.png"
            }
            else {
                $destino = Join-Path $CacheDir "$clave.mp4"
            }

            $null = $cacheEnUso.Add($destino)

            if (-not (Test-Path -LiteralPath $destino)) {
                Guardar-Estado `
                    -EstadoGeneral 'PREPARANDO' `
                    -Originales $total `
                    -Preparados $listos.Count `
                    -Errores $errores.Count `
                    -Ancho $Ancho `
                    -Alto $Alto `
                    -Detalle ("Preparando {0} de {1}: {2}" -f $indice, $total, $archivo.Name)

                Escribir-Log "Preparando '$($archivo.Name)' como $tipo para ${Ancho}x${Alto}."

                if ($tipo -eq 'imagen') {
                    Preparar-Imagen -Ffmpeg $ffmpeg -Origen $archivo -Destino $destino -Ancho $Ancho -Alto $Alto
                }
                else {
                    Preparar-Video -Ffmpeg $ffmpeg -Origen $archivo -Destino $destino -Ancho $Ancho -Alto $Alto
                }

                Escribir-Log "Archivo preparado correctamente: '$($archivo.Name)'."
            }

            $listos.Add($destino)
        }
        catch {
            $mensaje = "$($archivo.Name): $($_.Exception.Message)"
            $errores.Add($mensaje)
            Escribir-Log "ARCHIVO OMITIDO - $mensaje"
        }
    }

    # Limpia versiones antiguas del cache que ya no corresponden a ningún
    # archivo actual o a la resolución actual de la segunda pantalla.
    try {
        Get-ChildItem -LiteralPath $CacheDir -File -ErrorAction SilentlyContinue | ForEach-Object {
            if (-not $cacheEnUso.Contains($_.FullName)) {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {}

    return [pscustomobject]@{
        Listos = @($listos)
        Errores = @($errores)
    }
}

function Obtener-HuellaOriginales {
    param(
        [System.IO.FileInfo[]]$Archivos,
        [int]$Ancho,
        [int]$Alto
    )

    if (-not $Archivos -or $Archivos.Count -eq 0) {
        return "VACIO|${Ancho}x${Alto}"
    }

    return ("${Ancho}x${Alto}`n" + (($Archivos | ForEach-Object {
        '{0}|{1}|{2}' -f $_.FullName.ToLowerInvariant(), $_.Length, $_.LastWriteTimeUtc.Ticks
    }) -join "`n"))
}

function Escribir-Lista {
    param([string[]]$ArchivosPreparados)

    $lineas = New-Object System.Collections.Generic.List[string]
    $lineas.Add('#EXTM3U')

    if ($ArchivosPreparados -and $ArchivosPreparados.Count -gt 0) {
        $mezclados = @($ArchivosPreparados | Get-Random -Count $ArchivosPreparados.Count)
        foreach ($archivo in $mezclados) {
            $lineas.Add($archivo)
        }
    }
    else {
        $lineas.Add($BlankImagePath)
    }

    $utf8SinBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($PlaylistPath, $lineas, $utf8SinBom)
}

function Esta-Vlc-Activo {
    if ($null -eq $script:ProcesoVlc) {
        return $false
    }

    try { return (-not $script:ProcesoVlc.HasExited) }
    catch { return $false }
}

function Detener-Vlc {
    if (Esta-Vlc-Activo) {
        $pidVlc = $script:ProcesoVlc.Id
        Escribir-Log "Deteniendo VLC de anuncios. PID $pidVlc."

        try { $null = $script:ProcesoVlc.CloseMainWindow() } catch {}
        Start-Sleep -Milliseconds 700

        if (Esta-Vlc-Activo) {
            try { Stop-Process -Id $pidVlc -Force -ErrorAction SilentlyContinue } catch {}
        }
    }

    $script:ProcesoVlc = $null
    Remove-Item -LiteralPath $VlcPidPath -Force -ErrorAction SilentlyContinue
}

function Iniciar-Vlc {
    param(
        [string[]]$ArchivosPreparados,
        [object]$Config,
        [int]$CantidadPantallas
    )

    if ($CantidadPantallas -lt 2) {
        Escribir-Log 'No se inicia VLC porque no hay una segunda pantalla conectada.'
        return
    }

    $indicePantalla = [int]$Config.IndicePantallaVlc

    if ($indicePantalla -lt 0 -or $indicePantalla -ge $CantidadPantallas) {
        Escribir-Log "El índice de pantalla VLC $indicePantalla no es válido para $CantidadPantallas pantalla(s)."
        return
    }

    $vlc = Buscar-Vlc -RutaConfigurada $Config.RutaVlc

    if (-not $vlc) {
        Escribir-Log 'No se encontró VLC. El sistema volverá a intentar automáticamente.'
        return
    }

    Escribir-Lista -ArchivosPreparados $ArchivosPreparados
    Detener-Vlc

    $duracionImagen = [int]$Config.DuracionImagenSegundos
    $salidaVideo = [string]$Config.SalidaVideoVlc
    $siempreEncima = $true

    if ($null -ne $Config.SiempreEncimaVlc) {
        $siempreEncima = [bool]$Config.SiempreEncimaVlc
    }

    # Modo de máxima compatibilidad:
    # - FFmpeg ya convirtió todos los videos a H.264/yuv420p.
    # - VLC decodifica por software para evitar fallos DXVA/D3D11VA.
    # - Direct3D9 evita el camino Direct3D11 que causa pantallas negras
    #   en algunos equipos Windows 10 / Intel antiguos.
    $argumentos = New-Object System.Collections.Generic.List[string]

    $argumentos.Add('--no-one-instance')
    $argumentos.Add('--fullscreen')
    $argumentos.Add("--qt-fullscreen-screennumber=$indicePantalla")
    $argumentos.Add('--qt-minimal-view')
    $argumentos.Add('--no-qt-fs-controller')
    $argumentos.Add('--no-qt-system-tray')
    $argumentos.Add('--no-qt-video-autoresize')
    $argumentos.Add('--no-qt-error-dialogs')
    $argumentos.Add('--no-qt-privacy-ask')
    $argumentos.Add('--no-qt-updates-notif')
    $argumentos.Add('--no-video-title-show')
    $argumentos.Add('--no-osd')
    $argumentos.Add('--no-audio')
    $argumentos.Add('--avcodec-hw=none')
    $argumentos.Add("--vout=$salidaVideo")

    if ($siempreEncima) {
        # v3.3: mantiene la ventana de video de VLC por encima de otras
        # ventanas en la segunda pantalla. Esto no impide una minimización
        # explícita; un watchdog de estado de ventana queda como trabajo futuro.
        $argumentos.Add('--video-on-top')
    }

    $argumentos.Add('--random')
    $argumentos.Add('--loop')
    $argumentos.Add("--image-duration=$duracionImagen")
    $argumentos.Add("`"$PlaylistPath`"")

    try {
        $lineaArgumentos = $argumentos -join ' '

        $script:ProcesoVlc = Start-Process `
            -FilePath $vlc `
            -ArgumentList $lineaArgumentos `
            -WorkingDirectory (Split-Path -Parent $vlc) `
            -PassThru

        Set-Content -LiteralPath $VlcPidPath -Value $script:ProcesoVlc.Id -Encoding ASCII

        $cantidad = if ($ArchivosPreparados) { $ArchivosPreparados.Count } else { 0 }
        Escribir-Log "VLC iniciado. PID $($script:ProcesoVlc.Id). Pantalla $indicePantalla. $cantidad archivo(s) preparados. VOUT=$salidaVideo. HW decode=off. SiempreEncima=$siempreEncima."

        Start-Sleep -Seconds 2

        if (-not (Esta-Vlc-Activo)) {
            $codigo = $null
            try { $codigo = $script:ProcesoVlc.ExitCode } catch {}

            Escribir-Log "VLC terminó inmediatamente. Código de salida: $codigo"
            $script:ProcesoVlc = $null
            Remove-Item -LiteralPath $VlcPidPath -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Escribir-Log "Error al iniciar VLC: $($_.Exception.Message)"
        $script:ProcesoVlc = $null
        Remove-Item -LiteralPath $VlcPidPath -Force -ErrorAction SilentlyContinue
    }
}

$creado = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\Casa_Elida_Anuncios_Controller_v3', [ref]$creado)

if (-not $creado) {
    exit 0
}

$script:ProcesoVlc = $null

try {
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Falta el archivo de configuración: $ConfigPath"
    }

    $Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

    $CarpetaMultimedia = [string]$Config.CarpetaMultimedia
    $EsperaInicial = [int]$Config.EsperaInicialSegundos
    $Intervalo = [int]$Config.IntervaloRevisionSegundos
    $EsperaCambios = [int]$Config.EsperaCambiosSegundos

    New-Item -ItemType Directory -Path $CarpetaMultimedia -Force | Out-Null
    New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
    Set-Content -LiteralPath $ControllerPidPath -Value $PID -Encoding ASCII

    Add-Type -AssemblyName System.Windows.Forms

    Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class Casa_Elida_Power_v31
{
    private const uint ES_CONTINUOUS = 0x80000000;
    private const uint ES_DISPLAY_REQUIRED = 0x00000002;

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern uint SetThreadExecutionState(uint esFlags);

    public static uint MantenerPantallaEncendida()
    {
        return SetThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED);
    }

    public static uint Restaurar()
    {
        return SetThreadExecutionState(ES_CONTINUOUS);
    }
}
'@

    Escribir-Log 'Controlador Casa Elida - Anuncios v3.3 iniciado.'
    Escribir-Log "Carpeta de anuncios: $CarpetaMultimedia"

    if (-not $SinEsperaInicial) {
        Escribir-Log "Esperando $EsperaInicial segundo(s) para que Windows inicialice las pantallas."
        Start-Sleep -Seconds $EsperaInicial
    }
    else {
        Escribir-Log 'Inicio manual: se omite la espera inicial.'
    }

    $ultimaHuella = $null
    $cambioPendiente = $null
    $pantallaAusenteRegistrada = $false
    $ultimoIntentoVlc = [DateTime]::MinValue
    $ultimosPreparados = @()
    $ultimoConteoOriginales = 0
    $ultimoConteoErrores = 0
    $ultimoAncho = 0
    $ultimoAlto = 0

    while ($true) {
        [Casa_Elida_Power_v31]::MantenerPantallaEncendida() | Out-Null

        $pantallas = @([System.Windows.Forms.Screen]::AllScreens)
        $cantidadPantallas = $pantallas.Count

        if ($cantidadPantallas -lt 2) {
            if (-not $pantallaAusenteRegistrada) {
                Escribir-Log 'No hay segunda pantalla. VLC se detiene para no ocupar la pantalla de caja.'
                $pantallaAusenteRegistrada = $true
            }

            Guardar-Estado -EstadoGeneral 'SIN_SEGUNDA_PANTALLA' -Detalle 'Conecte o encienda el monitor de anuncios.'
            Detener-Vlc
            Start-Sleep -Seconds $Intervalo
            continue
        }

        $indicePantalla = [int]$Config.IndicePantallaVlc
        if ($indicePantalla -lt 0 -or $indicePantalla -ge $cantidadPantallas) {
            Guardar-Estado -EstadoGeneral 'ERROR' -Detalle "Índice de pantalla inválido: $indicePantalla"
            Detener-Vlc
            Start-Sleep -Seconds $Intervalo
            continue
        }

        $pantallaObjetivo = $pantallas[$indicePantalla]
        $ancho = [int]$pantallaObjetivo.Bounds.Width
        $alto = [int]$pantallaObjetivo.Bounds.Height

        # H.264/yuv420p requiere dimensiones pares.
        if (($ancho % 2) -ne 0) { $ancho-- }
        if (($alto % 2) -ne 0) { $alto-- }

        if ($pantallaAusenteRegistrada) {
            Escribir-Log "Segunda pantalla detectada nuevamente. Resolución objetivo: ${ancho}x${alto}."
            $pantallaAusenteRegistrada = $false
            $cambioPendiente = (Get-Date).AddSeconds(-$EsperaCambios)
        }

        $archivos = @(
            Get-ChildItem -LiteralPath $CarpetaMultimedia -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { -not $_.Name.StartsWith('.') } |
                Sort-Object FullName
        )

        $huella = Obtener-HuellaOriginales -Archivos $archivos -Ancho $ancho -Alto $alto

        if ($null -eq $ultimaHuella) {
            $ultimaHuella = $huella
            $cambioPendiente = (Get-Date).AddSeconds(-$EsperaCambios)
        }
        elseif ($huella -ne $ultimaHuella) {
            $ultimaHuella = $huella
            $cambioPendiente = Get-Date
            Escribir-Log "La carpeta de anuncios cambió. Esperando $EsperaCambios segundo(s) para que terminen las copias."
        }

        if ($cambioPendiente) {
            $edad = ((Get-Date) - $cambioPendiente).TotalSeconds

            if ($edad -ge $EsperaCambios) {
                try {
                    $resultado = Preparar-Multimedia `
                        -Archivos $archivos `
                        -Config $Config `
                        -Ancho $ancho `
                        -Alto $alto

                    $ultimosPreparados = @($resultado.Listos)
                    $ultimoConteoOriginales = $archivos.Count
                    $ultimoConteoErrores = @($resultado.Errores).Count
                    $ultimoAncho = $ancho
                    $ultimoAlto = $alto

                    Guardar-Estado `
                        -EstadoGeneral 'LISTO' `
                        -Originales $ultimoConteoOriginales `
                        -Preparados $ultimosPreparados.Count `
                        -Errores $ultimoConteoErrores `
                        -Ancho $ancho `
                        -Alto $alto `
                        -Detalle $(if ($ultimoConteoErrores -gt 0) { "$ultimoConteoErrores archivo(s) fueron omitidos; revise registro.log." } else { 'Multimedia normalizada correctamente.' })

                    Iniciar-Vlc `
                        -ArchivosPreparados $ultimosPreparados `
                        -Config $Config `
                        -CantidadPantallas $cantidadPantallas

                    $cambioPendiente = $null
                    $ultimoIntentoVlc = Get-Date
                }
                catch {
                    $detalle = $_.Exception.Message
                    Escribir-Log "ERROR AL PREPARAR MULTIMEDIA: $detalle"

                    Guardar-Estado `
                        -EstadoGeneral 'ERROR' `
                        -Originales $archivos.Count `
                        -Preparados 0 `
                        -Errores 1 `
                        -Ancho $ancho `
                        -Alto $alto `
                        -Detalle $detalle

                    $cambioPendiente = $null
                    $ultimoIntentoVlc = Get-Date
                }
            }
        }
        elseif (-not (Esta-Vlc-Activo)) {
            if (((Get-Date) - $ultimoIntentoVlc).TotalSeconds -ge 5) {
                Escribir-Log 'VLC de anuncios no está activo. Se intenta reiniciar.'

                Iniciar-Vlc `
                    -ArchivosPreparados $ultimosPreparados `
                    -Config $Config `
                    -CantidadPantallas $cantidadPantallas

                $ultimoIntentoVlc = Get-Date
            }
        }

        Start-Sleep -Seconds $Intervalo
    }
}
catch {
    Escribir-Log "ERROR FATAL DEL CONTROLADOR: $($_.Exception.Message)"
    Guardar-Estado -EstadoGeneral 'ERROR_FATAL' -Detalle $_.Exception.Message
}
finally {
    Detener-Vlc

    try {
        [Casa_Elida_Power_v31]::Restaurar() | Out-Null
    }
    catch {}

    Remove-Item -LiteralPath $ControllerPidPath -Force -ErrorAction SilentlyContinue

    try {
        if ($mutex) {
            $mutex.ReleaseMutex()
            $mutex.Dispose()
        }
    }
    catch {}
}
