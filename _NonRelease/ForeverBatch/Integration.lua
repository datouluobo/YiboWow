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
        -- These shared resources use table-variable registration and require a runtime check.
        local crafting = e.YiboCrafting
        local chinese = language == "zhCN"
        Check(crafting:T("UI.ALL_CHARACTERS") == (chinese and "全部角色" or "All characters"), "Crafting character filter translation")
        Check(crafting:T("UI.ALL_PROFESSIONS") == (chinese and "全部专业" or "All professions"), "Crafting profession filter translation")
        Check(crafting:T("UI.ALL_STATES") == (chinese and "全部状态" or "All states"), "Crafting state filter translation")
        Check(crafting:T("UI.LEARNED") == (chinese and "已学" or "Learned"), "Crafting learned cell translation")
        local footer = chinese and "显示 6 / 12 项 · 左键入口打开完整列表"
            or "Showing 6 / 12 recipes · Left-click the entry for the full list"
        Check(crafting:T("UI.PREVIEW_REMAINDER", 6, 12) == footer, "Crafting formatted preview footer translation")
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
        local view = core.AccountView
        local current = assert(core.Characters:GetCurrent())
        local alt = {id="Player-Batch-Alt", name="Alt", realm="OtherRealm", level=14}
        local originalRoster = view.GetVisibleCharacters
        view.GetVisibleCharacters = function() return {current, alt} end
        local slots = {}
        for slot=1,19 do slots[slot]={itemID=0} end
        local store = e.YiboBuilds.Store.db.characters
        store[alt.id] = {observedAt=1,slots=slots}
        local builds = view._pages.builds
        local historical = view:BuildContext(builds,{preview=true})
        Check(historical.scope=="all" and historical.characters[1].id==alt.id,
            "only historical realm falls back to all instead of an absent current realm")
        store[current.id] = {observedAt=1,slots=slots}
        Check(view:ShowPreview("builds",e.Minimap),"Builds opens a scoped preview")
        Check(view:SetPageScope("builds","realm:"..alt.realm),"preview can switch to the other realm")
        local preview = view.frame.instances.builds
        Check(preview.previewRows[1].name:GetText():find("Alt",1,true)~=nil
            and not builds.lastError,"scope switch repaints the other realm")
        view:Toggle("builds"); flush()
        Check(not view.frame.preview and not view:BuildContext(builds).scope and #preview.renderedEquipment==19,
            "realm choice in preview does not filter the current-character main page")
        local vaultPage = view._pages["vault-items"]
        Check(view:BuildContext(vaultPage).scopeDefinition~=nil
            and view:BuildContext(vaultPage,{preview=true}).scopeDefinition==nil,
            "Vault realm selector belongs to the account storage workspace")
        view.frame:Hide()
        view.GetVisibleCharacters = originalRoster
        store[alt.id], store[current.id] = nil, nil
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
