-- SPDX-License-Identifier: GPL-3.0-or-later
local Loader = require("tests.helpers.loader")

describe("DB", function()
    local ns, DB

    before_each(function()
        ns = Loader.load()
        DB = ns.DB
    end)

    describe("defaults", function()
        it("fills missing keys without overwriting the player's values", function()
            local target = { a = 5, nested = { keep = "mine" } }
            DB.ApplyDefaults(target, { a = 1, b = 2, nested = { keep = "default", extra = true } })
            assert.same({ a = 5, b = 2, nested = { keep = "mine", extra = true } }, target)
        end)

        it("keeps an explicit false", function()
            local target = { on = false }
            DB.ApplyDefaults(target, { on = true })
            assert.is_false(target.on)
        end)

        it("does not share default tables between targets", function()
            local defaults = { list = { x = 1 } }
            local a = DB.ApplyDefaults({}, defaults)
            local b = DB.ApplyDefaults({}, defaults)
            a.list.x = 99
            assert.equal(1, b.list.x)
            assert.equal(1, defaults.list.x)
        end)

        it("strips values equal to defaults and empties nested tables", function()
            local target = { a = 1, b = 3, nested = { keep = "default" }, other = { x = 1 } }
            DB.StripDefaults(target, { a = 1, b = 2, nested = { keep = "default" } })
            assert.same({ b = 3, other = { x = 1 } }, target)
        end)
    end)

    describe("startup", function()
        it("creates a fresh database at the current schema", function()
            assert.equal(DB.SCHEMA, _G.PerennialUIDB.schema)
            assert.equal("Default", DB.GetProfileName())
            assert.equal("Default", _G.PerennialUIDB.profileKeys["Tester - Stubrealm"])
            assert.same({}, _G.PerennialUICharDB)
        end)

        it("repairs damaged saved variables instead of erroring", function()
            ns = Loader.load({ saved = { schema = 1, profiles = "oops", profileKeys = 7 }, savedChar = "bad" })
            assert.equal("Default", ns.DB.GetProfileName())
            assert.same({}, ns.DB.Profile())
        end)

        it("falls back to Default when the saved profile no longer exists", function()
            ns = Loader.load({ saved = { schema = 1, profileKeys = { ["Tester - Stubrealm"] = "Gone" } } })
            assert.equal("Default", ns.DB.GetProfileName())
        end)

        it("refuses to be used before saved variables load", function()
            ns = Loader.load({ boot = false })
            assert.has_error(function()
                ns.DB.Profile()
            end)
        end)
    end)

    describe("migrations", function()
        it("runs each pending migration once, in order", function()
            local ran = {}
            DB.SCHEMA = 3
            DB.migrations[2] = function(data)
                ran[#ran + 1] = 2
                data.renamed = data.old
                data.old = nil
            end
            DB.migrations[3] = function()
                ran[#ran + 1] = 3
            end
            local data = DB.Migrate({ schema = 1, old = "value" })
            assert.same({ 2, 3 }, ran)
            assert.equal(3, data.schema)
            assert.equal("value", data.renamed)
            DB.Migrate(data)
            assert.same({ 2, 3 }, ran)
        end)

        it("leaves data from a newer version untouched", function()
            local data = DB.Migrate({ schema = DB.SCHEMA + 5, future = true })
            assert.equal(DB.SCHEMA + 5, data.schema)
            assert.is_true(DB.newerData)
        end)
    end)

    describe("profiles", function()
        it("switches, lists and announces profiles", function()
            local announced
            ns.Events.Listen("test", "PUI_PROFILE_CHANGED", function(_, name)
                announced = name
            end)
            assert.is_true(DB.SetProfile("Healer"))
            assert.equal("Healer", announced)
            assert.equal("Healer", _G.PerennialUIDB.profileKeys["Tester - Stubrealm"])
            assert.same({ "Default", "Healer" }, DB.ListProfiles())
        end)

        it("rejects empty names", function()
            assert.is_false((DB.SetProfile("   ")))
            assert.is_false((DB.SetProfile(nil)))
        end)

        it("copies a profile deeply", function()
            DB.Profile().theme = { season = "winter" }
            assert.is_true(DB.CopyProfile("Default", "Copy"))
            DB.Profile().theme.season = "spring"
            assert.equal("winter", _G.PerennialUIDB.profiles.Copy.theme.season)
        end)

        it("deletes a profile but never the active one", function()
            DB.SetProfile("Temp")
            assert.is_false((DB.DeleteProfile("Temp")))
            DB.SetProfile("Default")
            _G.PerennialUIDB.profileKeys["Alt - Stubrealm"] = "Temp"
            assert.is_true(DB.DeleteProfile("Temp"))
            assert.is_nil(_G.PerennialUIDB.profiles.Temp)
            assert.is_nil(_G.PerennialUIDB.profileKeys["Alt - Stubrealm"])
        end)

        it("saves only changed values at logout", function()
            local mod = ns.Modules.Register({ id = "frames", defaults = { scale = 1, width = 200 } })
            mod.db.width = 240
            DB.OnLogout()
            assert.same({ width = 240 }, _G.PerennialUIDB.profiles.Default.modules.frames)
        end)
    end)

    describe("share strings", function()
        it("round-trips a profile", function()
            local mod = ns.Modules.Register({ id = "frames", defaults = { scale = 1, width = 200 } })
            mod.db.width = 240
            DB.Profile().theme = { season = "winter" }

            local text = assert(DB.Export())
            assert.equal("PUI1:", text:sub(1, 5))
            assert.is_true(DB.Import(text, "Shared"))
            assert.same(
                { modules = { frames = { width = 240 } }, theme = { season = "winter" } },
                _G.PerennialUIDB.profiles.Shared
            )
        end)

        it("accepts strings with whitespace pasted in", function()
            local text = DB.Export()
            assert.is_true(DB.Import("  " .. text:sub(1, 8) .. "\n" .. text:sub(9) .. "  ", "Shared"))
        end)

        it("rejects foreign, damaged and newer strings", function()
            assert.is_false((DB.Import("hello", "X")))
            assert.is_false((DB.Import("PUI1:not base64!", "X")))
            assert.is_false((DB.Import("PUI1:" .. ns.Serialize.ToBase64("garbage"), "X")))
            local newer = ns.Serialize.Encode({ schema = DB.SCHEMA + 1, profile = {} })
            local ok, err = DB.Import("PUI1:" .. ns.Serialize.ToBase64(newer), "X")
            assert.is_false(ok)
            assert.is_truthy(err:find("newer", 1, true))
            assert.is_nil(_G.PerennialUIDB.profiles.X)
        end)
    end)
end)
