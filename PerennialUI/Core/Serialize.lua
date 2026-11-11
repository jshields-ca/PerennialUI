-- SPDX-License-Identifier: GPL-3.0-or-later
-- Plain-data serializer and Base64 codec for profile share strings.
-- Imported strings are parsed, never executed.
local _, ns = ...

local Serialize = {}
ns.Serialize = Serialize

local MAX_DEPTH = 50
local floor = math.floor

local TYPE_ORDER = { boolean = 1, number = 2, string = 3 }

local function keyLess(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then
        return TYPE_ORDER[ta] < TYPE_ORDER[tb]
    end
    if ta == "boolean" then
        return (not a) and b
    end
    return a < b
end

local function encodeNumber(v)
    if v ~= v or v == math.huge or v == -math.huge then
        error("cannot serialize nan or infinity")
    end
    if v == floor(v) and v > -1e15 and v < 1e15 then
        return ("n%d;"):format(v)
    end
    return ("n%.17g;"):format(v)
end

local function encode(value, out, depth)
    local t = type(value)
    if t == "boolean" then
        out[#out + 1] = value and "t" or "f"
    elseif t == "number" then
        out[#out + 1] = encodeNumber(value)
    elseif t == "string" then
        out[#out + 1] = "s" .. #value .. ":" .. value
    elseif t == "table" then
        if depth >= MAX_DEPTH then
            error("table is nested too deeply (or refers to itself)")
        end
        local keys = {}
        for k in pairs(value) do
            if not TYPE_ORDER[type(k)] then
                error("cannot serialize a key of type " .. type(k))
            end
            keys[#keys + 1] = k
        end
        table.sort(keys, keyLess)
        out[#out + 1] = "{"
        for i = 1, #keys do
            encode(keys[i], out, depth + 1)
            encode(value[keys[i]], out, depth + 1)
        end
        out[#out + 1] = "}"
    else
        error("cannot serialize a value of type " .. t)
    end
end

--- Returns the serialized string, or nil plus an error message.
function Serialize.Encode(value)
    local out = {}
    local ok, err = pcall(encode, value, out, 0)
    if not ok then
        return nil, tostring(err)
    end
    return table.concat(out)
end

local function decode(str, pos, depth)
    local tag = str:sub(pos, pos)
    if tag == "t" then
        return true, pos + 1
    elseif tag == "f" then
        return false, pos + 1
    elseif tag == "n" then
        local stop = str:find(";", pos, true)
        local text = stop and str:sub(pos + 1, stop - 1)
        local number = text and text:match("^[%-%+%.%deE]+$") and tonumber(text)
        if not number then
            error("bad number")
        end
        return number, stop + 1
    elseif tag == "s" then
        local colon = str:find(":", pos, true)
        local length = colon and tonumber(str:sub(pos + 1, colon - 1):match("^%d+$"))
        if not length or colon + length > #str then
            error("bad string")
        end
        return str:sub(colon + 1, colon + length), colon + length + 1
    elseif tag == "{" then
        if depth >= MAX_DEPTH then
            error("nested too deeply")
        end
        local result = {}
        pos = pos + 1
        while str:sub(pos, pos) ~= "}" do
            if pos > #str then
                error("unterminated table")
            end
            local key, value
            key, pos = decode(str, pos, depth + 1)
            if type(key) == "table" then
                error("bad key")
            end
            value, pos = decode(str, pos, depth + 1)
            result[key] = value
        end
        return result, pos + 1
    end
    error("unexpected data")
end

--- Returns the decoded value, or nil plus an error message.
function Serialize.Decode(str)
    if type(str) ~= "string" or str == "" then
        return nil, "nothing to decode"
    end
    local ok, value, pos = pcall(decode, str, 1, 0)
    if not ok then
        return nil, "malformed data"
    end
    if pos ~= #str + 1 then
        return nil, "malformed data"
    end
    return value
end

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local INDEX = {}
for i = 1, #ALPHABET do
    INDEX[ALPHABET:sub(i, i)] = i - 1
end

local function digit(n)
    return ALPHABET:sub(n + 1, n + 1)
end

function Serialize.ToBase64(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        out[#out + 1] = digit(floor(n / 262144))
            .. digit(floor(n / 4096) % 64)
            .. (b and digit(floor(n / 64) % 64) or "=")
            .. (c and digit(n % 64) or "=")
    end
    return table.concat(out)
end

--- Returns the decoded bytes, or nil if the text is not valid Base64.
function Serialize.FromBase64(text)
    if type(text) ~= "string" then
        return nil
    end
    text = text:gsub("%s+", "")
    if #text % 4 ~= 0 or not text:match("^[A-Za-z0-9+/]*=?=?$") then
        return nil
    end
    local out = {}
    for i = 1, #text, 4 do
        local c1, c2, c3, c4 = text:sub(i, i), text:sub(i + 1, i + 1), text:sub(i + 2, i + 2), text:sub(i + 3, i + 3)
        local n = INDEX[c1] * 262144 + INDEX[c2] * 4096 + (INDEX[c3] or 0) * 64 + (INDEX[c4] or 0)
        local a, b, c = floor(n / 65536), floor(n / 256) % 256, n % 256
        if c3 == "=" then
            out[#out + 1] = string.char(a)
        elseif c4 == "=" then
            out[#out + 1] = string.char(a, b)
        else
            out[#out + 1] = string.char(a, b, c)
        end
    end
    return table.concat(out)
end
