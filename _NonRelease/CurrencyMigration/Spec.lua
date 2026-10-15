dofile("_NonRelease/CurrencyMigration/CoreSpec.lua")
local checks = 0
local function Check(value, message) checks = checks + 1; assert(value, message) end
local Core, now = YiboCore, 1000
GetServerTime = function() return now end
Core.VERSION, Core._private.initialized = "1.12.4", true
Core.CharacterCleanup.MAX_HISTORY = 100
local db = Core.Database:GetDB()
local function Legacy()
    return { economy = { schemaVersion = 1, state = "known", updatedAt = 123, revision = 17,
        data = { money = 100000, currencies = { [392] = { quantity = 90, maxWeeklyQuantity = 100, weeklyQuantity = 67 } } } },
        ["economy-items"] = { schemaVersion = 1, state = "known", updatedAt = 124, revision = 8,
            data = { items = { [123] = { carried = 3, bank = 100, total = 103, bankKnown = true }, [456] = { total = 55 } } } } }
end
local function Role(id, domains)
    db.characters.byID[id] = { id = id, name = id, realm = "Realm", domains = domains or {} }
end
Role("Current"); Role("Offline", Legacy())
dofile("YiboCore/Data/DomainStore.lua")
YiboCurrencyDB = { version = 4, settings = { customItems = {}, previewColumns = {} } }
dofile("YiboCurrency/Bootstrap.lua")
dofile("YiboCurrency/Locales/zhCN.lua")
dofile("YiboCurrency/Locales/enUS.lua")
dofile("YiboCurrency/Store.lua")
dofile("YiboCurrency/Migration.lua")
dofile("YiboCurrency/Scanner.lua")
dofile("YiboCurrency/Data.lua")
dofile("YiboCurrency/VaultIntegration.lua")
dofile("YiboCurrency/Projection.lua")
dofile("YiboCurrency/ArchiveProvider.lua")
dofile("YiboCurrency/GoalTargets.lua")
local Addon = YiboCurrency
Addon.NotifyChanged = function() end
Addon.Catalog = { { id = "money", source = "money", title = "Gold" },
    { id = "currency:392", currencyID = 392, source = "currency", title = "Honor" },
    { id = "item:123", itemID = 123, source = "item", title = "Token", verified = "implemented" } }
Core:RegisterAddon(Addon.NAME, { requiredAPI = 13 })
Check(Addon.Migration:CheckCoreHandoff(), "compatible handoff accepts inactive Core collectors")
Core.VERSION = "1.12.3"
Check(not Addon.Migration:CheckCoreHandoff(), "old Core is rejected")
Core.VERSION = "1.12.4"
local getDefinitions = Core.DataDomains.GetDefinitions
Core.DataDomains.GetDefinitions = function() return { { id = "economy" } } end
Check(not Addon.Migration:CheckCoreHandoff(), "active collector is rejected even with a high version")
Core.DataDomains.GetDefinitions = getDefinitions
Check(Addon.Store:Initialize() and Addon.Store:RegisterLifecycle(), "store and cleanup register")
local source = Core.Defaults:Copy(db.characters.byID.Offline.domains)
Check(Addon.Migration:ImportCharacter("Offline"), "first role imports both snapshots")
local native = Addon.Store:Get("Offline", "native")
Check(native.state == "stale" and native.observedAt == 123 and native.provenance.sourceRevision == 17, "legacy time and provenance preserved")
Check(native.data.currencies[392].weeklyQuantity == nil and native.data.currencies[392].weeklyState == "unknown", "imported week progress is unknown")
local tokens = Addon.Store:Get("Offline", "carriedTokens")
Check(tokens.data.items[123].carried == 3 and tokens.data.items[456] == nil and tokens.data.items[123].bank == nil, "only reliable carried values import")
Check(Addon.Store.Equal(source, db.characters.byID.Offline.domains), "all legacy Core values remain unchanged")
local importedAt = Addon.Store.db.migration.byCharacter.Offline.importedAt
Check(not Addon.Migration:ImportCharacter("Offline") and Addon.Store.db.migration.byCharacter.Offline.importedAt == importedAt, "repeat import does not replace values or metadata")
local value, state = Addon:GetValue({ id = "Offline" }, { source = "money" })
Check(value.quantity == 100000 and state == "historical", "imported gold displays as historical")
local result = Addon.GoalTargets:Evaluate({ goals = { { id = "G", intent = { objectID = "currency:392", scope = { characterID = "Offline" }, conditions = { quantity = 1, mode = "maintain" } } } } })
Check(result.evaluations.G.task.readiness == "unknown", "historical balance cannot prove goal completion")
-- Validate per-role transactions and failure retry.
Role("Bad", Legacy()); db.characters.byID.Bad.domains["economy-items"].schemaVersion = 99
Check(Addon.Migration:ImportCharacter("Bad") == nil and Addon.Store.db.characters.Bad == nil, "a malformed counterpart cannot leave half a role committed")
db.characters.byID.Bad.domains["economy-items"].schemaVersion = 1
Check(Addon.Migration:ImportCharacter("Bad"), "failed role can retry after repair")
Check(Addon.Store:Commit("Bad", "native", { moneyCopper = 999, moneyState = "known", currencies = {} }, "known"), "new local data commits")
Check(not Addon.Migration:ImportCharacter("Bad") and Addon.Store:Get("Bad", "native").data.moneyCopper == 999, "legacy retry never replaces local success")
-- Actual scanner: counts bags only, reads stable currency ID and records zero.
local currencyReads, bagReads = 0, 0
GetMoney = function() return 200000 end
C_CurrencyInfo = { GetCurrencyInfo = function(id) currencyReads = currencyReads + 1; return { name = "Honor", quantity = 0, weeklyQuantity = 5, maxWeeklyQuantity = 100 } end }
C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return 5000 - now end }
C_Container = { GetContainerNumSlots = function(bag) Check(bag <= 4, "fallback never scans banks"); return bag == 0 and 1 or 0 end,
    GetContainerItemInfo = function() bagReads = bagReads + 1; return { itemID = 123, stackCount = 5 } end }
