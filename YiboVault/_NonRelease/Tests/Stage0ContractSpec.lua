local VALID_STATUS = {
    ["not-installed"] = true,
    incompatible = true,
    ["not-yet-scanned"] = true,
    unavailable = true,
    partial = true,
    error = true,
    stale = true,
    ["known-empty"] = true,
    known = true,
}

local SOURCE_CLASS = {
    bags = "physical",
    equipment = "physical",
    bank = "physical",
    ["guild-bank"] = "physical",
    auction = "listed",
    mail = "external",
}

local function ValidateRecord(record, sourceIDs)
    assert(type(record.sourceID) == "string" and record.sourceID ~= "", "sourceID is required")
    assert(not sourceIDs[record.sourceID], "sourceID must be unique inside a provider result")
    sourceIDs[record.sourceID] = true
    assert(SOURCE_CLASS[record.source] == record.sourceClass, "sourceClass must match source")
    assert(type(record.itemID) == "number" and record.itemID > 0, "itemID must be positive")
    assert(record.itemKey == "item:" .. record.itemID, "itemKey must be the coarse item identity")
    assert(type(record.variantKey) == "string" and record.variantKey ~= "", "variantKey is required")
    assert(type(record.quantity) == "number" and record.quantity > 0 and record.quantity % 1 == 0, "quantity must be a positive integer")
    assert(type(record.observedAt) == "number", "observedAt is required")
end

local function Aggregate(records)
    local totals = {
        totalQuantity = 0,
        physicalQuantity = 0,
        listedQuantity = 0,
        externalQuantity = 0,
        bySource = {},
    }
    local sourceIDs = {}
    for _, record in ipairs(records) do
        ValidateRecord(record, sourceIDs)
        totals.totalQuantity = totals.totalQuantity + record.quantity
        totals.bySource[record.source] = (totals.bySource[record.source] or 0) + record.quantity
        local key = record.sourceClass .. "Quantity"
        totals[key] = totals[key] + record.quantity
    end
    return totals
end

local function ValidateCoverage(coverage)
    for _, entry in pairs(coverage) do
        assert(VALID_STATUS[entry.status], "coverage status must be from the public enum")
        if entry.status == "known-empty" then
            assert(entry.completedScan == true, "known-empty requires a completed scan")
            assert(entry.recordCount == 0, "known-empty cannot contain records")
        end
        if entry.status == "partial" then
            assert((entry.unscannedCount or 0) > 0, "partial must expose unscannedCount")
        end
    end
end

local observedAt = 1790200000
local records = {
    {
        sourceID = "bags:Alpha-Realm:0:1", source = "bags", sourceClass = "physical",
        itemID = 100, itemKey = "item:100", variantKey = "link:item:100:0:0:0:0:0:0:0",
        identityQuality = "full-link", quantity = 5, characterID = "Alpha-Realm",
        observedAt = observedAt, state = "observed",
    },
    {
        sourceID = "auction:Alpha-Realm:77", source = "auction", sourceClass = "listed",
        itemID = 100, itemKey = "item:100", variantKey = "link:item:100:0:0:0:0:0:0:0",
        identityQuality = "full-link", quantity = 3, characterID = "Alpha-Realm",
        observedAt = observedAt - 60, state = "observed",
    },
    {
        sourceID = "mail:Beta-Realm:m:42:1", source = "mail", sourceClass = "external",
        itemID = 100, itemKey = "item:100", variantKey = "link:item:100:0:0:0:0:0:0:0",
        identityQuality = "full-link", quantity = 2, characterID = "Beta-Realm",
        mailKey = "m:42", attachmentIndex = 1, observedAt = observedAt - 120, state = "observed",
    },
    {
        sourceID = "equipment:Alpha-Realm:16", source = "equipment", sourceClass = "physical",
        itemID = 200, itemKey = "item:200", variantKey = "link:item:200:9:0:0:0:0:0:0",
        identityQuality = "full-link", quantity = 1, characterID = "Alpha-Realm",
        observedAt = observedAt, state = "observed",
    },
    {
        sourceID = "equipment:Alpha-Realm:17", source = "equipment", sourceClass = "physical",
        itemID = 200, itemKey = "item:200", variantKey = "link:item:200:10:0:0:0:0:0:0",
        identityQuality = "full-link", quantity = 1, characterID = "Alpha-Realm",
        observedAt = observedAt, state = "observed",
    },
}

local coverage = {
    bags = { status = "known", completedScan = true, recordCount = 1 },
    equipment = { status = "known", completedScan = true, recordCount = 2 },
    bank = { status = "not-yet-scanned" },
    ["guild-bank"] = { status = "unavailable" },
    auction = { status = "stale", recordCount = 1 },
    mail = { status = "partial", currentCount = 100, totalCount = 103, unscannedCount = 3 },
    emptyCharacterBags = { status = "known-empty", completedScan = true, recordCount = 0 },
}

ValidateCoverage(coverage)
local totals = Aggregate(records)
assert(totals.physicalQuantity == 7, "physical total excludes auction and mail")
assert(totals.listedQuantity == 3, "listed total contains auction only")
assert(totals.externalQuantity == 2, "external total contains mail only")
assert(totals.totalQuantity == 12, "total combines all source classes")
assert(totals.bySource.bags == 5 and totals.bySource.equipment == 2, "physical sources remain traceable")

local itemIDCount, strictCount = {}, {}
for _, record in ipairs(records) do
    itemIDCount[record.itemKey] = (itemIDCount[record.itemKey] or 0) + record.quantity
    strictCount[record.variantKey] = (strictCount[record.variantKey] or 0) + record.quantity
end
assert(itemIDCount["item:200"] == 2, "item-id mode combines variants")
assert(strictCount["link:item:200:9:0:0:0:0:0:0"] == 1, "strict mode preserves first variant")
assert(strictCount["link:item:200:10:0:0:0:0:0:0"] == 1, "strict mode preserves second variant")

local function GuildKey(realm, guild)
    assert(type(realm) == "string" and realm ~= "", "guild realm is required")
    assert(type(guild) == "string" and guild ~= "", "guild name is required")
    return realm .. "\31" .. guild
end

local guildTabs = {}
local function ReplaceGuildTab(realm, guild, tabID, observedByCharacterID, quantity)
    local key = GuildKey(realm, guild) .. "\31" .. tostring(tabID)
    guildTabs[key] = {
        guildKey = GuildKey(realm, guild),
        tabID = tabID,
        observedByCharacterID = observedByCharacterID,
        quantity = quantity,
    }
end

ReplaceGuildTab("Realm", "Shared Guild", 1, "Alpha-Realm", 47)
ReplaceGuildTab("Realm", "Shared Guild", 1, "Beta-Realm", 46)
local guildRecordCount, guildQuantity, observer
guildRecordCount, guildQuantity = 0, 0
for _, tab in pairs(guildTabs) do
    guildRecordCount = guildRecordCount + 1
    guildQuantity = guildQuantity + tab.quantity
    observer = tab.observedByCharacterID
end
assert(guildRecordCount == 1, "same-guild scans replace one tab instead of creating character copies")
assert(guildQuantity == 46, "the newest same-guild tab snapshot replaces the older quantity")
assert(observer == "Beta-Realm", "the access character is observation metadata only")

print("YiboVault/YiboMail stage 0 contract spec passed")
