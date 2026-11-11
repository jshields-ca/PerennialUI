-- SPDX-License-Identifier: GPL-3.0-or-later
-- Layout mode. Modules register the frames a player may move; in layout
-- mode each gets a drag handle. Positions are saved per profile as the
-- frame's centre offset from the screen centre, in UIParent units, and are
-- applied through the combat queue so protected frames are never moved in
-- combat.
local _, ns = ...

local Combat = ns.Combat
local DB = ns.DB
local Events = ns.Events
local Safety = ns.Safety
local Theme = ns.Theme
local Widgets = ns.Widgets

local Layout = {}
ns.Layout = Layout

Layout.DEFAULT_GRID = 8
Layout.GRID_LINE_SPACING = 32 -- drawn grid is coarser than the snap grid

local movers = {} -- id -> mover
local order = {} -- movers in registration order
local overlay
local spare = {} -- handles of unregistered movers, kept for reuse

--- Round a coordinate to the nearest multiple of grid.
function Layout.Snap(value, grid)
    if not grid or grid <= 1 then
        return math.floor(value + 0.5)
    end
    return math.floor(value / grid + 0.5) * grid
end

local function options()
    local global = DB.Global()
    if type(global.layout) ~= "table" then
        global.layout = {}
    end
    return global.layout
end

function Layout.GetGrid()
    return tonumber(options().grid) or Layout.DEFAULT_GRID
end

function Layout.SetGrid(size)
    options().grid = size
end

function Layout.GetSnap()
    return options().snap ~= false
end

function Layout.SetSnap(on)
    options().snap = on and true or false
end

local function saved()
    local profile = DB.Profile()
    if type(profile.layout) ~= "table" then
        profile.layout = {}
    end
    return profile.layout
end

--- x, y of a mover: the saved position, or its default.
function Layout.GetPosition(id)
    local mover = movers[id]
    if not mover then
        return nil
    end
    local position = saved()[id]
    if type(position) == "table" and tonumber(position.x) and tonumber(position.y) then
        return position.x, position.y
    end
    return mover.x, mover.y
end

--- Move the real frame to its position, now or after combat.
function Layout.Apply(id)
    local mover = movers[id]
    if not mover then
        return
    end
    local x, y = Layout.GetPosition(id)
    Combat.RunWhenSafe(mover.owner, "layout:" .. id, function()
        local scale = mover.frame:GetScale()
        if not scale or scale <= 0 then
            scale = 1
        end
        mover.frame:ClearAllPoints()
        mover.frame:SetPoint("CENTER", UIParent, "CENTER", x / scale, y / scale)
    end)
end

local function placeHandle(mover)
    if mover.handle then
        local x, y = Layout.GetPosition(mover.id)
        local scale = mover.frame:GetScale() or 1
        mover.handle:ClearAllPoints()
        mover.handle:SetPoint("CENTER", UIParent, "CENTER", x, y)
        mover.handle:SetSize(
            math.max(24, (mover.frame:GetWidth() or 0) * scale),
            math.max(16, (mover.frame:GetHeight() or 0) * scale)
        )
        mover.handle.caption:SetText(("%s  %d, %d"):format(mover.title, x, y))
    end
end

--- Save a new position for a mover and apply it.
function Layout.SetPosition(id, x, y)
    if not movers[id] then
        return false
    end
    saved()[id] = { x = x, y = y }
    Layout.Apply(id)
    placeHandle(movers[id])
    Events.Fire("PUI_LAYOUT_MOVED", id, x, y)
    return true
end

--- Put a mover back at its default position.
function Layout.Reset(id)
    if not movers[id] then
        return false
    end
    saved()[id] = nil
    Layout.Apply(id)
    placeHandle(movers[id])
    return true
end

function Layout.ResetAll()
    for i = 1, #order do
        Layout.Reset(order[i].id)
    end
end

local function newHandle()
    local handle = CreateFrame("Button", nil, overlay)
    Widgets.Fill(handle, "accent", "BACKGROUND", 0.35)
    Widgets.Border(handle, "accent")
    handle.caption = Widgets.Text(handle, "", "sm")
    handle.caption:SetPoint("CENTER")
    handle:SetMovable(true)
    handle:SetClampedToScreen(true)
    handle:RegisterForDrag("LeftButton")
    handle:RegisterForClicks("RightButtonUp")
    handle:SetScript("OnDragStart", function()
        handle:StartMoving()
    end)
    handle:SetScript("OnDragStop", Safety.Wrap("core.layout", function()
        handle:StopMovingOrSizing()
        local hx, hy = handle:GetCenter()
        local px, py = UIParent:GetCenter()
        local x, y = hx - px, hy - py
        local grid = Layout.GetSnap() and Layout.GetGrid() or 1
        Layout.SetPosition(handle.mover.id, Layout.Snap(x, grid), Layout.Snap(y, grid))
    end))
    -- Right click puts the frame back where it started.
    handle:SetScript("OnClick", Safety.Wrap("core.layout", function()
        Layout.Reset(handle.mover.id)
    end))
    return handle
