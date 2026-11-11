std = "lua51"
max_line_length = 120
codes = true
unused_args = false

exclude_files = {
    "PerennialUI/Libs/**",
    ".luarocks/**",
    "lua_modules/**",
    ".release/**",
}

-- Globals the addon defines.
globals = {
    "PerennialUI",
    "PerennialUIDB",
    "PerennialUICharDB",
    "SlashCmdList",
    "SLASH_PERENNIALUI1",
    "SLASH_PERENNIALUI2",
}

-- Client API the addon reads. Add a name here when you first use it.
read_globals = {
    "C_AddOns",
    "CreateFrame",
    "GetBuildInfo",
    "GetRealmName",
    "GetTime",
    "InCombatLockdown",
    "UnitName",
    "debugstack",
    "issecretvalue",
}

-- Tests install a fake client API, so they may write any global.
files["tests/**"] = {
    std = "+busted",
    ignore = { "11.", "12.", "13." },
}
