-- SPDX-License-Identifier: GPL-3.0-or-later
-- Slash commands: /pui and /perennial.
local _, ns = ...

local Combat = ns.Combat
local DB = ns.DB
local Events = ns.Events
local Modules = ns.Modules
local Safety = ns.Safety

local Slash = {}
ns.Slash = Slash

local commands = {}
local names = {}

--- Add a subcommand. run(args) receives the rest of the line.
function Slash.Register(name, help, run)
    if not commands[name] then
        names[#names + 1] = name
    end
    commands[name] = { help = help, run = run }
end

--- Handle a command line, e.g. Slash.Run("enable unitframes").
function Slash.Run(line)
    local name, args = (line or ""):match("^%s*(%S*)%s*(.-)%s*$")
    name = name:lower()
    if name == "" then
        name = "help"
    end
    local command = commands[name]
    if not command then
        ns.Print("Unknown command '" .. name .. "'. Type /pui help.")
        return
    end
    Safety.Call("core.slash", command.run, args)
end

Slash.Register("help", "list commands", function()
    ns.Print("version " .. ns.version .. ". Commands:")
    for i = 1, #names do
        print("  /pui " .. names[i] .. " - " .. commands[names[i]].help)
    end
end)

Slash.Register("move", "toggle layout mode to drag frames", function()
    if not ns.state.layoutMode and Combat.InLockdown() then
        ns.Print("Layout mode is not available in combat.")
        return
    end
    ns.state.layoutMode = not ns.state.layoutMode
    Events.Fire("PUI_LAYOUT_MODE", ns.state.layoutMode)
    ns.Print("Layout mode " .. (ns.state.layoutMode and "on." or "off."))
end)

Slash.Register("test", "toggle test mode (sample data in frames)", function()
    ns.state.testMode = not ns.state.testMode
    Events.Fire("PUI_TEST_MODE", ns.state.testMode)
    ns.Print("Test mode " .. (ns.state.testMode and "on." or "off."))
end)

Slash.Register("safe", "toggle safe mode (load with every module off)", function()
    local global = DB.Global()
    global.safeMode = not global.safeMode
    ns.Print("Safe mode will be " .. (global.safeMode and "ON" or "off") .. " after you /reload.")
end)

Slash.Register("modules", "list modules and their state", function()
    local ids = Modules.List()
    if #ids == 0 then
        ns.Print("No modules are installed yet.")
        return
    end
    for i = 1, #ids do
        local state, reason = Modules.GetState(ids[i])
        print("  " .. ids[i] .. ": " .. state .. (reason and (" (" .. reason .. ")") or ""))
    end
end)

local function setEnabled(id, enabled)
    if id == "" then
        ns.Print("Which module? Type /pui modules for the list.")
        return
    end
    local ok, err = Modules.SetEnabled(id, enabled)
    if ok then
        ns.Print(id .. (enabled and " enabled." or " disabled."))
    else
        ns.Print("Could not " .. (enabled and "enable " or "disable ") .. id .. ": " .. tostring(err))
    end
end

Slash.Register("enable", "enable a module: /pui enable <id>", function(args)
    setEnabled(args, true)
end)

Slash.Register("disable", "disable a module: /pui disable <id>", function(args)
    setEnabled(args, false)
end)

--- The lines of a bug report: version, client, module states, recent errors.
function Slash.BugReport()
    local lines = {
        "Perennial UI " .. ns.version .. ", client " .. tostring(ns.Compat.version)
            .. " (" .. tostring(ns.Compat.interface) .. ")"
            .. (ns.state.safeMode and ", safe mode" or ""),
    }
    local ids = Modules.List()
    for i = 1, #ids do
        local state, reason = Modules.GetState(ids[i])
        lines[#lines + 1] = "module " .. ids[i] .. ": " .. state .. (reason and (" - " .. reason) or "")
    end
    local log = Safety.GetLog()
    if #log == 0 then
        lines[#lines + 1] = "No errors recorded this session."
    end
    for i = math.max(1, #log - 9), #log do
        local entry = log[i]
        lines[#lines + 1] = "error [" .. tostring(entry.owner) .. "] x" .. entry.count .. ": " .. entry.message
    end
    return lines
end

Slash.Register("bug", "print a bug report to copy into an issue", function()
    local lines = Slash.BugReport()
    for i = 1, #lines do
        print(lines[i])
    end
end)

SLASH_PERENNIALUI1 = "/pui"
SLASH_PERENNIALUI2 = "/perennial"
SlashCmdList.PERENNIALUI = Slash.Run
