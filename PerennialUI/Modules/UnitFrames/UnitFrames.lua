-- SPDX-License-Identifier: GPL-3.0-or-later
-- Unit frames: the player and the target. Each is a glass panel with an
-- optional portrait, a name row (name, status, level), a health bar, a
-- power bar and a row of health numbers, and stands in for the game's own
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

local HEIGHT = 64
local CHIP_INSET = 6 -- space above and below the portrait chip
local CHIP = HEIGHT - CHIP_INSET * 2
local ROW_INSET = 6 -- from the top edge to the name row, and the bottom edge to the numbers row
local BAR_TOP = 24 -- from the top edge to the health bar

-- Words for a creature's rank, and letters for a group role.
local TAGS = { elite = "Elite", rare = "Rare", rareelite = "Rare elite", worldboss = "Boss" }
local ROLES = {
    TANK = { letter = "T", color = "roleTank" },
    HEALER = { letter = "H", color = "roleHealer" },
    DAMAGER = { letter = "D", color = "roleDamage" },
}
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
        nameStyle = "full",
        showLevel = true,
        showLeader = true,
        showRole = true,
        showCombat = true,
        showTag = true,
        showMarker = true,
        playerPortrait = "none",
        targetPortrait = "none",
        healthText = "current",
        classColor = true,
        scale = 1,
        width = 260,
    },
    settings = {
        { type = "header", label = "Frames" },
        { key = "player", type = "toggle", label = "Player frame" },
        { key = "target", type = "toggle", label = "Target frame" },
        {
            key = "hideDefault", type = "toggle", label = "Hide the game's own frames",
            desc = "Only for the frames turned on above.",
        },
        { type = "header", label = "Portrait" },
        {
            key = "playerPortrait", type = "select", label = "Player portrait",
            values = {
                { value = "none", label = "Off" },
                { value = "2d", label = "2D" },
                { value = "3d", label = "3D" },
            },
        },
        {
            key = "targetPortrait", type = "select", label = "Target portrait",
            values = {
                { value = "none", label = "Off" },
                { value = "2d", label = "2D" },
                { value = "3d", label = "3D" },
            },
        },
        { type = "header", label = "Name row" },
        { key = "showLevel", type = "toggle", label = "Level" },
        {
            key = "showLeader", type = "toggle", label = "Group leader",
            desc = "L for the leader, A for an assistant.",
        },
        {
            key = "showRole", type = "toggle", label = "Group role",
            desc = "T for tank, H for healer, D for damage.",
        },
        {
            key = "showCombat", type = "toggle", label = "Combat and resting",
            desc = "A red dot in combat, zz while resting.",
        },
        { key = "showTag", type = "toggle", label = "Elite, rare and boss" },
        { key = "showMarker", type = "toggle", label = "Raid marker" },
        { type = "header", label = "Look" },
        {
            key = "nameStyle", type = "select", label = "Name",
            values = {
                { value = "full", label = "First and last" },
                { value = "first", label = "First only" },
            },
        },
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
        { key = "width", type = "range", label = "Width", min = 200, max = 360, step = 10, advanced = true },
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
        UNIT_PORTRAIT_UPDATE = "OnPortraitEvent",
        UNIT_MODEL_CHANGED = "OnPortraitEvent",
        UNIT_FLAGS = "OnUnitEvent",
        UNIT_CLASSIFICATION_CHANGED = "OnUnitEvent",
        GROUP_ROSTER_UPDATE = "OnStatusEvent",
        PARTY_LEADER_CHANGED = "OnStatusEvent",
        PLAYER_ROLES_ASSIGNED = "OnStatusEvent",
        PLAYER_REGEN_DISABLED = "OnStatusEvent",
        PLAYER_REGEN_ENABLED = "OnStatusEvent",
        PLAYER_UPDATE_RESTING = "OnStatusEvent",
        RAID_TARGET_UPDATE = "OnStatusEvent",
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
--- "both" returns two texts: current health, then the percentage that is
--- shown to its left.
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
        return UnitFrames.FormatNumber(health), percent
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
    -- On Forever 1.60.1 the second value is the character's last name (seen
    -- in game for the player and other players). Creatures have none.
    local name, surname = UnitName(unit)
    local resting
    if unit == "player" then
        resting = Compat.Read("IsResting")
    end
    return {
        name = name,
        surname = surname,
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
        -- TODO(verify): these seven on the Forever client. Compat.Read gives
        -- nil for a function the client does not have.
        leader = Compat.Read("UnitIsGroupLeader", unit),
        assistant = Compat.Read("UnitIsGroupAssistant", unit),
        role = Compat.Read("UnitGroupRolesAssigned", unit),
        combat = Compat.Read("UnitAffectingCombat", unit),
        resting = resting,
        classification = Compat.Read("UnitClassification", unit),
        marker = Compat.Read("GetRaidTargetIndex", unit),
    }
end

