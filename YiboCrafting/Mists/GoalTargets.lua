local Addon, Core = _G.YiboCrafting, _G.YiboCore
local Targets = { PROVIDER = "YiboCrafting:targets" }
Addon.GoalTargets = Targets
local function L(key, ...) return Core.Locale:Get(Addon.NAME, key, ...) end
local function Now() return GetServerTime and GetServerTime() or time() end
local function ProfessionCharacters(professionID, recipeID, realmScope)
    local ids = {}
    for _, character in ipairs(Core.Characters:GetAll({ identityOnly = true })) do
        local domain = Core.DataDomains:Get(character.id, "professions")
        if domain and domain.state == "known" and (not realmScope or realmScope == "all" or realmScope == "realm:" .. (character.realm or "")) then
            for _, profession in ipairs(domain.data and domain.data.professions or {}) do
                if profession.id == professionID
                    and (not recipeID or Addon.Store:GetRecipeState(character.id, professionID, recipeID) == "learned") then
                    ids[#ids + 1] = character.id
                    break
                end
            end
        end
    end
    table.sort(ids)
    return ids
end
function Targets:Normalize(r)
    local intent = r.intent
    local c = type(intent) == "table" and intent.conditions or {}
    local recipe = c and Addon.RecipeCatalog.professions[c.professionID] and Addon.RecipeCatalog.professions[c.professionID][intent.objectID]
    if not recipe then return nil, L("RECIPE_REQUIRED") end
    local clean = Core.Defaults:Copy(intent)
    clean.scope, clean.conditions = clean.scope or {}, clean.conditions or {}
    c = clean.conditions
    if Addon.Store.ResolveCharacterID then
        clean.scope.characterID = Addon.Store:ResolveCharacterID(clean.scope.characterID)
        c.baselineCharacterID = Addon.Store:ResolveCharacterID(c.baselineCharacterID)
        if type(c.startCounts) == "table" then
            local migrated = {}
            for id, count in pairs(c.startCounts) do
                local key = Addon.Store:ResolveCharacterID(id)
                migrated[key] = math.max(migrated[key] or 0, count)
            end
            c.startCounts = migrated
        end
    end
    c.quantity = c.quantity or 1
    c.mode = c.mode or "craft-times"
    local hasProducts = #(recipe.outputItemIDs or {}) > 0
    if not hasProducts then
        -- Personal enchants and other spell-only recipes have no inventory item.
        -- Cast evidence identifies the recipe without a fabricated product ID.
        c.outputItemID = nil
        if c.mode == "holding" then c.mode = "craft-times" end
    elseif not c.outputItemID and #recipe.outputItemIDs == 1 then c.outputItemID = recipe.outputItemIDs[1] end
    local executorMode = c.executorMode or (clean.scope.characterID and "character" or "any")
    if executorMode ~= "character" and executorMode ~= "any" then return nil, L("SCOPE_REQUIRED") end
    c.executorMode = executorMode
    local current = Core.Characters:GetCurrent({ identityOnly = true })
    local defaultRealm = current and current.realm and ("realm:" .. current.realm)
    local realms, realmOptions = {}, {}
    for _, character in ipairs(Core.Characters:GetAll({ identityOnly = true })) do
        if character.realm and character.realm ~= "" then realms[character.realm] = true end
    end
    if c.realmScope and c.realmScope ~= "all" then
        if type(c.realmScope) ~= "string" or not c.realmScope:match("^realm:.+") then return nil, L("REALM_REQUIRED") end
        realms[c.realmScope:sub(7)] = true
    end
    local realmNames = {}
    for realm in pairs(realms) do realmNames[#realmNames + 1] = realm end
    table.sort(realmNames)
    for _, realm in ipairs(realmNames) do realmOptions[#realmOptions + 1] = { value = "realm:" .. realm, label = realm } end
    realmOptions[#realmOptions + 1] = { value = "all", label = L("UI.ALL_REALMS") }
    local realmScope = executorMode == "any" and (c.realmScope or defaultRealm) or nil
    -- Profession ownership alone does not mean this character can execute this
    -- recipe. Only include characters with a confirmed learned-recipe state;
    -- unknown/offline snapshots must not become Hub candidates.
    local candidates = ProfessionCharacters(c.professionID, intent.objectID, realmScope)
    local characterOptions, options = {}, {}
    for _, id in ipairs(candidates) do
        local character = Core.Characters:Get(id, { identityOnly = true })
        characterOptions[#characterOptions + 1] = { value = id, label = Core.Characters:FormatName(character, { realmMode = "full" }) }
    end
    for _, id in ipairs(recipe.outputItemIDs or {}) do
        local info = Core.ItemResolver and Core.ItemResolver:GetInfo(id)
        options[#options + 1] = { value = id, label = info and info.name or L("PRODUCT_ID", id) }
    end
    local modes = { { value = "craft-times", label = L("CRAFT_COUNT") } }
    if hasProducts then modes[#modes + 1] = { value = "holding", label = L("HOLD_PRODUCT") } end
    local fields = {
        { id = "executorMode", label = L("EXECUTION_SCOPE"), kind = "select", default = executorMode, options = {
            { value = "any", label = L("ANY_PROFESSION_CHARACTER") },
            { value = "character", label = L("SPECIFIC_CHARACTER") } } },
        { id = "quantity", label = L("QUANTITY"), kind = "number", default = c.quantity },
        { id = "mode", label = L("COMPLETION_CONDITION"), kind = "select", default = c.mode, options = modes },
    }
    if hasProducts then fields[#fields + 1] = { id = "outputItemID", label = L("PRODUCT"), kind = "select", default = c.outputItemID, options = options } end
    if executorMode == "any" then
        fields[#fields + 1] = { id = "realmScope", label = L("SERVER_SCOPE"), kind = "select", default = defaultRealm, options = realmOptions }
    end
    local result = { fields = fields, managesExecutionScope = true, needsCharacter = executorMode == "character", characterOptions = characterOptions }
    if executorMode == "any" and not c.realmScope then
        result.needsConfiguration, result.title = true, L("REALM_REQUIRED"); return result
    end
    if (executorMode == "character" and not clean.scope.characterID) or not c.quantity or not c.mode or (hasProducts and not c.outputItemID) then
        result.needsConfiguration = true; return result
    end
    if type(c.quantity) ~= "number" or c.quantity < 1 or c.quantity > 100000000 or c.quantity % 1 ~= 0 then return nil, L("VALID_QUANTITY_REQUIRED") end
    local matches
    for _, id in ipairs(recipe.outputItemIDs or {}) do if id == c.outputItemID then matches = true end end
    if (hasProducts and not matches) or (c.mode ~= "craft-times" and c.mode ~= "holding") then return nil, L("INVALID_PRODUCT_MODE") end
    local counts = Addon.Store.db.goalCraftCounts or {}
    local key
    if executorMode == "character" then
        if not Core.Characters:Get(clean.scope.characterID, { identityOnly = true }) then return nil, L("CHARACTER_MISSING") end
        local learned = false
        for _, id in ipairs(candidates) do if id == clean.scope.characterID then learned = true; break end end
        if not learned then return nil, L("RECIPE_NOT_LEARNED") end
        clean.scope.mode, clean.scope.characterIDs = "character", nil
        local current = counts[clean.scope.characterID] or {}
        c.startCount = not r.restart and c.baselineCharacterID == clean.scope.characterID and tonumber(c.startCount) or (current[intent.objectID] or 0)
        c.baselineCharacterID, c.startCounts = clean.scope.characterID, nil
        key = clean.scope.characterID
    else
        clean.scope.mode, clean.scope.characterID, clean.scope.characterIDs = "account", nil, candidates
        if r.restart or c.baselineScope ~= "account" or type(c.startCounts) ~= "table" then
            c.startCounts = {}
            -- Capture all existing cast counters so a later profession change
            -- cannot count casts made before the goal was created.
            for id, spells in pairs(counts) do c.startCounts[id] = spells[intent.objectID] or 0 end
        end
        c.baselineScope, c.startCount, c.baselineCharacterID = "account", nil, nil
        key = "any-profession:" .. c.professionID .. (c.realmScope == "all" and "" or ":" .. c.realmScope)
    end
    clean.repeatPolicy, clean.targetType = "once", "crafting"
    result.intent = clean
    result.identity = self.PROVIDER .. ":" .. key .. ":" .. intent.objectID .. ":" .. (c.outputItemID or "spell") .. ":" .. c.mode
    local info = c.outputItemID and Core.ItemResolver and Core.ItemResolver:GetInfo(c.outputItemID)
    local name = c.mode == "holding" and info and info.name or (GetSpellInfo and GetSpellInfo(intent.objectID)) or L("RECIPE_ID", intent.objectID)
    result.title = L(c.mode == "holding" and "HOLD_TITLE" or "CRAFT_TITLE", name, c.quantity)
    if executorMode == "any" then result.title = L("SCOPED_GOAL_TITLE", result.title, c.realmScope == "all" and L("UI.ALL_REALMS") or c.realmScope:sub(7)) end
    return result
end
function Targets:Evaluate(r)
    local db = Addon.Store.db
    local result = { sourceEpoch = db.goalSourceEpoch, revision = db.goalRevision or 0, sourceTitle = L("PAGE_TITLE"), evaluations = {} }
    local current = Core.Characters:GetCurrent({ identityOnly = true })
    local inventoryRef
    for _, ref in ipairs(Core.Contracts:List("action.targets", { major = 1 })) do
        if ref.providerID == "YiboVault:targets" then inventoryRef = ref; break end
    end
    for _, goal in ipairs(r.goals or {}) do
        local clean, err = self:Normalize({ intent = goal.intent })
        if clean and not clean.needsConfiguration then
            local intent, c = clean.intent, clean.intent.conditions
            local any = intent.scope.mode == "account"
            local ids = any and intent.scope.characterIDs or { intent.scope.characterID }
            local done, known, learned, count, observedAt = false, true, false, 0, db.goalObservedAt
            for _, id in ipairs(ids) do
                local roleLearned = Addon.Store:GetRecipeState(id, c.professionID, intent.objectID) == "learned"
                learned = learned or roleLearned
                local roleKnown, roleDone, roleCount
                if c.mode == "craft-times" then
                    local baseline = any and (c.startCounts[id] or 0) or c.startCount
                    roleCount = math.max(0, ((db.goalCraftCounts[id] or {})[intent.objectID] or 0) - baseline)
                    roleDone = roleCount >= c.quantity
                    roleKnown = roleDone or (current and current.id == id) or false
                elseif inventoryRef then
                    local response = Core.Contracts:Call(Addon.NAME, inventoryRef, "Evaluate", { goals = { { id = goal.id, intent = {
                        providerID = inventoryRef.providerID, objectID = c.outputItemID,
                        scope = { mode = "character", characterID = id }, conditions = { quantity = c.quantity, storage = "bags", mode = "once", scopeMode = "character" }, repeatPolicy = "once" } } } })
                    local task = response and response.evaluations and response.evaluations[goal.id] and response.evaluations[goal.id].task
                    roleKnown = task and task.freshness and task.freshness.state == "known"
                        and (not task.freshness.validUntil or task.freshness.validUntil > Now())
                    roleDone = roleKnown and task.state == "completed"
                    roleCount = task and task.item and task.item.quantity or 0
                    if task and task.freshness and task.freshness.observedAt then observedAt = task.freshness.observedAt end
                end
                known = known and roleKnown == true
                done = done or roleDone == true
                count = math.max(count, roleCount or 0)
            end
            known = done or known
            local reasonKey = any and "PROGRESS_SHARED" or "PROGRESS"
            if not known then
                reasonKey = (any and "SHARED_" or "") .. (c.mode == "holding" and "HOLD_PROGRESS_PENDING" or "CAST_PROGRESS_PENDING")
            end
            local reason = L(reasonKey, count, c.quantity)
            result.evaluations[goal.id] = { task = { title = clean.title, reason = reason, summary = reason,
                state = done and "completed" or "active",
                readiness = done and "not-applicable" or ((not known or not learned) and "unknown" or "preparation"),
                execution = any and { mode = "account", candidateCharacterIDs = ids } or { mode = "self", characterID = ids[1] },
                beneficiary = any and { mode = "account" } or { mode = "character", characterID = ids[1] },
                temporal = { kind = "persistent" }, freshness = { state = known and "known" or "partial", observedAt = observedAt },
                item = c.mode == "holding" and { itemID = c.outputItemID, quantity = count } or nil,
                nextAction = { kind = "open-page", pageID = "crafting" } } }
        elseif clean and clean.needsConfiguration and clean.title then
            -- Keep legacy unscoped goals editable without projecting their old
            -- account-wide candidate snapshot onto every character.
            result.evaluations[goal.id] = { task = {
                title = goal.title or clean.title, reason = clean.title, summary = clean.title,
                state = "active", readiness = "unknown",
                execution = { mode = "account", candidateCharacterIDs = {} }, beneficiary = { mode = "account" },
                temporal = { kind = "persistent" }, freshness = { state = "unavailable" },
            } }
        else result.evaluations[goal.id] = { reason = err or L("CHARACTER_PROFESSION_REQUIRED") } end
    end
    return result
end
function Targets:RecipeStatesChanged(characterID, professionID)
    if not self.ref then return end
    local db = Addon.Store.db
    db.goalRevision = (db.goalRevision or 0) + 1
    Core.Contracts:NotifyChanged(Addon.NAME, self.ref, {
        reason = "recipe-learning-changed", characterID = characterID, professionID = professionID,
    })
end
function Targets:Initialize()
    if not (Core:CheckAPIVersion(13) and Core:HasCapability("localization", 1) and Core.Locale and Core:HasCapability("business-item-actions", 2)) then
        Core:Print(Core.Locale and L("UPGRADE_CORE") or "YiboCrafting: Core API v13 / localization:1 / business-item-actions:2"); return
    end
    if self.ref then return true end
    local db = Addon.Store.db
    db.goalSourceEpoch = db.goalSourceEpoch or ("crafting:" .. Now() .. ":" .. math.random(100000, 999999)); db.goalCraftCounts = db.goalCraftCounts or {}
    self.definition = { name = "action.targets", kind = "provider", providerID = self.PROVIDER, version = { major = 1, minor = 2 },
        methods = { GetEntry = function() return { title = L("PAGE_TITLE"), pageID = "crafting" } end, Normalize = function(r) return Targets:Normalize(r) end, Evaluate = function(r) return Targets:Evaluate(r) end } }
    self.ref = Core.Contracts:Register(Addon.NAME, self.definition)
    if not self.ref then return nil end
    Core.Events:Register("DATA_DOMAIN_UPDATED", self, function(_, snapshot)
        if snapshot.domainID == "professions" and Targets.ref then
            db.goalRevision = (db.goalRevision or 0) + 1
            Core.Contracts:NotifyChanged(Addon.NAME, Targets.ref, { reason = "profession-candidates-changed" })
        end
    end)
    for _, event in ipairs({ "BUSINESS_CONTRACT_REGISTERED", "BUSINESS_CONTRACT_UNREGISTERED", "BUSINESS_CONTRACT_CHANGED" }) do
        Core.Events:Register(event, self, function(_, descriptor)
            if descriptor.providerID == "YiboVault:targets" and Targets.ref then
                db.goalRevision = (db.goalRevision or 0) + 1
                Core.Contracts:NotifyChanged(Addon.NAME, Targets.ref, { reason = "holding-source-changed" })
            end
        end)
    end
    self.frame = self.frame or CreateFrame("Frame"); self.frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self.frame:SetScript("OnEvent", function(_, _, unit, castGUID, spellID)
        if unit ~= "player" then return end
        -- UNIT_SPELLCAST_SUCCEEDED: unit, castGUID, spellID, optional castBarID.
        -- The recipe ID stays in position three when the payload grows.
        spellID = tonumber(spellID); if not spellID then return end
        local professionID
        for id, recipes in pairs(Addon.RecipeCatalog.professions) do if recipes[spellID] then professionID = id; break end end
        if not professionID then return end
        local current = Core.Characters:GetCurrent({ identityOnly = true }); if not current then return end
        db.goalCraftCounts[current.id] = db.goalCraftCounts[current.id] or {}
        local counts = db.goalCraftCounts[current.id]; counts[spellID] = (counts[spellID] or 0) + 1
        db.goalObservedAt, db.goalRevision = Now(), (db.goalRevision or 0) + 1
        Core.Contracts:NotifyChanged(Addon.NAME, Targets.ref, { reason = "craft-observed", characterID = current.id })
    end)
    return self.ref ~= nil
end
function Targets:Bind(control, entry, characterID, original, menu, product)
    if not self.ref then return end
    if characterID and Addon.Store:GetRecipeState(characterID, entry.professionID, entry.id) ~= "learned" then
        Core.BusinessItemActions:Unbind(control); return
    end
    local intent = { providerID = self.PROVIDER, objectID = entry.id, scope = { mode = "character", characterID = characterID },
        conditions = { professionID = entry.professionID, outputItemID = entry.outputItemID,
            quantity = 1, executorMode = characterID and "character" or "any", mode = product and "holding" or "craft-times" } }
    Core.BusinessItemActions:Bind(control, { owner = Addon.NAME, menu = menu, menuPlacement = product and "right" or nil, GetIntent = function() return intent end, ctrlLeftSafe = true, reservedButtons = { LeftButton = true } })
    control:RegisterForClicks("AnyUp"); control:SetScript("OnClick", function(self, button)
        if not intent.conditions.outputItemID and Core.BusinessItemActions:Matches(button) then
            Core.BusinessItemActions:Invoke(self); return
        end
        if Core.BusinessItemActions:Handle(self, button) then return end
        if original and button == "LeftButton" then original(self, button) end
    end)
    Core.UITheme:BindTooltip(control, entry.name, Core.BusinessItemActions:TooltipLines(control.tooltipLines or {}, control))
end

function Targets:BindRecipeHits(row, entry)
    for _, hit in ipairs({ row.nameHit, row.iconHit }) do
        local product = hit == row.iconHit
        if not product or entry.outputItemID then
            local enter, leave = hit:GetScript("OnEnter"), hit:GetScript("OnLeave")
            self:Bind(hit, entry, nil, hit:GetScript("OnClick"), true, product)
            hit:SetScript("OnEnter", function(control)
                if enter then enter(control) end
                if GameTooltip and GameTooltip:IsShown() then
                    GameTooltip:AddLine(L("ACTION_HINT", Core.BusinessItemActions:GestureLabel()))
                    GameTooltip:Show()
                end
            end)
            hit:SetScript("OnLeave", leave)
        else Core.BusinessItemActions:Unbind(hit) end
    end
end
function Targets:Shutdown()
    Core.Events:Unregister("DATA_DOMAIN_UPDATED", self)
    for _, event in ipairs({ "BUSINESS_CONTRACT_REGISTERED", "BUSINESS_CONTRACT_UNREGISTERED", "BUSINESS_CONTRACT_CHANGED" }) do Core.Events:Unregister(event, self) end
    if self.frame then self.frame:UnregisterAllEvents(); self.frame:SetScript("OnEvent", nil) end
    if self.ref then Core.Contracts:Unregister(Addon.NAME, self.ref); self.ref = nil end
end
