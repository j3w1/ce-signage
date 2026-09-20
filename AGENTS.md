# AGENTS.md

## Project
`ce-signage` is the Windows 10 cashier-PC digital-signage system for Casa Elida.

## Target environment
- Windows 10.
- Windows PowerShell 5.1 is the compatibility baseline.
- VLC desktop is the presentation engine.
- FFmpeg/FFprobe normalize user-supplied media before VLC receives it.
- Default cashier account: `windows`.
- Media drop folder: `C:\Users\windows\Desktop\anuncios`.
- Installed runtime: `C:\ProgramData\Casa Elida\Anuncios`.

## Non-negotiable behavior
1. Never modify originals inside `C:\Users\windows\Desktop\anuncios`.
2. Normalize into the private cache before playback.
3. Monitor 1 must remain usable by the cashier.
4. Monitor 2 is the signage display.
5. If monitor 2 disappears, do not move signage onto monitor 1.
6. Images display for 10 seconds by default.
7. Videos play for their full duration.
8. Audio is always disabled.
9. Playback is randomized and loops forever.
10. Invalid/corrupt media must be skipped without stopping valid ads.
11. Folder additions, replacements, and deletions are detected automatically.
12. Normal cashier START/STOP/STATUS controls must not require elevation.
13. Preserve the exact user-facing brand spelling `Casa Elida`. Never use `CasaElida`.
14. Runtime UI and cashier-facing messages are Spanish.
15. VLC must include `--video-on-top` while `SiempreEncimaVlc` is enabled.
16. Keep software decoding and the Direct3D9 compatibility path unless a tested migration replaces it.

## PowerShell rules
- Code must parse and run under Windows PowerShell 5.1.
- Do not use PowerShell 7-only syntax (`??`, `?.`, ternary operator, etc.).
- Be careful with interpolated variables followed by `:`. Prefer `-f` formatting or `${name}`.
- Do not rely on signed coercion for Win32 `uint` flags such as `0x80000000`.
- Paths contain spaces. Prefer robust argument construction / EncodedCommand.
- Do not introduce interactive prompts into automatic startup paths.
- Runtime failures should be logged, not displayed as disruptive dialogs.

## Media pipeline
Original file -> detect -> debounce -> FFmpeg/FFprobe -> normalized cache -> shuffled M3U8 -> VLC -> monitor 2.

## Required validation before completing a change
Run on Windows:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Validate-PowerShell.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Invariants.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Control-Logic.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Build-Release.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Release.ps1 -OutputDirectory .\release
```

Do not claim a Windows runtime behavior is verified unless it has actually been tested on the cashier PC or CI.

## Versioning
- `VERSION` is the source of truth.
- Update `CHANGELOG.md` for behavior changes.
- Keep the deployable files under `package/`.
- `tools/Build-Release.ps1` creates the distributable ZIP under `release/`.

## Current known gap
`--video-on-top` prevents ordinary windows from covering VLC, but it does not stop a user from manually minimizing VLC. A window-state/fullscreen watchdog is planned; do not claim it already exists.
