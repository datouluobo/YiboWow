local Addon, Core = _G.YiboReputation, _G.YiboCore
local Scanner = { RETRY_LIMIT=3 }
Addon.Scanner = Scanner

local function Friendship(factionID)
    local friendshipFactionID, friendRep, friendMaxRep, friendName, reaction, threshold, nextThreshold
    if GetFriendshipReputation then
        local unused
        friendshipFactionID, friendRep, friendMaxRep, friendName, unused, unused, reaction, threshold, nextThreshold = GetFriendshipReputation(factionID)
    elseif GetFriendshipReputationByID then
        local unused
        friendshipFactionID, friendRep, friendMaxRep, unused, unused, reaction, threshold = GetFriendshipReputationByID(factionID)
    elseif C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
        local info = C_GossipInfo.GetFriendshipReputation(factionID)
        if info then
            friendshipFactionID, friendRep, friendMaxRep = info.friendshipFactionID, info.standing, info.maxRep
            friendName, reaction, threshold, nextThreshold = info.name, info.reaction, info.reactionThreshold, info.nextThreshold
        end
    else return nil end
    if not friendshipFactionID or friendshipFactionID == 0 then return nil end
    local rank, maxRank
    if GetFriendshipReputationRanks then rank, maxRank = GetFriendshipReputationRanks(friendshipFactionID) end
    return { reaction=friendRep, reactionName=reaction, friendName=friendName, rank=rank, maxRank=maxRank,
        reactionThreshold=threshold, nextThreshold=nextThreshold, maxValue=friendMaxRep }
end

local function ReadFaction(query, id, byID)
    local name, description, standing, minimum, maximum, value, atWar, canWar, header, collapsed, hasRep, watched, child, factionID = query(id)
    if type(name) == "table" then
        local info = name
        return info.factionID, info.name, info.reaction or info.standingID,
            info.currentReactionThreshold or info.barMin, info.nextReactionThreshold or info.barMax,
            info.currentStanding or info.barValue, info.isHeader
    end
    return factionID or (byID and id), name, standing, minimum, maximum, value, header
end

function Scanner:Collect()
    local countQuery = GetNumFactions or (C_Reputation and C_Reputation.GetNumFactions)
    local rowQuery = GetFactionInfo or (C_Reputation and C_Reputation.GetFactionDataByIndex)
    local idQuery = GetFactionInfoByID or (C_Reputation and C_Reputation.GetFactionDataByID)
    if type(countQuery) ~= "function" or type(rowQuery) ~= "function" then return nil, "unavailable", "missing-api" end
    local factions, statuses, discovered = {}, {}, {}
    local enumeratedCount, registeredCount = 0, 0
    local function Store(id, name, standing, minimum, maximum, value, header, group)
        id = tonumber(id)
        if not id or id <= 0 or id % 1 ~= 0 then return false end
        local metadata = Addon.FactionRegistry[id]
        local retainHeader = header and metadata and metadata.isPrimaryFaction == true
        local ordinary = (not header or retainHeader) and tonumber(standing)
        local friendship = Friendship(id)
        if type(name) == "string" and name ~= "" and (ordinary or friendship) then
            factions[id] = { factionID=id, state="known", name=name, standingID=standing,
                value=value, min=minimum, max=maximum, friendship=friendship, nativeGroup=group }
            statuses[id], discovered[id] = "known", true
            return true
        end
        return false
    end
    local group
    local count = tonumber(countQuery()) or 0
    for index = 1, count do
        -- Row indices must never be used as faction identities.
        local id, name, standing, minimum, maximum, value, header = ReadFaction(rowQuery, index)
        if header then
            Store(id, name, standing, minimum, maximum, value, true, group)
            group = name
        elseif Store(id, name, standing, minimum, maximum, value, false, group) then
            enumeratedCount = enumeratedCount + 1
        end
    end
    for id in pairs(Addon.FactionRegistry) do
        registeredCount = registeredCount + 1
        if not factions[id] then
            local stored
            if type(idQuery) == "function" then
                local ignored, name, standing, minimum, maximum, value, header = ReadFaction(idQuery, id, true)
                stored = Store(id, name, standing, minimum, maximum, value, header)
            end
            if not stored then statuses[id] = "unavailable" end
        end
    end
    if not next(factions) then return nil, "not-yet-scanned", "empty-result" end
    return { contractVersion=1, coverage="registered-and-enumerated", factions=factions, statuses=statuses,
        enumeratedCount=enumeratedCount, registeredCount=registeredCount }, "known", discovered
end

function Addon:ScanCurrent(reason)
    local character = Core.Characters:GetCurrent({ identityOnly=true })
    if not character or not UnitGUID or character.id ~= UnitGUID("player") then return nil, "identity-not-ready" end
    local ok, data, state, detail = pcall(self.Scanner.Collect, self.Scanner)
    if not ok then data, state, detail = nil, "error", tostring(data) end
    local snapshot, changed = self:CommitSnapshot(character.id, data, state, {
        reason=reason, error=state ~= "known" and detail or nil,
    })
    if not snapshot then
        self:CommitSnapshot(character.id, nil, "error", { reason=reason, error=changed })
        return nil, changed
    end
    if snapshot and state == "known" then
        for id in pairs(detail or {}) do
            self.FactionRegistry[id] = self.FactionRegistry[id] or { factionID=id, discovered=true }
        end
        return true, changed
    end
    return nil, detail or changed or state
end

function Scanner:Request(reason, retry)
    if not self.initialized then return end
    if not retry then self.retryCount = 0 end
    self.reason = reason or self.reason or "event"
    if self.pending then return end
    self.pending = true
    C_Timer.After(retry and 1 or 0.15, function()
        self.pending = false
        if not self.initialized then return end
        local success, err = Addon:ScanCurrent(self.reason)
        self.lastError = success and nil or err
        if success then self.retryCount = 0
        elseif self.retryCount < self.RETRY_LIMIT then
            self.retryCount = self.retryCount + 1
            self:Request("retry", true)
        end
    end)
end

function Scanner:Initialize()
    if self.initialized then return true end
    self.frame = self.frame or CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UPDATE_FACTION" }) do self.frame:RegisterEvent(event) end
    self.frame:SetScript("OnEvent", function(_, event) self:Request(event) end)
    self.initialized, self.retryCount = true, 0
    if IsLoggedIn and IsLoggedIn() then self:Request("initialize") end
    return true
end
