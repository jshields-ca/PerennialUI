-- SPDX-License-Identifier: GPL-3.0-or-later
-- Widget kit. Small themed building blocks for every Perennial window.
-- Each widget takes its colours and fonts from Theme and restyles itself
-- when the season changes. Build widgets once and reuse them: every widget
-- registers a restyle function that lives for the session.
local _, ns = ...

local Events = ns.Events
local Safety = ns.Safety
local Theme = ns.Theme

local Widgets = {}
ns.Widgets = Widgets

local restylers = {}

local function styled(fn)
    restylers[#restylers + 1] = fn
    fn()
end

Events.Listen("core.widgets", "PUI_THEME_CHANGED", function()
    for i = 1, #restylers do
        restylers[i]()
    end
end)

--- Apply a theme font. role is heading, body or number; size a font.size token.
--- Falls back to a client font if the bundled file cannot be loaded.
function Widgets.SetFont(target, role, size)
    local height = Theme.Get("font.size." .. size)
    target:SetFont(Theme.Get("font." .. role), height, "")
    if not target:GetFont() then
        target:SetFont(Theme.Get("font.fallback"), height, "")
    end
end

--- A font string. size is a font.size token (sm, md, lg, xl); color a colour
--- token; role is heading, body or number (large sizes default to heading).
function Widgets.Text(parent, text, size, color, role)
    local label = parent:CreateFontString(nil, "OVERLAY")
    size, color = size or "md", color or "text"
    role = role or ((size == "lg" or size == "xl") and "heading" or "body")
    styled(function()
        Widgets.SetFont(label, role, size)
        label:SetTextColor(Theme.Color(color))
    end)
    label:SetJustifyH("LEFT")
    label:SetText(text or "")
    return label
end

-- Draw a texture as a tinted rounded mask when the shape is soft and the
-- client can nine-slice; otherwise as a flat colour.
local function paint(texture, file, r, g, b, a, square)
    if not square and Theme.GetShape() == "soft" and texture.SetTextureSliceMargins then
        local margin = Theme.Get("texture.slice")
        texture:SetTexture(file)
        texture:SetTextureSliceMargins(margin, margin, margin, margin)
        texture:SetVertexColor(r, g, b, a)
        return true
    end
    if texture.ClearTextureSlice then
        texture:ClearTextureSlice()
    end
    texture:SetColorTexture(r, g, b, a)
    texture:SetVertexColor(1, 1, 1, 1)
    return false
end

--- A colour fill that covers the frame unless you re-anchor it. It follows
--- the shape setting (rounded when soft). Pass square = true for anything
--- smaller than 16 pixels in either direction.
function Widgets.Fill(frame, token, layer, alpha, square)
    local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAllPoints(frame)
    styled(function()
        local r, g, b, a = Theme.Color(token)
        paint(texture, Theme.Get("texture.panelFill"), r, g, b, alpha or a, square)
    end)
    return texture
end

--- A one-pixel border drawn inside the frame's edge. It follows the shape
--- setting: a rounded outline when soft, four straight edges when crisp.
function Widgets.Border(frame, token, square)
    local width = Theme.Get("border.width")
    local ring = frame:CreateTexture(nil, "BORDER")
    ring:SetAllPoints(frame)
    local edges = {}
    for i = 1, 4 do
        edges[i] = frame:CreateTexture(nil, "BORDER")
    end
    styled(function()
        local r, g, b, a = Theme.Color(token or "border")
        local soft = not square and Theme.GetShape() == "soft" and ring.SetTextureSliceMargins ~= nil
        if soft then
            paint(ring, Theme.Get("texture.panelEdge"), r, g, b, a)
        end
        ring:SetShown(soft)
        for i = 1, 4 do
            edges[i]:SetColorTexture(r, g, b, a)
            edges[i]:SetShown(not soft)
        end
    end)
    edges[1]:SetPoint("TOPLEFT")
    edges[1]:SetPoint("TOPRIGHT")
    edges[1]:SetHeight(width)
    edges[2]:SetPoint("BOTTOMLEFT")
    edges[2]:SetPoint("BOTTOMRIGHT")
    edges[2]:SetHeight(width)
    edges[3]:SetPoint("TOPLEFT")
    edges[3]:SetPoint("BOTTOMLEFT")
    edges[3]:SetWidth(width)
    edges[4]:SetPoint("TOPRIGHT")
    edges[4]:SetPoint("BOTTOMRIGHT")
    edges[4]:SetWidth(width)
    return edges
end

--- A glass panel: see-through tinted fill, border and a lit top edge.
--- opts.rail = true adds the accent rail down the left side; opts.alpha
--- overrides how see-through the fill is (0 clear, 1 solid).
function Widgets.Panel(parent, name, opts)
    opts = opts or {}
    local panel = CreateFrame("Frame", name, parent)
    Widgets.Fill(panel, opts.token or "bg", nil, opts.alpha)
    Widgets.Border(panel)

    local highlight = panel:CreateTexture(nil, "ARTWORK")
    highlight:SetHeight(1)
    local rail = opts.rail and panel:CreateTexture(nil, "ARTWORK")
    styled(function()
        -- Keep clear of the corners, which are rounded when the shape is soft.
        local inset = Theme.Radius() + 1
        highlight:ClearAllPoints()
        highlight:SetPoint("TOPLEFT", panel, "TOPLEFT", inset, -1)
        highlight:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -inset, -1)
        highlight:SetColorTexture(Theme.Color("highlight"))
        if rail then
            -- Soft: a mask of the panel's left edge, so the rail follows the
            -- rounded corners. Crisp: a plain strip down the full height.
            local r, g, b, a = Theme.Color("accent")
            rail:ClearAllPoints()
            rail:SetAllPoints(panel)
            if not paint(rail, Theme.Get("texture.panelRail"), r, g, b, a) then
                rail:ClearAllPoints()
                rail:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
                rail:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
                rail:SetWidth(Theme.Get("border.rail"))
            end
        end
    end)
    return panel
