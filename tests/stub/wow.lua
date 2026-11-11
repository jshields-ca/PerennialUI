-- SPDX-License-Identifier: GPL-3.0-or-later
-- A deliberately small stand-in for the WoW client API, enough to load the
-- addon outside the game. Frames record what is done to them and ignore any
-- method they do not know, so the stub proves logic, not API correctness:
-- UI code still has to be checked in the client.
local Stub = {}

local frames

local function noop() end

local Region = {}
local regionMeta = {
    __index = function(_, key)
        return Region[key] or noop
    end,
}

local function newRegion(kind, name, parent)
    local region = setmetatable({
        kind = kind,
        name = name,
        parent = parent,
        shown = true,
        events = {},
        scripts = {},
        points = {},
        width = 0,
        height = 0,
        scale = 1,
    }, regionMeta)
    return region
end

function Region:Show()
    self.shown = true
    if self.scripts.OnShow then
        self.scripts.OnShow(self)
    end
end
function Region:Hide()
    self.shown = false
    if self.scripts.OnHide then
        self.scripts.OnHide(self)
    end
end
function Region:SetShown(shown)
    if shown then
        self:Show()
    else
        self:Hide()
    end
end
function Region:IsShown()
    return self.shown
end
function Region:GetName()
    return self.name
end
function Region:GetParent()
    return self.parent
end
function Region:SetSize(width, height)
    self.width, self.height = width, height
end
function Region:SetWidth(width)
    self.width = width
end
function Region:SetHeight(height)
    self.height = height
end
function Region:GetWidth()
    return self.width
end
function Region:GetHeight()
    return self.height
end
function Region:GetSize()
    return self.width, self.height
end
function Region:SetScale(scale)
    self.scale = scale
end
function Region:GetScale()
    return self.scale
end
function Region:GetEffectiveScale()
    return self.scale
end
function Region:ClearAllPoints()
    self.points = {}
end
function Region:SetPoint(point, relativeTo, relativePoint, x, y)
    self.points[#self.points + 1] = { point, relativeTo, relativePoint, x, y }
end
--- Tests set frame.center = { x, y } to place a frame on the fake screen.
function Region:GetCenter()
    local center = self.center or { 0, 0 }
    return center[1], center[2]
end
function Region:SetText(text)
    self.text = text
    if self.scripts.OnTextChanged then
        self.scripts.OnTextChanged(self, true)
    end
end
function Region:GetText()
    return self.text or ""
end
function Region:SetMinMaxValues(low, high)
    self.min, self.max = low, high
end
function Region:SetValue(value)
    self.value = value
    if self.scripts.OnValueChanged then
        self.scripts.OnValueChanged(self, value, false)
    end
end
function Region:GetValue()
    return self.value
end
function Region:SetScript(name, fn)
    self.scripts[name] = fn
end
function Region:GetScript(name)
    return self.scripts[name]
end
function Region:RegisterEvent(event)
    self.events[event] = true
end
function Region:UnregisterEvent(event)
    self.events[event] = nil
end
function Region:IsEventRegistered(event)
    return self.events[event] == true
end
function Region:CreateTexture()
    return newRegion("Texture", nil, self)
end
function Region:CreateFontString()
    return newRegion("FontString", nil, self)
end
function Region:GetVerticalScrollRange()
    return 0
end
function Region:GetVerticalScroll()
    return 0
end
--- Test helper: run a script as the client would, e.g. frame:Run("OnClick", "LeftButton").
function Region:Run(script, ...)
    if self.scripts[script] then
        return self.scripts[script](self, ...)
    end
end

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
    _G.PerennialUISettings = nil
    _G.SlashCmdList = {}
    _G.UISpecialFrames = {}
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
    _G.CreateFrame = function(kind, name, parent)
        local frame = newRegion(kind, name, parent)
        frames[#frames + 1] = frame
        if name then
            _G[name] = frame
        end
        return frame
    end
    _G.UIParent = _G.CreateFrame("Frame", "UIParent")
    _G.UIParent:SetSize(1920, 1080)
    _G.UIParent.center = { 960, 540 }
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
