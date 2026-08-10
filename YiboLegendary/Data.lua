local Addon = _G.YiboLegendary
local Data = {}
Addon.Data = Data

Data.BLACK_PRINCE_FACTION_ID = 1359
Data.VALOR_CURRENCY_ID = 396
Data.VALOR_TARGET = 1600
Data.REPUTATION_RANKS = { FRIENDLY = 5, HONORED = 6, REVERED = 7, EXALTED = 8 }
Data.REPUTATION_LABELS = { [4] = "中立", [5] = "友善", [6] = "尊敬", [7] = "崇敬", [8] = "崇拜" }

local actions = {
    ["ORANGE-PRE-01"] = "达到 90 级后，前往迷雾栈道寻找拉西奥。",
    ["ORANGE-C1-01"] = "前往迷雾栈道，与拉西奥完成对话。",
    ["ORANGE-C1-02"] = "通过天神尾王或每个 10 个至尊石碎块获得印记。",
    ["ORANGE-C1-03"] = "完成黑王子阵营日常或击杀相应敌人，将声望提升至尊敬。",
    ["ORANGE-C1-04"] = "进入永春台，击败惧之煞并取得任务物品。",
    ["ORANGE-C1-05"] = "返回迷雾栈道，向拉西奥领取第一章奖励。",
    ["ORANGE-C2-01"] = "前往迷雾栈道，与拉西奥开启战争篇。",
    ["ORANGE-C2-02"] = "前往迷雾栈道，与拉西奥对话。",
    ["ORANGE-C2-03"] = "通过地下城、场景战役或日常活动累计 1,600 点勇气。",
    ["ORANGE-C2-04"] = "完成黑王子阵营日常或击杀相应敌人，将声望提升至崇敬。",
    ["ORANGE-C2-05A"] = "排队寇魔古寺和碎银矿脉，分别取得一场胜利。",
    ["ORANGE-C2-05H"] = "排队寇魔古寺和碎银矿脉，分别取得一场胜利。",
    ["ORANGE-C2-06"] = "前往卡桑琅丛林，击败敌对阵营指挥官。",
    ["ORANGE-C2-07A"] = "完成联盟结尾剧情，并向拉西奥领取奖励。",
    ["ORANGE-C2-07H"] = "完成部落结尾剧情，并向拉西奥领取奖励。",
    ["ORANGE-C3-01"] = "前往迷雾栈道酒馆，与拉西奥联系。",
    ["ORANGE-C3-02"] = "前往酒馆二楼，与拉西奥会面。",
    ["ORANGE-C3-03"] = "通过天神尾王或每个 10 个至尊石碎块获得帝国秘史，并准备延极锭。",
    ["ORANGE-C3-04"] = "完成黑王子阵营日常或击杀相应敌人，将声望提升至崇拜。",
    ["ORANGE-C3-05"] = "前往雷神岛，解锁并完成雷霆熔炉事件。",
    ["ORANGE-C3-06"] = "前往雷神岛挑战纳拉克，用闪电长矛命中后存活。",
    ["ORANGE-C3-07"] = "返回拉西奥处，领取传说多彩宝石。",
    ["ORANGE-C3-08"] = "继续挑战雷电王座，收集 12 个泰坦符文石。",
    ["ORANGE-C3-09"] = "进入雷电王座击败雷神，取得雷神之心。",
    ["ORANGE-C3-10"] = "返回拉西奥处，完成雷电王座篇收尾。",
    ["ORANGE-C4-01"] = "前往昆莱山白虎寺，完成适合职责的天神挑战。",
    ["ORANGE-C4-02"] = "从拉西奥提供的奖励中选择一件 600 装等史诗披风。",
    ["ORANGE-C4-03"] = "与拉西奥对话，等待最终阶段开放。",
    ["ORANGE-C5-01"] = "前往永恒岛，与拉西奥交谈。",
    ["ORANGE-C5-02"] = "在永恒岛收集 5,000 枚永恒铸币。",
    ["ORANGE-C5-03"] = "分别挑战四天神，完成天神试炼。",
    ["ORANGE-C5-04"] = "完成最终仪式，将史诗披风升级为传说披风。",
    ["ORANGE-C5-05"] = "进入决战奥格瑞玛，击败加尔鲁什·地狱咆哮。",
}

