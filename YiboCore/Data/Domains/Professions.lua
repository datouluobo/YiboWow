local Core = _G.YiboCore

-- Client-native aliases are input matching data, never plugin display resources.
-- Skill-line IDs remain the identity even when the plugin language is overridden.
local PRIMARY_PROFESSIONS = {
    { id = 171, spell = 2259, icon = "Trade_Alchemy", aliases = { "Alchemy", "炼金", "炼金术", "鍊金術", "煉金術" } },
    { id = 164, spell = 2018, icon = "Trade_BlackSmithing", aliases = { "Blacksmithing", "锻造", "鍛造" } },
    { id = 333, spell = 7411, icon = "Trade_Engraving", aliases = { "Enchanting", "附魔" } },
    { id = 202, spell = 4036, icon = "Trade_Engineering", aliases = { "Engineering", "工程", "工程学", "工程學" } },
    { id = 182, spell = 2366, icon = "Trade_Herbalism", aliases = { "Herbalism", "草药", "草药学", "草藥學" } },
    { id = 773, spell = 45357, icon = "INV_Inscription_Tradeskill01", aliases = { "Inscription", "铭文", "銘文學" } },
    { id = 755, spell = 25229, icon = "INV_Misc_Gem_01", aliases = { "Jewelcrafting", "珠宝加工", "珠宝", "珠寶設計" } },
    { id = 165, spell = 2108, icon = "Trade_LeatherWorking", aliases = { "Leatherworking", "制皮", "製皮" } },
    { id = 197, spell = 3908, icon = "Trade_Tailoring", aliases = { "Tailoring", "裁缝", "裁縫" } },
    { id = 186, spell = 2575, icon = "Trade_Mining", aliases = { "Mining", "采矿", "採礦" } },
    { id = 393, spell = 8613, icon = "INV_Misc_Pelt_Wolf_01", aliases = { "Skinning", "剥皮", "剝皮" } },
}
local function NativeProfessions()
    local names = {}
    for _, profession in ipairs(PRIMARY_PROFESSIONS) do
        for _, alias in ipairs(profession.aliases) do names[alias] = profession end
        local name = GetSpellInfo and GetSpellInfo(profession.spell)
        if name then names[name] = profession end
    end
    return names
end

local function FallbackPrimary()
    local result = {}
    if not GetNumSkillLines or not GetSkillLineInfo then return result end
    local names = NativeProfessions()
    for index = 1, GetNumSkillLines() do
        local name, header, _, level, _, _, maximum = GetSkillLineInfo(index)
        local profession = not header and names[name]
        if profession then
            result[#result + 1] = { id = profession.id, name = name, icon = "Interface\\Icons\\" .. profession.icon, skillLevel = level, maxSkillLevel = maximum }
        end
    end
    return result
end

Core.DataDomains:Register("YiboCore", {
    id = "professions", version = 1,
    events = { PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, SKILL_LINES_CHANGED = true },
    Collect = function()
        if not GetProfessions or not GetProfessionInfo then
            local primary = FallbackPrimary()
            return { professions = primary, primaryProfessions = Core.Defaults:Copy(primary) }, #primary > 0 and "known" or "unavailable"
        end
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
