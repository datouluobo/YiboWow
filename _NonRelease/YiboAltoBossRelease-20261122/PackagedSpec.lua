-- YiboAltoBoss Mists 2.9.0 / Forever 0.2.0 release replay from the actual CurseForge zips.
-- Core is loaded from the published API14 Core packages (Core-<Target>/), the addon from
-- Clean-<Target> and Overlay-<Target> (old package extracted, new package over it).
-- Run from repository root: lua _NonRelease/YiboAltoBossRelease-20261122/PackagedSpec.lua
local BootCore = dofile("_NonRelease/CoreRetailR2/Harness.lua")
local base = "_NonRelease/YiboAltoBossRelease-20261122/"
local checks, counts = 0, {}
local function Check(value, label) checks = checks + 1; assert(value, label) end
local versions = { Mists = "2.9.0", Forever = "0.2.0" }
local oldVersions = { Mists = "2.8.7", Forever = "0.1.0" }
local coreVersions = { Mists = "1.13.0", Forever = "0.3.0" }
local other = { Mists = "Forever", Forever = "Mists" }

local function Boot(client, addonRoot, opts)
    opts = opts or {}
    local e, core, fire, flush = BootCore(client, nil, nil, nil, nil, base .. "Core-" .. client .. "/YiboCore", "YiboCore.toc")
    -- The Core harness loader always passes "YiboCore" as the addon name; addon files need their own name.
    local function load(path, addonName)
        local chunk = assert(loadfile(path)); setfenv(chunk, e); chunk(addonName, {})
    end
    getmetatable(e.UIParent).__index.GetRegions = function() end
    e.TEST_GUID = "Player-Test-1"
    e.GetServerTime = function() return 200000 end
    if client == "Mists" then
        e.GetInstanceInfo = function() return nil, "none" end
        e.UnitExists = function() return false end
        getmetatable(e.UIParent).__index.UnregisterAllEvents = function(frame) frame.events = {} end
    end
    e.YiboAltoBossDB = opts.mistsDB or { sentinel = "mists" }
    e.YiboAltoBossForeverDB = opts.foreverDB
    fire("ADDON_LOADED")
    local registrations = { addon = 0, entry = 0 }
    local registerAddon, registerEntry = core.RegisterAddon, core.Entry.RegisterBusinessEntry
    core.RegisterAddon = function(...) registrations.addon = registrations.addon + 1; return registerAddon(...) end
    core.Entry.RegisterBusinessEntry = function(...) registrations.entry = registrations.entry + 1; return registerEntry(...) end
    if opts.configure then opts.configure(e, core) end
    for line in io.lines(addonRoot .. "/YiboAltoBoss.toc") do
        line = line:gsub("\r", "")
        if line:match("%.lua$") then load(addonRoot .. "/" .. line:gsub("\\", "/"), "YiboAltoBoss") end
    end
    fire("ADDON_LOADED", "YiboAltoBoss")
    fire("PLAYER_LOGIN")
    flush()
    return e, core, fire, flush, registrations
end

local function Initialized(client, e)
    if client == "Mists" then return e.YAB and e.YAB.CoreIntegration and e.YAB.CoreIntegration.initialized end
    return e.YAB and e.YAB.initialized
end

local function HasMessage(e, pattern)
    for _, message in ipairs(e.TEST_MESSAGES) do if tostring(message):find(pattern, 1, true) then return true end end
end

-- Previous-release stores produced by the actual previous package under the published Core.
local previous = {}
do
    local e, core = Boot("Mists", base .. "Old-Mists/YiboAltoBoss", { mistsDB = {
        settings = { normalInstanceLimit = 7, accountPage = "lockouts" },
        customTargets = { ["456"] = { id = 456, name = "Existing target" } },
    } })
    Check(Initialized("Mists", e) and e.YAB.Version == oldVersions.Mists, "old Mists package runs to produce its store")
    previous.Mists = core.Defaults:Copy(e.YiboAltoBossDB)
end
do
    local e, core = Boot("Forever", base .. "Old-Forever/YiboAltoBoss")
    Check(Initialized("Forever", e) and e.YAB.Version == oldVersions.Forever, "old Forever package runs to produce its store")
    local target = e.YAB.CustomTargets:Add(e.YAB.Store.db.customTargets, 123, "Old target")
    Check(target and e.YAB.Store:ToggleMark(core.Characters:GetCurrentID(), target), "old Forever records a manual mark")
    previous.Forever = core.Defaults:Copy(e.YiboAltoBossForeverDB)
    previous.ForeverID = core.Characters:GetCurrentID()
end

