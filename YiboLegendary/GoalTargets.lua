local Addon = _G.YiboLegendary
local Targets = { PROVIDER = "YiboLegendary:targets" }; Addon.GoalTargets = Targets
function Targets:Normalize(r)
    local intent = r.intent
    local target = type(intent) == "table" and Addon.Catalog:GetTarget(intent.objectID)
    if not target then return nil, Addon:T("GOAL.SELECT_TARGET") end
    local clean = Addon.Core.Defaults:Copy(intent); clean.scope = clean.scope or { mode = "character" }
    if not clean.scope.characterID then return { needsConfiguration = true, fields = {} } end
    if not Addon.Core.Characters or type(Addon.Core.Characters.Get) ~= "function" or not Addon.Core.Characters:Get(clean.scope.characterID, { identityOnly = true }) then return nil, Addon:T("GOAL.CHARACTER_MISSING") end
    clean.targetType, clean.repeatPolicy, clean.scope.mode, clean.conditions = "legendary", "once", "character", {}
    return { intent = clean, identity = self.PROVIDER .. ":" .. clean.scope.characterID .. ":" .. target.id, title = target.title, fields = {} }
end
function Targets:Evaluate(r)
    local result = { sourceEpoch = Addon.db.goalSourceEpoch, revision = Addon.db.goalRevision or 0, sourceTitle = "传奇之路", evaluations = {} }
    for _, goal in ipairs(r.goals or {}) do
        local clean, err = self:Normalize({ intent = goal.intent })
        if clean and not clean.needsConfiguration then
            local id = clean.intent.scope.characterID
            local store = Addon.db.byCharacter[id]
            local snapshot = store and store.snapshot
            local state = snapshot and snapshot.targets and snapshot.targets[clean.intent.objectID]
            local evidence = state and state.evidence
            local known = evidence and (evidence.source == "real" or evidence.source == "manual") and state.status ~= "unknown" and state.status ~= "pending_sync" and state.status ~= "unavailable"
            local done = known and state.acquired == true
            local reason = known and (state.nextAction or state.progressText or state.stageLabel) or "传奇进度待同步或仅有测试投影"
            result.evaluations[goal.id] = { task = { title = clean.title, reason = reason, summary = reason,
                state = done and "completed" or "active", readiness = known and (done and "not-applicable" or (state.status == "ineligible" and "blocked" or "actionable")) or "unknown",
                execution = { mode = "self", characterID = id }, beneficiary = { mode = "character", characterID = id },
                temporal = { kind = "persistent" }, freshness = { state = known and "known" or "partial", observedAt = evidence and evidence.updatedAt },
                nextAction = { kind = "open-page", pageID = "legendary" } } }
        else result.evaluations[goal.id] = { reason = err } end
    end
    return result
end

function Targets:Initialize()
    local core = Addon.Core
    if not (core:CheckAPIVersion(12) and core:HasCapability("business-item-actions", 1)
        and core.Contracts and type(core.Contracts.Register) == "function"
        and core.BusinessItemActions and type(core.BusinessItemActions.Bind) == "function"
        and type(core.BusinessItemActions.Handle) == "function") then
        core:Print(Addon:T("GOAL.CORE_ACTIONS_REQUIRED")); return false
    end
    if self.ref then return true end
    local db = Addon.db
    db.goalSourceEpoch = db.goalSourceEpoch or ("yibolegendary:" .. Addon:GetTimestamp() .. ":" .. math.random(100000,999999))
    self.definition = { name = "action.targets", kind = "provider", providerID = self.PROVIDER, version = { major = 1, minor = 1 },
        methods = { GetEntry = function() return { title = "传奇之路", pageID = "legendary" } end, Normalize = function(r) return Targets:Normalize(r) end, Evaluate = function(r) return Targets:Evaluate(r) end } }
    self.ref = core.Contracts:Register("YiboLegendary", self.definition)
    return self.ref ~= nil
end
function Targets:Bind(control, objectID, characterID, original)
    if not self.ref then return end
    local core = Addon.Core
    local intent = { providerID = self.PROVIDER, objectID = objectID, scope = { mode = "character", characterID = characterID }, conditions = {} }
    core.BusinessItemActions:Bind(control, { owner = "YiboLegendary", GetIntent = function() return intent end, ctrlLeftSafe = true, reservedButtons = { LeftButton = true, RightButton = true } })
    control:RegisterForClicks("AnyUp"); control:SetScript("OnClick", function(self, button)
        if core.BusinessItemActions:Handle(self, button) then return end
        if original and button == "LeftButton" then original(self, button) end
    end)
end
