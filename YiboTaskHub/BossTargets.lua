local Addon = _G.YiboTaskHub
local Targets = {}
Addon.BossTargets = Targets
local function Copy(value) return Addon.Core.Defaults:Copy(value) end
local function Root()
    if Targets.view then return Targets.view end
    local metadata, goals = Addon.db.bossTargets, Addon.db.goals
    local view = { byCharacter = {}, revision = goals.revision, nextID = metadata.nextID, sourceEpoch = metadata.sourceEpoch }
    for _, goal in ipairs(Addon.Goals:List(false, { omitHistory = true })) do if goal.intent.targetType == "boss" then
        local normalized = Addon.Goals:Normalize(goal.intent)
        local id, target = goal.intent.scope.characterID, Copy(normalized and normalized.intent and normalized.intent.conditions or goal.intent.conditions)
        target.id, target.active = goal.legacyBossID or goal.id, goal.state == "active"
        view.byCharacter[id] = view.byCharacter[id] or {}; table.insert(view.byCharacter[id], target)
    end end
    Targets.view = view
    return view
end
local function IDs(request)
    local ids = type(request) == "table" and type(request.scope) == "table" and request.scope.characterIDs
    if type(ids) ~= "table" then return nil end
    local result, seen, count = {}, {}, 0
    for k, id in pairs(ids) do
        if type(k) ~= "number" or k < 1 or k % 1 ~= 0 or type(id) ~= "string" or id == "" then return nil end
        count = count + 1
    end
    if count ~= #ids then return nil end
    for _, id in ipairs(ids) do if not seen[id] then result[#result + 1], seen[id] = id, true end end
    return result
end
function Targets:Query(request)
    local ids = IDs(request)
    if not ids then return nil, "invalid-request" end
    local db, result = Root(), { targets = {}, characterIDs = ids }
    result.sourceEpoch, result.revision = db.sourceEpoch, db.revision
    result.autoDisplay = Addon.db.settings.bossTargetsAutoDisplay
    for _, id in ipairs(ids) do result.targets[id] = Copy(db.byCharacter[id] or {}) end
    return result
end
function Targets:Catalog(force)
    if self.catalog and not force then return self.catalog end
    local c = Addon.Core.Contracts
    local ref = c:Resolve("boss.target-catalog", { major = 1 })
    if not ref then self.catalog = nil; return nil, Addon:T("TEXT.BOSS_CATALOG_IS_UNAVAILABLE_ENABLE_A.AE7BF0") end
    local value, err = c:Call(Addon.NAME, ref, "Query", {})
    if type(value) ~= "table" or type(value.targets) ~= "table" then self.catalog = nil; return nil, err or Addon:T("TEXT.CATALOG_TEMPORARILY_UNAVAILABLE.8F08A3") end
    self.catalog = value
    return value
end
function Targets:List(characterID) return Copy(Root().byCharacter[characterID] or {}) end
function Targets:Changed()
    local db, stored, seen = Root(), Addon.db.goals, {}
    local nextByID = Copy(stored.byID)
    for characterID, list in pairs(db.byCharacter) do for _, target in ipairs(list) do
        local goal
        for _, old in pairs(nextByID) do
            if old.intent.targetType == "boss" and old.intent.scope.characterID == characterID
                and (old.legacyBossID or old.id) == target.id and old.state ~= "removed" then goal = old; break end
        end
        if not goal then
            stored.nextID = stored.nextID + 1
            local id = "goal:" .. stored.nextID
            goal = { id = id, priority = 0, revision = 0, history = {}, createdAt = Addon:Now(), legacyBossID = target.id }
            nextByID[id] = goal
        end
        local policy = target.repeatPolicy or (goal.intent and goal.intent.repeatPolicy) or "recurring"
        local state = goal.state or "active"
        if target.active ~= (state == "active") then state = target.active and "active" or "paused" end
        goal.title, goal.state, goal.revision, goal.updatedAt = target.title, state, goal.revision + 1, Addon:Now()
        goal.intent = { providerID = "YiboAltoBoss:targets", objectID = target.catalogID, targetType = "boss", scope = { mode = "character", characterID = characterID },
            conditions = Copy(target), repeatPolicy = policy }
        goal.identity = nil -- Source normalization supplies the canonical identity on the next exact query.
        seen[goal.id] = true
    end end
    for id, goal in pairs(nextByID) do if goal.intent.targetType == "boss" and not seen[id] then goal.state = "removed" end end
    stored.byID = nextByID
    Addon.db.bossTargets.nextID = db.nextID
    Targets.view = nil
    Addon.Goals:Changed("YiboAltoBoss:targets")
    db = Root()
    if self.ref then Addon.Core.Contracts:NotifyChanged(Addon.NAME, self.ref, { sourceEpoch = db.sourceEpoch, revision = db.revision }) end
    Addon.Contracts:Invalidate("YiboAltoBoss:targets")
end
function Targets:SetAutoDisplay(value)
    if type(value) ~= "boolean" then return nil, "invalid-setting" end
    if Addon.db.settings.bossTargetsAutoDisplay ~= value then Addon.db.settings.bossTargetsAutoDisplay = value; self:Changed() end
    return true
end
local function Key(target) return target.catalogID .. ":" .. tostring(target.difficultyID or 0) .. ":" .. (target.repeatPolicy or "recurring") end
local function Merge(list, target)
    for _, old in ipairs(list) do
        if Key(old) == Key(target) then
            if old.scope == "all" then return "unchanged" end
            if target.scope == "all" then old.scope, old.encounterIDs = "all", {}; return "merged" end
            local seen, changed = {}, false
            for _, id in ipairs(old.encounterIDs or {}) do seen[id] = true end
            for _, id in ipairs(target.encounterIDs or {}) do
                if not seen[id] then old.encounterIDs[#old.encounterIDs + 1], seen[id], changed = id, true, true end
            end
            table.sort(old.encounterIDs)
            return changed and "merged" or "unchanged"
        end
    end
    list[#list + 1] = target
    return "added"
end
function Targets:Validate(target)
    local ref
    for _, d in ipairs(Addon.Core.Contracts:List("action.targets", { major = 1 })) do if d.providerID == "YiboAltoBoss:targets" then ref = d end end
    if not ref then return nil, Addon:T("TEXT.ENABLE_A_COMPATIBLE_BOSS_TRACKER_TO_.30FBC7") end
    local character = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    local clean, err = Addon.Core.Contracts:Call(Addon.NAME, ref, "Normalize", { intent = { providerID = ref.providerID,
        scope = { mode = "character", characterID = character and character.id }, conditions = target, repeatPolicy = "recurring" } })
    if not clean or clean.needsConfiguration then return nil, err or Addon:T("TEXT.CHOOSE_A_RAID_DIFFICULTY_AND_BOSS.606BD2") end
    local result = clean.intent.conditions; result.active = target.active ~= false
    return result
end
function Targets:Put(characterID, target, replacing)
    if not Addon.Core.Characters:Get(characterID, { identityOnly = true }) then return nil, Addon:T("TEXT.CHARACTER_NOT_FOUND.3B434E") end
    local clean, err = self:Validate(target)
    if not clean then return nil, err end
    local db, list = Root(), self:List(characterID)
    if replacing then
        local found
        for i, old in ipairs(list) do if old.id == replacing then table.remove(list, i); found = true; break end end
        if not found then return nil, Addon:T("TEXT.GOAL_CHANGED_REFRESH_AND_TRY_AGAIN.EA300F") end
    end
    local nextID = db.nextID + 1
    clean.id = "target:" .. nextID
    if replacing then clean.id = replacing end
    Merge(list, clean)
    db.nextID, db.byCharacter[characterID] = nextID, list
    self:Changed(); return true
end
function Targets:PutMany(characterID, targets)
    if not Addon.Core.Characters:Get(characterID, { identityOnly = true }) then return nil, Addon:T("TEXT.CHARACTER_NOT_FOUND.3B434E") end
    local db, list, nextID = Root(), self:List(characterID), Root().nextID
    for _, target in ipairs(targets) do
        local clean, err = self:Validate(target)
        if not clean then return nil, err end
        nextID = nextID + 1; clean.id = "target:" .. nextID; Merge(list, clean)
    end
    db.byCharacter[characterID], db.nextID = list, nextID; self:Changed(); return true
end
function Targets:Edit(characterID, id, active, remove)
    local list = self:List(characterID)
    for i, target in ipairs(list) do if target.id == id then
        if remove then table.remove(list, i) else target.active = active == true end
        Root().byCharacter[characterID] = list; self:Changed(); return true
    end end
    return nil, Addon:T("TEXT.GOAL_CHANGED.07E7F5")
end
function Targets:PreviewCopy(sourceID, destinations)
    local db, source, pending = Root(), self:List(sourceID), { sourceEpoch = Root().sourceEpoch, revision = Root().revision,
        byCharacter = {}, changes = {}, added = 0, merged = 0, expanded = 0, unchanged = 0, pausedDifferences = 0, nextID = Root().nextID }
    if not Addon.Core.Characters:Get(sourceID, { identityOnly = true }) then return nil, Addon:T("TEXT.SOURCE_CHARACTER_NOT_FOUND.D3391A") end
    for _, id in ipairs(destinations or {}) do
        if id ~= sourceID and not pending.byCharacter[id] then
            if not Addon.Core.Characters:Get(id, { identityOnly = true }) then return nil, Addon:T("TEXT.TARGET_CHARACTER_NOT_FOUND.5BE13A") end
            local list = self:List(id)
            local change = { added = 0, merged = 0, expanded = 0, unchanged = 0 }
            for _, target in ipairs(source) do
                local incoming = Copy(target)
                for _, old in ipairs(list) do if Key(old) == Key(incoming) then
                    if old.active ~= incoming.active then pending.pausedDifferences = pending.pausedDifferences + 1 end
                    if old.scope ~= "all" and incoming.scope == "all" then pending.expanded, change.expanded = pending.expanded + 1, change.expanded + 1 end
                end end
                pending.nextID = pending.nextID + 1; incoming.id = "target:" .. pending.nextID
                local status = Merge(list, incoming); pending[status] = pending[status] + 1
                change[status] = change[status] + 1
            end
            pending.byCharacter[id] = list
            pending.changes[id] = change
        end
    end
    return pending
end
function Targets:ApplyCopy(pending)
    local db = Root()
    if not pending or pending.sourceEpoch ~= db.sourceEpoch or pending.revision ~= db.revision then return nil, Addon:T("TEXT.GOAL_CHANGED_PREVIEW_THE_COPY_AGAIN.54D9B0") end
    for id in pairs(pending.byCharacter) do if not Addon.Core.Characters:Get(id, { identityOnly = true }) then return nil, Addon:T("TEXT.CHARACTER_WAS_REMOVED_PREVIEW_AGAIN.AEC272") end end
    local nextByCharacter = Copy(db.byCharacter)
    for id, list in pairs(pending.byCharacter) do nextByCharacter[id] = Copy(list) end
    db.byCharacter, db.nextID = nextByCharacter, pending.nextID
    self:Changed(); return true
end
local function Normalize(text)
    return tostring(text or ""):lower():gsub("[%s%p]", ""):gsub("：", ""):gsub("·", ""):gsub("（", ""):gsub("）", "")
end
function Targets:Matches(definition, query)
    local needle = Normalize(query)
    if needle == "" then return true end
    local words = { definition.name, definition.englishName or "", definition.expansion or "" }
    for _, word in ipairs(definition.aliases or {}) do words[#words + 1] = word end
    for _, e in ipairs(definition.encounters or {}) do
        words[#words + 1] = e.name
        for _, alias in ipairs(e.aliases or {}) do words[#words + 1] = alias end
    end
    for _, word in ipairs(words) do if Normalize(word):find(needle, 1, true) then return true end end
    return false
end
function Targets:EncounterMatch(definition, query)
    local needle = Normalize(query)
    if needle == "" then return nil end
    for _, encounter in ipairs(definition.encounters or {}) do
        if Normalize(encounter.name):find(needle, 1, true) then return encounter.name end
        for _, alias in ipairs(encounter.aliases or {}) do if Normalize(alias):find(needle, 1, true) then return encounter.name end end
    end
end
function Targets:Initialize()
    if self.ref then return true end
    local core = Addon.Core
    self.definition = self.definition or { kind = "service", name = "task.boss-targets", providerID = Addon.NAME .. ":boss-targets",
        version = { major = 1, minor = 0 }, methods = { Query = function(request) return Targets:Query(request) end } }
    for _, event in ipairs({ "BUSINESS_CONTRACT_REGISTERED", "BUSINESS_CONTRACT_UNREGISTERED", "BUSINESS_CONTRACT_CHANGED" }) do
        core.Events:Register(event, self, function(_, descriptor)
            if descriptor.name == "boss.target-catalog" then self.catalog = nil; core.AccountView:NotifyPageChanged(Addon.PAGE_ID) end
        end)
    end
    core.Events:Register("CHARACTER_CACHE_DELETED", self, function()
        Targets.view = nil; Addon.Contracts:Invalidate("YiboAltoBoss:targets")
    end)
    local err
    self.ref, err = core.Contracts:Register(Addon.NAME, self.definition)
    if not self.ref then self:Shutdown() end
    return self.ref ~= nil, err
end
function Targets:Shutdown()
    if self.ref then Addon.Core.Contracts:Unregister(Addon.NAME, self.ref); self.ref = nil end
    for _, event in ipairs({ "BUSINESS_CONTRACT_REGISTERED", "BUSINESS_CONTRACT_UNREGISTERED", "BUSINESS_CONTRACT_CHANGED", "CHARACTER_CACHE_DELETED", "CHARACTER_ID_CHANGED" }) do Addon.Core.Events:Unregister(event, self) end
    self.catalog = nil
end
