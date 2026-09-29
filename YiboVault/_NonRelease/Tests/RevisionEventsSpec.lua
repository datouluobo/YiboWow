CreateFrame = function() return {} end
GetServerTime = function() return 1790200000 end
local character = { id = "A-Realm", realm = "Realm", profile = { guild = "Guild" } }

_G.YiboVault = nil
dofile("YiboVault/Namespace.lua")
local addon = YiboVault
addon.Core = { Characters = {
    GetCurrent = function() return character end,
    GetAll = function() return { character } end,
} }
addon.db = { byCharacter = {}, byGuild = {}, revision = 0 }
dofile("YiboVault/Store.lua")
dofile("YiboVault/Items.lua")
dofile("YiboVault/Collector.lua")

local events = {}
addon.Items.Events:Register("revision-test", function(name, payload)
    assert(name == "VAULT_ITEMS_CHANGED")
    assert(payload.revision == addon.Items:GetRevision(), "callback must see the committed global revision")
    local state = addon.Items:GetSourceState(payload.source)[payload.guildKey or character.id]
    local locationKey = payload.source == "guild-bank" and tostring(payload.tabID)
        or payload.source == "mail" and "inbox" or "0"
    local location = state and state.locations[locationKey]
    assert(location and location.revision == payload.revision,
        "callback must see the committed location status and matching revision")
    if payload.source == "guild-bank" and location.status == "known" then
        local query = addon.Items:Query({ sources = { "guild-bank" }, itemID = 100 })
        assert(query.totals.totalQuantity == 3 and query.records[1].state == "observed",
            "guild callback must read the new records immediately")
    end
    events[#events + 1] = { payload = payload, location = location }
end)

local empty, bagLocation = {}, { bagID = 0 }
addon:ReplaceLocation(character.id, "bags", "0", empty, bagLocation)
assert(#events == 1 and events[1].location.status == "known-empty"
    and #events[1].payload.changedItemIDs == 0, "first complete empty scan changes coverage")
addon:ReplaceLocation(character.id, "bags", "0", empty, bagLocation)
assert(#events == 1, "an identical repeat scan must not notify")

addon.db.byCharacter[character.id].coverage.bags["0"].status = "stale"
addon:ReplaceLocation(character.id, "bags", "0", empty, bagLocation)
assert(#events == 2 and events[2].location.status == "known-empty"
    and #events[2].payload.changedItemIDs == 0, "stale to known-empty must notify without item IDs")

addon:MarkLocationError("bags", "0", bagLocation, "read-failed")
assert(#events == 3 and events[3].location.status == "error", "scan failure must notify after coverage commit")
addon:MarkLocationError("bags", "0", bagLocation, "read-failed")
assert(#events == 3, "the same repeated failure must not notify")
addon:ReplaceLocation(character.id, "bags", "0", empty, bagLocation)
assert(#events == 4 and events[4].location.status == "known-empty", "recovery must notify")
addon:MarkLocationStale(character.id, "bags", "0")
assert(#events == 5 and events[5].location.status == "stale"
    and events[5].payload.reason == "visibility", "lost visibility must notify")
addon:MarkLocationStale(character.id, "bags", "0")
assert(#events == 5, "repeated stale marking must be idempotent")

local mailMeta = { status = "partial", currentCount = 8, totalCount = 9, unscannedCount = 1 }
addon:ReplaceLocation(character.id, "mail", "inbox", empty, { container = "inbox" }, nil, mailMeta)
local mailRevision = addon.Items:GetRevision()
addon:ReplaceLocation(character.id, "mail", "inbox", empty, { container = "inbox" }, nil, mailMeta)
assert(addon.Items:GetRevision() == mailRevision, "identical partial-mail scans must not notify")
mailMeta.currentCount, mailMeta.totalCount, mailMeta.unscannedCount = 9, 10, 1
addon:ReplaceLocation(character.id, "mail", "inbox", empty, { container = "inbox" }, nil, mailMeta)
assert(addon.Items:GetRevision() == mailRevision + 1,
    "a visible mail-count change must notify even when attachment records stay empty")

local guildKey = addon:GetGuildIdentity(character)
local guildRecord = {
    sourceID = "guild:1:1", source = "guild-bank", sourceClass = "physical",
    itemID = 100, itemKey = "item:100", variantKey = "item:100",
    identityQuality = "item-id-only", quantity = 3, guildKey = guildKey,
    location = { container = 1, tabID = 1, slot = 1 }, observedAt = 1790200000,
}
addon:ReplaceGuildTab(guildKey, "Guild", "Realm", 1, character.id, { guildRecord }, "First")
assert(events[#events].location.status == "known"
    and events[#events].payload.changedItemIDs[1] == 100, "guild callback must see committed records and coverage")
local guildQuery = addon.Items:Query({ sources = { "guild-bank" }, itemID = 100 })
assert(guildQuery.totals.totalQuantity == 3, "guild records must be readable immediately after notification")
addon:ReplaceGuildTab(guildKey, "Guild", "Realm", 1, "B-Realm", { guildRecord }, "First")
local guildEventCount = #events
assert(guildEventCount == 8, "mail and guild changes must each emit once")
addon:ReplaceGuildTab(guildKey, "Guild", "Realm", 1, character.id, { guildRecord }, "Renamed")
assert(#events == guildEventCount + 1 and events[#events].location.location.tabName == "Renamed"
    and #events[#events].payload.changedItemIDs == 0, "visible tab metadata changes must notify")
addon:MarkGuildTabError(guildKey, "Guild", "Realm", 1, "timeout")
assert(#events == guildEventCount + 2 and events[#events].location.status == "error", "guild failure must notify")
addon:MarkGuildTabError(guildKey, "Guild", "Realm", 1, "timeout")
assert(#events == guildEventCount + 2, "identical guild failure must not notify")

print("RevisionEventsSpec: OK")
