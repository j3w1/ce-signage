CASA ELIDA - ANUNCIOS v3.4
========================

CAMBIO PRINCIPAL
----------------
Esta versión YA NO entrega directamente a VLC los archivos que el personal
copia en:

    C:\Users\windows\Desktop\anuncios

Primero los normaliza a un formato seguro y uniforme.

FLUJO
-----
archivo original
    ↓
FFmpeg valida y normaliza
    ↓
cache interno de Casa Elida
    ↓
VLC reproduce únicamente archivos normalizados
    ↓
segunda pantalla

Esto evita que una imagen PNG extraña, una resolución impar, un perfil de
color, un AVI con codec antiguo, un MOV o un MP4 poco común llegue directamente
al reproductor de caja.

IMÁGENES
--------
Las imágenes se convierten a:

    PNG RGB
    resolución exacta de la segunda pantalla
    relación de aspecto conservada
    bandas negras solamente si hacen falta
    dimensiones pares

Por ejemplo, si el monitor 2 es 1366x768, todas las imágenes que VLC recibe
terminan siendo 1366x768 RGB.

VIDEOS
------
Los videos se convierten a:

    MP4
    H.264
    yuv420p
    30 fps
    resolución exacta del monitor
    sin audio
    faststart

VLC
---
VLC queda configurado por script para:

    - pantalla completa
    - segunda pantalla
    - sin título
    - sin controles
    - sin OSD
    - sin audio
    - orden aleatorio
    - loop infinito
    - decodificación de video por software
    - salida Direct3D9

La decodificación por software y Direct3D9 reducen la dependencia de
DXVA/D3D11VA y de problemas de drivers de video que pueden producir una
pantalla negra en Windows 10.

FFMPEG
------
El instalador descarga automáticamente el "release essentials" de FFmpeg
para Windows desde:

    https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip

Se guarda privadamente dentro de:

    C:\ProgramData\Casa Elida\Anuncios\herramientas\ffmpeg

No es necesario que el cajero instale ni use FFmpeg manualmente.

FORMATOS QUE SE INTENTAN NORMALIZAR
-----------------------------------
Imágenes:
    JPG, JPEG, JFIF, PNG, BMP, GIF, WEBP, TIFF

Videos:
    MP4, AVI, MOV, MKV, WMV, M4V, WEBM,
    MPG, MPEG, TS, MTS, M2TS, FLV, 3GP, OGV, VOB

Para archivos con extensión desconocida, el sistema también intenta detectar
si contienen una pista de video.

IMPORTANTE
----------
No existe un reproductor que pueda garantizar reproducción de un archivo
corrupto, incompleto o de un codec inexistente.

Si FFmpeg no puede decodificar un archivo:
    - el archivo se omite;
    - los demás anuncios siguen funcionando;
    - STATUS ANUNCIOS muestra cuántos fueron omitidos;
    - el detalle queda en:
          C:\ProgramData\Casa Elida\Anuncios\registro.log

INSTALAR / ACTUALIZAR
---------------------
1. Mantenga VLC instalado.

2. Confirme:
       Configuración > Sistema > Pantalla
       - Pantalla 1 = principal
       - Pantalla 2 = secundaria
       - Extender estas pantallas

3. Extraiga este ZIP.

4. Ejecute:
       INSTALAR O ACTUALIZAR.cmd

5. Acepte el aviso de administrador.

6. El instalador:
       - detiene la versión anterior;
       - conserva C:\Users\windows\Desktop\anuncios;
       - instala Casa Elida - Anuncios v3;
       - descarga FFmpeg si hace falta;
       - configura el inicio automático;
       - inicia el controlador.

7. La PRIMERA vez que detecta videos, puede tardar porque los transcodifica.
   Después usa cache y no repite el trabajo mientras el archivo no cambie.

CONTROLES DEL ESCRITORIO
------------------------
Copie:

    CONTROLES PARA ESCRITORIO\ANUNCIOS.cmd
    CONTROLES PARA ESCRITORIO\START ANUNCIOS.cmd
    CONTROLES PARA ESCRITORIO\STOP ANUNCIOS.cmd
    CONTROLES PARA ESCRITORIO\STATUS ANUNCIOS.cmd

a:

    C:\Users\windows\Desktop

ANUNCIOS.cmd ofrece un menú para iniciar, detener y consultar el estado.
Las tres opciones anteriores siguen disponibles.

