# Installation

**For administrators.** Requirements: Windows 10, a local `windows` account, desktop VLC, and two displays in **Extend these displays** mode. Monitor 1 is the cashier's primary display; monitor 2 shows signage. The installer needs Internet access to download FFmpeg and verify its SHA-256.

1. Download the ZIP from a successful [Windows PowerShell 5.1 workflow](https://github.com/j3w1/ce-signage/actions), or build it with `tools/Build-Release.ps1`.
2. Extract the ZIP and run `INSTALAR O ACTUALIZAR.cmd` as administrator. Keep VLC installed.
3. Copy `CONTROLES PARA ESCRITORIO\ANUNCIOS.cmd` to the `windows` desktop. You may also copy the three existing shortcuts.
4. On the cashier PC, check that monitor 1 stays usable, VLC plays on monitor 2, added/replaced/deleted files update, corrupt files are skipped, audio stays muted, all four controls work, and playback starts after login.

Installation preserves `C:\Users\windows\Desktop\anuncios`. The runtime lives in `C:\ProgramData\Casa Elida\Anuncios`. `DESINSTALAR.cmd` removes the runtime while retaining original ads.

CI validates syntax, logic, and ZIP contents. Physical display and VLC behavior require testing on the cashier PC.
