local _, NS = ...

NS.SourceFactProbe = {}

local function NPCName(id)
    local tooltip = CreateFrame("GameTooltip", "YiboMountSourceNameProbe", UIParent, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(("unit:Creature-0-0-0-0-%d-0000000000"):format(id))
    local name = _G[tooltip:GetName() .. "TextLeft1"]
    local value = name and name:GetText() or nil
    tooltip:Hide()
    return value
end

local function MapName(id)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
    return info and info.name or nil
end

local function AchievementName(id)
    if not GetAchievementInfo then return nil end
    local first, second = GetAchievementInfo(id)
    if type(first) == "string" then return first end
    return type(second) == "string" and second or nil
end

local function QuestName(id)
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local title = C_QuestLog.GetTitleForQuestID(id)
        if title then return title end
    end
    local tooltip = CreateFrame("GameTooltip", "YiboMountSourceQuestProbe", UIParent, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink("quest:" .. tostring(id))
    local name = _G[tooltip:GetName() .. "TextLeft1"]
    local value = name and name:GetText() or nil
    tooltip:Hide()
    return value
end

local function InstanceName(id)
    if EJ_GetInstanceInfo then
        local name = EJ_GetInstanceInfo(id)
        return name
    end
    return nil
end

local function EncounterName(id)
    if EJ_GetEncounterInfo then
        local name = EJ_GetEncounterInfo(id)
        return name
    end
    return nil
end

local function ProfessionName(id)
    -- These are profession skill-line IDs, not spell IDs.  Using GetSpellInfo
    -- here would produce unrelated abilities (for example ID 202).
    local names = {
        [164] = "锻造", [165] = "制皮", [171] = "炼金术", [182] = "草药学",
        [186] = "采矿", [197] = "裁缝", [202] = "工程学", [333] = "附魔",
        [356] = "钓鱼", [393] = "剥皮", [755] = "珠宝加工", [773] = "铭文",
        [794] = "考古学",
    }
    return names[id]
end

local function FactionName(id)
    if GetFactionInfoByID then
        local name = GetFactionInfoByID(id)
        return name
    end
    return nil
end

local function AppendResolved(result, field, id, resolver)
    result[field] = result[field] or {}
    if result[field][id] == nil then result[field][id] = resolver(id) end
end

function NS.SourceFactProbe:Capture()
    local result = {}
    for spellID, hints in pairs(NS.SourceFacts or {}) do
        local names = {}
        for _, hint in ipairs(hints) do
            for _, npcID in ipairs(hint.npcIDs or {}) do
                AppendResolved(names, "npcNames", npcID, NPCName)
            end
            for _, mapID in ipairs(hint.mapIDs or {}) do
                AppendResolved(names, "mapNames", mapID, MapName)
            end
            for _, achievementID in ipairs(hint.achievementIDs or {}) do
                AppendResolved(names, "achievementNames", achievementID, AchievementName)
            end
            for _, questID in ipairs(hint.questIDs or {}) do
                AppendResolved(names, "questNames", questID, QuestName)
            end
            for _, instanceID in ipairs(hint.instanceIDs or {}) do
                AppendResolved(names, "instanceNames", instanceID, InstanceName)
            end
            for _, encounterID in ipairs(hint.encounterIDs or {}) do
                AppendResolved(names, "encounterNames", encounterID, EncounterName)
            end
            for _, professionID in ipairs(hint.professionIDs or {}) do
                AppendResolved(names, "professionNames", professionID, ProfessionName)
            end
            for _, factionID in ipairs(hint.factionIDs or {}) do
                AppendResolved(names, "factionNames", factionID, FactionName)
            end
        end
        result[spellID] = names
    end
    YiboMountSourceDiagnostics = YiboMountSourceDiagnostics or {}
    YiboMountSourceDiagnostics.sourceFactNames = result
    return result
end
