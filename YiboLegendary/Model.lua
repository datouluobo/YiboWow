local Addon = _G.YiboLegendary
local Model = {}
Addon.Model = Model

Model.STATUS = { completed=true, in_progress=true, obtainable=true, pending_sync=true, ineligible=true, unknown=true, unavailable=true }

local function ItemCount(itemID)
    if type(GetItemCount) ~= "function" then return nil end
    local count = GetItemCount(itemID, true, false, true)
    return type(count) == "number" and count or nil
end

local function ItemObserved(itemID)
    local count = ItemCount(itemID)
    if count and count > 0 then return count, true end
    if type(GetInventoryItemID) == "function" then
        for slot = 1, 19 do if GetInventoryItemID("player", slot) == itemID then return count or 0, true end end
    end
    return count, false
end

local function CharacterCanUse(character, target)
    local eligibility = target.eligibility or {}
    if eligibility.allowedClasses then return eligibility.allowedClasses[character.class or ""] == true end
    return not (eligibility.excludedClasses and eligibility.excludedClasses[character.class or ""])
end

local function Evidence(source, updatedAt, extra)
    local result = { source=source, updatedAt=updatedAt }
    if extra then for key, value in pairs(extra) do result[key] = value end end
    return result
end

local function Snapshot(targetID, status, acquired, stageLabel, progressText, nextAction, currentNodeIds, evidence)
    return { targetId=targetID, status=status, acquired=acquired == true, currentNodeIds=currentNodeIds or {}, stageLabel=stageLabel, progressText=progressText, nextAction=nextAction, evidence=evidence or Evidence("real", Addon:GetTimestamp()) }
end

local function Observe(store, itemID)
    store.observedItems = store.observedItems or {}
    local count, observed = ItemObserved(itemID)
    if observed then store.observedItems[itemID] = true end
    return count, observed or store.observedItems[itemID] == true
end

local function Objective(entry, faction)
    local definition = entry and entry.definition
    if not definition then return "等待前置条件" end
    if definition.valor then return string.format("勇气 %d/%d", tonumber(entry.valorProgress) or 0, Addon.Data.VALOR_TARGET) end
    if entry.log and entry.log.objectives and #entry.log.objectives > 0 then return table.concat(entry.log.objectives, "；") end
    return (definition.objectiveByFaction and definition.objectiveByFaction[faction]) or definition.objective or "等待任务更新"
end

local function CloakSnapshot(character, legacy)
    if legacy.readable == false then return Snapshot("CLOAK", "unknown", false, "无法读取任务状态", "执行 /yle probe", "确认任务 API 兼容性。", nil, Evidence("real", Addon:GetTimestamp(), { readable=false })) end
    if legacy.completed then return Snapshot("CLOAK", "completed", true, "传说披风任务线", "已完成", "—", nil, Evidence("real", Addon:GetTimestamp(), { kind="quest" })) end
    local current = legacy.current
    if not current then return Snapshot("CLOAK", "pending_sync", false, "尚无可确定的下一任务", "等待任务同步", "登录并打开任务日志后重新同步。", nil, Evidence("real", Addon:GetTimestamp())) end
    local definition = current.definition or Addon.Data.byID[current.definitionId] or {}
    local label = definition.chapter and definition.chapter > 0 and ("第 " .. definition.chapter .. " 章 · ") or ""
    local status = current.status == "available" and "obtainable" or (current.status == "unavailable" and "unavailable" or "in_progress")
    return Snapshot("CLOAK", status, false, label .. ((current.log and current.log.title) or definition.name or "当前任务"), Objective(current, legacy.faction), Addon.Data:GetTableAction(current), { current.definitionId }, Evidence("real", Addon:GetTimestamp(), { kind="quest" }))
end

local function ManualState(store, targetID)
    local evidence = store.manualEvidence and store.manualEvidence[targetID]
    if evidence and evidence.confirmed then return evidence end
end

