local Boot = dofile("_NonRelease/CoreForever/Harness.lua")
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Count(values) local n = 0; for _ in pairs(values) do n = n + 1 end; return n end
for _, forever in ipairs({ false, true }) do
    local e, c, fire, flush = Boot(forever)
    Check(c:HasCapability("account-view", 2) and not c:IsInitialized(), "capability existence is not ready")
    local initialized, creates, refreshes, changes = false, 0, 0, 0
    local snapshots = {}
    local function Admitted(character) return character.class == "HUNTER" and snapshots[character.id] ~= nil end
    local definition = { id = "fixture", title = "Fixture", scope = { mode = "realms" }, previewEnabled = true, previewCharacterLimit = false,
        HasCharacterSnapshot = Admitted,
        GetEligibleCharacters = function(characters)
            local result = {}; for _, character in ipairs(characters) do if Admitted(character) then result[#result + 1] = character end end; return result
        end,
        fields = { { id = "quantity", title = "Quantity", defaultVisible = true, defaultPreviewVisible = true } },
        Create = function(parent) creates = creates + 1; parent.fixtureGeneration = creates end,
        Refresh = function(parent, context)
            refreshes = refreshes + 1; parent.rows = {}
            for _, character in ipairs(context.characters) do parent.rows[#parent.rows + 1] = { id = character.id, value = snapshots[character.id].value } end
        end,
    }
    local function Changed() changes = changes + 1 end
    local function Start(core)
        if not core or not core:IsInitialized() or not core:CheckAPIVersion(13)
            or not core:HasCapability("account-surface-budget", 2) then return nil, "core-unavailable" end
        if initialized then return true end
        Check(core:RegisterAddon("FixtureA", { requiredAPI = 13 }) ~= nil, "consumer registers after gate")
        Check(core.AccountView:RegisterPage("FixtureA", definition) ~= nil, "consumer page")
        Check(core.Entry:RegisterBusinessEntry("FixtureA", { id = "fixture", pageID = "fixture", text = "Fixture" }) ~= nil, "consumer entry")
        core.Events:Register("FIXTURE_CHANGED", "FixtureA", Changed)
        initialized = true; return true
    end
    Check(not Start(nil) and not Start(c), "missing and not-ready Core stop consumer")
    c.Events:Register("CORE_READY", "FixtureLifecycle", function() Start(c) end)
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN"); flush()
    Check(initialized and Count(c.AccountView._pages) > 0, "late Core ready coordinates consumer")
    local pageCount = #c.AccountView._pageOrder
    c.Events:FireIsolated("CORE_READY"); Check(Start(c), "repeat ready succeeds through caller coordination")
    Check(#c.AccountView._pageOrder == pageCount and #c.Events._listeners.FIXTURE_CHANGED == 1, "repeat initialization has one page and subscription")
    c.API_VERSION = 12; Check(not Start(c), "old API cannot use ready marker alone"); c.API_VERSION = 13
    c.Capabilities._items["account-surface-budget"] = 1; Check(not Start(c), "old required capability stops consumer"); c.Capabilities._items["account-surface-budget"] = 2
    Check(c.AccountView:RegisterPage("FixtureA", definition) == nil, "duplicate page remains error")
    local firstRegistry = c:RegisterAddon("FixtureB", { requiredAPI = 13, version = "1" })
    Check(c:RegisterAddon("FixtureB", { requiredAPI = 13, version = "2" }) == firstRegistry and firstRegistry.version == "2", "registry repeat updates same entry")
    Check(c:RegisterAddon("TooNew", { requiredAPI = 999 }) == nil, "registry rejects newer API")
    local resource = c:ClaimResource("fixture", "one", "FixtureA")
    Check(c:ClaimResource("fixture", "one", "FixtureA") == resource, "same resource owner is idempotent")
    Check(c:ClaimResource("fixture", "one", "FixtureB") == nil and not c.Registry:ReleaseResource("fixture", "one", "FixtureB"), "resource conflict and foreign release rejected")
    Check(c.Registry:ReleaseResource("fixture", "one", "FixtureA") and not c.Registry:ReleaseResource("fixture", "one", "FixtureA"), "resource release repeated result")
    local settings = { id = "fixture-settings", title = "Fixture", CreateSettingsPanel = function() end }
    local registered = c:RegisterSettingsPanel("FixtureA", settings)
    Check(registered and c:RegisterSettingsPanel("FixtureA", settings) == registered, "settings same owner reuses")
    Check(c:RegisterSettingsPanel("FixtureB", settings) == nil and not c:UnregisterSettingsPanel(settings.id, "FixtureB"), "settings conflict and foreign unregister")
    Check(c:UnregisterSettingsPanel(settings.id, "FixtureA") and not c:UnregisterSettingsPanel(settings.id, "FixtureA"), "settings unregister repeated result")
    local secondSettings = c.Defaults:Copy(settings); secondSettings.id = "fixture-b"
    c:RegisterSettingsPanel("FixtureB", secondSettings); c:RegisterSettingsPanel("FixtureA", settings)
    local orderedSettings = c:GetRegisteredSettingsPanels()
    Check(orderedSettings[1].addonName == "FixtureA" and orderedSettings[2].addonName == "FixtureB", "settings sort by technical name rather than registration order")
    c.Capabilities:Register("fixture-capability", 1); c.Capabilities:Register("fixture-capability", 2); c.Capabilities:Register("fixture-capability", 1)
    Check(c:GetCapabilityVersion("fixture-capability") == 2 and not c:HasCapability("fixture-capability", 3), "capability registration keeps highest version")
    local entryPolicy = c.EntryConfig:Normalize({ coreMode = "none", pageModes = { fixture = "both" } })
    entryPolicy.coreChannels.builtinBar = true
    Check(c.EntryConfig:Normalize(entryPolicy) == entryPolicy and entryPolicy.coreChannels.builtinBar
        and not entryPolicy.coreChannels.broker and entryPolicy.businessChannels.fixture.broker, "entry migration idempotent and retains explicit choices")
    local fired = 0
    local function Listener() fired = fired + 1 end
    c.Events:Register("FIXTURE_EVENT", "FixtureA", Listener); c.Events:Register("FIXTURE_EVENT", "FixtureA", Listener)
    c.Events:Fire("FIXTURE_EVENT"); Check(fired == 1, "event tuple deduplicated")
    c.Events:Register("FIXTURE_EVENT", "FixtureB", Listener); c.Events:Unregister("FIXTURE_EVENT", "FixtureA", Listener)
    c.Events:Fire("FIXTURE_EVENT"); Check(fired == 2, "event unsubscribe owns its tuple")
    c.Events:Unregister("FIXTURE_EVENT", "FixtureB"); Check(not c.Events:HasListeners("FIXTURE_EVENT"), "owner event cleanup")
    c.Events:Register("FIXTURE_ISOLATED", "FixtureA", function(_, value) value.changed = true; error("consumer error") end)
    c.Events:Register("FIXTURE_ISOLATED", "FixtureB", function(_, value) Check(not value.changed, "isolated event payload detached") end)
    local payload = {}; c.Events:FireIsolated("FIXTURE_ISOLATED", payload); Check(not payload.changed, "event leaves original untouched")
    local methods = { Read = function() return snapshots end }
    local service = { name = "fixture.records", kind = "service", providerID = "FixtureA:records", version = { major = 1, minor = 0 }, methods = methods }
    local ref = c.Contracts:Register("FixtureA", service)
    Check(ref and c.Contracts:Register("FixtureA", service) == ref, "same method identities retain contract registration")
    local changed = c.Defaults:Copy(service); changed.methods.Read = function() return {} end
    local _, reason = c.Contracts:Register("FixtureA", changed); Check(reason == "definition-changed", "changed contract is not silently overwritten")
    local foreign = c.Defaults:Copy(service); foreign.providerID = "FixtureB:records"
    _, reason = c.Contracts:Register("FixtureB", foreign); Check(reason == "service-conflict", "cross-owner service conflict")
    Check(c.Contracts:Resolve(service.name, { major = 1, minMinor = 1 }) == nil, "incompatible contract unavailable")
    local descriptor = c.Contracts:Resolve(service.name, { major = 1, minMinor = 0 })
    snapshots.One = { value = 1 }; local response = c.Contracts:Call("FixtureB", descriptor, "Read", {})
    response.One.value = 99; Check(snapshots.One.value == 1, "contract response detached from owner")
    Check(not c.Contracts:Unregister("FixtureB", ref) and c.Contracts:Unregister("FixtureA", ref), "contract owner unregister")
    _, reason = c.Contracts:Call("FixtureB", descriptor, "Read", {}); Check(reason == "unregistered", "retained descriptor invalid after unregister")
    local domain = { id = "fixture-domain", version = 1, Collect = function() return {} end }
    Check(c.DataDomains:Register("FixtureA", domain) ~= nil and c.DataDomains:Register("FixtureA", domain) == nil, "domain duplicates remain error")
    local field = { id = "fixture-field", consumer = "fixture", domain = domain.id, order = 1, Read = function() return 1 end }
    Check(c.Fields:Register("FixtureA", field) ~= nil and c.Fields:Register("FixtureA", field) == nil, "static field duplicates remain error")
    local function Archive(provider)
        return { kind = "provider", name = "character-archive.fields", providerID = provider .. ":archive", version = { major = 1, minor = 0 }, methods = {
            GetFields = function() return { { id = "fixture-money", title = "Money", order = 99, formatKind = "money" } } end,
            Read = function() return { sourceID = provider .. ":archive", characters = {} } end,
        } }
    end
    local ar1 = c.Contracts:Register("FixtureA", Archive("FixtureA"))
    local ar2 = c.Contracts:Register("FixtureB", Archive("FixtureB"))
    Check(#c.ArchiveFields:GetDefinitions({}) == 0, "archive duplicate IDs isolate both providers")
    c.Contracts:Unregister("FixtureB", ar2)
    Check(#c.ArchiveFields:GetDefinitions({}) == 1, "archive provider recovers after conflict removed")
    c.Contracts:Unregister("FixtureA", ar1)
    Check(#c.ArchiveFields:GetDefinitions({}) == 0, "archive provider unregister")
    local db = c.Database:GetDB()
    for i = 1, 24 do
        local id = string.format("Hunter%02d", i)
        db.characters.byID[id] = { id = id, name = id, class = "HUNTER", realm = i % 2 == 0 and "OtherRealm" or "ProbeRealm", level = i, lastSeenAt = i }
        snapshots[id] = { value = i }
    end
    db.characters.byID.NoSnapshot = { id = "NoSnapshot", name = "NoSnapshot", class = "HUNTER", realm = "NoDataRealm" }
    db.characters.byID.Mage = { id = "Mage", name = "Mage", class = "MAGE", realm = "MageRealm" }; snapshots.Mage = { value = 0 }
    c.Characters:InvalidateAllCache()
    local allCalls, originalGetAll = 0, c.Characters.GetAll
    c.Characters.GetAll = function(self, ...) allCalls = allCalls + 1; return originalGetAll(self, ...) end
    local cached = c.Characters:GetAllCached()
    for _ = 1, 100 do Check(c.Characters:GetAllCached() == cached, "read-only roster stable across passes") end
    Check(allCalls == 1, "no repeated full roster copies")
    c.AccountView:SetPageScope("fixture", "all")
    local page = c.AccountView._pages.fixture
    local main, preview = c.AccountView:BuildContext(page), c.AccountView:BuildContext(page, { preview = true })
    Check(#main.characters == 24 and #preview.characters == 24, "cross-realm snapshot admission and explicit all-character preview")
    for index, character in ipairs(main.characters) do Check(character.id == preview.characters[index].id, "same ordering and admitted snapshot in main and preview") end
    c.AccountView:ShowPage("fixture"); flush()
    local originalInstance = c.AccountView.frame.instances.fixture
    Check(#originalInstance.rows == 24 and creates == 1, "real shared page renders once")
    c.AccountView:ShowPage("fixture"); Check(creates == 1 and refreshes >= 2, "refresh reuses current registration instance")
    local mainRows = c.Defaults:Copy(originalInstance.rows)
    c.AccountView.frame:Hide(); c.AccountView:ShowPreview("fixture", nil)
    Check(c.AccountView.frame.preview and #originalInstance.rows == #mainRows, "real hover projection uses same page")
    for index, row in ipairs(originalInstance.rows) do Check(row.id == mainRows[index].id and row.value == mainRows[index].value, "main and hover render identical source values") end
    c.AccountView:HidePreview(); c.AccountView:ShowPage("fixture")
    local countBefore, orderBefore = #cached, {}
    for index, character in ipairs(cached) do orderBefore[index] = character.id end
    c.CharacterSort:Sort(cached, { mode = "name", direction = "desc" }, nil, {})
    Check(#cached == countBefore, "sort preserves roster size")
    for index, character in ipairs(cached) do Check(character.id == orderBefore[index], "sort leaves cached roster order untouched") end
    local sorted = c.CharacterSort:Sort(main.characters, { mode = "level", direction = "desc", pinCurrent = true }, "Hunter01", {})
    Check(sorted[1].id == "Hunter01" and sorted[2].id == "Hunter24", "pin and sort deterministic")
    local columns, pagination = c.AccountView:GetColumnPage("fixture", "wide", main.characters, 4000, 0, 100)
    Check(#columns == 24 and pagination.pages == 1, "wide matrix retains all natural columns")
    columns, pagination = c.AccountView:GetColumnPage("fixture", "narrow", main.characters, 500, 100, 100)
    Check(#columns == 4 and pagination.pages == 6 and columns[1].id == main.characters[pagination.first].id, "safe-boundary pagination shares one character slice")
    c.AccountView:SetPageScope("fixture", "realm:OtherRealm")
    Check(#c.AccountView:BuildContext(page).characters == 12, "realm scope filters same snapshots")
    c.AccountView:SetPageScope("fixture", "all")
    c.AccountView:SetCharacterHidden("Hunter01", true)
    Check(#c.AccountView:BuildContext(page).characters == 23 and #c.AccountView:BuildContext(page, { preview = true }).characters == 23, "hidden admission shared by main and preview")
    Check(c.Characters:GetAllCached() == cached, "view filtering does not invalidate or mutate cached roster")
    c.Events:Unregister("FIXTURE_CHANGED", "FixtureA"); c.Events:Fire("FIXTURE_CHANGED"); Check(changes == 0, "consumer unsubscribes on shutdown")
    c.AccountView.frame:Hide(); c.AccountView:ShowPreview("fixture", nil)
    Check(c.AccountView:UnregisterPage("fixture") and not c.AccountView:UnregisterPage("fixture"), "page unregister repeated result")
    Check(c.AccountView.previewPageID == nil and not c.AccountView.frame.preview, "unregister removes active preview lifecycle")
    Check(not c.Entry:GetEntryAvailability("fixture"), "page unregister disables entry")
    Check(c.AccountView:RegisterPage("FixtureA", definition) ~= nil, "page can register again after explicit removal")
    c.AccountView:ShowPage("fixture"); flush()
    Check(creates == 2 and c.AccountView.frame.instances.fixture ~= originalInstance, "new page registration must create its own instance")
    Check(not c.AccountView:UnregisterPage("overview"), "internal page cannot unregister")
end
print("CoreMetadataContractsR1 ContractsSpec passed: " .. checks .. " checks (real targets, lifecycle, registrations, cached roster and window contracts)")
