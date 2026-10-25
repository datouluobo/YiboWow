if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB = _G.YAB
local Targets = { PROVIDER = "YiboAltoBoss:targets" }
YAB.GoalTargets = Targets
local function Core() return _G.YiboCore end
local function Now() return GetServerTime and GetServerTime() or time() end
-- Both the standalone Boss view and action providers evaluate the owner's
-- canonical target, including historical difficulty aliases.
local Progress, Describe = YAB.PlannedTargets.Progress, YAB.PlannedTargets.Describe
local function Canonical(target)
    if target.kind ~= "instance" then return target end
    local result = Core().Defaults:Copy(target)
    result.difficultyID = YAB.TargetCatalog:CanonicalDifficulty(target.catalogID, target.difficultyID)
    local definition = YAB.TargetCatalog:Get(target.catalogID)
    for _, difficulty in ipairs(definition and definition.difficulties or {}) do
        if difficulty.id == result.difficultyID then result.difficultyName = difficulty.name; break end
    end
    return result
end
function YAB.PlannedTargets:Progress(id, target)
    target = Canonical(target)
    local result = Progress(self, id, target)
    if YAB.RaidProgress then result = YAB.RaidProgress:Apply(id, target, result) end
    if result.state == "unknown" and result.lockout then
        result.reason = Core().Locale:Get("YiboAltoBoss", "GOAL.LOCKED_UNVERIFIED")
    end
    return result
end
function YAB.PlannedTargets:Describe(target) return Describe(self, Canonical(target)) end
local Shutdown = YAB.PlannedTargets.Shutdown
function YAB.PlannedTargets:Shutdown()
    if YAB.RaidEvents then YAB.RaidEvents:Stop() end
    return Shutdown(self)