for _, client in ipairs({ "Mists", "Forever" }) do
    for _, kind in ipairs({ "Clean", "Overlay" }) do
        local root = base .. kind .. "-" .. client .. "/YiboAltoBoss"
        local tag = client .. "/" .. kind .. ": "
        local key = client .. "/" .. kind
        counts[key] = 0
        local before = checks
        -- Fresh, separate copy of the previous-release store for each root.
        local _, c0 = BootCore(client, nil, nil, nil, nil, base .. "Core-" .. client .. "/YiboCore", "YiboCore.toc")
        local opts = {}
        if client == "Mists" then opts.mistsDB = c0.Defaults:Copy(previous.Mists)
        else opts.foreverDB = c0.Defaults:Copy(previous.Forever) end

        local e, core, fire, flush, reg = Boot(client, root, opts)
        Check(core:IsInitialized() and core.API_VERSION == 14 and core.VERSION == coreVersions[client]
            and core:HasCapability("pixel-line", 1), tag .. "published Core API14 " .. tostring(core.VERSION))
        Check(Initialized(client, e) and e.YAB.Version == versions[client], tag .. "initializes package version " .. tostring(e.YAB and e.YAB.Version))
        Check(#e.TEST_MESSAGES == 0, tag .. "no startup or callback messages: " .. tostring(e.TEST_MESSAGES[1]))
        Check(reg.addon == 1 and reg.entry == 1, tag .. "one addon and one entry registration")
        local entry = core.Entry.businessEntries.yab
        local slash = e.SlashCmdList.YIBOALTOBOSS
        fire("ADDON_LOADED", "YiboAltoBoss"); fire("PLAYER_LOGIN"); fire("PLAYER_ENTERING_WORLD"); flush()
        Check(reg.addon == 1 and reg.entry == 1 and core.Entry.businessEntries.yab == entry
            and e.SlashCmdList.YIBOALTOBOSS == slash and slash, tag .. "duplicate events do not re-register")
        if client == "Mists" then
            local db = e.YiboAltoBossDB
            Check(db.settings.normalInstanceLimit == 7 and db.settings.accountPage == "lockouts"
                and db.customTargets["456"].name == "Existing target", tag .. "2.8.7 settings and custom targets kept")
            Check(e.YiboAltoBossForeverDB == nil, tag .. "Forever store untouched")
            Check(core.AccountView._pages["alto-boss"] and core.AccountView._pages["alto-lockouts"], tag .. "Mists pages registered")
        else
            local db = e.YiboAltoBossForeverDB
            local id = core.Characters:GetCurrentID()
            Check(id == previous.ForeverID and db.customTargets["123"].name == "Old target"
                and e.YAB.Store:Mark(id, "custom:123").source == "manual", tag .. "0.1.0 targets and marks kept")
            Check(e.YiboAltoBossDB.sentinel == "mists" and not e.YiboAltoBossDB.settings, tag .. "Mists store untouched")
            Check(core.AccountView._pages["alto-custom"] and core.AccountView._pages["alto-lockouts"], tag .. "Forever pages registered")
        end
        e.SlashCmdList.YIBOALTOBOSS(""); flush()
        -- Mists "/yab" with no argument prints its command help; only later messages count as errors.
        local slashMessages = #e.TEST_MESSAGES
        local page = client == "Mists" and "alto-boss" or "alto-custom"
        core.AccountView:ShowPage(page); flush()
        Check(not core.AccountView._pages[page].lastError, tag .. "main page renders: " .. tostring(core.AccountView._pages[page].lastError))
        core.AccountView:ShowPage("alto-lockouts"); flush()
        Check(not core.AccountView._pages["alto-lockouts"].lastError, tag .. "lockout page renders")
        core.UITheme:RefreshPixelLines(); flush()
        Check(#e.TEST_MESSAGES == slashMessages, tag .. "pages and pixel refresh without errors: " .. tostring(e.TEST_MESSAGES[slashMessages + 1]))

        -- Reload: the saved store from this session restores.
        local reopts = {}
        if client == "Mists" then reopts.mistsDB = core.Defaults:Copy(e.YiboAltoBossDB)
        else reopts.foreverDB = core.Defaults:Copy(e.YiboAltoBossForeverDB) end
        local re, rc = Boot(client, root, reopts)
        Check(Initialized(client, re) and #re.TEST_MESSAGES == 0, tag .. "reload initializes")
        if client == "Mists" then
            Check(re.YiboAltoBossDB.customTargets["456"] and re.YiboAltoBossDB.settings.normalInstanceLimit == 7, tag .. "reload keeps store")
        else
            Check(re.YAB.Store:Mark(rc.Characters:GetCurrentID(), "custom:123"), tag .. "reload keeps mark")
        end

        -- Wrong target: installed on the other client (with that client's published Core).
        local wrong = other[client]
        local we = Boot(wrong, root)
        Check(not Initialized(wrong, we) and not we.SlashCmdList.YIBOALTOBOSS and not we.YiboAltoBossDB.settings
            and we.YiboAltoBossDB.sentinel == "mists" and we.YiboAltoBossForeverDB == nil,
            tag .. "on " .. wrong .. " stops before any store write")
        Check(HasMessage(we, client == "Mists" and "Mists" or "Forever") or HasMessage(we, client == "Mists" and "熊猫人" or "无限服"),
            tag .. "wrong-target install message")

        -- API13 Core refused with the upgrade message, before store writes.
        local ae = Boot(client, root, { configure = function(_, c)
            c.CheckAPIVersion = function(_, minimum) return minimum <= 13 end
        end })
        Check(not Initialized(client, ae) and not ae.SlashCmdList.YIBOALTOBOSS
            and not ae.YiboAltoBossDB.settings and ae.YiboAltoBossForeverDB == nil, tag .. "API13 Core refused before write")
        Check(HasMessage(ae, "API14"), tag .. "API13 upgrade message: " .. tostring(ae.TEST_MESSAGES[1]))
        counts[key] = checks - before
    end
end
for _, key in ipairs({ "Mists/Clean", "Mists/Overlay", "Forever/Clean", "Forever/Overlay" }) do
    print(key .. ": " .. counts[key] .. " checks")
end
print("PASS YiboAltoBoss packaged clean/overlay replay: " .. checks .. " checks")
