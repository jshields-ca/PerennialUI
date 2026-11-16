-- SPDX-License-Identifier: GPL-3.0-or-later
-- Design tokens. Modules never hard-code a colour, size or font: they ask
-- the theme. The look is dark, see-through glass tinted by the season: each
-- season is two accent colours, and every panel colour is derived from them.
-- Colours that carry meaning (health, power, threat) are not part of a
-- season and never change with it.
local _, ns = ...

local Events = ns.Events

local Theme = {}
ns.Theme = Theme

local MEDIA = "Interface\\AddOns\\" .. ns.name .. "\\Media\\"

local function hex(code, alpha)
    return {
        tonumber(code:sub(2, 3), 16) / 255,
        tonumber(code:sub(4, 5), 16) / 255,
        tonumber(code:sub(6, 7), 16) / 255,
        alpha or 1,
    }
end

--- Blend `amount` (0..1) of colour a into colour b. The result is opaque
--- unless alpha is given.
local function mix(a, b, amount, alpha)
    return {
        a[1] * amount + b[1] * (1 - amount),
        a[2] * amount + b[2] * (1 - amount),
        a[3] * amount + b[3] * (1 - amount),
        alpha or 1,
    }
end

-- Every palette defines every colour token listed here.
Theme.COLOR_TOKENS = {
    "bg", "surface", "border", "highlight", "text", "textMuted",
    "accent", "accentAlt", "success", "warning", "danger",
}

local INK = hex("#080D14") -- the dark base every panel is tinted from
local STEEL = hex("#28303A")

--- Build a full glass palette from a season's two accent colours.
function Theme.MakePalette(accent, accentAlt)
    if type(accent) == "string" then
        accent = hex(accent)
    end
    if type(accentAlt) == "string" then
        accentAlt = hex(accentAlt)
    end
    return {
        bg = mix(accent, INK, 0.11, 0.88), -- panels: see-through
        surface = mix(accent, hex("#161E2A"), 0.16, 0.92), -- controls on a panel
        border = mix(accent, STEEL, 0.42),
        highlight = { 1, 1, 1, 0.16 }, -- the lit top edge of a panel
        text = hex("#EEF4F8"),
        textMuted = hex("#A3B3C0"),
        accent = accent,
        accentAlt = accentAlt,
        success = hex("#5FE08A"),
        warning = hex("#FFC24B"),
        danger = hex("#FF6B5E"),
    }
end

local seasons = {
    spring = Theme.MakePalette("#7BD88F", "#F3A6C4"),
    summer = Theme.MakePalette("#FFC24B", "#2EC4B6"),
    autumn = Theme.MakePalette("#FF8A4C", "#E5B93C"),
    winter = Theme.MakePalette("#7CC4FF", "#B9A7FF"),
}

-- Colours with a meaning. They are the same in every season.
local fixed = {
    health = hex("#4FD06B"),
    mana = hex("#4C8DFF"),
    rage = hex("#E0483C"),
    energy = hex("#F2D14B"),
    focus = hex("#E8944A"),
    power = hex("#9AA7B4"), -- any other resource
    hostile = hex("#E5534B"),
    neutral = hex("#E8C547"),
    friendly = hex("#4FD06B"),
    inactive = hex("#7C8894"), -- dead, offline or tapped by someone else
    track = { 0, 0, 0, 0.45 }, -- the empty part of a bar
    plate = { 0, 0, 0, 0.65 }, -- behind text that sits on a picture
}

Theme.DEFAULT_SEASON = "spring"

-- The bundled fonts cover Latin scripts only. Other locales keep the
-- client's own fonts so text never turns into empty boxes.
local CLIENT_FONT, CLIENT_NUMBER_FONT = "Fonts\\FRIZQT__.TTF", "Fonts\\ARIALN.TTF"
local NON_LATIN = { ruRU = true, koKR = true, zhCN = true, zhTW = true }
local bundled = not NON_LATIN[GetLocale and GetLocale() or "enUS"]

-- Non-colour tokens. `shape` switches the whole UI between soft and crisp.
local tokens = {
    space = { xs = 2, sm = 4, md = 8, lg = 12, xl = 16 },
    border = { width = 1, rail = 3 },
    shape = "soft",
    radius = { soft = 6, crisp = 0 },
    font = {
        heading = bundled and (MEDIA .. "Fonts\\Sora-Bold.ttf") or CLIENT_FONT,
        body = bundled and (MEDIA .. "Fonts\\DMSans-Medium.ttf") or CLIENT_FONT,
        number = bundled and (MEDIA .. "Fonts\\DMMono-Medium.ttf") or CLIENT_NUMBER_FONT,
        fallback = CLIENT_FONT, -- used if a bundled file fails to load
        size = { sm = 11, md = 13, lg = 15, xl = 20 },
    },
    texture = {
        -- White masks with a 6px corner radius, tinted at draw time.
        panelFill = MEDIA .. "Textures\\panel-fill.tga",
        panelEdge = MEDIA .. "Textures\\panel-edge.tga",
        panelRail = MEDIA .. "Textures\\panel-rail.tga",
        slice = 8, -- nine-slice margin of both textures
        flat = "Interface\\Buttons\\WHITE8x8", -- the client's plain white square
    },
}

local current = Theme.DEFAULT_SEASON

--- r, g, b, a for a colour token of the active season.
function Theme.Color(name)
    local color = seasons[current][name] or fixed[name]
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

--- Add or replace a palette. Use Theme.MakePalette(accent, accentAlt) for a
--- glass palette, or pass every colour token yourself.
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
