if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB, Core = _G.YAB, _G.YiboCore
local Events = {}
YAB.RaidEvents = Events
local frame = CreateFrame("Frame")
local function Instance()
    local _, kind, difficultyID, _, _, _, _, mapID = GetInstanceInfo()
    if kind == "raid" then return mapID, YAB.TargetCatalogRuntime:CanonicalDifficulty(mapID, difficultyID) end
end
local function CurrentID()
    local character = Core.Characters:GetCurrent({ identityOnly = true })
    return character and character.id
end
function Events:Sync()
    local mapID = Instance()
    if mapID == 580 then frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end
end
function Events:Observe(event, encounterID, encounterName, eventDifficulty, _, success)
    if not self.started then return end
    local mapID, difficultyID = Instance()
    if not mapID then return end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, _, _, _, _, guid = CombatLogGetCurrentEventInfo()
        local npcID = type(guid) == "string" and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
        -- Kil'jaeden's final creature death is unambiguous. Multi-creature and
        -- surrender encounters require their native success event instead.
        if mapID ~= 580 or subevent ~= "UNIT_DIED" or npcID ~= 25315 then return end
        for _, definition in ipairs(YAB.TargetCatalog:Query().targets) do if definition.mapID == mapID then
            for _, difficulty in ipairs(definition.difficulties) do if difficulty.id == difficultyID then
                local id = CurrentID()
                if id and difficulty.finalEncounterID then return YAB.RaidProgress:Observe(id, mapID, difficultyID, difficulty.finalEncounterID) end
            end end
        end end
        return
    end
    if event ~= "BOSS_KILL" and (event ~= "ENCOUNTER_END" or tonumber(success) ~= 1) then return end
    if eventDifficulty and YAB.TargetCatalogRuntime:CanonicalDifficulty(mapID, eventDifficulty) ~= difficultyID then return end
    local stableID
    for _, definition in ipairs(YAB.TargetCatalog:Query().targets) do if definition.mapID == mapID then
        for _, difficulty in ipairs(definition.difficulties) do if difficulty.id == difficultyID then
            for _, boss in ipairs(difficulty.encounters) do
                if boss.id == encounterID then stableID = boss.id end
                for _, nativeID in ipairs(boss.nativeEncounterIDs or {}) do if nativeID == encounterID then stableID = boss.id end end
            end
        end end
    end end
    stableID = stableID or YAB.TargetCatalog:ResolveSavedEncounter(mapID, difficultyID, encounterName)
    local id = CurrentID()
    if id and stableID then return YAB.RaidProgress:Observe(id, mapID, difficultyID, stableID) end
end
function Events:Start()
    if self.started then return end
    self.started = true
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS", "ENCOUNTER_END", "BOSS_KILL" }) do frame:RegisterEvent(event) end
    if GetInstanceInfo then self:Sync() end
end
function Events:Stop() self.started = false; frame:UnregisterAllEvents() end
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED_INDOORS" then Events:Sync()
    else Events:Observe(event, ...) end
end)
