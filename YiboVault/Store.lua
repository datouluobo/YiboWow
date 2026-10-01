local Addon = _G.YiboVault

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[Copy(key)] = Copy(child) end
    return result
end

local function EnsureCharacter(characterID)
    local byCharacter = Addon.db.byCharacter
    local character = byCharacter[characterID]
    if type(character) ~= "table" then character = {}; byCharacter[characterID] = character end
    character.bags = type(character.bags) == "table" and character.bags or {}
    character.equipment = type(character.equipment) == "table" and character.equipment or {}
    character.bank = type(character.bank) == "table" and character.bank or {}
    character.auction = type(character.auction) == "table" and character.auction or {}
    character.mail = type(character.mail) == "table" and character.mail or {}
    character.coverage = type(character.coverage) == "table" and character.coverage or { bags = {}, equipment = {}, bank = {}, auction = {}, mail = {} }
    character.coverage.bags = type(character.coverage.bags) == "table" and character.coverage.bags or {}
    character.coverage.equipment = type(character.coverage.equipment) == "table" and character.coverage.equipment or {}
    character.coverage.bank = type(character.coverage.bank) == "table" and character.coverage.bank or {}
    character.coverage.auction = type(character.coverage.auction) == "table" and character.coverage.auction or {}
    character.coverage.mail = type(character.coverage.mail) == "table" and character.coverage.mail or {}
    return character
end

