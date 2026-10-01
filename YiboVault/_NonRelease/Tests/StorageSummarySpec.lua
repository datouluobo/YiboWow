CreateFrame = function() return {} end
GetServerTime = function() return 1790200000 end
local characters = {
    { id = "A-Realm", realm = "Realm", profile = { guild = "Shared" } },
    { id = "B-Realm", realm = "Realm", profile = { guild = "Shared" } },
    { id = "C-Realm", realm = "Realm" },
}
_G.YiboVault = nil
dofile("YiboVault/Namespace.lua")
local addon = _G.YiboVault
addon.Core = { Characters = {
    GetAll = function() return characters end,
    GetCurrent = function() return characters[1] end,
} }
addon.db = { byCharacter = {}, byGuild = {}, revision = 0 }
dofile("YiboVault/Store.lua")
dofile("YiboVault/Items.lua")
assert(addon.Items:HasCapability("storage.summary", 1), "storage summary must be discoverable")
local capabilities = addon.Items:GetCapabilities()
capabilities["storage.summary"] = nil
assert(addon.Items:HasCapability("storage.summary", 1), "capability results must be copied")
assert(select(2, addon.Items:GetStorageSummary({ mode = "realm" })) == "invalid-scope",
    "summary must reject invalid scope")

local changed = 0
addon.Items.Events:Register("test", function() changed = changed + 1 end)
local empty = {}
addon:ReplaceLocation("A-Realm", "bags", "0", empty, { bagID = 0 }, { totalSlots = 20, freeSlots = 20 })
addon:ReplaceLocation("A-Realm", "bags", "1", empty, { bagID = 1 }, { totalSlots = 24, freeSlots = 12, bagName = "Herb" })
addon:ReplaceLocation("A-Realm", "bank", "-1", empty, { bagID = -1 }, { totalSlots = 28, freeSlots = 10 })
addon:ReplaceLocation("C-Realm", "bags", "0", empty, { bagID = 0 }, { totalSlots = 20 })
local revision = addon.Items:GetRevision()
addon:ReplaceLocation("A-Realm", "bags", "1", empty, { bagID = 1 }, { totalSlots = 24, freeSlots = 12, bagName = "Herb" })
assert(addon.Items:GetRevision() == revision and changed == 4, "identical capacity scan must be idempotent")
addon:ReplaceLocation("A-Realm", "bags", "1", empty, { bagID = 1 }, { totalSlots = 24, freeSlots = 11, bagName = "Herb" })
assert(addon.Items:GetRevision() == revision + 1 and changed == 5, "free-slot change must notify consumers")

local guildKey = addon:GetGuildIdentity(characters[1])
addon:ReplaceGuildTab(guildKey, "Shared", "Realm", 1, "A-Realm", empty, "First", { totalSlots = 98, freeSlots = 98 })
addon:ReplaceGuildTab(guildKey, "Shared", "Realm", 1, "B-Realm", empty, "First", { totalSlots = 98, freeSlots = 97 })

