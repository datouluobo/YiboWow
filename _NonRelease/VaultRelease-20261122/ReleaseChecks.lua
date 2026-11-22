-- Vault API14 release checks against extracted player packages and the published Core packages.
-- Covers: single initialization on Core API14, per-file single load, idempotent re-init, previous-version saved data
-- surviving an overlay upgrade (old package writes, serialized reload, new package reads), wrong-target stop before
-- any store write, and refusal by a real published API13 Core package with the upgrade message.
local R = dofile("_NonRelease/MailRelease-20261122/Redirect.lua")
R.Install()
local BootCore = dofile("_NonRelease/CoreForever/Harness.lua")
local M, V = "_NonRelease/MailRelease-20261122", "_NonRelease/VaultRelease-20261122"
local checks = 0
local function Check(ok, label) checks = checks + 1; assert(ok, label) end
local expected = { Mists = "1.3.0-api1", Forever = "0.7.0-api1" }
local cores = { Forever = V .. "/Core-Forever/YiboCore", Mists = V .. "/Core-Mists/YiboCore" }
local cores13 = { Forever = V .. "/Core13-Forever/YiboCore", Mists = V .. "/Core13-Mists/YiboCore" }
local function Use(coreRoots, mists, forever)
    R.roots.YiboCore = { Forever = coreRoots.Forever, Mists = coreRoots.Mists }
    R.roots.YiboVault = { Forever = forever, Mists = mists }
    R.active = {}; R.ResetLoads()
end
local function TocRefs(root)
    local n = 0
    for line in R.realLines(root .. "/YiboVault.toc") do
        line = line:gsub("\r", "")
        if line:match("%.lua$") then n = n + 1 end
    end
    return n
end
-- Same simulated client as _NonRelease/VaultForever/Smoke.lua Boot (bags 0/1 + two equipment slots, 7 items).
local function Boot(saved, forever, configure)
    local env, core, event, _, load = BootCore(forever)
    env.TEST_GUID = "Player-Test-1"
    local clock = 100
    env.GetTime = function() return clock end
    event("ADDON_LOADED"); event("PLAYER_LOGIN")
    if forever then env.YiboVaultDB, env.YiboVaultForeverDB = { sentinel = "mists" }, saved
    else env.YiboVaultDB, env.YiboVaultForeverDB = saved, { sentinel = "forever" } end
    env.Enum = { BagIndex = { ReagentBag = 5 } }
    local data = { bags = { [0] = { [1] = { itemID = 6948, stackCount = 1 }, [2] = { itemID = 42, stackCount = 3 } },
        [1] = { [1] = { itemID = 43, stackCount = 1 } } }, equipment = { [7] = 271666, [16] = 3661 } }
    env.C_Container = {
        GetContainerNumSlots = function(bag) return bag == 0 and 3 or (bag == 1 and 1 or 0) end,
        GetContainerItemInfo = function(bag, slot) return data.bags[bag] and data.bags[bag][slot] end,
        GetContainerNumFreeSlots = function(bag)
            local count = bag == 0 and 3 or (bag == 1 and 1 or 0)
            for _ in pairs(data.bags[bag] or {}) do count = count - 1 end
            return count
        end,
    }
    env.GetInventoryItemID = function(_, slot) return data.equipment[slot] end
    env.GetInventoryItemLink = function(_, slot) local id = data.equipment[slot]; return id and ("item:" .. id) end
    env.C_Item.GetItemInfo = function(id) return "NativeItem" .. id, "item:" .. id end
    env.GetItemInfo = env.C_Item.GetItemInfo
    local function Flush()
        local guard = 0
        while #env.TEST_TIMERS > 0 do
            guard = guard + 1; assert(guard < 30, "unbounded timer loop")
            local pending = env.TEST_TIMERS; env.TEST_TIMERS = {}
            table.sort(pending, function(a, b) return a[1] < b[1] end)
            for _, timer in ipairs(pending) do clock = clock + timer[1]; timer[2]() end
        end
    end
    if configure then configure(env, core) end
    for line in io.lines("YiboVault/" .. (forever and "YiboVault_Forever.toc" or "YiboVault_Mists.toc")) do
        line = line:gsub("\r", "")
        if line:match("%.lua$") then load("YiboVault/" .. line:gsub("\\", "/"), "YiboVault") end
    end
    event("ADDON_LOADED", "YiboVault")
    return env, core, env.YiboVault, event, Flush
