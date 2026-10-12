local Addon = _G.YiboVault
local Targets = { PROVIDER = "YiboVault:targets" }
Addon.GoalTargets = Targets
local presets = { bags = { "bags" }, bank = { "bank" }, equipment = { "equipment" }, mail = { "mail" }, personal = { "bags", "bank", "equipment", "mail" } }
function Targets:Normalize(r)
    local intent = r.intent
    if type(intent) ~= "table" or type(intent.objectID) ~= "number" or intent.objectID <= 0 or intent.objectID % 1 ~= 0 then return nil, Addon:T("TEXT.SELECT_A_VALID_ITEM_4D751E") end
    local clean = Addon.Copy(intent); clean.conditions = clean.conditions or {}; clean.scope = clean.scope or { mode = "character" }
    local c, scope = clean.conditions, clean.scope
    local fields = {
        { id = "quantity", label = Addon:T("TEXT.TARGET_QUANTITY_411625"), kind = "number" },
        { id = "storage", label = Addon:T("TEXT.COUNT_STORAGE_652698"), kind = "select", options = {
            { value = "bags", label = Addon:T("TEXT.BAGS_FF3D08") }, { value = "bank", label = Addon:T("TEXT.BANK_CB8A39") }, { value = "equipment", label = Addon:T("TEXT.EQUIPMENT_1FAF33") },
            { value = "mail", label = Addon:T("TEXT.MAIL_SHARED_INVENTORY_SOURCE_DA0B58") }, { value = "personal", label = Addon:T("TEXT.BAGS_BANK_EQUIPMENT_AND_MAIL_1AD38E") } } },
        { id = "mode", label = Addon:T("TEXT.COMPLETION_MODE_51E9D2"), kind = "select", options = { { value = "once", label = Addon:T("TEXT.COMPLETE_ONCE_CF8A80") }, { value = "maintain", label = Addon:T("TEXT.KEEP_IN_STOCK_CA133E") } } },
        { id = "scopeMode", label = Addon:T("TEXT.COUNTING_SCOPE_174FD6"), kind = "select", options = { { value = "character", label = Addon:T("TEXT.SELECTED_CHARACTER_F0B093") }, { value = "account", label = Addon:T("TEXT.ACCOUNT_CHARACTERS_SAVE_THE_CURRENT_DIRECT_68F438") } } },
    }
    if not c.quantity or not c.storage or not c.mode or not c.scopeMode then return { needsConfiguration = true, fields = fields } end
    if type(c.quantity) ~= "number" or c.quantity % 1 ~= 0 or c.quantity < 1 or c.quantity > 100000000 then return nil, Addon:T("TEXT.QUANTITY_MUST_BE_A_WHOLE_NUMBER_FROM_1_TO_EE5267") end
    if not presets[c.storage] or (c.mode ~= "once" and c.mode ~= "maintain") then return nil, Addon:T("TEXT.CHOOSE_STORAGE_LOCATIONS_AND_A_COMPLETION_E25D64") end
    if c.scopeMode == "account" then
        if scope.mode ~= "account" then
            scope = { mode = "account", characterIDs = {} }; clean.scope = scope
            for _, character in ipairs(Addon.Core.Characters:GetAll({ identityOnly = true })) do scope.characterIDs[#scope.characterIDs + 1] = character.id end
        end
        table.sort(scope.characterIDs)
        if #scope.characterIDs == 0 then return nil, Addon:T("TEXT.NO_CHARACTERS_ARE_AVAILABLE_TO_COUNT_7AA79C") end
    elseif c.scopeMode == "character" then
        if not scope.characterID then return { needsConfiguration = true, needsCharacter = true, fields = fields } end
        if not Addon.Core.Characters:Get(scope.characterID, { identityOnly = true }) then return nil, Addon:T("TEXT.CHARACTER_DOES_NOT_EXIST_3B434E") end
        scope.mode, scope.characterIDs = "character", nil
    else return nil, Addon:T("TEXT.CHOOSE_A_COUNTING_SCOPE_954DC7") end
    clean.repeatPolicy, clean.targetType = c.mode, "inventory"
    local key = scope.mode == "character" and scope.characterID or table.concat(scope.characterIDs, ",")
    local info = Addon.Core.ItemResolver:GetInfo(intent.objectID)
    return { intent = clean, title = (info and info.name or (Addon:T("TEXT.ITEM_521404") .. intent.objectID)) .. " × " .. c.quantity,
        identity = self.PROVIDER .. ":" .. intent.objectID .. ":" .. key .. ":" .. c.storage .. ":" .. c.mode,
        fields = fields }
end
function Targets:Evaluate(r)
    local result = { sourceEpoch = Addon.db.goalSourceEpoch, revision = Addon.Items:GetRevision(), sourceTitle = Addon:T("TEXT.ITEM_INVENTORY_CEAB6C"), evaluations = {} }
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
            local reason = not known and Addon:T("TEXT.STORAGE_COVERAGE_IS_INCOMPLETE_SCAN_THE_SE_210785") or (tostring(quantity) .. " / " .. intent.conditions.quantity)
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
    if not (core and type(core.CheckAPIVersion) == "function" and core:CheckAPIVersion(13)
        and type(core.HasCapability) == "function" and core:HasCapability("business-item-actions", 1)
        and core:HasCapability("character-identity", 1) and core.Contracts
        and type(core.Contracts.Register) == "function" and core.BusinessItemActions
        and type(core.BusinessItemActions.Bind) == "function"
        and type(core.BusinessItemActions.Unbind) == "function"
        and type(core.BusinessItemActions.Handle) == "function"
        and core.Characters and type(core.Characters.Get) == "function"
        and type(core.Characters.GetAll) == "function") then
        Addon:Print(Addon:T("ERROR.GOAL_CORE_REQUIRED")); return
    end
    if self.ref then return true end
    Addon.db.goalSourceEpoch = Addon.db.goalSourceEpoch or ("vault:" .. Addon:Now() .. ":" .. math.random(100000, 999999))
    self.definition = { name = "action.targets", kind = "provider", providerID = self.PROVIDER, version = { major = 1, minor = 1 }, methods = { GetEntry = function() return { title = Addon:T("TEXT.ITEM_INVENTORY_CEAB6C"), pageID = "vault" } end,
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
