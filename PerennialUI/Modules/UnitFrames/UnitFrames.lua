-- SPDX-License-Identifier: GPL-3.0-or-later
-- Unit frames: the player and the target. Each is a glass panel with a name,
-- a level, a health bar and a power bar, and stands in for the game's own
-- frame. They are secure buttons, so left click targets and right click
-- opens the unit menu in combat too.
--
-- Combat values may be hidden from addons. Everything read from a unit goes
-- through ns.Compat before it is compared or formatted; a hidden value is
-- handed to the bar or font string untouched, which may draw it even though
-- Lua cannot read it.
local _, ns = ...

local Compat = ns.Compat
local Theme = ns.Theme
local Widgets = ns.Widgets

local HEIGHT = 48
local UNITS = {
    player = { title = "Player", mover = "unitframes_player", x = -260, y = -220 },
    target = { title = "Target", mover = "unitframes_target", x = 260, y = -220 },
}
local ORDER = { "player", "target" }

-- Power type names from the client, to colour tokens.
local POWER_TOKENS = { MANA = "mana", RAGE = "rage", ENERGY = "energy", FOCUS = "focus" }

-- Shown on the target frame in test mode when nothing is targeted.
local SAMPLE = {
    name = "Training Dummy", level = 60, health = 6200, healthMax = 8000,
    power = 3400, powerMax = 5000, powerToken = "MANA", reaction = 2,
    isPlayer = false, dead = false, connected = true, tapped = false,
}

local UnitFrames = ns.Modules.Register({
    id = "unitframes",
    title = "Unit frames",
    defaults = {
        player = true,
        target = true,
        hideDefault = true,
        healthText = "current",
        classColor = true,
        scale = 1,
        width = 220,
    },
    settings = {
        { type = "header", label = "Frames" },
        { key = "player", type = "toggle", label = "Player frame" },
        { key = "target", type = "toggle", label = "Target frame" },
        {
            key = "hideDefault", type = "toggle", label = "Hide the game's own frames",
            desc = "Only for the frames turned on above.",
        },
        { type = "header", label = "Look" },
        {
            key = "healthText", type = "select", label = "Health text",
            values = {
                { value = "none", label = "None" },
                { value = "current", label = "Current" },
                { value = "percent", label = "Percent" },
                { value = "both", label = "Current and percent" },
            },
        },
        {
            key = "classColor", type = "toggle", label = "Class colours",
            desc = "Colour a player's health bar by class.",
        },
        { key = "scale", type = "range", label = "Scale", min = 0.6, max = 1.6, step = 0.05 },
        { key = "width", type = "range", label = "Width", min = 160, max = 320, step = 10, advanced = true },
    },
    events = {
        PLAYER_ENTERING_WORLD = "UpdateAll",
        PLAYER_TARGET_CHANGED = "OnTargetChanged",
        UNIT_HEALTH = "OnUnitEvent",
        UNIT_MAXHEALTH = "OnUnitEvent",
        UNIT_POWER_UPDATE = "OnUnitEvent",
        UNIT_MAXPOWER = "OnUnitEvent",
        UNIT_DISPLAYPOWER = "OnUnitEvent",
        UNIT_NAME_UPDATE = "OnUnitEvent",
        UNIT_LEVEL = "OnUnitEvent",
        UNIT_FACTION = "OnUnitEvent",
        UNIT_CONNECTION = "OnUnitEvent",
    },
})

--- 950, 12.3k, 4.6m.
function UnitFrames.FormatNumber(value)
    if value >= 1000000 then
        return ("%.1fm"):format(value / 1000000)
    elseif value >= 1000 then
        return ("%.1fk"):format(value / 1000)
    end
    return ("%d"):format(value)
end

--- The health text for a mode, or nil when the numbers are not readable.
function UnitFrames.HealthText(mode, health, healthMax)
    if mode == "none" then
        return ""
    end
    if not health or not healthMax or healthMax <= 0 then
        return nil
    end
    local percent = ("%d%%"):format(math.floor(health / healthMax * 100 + 0.5))
    if mode == "percent" then
        return percent
    elseif mode == "both" then
        return UnitFrames.FormatNumber(health) .. "  " .. percent
    end
    return UnitFrames.FormatNumber(health)
end

