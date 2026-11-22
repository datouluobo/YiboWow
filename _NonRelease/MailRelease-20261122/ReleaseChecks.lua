-- Mail API14 release checks against extracted player packages and the published Core packages.
-- Covers: single initialization on Core API14, per-file single load, idempotent re-init, wrong-target stop
-- before any store write, and refusal by a real published API13 Core package with the upgrade message.
local R = dofile("_NonRelease/MailRelease-20261122/Redirect.lua")
R.Install()
local Boot = dofile("_NonRelease/MailForever/Harness.lua")
local M = "_NonRelease/MailRelease-20261122"
local checks = 0
local function Check(ok, label) checks = checks + 1; assert(ok, label) end
local expected = { Mists = "1.4.0-api1", Forever = "0.3.0-api1" }
local cores = { Forever = M .. "/Core-Forever/YiboCore", Mists = M .. "/Core-Mists/YiboCore" }
local cores13 = { Forever = M .. "/Core13-Forever/YiboCore", Mists = M .. "/Core13-Mists/YiboCore" }
local function TocRefs(root)
    local n = 0
    for line in R.realLines(root .. "/YiboMail.toc") do
        line = line:gsub("\r", "")
        if line:match("%.lua$") then n = n + 1 end
    end
    return n
end
local function Use(coreRoots, mists, forever)
    R.roots.YiboCore = { Forever = coreRoots.Forever, Mists = coreRoots.Mists }
    R.roots.YiboMail = { Forever = forever, Mists = mists }
    R.active = {}; R.ResetLoads()
end
local function Configure(e)
    e.CheckInbox = function() end
    e.MailFrame = e.CreateFrame("Frame", nil, e.UIParent); e.MailFrame:Hide()
end
local function Has(messages, pattern)
    for _, message in ipairs(messages) do if tostring(message):find(pattern) then return tostring(message) end end
