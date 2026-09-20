# Architecture

## Objective

A cashier should only need to copy or delete media under:

```text
C:\Users\windows\Desktop\anuncios
```

Everything else is automatic.

## Components

### Controller
`package/sistema/Casa Elida - Anuncios.ps1`

Long-running process that:
- checks the media folder at a fixed interval;
- detects add/change/delete operations;
- debounces file copies;
- detects the second display;
- normalizes media;
- maintains the cache;
- creates the randomized playlist;
- starts/restarts VLC;
- prevents Windows display sleep while signage is active.

### Launcher
`package/sistema/Lanzador Casa Elida - Anuncios.ps1`

Wraps controller startup and persists startup diagnostics.

### Control TUI
`package/sistema/Control de Anuncios.ps1`

Spanish cashier/admin interface used by:
- `START ANUNCIOS.cmd`
- `STOP ANUNCIOS.cmd`
- `STATUS ANUNCIOS.cmd`

### Installer
`package/sistema/Instalar Casa Elida - Anuncios.ps1`

Installs the runtime under:

```text
C:\ProgramData\Casa Elida\Anuncios
```

and registers the scheduled task:

```text
Casa Elida - Anuncios
```

### FFmpeg
Downloaded at installation time. It is not committed to the repository.

Images are normalized to RGB PNG at the signage-monitor resolution.

Videos are normalized to H.264/yuv420p MP4, 30 fps, no audio, at the signage-monitor resolution.

### VLC
Receives only normalized media.

Important launch characteristics:
- fullscreen;
- second display;
- no audio;
- no OSD/title/controller;
- software decode;
- Direct3D9 output;
- randomized loop;
- `--video-on-top`.

## Safety boundaries

The controller must never:
- rewrite an original ad;
- move signage to monitor 1 when monitor 2 disappears;
- stop all playback because one file is corrupt;
- require cashier elevation for START/STOP/STATUS.
