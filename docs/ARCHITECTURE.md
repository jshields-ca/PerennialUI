# Architecture

A small core owns every shared service. Each feature is a module that registers itself and that the core can enable, disable or pause on its own.

```text
                 game client (events, API, saved variables)
                                   |
   +-------------------------------+--------------------------------+
   |  CORE                                                          |
   |  Compat   client differences, hidden-value guards              |
   |  Events   one frame, fans events and PUI_* messages out        |
   |  Safety   runs every handler protected, counts errors, trips   |
   |  DB       schema migration, defaults, profiles, share strings  |
   |  Theme    colour, spacing, shape and font tokens               |
   |  Combat   queue for work that must wait until combat ends      |
   |  Modules  registry and lifecycle: enabled / disabled / paused  |
   +-------------------------------+--------------------------------+
                                   |
        Modules/UnitFrames   Modules/Bags   Modules/Nameplates  ...
```

Modules never talk to the client's version-specific API directly: they go through `Compat`, read and write through `DB`, style through `Theme`, and run their handlers inside `Safety`.

## Load order

`PerennialUI.toc` loads the core in dependency order, then modules, then `Core/Boot.lua` last.

| When | What happens |
| --- | --- |
| Files load | Each file attaches its service to the namespace. Modules call `Modules.Register`. Nothing touches saved data yet. |
| `ADDON_LOADED` | `DB.Init` migrates saved variables and picks the character's profile. Safe mode is read. `Theme.Load` applies the profile's season. |
| `PLAYER_LOGIN` | `Modules.EnableAll` starts every module the profile has on (none in safe mode). `PUI_READY` is sent. |
| `PLAYER_LOGOUT` | `DB.OnLogout` removes values that still equal their defaults, so only changes are saved. |

## Services

### Safety (`Core/Safety.lua`)

`Safety.Call(owner, fn, ...)` runs a function protected and records any error against `owner` (a module id, or `core.*`). Five errors from one owner within ten seconds trip it: the registry pauses that module, tells the player, and keeps the error for `/pui bug`. Other modules never notice.

### Events (`Core/Events.lua`)

One hidden frame registers game events once, however many modules want them, and calls each subscriber through `Safety.Call`. The same bus carries internal messages:

| Message | Arguments | Sent when |
| --- | --- | --- |
| `PUI_READY` | | Login finished, modules started |
| `PUI_MODULE_STATE` | id, state, reason | A module was enabled, disabled or paused |
| `PUI_PROFILE_CHANGED` | name | The active profile changed or was replaced |
| `PUI_THEME_CHANGED` | | Season or shape changed |
| `PUI_LAYOUT_MODE` | on | Layout mode turned on or off |
| `PUI_LAYOUT_MOVED` | id, x, y | A frame was moved in layout mode |
| `PUI_SETTING_CHANGED` | page, key, value | A setting changed (also on undo) |
| `PUI_SETTINGS_MODE` | advanced | Simple/advanced mode switched |
| `PUI_SETTINGS_PAGES` | | A page was added, or pins changed |
| `PUI_MODULE_REGISTERED` | id | A module registered |
| `PUI_TEST_MODE` | on | `/pui test` toggled |

### DB (`Core/DB.lua`)

`PerennialUIDB` holds `schema`, `global`, `profiles` and `profileKeys` (character to profile). `PerennialUICharDB` is free-form per-character data.

- **Migrations.** Changing the saved layout means bumping `DB.SCHEMA` and adding `DB.migrations[n]`. Data from a newer version is left untouched.
- **Defaults** are filled in when a module's settings are read and stripped at logout, so a changed default reaches everyone who never touched that setting.
- **Share strings** are `PUI1:` plus Base64 of a plain-data encoding. Importing parses the text; it never executes it.

### Theme (`Core/Theme.lua`)

`Theme.Color("accent")` returns r, g, b, a for the active season. `Theme.Get("space.md")` returns spacing, border and font tokens. `Theme.Radius()` follows the soft/crisp shape setting. New palettes register with `Theme.RegisterSeason` and must define every colour token.

### Combat (`Core/Combat.lua`)

`Combat.RunWhenSafe(owner, key, fn)` runs now, or queues until `PLAYER_REGEN_ENABLED`. A second call with the same owner and key replaces the first, so only the final state is applied.

### Compat (`Compat/Compat.lua`)

Client detection (`isForever`, `isClassicEra`) and `Compat.Number(value, fallback)`, the guard for values the client may hide in combat. Any API that differs between clients gets a wrapper here.

### Settings (`Settings/Registry.lua`, `Pages.lua`, `Window.lua`)

The registry holds pages of options and is the only code that reads or writes their values. It validates every change, records it in a session history for undo, and answers searches. The window draws whatever the registry describes: a page list (right click pins a page), a search box, a simple/advanced switch and an undo button. Modules get a page by declaring `settings`; the core's own pages are General, Modules, Profiles and History.

### Layout (`Layout/Layout.lua`)

Modules register movable frames. A position is the frame's centre offset from the screen centre, saved per profile and applied through the combat queue. Layout mode draws a grid and a drag handle over each registered frame; dropping a handle snaps to the grid and saves. Layout mode refuses to start in combat and closes when combat starts.

### Widgets (`UI/Widgets.lua`)

Themed building blocks: text, panel, button, checkbox, slider, picker, text input, scroll area. Each restyles itself when the season changes. Corners are square for now: rounding needs texture assets that do not exist yet.

## Testing

The core has no dependency on a running client. `tests/helpers/loader.lua` reads the TOC and loads each file against `tests/stub/wow.lua`, a minimal fake API. The stub's frames record what is done to them and ignore methods they do not know, so tests prove the logic of UI code but not that the client API calls are right. UI code is still tested in game.

## Not built yet

Frame designer, first-login wizard, spec-based profile switching, profile management in the window (create, copy, delete, import, export), a real dropdown list, and every visible module except the sandbox. See [ROADMAP.md](ROADMAP.md).
