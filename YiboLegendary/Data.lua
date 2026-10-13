local Addon = _G.YiboLegendary
local Data = {}
Addon.Data = Data

Data.BLACK_PRINCE_FACTION_ID = 1359
Data.VALOR_CURRENCY_ID = 396
Data.VALOR_QUEST_ID = 32476
Data.VALOR_QUEST_TITLE = "勇气的试炼"
Data.VALOR_TARGET = 1600
Data.REPUTATION_RANKS = { FRIENDLY = 5, HONORED = 6, REVERED = 7, EXALTED = 8 }
Data.REPUTATION_LABELS = { [4] = "中立", [5] = "友善", [6] = "尊敬", [7] = "崇敬", [8] = "崇拜" }

-- 截图确认的商店价格；价格适用于力量印记和智慧印记。
Data.VENDOR_PRICE_SNAPSHOTS = {
    ["至尊石碎块"] = { strengthMark = 30, wisdomMark = 30 },
    ["至尊石碎片"] = { strengthMark = 60, wisdomMark = 60 },
    ["至尊石聚簇"] = { strengthMark = 15, wisdomMark = 15 },
}

local actions = {
    ["ORANGE-PRE-01"] = "QUEST.ACTION.ORANGE-PRE-01",
    ["ORANGE-C1-01"] = "QUEST.ACTION.ORANGE-C1-01",
    ["ORANGE-C1-02"] = "QUEST.ACTION.ORANGE-C1-02",
    ["ORANGE-C1-03"] = "QUEST.ACTION.ORANGE-C1-03",
    ["ORANGE-C1-04"] = "QUEST.ACTION.ORANGE-C1-04",
    ["ORANGE-C1-05"] = "QUEST.ACTION.ORANGE-C1-05",
    ["ORANGE-C2-01"] = "QUEST.ACTION.ORANGE-C2-01",
    ["ORANGE-C2-02"] = "QUEST.ACTION.ORANGE-C2-02",
    ["ORANGE-C2-03"] = "QUEST.ACTION.ORANGE-C2-03",
    ["ORANGE-C2-04"] = "QUEST.ACTION.ORANGE-C2-04",
    ["ORANGE-C2-05A"] = "QUEST.ACTION.ORANGE-C2-05A",
    ["ORANGE-C2-05H"] = "QUEST.ACTION.ORANGE-C2-05H",
    ["ORANGE-C2-06"] = "QUEST.ACTION.ORANGE-C2-06",
    ["ORANGE-C2-07A"] = "QUEST.ACTION.ORANGE-C2-07A",
    ["ORANGE-C2-07H"] = "QUEST.ACTION.ORANGE-C2-07H",
    ["ORANGE-C3-01"] = "QUEST.ACTION.ORANGE-C3-01",
    ["ORANGE-C3-02"] = "QUEST.ACTION.ORANGE-C3-02",
    ["ORANGE-C3-03"] = "QUEST.ACTION.ORANGE-C3-03",
    ["ORANGE-C3-04"] = "QUEST.ACTION.ORANGE-C3-04",
    ["ORANGE-C3-05"] = "QUEST.ACTION.ORANGE-C3-05",
    ["ORANGE-C3-06"] = "QUEST.ACTION.ORANGE-C3-06",
    ["ORANGE-C3-07"] = "QUEST.ACTION.ORANGE-C3-07",
    ["ORANGE-C3-08"] = "QUEST.ACTION.ORANGE-C3-08",
    ["ORANGE-C3-09"] = "QUEST.ACTION.ORANGE-C3-09",
    ["ORANGE-C3-10"] = "QUEST.ACTION.ORANGE-C3-10",
    ["ORANGE-C4-01"] = "QUEST.ACTION.ORANGE-C4-01",
    ["ORANGE-C4-02"] = "QUEST.ACTION.ORANGE-C4-02",
    ["ORANGE-C4-03"] = "QUEST.ACTION.ORANGE-C4-03",
    ["ORANGE-C5-01"] = "QUEST.ACTION.ORANGE-C5-01",
    ["ORANGE-C5-02"] = "QUEST.ACTION.ORANGE-C5-02",
    ["ORANGE-C5-03"] = "QUEST.ACTION.ORANGE-C5-03",
    ["ORANGE-C5-04"] = "QUEST.ACTION.ORANGE-C5-04",
    ["ORANGE-C5-05"] = "QUEST.ACTION.ORANGE-C5-05",
}

