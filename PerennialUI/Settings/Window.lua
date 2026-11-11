-- SPDX-License-Identifier: GPL-3.0-or-later
-- The settings window: page list, search, simple/advanced switch, undo.
-- It only draws what Settings/Registry.lua describes; all reading and
-- writing of values goes through the registry.
local _, ns = ...

local DB = ns.DB
local Events = ns.Events
local Settings = ns.Settings
local Widgets = ns.Widgets

local Window = {}
ns.SettingsWindow = Window

local NAME = "PerennialUISettings"
local MIN_WIDTH, MIN_HEIGHT = 560, 360
local SIDEBAR_WIDTH = 170
local ROW_HEIGHT, DESC_HEIGHT, INFO_HEIGHT = 30, 14, 300

local frame, sidebar, content, results, searchBox, advancedBox
local pageButtons = {} -- pooled sidebar buttons
local resultButtons = {} -- pooled search-result buttons
local pageViews = {} -- page id -> { holder = frame, rows = {} }
local currentPage

local function geometry()
    local global = DB.Global()
    if type(global.window) ~= "table" then
        global.window = {}
    end
    return global.window
end

local function saveGeometry()
    local saved = geometry()
    local x, y = frame:GetCenter()
    local px, py = UIParent:GetCenter()
    if x and px then
        saved.x, saved.y = x - px, y - py
    end
    saved.w, saved.h = frame:GetWidth(), frame:GetHeight()
end

--- Build the control for one option. Returns the row frame.
local function buildRow(page, option, holder)
    local owner = page.owner or "core.ui"
    local row = CreateFrame("Frame", nil, holder)
    row.option = option
    row.rowHeight = ROW_HEIGHT

    if option.type == "header" then
        row.caption = Widgets.Text(row, option.label, "lg", "accent")
        row.caption:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 6)
        return row
    end

    if option.type == "info" then
        row.rowHeight = INFO_HEIGHT
        row.caption = Widgets.Text(row, "", "md", "textMuted")
        row.caption:SetPoint("TOPLEFT")
        row.caption:SetPoint("TOPRIGHT")
        row.caption:SetJustifyV("TOP")
        row.caption:SetWordWrap(true)
        function row:Refresh()
            self.caption:SetText(Settings.Info(page.id, option.key))
        end
        return row
    end

    if option.type == "action" then
        row.control = Widgets.Button(row, option.label, function()
            Settings.Run(page.id, option.key)
        end, owner)
        row.control:SetSize(200, 22)
        row.control:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -4)
    else
        row.caption = Widgets.Text(row, option.label)
        row.caption:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -8)
    end

    if option.desc then
        row.rowHeight = ROW_HEIGHT + DESC_HEIGHT
        row.note = Widgets.Text(row, option.desc, "sm", "textMuted")
        row.note:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -28)
    end

    local function change(value)
        if not Settings.Set(page.id, option.key, value) then
            row:Refresh() -- rejected: show the real value again
        end
    end

    if option.type == "toggle" then
        row.control = Widgets.Checkbox(row, change, owner)
        row.control:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -6)
        function row:Refresh()
            self.control:SetChecked(Settings.Get(page.id, option.key))
        end
    elseif option.type == "range" then
        row.control = Widgets.Slider(row, option.min or 0, option.max or 1, option.step, change, owner)
        row.control:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -7)
        function row:Refresh()
            local value = Settings.Get(page.id, option.key)
            if type(value) == "number" then
                self.control:SetNumber(value)
            end
        end
    elseif option.type == "select" then
        row.control = Widgets.Picker(row, change, owner)
        row.control:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -4)
        function row:Refresh()
            self.control:SetChoice(Settings.Values(option), Settings.Get(page.id, option.key))
        end
    end
    return row
end

--- Create rows for options that do not have one yet, then stack the rows
--- the current mode shows and refresh their values.
local function layoutPage(pageId)
    local page = Settings.GetPage(pageId)
    local view = pageViews[pageId]
    if not view then
        view = { holder = CreateFrame("Frame", nil, content), rows = {} }
        view.holder:SetPoint("TOPLEFT")
        view.holder:SetPoint("TOPRIGHT")
        pageViews[pageId] = view
    end
    local all = Settings.AllOptions(pageId)
    for i = #view.rows + 1, #all do
        view.rows[i] = buildRow(page, all[i], view.holder)
    end

    local advanced = Settings.IsAdvanced()
    local offset = 0
    for i = 1, #view.rows do
        local row = view.rows[i]
        if row.option.advanced and not advanced then
            row:Hide()
        else
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", view.holder, "TOPLEFT", 0, -offset)
            row:SetPoint("TOPRIGHT", view.holder, "TOPRIGHT", 0, -offset)
            row:SetHeight(row.rowHeight)
            row:Show()
            if row.Refresh then
                row:Refresh()
            end
            offset = offset + row.rowHeight
        end
    end
    view.holder:SetHeight(math.max(offset, 1))
    content:SetHeight(math.max(offset, 1))
    return view
end

local function refreshSidebar()
    local pages = Settings.Pages()
    for i = 1, #pages do
        local page = pages[i]
        local button = pageButtons[i]
        if not button then
            button = Widgets.Button(sidebar, "", function(self, mouseButton)
                if mouseButton == "RightButton" then
                    Settings.SetPinned(self.pageId, not Settings.IsPinned(self.pageId))
                else
                    searchBox:SetText("")
                    Window.ShowPage(self.pageId)
                end
            end)
            button:SetSize(SIDEBAR_WIDTH - 8, 22)
            button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, -(i - 1) * 24)
            button.selected = Widgets.Fill(button, "accent", "ARTWORK", 0.4)
            pageButtons[i] = button
        end
        button.pageId = page.id
        button.caption:SetText((Settings.IsPinned(page.id) and "* " or "") .. page.title)
        button.selected:SetShown(page.id == currentPage)
        button:Show()
    end
    for i = #pages + 1, #pageButtons do
        pageButtons[i]:Hide()
    end
