# Changelog

## 3.4.0

- Added one compact Spanish menu with Start, Stop, and Status; preserved the three existing shortcuts.
- Added clearer status and guidance for preparation, empty media, partial failures, missing monitor, and stale state.
- Protected process stop operations against reused or unrelated PIDs.
- Made state updates atomic and added a controller heartbeat.
- Verified FFmpeg downloads before interrupting an existing installation.
- Expanded Windows PowerShell 5.1 CI tests and release package checks.

## 3.3.0

- Added VLC `--video-on-top`.
- Added `SiempreEncimaVlc` configuration flag, enabled by default.
- Added `Siempre encima: ACTIVADO` to the Spanish STATUS TUI.
- Added a Git-ready development repository structure.
- Added Windows PowerShell 5.1 syntax validation.
- Added invariant tests for safety-critical signage behavior.
- Added a reproducible release builder and Windows CI workflow.
- Documented that explicit VLC minimization is not yet auto-recovered.

## 3.2.0

- Fixed a Windows PowerShell 5.1 parser error caused by an interpolated variable immediately followed by `:`.
- Added pre-install syntax validation.

## 3.1.0

- Hardened controller startup and error diagnostics.
- Added a launcher wrapper and startup-error logging.

## 3.0.0

- Introduced FFmpeg/FFprobe media normalization.
- Added normalized private cache before VLC playback.
- Added Direct3D9 + software decoding compatibility path.
