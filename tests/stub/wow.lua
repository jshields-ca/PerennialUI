-- SPDX-License-Identifier: GPL-3.0-or-later
-- A deliberately small stand-in for the WoW client API, enough to load the
-- core outside the game. Add to it only what the code under test calls.
local Stub = {}

local frames

--- Install fresh globals. Call before loading the addon in each test.
function Stub.reset()
    frames = {}
    Stub.now = 1000
    Stub.inCombat = false
    Stub.printed = {}
    Stub.interface = 16001

    _G.PerennialUI = nil
    _G.PerennialUIDB = nil
    _G.PerennialUICharDB = nil
    _G.SlashCmdList = {}
    _G.C_AddOns = nil
    _G.debugstack = nil
    _G.issecretvalue = nil

    _G.GetTime = function()
        return Stub.now
    end
    _G.InCombatLockdown = function()
        return Stub.inCombat
    end
    _G.UnitName = function()
        return "Tester"
    end
    _G.GetRealmName = function()
        return "Stubrealm"
    end
    _G.GetBuildInfo = function()
        return "1.60.1", "99999", "Nov 1 2026", Stub.interface
    end
    _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring((select(i, ...)))
        end
        Stub.printed[#Stub.printed + 1] = table.concat(parts, " ")
    end
    _G.CreateFrame = function()
        local frame = { events = {}, scripts = {} }
        function frame:RegisterEvent(event)
            self.events[event] = true
        end
        function frame:UnregisterEvent(event)
            self.events[event] = nil
        end
        function frame:IsEventRegistered(event)
            return self.events[event] == true
        end
        function frame:SetScript(name, fn)
            self.scripts[name] = fn
        end
        frames[#frames + 1] = frame
        return frame
    end
end

--- Deliver a game event to every frame registered for it.
function Stub.fire(event, ...)
    for i = 1, #frames do
        local frame = frames[i]
        if frame.events[event] and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, event, ...)
        end
    end
end

--- True if any frame is registered for the game event.
function Stub.isRegistered(event)
    for i = 1, #frames do
        if frames[i].events[event] then
            return true
        end
    end
    return false
end

--- True if any printed line contains the text.
function Stub.printedContains(text)
    for i = 1, #Stub.printed do
        if Stub.printed[i]:find(text, 1, true) then
            return true
        end
    end
    return false
end

function Stub.advance(seconds)
    Stub.now = Stub.now + seconds
end

return Stub
