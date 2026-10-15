local Addon, Core = _G.YiboCurrency, _G.YiboCore
local Targets = { PROVIDER = "YiboCurrency:targets" }; Addon.GoalTargets = Targets
local function Entry(id) for _, e in ipairs(Addon:GetCatalog()) do if e.id == id and (e.source == "currency" or e.source == "money") then return e end end end
function Targets:Normalize(r)
    local intent = r.intent
    local entry = type(intent) == "table" and Entry(intent.objectID)
    if not entry then return nil, Addon:T("CURRENCY.CHOOSE_A_NATIVE_CURRENCY_OR_GOLD_ADD_ITEM_GOALS_FROM_VA_1E5A19") end
    local clean = Core.Defaults:Copy(intent); clean.conditions = clean.conditions or {}; clean.scope = clean.scope or { mode = "character" }
    local fields = { { id = "quantity", label = entry.source == "money" and Addon:T("CURRENCY.TARGET_COPPER_939169") or Addon:T("CURRENCY.TARGET_QUANTITY_6714E7"), kind = "number" },
        { id = "mode", label = Addon:T("CURRENCY.COMPLETION_MODE_4553EA"), kind = "select", options = { { value = "once", label = Addon:T("CURRENCY.REACH_ONCE_CF8A80") }, { value = "maintain", label = Addon:T("CURRENCY.MAINTAIN_CA133E") } } } }
    local c = clean.conditions
    if not clean.scope.characterID or not c.quantity or not c.mode then return { needsConfiguration = true, fields = fields } end
    if type(c.quantity) ~= "number" or c.quantity < 1 or c.quantity > 1000000000000 or c.quantity % 1 ~= 0 then return nil, Addon:T("CURRENCY.ENTER_A_VALID_WHOLE_NUMBER_QUANTITY_E579BE") end
    if c.mode ~= "once" and c.mode ~= "maintain" then return nil, Addon:T("CURRENCY.CHOOSE_A_COMPLETION_MODE_34A2E8") end
    if not Core.Characters:Get(clean.scope.characterID, { identityOnly = true }) then return nil, Addon:T("CURRENCY.CHARACTER_DOES_NOT_EXIST_3B434E") end
    clean.targetType, clean.repeatPolicy, clean.scope.mode = "currency", c.mode, "character"
    return { intent = clean, title = entry.title .. " ≥ " .. c.quantity, identity = self.PROVIDER .. ":" .. clean.scope.characterID .. ":" .. entry.id .. ":" .. c.mode, fields = fields }
end
function Targets:Evaluate(r)
    local db = Addon:EnsureDB()
    local result = { sourceEpoch = db.goalSourceEpoch, revision = db.goalRevision or 0, sourceTitle = Addon:T("CURRENCY.CURRENCY_TRACKER_D84A55"), evaluations = {} }
    for _, goal in ipairs(r.goals or {}) do
        local clean, err = self:Normalize({ intent = goal.intent })
        if clean and not clean.needsConfiguration then
            local id, intent = clean.intent.scope.characterID, clean.intent
            local character = Core.Characters:Get(id, { identityOnly = true })
            local value, state = Addon:GetValue(character, Entry(intent.objectID))
            local known = state == "known" and value and type(value.quantity) == "number"
            local done = known and value.quantity >= intent.conditions.quantity
            local reason = known and (value.quantity .. " / " .. intent.conditions.quantity) or Addon:T("CURRENCY.LOG_IN_TO_SYNC_THE_CURRENCY_BALANCE_DA1F0F")
            result.evaluations[goal.id] = { task = { title = clean.title, reason = reason, summary = reason,
                state = done and "completed" or "active", readiness = known and (done and "not-applicable" or "actionable") or "unknown",
                execution = { mode = "self", characterID = id }, beneficiary = { mode = "character", characterID = id },
                temporal = { kind = "persistent" }, freshness = { state = known and "known" or "partial" }, nextAction = { kind = "open-page", pageID = "currency" } } }
        else result.evaluations[goal.id] = { reason = err } end
    end
    return result
end

function Targets:Initialize()
    local core = Core
    if not (core:CheckAPIVersion(13) and core:HasCapability("business-item-actions", 1)
        and core:HasCapability("business-providers", 1) and core:HasCapability("character-identity", 1)
        and core.BusinessItemActions and type(core.BusinessItemActions.Bind) == "function"
        and type(core.BusinessItemActions.Handle) == "function" and type(core.BusinessItemActions.Unbind) == "function"
        and type(core.BusinessItemActions.GestureLabel) == "function") then core:Print(Addon:T("CURRENCY.GOAL_ACTIONS_REQUIRE_CORE_API13_WITH_GOAL_PROVIDER_AND__DE2E6B")); return end
    if self.ref then return true end
    local db = Addon:EnsureDB()
    db.goalSourceEpoch = db.goalSourceEpoch or ("yibocurrency:" .. GetServerTime() .. ":" .. math.random(100000,999999))
    self.definition = { name = "action.targets", kind = "provider", providerID = self.PROVIDER, version = { major = 1, minor = 1 },
        methods = { GetEntry = function() return { title = Addon:T("CURRENCY.CURRENCY_219994"), pageID = "currency" } end, Normalize = function(r) return Targets:Normalize(r) end, Evaluate = function(r) return Targets:Evaluate(r) end } }
    self.ref = core.Contracts:Register("YiboCurrency", self.definition); return self.ref ~= nil
end
function Targets:Bind(control, objectID, characterID, original)
    if not self.ref then return end
    local core = Core
    local intent = { providerID = self.PROVIDER, objectID = objectID, scope = { mode = "character", characterID = characterID }, conditions = {} }
    core.BusinessItemActions:Bind(control, { owner = "YiboCurrency", GetIntent = function() return intent end, ctrlLeftSafe = true, reservedButtons = { RightButton = original ~= nil } })
    control:RegisterForClicks("AnyUp"); control:SetScript("OnClick", function(self, button)
        if core.BusinessItemActions:Handle(self, button) then return end
        if original and button == "RightButton" then original(self, button) end
    end)
end
