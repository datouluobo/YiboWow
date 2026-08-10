local Addon = _G.YiboLegendary
local Probe = {}
Addon.Probe = Probe

local function Call(name, callback)
    local ok, first, second = pcall(callback)
    return { available = ok, firstType = type(first), secondType = type(second), error = ok and nil or tostring(first) }
end

local function Availability(callback)
    local ok, value = pcall(callback)
    return { available = ok and type(value) == "function", firstType = type(value), error = ok and nil or tostring(value) }
end

function Probe:Run(verbose)
    if not Addon.db then return end
    local probes = Addon.db.probes
    probes.updatedAt = Addon:GetTimestamp()
    probes.questCompletion = Availability(function()
        return (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
    end)
    probes.questLogIndex = Availability(function()
        return (C_QuestLog and C_QuestLog.GetLogIndexForQuestID) or GetQuestLogIndexByID
    end)
    probes.questObjectives = Call("questObjectives", function()
        local query = (C_QuestLog and C_QuestLog.GetLogIndexForQuestID) or GetQuestLogIndexByID
        local index = type(query) == "function" and query(31488)
        if index and index > 0 and GetNumQuestLeaderBoards then return GetNumQuestLeaderBoards(index) end
    end)
    probes.reputation = Call("reputation", function()
        return GetFactionInfoByID and GetFactionInfoByID(Addon.Data.BLACK_PRINCE_FACTION_ID)
    end)
    if verbose then
        for name, result in pairs(probes) do
            if type(result) == "table" and result.available ~= nil then
                Addon:Print(name .. ": " .. (result.available and "可用" or "不可用") .. (result.error and (" (" .. result.error .. ")") or ""))
            end
        end
    end
end