end
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
        local difficultyID = YAB.TargetCatalog:CanonicalDifficulty(target.catalogID, target.difficultyID)
        for _, d in ipairs(definition.difficulties or {}) do if d.id == difficultyID then difficulty = d end end
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
    local function Text(key, ...) return Core().Locale:Get("YiboAltoBoss", key, ...) end
    -- A journal can become ready after the first request. Do not pin an
    -- incomplete directory for the lifetime of the configuration screen.
    self.catalogRetryAt = self.catalogRetryAt or {}
    if definition.kind == "instance" and not definition.complete and Now() >= (self.catalogRetryAt[raw.catalogID] or 0) then
        self.catalogRetryAt[raw.catalogID] = Now() + 2
        YAB.TargetCatalog:Invalidate()
        definition = YAB.TargetCatalog:Get(raw.catalogID) or definition
    end
    local fields = { { id = "repeatPolicy", label = Text("UI.COMPLETION_POLICY"), kind = "select", default = intent.repeatPolicy or "recurring",
        options = { { value = "recurring", label = Text("UI.REPEAT_BY_SOURCE_CYCLE") }, { value = "once", label = Text("UI.COMPLETE_ONCE") } } } }
    local candidate = Core().Defaults:Copy(raw)
    local function Pending(message)
        return { needsConfiguration = true, fields = fields, title = definition.name, reason = message }
    end
    if definition.kind == "instance" then
        local options, selected = {}, nil
        for _, d in ipairs(definition.difficulties or {}) do if d.trackable ~= false and d.complete then
            options[#options + 1] = { value = d.id, label = d.name }
            if d.id == YAB.TargetCatalog:CanonicalDifficulty(raw.catalogID, raw.difficultyID) then selected = d end
        end end
        fields[#fields + 1] = { id = "difficultyID", label = Text("UI.INSTANCE_DIFFICULTY"), kind = "select", options = options,
            canonicalValue = selected and selected.id, clears = { "encounterIDs" } }
        local final
        for _, encounter in ipairs(selected and selected.encounters or {}) do
            if encounter.id == selected.finalEncounterID then final = encounter end
        end
        local scopes = { { value = "all", label = Text("GOAL.WHOLE_INSTANCE") } }
        if final then scopes[#scopes + 1] = { value = "final", label = Text("GOAL.FINAL_BOSS_NAME", final.name) } end
        scopes[#scopes + 1] = { value = "boss", label = Text("GOAL.SELECTED_BOSSES") }
        fields[#fields + 1] = { id = "scope", label = Text("GOAL.BOSS_SCOPE"), kind = "select", default = "all",
            options = scopes }
        if raw.scope == "boss" then
            local bosses = {}
            for _, e in ipairs(selected and selected.encounters or {}) do bosses[#bosses + 1] = { value = e.id, label = e.name } end
            fields[#fields + 1] = { id = "encounterIDs", label = Text("GOAL.SELECTED_BOSSES"), kind = "multiselect", options = bosses }
        end
        if #options == 0 then return Pending(Text("GOAL.CATALOG_NOT_READY")) end
        if not selected then return Pending(Text("UI.SELECT_A_VERIFIED_INSTANCE_DIFFICULTY")) end
        -- "final" is an editor shortcut. Persist the exact stable encounter ID
        -- so a later directory update cannot silently change the user's goal.
        if raw.scope == "final" then
            if not final then return Pending(Text("GOAL.FINAL_UNAVAILABLE")) end
            candidate.scope, candidate.encounterIDs = "boss", { final.id }
        end
    end
    if not scope.characterID then return Pending(Text("UI.CHARACTER_NOT_FOUND")) end
    local clean, err = Validate(candidate)
    if not clean then return Pending(err) end
    if not Core().Characters:Get(scope.characterID, { identityOnly = true }) then return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CHARACTER_NOT_FOUND") end
    clean.active = nil; clean.id = nil
    local policy = raw.repeatPolicy or intent.repeatPolicy or "recurring"
    if policy ~= "recurring" and policy ~= "once" then return nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SELECT_A_COMPLETION_POLICY") end
    clean.repeatPolicy = policy
    local normalized = { providerID = self.PROVIDER, objectID = clean.catalogID, targetType = "boss", conditions = clean,
        scope = { mode = "character", characterID = scope.characterID }, repeatPolicy = policy }
    local function Identity(difficultyID)
        return self.PROVIDER .. ":" .. scope.characterID .. ":" .. clean.catalogID .. ":" .. tostring(difficultyID or 0)
            .. ":" .. clean.scope .. ":" .. table.concat(clean.encounterIDs, ",") .. ":" .. policy
    end
    local aliases = {}
    for _, oldID in ipairs({ 3, 4 }) do
        if oldID ~= clean.difficultyID and YAB.TargetCatalog:CanonicalDifficulty(clean.catalogID, oldID) == clean.difficultyID then
            aliases[#aliases + 1] = Identity(oldID)
        end
    end
    return { intent = normalized, title = clean.title, identity = Identity(clean.difficultyID), identityAliases = aliases, fields = fields,
        actions = YAB.RaidProgress and YAB.RaidProgress:Actions(scope.characterID, clean, normalized) }
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
        else result.evaluations[goal.id] = { reason = err or (clean and clean.reason) or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.TARGET_PARAMETERS_UNCONFIRMED") } end
    end
    return result
end
function Targets:Initialize()
    local core = Core()
    if not (core:CheckAPIVersion(13) and core:HasCapability("business-item-actions", 3)) then core:Print(core.Locale:Get("YiboAltoBoss", "TP.UPGRADE_ACTIONS")); return end
    if self.ref then return true end
    self.definition = { name = "action.targets", kind = "provider", providerID = self.PROVIDER, version = { major = 1, minor = 2 },
        methods = { GetEntry = function() return { title = _G.YiboCore.Locale:Get("YiboAltoBoss", "GOAL.SOURCE"), pageID = "alto-boss", targetType = "boss" } end,
            Normalize = function(r) return Targets:Normalize(r) end, Evaluate = function(r) return Targets:Evaluate(r) end,
            ConfirmCycle = function(r) return YAB.RaidProgress:Confirm(r, false) end,
            RevokeCycle = function(r) return YAB.RaidProgress:Confirm(r, true) end } }
    self.ref = core.Contracts:Register("YiboAltoBoss", self.definition)
    if self.ref and YAB.RaidEvents then YAB.RaidEvents:Start() end
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