end

local function buildHandle(mover)
    local handle = table.remove(spare) or newHandle()
    handle.mover = mover
    mover.handle = handle
    placeHandle(mover)
end

local function buildOverlay()
    overlay = CreateFrame("Frame", nil, UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("DIALOG")
    overlay:Hide()

    local spacing = Layout.GRID_LINE_SPACING
    local width, height = UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
    local function line(vertical, offset)
        local texture = overlay:CreateTexture(nil, "BACKGROUND")
        local r, g, b = Theme.Color("textMuted")
        texture:SetColorTexture(r, g, b, offset == 0 and 0.5 or 0.15)
        if vertical then
            texture:SetWidth(1)
            texture:SetPoint("TOP", overlay, "TOP", offset, 0)
            texture:SetPoint("BOTTOM", overlay, "BOTTOM", offset, 0)
        else
            texture:SetHeight(1)
            texture:SetPoint("LEFT", overlay, "LEFT", 0, offset)
            texture:SetPoint("RIGHT", overlay, "RIGHT", 0, offset)
        end
    end
    -- Lines run outwards from the centre, so the centre lines always exist.
    for offset = 0, width / 2, spacing do
        line(true, offset)
        if offset > 0 then
            line(true, -offset)
        end
    end
    for offset = 0, height / 2, spacing do
        line(false, offset)
        if offset > 0 then
            line(false, -offset)
        end
    end

    local banner = Widgets.Panel(overlay)
    banner:SetSize(520, 30)
    banner:SetPoint("TOP", overlay, "TOP", 0, -40)
    overlay.banner = Widgets.Text(banner, "")
    overlay.banner:SetPoint("CENTER")
end

local function refreshOverlay()
    if not overlay then
        buildOverlay()
    end
    for i = 1, #order do
        if not order[i].handle then
            buildHandle(order[i])
        else
            placeHandle(order[i])
        end
        order[i].handle:Show()
    end
    if #order == 0 then
        overlay.banner:SetText("Layout mode: no movable frames are loaded yet. Type /pui move to leave.")
    else
        overlay.banner:SetText("Layout mode: drag to move, right click to reset. Type /pui move to leave.")
    end
end

function Layout.IsActive()
    return ns.state.layoutMode == true
end

--- Turn layout mode on or off. Returns false if refused (in combat).
function Layout.SetActive(on)
    on = on and true or false
    if on == Layout.IsActive() then
        return true
    end
    if on and Combat.InLockdown() then
        return false, "Layout mode is not available in combat."
    end
    ns.state.layoutMode = on
    if on then
        refreshOverlay()
        overlay:Show()
    elseif overlay then
        overlay:Hide()
    end
    Events.Fire("PUI_LAYOUT_MODE", on)
    return true
end

function Layout.Toggle()
    return Layout.SetActive(not Layout.IsActive())
end

--- Make a frame movable in layout mode. opts: title, x, y (default centre
--- offset from the screen centre). Applies the saved position at once.
function Layout.Register(owner, id, frame, opts)
    if type(id) ~= "string" or type(frame) ~= "table" then
        error("Layout.Register(owner, id, frame, opts)", 2)
    end
    if movers[id] then
        error("Layout.Register: mover '" .. id .. "' is already registered", 2)
    end
    opts = opts or {}
    local mover = {
        id = id, owner = owner, frame = frame,
        title = opts.title or id, x = opts.x or 0, y = opts.y or 0,
    }
    movers[id] = mover
    order[#order + 1] = mover
    Layout.Apply(id)
    if Layout.IsActive() then
        refreshOverlay()
    end
    return mover
end

function Layout.Unregister(id)
    local mover = movers[id]
    if not mover then
        return
    end
    if mover.handle then
        mover.handle:Hide()
        mover.handle.mover = nil
        spare[#spare + 1] = mover.handle
        mover.handle = nil
    end
    movers[id] = nil
    for i = #order, 1, -1 do
        if order[i] == mover then
            table.remove(order, i)
        end
    end
end

--- Remove every mover an owner registered. Called when a module stops.
function Layout.UnregisterAll(owner)
    for i = #order, 1, -1 do
        if order[i].owner == owner then
            Layout.Unregister(order[i].id)
        end
    end
end

--- Ids of registered movers, in registration order.
function Layout.List()
    local ids = {}
    for i = 1, #order do
        ids[i] = order[i].id
    end
    return ids
end

-- Frames cannot be moved in combat, so layout mode ends when combat starts.
Events.Register("core.layout", "PLAYER_REGEN_DISABLED", function()
    if Layout.IsActive() then
        ns.state.layoutMode = false
        if overlay then
            overlay:Hide()
        end
        Events.Fire("PUI_LAYOUT_MODE", false)
        ns.Print("Layout mode closed because combat started.")
    end
end)