STATUS ahora muestra:
    - segunda pantalla;
    - archivos originales;
    - archivos listos para reproducir;
    - archivos omitidos / con error;
    - resolución de normalización;
    - FFmpeg;
    - modo VLC;
    - controlador;
    - VLC;
    - inicio automático.

CACHE
-----
El cache se encuentra en:

    C:\ProgramData\Casa Elida\Anuncios\cache

El personal NO debe copiar archivos ahí.

El controlador elimina versiones antiguas del cache automáticamente.

CARPETA QUE USA EL PERSONAL
---------------------------
Siempre:

    C:\Users\windows\Desktop\anuncios

No necesitan:
    - renombrar archivos;
    - cambiar resolución;
    - convertir videos;
    - abrir VLC;
    - usar FFmpeg.

VNC
---
VNC no forma parte de la reproducción de anuncios.

VNC es una herramienta de control remoto. Para esta instalación, los anuncios
se reproducen localmente con FFmpeg + VLC. Si se usa VNC para soporte remoto,
puede existir una pantalla negra SOLO en la sesión remota dependiendo del
método de captura de VNC, aunque la pantalla física esté reproduciendo bien.

REGISTRO
--------
    C:\ProgramData\Casa Elida\Anuncios\registro.log

ESTADO INTERNO
--------------
    C:\ProgramData\Casa Elida\Anuncios\estado.json

CONFIGURACIÓN
-------------
    C:\ProgramData\Casa Elida\Anuncios\config.json

DESINSTALAR
-----------
Ejecute:

    DESINSTALAR.cmd

NO elimina:

    C:\Users\windows\Desktop\anuncios


CORRECCIÓN v3.1
---------------
v3.1 corrige el arranque del controlador en Windows PowerShell 5.1:

1. Las banderas de energía de Windows ahora se combinan dentro de C#.
   PowerShell ya no realiza la operación bit a bit sobre 0x80000000.

2. START ANUNCIOS usa EncodedCommand.
   Esto elimina problemas de comillas con rutas que contienen espacios como:
       C:\ProgramData\Casa Elida\Anuncios

3. El inicio automático también usa el mismo lanzador robusto.

4. Si el controlador falla al arrancar, se crea:
       C:\ProgramData\Casa Elida\Anuncios\arranque-error.log

5. START ANUNCIOS y STATUS ANUNCIOS muestran ese error directamente en español.
   Ya no deben limitarse a decir "Controlador: DETENIDO" sin explicar la causa.

PARA ACTUALIZAR DESDE v3
------------------------
No desinstale manualmente.

Ejecute:
    INSTALAR O ACTUALIZAR.cmd

La carpeta:
    C:\Users\windows\Desktop\anuncios

se conserva.


CORRECCIÓN v3.2
---------------
v3.2 corrige un error de sintaxis de Windows PowerShell 5.1 que ocurría en
un mensaje de estado:

    "Preparando $indice de $total: ..."

En una cadena interpolada de PowerShell, el carácter ":" inmediatamente
después de una variable puede interpretarse como parte de una referencia de
variable con ámbito/unidad.

Ahora se usa el operador de formato:

    ("Preparando {0} de {1}: {2}" -f ...)

Además, el instalador v3.2 analiza la sintaxis de los scripts con el parser
nativo de Windows PowerShell ANTES de instalarlos. Si un futuro paquete
contuviera otro error de parser, la instalación se detendrá y mostrará la
línea y columna exactas en vez de instalar un controlador que no puede iniciar.

PARA ACTUALIZAR
---------------
Ejecute:

    INSTALAR O ACTUALIZAR.cmd

No se elimina ni modifica:

    C:\Users\windows\Desktop\anuncios


CAMBIO v3.3
-----------
VLC ahora se inicia con:

    --video-on-top

y la configuración guarda:

    "SiempreEncimaVlc": true

Esto ayuda a impedir que otras ventanas abiertas en la segunda pantalla cubran
la publicidad.

IMPORTANTE:
    --video-on-top NO impide que una persona minimice VLC manualmente.

La detección y recuperación automática de una ventana minimizada o de la pérdida
de pantalla completa se deja como mejora posterior y está documentada en el
ROADMAP del repositorio de desarrollo.

STATUS ANUNCIOS ahora muestra:

    Siempre encima: ACTIVADO
