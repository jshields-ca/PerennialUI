-- SPDX-License-Identifier: GPL-3.0-or-later
-- Settings registry: the data behind the settings window. Pages declare
-- options; this file reads, validates and writes their values, keeps the
-- change history for undo, and answers searches. No frames are created here.
--
-- Option fields:
--   key       unique within the page (not needed for "header")
--   type      "toggle" | "range" | "select" | "action" | "info" | "header"
--   label     shown to the player
--   desc      optional second line
--   advanced  true hides the option in simple mode
--   range:    min, max, step
--   select:   values = { { value = , label = }, ... } or a function returning that
--   action:   func()
--   info:     text = string or function returning a string
--   get, set  optional accessors. Module pages default to module.db[key].
local _, ns = ...

local DB = ns.DB
local Events = ns.Events
local Safety = ns.Safety

local Settings = {}
ns.Settings = Settings

Settings.MAX_HISTORY = 100

local pages = {} -- id -> page
local order = {} -- pages in registration order
local history = {} -- oldest first

local VALUE_TYPES = { toggle = true, range = true, select = true }
local ALL_TYPES = { toggle = true, range = true, select = true, action = true, info = true, header = true }

--- Register a settings page. Returns the page.
---   id, title   required
---   order       lower sorts first (default 100)
---   owner       module id, if the page belongs to a module
---   options     list of options, or a function returning one (built on first use)
function Settings.RegisterPage(page)
    if type(page) ~= "table" or type(page.id) ~= "string" or type(page.title) ~= "string" then
        error("Settings.RegisterPage: a page needs an id and a title", 2)
    end
    if pages[page.id] then
        error("Settings.RegisterPage: page '" .. page.id .. "' is already registered", 2)
    end
    page.order = page.order or 100
    pages[page.id] = page
    order[#order + 1] = page
    Events.Fire("PUI_SETTINGS_PAGES")
    return page
end

function Settings.GetPage(id)
    return pages[id]
end

local function validate(page, options)
    local seen = {}
    for i = 1, #options do
        local option = options[i]
        if not ALL_TYPES[option.type] then
            error("settings page '" .. page.id .. "': unknown option type '" .. tostring(option.type) .. "'")
        end
        if option.type ~= "header" then
            if type(option.key) ~= "string" or seen[option.key] then
                error("settings page '" .. page.id .. "': options need unique keys")
            end
            seen[option.key] = true
        end
    end
    return options
end

--- Every option of a page, including advanced ones.
function Settings.AllOptions(pageId)
    local page = pages[pageId]
    if not page then
        return {}
    end
    if not page.built then
        local options = page.options or {}
        if type(options) == "function" then
            options = options()
        end
        page.built = validate(page, options)
    end
    return page.built
end

--- Forget a page's built option list so a function-built page is rebuilt.
function Settings.Invalidate(pageId)
    if pages[pageId] then
        pages[pageId].built = nil
    end
end

function Settings.IsAdvanced()
    return DB.Global().advanced == true
end

function Settings.SetAdvanced(on)
    DB.Global().advanced = on and true or false
    Events.Fire("PUI_SETTINGS_MODE", on and true or false)
end

--- The options of a page that the current mode shows.
function Settings.VisibleOptions(pageId)
    local all = Settings.AllOptions(pageId)
    if Settings.IsAdvanced() then
        return all
    end
    local visible = {}
    for i = 1, #all do
        if not all[i].advanced then
            visible[#visible + 1] = all[i]
        end
    end
    return visible
end

local function findOption(pageId, key)
    local all = Settings.AllOptions(pageId)
    for i = 1, #all do
        if all[i].key == key then
            return all[i]
        end
    end
end
Settings.GetOption = findOption

--- The { value, label } list of a select option.
function Settings.Values(option)
    local values = option.values
    if type(values) == "function" then
        values = values()
    end
    return values or {}
end

local function ownerModule(page)
    return page.owner and ns.Modules.Get(page.owner)
end

--- Current value of an option.
function Settings.Get(pageId, key)
    local page = pages[pageId]
    local option = page and findOption(pageId, key)
    if not option then
        return nil
    end
    if option.get then
        return option.get()
    end
    local mod = ownerModule(page)
    if mod then
        return DB.Module(mod.id, mod.defaults)[key]
    end
end

local function clean(option, value)
    if option.type == "toggle" then
        return value and true or false
    elseif option.type == "range" then
        if type(value) ~= "number" then
            return nil, "expected a number"
        end
        local low, high, step = option.min or 0, option.max or 1, option.step
        if step and step > 0 then
            value = low + math.floor((value - low) / step + 0.5) * step
        end
        if value < low then
            value = low
        elseif value > high then
            value = high
        end
        return value
    elseif option.type == "select" then
        local values = Settings.Values(option)
        for i = 1, #values do
            if values[i].value == value then
                return value
            end
        end
        return nil, "not one of the choices"
    end
    return nil, "this option has no value"
end

local function write(page, option, value)
    if option.set then
        option.set(value)
        return
    end
    local mod = ownerModule(page)
    if not mod then
        error("settings option '" .. option.key .. "' has no setter")
    end
    local old = DB.Module(mod.id, mod.defaults)[option.key]
    DB.Module(mod.id, mod.defaults)[option.key] = value
    if mod.state == "enabled" and mod.OnSettingChanged then
        Safety.Call(mod.id, mod.OnSettingChanged, mod, option.key, value, old)
    end
end

local function apply(pageId, key, value, record)
    local page = pages[pageId]
    local option = page and findOption(pageId, key)
    if not option or not VALUE_TYPES[option.type] then
        return false, "no such setting"
    end
    local cleaned, problem = clean(option, value)
    if cleaned == nil then
        return false, problem
    end
    local old = Settings.Get(pageId, key)
    if old == cleaned then
        return true
    end
    local ok, err = Safety.Call(page.owner or "core.settings", write, page, option, cleaned)
    if not ok then
        return false, err
    end
    if record then
        history[#history + 1] = {
            page = pageId, key = key, label = option.label or key,
            old = old, new = cleaned, time = GetTime(),
        }
        if #history > Settings.MAX_HISTORY then
            table.remove(history, 1)
        end
    end
    Events.Fire("PUI_SETTING_CHANGED", pageId, key, cleaned)
    return true
end

--- Change a setting. Returns true, or false plus the reason.
function Settings.Set(pageId, key, value)
    return apply(pageId, key, value, true)
end

--- Run an "action" option.
function Settings.Run(pageId, key)
    local page = pages[pageId]
    local option = page and findOption(pageId, key)
    if not option or option.type ~= "action" or type(option.func) ~= "function" then
        return false
    end
    return (Safety.Call(page.owner or "core.settings", option.func))
end

--- The text of an "info" option.
function Settings.Info(pageId, key)
    local option = findOption(pageId, key)
    local text = option and option.text
    if type(text) == "function" then
        local ok, result = Safety.Call("core.settings", text)
        text = ok and result or ""
    end
    return text or ""
end

--- Session change history, oldest first. Entries: page, key, label, old, new, time.
function Settings.History()
    return history
end

--- Revert the most recent change. Returns the reverted entry, or nil.
function Settings.Undo()
    local entry = table.remove(history)
    if not entry then
        return nil
    end
    apply(entry.page, entry.key, entry.old, false)
    return entry
end

local function pinned()
    local global = DB.Global()
    if type(global.pinned) ~= "table" then
        global.pinned = {}
    end
    return global.pinned
end

function Settings.IsPinned(pageId)
    return pinned()[pageId] == true
end

function Settings.SetPinned(pageId, on)
    pinned()[pageId] = on and true or nil
    Events.Fire("PUI_SETTINGS_PAGES")
end

--- Pages in display order: pinned first, then by order, then by title.
function Settings.Pages()
    local list = {}
    for i = 1, #order do
        list[i] = order[i]
    end
    local pins = pinned()
    table.sort(list, function(a, b)
        local pa, pb = pins[a.id] == true, pins[b.id] == true
        if pa ~= pb then
            return pa
        end
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.title:lower() < b.title:lower()
    end)
    return list
end

--- Options whose label, description or page title contains every word of
--- the query. Returns a list of { page = , option = }.
function Settings.Search(query)
    local words = {}
    for word in tostring(query or ""):lower():gmatch("%S+") do
        words[#words + 1] = word
    end
    local results = {}
    if #words == 0 then
        return results
    end
    local list = Settings.Pages()
    for i = 1, #list do
        local page = list[i]
        local options = Settings.VisibleOptions(page.id)
        for j = 1, #options do
            local option = options[j]
            if option.type ~= "header" and option.type ~= "info" then
                local haystack = (page.title .. " " .. (option.label or "") .. " " .. (option.desc or "")):lower()
                local match = true
                for k = 1, #words do
                    if not haystack:find(words[k], 1, true) then
                        match = false
                        break
                    end
                end
                if match then
                    results[#results + 1] = { page = page, option = option }
                end
            end
        end
    end
    return results
end
