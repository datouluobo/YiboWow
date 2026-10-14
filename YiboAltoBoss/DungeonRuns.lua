if _G.YAB and _G.YAB.CoreReady == false then return end
local Runs = {}
YAB.DungeonRuns = Runs
local NORMAL_PROGRESS_TTL = 30 * 60

local function DisplayState(record, mapID, difficultyID)
    local state = (record.statistics.dungeonCycles or {})[tostring(mapID) .. ":" .. tostring(difficultyID)]
    if not state or difficultyID ~= 1 or next(state.completed or {}) == nil then return state end
    local now = (GetServerTime and GetServerTime()) or time()
    local currentKey = YAB.GetCurrentCharKey and YAB.GetCurrentCharKey()
    local currentRecord = _G.YiboAltoBossDB and _G.YiboAltoBossDB.characters
        and _G.YiboAltoBossDB.characters[currentKey]
    local inside = false
    if currentRecord == record and GetInstanceInfo then
        local _, kind, difficulty, _, maxPlayers, _, _, currentMap = GetInstanceInfo()
        inside = kind == "party" and difficulty == difficultyID and currentMap == mapID
            and tonumber(maxPlayers or 0) <= 5
    end
    if inside then
        -- A legacy active run gets a real observation time, not an invented exit.
        state.lastObservedAt = state.lastObservedAt or now
    elseif not state.outsideAt then
        local observed = state.lastObservedAt
        if not observed then
            for _, boss in pairs(record.statistics.bosses or {}) do
                if boss.instanceID == mapID and (boss.difficultyID or 1) == difficultyID and tonumber(boss.lastAt) then
                    observed = math.max(observed or 0, boss.lastAt)
                end
            end
        end
        -- Fallback freshness is based on existing evidence. Reading the cell
        -- must never start a fresh 30-minute window for an old completion.
        state.outsideAt = observed or (now - NORMAL_PROGRESS_TTL)
    end
    return state
end

local function DisplayStale(state, difficultyID)
    return state and next(state.completed or {}) ~= nil and difficultyID == 1 and state.outsideAt
        and ((GetServerTime and GetServerTime()) or time()) >= state.outsideAt + NORMAL_PROGRESS_TTL or false
end

function Runs:IsStale(record, mapID, difficultyID)
    return DisplayStale(DisplayState(record, mapID, difficultyID), difficultyID)
end

function Runs:Leave(record, mapID, difficultyID)
    if difficultyID ~= 1 then return end
    local state = (record.statistics.dungeonCycles or {})[tostring(mapID) .. ":1"]
    if not state then return end
    state.outsideAt = state.outsideAt or ((GetServerTime and GetServerTime()) or time())
    return state.outsideAt + NORMAL_PROGRESS_TTL
end

local function State(record, mapID, difficultyID, name)
    record.statistics.dungeonCycles = record.statistics.dungeonCycles or {}
    local key = tostring(mapID) .. ":" .. tostring(difficultyID)
    local states = record.statistics.dungeonCycles
    local state = states[key]
    if type(state) ~= "table" then
        state = { generation = 1, completed = {} }
        states[key] = state
    end
    state.completed = state.completed or {}
    state.generation = tonumber(state.generation) or 1
    state.name = name
    state.difficultyID = difficultyID
    local now = (GetServerTime and GetServerTime()) or time()
    if state.expiresAt and now >= state.expiresAt then
        state.generation = state.generation + 1
        state.resetGeneration = (tonumber(state.resetGeneration) or 0) + 1
        state.completed, state.scope, state.expiresAt = {}, nil, nil
    end
    for _, lockout in pairs(record.instanceLockouts or {}) do
        if lockout.instanceID == mapID and lockout.difficultyID == difficultyID
            and tonumber(lockout.resetAt) and lockout.resetAt > now then
            state.expiresAt = lockout.resetAt
            break
        end
    end
    return state
end

function Runs:Observe(record, mapID, difficultyID, name, guid)
    local state = State(record, mapID, difficultyID, name)
    local stale = DisplayStale(state, difficultyID)
    state.lastObservedAt = (GetServerTime and GetServerTime()) or time()
    -- Re-entering the actual instance revalidates its preserved run. A new
    -- GUID scope or a successful reset, rather than elapsed time, opens a run.
    if not stale then state.outsideAt = nil end
    if type(guid) == "string" then
        local server, map, instance = guid:match("^Creature%-%d+%-(%d+)%-(%d+)%-(%d+)%-")
        if tonumber(map) == mapID then
            state.outsideAt = nil
            local scope = server .. ":" .. map .. ":" .. instance
            if state.scope and state.scope ~= scope then
                state.generation = state.generation + 1
                state.completed = {}
            end
            state.scope = scope
        end
    end
    return state.generation, tonumber(state.resetGeneration) or 0
end

function Runs:Claim(record, mapID, difficultyID, name, identity, npcID, guid)
    self:Observe(record, mapID, difficultyID, name, guid)
    local state = State(record, mapID, difficultyID, name)
    local npcIdentity = npcID and ("npc:" .. npcID)
    if state.completed[identity] or npcIdentity and state.completed[npcIdentity] then return false end
    state.completed[identity] = true
    if npcIdentity then state.completed[npcIdentity] = true end
    return true
end

-- Completion projection of the existing run. Only legacy display timestamps
-- may be repaired; lifetime kill totals never determine current completion.
function Runs:GetProgress(record, mapID, difficultyID)
    local state = DisplayState(record, mapID, difficultyID)
    local now = (GetServerTime and GetServerTime()) or time()
    if not state or DisplayStale(state, difficultyID) or state.expiresAt and now >= state.expiresAt then return 0 end
    local aliases = {}
    for npcID, encounterID in pairs(YAB.DungeonBossCatalog[mapID] or {}) do
        if encounterID > 0 then aliases["npc:" .. npcID] = "encounter:" .. encounterID end
    end
    -- Client encounter IDs may have enriched the original imported facts.
    for _, boss in pairs(record.statistics.bosses or {}) do
        if boss.instanceID == mapID and boss.difficultyID == difficultyID
            and boss.npcID and boss.encounterID and boss.encounterID > 0 then
            aliases["npc:" .. boss.npcID] = "encounter:" .. boss.encounterID
        end
    end
    local seen, count = {}, 0
    for identity, completed in pairs(state.completed or {}) do
        if completed then
            local key = aliases[identity] or identity
            if not seen[key] then seen[key], count = true, count + 1 end
        end
    end
    return count
end

function Runs:IsCompleted(record, mapID, difficultyID, encounterID, npcID)
    local state = DisplayState(record, mapID, difficultyID)
    if not state or DisplayStale(state, difficultyID) or state.expiresAt and state.expiresAt <= ((GetServerTime and GetServerTime()) or time()) then return nil end
    local completed = state.completed or {}
    return (encounterID and completed["encounter:" .. encounterID] == true)
        or (npcID and completed["npc:" .. npcID] == true) or false
end

function Runs:Reset(record, name, difficultyID)
    for _, state in pairs(record.statistics.dungeonCycles or {}) do
        if state.name == name and state.difficultyID == difficultyID then
            state.generation = (tonumber(state.generation) or 1) + 1
            state.resetGeneration = (tonumber(state.resetGeneration) or 0) + 1
            state.completed, state.scope, state.expiresAt = {}, nil, nil
            state.outsideAt = nil
        end
    end
end