local tableActions = {
    ["ORANGE-PRE-01"] = "QUEST.TABLE_ACTION.ORANGE-PRE-01",
    ["ORANGE-C1-01"] = "QUEST.TABLE_ACTION.ORANGE-C1-01",
    ["ORANGE-C1-02"] = "QUEST.TABLE_ACTION.ORANGE-C1-02",
    ["ORANGE-C1-03"] = "QUEST.TABLE_ACTION.ORANGE-C1-03",
    ["ORANGE-C1-04"] = "QUEST.TABLE_ACTION.ORANGE-C1-04",
    ["ORANGE-C1-05"] = "QUEST.TABLE_ACTION.ORANGE-C1-05",
    ["ORANGE-C2-01"] = "QUEST.TABLE_ACTION.ORANGE-C2-01",
    ["ORANGE-C2-02"] = "QUEST.TABLE_ACTION.ORANGE-C2-02",
    ["ORANGE-C2-03"] = "QUEST.TABLE_ACTION.ORANGE-C2-03",
    ["ORANGE-C2-04"] = "QUEST.TABLE_ACTION.ORANGE-C2-04",
    ["ORANGE-C2-05A"] = "QUEST.TABLE_ACTION.ORANGE-C2-05A",
    ["ORANGE-C2-05H"] = "QUEST.TABLE_ACTION.ORANGE-C2-05H",
    ["ORANGE-C2-06"] = "QUEST.TABLE_ACTION.ORANGE-C2-06",
    ["ORANGE-C2-07A"] = "QUEST.TABLE_ACTION.ORANGE-C2-07A",
    ["ORANGE-C2-07H"] = "QUEST.TABLE_ACTION.ORANGE-C2-07H",
    ["ORANGE-C3-01"] = "QUEST.TABLE_ACTION.ORANGE-C3-01",
    ["ORANGE-C3-02"] = "QUEST.TABLE_ACTION.ORANGE-C3-02",
    ["ORANGE-C3-03"] = "QUEST.TABLE_ACTION.ORANGE-C3-03",
    ["ORANGE-C3-04"] = "QUEST.TABLE_ACTION.ORANGE-C3-04",
    ["ORANGE-C3-05"] = "QUEST.TABLE_ACTION.ORANGE-C3-05",
    ["ORANGE-C3-06"] = "QUEST.TABLE_ACTION.ORANGE-C3-06",
    ["ORANGE-C3-07"] = "QUEST.TABLE_ACTION.ORANGE-C3-07",
    ["ORANGE-C3-08"] = "QUEST.TABLE_ACTION.ORANGE-C3-08",
    ["ORANGE-C3-09"] = "QUEST.TABLE_ACTION.ORANGE-C3-09",
    ["ORANGE-C3-10"] = "QUEST.TABLE_ACTION.ORANGE-C3-10",
    ["ORANGE-C4-01"] = "QUEST.TABLE_ACTION.ORANGE-C4-01",
    ["ORANGE-C4-02"] = "QUEST.TABLE_ACTION.ORANGE-C4-02",
    ["ORANGE-C4-03"] = "QUEST.TABLE_ACTION.ORANGE-C4-03",
    ["ORANGE-C5-01"] = "QUEST.TABLE_ACTION.ORANGE-C5-01",
    ["ORANGE-C5-02"] = "QUEST.TABLE_ACTION.ORANGE-C5-02",
    ["ORANGE-C5-03"] = "QUEST.TABLE_ACTION.ORANGE-C5-03",
    ["ORANGE-C5-04"] = "QUEST.TABLE_ACTION.ORANGE-C5-04",
    ["ORANGE-C5-05"] = "QUEST.TABLE_ACTION.ORANGE-C5-05",
}

