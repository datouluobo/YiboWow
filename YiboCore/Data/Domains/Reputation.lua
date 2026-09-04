local Core = _G.YiboCore
Core.ReputationRegistry = Core.ReputationRegistry or {}

-- Business pages may register stable IDs that the native reputation window
-- hides behind collapsed headers. This avoids depending on temporary UI state.
function Core:RegisterReputationFactions(entries)
    for _, entry in ipairs(entries or {}) do
        local factionID = tonumber(type(entry) == "table" and entry.factionID or entry)
        if factionID and factionID > 0 then
            local current = self.ReputationRegistry[factionID] or { factionID = factionID }
            if type(entry) == "table" then
                for key, value in pairs(entry) do
                    if key ~= "factionID" and value ~= nil then current[key] = Core.Defaults:Copy(value) end
                end
            end
            self.ReputationRegistry[factionID] = current
        end
    end
end

function Core:RegisterReputationFactionIDs(ids) self:RegisterReputationFactions(ids) end
function Core:GetReputationFactionMetadata(factionID)
    local metadata = self.ReputationRegistry[tonumber(factionID)]
    return metadata and Core.Defaults:Copy(metadata) or nil
end

-- Faction list indices are UI state and may change when headers are expanded.
-- Store facts by stable factionID so consumers can safely compare snapshots.
local function Friendship(factionID)
    if not GetFriendshipReputation then return nil end
    local friendshipFactionID, friendRep, friendMaxRep, friendName, _, _, friendTextLevel, reactionThreshold, nextThreshold = GetFriendshipReputation(factionID)
    if not friendshipFactionID or friendshipFactionID == 0 then return nil end
    local rank, maxRank
    if GetFriendshipReputationRanks then rank, maxRank = GetFriendshipReputationRanks(factionID) end
    return { reaction = friendRep, reactionName = friendTextLevel, friendName = friendName, rank = rank, maxRank = maxRank, reactionThreshold = reactionThreshold, nextThreshold = nextThreshold, maxValue = friendMaxRep }
end

Core.DataDomains:Register("YiboCore", {
    id = "reputation", version = 4,
    events = { PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, UPDATE_FACTION = true },
    Collect = function()
        if not GetNumFactions or not GetFactionInfo then return {}, "unavailable" end
        local factions, statuses = {}, {}
        local enumeratedCount, registeredCount = 0, 0
        local function Store(factionID, name, standingID, barMin, barMax, barValue, isHeader, nativeGroup)
            factionID = tonumber(factionID)
            if name and factionID and not isHeader and tonumber(standingID) then
                if not Core.ReputationRegistry[factionID] then
                    Core.ReputationRegistry[factionID] = { factionID = factionID, discovered = true }
                end
                factions[factionID] = { factionID = factionID, state = "known", name = name, standingID = standingID, value = barValue, min = barMin, max = barMax, friendship = Friendship(factionID), nativeGroup = nativeGroup }
                statuses[factionID] = "known"
                return true
            end
            return false
        end

        local nativeGroup
        for index = 1, GetNumFactions() do
            local name, _, standingID, barMin, barMax, barValue, _, _, isHeader, _, _, _, _, factionID = GetFactionInfo(index)
            if isHeader then
                nativeGroup = name
            elseif Store(factionID, name, standingID, barMin, barMax, barValue, false, nativeGroup) then
                enumeratedCount = enumeratedCount + 1
            end
        end
        -- Older clients enumerate only expanded faction-window rows. Direct
        -- ID lookup remains valid for registered entries under collapsed rows.
        if GetFactionInfoByID then
            for factionID in pairs(Core.ReputationRegistry) do
                registeredCount = registeredCount + 1
                if not factions[factionID] then
                    local name, _, standingID, barMin, barMax, barValue, _, _, isHeader = GetFactionInfoByID(factionID)
                    -- On the affected legacy client, hasRep describes whether
                    -- the faction is an expanded list row, not whether the
                    -- direct faction-ID result is usable. Registered IDs are
                    -- known reputation entries, so never reject them here.
                    if not Store(factionID, name, standingID, barMin, barMax, barValue, isHeader, nil) then statuses[factionID] = "unavailable" end
                end
            end
        else
            for factionID in pairs(Core.ReputationRegistry) do
                registeredCount = registeredCount + 1
                if not factions[factionID] then statuses[factionID] = "unavailable" end
            end
        end

        return { contractVersion = 1, coverage = "registered-and-enumerated", factions = factions, statuses = statuses, enumeratedCount = enumeratedCount, registeredCount = registeredCount }, "known"
    end,
})
