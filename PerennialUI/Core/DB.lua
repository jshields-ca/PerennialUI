-- SPDX-License-Identifier: GPL-3.0-or-later
-- Saved variables: schema migration, defaults, profiles and share strings.
--
-- PerennialUIDB (account):
--   schema       number, see DB.SCHEMA
--   global       account-wide values that are not part of any profile
--   profiles     name -> profile table (modules = { [id] = settings }, theme = ...)
--   profileKeys  "Name - Realm" -> profile name
-- PerennialUICharDB (character): free-form per-character data.
local _, ns = ...

local Events = ns.Events
local Serialize = ns.Serialize

local DB = {}
ns.DB = DB

--- Bump when the saved layout changes, and add DB.migrations[newSchema].
DB.SCHEMA = 1
--- migrations[n](root) upgrades saved data from schema n-1 to n.
DB.migrations = {}

DB.DEFAULT_PROFILE = "Default"
DB.EXPORT_PREFIX = "PUI1:"

local root, charRoot, profileName
local ready = false
local moduleDefaults = {}

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = copy(v)
    end
    return out
end
DB.Copy = copy

--- Fill keys missing from target with copies of defaults. Returns target.
function DB.ApplyDefaults(target, defaults)
    if type(defaults) ~= "table" then
        return target
    end
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            DB.ApplyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
    return target
end

--- Remove values equal to their default, so that only the player's changes
--- are saved and later changes to defaults reach everyone. Returns target.
function DB.StripDefaults(target, defaults)
    if type(target) ~= "table" or type(defaults) ~= "table" then
        return target
    end
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) == "table" then
                DB.StripDefaults(target[k], v)
                if next(target[k]) == nil then
                    target[k] = nil
                end
            end
        elseif target[k] == v then
            target[k] = nil
        end
    end
    return target
end

--- Run pending migrations on a saved-variables root. Returns the root.
function DB.Migrate(data)
    local from = tonumber(data.schema) or 0
    if from > DB.SCHEMA then
        -- Saved by a newer version. Leave it untouched rather than guess.
        DB.newerData = true
        return data
    end
    for version = from + 1, DB.SCHEMA do
        local migrate = DB.migrations[version]
        if migrate then
            migrate(data)
        end
        data.schema = version
    end
    return data
end

function DB.CharacterKey()
    return (UnitName("player") or "Unknown") .. " - " .. (GetRealmName() or "Unknown")
end

--- Called once from ADDON_LOADED, when saved variables are available.
function DB.Init()
    root = DB.Migrate(type(PerennialUIDB) == "table" and PerennialUIDB or {})
    PerennialUIDB = root
    if type(root.global) ~= "table" then
        root.global = {}
    end
    if type(root.profiles) ~= "table" then
        root.profiles = {}
    end
    if type(root.profileKeys) ~= "table" then
        root.profileKeys = {}
    end

    charRoot = type(PerennialUICharDB) == "table" and PerennialUICharDB or {}
    PerennialUICharDB = charRoot

    local key = DB.CharacterKey()
    profileName = root.profileKeys[key]
    if type(profileName) ~= "string" or type(root.profiles[profileName]) ~= "table" then
        profileName = DB.DEFAULT_PROFILE
    end
    root.profileKeys[key] = profileName
    if type(root.profiles[profileName]) ~= "table" then
        root.profiles[profileName] = {}
    end
    ready = true
end

function DB.IsReady()
    return ready
end

local function requireReady()
    if not ready then
        error("PerennialUI DB used before saved variables loaded", 3)
    end
end

function DB.Global()
    requireReady()
    return root.global
end

function DB.Char()
    requireReady()
    return charRoot
end

--- The active profile table.
function DB.Profile()
    requireReady()
    return root.profiles[profileName]
end

--- A module's settings in the active profile, with its defaults filled in.
function DB.Module(id, defaults)
    requireReady()
    local profile = root.profiles[profileName]
    if type(profile.modules) ~= "table" then
        profile.modules = {}
    end
    if type(profile.modules[id]) ~= "table" then
        profile.modules[id] = {}
    end
    if defaults then
        moduleDefaults[id] = defaults
    end
    return DB.ApplyDefaults(profile.modules[id], moduleDefaults[id])