Check(Addon.Scanner:Scan(true, true), "scanner owns native and token collection")
value, state = Addon:GetValue({ id = "Current" }, { source = "currency", currencyID = 392 })
Check(value.quantity == 0 and state == "known", "readable zero is known")
local revision = Addon.Store.db.characters.Current.native.revision
now = now + 1
Addon.Scanner:Scan(true, true)
native = Addon.Store:Get("Current", "native")
Check(native.observedAt == now and native.revision == revision, "unchanged observations refresh time without raising fact revision")
now = 5000
native = Addon.Store:Get("Current", "native")
Check(native.data.currencies[392].weeklyQuantity == nil and native.data.currencies[392].quantity == 0, "weekly reset expires progress without zeroing held balance")
now = 1001
local oldGetMoney, oldCurrency = GetMoney, C_CurrencyInfo.GetCurrencyInfo
GetMoney = function() error("temporary") end; C_CurrencyInfo.GetCurrencyInfo = function() error("temporary") end
now = 1002; Addon.Scanner:Scan(true, false)
Check(Addon.Store:Get("Current", "native").observedAt == 1001, "failed reads cannot mint a successful observation time")
value, state = Addon:GetValue({ id = "Current" }, { source = "money" })
Check(value == nil and state == "unavailable", "API failure is not known zero")
GetMoney, C_CurrencyInfo.GetCurrencyInfo = oldGetMoney, oldCurrency
Addon.Scanner:Scan(true, false)
-- Source selection is atomic, including provider known-zero and partial coverage.
Addon.GetVaultItemBalance = function() return { equipped = 1, bagsKnown = false, bankKnown = false, equipmentKnown = true } end
value, state = Addon:GetValue({ id = "Current" }, Addon.Catalog[3])
Check(value.total == 1 and value.carried == nil and state == "bank" and value.sourceID == "vault.items", "partial Vault never borrows the five local carried tokens")
Addon.GetVaultItemBalance = function() return { carried = 0, bank = 0, equipped = 0, bagsKnown = true, bankKnown = true, equipmentKnown = true } end
value, state = Addon:GetValue({ id = "Current" }, Addon.Catalog[3])
Check(value.total == 0 and state == "known", "fully scanned Vault zero wins over local stock")
Addon.GetVaultItemBalance = function() return nil end
value, state = Addon:GetValue({ id = "Current" }, Addon.Catalog[3])
Check(value.total == 5 and state == "bank" and value.sourceID == "currency.carried", "missing provider uses local carried observation only")
Addon.GetVaultPersonalCounts = function() return nil end
local projection = Addon:GetCurrencyProjection({}, { { id = "Current" }, { id = "Offline" } }, Addon.Catalog)
Check(projection.totals["item:123"].quantity == 8 and not projection.totals["item:123"].complete, "main and hover include historical values with incomplete total")
-- Register and consume the real archive provider.
Check(Addon.ArchiveProvider:Initialize(), "Currency archive provider registers")
local fields = Core.Fields:GetByConsumer("character-archive")
local money
for _, field in ipairs(fields) do if field.id == "character.money" then money = field end end
local archive = Core.ArchiveFields:Read({ { id = "Current" }, { id = "Offline" } }, fields)
Check(Core.Fields:FormatValue({ id = "Current" }, money, archive) == "20g", "Core archive consumes Currency copper")
Check(Core.Fields:FormatValue({ id = "Offline" }, money, archive) == "10g~", "Core archive preserves historical state")
-- Coalescing: a burst of bag events performs one token scan, no currency query.
local timers = {}
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay = delay, callback = callback } end }
local function FlushImmediate()
    local pending = timers; timers = {}
    for _, timer in ipairs(pending) do if timer.delay == 0 then timer.callback() else timers[#timers + 1] = timer end end
end
local beforeCurrency, beforeBags = currencyReads, bagReads
for _ = 1, 100 do Addon.Scanner:Request("BAG_UPDATE_DELAYED") end
FlushImmediate()
Check(currencyReads == beforeCurrency and bagReads == beforeBags + 1, "bag event burst coalesces without querying currencies")
-- Tombstones and cold-start deletion.
Check(Core.CharacterCleanup:Delete("Offline"), "explicit Core cleanup coordinates owner deletion")
Check(Addon.Store.db.characters.Offline == nil and Addon.Store.db.migration.blocked.Offline, "owner deletes only its role snapshots and blocks import")
Role("Offline", source)
Check(not Addon.Migration:ImportCharacter("Offline"), "directory recreation cannot resurrect frozen snapshots")
Check(Addon.Store:Commit("Offline", "native", { moneyCopper = 42, moneyState = "known", currencies = {} }, "known"), "real new observations are allowed after deletion")
Role("Pending")
Addon.Store:Commit("Pending", "native", { moneyCopper = 11, moneyState = "known", currencies = {} }, "known")
Core.CharacterCleanup._owners.YiboCurrency = nil
local deletion = assert(Core.CharacterCleanup:Delete("Pending"))
Check(deletion.owners.YiboCurrency.status == "pending" and Addon.Store.db.characters.Pending, "disabled owner is not directly accessed")
dofile("YiboCurrency/Store.lua")
Addon.Store:Initialize(); Addon.Store:RegisterLifecycle()
Check(Addon.Store.db.characters.Pending == nil, "next load retries pending cleanup")
-- ID promotion only through Core aliases; local data wins and conflicts are retained.
Role("NewGUID")
db.characters.aliases["Old-Realm"] = "NewGUID"
Addon.Store.db.characters["legacy:Old-Realm"] = { native = Addon.Store.Copy(Addon.Store.db.characters.Current.native), identityAliases = { ["Old-Realm"] = true } }
Addon.Store:ReconcileIDs()
Check(Addon.Store.db.characters["legacy:Old-Realm"] == nil and Addon.Store.db.characters.NewGUID, "late-loaded legacy identity reconciles through Core")
Core.Events:Fire("CHARACTER_ID_CHANGED", "NewGUID", "NewGUID")
Check(not Addon.Store.db.migration.blocked.NewGUID, "repeat identity event does not become deletion")
Check(not Addon.Store:Remap("Current", "NewGUID"), "two real GUIDs are never merged by display identity")
now = 100000
value, state = Addon:GetValue({ id = "Current" }, { source = "money" })
Check(value.quantity == 200000 and state == "historical", "old local balances expire into historical state")
print("Currency MigrationSpec: " .. checks .. " checks passed")
