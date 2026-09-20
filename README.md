# ce-signage

Casa Elida digital signage for Windows 10 cashier PCs.

The project turns `C:\Users\windows\Desktop\anuncios` into an automatically managed advertising source for the cashier PC's second monitor. Cashiers drop images/videos into the folder; the controller detects changes, validates and normalizes media with FFmpeg, rebuilds a randomized playlist, and runs VLC fullscreen on monitor 2.

## v3.3

v3.3 adds VLC `--video-on-top`.

That means the signage video window is configured to remain above ordinary windows on the second display. This reduces accidental coverage by other applications.

It does **not** yet detect or recover from a user explicitly minimizing VLC. See `docs/ROADMAP.md`.

## Runtime architecture

```text
C:\Users\windows\Desktop\anuncios
                |
                v
       folder polling/debounce
                |
                v
         FFmpeg / FFprobe
                |
                v
C:\ProgramData\Casa Elida\Anuncios\cache
                |
                v
       randomized M3U8 playlist
                |
                v
 VLC: fullscreen + muted + Direct3D9
      + software decode + video-on-top
                |
                v
             Monitor 2
```

Original advertisement files are never modified.

## Repository layout

```text
ce-signage/
├─ AGENTS.md
├─ README.md
├─ CHANGELOG.md
├─ VERSION
├─ package/                       # deployable Windows package
│  ├─ INSTALAR O ACTUALIZAR.cmd
│  ├─ DESINSTALAR.cmd
│  ├─ CONTROLES PARA ESCRITORIO/
│  └─ sistema/
├─ docs/
├─ tests/
├─ tools/
└─ .github/workflows/
```

## Develop with Codex

Open the repository root in your development environment. Codex should read `AGENTS.md` before making changes.

Recommended first commands on Windows:

```powershell
git status
Get-Content .\AGENTS.md
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Validate-PowerShell.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Invariants.ps1
```

## Build a release

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Build-Release.ps1
```

Output:

```text
release\Casa Elida - Anuncios v3.3.0.zip
```

## Install on the cashier PC

Use the generated package or the checked-in `package/` directory and run:

```text
INSTALAR O ACTUALIZAR.cmd
```

The installer preserves:

```text
C:\Users\windows\Desktop\anuncios
```

## GitHub

This repository is intentionally Git-ready but does not contain a `.git` directory.

Typical first setup:

```powershell
git init
git add .
git commit -m "Initial Casa Elida signage v3.3"
git branch -M main
```

Then create the GitHub repository and add its remote when ready.
