# Troubleshooting

Open `ANUNCIOS.cmd` and choose **3 Detailed status and notices**. Administrator access is not required.

| Status | Action |
| --- | --- |
| Second monitor disconnected | Turn on the signage monitor and confirm Windows is using Extend mode. |
| Preparing ads | Allow FFmpeg to finish; large videos can take time. |
| No ads ready | Add supported media to the `anuncios` folder. |
| Playing with notices | Some files were skipped; read the latest notices and replace damaged media. |
| VLC inactive | The controller retries. Contact the administrator if it persists. |
| Configuration or state unavailable | Contact the administrator; inspect `config.json`, `estado.json`, and `registro.log` in the installed folder. |
| FFmpeg verification failed | The existing installation stays in place. Check connectivity and retry the installer. |

A black image over VNC does not establish that the physical display is black. Check the monitor directly. Manually minimizing VLC still needs intervention; the watchdog is planned.
