local checks = 0
local function Check(value, message) checks = checks + 1; assert(value, message) end
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
GetServerTime = function() return 1000 end
UnitGUID = function() return "Current" end
GetLocale = function() return "enUS" end
BreakUpLargeNumbers = tostring
dofile("YiboCore/Bootstrap.lua")
dofile("YiboCore/Util/Defaults.lua")
dofile("YiboCore/Runtime/Capabilities.lua")
dofile("YiboCore/Runtime/Locale.lua")
dofile("YiboCore/Locales/zhCN.lua")
dofile("YiboCore/Locales/enUS.lua")
dofile("YiboCore/Runtime/Events.lua")
dofile("YiboCore/Runtime/Registry.lua")
dofile("YiboCore/Runtime/Contracts.lua")
local Core = YiboCore
local db = { settings = {}, characters = { byID = {}, aliases = {}, seenOrder = {} } }
Core.Database = { GetDB = function() return db end }
Core.Print = function() end
Core:RegisterAddon("YiboCore", { requiredAPI = 13 })
Core:RegisterAddon("Fixture", { requiredAPI = 13 })
dofile("YiboCore/Runtime/DataDomains.lua")
Core.DataDomains:Register("YiboCore", { id = "identity", version = 1, Collect = function() return {} end })
dofile("YiboCore/Runtime/Fields.lua")
dofile("YiboCore/Runtime/ArchiveFields.lua")
dofile("YiboCore/Data/Characters.lua")
dofile("YiboCore/Data/CharacterCleanup.lua")
local static = assert(Core.Fields:Register("YiboCore", { id = "identity", title = "Identity", consumer = "character-archive",
    domain = "identity", order = 1, Read = function(c) return c.name end }))
local notifications, calls = 0, 0
Core.AccountView = { NotifyPageChanged = function(_, id) if id == "characters" then notifications = notifications + 1 end end }
local payload = { sourceID = "Fixture:fields", characters = { A = { fields = { balance = { value = 1230000, state = "known" } } },
    B = { fields = { balance = { value = 20000, state = "stale" } } } } }
local definition = { name = "character-archive.fields", kind = "provider", providerID = "Fixture:fields", version = { major = 1, minor = 0 },
    methods = { GetFields = function() return { { id = "balance", title = "Balance", order = 20, width = 72, formatKind = "money" } } end,
        Read = function(request) calls = calls + 1; Check(#request.characterIDs == 2, "archive batch includes both characters"); return payload end } }
local ref = assert(Core.Contracts:Register("Fixture", definition))
Check(notifications == 1, "late provider refreshes archive")
local fields = Core.Fields:GetByConsumer("character-archive")
Check(#fields == 2 and fields[1] == static and fields[2].id == "balance", "static and provider fields coexist")
local snapshot = Core.ArchiveFields:Read({ { id = "A" }, { id = "B" } }, fields)
local text = Core.Fields:FormatValue({ id = "A" }, fields[2], snapshot)
Check(text == "123g", "money format uses copper unit")
Check(Core.Fields:FormatValue({ id = "B" }, fields[2], snapshot) == "2g~", "stale value remains explicitly historical")
Check(calls == 1, "drawing cells reuses one provider batch")
Check(Core.Fields:FormatValue({ id = "C" }, fields[2], snapshot) == "?", "missing is not zero")
snapshot[fields[2].archiveProvider.registrationRef].A.fields.balance.value = 0
Check(payload.characters.A.fields.balance.value == 1230000, "contract return cannot mutate provider authority")
assert(Core.Contracts:Unregister("Fixture", ref))
Check(#Core.Fields:GetByConsumer("character-archive") == 1 and notifications == 2, "unregister keeps base archive")
ref = assert(Core.Contracts:Register("Fixture", definition))
Core:RegisterAddon("Other", {})
local collision = { name = definition.name, kind = "provider", providerID = "Other:fields", version = { major = 1, minor = 0 },
    methods = { GetFields = definition.methods.GetFields, Read = function() return {} end } }
local otherRef = assert(Core.Contracts:Register("Other", collision))
Check(#Core.Fields:GetByConsumer("character-archive") == 1, "duplicate public field ID isolates both providers")
Core.Contracts:Unregister("Other", otherRef)
Check(#Core.Fields:GetByConsumer("character-archive") == 2, "conflict removal restores unique field")
Core.Contracts:Unregister("Fixture", ref)
local invalidIsolated = true
for _, supplied in ipairs({
    { { id = "bad", title = "Bad", order = 20, formatKind = "unknown" } },
    { [1] = { id = "first", title = "First", order = 20, formatKind = "money" },
        [3] = { id = "third", title = "Third", order = 30, formatKind = "money" } },
}) do
    definition.methods.GetFields = function() return supplied end
    ref = assert(Core.Contracts:Register("Fixture", definition))
    invalidIsolated = invalidIsolated and #Core.Fields:GetByConsumer("character-archive") == 1
    Core.Contracts:Unregister("Fixture", ref)
end
Check(invalidIsolated, "invalid metadata and sparse arrays cannot break base fields")
-- A dynamic owner must survive cold-start and history pruning while disabled.
local deleted = 0
local owner = { Inspect = function() return { hasData = true, label = "Fixture" } end,
    Delete = function(_, _, context) Check(context.deletedAt ~= nil, "delete callback receives tombstone time"); deleted = deleted + 1; return true end }
Check(Core.CharacterCleanup:RegisterOwner("Fixture", owner), "generic owner registers")
Check(db.characterDataOwners.Fixture, "owner ID is persisted without a business branch")
for name in pairs(Core.CharacterCleanup.EXPECTED_OWNERS) do
    Core:RegisterAddon(name, {})
    Core.CharacterCleanup:RegisterOwner(name, { Inspect = function() return {} end, Delete = function() return true end })
end
Core.CharacterCleanup._owners.Fixture = nil
Core.CharacterCleanup.MAX_HISTORY = 1
for _, id in ipairs({ "A", "B", "C" }) do
    db.characters.byID[id] = { id = id, name = id, realm = "Realm" }
    local result = assert(Core.CharacterCleanup:Delete(id))
    Check(result.owners.Fixture.status == "pending", "disabled owner is listed as pending")
end
local count = 0; for _ in pairs(db.characterDeletionHistory) do count = count + 1 end
Check(count == 3, "pending dynamic owners prevent pruning beyond soft limit")
dofile("YiboCore/Data/CharacterCleanup.lua")
Check(Core.CharacterCleanup:RegisterOwner("Fixture", owner) and deleted == 3, "cold start replays pending cleanup")
Check(Core.CharacterCleanup:IsLegacyImportBlocked("Fixture", nil, "A"), "deleted identity cannot be imported from frozen legacy data")
print("Currency CoreSpec: " .. checks .. " checks passed")