local function ThunderfurySnapshot(character, store, target)
    if not CharacterCanUse(character, target) then return Snapshot(target.id, "ineligible", false, "不适用", "该职业无法装备风剑", "—", nil, Evidence("real", Addon:GetTimestamp())) end
    local projected = Addon.runtime and Addon.runtime.testProjectionByCharacter[character.id] and Addon.runtime.testProjectionByCharacter[character.id][target.id]
    if projected then projected.evidence = Evidence("projection", Addon:GetTimestamp()); return projected end
    for _, itemID in ipairs(target.finalItemIds or { target.finalItemId }) do
        local count, seen = Observe(store, itemID)
        if (count or 0) > 0 or seen then return Snapshot(target.id, "completed", true, "已获得", "雷霆之怒", "—", nil, Evidence("real", Addon:GetTimestamp(), { kind="item", itemId=itemID })) end
    end
    local _, leftSeen = Observe(store, 18563); local _, rightSeen = Observe(store, 18564)
    local bindings = (leftSeen and 1 or 0) + (rightSeen and 1 or 0)
    if bindings < 2 then return Snapshot(target.id, "obtainable", false, "逐风者禁锢之颅", string.format("关键掉落 %d/2 · 本周可刷", bindings), "前往熔火之心击败加尔与迦顿男爵。", { leftSeen and "BINDING_RIGHT" or "BINDING_LEFT", rightSeen and "BINDING_LEFT" or "BINDING_RIGHT" }, Evidence("real", Addon:GetTimestamp())) end
    local ingots, ingotsSeen = Observe(store, 18562)
    if not ingotsSeen or (ingots or 0) < 10 then return Snapshot(target.id, "in_progress", false, "收集元素锭", string.format("元素锭 %d/10", ingots or 0), "前往黑翼之巢收集元素锭。", { "ELEMENTIUM" }, Evidence("real", Addon:GetTimestamp())) end
    return Snapshot(target.id, "obtainable", false, "召唤逐风者桑德兰", "材料已齐", "前往希利苏斯完成最终事件。", { "THUNDERAAN" }, Evidence("real", Addon:GetTimestamp()))
end

local function SoridalSnapshot(character, store, target)
    if not CharacterCanUse(character, target) then return Snapshot(target.id, "ineligible", false, "不适用", "该职业无法获取索利达尔", "—", nil, Evidence("real", Addon:GetTimestamp())) end
    local projected = Addon.runtime and Addon.runtime.testProjectionByCharacter[character.id] and Addon.runtime.testProjectionByCharacter[character.id][target.id]
    if projected then projected.evidence = Evidence("projection", Addon:GetTimestamp()); return projected end
    for _, itemID in ipairs(target.finalItemIds or {}) do
        local count, seen = Observe(store, itemID)
        if (count or 0) > 0 or seen then return Snapshot(target.id, "completed", true, "已获得", "自动检测", "—", { "SORIDAL_ITEM" }, Evidence("real", Addon:GetTimestamp(), { kind="item", itemId=itemID })) end
    end
    local manual = ManualState(store, target.id)
    if manual then return Snapshot(target.id, "completed", true, "已获得", "玩家确认", "—", { "SORIDAL_ITEM" }, Evidence("manual", manual.updatedAt, manual)) end
    return Snapshot(target.id, "obtainable", false, "基尔加丹掉落", "未获得 · 可刷取", "前往太阳之井高地击败基尔加丹。", { "SORIDAL_DROP" }, Evidence("real", Addon:GetTimestamp(), { kind="bossDrop", boss="基尔加丹" }))
end

function Model:BuildSnapshot(character, store, phaseAvailability, valorProgress)
    local legacy = Addon.Data:BuildSnapshot(character, phaseAvailability, valorProgress)
    local targets = { CLOAK=CloakSnapshot(character, legacy) }
    for _, target in ipairs(Addon.Catalog:GetTargets()) do
        if target.id == "THUNDERFURY" then targets[target.id] = ThunderfurySnapshot(character, store, target)
        elseif target.id == "SORIDAL" then targets[target.id] = SoridalSnapshot(character, store, target) end
    end
    return { characterID=character.id, readable=legacy.readable, legacy=legacy, targets=targets, updatedAt=Addon:GetTimestamp() }
