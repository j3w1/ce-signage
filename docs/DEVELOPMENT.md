# Development

## Compatibility target

Use Windows PowerShell 5.1 as the source compatibility target even if development happens from a newer shell or another OS.

The production PC is Windows 10.

## Local workflow

1. Edit files under `package/`.
2. Update `VERSION` and `CHANGELOG.md` when behavior changes.
3. Run:
   ```powershell
   .\tests\Validate-PowerShell.ps1
   .\tests\Test-Invariants.ps1
   .\tools\Build-Release.ps1
   ```
4. Install the generated package on a test/cashier Windows 10 machine.
5. Test monitor 1 remains usable.
6. Test monitor 2 playback.
7. Test add/replace/delete media without restarting.
8. Test invalid media is skipped.
9. Test STOP/START/STATUS.
10. Test reboot/login autostart.

## Codex

`AGENTS.md` contains the constraints Codex should follow.

A useful first Codex task is:

> Read AGENTS.md, README.md, docs/ARCHITECTURE.md and package/sistema/Casa Elida - Anuncios.ps1. Explain the runtime lifecycle and list any Windows PowerShell 5.1 compatibility risks. Do not modify files.

## Do not vendor FFmpeg or VLC

Keep the Git repository source-only. The installer obtains FFmpeg and detects VLC from the machine.

## Encoding

PowerShell files should stay UTF-8 with BOM because the runtime UI contains Spanish text and targets Windows PowerShell 5.1.
