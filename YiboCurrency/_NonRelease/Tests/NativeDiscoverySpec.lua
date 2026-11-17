_G.YiboCurrency = {}
dofile("YiboCurrency/Common/NativeDiscovery.lua")
local discovery = YiboCurrency.NativeDiscovery
local function check(value, message) assert(value, message) end
local adapter = {}
function adapter:List()
    return { { id = 10, name = "A" }, { id = 20, name = "B" }, { id = 0, name = "invalid" } }, false
end
function adapter:Detail(id)
    if id == 10 then return { id = 10, name = "A", quantity = 0 } end
    if id == 20 then return { id = 20, name = "B", quantity = 4 } end
    error("unavailable")
end
local old = { [30] = { id = 30, name = "historical", discoveredAt = 1, updatedAt = 1 } }
local catalog, values, complete = discovery:Collect(adapter, old, 100)
check(not complete and catalog[10] and catalog[20] and catalog[30], "partial discovery retains historical entries")
check(values[10].quantity == 0 and values[20].quantity == 4 and not values[30], "zero is valid; failure is unknown")
check(old[30].updatedAt == 1 and not old[10], "input catalog remains unchanged")
function adapter:List() return {}, true end
function adapter:Detail() return nil end
local nextCatalog, nextValues, emptyComplete = discovery:Collect(adapter, catalog, 101)
check(emptyComplete and nextCatalog[10] and nextCatalog[30] and not next(nextValues), "empty list retains the directory")
local prior = { [10] = { quantity = 8, observedAt = 50, state = "known" }, [30] = { quantity = 9, observedAt = 1, state = "known" } }
local merged = discovery:MergeSnapshot(prior, { [10] = values[10], [20] = values[20], [30] = { quantity = -1, observedAt = 100, state = "known" } })
check(merged[10].quantity == 0 and merged[20].quantity == 4 and merged[30].quantity == 9, "snapshot merges valid observations only")
check(prior[10].quantity == 8 and prior[20] == nil, "snapshot input is not changed")
local zero, zeroState = discovery:GetValue(merged, values, 10)
local historic, historicState = discovery:GetValue(merged, values, 30)
local missing, missingState = discovery:GetValue(merged, values, 99)
check(zero == 0 and zeroState == "known" and historic == 9 and historicState == "stale"
    and missing == nil and missingState == "unknown", "fresh zero, history and missing remain distinct")
local older = discovery:MergeSnapshot(merged, { [10] = { quantity = 7, observedAt = 2, state = "known" } })
check(older[10].quantity == 0, "old observation does not replace newer snapshot")
local imported = discovery:ImportObserved({}, { first = { [10] = { name = "zero", quantity = 0, observedAt = 10 },
    [11] = { name = "no evidence", observedAt = 10 }, [12] = { name = "", quantity = 5, observedAt = 10 } } }, 100)
check(imported[10] and not imported[11] and not imported[12], "migration only imports valid observed entries")
local history = discovery:ImportObserved({}, {
    first = { [10] = { name = "earlier", quantity = 1, observedAt = 5 } },
    second = { [10] = { name = "later", quantity = 0, observedAt = 20 } },
}, 100)
check(history[10].name == "later" and history[10].discoveredAt == 5 and history[10].updatedAt == 20,
    "migration combines multiple characters regardless of iteration order")