local summary = addon.Items:GetStorageSummary({ mode = "characters", characterIDs = { "B-Realm", "A-Realm", "C-Realm" } })
assert(#summary.characters == 2 and summary.characters[1].characterID == "A-Realm", "summary must preserve scoped order and omit unscanned roles")
assert(summary.characters[1].bags.totalSlots == 44 and summary.characters[1].bags.freeSlots == 31, "bag capacity must aggregate known containers")
assert(summary.characters[1].bank.totalSlots == 28 and summary.characters[1].bank.freeSlots == 10, "bank capacity must stay separate")
assert(summary.characters[2].bags.totalSlots == 20 and summary.characters[2].bags.freeSlots == nil,
    "unavailable free-slot data must remain unknown")
assert(summary.characters[2].bags.completeCapacity == false,
    "unknown free slots must not become complete capacity")
assert(#summary.guilds == 1 and summary.guilds[1].tabs.freeSlots == 97, "shared guild tab must be counted once")
summary.characters[1].bags.locations[1].capacity.totalSlots = 999
assert(addon.Items:GetStorageSummary().characters[1].bags.totalSlots == 44, "public summary must be a copy")
local legacyKey = addon:GetGuildIdentity({ realm = "Realm", profile = { guild = "Old Guild" } })
addon.db.byGuild[legacyKey] = {
    guildName = "Old Guild", realm = "Realm",
    coverage = { ["2"] = { status = "stale", recordCount = 1,
        visitorCharacterID = "C-Realm", location = { tabID = 2, tabName = "Supplies" } } },
    tabs = { ["2"] = { { sourceID = "legacy:2:1", source = "guild-bank", sourceClass = "physical",
        itemID = 42, quantity = 3, guildKey = legacyKey, location = { container = 2, tabID = 2, slot = 1 } } } },
}
local legacyScope = { mode = "characters", characterIDs = { "C-Realm" } }
local legacySummary = addon.Items:GetStorageSummary(legacyScope)
assert(#legacySummary.guilds == 1 and legacySummary.guilds[1].guildKey == legacyKey
    and legacySummary.guilds[1].tabs.hasStale and #legacySummary.guilds[1].tabs.locations == 1,
    "a legacy guild tab must remain visible as a stale snapshot for its visitor")
assert(legacySummary.guilds[1].tabs.totalSlots == nil and legacySummary.guilds[1].tabs.freeSlots == nil
    and legacySummary.guilds[1].tabs.completeCapacity == false,
    "legacy guild capacity must remain unknown")
assert(addon.Items:GetSourceState("guild-bank", legacyScope)[legacyKey].locations["2"].status == "stale",
    "guild source state must use the same historical visitor association")
local legacyQuery = addon.Items:Query({ scope = legacyScope, sources = { "guild-bank" } })
assert(#legacyQuery.records == 1 and legacyQuery.records[1].state == "stale"
    and legacyQuery.totals.totalQuantity == 3, "legacy guild items must be queryable once")
characters[3].profile = { guild = "New Guild" }
assert(#addon.Items:GetStorageSummary(legacyScope).guilds == 0,
    "a current guild identity must supersede historical visitor associations")
local sharedScope = { mode = "characters", characterIDs = { "A-Realm" } }
addon:ReplaceGuildTab(guildKey, "Shared", "Realm", 1, "A-Realm", {
    { sourceID = "guild:1:1", source = "guild-bank", itemID = 42, quantity = 7,
        guildKey = guildKey, location = { container = 1, tabID = 1, slot = 1 } },
}, "First", { totalSlots = 98, freeSlots = 97 })
assert(addon.Items:Query({ scope = sharedScope, itemID = 42 }).totals.totalQuantity == 7,
    "visible guild stock must be included by default")
assert(addon:SetGuildHidden(guildKey, true))
assert(addon.Items:Query({ scope = sharedScope, itemID = 42 }).totals.totalQuantity == 0,
    "hidden guild stock must leave default totals")
assert(#addon.Items:GetStorageSummary(sharedScope).guilds == 0
    and addon.Items:GetSourceState("guild-bank", sharedScope)[guildKey] == nil,
    "hidden guilds must leave default capacity and source state")
assert(addon.Items:Query({ scope = sharedScope, itemID = 42,
    includeHiddenGuilds = true }).totals.totalQuantity == 7,
    "an opted-in scope must still query hidden guild stock")
addon:ReplaceGuildTab(guildKey, "Shared", "Realm", 1, "A-Realm", {
    { sourceID = "guild:1:1", source = "guild-bank", itemID = 42, quantity = 8,
        guildKey = guildKey, location = { container = 1, tabID = 1, slot = 1 } },
}, "First", { totalSlots = 98, freeSlots = 97 })
assert(addon:IsGuildHidden(guildKey)
    and addon.Items:Query({ scope = sharedScope, itemID = 42 }).totals.totalQuantity == 0,
    "scanning a hidden guild must update its cache without restoring it to default totals")
assert(addon.Items:Query({ scope = { mode = "characters", characterIDs = {} },
    itemID = 42, guildKey = guildKey }).totals.totalQuantity == 8,
    "an explicit guild key must work without a linked character")
assert(#addon.Items:GetStorageSummary({ mode = "characters", characterIDs = {} },
    { guildKey = legacyKey }).guilds == 1,
    "an orphaned historical guild must be inspectable explicitly")
assert(select(2, addon.Items:Query({ includeHiddenGuilds = "yes" })) == "invalid-include-hidden-guilds")
assert(addon:DeleteGuild(guildKey) and addon.db.byGuild[guildKey] == nil,
    "deleting a guild must remove its snapshot and hidden state")
print("YiboVault storage summary spec passed")
