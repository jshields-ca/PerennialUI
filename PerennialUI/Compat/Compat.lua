-- SPDX-License-Identifier: GPL-3.0-or-later
-- Compatibility layer. Modules never branch on the client version or call a
-- flavor-specific API directly: they ask Compat. Forever comes first; Classic
-- Era shims are added here later without touching modules.
local _, ns = ...

local Compat = {}
ns.Compat = Compat

local version, build, _, interface = GetBuildInfo()

Compat.version = version
Compat.build = build
Compat.interface = interface or 0

-- Forever is patch 1.60.x (interface 160xx). Classic Era is 1.15.x (115xx).
Compat.isForever = Compat.interface >= 16000 and Compat.interface < 20000
Compat.isClassicEra = Compat.interface >= 11300 and Compat.interface < 16000

--- True if the client is hiding this value from addons. On Forever 1.60.1
--- current health and power are hidden all the time, not only in combat; a
--- target's maximum health is hidden in combat. (Seen in game, 2026-11-15.)
function Compat.IsHidden(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

--- The value as a number, or fallback when it is hidden or not a number.
--- Use this for every combat value before doing arithmetic on it.
function Compat.Number(value, fallback)
    if Compat.IsHidden(value) or type(value) ~= "number" then
        return fallback
    end
    return value
end

--- The value as true or false, or fallback when it is hidden. Use this
--- before branching on a unit flag (dead, connected, is a player).
function Compat.Flag(value, fallback)
    if Compat.IsHidden(value) then
        return fallback
    end
    return value and true or false
end

--- Fill a status bar from a value and its maximum. Returns:
---   "known"    both were readable numbers
---   "hidden"   they were hidden, and the bar accepted them directly
---   "unknown"  the bar could not be set; it is shown full
--- Forever's status bars accept hidden values (seen in game). On a client
--- that refuses them, the bar shows full instead of erroring.
function Compat.SetBar(bar, value, max)
    local known, knownMax = Compat.Number(value), Compat.Number(max)
    if known and knownMax then
        bar:SetMinMaxValues(0, knownMax > 0 and knownMax or 1)
        bar:SetValue(known)
        return "known"
    end
    if Compat.IsHidden(value) and (knownMax or Compat.IsHidden(max)) then
        local ok = pcall(function()
            bar:SetMinMaxValues(0, max)
            bar:SetValue(value)
        end)
        if ok then
            return "hidden"
        end
    end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    return "unknown"
end

--- Put a string or number into a font string. A hidden value is handed to
--- the font string directly; if the client refuses, fallback is shown.
--- Returns true if the value itself is on screen.
--- Forever's font strings accept hidden values (seen in game).
function Compat.SetText(label, value, fallback)
    local kind = type(value)
    if Compat.IsHidden(value) then
        if pcall(label.SetText, label, value) then
            return true
        end
    elseif kind == "string" or kind == "number" then
        label:SetText(value)
        return true
    end
    label:SetText(fallback or "")
    return false
end

local function setFormatted(label, pattern, ...)
    label:SetText(pattern:format(...))
end

--- Format values that may be hidden and put the result in a font string,
--- without Lua ever looking at them. Returns true if the text was set; on
--- false the font string is unchanged, so the caller shows something else.
--- TODO(verify): that Forever's string.format accepts hidden values.
function Compat.SetFormatted(label, pattern, ...)
    return (pcall(setFormatted, label, pattern, ...))
end

--- A unit's health as 0 to 100, from the client. It may be hidden, so hand
--- it to SetFormatted. Nil when the client cannot give it.
--- TODO(verify): the arguments (unit, use predicted health, scale) and that
--- CurveConstants.ScaleTo100 gives 0 to 100. Check that full health reads 100%.
function Compat.HealthPercent(unit)
    local scale = CurveConstants and CurveConstants.ScaleTo100
    if type(UnitHealthPercent) ~= "function" or scale == nil then
        return nil
    end
    local ok, percent = pcall(UnitHealthPercent, unit, true, scale)
    if ok then
        return percent
    end
    return nil
end

--- r, g, b for a class file name such as "WARRIOR", or nil.
function Compat.ClassColor(classFile)
    if Compat.IsHidden(classFile) or type(classFile) ~= "string" then
        return nil
    end
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if not color then
        return nil
    end
    return color.r, color.g, color.b
end

-- The game's own frames that a module can stand in for, by key.
local DEFAULT_FRAMES = { player = "PlayerFrame", target = "TargetFrame" }
local originalParent = {}
local hiddenParent

--- Hide one of the game's own frames by moving it under a hidden parent. The
--- frame keeps running, so putting it back is exact. Call out of combat
--- (through RunWhenSafe). Returns true if the frame is now hidden.
function Compat.HideDefault(key)
    local frame = _G[DEFAULT_FRAMES[key] or ""]
    if type(frame) ~= "table" then
        return false
    end
    if not originalParent[key] then
        if not hiddenParent then
            hiddenParent = CreateFrame("Frame")
            hiddenParent:Hide()
        end
        originalParent[key] = frame:GetParent() or UIParent
        frame:SetParent(hiddenParent)
    end
    return true
end

--- Put back a frame hidden with HideDefault. Call out of combat.
function Compat.ShowDefault(key)
    local frame = _G[DEFAULT_FRAMES[key] or ""]
    if type(frame) == "table" and originalParent[key] then
        frame:SetParent(originalParent[key])
    end
    originalParent[key] = nil
end

function Compat.IsDefaultHidden(key)
    return originalParent[key] ~= nil
end

-- What the addon relies on from the client. /pui api reports which of
-- these exist, so guesses can be replaced with facts.
local PROBE_GLOBALS = {
    "issecretvalue", "InCombatLockdown", "RegisterUnitWatch", "UnregisterUnitWatch",
    "UnitExists", "UnitName", "UnitLevel", "UnitClass", "UnitIsPlayer", "UnitReaction",
    "UnitHealth", "UnitHealthMax", "UnitHealthPercent", "UnitPower", "UnitPowerMax", "UnitPowerType",
    "UnitIsDeadOrGhost", "UnitIsConnected", "UnitIsTapDenied",
    "RAID_CLASS_COLORS", "PlayerFrame", "TargetFrame", "C_AddOns.GetAddOnMetadata",
    "C_CurveUtil", "C_Secrets", "SecureUnitButton_OnLoad",
    "CurveConstants.ScaleTo100", "AbbreviateNumbers",
}
local PROBE_METHODS = {
    Texture = { "SetTextureSliceMargins", "ClearTextureSlice", "SetColorTexture" },
    StatusBar = { "SetStatusBarTexture", "SetStatusBarColor", "SetMinMaxValues", "SetValue" },
    Frame = { "SetAttribute", "RegisterUnitEvent", "SetClampedToScreen" },
}
local PROBE_UNIT_VALUES = { "UnitHealth", "UnitHealthMax", "UnitPower", "UnitName", "UnitLevel" }

local function lookup(path)
    local value = _G
    for part in path:gmatch("[^%.]+") do
        if type(value) ~= "table" then
            return nil
        end
        value = value[part]
    end
    return value
end

--- Check the client for everything the addon relies on. Returns a plain
--- table: missing (names), present (a count), and values (for the player
--- and target, whether each reading is a number, a string or "hidden").
function Compat.Probe()
    local report = {
        version = Compat.version, build = Compat.build, interface = Compat.interface,
        combat = InCombatLockdown() and true or false,
        present = 0, missing = {}, values = {},
    }
    local function note(name, found)
        if found then
            report.present = report.present + 1
        else
            report.missing[#report.missing + 1] = name
        end
    end
    for i = 1, #PROBE_GLOBALS do
        note(PROBE_GLOBALS[i], lookup(PROBE_GLOBALS[i]) ~= nil)
    end
    local frame = CreateFrame("Frame")
    local samples = { Frame = frame, Texture = frame:CreateTexture(), StatusBar = CreateFrame("StatusBar") }
    for kind, methods in pairs(PROBE_METHODS) do
        for i = 1, #methods do
            note(kind .. ":" .. methods[i], samples[kind][methods[i]] ~= nil)
        end
    end
    for _, unit in ipairs({ "player", "target" }) do
        for i = 1, #PROBE_UNIT_VALUES do
            local read = lookup(PROBE_UNIT_VALUES[i])
            if type(read) == "function" then
                local ok, value = pcall(read, unit)
                report.values[PROBE_UNIT_VALUES[i] .. "(" .. unit .. ")"] =
                    not ok and "error" or (Compat.IsHidden(value) and "hidden" or type(value))
            end
        end
        local percent = Compat.HealthPercent(unit)
        report.values["HealthPercent(" .. unit .. ")"] = Compat.IsHidden(percent) and "hidden" or type(percent)
    end
    -- Whether text can be built from a value Lua cannot read.
    report.values["format(UnitHealth)"] = pcall(string.format, "%d", UnitHealth("player")) and "ok" or "refused"
    table.sort(report.missing)
    return report
end
