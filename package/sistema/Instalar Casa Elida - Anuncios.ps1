$ErrorActionPreference = 'Stop'
$SourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $SourceDir 'Identidad de Procesos.ps1')
. (Join-Path $SourceDir 'Verificar Descarga.ps1')

$TaskName = 'Casa Elida - Anuncios'
$InstallDir = 'C:\ProgramData\Casa Elida\Anuncios'
$CashierUserName = 'windows'
$MediaFolder = 'C:\Users\windows\Desktop\anuncios'
$ToolsDir = Join-Path $InstallDir 'herramientas'
$FfmpegDir = Join-Path $ToolsDir 'ffmpeg'
$FfmpegPath = Join-Path $FfmpegDir 'ffmpeg.exe'
$FfprobePath = Join-Path $FfmpegDir 'ffprobe.exe'

$LegacyTaskNames = @(
    'Casa Elida Signage',
    'Casa Elida - Anuncios'
)

$LegacyInstallDirs = @(
    (Join-Path $env:ProgramData (('Casa' + 'Elida') + '\Signage')),
    'C:\ProgramData\Casa Elida\Anuncios'
)

function Es-Administrador {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Probar-SintaxisPowerShell {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Archivos
    )

    $hayErrores = $false

    foreach ($archivo in $Archivos) {
        if (-not (Test-Path -LiteralPath $archivo)) {
            Write-Host "ERROR: Falta el archivo: $archivo" -ForegroundColor Red
            $hayErrores = $true
            continue
        }

        $tokens = $null
        $errores = $null

        [void][System.Management.Automation.Language.Parser]::ParseFile(
            $archivo,
            [ref]$tokens,
            [ref]$errores
        )

        if ($errores -and $errores.Count -gt 0) {
            $hayErrores = $true
            Write-Host ''
            Write-Host "ERROR DE SINTAXIS: $archivo" -ForegroundColor Red

            foreach ($errorSintaxis in $errores) {
                $linea = $errorSintaxis.Extent.StartLineNumber
                $columna = $errorSintaxis.Extent.StartColumnNumber
                Write-Host ("  Línea {0}, columna {1}: {2}" -f $linea, $columna, $errorSintaxis.Message) -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "Sintaxis OK: $(Split-Path -Leaf $archivo)" -ForegroundColor Green
        }
    }

    if ($hayErrores) {
        throw 'La instalación se detuvo porque uno o más scripts contienen errores de sintaxis.'
    }
}

function Buscar-Vlc {
    $candidatos = @()

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

function Detener-Instalacion {
    param(
        [string]$NombreTarea,
        [string]$Carpeta
    )

    try { Stop-ScheduledTask -TaskName $NombreTarea -ErrorAction SilentlyContinue } catch {}
    Start-Sleep -Milliseconds 300

    foreach ($archivoPid in @(
        (Join-Path $Carpeta 'vlc.pid'),
        (Join-Path $Carpeta 'controlador.pid'),
        (Join-Path $Carpeta 'controller.pid')
    )) {
        $nombre = if ($archivoPid -like '*vlc.pid') { 'vlc' } else { 'powershell' }
        $proceso = Obtener-ProcesoControlado -ArchivoPid $archivoPid -NombreEsperado $nombre
        if ($proceso) {
            try { Stop-Process -Id $proceso.Id -Force -ErrorAction Stop }
            catch { throw "No se pudo detener $nombre (PID $($proceso.Id))." }
        }
        elseif (Test-Path -LiteralPath $archivoPid) {
            Write-Host "Aviso: PID no verificable en $archivoPid; no se detendrá otro proceso." -ForegroundColor Yellow
        }
    }

    try {
        Unregister-ScheduledTask -TaskName $NombreTarea -Confirm:$false -ErrorAction SilentlyContinue
    }
    catch {}
}

function Preparar-Ffmpeg {
    if ((Test-Path -LiteralPath $FfmpegPath) -and (Test-Path -LiteralPath $FfprobePath)) {
        Write-Host 'FFmpeg ya está disponible.' -ForegroundColor Green
        return $null
    }

    Write-Host 'Descargando y verificando FFmpeg antes de detener la versión instalada...' -ForegroundColor Cyan
    $tempRoot = Join-Path $env:TEMP ('Casa-Elida-FFmpeg-' + [Guid]::NewGuid().ToString('N'))
    $zipPath = Join-Path $tempRoot 'ffmpeg.zip'
    $hashPath = Join-Path $tempRoot 'ffmpeg.sha256'
    $extractDir = Join-Path $tempRoot 'extraido'
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $url = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zipPath -ErrorAction Stop
        Invoke-WebRequest -UseBasicParsing -Uri ($url + '.sha256') -OutFile $hashPath -ErrorAction Stop
        Confirmar-Sha256 -Archivo $zipPath -ArchivoSha256 $hashPath

        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force
        $ffmpeg = Get-ChildItem -LiteralPath $extractDir -Filter 'ffmpeg.exe' -File -Recurse | Select-Object -First 1
        $ffprobe = Get-ChildItem -LiteralPath $extractDir -Filter 'ffprobe.exe' -File -Recurse | Select-Object -First 1
        if (-not $ffmpeg -or -not $ffprobe) { throw 'La descarga no contiene FFmpeg y FFprobe.' }
        return [pscustomobject]@{ TempRoot = $tempRoot; BinDir = (Split-Path -Parent $ffmpeg.FullName) }
    }
    catch {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        throw
    }
}

function Copiar-FfmpegPreparado {
    param([object]$Preparado)
    if (-not $Preparado) { return }
    New-Item -ItemType Directory -Path $FfmpegDir -Force | Out-Null
    foreach ($nombre in @('ffmpeg.exe', 'ffprobe.exe')) {
        Copy-Item -LiteralPath (Join-Path $Preparado.BinDir $nombre) -Destination (Join-Path $FfmpegDir $nombre) -Force
    }
    Get-ChildItem -LiteralPath $Preparado.BinDir -Filter '*.dll' -File -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $FfmpegDir -Force
    }
}

