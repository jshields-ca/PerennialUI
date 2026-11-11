-- SPDX-License-Identifier: GPL-3.0-or-later
-- The core's own settings pages: General, Modules, Profiles, History.
local _, ns = ...

local DB = ns.DB
local Events = ns.Events
local Layout = ns.Layout
local Modules = ns.Modules
local Settings = ns.Settings
local Theme = ns.Theme

local function titleCase(word)
    return (word:gsub("^%l", string.upper))
end

Settings.RegisterPage({
    id = "general",
    title = "General",
    order = 10,
    options = {
        { type = "header", label = "Appearance" },
        {
            key = "season", type = "select", label = "Season",
            desc = "The colour theme used by every Perennial frame.",
            values = function()
                local values = {}
                local names = Theme.ListSeasons()
                for i = 1, #names do
                    values[i] = { value = names[i], label = titleCase(names[i]) }
                end
                return values
            end,
            get = Theme.GetSeason,
            set = Theme.SetSeason,
        },
        {
            key = "shape", type = "select", label = "Shape",
            desc = "Soft rounds corners where it can; crisp keeps them square.",
            values = { { value = "soft", label = "Soft" }, { value = "crisp", label = "Crisp" } },
            get = Theme.GetShape,
            set = Theme.SetShape,
        },
        { type = "header", label = "Layout" },
        {
            key = "layoutMode", type = "action", label = "Toggle layout mode",
            desc = "Drag frames around the screen. Same as /pui move.",
            func = function()
                local ok, reason = Layout.Toggle()
                if not ok then
                    ns.Print(reason)
                end
            end,
        },
        {
            key = "snap", type = "toggle", label = "Snap to grid",
            get = Layout.GetSnap,
            set = Layout.SetSnap,
        },
        {
            key = "grid", type = "range", label = "Grid size", advanced = true,
            min = 2, max = 64, step = 2,
            get = Layout.GetGrid,
            set = Layout.SetGrid,
        },
        {
            key = "resetPositions", type = "action", label = "Reset frame positions", advanced = true,
            desc = "Put every frame of this profile back where it started.",
            func = Layout.ResetAll,
        },
        { type = "header", label = "Troubleshooting", advanced = true },
        {
            key = "safeMode", type = "toggle", label = "Safe mode", advanced = true,
            desc = "Load with every module off. Takes effect after /reload.",
            get = function()
                return DB.Global().safeMode == true
            end,
            set = function(on)
                DB.Global().safeMode = on
            end,
        },
    },
})

Settings.RegisterPage({
    id = "modules",
    title = "Modules",
    order = 20,
    options = function()
        local options = {}
        local ids = Modules.List()
        for i = 1, #ids do
            local id = ids[i]
            local mod = Modules.Get(id)
            options[i] = {
                key = id, type = "toggle", label = mod.title,
                desc = "Off leaves the game's default element as it is.",
                get = function()
                    return DB.Module(id, mod.defaults).enabled == true
                end,
                set = function(on)
                    Modules.SetEnabled(id, on)
                end,
            }
        end
        return options
    end,
})

-- Modules can register late (load on demand); rebuild the list when one does.
Events.Listen("core.pages", "PUI_MODULE_REGISTERED", function()
    Settings.Invalidate("modules")
end)

Settings.RegisterPage({
    id = "profiles",
    title = "Profiles",
    order = 30,
    options = {
        {
            key = "active", type = "select", label = "Active profile",
            desc = "Each character remembers which profile it uses.",
            values = function()
                local values = {}
                local names = DB.ListProfiles()
                for i = 1, #names do
                    values[i] = { value = names[i], label = names[i] }
                end
                return values
            end,
            get = DB.GetProfileName,
            set = DB.SetProfile,
        },
    },
})

local function describe(value)
    if type(value) == "boolean" then
        return value and "on" or "off"
    end
    return tostring(value)
end

Settings.RegisterPage({
    id = "history",
    title = "History",
    order = 900,
    options = {
        {
            key = "changes", type = "info",
            text = function()
                local history = Settings.History()
                if #history == 0 then
                    return "No settings have been changed this session."
                end
                local lines = {}
                for i = #history, math.max(1, #history - 19), -1 do
                    local entry = history[i]
                    local page = Settings.GetPage(entry.page)
                    lines[#lines + 1] = ("%s: %s  %s -> %s"):format(
                        page and page.title or entry.page, entry.label, describe(entry.old), describe(entry.new)
                    )
                end
                return table.concat(lines, "\n")
            end,
        },
    },
})