end

function DB.GetProfileName()
    requireReady()
    return profileName
end

function DB.ListProfiles()
    requireReady()
    local names = {}
    for name in pairs(root.profiles) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

local function validName(name)
    return type(name) == "string" and name:match("%S") ~= nil and #name <= 48
end

--- Switch this character to a profile, creating it if needed.
function DB.SetProfile(name)
    requireReady()
    if not validName(name) then
        return false, "invalid profile name"
    end
    if type(root.profiles[name]) ~= "table" then
        root.profiles[name] = {}
    end
    if name == profileName then
        return true
    end
    profileName = name
    root.profileKeys[DB.CharacterKey()] = name
    Events.Fire("PUI_PROFILE_CHANGED", name)
    return true
end

--- Copy profile `from` over profile `to` (created if needed).
function DB.CopyProfile(from, to)
    requireReady()
    if type(root.profiles[from]) ~= "table" then
        return false, "no such profile"
    end
    if not validName(to) then
        return false, "invalid profile name"
    end
    if from == to then
        return true
    end
    root.profiles[to] = copy(root.profiles[from])
    if to == profileName then
        Events.Fire("PUI_PROFILE_CHANGED", to)
    end
    return true
end

--- Delete a profile. Characters that used it fall back to the default profile.
function DB.DeleteProfile(name)
    requireReady()
    if name == profileName then
        return false, "cannot delete the active profile"
    end
    if type(root.profiles[name]) ~= "table" then
        return false, "no such profile"
    end
    root.profiles[name] = nil
    for key, value in pairs(root.profileKeys) do
        if value == name then
            root.profileKeys[key] = nil
        end
    end
    return true
end

--- Reset the active profile to defaults.
function DB.ResetProfile()
    requireReady()
    root.profiles[profileName] = {}
    Events.Fire("PUI_PROFILE_CHANGED", profileName)
end

local function stripProfile(profile)
    if type(profile.modules) ~= "table" then
        return
    end
    for id, defaults in pairs(moduleDefaults) do
        if type(profile.modules[id]) == "table" then
            DB.StripDefaults(profile.modules[id], defaults)
            if next(profile.modules[id]) == nil then
                profile.modules[id] = nil
            end
        end
    end
end

--- A share string for a profile (the active one if name is omitted).
function DB.Export(name)
    requireReady()
    local profile = root.profiles[name or profileName]
    if type(profile) ~= "table" then
        return nil, "no such profile"
    end
    local payload = copy(profile)
    stripProfile(payload)
    local data, err = Serialize.Encode({ schema = DB.SCHEMA, profile = payload })
    if not data then
        return nil, err
    end
    return DB.EXPORT_PREFIX .. Serialize.ToBase64(data)
end

--- Store a share string as profile `name`. Does not switch to it.
function DB.Import(text, name)
    requireReady()
    if not validName(name) then
        return false, "invalid profile name"
    end
    if type(text) ~= "string" then
        return false, "not a Perennial UI share string"
    end
    text = text:gsub("%s+", "")
    local prefix = DB.EXPORT_PREFIX
    if text:sub(1, #prefix) ~= prefix then
        return false, "not a Perennial UI share string"
    end
    local data = Serialize.FromBase64(text:sub(#prefix + 1))
    local payload = data and Serialize.Decode(data)
    if type(payload) ~= "table" or type(payload.profile) ~= "table" or type(payload.schema) ~= "number" then
        return false, "the share string is damaged"
    end
    if payload.schema > DB.SCHEMA then
        return false, "the share string was made by a newer version of Perennial UI"
    end
    -- Reuse the root migrations by wrapping the profile in a throwaway root.
    local wrapper = DB.Migrate({ schema = payload.schema, profiles = { import = payload.profile } })
    root.profiles[name] = wrapper.profiles.import
    if name == profileName then
        Events.Fire("PUI_PROFILE_CHANGED", name)
    end
    return true
end

--- Called from PLAYER_LOGOUT: drop values that still equal their defaults.
function DB.OnLogout()
    if not ready or DB.newerData then
        return
    end
    for _, profile in pairs(root.profiles) do
        if type(profile) == "table" then
            stripProfile(profile)
        end
    end
end
