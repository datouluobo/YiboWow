dofile("_NonRelease/CurrencyMigration/Spec.lua")
local Addon, Core, checks, now = YiboCurrency, YiboCore, 0, 200000
local function Check(value, message) checks = checks + 1; assert(value, message) end
GetServerTime = function() return now end
C_Timer = nil
local db = Core.Database:GetDB()
local function Role(id, domains) db.characters.byID[id] = { id = id, name = id, realm = "Realm", domains = domains or {} } end
local function Source()
    return { economy = { schemaVersion = 1, state = "known", updatedAt = 123, revision = 1, data = { money = 7, currencies = {} } },
        ["economy-items"] = { schemaVersion = 1, state = "known", updatedAt = 124, revision = 1, data = { items = { [123] = { carried = 3 } } } } }
end
-- Error placeholders are recoverable independently per data kind.
Role("Placeholder", Source())
Addon.Store:Commit("Placeholder", "native", { moneyCopper = 99, moneyState = "known", currencies = {} }, "known")
Addon.Store:Commit("Placeholder", "carriedTokens", nil, "error")
Check(Addon.Migration:ImportCharacter("Placeholder"), "token placeholder can recover even with a valid native snapshot")
Check(Addon.Store:Get("Placeholder", "native").data.moneyCopper == 99 and Addon.Store:Get("Placeholder", "carriedTokens").data.items[123].carried == 3, "recovery preserves successful local counterpart")
local records = Addon.Store.db.characters
Addon.Store.db.migration.byCharacter.Placeholder = { status = "imported" }
records.Placeholder.carriedTokens = nil
Check(Addon.Migration:ImportCharacter("Placeholder"), "missing data can recover despite old completion metadata")
Role("NativePlaceholder", Source())
Addon.Store:Commit("NativePlaceholder", "native", { currencies = { [392] = { state = "error" } }, moneyState = "error" }, "unavailable")
Check(Addon.Migration:ImportCharacter("NativePlaceholder") and Addon.Store:Get("NativePlaceholder", "native").data.moneyCopper == 7,
    "unsupported-only error cells do not block legacy recovery")
Role("Invalid", Source()); db.characters.byID.Invalid.domains.economy.data.money = -1
Check(Addon.Migration:ImportCharacter("Invalid") == nil and not records.Invalid, "negative legacy values fail without committing")
db.characters.byID.Invalid.domains.economy.data.money = 0
Check(Addon.Migration:ImportCharacter("Invalid"), "known legacy zero can retry safely")
local sourceBefore = Core.Defaults:Copy(db.characters.byID.Invalid.domains)
local snapshot = Addon.Store:Get("Invalid", "native"); snapshot.data.moneyCopper = 999
Check(records.Invalid.native.data.moneyCopper == 0 and Addon.Store.Equal(sourceBefore, db.characters.byID.Invalid.domains), "returned snapshots cannot mutate new or old storage")
-- Unsupported storage is preserved, never reset or downgraded.
local saved, store = YiboCurrencyDB, Addon.Store
YiboCurrencyDB = { version = 999, dataSchemaVersion = 999, marker = "keep" }
dofile("YiboCurrency/Store.lua")
Check(not Addon.Store:Initialize() and YiboCurrencyDB.marker == "keep" and YiboCurrencyDB.version == 999, "future storage stops without destructive reset")
YiboCurrencyDB, Addon.Store = saved, store
-- Replayed old deletions preserve newer local observations, but explicit delete always clears.
Role("Recreated")
Addon.Store:Commit("Recreated", "native", { moneyCopper = 10, moneyState = "known", currencies = {} }, "known")
Addon.Store:Commit("Recreated", "carriedTokens", { items = { [123] = { carried = 5 } } }, "partial")
Core.CharacterCleanup._owners.YiboCurrency = nil
Check(Core.CharacterCleanup:Delete("Recreated").owners.YiboCurrency.status == "pending", "disabled owner leaves a replayable tombstone")
now = now + 10; Role("Recreated")
Addon.Store:Commit("Recreated", "native", { moneyCopper = 77, moneyState = "known", currencies = {} }, "known")
dofile("YiboCurrency/Store.lua"); Addon.Store:Initialize(); Addon.Store:RegisterLifecycle()
Check(Addon.Store:Get("Recreated", "native").data.moneyCopper == 77, "historical replay preserves a newer successful local observation")
Check(not Addon.Store:Get("Recreated", "carriedTokens"), "same replay removes the older token snapshot")
Role("FutureTimestamp")
Addon.Store:Commit("FutureTimestamp", "native", { moneyCopper = 1, moneyState = "known", currencies = {} }, "known")
Addon.Store.db.characters.FutureTimestamp.native.observedAt = now + 999
Check(Core.CharacterCleanup:Delete("FutureTimestamp") and not Addon.Store.db.characters.FutureTimestamp, "explicit deletion cannot be bypassed by a future timestamp")
Check(not Core.CharacterCleanup:Delete("Current") and Addon.Store.db.characters.Current, "current role remains protected")
-- Core aliases repair legacy IDs, never two GUIDs; ties remain uncertain.
Role("Target")
Addon.Store:Commit("Target", "native", { moneyCopper = 999, moneyState = "known", currencies = {} }, "known")
local old = Addon.Store.Copy(Addon.Store.db.characters.Target.native)
old.data.moneyCopper, old.provenance.kind = 1, "core-import"
Addon.Store.db.characters["legacy:Old"] = { native = old, identityAliases = { ["Old-Realm"] = true } }
Check(Addon.Store:Remap("legacy:Old", "Target") and Addon.Store:Get("Target", "native").data.moneyCopper == 999, "local target wins over imported legacy ID")
Check(next(Addon.Store.db.identityConflicts) ~= nil, "losing snapshot is retained as diagnostic evidence")
old = Addon.Store.Copy(Addon.Store.db.characters.Target.native); old.data.moneyCopper = 2
Addon.Store.db.characters["legacy:Tie"] = { native = old, identityAliases = {} }
Addon.Store:Remap("legacy:Tie", "Target")
local _, state = Addon:GetValue({ id = "Target" }, { source = "money" })
Check(state == "historical", "ambiguous equal-time local conflict cannot prove a goal")
Core.CharacterCleanup:Delete("Target")
local targetConflict = false
for _, conflict in pairs(Addon.Store.db.identityConflicts) do if conflict.newID == "Target" then targetConflict = true end end
Check(not targetConflict, "explicit cleanup removes owned diagnostic snapshots too")
Role("EmptyTarget", Source())
Addon.Migration:ImportCharacter("EmptyTarget")
Addon.Store.db.characters["legacy:Empty"] = { native = { state = "error", observedAt = now, revision = 1,
    data = { currencies = {} }, provenance = { kind = "client" } }, identityAliases = {} }
