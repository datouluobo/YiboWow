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
local function Serialize(value)
    if type(value) == "string" then return string.format("%q", value) end
    if type(value) ~= "table" then return tostring(value) end
    local keys, parts = {}, { "{" }
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do parts[#parts + 1] = "[" .. Serialize(k) .. "]=" .. Serialize(value[k]) .. "," end
    return table.concat(parts) .. "}"
end

-- Previous-release stores produced by the actual previous package under the published Core.
local previous = {}
do
    local e, core = Boot("Mists", base .. "Old-Mists/YiboBuilds", { mistsDB = {
        marker = "keep", settings = { appearanceMode = "equipment", previewColumns = { spec = false } },
    } })
    Check(Initialized("Mists", e) and e.YiboBuilds.VERSION == oldVersions.Mists, "old Mists package runs to produce its store")
    previous.Mists = core.Defaults:Copy(e.YiboBuildsDB)
end
do
    local e, core, fire, flush = Boot("Forever", base .. "Old-Forever/YiboBuilds")
    Check(Initialized("Forever", e) and e.YiboBuilds.VERSION == oldVersions.Forever, "old Forever package runs to produce its store")
    fire("PLAYER_ENTERING_WORLD"); flush()
    local row, state = e.YiboBuilds.Store:Get(e.TEST_GUID)
    Check(state == "known" and row.slots[1].itemID == 1001, "old Forever captured equipment")
    previous.Forever = core.Defaults:Copy(e.YiboBuildsForeverDB)
end

for _, client in ipairs({ "Mists", "Forever" }) do
    for _, kind in ipairs({ "Clean", "Overlay" }) do
        local root = base .. kind .. "-" .. client .. "/YiboBuilds"
        local tag = client .. "/" .. kind .. ": "
        local key = client .. "/" .. kind
        local before = checks
        local _, c0 = BootCore(client, nil, nil, nil, nil, base .. "Core-" .. client .. "/YiboCore", "YiboCore.toc")
        local opts = {}
        if client == "Mists" then opts.mistsDB = c0.Defaults:Copy(previous.Mists)
        else opts.foreverDB = c0.Defaults:Copy(previous.Forever) end

        local e, core, fire, flush, reg = Boot(client, root, opts)
        Check(core:IsInitialized() and core.API_VERSION == 14 and core.VERSION == coreVersions[client]
            and core:HasCapability("pixel-line", 1), tag .. "published Core API14 " .. tostring(core.VERSION))
        Check(Initialized(client, e) and e.YiboBuilds.VERSION == versions[client], tag .. "initializes package version " .. tostring(e.YiboBuilds and e.YiboBuilds.VERSION))
        Check(#e.TEST_MESSAGES == 0, tag .. "no startup or callback messages: " .. tostring(e.TEST_MESSAGES[1]))
        Check(reg.addon == 1 and reg.entry == 1 and reg.page == 1, tag .. "one addon, page and entry registration")
        fire("ADDON_LOADED", "YiboBuilds"); fire("PLAYER_LOGIN")
        if client == "Forever" then e.YiboBuilds:Initialize() else e.YiboBuilds.CoreIntegration:Initialize() end
        flush()
        Check(reg.addon == 1 and reg.entry == 1 and reg.page == 1, tag .. "duplicate events and initialize do not re-register")
        if client == "Mists" then
            local db = e.YiboBuildsDB
            Check(db.marker == "keep" and db.settings.appearanceMode == "equipment" and db.settings.previewColumns.spec == false
                and db.settings.previewColumns.talent1 == true, tag .. "1.5.4 settings kept")
            Check(e.YiboBuildsForeverDB == nil, tag .. "Forever store untouched")
        else
            local row, state = e.YiboBuilds.Store:Get(e.TEST_GUID)
            -- Before this session's first scan a kept snapshot is reported as "stale" by design.
            Check(state == "stale" and row.slots[1].itemID == 1001 and row.slots[16].itemID == 1016, tag .. "0.1.20 equipment snapshot kept: " .. tostring(state))
            fire("PLAYER_ENTERING_WORLD"); flush()
            Check(select(2, e.YiboBuilds.Store:Get(e.TEST_GUID)) == "known", tag .. "rescan after entering world")
            Check(e.YiboBuildsDB.sentinel == "mists" and not MistsTouched(e.YiboBuildsDB), tag .. "Mists store untouched")
        end
        local messages = #e.TEST_MESSAGES
        core.AccountView:ShowPage("builds"); flush()
        Check(not core.AccountView._pages.builds.lastError, tag .. "builds page renders: " .. tostring(core.AccountView._pages.builds.lastError))
        core.UITheme:RefreshPixelLines(); flush()
        Check(#e.TEST_MESSAGES == messages, tag .. "page and pixel refresh without errors: " .. tostring(e.TEST_MESSAGES[messages + 1]))

        -- Reload with this session's store.
        local reopts = {}
        if client == "Mists" then reopts.mistsDB = core.Defaults:Copy(e.YiboBuildsDB)
        else reopts.foreverDB = core.Defaults:Copy(e.YiboBuildsForeverDB) end
        local re = Boot(client, root, reopts)
        Check(Initialized(client, re) and #re.TEST_MESSAGES == 0, tag .. "reload initializes")
        if client == "Mists" then
            Check(re.YiboBuildsDB.marker == "keep" and re.YiboBuildsDB.settings.appearanceMode == "equipment", tag .. "reload keeps store")
        else
            Check(re.YiboBuilds.Store:Get(re.TEST_GUID).slots[1].itemID == 1001, tag .. "reload keeps snapshot")
        end

        -- Wrong target: installed on the other client (with that client's published Core).
        local wrong = other[client]
        local we = Boot(wrong, root)
        Check(not Initialized(client, we) and we.YiboBuildsDB.sentinel == "mists" and not MistsTouched(we.YiboBuildsDB)
            and we.YiboBuildsForeverDB == nil, tag .. "on " .. wrong .. " stops before any store write")
        counts[key .. "/wrongMessages"] = #we.TEST_MESSAGES
        counts[key .. "/wrongMessage"] = tostring(we.TEST_MESSAGES[1])
        -- 2026-11-22 rebuild: both packages give exactly one install notice; a real previous store stays byte-identical.
        Check(#we.TEST_MESSAGES == 1, tag .. "on " .. wrong .. " prints exactly one install notice: " .. table.concat(we.TEST_MESSAGES, " | "))
        if client == "Mists" then
            Check(HasMessage(we, "Install the YiboBuilds package") or HasMessage(we, "YiboBuilds："), tag .. "Mists wrong-target notice text")
            local own = core.Defaults:Copy(previous.Mists); local ownText = Serialize(own)
            local wp = Boot(wrong, root, { mistsDB = own })
            Check(not Initialized(client, wp) and wp.YiboBuildsDB == own and Serialize(own) == ownText and wp.YiboBuildsForeverDB == nil,
                tag .. "on " .. wrong .. " previous Mists store byte-identical")
        end

        -- API13 Core refused with the upgrade message.
        local ae = Boot(client, root, { configure = function(_, c)
            c.CheckAPIVersion = function(_, minimum) return minimum <= 13 end
        end })
        Check(not Initialized(client, ae) and ae.YiboBuildsForeverDB == nil, tag .. "API13 Core refused, no Forever store")
        Check(HasMessage(ae, "API14") or HasMessage(ae, "API 14"), tag .. "API13 upgrade message: " .. tostring(ae.TEST_MESSAGES[1]))
        counts[key .. "/api13MistsDefaults"] = MistsTouched(ae.YiboBuildsDB)
        Check(Serialize(ae.YiboBuildsDB) == '{["sentinel"]="mists",}', tag .. "API13 Core: Mists sentinel store byte-identical")
        -- API13 Core with this target's real previous-release store: byte-identical after refusal.
        local prevStore = core.Defaults:Copy(previous[client]); local prevText = Serialize(prevStore)
        local popts = { configure = function(_, c) c.CheckAPIVersion = function(_, minimum) return minimum <= 13 end end }
        if client == "Mists" then popts.mistsDB = prevStore else popts.foreverDB = prevStore end
        local pe = Boot(client, root, popts)
        local kept = client == "Mists" and pe.YiboBuildsDB or pe.YiboBuildsForeverDB
        Check(not Initialized(client, pe) and kept == prevStore and Serialize(prevStore) == prevText,
            tag .. "API13 Core: previous-release store byte-identical")
        counts[key] = checks - before
    end
end
for _, key in ipairs({ "Mists/Clean", "Mists/Overlay", "Forever/Clean", "Forever/Overlay" }) do
    print(key .. ": " .. counts[key] .. " checks; wrong-target messages=" .. counts[key .. "/wrongMessages"]
        .. " first=" .. counts[key .. "/wrongMessage"] .. "; API13 Mists store normalized=" .. tostring(counts[key .. "/api13MistsDefaults"]))
end
print("PASS YiboBuilds packaged clean/overlay replay: " .. checks .. " checks")
