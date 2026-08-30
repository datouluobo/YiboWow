local Addon = _G.YiboTodo
local Probe = {}
Addon.Probe = Probe

local FARM_API_PATHS = {
    "C_Garrison.GetGarrisonInfo", "C_Garrison.GetPlots", "GetGarrisonInfo", "GetNumGarrisonPlots",
    "GetNumFarmPlots", "GetFarmPlotInfo", "FarmFrame", "FarmFrame_GetPlotInfo",
}

local FARM_SAFE_CALLS = {
    "C_Garrison.GetGarrisonInfo", "C_Garrison.GetPlots", "GetGarrisonInfo", "GetNumGarrisonPlots",
}

local function CaptureNamedGlobals()
    local matches = {}
    for name, value in pairs(_G) do
        local lowered = string.lower(tostring(name))
        if string.find(lowered, "farm", 1, true) or string.find(lowered, "halfhill", 1, true) or string.find(lowered, "sunsong", 1, true) then
            matches[#matches + 1] = tostring(name) .. ":" .. type(value)
        end
    end
    table.sort(matches)
    while #matches > 80 do table.remove(matches) end
    return matches
end

local function AddOnIsLoaded(index)
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then return C_AddOns.IsAddOnLoaded(index) end
    if type(_G.IsAddOnLoaded) == "function" then return _G.IsAddOnLoaded(index) end
    return false
end

local function CaptureFarmModules()
    local result = { garrisonUI = false, matches = {} }
    result.garrisonUI = AddOnIsLoaded("Blizzard_GarrisonUI")
    local getNum = C_AddOns and C_AddOns.GetNumAddOns or _G.GetNumAddOns
    local getInfo = C_AddOns and C_AddOns.GetAddOnInfo or _G.GetAddOnInfo
    if type(getNum) ~= "function" or type(getInfo) ~= "function" then return result end
    local count = getNum()
    for index = 1, tonumber(count) or 0 do
        local name, title = getInfo(index)
        local text = string.lower(tostring(name) .. " " .. tostring(title))
        if AddOnIsLoaded(index) and (string.find(text, "farm", 1, true) or string.find(text, "garrison", 1, true) or string.find(text, "tiller", 1, true) or string.find(text, "halfhill", 1, true) or string.find(text, "pandaria", 1, true)) then
            result.matches[#result.matches + 1] = tostring(name) .. " / " .. tostring(title)
        end
    end
    table.sort(result.matches)
    return result
end

local function CaptureUnit(unit)
    if type(UnitExists) ~= "function" or not UnitExists(unit) then return { exists = false } end
    local result = {
        exists = true,
        name = UnitName and UnitName(unit) or nil,
        guid = UnitGUID and UnitGUID(unit) or nil,
    }
    if result.guid then result.creatureID = string.match(result.guid, "^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)") end
    if type(UnitPosition) == "function" then
        local x, y, z, instanceID = UnitPosition(unit)
        result.position = { x = x, y = y, z = z, instanceID = instanceID }
    end
    return result
end

local function ResolvePath(path)
    local value = _G
    for segment in string.gmatch(path, "[^.]+") do
        if type(value) ~= "table" then return nil end
        value = value[segment]
    end
    return value
end

local function ValueText(value, depth)
    depth = depth or 0
    local kind = type(value)
    if kind == "nil" then return "nil" end
    if kind == "string" or kind == "number" or kind == "boolean" then return tostring(value) end
    if kind == "table" then
        if depth >= 2 then return "<table>" end
        local parts, count = {}, 0
        for key, entry in pairs(value) do
            count = count + 1
            if count > 12 then parts[#parts + 1] = "…"; break end
            parts[#parts + 1] = tostring(key) .. "=" .. ValueText(entry, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return "<" .. kind .. ">"
end

local function SafeCall(path)
    local fn = ResolvePath(path)
    if type(fn) ~= "function" then return { available = false } end
    local result = { available = true }
    local packed = { pcall(fn) }
    result.ok = table.remove(packed, 1)
    if result.ok then
        result.returns = {}
        for index, value in ipairs(packed) do result.returns[index] = ValueText(value) end
    else
        result.error = tostring(packed[1])
    end
    return result
end

local function SafeCallWith(path, ...)
    local fn = ResolvePath(path)
    if type(fn) ~= "function" then return { available = false } end
    local result = { available = true }
    local packed = { pcall(fn, ...) }
    result.ok = table.remove(packed, 1)
    if result.ok then
        result.returns = {}
        for index, value in ipairs(packed) do result.returns[index] = ValueText(value) end
        result.values = packed
    else
        result.error = tostring(packed[1])
    end
    return result
end

local function ExtractQuestIDs(value)
    local ids, seen = {}, {}
    if type(value) ~= "table" then return ids end
    for key, entry in pairs(value) do
        local candidate
        if type(entry) == "number" then candidate = entry
        elseif type(entry) == "table" then candidate = entry.questID or entry.questId or entry.id end
        if not candidate and type(key) == "number" and type(entry) == "boolean" then candidate = key end
        if candidate and not seen[candidate] then seen[candidate] = true; ids[#ids + 1] = tostring(candidate) end
    end
    table.sort(ids)
    return ids
end

local function CaptureMapTaskSignals()
    local result = { capabilities = {}, mapID = nil, taskQuestIDs = {}, mapTasks = { available = false }, scenario = { available = false } }
    local paths = { "C_Map.GetBestMapForUnit", "C_TaskQuest.GetQuestsForPlayerByMapID", "C_QuestLog.GetQuestsOnMap", "C_Scenario.GetStepInfo", "C_Scenario.GetCriteriaInfo" }
    for _, path in ipairs(paths) do result.capabilities[path] = type(ResolvePath(path)) end

    local map = SafeCallWith("C_Map.GetBestMapForUnit", "player")
    if map.ok then result.mapID = tonumber(map.values and map.values[1]) end
    if result.mapID then
        result.taskQuest = SafeCallWith("C_TaskQuest.GetQuestsForPlayerByMapID", result.mapID)
        result.mapTasks = SafeCallWith("C_QuestLog.GetQuestsOnMap", result.mapID)
        local taskValues = result.taskQuest and result.taskQuest.values
        local mapValues = result.mapTasks and result.mapTasks.values
        result.taskQuestIDs = ExtractQuestIDs(taskValues and taskValues[1])
        result.mapQuestIDs = ExtractQuestIDs(mapValues and mapValues[1])
    end
    result.scenario = SafeCall("C_Scenario.GetStepInfo")
    return result
end

local function CurrentMapID()
    local map = SafeCallWith("C_Map.GetBestMapForUnit", "player")
    if map.ok then return tonumber(map.values and map.values[1]) end
    return nil
end

local function CaptureSpellInfo(spellID)
    return SafeCallWith("GetSpellInfo", spellID)
end

local function PrintFarmSpellCapture(capture)
    if not capture then Addon:Print("农场法术采集：未建立会话。"); return end
    local grouped = {}
    for _, event in ipairs(capture.events or {}) do
        local group = grouped[event.spellID] or { count = 0, casts = {} }
        grouped[event.spellID] = group
        group.count = group.count + 1
        group.casts[#group.casts + 1] = event.castGUID
    end
    local spellIDs = {}
    for spellID in pairs(grouped) do spellIDs[#spellIDs + 1] = spellID end
    table.sort(spellIDs)
    Addon:Print(string.format("农场法术采集：开始=%s，地图=%s，成功施法=%d，唯一 ID=%d。", tostring(capture.startedAt), tostring(capture.mapID), #(capture.events or {}), #spellIDs))
    for _, spellID in ipairs(spellIDs) do
        local group, info = grouped[spellID], CaptureSpellInfo(spellID)
        local raw = not info.available and "不可用" or (not info.ok and ("调用失败：" .. tostring(info.error)) or ("返回 " .. table.concat(info.returns or {}, " | ")))
        Addon:Print(string.format("农场候选 spell=%d；次数=%d；GetSpellInfo=%s。", spellID, group.count, raw))
    end
end

local function CaptureQuestLog()
    local result = { api = "unavailable", entries = {} }
    if type(GetNumQuestLogEntries) ~= "function" or type(GetQuestLogTitle) ~= "function" then return result end
    local entryCount = GetNumQuestLogEntries()
    local count = tonumber(entryCount) or 0
    result.api, result.count = "GetQuestLogTitle", count
    for index = 1, count do
        local title, level, tag, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(index)
        if not isHeader then
            result.entries[#result.entries + 1] = {
                index = index, id = questID, title = title, level = level, tag = tag,
                complete = isComplete, frequency = frequency, collapsed = isCollapsed,
            }
        end
    end
    return result
end

local function CaptureQuestCompletion(questIDs)
    local result = {}
    for _, questID in ipairs(questIDs or {}) do
        local row = { id = questID }
        if type(IsQuestFlaggedCompleted) == "function" then
            local ok, value = pcall(IsQuestFlaggedCompleted, questID)
            row.isQuestFlaggedCompleted = ok and value or ("error: " .. tostring(value))
        else
            row.isQuestFlaggedCompleted = "unavailable"
        end
        if C_QuestLog and type(C_QuestLog.IsQuestFlaggedCompleted) == "function" then
            local ok, value = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
            row.cQuestLogIsQuestFlaggedCompleted = ok and value or ("error: " .. tostring(value))
        end
        result[#result + 1] = row
    end
    return result
end

local function CaptureCompletedQuestSet()
    local result = { available = type(GetQuestsCompleted) == "function", ids = {} }
    if not result.available then return result end
    local completed = {}
    local ok, err = pcall(GetQuestsCompleted, completed)
    result.ok, result.error = ok, ok and nil or tostring(err)
    if not ok then return result end
    for questID, isCompleted in pairs(completed) do
        if isCompleted then result.ids[tonumber(questID) or questID] = true end
    end
    return result
end

local function CompareQuestSets(before, after)
    local added, removed = {}, {}
    for questID in pairs(after or {}) do if not (before and before[questID]) then added[#added + 1] = tostring(questID) end end
    for questID in pairs(before or {}) do if not (after and after[questID]) then removed[#removed + 1] = tostring(questID) end end
    table.sort(added); table.sort(removed)
    return added, removed
end

local function DescribeRawCall(value)
    if not value.available then return "不可用" end
    if not value.ok then return "调用失败：" .. tostring(value.error) end
    return "返回 " .. table.concat(value.returns or {}, " | ")
end

local function PrintList(prefix, values, perLine)
    if #values == 0 then Addon:Print(prefix .. "无"); return end
    perLine = perLine or 4
    for first = 1, #values, perLine do
        local last, chunk = math.min(first + perLine - 1, #values), {}
        for index = first, last do chunk[#chunk + 1] = values[index] end
        Addon:Print(prefix .. table.concat(chunk, "，"))
    end
end

local function PrintEventTrace(events)
    local first = math.max(1, #events - 11)
    if #events == 0 then Addon:Print("每日活动事件：无"); return end
    for index = first, #events do
        local event, args = events[index], {}
        for argIndex, value in ipairs(event.args or {}) do args[#args + 1] = ValueText(value) end
        Addon:Print(string.format("每日活动事件：%s；参数=%s。", tostring(event.event), table.concat(args, " | ")))
    end
end

function Probe:CaptureEvent(event, ...)
    local diagnostics = Addon.db and Addon.db.diagnostics
    if not diagnostics or not diagnostics.dailyProbeEnabled then return end
    local capture = self.farmSpellCapture
    if capture and event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        local mapID = CurrentMapID()
        if unit == "player" and capture.mapID and mapID == capture.mapID and tonumber(spellID) then
            local key = tostring(castGUID or "")
            capture.castGUIDs = capture.castGUIDs or {}
            if key == "" or not capture.castGUIDs[key] then
                if key ~= "" then capture.castGUIDs[key] = true end
                capture.events[#capture.events + 1] = { at = Addon:Now(), spellID = tonumber(spellID), castGUID = castGUID, mapID = mapID }
            end
        end
    end
    diagnostics.dailyEventTrace = diagnostics.dailyEventTrace or {}
    local trace = diagnostics.dailyEventTrace
    trace[#trace + 1] = { at = Addon:Now(), event = event, args = { ... } }
    while #trace > 80 do table.remove(trace, 1) end
end

function Probe:Run(verbose, questIDs, resetQuestBaseline, farmCaptureMode)
    local validation = Addon:ValidateCatalog()
    local gameHour, gameMinute
    if GetGameTime then gameHour, gameMinute = GetGameTime() end
    local interface = 0
    if GetBuildInfo then
        local _, _, _, tocVersion = GetBuildInfo()
        interface = tonumber(tocVersion) or 0
    end
    local detail = {
        at = Addon:Now(), interface = interface,
        locale = GetLocale and GetLocale() or "unknown", hasCTradeSkillUI = C_TradeSkillUI ~= nil,
        activeRecipes = #validation.activeRecipes, errors = validation.errors, warnings = validation.warnings,
        serverClock = { hour = gameHour, minute = gameMinute, resetHour = 7 },
        farm = { capabilities = {}, rawCalls = {} }, questLog = CaptureQuestLog(),
        questCompletion = CaptureQuestCompletion(questIDs), completedQuestSet = CaptureCompletedQuestSet(),
        mapTaskSignals = CaptureMapTaskSignals(),
        namedFarmGlobals = CaptureNamedGlobals(),
        farmModules = CaptureFarmModules(),
        mouseover = CaptureUnit("mouseover"), target = CaptureUnit("target"),
    }
    if farmCaptureMode == "finish" then detail.farmSpellCapture = self.farmSpellCapture end
    for _, path in ipairs(FARM_API_PATHS) do detail.farm.capabilities[path] = type(ResolvePath(path)) end
    for _, path in ipairs(FARM_SAFE_CALLS) do detail.farm.rawCalls[path] = SafeCall(path) end
    Addon.db.diagnostics.dailyProbeEnabled = true
    local completed = detail.completedQuestSet
    if completed.ok then
        if resetQuestBaseline or not self.completedQuestBaseline then
            self.completedQuestBaseline = completed.ids
            detail.completedQuestDelta = { baseline = true, added = {}, removed = {} }
        else
            local added, removed = CompareQuestSets(self.completedQuestBaseline, completed.ids)
            detail.completedQuestDelta = { baseline = false, added = added, removed = removed }
            self.completedQuestBaseline = completed.ids
        end
    end
    detail.eventTrace = Addon.db.diagnostics.dailyEventTrace or {}
    Addon.db.diagnostics.lastProbe = detail
    Addon:Print(string.format("探针：Interface %s，正式条目 %d，任务日志 %d 条，目录错误 %d，候选 %d。", tostring(detail.interface), detail.activeRecipes, #detail.questLog.entries, #detail.errors, #detail.warnings))
    if verbose then
        for _, code in ipairs(detail.errors) do Addon:Print("错误：" .. code) end
        for _, code in ipairs(detail.warnings) do Addon:Print("候选：" .. code) end
        Addon:Print(string.format("服务器时钟：%s:%s；每日边界：07:00。", tostring(gameHour), tostring(gameMinute)))
        for _, path in ipairs(FARM_API_PATHS) do
            Addon:Print("农场 API " .. path .. "：" .. tostring(detail.farm.capabilities[path]))
        end
        for _, path in ipairs(FARM_SAFE_CALLS) do
            Addon:Print("农场原值 " .. path .. "：" .. DescribeRawCall(detail.farm.rawCalls[path]))
        end
        PrintList("农场相关全局：", detail.namedFarmGlobals)
        Addon:Print("Blizzard_GarrisonUI 已加载：" .. tostring(detail.farmModules.garrisonUI))
        PrintList("农场相关已加载模块：", detail.farmModules.matches)
        Addon:Print("地图任务 API：地图=" .. tostring(detail.mapTaskSignals.mapID))
        for path, value in pairs(detail.mapTaskSignals.capabilities) do Addon:Print("地图任务 API " .. path .. "：" .. tostring(value)) end
        Addon:Print("地图 TaskQuest 原值：" .. DescribeRawCall(detail.mapTaskSignals.taskQuest or { available = false }))
        PrintList("地图 TaskQuest ID：", detail.mapTaskSignals.taskQuestIDs)
        Addon:Print("地图 QuestLog 原值：" .. DescribeRawCall(detail.mapTaskSignals.mapTasks))
        PrintList("地图 QuestLog ID：", detail.mapTaskSignals.mapQuestIDs or {})
        Addon:Print("场景步骤原值：" .. DescribeRawCall(detail.mapTaskSignals.scenario))
        Addon:Print(string.format("鼠标指向：%s / %s；当前目标：%s / %s；实体=%s。", tostring(detail.mouseover.name), tostring(detail.mouseover.guid), tostring(detail.target.name), tostring(detail.target.guid), tostring(detail.target.creatureID)))
        local position = detail.target.position or {}
        Addon:Print(string.format("当前目标位置：x=%s，y=%s，z=%s，实例=%s。", tostring(position.x), tostring(position.y), tostring(position.z), tostring(position.instanceID)))
        for _, entry in ipairs(detail.questLog.entries) do
            Addon:Print(string.format("任务日志：ID=%s；完成=%s；频率=%s；名称=%s。", tostring(entry.id), tostring(entry.complete), tostring(entry.frequency), tostring(entry.title)))
        end
        for _, row in ipairs(detail.questCompletion) do
            Addon:Print(string.format("任务 %d：IsQuestFlaggedCompleted=%s；C_QuestLog=%s。", row.id, tostring(row.isQuestFlaggedCompleted), tostring(row.cQuestLogIsQuestFlaggedCompleted)))
        end
        if not completed.available then
            Addon:Print("完成任务集合：GetQuestsCompleted 不可用。")
        elseif not completed.ok then
            Addon:Print("完成任务集合读取失败：" .. tostring(completed.error))
        elseif detail.completedQuestDelta.baseline then
            Addon:Print("完成任务集合：已建立本次登录会话基线。")
        else
            PrintList("完成任务集合新增：", detail.completedQuestDelta.added)
            PrintList("完成任务集合移除：", detail.completedQuestDelta.removed)
        end
        PrintEventTrace(detail.eventTrace)
        if farmCaptureMode == "finish" then PrintFarmSpellCapture(detail.farmSpellCapture) end
        Addon:Print(string.format("任务日志 %d 条；已捕获每日活动事件 %d 条。", #detail.questLog.entries, #detail.eventTrace))
        Addon:Print("每日活动探针只记录 diagnostics；农场、任务和账号每日均未写入正式业务快照。")
    end
    if farmCaptureMode == "start" then
        self.farmSpellCapture = { startedAt = Addon:Now(), mapID = CurrentMapID(), events = {}, castGUIDs = {} }
        Addon:Print("农场法术采集已开始：请完成一次完整农场流程后执行 /ytd probe farm-finish。")
    elseif farmCaptureMode == "finish" then
        self.farmSpellCapture = nil
    end
    return detail
end
