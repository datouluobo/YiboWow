local YQB = _G.YQB
local Core = _G.YiboCore
local offers, reported = {}, {}
local detailID

function YQB.GetQuestOffers()
    local list = {}
    for id, row in pairs(offers) do
        if not YQB.IsQuestInLog(id) then list[#list + 1] = row end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function ClearOffers()
    offers, reported, detailID = {}, {}, nil
end

local function ReportOffer(id)
    if YQB.IsProcessingPaused() or reported[id] then return end
    local offer = offers[id]
    local protection = YQB.GetQuestProtection(id)
    if protection and YQB.IsQuestBlocked(id) then
        YQB.ReportMessage(YQB.T("FOREVER.PROTECT_MATCH", offer.name, protection))
    elseif not YQB.IsAutoRejectEnabled() and YQB.IsQuestBlocked(id) then
        YQB.ReportMessage(YQB.T("FOREVER.OFFER_MATCH", offer.name))
    else
        return
    end
    reported[id] = true
end

local function RememberOffer(id, title)
    if not id or id <= 0 or YQB.IsQuestInLog(id) then return end
    offers[id] = { id = id, name = title or YQB.ReadQuestTitle(id) or ("ID: " .. id) }
    ReportOffer(id)
end

function YQB.StartQuestRuntime()
    YQB.ReadUnfilteredQuestOffers = C_GossipInfo.GetAvailableQuests
    YQB.UpdateQuestRejection()
    local frame = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "GOSSIP_SHOW", "GOSSIP_CLOSED",
        "QUEST_DETAIL", "QUEST_FINISHED", "QUEST_ACCEPT_CONFIRM", "QUEST_ACCEPTED",
        "QUEST_TURNED_IN", "PLAYER_REGEN_ENABLED" }) do
        frame:RegisterEvent(event)
    end
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            ClearOffers()
            YQB.BindCurrentCharacter()
            YQB.RefreshQuestNames()
        elseif event == "GOSSIP_SHOW" then
            ClearOffers()
            for _, quest in ipairs(YQB.ReadUnfilteredQuestOffers()) do
                RememberOffer(quest.questID, quest.title)
            end
        elseif event == "QUEST_DETAIL" then
            detailID = GetQuestID()
            RememberOffer(detailID, GetTitleText())
        elseif event == "QUEST_ACCEPT_CONFIRM" then
            local _, title, id = ...
            YQB.OnQuestRejectionEvent(event, id)
            detailID = id
            RememberOffer(id, title)
        elseif event == "QUEST_ACCEPTED" then
            local id = ...
            if offers[id] then
                YQB.RememberQuestName(id, offers[id].name)
                offers[id] = nil
                if not YQB.IsProcessingPaused() and not YQB.IsAutoAbandonEnabled() and YQB.IsQuestBlocked(id) then
                    YQB.ReportMessage(YQB.T("FOREVER.LOG_MATCH", YQB.GetQuestName(id)))
                end
            end
        elseif event == "GOSSIP_CLOSED" then
            local detail = detailID and offers[detailID]
            offers = detail and { [detailID] = detail } or {}
            if not detail then ClearOffers() end
        elseif event == "QUEST_FINISHED" then
            ClearOffers()
        end
        if event ~= "QUEST_ACCEPT_CONFIRM" then YQB.OnQuestRejectionEvent(event, ...) end
        YQB.OnQuestHandlingEvent(event, ...)
        YQB.NotifyCorePageChanged(true)
    end)
    Core.Events:Register("CHARACTER_ID_CHANGED", frame, ClearOffers)
end