end

local function ProjectionState(target, nodeID)
    local states = {
        BINDING_LEFT=Snapshot(target.id, "obtainable", false, "逐风者禁锢之颅", "关键掉落 1/2 · 本周可刷", "继续前往熔火之心击败另一名首领。", { "BINDING_RIGHT" }, Evidence("projection", Addon:GetTimestamp())),
        BINDING_RIGHT=Snapshot(target.id, "obtainable", false, "逐风者禁锢之颅", "关键掉落 1/2 · 本周可刷", "继续前往熔火之心击败另一名首领。", { "BINDING_LEFT" }, Evidence("projection", Addon:GetTimestamp())),
        BINDINGS=Snapshot(target.id, "in_progress", false, "收集元素锭", "元素锭 0/10", "前往黑翼之巢收集元素锭。", { "ELEMENTIUM" }, Evidence("projection", Addon:GetTimestamp())),
        ELEMENTIUM=Snapshot(target.id, "in_progress", false, "收集元素锭", "元素锭 4/10", "继续收集元素锭。", { "ELEMENTIUM" }, Evidence("projection", Addon:GetTimestamp())),
        THUNDERAAN=Snapshot(target.id, "obtainable", false, "召唤逐风者桑德兰", "材料已齐", "前往希利苏斯完成最终事件。", { "THUNDERAAN" }, Evidence("projection", Addon:GetTimestamp())),
        COMPLETED=Snapshot(target.id, "completed", true, "已获得", "雷霆之怒", "—", nil, Evidence("projection", Addon:GetTimestamp())),
    }
    return states[string.upper(nodeID or "")]
end

function Model:SetTestProjection(characterID, targetID, nodeID)
    local target = Addon.Catalog:GetTarget(targetID)
    if not target then return false, "未知传说目标" end
    Addon.runtime.testProjectionByCharacter[characterID] = Addon.runtime.testProjectionByCharacter[characterID] or {}
    if nodeID == nil or nodeID == "" or string.upper(nodeID) == "CLEAR" then Addon.runtime.testProjectionByCharacter[characterID][targetID] = nil; return true end
    if string.upper(nodeID) == "ALL" then nodeID = "COMPLETED" end
    if targetID ~= "THUNDERFURY" then return false, "当前测试投影仅支持风剑路线" end
    local state = ProjectionState(target, nodeID)
    if not state then return false, "可用节点：BINDING_LEFT、BINDING_RIGHT、BINDINGS、ELEMENTIUM、THUNDERAAN、COMPLETED" end
    Addon.runtime.testProjectionByCharacter[characterID][targetID] = state
    return true
end

function Model:SetManualEvidence(characterID, targetID)
    local target = Addon.Catalog:GetTarget(targetID)
    if not target or not target.manualEvidenceAllowed then return false, "该目标不允许人工确认" end
    local store = Addon.db.byCharacter[characterID] or {}; Addon.db.byCharacter[characterID] = store
    store.manualEvidence = store.manualEvidence or {}
    store.manualEvidence[targetID] = { confirmed=true, characterID=characterID, targetId=targetID, source="manual", updatedAt=Addon:GetTimestamp(), revocable=true }
    return true
end

function Model:ClearManualEvidence(characterID, targetID)
    local store = Addon.db.byCharacter[characterID]
    if store and store.manualEvidence then store.manualEvidence[targetID] = nil end
    return true
end

function Model:ClearCharacterRuntime(characterID)
    if Addon.runtime and Addon.runtime.testProjectionByCharacter then Addon.runtime.testProjectionByCharacter[characterID] = nil end
end
