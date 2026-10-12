local Addon, Core = _G.YiboReputation, _G.YiboCore
local Targets = { PROVIDER = "YiboReputation:targets" }
Addon.GoalTargets = Targets
function Targets:Normalize(r)
    local intent = r.intent
    if type(intent) ~= "table" or type(intent.objectID) ~= "number" or intent.objectID <= 0 then return nil, "请选择声望对象" end
    local clean = Core.Defaults:Copy(intent); clean.scope = clean.scope or { mode = "character" }; clean.conditions = clean.conditions or {}
    local fields = { { id = "rank", label = "目标等级（普通声望 1～8；友谊按来源等级）", kind = "number" } }
    if not clean.scope.characterID or not clean.conditions.rank then return { needsConfiguration = true, fields = fields } end
    local rank = clean.conditions.rank
    if type(rank) ~= "number" or rank % 1 ~= 0 or rank < 1 or rank > 8 then return nil, "声望等级必须是 1～8 的整数" end
    if not Core.Characters:Get(clean.scope.characterID, { identityOnly = true }) then return nil, "角色不存在" end
    clean.targetType, clean.repeatPolicy, clean.scope.mode = "reputation", "once", "character"
    return { intent = clean, identity = self.PROVIDER .. ":" .. clean.scope.characterID .. ":" .. clean.objectID,
        title = Addon:GetFactionName(clean.objectID) .. " · 等级 " .. rank, fields = fields }
end
function Targets:Evaluate(r)
    local db, snapshots = Addon:EnsureDB(), {}
    local result = { sourceEpoch = db.goalSourceEpoch, revision = Addon._matrixDataRevision or 0, sourceTitle = "声望之路", evaluations = {} }
    for _, goal in ipairs(r.goals or {}) do
        local clean, err = self:Normalize({ intent = goal.intent })
        if clean and not clean.needsConfiguration then
            local intent, id = clean.intent, clean.intent.scope.characterID
            if snapshots[id] == nil then snapshots[id] = Core.DataDomains:Get(id, "reputation") or false end
            local snapshot = snapshots[id] or nil
            local data = Addon:GetFactionData(snapshot, intent.objectID)
            local friend = data and Addon:GetFriendship(data)
            local rank = data and (friend and tonumber(friend.rank) or tonumber(data.standingID))
            local known = snapshot and snapshot.state == "known" and (tonumber(snapshot.schemaVersion) or 0) >= 5
                and snapshot.data and snapshot.data.contractVersion and rank ~= nil
            local done = known and rank >= intent.conditions.rank
            local reason = known and Addon:FormatReputation(data) or "登录角色同步声望；未采集或友谊等级不明"
            result.evaluations[goal.id] = { task = { title = clean.title, reason = reason, summary = reason,
                state = done and "completed" or "active", readiness = not known and "unknown" or (done and "not-applicable" or "actionable"),
                execution = { mode = "self", characterID = id }, beneficiary = { mode = "character", characterID = id },
                temporal = { kind = "persistent" }, freshness = { state = known and "known" or "partial", observedAt = snapshot and snapshot.updatedAt },
                nextAction = { kind = "open-page", pageID = "reputation" } } }
        else result.evaluations[goal.id] = { reason = err } end
    end
    return result
end
function Targets:Initialize()
    if not (Core:CheckAPIVersion(12) and Core:HasCapability("business-item-actions", 1)) then Core:Print("声望目标需要 Core API v12，请升级 Core。"); return end
    if self.ref then return true end
    local db = Addon:EnsureDB(); db.goalSourceEpoch = db.goalSourceEpoch or ("reputation:" .. GetServerTime() .. ":" .. math.random(100000,999999))
    self.definition = { name = "action.targets", kind = "provider", providerID = self.PROVIDER, version = { major = 1, minor = 1 },
        methods = { GetEntry = function() return { title = "声望", pageID = "reputation" } end, Normalize = function(r) return Targets:Normalize(r) end, Evaluate = function(r) return Targets:Evaluate(r) end } }
    self.ref = Core.Contracts:Register("YiboReputation", self.definition)
    return self.ref ~= nil
end
function Targets:BindRow(row, node, characters)
    if not self.ref then return end
    row.goalHits = row.goalHits or {}
    for _, hit in ipairs(row.goalHits) do hit:Hide(); Core.BusinessItemActions:Unbind(hit) end
    if node.kind ~= "faction" then return end
    for i, character in ipairs(characters) do
        local hit = row.goalHits[i] or CreateFrame("Button", nil, row); row.goalHits[i] = hit
        hit:ClearAllPoints(); hit:SetAllPoints(row.cells[i + 1]); hit:SetFrameLevel(row:GetFrameLevel() + 2)
        hit:RegisterForClicks("AnyUp")
        local intent = { providerID = self.PROVIDER, objectID = node.factionID, scope = { mode = "character", characterID = character.id }, conditions = {} }
        Core.BusinessItemActions:Bind(hit, { owner = "YiboReputation", GetIntent = function() return intent end, ctrlLeftSafe = true, reservedButtons = { LeftButton = true, RightButton = true } })
        hit:SetScript("OnClick", function(self, button)
            if Core.BusinessItemActions:Handle(self, button) then return end
            local original = row:GetScript("OnClick"); if original then original(row, button) end
        end)
        local snapshot = Core.DataDomains:Get(character.id, "reputation")
        local data = Addon:GetFactionData(snapshot, node.factionID)
        Core.UITheme:BindTooltip(hit, node.title, Core.BusinessItemActions:TooltipLines({ { kind = "text", text = data and Addon:FormatReputation(data) or "登录角色同步声望" } }, hit))
        hit:Show()
    end
end