local tableActions = {
    ["ORANGE-PRE-01"] = "迷雾栈道找拉西奥",
    ["ORANGE-C1-01"] = "迷雾栈道找拉西奥",
    ["ORANGE-C1-02"] = "天神尾王或 10 碎块换印记",
    ["ORANGE-C1-03"] = "完成黑王子日常提升声望",
    ["ORANGE-C1-04"] = "进入永春台击败惧之煞",
    ["ORANGE-C1-05"] = "迷雾栈道找拉西奥",
    ["ORANGE-C2-01"] = "迷雾栈道找拉西奥",
    ["ORANGE-C2-02"] = "迷雾栈道找拉西奥",
    ["ORANGE-C2-03"] = "累计 1,600 点勇气",
    ["ORANGE-C2-04"] = "完成黑王子日常提升声望",
    ["ORANGE-C2-05A"] = "排队两张战场并获胜",
    ["ORANGE-C2-05H"] = "排队两张战场并获胜",
    ["ORANGE-C2-06"] = "卡桑琅丛林击杀指挥官",
    ["ORANGE-C2-07A"] = "完成联盟结尾剧情",
    ["ORANGE-C2-07H"] = "完成部落结尾剧情",
    ["ORANGE-C3-01"] = "迷雾栈道酒馆找拉西奥",
    ["ORANGE-C3-02"] = "前往酒馆二楼",
    ["ORANGE-C3-03"] = "天神尾王或 10 碎块换秘史",
    ["ORANGE-C3-04"] = "完成黑王子日常提升声望",
    ["ORANGE-C3-05"] = "雷神岛完成雷霆熔炉",
    ["ORANGE-C3-06"] = "雷神岛挑战纳拉克",
    ["ORANGE-C3-07"] = "返回拉西奥处",
    ["ORANGE-C3-08"] = "挑战雷电王座收集符文石",
    ["ORANGE-C3-09"] = "雷电王座击败雷神",
    ["ORANGE-C3-10"] = "返回拉西奥处",
    ["ORANGE-C4-01"] = "白虎寺完成天神挑战",
    ["ORANGE-C4-02"] = "选择 600 装等史诗披风",
    ["ORANGE-C4-03"] = "与拉西奥对话",
    ["ORANGE-C5-01"] = "永恒岛找拉西奥",
    ["ORANGE-C5-02"] = "永恒岛收集永恒铸币",
    ["ORANGE-C5-03"] = "完成四天神试炼",
    ["ORANGE-C5-04"] = "完成披风升级仪式",
    ["ORANGE-C5-05"] = "决战奥格瑞玛击败加尔鲁什",
}