local function ItemIDs(records)
    local result, seen = {}, {}
    for _, record in ipairs(records or {}) do
        if type(record.itemID) == "number" and not seen[record.itemID] then
            seen[record.itemID] = true
            result[#result + 1] = record.itemID
        end
    end
    table.sort(result)
    return result
end

local function SameContent(left, right)
    if #left ~= #right then return false end
    for index, a in ipairs(left) do
        local b = right[index]
        if a.sourceID ~= b.sourceID or a.itemID ~= b.itemID or a.itemLink ~= b.itemLink
            or a.itemKey ~= b.itemKey or a.variantKey ~= b.variantKey or a.identityQuality ~= b.identityQuality
            or a.quantity ~= b.quantity or a.location.container ~= b.location.container or a.location.slot ~= b.location.slot
            or a.auctionID ~= b.auctionID or a.stackCount ~= b.stackCount or a.buyoutAmount ~= b.buyoutAmount
            or a.bidAmount ~= b.bidAmount or a.unitPrice ~= b.unitPrice or a.timeLeft ~= b.timeLeft or a.status ~= b.status then
            return false
        end
    end
    return true
end

local function SameCapacity(left, right)
    if left == nil or right == nil then return left == right end
    return left.totalSlots == right.totalSlots and left.freeSlots == right.freeSlots
        and left.bagType == right.bagType and left.bagName == right.bagName
end

local function SameFields(left, right)
    if left == nil or right == nil then return left == right end
    for key, value in pairs(left) do if right[key] ~= value then return false end end
    for key, value in pairs(right) do if left[key] ~= value then return false end end
    return true
end

local function FireChanged(source, characterID, changedItemIDs, observedAt, force, reason, extra)
    if not next(changedItemIDs) and not force then return end
    Addon.db.revision = (tonumber(Addon.db.revision) or 0) + 1
    Addon.Items._revision = Addon.db.revision
    if Addon.Items.UpdatePersonalCountsIndex then
        Addon.Items:UpdatePersonalCountsIndex(source, characterID)
    end
    local payload = {
        apiVersion = Addon.API_VERSION,
        revision = Addon.db.revision,
        source = source,
        characterID = characterID,
        changedItemIDs = changedItemIDs,
        reason = reason or "scan",
        observedAt = observedAt,
    }
    for key, value in pairs(extra or {}) do payload[key] = Copy(value) end
    Addon.Items.Events:Fire("VAULT_ITEMS_CHANGED", payload)
end

function Addon:NotifyLocationStatusChanged(source, characterID, observedAt)
    FireChanged(source, characterID, {}, observedAt, true, "scan")
end

function Addon:ReplaceLocation(characterID, source, locationKey, candidate, location, capacity, scanMeta)
    local character = EnsureCharacter(characterID)
    local sourceData = character[source]
    local previous = sourceData[locationKey] or {}
    local now, clockSource = self:Now()
    local coverage = character.coverage[source][locationKey] or {}
    local same = SameContent(previous, candidate)
    local capacityChanged = capacity ~= nil and not SameCapacity(coverage.capacity, capacity)
    local scanStatus = scanMeta and scanMeta.status or (#candidate > 0 and "known" or "known-empty")
    local stateChanged = coverage.status ~= scanStatus or coverage.completedScan ~= true
    local locationChanged = not SameFields(coverage.location, location)
    local metaChanged = scanMeta and (coverage.currentCount ~= scanMeta.currentCount
        or coverage.totalCount ~= scanMeta.totalCount
        or coverage.unscannedCount ~= scanMeta.unscannedCount) or false
    local changed = not same or capacityChanged or stateChanged or locationChanged or metaChanged
    local changedItemIDs = {}
    if not same then
        sourceData[locationKey] = candidate
        local affectedIDs = {}
        for _, record in ipairs(previous) do affectedIDs[record.itemID] = true end
        for _, record in ipairs(candidate) do affectedIDs[record.itemID] = true end
        for itemID in pairs(affectedIDs) do changedItemIDs[#changedItemIDs + 1] = itemID end
        table.sort(changedItemIDs)
    end
    coverage.status = scanStatus
    coverage.recordCount = #candidate
    coverage.completedScan = true
    coverage.observedAt = now
    coverage.clockSource = clockSource
    coverage.revision = changed and (tonumber(self.db.revision) or 0) + 1
        or coverage.revision or (tonumber(self.db.revision) or 0)
    coverage.location = Copy(location)
    if capacity then coverage.capacity = Copy(capacity) end
    coverage.error = nil
    if scanMeta then
        coverage.currentCount = scanMeta.currentCount
        coverage.totalCount = scanMeta.totalCount
        coverage.unscannedCount = scanMeta.unscannedCount
    end
    character.coverage[source][locationKey] = coverage
    FireChanged(source, characterID, changedItemIDs, now, changed)
    return changed, Copy(coverage)
end

local function EnsureGuild(guildKey)
    Addon.db.byGuild = type(Addon.db.byGuild) == "table" and Addon.db.byGuild or {}
    local guild = Addon.db.byGuild[guildKey]
    if type(guild) ~= "table" then guild = {}; Addon.db.byGuild[guildKey] = guild end
    guild.tabs = type(guild.tabs) == "table" and guild.tabs or {}
    guild.coverage = type(guild.coverage) == "table" and guild.coverage or {}
    return guild
end

function Addon:ReplaceGuildTab(guildKey, guildName, realm, tabID, visitorCharacterID, candidate, tabName, capacity)
    local guild = EnsureGuild(guildKey)
    guild.guildName = guildName
    guild.realm = realm
    local key = tostring(tabID)
    local previous = guild.tabs[key] or {}
    local now, clockSource = self:Now()
    local same = SameContent(previous, candidate)
    local coverage = guild.coverage[key] or {}
    local capacityChanged = capacity ~= nil and not SameCapacity(coverage.capacity, capacity)
    local scanStatus = #candidate > 0 and "known" or "known-empty"
    local stateChanged = coverage.status ~= scanStatus or coverage.completedScan ~= true
    local location = { tabID = tabID, tabName = tabName }
    local locationChanged = not SameFields(coverage.location, location)
    local changed = not same or capacityChanged or stateChanged or locationChanged
    local changedItemIDs = {}
    if not same then
        guild.tabs[key] = candidate
        local affectedIDs = {}
        for _, record in ipairs(previous) do affectedIDs[record.itemID] = true end
        for _, record in ipairs(candidate) do affectedIDs[record.itemID] = true end
        for itemID in pairs(affectedIDs) do changedItemIDs[#changedItemIDs + 1] = itemID end
        table.sort(changedItemIDs)
    end
    coverage.status = scanStatus
    coverage.recordCount = #candidate
    coverage.completedScan = true
    coverage.observedAt = now
    coverage.clockSource = clockSource
    coverage.revision = changed and (tonumber(self.db.revision) or 0) + 1
        or coverage.revision or (tonumber(self.db.revision) or 0)
    coverage.visitorCharacterID = visitorCharacterID
    coverage.location = location
    if capacity then coverage.capacity = Copy(capacity) end
    coverage.error = nil
    guild.coverage[key] = coverage
    FireChanged("guild-bank", nil, changedItemIDs, now, changed, "scan", {
        guildKey = guildKey, tabID = tabID, visitorCharacterID = visitorCharacterID,
    })
    return changed, Copy(coverage)
end

function Addon:MarkGuildTabError(guildKey, guildName, realm, tabID, errorMessage)
    local guild = EnsureGuild(guildKey)
    guild.guildName = guildName
    guild.realm = realm
    local key = tostring(tabID)
    local coverage = guild.coverage[key] or {}
    local errorCode = tostring(errorMessage or "guild-tab-scan-failed")
    local changed = coverage.status ~= "error" or coverage.error ~= errorCode
    coverage.status = "error"
    coverage.error = errorCode
    coverage.observedAt = select(1, self:Now())
    if changed then coverage.revision = (tonumber(self.db.revision) or 0) + 1 end
    guild.coverage[key] = coverage
    FireChanged("guild-bank", nil, {}, coverage.observedAt, changed, "scan", { guildKey = guildKey, tabID = tabID })
end

function Addon:GetGuildRecords(guildKey, itemID)
    local guild = self.db.byGuild and self.db.byGuild[guildKey]
    local records = {}
    for _, tabItems in pairs(guild and guild.tabs or {}) do
        for _, record in ipairs(tabItems) do
            if not itemID or record.itemID == itemID then records[#records + 1] = Copy(record) end
        end
    end
    table.sort(records, function(a, b) return a.sourceID < b.sourceID end)
    return records
end

function Addon:GetGuildCoverage(guildKey)
    local guild = self.db.byGuild and self.db.byGuild[guildKey]
    return Copy(guild and guild.coverage or {})
end

function Addon:IsGuildHidden(guildKey)
    local guild = self.db.byGuild and self.db.byGuild[guildKey]
    return type(guild) == "table" and guild.hidden == true
end

function Addon:SetGuildHidden(guildKey, hidden)
    local guild = self.db.byGuild and self.db.byGuild[guildKey]
    if type(guild) ~= "table" then return nil, "公会缓存不存在。" end
    hidden = hidden == true
    if (guild.hidden == true) == hidden then return true, false end
    guild.hidden = hidden or nil
    local affected = {}
    for _, records in pairs(guild.tabs or {}) do
        for _, record in ipairs(records) do affected[record.itemID] = true end
    end
    local changedItemIDs = {}
    for itemID in pairs(affected) do changedItemIDs[#changedItemIDs + 1] = itemID end
    table.sort(changedItemIDs)
    FireChanged("guild-bank", nil, changedItemIDs, select(1, self:Now()), true, "visibility", { guildKey = guildKey })
    return true, true
end

function Addon:DeleteGuild(guildKey)
    local guild = self.db.byGuild and self.db.byGuild[guildKey]
    if type(guild) ~= "table" then return nil, "公会缓存不存在。" end
    local affected = {}
    for _, records in pairs(guild.tabs or {}) do
        for _, record in ipairs(records) do affected[record.itemID] = true end
    end
    local changedItemIDs = {}
    for itemID in pairs(affected) do changedItemIDs[#changedItemIDs + 1] = itemID end
    table.sort(changedItemIDs)
    self.db.byGuild[guildKey] = nil
    FireChanged("guild-bank", nil, changedItemIDs, select(1, self:Now()), true, "cleanup", { guildKey = guildKey })
    return true
end

function Addon:GetCharacterStore(characterID)
    return EnsureCharacter(characterID)
end

function Addon:GetCharacterRecords(characterID, source, itemID)
    local character = self.db.byCharacter[characterID]
    if not character then return {} end
    local records = {}
    for _, locationItems in pairs(character[source] or {}) do
        for _, record in ipairs(locationItems) do
            if not itemID or record.itemID == itemID then records[#records + 1] = Copy(record) end
        end
    end
    table.sort(records, function(a, b) return a.sourceID < b.sourceID end)
    return records
end

function Addon:GetCharacterCoverage(characterID, source)
    local character = self.db.byCharacter[characterID]
    return Copy(character and character.coverage and character.coverage[source] or {})
end

function Addon:DeleteCharacter(character)
    if not (character and type(character.id) == "string") then return nil, "角色 ID 无效。" end
    local existed = self.db.byCharacter[character.id]
    if existed then
        local changedBySource, observedAt = { bags = {}, equipment = {}, bank = {}, auction = {}, mail = {} }, self:Now()
        for _, source in ipairs({ "bags", "equipment", "bank", "auction", "mail" }) do
            for _, location in pairs(existed[source] or {}) do
                for _, record in ipairs(location) do changedBySource[source][record.itemID] = true end
            end
        end
        local hadCoverage = existed.coverage or {}
        self.db.byCharacter[character.id] = nil
        for _, source in ipairs({ "bags", "equipment", "bank", "auction", "mail" }) do
            local changedItemIDs = {}
            for itemID in pairs(changedBySource[source]) do changedItemIDs[#changedItemIDs + 1] = itemID end
            table.sort(changedItemIDs)
            if #changedItemIDs > 0 or next(hadCoverage[source] or {}) then
                FireChanged(source, character.id, changedItemIDs, observedAt, true, "cleanup")
            end
        end
    end
    return true, existed ~= nil
end

function Addon:MarkLocationStale(characterID, source, key)
    local store = self.db.byCharacter[characterID]
    local coverage = store and store.coverage and store.coverage[source] and store.coverage[source][key]
    if not coverage or coverage.status == "stale" then return false end
    coverage.status = "stale"
    coverage.revision = (tonumber(self.db.revision) or 0) + 1
    FireChanged(source, characterID, {}, select(1, self:Now()), true, "visibility")
    return true
end

function Addon:InspectCharacter(character)
    local store = character and self.db.byCharacter[character.id]
    local locations = 0
    if store then
        for _, source in ipairs({ "bags", "equipment", "bank", "auction", "mail" }) do
            for _ in pairs(store[source] or {}) do locations = locations + 1 end
        end
    end
    return { hasData = locations > 0, label = "物品库存快照", detail = locations > 0 and ("已采集 " .. locations .. " 个位置") or "无角色库存缓存" }
end

Addon.Copy = Copy
