function Resolver-EstadoAnuncios {
    param([Parameter(Mandatory = $true)][object]$Datos)

    $codigo = 'FUNCIONANDO'
    $titulo = 'Anuncios en reproducción'
    $paso = 'Puede agregar o quitar anuncios en la carpeta del escritorio.'
    $color = 'Green'

    if (-not $Datos.Instalado) {
        $codigo = 'NO_INSTALADO'; $titulo = 'Sistema no instalado'
        $paso = 'Avise al administrador para instalar Casa Elida - Anuncios.'; $color = 'Red'
    }
    elseif (-not $Datos.ConfigValida) {
        $codigo = 'CONFIG_ERROR'; $titulo = 'Configuración no disponible'
        $paso = 'Avise al administrador. Revise config.json.'; $color = 'Red'
    }
    elseif (-not $Datos.SegundaPantalla) {
        $codigo = 'SIN_PANTALLA'; $titulo = 'Segunda pantalla desconectada'
        $paso = 'Encienda o conecte el monitor de anuncios.'; $color = 'Red'
    }
    elseif (-not $Datos.Controlador) {
        $codigo = 'DETENIDO'; $titulo = 'Anuncios detenidos'
        $paso = 'Use Iniciar para volver a reproducir anuncios.'; $color = 'Yellow'
    }
    elseif ($Datos.EstadoPreparacion -match '^ERROR') {
        $codigo = 'ERROR'; $titulo = 'Error al preparar anuncios'
        $paso = 'Revise los avisos o contacte al administrador.'; $color = 'Red'
    }
    elseif (-not $Datos.EstadoValido) {
        $codigo = 'SIN_ESTADO'; $titulo = 'Estado no disponible'
        $paso = 'Espere un momento; si persiste, revise los avisos.'; $color = 'Yellow'
    }
    elseif ($Datos.EstadoPreparacion -eq 'PREPARANDO') {
        $codigo = 'PREPARANDO'; $titulo = 'Preparando anuncios'
        $paso = 'Espere a que termine la conversión de imágenes y videos.'; $color = 'Cyan'
    }
    elseif ($Datos.EstadoActualizado -and ((Get-Date) - $Datos.EstadoActualizado).TotalSeconds -gt 30) {
        $codigo = 'ESTADO_ANTIGUO'; $titulo = 'Estado sin actualizar'
        $paso = 'Revise el controlador y los avisos del sistema.'; $color = 'Yellow'
    }
    elseif (-not $Datos.Vlc) {
        $codigo = 'ESPERANDO_VLC'; $titulo = 'VLC no está activo'
        $paso = 'El controlador reintentará. Revise avisos si persiste.'; $color = 'Yellow'
    }
    elseif ($Datos.ArchivosPreparados -eq 0) {
        $codigo = 'SIN_ANUNCIOS'; $titulo = 'Sin anuncios listos'
        $paso = 'Copie imágenes o videos a la carpeta de anuncios.'; $color = 'Yellow'
    }
    elseif ($Datos.ArchivosConError -gt 0) {
        $codigo = 'PARCIAL'; $titulo = 'Reproduciendo con avisos'
        $paso = 'Algunos archivos se omitieron. Revise los avisos.'; $color = 'Yellow'
    }
    elseif (-not $Datos.Ffmpeg) {
        $codigo = 'SIN_FFMPEG'; $titulo = 'Reproduciendo; falta FFmpeg'
        $paso = 'Avise al administrador antes de agregar nuevos anuncios.'; $color = 'Yellow'
    }

    return [pscustomobject]@{ Codigo = $codigo; Titulo = $titulo; Paso = $paso; Color = $color }
}
