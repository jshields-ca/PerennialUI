-- SPDX-License-Identifier: GPL-3.0-or-later
-- Module registry. Every feature is a module that registers itself here and
-- can be enabled, disabled or paused on its own. See docs/MODULES.md.
local _, ns = ...

local Combat = ns.Combat
local DB = ns.DB
local Events = ns.Events
local Safety = ns.Safety

local Modules = {}
ns.Modules = Modules

local registry = {} -- id -> module
local order = {} -- modules in registration order
local started = false

local proto = {}
proto.__index = proto

local function bind(mod, handler, event)
    if handler == nil or handler == true then
        handler = event
    end
    if type(handler) == "string" then
        local name = handler
        if type(mod[name]) ~= "function" then
            error("module '" .. mod.id .. "' has no method '" .. name .. "'", 3)
        end
        return function(...)
            return mod[name](mod, ...)
        end
    end
    return handler
end

--- Subscribe to a game event. handler is a function, a method name, or
--- omitted to use the method named after the event. Called as (event, ...),
--- or (self, event, ...) for methods.
function proto:RegisterEvent(event, handler)
    Events.Register(self.id, event, bind(self, handler, event))
end

function proto:UnregisterEvent(event)
    Events.Unregister(self.id, event)
end

--- Subscribe to an internal PUI_* message.
function proto:Listen(message, handler)
    Events.Listen(self.id, message, bind(self, handler, message))
end

--- Run fn now, or after combat. See Combat.RunWhenSafe.
function proto:RunWhenSafe(key, fn)
    return Combat.RunWhenSafe(self.id, key, fn)
end

--- Make a frame draggable in layout mode. See Layout.Register.
function proto:RegisterMover(id, frame, opts)
    return ns.Layout.Register(self.id, id, frame, opts)
end

function proto:IsEnabled()
    return self.state == "enabled"
end

function proto:Print(...)
    ns.Print("[" .. self.title .. "]", ...)
end

local function setState(mod, state, reason)
    mod.state = state
    mod.pauseReason = reason
    Events.Fire("PUI_MODULE_STATE", mod.id, state, reason)
end

local function settings(mod)
    mod.db = DB.Module(mod.id, mod.defaults)
    return mod.db
end

local function teardown(mod)
    local wasEnabled = mod.state == "enabled"
    Events.UnregisterAll(mod.id)
    Combat.Cancel(mod.id)
    if ns.Layout then
        ns.Layout.UnregisterAll(mod.id)
    end
    if wasEnabled and mod.OnDisable then
        Safety.Call(mod.id, mod.OnDisable, mod)
    end
end

--- Register a module definition. Returns the module.
---   id        unique, letters/digits/underscore, starts with a letter
---   title     shown to the player (defaults to id)
---   defaults  default settings; `enabled` is reserved
---   events    { EVENT_NAME = function | "MethodName" | true }
---   settings  list of options for the module's settings page (see Settings/Registry.lua)
---   OnEnable, OnDisable   lifecycle methods
function Modules.Register(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or not def.id:match("^%a[%w_]*$") then
        error("Modules.Register: a module needs an id of letters, digits and underscores", 2)
    end
    if registry[def.id] then
        error("Modules.Register: module '" .. def.id .. "' is already registered", 2)
    end
    def.title = def.title or def.id
    def.state = "disabled"
    def.defaults = DB.Copy(def.defaults or {})
    def.defaults.enabled = def.enabledByDefault ~= false
    setmetatable(def, proto)

    registry[def.id] = def
    order[#order + 1] = def

    if def.settings and ns.Settings then
        ns.Settings.RegisterPage({ id = def.id, title = def.title, owner = def.id, options = def.settings })
    end
    Events.Fire("PUI_MODULE_REGISTERED", def.id)

    -- A module that registers after login (load on demand) starts right away.
    if started and not ns.state.safeMode and settings(def).enabled then
        Modules.Enable(def.id)
    end
    return def
end

function Modules.Get(id)
    return registry[id]
end

--- Module ids in registration order.
function Modules.List()
    local ids = {}
    for i = 1, #order do
        ids[i] = order[i].id
    end
    return ids
end

--- "enabled", "disabled" or "paused"; nil for an unknown id.
function Modules.GetState(id)
    local mod = registry[id]
    return mod and mod.state, mod and mod.pauseReason
end

--- Start a module for this session. Does not change the saved setting.
function Modules.Enable(id)
    local mod = registry[id]
    if not mod then
        return false, "unknown module"
    end
    if mod.state == "enabled" then
        return true
    end
    Safety.Reset(id)
    settings(mod)
    mod.state = "enabled"
    mod.pauseReason = nil

    local ok, err = Safety.Call(id, function()
        if mod.events then
            for event, handler in pairs(mod.events) do
                mod:RegisterEvent(event, handler)
            end
        end
        if mod.OnEnable then
            mod:OnEnable()
        end
    end)
    if not ok then
        Modules.Pause(id, err)
        return false, err
    end
    Events.Fire("PUI_MODULE_STATE", id, "enabled")
    return true
end

--- Stop a module for this session. Does not change the saved setting.
function Modules.Disable(id)
    local mod = registry[id]
    if not mod then
        return false, "unknown module"
    end
    if mod.state == "disabled" then
        return true
    end
    teardown(mod)
    setState(mod, "disabled")
    return true
end

--- Stop a misbehaving module but remember why. Used by the safety net.
function Modules.Pause(id, reason)
    local mod = registry[id]
    if not mod or mod.state == "paused" then
        return false
    end
    teardown(mod)
    setState(mod, "paused", tostring(reason or "unknown error"))
    return true
end

--- Save the player's choice and apply it.
function Modules.SetEnabled(id, enabled)
    local mod = registry[id]
    if not mod then
        return false, "unknown module"
    end
    settings(mod).enabled = enabled and true or false
    if enabled then
        return Modules.Enable(id)
    end
    return Modules.Disable(id)
end

--- Enable every module the active profile has switched on. Called at login.
function Modules.EnableAll()
    started = true
    for i = 1, #order do
        local mod = order[i]
        if mod.state == "disabled" and settings(mod).enabled then
            Modules.Enable(mod.id)
        end
    end
end

Safety.SetTripHandler(function(owner, message)
    local mod = registry[owner]
    if mod and Modules.Pause(owner, message) then
        ns.Print(mod.title .. " kept failing and has been paused. The rest of the UI is still running.")
        ns.Print("Type /pui bug for details, or /pui enable " .. owner .. " to try it again.")
    end
end)

-- A profile switch restarts modules against the new profile's settings.
Events.Listen("core.modules", "PUI_PROFILE_CHANGED", function()
    if not started then
        return
    end
    for i = 1, #order do
        Modules.Disable(order[i].id)
    end
    if not ns.state.safeMode then
        Modules.EnableAll()
    end
end)
