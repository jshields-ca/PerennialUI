-- SPDX-License-Identifier: GPL-3.0-or-later
-- Startup sequence. Loaded last.
local _, ns = ...

local DB = ns.DB
local Events = ns.Events
local Modules = ns.Modules
local Theme = ns.Theme

Events.Register("core", "ADDON_LOADED", function(_, name)
    if name ~= ns.name then
        return
    end
    Events.Unregister("core", "ADDON_LOADED")
    DB.Init()
    ns.state.safeMode = DB.Global().safeMode == true
    Theme.Load()
    if DB.newerData then
        ns.Print("Your settings were saved by a newer version of Perennial UI. Update the addon to avoid problems.")
    end
end)

Events.Register("core", "PLAYER_LOGIN", function()
    if ns.state.safeMode then
        ns.Print("Safe mode is on: no modules were loaded. Type /pui safe, then /reload, to turn it off.")
    else
        Modules.EnableAll()
    end
    Events.Fire("PUI_READY")
end)

Events.Register("core", "PLAYER_LOGOUT", DB.OnLogout)
