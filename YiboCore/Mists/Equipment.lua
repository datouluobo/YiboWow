local Core = _G.YiboCore

Core.DataDomains:Register("YiboCore", {
    id = "equipment", version = 1,
    events = { PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, PLAYER_EQUIPMENT_CHANGED = true },
    Collect = function()
        local itemLevel
        if C_PaperDollInfo and C_PaperDollInfo.GetAverageItemLevel then
            local average, equipped = C_PaperDollInfo.GetAverageItemLevel(); itemLevel = equipped or average
        elseif GetAverageItemLevel then
            local average, equipped = GetAverageItemLevel(); itemLevel = equipped or average
        end
        if itemLevel == nil then return nil, "unavailable" end
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
