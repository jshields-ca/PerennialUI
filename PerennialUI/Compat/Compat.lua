-- SPDX-License-Identifier: GPL-3.0-or-later
-- Compatibility layer. Modules never branch on the client version or call a
-- flavor-specific API directly: they ask Compat. Forever comes first; Classic
-- Era shims are added here later without touching modules.
local _, ns = ...

local Compat = {}
ns.Compat = Compat

local version, build, _, interface = GetBuildInfo()

Compat.version = version
Compat.build = build
Compat.interface = interface or 0

-- Forever is patch 1.60.x (interface 160xx). Classic Era is 1.15.x (115xx).
Compat.isForever = Compat.interface >= 16000 and Compat.interface < 20000
Compat.isClassicEra = Compat.interface >= 11300 and Compat.interface < 16000

--- True if the client is hiding this value from addons (combat restrictions).
--- TODO(verify): confirm the predicate's name against the Forever /api export.
function Compat.IsHidden(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

--- The value as a number, or fallback when it is hidden or not a number.
--- Use this for every combat value before doing arithmetic on it.
function Compat.Number(value, fallback)
    if Compat.IsHidden(value) or type(value) ~= "number" then
        return fallback
    end
    return value
end
