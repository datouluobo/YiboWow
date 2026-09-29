CreateFrame = function() return {} end
GetServerTime = function() return 1790467200 end
BreakUpLargeNumbers = tostring

local characters = {
    { id = "A-Realm", name = "A", realm = "Realm", profile = { guild = "Shared" } },
    { id = "B-Realm", name = "B", realm = "Realm", profile = { guild = "Shared" } },
}
local snapshots = {
    ["A-Realm"] = { state = "known", data = { items = { [72988] = { carried = 3, total = 5 } } } },
    ["B-Realm"] = { state = "known", data = { items = { [72988] = { carried = 4, total = 4 } } } },
}
YiboCore = {
    Characters = {
        GetCurrent = function() return characters[1] end,
        GetAll = function() return characters end,
    },
    AccountView = { GetVisibleCharacters = function() return characters end },
    DataDomains = { Get = function(_, id, domain)
        return domain == "economy-items" and snapshots[id] or nil
    end },
}
YiboCurrency = {}
dofile("YiboCurrency/Data.lua")
dofile("YiboCurrency/VaultIntegration.lua")
local entry = { source = "item", itemID = 72988, verified = "implemented" }
local balance = YiboCurrency:TotalFor(characters, entry)
assert(balance.quantity == 9 and balance.complete, "Currency starts from Core item balances")
assert(YiboCurrency:GetVaultItemDetail(entry, characters) == nil,
    "without Vault the optional detail must be absent")

YiboVault = nil
dofile("YiboVault/Namespace.lua")
YiboVault.Core = YiboCore
YiboVault.db = { byCharacter = {}, byGuild = {}, revision = 0 }
dofile("YiboVault/Store.lua")
dofile("YiboVault/Items.lua")
dofile("YiboVault/PersonalCounts.lua")
local function Record(source, quantity, id, owner)
    return { sourceID = id, source = source, sourceClass = YiboVault.SourceClasses[source],
        itemID = 72988, itemKey = "item:72988", variantKey = "item:72988",
        identityQuality = "item-id-only", quantity = quantity, characterID = owner,
        realm = "Realm", location = { container = 0, slot = 1 }, observedAt = 1790467200 }
end
YiboVault:ReplaceLocation("A-Realm", "bags", "0", { Record("bags", 3, "bags:A:0:1", "A-Realm") }, { bagID = 0 })
YiboVault:ReplaceLocation("A-Realm", "bank", "-1", { Record("bank", 2, "bank:A:-1:1", "A-Realm") }, { bagID = -1 })
YiboVault:ReplaceLocation("A-Realm", "equipment", "equipment", {}, { container = "equipment" })
YiboVault:ReplaceLocation("B-Realm", "bags", "0", { Record("bags", 1, "bags:B:0:1", "B-Realm") }, { bagID = 0 })
YiboVault:ReplaceLocation("B-Realm", "mail", "inbox", { Record("mail", 2, "mail:B:1:1", "B-Realm") }, { container = "inbox" })
local guildKey = YiboVault:GetGuildIdentity(characters[1])
local guildRecord = Record("guild-bank", 7, "guild:1:1", nil)
guildRecord.guildKey = guildKey
YiboVault:ReplaceGuildTab(guildKey, "Shared", "Realm", 1, "A-Realm", { guildRecord }, "Supplies")

local revision = YiboVault.Items:GetRevision()
local detail = YiboCurrency:GetVaultItemDetail(entry, { characters[1], characters[2], characters[1] })
assert(detail.totals.bySource.bags == 4 and detail.totals.bySource.bank == 2
    and detail.totals.bySource.mail == 2
    and detail.totals.bySource["guild-bank"] == 7, "sources remain distinct and shared guild is counted once")
assert(detail.totals.totalQuantity == 15 and #detail.records == 5,
    "Vault detail can differ from Currency's own balance")
local bulkQueries, originalQuery = 0, YiboVault.Items.Query
YiboVault.Items.Query = function(self, options)
    if options and options.itemID == nil then bulkQueries = bulkQueries + 1 end
    return originalQuery(self, options)
end
local aValue, aState = YiboCurrency:GetValue(characters[1], entry)
local bValue, bState = YiboCurrency:GetValue(characters[2], entry)
assert(aValue.total == 5 and aState == "known" and bValue.total == 1 and bState == "bank",
    "Vault personal bags and bank replace the matching Core source counts per character")
local integrated = YiboCurrency:TotalFor(characters, entry)
assert(integrated.quantity == 6 and integrated.bankPending and not integrated.complete,
    "cross-character total uses Vault personal stock without adding mail, auction or shared guild stock")
assert(bulkQueries == 0, "balance reads must not scan all Vault records")
assert(YiboVault.Items:GetRevision() == revision,
    "reading already cached Vault data must not rescan or mutate the cache")
