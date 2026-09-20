# v3.4 code review

The imported v3.3 source was reviewed before this refactor. This note records the concrete findings and their treatment.

| Finding | v3.4 treatment |
| --- | --- |
| PID files contained only a number, so a reused PID could select another PowerShell or VLC process. | Record process start time; verify name and start time before stopping. Legacy files use their modification time as a conservative bound. |
| Status could silently use missing or malformed state data and report a healthy looking system. | Parse and classify configuration/state explicitly; write state atomically and refresh a heartbeat. |
| A 110-column banner and forced window size crowded smaller cashier consoles. | Use a compact normal console menu and actionable status, with the three existing shortcuts retained. |
| FFmpeg download happened after the installer stopped and removed the prior runtime. | Download, verify SHA-256, and extract before stopping the installed version. |

## Remaining runtime acceptance

Windows CI checks PowerShell 5.1 syntax, logic, and release contents. It cannot show that VLC is visible on the physical second monitor, that the cashier keeps control of monitor 1, or that a specific media file decodes. Perform the Windows 10 dual-monitor checks in `DEVELOPMENT.md` before installing the update on the cashier PC. Explicit minimization recovery remains on the roadmap.