end

--- A status bar on a darker track. token is the fill's colour token; change
--- it later with bar:SetColor(r, g, b). Values are set by the caller, usually
--- through ns.Compat.SetBar so hidden combat values are handled.
function Widgets.Bar(parent, token)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(Theme.Get("texture.flat"))
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar.track = Widgets.Fill(bar, "track", "BACKGROUND", nil, true)
    function bar:SetColor(r, g, b)
        self.color = { r, g, b }
        self:SetStatusBarColor(r, g, b, 1)
    end
    styled(function()
        if not bar.color then
            local r, g, b = Theme.Color(token or "health")
            bar:SetStatusBarColor(r, g, b, 1)
        end
    end)
    return bar
end

--- A push button. onClick(button, mouseButton) runs inside the safety net.
function Widgets.Button(parent, text, onClick, owner)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(110, 22)
    Widgets.Fill(button, "surface")
    Widgets.Border(button)
    button.hover = Widgets.Fill(button, "accent", "ARTWORK", 0.25)
    button.hover:Hide()
    button.caption = Widgets.Text(button, text)
    button.caption:SetPoint("CENTER")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnEnter", function()
        button.hover:Show()
    end)
    button:SetScript("OnLeave", function()
        button.hover:Hide()
    end)
    button:SetScript("OnClick", Safety.Wrap(owner or "core.ui", function(_, mouseButton)
        onClick(button, mouseButton)
    end))
    return button
end