end

local function hideViews()
    for _, view in pairs(pageViews) do
        view.holder:Hide()
    end
    results:Hide()
end

--- Show a page by id. Opens the window if needed.
function Window.ShowPage(pageId)
    if not Settings.GetPage(pageId) then
        return false
    end
    Window.Open()
    currentPage = pageId
    hideViews()
    layoutPage(pageId).holder:Show()
    refreshSidebar()
    return true
end

--- Show the options matching the text. Returns how many matched.
function Window.Search(text)
    Window.Open()
    if not text or not text:match("%S") then
        Window.ShowPage(currentPage)
        return 0
    end
    local found = Settings.Search(text)
    hideViews()
    results:Show()
    for i = 1, #found do
        local button = resultButtons[i]
        if not button then
            button = Widgets.Button(results, "", function(self)
                searchBox:SetText("")
                Window.ShowPage(self.pageId)
            end)
            button:SetHeight(22)
            button:SetPoint("TOPLEFT", results, "TOPLEFT", 0, -(i - 1) * 24)
            button:SetPoint("TOPRIGHT", results, "TOPRIGHT", 0, -(i - 1) * 24)
            resultButtons[i] = button
        end
        button.pageId = found[i].page.id
        button.caption:SetText(found[i].page.title .. ": " .. (found[i].option.label or found[i].option.key))
        button:Show()
    end
    for i = #found + 1, #resultButtons do
        resultButtons[i]:Hide()
    end
    results.empty:SetShown(#found == 0)
    results:SetHeight(math.max(#found * 24, 24))
    content:SetHeight(math.max(#found * 24, 24))
    return #found
end

local function build()
    local saved = geometry()
    frame = Widgets.Panel(UIParent, NAME)
    frame:SetSize(math.max(tonumber(saved.w) or 720, MIN_WIDTH), math.max(tonumber(saved.h) or 480, MIN_HEIGHT))
    frame:SetPoint("CENTER", UIParent, "CENTER", tonumber(saved.x) or 0, tonumber(saved.y) or 0)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT)
    end
    frame:Hide()
    UISpecialFrames[#UISpecialFrames + 1] = NAME -- Escape closes the window

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(32)
    Widgets.Fill(header, "surface")
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        saveGeometry()
    end)
    local heading = Widgets.Text(header, "Perennial UI", "lg")
    heading:SetPoint("LEFT", header, "LEFT", 12, 0)
    local version = Widgets.Text(header, ns.version, "sm", "textMuted")
    version:SetPoint("LEFT", heading, "RIGHT", 8, 0)
    local close = Widgets.Button(header, "x", Window.Close)
    close:SetSize(22, 22)
    close:SetPoint("RIGHT", header, "RIGHT", -5, 0)

    local searchLabel = Widgets.Text(frame, "Search", "md", "textMuted")
    searchLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -46)
    searchBox = Widgets.Input(frame, Window.Search)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)

    local undo = Widgets.Button(frame, "Undo", function()
        if not Settings.Undo() then
            ns.Print("Nothing to undo.")
        end
    end)
    undo:SetSize(70, 22)
    undo:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -42)

    local advancedLabel = Widgets.Text(frame, "Advanced")
    advancedLabel:SetPoint("RIGHT", undo, "LEFT", -16, 0)
    advancedBox = Widgets.Checkbox(frame, Settings.SetAdvanced)
    advancedBox:SetPoint("RIGHT", advancedLabel, "LEFT", -6, 0)
    advancedBox:SetChecked(Settings.IsAdvanced())

    sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -78)
    sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    sidebar:SetWidth(SIDEBAR_WIDTH)

    local scroll
    scroll, content = Widgets.Scroll(frame)
    scroll:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 20)

    results = CreateFrame("Frame", nil, content)
    results:SetPoint("TOPLEFT")
    results:SetPoint("TOPRIGHT")
    results.empty = Widgets.Text(results, "Nothing matches. Advanced options are searched only in advanced mode.",
        "md", "textMuted")
    results.empty:SetPoint("TOPLEFT")
    results:Hide()

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    Widgets.Fill(grip, "border")
    grip:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        saveGeometry()
    end)
end

function Window.IsOpen()
    return frame ~= nil and frame:IsShown()
end

function Window.Open()
    if not frame then
        build()
    end
    if frame:IsShown() then
        return
    end
    frame:Show()
    Window.ShowPage(currentPage or Settings.Pages()[1].id)
end

function Window.Close()
    if frame then
        frame:Hide()
    end
end

function Window.Toggle()
    if Window.IsOpen() then
        Window.Close()
    else
        Window.Open()
    end
end

local function refreshCurrent()
    if Window.IsOpen() and currentPage and not results:IsShown() then
        layoutPage(currentPage)
    end
end

Events.Listen("core.window", "PUI_SETTING_CHANGED", refreshCurrent)
Events.Listen("core.window", "PUI_MODULE_STATE", refreshCurrent)
Events.Listen("core.window", "PUI_PROFILE_CHANGED", refreshCurrent)
Events.Listen("core.window", "PUI_SETTINGS_MODE", function(_, on)
    if frame then
        advancedBox:SetChecked(on)
        refreshCurrent()
    end
end)
Events.Listen("core.window", "PUI_SETTINGS_PAGES", function()
    if frame then
        refreshSidebar()
    end
end)
