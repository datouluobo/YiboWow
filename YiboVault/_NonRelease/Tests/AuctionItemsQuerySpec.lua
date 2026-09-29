CreateFrame = function() return {} end
GetServerTime = function() return 1790467200 end

local character = { id = "Tester-Realm", name = "Tester", realm = "Realm", profile = { guild = "Guild" } }
local hiddenCharacter = { id = "Hidden-Realm", name = "Hidden", realm = "Realm" }
YiboCore = {
    Characters = {
        GetCurrent = function() return character end,
        GetAll = function() return { character, hiddenCharacter } end,
    },
    AccountView = { GetVisibleCharacters = function() return { character } end },
}
YiboVaultDB = { schemaVersion = 1, revision = 0, byCharacter = {}, byGuild = {} }

dofile("YiboVault/Namespace.lua")
YiboVault.Core = YiboCore
YiboVault.db = YiboVaultDB
dofile("YiboVault/Store.lua")
dofile("YiboVault/Items.lua")

local function Record(source, sourceClass, quantity, sourceID)
    return {
        sourceID = sourceID,
        source = source,
        sourceClass = sourceClass,
        itemID = 72988,
        itemKey = "item:72988",
        variantKey = "item:72988",
        identityQuality = "item-id-only",
        quantity = quantity,
        characterID = character.id,
        realm = character.realm,
        location = { container = source, slot = 1 },
        observedAt = 1790467200,
        state = "observed",
    }
end

YiboVault:ReplaceLocation(character.id, "bags", "0", { Record("bags", "physical", 2, "bags:Tester-Realm:0:1") }, { bagID = 0 })
YiboVault:ReplaceLocation(character.id, "auction", "auction", { Record("auction", "listed", 3, "auction:Tester-Realm:42") }, { auctionHouse = true })
YiboVault:ReplaceLocation(character.id, "mail", "inbox", { Record("mail", "external", 4, "mail:Tester-Realm:1:1") },
    { container = "inbox" }, nil, { status = "partial", currentCount = 1, totalCount = 2, unscannedCount = 1 })

local result = YiboVault.Items:Query({ scope = nil, itemID = 72988 })
assert(result.totals.totalQuantity == 9, "total includes physical stock, AH listings and visible mail attachments")
assert(result.totals.physicalQuantity == 2, "physical subtotal excludes AH listings")
assert(result.totals.listedQuantity == 3, "listed subtotal includes AH quantities")
assert(result.totals.externalQuantity == 4 and result.totals.bySource.mail == 4, "mail remains a distinct external subtotal")
assert(result.totals.bySource.bags == 2 and result.totals.bySource.auction == 3, "source subtotals remain traceable")
assert(#result.records == 3, "query returns physical, listed and mail records")
for _, record in ipairs(result.records) do
    if record.source == "auction" then assert(record.state == "observed", "fresh auction coverage marks its listing as observed") end
    if record.source == "mail" then assert(record.state == "observed", "visible partial mail remains observed") end
end
assert(result.coverage.mail[character.id].locations.inbox.unscannedCount == 1, "partial coverage exposes undisplayed mail count")

local auctionState = YiboVault.Items:GetSourceState("auction", nil)[character.id]
assert(auctionState.locations.auction.status == "known", "auction scan coverage is exposed through the public source-state query")
local unscanned = YiboVault.Items:GetSourceState("mail", { mode = "characters", characterIDs = { hiddenCharacter.id } })
assert(unscanned[hiddenCharacter.id].status == "not-yet-scanned"
    and next(unscanned[hiddenCharacter.id].locations) == nil, "unscanned owners keep the same locations envelope")
local hiddenRecord = Record("bags", "physical", 7, "bags:Hidden-Realm:0:1")
hiddenRecord.characterID = hiddenCharacter.id
YiboVault:ReplaceLocation(hiddenCharacter.id, "bags", "0", { hiddenRecord }, { bagID = 0 })
local account = YiboVault.Items:Query({ scope = { mode = "account" }, itemID = 72988 })
local realm = YiboVault.Items:Query({ scope = { mode = "realm", realm = "Realm" }, itemID = 72988 })
local explicit = YiboVault.Items:Query({ scope = { mode = "characters", characterIDs = { hiddenCharacter.id } }, itemID = 72988 })
assert(account.totals.totalQuantity == 9 and realm.totals.totalQuantity == 9
    and explicit.totals.totalQuantity == 7, "account and realm exclude hidden roles; explicit IDs may include them")
assert(YiboVault.Items:GetSourceState("bags", { mode = "account" })[hiddenCharacter.id] == nil
    and YiboVault.Items:GetStorageSummary({ mode = "account" }).characters[2] == nil,
    "all Vault read methods must apply the same visible account scope")
local copiedState = YiboVault.Items:GetSourceState("bags", { mode = "characters", characterIDs = { character.id } })
copiedState[character.id].locations["0"].status = "known-empty"
assert(YiboVault.Items:GetSourceState("bags")[character.id].locations["0"].status == "known",
    "source-state results must not expose mutable cache tables")
assert(YiboVault.Items:Query({ itemID = "72988" }) == nil
    and select(2, YiboVault.Items:Query({ itemID = "72988" })) == "invalid-item-id",
    "invalid item IDs must not look like an empty inventory")
assert(select(2, YiboVault.Items:Query({ scope = { mode = "realm" } })) == "invalid-scope")
assert(select(2, YiboVault.Items:Query({ sources = { "unknown" } })) == "invalid-sources")
assert(select(2, YiboVault.Items:Query({ identityMode = "strict", variantKey = "" })) == "invalid-variant-key")
assert(select(2, YiboVault.Items:GetStorageSummary({ mode = "unknown" })) == "invalid-scope")
assert(select(2, YiboVault.Items:GetSourceState("unknown")) == "invalid-source")
print("AuctionItemsQuerySpec: OK")
