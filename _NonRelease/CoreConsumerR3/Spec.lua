local Boot = dofile("_NonRelease/CoreRetailR2/Harness.lua")
local Consumer = dofile("_NonRelease/CoreConsumerR3/Consumer.lua")
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not Equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function Count(value) local n = 0; for _ in pairs(value or {}) do n = n + 1 end; return n end
local function Has(rows, id) for _, row in ipairs(rows) do if row.id == id then return true end end; return false end
local function Groups(at)
    return { carried = { observedAt = at, state = "known", records = { { label = "Native pet name", token = "synthetic-A" } } },
        stable = { observedAt = at - 50, state = "unavailable", attemptedAt = at + 10,
            records = { { label = "Unmodified historical name", token = "synthetic-B" } } } }
end
local modes = { { "zhCN", "auto", "zh" }, { "zhTW", "auto", "zh" }, { "enUS", "auto", "en" },
    { "zhCN", "en", "en" }, { "enUS", "zh", "zh" } }
for _, target in ipairs({ "Retail", "Mists", "Forever" }) do
    for _, mode in ipairs(modes) do
        local e, c, fire, flush = Boot(target, nil, nil, function(env)
            env.GetLocale = function() return mode[1] end
        end)
        local selected
        local consumer = Consumer.New(function() return selected end)
        local ok, reason = consumer:Watch()
        Check(not ok and reason == "core-missing" and consumer:Route() == "route-ok", "missing Core only gates enhancement")
        Check(not consumer.active and consumer.starts == 0, "missing Core creates no consumer registration")
        selected = c; ok, reason = consumer:Watch()
        Check(not ok and reason == "core-not-ready" and c.Registry:Get(consumer.owner) == nil, "loaded but not ready is insufficient")
        consumer:Watch()
        fire("ADDON_LOADED"); fire("PLAYER_LOGIN"); flush()
        Check(consumer.active and consumer.starts == 1, "late CORE_READY starts once")
        Check(consumer:Route() == "route-ok", "base-route stand-in remains callable")
        local registeredPages = #c.AccountView:GetRegisteredPages()
        local registeredPanels = #c:GetRegisteredSettingsPanels()
        for n = 1, 3 do c.Events:FireIsolated("CORE_READY"); consumer:Start() end
        Check(consumer.starts == 1 and #c.AccountView:GetRegisteredPages() == registeredPages
            and #c:GetRegisteredSettingsPanels() == registeredPanels, "repeated ready/start produces no duplicate page/settings")
        Check(Count(c.CharacterCleanup:GetOwners()) == 1, "single cleanup owner without target-policy hardcoding")
        local function ExpectGate(code)
            local before = consumer.routeCalls
            local passed, actual = consumer:Start()
            Check(not passed and actual == code and consumer:Route() == "route-ok" and consumer.routeCalls == before + 1, "gate: " .. code)
        end
        c.API_VERSION = 12; ExpectGate("core-api-old"); c.API_VERSION = 13
        for _, capability in ipairs(Consumer.Required) do
            local name, minimum = capability[1], capability[2]
            local version = c.Capabilities._items[name]
            c.Capabilities._items[name] = nil; ExpectGate("core-capability-old")
            if minimum > 1 then c.Capabilities._items[name] = minimum - 1; ExpectGate("core-capability-old") end
            c.Capabilities._items[name] = version
        end
        for _, method in ipairs(Consumer.Methods) do
            local original = c[method[1]][method[2]]
            c[method[1]][method[2]] = nil
            local passed, code = Consumer.Gate(c)
            Check(not passed and code == "core-interface-missing", "advertised capability with missing method is rejected")
            c[method[1]][method[2]] = original
        end
        Check(c.AccountView:RegisterPage(consumer.owner, consumer.page) == nil, "Core rejects duplicate pages; consumer owns init guard")
        Check(c.CharacterCleanup:RegisterOwner(consumer.owner, c.CharacterCleanup:GetOwners()[consumer.owner]) == nil,
            "cleanup duplicates rejected, session owner guarded by consumer")

        -- Populate real Core directory via native-facing observation, never by business DB access.
        local function Observe(id, realm, class, level, name)
            e.TEST_GUID = id
            e.GetRealmName = function() return realm end
            e.UnitName = function() return name or "SameName" end
            e.UnitClass = function() return class, class, 3 end
            e.UnitLevel = function() return level or 60 end
            fire("PLAYER_ENTERING_WORLD"); flush()
        end
        Observe("Player-R3-1", "RealmA", "HUNTER", 60)
        Observe("Player-R3-2", "RealmB", "HUNTER", 70)
        Observe("Player-R3-NoData", "NoDataRealm", "HUNTER", 60)
        Observe("Player-R3-CarriedOnly", "CarriedOnlyRealm", "HUNTER", 60)
        Observe("Player-R3-Druid", "DruidRealm", "DRUID", 66)
        Observe("Player-R3-Current", "RealmA", "DRUID", 66, "Current")
        consumer.snapshots["Player-R3-1"] = Groups(200)
        consumer.snapshots["Player-R3-2"] = Groups(300)
        consumer.snapshots["Player-R3-Druid"] = Groups(400)
        consumer.snapshots["Player-R3-CarriedOnly"] = { carried = Groups(400).carried,
            stable = { state = "unavailable" } }
        -- Known-empty group is a genuine collected snapshot, distinct from absent snapshot.
        consumer.snapshots["Player-R3-2"].stable = { observedAt = 300, state = "known", records = {} }
        Check(c.AccountView:SetPageScope(consumer.pageID, "all"), "all-realm selection available")
        local context = c.AccountView:BuildContext(consumer.page)
        local rows = consumer:Project(context)
        Check(#rows == 2 and Has(rows, "Player-R3-1") and Has(rows, "Player-R3-2"), "cross-realm same-name GUIDs remain separate")
        Check(rows[1].name ~= rows[2].name, "full realm display disambiguates same-name characters")
        Check(not Has(rows, "Player-R3-NoData") and not Has(rows, "Player-R3-Druid")
            and not Has(rows, "Player-R3-CarriedOnly"), "business admission excludes no stable observation and non-hunter")
        local scopeIDs = {}; for _, scope in ipairs(context.scopeDefinition.values) do scopeIDs[scope.id] = true end
        Check(scopeIDs["realm:RealmA"] and scopeIDs["realm:RealmB"] and not scopeIDs["realm:NoDataRealm"]
            and not scopeIDs["realm:DruidRealm"] and not scopeIDs["realm:CarriedOnlyRealm"], "realm controls use identical snapshot admission")
        local identities = c.Characters:GetAll({ identityOnly = true })
        local identity = c.Characters:Get("Player-R3-1", { identityOnly = true })
        identity.name = "tampered"
        Check(c.Characters:Get("Player-R3-1", { identityOnly = true }).name == "SameName"
            and #identities >= 5 and c.Characters:GetCurrent({ identityOnly = true }).class == "DRUID", "identity projection copies; Core directory is not hunter-only")
        Check(c.Characters:Get("unknown", { identityOnly = true }) == nil, "unknown identity remains nil")
        for _, item in ipairs(identities) do Check(item.domains == nil, "identity projection excludes domain state") end
        local saved = consumer:ReadSnapshot("Player-R3-1")
        local projected = consumer:Project(context)
        Check(projected[1].groups.carried ~= consumer.snapshots[projected[1].id].carried, "projection detached from business snapshot")
        projected[1].groups.carried.records[1].label = "mutated"
        Check(Equal(saved, consumer:ReadSnapshot("Player-R3-1")), "projection mutation does not change owner records")
        Check(saved.carried.observedAt == 200 and saved.stable.observedAt == 150 and saved.stable.attemptedAt == 210
            and saved.stable.state == "unavailable" and #saved.stable.records == 1, "independent group times and unavailable historical rows preserved")
        Check(c.AccountView:SetPageScope(consumer.pageID, "realm:RealmB"), "select other realm")
        context = c.AccountView:BuildContext(consumer.page)
        Check(#context.characters == 1 and context.characters[1].id == "Player-R3-2", "realm selector changes admitted collection")
        Check(#consumer:Project(context)[1].groups.stable.records == 0, "known empty remains distinguishable from missing/unavailable")
        c.AccountView:SetPageScope(consumer.pageID, "all")
        local notices = consumer.notifications
        c.AccountView:SetCharacterHidden("Player-R3-1", true)
        Check(#c.AccountView:BuildContext(consumer.page).characters == 1 and consumer.notifications == notices + 1, "Core hide notifies consumer")
        c.AccountView:SetCharacterHidden("Player-R3-1", true)
        Check(consumer.notifications == notices + 1, "same visibility setting is silent")
        c.AccountView:SetCharacterHidden("Player-R3-1", false)
        Check(consumer.page.characterFilter.SetExpression(">=65"), "Core default level filter accepts expression")
        Check(#c.AccountView:BuildContext(consumer.page).characters == 1, "level filter applied after business admission")
        local valid = consumer.page.characterFilter.SetExpression("invalid")
        Check(not valid and #c.AccountView:BuildContext(consumer.page).characters == 1, "invalid filter retains last valid admission")
        consumer.page.characterFilter.SetExpression("")
        c.AccountView:SetPageCharacterSort(consumer.pageID, { mode = "level", direction = "asc", pinCurrent = false })
        Check(c.AccountView:BuildContext(consumer.page).characters[1].id == "Player-R3-1", "shared level sort ascending")
        c.AccountView:SetPageCharacterSort(consumer.pageID, { mode = "level", direction = "desc", pinCurrent = false })
        Check(c.AccountView:BuildContext(consumer.page).characters[1].id == "Player-R3-2", "shared level sort descending")
        c.Characters:SetShortName("Player-R3-1", "Short")
        Check(c.Characters:FormatName(c.Characters:Get("Player-R3-1", { identityOnly = true }), { nameMode = "short", realmMode = "full" }) == "Short-RealmA",
            "short display uses Core formatter without changing GUID")
        Check(Equal(saved, consumer:ReadSnapshot("Player-R3-1")), "hide/filter/sort/short name never rewrites business history")

        -- Main window and preview consume the same projection; Core owns the shell and entry channels.
        c.AccountView:ShowPage(consumer.pageID); flush()
        Check(not consumer.page.lastError and consumer.creates == 1, "actual Core invokes consumer page lifecycle")
        Check(Equal(c.AccountView.frame.instances[consumer.pageID].r3Rows,
            consumer:Project(c.AccountView:BuildContext(consumer.page))), "rendered main view matches pure projection")
        local previewContext = c.AccountView:BuildContext(consumer.page, { preview = true })
        Check(Equal(consumer:Project(previewContext), consumer:Project(c.AccountView:BuildContext(consumer.page))),
            "main and preview have same identities, times, states and native names")
        c.AccountView.frame:Hide()
        Check(c.Entry:ShowEntryPreview(consumer.entryID, nil, "broker") and c.AccountView.frame.preview,
            "actual Core entry opens shared preview shell")
        Check(Equal(c.AccountView.frame.instances[consumer.pageID].r3Rows, consumer:Project(previewContext)),
            "actual rendered hover has same snapshot rows")
        c.Entry:CloseEntryPreview(consumer.entryID, "broker")
        Check(not c.AccountView.frame.preview, "closing entry preview restores normal layout")
        Check(not c.Entry:GetBuiltinBarSettings().enabled, "builtin bar defaults off")
        for mask = 0, 7 do
            local expected = { minimap = mask % 2 == 1, broker = math.floor(mask / 2) % 2 == 1, builtinBar = math.floor(mask / 4) % 2 == 1 }
            for channel, enabled in pairs(expected) do Check(c.Entry:SetEntryChannel(consumer.entryID, channel, enabled), "channel choice accepted") end
            Check(Equal(c.Entry:GetEntryChannels(consumer.entryID), expected), "all eight channel combinations retained")
            c.Entry:SetBuiltinBarEnabled(true); c.Entry:SetBuiltinBarEnabled(false)
            Check(Equal(c.Entry:GetEntryChannels(consumer.entryID), expected), "global bar switch retains choices")
        end
        Check(c.Entry:HandleEntryClick(consumer.entryID, "LeftButton"), "left-click handled by Core")
        c.Entry:HandleEntryClick(consumer.entryID, "LeftButton") -- toggle visible again if it was open
        Check(c.AccountView.activePageID == consumer.pageID, "left-click targets business page")
        Check(c.Entry:HandleEntryClick(consumer.entryID, "RightButton") and c.AccountView.activePageID == "settings", "right-click enters unified settings")
        local content = e.CreateFrame("Frame", nil, e.UIParent); consumer.page.settings.CreateSettingsPanel(content)
        Check(#content.r3Sections == 2, "business settings provide content only")
        c.AccountView:ShowSettings(consumer.pageID); flush()
        Check(c.AccountView.settingsTargetPageID == consumer.pageID and #c:GetRegisteredSettingsPanels() == 0,
            "page-hosted settings use one navigation target, no standalone duplicate")
        c:RegisterAddon("AAA_R3", { requiredAPI = 13 }); c:RegisterAddon("ZZZ_R3", { requiredAPI = 13 })
        for _, owner in ipairs({ "ZZZ_R3", "AAA_R3" }) do
            c:RegisterSettingsPanel(owner, { id = owner, title = owner, CreateSettingsPanel = function() end })
        end
        local panels = c:GetRegisteredSettingsPanels()
        Check(panels[1].addonName == "AAA_R3" and panels[#panels].addonName == "ZZZ_R3", "workbench sorts technical owner names")

        -- Over 20 admitted characters: main keeps all; ordinary preview is the first 20 of the same ordering.
        for n = 1, 23 do local id = string.format("Player-R3-Many%02d", n)
            Observe(id, n % 2 == 0 and "RealmA" or "RealmB", "HUNTER", n + 20)
            consumer.snapshots[id] = Groups(n + 1000)
        end
        Observe("Player-R3-Current", "RealmA", "DRUID", 66, "Current")
        c.AccountView:SetPageScope(consumer.pageID, "all")
        context = c.AccountView:BuildContext(consumer.page)
        previewContext = c.AccountView:BuildContext(consumer.page, { preview = true })
        Check(#context.characters == 25 and #previewContext.characters == 20, "main complete; default preview limited to 20")
        for n, row in ipairs(consumer:Project(previewContext)) do Check(Equal(row, consumer:Project(context)[n]), "preview is same ordered projection") end
        c.AccountView:ShowPage(consumer.pageID); flush()
        Check(not consumer.page.lastError and c.AccountView.frame:GetWidth() <= e.UIParent:GetWidth()
            and c.AccountView.frame:GetHeight() <= e.UIParent:GetHeight(), "Core bounds real consumer page to safe screen")
        local id = "Player-R3-1"
        local impact = c.CharacterCleanup:GetImpact(id)
        Check(impact.owners[consumer.owner].hasData == true, "Core cleanup discovers owner snapshot via callback")
        local other = consumer:ReadSnapshot("Player-R3-2")
        local result = c.CharacterCleanup:Delete(id)
        Check(result and result.owners[consumer.owner].status == "deleted" and consumer:ReadSnapshot(id) == nil,
            "deletion routed to registered owner")
        Check(c.Characters:Get(id) == nil and Equal(other, consumer:ReadSnapshot("Player-R3-2")), "only selected GUID deleted across same names")
        Check(consumer.lastDeletion.replay == false and type(consumer.lastDeletion.deletionID) == "string", "cleanup v2 context passed intact")
        Check(not c.CharacterCleanup:Delete("Player-R3-Current"), "current character deletion blocked")
        consumer.failDelete = true; result = c.CharacterCleanup:Delete("Player-R3-2")
        Check(result.owners[consumer.owner].status == "pending" and consumer:ReadSnapshot("Player-R3-2") ~= nil,
            "owner failure retains business data and pending cleanup")
        consumer.failDelete = false
        local processed, failed = c.CharacterCleanup:RetryPending(consumer.owner)
        Check(processed >= 1 and failed == 0 and consumer:ReadSnapshot("Player-R3-2") == nil
            and consumer.lastDeletion.replay == true, "pending replay succeeds with context")

        local beforeStop = consumer.notifications
        consumer:Stop(); consumer:Stop(); flush()
        Check(not c.Entry:GetEntryAvailability(consumer.entryID) and not c.Registry:GetResource("page", consumer.pageID), "stop releases page and disables entry")
        Check(#c:GetRegisteredSettingsPanels() == 2 and Count(c.CharacterCleanup:GetOwners()) == 1, "settings removed, cleanup owner retains session lifetime")
        c.Events:FireIsolated("ACCOUNT_VIEW_CHARACTERS_CHANGED", { reason = "visibility" })
        c.Events:FireIsolated("CORE_READY")
        Check(consumer.notifications == beforeStop and not consumer.active, "stop removes change and ready listeners")
        Check(consumer:Watch() and consumer.starts == 2 and Count(c.CharacterCleanup:GetOwners()) == 1, "reactivation uses same session owner")
        c.AccountView:ShowPage(consumer.pageID); flush()
        Check(consumer.creates == 2 and not consumer.page.lastError, "re-registration creates a fresh page instance")
        consumer:Stop()
        -- Language selection is session-stable, switching only after a fresh boot using synthetic Core store.
        Check(c.Locale:SetPreference(mode[2]), "language preference accepted")
        local storeCopy = c.Defaults:Copy(c.Database:GetDB())
        local re, rc, refire, reflush = Boot(target, storeCopy, nil, function(env) env.GetLocale = function() return mode[1] end end)
        refire("ADDON_LOADED"); refire("PLAYER_LOGIN"); reflush()
        local again = Consumer.New(function() return rc end); again:Watch()
        Check(rc.Locale:GetLanguage() == mode[3] and #rc.Locale:GetMissingEnglish(again.owner) == 0, "owner resources in automatic/manual language after synthetic restart")
        local message = rc.Locale:Get(again.owner, "UNKNOWN")
        Check(message ~= "" and rc.Locale:Get(again.owner, "TIME", "123"):find("123", 1, true), "unknown preservation and timestamp labels localized")
        Check(rc.Characters:Get("Player-R3-Many01", { identityOnly = true }) ~= nil, "synthetic store reload preserves offline directory")
        again:Stop()
    end
end
-- An owner absent during deletion must replay tombstones when it next registers.
for _, target in ipairs({ "Retail", "Mists", "Forever" }) do
    local e, c, fire, flush = Boot(target)
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN"); flush()
    local consumer = Consumer.New(function() return c end); consumer:Watch()
    e.TEST_GUID = "Player-R3-LateOwner"; fire("PLAYER_ENTERING_WORLD"); flush()
    e.TEST_GUID = "Player-R3-1"; fire("PLAYER_ENTERING_WORLD"); flush()
    local coreStore = c.Defaults:Copy(c.Database:GetDB())
    local re, rc, refire, reflush = Boot(target, coreStore)
    refire("ADDON_LOADED"); refire("PLAYER_LOGIN"); reflush()
    Check(rc.CharacterCleanup:GetImpact("Player-R3-LateOwner").owners[consumer.owner].hasData == nil,
        "persisted absent owner reports unknown, not no data")
    local result = rc.CharacterCleanup:Delete("Player-R3-LateOwner")
    Check(result.owners[consumer.owner].status == "pending", "disabled owner stays pending")
    local deletionAt = rc.Database:GetDB().characterDeletionHistory[result.deletionID].deletedAt
    local late = Consumer.New(function() return rc end)
    late.snapshots["Player-R3-LateOwner"] = Groups(deletionAt - 100)
    late.snapshots["Player-R3-LateOwner"].carried.observedAt = deletionAt + 100
    Check(late:Watch() and late.ownerCalls == 1 and late.lastDeletion.replay, "late registration replays exactly once")
    local remaining = late:ReadSnapshot("Player-R3-LateOwner")
    Check(remaining.carried.observedAt == deletionAt + 100 and remaining.stable == nil,
        "owner applies per-group time semantics; fresh group survives old tombstone")
    rc.CharacterCleanup:RetryPending(late.owner)
    Check(late.ownerCalls == 1, "acknowledged tombstone never reapplied")
    Check(rc.Characters:Get("Player-R3-LateOwner") == nil, "business callback never resurrects directory identity")
    late:Stop()
end
print("CoreConsumerR3 Spec passed: " .. checks .. " checks (actual Retail/Mists/Forever manifests; synthetic consumer only, no pet collection or player stores)")
