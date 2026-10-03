local Probe = { hooks = {}, running = false, depth = 0, frameMS = 0 }
_G.YiboPerformanceProbe = Probe
local frame = CreateFrame("Frame")
local targets = {
    { "YiboCore", "Profile", "RefreshCurrent" },
    { "YiboCore", "DataDomains", "Dispatch" },
    { "YiboCore", "AccountView", "RefreshPage" },
    { "YiboCore", "Characters", "GetCurrent" },
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
    { "NDui", 1, "GetItemLevel" },
    { "NDui", 1, "Modules", "Bags", "Bags", "UpdateBag" },
    { "NDui", 1, "Modules", "Bags", "Bags", "GetItemInfo" },
    { "NDui", 1, "Modules", "Bags", "IsAcceptableQuestItem" },
}
local lootEvents = { LOOT_OPENED = true, LOOT_CLOSED = true, LOOT_SLOT_CLEARED = true,
    BAG_UPDATE = true, BAG_UPDATE_DELAYED = true, ITEM_PUSH = true,
    CHAT_MSG_LOOT = true, GET_ITEM_INFO_RECEIVED = true }
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
        local started = debugprofilestop()
        Probe.depth = Probe.depth + 1
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
    self.db = { schemaVersion = 3, calls = {}, slowCalls = {}, longFrames = {}, duration = 0,
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
    Print(self.db.cpuEnabled and "全插件 CPU 采样已启用（0.5 秒区间）。" or "全插件 CPU 采样未启用；/ypf cpuon 会开启计时并重载界面。")
end
function Probe:Report()
    local db = self.db or _G.YiboPerformanceProbeDB
    if not db then Print("暂无记录，先输入 /ypf start。"); return end
    Print(string.format("采样 %.1f 秒；慢调用 %d 条；长帧 %d 条（各最多保留 60 条）。", db.duration or 0, #db.slowCalls, #db.longFrames))
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
        Print("拾取/背包事件次数：" .. table.concat(counts, "，"))
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
SLASH_YIBOPERFORMANCEPROBE1 = "/ypf"
SlashCmdList.YIBOPERFORMANCEPROBE = function(message)
    local command = (message or ""):lower():match("^%s*(%S+)")
    if command == "start" then Probe:Start()
    elseif command == "stop" then Probe:Stop()
    elseif command == "report" then Probe:Report()
    elseif command == "cpuon" or command == "cpuoff" then
        Probe:Stop(true)
        SetCVar("scriptProfile", command == "cpuon" and "1" or "0")
        ReloadUI()
    else Print("/ypf start 开始；/ypf stop 停止；/ypf report 查看；/ypf cpuon 或 cpuoff 切换全插件 CPU 计时并重载。") end
end
