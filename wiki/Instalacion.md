# Instalación

**Para administradores.** Se necesita Windows 10, una cuenta local `windows`, VLC de escritorio y dos monitores en modo **Extender estas pantallas**. La pantalla 1 es la principal de caja; la pantalla 2 muestra anuncios. El instalador necesita acceso a Internet para descargar FFmpeg y verificar su SHA-256.

1. Descargue el ZIP de la ejecución correcta de [Windows PowerShell 5.1](https://github.com/j3w1/ce-signage/actions) o genere el paquete con `tools/Build-Release.ps1`.
2. Extraiga el ZIP y ejecute `INSTALAR O ACTUALIZAR.cmd` como administrador. Mantenga VLC instalado.
3. Copie `CONTROLES PARA ESCRITORIO\ANUNCIOS.cmd` al escritorio de `windows`. Puede copiar también los tres accesos anteriores.
4. Compruebe en la máquina: pantalla 1 libre, VLC en pantalla 2, archivos nuevos/reemplazados/borrados, archivos corruptos, silencio, los cuatro controles y arranque tras iniciar sesión.

La instalación no borra `C:\Users\windows\Desktop\anuncios`. El runtime se instala en `C:\ProgramData\Casa Elida\Anuncios`. El comando `DESINSTALAR.cmd` quita el runtime y conserva los anuncios originales.

CI verifica sintaxis, lógica y contenido del ZIP; las pruebas físicas de los monitores y VLC requieren el PC de caja.
