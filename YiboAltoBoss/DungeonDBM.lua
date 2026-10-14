if _G.YAB and _G.YAB.CoreReady == false then return end
-- Optional external signal adapter. DBM module objects are callback payloads;
-- only id/encounterId are inspected, and neither is trusted without our directory.
local YAB, Core = _G.YAB, _G.YiboCore
if not YAB.LockoutLocaleReady or not Core.HasCapability or not Core:HasCapability("events", 1)
    or not Core:HasCapability("character-identity", 1)
    or not Core.Characters or type(Core.Characters.GetCurrentID) ~= "function"
    or not Core.Events or type(Core.Events.FireIsolated) ~= "function"
    or type(Core.Events.Register) ~= "function" or type(Core.Events.Unregister) ~= "function" then return end
if YAB.DungeonDBM and YAB.DungeonDBM.Shutdown then YAB.DungeonDBM:Shutdown() end
local Bridge = { eventName = "YIBOALTOBOSS_DUNGEON_COMPLETED", version = 1, active = {} }
YAB.DungeonDBM = Bridge

local function Current()
    local name, kind, difficultyID, _, maxPlayers, _, _, mapID = GetInstanceInfo()
    maxPlayers = tonumber(maxPlayers)
    if kind ~= "party" or not maxPlayers or maxPlayers < 1 or maxPlayers > 5 then return end
    if not YAB.GetDungeonRunToken then return end
    local run, reset = YAB.GetDungeonRunToken()
    local characterID = Core.Characters:GetCurrentID()
    if not run or not characterID then return end
    return { mapID = mapID, difficultyID = difficultyID, run = run, reset = reset, characterID = characterID }
end

local function Resolve(mod, context)
    if type(mod) ~= "table" or not YAB.TargetCatalog then return end
    local nativeID, journalID = tonumber(mod.encounterId), tonumber(mod.id)
    if not nativeID and not journalID then return end
    local found
    for _, target in ipairs(YAB.TargetCatalog:Query().targets or {}) do
        if target.kind == "instance" and target.mapID == context.mapID then
            for _, difficulty in ipairs(target.difficulties or {}) do
                if difficulty.id == context.difficultyID and difficulty.complete then
                    for _, encounter in ipairs(difficulty.encounters or {}) do
                        if (nativeID and encounter.id == nativeID)
                            or (journalID and encounter.journalID == journalID) then
                            if found and found.id ~= encounter.id then return end
                            found = encounter
                        end
                    end
                end
            end
        end
    end
    if found and type(found.id) == "number" and found.id > 0 and type(found.name) == "string" then
        return found.id, found.name
    end
end

local function OnPull(_, mod)
    Bridge.active[mod or false] = nil
    if Bridge.testUntil and GetTime() < Bridge.testUntil then return end
    if not UnitAffectingCombat then return end
    local fighting = UnitAffectingCombat("player")
    for index = 1, 4 do fighting = fighting or UnitAffectingCombat("party" .. index) end
    if not fighting then return end
    local context = Current()
    if not context then return end
    local ok, encounterID, name = pcall(Resolve, mod, context)
    if not ok or not encounterID then return end
    context.encounterID, context.name = encounterID, name
    Bridge.active[mod] = context
end

local function OnKill(_, mod)
    local pull = Bridge.active[mod or false]
    Bridge.active[mod or false] = nil
    if not pull then return end
    local context = Current()
    if not context or context.characterID ~= pull.characterID or context.mapID ~= pull.mapID
        or context.difficultyID ~= pull.difficultyID or context.reset ~= pull.reset then return end
    Core.Events:FireIsolated(Bridge.eventName, {
        version = 1, source = "DBM", characterID = pull.characterID, mapID = pull.mapID,
        difficultyID = pull.difficultyID, run = context.run,
        encounterID = pull.encounterID, name = pull.name,
    })
end

local function OnWipe(_, mod) Bridge.active[mod or false] = nil end
local function OnTest()
    Bridge.active = {}
    Bridge.testUntil = GetTime() + 60
end
local callbacks = {
    DBM_Pull = OnPull, DBM_Kill = OnKill, DBM_Wipe = OnWipe, DBM_TestModStarted = OnTest,
}

local function Consume(_, fact)
    if type(fact) ~= "table" or fact.version ~= 1 or fact.source ~= "DBM"
        or type(fact.encounterID) ~= "number" or fact.encounterID <= 0
        or type(fact.name) ~= "string" or fact.name == "" then return end
    local context = Current()
    if not context or context.characterID ~= fact.characterID or context.mapID ~= fact.mapID
        or context.difficultyID ~= fact.difficultyID or context.run ~= fact.run then return end
    YAB.RecordEncounterKill(fact.name, fact.encounterID, { source = "DBM" })
end

function Bridge:Detach()
    if self.dbm then
        for event, callback in pairs(callbacks) do pcall(self.dbm.UnregisterCallback, self.dbm, event, callback) end
    end
    self.dbm, self.active = nil, {}
end

function Bridge:Attach()
    local dbm = _G.DBM
    if self.dbm == dbm and dbm then return true end
    self:Detach()
    if type(dbm) ~= "table" or type(dbm.RegisterCallback) ~= "function"
        or type(dbm.UnregisterCallback) ~= "function" then return false end
    self.dbm = dbm
    for event, callback in pairs(callbacks) do
        local ok = pcall(dbm.RegisterCallback, dbm, event, callback)
        if not ok then self:Detach(); return false end
    end
    return true
end

function Bridge:Shutdown()
    self:Detach()
    Core.Events:Unregister(self.eventName, "YiboAltoBoss:DBM", Consume)
    self.frame:UnregisterAllEvents()
end

Core.Events:Register(Bridge.eventName, "YiboAltoBoss:DBM", Consume)
Bridge.frame = CreateFrame("Frame")
Bridge.frame:RegisterEvent("ADDON_LOADED")
Bridge.frame:RegisterEvent("PLAYER_LOGIN")
Bridge.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
Bridge.frame:SetScript("OnEvent", function(_, event, addon)
    if event == "PLAYER_ENTERING_WORLD" then Bridge.active = {}; return end
    if event == "PLAYER_LOGIN" or addon == "DBM-Core" then Bridge:Attach() end
end)
Bridge:Attach()
