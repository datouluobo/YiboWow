if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB, Core = _G.YAB, _G.YiboCore
local Evidence = {}
YAB.RaidProgress = Evidence
local function Now() return GetServerTime and GetServerTime() or time() end
local function Text(key, ...) return Core.Locale:Get("YiboAltoBoss", key, ...) end
local function Record(id)
    local key = YAB.PlannedTargets:LegacyKey(id)
    return key and YiboAltoBossDB.characters and YiboAltoBossDB.characters[key]
end
local function Selection(target)
    local definition = YAB.TargetCatalog:Get(target.catalogID)
    if not definition or not definition.isRaid then return end
    local difficultyID = YAB.TargetCatalog:CanonicalDifficulty(target.catalogID, target.difficultyID)
    for _, difficulty in ipairs(definition.difficulties or {}) do if difficulty.id == difficultyID and difficulty.complete then
        local ids, chosen = {}, {}
        for _, id in ipairs(target.encounterIDs or {}) do chosen[id] = true end
        for _, boss in ipairs(difficulty.encounters) do
            if target.scope == "all" or chosen[boss.id] then ids[#ids + 1] = boss.id end
        end
        if #ids > 0 then return definition.mapID, difficultyID, ids end
    end end
end
local function Bucket(record, mapID, difficultyID, create)
    if not record then return end
    if create then record.raidProgress = record.raidProgress or {} end
    local key = tostring(mapID) .. ":" .. tostring(difficultyID)
    local root = record.raidProgress
    if create then root[key] = root[key] or { automatic = {}, manual = {} } end
    return root and root[key]
end
local function Current(entry, cycle)
    return entry and entry.completed == true and entry.cycleKey == cycle
        and type(entry.validUntil) == "number" and entry.validUntil > Now()
end
local function Changed()
    if YAB.PersistDB then YAB.PersistDB() end
    YAB.PlannedTargets:ScheduleChange()
end
function Evidence:Observe(id, mapID, difficultyID, encounterID)
    local cycle, boundary = YAB.PlannedTargets:Period("weekly")
    local record = Record(id)
    if not cycle or not record then return end
    local bucket = Bucket(record, mapID, difficultyID, true)
    if Current(bucket.automatic[encounterID], cycle) then return end
    bucket.automatic[encounterID] = { completed = true, cycleKey = cycle, validUntil = boundary,
        observedAt = Now(), source = "encounter" }
    Changed(); return true
end
function Evidence:Apply(id, target, progress)
    local mapID, difficultyID, ids = Selection(target)
    local cycle, boundary = YAB.PlannedTargets:Period("weekly")
    if not mapID or not cycle then return progress end
    local bucket = Bucket(Record(id), mapID, difficultyID)
    if not bucket then return progress end
    local known, killed, supplied, manual, observed = {}, 0, false, false, progress.observedAt
    for _, boss in ipairs(progress.lockout and progress.lockout.bosses or {}) do
        if type(boss.killed) == "boolean" then known[boss.encounterID or false] = boss.killed end
    end
    for _, encounterID in ipairs(ids) do
        local automatic = bucket.automatic and bucket.automatic[encounterID]
        local confirmation = bucket.manual and bucket.manual[encounterID]
        local entry = Current(automatic, cycle) and automatic or (Current(confirmation, cycle) and confirmation)
        if entry then
            known[encounterID], supplied = true, true
            manual = manual or entry.source == "manual"
            observed = math.max(observed or 0, entry.observedAt or 0)
        end
        if known[encounterID] == true then killed = killed + 1 end
    end
    if not supplied then return progress end
    local complete, verified = killed == #ids, true
    for _, encounterID in ipairs(ids) do
        if known[encounterID] == nil and not (progress.state == "ready" and not progress.lockout) then verified = false end
    end
    progress.killed, progress.total, progress.observedAt = killed, #ids, observed
    progress.cycleKey, progress.validUntil, progress.kind = cycle, boundary, "weekly"
    progress.state = complete and "completed" or (verified and "ready" or "unknown")
    progress.freshness = verified and "known" or "partial"
    if complete then
        progress.evidenceSource = manual and "manual" or "encounter"
        progress.reason = Text(manual and "GOAL.MANUAL_COMPLETE" or "GOAL.ENCOUNTER_COMPLETE")
    elseif verified then progress.reason = string.format(Text("UI.D_D_BOSSES"), killed, #ids) end
    return progress
end
function Evidence:Actions(id, target, intent)
    local mapID, difficultyID, ids = Selection(target)
    local cycle, boundary = YAB.PlannedTargets:Period("weekly")
    local record, meta = Record(id), YiboAltoBossDB.plannedTargetSource
    if not mapID or not cycle or not record or not meta then return end
    local character = Core.Characters:Get(id, { identityOnly = true })
    local name = Core.Characters:FormatName(character, { realmMode = "full" })
    local title = YAB.PlannedTargets:Describe(target)
    local bucket, hasManual = Bucket(record, mapID, difficultyID), false
    for _, bossID in ipairs(ids) do if Current(bucket and bucket.manual and bucket.manual[bossID], cycle) then hasManual = true end end
    local function Action(method, label, confirmation)
        return { id = method, method = method, label = Text(label),
            confirmation = Text(confirmation, name, title, date("%m-%d %H:%M", boundary)),
            cycleKey = cycle, sourceEpoch = meta.sourceEpoch, revision = meta.revision,
            request = { intent = Core.Defaults:Copy(intent), cycleKey = cycle, sourceEpoch = meta.sourceEpoch, revision = meta.revision } }
    end
    local actions = { Action("ConfirmCycle", "GOAL.CONFIRM_CYCLE", "GOAL.CONFIRM_CYCLE_TEXT") }
    if hasManual then actions[#actions + 1] = Action("RevokeCycle", "GOAL.REVOKE_CYCLE", "GOAL.REVOKE_CYCLE_TEXT") end
    return actions
end
function Evidence:Confirm(request, revoke)
    local clean, err = YAB.GoalTargets:Normalize({ intent = request.intent })
    if not clean or clean.needsConfiguration then return nil, err or Text("UI.TARGET_PARAMETERS_UNCONFIRMED") end
    local target, id = clean.intent.conditions, clean.intent.scope.characterID
    local mapID, difficultyID, ids = Selection(target)
    local cycle, boundary = YAB.PlannedTargets:Period("weekly")
    local meta = YiboAltoBossDB.plannedTargetSource
    if not mapID or not cycle or cycle ~= request.cycleKey or not meta
        or meta.sourceEpoch ~= request.sourceEpoch or meta.revision ~= request.revision then
        return nil, Text("GOAL.CONFIRM_STALE")
    end
    local record = Record(id)
    if not record then return nil, Text("UI.CHARACTER_NOT_FOUND") end
    local bucket = Bucket(record, mapID, difficultyID, true)
    for _, bossID in ipairs(ids) do
        bucket.manual[bossID] = { completed = not revoke, source = "manual", cycleKey = cycle,
            observedAt = Now(), validUntil = boundary }
    end
    Changed()
    return { message = Text(revoke and "GOAL.CONFIRM_REVOKED" or "GOAL.CONFIRM_SAVED") }
end
