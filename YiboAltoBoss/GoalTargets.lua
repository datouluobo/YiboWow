if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB = _G.YAB
local Targets = { PROVIDER = "YiboAltoBoss:targets" }
YAB.GoalTargets = Targets
local function Core() return _G.YiboCore end
local function Now() return GetServerTime and GetServerTime() or time() end
local function Validate(target)
    if type(target) ~= "table" or type(target.catalogID) ~= "string" then return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SELECT_A_TARGET") end
    local definition = YAB.TargetCatalog:Get(target.catalogID)
    if not definition then return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.THE_TARGET_CATALOG_CHANGED_SELECT_THE_TARGET_AGAIN") end
    if definition.available == false then return nil, definition.reason or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.THIS_TARGET_IS_NOT_SUPPORTED_YET") end
    if target.scope ~= "all" and target.scope ~= "boss" then return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SELECT_THE_WHOLE_INSTANCE_OR_SPECIFIC_BOSSES") end
    local result = { catalogID = definition.id, title = definition.name, kind = definition.kind, active = target.active ~= false,
        scope = target.scope == "all" and "all" or "boss", encounterIDs = {} }
    if definition.kind == "instance" then
        local difficulty
        for _, d in ipairs(definition.difficulties or {}) do if d.id == target.difficultyID then difficulty = d end end
        if not difficulty then return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SELECT_A_VERIFIED_INSTANCE_DIFFICULTY") end
        if not definition.complete or not difficulty.complete then return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.THE_BOSS_CATALOG_IS_INCOMPLETE_THIS_INSTANCE_GOAL_CANNOT_BE_SAVED_YET") end
        if difficulty.trackable == false then return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.NORMAL_FIVE_PLAYER_DUNGEONS_HAVE_NO_PERIODIC_LOCKOUT_AUTOMATIC_GOAL_COMP") end
        result.difficultyID, result.difficultyName = difficulty.id, difficulty.name
        if result.scope == "boss" then
            local valid, seen = {}, {}
            for _, e in ipairs(difficulty.encounters or definition.encounters or {}) do valid[e.id] = true end
            if type(target.encounterIDs) ~= "table" then return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SELECT_BOSSES") end
            for _, id in ipairs(target.encounterIDs) do
                if not valid[id] then return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.THE_BOSS_CATALOG_CHANGED") end
                if not seen[id] then result.encounterIDs[#result.encounterIDs + 1], seen[id] = id, true end
            end
            if #result.encounterIDs == 0 then return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SELECT_AT_LEAST_ONE_BOSS") end
            table.sort(result.encounterIDs)
        end
    else result.scope = "all" end
    return result
end

function Targets:Normalize(r)
    local intent = r.intent
    if type(intent) ~= "table" or type(intent.conditions) ~= "table" then return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SELECT_A_BOSS_TARGET") end
    local raw, scope = intent.conditions, intent.scope or {}
    local definition = YAB.TargetCatalog:Get(raw.catalogID)
    if not definition then return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.TARGET_CATALOG_TEMPORARILY_UNAVAILABLE") end
    local fields = { { id = "repeatPolicy", label = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.COMPLETION_POLICY"), kind = "select", default = intent.repeatPolicy or "recurring",
        options = { { value = "recurring", label = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.REPEAT_BY_SOURCE_CYCLE") }, { value = "once", label = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.COMPLETE_ONCE") } } } }
    if definition.kind == "instance" then
        local options = {}
        for _, d in ipairs(definition.difficulties or {}) do if d.trackable ~= false and d.complete then options[#options+1] = { value = d.id, label = d.name } end end
        fields[#fields+1] = { id = "difficultyID", label = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.INSTANCE_DIFFICULTY"), kind = "select", options = options }
    end
    if not scope.characterID or (definition.kind == "instance" and not raw.difficultyID) then return { needsConfiguration = true, fields = fields, title = definition.name } end
    local clean, err = Validate(raw)
    if not clean then return nil, err end
    if not Core().Characters:Get(scope.characterID, { identityOnly = true }) then return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CHARACTER_NOT_FOUND") end
    clean.active = nil; clean.id = nil
    local policy = raw.repeatPolicy or intent.repeatPolicy or "recurring"
    if policy ~= "recurring" and policy ~= "once" then return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SELECT_A_COMPLETION_POLICY") end
    clean.repeatPolicy = policy
    local normalized = { providerID = self.PROVIDER, objectID = clean.catalogID, targetType = "boss", conditions = clean,
        scope = { mode = "character", characterID = scope.characterID }, repeatPolicy = policy }
    local identity = self.PROVIDER .. ":" .. scope.characterID .. ":" .. clean.catalogID .. ":" .. tostring(clean.difficultyID or 0)
        .. ":" .. clean.scope .. ":" .. table.concat(clean.encounterIDs, ",") .. ":" .. policy
    return { intent = normalized, title = clean.title, identity = identity, fields = fields }
end
function Targets:Evaluate(r)
    local meta = YiboAltoBossDB.plannedTargetSource
    local result = { sourceEpoch = meta.sourceEpoch, revision = meta.revision, sourceTitle = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.BOSSES_AND_INSTANCES"), evaluations = {} }
    for _, goal in ipairs(r.goals or {}) do
        local clean, err = self:Normalize({ intent = goal.intent })
        if clean and not clean.needsConfiguration then
            local intent, id = clean.intent, clean.intent.scope.characterID
            local p = YAB.PlannedTargets:Progress(id, intent.conditions)
            local title, description = YAB.PlannedTargets:Describe(intent.conditions)
            result.evaluations[goal.id] = { task = { title = title, summary = description, reason = p.reason,
                state = p.state == "completed" and "completed" or "active",
                readiness = p.state == "completed" and "not-applicable" or (p.state == "ready" and "actionable" or (p.state == "dormant" and "blocked" or "unknown")),
                execution = { mode = "self", characterID = id }, beneficiary = { mode = "character", characterID = id },
                temporal = { kind = p.kind or "weekly", cycleKey = p.cycleKey, nextChangeAt = p.validUntil },
                freshness = { state = p.freshness, observedAt = p.observedAt, validUntil = p.validUntil },
                nextAction = { kind = "open-page", pageID = intent.conditions.kind == "instance" and "alto-lockouts" or "alto-boss" } } }
        else result.evaluations[goal.id] = { reason = err or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.TARGET_PARAMETERS_UNCONFIRMED") } end
    end
    return result
end
function Targets:Initialize()
    local core = Core()
    if not (core:CheckAPIVersion(13) and core:HasCapability("business-item-actions", 3)) then core:Print(core.Locale:Get("YiboAltoBoss", "TP.UPGRADE_ACTIONS")); return end
    if self.ref then return true end
    self.definition = { name = "action.targets", kind = "provider", providerID = self.PROVIDER, version = { major = 1, minor = 1 },
        methods = { GetEntry = function() return { title = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.BOSSES_AND_INSTANCES"), pageID = "alto-boss" } end, Normalize = function(r) return Targets:Normalize(r) end, Evaluate = function(r) return Targets:Evaluate(r) end } }
    self.ref = core.Contracts:Register("YiboAltoBoss", self.definition)
    return self.ref ~= nil
end
function Targets:Bind(control, key, target, original, compactTooltip)
    local core = Core()
    if not self.ref then return end
    local id = core.Characters:ResolveLegacyKey(key)
    if not id then core.BusinessItemActions:Unbind(control); return end
    local intent = { providerID = self.PROVIDER, objectID = target.catalogID, targetType = "boss", scope = { mode = "character", characterID = id }, conditions = target, repeatPolicy = "recurring" }
    core.BusinessItemActions:Bind(control, { owner = "YiboAltoBoss", GetIntent = function() return intent end, ctrlLeftSafe = true, reservedButtons = { LeftButton = true }, compactTooltip = compactTooltip == true })
    control:RegisterForClicks("AnyUp")
    control:SetScript("OnClick", function(self, button)
        if core.BusinessItemActions:Handle(self, button) then return end
        if original and button == "LeftButton" then original(self, button) end
    end)
    if control.tooltipLines then core.UITheme:BindTooltip(control, control.tooltipTitle, core.BusinessItemActions:TooltipLines(control.tooltipLines, control)) end
end
