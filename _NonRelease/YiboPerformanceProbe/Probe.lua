local Probe = { hooks = {}, running = false, depth = 0, frameMS = 0 }
_G.YiboPerformanceProbe = Probe
local frame = CreateFrame("Frame")
local targets = {
    { "YiboCore", "Profile", "RefreshCurrent" },
    { "YiboCore", "DataDomains", "Dispatch" },
    { "YiboCore", "AccountView", "RefreshPage" },
    { "YiboCore", "AccountView", "NotifyPageChanged" },
    { "YiboCore", "Characters", "GetCurrent" },
    { "YiboCore", "Characters", "GetAll" },
    { "YiboCore", "Characters", "Get" },
    { "YiboCore", "Characters", "GetAllCached" },
    { "YiboCore", "ItemResolver", "Request" },
    { "YiboCore", "Defaults", "Copy" },
    { "YiboCore", "DomainStore", "Commit" },
    { "YiboCore", "Events", "Fire" },
    { "YiboCore", "ItemResolver", "Finish" },
    { "YiboBuilds", "Snapshot", "Capture" },
    { "YiboBuilds", "Snapshot", "CaptureSlot" },
    { "YiboBuilds", "AccountPage", "RefreshOpenDetail" },
    { "YiboBeastPaths", "RefreshMinimapLayer" },
    { "YiboLegendary", "Refresh" },
    { "YiboVault", "OnEvent" },
    { "YiboVault", "ScanEquipment" },
    { "YiboVault", "Items", "UpdatePersonalCountsIndex" },
    { "YiboAutoOpen", "Queue", "RefreshCandidates" },
    { "YiboAutoOpen", "Queue", "ProcessNext" },
    { "YiboCrafting", "Collector", "Scan" },
    { "YiboMail", "Scanner", "Scan" },
    { "YAB", "SyncWorldBossQuestKillsIfNeeded" },
    { "YAB", "ObserveUnit" },
    { "YAB", "PersistDB" },
    { "YiboLegendary", "Probe", "Run" },
    { "YiboVault", "ScanBag" },
    { "YiboVault", "Tooltip", "Append" },
    { "YiboVault", "AccountPage", "GetTooltipScope" },
    { "NDui", 1, "GetItemLevel" },
    { "NDui", 1, "Modules", "Bags", "Bags", "UpdateBag" },
    { "NDui", 1, "Modules", "Bags", "Bags", "GetItemInfo" },
    { "NDui", 1, "Modules", "Bags", "IsAcceptableQuestItem" },
}
local lootEvents = { LOOT_OPENED = true, LOOT_CLOSED = true, LOOT_SLOT_CLEARED = true,
    BAG_UPDATE = true, BAG_UPDATE_DELAYED = true, ITEM_PUSH = true,
    CHAT_MSG_LOOT = true, GET_ITEM_INFO_RECEIVED = true,
    SPELLS_CHANGED = true, SKILL_LINES_CHANGED = true, TRADE_SKILL_LIST_UPDATE = true,
    PLAYER_TALENT_UPDATE = true, PLAYER_EQUIPMENT_CHANGED = true,
    UNIT_INVENTORY_CHANGED = true, QUEST_LOG_UPDATE = true }