function UnitFrames:Build(unit)
    local info = UNITS[unit]
    local pad = Theme.Get("space.md")

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
    frame.skin = skin

    -- The chip: a square at the left edge for the portrait. Nothing is drawn
    -- over it. With portraits off it is hidden and the rows use its space.
    local chip = CreateFrame("Frame", nil, skin)
    chip:SetPoint("TOPLEFT", skin, "TOPLEFT", pad + Theme.Get("border.rail"), -CHIP_INSET)
    chip:SetSize(CHIP, CHIP)
    chip.fill = chip:CreateTexture(nil, "BACKGROUND")
    chip.fill:SetAllPoints(chip)
    chip.fill:SetColorTexture(Theme.Color("track"))
    chip.picture = chip:CreateTexture(nil, "ARTWORK")
    chip.picture:SetAllPoints(chip)
    chip.model = false -- made the first time a 3D portrait is asked for
    frame.chip = chip

    -- Name row: the name on the left; on the right the level and the status
    -- items, placed right to left by arrangeStatus so hidden ones leave no gap.
    frame.name = Widgets.Text(skin, "", "md", "text")
    frame.name:SetWordWrap(false)

    frame.level = Widgets.Text(skin, "", "sm", "textMuted", "number")
    frame.tag = Widgets.Text(skin, "", "sm", "textMuted")
    frame.role = Widgets.Text(skin, "", "sm", "text", "number")
    frame.leader = Widgets.Text(skin, "", "sm", "accent", "number")
    frame.rest = Widgets.Text(skin, "zz", "sm", "textMuted", "number")
    frame.combat = skin:CreateTexture(nil, "OVERLAY")
    frame.combat:SetSize(6, 6)
    frame.combat:SetColorTexture(Theme.Color("hostile"))
    frame.marker = skin:CreateTexture(nil, "OVERLAY")
    frame.marker:SetSize(14, 14)
    frame.status = { frame.level, frame.tag, frame.role, frame.leader, frame.rest, frame.combat, frame.marker }
    for i = 1, #frame.status do
        frame.status[i].on = false
    end

    frame.health = Widgets.Bar(skin, "health")
    frame.health:SetHeight(14)

    frame.power = Widgets.Bar(skin, "power")
    frame.power:SetPoint("TOPLEFT", frame.health, "BOTTOMLEFT", 0, -Theme.Get("space.xs"))
    frame.power:SetPoint("TOPRIGHT", frame.health, "BOTTOMRIGHT", 0, -Theme.Get("space.xs"))
    frame.power:SetHeight(4)

    -- Bottom row: the health numbers, off the bar (which can be any class
    -- colour) so they always sit on the panel and stay readable.
    frame.healthText = Widgets.Text(skin, "", "sm", "text", "number")
    frame.healthText:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", -pad, ROW_INSET)
    frame.healthText:SetJustifyH("RIGHT")

    -- The percentage, when both it and the current value are shown.
    frame.healthSide = Widgets.Text(skin, "", "sm", "textMuted", "number")

    return frame
end

-- Place the name-row items that are on, right to left, then give the name
-- the room that is left. Each item carries item.on (true or false).
local function arrangeStatus(frame)
    local skin = frame.skin
    local gap = Theme.Get("space.sm")
    local anchor
    for i = 1, #frame.status do
        local item = frame.status[i]
        item:ClearAllPoints()
        if item.on then
            if anchor then
                item:SetPoint("RIGHT", anchor, "LEFT", -gap, 0)
            else
                item:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -Theme.Get("space.md"), -ROW_INSET - 1)
            end
            anchor = item
        end
        item:SetShown(item.on)
    end
    frame.name:ClearAllPoints()
    frame.name:SetPoint("TOPLEFT", skin, "TOPLEFT", frame.contentX, -ROW_INSET)
    if anchor then
        frame.name:SetPoint("RIGHT", anchor, "LEFT", -gap, 0)
    else
        frame.name:SetPoint("RIGHT", skin, "RIGHT", -Theme.Get("space.md"), 0)
    end
end

--- Place the chip and the rows for the current settings: with a portrait
--- the rows start to the right of the chip, without one they use the full
--- width. Sets frame.chip.mode to "none", "2d" or "3d".
function UnitFrames:Arrange(unit)
    local frame, db = self.frames[unit], self.db
    local chip, skin = frame.chip, frame.skin
    local pad = Theme.Get("space.md")

    local mode = db[unit .. "Portrait"]
    if mode == "3d" and not chip.model then
        chip.model = Compat.CreateModel(chip) or false
        if chip.model then
            chip.model:SetAllPoints(chip)
        end
    end
    if mode == "3d" and not chip.model then
        mode = "2d" -- this client cannot draw a model here
    end
    chip.mode = mode

    local portrait = mode ~= "none"
    chip:SetShown(portrait)
    chip.picture:SetShown(mode == "2d")
    if chip.model then
        chip.model:SetShown(mode == "3d")
    end

    local x = pad + Theme.Get("border.rail") + (portrait and (CHIP + Theme.Get("space.sm")) or 0)
    frame.contentX = x
    frame.health:ClearAllPoints()
    frame.health:SetPoint("TOPLEFT", skin, "TOPLEFT", x, -BAR_TOP)
    frame.health:SetPoint("TOPRIGHT", skin, "TOPRIGHT", -pad, -BAR_TOP)
    frame.healthSide:ClearAllPoints()
    frame.healthSide:SetPoint("BOTTOMLEFT", skin, "BOTTOMLEFT", x, ROW_INSET)
    arrangeStatus(frame)
