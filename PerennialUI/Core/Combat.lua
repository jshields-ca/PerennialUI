-- SPDX-License-Identifier: GPL-3.0-or-later
-- Combat lockdown queue. Protected frames cannot be moved, shown or
-- reconfigured in combat, so that work is queued and replayed afterwards.
local _, ns = ...

local Events = ns.Events
local Safety = ns.Safety

local Combat = {}
ns.Combat = Combat

local queue = {} -- array of { owner = , key = , fn = }

function Combat.InLockdown()
    return InCombatLockdown() and true or false
end

--- Run fn now, or once combat ends. A later call with the same owner and key
--- replaces the earlier one, so repeated changes only apply their final state.
--- Returns true if fn ran immediately.
function Combat.RunWhenSafe(owner, key, fn)
    if not Combat.InLockdown() then
        Safety.Call(owner, fn)
        return true
    end
    for i = 1, #queue do
        if queue[i].owner == owner and queue[i].key == key then
            table.remove(queue, i)
            break
        end
    end
    queue[#queue + 1] = { owner = owner, key = key, fn = fn }
    return false
end

--- Drop everything an owner has queued.
function Combat.Cancel(owner)
    for i = #queue, 1, -1 do
        if queue[i].owner == owner then
            table.remove(queue, i)
        end
    end
end

function Combat.Pending()
    return #queue
end

local function flush()
    local pending = queue
    queue = {}
    for i = 1, #pending do
        Safety.Call(pending[i].owner, pending[i].fn)
    end
end

Events.Register("core.combat", "PLAYER_REGEN_ENABLED", flush)