-- Only a readable "not connected" counts: unknown is treated as online.
local function isOffline(state)
    return not Compat.IsHidden(state.connected) and state.connected == false
end

--- Which colour a health bar gets: a colour token, or "class".
function UnitFrames.HealthColor(unit, state, classColor)
    if Compat.Flag(state.dead, false) or Compat.Flag(state.tapped, false) or isOffline(state) then
        return "inactive"
    end
    if Compat.Flag(state.isPlayer, unit == "player") then
        return classColor and "class" or "health"
    end
    local reaction = Compat.Number(state.reaction)
    if not reaction then
        return "health"
    elseif reaction <= 3 then
        return "hostile"
    elseif reaction == 4 then
        return "neutral"
    end
    return "friendly"
end

--- Everything a frame shows about a unit, as the client returned it. Values
--- may be hidden: do not compare or format them without ns.Compat.
function UnitFrames.Read(unit)
    local _, classFile = UnitClass(unit)
    local _, powerToken = UnitPowerType(unit)
    return {
        name = UnitName(unit),
        level = UnitLevel(unit),
        health = UnitHealth(unit),
        healthMax = UnitHealthMax(unit),
        healthPercent = Compat.HealthPercent(unit),
        power = UnitPower(unit),
        powerMax = UnitPowerMax(unit),
        powerToken = powerToken,
        classFile = classFile,
        isPlayer = UnitIsPlayer(unit),
        reaction = UnitReaction(unit, "player"),
        dead = UnitIsDeadOrGhost(unit),
        connected = UnitIsConnected(unit),
        tapped = UnitIsTapDenied(unit),
    }
end

function UnitFrames:Build(unit)
    local info = UNITS[unit]
    local pad = Theme.Get("space.md")
    local left = pad + Theme.Get("border.rail")

    -- Template and click attributes checked in game on 1.60.1, in and out of combat.
    local frame = CreateFrame("Button", "PerennialUI" .. info.title .. "Frame", UIParent, "SecureUnitButtonTemplate")
    frame:SetAttribute("unit", unit)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")
    frame:RegisterForClicks("AnyUp")
    frame:SetSize(self.db.width, HEIGHT)
    frame:Hide()

    -- The look is a plain child frame, so restyling never touches the
    -- secure button itself.
    local skin = Widgets.Panel(frame, nil, { rail = true })
    skin:SetAllPoints(frame)

    frame.level = Widgets.Text(skin, "", "sm", "textMuted", "number")
    frame.level:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -pad, -7)
    frame.level:SetJustifyH("RIGHT")

    frame.name = Widgets.Text(skin, "", "md", "text")
    frame.name:SetPoint("TOPLEFT", skin, "TOPLEFT", left, -6)
    frame.name:SetPoint("RIGHT", frame.level, "LEFT", -Theme.Get("space.sm"), 0)
    frame.name:SetWordWrap(false)

    frame.health = Widgets.Bar(skin, "health")
    frame.health:SetPoint("TOPLEFT", skin, "TOPLEFT", left, -23)
    frame.health:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -pad, -23)
    frame.health:SetHeight(13)

    frame.healthText = Widgets.Text(frame.health, "", "sm", "text", "number")
    frame.healthText:SetPoint("RIGHT", frame.health, "RIGHT", -Theme.Get("space.sm"), 0)
    frame.healthText:SetJustifyH("RIGHT")
    frame.healthText:SetShadowOffset(1, -1)
    frame.healthText:SetShadowColor(0, 0, 0, 0.8)

    frame.power = Widgets.Bar(skin, "power")
    frame.power:SetPoint("TOPLEFT", frame.health, "BOTTOMLEFT", 0, -Theme.Get("space.xs"))
    frame.power:SetPoint("TOPRIGHT", frame.health, "BOTTOMRIGHT", 0, -Theme.Get("space.xs"))
    frame.power:SetHeight(4)

    return frame
end

