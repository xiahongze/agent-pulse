# Changelog

## 0.5.0 — Unreleased

- Bundled the collector in the plasmoid and removed the persistent local service
- Added a widget setting for optional Claude online usage
- Simplified installation to a single widget package
- Cached Claude usage windows across refreshes and delayed retries after provider rate limits

## 0.4.2 — 2026-09-24

- Restored the refresh action before the rightmost icon-only pin

## 0.4.1 — 2026-09-24

- Replaced the popup refresh action with an icon-only pin at the far right

## 0.4.0 — 2026-09-24

- Added a persistent pin control that keeps the taskbar popup open
- Fixed Codex windows disappearing when a newer unrelated limit event had no windows

## 0.3.1 — 2026-09-24

- Fixed desktop transparency by disabling Plasma's opaque chrome only in planar mode
- Installed the custom icon into the user icon theme for the widget explorer

## 0.3.0 — 2026-09-24

- Added desktop-only transparency and functional light/dark themes
- Added a custom Agent Pulse pulse-wave icon
- Added public, privacy-safe widget screenshots
- Renamed the project repository to Agent Pulse

## 0.2.0 — 2026-09-24

- Added dual desktop-dashboard and taskbar-popup representations
- Added Claude OAuth usage windows and current session history fallback
- Switched surfaces to native Plasma theming

## 0.1.0 — 2026-09-24

- Initial Plasma 6 widget with local Codex and Claude collectors
- Five accent palettes and system/light/dark modes
- User service installer, tests, packaging, and release automation