end

--- Draw the unit in the chip. Kept apart from Render: a portrait changes
--- rarely, and resetting a 3D model on every health change would flicker.
function UnitFrames:UpdatePortrait(unit)
    local frame = self.frames and self.frames[unit]
    if not frame then
        return
    end
    local chip = frame.chip
    local exists = Compat.Flag(UnitExists(unit), true)
    if chip.mode == "2d" then
        if not (exists and Compat.SetPortrait(chip.picture, unit)) then
            chip.picture:SetTexture(nil)
        end
    elseif chip.mode == "3d" then
        if not (exists and Compat.SetModelUnit(chip.model, unit)) then
            Compat.ClearModel(chip.model)
        end
    end
end

-- First and last name where there is a last name, otherwise the first alone.
local function setName(label, state, style)
    local first, last = state.name, state.surname
    if style == "full" then
        if Compat.IsHidden(first) or Compat.IsHidden(last) then
            if Compat.SetFormatted(label, "%s %s", first, last) then
                return
            end
        elseif type(first) == "string" and type(last) == "string" and last ~= "" then
            label:SetText(first .. " " .. last)
            return
        end
    end
    Compat.SetText(label, first, "")
end

-- Fill in the level and the status items on the name row. Any of these
-- values may be hidden; a hidden one is treated as "not shown".
local function renderStatus(frame, state, db)
    local level = Compat.Number(state.level)
    local levelText = level and (level > 0 and tostring(level) or "??") or ""
    frame.level:SetText(levelText)
    frame.level.on = db.showLevel and levelText ~= ""

    local tag = not Compat.IsHidden(state.classification) and TAGS[state.classification] or nil
    frame.tag:SetText(tag or "")
    frame.tag.on = db.showTag and tag ~= nil

    local role = not Compat.IsHidden(state.role) and ROLES[state.role] or nil
    frame.role.on = db.showRole and role ~= nil
    if role then
        frame.role:SetText(role.letter)
        frame.role:SetTextColor(Theme.Color(role.color))
    end

    local leader = Compat.Flag(state.leader, false)
    local assistant = Compat.Flag(state.assistant, false)
    frame.leader:SetText(leader and "L" or (assistant and "A" or ""))
    frame.leader.on = db.showLeader and (leader or assistant)

    local combat = Compat.Flag(state.combat, false)
    frame.combat.on = db.showCombat and combat
    frame.rest.on = db.showCombat and not combat and Compat.Flag(state.resting, false)

    -- type() is safe on a hidden value; comparing it to nil is not.
    frame.marker.on = db.showMarker and type(state.marker) ~= "nil"
        and Compat.SetRaidMarker(frame.marker, state.marker)

    arrangeStatus(frame)
end

--- Draw a state table (from Read, or sample data) on a unit's frame.
function UnitFrames:Render(unit, state)
    local frame = self.frames[unit]
    local db = self.db

    setName(frame.name, state, db.nameStyle)
    renderStatus(frame, state, db)

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
    frame.healthSide:SetText("")
    if dead or offline then
        Compat.SetBar(frame.health, 0, 1)
        frame.healthText:SetText(offline and "Offline" or "Dead")
    else
        Compat.SetBar(frame.health, state.health, state.healthMax)
        local health, healthMax = Compat.Number(state.health), Compat.Number(state.healthMax)
        local text, side = UnitFrames.HealthText(db.healthText, health, healthMax)
        if text then
            frame.healthText:SetText(text)
            frame.healthSide:SetText(side or "")
        else
            -- Not readable (the usual case on Forever): the client builds the
            -- text, which works on 1.60.1 (seen in game). If it cannot, show
            -- the current value on its own.
            local mode, shown = db.healthText, false
            if mode == "percent" then
                shown = Compat.SetFormatted(frame.healthText, "%.0f%%", state.healthPercent)
            elseif mode == "both" then
                Compat.SetFormatted(frame.healthSide, "%.0f%%", state.healthPercent)
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
        self:UpdatePortrait(ORDER[i])
    end
end

-- Group, combat, resting and marker changes: redraw without touching the
-- portraits, so a 3D model does not restart.
function UnitFrames:OnStatusEvent()
    for i = 1, #ORDER do
        self:Update(ORDER[i])
    end
end

function UnitFrames:OnPortraitEvent(_, unit)
    if UNITS[unit] then
        self:UpdatePortrait(unit)
    end
end

function UnitFrames:OnUnitEvent(_, unit)
    if UNITS[unit] then
        self:Update(unit)
    end
end

function UnitFrames:OnTargetChanged()
    self:Update("target")
    self:UpdatePortrait("target")
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
            self:Arrange(unit)
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