end
local function Collect(event, flush)
    event("PLAYER_ENTERING_WORLD"); flush()
    event("BAG_UPDATE_DELAYED"); event("UNIT_INVENTORY_CHANGED", "player"); flush()
end
local function Serialize(value)
    if type(value) == "string" then return string.format("%q", value) end
    if type(value) ~= "table" then return tostring(value) end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = { "{" }
    for _, key in ipairs(keys) do parts[#parts + 1] = "[" .. Serialize(key) .. "]=" .. Serialize(value[key]) .. "," end
    return table.concat(parts) .. "}"
end
local function Deserialize(text) local chunk = assert(loadstring("return " .. text)); setfenv(chunk, {}); return chunk() end
local function Has(messages, pattern)
    for _, message in ipairs(messages) do if tostring(message):find(pattern) then return tostring(message) end end
end
local summary, findings, lastSaved = {}, {}, {}
local layouts = {
    Mists = { { "Clean-Mists" }, { "Overlay-Mists", "Baseline-Mists", "1.2.6-api1" } },
    Forever = { { "Clean-Forever" }, { "Overlay-Forever", "Baseline-Forever", "0.6.5-api1" },
        { "Overlay-Forever-from-0.6.4", "Baseline-Forever-from-0.6.4", "0.6.4-api1" } },
}
for _, target in ipairs({ "Mists", "Forever" }) do
    local forever = target == "Forever"
    local other = forever and "Mists" or "Forever"
    for _, layout in ipairs(layouts[target]) do
        local dir, baselineDir, oldVersion = layout[1], layout[2], layout[3]
        local root = V .. "/" .. dir .. "/YiboVault"
        local label = target .. "/" .. dir
        local saved, savedText
        if baselineDir then
            local oldRoot = V .. "/" .. baselineDir .. "/YiboVault"
            Use(cores, oldRoot, oldRoot)
            local _, _, old, oldEvent, oldFlush = Boot(nil, forever)
            Check(old.initialized and old.VERSION == oldVersion, label .. ": previous package " .. oldVersion .. " initializes")
            Collect(oldEvent, oldFlush)
            Check(old.Items:Query({ sources = { "bags", "equipment" } }).totals.totalQuantity == 7, label .. ": previous package collected 7 items")
            old.db.settings.tooltipRealmScope = "all"
            savedText = Serialize(old.db); lastSaved[target] = lastSaved[target] or savedText
            saved = Deserialize(savedText)
        end
        Use(cores, root, root)
        local e, core, vault, event, flush = Boot(saved, forever)
        Check(core:IsInitialized() and core.API_VERSION == 14 and core:HasCapability("pixel-line", 1), label .. ": published Core API14 ready")
        Check(vault.initialized and vault.VERSION == expected[target], label .. ": Vault initializes with " .. expected[target])
        local entry = core.Registry:Get("YiboVault")
        Check(entry and entry.version == expected[target] and entry.requiredAPI == 14, label .. ": Core registry version/requiredAPI")
        local files, duplicates = R.LoadCounts(root .. "/")
        Check(files == TocRefs(root) and #duplicates == 0, label .. ": every TOC file loaded exactly once (" .. files .. ") " .. table.concat(duplicates, ","))
        local coreFiles, coreDup = R.LoadCounts(cores[target] .. "/")
        Check(coreFiles > 0 and #coreDup == 0, label .. ": published Core files loaded once each")
        if saved then
            Check(vault.db == saved, label .. ": new package adopts the previous saved table (same identity)")
            Check(vault.db.settings.tooltipRealmScope == "all", label .. ": previous settings preserved")
            Check(vault.db.byCharacter[e.TEST_GUID] ~= nil, label .. ": previous character snapshot preserved")
            local restored = vault.Items:Query({ sources = { "bags", "equipment" } })
            Check(restored and restored.totals.totalQuantity == 7, label .. ": previous snapshot readable before any new scan")
        end
        local db = vault.db
        Check(vault:Initialize() ~= false and vault.db == db, label .. ": repeat initialization keeps the store")
        local hooks = #e.GameTooltip.hooks.OnShow
        vault:Initialize(); event("ADDON_LOADED", "YiboVault")
        Check(#e.GameTooltip.hooks.OnShow == hooks and core.Registry:Get("YiboVault") == entry, label .. ": repeated init/ADDON_LOADED adds no hooks or registrations")
        Collect(event, flush)
        Check(vault.Items:Query({ sources = { "bags", "equipment" } }).totals.totalQuantity == 7, label .. ": new package collects live data")
        local otherStore = forever and e.YiboVaultDB or e.YiboVaultForeverDB
        Check(otherStore.sentinel == (forever and "mists" or "forever") and not otherStore.byCharacter, label .. ": other target store untouched")
        Check(#e.TEST_MESSAGES == 0, label .. ": no startup errors " .. table.concat(e.TEST_MESSAGES, " | "))
        summary[#summary + 1] = label .. (saved and (" upgrade from " .. oldVersion .. " keeps saved data") or " clean init-once") .. " ok"
    end
    -- Wrong target: this target's package installed on the other client (other client's Core).
    do
        local root = V .. "/Clean-" .. target .. "/YiboVault"
        if forever then Use(cores, root, nil) else Use(cores, nil, root) end
        local e, core, vault = Boot(nil, not forever)
        local label = target .. " package on " .. other .. " client"
        Check(core:IsInitialized() and R.LoadCounts(root .. "/") > 0, label .. ": host Core ready and package loaded")
        Check(not vault.initialized and not vault.db, label .. ": Vault stopped")
        if forever then
            Check(e.YiboVaultDB == nil and Serialize(e.YiboVaultForeverDB) == '{["sentinel"]="forever",}',
                label .. ": no saved store created or modified (byte-identical)")
        else
            Check(Serialize(e.YiboVaultDB) == '{["sentinel"]="mists",}' and e.YiboVaultForeverDB == nil,
                label .. ": no saved store created or modified (byte-identical)")
        end
        Check(#e.TEST_MESSAGES == 1, label .. ": exactly one wrong-client message")
        Check(not core.Registry:Get("YiboVault"), label .. ": not registered with Core")
        summary[#summary + 1] = label .. " stopped before write: " .. table.concat(e.TEST_MESSAGES, " | ")
    end
    -- Real published API13 Core package must refuse the new Vault with the upgrade message.
    do
        local root = V .. "/Clean-" .. target .. "/YiboVault"
        Use(cores13, root, root)
        local saved = { sentinel = "api13-keep" }
        local e, core, vault = Boot(saved, forever)
        local label = target .. " on API13 Core"
        Check(core:IsInitialized() and core.API_VERSION == 13 and not core:HasCapability("pixel-line", 1), label .. ": real API13 Core package ready")
        Check(not vault.initialized, label .. ": Vault refused")
        local store = forever and e.YiboVaultForeverDB or e.YiboVaultDB
        local keys = {}; for key in pairs(store) do keys[#keys + 1] = tostring(key) end
        table.sort(keys)
        -- Both targets (Mists fixed in the 2026-11-22 rebuild: Core check before InitializeDatabase).
        Check(not vault.db and store == saved and #keys == 1 and Serialize(store) == '{["sentinel"]="api13-keep",}',
            label .. ": saved store untouched (byte-identical)")
        Check(not core.Registry:Get("YiboVault"), label .. ": not registered with API13 Core")
        local message = Has(e.TEST_MESSAGES, "14")
        Check(message and message:find("Core", 1, true), label .. ": upgrade message mentions Core API14: " .. table.concat(e.TEST_MESSAGES, " | "))
        summary[#summary + 1] = label .. " refused: " .. message
    end
    -- API13 Core with a real previous-version store: data must survive the refusal.
    do
        local root = V .. "/Clean-" .. target .. "/YiboVault"
        Use(cores13, root, root)
        local saved = Deserialize(lastSaved[target])
        local e, core, vault = Boot(saved, forever)
        local label = target .. " on API13 Core with previous store"
        Check(not vault.initialized and not core.Registry:Get("YiboVault"), label .. ": Vault refused")
        local store = forever and e.YiboVaultForeverDB or e.YiboVaultDB
        Check(store == saved and saved.settings.tooltipRealmScope == "all" and saved.byCharacter[e.TEST_GUID], label .. ": previous settings and snapshot kept")
        local same = Serialize(saved) == lastSaved[target]
        Check(not vault.db and lastSaved[target]:find('"known"', 1, true) and same, label .. ": store byte-identical (known coverage not normalized)")
        summary[#summary + 1] = label .. ": refused, data kept, serialized store unchanged"
    end
end
for _, line in ipairs(findings) do print("  " .. line) end
R.Uninstall()
for _, line in ipairs(summary) do print("  " .. line) end
print("Vault ReleaseChecks passed: " .. checks .. " checks (published Core packages + extracted Vault packages)")
