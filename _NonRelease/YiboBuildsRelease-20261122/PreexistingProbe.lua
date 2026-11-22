-- YiboBuilds Mists 1.6.0 / Forever 0.2.0 release replay from the actual CurseForge zips.
-- Core is loaded from the published API14 Core packages (Core-<Target>/), the addon from
-- Clean-<Target> and Overlay-<Target> (old package extracted, new package over it).
-- Run from repository root: lua _NonRelease/YiboBuildsRelease-20261122/PackagedSpec.lua
local BootCore = dofile("_NonRelease/CoreRetailR2/Harness.lua")
local base = "_NonRelease/YiboBuildsRelease-20261122/"
local checks, counts = 0, {}
local function Check(value, label) checks = checks + 1; assert(value, label) end
local versions = { Mists = "1.6.0", Forever = "0.2.0" }
local oldVersions = { Mists = "1.5.4", Forever = "0.1.20" }
local coreVersions = { Mists = "1.13.0", Forever = "0.3.0" }
local other = { Mists = "Forever", Forever = "Mists" }

local function Boot(client, addonRoot, opts)
    opts = opts or {}
    local e, core, fire, flush = BootCore(client, nil, nil, nil, nil, base .. "Core-" .. client .. "/YiboCore", "YiboCore.toc")
    -- The Core harness loader always passes "YiboCore" as the addon name; addon files need their own name.
    local function load(path, addonName)
        local chunk = assert(loadfile(path)); setfenv(chunk, e); chunk(addonName, {})
    end
    e.TEST_GUID = "Player-Test-1"
    -- Fixture gap: the shared frame fixture has no SetParent (real client frames do).
    local frameMethods = getmetatable(e.UIParent).__index
    if not frameMethods.SetParent then frameMethods.SetParent = function(frame, parent) frame.parent = parent end end
    e.GetServerTime = function() return 200000 end
    e.IsLoggedIn = function() return true end
    local items = { [1] = 1001, [5] = 1005, [16] = 1016 }
    local function Link(id) return "|cffffffff|Hitem:" .. id .. ":0:0:0|h[Item" .. id .. "]|h|r" end
    e.GetInventoryItemID = function(unit, slot) assert(unit == "player"); return items[slot] end
    e.GetInventoryItemLink = function(_, slot) local id = items[slot]; return id and Link(id) or nil end
    e.GetItemInfo = function(id) return "Item" .. id, Link(id), nil, nil, nil, nil, nil, nil, nil, 1 end
    for _, name in ipairs({ "EquipItemByName", "PickupInventoryItem", "SocketInventoryItem", "LearnTalent", "CastSpellByID" }) do
        e[name] = function() error("unexpected action " .. name) end
    end
    fire("ADDON_LOADED")
    e.YiboBuildsDB = opts.mistsDB or { sentinel = "mists" }
    e.YiboBuildsForeverDB = opts.foreverDB
    local registrations = { addon = 0, entry = 0, page = 0 }
    local registerAddon, registerEntry, registerPage = core.RegisterAddon, core.Entry.RegisterBusinessEntry, core.AccountView.RegisterPage
    core.RegisterAddon = function(...) registrations.addon = registrations.addon + 1; return registerAddon(...) end
    core.Entry.RegisterBusinessEntry = function(...) registrations.entry = registrations.entry + 1; return registerEntry(...) end
    core.AccountView.RegisterPage = function(...) registrations.page = registrations.page + 1; return registerPage(...) end
    if opts.configure then opts.configure(e, core) end
    for line in io.lines(addonRoot .. "/YiboBuilds.toc") do
        line = line:gsub("\r", "")
        if line:match("%.lua$") then load(addonRoot .. "/" .. line:gsub("\\", "/"), "YiboBuilds") end
    end
    fire("ADDON_LOADED", "YiboBuilds")
    fire("PLAYER_LOGIN")
    if not opts.noFlush then flush() end
    return e, core, fire, flush, registrations
end

local function Initialized(client, e)
    local addon = e.YiboBuilds
    if client == "Mists" then return addon and addon.CoreIntegration and addon.CoreIntegration.initialized end
    return addon and addon.initialized
end

local function HasMessage(e, pattern)
    for _, message in ipairs(e.TEST_MESSAGES) do if tostring(message):find(pattern, 1, true) then return true end end
end

local function MistsTouched(db)
    return db.characters ~= nil or db.settings ~= nil or db.schemaVersion ~= nil
end

local root = base .. "Old-Mists/YiboBuilds"
local we = Boot("Forever", root)
print("old 1.5.4 on Forever: init=", tostring(Initialized("Mists", we)), "messages=", #we.TEST_MESSAGES, "mistsTouched=", tostring(MistsTouched(we.YiboBuildsDB)))
local ae = Boot("Mists", root, { configure = function(_, c) c.CheckAPIVersion = function(_, m) return m <= 12 end end })
print("old 1.5.4 with API12 Core: init=", tostring(Initialized("Mists", ae)), "msg=", tostring(ae.TEST_MESSAGES[1]), "mistsTouched=", tostring(MistsTouched(ae.YiboBuildsDB)))