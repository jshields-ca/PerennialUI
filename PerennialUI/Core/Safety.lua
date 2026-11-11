-- SPDX-License-Identifier: GPL-3.0-or-later
-- Safety net. Every module handler runs through Safety.Call so that one
-- broken module cannot take the rest of the UI down. Errors are recorded per
-- owner; an owner that errors too often in a short window is "tripped" and
-- the trip handler (the module registry) pauses it.
local _, ns = ...

local Safety = {}
ns.Safety = Safety

Safety.threshold = 5 -- errors within `window` seconds that trip an owner
Safety.window = 10
Safety.maxLog = 50

local unpack = unpack or table.unpack -- luacheck: ignore 143

local log = {} -- oldest first
local recent = {} -- owner -> list of error timestamps inside the window
local tripped = {} -- owner -> true
local tripHandler
local pendingStack

local function handler(err)
    pendingStack = debugstack and debugstack(2) or nil
    return err
end

local function record(owner, err)
    local now = GetTime()
    local message = tostring(err)
    local stack = pendingStack
    pendingStack = nil

    local last = log[#log]
    if last and last.owner == owner and last.message == message then
        last.count = last.count + 1
        last.time = now
    else
        log[#log + 1] = { owner = owner, message = message, stack = stack, time = now, count = 1 }
        if #log > Safety.maxLog then
            table.remove(log, 1)
        end
    end

    local times = recent[owner]
    if not times then
        times = {}
        recent[owner] = times
    end
    times[#times + 1] = now
    while times[1] and now - times[1] > Safety.window do
        table.remove(times, 1)
    end

    if #times >= Safety.threshold and not tripped[owner] then
        tripped[owner] = true
        if tripHandler then
            -- The trip handler must never be able to break the safety net.
            pcall(tripHandler, owner, message)
        end
    end
end

local function finish(owner, ok, ...)
    if ok then
        return true, ...
    end
    local err = ...
    record(owner, err)
    return false, err
end

-- WoW's xpcall forwards extra arguments; stock Lua 5.1 (used in CI) does not.
local forwardsArgs = select(2, xpcall(function(flag)
    return flag == true
end, handler, true)) == true

--- Run fn(...) protected. Returns true plus fn's results, or false plus the error.
function Safety.Call(owner, fn, ...)
    if forwardsArgs then
        return finish(owner, xpcall(fn, handler, ...))
    end
    local n = select("#", ...)
    local args = { ... }
    return finish(owner, xpcall(function()
        return fn(unpack(args, 1, n))
    end, handler))
end

local function resultsOnly(ok, ...)
    if ok then
        return ...
    end
end

--- Returns a function that runs fn protected and returns nothing on error.
function Safety.Wrap(owner, fn)
    return function(...)
        return resultsOnly(Safety.Call(owner, fn, ...))
    end
end

function Safety.IsTripped(owner)
    return tripped[owner] == true
end

--- Forget an owner's recent errors so it can be enabled again.
function Safety.Reset(owner)
    tripped[owner] = nil
    recent[owner] = nil
end

--- fn(owner, message) is called once when an owner trips.
function Safety.SetTripHandler(fn)
    tripHandler = fn
end

--- The error log, oldest first. Entries: owner, message, stack, time, count.
function Safety.GetLog()
    return log
end

function Safety.ClearLog()
    for i = #log, 1, -1 do
        log[i] = nil
    end
end
