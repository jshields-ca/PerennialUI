-- SPDX-License-Identifier: GPL-3.0-or-later
-- Combat queue, theme, compat, slash commands and startup.
local Loader = require("tests.helpers.loader")

describe("Combat queue", function()
    local ns, stub, Combat

    before_each(function()
        ns, stub = Loader.load()
        Combat = ns.Combat
    end)

    it("runs immediately out of combat", function()
        local ran = false
        assert.is_true(Combat.RunWhenSafe("a", "move", function()
            ran = true
        end))
        assert.is_true(ran)
    end)

    it("defers work in combat and replays it when combat ends", function()
        local order = {}
        stub.inCombat = true
        assert.is_false(Combat.RunWhenSafe("a", "move", function()
            order[#order + 1] = "a"
        end))
        Combat.RunWhenSafe("b", "move", function()
            order[#order + 1] = "b"
        end)
        assert.same({}, order)
        assert.equal(2, Combat.Pending())
        stub.inCombat = false
        stub.fire("PLAYER_REGEN_ENABLED")
        assert.same({ "a", "b" }, order)
        assert.equal(0, Combat.Pending())
    end)

    it("keeps only the latest call for the same owner and key", function()
        local value
        stub.inCombat = true
        Combat.RunWhenSafe("a", "scale", function()
            value = "first"
        end)
        Combat.RunWhenSafe("a", "scale", function()
            value = "last"
        end)
        stub.inCombat = false
        stub.fire("PLAYER_REGEN_ENABLED")
        assert.equal("last", value)
    end)

    it("drops queued work when its module is disabled", function()
        local ran = false
        local mod = ns.Modules.Register({ id = "bars" })
        stub.inCombat = true
        mod:RunWhenSafe("layout", function()
            ran = true
        end)
        ns.Modules.Disable("bars")
        stub.inCombat = false
        stub.fire("PLAYER_REGEN_ENABLED")
        assert.is_false(ran)
    end)

    it("one failing queued task does not block the others", function()
        local ran = false
        stub.inCombat = true
        Combat.RunWhenSafe("a", "x", function()
            error("bad")
        end)
        Combat.RunWhenSafe("b", "x", function()
            ran = true
        end)
        stub.inCombat = false
        stub.fire("PLAYER_REGEN_ENABLED")
        assert.is_true(ran)
    end)
end)

describe("Theme", function()
    local ns, Theme

    before_each(function()
        ns = Loader.load()
        Theme = ns.Theme
    end)

    it("defines every colour token in every season", function()
        local seasons = Theme.ListSeasons()
        assert.same({ "autumn", "spring", "summer", "winter" }, seasons)
        for i = 1, #seasons do
            assert.is_true(Theme.SetSeason(seasons[i]))
            for j = 1, #Theme.COLOR_TOKENS do
                local r, g, b, a = Theme.Color(Theme.COLOR_TOKENS[j])
                assert.is_true(r >= 0 and r <= 1 and g >= 0 and g <= 1 and b >= 0 and b <= 1)
                assert.equal(1, a)
            end
        end
    end)

    it("saves the season in the profile and announces the change", function()
        local changes = 0
        ns.Events.Listen("test", "PUI_THEME_CHANGED", function()
            changes = changes + 1
        end)
        Theme.SetSeason("winter")
        assert.equal(1, changes)
        assert.equal("winter", ns.DB.Profile().theme.season)
        assert.is_false(Theme.SetSeason("monsoon"))
        assert.equal("winter", Theme.GetSeason())
    end)

    it("follows the profile", function()
        Theme.SetSeason("winter")
        ns.DB.SetProfile("Other")
        assert.equal(Theme.DEFAULT_SEASON, Theme.GetSeason())
        ns.DB.SetProfile("Default")
        assert.equal("winter", Theme.GetSeason())
    end)

    it("exposes spacing and shape tokens", function()
        assert.equal(8, Theme.Get("space.md"))
        assert.is_nil(Theme.Get("space.nope.deeper"))
        assert.is_true(Theme.Radius() > 0)
        Theme.SetShape("crisp")
        assert.equal(0, Theme.Radius())
        assert.is_false(Theme.SetShape("blobby"))
    end)

    it("accepts a complete custom palette and rejects a partial one", function()
        local palette = {}
        for i = 1, #Theme.COLOR_TOKENS do
            palette[Theme.COLOR_TOKENS[i]] = "#336699"
        end
        Theme.RegisterSeason("custom", palette)
        assert.is_true(Theme.SetSeason("custom"))
        local r, g, b = Theme.Color("accent")
        assert.equal(0.2, r)
        assert.equal(0.4, g)
        assert.equal(0.6, b)
        assert.has_error(function()
            Theme.RegisterSeason("partial", { bg = "#000000" })
        end)
        assert.has_error(function()
            Theme.Color("glass")
        end)
    end)
end)

describe("Compat", function()
    it("detects Forever and Classic Era from the interface number", function()
        local ns = Loader.load()
        assert.is_true(ns.Compat.isForever)
        assert.is_false(ns.Compat.isClassicEra)
        ns = Loader.load({ interface = 11508 })
        assert.is_false(ns.Compat.isForever)
        assert.is_true(ns.Compat.isClassicEra)
    end)

    it("treats hidden and non-numeric values as missing", function()
        local ns = Loader.load()
        local secret = {}
        _G.issecretvalue = function(value)
            return value == secret
        end
        assert.equal(50, ns.Compat.Number(50, 0))
        assert.equal(0, ns.Compat.Number(secret, 0))
        assert.is_nil(ns.Compat.Number(nil))
        assert.equal(-1, ns.Compat.Number("12", -1))
        assert.is_true(ns.Compat.IsHidden(secret))
    end)
end)

describe("Slash commands", function()
    local ns, stub

    before_each(function()
        ns, stub = Loader.load()
    end)

    it("registers /pui and /perennial", function()
        assert.equal("/pui", _G.SLASH_PERENNIALUI1)
        assert.equal("/perennial", _G.SLASH_PERENNIALUI2)
        assert.equal("function", type(_G.SlashCmdList.PERENNIALUI))
    end)

    it("lists the required subcommands in help", function()
        _G.SlashCmdList.PERENNIALUI("")
        for _, name in ipairs({ "help", "move", "test", "safe", "bug" }) do
            assert.is_true(stub.printedContains("/pui " .. name .. " "))
        end
    end)

    it("toggles layout mode and announces it, but not in combat", function()
        local announced
        ns.Events.Listen("test", "PUI_LAYOUT_MODE", function(_, on)
            announced = on
        end)
        ns.Slash.Run("move")
        assert.is_true(announced)
        assert.is_true(ns.state.layoutMode)
        ns.Slash.Run("MOVE")
        assert.is_false(ns.state.layoutMode)
        stub.inCombat = true
        ns.Slash.Run("move")
        assert.is_false(ns.state.layoutMode)
    end)

    it("toggles test mode", function()
        ns.Slash.Run("  test  ")
        assert.is_true(ns.state.testMode)
    end)

    it("saves safe mode for the next load", function()
        ns.Slash.Run("safe")
        assert.is_true(_G.PerennialUIDB.global.safeMode)
        ns.Slash.Run("safe")
        assert.is_false(_G.PerennialUIDB.global.safeMode)
    end)

    it("enables and disables modules by id", function()
        ns.Modules.Register({ id = "bags" })
        ns.Slash.Run("disable bags")
        assert.equal("disabled", ns.Modules.GetState("bags"))
        ns.Slash.Run("enable bags")
        assert.equal("enabled", ns.Modules.GetState("bags"))
        ns.Slash.Run("enable nothing")
        assert.is_true(stub.printedContains("Could not enable nothing"))
    end)

    it("builds a bug report with module states and errors", function()
        local mod = ns.Modules.Register({ id = "bags" })
        ns.Safety.Call("bags", error, "bag exploded")
        local report = table.concat(ns.Slash.BugReport(), "\n")
        assert.is_truthy(report:find("16001", 1, true))
        assert.is_truthy(report:find("module bags: enabled", 1, true))
        assert.is_truthy(report:find("bag exploded", 1, true))
        assert.equal("bags", mod.id)
    end)

    it("reports unknown commands and survives a failing one", function()
        ns.Slash.Run("dance")
        assert.is_true(stub.printedContains("Unknown command 'dance'"))
        ns.Slash.Register("explode", "test", function()
            error("kaboom")
        end)
        ns.Slash.Run("explode")
        assert.equal("core.slash", ns.Safety.GetLog()[1].owner)
    end)
end)

describe("Packaging", function()
    it("every file in the TOC exists and carries the licence header", function()
        local files = Loader.tocFiles()
        assert.is_true(#files > 0)
        for i = 1, #files do
            local file = io.open(Loader.DIR .. files[i], "r")
            assert.is_truthy(file, files[i] .. " is listed in the TOC but missing")
            local first = file:read("*l")
            file:close()
            assert.equal("-- SPDX-License-Identifier: GPL-3.0-or-later", (first:gsub("\r", "")))
        end
    end)
end)