local definitions = {
    { id="ORANGE-PRE-01", questId=31488, chapter=0, name="异乡的陌生人", objective="90 级后，在雾沙栈道的迷雾酒肆找到“黑王子”。", level=90, startLocation="雾沙栈道·迷雾酒肆" },
    { id="ORANGE-C1-01", questId=31454, chapter=1, name="创造传奇", objective="跟拉西奥喝一杯：0/1。", requires={"ORANGE-PRE-01"}, startLocation="迷雾栈道·迷雾酒肆" },
    { id="ORANGE-C1-02", questId=31473, chapter=1, name="敌人的力量", objective="力量印记：0/10；智慧印记：0/10。", requires={"ORANGE-C1-01"}, parallelGroup="ORANGE-C1-REQUIREMENTS" },
    { id="ORANGE-C1-03", questId=31468, chapter=1, name="黑王子的试炼", objective="黑王子阵营声望达到尊敬：0/1。", requires={"ORANGE-C1-01"}, reputation="HONORED", parallelGroup="ORANGE-C1-REQUIREMENTS" },
    { id="ORANGE-C1-04", questId=31481, chapter=1, name="恐惧本身", objective="击败惧之煞，获得恐惧奇美拉。", requires={"ORANGE-C1-02", "ORANGE-C1-03"}, requirementMode="all" },
    { id="ORANGE-C1-05", questId=31482, chapter=1, name="黑王子的气息", objective="前往迷雾栈道领取章节奖励。", requires={"ORANGE-C1-04"} },
    { id="ORANGE-C2-01", questId=31483, chapter=2, name="来袭……", objective="联系拉西奥，开启战争篇。", requires={"ORANGE-C1-05"}, phase=true },
    { id="ORANGE-C2-02", questId=32373, chapter=2, name="领袖的衡量标准", objective="在迷雾栈道与拉西奥对话。", requires={"ORANGE-C2-01"} },
    { id="ORANGE-C2-03", questId=32476, chapter=2, name="勇气的试炼", objective="累计获得勇气点数（MoP Classic：1,600）。", requires={"ORANGE-C2-02"}, valor=true },
    { id="ORANGE-C2-04", questId=32429, chapter=2, name="王子的追猎", objective="黑王子声望达到崇敬。", requires={"ORANGE-C2-03"}, reputation="REVERED" },
    { id="ORANGE-C2-05A", questId=32389, chapter=2, name="雄狮怒吼", objective="寇魔古寺、碎银矿脉各取得 1 场胜利。", requires={"ORANGE-C2-04"}, faction="Alliance" },
    { id="ORANGE-C2-05H", questId=32431, chapter=2, name="为了部落的荣耀", objective="寇魔古寺、碎银矿脉各取得 1 场胜利。", requires={"ORANGE-C2-04"}, faction="Horde" },
    { id="ORANGE-C2-06", questId=32388, chapter=2, name="朝令夕改", objective="消灭敌对阵营指挥官：0/1。", objectiveByFaction={ Alliance="消灭血柄督军：0/1。", Horde="消灭大元帅双辫：0/1。" }, requires={"ORANGE-C2-05A", "ORANGE-C2-05H"}, anyRequirement=true, pvp=true, groupRecommended=true, soloPossible=true, startLocation="迷雾栈道·拉西奥" },
    { id="ORANGE-C2-07A", questId=32390, chapter=2, name="驭兽者的召唤", objective="完成联盟结尾剧情并领取奖励。", requires={"ORANGE-C2-06"}, faction="Alliance" },
    { id="ORANGE-C2-07H", questId=32432, chapter=2, name="部落之魂", objective="完成部落结尾剧情并领取奖励。", requires={"ORANGE-C2-06"}, faction="Horde" },
    { id="ORANGE-C3-01", questId=32457, chapter=3, name="雷电之王", objective="在迷雾栈道酒馆联系拉西奥。", requires={"ORANGE-C2-07A", "ORANGE-C2-07H"}, anyRequirement=true, phase=true },
    { id="ORANGE-C3-02", questId=32590, chapter=3, name="楼上见", objective="前往酒馆二楼会见拉西奥。", requires={"ORANGE-C3-01"} },
    { id="ORANGE-C3-03", questId=32591, chapter=3, name="第一帝国的秘密", objective="帝国秘史 20 个；延极锭 40 个。", requires={"ORANGE-C3-02"} },
    { id="ORANGE-C3-04", questId=32592, chapter=3, name="我需要一位勇士", objective="黑王子声望达到崇拜。", requires={"ORANGE-C3-03"}, reputation="EXALTED" },
    { id="ORANGE-C3-05", questId=32593, chapter=3, name="雷霆熔炉", objective="完成雷神岛单人战役，解锁雷神之基。", requires={"ORANGE-C3-04"}, soloCampaign=true },
    { id="ORANGE-C3-06", questId=32594, chapter=3, name="暴风领主之魂", objective="解锁雷神之基 1 个；淬冰闪电长枪 1 把。", requires={"ORANGE-C3-05"}, soloPossible=true, itemCooldownSeconds=60 },
    { id="ORANGE-C3-07", questId=32595, chapter=3, name="天神之冠", objective="领取传说多彩宝石。", requires={"ORANGE-C3-06"} },
    { id="ORANGE-C3-08", questId=32596, chapter=3, name="泰坦的回响", objective="泰坦符文石 12 个。", requires={"ORANGE-C3-07"} },
    { id="ORANGE-C3-09", questId=32597, chapter=3, name="雷电之王的心脏", objective="击败雷神，取得雷神之心。", requires={"ORANGE-C3-08"} },
    { id="ORANGE-C3-10", questId=32598, chapter=3, name="清算", objective="回到拉西奥处完成本章收尾。", requires={"ORANGE-C3-09"} },
    { id="ORANGE-C4-01", questId=32805, chapter=4, name="天神的祝福", objective="完成任意一个适合职责的天神挑战。", requires={"ORANGE-C3-10"}, phase=true },
    { id="ORANGE-C4-02", questId=32861, chapter=4, name="美德披风", objective="选择一件 600 装等史诗披风。", requires={"ORANGE-C4-01"} },
    { id="ORANGE-C4-03", questId=32870, chapter=4, name="准备出击", objective="与拉西奥对话并等待最终阶段。", requires={"ORANGE-C4-02"} },
    { id="ORANGE-C5-01", questId=33088, chapter=5, name="永恒的发现", objective="前往永恒岛与拉西奥交谈。", requires={"ORANGE-C4-03"}, phase=true },
    { id="ORANGE-C5-02", questId=33098, chapter=5, name="永恒岛的秘密", objective="永恒铸币 5,000 枚。", requires={"ORANGE-C5-01"} },
    { id="ORANGE-C5-03", questId=33100, chapter=5, name="帝王之道", objective="玉珑 0/1；赤精 0/1；雪怒 0/1；砮皂 0/1。", requires={"ORANGE-C5-02"}, requirementMode="all", startLocation="永恒岛·拉西奥" },
    { id="ORANGE-C5-04", questId=33104, chapter=5, name="熊猫人传奇", objective="获得精华并将史诗披风转为传说披风。", requires={"ORANGE-C5-03"} },
    { id="ORANGE-C5-05", questId=33105, chapter=5, name="黑王子的审判", objective="击败加尔鲁什·地狱咆哮。", requires={"ORANGE-C5-04"} },
}

