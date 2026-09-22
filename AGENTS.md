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

## CE Metadata integration

This repository joined the CE Metadata portfolio on 2026-09-22. Nothing is installed here and
nothing is imported: CE Metadata is a service that reads this repository through one GitHub App
installation, and this section is the cooperation contract an agent working in it needs.

**Right now it writes nothing here.** Being in the portfolio means this repository is read and
censused and its objects are visible. It does not mean any writer reaches them. Reviewed
classification rules may decide labels only in the repositories named by
`classification_authority.repositories` in [`policy/object-metadata.yaml`](https://github.com/j3w1/ce-metadata/blob/main/policy/object-metadata.yaml),
and the canonical label definitions are written only in the repositories named by
`coverage_repositories` in [`policy/label-management.yaml`](https://github.com/j3w1/ce-metadata/blob/main/policy/label-management.yaml).
This repository is in neither yet. Each is its own reviewed change, made once this repository's
corpus has been classified — so the first labels that appear here will have been reviewed before
they were written, not after.

**Protected CE label prefixes:** `ce-systems`, `cross-repo`, `historical-evidence`, `type:`,
`area:`, `concern:`. Labels outside them are never touched — including the ones GitHub creates by
default and the ones Dependabot applies. Within them CE Metadata is authoritative once a writer
reaches this repository: a reviewed rule states an object's whole managed label set, so a CE label
added by hand and absent from that rule is drift, and the sweep removes it.

**Do not hand-label to steer it.** An object labelled by hand to influence classification is not
configuration, it is drift the next sweep removes — and it spends a breaker budget doing so. If
the labels are wrong, the reviewed policy is wrong: report the exact object, the policy digest,
the plan and the readback, and the fix is a policy change.

**Classification decides labels; it is not only evidence.** Every sweep classifies uncovered
objects, and since [ADR 0038](https://github.com/j3w1/ce-metadata/blob/main/docs/adr/0038-reviewed-classification-rules-as-label-authority.md)
a complete, canonical, unambiguous classification derived from reviewed rules *is* an object's
exact managed label set where no explicit reviewed rule covers it — in the repositories that
declaration names.

The half that fails closed matters more here. An object whose evidence does not decide a single
`type:` and a single `area:` sits at `NEEDS_REVIEW` and writes nothing. Since
[ADR 0039](https://github.com/j3w1/ce-metadata/blob/main/docs/adr/0039-semantic-pr-evidence.md) a pull request is classified from the
files it changed **as well as** its title: where they disagree in an exclusive namespace structure
wins and the title rule's whole contribution is set aside, and where they agree they merge. Within
one class of evidence there is no principled winner, so two conflicting title rules and two
conflicting structural rules both fail closed. An incomplete changed-file list fails a *universal*
fact closed — "every path here is documentation" cannot be established from a truncated list — but
an *existential* one can still hold.

Since [ADR 0046](https://github.com/j3w1/ce-metadata/blob/main/docs/adr/0046-classification-evidence-from-title-convention.md) the
classifier reads this portfolio's own title conventions: a conventional-commit prefix
(`feat:`, `fix:`, `ci:`), a leading imperative verb, or an identifier or bracketed tag followed by
one. The identifier itself is skipped and cannot be read — the patterns answer identically for any
scheme — so a `CE-####` prefix implies neither a type nor an area. What decides a type is the verb
after it.

**No CE task identifier is allocated by any of this.** CE Metadata cannot create `CE-GD`, `HQ`,
`IAR`, `IAP`, `MQ`, `D3` or `DONE` state, approve anything, mark anything ready, or merge. This
repository's existing delivery process is untouched.

**Do not create a competing writer.** A second workflow, Action or agent writing the same labels or
the same Project membership is exactly the failure `NO_DUAL_WRITER` exists to prevent. Project
membership is written by the owner-authenticated Project bridge, never by the App, and Project
Status belongs to GitHub's own native workflows rather than to CE Metadata.

**This repository's profile is reviewed policy, not a claim made here.** Its role is `ce-retail-signage`, its
membership writer is `OWNER_AUTHENTICATED_BRIDGE`, its default area is `area:signage`, and the prefixes
above are what protected policy currently allows it. Read them from
[`policy/repositories.yaml`](https://github.com/j3w1/ce-metadata/blob/main/policy/repositories.yaml) rather than from this file, and
verify the live grant before assuming a writer is active — a grant names exact repositories and,
at a canary ring, exact objects, so being in the allowlist is not the same as being covered by a
live grant.
