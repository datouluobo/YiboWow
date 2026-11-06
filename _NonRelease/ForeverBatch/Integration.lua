-- Batch acceptance: all seven real Forever manifests in one simulated client.
-- Individual business semantics remain covered by each target's Smoke.lua.
-- Optional argument replays the exact staged runtime; fixtures remain in the workspace.
local payload = arg and arg[1]
if payload then
    local originalLoadfile, originalLines = loadfile, io.lines
    local function RuntimePath(path)
        if path:match("^_NonRelease/Yibo[^/]+/") then
            return payload:gsub("\\", "/") .. "/" .. path:gsub("^_NonRelease/", "")
        end
        if path:match("^Yibo[^/]+/") then
            return payload:gsub("\\", "/") .. "/" .. path:gsub("_Forever%.toc$", ".toc")
        end
        return path
    end
    loadfile = function(path) return originalLoadfile(RuntimePath(path)) end
    io.lines = function(path) return originalLines(RuntimePath(path)) end
end
local BootCore = dofile("_NonRelease/CoreForever/Harness.lua")
local checks = 0
local function Check(value, label)
    checks = checks + 1
    assert(value, label)
end
local addons = { "YiboBuilds", "YiboCrafting", "YiboCurrency", "YiboMail", "YiboReputation", "YiboVault" }
local probes = { "YiboAltoBossForeverProbe", "YiboBuildsForeverProbe", "YiboProgressForeverProbe" }
local pages = { "builds", "crafting", "currency", "mail-inbox", "reputation", "vault-items" }
local function Count(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end
local function Boot(reverse, language, saved)
    local e, core, fire, _, load = BootCore(true, saved and saved.YiboCoreForeverDB)
    e.GetLocale = function() return language end
    e.GetBuildInfo = function() return "1.60.1", "70374", "Oct 12 2026", 16001 end
    e.print = function(message) e.TEST_MESSAGES[#e.TEST_MESSAGES + 1] = message end
    e.TEST_GUID = "Player-Batch-1"
    e.GetServerTime = function() return 200000 end
    e.IsLoggedIn = function() return true end
    -- No real business objects in this fixture: absent data must stay unobserved.
    e.GetProfessions = function() return nil end
    for _, name in ipairs(addons) do
        e[name .. "DB"] = { sentinel = "mists" }
        e[name .. "ForeverDB"] = saved and saved[name .. "ForeverDB"]
    end
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN")
    for offset = 1, #addons do
        local name = addons[reverse and (#addons + 1 - offset) or offset]
        for line in io.lines(name .. "/" .. name .. "_Forever.toc") do
            line = line:gsub("\r", "")
            if line:match("%.lua$") then load(name .. "/" .. line:gsub("\\", "/"), name) end
        end
        fire("ADDON_LOADED", name)
        Check(e[name].initialized, name .. " initializes in the full batch")
    end
    for _, name in ipairs(probes) do
        local namespace, base = {}, "_NonRelease/" .. name .. "/"
        for line in io.lines(base .. name .. ".toc") do
            line = line:gsub("\r", "")
            if line:match("%.lua$") then
                local chunk = assert(loadfile(base .. line:gsub("\\", "/")))
                setfenv(chunk, e); chunk(name, namespace)
            end
        end
        fire("ADDON_LOADED", name)
        Check(e[name .. "DB"] ~= nil, name .. " initializes alongside business addons")
    end
    local function Flush()
        for _ = 1, 30 do
            if #e.TEST_TIMERS == 0 then return end
            local timers = e.TEST_TIMERS; e.TEST_TIMERS = {}
            for _, timer in ipairs(timers) do timer[2]() end
        end
        error("unbounded timers in combined batch")
    end
    fire("PLAYER_ENTERING_WORLD"); Flush()
    return e, core, fire, Flush
end

for _, language in ipairs({ "zhCN", "enUS" }) do
    for _, reverse in ipairs({ false, true }) do
        local e, core, fire, flush = Boot(reverse, language)
        local frames, slashCount = #e.TEST_FRAMES, Count(e.SlashCmdList)
        local seen = {}
        for key, value in pairs(e) do
            if type(key) == "string" and key:match("^SLASH_.+%d+$") then
                Check(type(value) == "string" and value:match("^/%a%a%a$"), "three-letter slash " .. key)
                Check(not seen[value], "unique combined slash " .. value)
                seen[value] = true
            end
        end
        for _, name in ipairs(addons) do
            fire("ADDON_LOADED", name)
            Check(e[name .. "DB"].sentinel == "mists" and Count(e[name .. "DB"]) == 1, name .. " leaves Mists saves untouched")
        end
        for _, name in ipairs(probes) do
            local db = e[name .. "DB"]
            local sessions = db.sessions
            fire("ADDON_LOADED", name)
            Check(db.sessions == sessions, name .. " ignores repeated load notifications")
            Check(#db.samples == 0, name .. " does not collect business samples on login")
        end
        Check(#e.TEST_FRAMES == frames and Count(e.SlashCmdList) == slashCount, "repeated addon notifications do not duplicate frames or commands")
        for _, page in ipairs(pages) do
            core.AccountView:Toggle(page); flush()
            Check(core.AccountView.activePageID == page and core.AccountView.frame.instances[page], "combined page opens: " .. page)
            core.AccountView.frame:Hide()
        end
        local descriptor = core.Contracts:Resolve("mail.items", { major = 1, minMinor = 0 })
        Check(descriptor ~= nil, "Mail contract resolves with all addons loaded")
        Check(e.YiboMail.Items:GetState(e.TEST_GUID).status == "not-yet-scanned", "unopened mailbox remains unknown in batch")
        Check(not e.YiboBuilds.Snapshot and not e.YiboCrafting.RecipeCatalog and not e.YiboMail.Queue, "Mists business modules remain excluded")
        local disk = { YiboCoreForeverDB = core.Defaults:Copy(e.YiboCoreForeverDB) }
        for _, name in ipairs(addons) do disk[name .. "ForeverDB"] = core.Defaults:Copy(e[name .. "ForeverDB"]) end
        fire("PLAYER_LEAVING_WORLD"); fire("PLAYER_LOGOUT"); flush()
        local restored, restoredCore = Boot(not reverse, language, disk)
        Check(restoredCore:IsInitialized(), "batch Core reloads saved state")
        for _, name in ipairs(addons) do Check(restored[name].initialized, name .. " restores with reverse load order") end
    end
end
print("ForeverBatch Integration passed: " .. checks .. " checks (seven business and three probe manifests; simulated client, two languages and both business load orders)")
