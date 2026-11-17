local Core = _G.YiboCore

Core.DataDomains:Register("YiboCore", {
    id = "equipment", version = 1,
    events = { PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, PLAYER_EQUIPMENT_CHANGED = true },
    Collect = function()
        local itemLevel
        if C_PaperDollInfo and C_PaperDollInfo.GetAverageItemLevel then
            local average, equipped = C_PaperDollInfo.GetAverageItemLevel()
            itemLevel = equipped or average
        elseif GetAverageItemLevel then
            local average, equipped = GetAverageItemLevel()
            itemLevel = equipped or average
        end
        if not itemLevel or itemLevel <= 0 then
            local total, count = 0, 0
            local slots = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }
            for _, slot in ipairs(slots) do
                local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
                if link then
                    local _, _, _, ilvl = GetItemInfo(link)
                    if ilvl and ilvl > 0 then
                        total = total + ilvl
                        count = count + 1
                    end
                end
            end
            if count > 0 then itemLevel = total / count end
        end
        if itemLevel == nil or itemLevel <= 0 then return nil, "unavailable" end
        if type(itemLevel) ~= "number" or itemLevel ~= itemLevel or math.abs(itemLevel) == math.huge then return nil, "error" end
        return { itemLevel = itemLevel }, "known"
    end,
    ProjectLegacy = function(record, data, domain)
        record.profile = record.profile or {}
        record.observedAt = record.observedAt or {}
        if domain.state == "known" then record.profile.itemLevel = data.itemLevel; record.observedAt.itemLevel = domain.updatedAt end
        record.availability = record.availability or {}; record.availability.itemLevel = domain.state
    end,
})
