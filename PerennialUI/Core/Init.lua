-- SPDX-License-Identifier: GPL-3.0-or-later
-- Namespace bootstrap. Loaded first; everything else hangs off `ns`.
local ADDON, ns = ...

ns.name = ADDON

local function readVersion()
    local get = C_AddOns and C_AddOns.GetAddOnMetadata
    local version = get and get(ADDON, "Version")
    -- An unpackaged checkout still carries the packager's placeholder token.
    if not version or version:find("@", 1, true) then
        return "dev"
    end
    return version
end

ns.version = readVersion()

-- Session-only flags. Anything that must survive a reload lives in the DB.
ns.state = {
    safeMode = false,
    testMode = false,
    layoutMode = false,
}

function ns.Print(...)
    print("Perennial UI:", ...)
end

PerennialUI = ns
