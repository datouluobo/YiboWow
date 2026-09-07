local Addon = _G.YiboLegendary
local Probe = {}
Addon.Probe = Probe

local function Call(name, callback)
    local ok, first, second = pcall(callback)
    local available = ok and first ~= nil
    local errorMessage
    if not ok then
        errorMessage = tostring(first)
    elseif not available then
        errorMessage = "未返回有效数据"
    end
    return { available = available, firstType = type(first), secondType = type(second), error = errorMessage }
end

local function Availability(callback)
    local ok, value = pcall(callback)
    return { available = ok and type(value) == "function", firstType = type(value), error = ok and nil or tostring(value) }
end

local function Readability(name, callback)
    local ok, value = pcall(callback)
    return {
        readable = ok and value == true,
        available = ok and value ~= nil,
        state = (not ok and "unreadable") or (value == true and "normal" or "not_synced"),
        error = ok and nil or tostring(value),
        name = name,
    }
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
        if type(GetFactionInfoByID) ~= "function" then return nil end
        local name = GetFactionInfoByID(Addon.Data.BLACK_PRINCE_FACTION_ID)
        return name
    end)
    probes.itemCount = Call("itemCount", function()
        if type(GetItemCount) ~= "function" then return nil end
        return GetItemCount(18563, true, false, true)
    end)
    probes.finalItem = Readability("finalItem", function()
        if type(GetItemCount) ~= "function" then return nil end
        return GetItemCount(19019, true, false, true) ~= nil
    end)
    probes.equipment = Readability("equipment", function()
        return type(GetInventoryItemID) == "function"
    end)
    probes.questHistory = Readability("questHistory", function()
        return type(IsQuestFlaggedCompleted) == "function" or (C_QuestLog and type(C_QuestLog.IsQuestFlaggedCompleted) == "function")
    end)
    if verbose then
        for name, result in pairs(probes) do
            if type(result) == "table" and result.available ~= nil then
                local suffix = result.state and (" · " .. result.state) or ""
                Addon:Print(name .. ": " .. (result.available and "可用" or "不可用") .. suffix .. (result.error and (" (" .. result.error .. ")") or ""))
            end
        end
    end
end