--- Draw a state table (from Read, or sample data) on a unit's frame.
function UnitFrames:Render(unit, state)
    local frame = self.frames[unit]
    local db = self.db

    Compat.SetText(frame.name, state.name, "")
    local level = Compat.Number(state.level)
    frame.level:SetText(level and (level > 0 and tostring(level) or "??") or "")

    local color = UnitFrames.HealthColor(unit, state, db.classColor)
    local r, g, b
    if color == "class" then
        r, g, b = Compat.ClassColor(state.classFile)
    end
    if not r then
        r, g, b = Theme.Color(color == "class" and "health" or color)
    end
    frame.health:SetColor(r, g, b)

    local dead, offline = Compat.Flag(state.dead, false), isOffline(state)
    if dead or offline then
        Compat.SetBar(frame.health, 0, 1)
        frame.healthText:SetText(offline and "Offline" or "Dead")
    else
        Compat.SetBar(frame.health, state.health, state.healthMax)
        local health, healthMax = Compat.Number(state.health), Compat.Number(state.healthMax)
        local text = UnitFrames.HealthText(db.healthText, health, healthMax)
        if text then
            frame.healthText:SetText(text)
        else
            -- Not readable (the usual case on Forever): the client builds the
            -- text. If it cannot, show the current value on its own.
            local mode, shown = db.healthText, false
            if mode == "percent" then
                shown = Compat.SetFormatted(frame.healthText, "%.0f%%", state.healthPercent)
            elseif mode == "both" then
                shown = Compat.SetFormatted(frame.healthText, "%d  %.0f%%", state.health, state.healthPercent)
            end
            if not shown then
                Compat.SetText(frame.healthText, state.health, "")
            end
        end
    end

    local powerMax = Compat.Number(state.powerMax)
    frame.power:SetShown(powerMax ~= 0)
    Compat.SetBar(frame.power, state.power, state.powerMax)
    local token = not Compat.IsHidden(state.powerToken) and POWER_TOKENS[state.powerToken] or "power"
    frame.power:SetColor(Theme.Color(token))
end

function UnitFrames:Update(unit)
    if not self.frames or not self.frames[unit] then
        return
    end
    if Compat.Flag(UnitExists(unit), true) then
        self:Render(unit, UnitFrames.Read(unit))
    elseif ns.state.testMode then
        self:Render(unit, SAMPLE)
    end
end

function UnitFrames:UpdateAll()
    for i = 1, #ORDER do
        self:Update(ORDER[i])
    end
end

function UnitFrames:OnUnitEvent(_, unit)
    if UNITS[unit] then
        self:Update(unit)
    end
end

function UnitFrames:OnTargetChanged()
    self:Update("target")
end

--- Build the frames if needed and bring size, visibility and the game's own
--- frames in line with the settings. These are protected changes, so they
--- wait for combat to end.
function UnitFrames:Apply()
    self:RunWhenSafe("apply", function()
        local db = self.db
        if not self.frames then
            if not self.active then
                return
            end
            local frames = {}
            for i = 1, #ORDER do
                frames[ORDER[i]] = self:Build(ORDER[i])
            end
            self.frames = frames
        end
        if self.active and not self.movers then
            self.movers = true
            for i = 1, #ORDER do
                local info = UNITS[ORDER[i]]
                self:RegisterMover(info.mover, self.frames[ORDER[i]], { title = info.title, x = info.x, y = info.y })
            end
        end
        for i = 1, #ORDER do
            local unit = ORDER[i]
            local frame = self.frames[unit]
            local want = self.active and db[unit] and true or false
            frame:SetSize(db.width, HEIGHT)
            frame:SetScale(db.scale)
            if unit == "target" and want and not ns.state.testMode then
                -- The client shows the frame while a target exists, even in combat.
                RegisterUnitWatch(frame)
            else
                UnregisterUnitWatch(frame)
                frame:SetShown(want)
            end
            if want and db.hideDefault then
                Compat.HideDefault(unit)
            else
                Compat.ShowDefault(unit)
            end
            ns.Layout.Apply(UNITS[unit].mover)
        end
        self:UpdateAll()
    end)
end

-- Frames are built inside Apply, so a first start during combat waits too.
function UnitFrames:OnEnable()
    self.active = true
    self:Listen("PUI_TEST_MODE", "Apply")
    self:Apply()
end

-- The core has already removed this module's movers and queued work. If
-- combat is on, the frames stay until it ends, then the game's own return.
function UnitFrames:OnDisable()
    self.active = false
    self.movers = false
    self:Apply()
end

function UnitFrames:OnSettingChanged()
    self:Apply()
end
