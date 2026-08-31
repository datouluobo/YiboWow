local Addon = _G.YiboLegendary
local Model = {}
Addon.Model = Model

local function IsCompleted(questID)
    local query = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
    return type(query) == "function" and query(questID) == true
end

local function ItemCount(itemID)
    if type(GetItemCount) ~= "function" then return nil end
    local count = GetItemCount(itemID, true, false, true)
    return type(count) == "number" and count or nil
end

local function CharacterCanUse(character, target)
    local excluded = target.eligibility and target.eligibility.excludedClasses
    return not (excluded and excluded[character.class or ""])
end

local function Observe(store, itemID)
    store.observedItems = store.observedItems or {}
    local count = ItemCount(itemID)
    if count and count > 0 then
        store.observedItems[itemID] = true
    end
    return count, store.observedItems[itemID] == true
end

local function Objective(entry, faction)
    local definition = entry and entry.definition
    if not definition then return "等待前置条件" end
    if definition.valor then
        return string.format("勇气 %d/%d", tonumber(entry.valorProgress) or 0, Addon.Data.VALOR_TARGET)
    end
    if entry.log and entry.log.objectives and #entry.log.objectives > 0 then
        return table.concat(entry.log.objectives, "；")
    end
    return (definition.objectiveByFaction and definition.objectiveByFaction[faction]) or definition.objective or "等待任务更新"
end

local function CloakSnapshot(character, legacy)
    if legacy.readable == false then
        return { targetId = "CLOAK", status = "unknown", acquired = false, stageLabel = "无法读取任务状态", progressText = "执行 /yle probe", nextAction = "确认任务 API 兼容性。", route = legacy }
    end
    if legacy.completed then
        return { targetId = "CLOAK", status = "completed", acquired = true, stageLabel = "传说披风任务线", progressText = "已完成 ✓", nextAction = "—", route = legacy }
    end
    local current = legacy.current
    if not current then
        return { targetId = "CLOAK", status = "not_started", acquired = false, stageLabel = "尚无可确定的下一任务", progressText = "检查前置、声望或阶段", nextAction = "完成前置条件后重新登录同步。", route = legacy }
    end
    local definition = current.definition or Addon.Data.byID[current.definitionId] or {}
    local label = definition.chapter and definition.chapter > 0 and ("第 " .. definition.chapter .. " 章 · ") or ""
    return {
        targetId = "CLOAK",
        status = current.status == "available" and "available" or (current.status == "unavailable" and "unavailable" or "in_progress"),
        acquired = false,
        stageLabel = label .. ((current.log and current.log.title) or definition.name or "当前任务"),
        progressText = Objective(current, legacy.faction),
        nextAction = Addon.Data:GetTableAction(current),
        route = legacy,
        currentNodeIds = { current.definitionId },
    }
end

local function ThunderfurySnapshot(character, store)
    local target = Addon.Catalog:GetTarget("THUNDERFURY")
    if not CharacterCanUse(character, target) then
        return { targetId = target.id, status = "ineligible", acquired = false, stageLabel = "不适用", progressText = "该职业无法装备风剑", nextAction = "—", target = target }
    end
    local projected = store.testProjection and store.testProjection[target.id]
    if projected then
        return projected
    end
    local finalCount, finalSeen = Observe(store, target.finalItemId)
    if (finalCount or 0) > 0 or finalSeen then
        return { targetId = target.id, status = "completed", acquired = true, stageLabel = "已获得 ✓", progressText = "雷霆之怒", nextAction = "—", target = target }
    end
    local leftCount, leftSeen = Observe(store, 18563)
    local rightCount, rightSeen = Observe(store, 18564)
    local bindings = (leftSeen and 1 or 0) + (rightSeen and 1 or 0)
    if bindings < 2 then
        return {
            targetId = target.id, status = "obtainable", acquired = false,
            stageLabel = "逐风者禁锢之颅", progressText = string.format("关键掉落 %d/2 · 本周可刷", bindings),
            nextAction = "前往熔火之心击败加尔与迦顿男爵。", target = target,
            currentNodeIds = { "BINDING_LEFT", "BINDING_RIGHT" },
        }
    end
    local ingots, ingotsSeen = Observe(store, 18562)
    if not ingotsSeen or (ingots or 0) < 10 then
        return {
            targetId = target.id, status = "in_progress", acquired = false,
            stageLabel = "收集元素锭", progressText = string.format("元素锭 %d/10", ingots or 0),
            nextAction = "前往黑翼之巢收集元素锭，并准备任务材料。", target = target,
            currentNodeIds = { "ELEMENTIUM" },
        }
    end
    return {
        targetId = target.id, status = "available", acquired = false,
        stageLabel = "召唤逐风者桑德兰", progressText = "材料已齐", nextAction = "前往希利苏斯完成最终事件。", target = target,
        currentNodeIds = { "THUNDERAAN" },
    }
end

function Model:BuildSnapshot(character, store, phaseAvailability, valorProgress)
    local legacy = Addon.Data:BuildSnapshot(character, phaseAvailability, valorProgress)
    local targets = { CLOAK = CloakSnapshot(character, legacy), THUNDERFURY = ThunderfurySnapshot(character, store) }
    return {
        characterID = character.id,
        readable = legacy.readable,
        legacy = legacy,
        targets = targets,
        updatedAt = Addon:GetTimestamp(),
    }
end

function Model:SetTestProjection(store, targetID, nodeID)
    local target = Addon.Catalog:GetTarget(targetID)
    if not target then return false, "未知传说目标" end
    store.testProjection = store.testProjection or {}
    if nodeID == nil then store.testProjection[targetID] = nil; return true end
    if targetID ~= "THUNDERFURY" then return false, "当前仅支持风剑路线投影" end
    local states = {
        BINDING_LEFT = { status="obtainable", acquired=false, stageLabel="逐风者禁锢之颅", progressText="关键掉落 1/2 · 本周可刷", nextAction="继续前往熔火之心击败另一名首领。", currentNodeIds={"BINDING_RIGHT"}, target=target, testProjection=true },
        BINDINGS = { status="in_progress", acquired=false, stageLabel="收集元素锭", progressText="元素锭 0/10", nextAction="前往黑翼之巢收集元素锭。", currentNodeIds={"ELEMENTIUM"}, target=target, testProjection=true },
        ELEMENTIUM = { status="in_progress", acquired=false, stageLabel="收集元素锭", progressText="元素锭 4/10", nextAction="继续收集元素锭。", currentNodeIds={"ELEMENTIUM"}, target=target, testProjection=true },
        THUNDERAAN = { status="available", acquired=false, stageLabel="召唤逐风者桑德兰", progressText="材料已齐", nextAction="前往希利苏斯完成最终事件。", currentNodeIds={"THUNDERAAN"}, target=target, testProjection=true },
        COMPLETED = { status="completed", acquired=true, stageLabel="已获得 ✓", progressText="雷霆之怒", nextAction="—", target=target, testProjection=true },
    }
    local state = states[string.upper(nodeID or "")]
    if not state then return false, "可用节点：BINDING_LEFT、BINDINGS、ELEMENTIUM、THUNDERAAN、COMPLETED" end
    state.targetId = targetID
    store.testProjection[targetID] = state
    return true
end
