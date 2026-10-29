local Addon = _G.YiboTodo
local Action = { GROUP = "mop.tailoring.celestial-cloth", PROVIDER = "YiboTodo:profession-cooldown",
    METADATA_KEY = "actionTodo" }
Addon.ActionTodo = Action

-- This adapter owns the business projection. The consumer never sees Todo's
-- database, internal providers, recipe actions or mutable snapshot objects.
local function Encode(value)
    if type(value) ~= "table" then return type(value) .. ":" .. tostring(value) end
    local keys, parts = {}, {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do parts[#parts + 1] = Encode(key) .. "=" .. Encode(value[key]) end
    return "{" .. table.concat(parts, ";") .. "}"
end

function Action:GetMetadata()
    local db = Addon.db
    if type(db[self.METADATA_KEY]) ~= "table" then db[self.METADATA_KEY] = {} end
    local meta = db[self.METADATA_KEY]
    if type(meta.sourceEpoch) ~= "string" or meta.sourceEpoch == "" then
        meta.sourceEpoch = tostring(Addon:Now()) .. ":" .. tostring(math.random(1, 2147483646))
        meta.revision, meta.fingerprint = 0, nil
    end
    meta.revision = tonumber(meta.revision) or 0
    return meta
end

function Action:Project(characterID, snapshot, now, epoch, groupID, explicit)
    groupID = groupID or self.GROUP
    local group = Addon.Catalog.groups[groupID]
    if not group or not group.active or (not explicit and not Addon.Settings:IsMonitoringItemEnabled("profession-cooldown", groupID)) then
        return nil, { state = "known-empty", reason = "not-monitored" }
    end
    local domain = Addon.Core.DataDomains:Get(characterID, "professions")
    if not (domain and domain.state == "known" and domain.data and type(domain.data.primaryProfessions) == "table") then
        return nil, { state = "not-yet-scanned", reason = "professions-unknown" }
    end
    local hasProfession = false
    for _, profession in ipairs(domain.data.primaryProfessions) do
        if profession and tonumber(profession.id) == tonumber(group.professionID) then hasProfession = true end
    end
    if not hasProfession then return nil, { state = "known-empty", reason = "profession-not-applicable" } end
    local activity = snapshot and snapshot.activities[groupID]
    if not activity then return nil, { state = "partial", reason = "activity-unavailable" } end
    if activity.state == "locked" or activity.state == "not-applicable" then
        return nil, { state = "known-empty", reason = activity.state }
    end
    local provider = Addon.Database:GetProvider(characterID, "profession-cooldown", false)
    local observation = provider and provider.observations and provider.observations[groupID]
    -- A scan of a different recipe is not an observation of this work.
    local observedAt = observation and tonumber(observation.observedAt)
    local nextReset = Addon.Model.Schedule:NextResetAt(now, group.resetHour)
    local freshness = observedAt and observedAt > 0 and "known" or "not-yet-scanned"
    local readiness, reason = "unknown", Addon:T("ACTION.PROFESSION_VERIFY")
    if activity.state == "actionable" then
        -- A learned, craftable recipe can project as actionable even when
        -- this client returns no cooldown value. Reuse the source readiness;
        -- preparation is not proof of zero cooldown or a completed craft.
        readiness = "preparation"
        reason = activity.confidence == "confirmed" and Addon:T("ACTION.COOLDOWN_MATERIALS") or Addon:T("ACTION.RECIPE_CONFIRM")
    elseif activity.state == "cooldown" and activity.confidence == "confirmed" then
        readiness, reason = "blocked", Addon:T("ACTION.COOLDOWN")
    elseif activity.state == "skill-insufficient" then
        readiness, reason = "blocked", Addon:T("ACTION.SKILL_LOW")
    elseif activity.state == "estimated" then
        -- The source knows the reset-derived preparation state, while the
        -- cooldown itself remains explicitly estimated. This is not proof
        -- of completion and must never be promoted to a confirmed cooldown.
        freshness, readiness, reason = "known", "preparation", Addon:T("ACTION.ESTIMATED_CONFIRM")
    elseif activity.reason == "recipe-unlearned" then
        readiness, reason = "blocked", Addon:T("ACTION.RECIPE_UNLEARNED")
    elseif activity.diagnostic == "group-conflict" then
        freshness, reason = "partial", Addon:T("ACTION.COOLDOWN_CONFLICT")
    end
    -- Old observations cannot confirm an action in the new daily cycle.
    -- Reset-derived estimates above remain explicitly preparation only.
    if activity.state ~= "estimated" and observedAt and Addon.Model.Schedule:CrossedReset(observedAt, now, group.resetHour) then
        freshness, readiness, reason = "stale", "unknown", Addon:T("ACTION.SNAPSHOT_EXPIRED")
    end
    local key = characterID .. ":" .. groupID
    local task = {
        itemKey = key,
        businessRef = { capability = "action.todo", providerID = self.PROVIDER, sourceEpoch = epoch, key = key },
        title = activity.label or group.label, summary = reason,
        displayGroup = { id = groupID, title = group.label or groupID },
        execution = { mode = "self", characterID = characterID },
        beneficiary = { mode = "character", characterID = characterID },
        state = "active", readiness = readiness, reason = reason,
        sourceState = activity.state, confidence = activity.confidence,
        temporal = { kind = "daily", cycleKey = Addon.Model.Schedule:ServerDay(now, group.resetHour), nextChangeAt = nextReset },
        freshness = { state = freshness, observedAt = observedAt, validUntil = nextReset, clockSource = "server" },
        nextAction = { kind = "open-page", title = Addon:T("ACTION.OPEN_TODO"), pageID = "todo" },
        item = activity.iconKind == "item" and { itemID = activity.icon } or nil,
        icon = activity.iconKind ~= "item" and (activity.iconKind == "texture" and activity.icon or activity.fallbackIcon) or nil,
    }
    return task, { state = freshness, observedAt = observedAt, validUntil = nextReset, nextChangeAt = nextReset, clockSource = "server", reason = reason }
end

-- Enumerate the source catalog, preserving the existing Provider identity.
function Action:ProjectAll(characterID, snapshot, now, epoch)
    local tasks, coverage, ids = {}, { state = "known-empty", reason = "not-monitored" }, {}
    for id, group in pairs(Addon.Catalog.groups) do if group.active then ids[#ids + 1] = id end end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local task, entry = self:Project(characterID, snapshot, now, epoch, id)
        if task then tasks[#tasks + 1] = task end
        if entry.state ~= "known-empty" then
            if coverage.state == "known-empty" or (coverage.state == "known" and entry.state ~= "known") then coverage = entry end
        end
        if entry.nextChangeAt and (not coverage.nextChangeAt or entry.nextChangeAt < coverage.nextChangeAt) then
            coverage.nextChangeAt = entry.nextChangeAt
        end
    end
    return tasks, coverage
end

function Action:Commit()
    local meta, now = self:GetMetadata(), Addon:Now()
    if self.transitionAt and now >= self.transitionAt then Addon.Snapshot:Invalidate() end
    local source = Addon.Snapshot:Build()
    if self.value and self.cachedSource == source and self.cachedEpoch == meta.sourceEpoch
        and (not self.transitionAt or now < self.transitionAt) then return false, meta end
    local value = { tasks = {}, coverage = {} }
    local transitionAt
    for _, character in ipairs(Addon.Core.Characters:GetAll({ identityOnly = true })) do
        local tasks, coverage
        if self.ProjectAll then
            tasks, coverage = self:ProjectAll(character.id, source.characters[character.id], now, meta.sourceEpoch)
        else
            local task
            task, coverage = self:Project(character.id, source.characters[character.id], now, meta.sourceEpoch)
            tasks = task and { task } or {}
        end
        value.coverage[character.id] = coverage
        if coverage.nextChangeAt and (not transitionAt or coverage.nextChangeAt < transitionAt) then transitionAt = coverage.nextChangeAt end
        value.tasks[character.id] = tasks
    end
    local fingerprint = Encode(value)
    local changed = meta.fingerprint ~= fingerprint
    if changed then meta.revision, meta.fingerprint = meta.revision + 1, fingerprint end
    self.value, self.cachedSource, self.cachedEpoch, self.transitionAt = value, source, meta.sourceEpoch, transitionAt
    return changed, meta
end

function Action:Query(request)
    local ids = type(request) == "table" and type(request.scope) == "table" and request.scope.characterIDs
    if type(ids) ~= "table" then return nil, "invalid-request" end
    local count = 0
    for key, id in pairs(ids) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or type(id) ~= "string" or id == "" then return nil, "invalid-request" end
        count = count + 1
    end
    if count ~= #ids then return nil, "invalid-request" end
    local _, meta = self:Commit()
    local result = { providerID = self.PROVIDER, sourceEpoch = meta.sourceEpoch, revision = meta.revision,
        generatedAt = Addon:Now(), sourceTitle = Addon:T(self.SOURCE_TITLE_KEY or "PROVIDER.TODO"), status = "ready", coverage = {}, data = { tasks = {} } }
    if self.DisplayGroups then result.displayGroups = self:DisplayGroups() end
    local seen = {}
    for _, id in ipairs(ids) do
        if not seen[id] then
            seen[id] = true
            local coverage = self.value.coverage[id] or { state = "not-yet-scanned", reason = "character-unavailable" }
            result.coverage[id] = coverage
            if coverage.state ~= "known" and coverage.state ~= "known-empty" then result.status = "partial" end
            for _, task in ipairs(self.value.tasks[id] or {}) do result.data.tasks[#result.data.tasks + 1] = task end
        end
    end
    -- Core additionally copies results at the cross-business boundary.
    return Addon.Core.Defaults:Copy(result)
end

function Action:DisplayGroups()
    local groups = {}
    for id, group in pairs(Addon.Catalog.groups) do if group.active then groups[#groups + 1] = { id = id, title = group.label or id } end end
    table.sort(groups, function(a, b) return a.id < b.id end)
    return groups
end