if (-not (Es-Administrador)) {
    Write-Host ''
    Write-Host 'ERROR: Ejecute INSTALAR O ACTUALIZAR.cmd y acepte el aviso de Windows.' -ForegroundColor Red
    exit 1
}

$cuenta = Get-CimInstance Win32_UserAccount -Filter "LocalAccount=True AND Name='$CashierUserName'" -ErrorAction SilentlyContinue

if (-not $cuenta) {
    Write-Host ''
    Write-Host "ERROR: No se encontró la cuenta local '$CashierUserName'." -ForegroundColor Red
    Write-Host "Esta instalación está preparada para $MediaFolder"
    exit 1
}

$CashierUserId = "$env:COMPUTERNAME\$CashierUserName"

$vlcPath = Buscar-Vlc

if (-not $vlcPath) {
    Write-Host ''
    Write-Host 'ERROR: VLC Media Player no está instalado.' -ForegroundColor Red
    Write-Host 'Instale VLC de escritorio de 64 bits y vuelva a ejecutar el instalador.'
    exit 1
}

$ControllerSource = Join-Path $SourceDir 'Casa Elida - Anuncios.ps1'
$LauncherSource = Join-Path $SourceDir 'Lanzador Casa Elida - Anuncios.ps1'
$ControlSource = Join-Path $SourceDir 'Control de Anuncios.ps1'
$IdentitySource = Join-Path $SourceDir 'Identidad de Procesos.ps1'
$StatusSource = Join-Path $SourceDir 'Estado de Anuncios.ps1'
$HashSource = Join-Path $SourceDir 'Verificar Descarga.ps1'

foreach ($archivo in @($ControllerSource, $LauncherSource, $ControlSource, $IdentitySource, $StatusSource, $HashSource)) {
    if (-not (Test-Path -LiteralPath $archivo)) {
        throw "Falta un archivo del paquete: $archivo"
    }
}


Write-Host ''
Write-Host 'Validando sintaxis de los scripts antes de instalar...' -ForegroundColor Cyan
Probar-SintaxisPowerShell -Archivos @(
    $ControllerSource,
    $LauncherSource,
    $ControlSource,
    $IdentitySource,
    $StatusSource,
    $HashSource
)

Write-Host ''
Write-Host 'CASA ELIDA - ANUNCIOS v3.4'
Write-Host '=========================='
Write-Host ''
Write-Host 'Instalando / actualizando...' -ForegroundColor Cyan

$ffmpegPreparado = Preparar-Ffmpeg

