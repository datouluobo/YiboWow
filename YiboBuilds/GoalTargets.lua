local Addon = _G.YiboBuilds
local Targets = { PROVIDER = "YiboBuilds:targets" }
Addon.GoalTargets = Targets
local function ObjectID(c)
    return tostring(c.buildSlot) .. ":" .. tostring(c.slotID) .. ":" .. tostring(c.instanceKey or ("unknown:" .. tostring(c.itemID)))
        .. ":" .. tostring(c.kind) .. ":" .. tostring(c.socketIndex or 0) .. ":" .. tostring(c.enhancementID)
end
function Targets:Normalize(r)
    local intent = r.intent
    if type(intent) ~= "table" or type(intent.conditions) ~= "table" or type(intent.scope) ~= "table" then return nil, "请选择装备强化候选" end
    local c, id = intent.conditions, intent.scope.characterID
    if not id then return { needsConfiguration = true, fields = {} } end
    if not Addon.Core.Characters:Get(id, { identityOnly = true }) then return nil, "角色不存在" end
    if type(c.slotID) ~= "number" or not c.itemID or not c.buildSlot or not c.enhancementID
        or (c.kind ~= "gem" and c.kind ~= "enchant") then return nil, "装备或强化引用无效" end
    if c.kind == "enchant" and not Addon.EnchantCatalog[c.enhancementID] then return nil, "附魔目录缺少此效果" end
    if c.kind == "gem" and (type(c.socketIndex) ~= "number" or c.socketIndex < 1 or c.socketIndex > 8) then return nil, "请选择实际孔位" end
    local clean = Addon.Core.Defaults:Copy(intent)
    clean.targetType, clean.repeatPolicy, clean.scope.mode = "enhancement", "once", "character"
    clean.objectID = ObjectID(c)
    return { intent = clean, identity = self.PROVIDER .. ":" .. id .. ":" .. c.buildSlot .. ":" .. c.slotID .. ":"
        .. tostring(c.instanceKey or "unknown:" .. c.itemID) .. ":" .. c.kind .. ":" .. tostring(c.socketIndex or 0) .. ":" .. c.enhancementID,
        title = (c.kind == "gem" and "镶嵌宝石 " or "施加附魔 ") .. c.enhancementID .. " · 装备 " .. c.itemID, fields = {} }
end
function Targets:Evaluate(r)
    local db = Addon:EnsureDB()
    local result = { sourceEpoch = db.goalSourceEpoch, revision = db.goalRevision or 0, sourceTitle = "装备提升", evaluations = {} }
    for _, goal in ipairs(r.goals or {}) do
        local clean, err = self:Normalize({ intent = goal.intent })
        if clean and not clean.needsConfiguration then
            local c, id = clean.intent.conditions, clean.intent.scope.characterID
            local record = Addon.Snapshot:GetCharacter(id)
            local build = record and record.slots and record.slots[c.buildSlot]
            local equipment = build and build.observedEquipment
            local item = equipment and equipment.slots and equipment.slots[tostring(c.slotID)]
            local identityKnown = c.instanceKey ~= nil and item and item.instanceKey ~= nil
            local invalid = identityKnown and item.instanceKey ~= c.instanceKey
            local applicable = identityKnown and not invalid and Addon.AccountPage:IsGoalTargetApplicable(item, c)
            local installed = applicable and (c.kind == "gem" and item.gems and item.gems[c.socketIndex]
                and item.gems[c.socketIndex].state == "installed" and item.gems[c.socketIndex].itemID == c.enhancementID
                or c.kind == "enchant" and item.enchant and item.enchant.state == "installed" and item.enchant.enchantID == c.enhancementID)
            local known = invalid or applicable
            local reason = invalid and "装备已更换，目标暂停；请重新选择装备" or (not identityKnown and "装备实例身份不明，需重新采集" or (not applicable and "强化适用性待核实" or (installed and "已实际应用" or "尚未应用到该装备")))
            result.evaluations[goal.id] = { invalid = invalid == true, reason = reason, task = { title = clean.title, reason = reason, summary = reason,
                state = installed and "completed" or "active", readiness = known and not invalid and (installed and "not-applicable" or "actionable") or "unknown",
                execution = { mode = "self", characterID = id }, beneficiary = { mode = "character", characterID = id },
                temporal = { kind = "persistent" }, freshness = { state = known and "known" or "partial", observedAt = equipment and equipment.capturedAt },
                nextAction = { kind = "open-page", pageID = "builds" } } }
        else result.evaluations[goal.id] = { reason = err } end
    end
    return result
end
function Targets:Initialize()
    local core = Addon.Core
    if not (core:CheckAPIVersion(12) and core:HasCapability("business-item-actions", 1)) then Addon:Print("强化目标需要 Core API v12，请升级 Core。"); return end
    if self.ref then return true end
    local db = Addon:EnsureDB(); db.goalSourceEpoch = db.goalSourceEpoch or ("builds:" .. Addon:Now() .. ":" .. math.random(100000,999999))
    self.definition = { name = "action.targets", kind = "provider", providerID = self.PROVIDER, version = { major = 1, minor = 1 },
        methods = { GetEntry = function() return { title = "角色构筑", pageID = "builds" } end, Normalize = function(r) return Targets:Normalize(r) end, Evaluate = function(r) return Targets:Evaluate(r) end } }
    self.ref = core.Contracts:Register(Addon.NAME, self.definition); return self.ref ~= nil
end
function Targets:Bind(row, parent, item, slotID, kind, enhancementID, socketIndex)
    if not self.ref or not row or not enhancementID then return end
    local core = Addon.Core
    local intent = { providerID = self.PROVIDER, scope = { mode = "character", characterID = parent.buildsSelectedCharacter.id },
        conditions = { buildSlot = parent.buildsSlot, slotID = slotID, itemID = item.itemID, instanceKey = item.instanceKey,
            kind = kind, enhancementID = enhancementID, socketIndex = socketIndex } }
    intent.objectID = ObjectID(intent.conditions)
    core.BusinessItemActions:Bind(row, { owner = Addon.NAME, GetIntent = function() return intent end, ctrlLeftSafe = true, reservedButtons = { LeftButton = true, RightButton = true } })
    local original = row:GetScript("OnClick")
    row:RegisterForClicks("AnyUp"); row:SetScript("OnClick", function(self, button)
        if core.BusinessItemActions:Handle(self, button) then return end
        if original and button == "LeftButton" then original(self, button) end
    end)
    local secure = row.buildsSecureAugmentButton
    if secure then
        if InCombatLockdown and InCombatLockdown() then core.BusinessItemActions:Unbind(secure); return end
        secure:SetAttribute("type3", ""); secure:SetAttribute("type4", ""); secure:SetAttribute("type5", "")
        core.BusinessItemActions:Bind(secure, { owner = Addon.NAME, menu = false, GetIntent = function() return intent end,
            ConfigureCtrlLeft = function(enabled)
                if InCombatLockdown and InCombatLockdown() then return false end
                secure:SetAttribute("ctrl-type1", enabled and "" or nil); return true
            end,
            reservedButtons = { LeftButton = true, RightButton = true } })
        if not secure.yiboGoalHook then
            secure:HookScript("PostClick", function(self, button, down) if not down then core.BusinessItemActions:Handle(self, button) end end)
            secure.yiboGoalHook = true
        end
        row.yiboItemMenu:SetFrameLevel(secure:GetFrameLevel() + 2)
    end
end
