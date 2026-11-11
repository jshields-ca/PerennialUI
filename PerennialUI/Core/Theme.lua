-- SPDX-License-Identifier: GPL-3.0-or-later
-- Design tokens. Modules never hard-code a colour, size or font: they ask
-- the theme. Palettes are the four seasons plus anything registered later.
local _, ns = ...

local Events = ns.Events

local Theme = {}
ns.Theme = Theme

local function hex(code)
    return {
        tonumber(code:sub(2, 3), 16) / 255,
        tonumber(code:sub(4, 5), 16) / 255,
        tonumber(code:sub(6, 7), 16) / 255,
        1,
    }
end

-- Every palette defines every colour token listed here.
Theme.COLOR_TOKENS = {
    "bg", "surface", "border", "text", "textMuted",
    "accent", "accentAlt", "success", "warning", "danger",
}

local seasons = {
    spring = {
        bg = hex("#1F2A22"), surface = hex("#2B3A2E"), border = hex("#4F6B4A"),
        text = hex("#F1F4E6"), textMuted = hex("#A9B79C"),
        accent = hex("#8CC265"), accentAlt = hex("#E9A6B8"),
        success = hex("#8CC265"), warning = hex("#E8C24A"), danger = hex("#D9594C"),
    },
    summer = {
        bg = hex("#2A2416"), surface = hex("#3A321E"), border = hex("#75643A"),
        text = hex("#FBF3DC"), textMuted = hex("#C2B48A"),
        accent = hex("#EDB334"), accentAlt = hex("#3E9C9C"),
        success = hex("#86B84F"), warning = hex("#EDB334"), danger = hex("#D4513F"),
    },
    autumn = {
        bg = hex("#2B1D17"), surface = hex("#3B2820"), border = hex("#7A4B33"),
        text = hex("#F6E9D8"), textMuted = hex("#BFA58D"),
        accent = hex("#D5682E"), accentAlt = hex("#C9A227"),
        success = hex("#8FA644"), warning = hex("#C9A227"), danger = hex("#C63D2F"),
    },
    winter = {
        bg = hex("#1A222C"), surface = hex("#25303D"), border = hex("#4C6076"),
        text = hex("#EAF0F5"), textMuted = hex("#9DAEBF"),
        accent = hex("#7FB2D9"), accentAlt = hex("#C7D3DD"),
        success = hex("#7FBF9A"), warning = hex("#E3C170"), danger = hex("#D8606A"),
    },
}

Theme.DEFAULT_SEASON = "autumn"

-- Non-colour tokens. `shape` switches the whole UI between soft and crisp.
local tokens = {
    space = { xs = 2, sm = 4, md = 8, lg = 12, xl = 16 },
    border = { width = 1 },
    shape = "soft",
    radius = { soft = 6, crisp = 0 },
    font = {
        -- Client fonts until an openly licensed face is chosen and bundled.
        body = "Fonts\\FRIZQT__.TTF",
        number = "Fonts\\ARIALN.TTF",
        size = { sm = 10, md = 12, lg = 14, xl = 18 },
    },
}

local current = Theme.DEFAULT_SEASON

--- r, g, b, a for a colour token of the active season.
function Theme.Color(name)
    local color = seasons[current][name]
    if not color then
        error("Theme: unknown colour token '" .. tostring(name) .. "'", 2)
    end
    return color[1], color[2], color[3], color[4]
end

--- A non-colour token by dotted path, e.g. Theme.Get("space.md").
function Theme.Get(path)
    local value = tokens
    for part in path:gmatch("[^%.]+") do
        if type(value) ~= "table" then
            return nil
        end
        value = value[part]
    end
    return value
end

--- Corner radius for the active shape language.
function Theme.Radius()
    return tokens.radius[tokens.shape] or 0
end

function Theme.GetShape()
    return tokens.shape
end

function Theme.GetSeason()
    return current
end

function Theme.ListSeasons()
    local names = {}
    for name in pairs(seasons) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

--- Add or replace a palette. Missing colour tokens are an error.
function Theme.RegisterSeason(name, palette)
    if type(name) ~= "string" or type(palette) ~= "table" then
        error("Theme.RegisterSeason(name, palette)", 2)
    end
    for i = 1, #Theme.COLOR_TOKENS do
        local token = Theme.COLOR_TOKENS[i]
        local color = palette[token]
        if type(color) == "string" then
            palette[token] = hex(color)
        elseif type(color) ~= "table" then
            error("Theme: palette '" .. name .. "' is missing '" .. token .. "'", 2)
        end
    end
    seasons[name] = palette
end

local function save(key, value)
    if ns.DB.IsReady() then
        local profile = ns.DB.Profile()
        if type(profile.theme) ~= "table" then
            profile.theme = {}
        end
        profile.theme[key] = value
    end
end

function Theme.SetSeason(name)
    if not seasons[name] then
        return false
    end
    if name ~= current then
        current = name
        save("season", name)
        Events.Fire("PUI_THEME_CHANGED")
    end
    return true
end

function Theme.SetShape(shape)
    if not tokens.radius[shape] then
        return false
    end
    if shape ~= tokens.shape then
        tokens.shape = shape
        save("shape", shape)
        Events.Fire("PUI_THEME_CHANGED")
    end
    return true
end

--- Read the theme choice from the active profile.
function Theme.Load()
    local saved = ns.DB.Profile().theme
    local season = type(saved) == "table" and saved.season
    local shape = type(saved) == "table" and saved.shape
    current = seasons[season] and season or Theme.DEFAULT_SEASON
    tokens.shape = tokens.radius[shape] and shape or "soft"
    Events.Fire("PUI_THEME_CHANGED")
end

Events.Listen("core.theme", "PUI_PROFILE_CHANGED", Theme.Load)
