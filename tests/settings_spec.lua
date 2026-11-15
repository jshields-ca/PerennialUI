-- SPDX-License-Identifier: GPL-3.0-or-later
local Loader = require("tests.helpers.loader")

describe("Settings registry", function()
    local ns, stub, Settings, mod, changes

    before_each(function()
        ns, stub = Loader.load()
        Settings = ns.Settings
        changes = {}
        mod = ns.Modules.Register({
            id = "frames",
            title = "Unit Frames",
            defaults = { scale = 1, style = "bars", glow = true, debug = false },
            settings = {
                { type = "header", label = "Look" },
                { key = "scale", type = "range", label = "Frame scale", min = 0.5, max = 2, step = 0.25 },
                {
                    key = "style", type = "select", label = "Health style", desc = "How health is drawn",
                    values = { { value = "bars", label = "Bars" }, { value = "orbs", label = "Orbs" } },
                },
                { key = "glow", type = "toggle", label = "Low health glow" },
                { key = "debug", type = "toggle", label = "Debug outlines", advanced = true },
            },
            OnSettingChanged = function(_, key, value, old)
                changes[#changes + 1] = key .. ":" .. tostring(old) .. ">" .. tostring(value)
            end,
        })
    end)

    it("gives a module with settings its own page", function()
        local page = Settings.GetPage("frames")
        assert.equal("Unit Frames", page.title)
        assert.equal(5, #Settings.AllOptions("frames"))
    end)

    it("reads and writes module settings and tells the module", function()
        assert.equal(1, Settings.Get("frames", "scale"))
        assert.is_true(Settings.Set("frames", "scale", 1.5))
        assert.equal(1.5, mod.db.scale)
        assert.same({ "scale:1>1.5" }, changes)
    end)

    it("announces changes as a message", function()
        local seen
        ns.Events.Listen("test", "PUI_SETTING_CHANGED", function(_, page, key, value)
            seen = page .. "." .. key .. "=" .. tostring(value)
        end)
        Settings.Set("frames", "glow", false)
        assert.equal("frames.glow=false", seen)
    end)

    it("clamps ranges and snaps them to the step", function()
        Settings.Set("frames", "scale", 99)
        assert.equal(2, mod.db.scale)
        Settings.Set("frames", "scale", 1.3)
        assert.equal(1.25, mod.db.scale)
        assert.is_false((Settings.Set("frames", "scale", "big")))
        assert.equal(1.25, mod.db.scale)
    end)

    it("rejects values a select does not offer, and unknown settings", function()
        assert.is_false((Settings.Set("frames", "style", "hexagons")))
        assert.equal("bars", mod.db.style)
        assert.is_false((Settings.Set("frames", "nope", 1)))
        assert.is_false((Settings.Set("nowhere", "scale", 1)))
    end)

    it("records history and undoes changes in reverse order", function()
        Settings.Set("frames", "scale", 1.5)
        Settings.Set("frames", "style", "orbs")
        Settings.Set("frames", "style", "orbs") -- no change, not recorded
        assert.equal(2, #Settings.History())
        assert.equal("Health style", Settings.History()[2].label)

        assert.equal("style", Settings.Undo().key)
        assert.equal("bars", mod.db.style)
        assert.equal("scale", Settings.Undo().key)
        assert.equal(1, mod.db.scale)
        assert.is_nil(Settings.Undo())
        assert.equal(0, #Settings.History())
    end)

    it("caps the history", function()
        for i = 1, Settings.MAX_HISTORY + 20 do
            Settings.Set("frames", "glow", i % 2 == 0)
        end
        assert.equal(Settings.MAX_HISTORY, #Settings.History())
    end)

    it("hides advanced options in simple mode", function()
        assert.equal(4, #Settings.VisibleOptions("frames"))
        Settings.SetAdvanced(true)
        assert.equal(5, #Settings.VisibleOptions("frames"))
        assert.is_true(_G.PerennialUIDB.global.advanced)
    end)

    it("searches labels, descriptions and page titles", function()
        local found = Settings.Search("health")
        assert.equal(2, #found)
        assert.equal(1, #Settings.Search("HEALTH glow"))
        assert.equal(4, #Settings.Search("unit frames")) -- three options plus the Modules page toggle
        assert.equal(0, #Settings.Search("debug"))
        Settings.SetAdvanced(true)
        assert.equal(1, #Settings.Search("debug"))
        assert.equal(0, #Settings.Search("   "))
    end)

    it("lists pinned pages first, then by order", function()
        local function ids()
            local list = {}
            for i, page in ipairs(Settings.Pages()) do
                list[i] = page.id
            end
            return list
        end
        assert.same({ "general", "modules", "profiles", "sandbox", "frames", "history" }, ids())
        Settings.SetPinned("history", true)
        assert.same({ "history", "general", "modules", "profiles", "sandbox", "frames" }, ids())
        Settings.SetPinned("history", false)
        assert.equal("general", ids()[1])
    end)

    it("uses custom accessors and runs actions inside the safety net", function()
        local stored, ran = "a", 0
        Settings.RegisterPage({
            id = "custom",
            title = "Custom",
            options = {
                {
                    key = "letter", type = "select", label = "Letter",
                    values = function()
                        return { { value = "a" }, { value = "b" } }
                    end,
                    get = function()
                        return stored
                    end,
                    set = function(value)
                        stored = value
                    end,
                },
                { key = "go", type = "action", label = "Go", func = function()
                    ran = ran + 1
                end },
                { key = "boom", type = "action", label = "Boom", func = function()
                    error("action failed")
                end },
            },
        })
        assert.is_true(Settings.Set("custom", "letter", "b"))
        assert.equal("b", stored)
        assert.is_true(Settings.Run("custom", "go"))
        assert.equal(1, ran)
        assert.is_false(Settings.Run("custom", "boom"))
        assert.is_false(Settings.Run("custom", "letter"))
    end)

    it("rejects malformed pages", function()
        assert.has_error(function()
            Settings.RegisterPage({ id = "x" })
        end)
        assert.has_error(function()
            Settings.RegisterPage({ id = "general", title = "Again" })
        end)
        Settings.RegisterPage({ id = "dupes", title = "Dupes", options = {
            { key = "a", type = "toggle" }, { key = "a", type = "toggle" },
        } })
        assert.has_error(function()
            Settings.AllOptions("dupes")
        end)
    end)

    describe("core pages", function()
        it("changes the season and can undo it", function()
            assert.is_true(Settings.Set("general", "season", "winter"))
            assert.equal("winter", ns.Theme.GetSeason())
            Settings.Undo()
            assert.equal(ns.Theme.DEFAULT_SEASON, ns.Theme.GetSeason())
        end)

        it("turns modules on and off from the Modules page", function()
            assert.is_true(Settings.Get("modules", "frames"))
            Settings.Set("modules", "frames", false)
            assert.equal("disabled", ns.Modules.GetState("frames"))
            assert.is_false(Settings.Get("modules", "sandbox"))
        end)

        it("picks up a module registered after the page was built", function()
            Settings.AllOptions("modules")
            ns.Modules.Register({ id = "latecomer" })
            assert.is_true(Settings.Get("modules", "latecomer"))
        end)

        it("switches profile", function()
            ns.DB.CopyProfile("Default", "Alt")
            assert.is_true(Settings.Set("profiles", "active", "Alt"))
            assert.equal("Alt", ns.DB.GetProfileName())
            assert.is_false((Settings.Set("profiles", "active", "Missing")))
        end)

        it("describes recent changes on the History page", function()
            assert.is_truthy(Settings.Info("history", "changes"):find("No settings", 1, true))
            Settings.Set("frames", "glow", false)
            local text = Settings.Info("history", "changes")
            assert.is_truthy(text:find("Unit Frames: Low health glow  on -> off", 1, true))
        end)
    end)

    describe("window", function()
        local Window

        before_each(function()
            Window = ns.SettingsWindow
        end)

        local function noErrors()
            assert.same({}, ns.Safety.GetLog())
        end

        it("opens from /pui, closes on a second /pui, and closes with Escape", function()
            ns.Slash.Run("")
            assert.is_true(Window.IsOpen())
            assert.equal("PerennialUISettings", _G.UISpecialFrames[1])
            ns.Slash.Run("config")
            assert.is_false(Window.IsOpen())
            noErrors()
        end)

        it("shows every page, in both modes, without errors", function()
            for _, page in ipairs(Settings.Pages()) do
                assert.is_true(Window.ShowPage(page.id))
            end
            Settings.SetAdvanced(true)
            for _, page in ipairs(Settings.Pages()) do
                Window.ShowPage(page.id)
            end
            assert.is_false(Window.ShowPage("nonexistent"))
            noErrors()
        end)

        it("searches and returns to the page when the search is cleared", function()
            assert.equal(2, Window.Search("health"))
            assert.equal(0, Window.Search("zzzz"))
            assert.equal(0, Window.Search(""))
            noErrors()
        end)

        it("stays in step with changes made elsewhere", function()
            Window.ShowPage("frames")
            Settings.Set("frames", "scale", 2)
            Settings.Undo()
            ns.DB.SetProfile("Other")
            ns.Modules.Disable("frames")
            Settings.SetPinned("frames", true)
            noErrors()
        end)

        it("remembers its size and position", function()
            Window.Open()
            local frame = _G.PerennialUISettings
            assert.equal(720, frame:GetWidth())
            _G.PerennialUIDB.global.window = { w = 100, h = 100, x = 30, y = -20 }
            ns = Loader.load({ saved = _G.PerennialUIDB })
            ns.SettingsWindow.Open()
            frame = _G.PerennialUISettings
            assert.equal(560, frame:GetWidth()) -- clamped to the minimum
            assert.equal(30, frame.points[1][4])
        end)
    end)

    it("undoes from the slash command", function()
        Settings.Set("frames", "glow", false)
        ns.Slash.Run("undo")
        assert.is_true(mod.db.glow)
        assert.is_true(stub.printedContains("Undid the change to Low health glow"))
        ns.Slash.Run("undo")
        assert.is_true(stub.printedContains("Nothing to undo"))
    end)
end)
