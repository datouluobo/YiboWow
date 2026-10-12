local Addon, Core = _G.YiboCurrency, _G.YiboCore
local Targets = { PROVIDER = "YiboCurrency:targets" }; Addon.GoalTargets = Targets
local function Entry(id) for _, e in ipairs(Addon:GetCatalog()) do if e.id == id and (e.source == "currency" or e.source == "money") then return e end end end
function Targets:Normalize(r)
    local intent = r.intent
    local entry = type(intent) == "table" and Entry(intent.objectID)
    if not entry then return nil, "请选择原生货币或金币；物品数量请从库存添加" end
    local clean = Core.Defaults:Copy(intent); clean.conditions = clean.conditions or {}; clean.scope = clean.scope or { mode = "character" }
    local fields = { { id = "quantity", label = entry.source == "money" and "目标铜币数量" or "目标货币数量", kind = "number" },
        { id = "mode", label = "完成模式", kind = "select", options = { { value = "once", label = "一次达标" }, { value = "maintain", label = "持续保持" } } } }
    local c = clean.conditions
    if not clean.scope.characterID or not c.quantity or not c.mode then return { needsConfiguration = true, fields = fields } end
    if type(c.quantity) ~= "number" or c.quantity < 1 or c.quantity > 1000000000000 or c.quantity % 1 ~= 0 then return nil, "请输入有效整数数量" end
    if c.mode ~= "once" and c.mode ~= "maintain" then return nil, "请选择完成模式" end
    if not Core.Characters:Get(clean.scope.characterID, { identityOnly = true }) then return nil, "角色不存在" end
    clean.targetType, clean.repeatPolicy, clean.scope.mode = "currency", c.mode, "character"
    return { intent = clean, title = entry.title .. " ≥ " .. c.quantity, identity = self.PROVIDER .. ":" .. clean.scope.characterID .. ":" .. entry.id .. ":" .. c.mode, fields = fields }
end
function Targets:Evaluate(r)
    local db = Addon:EnsureDB()
    local result = { sourceEpoch = db.goalSourceEpoch, revision = db.goalRevision or 0, sourceTitle = "货币管家", evaluations = {} }
    for _, goal in ipairs(r.goals or {}) do
        local clean, err = self:Normalize({ intent = goal.intent })
        if clean and not clean.needsConfiguration then
            local id, intent = clean.intent.scope.characterID, clean.intent
            local character = Core.Characters:Get(id, { identityOnly = true })
            local value, state = Addon:GetValue(character, Entry(intent.objectID))
            local known = state == "known" and value and type(value.quantity) == "number"
            local done = known and value.quantity >= intent.conditions.quantity
            local reason = known and (value.quantity .. " / " .. intent.conditions.quantity) or "登录角色同步货币余额"
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
    if not (core:CheckAPIVersion(12) and core:HasCapability("business-item-actions", 1)) then core:Print("主动添加目标需要 Core API v12，请升级 Core。"); return end
    if self.ref then return true end
    local db = Addon:EnsureDB()
    db.goalSourceEpoch = db.goalSourceEpoch or ("yibocurrency:" .. GetServerTime() .. ":" .. math.random(100000,999999))
    self.definition = { name = "action.targets", kind = "provider", providerID = self.PROVIDER, version = { major = 1, minor = 1 },
        methods = { GetEntry = function() return { title = "货币", pageID = "currency" } end, Normalize = function(r) return Targets:Normalize(r) end, Evaluate = function(r) return Targets:Evaluate(r) end } }
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
