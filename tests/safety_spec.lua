-- SPDX-License-Identifier: GPL-3.0-or-later
local Loader = require("tests.helpers.loader")

describe("Safety", function()
    local ns, stub, Safety

    before_each(function()
        ns, stub = Loader.load()
        Safety = ns.Safety
    end)

    it("returns results and passes arguments through", function()
        local ok, a, b = Safety.Call("x", function(p, q)
            return p + q, "second"
        end, 2, 3)
        assert.is_true(ok)
        assert.equal(5, a)
        assert.equal("second", b)
    end)

    it("passes nil arguments in the middle", function()
        local ok, count = Safety.Call("x", function(...)
            return select("#", ...)
        end, nil, nil, 1)
        assert.is_true(ok)
        assert.equal(3, count)
    end)

    it("catches errors and records them", function()
        local ok, err = Safety.Call("x", function()
            error("boom")
        end)
        assert.is_false(ok)
        assert.is_truthy(tostring(err):find("boom", 1, true))
        local log = Safety.GetLog()
        assert.equal(1, #log)
        assert.equal("x", log[1].owner)
        assert.equal(1, log[1].count)
    end)

    it("collapses repeated identical errors into one log entry", function()
        local function bad()
            error("same", 0)
        end
        Safety.Call("x", bad)
        Safety.Call("x", bad)
        Safety.Call("x", bad)
        assert.equal(1, #Safety.GetLog())
        assert.equal(3, Safety.GetLog()[1].count)
    end)

    it("trips an owner after too many errors in the window", function()
        local trippedOwner
        Safety.SetTripHandler(function(owner)
            trippedOwner = owner
        end)
        for _ = 1, Safety.threshold - 1 do
            Safety.Call("noisy", error, "x")
        end
        assert.is_nil(trippedOwner)
        assert.is_false(Safety.IsTripped("noisy"))
        Safety.Call("noisy", error, "x")
        assert.equal("noisy", trippedOwner)
        assert.is_true(Safety.IsTripped("noisy"))
    end)

    it("does not trip when errors are spread out over time", function()
        for _ = 1, Safety.threshold * 2 do
            Safety.Call("slow", error, "x")
            stub.advance(Safety.window + 1)
        end
        assert.is_false(Safety.IsTripped("slow"))
    end)

    it("keeps owners separate", function()
        for _ = 1, Safety.threshold do
            Safety.Call("a", error, "x")
        end
        assert.is_true(Safety.IsTripped("a"))
        assert.is_false(Safety.IsTripped("b"))
    end)

    it("survives a trip handler that errors", function()
        Safety.SetTripHandler(function()
            error("handler broke")
        end)
        for _ = 1, Safety.threshold do
            Safety.Call("a", error, "x")
        end
        assert.is_true(Safety.IsTripped("a"))
    end)

    it("Reset lets an owner start again", function()
        for _ = 1, Safety.threshold do
            Safety.Call("a", error, "x")
        end
        Safety.Reset("a")
        assert.is_false(Safety.IsTripped("a"))
        Safety.Call("a", error, "x")
        assert.is_false(Safety.IsTripped("a"))
    end)

    it("caps the log", function()
        for i = 1, Safety.maxLog + 10 do
            Safety.Call("owner" .. i, error, "e" .. i)
        end
        assert.equal(Safety.maxLog, #Safety.GetLog())
    end)

    it("Wrap returns results, or nothing on error", function()
        local good = Safety.Wrap("w", function(v)
            return v * 2
        end)
        local bad = Safety.Wrap("w", function()
            error("nope")
        end)
        assert.equal(8, good(4))
        assert.is_nil(bad())
    end)
end)
