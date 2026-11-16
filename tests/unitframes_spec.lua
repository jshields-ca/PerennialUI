-- SPDX-License-Identifier: GPL-3.0-or-later
local Loader = require("tests.helpers.loader")

-- A value the fake client treats as hidden from addons.
local SECRET = { secret = true }

local function hideSecrets()
    _G.issecretvalue = function(value)
        return value == SECRET
    end
end

describe("Compat for hidden values", function()
    local ns, Compat, bar, label

    before_each(function()
        ns = Loader.load()
        Compat = ns.Compat
        hideSecrets()
        bar = CreateFrame("StatusBar")
        label = bar:CreateFontString()
    end)

    it("fills a bar from readable numbers", function()
        assert.equal("known", Compat.SetBar(bar, 30, 120))
        assert.equal(30, bar.value)
        assert.equal(120, bar.max)
    end)

    it("never gives a bar a zero maximum", function()
        Compat.SetBar(bar, 0, 0)
        assert.equal(1, bar.max)
    end)

    it("hands hidden numbers to the bar untouched", function()
        assert.equal("hidden", Compat.SetBar(bar, SECRET, SECRET))
        assert.equal(SECRET, bar.value)
        assert.equal("hidden", Compat.SetBar(bar, SECRET, 200))
        assert.equal(200, bar.max)
    end)

    it("shows a full bar when the client refuses a hidden number", function()
        bar.SetValue = function(self, value)
            if value == SECRET then
                error("refused")
            end
            self.value = value
        end
        assert.equal("unknown", Compat.SetBar(bar, SECRET, SECRET))
        assert.equal(1, bar.value)
        assert.equal(1, bar.max)
    end)

    it("shows a full bar when a value is missing", function()
        assert.equal("unknown", Compat.SetBar(bar, nil, 100))
        assert.equal(1, bar.value)
    end)

    it("sets text, passing hidden text through and falling back if refused", function()
        assert.is_true(Compat.SetText(label, "Hogger", "?"))
        assert.equal("Hogger", label:GetText())
        assert.is_true(Compat.SetText(label, SECRET, "?"))
        assert.equal(SECRET, label.text)
        label.SetText = function(self, text)
            if text == SECRET then
                error("refused")
            end
            self.text = text
        end
        assert.is_false(Compat.SetText(label, SECRET, "?"))
        assert.equal("?", label.text)
        assert.is_false(Compat.SetText(label, nil, "none"))
        assert.equal("none", label.text)
    end)

    it("reads flags without branching on a hidden one", function()
        assert.is_true(Compat.Flag(true, false))
        assert.is_false(Compat.Flag(nil, true))
        assert.is_true(Compat.Flag(SECRET, true))
        assert.is_false(Compat.Flag(SECRET, false))
    end)

    it("looks up class colours", function()
        local r = Compat.ClassColor("WARRIOR")
        assert.equal(0.78, r)
        assert.is_nil(Compat.ClassColor("NOPE"))
        assert.is_nil(Compat.ClassColor(SECRET))
    end)

    it("hides and restores the game's own frames", function()
        assert.is_true(Compat.HideDefault("player"))
        assert.is_true(Compat.IsDefaultHidden("player"))
        assert.is_true(PlayerFrame:GetParent() ~= UIParent)
        assert.is_true(Compat.HideDefault("player")) -- twice is harmless
        Compat.ShowDefault("player")
        assert.equal(UIParent, PlayerFrame:GetParent())
        assert.is_false(Compat.IsDefaultHidden("player"))
        assert.is_false(Compat.HideDefault("nothing"))
    end)

    it("reports what the client supports", function()
        local report = Compat.Probe()
        assert.equal(16001, report.interface)
        assert.is_false(report.combat)
        assert.is_true(report.present > 0)
        assert.equal("number", report.values["UnitHealth(player)"])
        local missing = table.concat(report.missing, " ")
        assert.is_truthy(missing:find("UnitHealthPercent", 1, true))
        assert.is_falsy(missing:find("UnitHealthMax", 1, true))
    end)

    it("asks the client for a health percentage only when it can scale it", function()
        assert.is_nil(Compat.HealthPercent("player"))
        _G.UnitHealthPercent = function(_, _, scale)
            return scale == "to100" and 75 or 0.75
        end
        assert.is_nil(Compat.HealthPercent("player"))
        _G.CurveConstants = { ScaleTo100 = "to100" }
        assert.equal(75, Compat.HealthPercent("player"))
        _G.UnitHealthPercent = function()
            error("refused")
        end
        assert.is_nil(Compat.HealthPercent("player"))
    end)

    it("formats into a label, and leaves it alone when formatting fails", function()
        label:SetText("before")
        assert.is_true(Compat.SetFormatted(label, "%d%%", 40))
        assert.equal("40%", label:GetText())
        assert.is_false(Compat.SetFormatted(label, "%d%%", SECRET))
        assert.is_false(Compat.SetFormatted(label, "%d%%", nil))
        assert.equal("40%", label:GetText())
    end)

    it("saves the report from /pui api", function()
        ns.Slash.Run("api")
        assert.equal("table", type(_G.PerennialUIDB.global.probes.rest))
    end)
end)

