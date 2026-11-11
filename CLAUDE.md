# Perennial UI: notes for AI assistants

Perennial UI is a GPL-3.0-or-later interface replacement for World of Warcraft: Forever, written from scratch. Read this before changing anything.

## Clean-room rule (never break this)

- **Never open, read, fetch, paste or summarise the files of ObsidianUI, ForeverUI, or any addon that does not permit reuse.** No Lua, XML, textures, fonts or settings files. This includes copies on the user's disk (for example in an `Interface/AddOns` folder) and copies on GitHub, CurseForge or Wago.
- Specs come only from public behaviour: public feature descriptions, how a feature behaves in game, and the client's own API.
- Do not reproduce another addon's look ("dark glass", one accent on black), preset names or branding.
- If a task seems to need another addon's source, stop and say so.
- GPL-compatible code (MIT, BSD, GPL) may be used with attribution in `THIRD_PARTY.md`; ask first.

## Target platform

- WoW: Forever, client 1.60.1, TOC `## Interface: 16001`. Codename "Camelot".
- Classic content on a **modern 12.0-based engine and API**. Build against the modern API, not Classic Era's. Do not trust retail or Classic documentation from memory; check the client's own `/api` export (generated into `tools/api/`, not committed) and mark anything unverified with `TODO(verify)`.
- **Combat restrictions:** health, names and threat can be hidden from addons in combat, and the combat log is not readable. Every combat number goes through `ns.Compat.Number(value, fallback)`; widgets must degrade, not error. Damage meters read the game's own numbers.
- Anything clickable in combat uses secure templates. Frame moves and settings changes in combat go through `module:RunWhenSafe(key, fn)`.
- Never call Blizzard's map, quest or auction code on the player's behalf (taint). Waypoints, pins and quest UI are our own frames.
- Classic Era, Hardcore and Season of Discovery are a later stretch target. Keep client differences in `PerennialUI/Compat/` only.

## Layout

```text
PerennialUI/            the addon; PerennialUI.toc lists load order
  Core/                 Init, Safety, Events, Serialize, DB, Theme, Combat, Modules, Boot
  Compat/               client differences and hidden-value guards
  Settings/             slash commands (settings window to come)
  Modules/              one folder per feature module
  Media/  Libs/         openly licensed assets and vendored libraries
tests/                  busted specs; tests/stub/wow.lua fakes the client API
tools/                  check-files.sh, link scripts
docs/                   ARCHITECTURE.md, MODULES.md, ROADMAP.md
```

## Conventions

- Lua 5.1, four spaces, 120 columns. First line of every Lua file: `-- SPDX-License-Identifier: GPL-3.0-or-later`.
- Every addon Lua file must be listed in `PerennialUI/PerennialUI.toc`, or it never loads.
- One global, `PerennialUI`. Files start with `local _, ns = ...`.
- Features are modules registered with `ns.Modules.Register` (contract in `docs/MODULES.md`). Do not add features to the core.
- Modules subscribe with `self:RegisterEvent` / `self:Listen` so handlers run inside the safety net. Never create a private event frame in a module.
- No hard-coded colours, spacing or fonts: use `ns.Theme`.
- Saved data goes through `ns.DB`; a change to the saved layout needs a bump of `DB.SCHEMA` and a migration with a test.
- Every module has an off switch, and off means the default Blizzard element is left as it was.
- Core code must stay loadable outside the game: new client API calls need a stub in `tests/stub/wow.lua` and an entry in `.luacheckrc` and `.luarc.json`.
- Player-facing text is plain and short. No colour codes in the core.

## Commands

```bash
luacheck .                    # lint
busted                        # tests (Lua 5.1)
bash tools/check-files.sh     # SPDX headers and TOC listing
```

CI runs all three plus a DCO check on every pull request. If Lua is not installed locally, say so rather than claiming the checks pass.

## Git

- Sign off every commit: `git commit -s`.
- Work on a branch and open a pull request; never push to `main`.
- Do not tag releases or change repository settings without being asked.

## Decisions already made

- Licence: GPL-3.0-or-later.
- Framework: our own small core, no Ace3. Small single-purpose libraries may be vendored when needed.
- Merging: CI green plus a code-owner approval, then auto-merge by squash.
- Theme system: four seasons. Avoid the preset names healer, raider, minimal, hardcore, controller.
- Open questions are tracked at the end of `docs/ROADMAP.md`.