check(discovery:ImportObserved(history, {}, 101)[10].name == "later", "migration is idempotent")
dofile("YiboCurrency/Common/NativeAPI.lua")
local api = YiboCurrency.NativeAPI:New({
    listSize = function() return 3 end,
    listInfo = function(i)
        if i == 1 then return { name = "group", isHeader = true } end
        if i == 2 then return { name = "modern", iconFileID = 4, isHeader = false } end
        return "legacy", false, false, false, false, 0, 7
    end,
    listLink = function(i) return "|Hcurrency:" .. (i == 2 and 10 or 20) .. ":0|h" end,
    detail = function(id) return { name = id == 10 and "modern" or "legacy", quantity = 0, iconFileID = 4 } end,
})
local rows, apiComplete = api:List()
check(apiComplete and #rows == 2 and rows[1].id == 10 and rows[2].id == 20 and rows[2].icon == 7, "normalizes list APIs")
local nativeCatalog, nativeValues = discovery:Collect(api, {}, 102)
check(nativeCatalog[10] and nativeValues[20].quantity == 0, "shared API adapter composes with discovery")
api.api.listLink = function() return nil end
local _, missingIDComplete = api:List()
check(not missingIDComplete, "missing ID marks scan partial")
api.api.listSize = function() return 0 end
local empty, emptyOK = api:List()
check(emptyOK and #empty == 0, "empty list is a successful observation")
local legacyAPI = YiboCurrency.NativeAPI:ForClient({
    GetCurrencyListSize = function() return 1 end,
    GetCurrencyListInfo = function() return "legacy", false, false, false, false, 0, 7 end,
    GetCurrencyListLink = function() return "|Hcurrency:20:0|h" end,
    GetCurrencyInfo = function() return "legacy", 0, 7 end,
})
local legacyRows, legacyOK = legacyAPI:List()
check(legacyOK and legacyRows[1].id == 20 and legacyAPI:Detail(20).quantity == 0,
    "client adapter resolves legacy API without inventing currencies")
local modernAPI = YiboCurrency.NativeAPI:ForClient({ C_CurrencyInfo = {
    GetCurrencyInfo = function(id) return { name = "native", quantity = 1, currencyID = id + 1 } end,
} })
check(modernAPI:Detail(10) == nil, "nonzero mismatched detail identity is rejected")
modernAPI.api.detail = function() return { name = "native", quantity = 0, currencyID = 0 } end
check(modernAPI:Detail(10).quantity == 0, "observed MoP zero identity is accepted")
dofile("YiboCurrency/Common/NativeRefresh.lua")
local pending, scans, identity = {}, 0, "character-a"
local hooks = {}
function hooks:After(_, fn) pending[#pending + 1] = fn end
function hooks:Identity() return identity end
function hooks:Scan(id) check(id == identity, "identity supplied"); scans = scans + 1; return scans >= 3 end
local refresh = YiboCurrency.NativeRefresh:New(hooks)
refresh:Request(); refresh:Request()
check(#pending == 1, "requests coalesce")
while #pending > 0 do table.remove(pending, 1)() end
check(scans == 3, "incomplete scans retry finitely")
refresh:Request(); refresh:Cancel()
while #pending > 0 do table.remove(pending, 1)() end
check(scans == 3, "cancel invalidates queued scan")
function hooks:Scan() scans = scans + 1; return false end
refresh:Request()
while #pending > 0 do table.remove(pending, 1)() end
check(scans == 7, "retry count is bounded")
dofile("YiboCurrency/Common/NativeSession.lua")
local currentID, stored, commitCount = "a", { directory = {}, snapshot = {} }, 0
local sessionHooks = { Adapter = {
    List = function() return { { id = 10, name = "native" } }, true end,
    Detail = function(_, id) return { id = id, name = "native", quantity = 0 } end,
} }
function sessionHooks:Identity() return currentID end
function sessionHooks:IsReady() return true end
function sessionHooks:Load() return stored end
function sessionHooks:Now() return 200 end
function sessionHooks:Commit(id, directory, snapshot)
    if id ~= currentID then return false end
    commitCount = commitCount + 1; stored = { directory = directory, snapshot = snapshot }; return true
end
local session = YiboCurrency.NativeSession:New(sessionHooks)
check(session:Scan("a") and commitCount == 1, "session commits valid scan")
local quantity, state = session:Value("a", stored.snapshot, 10)
check(quantity == 0 and state == "known", "current session confirms zero")
local _, otherState = session:Value("b", stored.snapshot, 10)
check(otherState == "stale", "observations are bound to a character")
function sessionHooks.Adapter:Detail(id) currentID = "b"; return { id = id, name = "native", quantity = 3 } end
local switched, reason = session:Scan("a")
check(not switched and reason == "identity-changed" and commitCount == 1 and stored.snapshot[10].quantity == 0,
    "identity change cannot commit staged data")
local _, afterSwitch = session:Value("a", stored.snapshot, 10)
check(afterSwitch == "stale", "failed scan invalidates current observation")
dofile("YiboCurrency/Common/NativeStore.lua")
local dbA, dbB, storeIdentity, ready = { settings = { keep = true } }, {}, "a", true
local store = YiboCurrency.NativeStore:New(dbA, function() return storeIdentity end, function() return ready end)
check(store and store:Load("a") and not dbA.nativeDiscovery, "load does not write the database")
check(store:Commit("a", { [10] = { id = 10, name = "native" } }, { [10] = { quantity = 0, observedAt = 200 } }),
    "new directory and character snapshot commit together")
local loaded = store:Load("a"); loaded.directory[10].name = "changed"
check(dbA.nativeDiscovery.directory[10].name == "native" and dbA.settings.keep and not dbB.nativeDiscovery,
    "returned data is copied and target databases remain independent")
storeIdentity = "b"
check(not store:Commit("a", {}, {}) and dbA.nativeDiscovery.characters.a[10].quantity == 0,
    "wrong-character write is rejected")
check(store:DeleteCharacter("a") and dbA.nativeDiscovery.directory[10] and not dbA.nativeDiscovery.characters.a,
    "removing a character preserves the account directory")
check(not YiboCurrency.NativeStore:New({ nativeDiscovery = { schema = 99 } }, function() return "a" end,
    function() return true end), "unknown native schema is not overwritten")
dofile("YiboCurrency/Mists/NativeMigration.lua")
local legacy = { characters = {
    a = { native = { observedAt = 50, data = { currencies = {
        [10] = { name = "zero", quantity = 0, state = "known", iconFileID = 12 },
        [11] = { name = "unknown", state = "unavailable" },
    } } } },
    b = { native = { observedAt = 60, data = { currencies = {
        [10] = { name = "zero", quantity = 7, state = "stale" },
    } } } },
} }
local migrated, characterValues = YiboCurrency.NativeMigration:Stage(legacy, {}, 100)
check(migrated[10] and not migrated[11] and characterValues.a[10].quantity == 0
    and characterValues.b[10].quantity == 7 and not characterValues.a[11], "Mists migrates only observed facts per character")
check(legacy.characters.a.native.data.currencies[10].quantity == 0 and not legacy.nativeDiscovery,
    "Mists migration staging does not mutate legacy state")
storeIdentity = "a"
check(store:Commit("a", { [10] = { id = 10, name = "current" } },
    { [10] = { quantity = 9, observedAt = 90, state = "known" } }), "current native data can be written")
check(store:Import("a", migrated, characterValues) and store:Import("a", migrated, characterValues), "migration can be repeated")
check(dbA.nativeDiscovery.characters.a[10].quantity == 9 and dbA.nativeDiscovery.characters.b[10].quantity == 7
    and dbA.nativeDiscovery.directory[10].name == "current", "migration preserves newer data and existing directory metadata")
check(store:Import("a", {}, { a = { [10] = { quantity = 1, observedAt = 90, state = "known" } } })
    and dbA.nativeDiscovery.characters.a[10].quantity == 9, "equal-time import cannot overwrite an existing observation")
storeIdentity = "b"
check(not store:Import("a", {}, {}) and dbA.nativeDiscovery.characters.a[10].quantity == 9,
    "migration requires current identity")
function YiboCurrency:T(key) return key end
dofile("YiboCurrency/Common/Catalog.lua")
local defaults = {
    { id = "money", titleKey = "gold", source = "money" },
    { id = "currency:77", currencyID = 77, source = "currency" },
    { id = "item:10", itemID = 10, title = "token", source = "item" },
}
local custom = { { itemID = 10, title = "duplicate" }, { itemID = 20, title = "custom" } }
local catalogView = YiboCurrency:BuildDiscoveredCatalog(defaults, {
    [77] = { id = 77, name = "native 77" }, [10] = { id = 10, name = "native 10" },
}, custom)
check(#catalogView == 5 and catalogView[1].id == "money" and catalogView[2].id == "item:10"
    and catalogView[3].id == "currency:10" and catalogView[4].id == "currency:77"
    and catalogView[5].id == "item:20", "native ID and item ID stay separate; items are deduplicated")
check(catalogView[3].totalAllowed == false, "unknown native scope is not summed")
local preferences = { ["currency:10"] = false }
local selected = { ["currency:10"] = true, ["currency:77"] = false }
local fields = YiboCurrency:BuildDisplayFields(catalogView, preferences, selected)
check(fields[1].title == "gold" and not fields[3].defaultVisible and fields[3].previewVisible
    and not fields[4].previewVisible and preferences["currency:10"] == false,
    "field projection preserves independent choices")
print("NativeDiscoverySpec passed")
