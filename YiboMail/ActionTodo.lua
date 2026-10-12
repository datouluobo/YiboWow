local Addon = _G.YiboMail
local Action = { PROVIDER = "YiboMail:inbox-collection" }
Addon.ActionTodo = Action

function Action:Metadata()
    local meta = Addon.db.actionTodo
    if type(meta) ~= "table" then meta = {}; Addon.db.actionTodo = meta end
    if type(meta.sourceEpoch) ~= "string" or meta.sourceEpoch == "" then
        meta.sourceEpoch = tostring(Addon:Now()) .. ":" .. tostring(math.random(1, 2147483646))
        meta.revision = 0
    end
    meta.revision = tonumber(meta.revision) or 0
    return meta
end

function Action:Query(request)
    local scope = type(request) == "table" and request.scope
    local ids = type(scope) == "table" and scope.characterIDs
    if type(ids) ~= "table" then return nil, "invalid-scope" end
    local count = 0
    for key, id in pairs(ids) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or type(id) ~= "string" or id == "" then return nil, "invalid-scope" end
        count = count + 1
    end
    local byID, characters, seen, coverage = {}, {}, {}, {}
    for _, character in ipairs(Addon.Core.Characters:GetAllCached()) do byID[character.id] = character end
    for index = 1, count do
        local id = ids[index]
        if not id then return nil, "invalid-scope" end
        if not seen[id] then
            seen[id] = true
            if byID[id] then characters[#characters + 1] = byID[id] end
            local state = Addon.Items:GetState(id)
            coverage[id] = { state = state.status, observedAt = state.observedAt, clockSource = state.clockSource }
        end
    end
    local meta, now, tasks, partial = self:Metadata(), Addon:Now(), {}, false
    for _, state in pairs(coverage) do if state.state ~= "known" and state.state ~= "known-empty" then partial = true end end
    local notices, current = {}, Addon.Core.Characters:GetCurrent()
    for _, entry in ipairs(Addon.ViewModel:GetMails({ characters = characters })) do
        local mail = entry.mail
        if mail.state == "observed" and not mail.openedByUser and not mail.noticeHandled then
            local expiry = tonumber(mail.expiresAtEstimate)
            local id = entry.character.id
            local live = coverage[id].state
            local known = current and current.id == id and (live == "known" or live == "partial") and expiry and expiry > now
            local notice = notices[id]
            if not notice then notice = { count = 0, known = true, subjects = {} }; notices[id] = notice end
            notice.count, notice.known = notice.count + 1, notice.known and known
            if expiry and (not notice.expiry or expiry < notice.expiry) then notice.expiry = expiry end
            if #notice.subjects < 3 then notice.subjects[#notice.subjects + 1] = Addon.ViewModel:Escape(mail.subject ~= "" and mail.subject or "无主题邮件") end
            notice.observedAt, notice.clockSource = mail.observedAt, mail.clockSource
        end
    end
    -- One notice per mailbox, independent of how many stored attachments it
    -- contains. Viewing letters acknowledges them in the owning Mail store.
    for _, character in ipairs(characters) do
        local notice = notices[character.id]
        local arrival = Addon.db.mailArrivalSignals[character.id]
        if arrival and arrival.awaitingScan then
            notice = notice or { count = 0, subjects = {}, known = true, observedAt = arrival.observedAt }
            notice.pending = true
            notice.known, notice.expiry, notice.observedAt = current and current.id == character.id, nil, arrival.observedAt
        end
        if notice then
            local known, expiry = notice.known, notice.expiry
            local state = coverage[character.id].state
            local freshness = known and "known" or (state == "error" and "error" or "stale")
            local key = Addon.Encode({ character.id, "new-mail", Addon.db.mailNoticeBatches[character.id] or "pending" })
            local task = {
                itemKey = key,
                businessRef = { capability = "action.todo", providerID = self.PROVIDER, sourceEpoch = meta.sourceEpoch, key = key },
                title = notice.pending and "新邮件 · 待查看" or ("新邮件 · " .. notice.count .. " 封"),
                icon = "Interface\\Icons\\INV_Letter_15",
                summary = (notice.pending and "游戏提示收到新邮件，打开邮箱核对。" or
                    ("尚未查看：" .. table.concat(notice.subjects, "、") .. (notice.count > 3 and "等。" or "。")))
                    .. "查看信件或展开附件后即停止提醒；附件可继续保存在邮箱。",
                execution = { mode = "self", characterID = character.id },
                beneficiary = { mode = "character", characterID = character.id },
                state = "active", readiness = known and "actionable" or "unknown", reason = known and "待查看" or "新邮件待核实",
                temporal = { kind = "persistent", nextChangeAt = expiry and expiry > now and expiry or nil },
                freshness = { state = freshness, observedAt = notice.observedAt,
                    validUntil = expiry, clockSource = notice.clockSource },
            }
            if Addon.FEATURES.account then task.nextAction = { kind = "open-page", title = "查看邮件", pageID = "mail-inbox" } end
            tasks[#tasks + 1] = task
        end
    end
    return { providerID = self.PROVIDER, sourceTitle = "新邮件", sourceEpoch = meta.sourceEpoch, revision = meta.revision,
        generatedAt = now, status = partial and "partial" or "ready", coverage = coverage, data = { tasks = tasks } }
end

function Action:Changed()
    if not self.ref or self.queued then return end
    self.queued = true
    local generation = self.generation
    local function Flush()
        if Action.generation ~= generation or not Action.ref then return end
        Action.queued = nil
        if Addon.GoalTargets and Addon.GoalTargets.ref then Addon.Core.Contracts:NotifyChanged(Addon.NAME, Addon.GoalTargets.ref, { reason = "mail-view-changed" }) end
        local meta = Action:Metadata(); meta.revision = meta.revision + 1
        Addon.Core.Contracts:NotifyChanged(Addon.NAME, Action.ref,
            { sourceEpoch = meta.sourceEpoch, revision = meta.revision, reason = "mail-snapshot-changed" })
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Flush) else Flush() end
end

function Action:Initialize()
    if self.ref then return true end
    local core = Addon.Core
    if not (core and core:CheckAPIVersion(11) and core:HasCapability("business-providers", 1)
        and core.Contracts and type(core.Contracts.List) == "function") then
        return nil, "行动中心邮件集成需要升级 YiboCore 至 API v11；邮件基础功能仍可使用。"
    end
    self:Metadata()
    self.callback = self.callback or function() Action:Changed() end
    Addon.Items.Events:Register(self, self.callback)
    self.definition = self.definition or { name = "action.todo", kind = "provider", providerID = self.PROVIDER,
        version = { major = 1, minor = 0 }, methods = { Query = function(request) return Action:Query(request) end } }
    local ref, err = core.Contracts:Register(Addon.NAME, self.definition)
    if not ref then Addon.Items.Events:Unregister(self, self.callback); return nil, err end
    self.ref = ref
    return true
end

function Action:Shutdown()
    self.generation, self.queued = (self.generation or 0) + 1, nil
    Addon.Items.Events:Unregister(self, self.callback)
    if self.ref then local ref = self.ref; self.ref = nil; Addon.Core.Contracts:Unregister(Addon.NAME, ref) end
end
