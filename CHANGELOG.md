# Changelog

## 1.0.3 — 2026-10-12

- Load the one-line installer's helper without changing Windows execution policy.
- Include process-scoped execution policy in manual update/uninstall commands.

## 1.0.2 — 2026-10-12

- Report a successful test exit after checking a deliberately failing native command in CI.

## 1.0.1 — 2026-10-12

- Handle native progress messages on Windows PowerShell 5.1 without aborting Spotify repair.
- Preserve native exit codes and error diagnostics.
- Keep glass panels and native appearance controls working after Spotify 1.3.4 layout changes.

## 1.0.0 — 2026-10-12

- Install a Windows auto updater with one PowerShell command.
- Check official Spicetify releases daily and restore patches after Spotify updates.
- Defer while Spotify is running; keep the existing theme, extensions, and local photo.
- Add Elaina Glass with a local JPG wallpaper and saved appearance controls.
- Add Windows script checks and updater logs.