Data.definitions, Data.byID = definitions, {}
for _, definition in ipairs(definitions) do Data.byID[definition.id] = definition end

local function IsCompleted(questID)
    local query = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
    return type(query) == "function" and query(questID) == true
end

local function QuestLogIndex(questID)
    -- Some Classic builds expose the modern lookup but return no index for
    -- legacy quest records.  Try both APIs instead of letting the existence
    -- of the first one suppress the second.
    local index
    if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
        index = C_QuestLog.GetLogIndexForQuestID(questID)
    end
    if (not index or index <= 0) and type(GetQuestLogIndexByID) == "function" then
        index = GetQuestLogIndexByID(questID)
    end
    if index and index > 0 then return index end

    -- Last-resort compatibility path for clients where direct ID lookup is
    -- present but incomplete: scan the active quest log via its stable ID API.
    local total = type(GetNumQuestLogEntries) == "function" and GetNumQuestLogEntries() or 0
    for logIndex = 1, total do
        if C_QuestLog and type(C_QuestLog.GetQuestIDForLogIndex) == "function" then
            if C_QuestLog.GetQuestIDForLogIndex(logIndex) == questID then return logIndex end
        end
        if C_QuestLog and type(C_QuestLog.GetInfo) == "function" then
            local info = C_QuestLog.GetInfo(logIndex)
            if info and info.questID == questID then return logIndex end
        end
        -- Final fallback for the oldest tuple API.  It is only used while
        -- scanning, never to reject an index already resolved by an ID API.
        local title, _, _, isHeader, _, _, _, listedQuestID = GetQuestLogTitle(logIndex)
        if not isHeader and listedQuestID == questID then return logIndex end
        -- The Chinese MoP Classic client can expose neither ID lookup for
        -- this legacy quest, while still returning its title in the log.
        -- Use this narrow title fallback only for the tracked valor quest.
        if not isHeader and questID == Data.VALOR_QUEST_ID and title == Data.VALOR_QUEST_TITLE then return logIndex end
    end
    return nil
