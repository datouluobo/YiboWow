local Addon = _G.YiboMail
local Targets = { PROVIDER = "YiboMail:targets" }; Addon.GoalTargets = Targets
function Targets:Normalize(r)
    local intent = r.intent
    if type(intent) ~= "table" or intent.objectID ~= "view-mailbox" then return nil, "此入口支持明确添加的新邮件查看目标" end
    local clean = Addon.Core.Defaults:Copy(intent); clean.scope = clean.scope or { mode = "character" }
    if not clean.scope.characterID then return { needsConfiguration = true, fields = {} } end
    if not Addon.Core.Characters:Get(clean.scope.characterID, { identityOnly = true }) then return nil, "角色不存在" end
    clean.targetType, clean.repeatPolicy, clean.scope.mode, clean.conditions = "mail-view", "once", "character", {}
    return { intent = clean, identity = self.PROVIDER .. ":" .. clean.scope.characterID .. ":view", title = "查看已添加的邮箱新邮件", fields = {} }
end
function Targets:Evaluate(r)
    local meta = Addon.ActionTodo:Metadata()
    local result = { sourceEpoch = Addon.db.goalSourceEpoch, revision = meta.revision, sourceTitle = "邮件查看", evaluations = {} }
    local ids, seen = {}, {}
    for _, goal in ipairs(r.goals or {}) do local id = goal.intent.scope.characterID; if id and not seen[id] then ids[#ids+1] = id; seen[id] = true end end
    local value = Addon.ActionTodo:Query({ scope = { characterIDs = ids } })
    local tasks = {}; for _, task in ipairs(value and value.data.tasks or {}) do tasks[task.execution.characterID] = task end
    for _, goal in ipairs(r.goals or {}) do
        local id = goal.intent.scope.characterID
        local task, coverage = tasks[id], value and value.coverage[id]
        if not task then
            local known = coverage and (coverage.state == "known" or coverage.state == "known-empty")
            task = { title = goal.title, reason = known and "当前新邮件已查看" or "打开邮箱同步查看状态", state = known and "completed" or "active", readiness = known and "not-applicable" or "unknown",
                execution = { mode = "self", characterID = id }, beneficiary = { mode = "character", characterID = id }, temporal = { kind = "persistent" },
                freshness = { state = known and "known" or "partial", observedAt = coverage and coverage.observedAt }, nextAction = { kind = "open-page", pageID = "mail-inbox" } }
        end
        result.evaluations[goal.id] = { task = task }
    end
    return result
end

function Targets:Initialize()
    local core = Addon.Core
    if not (core:CheckAPIVersion(12) and core:HasCapability("business-item-actions", 1)) then Addon:Print("主动添加目标需要 Core API v12，请升级 Core。"); return end
    if self.ref then return true end
    local db = Addon.db
    db.goalSourceEpoch = db.goalSourceEpoch or ("yibomail:" .. Addon:Now() .. ":" .. math.random(100000,999999))
    self.definition = { name = "action.targets", kind = "provider", providerID = self.PROVIDER, version = { major = 1, minor = 1 },
        methods = { GetEntry = function() return { title = "查看邮箱", pageID = "mail-inbox" } end, Normalize = function(r) return Targets:Normalize(r) end, Evaluate = function(r) return Targets:Evaluate(r) end } }
    self.ref = core.Contracts:Register("YiboMail", self.definition); return self.ref ~= nil
end
function Targets:Bind(control, objectID, characterID, original)
    if not self.ref then return end
    local core = Addon.Core
    local intent = { providerID = self.PROVIDER, objectID = objectID, scope = { mode = "character", characterID = characterID }, conditions = {} }
    core.BusinessItemActions:Bind(control, { owner = "YiboMail", GetIntent = function() return intent end, ctrlLeftSafe = true, reservedButtons = { LeftButton = original ~= nil } })
    control:RegisterForClicks("AnyUp"); control:SetScript("OnClick", function(self, button)
        if core.BusinessItemActions:Handle(self, button) then return end
        if original and button == "LeftButton" then original(self, button) end
    end)
end