Addon.Store:Remap("legacy:Empty", "EmptyTarget")
Check(Addon.Store:Get("EmptyTarget", "native").data.moneyCopper == 7, "empty local placeholder cannot displace useful imported evidence")
Role("legacy:Restored", Source()); db.characters.aliases["Old-Realm"] = "legacy:Restored"
Addon.Store.db.migration.blockedAliases["Old-Realm"] = true
Check(not Addon.Migration:ImportCharacter("legacy:Restored"), "deleted legacy alias cannot import under a replacement fallback ID")
Role("DifferentGUID", Source()); db.characters.aliases["Old-Realm"] = "DifferentGUID"
Check(Addon.Migration:ImportCharacter("DifferentGUID"), "reused display name does not block an unrelated real GUID")
-- Vault-only role admission consumes the public row, never its database.
Role("VaultOnly")
local calls = 0
Addon.GetVaultPersonalCounts = function(_, characters)
    calls = calls + 1
    local rows = {}
    for _, c in ipairs(characters) do rows[c.id] = { coverage = { bags = { hasSnapshot = c.id == "VaultOnly" }, bank = { hasSnapshot = false } }, items = {} } end
    return { characters = rows }
end
local admitted = Addon:GetEligibleCurrencyCharacters({ { id = "Current" }, { id = "VaultOnly" }, { id = "NoData" } })
Check(#admitted == 2 and admitted[2].id == "VaultOnly" and calls == 1, "eligible roster batches provider admission and excludes unobserved roles")
-- Transient currency failure retries even when money succeeds; bounded retries.
local timers, reads = {}, 0
C_Timer = { After = function(delay, callback) timers[#timers + 1] = { delay, callback } end }
GetMoney = function() return 1000 end
C_CurrencyInfo.GetCurrencyInfo = function() reads = reads + 1; error("temporary currency failure") end
Addon.Scanner.queued, Addon.Scanner.pendingNative, Addon.Scanner.pendingTokens = false, nil, nil
Addon.Scanner:Request("PLAYER_MONEY")
for _ = 1, 20 do
    local pending = timers; timers = {}
    local ran = false
    for _, timer in ipairs(pending) do if timer[1] <= 1 then timer[2](); ran = true else timers[#timers + 1] = timer end end
    if not ran then break end
end
Check(reads == 4 and Addon.Scanner.retries == 3, "currency API retries are bounded independently of money availability")
local currency = Addon.Store:Get("Current", "native").data.currencies[392]
Check(currency.state == "error" and currency.quantity == 0, "failed currency API preserves prior count without claiming it is current")
Check(pcall(Addon.GetIcon, Addon, Addon.Catalog[2]), "temporary currency API failure cannot crash icon rendering")
SlashCmdList = {}
strtrim = function(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end
Addon.CoreIntegration = { initialized = true }
local messages = {}
Addon.Print = function(_, message) messages[#messages + 1] = message end
dofile("YiboCurrency/Commands.lua")
SlashCmdList.YCU("status")
Check(#messages == 1 and not messages[1]:find("%%d"), "status diagnostic formats actual migration state")
Check(pcall(SlashCmdList.YCU, "probe") and #messages > 1, "probe remains usable while native APIs fail")
Core.VERSION = "1.12.3"
local imported, _, err = Addon.Migration:ImportAll()
Check(imported == nil and err, "manual retry rechecks the Core handoff")
Core.VERSION = "1.12.4"
for _, capability in ipairs({ "character-archive-providers", "character-cleanup" }) do
    local saved = Core.Capabilities._items[capability]
    Core.Capabilities._items[capability] = capability == "character-cleanup" and 1 or nil
    local result, _, reason = Addon.Migration:ImportAll()
    Check(result == nil and reason, "same release number without " .. capability .. " cannot import")
    Core.Capabilities._items[capability] = saved
end
print("Currency RetentionSpec: " .. checks .. " additional checks passed")
