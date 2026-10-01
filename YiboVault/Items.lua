local Addon = _G.YiboVault
local Items = {}
Addon.Items = Items
Items.API_VERSION = Addon.API_VERSION
Items.Events = { _listeners = {} }

function Items:GetAPIVersion() return self.API_VERSION end

function Items:GetCapabilities()
    return Addon.Copy(Addon.CAPABILITIES)
end

function Items:HasCapability(name, minimumVersion)
    local version = Addon.CAPABILITIES[name]
    return version ~= nil and version >= (tonumber(minimumVersion) or 1), version
end

function Items:GetRevision()
    return tonumber(Addon.db and Addon.db.revision) or 0
end

local function ValidateScope(scope)
    if scope == nil then return true end
    if type(scope) ~= "table" then return nil, "invalid-scope" end
    if scope.mode == "account" then return true end
    if scope.mode == "realm" then
        if type(scope.realm) == "string" and scope.realm ~= "" then return true end
        return nil, "invalid-scope"
    end
    if scope.mode == "characters" then
        if type(scope.characterIDs) ~= "table" then return nil, "invalid-scope" end
        local count = 0
        for index, id in ipairs(scope.characterIDs) do
            if type(id) ~= "string" or id == "" then return nil, "invalid-scope" end
        end
        for key in pairs(scope.characterIDs) do
            count = count + 1
            if type(key) ~= "number" or key < 1 or key % 1 ~= 0
                or key > #scope.characterIDs then return nil, "invalid-scope" end
        end
        if count ~= #scope.characterIDs then return nil, "invalid-scope" end
        return true
    end
    return nil, "invalid-scope"
end

