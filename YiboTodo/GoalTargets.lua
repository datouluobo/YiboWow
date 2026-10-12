local Addon = _G.YiboTodo
local Targets = { PROVIDER = "YiboTodo:targets" }
Addon.GoalTargets = Targets
local function Definition(id)
    return Addon.Catalog.groups[id] or Addon.Catalog.dailyActivities[id]
        or (Addon.Catalog.farmOperations and Addon.Catalog.farmOperations[id])
        or (Addon.Catalog.specialActivities and Addon.Catalog.specialActivities[id])
end
function Targets:Intent(project, characterID)
    if not project or not project.groupID then return nil end
    return { providerID = self.PROVIDER, targetType = "activity", objectID = project.groupID,
        scope = { mode = project.scope == "account" and "account" or "character", characterID = characterID or project.characterID,
            characterIDs = project.scope == "account" and { characterID or project.characterID } or nil },
        conditions = {}, repeatPolicy = "recurring" }
end
function Targets:Normalize(request)
    local intent = request.intent
    local definition = type(intent) == "table" and Definition(intent.objectID)
    if not definition then return nil, Addon:T("GOAL.INVALID") end
    local scope = intent.scope or {}
    if scope.mode ~= "character" and scope.mode ~= "account" then return nil, Addon:T("GOAL.SCOPE") end
    if scope.mode == "character" and not scope.characterID then return { needsConfiguration = true, fields = {} } end
    if scope.mode == "character" and not Addon.Core.Characters:Get(scope.characterID, { identityOnly = true }) then return nil, Addon:T("GOAL.CHARACTER_MISSING") end
    if scope.mode == "account" and (type(scope.characterIDs) ~= "table" or #scope.characterIDs == 0) then return nil, Addon:T("GOAL.ACCOUNT_SCOPE") end
    local clean = Addon.Core.Defaults:Copy(intent)
    clean.repeatPolicy = "recurring"; clean.conditions = {}; clean.targetType = "activity"
    local scopeKey = scope.mode == "character" and scope.characterID or table.concat(scope.characterIDs, ",")
    return { intent = clean, identity = self.PROVIDER .. ":" .. #intent.objectID .. ":" .. intent.objectID .. ":" .. scopeKey,
        title = definition.label or definition.name or intent.objectID, fields = {} }
end
function Targets:Evaluate(request)
    local meta = Addon.ActionTodo:GetMetadata()
    local result = { sourceEpoch = meta.sourceEpoch, revision = meta.revision, sourceTitle = Addon:T("GOAL.SOURCE_TITLE"), evaluations = {} }
    for _, goal in ipairs(request.goals or {}) do
        local clean, err = self:Normalize({ intent = goal.intent })
        local task, coverage, display
        if clean and not clean.needsConfiguration then
            local intent, id = clean.intent, clean.intent.scope.characterID or clean.intent.scope.characterIDs[1]
            local snapshot = Addon.Snapshot:BuildTarget(id, intent.objectID)
            local project = snapshot.activities and snapshot.activities[intent.objectID] or snapshot.nomiProjects and snapshot.nomiProjects[1]
            if project then display = { item = project.iconKind == "item" and { itemID = project.icon } or nil,
                icon = project.iconKind == "texture" and project.icon or project.fallbackIcon } end
            if Addon.Catalog.groups[intent.objectID] then
                task, coverage = Addon.ActionTodo:Project(id, snapshot, Addon:Now(), meta.sourceEpoch, intent.objectID, true)
                -- A confirmed active cooldown proves this cycle's operation;
                -- an estimated cooldown is not completion evidence.
                if task and task.sourceState == "cooldown" and task.freshness.state == "known" then task.state, task.readiness = "completed", "not-applicable" end
            elseif intent.objectID == "mop.nomi" then
                task, coverage = Addon.ActionNomi:Project(id, snapshot, Addon:Now(), meta.sourceEpoch, intent.objectID, true)
            else
                local tasks; tasks, coverage = Addon.ActionActivities:ProjectAll(id, snapshot, Addon:Now(), meta.sourceEpoch, true)
                task = tasks[1]
            end
            if task and intent.scope.mode == "account" then
                task.execution = { mode = "account", candidateCharacterIDs = intent.scope.characterIDs }; task.beneficiary = { mode = "account" }
            end
        end
        result.evaluations[goal.id] = { task = task, display = display, reason = err or (coverage and coverage.reason) or Addon:T("GOAL.NEEDS_DATA") }
    end
    return result
end
function Targets:Initialize()
    local core = Addon.Core
    if not (core:CheckAPIVersion(12) and core:HasCapability("business-item-actions", 1)) then
        Addon:Print(Addon:T("GOAL.API_REQUIRED")); return nil
    end
    if self.ref then return true end
    self.definition = { name = "action.targets", kind = "provider", providerID = self.PROVIDER, version = { major = 1, minor = 2 }, methods = { GetEntry = function() return { title = Addon:T("PAGE.TITLE"), pageID = "todo" } end,
        GetClickAction = function(r) return Targets:GetClickAction(r.intent) end,
        AfterClick = function(r) return Targets:AfterClick(r.intent, r.button) end,
        Normalize = function(r) return Targets:Normalize(r) end, Evaluate = function(r) return Targets:Evaluate(r) end } }
    self.ref = core.Contracts:Register(Addon.NAME, self.definition)
    return self.ref ~= nil
end
function Targets:GetClickAction(intent)
    local clean = self:Normalize({ intent = intent })
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not clean or clean.needsConfiguration or not current or clean.intent.scope.mode ~= "character"
        or clean.intent.scope.characterID ~= current.id or not Addon.Actions then return nil end
    local snapshot = Addon.Snapshot:BuildTarget(current.id, clean.intent.objectID)
    local project = snapshot.activities and snapshot.activities[clean.intent.objectID]
        or snapshot.nomiProjects and snapshot.nomiProjects[1]
    return project and Addon.Actions:Describe(project, true)
end
function Targets:AfterClick(intent, button)
    local descriptor = self:GetClickAction(intent)
    if not descriptor then return nil end
    if button == "LeftButton" and descriptor.professionAction and Addon.QueueProfessionCooldownRefresh then
        Addon:QueueProfessionCooldownRefresh()
    end
    return true
end
function Targets:Changed()
    if self.ref then Addon.Core.Contracts:NotifyChanged(Addon.NAME, self.ref, { reason = "activity-facts-changed" }) end
end
