local Addon = _G.YiboCrafting
local Core = _G.YiboCore
local Scanner = {}
Addon.RecipeStateScanner = Scanner

local scanSequence = 0
local BATCH_SIZE = 100
local activeKey, completedKey
local cachedCatalog, cachedVersion, cachedIDs

local function Milliseconds()
    if GetTimePreciseSec then return GetTimePreciseSec() * 1000 end
    if debugprofilestop then return debugprofilestop() end
    return GetTime and GetTime() * 1000 or 0
end

local function CurrentProfessionIDs(characterID)
    local domain = Core.DataDomains:Get(characterID, "professions")
    if not domain or domain.state ~= "known" or type(domain.data) ~= "table" then return nil end
    local result = {}
    for _, profession in ipairs(domain.data.professions or {}) do
        if type(profession.id) == "number" and profession.id > 0 then result[profession.id] = true end
    end
    return result
end

local function RecipeIDs(recipes)
    local ids = {}
    for recipeID in pairs(recipes or {}) do
        recipeID = tonumber(recipeID)
        if recipeID and recipeID > 0 and recipeID % 1 == 0 then ids[#ids + 1] = recipeID end
    end
    table.sort(ids)
    return ids
end

function Scanner:Start(reason, retryCount)
    local catalog = Addon.RecipeCatalog
    local characterID = Core and Core.Characters and Core.Characters.GetCurrentID and Core.Characters:GetCurrentID()
    if not catalog or type(catalog.professions) ~= "table" or type(catalog.catalogVersion) ~= "string"
        or type(characterID) ~= "string" or characterID == "" or type(_G.IsPlayerSpell) ~= "function" then
        return nil, "scan-unavailable"
    end
    local ownedProfessions = CurrentProfessionIDs(characterID)
    if not ownedProfessions then
        retryCount = retryCount or 0
        if retryCount < 3 and C_Timer and C_Timer.After then
            local retrySequence = scanSequence
            C_Timer.After(2, function()
                if retrySequence == scanSequence then self:Start(reason, retryCount + 1) end
            end)
        end
        return nil, "profession-domain-unavailable"
    end

    if cachedCatalog ~= catalog or cachedVersion ~= catalog.catalogVersion then
        cachedCatalog, cachedVersion, cachedIDs = catalog, catalog.catalogVersion, {}
    end
    local jobs, professionKeys = {}, {}
    for professionID, recipes in pairs(catalog.professions) do
        professionID = tonumber(professionID)
        if professionID and ownedProfessions[professionID] then
            cachedIDs[professionID] = cachedIDs[professionID] or RecipeIDs(recipes)
            local ids = cachedIDs[professionID]
            if #ids > 0 then jobs[#jobs + 1] = { professionID = professionID, ids = ids } end
        end
    end
    table.sort(jobs, function(a, b) return a.professionID < b.professionID end)
    if #jobs == 0 then return nil, "no-catalog-for-owned-profession" end
    for _, job in ipairs(jobs) do professionKeys[#professionKeys + 1] = job.professionID end
    local key = characterID .. ":" .. catalog.catalogVersion .. ":" .. table.concat(professionKeys, ",")
    local force = reason == "PLAYER_LOGIN" or reason == "TRADE_SKILL_SHOW"
        or reason == "NEW_RECIPE_LEARNED" or reason == "SPELLS_CHANGED"
    -- List filtering, folding and crafting can emit many updates. They do not
    -- change spell ownership, so reuse this session's completed spell query.
    if not force and (activeKey == key or completedKey == key) then return true, "session-scan-reused" end
    scanSequence = scanSequence + 1
    local sequence = scanSequence
    activeKey = key
    local stats = { reason = reason, state = "running", processed = 0, batches = 0, maxBatchMS = 0 }
    self.lastScan = stats
    local started = Milliseconds()

    local jobIndex, recipeIndex = 1, 1
    local states = {}
    local function Step()
        if sequence ~= scanSequence then return end
        local batchStarted = Milliseconds()
        local processed = 0
        while jobIndex <= #jobs and processed < BATCH_SIZE do
            local job = jobs[jobIndex]
            local recipeID = job.ids[recipeIndex]
            if not recipeID then
                job.states = states
                states = {}
                jobIndex, recipeIndex = jobIndex + 1, 1
            else
                local ok, learned = pcall(_G.IsPlayerSpell, recipeID)
                if not ok or type(learned) ~= "boolean" then
                    -- Do not replace the last valid snapshot with a partial or ambiguous scan.
                    stats.state, activeKey = "failed", nil
                    return
                end
                states[recipeID] = learned
                recipeIndex = recipeIndex + 1
                processed = processed + 1
                stats.processed = stats.processed + 1
            end
        end

        -- Commit a profession only after every catalog spell in that profession was queried.
        for _, job in ipairs(jobs) do
            if job.states and not job.committed then
                local ok, changed = Addon.Store:ApplyRecipeSpellSnapshot(
                    characterID, job.professionID, job.states, catalog.catalogVersion, #job.ids)
                if not ok then stats.state, activeKey = "failed", nil; return end
                job.committed = true
                if changed then
                    if Addon.NotifyPageChanged then Addon:NotifyPageChanged() end
                    if Addon.GoalTargets then Addon.GoalTargets:RecipeStatesChanged(characterID, job.professionID) end
                end
            end
        end
        stats.batches = stats.batches + 1
        stats.maxBatchMS = math.max(stats.maxBatchMS, Milliseconds() - batchStarted)
        stats.elapsedMS = Milliseconds() - started

        if jobIndex <= #jobs then
            if C_Timer and C_Timer.After then C_Timer.After(0.01, Step) else Step() end
        else
            stats.state, completedKey, activeKey = "complete", key, nil
        end
    end
    Step()
    return true, reason or "scheduled"
end

function Scanner:Cancel()
    scanSequence = scanSequence + 1
    activeKey = nil
    if self.lastScan and self.lastScan.state == "running" then self.lastScan.state = "cancelled" end
end
