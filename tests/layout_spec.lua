-- SPDX-License-Identifier: GPL-3.0-or-later
local Loader = require("tests.helpers.loader")

describe("Layout", function()
    local ns, stub, Layout, frame

    before_each(function()
        ns, stub = Loader.load()
        Layout = ns.Layout
        frame = _G.CreateFrame("Frame", nil, _G.UIParent)
        frame:SetSize(200, 50)
    end)

    local function lastPoint(target)
        return target.points[#target.points]
    end

    it("snaps to the grid", function()
        assert.equal(16, Layout.Snap(13, 8))
        assert.equal(8, Layout.Snap(11.9, 8))
        assert.equal(-16, Layout.Snap(-13, 8))
        assert.equal(13, Layout.Snap(12.6, 1))
        assert.equal(13, Layout.Snap(12.6, nil))
    end)

    it("places a frame at its default position when registered", function()
        Layout.Register("test", "player", frame, { title = "Player", x = -200, y = -100 })
        local point = lastPoint(frame)
        assert.equal("CENTER", point[1])
        assert.equal(_G.UIParent, point[2])
        assert.equal(-200, point[4])
        assert.equal(-100, point[5])
        assert.same({ "player" }, Layout.List())
    end)

    it("saves a moved position in the profile and applies it", function()
        Layout.Register("test", "player", frame, { x = 0, y = 0 })
        assert.is_true(Layout.SetPosition("player", 120, -64))
        assert.same({ x = 120, y = -64 }, _G.PerennialUIDB.profiles.Default.layout.player)
        assert.equal(120, lastPoint(frame)[4])
        assert.is_false(Layout.SetPosition("missing", 0, 0))
    end)

    it("compensates for the frame's own scale", function()
        frame:SetScale(2)
        Layout.Register("test", "player", frame, { x = 100, y = 40 })
        assert.equal(50, lastPoint(frame)[4])
        assert.equal(20, lastPoint(frame)[5])
    end)

    it("restores the saved position on the next load", function()
        Layout.Register("test", "player", frame, { x = 0, y = 0 })
        Layout.SetPosition("player", 88, 16)
        ns = Loader.load({ saved = _G.PerennialUIDB })
        local again = _G.CreateFrame("Frame")
        ns.Layout.Register("test", "player", again, { x = 0, y = 0 })
        assert.equal(88, lastPoint(again)[4])
    end)

    it("keeps positions per profile", function()
        Layout.Register("test", "player", frame, { x = 0, y = 0 })
        Layout.SetPosition("player", 88, 16)
        ns.DB.SetProfile("Other")
        assert.equal(0, (Layout.GetPosition("player")))
    end)

    it("waits for combat to end before moving a frame", function()
        Layout.Register("test", "player", frame, { x = 0, y = 0 })
        local before = #frame.points
        stub.inCombat = true
        Layout.SetPosition("player", 40, 40)
        Layout.SetPosition("player", 80, 80)
        assert.equal(before, #frame.points)
        stub.inCombat = false
        stub.fire("PLAYER_REGEN_ENABLED")
        assert.equal(80, lastPoint(frame)[4])
        assert.equal(1, #frame.points) -- applied once, with the final position
    end)

    it("resets one mover or all of them", function()
        Layout.Register("test", "player", frame, { x = 10, y = 20 })
        Layout.SetPosition("player", 300, 300)
        Layout.Reset("player")
        assert.equal(10, lastPoint(frame)[4])
        assert.is_nil(_G.PerennialUIDB.profiles.Default.layout.player)
        Layout.SetPosition("player", 300, 300)
        Layout.ResetAll()
        assert.equal(20, lastPoint(frame)[5])
    end)

    it("rejects duplicate movers", function()
        Layout.Register("test", "player", frame)
        assert.has_error(function()
            Layout.Register("test", "player", frame)
        end)
    end)

    describe("layout mode", function()
        local mover

        before_each(function()
            mover = Layout.Register("test", "player", frame, { title = "Player", x = 0, y = 0 })
        end)

        it("turns on and off and announces it", function()
            local states = {}
            ns.Events.Listen("test", "PUI_LAYOUT_MODE", function(_, on)
                states[#states + 1] = on
            end)
            ns.Slash.Run("move")
            assert.is_true(Layout.IsActive())
            assert.is_true(mover.handle:IsShown())
            assert.equal(200, mover.handle:GetWidth())
            ns.Slash.Run("move")
            assert.is_false(Layout.IsActive())
            assert.same({ true, false }, states)
            assert.same({}, ns.Safety.GetLog())
        end)

        it("refuses to start in combat", function()
            stub.inCombat = true
            ns.Slash.Run("move")
            assert.is_false(Layout.IsActive())
            assert.is_true(stub.printedContains("not available in combat"))
        end)

        it("closes when combat starts", function()
            Layout.SetActive(true)
            stub.inCombat = true
            stub.fire("PLAYER_REGEN_DISABLED")
            assert.is_false(Layout.IsActive())
            assert.is_true(stub.printedContains("closed because combat started"))
        end)

        it("saves the snapped position when a handle is dropped", function()
            Layout.SetActive(true)
            mover.handle:Run("OnDragStart")
            mover.handle.center = { 960 + 101, 540 - 59 }
            mover.handle:Run("OnDragStop")
            assert.same({ x = 104, y = -56 }, _G.PerennialUIDB.profiles.Default.layout.player)
            assert.equal(104, lastPoint(frame)[4])
            assert.equal(104, lastPoint(mover.handle)[4])
        end)

        it("drops exactly where released when snapping is off", function()
            ns.Settings.Set("general", "snap", false)
            Layout.SetActive(true)
            mover.handle.center = { 960 + 101, 540 - 59 }
            mover.handle:Run("OnDragStop")
            assert.same({ x = 101, y = -59 }, _G.PerennialUIDB.profiles.Default.layout.player)
        end)

        it("uses the grid size from settings", function()
            ns.Settings.SetAdvanced(true)
            ns.Settings.Set("general", "grid", 32)
            Layout.SetActive(true)
            mover.handle.center = { 960 + 101, 540 - 59 }
            mover.handle:Run("OnDragStop")
            assert.same({ x = 96, y = -64 }, _G.PerennialUIDB.profiles.Default.layout.player)
        end)

        it("resets a mover on right click", function()
            Layout.SetActive(true)
            Layout.SetPosition("player", 300, 300)
            mover.handle:Run("OnClick", "RightButton")
            assert.equal(0, (Layout.GetPosition("player")))
        end)

        it("shows a handle for a frame registered while layout mode is on", function()
            Layout.SetActive(true)
            local late = Layout.Register("test", "target", _G.CreateFrame("Frame"), { x = 50, y = 0 })
            assert.is_truthy(late.handle)
            assert.is_true(late.handle:IsShown())
        end)

        it("reuses the handle of a removed mover", function()
            Layout.SetActive(true)
            local handle = mover.handle
            Layout.Unregister("player")
            assert.is_false(handle:IsShown())
            local again = Layout.Register("test", "player", frame, { title = "Player" })
            assert.equal(handle, again.handle)
        end)
    end)

    describe("with modules", function()
        it("removes a module's movers when it stops, and restores them when it starts", function()
            ns.Slash.Run("enable sandbox")
            assert.same({ "sandbox" }, Layout.List())
            ns.Slash.Run("disable sandbox")
            assert.same({}, Layout.List())
            ns.Slash.Run("enable sandbox")
            assert.same({ "sandbox" }, Layout.List())
            assert.same({}, ns.Safety.GetLog())
        end)
    end)
end)

describe("Sandbox module", function()
    local ns, stub

    before_each(function()
        ns, stub = Loader.load()
    end)

    it("is off until the player turns it on", function()
        assert.equal("disabled", ns.Modules.GetState("sandbox"))
        ns.Modules.SetEnabled("sandbox", true)
        assert.equal("enabled", ns.Modules.GetState("sandbox"))
        assert.is_true(ns.Modules.Get("sandbox").frame:IsShown())
    end)

    it("applies its scale setting", function()
        ns.Modules.SetEnabled("sandbox", true)
        ns.Settings.Set("sandbox", "scale", 1.5)
        assert.equal(1.5, ns.Modules.Get("sandbox").frame:GetScale())
    end)

    it("is paused by the safety net when it breaks itself, and hides", function()
        ns.Modules.SetEnabled("sandbox", true)
        ns.Settings.SetAdvanced(true)
        ns.Settings.Run("sandbox", "break")
        assert.equal("paused", ns.Modules.GetState("sandbox"))
        assert.is_false(ns.Modules.Get("sandbox").frame:IsShown())
        assert.is_true(stub.printedContains("Sandbox kept failing"))
        assert.same({}, ns.Layout.List())
    end)

    it("reacts to test mode", function()
        ns.Modules.SetEnabled("sandbox", true)
        ns.Slash.Run("test")
        assert.equal("Test mode: sample data", ns.Modules.Get("sandbox").frame.status:GetText())
    end)
end)