describe("Unit frames", function()
    local ns, stub, UF, frames

    before_each(function()
        ns, stub = Loader.load()
        UF = ns.Modules.Get("unitframes")
        frames = UF.frames
    end)

    local function target(data)
        stub.units.target = data
        stub.fire("PLAYER_TARGET_CHANGED")
        if stub.watched[frames.target] then
            frames.target.shown = data ~= nil
        end
    end

    local boar = {
        name = "Mottled Boar", level = 3, health = 60, healthMax = 80, power = 0, powerMax = 0,
        isPlayer = false, reaction = 2,
    }

    describe("formatting", function()
        it("shortens large numbers", function()
            assert.equal("950", UF.FormatNumber(950))
            assert.equal("12.3k", UF.FormatNumber(12345))
            assert.equal("4.6m", UF.FormatNumber(4600000))
        end)

        it("writes health text for each mode", function()
            assert.equal("", UF.HealthText("none", 50, 200))
            assert.equal("50", UF.HealthText("current", 50, 200))
            assert.equal("25%", UF.HealthText("percent", 50, 200))
            assert.equal("50  25%", UF.HealthText("both", 50, 200))
        end)

        it("has no health text when the numbers are not readable", function()
            assert.is_nil(UF.HealthText("percent", nil, 200))
            assert.is_nil(UF.HealthText("current", 50, 0))
        end)

        it("picks a health colour", function()
            assert.equal("class", UF.HealthColor("player", { isPlayer = true }, true))
            assert.equal("health", UF.HealthColor("player", { isPlayer = true }, false))
            assert.equal("hostile", UF.HealthColor("target", { isPlayer = false, reaction = 2 }, true))
            assert.equal("neutral", UF.HealthColor("target", { isPlayer = false, reaction = 4 }, true))
            assert.equal("friendly", UF.HealthColor("target", { isPlayer = false, reaction = 5 }, true))
            assert.equal("health", UF.HealthColor("target", { isPlayer = false }, true))
            assert.equal("inactive", UF.HealthColor("target", { dead = true, reaction = 2 }, true))
            assert.equal("inactive", UF.HealthColor("target", { connected = false, isPlayer = true }, true))
        end)
    end)

    it("is on by default, shows the player and hides the game's frames", function()
        assert.equal("enabled", ns.Modules.GetState("unitframes"))
        assert.is_true(frames.player:IsShown())
        assert.equal("player", frames.player:GetAttribute("unit"))
        assert.equal("target", frames.player:GetAttribute("*type1"))
        assert.is_true(ns.Compat.IsDefaultHidden("player"))
        assert.is_true(ns.Compat.IsDefaultHidden("target"))
    end)

    it("draws the player", function()
        local frame = frames.player
        assert.equal("Tester", frame.name:GetText())
        assert.equal("14", frame.level:GetText())
        assert.equal(300, frame.health.value)
        assert.equal(400, frame.health.max)
        assert.equal("300", frame.healthText:GetText())
        assert.same({ 0.78, 0.61, 0.43 }, frame.health.color)
        assert.equal(50, frame.power.value)
        assert.same({ ns.Theme.Color("rage") }, { frame.power.color[1], frame.power.color[2], frame.power.color[3], 1 })
    end)

    it("follows health changes for its own units only", function()
        stub.units.player.health = 120
        stub.fire("UNIT_HEALTH", "party1")
        assert.equal(300, frames.player.health.value)
        stub.fire("UNIT_HEALTH", "player")
        assert.equal(120, frames.player.health.value)
    end)

    it("shows the target frame only while there is a target", function()
        assert.is_false(frames.target:IsShown())
        target(boar)
        assert.is_true(frames.target:IsShown())
        assert.equal("Mottled Boar", frames.target.name:GetText())
        assert.same({ ns.Theme.Color("hostile") },
            { frames.target.health.color[1], frames.target.health.color[2], frames.target.health.color[3], 1 })
        assert.is_false(frames.target.power:IsShown())
        target(nil)
        assert.is_false(frames.target:IsShown())
    end)

    it("shows ?? for a level the client will not give", function()
        boar.level = -1
        target(boar)
        assert.equal("??", frames.target.level:GetText())
        boar.level = 3
    end)

    it("marks dead and offline units", function()
        stub.units.player.dead = true
        stub.fire("UNIT_HEALTH", "player")
        assert.equal("Dead", frames.player.healthText:GetText())
        assert.equal(0, frames.player.health.value)
        stub.units.player.dead, stub.units.player.offline = false, true
        stub.fire("UNIT_CONNECTION", "player")
        assert.equal("Offline", frames.player.healthText:GetText())
    end)

    it("keeps working when combat hides the numbers", function()
        hideSecrets()
        local player = stub.units.player
        player.health, player.healthMax, player.name, player.level = SECRET, SECRET, SECRET, SECRET
        stub.fire("UNIT_HEALTH", "player")
        local frame = frames.player
        assert.equal(SECRET, frame.health.value)
        assert.equal(SECRET, frame.healthText.text)
        assert.equal(SECRET, frame.name.text)
        assert.equal("", frame.level:GetText())
        assert.equal("enabled", ns.Modules.GetState("unitframes"))
        assert.equal(0, #ns.Safety.GetLog())
    end)

    it("shows a percentage from the client when health itself is hidden", function()
        hideSecrets()
        _G.CurveConstants = { ScaleTo100 = "to100" }
        _G.UnitHealthPercent = function()
            return 75
        end
        stub.units.player.health = SECRET
        ns.Settings.Set("unitframes", "healthText", "percent")
        assert.equal("75%", frames.player.healthText:GetText())
        -- The fake hidden value cannot be formatted, so "both" falls back to it.
        ns.Settings.Set("unitframes", "healthText", "both")
        assert.equal(SECRET, frames.player.healthText.text)
        assert.equal(0, #ns.Safety.GetLog())
    end)

    it("shows current health when the client has no percentage", function()
        hideSecrets()
        stub.units.player.health = SECRET
        ns.Settings.Set("unitframes", "healthText", "percent")
        assert.equal(SECRET, frames.player.healthText.text)
    end)

    it("applies settings", function()
        ns.Settings.Set("unitframes", "healthText", "percent")
        assert.equal("75%", frames.player.healthText:GetText())
        ns.Settings.Set("unitframes", "classColor", false)
        assert.same({ ns.Theme.Color("health") },
            { frames.player.health.color[1], frames.player.health.color[2], frames.player.health.color[3], 1 })
        ns.Settings.Set("unitframes", "scale", 1.2)
        assert.is_true(math.abs(frames.player:GetScale() - 1.2) < 1e-9)
        ns.Settings.Set("unitframes", "width", 260)
        assert.equal(260, frames.target:GetWidth())
    end)

    it("turns one frame off and gives that default frame back", function()
        ns.Settings.Set("unitframes", "player", false)
        assert.is_false(frames.player:IsShown())
        assert.is_false(ns.Compat.IsDefaultHidden("player"))
        assert.is_true(ns.Compat.IsDefaultHidden("target"))
        ns.Settings.Set("unitframes", "hideDefault", false)
        assert.is_false(ns.Compat.IsDefaultHidden("target"))
    end)

    it("off means off: frames hidden, defaults back, no events, no movers", function()
        target(boar)
        ns.Modules.SetEnabled("unitframes", false)
        assert.is_false(frames.player:IsShown())
        assert.is_false(frames.target:IsShown())
        assert.is_nil(stub.watched[frames.target])
        assert.equal(UIParent, PlayerFrame:GetParent())
        assert.equal(UIParent, TargetFrame:GetParent())
        assert.is_false(stub.isRegistered("UNIT_HEALTH"))
        assert.same({}, ns.Layout.List())
        ns.Modules.SetEnabled("unitframes", true)
        assert.is_true(frames.player:IsShown())
        assert.same({ "unitframes_player", "unitframes_target" }, ns.Layout.List())
    end)

    it("waits for combat to end before changing protected frames", function()
        stub.inCombat = true
        ns.Modules.SetEnabled("unitframes", false)
        assert.is_true(frames.player:IsShown())
        assert.is_true(ns.Compat.IsDefaultHidden("player"))
        stub.inCombat = false
        stub.fire("PLAYER_REGEN_ENABLED")
        assert.is_false(frames.player:IsShown())
        assert.is_false(ns.Compat.IsDefaultHidden("player"))
    end)

    it("shows sample data on the target frame in test mode", function()
        ns.Slash.Run("test")
        assert.is_true(frames.target:IsShown())
        assert.equal("Training Dummy", frames.target.name:GetText())
        ns.Slash.Run("test")
        assert.is_false(frames.target:IsShown())
    end)

    it("can be moved in layout mode and remembers where", function()
        ns.Layout.SetPosition("unitframes_player", -300, -100)
        local x, y = ns.Layout.GetPosition("unitframes_player")
        assert.same({ -300, -100 }, { x, y })
    end)
end)