local function Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r 性能探针：" .. message) end
end
local function Push(list, value)
    if #list >= 60 then table.remove(list, 1) end
    list[#list + 1] = value
end
local function CPUAvailable()
    return GetCVar and GetCVar("scriptProfile") == "1"
        and type(UpdateAddOnCPUUsage) == "function" and type(GetAddOnCPUUsage) == "function"
end
function Probe:ReadCPU()
    local started = debugprofilestop()
    UpdateAddOnCPUUsage()
    local values = {}
    local getCount = C_AddOns and C_AddOns.GetNumAddOns or GetNumAddOns
    local getInfo = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
    if not getCount or not getInfo then return values, debugprofilestop() - started end
    for index = 1, getCount() do
        local name = getInfo(index)
        if name then values[name] = tonumber(GetAddOnCPUUsage(index)) or 0 end
    end
    return values, math.max(0, debugprofilestop() - started)
end
function Probe:SampleCPU(longFrame)
    if not self.cpuPrevious then return end
    local values, overhead = self:ReadCPU()
    local rows, yiboMS = {}, 0
    for name, value in pairs(values) do
        local delta = math.max(0, value - (self.cpuPrevious[name] or value))
        if delta > 0 then
            rows[#rows + 1] = { name = name, ms = delta }
            local stats = self.db.cpu[name] or { totalMS = 0, maxWindowMS = 0 }
            self.db.cpu[name] = stats
            stats.totalMS = stats.totalMS + delta
            stats.maxWindowMS = math.max(stats.maxWindowMS, delta)
            if name:match("^Yibo") and name ~= "YiboPerformanceProbe" then yiboMS = yiboMS + delta end
        end
    end
    table.sort(rows, function(a, b) return a.ms > b.ms end)
    local top = {}
    for index = 1, math.min(5, #rows) do top[index] = rows[index] end
    Push(self.db.cpuWindows, { at = GetTime() - self.startedAt, seconds = GetTime() - self.cpuAt,
        longFrameMS = longFrame and longFrame.ms or nil, yiboMS = yiboMS, top = top, overheadMS = overhead })
    if longFrame then longFrame.cpuTop, longFrame.yiboMS, longFrame.cpuWindowSeconds = top, yiboMS, GetTime() - self.cpuAt end
    self.cpuPrevious, self.cpuAt = values, GetTime()
    self.db.cpuSampleMaxMS = math.max(self.db.cpuSampleMaxMS or 0, overhead)
end
local function Finish(hook, started, ...)
    local elapsed = math.max(0, debugprofilestop() - started)
    Probe.depth = Probe.depth - 1
    if Probe.depth == 0 then Probe.frameMS = Probe.frameMS + elapsed end
    local stats = Probe.db.calls[hook.label]
    stats.count, stats.totalMS = stats.count + 1, stats.totalMS + elapsed
    stats.maxMS = math.max(stats.maxMS, elapsed)
    if elapsed >= 20 then
        Push(Probe.db.slowCalls, { at = GetTime() - Probe.startedAt, label = hook.label, ms = elapsed })
    end
    return ...
end
-- Attribute only public Core boundaries; do not modify business implementations.
-- Inclusive timings of nested APIs are separate rows, never summed as Core CPU.
local attributed = {
    ["YiboCore.Characters.GetCurrent"] = true, ["YiboCore.Characters.Get"] = true,
    ["YiboCore.Characters.GetAll"] = true, ["YiboCore.Characters.GetAllCached"] = true,
    ["YiboCore.DomainStore.Commit"] = true, ["YiboCore.ItemResolver.Request"] = true,
    ["YiboCore.Profile.RefreshCurrent"] = true, ["YiboCore.DataDomains.Dispatch"] = true,
    ["YiboCore.AccountView.RefreshPage"] = true, ["YiboCore.AccountView.NotifyPageChanged"] = true,
}
local function Caller()
    if type(debugstack) ~= "function" then return "unknown", "stack-unavailable" end
    local trace = debugstack(3, 32, 0) or ""
    for line in trace:gmatch("[^\r\n]+") do
        line = line:gsub('"', ''):gsub('%]', ''):gsub('%[', '')
        local addon, location = line:match("[Aa]dd[Oo]ns[/\\]([^/\\]+)[/\\]([^\"]-:%d+)")
        if addon and addon ~= "YiboCore" and addon ~= "YiboPerformanceProbe" then
            return addon, location
        end
    end
    return "Core/unknown", "no-external-frame"
end
local function FinishCaller(row, started, ...)
    local elapsed = math.max(0, debugprofilestop() - started)
    row.count, row.totalMS, row.maxMS = row.count + 1, row.totalMS + elapsed, math.max(row.maxMS, elapsed)
    return ...
end
function Probe:Install(path)
    local owner = _G[path[1]]
    for index = 2, #path - 1 do owner = owner and owner[path[index]] end
    local key = path[#path]
    if not owner or type(owner[key]) ~= "function" then return end
    local hook = { owner = owner, key = key, original = owner[key], label = table.concat(path, "."),
        ownOriginal = rawget(owner, key) }
    self.db.calls[hook.label] = { count = 0, totalMS = 0, maxMS = 0 }
    hook.wrapper = function(...)
        if not Probe.running then return hook.original(...) end
        local callerRow
        if attributed[hook.label] then
            local attributionStart = debugprofilestop()
            local addon, source = Caller()
            local id = addon .. "|" .. hook.label .. "|" .. source
            if not Probe.db.coreCallers[id] and Probe.callerRows >= 120 then
                id, addon, source = "overflow|" .. hook.label, "other", "row-limit"
            end
            callerRow = Probe.db.coreCallers[id]
            if not callerRow then
                callerRow = { addon = addon, source = source, api = hook.label, count = 0, totalMS = 0, maxMS = 0 }
                Probe.db.coreCallers[id] = callerRow; Probe.callerRows = Probe.callerRows + 1
            end
            Probe.db.attributionMS = Probe.db.attributionMS + math.max(0, debugprofilestop() - attributionStart)
        end
        local started = debugprofilestop()
        Probe.depth = Probe.depth + 1
        if callerRow then return Finish(hook, started, FinishCaller(callerRow, started, hook.original(...))) end
        return Finish(hook, started, hook.original(...))
    end
    owner[key] = hook.wrapper
    self.hooks[#self.hooks + 1] = hook
end
function Probe:Stop(quiet)
    local wasRunning = self.running
    if self.running and self.cpuPrevious then self:SampleCPU() end
    self.running = false
    frame:SetScript("OnUpdate", nil)
    for _, hook in ipairs(self.hooks) do
        if hook.owner[hook.key] == hook.wrapper then hook.owner[hook.key] = hook.ownOriginal end
    end
    self.hooks = {}
    self.cpuPrevious = nil
    if self.db and wasRunning then self.db.duration = math.max(0, GetTime() - (self.startedAt or GetTime())) end
    if not quiet then Print("已停止；/ypf report 查看结果。/reload 或退出游戏后记录写入存档。") end
end
function Probe:Start()
    if type(debugprofilestop) ~= "function" then Print("客户端不提供计时接口。"); return end
    self:Stop(true)
    self.startedAt, self.depth, self.frameMS = GetTime(), 0, 0
    self.ignoreUntil = GetTime() + 2
    self.callerRows = 0
    self.db = { schemaVersion = 4, probeVersion = "0.4.2", calls = {}, slowCalls = {}, longFrames = {}, duration = 0,
        coreCallers = {}, attributionMS = 0,
        lootEvents = {}, eventCounts = {},
        cpu = {}, cpuWindows = {}, cpuEnabled = CPUAvailable() and true or false }
    _G.YiboPerformanceProbeDB = self.db
    for _, path in ipairs(targets) do self:Install(path) end
    if self.db.cpuEnabled then self.cpuPrevious = self:ReadCPU(); self.cpuAt = GetTime() end
    self.running = true
    frame:SetScript("OnUpdate", function(_, elapsed)
        -- A thrown addon error bypasses Finish. Recover the nesting counter at
        -- the next frame; the failed call itself is not measured.
        if Probe.depth ~= 0 then Probe.depth, Probe.frameMS = 0, 0 end
        local longFrame
        if not Probe.loading and GetTime() >= Probe.ignoreUntil and elapsed >= 0.25 then
            local latest = Probe.db.lootEvents[#Probe.db.lootEvents]
            longFrame = { at = GetTime() - Probe.startedAt, ms = elapsed * 1000, trackedMS = Probe.frameMS,
                recentEvent = latest and latest.event, recentEventAt = latest and latest.at }
            Push(Probe.db.longFrames, longFrame)
        end
        if Probe.cpuPrevious and (longFrame or GetTime() - Probe.cpuAt >= 0.5) then Probe:SampleCPU(longFrame) end
        Probe.frameMS = 0
        Probe.db.duration = GetTime() - Probe.startedAt
    end)
    Print("已开始，覆盖 " .. #self.hooks .. " 个回调；跑动复现卡顿后输入 /ypf stop，再输入 /ypf report。")
    Print("探针版本 0.4.2；角色 " .. tostring(UnitName and UnitName("player") or "unknown")
        .. "；Core " .. tostring(_G.YiboCore and _G.YiboCore.VERSION or "unavailable"))
    Print(self.db.cpuEnabled and "全插件 CPU 采样已启用（0.5 秒区间）。" or "全插件 CPU 采样未启用；/ypf cpuon 会开启计时并重载界面。")
end
function Probe:Report()
    local db = self.db or _G.YiboPerformanceProbeDB
    if not db then Print("暂无记录，先输入 /ypf start。"); return end
    Print(string.format("采样 %.1f 秒；慢调用 %d 条；长帧 %d 条（各最多保留 60 条）。", db.duration or 0, #db.slowCalls, #db.longFrames))
    if db.coreCallers then
        local callers = {}
        for _, row in pairs(db.coreCallers) do callers[#callers + 1] = row end
        table.sort(callers, function(a, b) return a.totalMS > b.totalMS end)
        Print(string.format("Core 调用来源：溯源自身累计 %.1fms；以下嵌套 API 耗时不可相加。", db.attributionMS or 0))
        for index = 1, math.min(8, #callers) do
            local row = callers[index]
            Print(string.format("%s → %s：累计 %.1fms，峰值 %.1fms，%d次；%s", row.addon, row.api,
                row.totalMS, row.maxMS, row.count, row.source))
        end
    end
    local rows = {}
    for label, stats in pairs(db.calls) do rows[#rows + 1] = { label = label, stats = stats } end
    table.sort(rows, function(a, b) return a.stats.maxMS > b.stats.maxMS end)
    for index = 1, math.min(10, #rows) do
        local row = rows[index]
        Print(string.format("%s：峰值 %.1f ms，累计 %.1f ms，%d 次", row.label, row.stats.maxMS, row.stats.totalMS, row.stats.count))
    end
    for index = math.max(1, #db.longFrames - 4), #db.longFrames do
        local item = db.longFrames[index]
        Print(string.format("长帧 +%.1fs：%.0f ms；邻近帧区间已测回调 %.1f ms", item.at, item.ms, item.trackedMS))
        if item.recentEvent then Print(string.format("最近事件 %s，时间 +%.2fs（仅关联线索）。", item.recentEvent, item.recentEventAt)) end
        if item.cpuTop then
            local names = {}
            for _, row in ipairs(item.cpuTop) do names[#names + 1] = string.format("%s %.1fms", row.name, row.ms) end
            Print(string.format("邻近 CPU 区间 %.2fs，Yibo 合计 %.1fms；%s", item.cpuWindowSeconds, item.yiboMS, table.concat(names, "；")))
        end
    end
    if db.cpuEnabled then
        Print(string.format("CPU 采样自身峰值 %.1fms；采样会增加开销，结束后 /ypf cpuoff 关闭并重载。", db.cpuSampleMaxMS or 0))
    end
    if db.eventCounts and next(db.eventCounts) then
        local counts = {}
        for event, count in pairs(db.eventCounts) do counts[#counts + 1] = event .. "=" .. count end
        table.sort(counts)
        Print("已监测事件次数：" .. table.concat(counts, "，"))
    end
    Print("回调耗时包含下游插件钩子；嵌套调用不可相加。长帧与回调跨帧可能错位，未覆盖的调用仍需排查。")
end
frame:RegisterEvent("LOADING_SCREEN_ENABLED")
frame:RegisterEvent("LOADING_SCREEN_DISABLED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
for event in pairs(lootEvents) do pcall(frame.RegisterEvent, frame, event) end
frame:SetScript("OnEvent", function(_, event)
    if lootEvents[event] then
        if Probe.running then
            Probe.db.eventCounts[event] = (Probe.db.eventCounts[event] or 0) + 1
            Push(Probe.db.lootEvents, { at = GetTime() - Probe.startedAt, event = event })
        end
        return
    end
    Probe.loading = event == "LOADING_SCREEN_ENABLED"
    Probe.ignoreUntil = GetTime() + 2
    Probe.frameMS = 0
end)
function Probe:Memory()
    local update = UpdateAddOnMemoryUsage or (C_AddOns and C_AddOns.UpdateAddOnMemoryUsage)
    local getMemory = GetAddOnMemoryUsage or (C_AddOns and C_AddOns.GetAddOnMemoryUsage)
    if not update or not getMemory then Print("客户端不提供插件内存接口。"); return end
    self:Stop(true)
    update()
    local before = { YiboCore = getMemory("YiboCore") or 0, YiboTodo = getMemory("YiboTodo") or 0 }
    local luaBefore = collectgarbage("count")
    collectgarbage("collect")
    update()
    local result = { before = before, after = {}, luaBeforeKB = luaBefore,
        luaAfterKB = collectgarbage("count"), at = GetTime() }
    for _, name in ipairs({ "YiboCore", "YiboTodo" }) do
        result.after[name] = getMemory(name) or 0
        Print(string.format("内存 %s：回收前 %.1fMB → 回收后 %.1fMB（减少 %.1fMB）。", name,
            before[name] / 1024, result.after[name] / 1024, (before[name] - result.after[name]) / 1024))
    end
    Print("已停止采样并完成一次 Lua 垃圾回收；未删除存档。回收后数值用于观察仍保留的内存，不是泄漏证明。")
    _G.YiboPerformanceProbeMemoryDB = result
end
SLASH_YIBOPERFORMANCEPROBE1 = "/ypf"
SlashCmdList.YIBOPERFORMANCEPROBE = function(message)
    local command = (message or ""):lower():match("^%s*(%S+)")
    if command == "start" then Probe:Start()
    elseif command == "stop" then Probe:Stop()
    elseif command == "report" then Probe:Report()
    elseif command == "memory" then Probe:Memory()
    elseif command == "cpuon" or command == "cpuoff" then
        Probe:Stop(true)
        SetCVar("scriptProfile", command == "cpuon" and "1" or "0")
        ReloadUI()
    else Print("/ypf start 开始；/ypf stop 停止；/ypf report 查看；/ypf memory 比较回收前后内存；/ypf cpuon 或 cpuoff 切换全插件 CPU 计时并重载。") end
end
