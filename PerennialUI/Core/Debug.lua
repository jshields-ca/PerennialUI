-- SPDX-License-Identifier: GPL-3.0-or-later
-- Debug mode: the development feedback loop. An addon cannot write files of
-- its own, but the client writes its saved variables on /reload and logout,
-- and screenshots when asked. With debug mode on (/pui debug) the addon
-- records where each of its frames is, what it shows and any caught errors
-- into the saved variables, and takes a screenshot once frames have drawn.
-- A developer, or an assistant with file access, reads those afterwards.
-- Off by default: players never pay for it.
local _, ns = ...

local Compat = ns.Compat
local DB = ns.DB
local Events = ns.Events
local Safety = ns.Safety

local Debug = {}
ns.Debug = Debug

Debug.MAX_DEPTH = 3
Debug.LOAD_DELAY = 2 -- seconds after login before the "load" snapshot

local roots = {}

--- Record this frame, and the widgets stored on it, in every snapshot.
function Debug.Watch(name, frame)
    roots[name] = frame
end

function Debug.IsOn()
    return DB.Global().debug == true
end

function Debug.SetOn(on)
    DB.Global().debug = on and true or nil
end

-- A value that is safe to save: hidden values become the word "hidden",
-- numbers are rounded, anything that is not plain data is dropped.
local function clean(value)
    if Compat.IsHidden(value) then
        return "hidden"
    end
    local kind = type(value)
    if kind == "number" then
        return math.floor(value * 10 + 0.5) / 10
    elseif kind == "string" or kind == "boolean" then
        return value
    end
    return nil
end

local function call(region, method, ...)
    local fn = region[method]
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c, d, e = pcall(fn, region, ...)
    if ok then
        return a, b, c, d, e
    end
    return nil
end

local function describe(region)
    local entry = {
        type = clean(call(region, "GetObjectType")),
        shown = clean(call(region, "IsShown")),
        visible = clean(call(region, "IsVisible")),
        left = clean(call(region, "GetLeft")),
        top = clean(call(region, "GetTop")),
        alpha = clean(call(region, "GetAlpha")),
        text = clean(call(region, "GetText")),
    }
    local width, height = call(region, "GetSize")
    entry.width, entry.height = clean(width), clean(height)
    local point, relative, relativePoint, x, y = call(region, "GetPoint", 1)
    if clean(point) then
        entry.point = {
            clean(point),
            type(relative) == "table" and clean(call(relative, "GetName")) or nil,
            clean(relativePoint), clean(x), clean(y),
        }
    end
    return entry
end

-- Describe a widget and the widgets kept in its fields (frame.name,
-- frame.health and so on), a few levels deep.
local function walk(out, path, region, depth, seen)
    if seen[region] then
        return
    end
    seen[region] = true
    out[path] = describe(region)
    if depth >= Debug.MAX_DEPTH then
        return
    end
    for key, child in pairs(region) do
        if type(key) == "string" and type(child) == "table" and type(child.GetObjectType) == "function" then
            walk(out, path .. "." .. key, child, depth + 1, seen)
        end
    end
end

--- Record every watched frame and the error log under a label ("load",
--- "exit" or "manual"). Returns the snapshot.
function Debug.Snapshot(label)
    local frames = {}
    for name, frame in pairs(roots) do
        pcall(walk, frames, name, frame, 0, {})
    end
    local errors = {}
    local log = Safety.GetLog()
    for i = 1, #log do
        errors[i] = { owner = log[i].owner, message = log[i].message, count = log[i].count }
    end
    local snapshot = {
        label = label,
        time = _G.date and _G.date("%Y-%m-%d %H:%M:%S") or nil,
        version = Compat.version,
        combat = InCombatLockdown() and true or false,
        frames = frames,
        errors = errors,
    }
    local store = DB.Global()
    if type(store.snapshots) ~= "table" then
        store.snapshots = {}
    end
    store.snapshots[label] = snapshot
    return snapshot
end

--- Ask the client for a screenshot. Returns true if it accepted.
function Debug.Screenshot()
    if type(_G.Screenshot) ~= "function" then
        return false
    end
    return (pcall(_G.Screenshot))
end

local function afterLoad()
    if Debug.IsOn() then
        Debug.Snapshot("load")
        Debug.Screenshot()
    end
end

Events.Listen("core.debug", "PUI_READY", function()
    if not Debug.IsOn() then
        return
    end
    ns.Print("Debug mode is on: frames and errors are recorded on /reload. Type /pui debug to turn it off.")
    local timer = _G.C_Timer
    if timer and type(timer.After) == "function" then
        timer.After(Debug.LOAD_DELAY, function()
            Safety.Call("core.debug", afterLoad)
        end)
    else
        afterLoad()
    end
end)

-- The state just before a /reload or logout is what the developer was
-- looking at, so it is the most useful snapshot.
Events.Register("core.debug", "PLAYER_LOGOUT", function()
    if Debug.IsOn() then
        Debug.Snapshot("exit")
    end
end)