local definitions = {
    { id="ORANGE-PRE-01", questId=31488, chapter=0, name="陌生之地的陌生人", objective="达到 90 级后，在迷雾栈道接触拉西奥。", level=90 },
    { id="ORANGE-C1-01", questId=31454, chapter=1, name="传说的开端", objective="与拉西奥完成剧情对话。", requires={"ORANGE-PRE-01"} },
    { id="ORANGE-C1-02", questId=31473, chapter=1, name="敌人的力量", objective="力量印记 10 个；智慧印记 10 个。", requires={"ORANGE-C1-01"} },
    { id="ORANGE-C1-03", questId=31468, chapter=1, name="黑王子的试炼", objective="黑王子声望达到尊敬。", requires={"ORANGE-C1-01"}, reputation="HONORED" },
    { id="ORANGE-C1-04", questId=31481, chapter=1, name="恐惧本身", objective="击败惧之煞，获得恐惧奇美拉。", requires={"ORANGE-C1-02", "ORANGE-C1-03"} },
    { id="ORANGE-C1-05", questId=31482, chapter=1, name="黑王子的气息", objective="前往迷雾栈道领取章节奖励。", requires={"ORANGE-C1-04"} },
    { id="ORANGE-C2-01", questId=31483, chapter=2, name="来袭……", objective="联系拉西奥，开启战争篇。", requires={"ORANGE-C1-05"}, phase=true },
    { id="ORANGE-C2-02", questId=32373, chapter=2, name="领袖的衡量标准", objective="在迷雾栈道与拉西奥对话。", requires={"ORANGE-C2-01"} },
    { id="ORANGE-C2-03", questId=32476, chapter=2, name="勇气的试炼", objective="累计获得勇气点数（MoP Classic：1,600）。", requires={"ORANGE-C2-02"}, valor=true },
    { id="ORANGE-C2-04", questId=32429, chapter=2, name="王子的追猎", objective="黑王子声望达到崇敬。", requires={"ORANGE-C2-03"}, reputation="REVERED" },
    { id="ORANGE-C2-05A", questId=32389, chapter=2, name="雄狮怒吼", objective="寇魔古寺、碎银矿脉各取得 1 场胜利。", requires={"ORANGE-C2-04"}, faction="Alliance" },
    { id="ORANGE-C2-05H", questId=32431, chapter=2, name="为了部落的荣耀", objective="寇魔古寺、碎银矿脉各取得 1 场胜利。", requires={"ORANGE-C2-04"}, faction="Horde" },
    { id="ORANGE-C2-06", questId=32388, chapter=2, name="指挥官易位", objective="击杀卡桑琅丛林敌对阵营指挥官。", requires={"ORANGE-C2-05A", "ORANGE-C2-05H"}, anyRequirement=true },
    { id="ORANGE-C2-07A", questId=32390, chapter=2, name="驭兽者的召唤", objective="完成联盟结尾剧情并领取奖励。", requires={"ORANGE-C2-06"}, faction="Alliance" },
    { id="ORANGE-C2-07H", questId=32432, chapter=2, name="部落之魂", objective="完成部落结尾剧情并领取奖励。", requires={"ORANGE-C2-06"}, faction="Horde" },
    { id="ORANGE-C3-01", questId=32457, chapter=3, name="雷电之王", objective="在迷雾栈道酒馆联系拉西奥。", requires={"ORANGE-C2-07A", "ORANGE-C2-07H"}, anyRequirement=true, phase=true },
    { id="ORANGE-C3-02", questId=32590, chapter=3, name="楼上见", objective="前往酒馆二楼会见拉西奥。", requires={"ORANGE-C3-01"} },
    { id="ORANGE-C3-03", questId=32591, chapter=3, name="第一帝国的秘密", objective="帝国秘史 20 个；延极锭 40 个。", requires={"ORANGE-C3-02"} },
    { id="ORANGE-C3-04", questId=32592, chapter=3, name="我需要一位勇士", objective="黑王子声望达到崇拜。", requires={"ORANGE-C3-03"}, reputation="EXALTED" },
    { id="ORANGE-C3-05", questId=32593, chapter=3, name="雷霆熔炉", objective="解锁雷霆熔炉并完成拉西奥的任务。", requires={"ORANGE-C3-04"} },
    { id="ORANGE-C3-06", questId=32594, chapter=3, name="风暴之王的灵魂", objective="用闪电长矛刺中纳拉克并存活。", requires={"ORANGE-C3-05"} },
    { id="ORANGE-C3-07", questId=32595, chapter=3, name="天神之冠", objective="领取传说多彩宝石。", requires={"ORANGE-C3-06"} },
    { id="ORANGE-C3-08", questId=32596, chapter=3, name="泰坦的回响", objective="泰坦符文石 12 个。", requires={"ORANGE-C3-07"} },
    { id="ORANGE-C3-09", questId=32597, chapter=3, name="雷电之王的心脏", objective="击败雷神，取得雷神之心。", requires={"ORANGE-C3-08"} },
    { id="ORANGE-C3-10", questId=32598, chapter=3, name="清算", objective="回到拉西奥处完成本章收尾。", requires={"ORANGE-C3-09"} },
    { id="ORANGE-C4-01", questId=32805, chapter=4, name="天神的祝福", objective="完成任意一个适合职责的天神挑战。", requires={"ORANGE-C3-10"}, phase=true },
    { id="ORANGE-C4-02", questId=32861, chapter=4, name="美德披风", objective="选择一件 600 装等史诗披风。", requires={"ORANGE-C4-01"} },
    { id="ORANGE-C4-03", questId=32870, chapter=4, name="准备出击", objective="与拉西奥对话并等待最终阶段。", requires={"ORANGE-C4-02"} },
    { id="ORANGE-C5-01", questId=33088, chapter=5, name="永恒的发现", objective="前往永恒岛与拉西奥交谈。", requires={"ORANGE-C4-03"}, phase=true },
    { id="ORANGE-C5-02", questId=33098, chapter=5, name="永恒岛的秘密", objective="永恒铸币 5,000 枚。", requires={"ORANGE-C5-01"} },
    { id="ORANGE-C5-03", questId=33100, chapter=5, name="皇帝之道", objective="分别击败四天神。", requires={"ORANGE-C5-02"} },
    { id="ORANGE-C5-04", questId=33104, chapter=5, name="熊猫人传奇", objective="获得精华并将史诗披风转为传说披风。", requires={"ORANGE-C5-03"} },
    { id="ORANGE-C5-05", questId=33105, chapter=5, name="黑王子的审判", objective="击败加尔鲁什·地狱咆哮。", requires={"ORANGE-C5-04"} },
}

