# Troubleshooting

## STATUS first

Run:

```text
STATUS ANUNCIOS.cmd
```

The TUI reports:
- second display;
- original media count;
- normalized media count;
- rejected media count;
- FFmpeg availability;
- VLC output mode;
- video-on-top status;
- controller process;
- VLC process;
- scheduled-task state.

## Logs

```text
C:\ProgramData\Casa Elida\Anuncios\registro.log
C:\ProgramData\Casa Elida\Anuncios\arranque.log
C:\ProgramData\Casa Elida\Anuncios\arranque-error.log
```

## VLC is black

The normal path should avoid most black-screen cases because:
- images/videos are normalized before VLC;
- VLC uses software decoding;
- VLC uses Direct3D9.

If it still occurs, preserve the original media and collect:
- STATUS output;
- recent `registro.log`;
- graphics adapter/driver information;
- whether the normalized cached file plays when opened manually.

## VLC is minimized

v3.3 does not yet auto-detect a minimized VLC window.

`--video-on-top` only keeps a visible VLC video window above ordinary windows.

Use `START ANUNCIOS` as the current manual recovery path. See the roadmap for the planned window-state watchdog.
