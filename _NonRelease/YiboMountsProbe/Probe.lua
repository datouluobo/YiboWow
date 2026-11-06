local ADDON_NAME, NS = ...
local initialized = false
local npcTooltip, questTooltip

local function Print(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r " .. NS:T("prefix") .. tostring(text)) end
end

local function IsSupportedClient()
    return type(WOW_PROJECT_MISTS_CLASSIC) == "number" and WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC
end

local function GetJournal()
    local journal = C_MountJournal
    if journal and type(journal.GetMountIDs) == "function" and type(journal.GetMountInfoByID) == "function" then return journal end
end

local function CaptureInventory()
    if not IsSupportedClient() then Print(NS:T("wrongClient")); return end
    local journal = GetJournal()
    if not journal then Print(NS:T("apiMissing")); return end
    local ok, mountIDs = pcall(journal.GetMountIDs)
    if not ok or type(mountIDs) ~= "table" then Print(NS:T("apiMissing")); return end
    local records, spellIDs = {}, {}
    for _, mountJournalID in ipairs(mountIDs) do
        local result = { pcall(journal.GetMountInfoByID, mountJournalID) }
        local callOK = table.remove(result, 1)
        if callOK then
            local name, spellID, icon, isActive, isUsable, sourceType, isFavorite,
                isFactionSpecific, faction, shouldHideOnChar, isCollected, mountType = unpack(result)
            if type(spellID) == "number" and not spellIDs[spellID] then
                spellIDs[spellID] = true
                local description, sourceText
                if type(journal.GetMountInfoExtraByID) == "function" then
                    local extra = { pcall(journal.GetMountInfoExtraByID, mountJournalID) }
                    if table.remove(extra, 1) then _, description, sourceText = unpack(extra) end
                end
                records[#records + 1] = {
                    mountJournalID = mountJournalID, name = name, spellID = spellID, icon = icon,
                    isActive = isActive, isUsable = isUsable, sourceType = sourceType,
                    isFavorite = isFavorite, isFactionSpecific = isFactionSpecific,
                    faction = faction, shouldHideOnChar = shouldHideOnChar,
                    isCollected = isCollected, mountType = mountType,
                    description = description, sourceText = sourceText,
                }
            end
        end
    end
    table.sort(records, function(left, right) return left.spellID < right.spellID end)
    local _, _, _, interface = GetBuildInfo()
    YiboMountsProbeDB = YiboMountsProbeDB or {}
    YiboMountsProbeDB.inventory = { interface = tonumber(interface), count = #records, mounts = records }
    Print(NS:T("inventorySaved"))
end

local function GetProbeTooltip(kind)
    local tooltip = kind == "npc" and npcTooltip or questTooltip
    if tooltip then return tooltip end
    local name = kind == "npc" and "YiboMountsProbeNPCTooltip" or "YiboMountsProbeQuestTooltip"
    tooltip = _G[name] or CreateFrame("GameTooltip", name, UIParent, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if kind == "npc" then npcTooltip = tooltip else questTooltip = tooltip end
    return tooltip
end

local function TooltipName(tooltip)
    local region = _G[tooltip:GetName() .. "TextLeft1"]
    return region and region:GetText() or nil
end

local function ResolveNPC(id)
    local tooltip = GetProbeTooltip("npc")
    local ok = pcall(tooltip.SetHyperlink, tooltip, ("unit:Creature-0-0-0-0-%d-0000000000"):format(id))
    local value = ok and TooltipName(tooltip) or nil
    tooltip:Hide()
    return value
end

local function ResolveQuest(id)
    if C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function" then
        local ok, value = pcall(C_QuestLog.GetTitleForQuestID, id)
        if ok and value then return value end
    end
    local tooltip = GetProbeTooltip("quest")
    local ok = pcall(tooltip.SetHyperlink, tooltip, "quest:" .. tostring(id))
    local value = ok and TooltipName(tooltip) or nil
    tooltip:Hide()
    return value
end

local function Resolve(kind, id)
    if kind == "npcIDs" then return ResolveNPC(id) end
    if kind == "questIDs" then return ResolveQuest(id) end
    if kind == "mapIDs" then
        local info = C_Map and C_Map.GetMapInfo
        if type(info) == "function" then local ok, row = pcall(info, id); return ok and row and row.name or nil end
    elseif kind == "achievementIDs" and type(GetAchievementInfo) == "function" then
        local ok, first, second = pcall(GetAchievementInfo, id)
        if ok then return type(first) == "string" and first or type(second) == "string" and second or nil end
    elseif kind == "instanceIDs" and type(EJ_GetInstanceInfo) == "function" then
        local ok, value = pcall(EJ_GetInstanceInfo, id); return ok and value or nil
    elseif kind == "encounterIDs" and type(EJ_GetEncounterInfo) == "function" then
        local ok, value = pcall(EJ_GetEncounterInfo, id); return ok and value or nil
    elseif kind == "factionIDs" and type(GetFactionInfoByID) == "function" then
        local ok, value = pcall(GetFactionInfoByID, id); return ok and value or nil
    end
end

local function CaptureSourceNames()
    if not IsSupportedClient() then Print(NS:T("wrongClient")); return end
    local output, seen = {}, {}
    for _, hints in pairs(NS.SourceFacts or {}) do
        for _, hint in ipairs(hints) do
            for _, field in ipairs({ "npcIDs", "mapIDs", "achievementIDs", "questIDs", "instanceIDs", "encounterIDs", "factionIDs" }) do
                for _, id in ipairs(hint[field] or {}) do
                    local key = field .. ":" .. tostring(id)
                    if not seen[key] then seen[key] = true; output[key] = Resolve(field, id) end
                end
            end
        end
    end
    YiboMountsProbeDB = YiboMountsProbeDB or {}
    YiboMountsProbeDB.sourceNames = output
    Print(NS:T("sourcesSaved"))
end

local function CaptureTooltip()
    if not IsSupportedClient() then Print(NS:T("wrongClient")); return end
    local tooltip = GameTooltip
    local unit, spellID
    if tooltip and type(tooltip.GetUnit) == "function" then local _, token = tooltip:GetUnit(); unit = token end
    if tooltip and type(tooltip.GetSpell) == "function" then local _, _, value = tooltip:GetSpell(); spellID = value end
    if not unit or type(UnitExists) ~= "function" or not UnitExists(unit) then Print(NS:T("tooltipMissing")); return end
    local journal, mountSpells = GetJournal(), {}
    if journal then
        local ok, ids = pcall(journal.GetMountIDs)
        if ok and type(ids) == "table" then
            for _, id in ipairs(ids) do
                local success, _, nativeSpellID = pcall(journal.GetMountInfoByID, id)
                if success and type(nativeSpellID) == "number" then mountSpells[nativeSpellID] = true end
            end
        end
    end
    local scanned, matches = 0, 0
    for index = 1, 80 do
        local auraName, _, _, _, _, _, _, _, _, auraSpellID
        if type(UnitAura) == "function" then auraName, _, _, _, _, _, _, _, _, auraSpellID = UnitAura(unit, index, "HELPFUL")
        elseif C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function" then
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")
            if aura then auraName, auraSpellID = aura.name, aura.spellId end
        end
        if not auraName then break end
        scanned = scanned + 1
        if mountSpells[auraSpellID] then matches = matches + 1 end
    end
    Print(string.format(NS:T("tooltipSummary"), tostring(unit), tostring(spellID), scanned, matches))
end

local function ReportStatus()
    local value = YiboMountsProbeDB and YiboMountsProbeDB.inventory
    if not value then Print(NS:T("statusEmpty")); return end
    Print(string.format(NS:T("status"), value.count or 0, tostring(value.interface)))
end

local function Initialize()
    if initialized then return end
    initialized = true
    SLASH_YIBOMOUNTSPROBE1 = "/ymp"
    SlashCmdList.YIBOMOUNTSPROBE = function(message)
        local command = tostring(message or ""):match("^%s*(%S+)") or ""
        if command == "inventory" then CaptureInventory()
        elseif command == "sources" then CaptureSourceNames()
        elseif command == "tooltip" then CaptureTooltip()
        elseif command == "status" then ReportStatus()
        else Print(NS:T("help")) end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, name)
    if event ~= "ADDON_LOADED" or name ~= ADDON_NAME then return end
    if not IsSupportedClient() then Print(NS:T("wrongClient")); return end
    Initialize()
end)
