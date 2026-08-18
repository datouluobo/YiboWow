local YAB = _G.YAB

local Tracking = {}
YAB.TrackingV3 = Tracking

local SCHEMA_VERSION = 3
local DIAGNOSTIC_LIMIT = 80
local MIN_SAMPLE_SECONDS = 30
local ACTIVE_VIEW_TTL_SECONDS = 6 * 60 * 60
local INCOMPLETE_EXPIRY_SECONDS = 24 * 60 * 60

local function Now()
    return YAB.GetServerTimestamp and YAB.GetServerTimestamp() or time()
end

local function EnsureRoot()
    YiboAltoBossDB.trackingV3 = YiboAltoBossDB.trackingV3 or {}
    local root = YiboAltoBossDB.trackingV3
    root.schemaVersion = SCHEMA_VERSION
    root.realms = root.realms or {}
    root.samples = root.samples or {}
    root.diagnostics = root.diagnostics or {}
    root.meta = root.meta or {}
    if not root.meta.legacyMigrationVersion then
        local migrated = 0
        for index, sample in ipairs(YiboAltoBossDB.respawnSamples or {}) do
            local bossKey = tostring(sample.targetKey or sample.bossId or "unknown")
            local diedAt = tonumber(sample.killedAt)
            local respawnedAt = tonumber(sample.respawnedAt)
            local elapsed = tonumber(sample.elapsedSeconds)
            local structurallyValid = diedAt and respawnedAt and elapsed
                and respawnedAt > diedAt and elapsed == (respawnedAt - diedAt)
                and elapsed >= MIN_SAMPLE_SECONDS
            local sampleID = table.concat({ "v2", tostring(index), bossKey, tostring(diedAt or 0), tostring(respawnedAt or 0) }, "|")
            if not root.samples[sampleID] then
                root.samples[sampleID] = {
                    sampleID = sampleID,
                    bossKey = bossKey,
                    realmKey = sample.realm,
                    phaseKey = sample.phaseKey,
                    phaseLabel = sample.phaseLabel,
                    diedAt = diedAt,
                    respawnedAt = respawnedAt,
                    elapsedSeconds = elapsed,
                    completedAt = sample.observedAt,
                    status = "complete",
                    modelEligible = structurallyValid == true,
                    exclusionReason = structurallyValid and nil or "invalid_legacy_structure",
                    provenance = "v2_legacy",
                }
                migrated = migrated + 1
            end
        end
        root.meta.legacySampleCount = #(YiboAltoBossDB.respawnSamples or {})
        root.meta.legacyMigratedCount = migrated
        root.meta.legacyMigratedAt = Now()
        root.meta.legacyMigrationVersion = 1
    end
    return root
end

local function AddDiagnostic(kind, event, detail)
    local root = EnsureRoot()
    local at = event and event.at or Now()
    local diagnosticKey = table.concat({
        tostring(kind), tostring(event and event.bossKey or "-"),
        tostring(event and event.phaseKey or "-"), tostring(event and event.spawnSignature or "-"),
        tostring(detail or "-"),
    }, "|")
    if root.meta.lastDiagnosticKey == diagnosticKey and (at - (tonumber(root.meta.lastDiagnosticAt) or 0)) < 30 then return end
    root.meta.lastDiagnosticKey = diagnosticKey
    root.meta.lastDiagnosticAt = at
    local items = root.diagnostics
    items[#items + 1] = {
        at = at,
        kind = kind,
        bossKey = event and event.bossKey,
        realmKey = event and event.realmKey,
        phaseKey = event and event.phaseKey,
        spawnSignature = event and event.spawnSignature,
        source = event and event.source,
        detail = detail,
    }
    while #items > DIAGNOSTIC_LIMIT do table.remove(items, 1) end
    root.meta.diagnosticsDirty = true
    if root.meta and root.meta.traceEnabled and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo] 采样|r " .. tostring(kind)
            .. " " .. tostring(event and event.bossKey or "-")
            .. " P" .. tostring(event and event.phaseId or "?")
            .. (detail and (" · " .. tostring(detail)) or ""))
    end
end

local function PhaseLabel(event)
    if event.phaseId and tonumber(event.phaseId) and tonumber(event.phaseId) > 0 then
        return tostring(event.phaseId)
    end
    if event.subZone and event.subZone ~= "" then return event.subZone end
    if event.zone and event.zone ~= "" then return event.zone end
    return "未知"
