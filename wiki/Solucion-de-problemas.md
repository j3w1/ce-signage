# Solución de problemas

Abra `ANUNCIOS.cmd` y elija **3 Ver estado y avisos**. No se necesita elevación.

| Estado | Acción |
| --- | --- |
| Segunda pantalla desconectada | Encienda el monitor de anuncios y confirme el modo Extender en Windows. |
| Preparando anuncios | Espere a que FFmpeg termine; videos grandes pueden tardar. |
| Sin anuncios listos | Copie archivos compatibles a la carpeta `anuncios`. |
| Reproduciendo con avisos | Algunos archivos se omitieron; revise los últimos avisos y sustituya el archivo dañado. |
| VLC no está activo | El controlador volverá a intentar. Si persiste, avise al administrador. |
| Configuración o estado no disponible | Avise al administrador; consulte `config.json`, `estado.json` y `registro.log` en la carpeta instalada. |
| Falló la verificación de FFmpeg | No interrumpa la versión instalada; revise la conexión y vuelva a ejecutar el instalador. |

Una pantalla negra vista por VNC no prueba que el monitor físico esté negro. Verifique el monitor directamente. Minimizar VLC manualmente aún requiere intervención: el watchdog está pendiente.
