# Roadmap

## Next: window-state watchdog

High priority.

Detect whether the signage VLC window is:
- minimized;
- no longer fullscreen;
- moved away from monitor 2;
- hidden/covered in a way `--video-on-top` does not solve.

Desired recovery:
1. confirm signage VLC PID;
2. inspect the top-level window belonging to that PID;
3. detect minimized/lost-fullscreen/wrong-monitor state;
4. restore or restart only the signage VLC process;
5. return fullscreen to monitor 2;
6. avoid stealing focus from the cashier on monitor 1;
7. rate-limit recovery to avoid loops.

Likely Windows APIs:
- `EnumWindows`
- `GetWindowThreadProcessId`
- `IsIconic`
- `GetWindowRect`
- `ShowWindow`
- `SetWindowPos`

## Later

- Configurable media duration by sidecar metadata.
- Optional admin-only settings TUI.
- Health export for remote monitoring.
- Signed release/checksum workflow.
- Optional Windows installer/MSI after the PowerShell implementation stabilizes.
- Structured event logs / metrics.
- Automated integration test harness for a dual-monitor Windows VM where feasible.