end
local summary = {}
for _, target in ipairs({ "Mists", "Forever" }) do
    local forever = target == "Forever"
    local other = forever and "Mists" or "Forever"
    for _, layout in ipairs({ "Clean", "Overlay", forever and "Overlay-Forever-from-0.1.5" or "Overlay-Mists-from-1.3.4" }) do
        local dir = (layout == "Clean" or layout == "Overlay") and (layout .. "-" .. target) or layout
        local root = M .. "/" .. dir .. "/YiboMail"
        Use(cores, root, root)
        local e, core, mail, fire, flush = Boot(nil, (not forever) and Configure or nil, forever)
        local label = target .. "/" .. dir
        Check(core:IsInitialized() and core.API_VERSION == 14 and core:HasCapability("pixel-line", 1), label .. ": published Core API14 ready")
        Check(mail.initialized and mail.VERSION == expected[target], label .. ": Mail initializes with " .. expected[target])
        local entry = core.Registry:Get("YiboMail")
        Check(entry and entry.version == expected[target] and entry.requiredAPI == 14, label .. ": Core registry version/requiredAPI")
        local files, duplicates = R.LoadCounts(root .. "/")
        Check(files == TocRefs(root) and #duplicates == 0, label .. ": every TOC file loaded exactly once (" .. files .. ") " .. table.concat(duplicates, ","))
        local coreFiles, coreDup = R.LoadCounts(cores[target] .. "/")
        Check(coreFiles > 0 and #coreDup == 0, label .. ": published Core files loaded once each")
        for _, residual in ipairs({ "Bootstrap.lua", "Mists/Queue.lua", "Mists/Returns.lua", "Mists/InboxUI.lua", "Mists/ReturnUI.lua",
            "Mists/TransferMigration.lua", "Forever/Bootstrap.lua", "Forever/AccountPage.lua" }) do
            Check(not R.loads[root .. "/" .. residual], label .. ": residual not executed " .. residual)
        end
        local db = mail.db
        local listeners = #mail.Items.Events.listeners
        Check(mail:Initialize() and mail:Initialize() and mail.db == db and #mail.Items.Events.listeners == listeners,
            label .. ": repeat initialization is a no-op")
        fire("ADDON_LOADED", "YiboMail")
        Check(#mail.Items.Events.listeners == listeners and core.Registry:Get("YiboMail") == entry, label .. ": repeated ADDON_LOADED does not re-register")
        local otherStore = forever and e.YiboMailDB or e.YiboMailForeverDB
        Check(otherStore.sentinel == (forever and "mists" or "forever") and not otherStore.byCharacter, label .. ": other target store untouched")
        Check(#e.TEST_MESSAGES == 0, label .. ": no startup errors " .. table.concat(e.TEST_MESSAGES, " | "))
        summary[#summary + 1] = label .. " init-once ok"
    end
    -- Wrong target: this target's package installed on the other client (other client's Core).
    do
        local root = M .. "/Clean-" .. target .. "/YiboMail"
        if forever then Use(cores, root, nil) else Use(cores, nil, root) end
        local savedOther = nil
        local e, core, mail = Boot(savedOther, (not forever) and Configure or nil, not forever)
        local label = target .. " package on " .. other .. " client"
        Check(core:IsInitialized(), label .. ": host Core ready")
        Check(R.LoadCounts(root .. "/") > 0, label .. ": package files actually loaded")
        Check(not mail.initialized and not mail.db, label .. ": Mail stopped")
        if forever then
            Check(e.YiboMailDB == nil and e.YiboMailForeverDB.sentinel == "forever" and not e.YiboMailForeverDB.byCharacter,
                label .. ": no saved store created or modified")
        else
            -- Harness pre-seeds both stores with sentinels on the Forever client; neither may gain data.
            Check(e.YiboMailDB.sentinel == "mists" and not e.YiboMailDB.byCharacter
                and e.YiboMailForeverDB.sentinel == "forever" and not e.YiboMailForeverDB.byCharacter,
                label .. ": no saved store created or modified")
        end
        Check(not core.Registry:Get("YiboMail"), label .. ": not registered with Core")
        local message = Has(e.TEST_MESSAGES, "")
        Check(message, label .. ": wrong-client prompt shown")
        summary[#summary + 1] = label .. " stopped before write: " .. tostring(message)
    end
    -- Real published API13 Core package must refuse the new Mail with the upgrade message.
    do -- default fixture session language (Chinese); text is resolved through the API13 Core locale service
        local root = M .. "/Clean-" .. target .. "/YiboMail"
        Use(cores13, root, root)
        local saved = { sentinel = "api13-keep" }
        local e, core, mail = Boot(saved, function(env, c)
            if not forever then Configure(env) end
        end, forever)
        local label = target .. " on API13 Core"
        Check(core:IsInitialized() and core.API_VERSION == 13 and not core:HasCapability("pixel-line", 1), label .. ": real API13 Core package ready")
        Check(not mail.initialized and not mail.db, label .. ": Mail refused")
        local store = forever and e.YiboMailForeverDB or e.YiboMailDB
        local keys = 0; for _ in pairs(store) do keys = keys + 1 end
        Check(store == saved and saved.sentinel == "api13-keep" and keys == 1, label .. ": saved store untouched")
        Check(not core.Registry:Get("YiboMail"), label .. ": not registered with API13 Core")
        local message = Has(e.TEST_MESSAGES, "14")
        Check(message and (message:find("YiboCore", 1, true) or message:find("Core", 1, true)), label .. ": upgrade message mentions Core API14: " .. table.concat(e.TEST_MESSAGES, " | "))
        summary[#summary + 1] = label .. " refused: " .. message
    end
end
R.Uninstall()
for _, line in ipairs(summary) do print("  " .. line) end
print("Mail ReleaseChecks passed: " .. checks .. " checks (published Core packages + extracted Mail packages)")
