local ms, seconds, scripts = 0, 0, {}
debugprofilestop = function() return ms end
GetTime = function() return seconds end
CreateFrame = function() return {
    SetScript = function(_, name, callback) scripts[name] = callback end,
    RegisterEvent = function() end,
} end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
local inner = function() ms = ms + 30; return nil, "ok", nil, 4 end
YiboCore = { Characters = { GetCurrent = inner }, Profile = {} }
local outer = function() return YiboCore.Characters:GetCurrent() end
YiboCore.Profile.RefreshCurrent = outer
dofile("_NonRelease/YiboPerformanceProbe/Probe.lua")
local probe = YiboPerformanceProbe
assert(not probe.running and not scripts.OnUpdate)
probe:Start()
local a, b, c, d = YiboCore.Profile:RefreshCurrent()
assert(a == nil and b == "ok" and c == nil and d == 4, "return values preserved")
assert(probe.frameMS == 30, "nested timing not double-counted")
assert(probe.db.calls["YiboCore.Profile.RefreshCurrent"].maxMS == 30)
seconds = 3
scripts.OnUpdate(nil, 1)
assert(#probe.db.longFrames == 1 and probe.db.longFrames[1].trackedMS == 30)
scripts.OnEvent(nil, "LOADING_SCREEN_ENABLED")
seconds = 10
scripts.OnUpdate(nil, 2)
assert(#probe.db.longFrames == 1, "loading excluded")
scripts.OnEvent(nil, "LOADING_SCREEN_DISABLED")
seconds = 13
for _ = 1, 70 do YiboCore.Profile:RefreshCurrent(); scripts.OnUpdate(nil, 1) end
assert(#probe.db.longFrames == 60 and #probe.db.slowCalls == 60, "bounded records")
probe:Report()
probe:Stop(true)
assert(YiboCore.Characters.GetCurrent == inner and YiboCore.Profile.RefreshCurrent == outer)
assert(not scripts.OnUpdate and not probe.running)
probe:Start(); probe:Start(); probe:Stop(true)
assert(YiboCore.Characters.GetCurrent == inner, "restart restores originals")
local stoppedDuration = probe.db.duration
seconds = seconds + 20
probe:Stop(true)
assert(probe.db.duration == stoppedDuration, "repeated stop must not extend sample duration")
local inherited = function() ms = ms + 45 end
local backpack = setmetatable({}, { __index = { UpdateBag = inherited } })
NDui = { { Modules = { Bags = { Bags = backpack } } } }
probe:Start()
scripts.OnEvent(nil, "LOOT_OPENED")
scripts.OnEvent(nil, "BAG_UPDATE")
backpack:UpdateBag(0)
assert(probe.db.calls["NDui.1.Modules.Bags.Bags.UpdateBag"].maxMS == 45)
assert(probe.db.eventCounts.BAG_UPDATE == 1 and #probe.db.lootEvents == 2)
assert(probe.loading == false, "loot event does not change loading state")
probe:Stop(true)
assert(rawget(backpack, "UpdateBag") == nil and backpack.UpdateBag == inherited, "restore inherited method")
local cpuValues = { 0, 0, 0 }
GetCVar = function() return "1" end
UpdateAddOnCPUUsage = function() ms = ms + 1 end
GetNumAddOns = function() return 3 end
GetAddOnInfo = function(index) return ({ "YiboBuilds", "OtherAddon", "YiboPerformanceProbe" })[index] end
GetAddOnCPUUsage = function(index) return cpuValues[index] end
YAB = { ObserveUnit = function() ms = ms + 1 end }
probe:Start()
assert(probe.db.cpuEnabled and probe.db.calls["YAB.ObserveUnit"], "CPU mode and correct boss global")
seconds = seconds + 3
cpuValues = { 2, 450, 3 }
scripts.OnUpdate(nil, 0.6)
local longFrame = probe.db.longFrames[1]
assert(longFrame.yiboMS == 2 and longFrame.cpuTop[1].name == "OtherAddon")
assert(longFrame.cpuTop[1].ms == 450 and probe.db.cpuSampleMaxMS == 1)
seconds = seconds + 0.6
cpuValues = { 4, 460, 5 }
scripts.OnUpdate(nil, 0.1)
assert(probe.db.cpu.OtherAddon.totalMS == 460, "CPU deltas accumulate once")
probe:Report()
probe:Stop(true)
local setting, reloaded
SetCVar = function(name, value) setting = { name, value } end
ReloadUI = function() reloaded = true end
SlashCmdList.YIBOPERFORMANCEPROBE("cpuoff")
assert(setting[1] == "scriptProfile" and setting[2] == "0" and reloaded)
print("YiboPerformanceProbe smoke passed")
