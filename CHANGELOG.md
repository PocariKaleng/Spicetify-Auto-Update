# Changelog

## 1.0.8 — 2026-10-17

- Check for missing Spotify patches every 5 minutes instead of hourly.
- Add optional automatic Spotify restart and repair after Spotify updates, preserving the user's preference on reinstall.
- Detect new stock archives even when the old patched app folder remains.
- Preserve existing updater state when refreshing installed scripts.
- Back off automatic restarts for 30 minutes after a failed recovery and reopen Spotify even on failure.

## 1.0.7 — 2026-10-13

- Refresh theme-only changes in place instead of restoring and rebuilding Spotify resources.
- Check for Spotify again immediately before repair and log when it opens during patching and needs a restart.
- Cover theme refresh and full-repair fallbacks with Windows regression checks.

## 1.0.6 — 2026-10-13

- Add a consistent 12px gap below the Spotify toolbar across all three content panes.
- Preserve player alignment and fit in desktop and narrow windows.

## 1.0.5 — 2026-10-13

- Start scheduled updates through a hidden Windows Script Host launcher to prevent PowerShell console flashes.
- Preserve the updater exit code, schedule, and existing appearance configuration.

## 1.0.4 — 2026-10-12

- Remove Spotify's opaque Home gradient that cut across the wallpaper.
- Align panel corners and the player, with a quieter toolbar and matching lyrics colors.
- Refine Balanced/Portrait presets while preserving customized appearance settings.
- Verify desktop and narrow layouts, scrolling, and keyboard controls in Spotify 1.3.4.

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