Data.definitions, Data.byID = definitions, {}
for _, definition in ipairs(definitions) do Data.byID[definition.id] = definition end

local function IsCompleted(questID)
    local query = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
    return type(query) == "function" and query(questID) == true
end

local function QuestLogEntry(questID)
    local query = (C_QuestLog and C_QuestLog.GetLogIndexForQuestID) or GetQuestLogIndexByID
    local index = type(query) == "function" and query(questID)
    if not index or index <= 0 then return nil end
    local title, _, _, _, _, _, _, questId = GetQuestLogTitle(index)
    if questId ~= questID then return nil end
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

function Data:TrackValorProgress(store)
    local tracker = store.valorProgress or {}
    store.valorProgress = tracker
    local quantity = self:GetValorQuantity()
    local active = QuestLogEntry(32476) ~= nil and not IsCompleted(32476)
    if tracker.active and type(quantity) == "number" and type(tracker.lastQuantity) == "number" and quantity > tracker.lastQuantity then
        tracker.progress = math.min(self.VALOR_TARGET, (tonumber(tracker.progress) or 0) + quantity - tracker.lastQuantity)
    end
    if active and not tracker.active then
        tracker.progress = 0
        tracker.startedAt = Addon:GetTimestamp()
    end
    tracker.active = active
    tracker.lastQuantity = quantity
    return active and math.min(self.VALOR_TARGET, tonumber(tracker.progress) or 0) or nil
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
            if definition.valor then entry.valorProgress = valorProgress end
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
                local requiredRank = self.REPUTATION_RANKS[definition.reputation]
                entry.reputationMet = rank and rank >= requiredRank or false
                entry.gateStatus = entry.reputationMet and "satisfied_by_reputation" or "pending"
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
        if entry.definition.reputation and not entry.completed and (entry.status == "in_progress" or entry.prerequisitesMet) then
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
    if not entry then return "继续完成任务线前置条件。" end
    if entry.status == "in_progress" or entry.status == "available" then return actions[entry.definitionId] or "继续完成当前任务目标。" end
    if entry.status == "unavailable" then
        return "等待服务器开放对应阶段。"
    end
    return "完成前置任务或声望门槛后再继续。"
end

function Data:GetTableAction(entry)
    if not entry then return "—" end
    if entry.definition.phase and entry.phaseStatus == "unknown" then
        return "确认服务器阶段后继续"
    end
    if entry.status == "in_progress" or entry.status == "available" then
        return tableActions[entry.definitionId] or self:GetNextAction(entry)
    end
    return self:GetNextAction(entry)
end