end

local function PhaseKey(event)
    if event.phaseId and tonumber(event.phaseId) and tonumber(event.phaseId) > 0 then
        return "phaseid:" .. tostring(tonumber(event.phaseId))
    end
    return "unknown"
end

local function EnsurePhase(event)
    local root = EnsureRoot()
    local realmKey = tostring(event.realmKey or "Unknown")
    local bossKey = tostring(event.bossKey or "unknown")
    local phaseKey = tostring(event.phaseKey or PhaseKey(event))
    root.realms[realmKey] = root.realms[realmKey] or { bosses = {} }
    local realm = root.realms[realmKey]
    realm.bosses[bossKey] = realm.bosses[bossKey] or { phases = {} }
    local boss = realm.bosses[bossKey]
    boss.phases[phaseKey] = boss.phases[phaseKey] or {
        phaseKey = phaseKey,
        phaseId = event.phaseId,
        phaseLabel = event.phaseLabel or PhaseLabel(event),
        cycles = {},
    }
    local phase = boss.phases[phaseKey]
    phase.phaseId = event.phaseId or phase.phaseId
    phase.phaseLabel = event.phaseLabel or phase.phaseLabel or PhaseLabel(event)
    phase.zone = event.zone or phase.zone
    phase.subZone = event.subZone or phase.subZone
    return phase, realmKey, bossKey, phaseKey
end

local function SampleID(realmKey, bossKey, phaseKey, previousSignature, nextSignature)
    return table.concat({ realmKey, bossKey, phaseKey, previousSignature, nextSignature }, "|")
end

local function MarkSampleEligibility(sample)
    if sample.elapsedSeconds < MIN_SAMPLE_SECONDS then
        sample.modelEligible = false
        sample.exclusionReason = "too_short"
    else
        sample.modelEligible = true
        sample.exclusionReason = nil
    end
end

