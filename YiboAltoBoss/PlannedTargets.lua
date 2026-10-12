local YAB = _G.YAB
local Plans = { OWNER = "YiboAltoBoss", PROVIDER = "YiboAltoBoss:planned-targets" }
YAB.PlannedTargets = Plans
local WORLD_FLAGS = { ordos = 33118, celestials = 33117, nalak = 32518, oondasta = 32519, galleon = 32098, sha_of_anger = 32099 }
local function Core() return _G.YiboCore end
local function Now() return GetServerTime and GetServerTime() or time() end
local function Copy(t) return Core().Defaults:Copy(t) end
local function Encode(value)
    if type(value) ~= "table" then return type(value) .. ":" .. tostring(value) end
    local keys, result = {}, {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do result[#result + 1] = Encode(key) .. "=" .. Encode(value[key]) end
    return "{" .. table.concat(result, ";") .. "}"
end
function Plans:Period(kind)
    local query = kind == "weekly" and C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
        or (kind == "daily" and GetQuestResetTime)
    if type(query) ~= "function" then return nil end
    local ok, seconds = pcall(query)
    if not ok or type(seconds) ~= "number" or seconds <= 0 then return nil end
    local boundary = Now() + math.floor(seconds + 0.5)
    boundary = boundary - boundary % 60
    return kind .. ":" .. boundary, boundary
end
function Plans:LegacyKey(id)
    for key in pairs(YiboAltoBossDB.knownChars or {}) do if Core().Characters:ResolveLegacyKey(key) == id then return key end end
end
function Plans:Configuration(ids)
    local ref = Core().Contracts:Resolve("task.boss-targets", { major = 1 })
    if not ref then return nil end
    local parts = {}
    for _, id in ipairs(ids) do parts[#parts + 1] = #id .. ":" .. id end
    local key = table.concat(parts, "|")
    if self.configurationRef ~= ref.registrationRef then self.configurations, self.configurationRef = {}, ref.registrationRef end
    if self.configurations[key] then return self.configurations[key] end
    local value = Core().Contracts:Call(self.OWNER, ref, "Query", { scope = { characterIDs = ids } })
    if type(value) ~= "table" or type(value.targets) ~= "table" or type(value.sourceEpoch) ~= "string"
        or type(value.revision) ~= "number" or type(value.autoDisplay) ~= "boolean" then return nil end
    for _, id in ipairs(ids) do
        if type(value.targets[id]) ~= "table" then return nil end
        for _, target in ipairs(value.targets[id]) do
            if type(target) ~= "table" or type(target.id) ~= "string" or type(target.catalogID) ~= "string"
                or type(target.title) ~= "string" or type(target.active) ~= "boolean" or type(target.encounterIDs) ~= "table"
                or not ({ world = true, holiday = true, instance = true, custom = true })[target.kind]
                or not ({ all = true, boss = true })[target.scope]
                or (target.kind == "instance" and type(target.difficultyID) ~= "number") then return nil end
            for _, encounterID in ipairs(target.encounterIDs) do
                if type(encounterID) ~= "number" and type(encounterID) ~= "string" then return nil end
            end
        end
    end
    local count = 0; for _ in pairs(self.configurations) do count = count + 1 end
    if count >= 24 then self.configurations = {} end
    self.configurations[key] = value
    return value
end
function Plans:Observe()
    local key = YAB.GetCurrentCharKey()
    local record = YiboAltoBossDB.characters and YiboAltoBossDB.characters[key]
    if not record then return end
    local cycle, boundary = self:Period("weekly")
    local changed = false
    local query = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted
    if cycle and type(query) == "function" then
        record.targetObservations = record.targetObservations or {}
        for bossKey, questID in pairs(WORLD_FLAGS) do
            local ok, done = pcall(query, questID)
            local previous = record.targetObservations[bossKey]
            if ok and type(done) == "boolean" and (not previous or previous.completed ~= done
                or previous.cycleKey ~= cycle or previous.validUntil ~= boundary) then
                record.targetObservations[bossKey] = {
                    completed = done, observedAt = Now(), cycleKey = cycle, validUntil = boundary }
                changed = true
            end
        end
    end
    if YAB.Holiday and YAB.Holiday:ObservePlanned("holiday:coren-direbrew") then changed = true end
    if changed then self:ScheduleChange() end
end
function Plans:Progress(characterID, target)
    local definition = YAB.TargetCatalog:Get(target.catalogID)
    local unknown = { state = "unknown", freshness = "not-yet-scanned", reason = "尚未采集角色进度", kind = "weekly" }
    if not definition then unknown.reason = "目标目录暂不可用"; return unknown end
    local key = self:LegacyKey(characterID)
    local record = key and YiboAltoBossDB.characters and YiboAltoBossDB.characters[key]
    if definition.kind == "custom" then
        unknown.kind = "cooldown"
        if not record or not YAB.GetBossKillStatus then return unknown end
        -- Reuse the owner's status and expiry, including manual marks and
        -- legacy record migration. Custom NPCs have no weekly lockout API.
        local status, info = YAB.GetBossKillStatus(key, definition.bossKey)
        if status == "killed" and info and info.updatedAt and info.expiresAt and info.expiresAt > Now() then
            return { state = "completed", freshness = "known", observedAt = info.updatedAt,
                validUntil = info.expiresAt, kind = "cooldown", cycleKey = definition.id .. ":" .. tostring(info.updatedAt),
                reason = "已记录击杀，按自定义目标规则恢复" }
        elseif status == "available" then
            return { state = "ready", freshness = "known", kind = "cooldown",
                cycleKey = definition.id .. ":pending", reason = "自定义目标待击杀" }
        end
        return unknown
    end
    if definition.kind == "holiday" then
        local snapshot = YAB.Holiday:GetTargetSnapshot(key, definition.bossKey)
        if not snapshot then return unknown end
        local observation = snapshot.record
        local closed = snapshot.availability == "closed"
        local verified = snapshot.open and observation and observation.observedAt
        return { state = closed and "dormant" or (snapshot.open and observation and observation.completed and "completed" or (verified and "ready" or "unknown")),
            freshness = closed and "known" or (verified and "known" or "not-yet-scanned"),
            observedAt = observation and observation.observedAt, validUntil = snapshot.nextResetAt,
            cycleKey = snapshot.cycleKey, kind = "daily", reason = closed and "活动未开放" or (not snapshot.open and "活动日历待核实" or "节日每日目标") }
    end
    local kind = definition.kind == "instance" and not definition.isRaid and "daily" or "weekly"
    local cycle, boundary = self:Period(kind)
    unknown.kind, unknown.cycleKey, unknown.validUntil = kind, cycle, boundary
    if not cycle then unknown.reason = "服务器重置时间暂不可用"; return unknown end
    if not record then return unknown end
    if definition.kind == "world" then
        local obs = record.targetObservations and record.targetObservations[definition.bossKey]
        if not obs then return unknown end
        local fresh = obs.cycleKey == cycle and obs.validUntil and obs.validUntil > Now()
        local character = Core().Characters:Get(characterID, { identityOnly = true })
        local eligible = character and tonumber(character.level) and character.level >= 90 and definition.bossKey ~= "ordos"
        if fresh and not obs.completed and not eligible then
            return { state = "unknown", freshness = "partial", observedAt = obs.observedAt, validUntil = boundary,
                cycleKey = cycle, kind = kind, reason = definition.bossKey == "ordos" and "斡耳朵斯准入条件待核实" or "角色等级资格待核实" }
        end
        return { state = fresh and (obs.completed and "completed" or "ready") or "unknown", freshness = fresh and "known" or "stale",
            observedAt = obs.observedAt, validUntil = boundary, cycleKey = cycle, kind = kind,
            reason = fresh and (obs.completed and "本周已完成" or "本周待击杀") or "重置后待重新采集" }
    end
    local difficulty
    for _, d in ipairs(definition.difficulties or {}) do if d.id == target.difficultyID then difficulty = d end end
    if not difficulty or not difficulty.complete or difficulty.trackable == false then unknown.reason = "该难度的目录或锁定规则待核实"; return unknown end
    local observedAt = record.instanceLockoutsObservedAt
    local fresh = record.targetLockoutCycles and record.targetLockoutCycles[kind] == cycle
    if not fresh or not observedAt then unknown.freshness = observedAt and "stale" or "not-yet-scanned"; unknown.observedAt = observedAt; return unknown end
    local lockout
    for _, candidate in pairs(record.instanceLockouts or {}) do
        -- Identity mapping is explicit; names and loose difficulty matches are
        -- never sufficient evidence of the planned dungeon's completion.
        if definition.mapID and candidate.instanceID == definition.mapID and candidate.difficultyID == target.difficultyID
            and candidate.resetAt and candidate.resetAt > Now() then lockout = candidate; break end
    end
    local wanted, killed, total = {}, 0, 0
    for _, e in ipairs(difficulty.encounters) do if target.scope == "all" then wanted[e.id] = true end end
    if target.scope ~= "all" then for _, id in ipairs(target.encounterIDs or {}) do wanted[id] = true end end
    for _ in pairs(wanted) do total = total + 1 end
    if total == 0 or not definition.mapID then unknown.reason = "副本身份或首领目录待核实"; return unknown end
    local seen, found = {}, 0
    for _, boss in ipairs(lockout and lockout.bosses or {}) do if wanted[boss.encounterID] and not seen[boss.encounterID] then
        seen[boss.encounterID], found = true, found + 1
        if boss.killed then killed = killed + 1 end
    end end
    local verified = not lockout or found == total
    return { state = verified and (killed >= total and "completed" or "ready") or "unknown",
        freshness = verified and "known" or "partial", observedAt = observedAt, validUntil = boundary,
        cycleKey = cycle, kind = kind, killed = killed, total = total,
        reason = not verified and "锁定中的首领记录不完整" or string.format("%d/%d 首领", killed, total), lockout = lockout }
end
function Plans:Describe(target)
    local title = target.title .. (target.difficultyName and (" · " .. target.difficultyName) or "")
    if target.kind ~= "instance" then return title, "" end
    if target.scope == "all" then return title .. " · 整本", "整本全部首领" end
    local wanted, names = {}, {}
    for _, id in ipairs(target.encounterIDs) do wanted[id] = true end
    local definition = YAB.TargetCatalog:Get(target.catalogID)
    for _, difficulty in ipairs(definition and definition.difficulties or {}) do if difficulty.id == target.difficultyID then
        for _, encounter in ipairs(difficulty.encounters) do if wanted[encounter.id] then names[#names + 1] = encounter.name end end
    end end
    local summary = #names > 0 and table.concat(names, "、") or "指定首领目录待核实"
    return title .. " · " .. (#names == 1 and names[1] or (tostring(#target.encounterIDs) .. " 位首领")), summary
end
local function RequestIDs(request)
    local ids = type(request) == "table" and type(request.scope) == "table" and request.scope.characterIDs
    if type(ids) ~= "table" then return nil, "invalid-request" end
    local count = 0
    for k, id in pairs(ids) do
        if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or type(id) ~= "string" or id == "" then return nil, "invalid-request" end
        count = count + 1
    end
    if count ~= #ids then return nil, "invalid-request" end
    return ids
end
function Plans:Project(ids)
    local db, seen = YiboAltoBossDB.plannedTargetSource, {}
    local result = { providerID = self.PROVIDER, sourceTitle = "首领与副本目标", sourceEpoch = db.sourceEpoch, revision = db.revision,
        generatedAt = Now(), status = "ready", coverage = {}, data = { tasks = {} } }
    local config = self:Configuration(ids)
    for _, id in ipairs(ids) do if not seen[id] then
        seen[id] = true
        local known = Core().Characters:Get(id, { identityOnly = true }) ~= nil
        local coverage = { state = known and config and "known-empty" or "unavailable", reason = not known and "角色不在目录中" or (config and "未配置目标" or "目标服务未连接") }
        for _, target in ipairs(known and config and config.targets[id] or {}) do if target.active then
            local p = self:Progress(id, target)
            local title, description = self:Describe(target)
            local key = id .. ":" .. target.id
            local task = { itemKey = key, title = title,
                summary = description ~= "" and (description .. " · " .. p.reason) or p.reason, reason = p.reason, state = p.state == "completed" and "completed" or (p.state == "dormant" and "paused" or "active"),
                readiness = p.state == "completed" and "not-applicable" or (p.state == "ready" and "actionable" or (p.state == "waiting" and "blocked" or "unknown")),
                businessRef = { capability = "action.todo", providerID = self.PROVIDER, sourceEpoch = db.sourceEpoch, key = key },
                execution = { mode = "self", characterID = id }, beneficiary = { mode = "character", characterID = id },
                temporal = { kind = p.kind, cycleKey = p.cycleKey, nextChangeAt = p.validUntil },
                freshness = { state = p.freshness, observedAt = p.observedAt, validUntil = p.validUntil, clockSource = "server" },
                nextAction = { kind = "open-page", pageID = target.kind == "instance" and "alto-lockouts" or "alto-boss", title = "查看首领追踪" } }
            result.data.tasks[#result.data.tasks + 1] = task
            if coverage.state == "known-empty" or p.freshness ~= "known" then coverage = { state = p.freshness, observedAt = p.observedAt, validUntil = p.validUntil, nextChangeAt = p.validUntil } end
        end end
        result.coverage[id] = coverage
        if coverage.state ~= "known" and coverage.state ~= "known-empty" then result.status = "partial" end
    end end
    return Copy(result)
end
function Plans:Commit()
    local weekly = self:Period("weekly")
    local daily = self:Period("daily")
    if self.value and not self.dirty and self.weekly == weekly and self.daily == daily
        and (not self.expiresAt or Now() < self.expiresAt) then return YiboAltoBossDB.plannedTargetSource end
    local ids = {}; for _, c in ipairs(Core().Characters:GetAll({ identityOnly = true })) do ids[#ids + 1] = c.id end
    local value = self:Project(ids)
    self.value, self.dirty, self.weekly, self.daily, self.expiresAt = value, false, weekly, daily, nil
    for _, task in ipairs(value.data.tasks) do
        local at = task.freshness.validUntil
        if at and at > Now() and (not self.expiresAt or at < self.expiresAt) then self.expiresAt = at end
    end
    value.generatedAt, value.revision = nil, nil
    local fingerprint, meta = Encode(value), YiboAltoBossDB.plannedTargetSource
    if meta.fingerprint ~= fingerprint then meta.fingerprint, meta.revision = fingerprint, meta.revision + 1 end
    return meta
end
function Plans:Query(request)
    local ids, err = RequestIDs(request)
    if not ids then return nil, err end
    local meta = self:Commit()
    local allowed, coverage, tasks = {}, {}, {}
    for _, id in ipairs(ids) do
        allowed[id] = true
        coverage[id] = self.value.coverage[id] or { state = "unavailable", reason = "角色不在目录中" }
    end
    for _, task in ipairs(self.value.data.tasks) do if allowed[task.execution.characterID] then tasks[#tasks + 1] = task end end
    local status = "ready"
    for _, item in pairs(coverage) do if item.state ~= "known" and item.state ~= "known-empty" then status = "partial" end end
    return Copy({ providerID = self.PROVIDER, sourceTitle = "首领与副本目标", sourceEpoch = meta.sourceEpoch,
        revision = meta.revision, generatedAt = Now(), status = status, coverage = coverage, data = { tasks = tasks } })
end
function Plans:ScheduleChange()
    self.dirty = true
    if not self.providerRef or self.queued then return end
    self.queued = true
    local generation = self.generation or 0
    local function Flush()
        if generation ~= (Plans.generation or 0) then return end
        self.queued = false
        if not Plans.providerRef then return end
        local meta = Plans:Commit()
        if Plans.notifiedRevision ~= meta.revision then
            Plans.notifiedRevision = meta.revision
            Core().Contracts:NotifyChanged(Plans.OWNER, Plans.providerRef, { sourceEpoch = meta.sourceEpoch, revision = meta.revision })
            if YAB.GoalTargets and YAB.GoalTargets.ref then
                Core().Contracts:NotifyChanged(Plans.OWNER, YAB.GoalTargets.ref, { sourceEpoch = meta.sourceEpoch, revision = meta.revision })
            end
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Flush) else Flush() end
end
function Plans:Initialize()
    if self.providerRef then return true end
    local core = Core()
    if not (core and core:CheckAPIVersion(11) and core:HasCapability("business-services", 1) and core:HasCapability("business-providers", 1)
        and core:HasCapability("character-name-format", 1) and core:HasCapability("character-identity", 1) and core.Characters and core.Characters.FormatName) then
        if core and core.Print then core:Print("首领刷取目标需要 YiboCore API v11，请升级 Core。") end
        return nil, "core-version"
    end
    YiboAltoBossDB.plannedTargetSource = YiboAltoBossDB.plannedTargetSource or { sourceEpoch = "boss:" .. Now() .. ":" .. math.random(100000,999999), revision = 0 }
    for _, event in ipairs({ "BUSINESS_CONTRACT_REGISTERED", "BUSINESS_CONTRACT_UNREGISTERED", "BUSINESS_CONTRACT_CHANGED" }) do
        core.Events:Register(event, self, function(_, descriptor)
            if descriptor.name == "task.boss-targets" then
                Plans.configurations = {}
                Plans:ScheduleChange(); YAB.NotifyCorePageChanged()
            end
        end)
    end
    for _, event in ipairs({ "CHARACTER_UPDATED", "CHARACTER_ID_CHANGED", "CHARACTER_CACHE_DELETED" }) do
        core.Events:Register(event, self, function() Plans:ScheduleChange() end)
    end
    self.catalogDefinition = self.catalogDefinition or { kind = "service", name = "boss.target-catalog", providerID = self.OWNER .. ":target-catalog",
        version = { major = 1, minor = 0 }, methods = { Query = function() return YAB.TargetCatalog:Query() end } }
    self.providerDefinition = self.providerDefinition or { kind = "provider", name = "action.todo", providerID = self.PROVIDER,
        version = { major = 1, minor = 0 }, methods = { Query = function(request) return Plans:Query(request) end } }
    local err
    self.catalogRef, err = core.Contracts:Register(self.OWNER, self.catalogDefinition)
    if not self.catalogRef then self:Shutdown(); return nil, err end
    self.providerRef, err = core.Contracts:Register(self.OWNER, self.providerDefinition)
    if not self.providerRef then self:Shutdown(); return nil, err end
    self.frame = self.frame or CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "UPDATE_INSTANCE_INFO", "CALENDAR_UPDATE_EVENT_LIST", "PLAYER_REGEN_ENABLED" }) do self.frame:RegisterEvent(event) end
    self.frame:SetScript("OnEvent", function(_, event)
        if event == "UPDATE_INSTANCE_INFO" then
            YAB.InvalidateInstanceCatalog()
            YAB.TargetCatalog:Invalidate()
            core.Contracts:NotifyChanged(Plans.OWNER, Plans.catalogRef, {})
        end
        Plans:Observe()
    end)
    if YAB.GoalTargets then YAB.GoalTargets:Initialize() end
    self:Observe(); self:ScheduleChange()
    return true
end
function Plans:Shutdown()
    if YAB.GoalTargets and YAB.GoalTargets.ref then Core().Contracts:Unregister(self.OWNER, YAB.GoalTargets.ref); YAB.GoalTargets.ref = nil end
    local core = Core()
    for _, event in ipairs({ "BUSINESS_CONTRACT_REGISTERED", "BUSINESS_CONTRACT_UNREGISTERED", "BUSINESS_CONTRACT_CHANGED",
        "CHARACTER_UPDATED", "CHARACTER_ID_CHANGED", "CHARACTER_CACHE_DELETED" }) do core.Events:Unregister(event, self) end
    if self.catalogRef then core.Contracts:Unregister(self.OWNER, self.catalogRef) end
    if self.providerRef then core.Contracts:Unregister(self.OWNER, self.providerRef) end
    self.generation = (self.generation or 0) + 1
    self.catalogRef, self.providerRef, self.queued = nil, nil, nil
    self.value, self.dirty = nil, true
    self.configurations, self.configurationRef = nil, nil
    if self.frame then self.frame:UnregisterAllEvents() end
end