local onlyB = YiboCurrency:GetVaultItemDetail(entry, { characters[2] })
assert(onlyB.totals.bySource.bags == 1 and onlyB.totals.bySource.bank == nil,
    "explicit character scope must exclude the other character's personal inventory")
YiboVault:ReplaceLocation("B-Realm", "bags", "0", { Record("bags", 2, "bags:B:0:1", "B-Realm") }, { bagID = 0 })
assert(YiboCurrency:TotalFor(characters, entry).quantity == 7,
    "a Vault revision change must invalidate cached item-token balances")
assert(bulkQueries == 0, "a new Vault revision updates the compact count index")
local newItemA = Record("bags", 1, "bags:A:0:2", "A-Realm")
local newItemB = Record("bags", 1, "bags:B:0:2", "B-Realm")
newItemA.itemID, newItemA.itemKey, newItemA.variantKey = 888, "item:888", "item:888"
newItemB.itemID, newItemB.itemKey, newItemB.variantKey = 888, "item:888", "item:888"
YiboVault:ReplaceLocation("A-Realm", "bags", "0", { Record("bags", 3, "bags:A:0:1", "A-Realm"), newItemA }, { bagID = 0 })
YiboVault:ReplaceLocation("B-Realm", "bags", "0", { Record("bags", 2, "bags:B:0:1", "B-Realm"), newItemB }, { bagID = 0 })
for _, id in ipairs({ "C-Realm", "D-Realm" }) do
    characters[#characters + 1] = { id = id, name = id, realm = "Realm" }
    snapshots[id] = { state = "known", data = { items = {} } }
    local record = Record("bags", 1, "bags:" .. id .. ":0:1", id)
    record.itemID, record.itemKey, record.variantKey = 888, "item:888", "item:888"
    YiboVault:ReplaceLocation(id, "bags", "0", { record }, { bagID = 0 })
end
local newlyAdded = { source = "item", itemID = 888, verified = "implemented" }
assert(YiboCurrency:TotalFor(characters, newlyAdded).quantity == 4,
    "a newly added token must show all four cached characters without rescanning")
local accountCounts = YiboVault.Items:GetPersonalCounts({
    scope = { mode = "characters", characterIDs = { "A-Realm", "B-Realm", "C-Realm", "D-Realm" } },
    itemIDs = { 888, 72988, 888 },
})
assert(accountCounts.characters["A-Realm"].items[888].bags == 1
    and accountCounts.characters["B-Realm"].items[888].bags == 1
    and accountCounts.characters["C-Realm"].items[888].bank == nil,
    "batch counts distinguish known zero from unscanned sources")
dofile("YiboCurrency/Projection.lua")
local countCalls, originalCounts = 0, YiboVault.Items.GetPersonalCounts
YiboVault.Items.GetPersonalCounts = function(self, options)
    countCalls = countCalls + 1
    return originalCounts(self, options)
end
local entries = { { id = "item:72988", source = "item", itemID = 72988, verified = "implemented" }, newlyAdded }
newlyAdded.id = "item:888"
local context = {}
local domainReads, originalDomainGet = 0, YiboCore.DataDomains.Get
YiboCore.DataDomains.Get = function(self, ...)
    domainReads = domainReads + 1
    return originalDomainGet(self, ...)
end
local projection = YiboCurrency:GetCurrencyProjection(context, characters, entries)
assert(projection == YiboCurrency:GetCurrencyProjection(context, characters, entries)
    and countCalls == 1 and bulkQueries == 0 and domainReads == #characters * 2,
    "one render context shares one batch request across sizing and drawing")
for _, character in ipairs(characters) do
    for _, monitored in ipairs(entries) do
        YiboCurrency:ProjectionValue(projection, character, monitored)
        YiboCurrency:ProjectionTotal(projection, characters, monitored)
    end
end
assert(countCalls == 1 and domainReads == #characters * 2,
    "cell and total reads reuse the projection without provider calls")
assert(projection.totals["item:888"].quantity == 4,
    "projection totals include all four characters")
local equippedToken = Record("equipment", 1, "equipment:A:1", "A-Realm")
equippedToken.itemID, equippedToken.itemKey, equippedToken.variantKey = 888, "item:888", "item:888"
YiboVault:ReplaceLocation("A-Realm", "equipment", "equipment", { equippedToken }, { container = "equipment" })
assert(YiboCurrency:TotalFor(characters, newlyAdded).quantity == 5,
    "an equipped token contributes once to the personal balance")
YiboVault.CAPABILITIES["items.personal-counts"] = nil
YiboVault.CAPABILITIES["items.query"] = nil
assert(YiboCurrency:GetVaultItemDetail(entry, characters) == nil,
    "an incompatible detail capability must keep the Currency flow usable")
assert(YiboCurrency:TotalFor(characters, entry).quantity == 9,
    "an incompatible Vault must use the original Core snapshots")
print("YiboCurrency Vault integration spec passed")