local function SortedCycles(phase)
    local cycles = {}
    for _, cycle in pairs(phase.cycles or {}) do
        if tonumber(cycle.spawnedAt) and cycle.spawnSignature then cycles[#cycles + 1] = cycle end
    end
    table.sort(cycles, function(left, right)
        local leftAt, rightAt = tonumber(left.spawnedAt) or 0, tonumber(right.spawnedAt) or 0
        if leftAt ~= rightAt then return leftAt < rightAt end
        return tostring(left.spawnSignature) < tostring(right.spawnSignature)
    end)
    return cycles
end

local function TryFinalizeAdjacentCycles(phase, realmKey, bossKey, phaseKey, event)
    local root = EnsureRoot()
    local changed = false
    local cycles = SortedCycles(phase)
    for index = 1, #cycles - 1 do
        local previous, nextCycle = cycles[index], cycles[index + 1]
        local diedAt = tonumber(previous.diedAt)
        local respawnedAt = tonumber(nextCycle.spawnedAt)
        if diedAt and previous.state == "Dead" and not previous.sampleID and respawnedAt then
            if previous.spawnSignature == nextCycle.spawnSignature then
                local rejection = "same_spawn_signature:" .. tostring(nextCycle.spawnSignature)
                if previous.lastSampleRejection ~= rejection then
                    previous.lastSampleRejection = rejection
                    AddDiagnostic("SAMPLE_REJECTED", event, "same_spawn_signature")
                end
            elseif respawnedAt <= diedAt then
                local rejection = "spawn_not_after_death:" .. tostring(nextCycle.spawnSignature)
                if previous.lastSampleRejection ~= rejection then
                    previous.lastSampleRejection = rejection
                    AddDiagnostic("SAMPLE_REJECTED", event, "spawn_not_after_death")
                end
            else
                local sampleID = SampleID(realmKey, bossKey, phaseKey, previous.spawnSignature, nextCycle.spawnSignature)
                local sample = root.samples[sampleID]
                if not sample then
                    sample = {
                        sampleID = sampleID,
                        bossKey = bossKey,
                        realmKey = realmKey,
                        phaseKey = phaseKey,
                        phaseLabel = phase.phaseLabel,
                        previousSpawnSignature = previous.spawnSignature,
                        nextSpawnSignature = nextCycle.spawnSignature,
                        diedAt = diedAt,
                        respawnedAt = respawnedAt,
                        elapsedSeconds = respawnedAt - diedAt,
                        completedAt = event.at or Now(),
                        status = "complete",
                        provenance = "v3",
                    }
                    MarkSampleEligibility(sample)
                    root.samples[sampleID] = sample
                    AddDiagnostic("SAMPLE_COMPLETED", event, tostring(sample.elapsedSeconds))
                    changed = true
                end
                previous.sampleID = sampleID
                previous.state = "SampleCompleted"
            end
        end
    end
    return changed
end

local function FindCycleByGUID(root, guid)
    if not guid then return nil end
    for realmKey, realm in pairs(root.realms or {}) do
        for bossKey, boss in pairs(realm.bosses or {}) do
            for phaseKey, phase in pairs(boss.phases or {}) do
                for _, cycle in pairs(phase.cycles or {}) do
                    if cycle.spawnGUID == guid then return cycle, phase, realmKey, bossKey, phaseKey end
                end
            end
        end
    end
end

local function ApplyAlive(event)
    if not event.spawnGUID or not event.spawnSignature or not tonumber(event.spawnedAt) then
        AddDiagnostic("ALIVE_REJECTED", event, "missing_spawn_identity")
        return false
    end
    if tonumber(event.spawnedAt) > (event.at + 5) then
        AddDiagnostic("ALIVE_REJECTED", event, "spawn_time_in_future")
        return false
    end
    local phase, realmKey, bossKey, phaseKey = EnsurePhase(event)
    if phaseKey == "unknown" then
        AddDiagnostic("ALIVE_REJECTED", event, "unknown_phase")
        return false
    end

    local cycle = phase.cycles[event.spawnSignature]
    local isNew = not cycle
    if not cycle then
        cycle = {
            spawnGUID = event.spawnGUID,
            spawnSignature = event.spawnSignature,
            spawnedAt = event.spawnedAt,
            firstSeenAt = event.at,
            lastSeenAt = event.at,
            state = "SeenAlive",
            aliveEvidence = {},
            deathEvidence = {},
        }
        phase.cycles[event.spawnSignature] = cycle
        AddDiagnostic("NEW_SPAWN", event)
    else
        cycle.firstSeenAt = math.min(tonumber(cycle.firstSeenAt) or event.at, event.at)
        cycle.lastSeenAt = math.max(tonumber(cycle.lastSeenAt) or 0, event.at)
        cycle.spawnGUID = cycle.spawnGUID or event.spawnGUID
        cycle.spawnedAt = cycle.spawnedAt or event.spawnedAt
    end
    cycle.aliveEvidence[event.source or "unknown"] = event.at
    phase.currentSpawnSignature = event.spawnSignature
    phase.lastObservedAt = event.at
    phase.lastObservedBy = event.charKey
    phase.lastObservedSource = event.source
    local finalized = TryFinalizeAdjacentCycles(phase, realmKey, bossKey, phaseKey, event)
    if isNew then AddDiagnostic("ALIVE_CONFIRMED", event, event.source) end
    return isNew or finalized
end

local function ApplyDeath(event)
    local root = EnsureRoot()
    local cycle, phase, realmKey, bossKey, phaseKey = FindCycleByGUID(root, event.spawnGUID)
    if not cycle then
        if event.strongEvidence and event.spawnSignature and event.phaseKey ~= "unknown" then
            ApplyAlive(event)
            cycle, phase, realmKey, bossKey, phaseKey = FindCycleByGUID(root, event.spawnGUID)
        end
    end
    if not cycle then
        AddDiagnostic("DEATH_REJECTED", event, "death_without_alive_evidence")
        return false
    end
    if tonumber(cycle.spawnedAt) and event.at < tonumber(cycle.spawnedAt) then
        AddDiagnostic("DEATH_REJECTED", event, "death_before_spawn")
        return false
    end
    cycle.deathEvidence = cycle.deathEvidence or {}
    cycle.deathEvidence[event.source or "unknown"] = event.at
    local isNewDeath = not cycle.diedAt
    if isNewDeath then
        cycle.diedAt = event.at
        cycle.state = "Dead"
        phase.lastDeathAt = event.at
        phase.lastDeathBy = event.charKey
        phase.lastDeathSource = event.source
        AddDiagnostic("DEATH_ACCEPTED", event, event.source)
    end
    local finalized = TryFinalizeAdjacentCycles(phase, realmKey, bossKey, phaseKey, event)
    return isNewDeath or finalized
end

function Tracking:Apply(event)
    event = event or {}
    event.at = tonumber(event.at) or Now()
    event.realmKey = event.realmKey or (YAB.GetCurrentRealm and YAB.GetCurrentRealm()) or "Unknown"
    event.phaseKey = event.phaseKey or PhaseKey(event)
    event.phaseLabel = event.phaseLabel or PhaseLabel(event)
    if event.type == "ALIVE_EVIDENCE" then return ApplyAlive(event) end
    if event.type == "DEATH_EVIDENCE" then return ApplyDeath(event) end
    AddDiagnostic("EVENT_REJECTED", event, "unknown_event_type")
    return false
end

function Tracking:Initialize()
    EnsureRoot()
    return true
end

function Tracking:BuildEvent(guid, eventType, source, extra)
    local npcId = YAB.ExtractNpcIDFromGUID and YAB.ExtractNpcIDFromGUID(guid)
    if not npcId then return nil end
    extra = extra or {}
    local zone = extra.zone or (GetRealZoneText and GetRealZoneText()) or nil
    local subZone = extra.subZone or (GetSubZoneText and GetSubZoneText()) or nil
    local targets = YAB.ResolveTargetsByNpcContext and YAB.ResolveTargetsByNpcContext(npcId, zone, subZone) or {}
    local phaseId = YAB.ExtractPhaseIDFromGUID and YAB.ExtractPhaseIDFromGUID(guid)
    local spawn = YAB.ExtractSpawnInfoFromGUID and YAB.ExtractSpawnInfoFromGUID(guid)
    local events = {}
    for _, boss in ipairs(targets) do
        if boss.trackPhase ~= false then
            events[#events + 1] = {
                type = eventType,
                at = extra.at or Now(),
                realmKey = extra.realmKey or (YAB.GetCurrentRealm and YAB.GetCurrentRealm()),
                bossKey = boss.key,
                phaseId = phaseId,
                phaseKey = phaseId and ("phaseid:" .. tostring(phaseId)) or "unknown",
                phaseLabel = phaseId and tostring(phaseId) or nil,
                spawnGUID = guid,
                spawnSignature = spawn and spawn.signature,
                spawnedAt = spawn and spawn.spawnTime,
                spawnIndex = spawn and spawn.spawnIndex,
                zone = zone,
                subZone = subZone,
                charKey = extra.charKey or (YAB.GetCurrentCharKey and YAB.GetCurrentCharKey()),
                source = source,
                strongEvidence = extra.strongEvidence == true,
            }
        end
    end
    return events, npcId
end

function Tracking:ApplyGUID(guid, eventType, source, extra)
    local events = self:BuildEvent(guid, eventType, source, extra)
    if not events or #events == 0 then return false end
    local changed = false
    for _, event in ipairs(events) do
        if self:Apply(event) then changed = true end
    end
    return changed
end

function Tracking:GetPhaseColumns(viewMode)
    local root = EnsureRoot()
    local items = {}
    local now = Now()
    for realmKey, realm in pairs(root.realms) do
        local currentRealm = YAB.GetCurrentRealm()
        local visible = viewMode == "all" or viewMode == nil
            or viewMode == "current" and realmKey == currentRealm
            or viewMode == "other" and realmKey ~= currentRealm
        if visible then
            local seen = {}
            for _, boss in pairs(realm.bosses or {}) do
                for phaseKey, phase in pairs(boss.phases or {}) do
                    local activeAt = tonumber(phase.lastDeathAt or phase.lastObservedAt) or 0
                    local hasPending = false
                    for _, cycle in pairs(phase.cycles or {}) do
                        if cycle.state == "Dead" and not cycle.sampleID then hasPending = true; break end
                    end
                    if not seen[phaseKey] and (hasPending or activeAt > 0 and (now - activeAt) < ACTIVE_VIEW_TTL_SECONDS) then
                        seen[phaseKey] = true
                        items[#items + 1] = {
                            key = realmKey .. "::" .. phaseKey,
                            realm = realmKey,
                            phaseKey = phaseKey,
                            label = phase.phaseLabel or "未知",
                            displayId = phase.phaseId and tostring(phase.phaseId) or "00",
                            sortObservedAt = tonumber(phase.lastObservedAt or phase.lastDeathAt) or 0,
                        }
                    end
                end
            end
        end
    end
    table.sort(items, function(left, right)
        if left.realm ~= right.realm then return tostring(left.realm) < tostring(right.realm) end
        local leftId, rightId = tonumber(left.displayId), tonumber(right.displayId)
        if leftId and rightId and leftId ~= rightId then return leftId < rightId end
        return tostring(left.displayId) < tostring(right.displayId)
    end)
    return items
end

function Tracking:GetPhaseState(realmKey, bossKey, phaseKey)
    local root = EnsureRoot()
    local phase = root.realms[realmKey]
        and root.realms[realmKey].bosses
        and root.realms[realmKey].bosses[tostring(bossKey)]
        and root.realms[realmKey].bosses[tostring(bossKey)].phases[phaseKey]
    if not phase then return nil end
    local current = phase.currentSpawnSignature and phase.cycles[phase.currentSpawnSignature] or nil
    local pendingCount = 0
    local pendingDeathAt
    for _, cycle in pairs(phase.cycles or {}) do
        if cycle.diedAt and not cycle.sampleID and cycle.state == "Dead" then
            pendingCount = pendingCount + 1
            pendingDeathAt = math.max(tonumber(pendingDeathAt) or 0, tonumber(cycle.diedAt) or 0)
        end
    end
    local activeAt = tonumber(phase.lastDeathAt or phase.lastObservedAt) or 0
    if pendingCount == 0 and (activeAt <= 0 or (Now() - activeAt) >= ACTIVE_VIEW_TTL_SECONDS) then return nil end
    return {
        realm = realmKey,
        phaseKey = phaseKey,
        phaseId = phase.phaseId,
        phaseLabel = phase.phaseLabel,
        phaseDisplayId = phase.phaseId and tostring(phase.phaseId) or "00",
        observedAt = phase.lastObservedAt,
        lastObservedBy = phase.lastObservedBy,
        observedSource = phase.lastObservedSource,
        lastKilledAt = pendingDeathAt,
        lastKilledBy = phase.lastDeathBy,
        killSource = phase.lastDeathSource,
        pendingCycleCount = pendingCount,
        currentSpawnSignature = current and current.spawnSignature,
        currentSpawnedAt = current and current.spawnedAt,
        zone = phase.zone,
        subZone = phase.subZone,
    }
end

function Tracking:GetSamples(bossKey, includeLegacy)
    local root = EnsureRoot()
    local items = {}
    for _, sample in pairs(root.samples) do
        if tostring(sample.bossKey) == tostring(bossKey) then items[#items + 1] = sample end
    end
    return items
end

function Tracking:GetDiagnostics(bossKey, limit)
    local root = EnsureRoot()
    local items = {}
    for index = #root.diagnostics, 1, -1 do
        local item = root.diagnostics[index]
        if not bossKey or tostring(item.bossKey) == tostring(bossKey) then
            items[#items + 1] = item
            if limit and #items >= limit then break end
        end
    end
    return items
end

function Tracking:GetDebugSummary(bossKey)
    local root = EnsureRoot()
    local lines = {
        "trackingV3 schema=" .. tostring(root.schemaVersion) .. " boss=" .. tostring(bossKey or "all"),
        "legacyMigrated=" .. tostring(root.meta.legacyMigratedCount or 0) .. "/" .. tostring(root.meta.legacySampleCount or 0),
    }
    local complete, pending, incomplete = 0, 0, 0
    for _, sample in pairs(root.samples) do
        if not bossKey or tostring(sample.bossKey) == tostring(bossKey) then complete = complete + 1 end
    end
    for realmKey, realm in pairs(root.realms) do
        for candidateBossKey, boss in pairs(realm.bosses or {}) do
            if not bossKey or tostring(candidateBossKey) == tostring(bossKey) then
                for phaseKey, phase in pairs(boss.phases or {}) do
                    local current = phase.currentSpawnSignature and phase.cycles[phase.currentSpawnSignature] or nil
                    for _, cycle in pairs(phase.cycles or {}) do
                        if cycle.state == "Dead" and not cycle.sampleID then pending = pending + 1 end
                        if cycle.state == "Incomplete" then incomplete = incomplete + 1 end
                    end
                    lines[#lines + 1] = table.concat({
                        tostring(realmKey), tostring(candidateBossKey), tostring(phaseKey),
                        "spawn=" .. tostring(current and current.spawnSignature or "-"),
                        "state=" .. tostring(current and current.state or "-"),
                        "death=" .. tostring(phase.lastDeathAt or "-"),
                    }, " ")
                end
            end
        end
    end
    lines[#lines + 1] = "v3Samples=" .. complete .. " pending=" .. pending .. " incomplete=" .. incomplete
    local diagnostics = self:GetDiagnostics(bossKey, 5)
    for _, item in ipairs(diagnostics) do
        lines[#lines + 1] = tostring(item.kind) .. " " .. tostring(item.detail or "") .. " source=" .. tostring(item.source or "-")
    end
    return lines
end

function Tracking:SetTraceEnabled(enabled)
    local root = EnsureRoot()
    root.meta.traceEnabled = enabled == true
end

function Tracking:IsTraceEnabled()
    return EnsureRoot().meta.traceEnabled == true
end

function Tracking:ConsumeDiagnosticsDirty()
    local root = EnsureRoot()
    local dirty = root.meta.diagnosticsDirty == true
    root.meta.diagnosticsDirty = nil
    return dirty
end

function Tracking:GetPendingCount(bossKey, realmKey)
    local root = EnsureRoot()
    local count = 0
    for candidateRealm, realm in pairs(root.realms) do
        if not realmKey or candidateRealm == realmKey then
            local boss = realm.bosses and realm.bosses[tostring(bossKey)]
            for _, phase in pairs(boss and boss.phases or {}) do
                for _, cycle in pairs(phase.cycles or {}) do
                    if cycle.diedAt and not cycle.sampleID and cycle.state == "Dead" then count = count + 1 end
                end
            end
        end
    end
    return count
end

function Tracking:Cleanup()
    local root, now = EnsureRoot(), Now()
    local changed = false
    for realmKey, realm in pairs(root.realms) do
        for bossKey, boss in pairs(realm.bosses or {}) do
            for phaseKey, phase in pairs(boss.phases or {}) do
                for _, cycle in pairs(phase.cycles or {}) do
                    if cycle.state == "Dead" and not cycle.sampleID and (now - (tonumber(cycle.diedAt) or now)) > INCOMPLETE_EXPIRY_SECONDS then
                        cycle.state = "Incomplete"
                        cycle.incompleteReason = "expired_incomplete"
                        changed = true
                        AddDiagnostic("CYCLE_INCOMPLETE", {
                            at = now,
                            realmKey = realmKey,
                            bossKey = bossKey,
                            phaseKey = phaseKey,
                            spawnSignature = cycle.spawnSignature,
                            source = "cleanup",
                        }, cycle.incompleteReason)
                    end
                end
            end
        end
    end
    return changed
end

function Tracking:RunSelfTest()
    local backup = YiboAltoBossDB.trackingV3
    local legacyBackup = YiboAltoBossDB.respawnSamples
    YiboAltoBossDB.trackingV3 = nil
    YiboAltoBossDB.respawnSamples = {}
    local base = 1800000000
    local first = { type = "ALIVE_EVIDENCE", at = base, realmKey = "SelfTest", bossKey = "ordos", phaseId = 64, spawnGUID = "A", spawnSignature = "A", spawnedAt = base - 10, source = "selftest" }
    local death = { type = "DEATH_EVIDENCE", at = base + 20, realmKey = "SelfTest", bossKey = "ordos", phaseId = 64, phaseKey = "phaseid:64", spawnGUID = "A", spawnSignature = "A", spawnedAt = base - 10, source = "selftest" }
    local nextSpawn = { type = "ALIVE_EVIDENCE", at = base + 210, realmKey = "SelfTest", bossKey = "ordos", phaseId = 64, spawnGUID = "B", spawnSignature = "B", spawnedAt = base + 200, source = "selftest" }
    self:Apply(first); self:Apply(death); self:Apply(death); self:Apply(nextSpawn); self:Apply(nextSpawn)
    local root = EnsureRoot()
    local sampleCount = 0
    for _ in pairs(root.samples) do sampleCount = sampleCount + 1 end
    local sample
    for _, value in pairs(root.samples) do sample = value end
    local passed = sampleCount == 1 and sample and sample.elapsedSeconds == 180 and self:GetPendingCount("ordos", "SelfTest") == 0
    YiboAltoBossDB.trackingV3 = backup
    YiboAltoBossDB.respawnSamples = legacyBackup
    return passed, passed and "1 sample / 180 seconds / idempotent" or "tracking reducer assertion failed"
end
