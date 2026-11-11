-- SPDX-License-Identifier: GPL-3.0-or-later
-- Sandbox: a small panel for trying the foundation in game, and a worked
-- example of the module contract. Off by default: /pui enable sandbox.
-- It can be moved in layout mode, has a settings page, reacts to test mode,
-- and can break itself on purpose to show the safety net pausing a module.
local _, ns = ...

local Safety = ns.Safety
local Widgets = ns.Widgets

local Sandbox = ns.Modules.Register({
    id = "sandbox",
    title = "Sandbox",
    enabledByDefault = false,
    defaults = {
        scale = 1,
        showTitle = true,
    },
    settings = {
        {
            key = "scale", type = "range", label = "Scale",
            min = 0.5, max = 2, step = 0.1,
        },
        {
            key = "showTitle", type = "toggle", label = "Show title",
        },
        {
            key = "break", type = "action", label = "Break this module", advanced = true,
            desc = "Raises errors until the safety net pauses the module.",
            func = function()
                for _ = 1, Safety.threshold do
                    Safety.Call("sandbox", error, "Sandbox test error (this is expected)")
                end
            end,
        },
    },
})

function Sandbox:Build()
    local frame = Widgets.Panel(UIParent)
    frame:SetSize(220, 64)
    frame.heading = Widgets.Text(frame, "Perennial UI sandbox", "lg", "accent")
    frame.heading:SetPoint("TOP", frame, "TOP", 0, -10)
    frame.status = Widgets.Text(frame, "", "sm", "textMuted")
    frame.status:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
    self.frame = frame
end

function Sandbox:Update()
    local frame = self.frame
    frame.heading:SetShown(self.db.showTitle)
    frame.status:SetText(ns.state.testMode and "Test mode: sample data" or "Type /pui move to drag me")
    self:RunWhenSafe("scale", function()
        frame:SetScale(self.db.scale)
        ns.Layout.Apply("sandbox")
    end)
end

function Sandbox:OnEnable()
    if not self.frame then
        self:Build()
    end
    self.frame:Show()
    self:RegisterMover("sandbox", self.frame, { title = "Sandbox", x = 0, y = -200 })
    self:Listen("PUI_TEST_MODE", "Update")
    self:Update()
end

function Sandbox:OnDisable()
    if self.frame then
        self.frame:Hide()
    end
end

function Sandbox:OnSettingChanged()
    self:Update()
end
