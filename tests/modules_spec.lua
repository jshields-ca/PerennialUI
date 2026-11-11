-- SPDX-License-Identifier: GPL-3.0-or-later
local Loader = require("tests.helpers.loader")

describe("Modules", function()
    local ns, stub, Modules

    before_each(function()
        ns, stub = Loader.load()
        Modules = ns.Modules
    end)

    local function sample(id, extra)
        local def = { id = id, title = "Sample " .. id, defaults = { scale = 1, colors = { hp = "green" } }, log = {} }
        function def:OnEnable()
            self.log[#self.log + 1] = "enable"
        end
        function def:OnDisable()
            self.log[#self.log + 1] = "disable"
        end
        for k, v in pairs(extra or {}) do
            def[k] = v
        end
        return def
    end

    it("rejects bad and duplicate ids", function()
        assert.has_error(function()
            Modules.Register({})
        end)
        assert.has_error(function()
            Modules.Register({ id = "has space" })
        end)
        Modules.Register(sample("one"))
        assert.has_error(function()
            Modules.Register(sample("one"))
        end)
    end)

    it("starts a module registered after login, with defaults in its db", function()
        local mod = Modules.Register(sample("late"))
        assert.equal("enabled", Modules.GetState("late"))
        assert.same({ "enable" }, mod.log)
        assert.equal(1, mod.db.scale)
        assert.equal("green", mod.db.colors.hp)
        assert.is_true(mod.db.enabled)
    end)

    it("leaves a module off when enabledByDefault is false", function()
        local mod = Modules.Register(sample("optin", { enabledByDefault = false }))
        assert.equal("disabled", Modules.GetState("optin"))
        assert.same({}, mod.log)
    end)

    it("enables modules registered before login at PLAYER_LOGIN", function()
        ns, stub = Loader.load({ boot = false })
        local mod = ns.Modules.Register(sample("early"))
        assert.equal("disabled", ns.Modules.GetState("early"))
        stub.fire("ADDON_LOADED", "PerennialUI")
        stub.fire("PLAYER_LOGIN")
        assert.equal("enabled", ns.Modules.GetState("early"))
        assert.same({ "enable" }, mod.log)
    end)

    it("routes declared events to methods and stops on disable", function()
        local seen = {}
        local mod = sample("ev", { events = { UNIT_HEALTH = true, UNIT_AURA = "Auras" } })
        function mod:UNIT_HEALTH(event, unit)
            seen[#seen + 1] = event .. ":" .. unit
        end
        function mod:Auras(_, unit)
            seen[#seen + 1] = "auras:" .. unit
        end
        Modules.Register(mod)
        stub.fire("UNIT_HEALTH", "player")
        stub.fire("UNIT_AURA", "target")
        Modules.Disable("ev")
        stub.fire("UNIT_HEALTH", "player")
        table.sort(seen)
        assert.same({ "UNIT_HEALTH:player", "auras:target" }, seen)
        assert.same({ "enable", "disable" }, mod.log)
        assert.is_false(stub.isRegistered("UNIT_HEALTH"))
    end)

    it("SetEnabled saves the choice in the profile", function()
        Modules.Register(sample("saved"))
        Modules.SetEnabled("saved", false)
        assert.equal("disabled", Modules.GetState("saved"))
        assert.is_false(_G.PerennialUIDB.profiles.Default.modules.saved.enabled)
        Modules.SetEnabled("saved", true)
        assert.equal("enabled", Modules.GetState("saved"))
    end)

    it("pauses a module whose OnEnable errors, and keeps others running", function()
        local bad = sample("bad")
        function bad:OnEnable()
            error("cannot start")
        end
        Modules.Register(bad)
        Modules.Register(sample("fine"))
        local state, reason = Modules.GetState("bad")
        assert.equal("paused", state)
        assert.is_truthy(reason:find("cannot start", 1, true))
        assert.equal("enabled", Modules.GetState("fine"))
    end)

    it("pauses a module that keeps erroring, tells the player, and spares the rest", function()
        local healthy = 0
        local noisy = sample("noisy", { events = { UNIT_AURA = true } })
        function noisy:UNIT_AURA()
            error("bad aura code")
        end
        local calm = sample("calm", { events = { UNIT_AURA = true } })
        function calm:UNIT_AURA()
            healthy = healthy + 1
        end
        Modules.Register(noisy)
        Modules.Register(calm)

        for _ = 1, ns.Safety.threshold + 3 do
            stub.fire("UNIT_AURA", "player")
        end

        assert.equal("paused", Modules.GetState("noisy"))
        assert.same({ "enable", "disable" }, noisy.log)
        assert.equal("enabled", Modules.GetState("calm"))
        assert.equal(ns.Safety.threshold + 3, healthy)
        assert.is_true(stub.printedContains("Sample noisy kept failing"))
    end)

    it("lets a paused module be enabled again", function()
        local flaky = sample("flaky", { events = { UNIT_AURA = true } })
        local broken = true
        function flaky:UNIT_AURA()
            if broken then
                error("flaky")
            end
        end
        Modules.Register(flaky)
        for _ = 1, ns.Safety.threshold do
            stub.fire("UNIT_AURA")
        end
        assert.equal("paused", Modules.GetState("flaky"))
        broken = false
        assert.is_true(Modules.Enable("flaky"))
        stub.fire("UNIT_AURA")
        assert.equal("enabled", Modules.GetState("flaky"))
    end)

    it("loads no modules in safe mode", function()
        ns, stub = Loader.load({ boot = false, saved = { schema = 1, global = { safeMode = true } } })
        ns.Modules.Register(sample("early"))
        stub.fire("ADDON_LOADED", "PerennialUI")
        stub.fire("PLAYER_LOGIN")
        ns.Modules.Register(sample("late"))
        assert.equal("disabled", ns.Modules.GetState("early"))
        assert.equal("disabled", ns.Modules.GetState("late"))
        assert.is_true(stub.printedContains("Safe mode is on"))
    end)

    it("restarts modules against the new profile on a profile switch", function()
        local mod = Modules.Register(sample("prof"))
        mod.db.scale = 2
        ns.DB.SetProfile("Other")
        assert.equal(1, mod.db.scale)
        assert.same({ "enable", "disable", "enable" }, mod.log)
        ns.DB.SetProfile("Default")
        assert.equal(2, mod.db.scale)
    end)

    it("reports state changes as a message", function()
        local states = {}
        ns.Events.Listen("test", "PUI_MODULE_STATE", function(_, id, state)
            states[#states + 1] = id .. "=" .. state
        end)
        Modules.Register(sample("msg"))
        Modules.Disable("msg")
        assert.same({ "msg=enabled", "msg=disabled" }, states)
    end)
end)
