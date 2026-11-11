# Changelog

Notable changes for players. The format follows [Keep a Changelog](https://keepachangelog.com/), and versions follow [Semantic Versioning](https://semver.org/).

## Unreleased

### Added

- Core: event bus, module registry, and a safety net that pauses a module that keeps erroring while the rest keeps running.
- Profiles: per-character profile choice, copy, delete, reset, share strings, and versioned migrations.
- Theme tokens with four seasonal palettes (spring, summer, autumn, winter) and a soft/crisp shape setting.
- Combat lockdown queue for changes that must wait until combat ends.
- Settings window (`/pui`): pages, search, simple and advanced modes, undo, change history, pinned pages; resizable and movable.
- Layout mode (`/pui move`): drag handles, grid snap, per-profile positions, right click to reset.
- Sandbox module (off by default) for trying the foundation in game.
- `/pui` and `/perennial` with `config`, `undo`, `help`, `move`, `test`, `safe`, `bug`, `modules`, `enable` and `disable`.
