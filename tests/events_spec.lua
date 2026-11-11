-- SPDX-License-Identifier: GPL-3.0-or-later
local Loader = require("tests.helpers.loader")

describe("Events", function()
    local ns, stub, Events

    before_each(function()
        ns, stub = Loader.load()
        Events = ns.Events
    end)

    it("delivers game events with their arguments", function()
        local got
        Events.Register("a", "UNIT_HEALTH", function(event, unit)
            got = event .. ":" .. unit
        end)
        assert.is_true(stub.isRegistered("UNIT_HEALTH"))
        stub.fire("UNIT_HEALTH", "player")
        assert.equal("UNIT_HEALTH:player", got)
    end)

    it("unregisters from the client when the last owner leaves", function()
        Events.Register("a", "UNIT_AURA", function() end)
        Events.Register("b", "UNIT_AURA", function() end)
        Events.Unregister("a", "UNIT_AURA")
        assert.is_true(stub.isRegistered("UNIT_AURA"))
        Events.Unregister("b", "UNIT_AURA")
        assert.is_false(stub.isRegistered("UNIT_AURA"))
    end)

    it("replaces the handler when an owner registers twice", function()
        local calls = {}
        Events.Register("a", "UNIT_AURA", function()
            calls[#calls + 1] = "first"
        end)
        Events.Register("a", "UNIT_AURA", function()
            calls[#calls + 1] = "second"
        end)
        stub.fire("UNIT_AURA")
        assert.same({ "second" }, calls)
    end)

    it("keeps delivering to other owners when one handler errors", function()
        local reached = false
        Events.Register("bad", "UNIT_AURA", function()
            error("broken module")
        end)
        Events.Register("good", "UNIT_AURA", function()
            reached = true
        end)
        stub.fire("UNIT_AURA")
        assert.is_true(reached)
        assert.equal("bad", ns.Safety.GetLog()[1].owner)
    end)

    it("lets a handler unregister itself during dispatch", function()
        local count = 0
        Events.Register("once", "UNIT_AURA", function()
            count = count + 1
            Events.Unregister("once", "UNIT_AURA")
        end)
        stub.fire("UNIT_AURA")
        stub.fire("UNIT_AURA")
        assert.equal(1, count)
        assert.is_false(stub.isRegistered("UNIT_AURA"))
    end)

    it("carries internal messages without touching the client", function()
        local got
        Events.Listen("a", "PUI_EXAMPLE", function(_, value)
            got = value
        end)
        assert.is_false(stub.isRegistered("PUI_EXAMPLE"))
        Events.Fire("PUI_EXAMPLE", 42)
        assert.equal(42, got)
    end)

    it("UnregisterAll removes everything an owner subscribed to", function()
        local count = 0
        local function bump()
            count = count + 1
        end
        Events.Register("a", "UNIT_AURA", bump)
        Events.Listen("a", "PUI_EXAMPLE", bump)
        Events.UnregisterAll("a")
        stub.fire("UNIT_AURA")
        Events.Fire("PUI_EXAMPLE")
        assert.equal(0, count)
    end)

    it("rejects a missing handler", function()
        assert.has_error(function()
            Events.Register("a", "UNIT_AURA", nil)
        end)
    end)
end)