end

local function QuestLogEntry(questID)
    local index = QuestLogIndex(questID)
    if not index or index <= 0 then return nil end
    -- GetLogIndexForQuestID / GetQuestLogIndexByID has already resolved this
    -- exact quest.  Do not validate a positional return value from
    -- GetQuestLogTitle here: the legacy API's tuple differs by client build,
    -- and a mismatched position made an active quest look absent.
    local title = GetQuestLogTitle(index)
    local objectives = {}
    local count = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(index) or 0
    for i = 1, count do objectives[#objectives + 1] = GetQuestLogLeaderBoard(i, index) end
    return { title = title, objectives = objectives }
end

local function EntrySatisfies(entry)
    return entry and (entry.completed or entry.gateStatus == "satisfied_by_reputation")
end

function Data:GetReputation()
    if GetFactionInfoByID then
        local name, _, standingID, bottomValue, topValue, earnedValue = GetFactionInfoByID(self.BLACK_PRINCE_FACTION_ID)
        if standingID then
            return {
                name = name or "黑王子",
                rank = standingID,
                bottomValue = bottomValue,
                topValue = topValue,
                earnedValue = earnedValue,
            }
        end
    end
    return nil
end

function Data:GetValorQuantity()
    if C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
        local info = C_CurrencyInfo.GetCurrencyInfo(self.VALOR_CURRENCY_ID)
        if info and type(info.quantity) == "number" then return info.quantity end
    end
    if type(GetCurrencyInfo) == "function" then
        local _, quantity = GetCurrencyInfo(self.VALOR_CURRENCY_ID)
        if type(quantity) == "number" then return quantity end
    end
    return nil
end

function Data:TrackValorProgress(store, currencyID, eventQuantity, quantityChange, quantityGainSource)
    local tracker = store.valorProgress or {}
    store.valorProgress = tracker
    local quantity = self:GetValorQuantity()
    local active = QuestLogEntry(self.VALOR_QUEST_ID) ~= nil and not IsCompleted(self.VALOR_QUEST_ID)
    if active and not tracker.active then
        -- This is deliberately a fresh baseline, rather than the character's
        -- current currency balance.  Valor earned before accepting the quest
        -- (including before the addon was installed) is not recoverable and
        -- must not be counted toward this quest objective.
        local existingProgress = tonumber(tracker.progress)
        -- A Classic API compatibility upgrade can make a task become
        -- recognizable without the player ever leaving it.  Preserve its
        -- existing cumulative value in that case instead of treating the
        -- recognition change as a fresh acceptance.
        if existingProgress == nil then
            tracker.progress = 0
        elseif existingProgress == 0 and (tonumber(tracker.lastGain) or 0) > 0 then
            -- Repair the one-time reset made by earlier builds: this quest is
            -- non-repeatable, so a retained last gain with a zeroed progress
            -- can only be an interrupted saved cumulative value.
            tracker.progress = math.min(self.VALOR_TARGET, tonumber(tracker.lastGain))
            tracker.recoveredFromLastGain = true
        else
            tracker.progress = math.min(self.VALOR_TARGET, existingProgress)
        end
        tracker.startedAt = tracker.startedAt or Addon:GetTimestamp()
        tracker.lastQuantity = quantity
        tracker.active = true
        return tracker.progress
    end
    if not active then
        -- 任务已完成或不在任务日志时，不要清掉已记录的累计值；它仍然是
        -- 角色的历史快照，下一次重新接到任务时才会在上面的分支重置。
        tracker.active = false
        tracker.lastQuantity = quantity
        return nil
    end

    -- The reset happened in builds that had already marked the quest active,
    -- so repair that saved state once as well.  This is intentionally guarded
    -- and applies only to this non-repeatable cumulative quest.
    if (tonumber(tracker.progress) or 0) == 0 and (tonumber(tracker.lastGain) or 0) > 0 and not tracker.recoveredFromLastGain then
        tracker.progress = math.min(self.VALOR_TARGET, tonumber(tracker.lastGain))
        tracker.recoveredFromLastGain = true
    end

    local gained = 0
    if currencyID == self.VALOR_CURRENCY_ID then
        -- CURRENCY_DISPLAY_UPDATE: currencyID, balance, quantityChange,
        -- quantityGainSource, destroyReason.  The fourth argument is an
        -- enum source, not a point value; only quantityChange is the gain.
        local reportedGain = tonumber(quantityChange)
        if reportedGain and reportedGain > 0 then
            gained = reportedGain
        end
    end
    if gained == 0 and type(quantity) == "number" and type(tracker.lastQuantity) == "number" and quantity > tracker.lastQuantity then
        -- 兼容未提供事件获得量的客户端/API：用余额正差值兜底。
        gained = quantity - tracker.lastQuantity
    end
    if gained > 0 then
        tracker.progress = math.min(self.VALOR_TARGET, (tonumber(tracker.progress) or 0) + gained)
        tracker.lastGain = gained
        tracker.lastGainSource = quantityGainSource
        tracker.updatedAt = Addon:GetTimestamp()
    end
    tracker.active = true
    if currencyID == self.VALOR_CURRENCY_ID and type(eventQuantity) == "number" then
        tracker.lastQuantity = eventQuantity
    else
        tracker.lastQuantity = quantity
    end
    return math.min(self.VALOR_TARGET, tonumber(tracker.progress) or 0)
end

function Data:BuildSnapshot(character, phaseAvailability, valorProgress)
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    local reputation = self:GetReputation()
    local rank = reputation and reputation.rank or nil
    local completionQuery = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
    if type(completionQuery) ~= "function" then
        return { characterID = character.id, faction = faction, reputation = reputation, reputationQueried = true, reputationRank = rank, entries = {}, byID = {}, readable = false }
    end
    local entries, byID = {}, {}
    for _, definition in ipairs(self.definitions) do
        if not definition.faction or definition.faction == faction then
            local entry = { definitionId = definition.id, questId = definition.questId, status = "locked", definition = definition }
            entry.completed = IsCompleted(definition.questId)
            entry.log = QuestLogEntry(definition.questId)
            -- The quest log is authoritative for whether the 1,600-point
            -- counter should be displayed.  Supplying a zero here also makes
            -- the first accepted-task snapshot render as 0/1,600 even before
            -- a later currency event arrives.
            if definition.valor and entry.log then entry.valorProgress = tonumber(valorProgress) or 0 end
            if entry.completed then
                entry.status = "completed"
            elseif entry.log then
                entry.status = "in_progress"
            end
            entries[#entries + 1], byID[definition.id] = entry, entry
        end
    end
    for _, entry in ipairs(entries) do
        local definition = entry.definition
        if definition.reputation then
            local requiredRank = self.REPUTATION_RANKS[definition.reputation]
            entry.reputationMet = rank and rank >= requiredRank or false
            entry.gateStatus = entry.reputationMet and "satisfied_by_reputation" or "pending"
        end
        if entry.status == "locked" then
            local requirementsMet = true
            if definition.level and (character.level or 0) < definition.level then requirementsMet = false end
            if definition.requires then
                local matched = definition.anyRequirement and false or true
                for _, requiredID in ipairs(definition.requires) do
                    local required = byID[requiredID]
                    local done = EntrySatisfies(required)
                    if definition.anyRequirement then matched = matched or done else matched = matched and done end
                end
                requirementsMet = requirementsMet and matched
            end
            entry.prerequisitesMet = requirementsMet
            if definition.reputation then
                requirementsMet = requirementsMet and entry.gateStatus == "satisfied_by_reputation"
            end
            if definition.phase and phaseAvailability[definition.id] == false then
                entry.status = "unavailable"
            elseif requirementsMet then
                entry.status = "available"
            end
            if definition.phase and phaseAvailability[definition.id] == nil then
                entry.phaseStatus = "unknown"
            end
        end
    end
    local current
    for _, entry in ipairs(entries) do
        if entry.status == "in_progress" then current = entry break end
        if not current and entry.status == "available" then current = entry end
    end
    local reputationTarget
    for _, entry in ipairs(entries) do
        if entry.definition.reputation and not entry.completed and not entry.reputationMet and (entry.status == "in_progress" or entry.prerequisitesMet) then
            reputationTarget = entry
            break
        end
    end
    return {
        characterID = character.id,
        faction = faction,
        reputation = reputation,
        reputationQueried = true,
        reputationRank = rank,
        reputationTarget = reputationTarget,
        entries = entries,
        byID = byID,
        current = current,
        completed = byID["ORANGE-C5-05"] and byID["ORANGE-C5-05"].completed or false,
        readable = true,
    }
end

function Data:GetNextAction(entry)
    if not entry then return Addon:T("QUEST.ACTION_GENERIC.PREREQUISITES") end
    if entry.definition.reputation and entry.reputationMet then
        return Addon:T("QUEST.ACTION_GENERIC.REPUTATION_MET")
    end
    if entry.status == "in_progress" or entry.status == "available" then return Addon:T(actions[entry.definitionId]) or Addon:T("QUEST.ACTION_GENERIC.CURRENT") end
    if entry.status == "unavailable" then
        return Addon:T("QUEST.ACTION_GENERIC.PHASE")
    end
    return Addon:T("QUEST.ACTION_GENERIC.PREREQUISITES")
end

function Data:GetTableAction(entry)
    if not entry then return Addon:T("COMMON.EM_DASH") end
    if entry.definition.reputation and entry.reputationMet then
        return Addon:T("QUEST.ACTION_GENERIC.REPUTATION_MET")
    end
    if entry.definition.phase and entry.phaseStatus == "unknown" then
        return Addon:T("QUEST.ACTION_GENERIC.CONFIRM_PHASE")
    end
    if entry.status == "in_progress" or entry.status == "available" then
        return Addon:T(tableActions[entry.definitionId]) or self:GetNextAction(entry)
    end
    return self:GetNextAction(entry)
end
