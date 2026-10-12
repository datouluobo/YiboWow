local Addon = _G.YiboVault
local Targets = { PROVIDER = "YiboVault:targets" }
Addon.GoalTargets = Targets
local presets = { bags = { "bags" }, bank = { "bank" }, equipment = { "equipment" }, mail = { "mail" }, personal = { "bags", "bank", "equipment", "mail" } }
function Targets:Normalize(r)
    local intent = r.intent
    if type(intent) ~= "table" or type(intent.objectID) ~= "number" or intent.objectID <= 0 or intent.objectID % 1 ~= 0 then return nil, "请选择有效物品" end
    local clean = Addon.Copy(intent); clean.conditions = clean.conditions or {}; clean.scope = clean.scope or { mode = "character" }
    local c, scope = clean.conditions, clean.scope
    local fields = {
        { id = "quantity", label = "目标数量", kind = "number" },
        { id = "storage", label = "统计仓储", kind = "select", options = {
            { value = "bags", label = "背包" }, { value = "bank", label = "银行" }, { value = "equipment", label = "装备" },
            { value = "mail", label = "邮件（统一库存来源）" }, { value = "personal", label = "背包、银行、装备与邮件" } } },
        { id = "mode", label = "达标模式", kind = "select", options = { { value = "once", label = "一次达标" }, { value = "maintain", label = "持续保持" } } },
        { id = "scopeMode", label = "统计范围", kind = "select", options = { { value = "character", label = "指定角色" }, { value = "account", label = "账号角色（保存当前目录范围）" } } },
    }
    if not c.quantity or not c.storage or not c.mode or not c.scopeMode then return { needsConfiguration = true, fields = fields } end
    if type(c.quantity) ~= "number" or c.quantity % 1 ~= 0 or c.quantity < 1 or c.quantity > 100000000 then return nil, "数量必须是 1～100000000 的整数" end
    if not presets[c.storage] or (c.mode ~= "once" and c.mode ~= "maintain") then return nil, "请选择仓储与达标模式" end
    if c.scopeMode == "account" then
        if scope.mode ~= "account" then
            scope = { mode = "account", characterIDs = {} }; clean.scope = scope
            for _, character in ipairs(Addon.Core.Characters:GetAll({ identityOnly = true })) do scope.characterIDs[#scope.characterIDs + 1] = character.id end
        end
        table.sort(scope.characterIDs)
        if #scope.characterIDs == 0 then return nil, "没有可统计角色" end
    elseif c.scopeMode == "character" then
        if not scope.characterID then return { needsConfiguration = true, needsCharacter = true, fields = fields } end
        if not Addon.Core.Characters:Get(scope.characterID, { identityOnly = true }) then return nil, "角色不存在" end
        scope.mode, scope.characterIDs = "character", nil
    else return nil, "请选择统计范围" end
    clean.repeatPolicy, clean.targetType = c.mode, "inventory"
    local key = scope.mode == "character" and scope.characterID or table.concat(scope.characterIDs, ",")
    local info = Addon.Core.ItemResolver:GetInfo(intent.objectID)
    return { intent = clean, title = (info and info.name or ("物品 " .. intent.objectID)) .. " × " .. c.quantity,
        identity = self.PROVIDER .. ":" .. intent.objectID .. ":" .. key .. ":" .. c.storage .. ":" .. c.mode,
        fields = fields }
end
function Targets:Evaluate(r)
    local result = { sourceEpoch = Addon.db.goalSourceEpoch, revision = Addon.Items:GetRevision(), sourceTitle = "物品库存", evaluations = {} }
    for _, goal in ipairs(r.goals or {}) do
        local clean, err = self:Normalize({ intent = goal.intent })
        if clean and not clean.needsConfiguration then
            local intent = clean.intent
            local ids = intent.scope.mode == "character" and { intent.scope.characterID } or intent.scope.characterIDs
            local value = Addon.Items:Query({ itemID = intent.objectID, sources = presets[intent.conditions.storage],
                scope = { mode = "characters", characterIDs = ids }, includeStale = false })
            local known, observedAt = value ~= nil, nil
            for _, source in ipairs(presets[intent.conditions.storage]) do for _, id in ipairs(ids) do
                local entry = value and value.coverage[source] and value.coverage[source][id]
                local locations = entry and entry.locations or {}
                if not next(locations) then known = false end
                local required = {}
                if source == "bags" then for bagID = 0, (tonumber(NUM_BAG_SLOTS) or 4) do required[#required + 1] = tostring(bagID) end
                elseif source == "bank" then
                    required[1] = tostring(tonumber(BANK_CONTAINER) or -1)
                    local first = (tonumber(NUM_BAG_SLOTS) or 4) + 1
                    for bagID = first, first + (tonumber(NUM_BANKBAGSLOTS) or 7) - 1 do required[#required + 1] = tostring(bagID) end
                elseif source == "equipment" then required[1] = "equipment"
                elseif source == "mail" then required[1] = "inbox" end
                for _, key in ipairs(required) do if not locations[key] then known = false end end
                for _, location in pairs(entry and entry.locations or {}) do
                    if location.status ~= "known" and location.status ~= "known-empty" then known = false end
                    if location.observedAt then observedAt = not observedAt and location.observedAt or math.min(observedAt, location.observedAt) end
                end
            end end
            local quantity = value and value.totals.totalQuantity
            local done = known and quantity >= intent.conditions.quantity
            local reason = not known and "仓储覆盖不足，请扫描所选角色与仓储" or (tostring(quantity) .. " / " .. intent.conditions.quantity)
            result.evaluations[goal.id] = { task = { title = clean.title, summary = reason, reason = reason,
                state = done and "completed" or "active", readiness = not known and "unknown" or (done and "not-applicable" or "actionable"),
                execution = intent.scope.mode == "character" and { mode = "self", characterID = intent.scope.characterID } or { mode = "account", candidateCharacterIDs = ids },
                beneficiary = intent.scope.mode == "character" and { mode = "character", characterID = intent.scope.characterID } or { mode = "account" },
                temporal = { kind = "persistent" }, freshness = { state = known and "known" or "partial", observedAt = observedAt },
                item = { itemID = intent.objectID, quantity = quantity }, nextAction = { kind = "open-page", pageID = "vault" } } }
        else result.evaluations[goal.id] = { reason = err } end
    end
    return result
end
function Targets:Initialize()
    local core = Addon.Core
    if not (core:CheckAPIVersion(12) and core:HasCapability("business-item-actions", 1) and core:HasCapability("character-identity", 1)) then Addon:Print("库存目标需要 Core API v12，请升级 Core。"); return end
    if self.ref then return true end
    Addon.db.goalSourceEpoch = Addon.db.goalSourceEpoch or ("vault:" .. Addon:Now() .. ":" .. math.random(100000, 999999))
    self.definition = { name = "action.targets", kind = "provider", providerID = self.PROVIDER, version = { major = 1, minor = 1 }, methods = { GetEntry = function() return { title = "物品库存", pageID = "vault" } end,
        Normalize = function(r) return Targets:Normalize(r) end, Evaluate = function(r) return Targets:Evaluate(r) end } }
    self.ref = core.Contracts:Register(Addon.NAME, self.definition)
    return self.ref ~= nil
end
function Targets:Bind(cell, item)
    local core = Addon.Core
    if not self.ref then return end
    core.BusinessItemActions:Unbind(cell)
    if not item then return end
    local intent = { providerID = self.PROVIDER, objectID = item.itemID, targetType = "inventory",
        scope = { mode = "character", characterID = item.characterID }, conditions = {} }
    core.BusinessItemActions:Bind(cell, { owner = Addon.NAME, GetIntent = function() return intent end })
    cell:RegisterForClicks("AnyUp"); cell:SetScript("OnClick", function(self, button) core.BusinessItemActions:Handle(self, button) end)
end
