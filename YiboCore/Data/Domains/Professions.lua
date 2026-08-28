local Core = _G.YiboCore

local PRIMARY_ICONS = {
    ["炼金"] = "Interface\\Icons\\Trade_Alchemy", ["炼金术"] = "Interface\\Icons\\Trade_Alchemy", ["锻造"] = "Interface\\Icons\\Trade_BlackSmithing",
    ["附魔"] = "Interface\\Icons\\Trade_Engraving", ["工程"] = "Interface\\Icons\\Trade_Engineering", ["草药"] = "Interface\\Icons\\Trade_Herbalism",
    ["铭文"] = "Interface\\Icons\\INV_Inscription_Tradeskill01", ["珠宝加工"] = "Interface\\Icons\\INV_Misc_Gem_01", ["珠宝"] = "Interface\\Icons\\INV_Misc_Gem_01",
    ["制皮"] = "Interface\\Icons\\Trade_LeatherWorking", ["裁缝"] = "Interface\\Icons\\Trade_Tailoring", ["采矿"] = "Interface\\Icons\\Trade_Mining", ["剥皮"] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
}

local function FallbackPrimary()
    local result = {}
    if not GetNumSkillLines or not GetSkillLineInfo then return result end
    for index = 1, GetNumSkillLines() do
        local name, header, _, level, _, _, maximum = GetSkillLineInfo(index)
        if not header and PRIMARY_ICONS[name] then result[#result + 1] = { name = name, icon = PRIMARY_ICONS[name], skillLevel = level, maxSkillLevel = maximum } end
    end
    return result
end

Core.DataDomains:Register("YiboCore", {
    id = "professions", version = 1,
    events = { PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, SKILL_LINES_CHANGED = true },
    Collect = function()
        if not GetProfessions or not GetProfessionInfo then return {}, "unavailable" end
        local professions, primary = {}, {}
        local slots = { GetProfessions() }
        for slot = 1, 6 do
            local index = slots[slot]
            if index then
                local name, icon, level, maximum, _, _, skillLine = GetProfessionInfo(index)
                local item = { id = skillLine, slot = slot, name = name, icon = icon, skillLevel = level, maxSkillLevel = maximum }
                professions[#professions + 1] = item
                if slot <= 2 then primary[slot] = Core.Defaults:Copy(item) end
            end
        end
        local nextSlot = 1
        for _, item in ipairs(FallbackPrimary()) do
            while nextSlot <= 2 and primary[nextSlot] do nextSlot = nextSlot + 1 end
            if nextSlot > 2 then break end
            primary[nextSlot], nextSlot = item, nextSlot + 1
        end
        return { professions = professions, primaryProfessions = primary }, "known"
    end,
    ProjectLegacy = function(record, data, domain)
        record.profile = record.profile or {}; record.profile.professions, record.profile.primaryProfessions = data.professions, data.primaryProfessions
        record.observedAt = record.observedAt or {}; record.observedAt.professions = domain.updatedAt
        record.availability = record.availability or {}; record.availability.professions = domain.state
    end,
})
