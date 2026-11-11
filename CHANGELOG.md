# Changelog

Notable changes for players. The format follows [Keep a Changelog](https://keepachangelog.com/), and versions follow [Semantic Versioning](https://semver.org/).

## Unreleased

### Added

- Core: event bus, module registry, and a safety net that pauses a module that keeps erroring while the rest keeps running.
- Profiles: per-character profile choice, copy, delete, reset, share strings, and versioned migrations.
- Theme tokens with four seasonal palettes (spring, summer, autumn, winter) and a soft/crisp shape setting.
- Combat lockdown queue for changes that must wait until combat ends.
- `/pui` and `/perennial` with `help`, `move`, `test`, `safe`, `bug`, `modules`, `enable` and `disable`.
