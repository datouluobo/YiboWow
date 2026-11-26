local YQB = _G.YQB
local sharedID
local reported = {}
local hooks = {}
local greetingOrder, greetingSignature, keepVisibleGreetingOrder

local function ShouldReject(id)
    return type(id) == "number" and id > 0 and YQB.IsAutoRejectEnabled()
        and YQB.GetBlockScope(id) ~= nil and not YQB.GetQuestProtection(id)
end

local function Reject(id)
    if not ShouldReject(id) then return false end
    if not reported[id] then
        reported[id] = true
        YQB.ReportMessage(YQB.T("FOREVER.REJECTED", YQB.GetQuestName(id) or tostring(id)))
    end
    return true
end

function YQB.OnQuestRejectionEvent(event, id)
    if event == "QUEST_ACCEPT_CONFIRM" then
        sharedID = id
    elseif event == "QUEST_ACCEPTED" and sharedID == id then
        sharedID = nil
    elseif event == "PLAYER_ENTERING_WORLD" or event == "QUEST_FINISHED" or event == "GOSSIP_CLOSED" then
        sharedID = nil
        wipe(reported)
        greetingOrder, greetingSignature, keepVisibleGreetingOrder = nil, nil, nil
        YQB.UpdateQuestRejection()
    end
end

local function Wrap(host, key, callback)
    local original = host[key]
    if type(original) ~= "function" then return end
    local wrapper = function(...) return callback(original, ...) end
    hooks[#hooks + 1] = { host, key, original, wrapper }
    host[key] = wrapper
end

local function InstallGreeting()
    local getInfo, getCount = GetAvailableQuestInfo, GetNumAvailableQuests
    if not (getInfo and getCount and GetAvailableTitle and SelectAvailableQuest) then return end
    keepVisibleGreetingOrder = QuestFrameGreetingPanel and QuestFrameGreetingPanel:IsShown()
    local function QuestID(index)
        local _, _, _, _, id = getInfo(index)
        return id
    end
    local function NativeIndex(index)
        if not YQB.IsAutoRejectEnabled() and not greetingOrder then return index end
        local ids = {}
        for native = 1, getCount() do ids[native] = QuestID(native) or 0 end
        local signature = table.concat(ids, ",")
        if signature ~= greetingSignature then
            local allowed, rejected = {}, {}
            for native, id in ipairs(ids) do
                local group = not keepVisibleGreetingOrder and ShouldReject(id) and rejected or allowed
                group[#group + 1] = native
            end
            for _, native in ipairs(rejected) do allowed[#allowed + 1] = native end
            greetingOrder, greetingSignature = allowed, signature
        end
        return greetingOrder[index] or index
    end
    Wrap(_G, "GetAvailableQuestInfo", function(original, index, ...)
        return original(NativeIndex(index), ...)
    end)
    Wrap(_G, "GetAvailableTitle", function(original, index, ...)
        return original(NativeIndex(index), ...)
    end)
    Wrap(_G, "SelectAvailableQuest", function(original, index, ...)
        local native = NativeIndex(index)
        if not Reject(QuestID(native)) then return original(native, ...) end
    end)
end

function YQB.UpdateQuestRejection()
    if not YQB.IsAutoRejectEnabled() then
        -- The greeting buttons keep their displayed indexes until closed.
        if greetingOrder then return end
        for _, hook in ipairs(hooks) do
            local host, key, original, wrapper = unpack(hook)
            if host[key] == wrapper then host[key] = original end
        end
        wipe(hooks)
        return
    end
    if #hooks > 0 then return end

    local getAvailable = C_GossipInfo.GetAvailableQuests
    YQB.ReadUnfilteredQuestOffers = getAvailable
    if C_GossipInfo.SelectAvailableQuest then
        Wrap(C_GossipInfo, "GetAvailableQuests", function(original, ...)
            local quests = original(...)
            if not YQB.IsAutoRejectEnabled() then return quests end
            -- Automation that chooses the first eligible offer must get a
            -- chance to choose an allowed one. Keep the count and the order
            -- within each group for consumers that cache the native count.
            local ordered, rejected = {}, {}
            for _, quest in ipairs(quests) do
                local group = ShouldReject(quest.questID) and rejected or ordered
                group[#group + 1] = quest
            end
            if #rejected == 0 then return quests end
            for _, quest in ipairs(rejected) do ordered[#ordered + 1] = quest end
            return ordered
        end)
        Wrap(C_GossipInfo, "SelectAvailableQuest", function(original, id, ...)
            if not Reject(id) then return original(id, ...) end
        end)
    end

    InstallGreeting()
    Wrap(_G, "AcceptQuest", function(original, ...)
        if not Reject(GetQuestID()) then return original(...) end
    end)
    Wrap(_G, "ConfirmAcceptQuest", function(original, ...)
        if not Reject(sharedID) then return original(...) end
    end)
end
