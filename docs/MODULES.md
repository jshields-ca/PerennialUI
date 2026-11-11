# Writing a module

A module is one feature: a frame, a bar, a helper. It lives in its own folder under `PerennialUI/Modules/`, registers itself, and never requires a change to the core.

## Minimal module

`PerennialUI/Modules/Example/Example.lua`:

```lua
-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...

local Example = ns.Modules.Register({
    id = "example",
    title = "Example",
    defaults = {
        scale = 1,
    },
    events = {
        PLAYER_TARGET_CHANGED = true, -- calls Example:PLAYER_TARGET_CHANGED
        UNIT_HEALTH = "OnHealth",     -- calls Example:OnHealth
    },
})

function Example:OnEnable()
    -- Create or show frames. self.db holds this module's settings.
    self:Print("scale is", self.db.scale)
end

function Example:OnDisable()
    -- Hide frames and hand the default element back to the game.
end

function Example:PLAYER_TARGET_CHANGED(event)
end

function Example:OnHealth(event, unit)
    local health = ns.Compat.Number(UnitHealth(unit))
    if not health then
        return -- hidden in combat: show a fallback instead of doing maths on it
    end
end
```

Add the file to `PerennialUI/PerennialUI.toc` before `Core/Boot.lua`, and add any new client API names (`UnitHealth` here) to `.luacheckrc` and `.luarc.json`.

## The contract

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | Unique. Letters, digits and underscores, starting with a letter. Used in saved settings and `/pui enable <id>`, so never rename it. |
| `title` | no | Name shown to the player. Defaults to `id`. |
| `defaults` | no | Default settings. `enabled` is reserved. |
| `enabledByDefault` | no | `false` makes the module opt-in. |
| `events` | no | Game events to subscribe to while enabled. The value is a function, a method name, or `true` for the method named after the event. |
| `OnEnable(self)` | no | Start. Runs at login, or when the player turns the module on. |
| `OnDisable(self)` | no | Stop and undo. Runs when turned off, when paused, and on a profile switch. |

Methods every module gets:

| Method | Does |
| --- | --- |
| `self:RegisterEvent(event[, handler])` | Subscribe to a game event at runtime |
| `self:UnregisterEvent(event)` | Unsubscribe |
| `self:Listen(message[, handler])` | Subscribe to an internal `PUI_*` message |
| `self:RunWhenSafe(key, fn)` | Run now, or after combat if frames are locked |
| `self:IsEnabled()` | True while the module is running |
| `self:Print(...)` | Chat message prefixed with the module's title |
| `self.db` | This module's settings in the active profile |

## Rules

1. **Off means off.** After `OnDisable`, the game's default element is back as it was and the module holds no events, timers or visible frames. `OnDisable` can also run after a failed `OnEnable`, so it must cope with half-built state.
2. **Handlers go through the module.** Use `events`, `RegisterEvent` and `Listen`. Do not create your own event frame: handlers registered that way bypass the safety net, and one error would no longer be contained.
3. **Wrap script handlers.** For `OnUpdate`, `OnClick` and similar, pass `ns.Safety.Wrap(self.id, fn)` to `SetScript`.
4. **Combat values may be hidden.** Health, names and threat can be unreadable in combat. Read them through `ns.Compat.Number(value, fallback)` and decide what the widget shows when it gets the fallback.
5. **Protected frames wait for combat to end.** Use secure templates for anything clickable in combat, and `self:RunWhenSafe` to move, show, hide or reconfigure them.
6. **Style from tokens.** `ns.Theme.Color(...)`, `ns.Theme.Get(...)`, `ns.Theme.Radius()`. Listen for `PUI_THEME_CHANGED` and restyle.
7. **Settings live in `self.db`.** `self.db` is replaced on a profile switch (the module is restarted), so read it fresh; do not cache the table across `OnDisable`.
8. **Respect the modes.** Listen for `PUI_LAYOUT_MODE` to show drag handles and `PUI_TEST_MODE` to show sample data.
9. **Client differences belong in `Compat/`.**

## What happens when a module breaks

Every handler runs protected. If a module errors five times within ten seconds, it is paused: its events are removed, `OnDisable` runs, and the player sees a message naming the module. `/pui bug` shows the error, and `/pui enable <id>` starts it again. The player's saved choice is not changed, so the module starts normally on the next login.

## Testing a module

Put logic that does not need a real frame (sorting, filtering, formatting, state machines) in plain functions and test it under `tests/`. See `tests/modules_spec.lua` for how to register a module against the stub and fire events at it.