try {
# Detiene instalaciones previas sin tocar la carpeta de anuncios.
foreach ($nombreTarea in $LegacyTaskNames) {
    foreach ($carpeta in $LegacyInstallDirs) {
        Detener-Instalacion -NombreTarea $nombreTarea -Carpeta $carpeta
    }
}

# Conserva herramientas descargadas de una instalación v3 previa.
$herramientasTemporales = $null
if (Test-Path -LiteralPath $ToolsDir) {
    $herramientasTemporales = Join-Path $env:TEMP ('Casa-Elida-Tools-' + [Guid]::NewGuid().ToString('N'))
    Copy-Item -LiteralPath $ToolsDir -Destination $herramientasTemporales -Recurse -Force -ErrorAction SilentlyContinue
}

if (Test-Path -LiteralPath $InstallDir) {
    Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
New-Item -ItemType Directory -Path $MediaFolder -Force | Out-Null

if ($herramientasTemporales -and (Test-Path -LiteralPath $herramientasTemporales)) {
    Copy-Item -LiteralPath $herramientasTemporales -Destination $ToolsDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $herramientasTemporales -Recurse -Force -ErrorAction SilentlyContinue
}

Copy-Item -LiteralPath $ControllerSource -Destination (Join-Path $InstallDir 'Casa Elida - Anuncios.ps1') -Force
Copy-Item -LiteralPath $LauncherSource -Destination (Join-Path $InstallDir 'Lanzador Casa Elida - Anuncios.ps1') -Force
Copy-Item -LiteralPath $ControlSource -Destination (Join-Path $InstallDir 'Control de Anuncios.ps1') -Force
Copy-Item -LiteralPath $IdentitySource -Destination (Join-Path $InstallDir 'Identidad de Procesos.ps1') -Force
Copy-Item -LiteralPath $StatusSource -Destination (Join-Path $InstallDir 'Estado de Anuncios.ps1') -Force
Copy-Item -LiteralPath $HashSource -Destination (Join-Path $InstallDir 'Verificar Descarga.ps1') -Force

Copiar-FfmpegPreparado -Preparado $ffmpegPreparado

$config = [ordered]@{
    CarpetaMultimedia = $MediaFolder
    RutaVlc = $vlcPath
    RutaFfmpeg = $FfmpegPath
    RutaFfprobe = $FfprobePath
    IndicePantallaVlc = 1
    DuracionImagenSegundos = 10
    EsperaInicialSegundos = 10
    IntervaloRevisionSegundos = 5
    EsperaCambiosSegundos = 8

    # Direct3D9 + decodificación por software prioriza estabilidad sobre
    # aceleración GPU. La resolución del monitor de anuncios es baja,
    # por lo que no necesitamos DXVA/D3D11VA.
    SalidaVideoVlc = 'direct3d9'

    # v3.3: VLC mantiene el video por encima de otras ventanas.
    SiempreEncimaVlc = $true

    ExtensionesImagen = @(
        '.jpg', '.jpeg', '.jfif', '.png', '.bmp',
        '.gif', '.webp', '.tif', '.tiff'
    )

    ExtensionesVideo = @(
        '.mp4', '.avi', '.mov', '.mkv', '.wmv', '.m4v',
        '.webm', '.mpg', '.mpeg', '.ts', '.mts', '.m2ts',
        '.flv', '.3gp', '.ogv', '.vob'
    )
}

$config | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $InstallDir 'config.json') -Encoding UTF8

Add-Type -AssemblyName System.Drawing
$blankPath = Join-Path $InstallDir 'negro.png'
$bitmap = New-Object System.Drawing.Bitmap 64,64
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)

try {
    $graphics.Clear([System.Drawing.Color]::Black)
    $bitmap.Save($blankPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $graphics.Dispose()
    $bitmap.Dispose()
}

# El usuario de caja necesita escribir cache, lista, estado y registro.
& icacls.exe $InstallDir /grant "${CashierUserId}:(OI)(CI)M" /T /C | Out-Null

$PowerShellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$LauncherInstalled = Join-Path $InstallDir 'Lanzador Casa Elida - Anuncios.ps1'

# Use EncodedCommand so Task Scheduler never has to parse a quoted script path
# containing spaces.
$comandoTarea = "& '$LauncherInstalled'"
$bytesTarea = [System.Text.Encoding]::Unicode.GetBytes($comandoTarea)
$encodedTarea = [Convert]::ToBase64String($bytesTarea)
$argumentosAccion = "-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $encodedTarea"

$action = New-ScheduledTaskAction -Execute $PowerShellExe -Argument $argumentosAccion
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $CashierUserId
$principal = New-ScheduledTaskPrincipal -UserId $CashierUserId -LogonType Interactive -RunLevel Limited

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit ([TimeSpan]::Zero)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description 'Casa Elida - anuncios normalizados y reproducidos en la segunda pantalla de caja.' `
    -Force | Out-Null

Write-Host ''
Write-Host 'INSTALACIÓN COMPLETADA.' -ForegroundColor Green
Write-Host ''
Write-Host "Usuario de caja:        $CashierUserId"
Write-Host "Carpeta de anuncios:    $MediaFolder"
Write-Host "Sistema instalado en:   $InstallDir"
Write-Host "VLC:                    $vlcPath"
Write-Host "FFmpeg:                 $FfmpegPath"
Write-Host 'Pantalla VLC:            índice 1 (segunda pantalla)'
Write-Host 'Imágenes:                10 segundos'
Write-Host 'Videos:                   duración completa'
Write-Host 'Audio:                    desactivado'
Write-Host 'Orden:                    aleatorio'
Write-Host 'VLC video output:         Direct3D9'
Write-Host 'Aceleración de video:     desactivada'
Write-Host 'Normalización:            activa (resolución exacta del monitor)'
Write-Host 'Siempre encima:           activado (--video-on-top)'
Write-Host 'Lanzador v3.4:            diagnóstico de arranque activado'
Write-Host ''

try {
    Start-ScheduledTask -TaskName $TaskName
    Write-Host 'Los anuncios se están iniciando.' -ForegroundColor Cyan
    Write-Host 'La primera preparación de videos puede tardar un poco más.' -ForegroundColor DarkGray
}
catch {
    Write-Host 'La tarea quedó instalada y se iniciará al próximo inicio de sesión.' -ForegroundColor Yellow
}

}
finally {
    if ($ffmpegPreparado) {
        Remove-Item -LiteralPath $ffmpegPreparado.TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