--- A checkbox. onChange(checked) runs when the player clicks it.
--- box:SetChecked(value) updates it without calling onChange.
function Widgets.Checkbox(parent, onChange, owner)
    local box = CreateFrame("Button", nil, parent)
    box:SetSize(18, 18)
    Widgets.Fill(box, "surface")
    Widgets.Border(box)
    box.mark = box:CreateTexture(nil, "ARTWORK")
    box.mark:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
    box.mark:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
    styled(function()
        box.mark:SetColorTexture(Theme.Color("accent"))
    end)
    box.checked = false
    box.mark:Hide()
    function box:SetChecked(checked)
        self.checked = checked and true or false
        self.mark:SetShown(self.checked)
    end
    function box:GetChecked()
        return self.checked
    end
    box:SetScript("OnClick", Safety.Wrap(owner or "core.ui", function()
        box:SetChecked(not box.checked)
        onChange(box.checked)
    end))
    return box
end

--- A horizontal slider with its value printed beside it.
--- onChange(value) runs when the player drags it; slider:SetNumber(value)
--- updates it without calling onChange.
function Widgets.Slider(parent, low, high, step, onChange, owner)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetSize(150, 16)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(10, 16)
    slider:SetThumbTexture(thumb)
    styled(function()
        track:SetColorTexture(Theme.Color("border"))
        thumb:SetColorTexture(Theme.Color("accent"))
    end)

    slider.readout = Widgets.Text(slider, "", "sm", "textMuted", "number")
    slider.readout:SetPoint("RIGHT", slider, "LEFT", -8, 0)

    local decimals = (step and step < 1) and 2 or 0
    local silent = false
    local function show(value)
        slider.readout:SetText(("%." .. decimals .. "f"):format(value))
    end
    function slider:SetNumber(value)
        silent = true
        self:SetValue(value)
        silent = false
        show(value)
    end
    slider:SetScript("OnValueChanged", Safety.Wrap(owner or "core.ui", function(_, value)
        show(value)
        if not silent then
            onChange(value)
        end
    end))
    return slider
end

--- A choice button: left click picks the next value, right click the previous.
--- values is a list of { value = , label = }. onChange(value) runs on a click;
--- picker:SetChoice(values, value) updates it without calling onChange.
function Widgets.Picker(parent, onChange, owner)
    local picker
    local choices, index = {}, 0
    picker = Widgets.Button(parent, "", function(_, mouseButton)
        if #choices == 0 then
            return
        end
        local delta = mouseButton == "RightButton" and -1 or 1
        index = (index - 1 + delta) % #choices + 1
        picker.caption:SetText(choices[index].label or tostring(choices[index].value))
        onChange(choices[index].value)
    end, owner)
    picker:SetSize(150, 22)
    function picker:SetChoice(values, value)
        choices, index = values, 0
        for i = 1, #values do
            if values[i].value == value then
                index = i
            end
        end
        local current = choices[index]
        self.caption:SetText(current and (current.label or tostring(current.value)) or "")
    end
    return picker
end

--- A single-line text box. onChange(text) runs as the player types.
function Widgets.Input(parent, onChange, owner)
    local input = CreateFrame("EditBox", nil, parent)
    input:SetSize(180, 22)
    input:SetAutoFocus(false)
    input:SetTextInsets(6, 6, 0, 0)
    Widgets.Fill(input, "surface")
    Widgets.Border(input)
    styled(function()
        Widgets.SetFont(input, "body", "md")
        input:SetTextColor(Theme.Color("text"))
    end)
    input:SetScript("OnEscapePressed", function()
        input:ClearFocus()
    end)
    input:SetScript("OnEnterPressed", function()
        input:ClearFocus()
    end)
    input:SetScript("OnTextChanged", Safety.Wrap(owner or "core.ui", function(_, byPlayer)
        if byPlayer then
            onChange(input:GetText())
        end
    end))
    return input
end

--- A vertically scrolling area. Returns the scroll frame and its content
--- frame; parent your rows to the content frame and set its height.
function Widgets.Scroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local target = scroll:GetVerticalScroll() - delta * 40
        local limit = scroll:GetVerticalScrollRange()
        if target < 0 then
            target = 0
        elseif target > limit then
            target = limit
        end
        scroll:SetVerticalScroll(target)
    end)
    scroll:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(width)
    end)
    return scroll, content
end