local function ResolveCharacters(scope)
    local core = Addon.Core
    if scope == nil then
        local current = core.Characters:GetCurrent()
        return current and { current } or {}
    end
    local all = scope.mode == "characters" and (core.Characters.GetAllCached and core.Characters:GetAllCached() or core.Characters:GetAll())
        or core.AccountView:GetVisibleCharacters()
    if scope.mode == "account" then return all end
    if scope.mode == "characters" then
        local byID, result, seen = {}, {}, {}
        for _, character in ipairs(all) do byID[character.id] = character end
        for _, id in ipairs(scope.characterIDs or {}) do
            if byID[id] and not seen[id] then result[#result + 1] = byID[id]; seen[id] = true end
        end
        return result
    end
    if scope.mode == "realm" then
        local result = {}
        for _, character in ipairs(all) do if character.realm == scope.realm then result[#result + 1] = character end end
        return result
    end
    return {}
end

Items._ValidateScope = ValidateScope
Items._ResolveCharacters = ResolveCharacters

local function SourceCoverage(locations)
    local state = { locations = locations }
    if not next(locations) then state.status = "not-yet-scanned" end
    return state
end

local function ResolveGuildKeys(characters, options)
    if options and options.guildKey then
        return Addon.db.byGuild and Addon.db.byGuild[options.guildKey]
            and { options.guildKey } or {}
    end
    local keys, seen, missingGuildByID = {}, {}, {}
    local function Add(key)
        if key and not seen[key] then seen[key] = true; keys[#keys + 1] = key end
    end
    for _, character in ipairs(characters) do
        local key = Addon:GetGuildIdentity(character)
        Add(key)
        if not key then missingGuildByID[character.id] = character.realm end
    end
    -- Older Core snapshots can lack the guild field even though Vault saved the
    -- visitor ID with each tab. Keep that historical association scoped to the
    -- selected character and realm, and never override a current guild identity.
    if next(missingGuildByID) then
        for key, guild in pairs(Addon.db.byGuild or {}) do
            if type(guild) == "table" and not seen[key] then
                for _, tab in pairs(guild.coverage or {}) do
                    local visitorID = type(tab) == "table" and tab.visitorCharacterID
                    if visitorID and missingGuildByID[visitorID] == guild.realm then
                        Add(key)
                        break
                    end
                end
            end
        end
    end
    table.sort(keys)
    local visible = {}
    for _, key in ipairs(keys) do
        if options and options.includeHiddenGuilds or not Addon:IsGuildHidden(key) then
            visible[#visible + 1] = key
        end
    end
    return visible
end

local function ValidateGuildOptions(options)
    if options == nil then return true end
    if type(options) ~= "table" then return nil, "invalid-options" end
    if options.includeHiddenGuilds ~= nil and type(options.includeHiddenGuilds) ~= "boolean" then
        return nil, "invalid-include-hidden-guilds"
    end
    if options.guildKey ~= nil and (type(options.guildKey) ~= "string" or options.guildKey == "") then
        return nil, "invalid-guild-key"
    end
    return true
end

local function StorageArea(locations, legacyTabs)
    local area = { locations = {}, totalSlots = 0, freeSlots = 0, capacityLocations = 0, freeLocations = 0, hasStale = false }
    for key, coverage in pairs(locations or {}) do
        local legacyRecords = legacyTabs and legacyTabs[key]
        local legacyGuildTab = coverage.status == "stale" and type(coverage.recordCount) == "number"
            and type(coverage.location) == "table" and tonumber(coverage.location.tabID)
            and type(legacyRecords) == "table" and #legacyRecords == coverage.recordCount
        if coverage.completedScan or legacyGuildTab then
            local entry = Addon.Copy(coverage)
            entry.locationKey = key
            area.locations[#area.locations + 1] = entry
            if coverage.status ~= "known" and coverage.status ~= "known-empty" then area.hasStale = true end
            local capacity = coverage.capacity
            if type(capacity) == "table" and type(capacity.totalSlots) == "number" and capacity.totalSlots >= 0 then
                area.totalSlots = area.totalSlots + capacity.totalSlots
                area.capacityLocations = area.capacityLocations + 1
                if capacity.totalSlots == 0 or type(capacity.freeSlots) == "number" then
                    area.freeSlots = area.freeSlots + (capacity.freeSlots or 0)
                    area.freeLocations = area.freeLocations + 1
                end
            end
        end
    end
    table.sort(area.locations, function(a, b)
        local left, right = tonumber(a.locationKey), tonumber(b.locationKey)
        if left and right then return left < right end
        return tostring(a.locationKey) < tostring(b.locationKey)
    end)
    if #area.locations == 0 then return nil end
    if area.capacityLocations == 0 then area.totalSlots = nil end
    if area.freeLocations < area.capacityLocations or area.freeLocations == 0 then area.freeSlots = nil end
    area.completeCapacity = area.capacityLocations == #area.locations and area.freeLocations == #area.locations
    return area
end

function Items:GetStorageSummary(scope, options)
    local valid, errorCode = ValidateScope(scope)
    if not valid then return nil, errorCode end
    valid, errorCode = ValidateGuildOptions(options)
    if not valid then return nil, errorCode end
    local result = { apiVersion = self.API_VERSION, revision = self:GetRevision(), characters = {}, guilds = {} }
    local characters = ResolveCharacters(scope)
    for _, character in ipairs(characters) do
        local bags = StorageArea(Addon:GetCharacterCoverage(character.id, "bags"))
        local bank = StorageArea(Addon:GetCharacterCoverage(character.id, "bank"))
        local equipment = StorageArea(Addon:GetCharacterCoverage(character.id, "equipment"))
        local mail = StorageArea(Addon:GetCharacterCoverage(character.id, "mail"))
        if bags or bank or equipment or mail then
            result.characters[#result.characters + 1] = {
                characterID = character.id, realm = character.realm,
                bags = bags, bank = bank, equipment = equipment, mail = mail,
            }
        end
    end
    for _, guildKey in ipairs(ResolveGuildKeys(characters, options)) do
        local guild = Addon.db.byGuild and Addon.db.byGuild[guildKey]
        local tabs = StorageArea(guild and guild.coverage, guild and guild.tabs)
        if tabs then
            result.guilds[#result.guilds + 1] = {
                guildKey = guildKey, guildName = guild.guildName, realm = guild.realm, tabs = tabs,
            }
        end
    end
    return result
end

function Items:GetSourceState(source, scope, options)
    if not Addon.SourceClasses[source] then return nil, "invalid-source" end
    local valid, errorCode = ValidateScope(scope)
    if not valid then return nil, errorCode end
    valid, errorCode = ValidateGuildOptions(options)
    if not valid then return nil, errorCode end
    local result = {}
    if source == "guild-bank" then
        for _, guildKey in ipairs(ResolveGuildKeys(ResolveCharacters(scope), options)) do
            local locations = Addon:GetGuildCoverage(guildKey)
            result[guildKey] = SourceCoverage(locations)
        end
        return result
    end
    for _, character in ipairs(ResolveCharacters(scope)) do
        local locations = Addon:GetCharacterCoverage(character.id, source)
        result[character.id] = SourceCoverage(locations)
    end
    return result
end

function Items:Query(options)
    if options ~= nil and type(options) ~= "table" then return nil, "invalid-options" end
    options = options or {}
    local valid, errorCode = ValidateScope(options.scope)
    if not valid then return nil, errorCode end
    valid, errorCode = ValidateGuildOptions(options)
    if not valid then return nil, errorCode end
    if options.itemID ~= nil and (type(options.itemID) ~= "number" or options.itemID <= 0
        or options.itemID % 1 ~= 0) then return nil, "invalid-item-id" end
    if options.identityMode ~= nil and options.identityMode ~= "item-id"
        and options.identityMode ~= "strict" then return nil, "invalid-identity-mode" end
    if options.variantKey ~= nil and (options.identityMode ~= "strict"
        or type(options.variantKey) ~= "string" or options.variantKey == "") then
        return nil, "invalid-variant-key"
    end
    if options.includeStale ~= nil and type(options.includeStale) ~= "boolean" then
        return nil, "invalid-include-stale"
    end
    if options.sources ~= nil then
        if type(options.sources) ~= "table" then return nil, "invalid-sources" end
        local count = 0
        for _, source in ipairs(options.sources) do
            if not Addon.SourceClasses[source] then return nil, "invalid-sources" end
        end
        for key in pairs(options.sources) do
            count = count + 1
            if type(key) ~= "number" or key < 1 or key % 1 ~= 0
                or key > #options.sources then return nil, "invalid-sources" end
        end
        if count ~= #options.sources then return nil, "invalid-sources" end
    end
    local requestedItemID = tonumber(options.itemID)
    local identityMode = options.identityMode == "strict" and "strict" or "item-id"
    local selectedSources = {}
    if type(options.sources) == "table" then
        for _, source in ipairs(options.sources) do if Addon.SourceClasses[source] then selectedSources[source] = true end end
    else
        for source in pairs(Addon.SourceClasses) do selectedSources[source] = true end
    end
    local records, coverage, totals = {}, {}, {
        totalQuantity = 0, physicalQuantity = 0, listedQuantity = 0, externalQuantity = 0, bySource = {},
    }
    local characters = ResolveCharacters(options.scope)
    for _, character in ipairs(characters) do
        for source in pairs(selectedSources) do
            if source ~= "guild-bank" then
                local states = Addon:GetCharacterCoverage(character.id, source)
                coverage[source] = coverage[source] or {}
                coverage[source][character.id] = SourceCoverage(states)
                for _, record in ipairs(Addon:GetCharacterRecords(character.id, source, requestedItemID)) do
                    local locationKey
                    if source == "bags" or source == "bank" then
                        locationKey = tostring(record.location.container)
                    elseif source == "auction" then
                        locationKey = "auction"
                    elseif source == "mail" then
                        locationKey = "inbox"
                    else
                        locationKey = "equipment"
                    end
                    local locationState = states[locationKey]
                    local fresh = locationState and (locationState.status == "known" or locationState.status == "known-empty"
                        or source == "mail" and locationState.status == "partial")
                    record.state = fresh and "observed" or "stale"
                    local identityMatches = identityMode ~= "strict" or not options.variantKey
                        or record.variantKey == options.variantKey
                    if (options.includeStale ~= false or fresh)
                        and identityMatches and (not options.itemID or record.itemID == requestedItemID) then
                        records[#records + 1] = record
                        totals.totalQuantity = totals.totalQuantity + record.quantity
                        local class = Addon.SourceClasses[source]
                        totals[class .. "Quantity"] = totals[class .. "Quantity"] + record.quantity
                        totals.bySource[source] = (totals.bySource[source] or 0) + record.quantity
                    end
                end
            end
        end
    end
    if selectedSources["guild-bank"] then
        for _, guildKey in ipairs(ResolveGuildKeys(characters, options)) do
                local states = Addon:GetGuildCoverage(guildKey)
                coverage["guild-bank"] = coverage["guild-bank"] or {}
                coverage["guild-bank"][guildKey] = SourceCoverage(states)
                for _, record in ipairs(Addon:GetGuildRecords(guildKey, requestedItemID)) do
                    local locationState = states[tostring(record.location.container)]
                    local fresh = locationState and (locationState.status == "known" or locationState.status == "known-empty")
                    record.state = fresh and "observed" or "stale"
                    local identityMatches = identityMode ~= "strict" or not options.variantKey
                        or record.variantKey == options.variantKey
                    if (options.includeStale ~= false or fresh)
                        and identityMatches and (not options.itemID or record.itemID == requestedItemID) then
                        records[#records + 1] = record
                        totals.totalQuantity = totals.totalQuantity + record.quantity
                        local class = Addon.SourceClasses["guild-bank"]
                        totals[class .. "Quantity"] = totals[class .. "Quantity"] + record.quantity
                        totals.bySource["guild-bank"] = (totals.bySource["guild-bank"] or 0) + record.quantity
                    end
                end
        end
    end
    table.sort(records, function(a, b) return a.sourceID < b.sourceID end)
    local generatedAt = Addon:Now()
    return {
        apiVersion = self.API_VERSION,
        revision = self:GetRevision(),
        generatedAt = generatedAt,
        identityMode = identityMode,
        records = records,
        totals = totals,
        coverage = coverage,
    }
end

function Items.Events:Register(owner, callback)
    if owner == nil or type(callback) ~= "function" then return nil, "事件订阅参数无效。" end
    self._listeners[#self._listeners + 1] = { owner = owner, callback = callback }
    return true
end

function Items.Events:Unregister(owner, callback)
    for index = #self._listeners, 1, -1 do
        local listener = self._listeners[index]
        if listener.owner == owner and (callback == nil or listener.callback == callback) then table.remove(self._listeners, index) end
    end
end

function Items.Events:Fire(eventName, payload)
    for _, listener in ipairs(self._listeners) do
        local ok, errorMessage = pcall(listener.callback, eventName, Addon.Copy(payload))
        if not ok then Addon:Print("事件订阅回调失败：" .. tostring(errorMessage)) end
    end
end
