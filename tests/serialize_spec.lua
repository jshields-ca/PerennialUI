-- SPDX-License-Identifier: GPL-3.0-or-later
local Loader = require("tests.helpers.loader")

describe("Serialize", function()
    local S

    before_each(function()
        S = Loader.load().Serialize
    end)

    it("round-trips nested plain data", function()
        local value = {
            name = "player frame",
            scale = 1.25,
            negative = -3,
            on = true,
            off = false,
            list = { "a", "b", "c" },
            [5] = "numeric key",
            text = "tricky: {braces} s3:abc; n1; \n newline",
            empty = {},
            nested = { deep = { deeper = { 1, 2, 3 } } },
        }
        local decoded = S.Decode(assert(S.Encode(value)))
        assert.same(value, decoded)
    end)

    it("preserves fractional numbers exactly", function()
        local value = { 0.1, 1 / 3, 123456.789, 1e-7 }
        assert.same(value, S.Decode(S.Encode(value)))
    end)

    it("is deterministic regardless of insertion order", function()
        local a = { x = 1, y = 2, z = 3 }
        local b = { z = 3, y = 2, x = 1 }
        assert.equal(S.Encode(a), S.Encode(b))
    end)

    it("refuses functions and self-referencing tables", function()
        assert.is_nil((S.Encode({ fn = print })))
        local loop = {}
        loop.self = loop
        assert.is_nil((S.Encode(loop)))
    end)

    it("returns nil for malformed input instead of erroring", function()
        local bad = { "", "x", "{", "s5:ab", "n12", "nabc;", "{s1:a", "tt", "{{t}t}", "s-1:a", 42 }
        for i = 1, #bad do
            assert.is_nil((S.Decode(bad[i])))
        end
    end)

    it("never executes its input", function()
        _G.PUI_TEST_RAN = nil
        S.Decode("PUI_TEST_RAN = true")
        S.Decode("s27:return (function() end)()")
        assert.is_nil(_G.PUI_TEST_RAN)
    end)

    it("Base64 round-trips every length and byte", function()
        local bytes = {}
        for i = 0, 255 do
            bytes[#bytes + 1] = string.char(i)
        end
        local all = table.concat(bytes)
        for length = 0, 7 do
            local piece = all:sub(1, length)
            assert.equal(piece, S.FromBase64(S.ToBase64(piece)))
        end
        assert.equal(all, S.FromBase64(S.ToBase64(all)))
    end)

    it("Base64 matches the standard encoding", function()
        assert.equal("UGVyZW5uaWFs", S.ToBase64("Perennial"))
        assert.equal("UFVJ", S.ToBase64("PUI"))
        assert.equal("YQ==", S.ToBase64("a"))
        assert.equal("YWI=", S.ToBase64("ab"))
    end)

    it("Base64 rejects invalid text", function()
        assert.is_nil(S.FromBase64("abc"))
        assert.is_nil(S.FromBase64("ab!d"))
        assert.is_nil(S.FromBase64("a=bc"))
        assert.is_nil(S.FromBase64(nil))
    end)
end)
