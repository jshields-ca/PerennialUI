-- SPDX-License-Identifier: GPL-3.0-or-later
-- Event bus. One frame receives every game event and fans it out to owners
-- through the safety net. The same bus carries internal messages (PUI_*),
-- which are never registered with the client.
local _, ns = ...

local Safety = ns.Safety

local Events = {}
ns.Events = Events

local frame = CreateFrame("Frame")
local lists = {} -- event -> array of { owner = , fn = }; fn == nil means removed
local isGameEvent = {}
local dirty = {}
local depth = 0

local function compact(event)
    local list = lists[event]
    if not list then
        return
    end
    local kept = {}
    for i = 1, #list do
        if list[i].fn then
            kept[#kept + 1] = list[i]
        end
    end
    if #kept == 0 then
        lists[event] = nil
        if isGameEvent[event] then
            isGameEvent[event] = nil
            frame:UnregisterEvent(event)
        end
    else
        lists[event] = kept
    end
end

local function dispatch(event, ...)
    local list = lists[event]
    if not list then
        return
    end
    depth = depth + 1
    -- Handlers added during dispatch are not called for this event.
    for i = 1, #list do
        local entry = list[i]
        if entry.fn then
            Safety.Call(entry.owner, entry.fn, event, ...)
        end
    end
    depth = depth - 1
    if depth == 0 and next(dirty) then
        for name in pairs(dirty) do
            compact(name)
            dirty[name] = nil
        end
    end
end

local function add(owner, event, fn, game)
    if type(event) ~= "string" or type(fn) ~= "function" then
        error("Events: expected (owner, event name, function)", 3)
    end
    local list = lists[event]
    if not list then
        list = {}
        lists[event] = list
    end
    for i = 1, #list do
        if list[i].owner == owner and list[i].fn then
            list[i].fn = fn
            return
        end
    end
    list[#list + 1] = { owner = owner, fn = fn }
    if game and not isGameEvent[event] then
        isGameEvent[event] = true
        frame:RegisterEvent(event)
    end
end

--- Subscribe owner to a game event. fn(event, ...) runs inside the safety net.
function Events.Register(owner, event, fn)
    add(owner, event, fn, true)
end

--- Subscribe owner to an internal message sent with Events.Fire.
function Events.Listen(owner, message, fn)
    add(owner, message, fn, false)
end

function Events.Unregister(owner, event)
    local list = lists[event]
    if not list then
        return
    end
    for i = 1, #list do
        if list[i].owner == owner then
            list[i].fn = nil
        end
    end
    if depth == 0 then
        compact(event)
    else
        dirty[event] = true
    end
end

function Events.UnregisterAll(owner)
    local names = {}
    for event in pairs(lists) do
        names[#names + 1] = event
    end
    for i = 1, #names do
        Events.Unregister(owner, names[i])
    end
end

--- Send an internal message to every listener.
function Events.Fire(message, ...)
    dispatch(message, ...)
end

frame:SetScript("OnEvent", function(_, event, ...)
    dispatch(event, ...)
end)
