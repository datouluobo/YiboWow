if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB, Core = _G.YAB, _G.YiboCore
local Runtime = {}
YAB.TargetCatalogRuntime = Runtime
local DIFFICULTIES = { 1, 2, 3, 4, 5, 6, 7, 9, 14, 15, 16, 17, 175, 176 }
-- Mists legacy TBC raid identities, shared by the catalog, existing goals and
-- native lockouts. Other raids retain their own exact difficulty identities.
local TBC_RAIDS = { [580] = true, [564] = true, [534] = true, [550] = true,
    [548] = true, [544] = true, [565] = true, [532] = true }
function Runtime:CanonicalDifficulty(mapID, id)
    if TBC_RAIDS[tonumber(mapID)] then
        if id == 3 then return 175 end
        if id == 4 then return 176 end
    end
    return id
end
local function Copy(value) return Core.Defaults:Copy(value) end
local function Text(key) return Core.Locale:Get("YiboAltoBoss", key) end
local function Aliases(key)
    local result = {}
    for name in Text(key):gmatch("[^;]+") do result[#result + 1] = name end
    return result
end
local function Matches(encounter, name)
    if encounter.name == name then return true end
    for _, alias in ipairs(encounter.aliases or {}) do if alias == name then return true end end
    return false
end
local function StaticDirectory(mapID)
    local static = YAB.RaidCatalog[mapID]
    if not static then return end
    local encounters, finalID = {}, static.finalID
    -- Retain existing player goal identities by mapping the old directory's
    -- names to canonical entries. Its count and order are never authoritative.
    local legacy = YiboAltoBossDB.targetLegacyDirectories and YiboAltoBossDB.targetLegacyDirectories[mapID]
    for _, boss in ipairs(static.encounters) do
        local item = Copy(boss)
        item.name = Text(item.nameKey)
        item.aliases = Aliases(item.aliasesKey)
        YAB.TargetCatalog:EnrichEncounterAliases(item)
        for _, difficulty in pairs(legacy and legacy.difficulties or {}) do
            for _, old in ipairs(difficulty.encounters or {}) do
                if Matches(item, old.name) then item.id = old.id; break end
            end
        end
        if boss.id == static.finalID then finalID = item.id end
        encounters[#encounters + 1] = item
    end
    local difficulties = {}
    for _, id in ipairs(static.difficulties) do
        local nativeID = Runtime:CanonicalDifficulty(mapID, id)
        difficulties[#difficulties + 1] = { id = nativeID, name = Text("RAID.DIFFICULTY." .. nativeID),
            encounters = Copy(encounters), finalEncounterID = finalID, complete = true, trackable = true }
    end
    return difficulties
end
local function Encounters(journalID)
    local result, seen = {}, {}
    if not EJ_GetEncounterInfoByIndex then return result, false end
    for index = 1, 100 do
        local name, _, journalEncounterID, _, _, _, nativeID = EJ_GetEncounterInfoByIndex(index, journalID)
        if not name then return result, #result > 0 end
        if type(journalEncounterID) ~= "number" or journalEncounterID <= 0 then return result, false end
        -- JournalEncounterID and DungeonEncounterID are separate namespaces.
        -- Some client records expose only the former. Keep their complete list
        -- under a namespaced business identity rather than rejecting the raid.
        local id = type(nativeID) == "number" and nativeID > 0 and nativeID or ("journal-encounter:" .. journalEncounterID)
        if seen[id] then return result, false end
        seen[id] = true
        result[#result + 1] = { id = id, journalID = journalEncounterID, name = name }
    end
    return result, false
end
local function JournalTiers()
    local tiers = {}
    if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex) then return tiers end
    for tier = 1, EJ_GetNumTiers() do
        EJ_SelectTier(tier)
        for _, raid in ipairs({ false, true }) do
            for index = 1, 200 do
                local id = EJ_GetInstanceByIndex(index, raid)
                if not id then break end
                tiers[id] = tier
            end
        end
    end
    return tiers
end
function Runtime:BuildInstances()
    local result = {}
    -- Journal APIs and cached instance lists can be unavailable until its UI
    -- addon loads. Load only Blizzard's declared addon; never open its window.
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    local journalLoaded = isLoaded and isLoaded("Blizzard_EncounterJournal") or EncounterJournal ~= nil
    if not journalLoaded then
        local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
        if load then
            local ok, loaded = pcall(load, "Blizzard_EncounterJournal")
            if ok and loaded and YAB.InvalidateInstanceCatalog then YAB.InvalidateInstanceCatalog() end
        end
    end
    local oldTier = EJ_GetCurrentTier and EJ_GetCurrentTier()
    local oldInstance = EJ_GetCurrentInstance and EJ_GetCurrentInstance()
    local oldDifficulty = EJ_GetDifficulty and EJ_GetDifficulty()
    local tiers = JournalTiers()
    for _, item in pairs(YAB.GetInstanceCatalog()) do
        local journalID = item.key and tonumber(item.key:match("^ej:(%d+)$"))
        local mapID = item.mapID or (not journalID and item.instanceID)
        if journalID and EJ_GetInstanceInfo then mapID = select(10, EJ_GetInstanceInfo(journalID)) or mapID end
        if type(mapID) ~= "number" or mapID <= 0 then mapID = nil end
        local id = journalID and ("journal:" .. journalID) or mapID and ("instance:" .. mapID)
        if id then
            local entry = { id = id, kind = "instance", name = item.name, expansion = item.expansion,
                abbreviation = item.abbreviation, journalID = journalID, mapID = mapID, isRaid = item.isRaid,
                difficulties = {}, complete = false, available = mapID ~= nil }
            if journalID and EJ_SelectInstance and EJ_SetDifficulty and EJ_IsValidInstanceDifficulty then
                if tiers[journalID] and EJ_SelectTier then EJ_SelectTier(tiers[journalID]) end
                EJ_SelectInstance(journalID)
                local seenDifficulties = {}
                for _, difficultyID in ipairs(DIFFICULTIES) do
                    if EJ_IsValidInstanceDifficulty(difficultyID) then
                        EJ_SetDifficulty(difficultyID)
                        local encounters, complete = Encounters(journalID)
                        local canonicalID = self:CanonicalDifficulty(mapID, difficultyID)
                        local name = TBC_RAIDS[mapID] and (canonicalID == 175 or canonicalID == 176) and Text("RAID.DIFFICULTY." .. canonicalID)
                            or (GetDifficultyInfo and GetDifficultyInfo(difficultyID))
                        local difficulty = { id = canonicalID, name = name or (Text("UI.DIFFICULTY") .. canonicalID),
                            encounters = encounters, complete = complete, trackable = difficultyID ~= 1 }
                        if not seenDifficulties[canonicalID] then
                            entry.difficulties[#entry.difficulties + 1] = difficulty
                            seenDifficulties[canonicalID] = true
                        end
                        if complete then entry.complete = true end
                    end
                end
            end
            -- A maintained Mists directory supplies all legacy choices before
            -- the character has entered the raid or acquired a lockout.
            local static = StaticDirectory(mapID)
            if static and not journalID then
                entry.difficulties, entry.complete = static, true
            elseif static then
                for _, difficulty in ipairs(entry.difficulties) do
                    for _, expected in ipairs(static) do if expected.id == difficulty.id then
                        if not difficulty.complete or #difficulty.encounters ~= #expected.encounters then
                            difficulty.encounters = Copy(expected.encounters)
                            difficulty.complete, difficulty.finalEncounterID = true, expected.finalEncounterID
                        else
                            local final
                            for _, e in ipairs(expected.encounters) do if e.id == expected.finalEncounterID then final = e end end
                            for _, e in ipairs(difficulty.encounters) do if final and Matches(final, e.name) then difficulty.finalEncounterID = e.id end end
                        end
                    end end
                end
                if #entry.difficulties == 0 then entry.difficulties = static end
                entry.complete = true
            end
            local finalKey = YAB.RaidFinalNames[mapID]
            if finalKey then
                for _, difficulty in ipairs(entry.difficulties) do
                    local names = Aliases(finalKey)
                    if mapID == 671 and (difficulty.id == 5 or difficulty.id == 6) then names = Aliases("RAID.FINAL.SINESTRA") end
                    for _, encounter in ipairs(difficulty.encounters) do
                        for _, name in ipairs(names) do if encounter.name == name then difficulty.finalEncounterID = encounter.id end end
                    end
                end
            end
            if not mapID then entry.complete = false end
            entry.reason = not entry.complete and Text("UI.CATALOG_UNCONFIRMED_VISIT_THE_INSTANCE_OR_REFRESH_RAID_INFORMATION_FIRST") or nil
            result[#result + 1] = entry
        end
    end
    if oldTier and EJ_SelectTier then EJ_SelectTier(oldTier) end
    if oldInstance and EJ_SelectInstance then EJ_SelectInstance(oldInstance) end
    if oldDifficulty and EJ_SetDifficulty then EJ_SetDifficulty(oldDifficulty) end
    return result
end
