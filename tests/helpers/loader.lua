-- SPDX-License-Identifier: GPL-3.0-or-later
-- Loads the addon the way the client does: every file listed in the TOC, in
-- order, each called with (addonName, namespace). Run busted from the repo root.
local Stub = require("tests.stub.wow")

local Loader = {}

Loader.ADDON = "PerennialUI"
Loader.DIR = "PerennialUI/"

--- The Lua files listed in the TOC, in load order.
function Loader.tocFiles()
    local files = {}
    local toc = assert(io.open(Loader.DIR .. Loader.ADDON .. ".toc", "r"))
    for line in toc:lines() do
        line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            files[#files + 1] = (line:gsub("\\", "/"))
        end
    end
    toc:close()
    return files
end

--- Fresh stub globals and a freshly loaded addon. Returns ns, Stub.
--- opts.saved / opts.savedChar preset the saved variables;
--- opts.boot = false stops before ADDON_LOADED / PLAYER_LOGIN.
function Loader.load(opts)
    opts = opts or {}
    Stub.reset()
    if opts.interface then
        Stub.interface = opts.interface
    end
    local ns = {}
    local files = Loader.tocFiles()
    for i = 1, #files do
        local chunk = assert(loadfile(Loader.DIR .. files[i]))
        chunk(Loader.ADDON, ns)
    end
    _G.PerennialUIDB = opts.saved
    _G.PerennialUICharDB = opts.savedChar
    if opts.boot ~= false then
        Stub.fire("ADDON_LOADED", Loader.ADDON)
        Stub.fire("PLAYER_LOGIN")
    end
    return ns, Stub
end

return Loader
