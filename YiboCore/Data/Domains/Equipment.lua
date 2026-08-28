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
        return { itemLevel = itemLevel }, itemLevel and "known" or "unavailable"
    end,
    ProjectLegacy = function(record, data, domain)
        record.profile = record.profile or {}; record.profile.itemLevel = data.itemLevel
        record.observedAt = record.observedAt or {}; record.observedAt.itemLevel = domain.updatedAt
        record.availability = record.availability or {}; record.availability.itemLevel = domain.state
    end,
})
