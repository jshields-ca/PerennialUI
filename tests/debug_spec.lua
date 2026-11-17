-- SPDX-License-Identifier: GPL-3.0-or-later
local Loader = require("tests.helpers.loader")

-- A value the fake client hides. It cannot be turned into text.
local SECRET = setmetatable({ secret = true }, {
    __tostring = function()
        error("hidden value")
    end,
})

describe("Debug mode", function()
    local ns, stub

    before_each(function()
        ns, stub = Loader.load()
    end)

    it("is off by default and records nothing", function()
        assert.is_false(ns.Debug.IsOn())
        assert.equal(0, #stub.timers)
        stub.fire("PLAYER_LOGOUT")
        assert.is_nil(_G.PerennialUIDB.global.snapshots)
        assert.equal(0, stub.screenshots)
    end)

    it("turns on and off from /pui debug", function()
        ns.Slash.Run("debug")
        assert.is_true(ns.Debug.IsOn())
        assert.is_true(stub.printedContains("Debug mode is on"))
        ns.Slash.Run("debug")
        assert.is_false(ns.Debug.IsOn())
        assert.is_true(stub.printedContains("Debug mode is off"))
    end)

    it("records watched frames and the widgets kept on them", function()
        local snapshot = ns.Debug.Snapshot("manual")
        local frames = snapshot.frames
        assert.equal(true, frames["unitframes_player"].shown)
        assert.equal("Tester", frames["unitframes_player.name"].text)
        assert.equal("14", frames["unitframes_player.level"].text)
        assert.equal("table", type(frames["unitframes_player.chip.picture"]))
        assert.equal(snapshot, _G.PerennialUIDB.global.snapshots.manual)
    end)

    it("records caught errors", function()
        ns.Safety.Call("tester", function()
            error("boom")
        end)
        local errors = ns.Debug.Snapshot("manual").errors
        assert.equal("tester", errors[1].owner)
        assert.is_truthy(errors[1].message:find("boom", 1, true))
    end)

    it("never saves a hidden value", function()
        _G.issecretvalue = function(value)
            return value == SECRET
        end
        stub.units.player.name = SECRET
        stub.fire("UNIT_NAME_UPDATE", "player")
        local frames = ns.Debug.Snapshot("manual").frames
        assert.equal("hidden", frames["unitframes_player.name"].text)
    end)

    it("after a reload, records once frames have drawn and takes a screenshot", function()
        ns.Debug.SetOn(true)
        ns, stub = Loader.load({ saved = _G.PerennialUIDB })
        assert.is_true(stub.printedContains("Debug mode is on"))
        assert.equal(1, #stub.timers)
        assert.is_nil(_G.PerennialUIDB.global.snapshots)
        stub.runTimers()
        assert.equal("load", _G.PerennialUIDB.global.snapshots.load.label)
        assert.equal(1, stub.screenshots)
        stub.fire("PLAYER_LOGOUT")
        assert.equal("exit", _G.PerennialUIDB.global.snapshots.exit.label)
    end)

    it("copes with a client that has no timer or screenshot call", function()
        _G.C_Timer, _G.Screenshot = nil, nil
        assert.is_false(ns.Debug.Screenshot())
        assert.equal(0, #ns.Safety.GetLog())
    end)
end)
