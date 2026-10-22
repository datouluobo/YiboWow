-- Run from workspace root with Lua 5.1. Actual Core contracts and Todo model;
-- the game directory/profession domain and frame geometry are controlled inputs.
local clock, hour, minute, checks = 100000, 6, 59, 0
GetServerTime = function() return clock end
time, date = GetServerTime, os.date
GetGameTime = function() return hour, minute end
STANDARD_TEXT_FONT = "font"
SlashCmdList = {}
local function Frame(parent)
    local frame = { parent = parent, width = 1040, height = 420, scripts = {}, shown = true }
    function frame:SetSize(w, h) self.width, self.height = w, h end
    function frame:SetWidth(w) self.width = w end
    function frame:SetHeight(h) self.height = h end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:GetParent() return self.parent end
    function frame:SetPoint(...) self.point = { ... } end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:GetScript(event) return self.scripts[event] end
    function frame:HookScript(event, callback) local old = self.scripts[event]; self.scripts[event] = function(...) if old then old(...) end; callback(...) end end
    function frame:SetText(text) self.text = text end
    function frame:SetShown(shown) self.shown = shown end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetEnabled(enabled) self.enabled = enabled end
    function frame:SetBackdrop(value) self.backdrop = value end
    function frame:CreateFontString() return Frame(self) end
    function frame:CreateTexture() return Frame(self) end
    return setmetatable(frame, { __index = function(_, key)
        if key:match("^[A-Z]") then return function() end end
    end })
end
CreateFrame = function(_, _, parent) return Frame(parent) end
local function Equal(a, b, label)
    checks = checks + 1
    assert(a == b, (label or "value") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end
dofile("YiboCore/Bootstrap.lua")
dofile("YiboCore/Util/Defaults.lua")
dofile("YiboCore/Runtime/Capabilities.lua")
dofile("YiboCore/_NonRelease/Tests/LoadLocale.lua")
dofile("YiboTaskHub/Locales/zh.lua")
dofile("YiboTaskHub/Locales/en.lua")
dofile("YiboCore/Runtime/Events.lua")
dofile("YiboCore/Runtime/Registry.lua")
dofile("YiboCore/Runtime/Contracts.lua")
dofile("YiboCore/UI/Theme.lua")
dofile("YiboCore/Runtime/ItemResolver.lua")
local Core = YiboCore
Core.IsInitialized = function() return true end
local notices = 0
Core.Print = function() end
local characters = { { id = "C", name = "星河", realm = "测试" }, { id = "D", name = "暮光", realm = "测试" },
    { id = "F", name = "云帆", realm = "测试" }, { id = "U", name = "未知", realm = "测试" } }
local currentID = "C"
Core.Characters = {
    GetAll = function() return Core.Defaults:Copy(characters) end,
    GetCurrent = function() for _, c in ipairs(characters) do if c.id == currentID then return Core.Defaults:Copy(c) end end end,
    Get = function(_, id) for _, c in ipairs(characters) do if c.id == id then return Core.Defaults:Copy(c) end end end,
    FormatName = function(_, c) return c and c.name end,
}
local domains = {
    C = { state = "known", data = { primaryProfessions = { { id = 197, skillLevel = 600, name = "裁缝" } } } },
    D = { state = "known", data = { primaryProfessions = { { id = 197, skillLevel = 600, name = "裁缝" } } } },
    F = { state = "known", data = { primaryProfessions = { { id = 171, skillLevel = 600, name = "炼金" } } } },
}
Core.DataDomains = { Get = function(_, id) return Core.Defaults:Copy(domains[id]) end }
local pages, entries, refreshes = {}, {}, 0
Core.AccountView = {
    SetPageScope = function() end,
    RegisterPage = function(_, _, page) pages[page.id] = page; return page end,
    NotifyPageChanged = function() refreshes = refreshes + 1 end,
    ShowPage = function(_, id) Core.lastPage = id end,
    GetVisibleCharacters = function() return Core.Defaults:Copy(characters) end,
}
Core.Entry = { RegisterBusinessEntry = function(_, _, definition) entries[definition.id] = definition; return definition end }
Core.Capabilities:Register("account-view", 2)
Core.Capabilities:Register("character-name-format", 1)
Core.Capabilities:Register("character-identity", 1)
Core.Capabilities:Register("account-character-admission", 1)
Core.Capabilities:Register("account-surface-budget", 1)


local timers = {}
C_Timer = { After = function(delay, fn) timers[#timers+1] = { delay = delay, fn = fn } end }
Core.Database = { db = { settings = {} }, GetDB = function(self) return self.db end }
dofile("YiboCore/UI/BusinessItemActions.lua")
assert(loadfile("YiboTaskHub/Namespace.lua"))("YiboTaskHub", {})
local Hub = YiboTaskHub
for _, name in ipairs({ "Database", "Goals", "BossTargets", "Snapshot", "Contracts", "GoalContracts" }) do dofile("YiboTaskHub/" .. name .. ".lua") end
Hub.Core = Core
assert(Core:RegisterAddon(Hub.NAME, { version = "test", requiredAPI = 12 }))
assert(Core:RegisterAddon("Spec", { version = "test", requiredAPI = 12 }))
Hub.GoalEditor = { Locate = function(_, id) Hub.located = id; return true end, Configure = function(_, intent) Hub.configuring = intent; return true end }
assert(Hub.Database:Initialize()); assert(Hub.Goals:Initialize()); Hub.Contracts:Initialize()


local now = clock
local characters = { { id = "A", name = "星河", realm = "甲", level = 90 }, { id = "B", name = "星河", realm = "乙", level = 90 },
    { id = "C", name = "暮光", realm = "甲", level = 90 }, { id = "D", name = "新角色", realm = "甲", level = 20 } }
Core.Characters.GetAll = function() return Core.Defaults:Copy(characters) end
Core.Characters.Get = function(_, id) for _, c in ipairs(characters) do if c.id == id then return Core.Defaults:Copy(c) end end end
Core.Characters.GetCurrent = function() return Core.Characters:Get("A") end
Core.Characters.ResolveLegacyKey = function(_, key) return ({ ["星河-甲"] = "A", ["星河-乙"] = "B", ["暮光-甲"] = "C", ["新角色-甲"] = "D" })[key] end

local Targets = Hub.BossTargets; assert(Targets:Initialize())
local weekly = now + 5000
local daily = now + 3000
C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return weekly - now end }
GetQuestResetTime = function() return daily - now end
local flags = {}
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return flags[id] == true end }
local saved = {}
GetNumSavedInstances = function() return #saved end
GetSavedInstanceInfo = function(index)
    local item = saved[index]
    return item.name, 999, item.reset or weekly - now, item.difficultyID, true, item.extended, 0, true, 10, item.difficultyName or "10人普通", 2, 0, false, item.mapID
end
GetSavedInstanceEncounterInfo = function(index, i)
    local boss = saved[index].bosses[i]
    if boss then return boss.name, 0, boss.killed, false end
end
GetDifficultyInfo = function(id) return ({ [1] = "普通", [3] = "10人普通", [4] = "25人普通", [5] = "10人英雄" })[id] end
local selectedInstance, selectedDifficulty = 777, 4
EJ_GetNumTiers = function() return 1 end
EJ_GetCurrentTier = function() return 1 end
EJ_SelectTier = function() end
EJ_GetTierInfo = function() return "巫妖王之怒" end
EJ_GetInstanceByIndex = function(i, raid) if i == 1 and raid then return 123 end end
EJ_GetInstanceInfo = function() return "冰冠堡垒", nil, nil, nil, nil, nil, 99999, nil, true, 631 end
EJ_SelectInstance = function(id) selectedInstance = id end
EJ_GetCurrentInstance = function() return selectedInstance end
EJ_SetDifficulty = function(id) selectedDifficulty = id end
EJ_GetDifficulty = function() return selectedDifficulty end
EJ_IsValidInstanceDifficulty = function(id) return id == 3 or id == 4 or id == 5 end
EJ_GetEncounterInfoByIndex = function(i)
    if i <= 2 then return ({ "玛洛加尔领主", "巫妖王" })[i], "description", 10000 + i, 0, nil, 123, 900 + i end
end
GetRealZoneText = function(mapID) if mapID == 631 then return "冰冠堡垒" end end
YAB = {
    GetCurrentCharKey = function() return "星河-甲" end,
    GetCurrentRealm = function() return "甲" end,
    PersistDB = function() end,
    NotifyCorePageChanged = function() if YAB.PlannedTargets then YAB.PlannedTargets:ScheduleChange() end end,
    GetAllBossList = function() return { { key = "galleon", name = "炮舰" }, { key = "sha_of_anger", name = "怒之煞" },
        { key = "ordos", name = "斡耳朵斯" }, { key = "celestials", name = "四天神" }, { key = "nalak", name = "纳拉克" }, { key = "oondasta", name = "乌达斯塔" } } end,
    GetBossList = function() return { { key = "sha_of_anger", name = "怒之煞" } } end,
    GetAccountCharacterKeys = function(context)
        local keys = {}; for key in pairs(YiboAltoBossDB.knownChars) do keys[#keys + 1] = key end; return keys
    end,
}
YiboAltoBossDB = { settings = { lockoutColumns = {} }, knownChars = { ["星河-甲"] = {}, ["星河-乙"] = {}, ["暮光-甲"] = {}, ["新角色-甲"] = {} },
    characters = { ["星河-甲"] = {}, ["星河-乙"] = {}, ["暮光-甲"] = {}, ["新角色-甲"] = {} } }
dofile("YiboAltoBoss/Locale.lua")
dofile("YiboCore/_NonRelease/Tests/LoadCalendar.lua")
dofile("YiboAltoBoss/HolidayBoss.lua")
dofile("YiboAltoBoss/LockoutLocale.lua")
dofile("YiboAltoBoss/DungeonBossCatalog.lua")
dofile("YiboAltoBoss/DungeonRuns.lua")
dofile("YiboAltoBoss/InstanceLockouts.lua")
dofile("YiboAltoBoss/TargetCatalog.lua")
dofile("YiboAltoBoss/PlannedTargets.lua")
dofile("YiboAltoBoss/GoalTargets.lua")
dofile("YiboAltoBoss/TargetProjection.lua")
assert(Core:RegisterAddon("YiboAltoBoss", { requiredAPI = 13 }))
local Plans = YAB.PlannedTargets
local originalAPI = Core.API_VERSION
Core.API_VERSION = 10; Equal(Plans:Initialize(), nil, "low API stops optional integration"); Core.API_VERSION = originalAPI
assert(Plans:Initialize())

local catalog = assert(Targets:Catalog())
local function Boss() return { catalogID = "world:galleon", scope = "all", active = true } end
local function Dungeon(encounters, difficulty) return { catalogID = "journal:123", difficultyID = difficulty or 3, scope = "boss", encounterIDs = encounters or { 901 }, active = true } end
Equal(Hub.Snapshot:Build(characters).uniqueCount, 0, "source registration does not create goals")
assert(Targets:Put("A", Boss())); assert(Targets:Put("A", Dungeon({901,901})))
Equal(#Hub.Goals:List(), 2, "old editor writes the shared library")
Equal(Targets:Put("A", Dungeon({10001})), nil, "reject journal ID as encounter ID")
Equal(Targets:Put("A", Dungeon({901},1)), nil, "reject untrackable difficulty")
Plans:Observe(); Hub.Contracts:Invalidate()
Equal(Hub.Snapshot:Build(characters).byCharacter.A[1].task.readiness, "actionable")
local copy = assert(Targets:PreviewCopy("A", {"B"})); assert(Targets:ApplyCopy(copy))
Equal(#Targets:List("B"),2); Equal(#Hub.Goals:List(),4)
local reverse = assert(Targets:PreviewCopy("B", {"A"})); assert(Targets:ApplyCopy(reverse))
Equal(#Hub.Goals:List(),4,"reverse copy dedup")
Equal(#Plans:Configuration({"A","B"}).targets.A,2,"public automatic display reads same goals")
local entry=Targets:List("A")[1]; assert(Targets:Edit("A",entry.id,false))
Equal(Hub.Goals:List()[1].state,"paused","legacy pause updates shared record")
assert(Targets:Edit("A",entry.id,true)); Hub.Snapshot:Build(characters)
local targetChanges = 0
Core.Events:Register("BUSINESS_CONTRACT_CHANGED", "goal-sync-spec", function(_, descriptor)
    if descriptor.name == "action.targets" and descriptor.providerID == "YiboAltoBoss:targets" then targetChanges = targetChanges + 1 end
end)
flags[32098]=true; Plans:Observe()
local pendingTimers = timers; timers = {}
for _, timer in ipairs(pendingTimers) do if timer.delay == 0 then timer.fn() end end
Equal(targetChanges > 0,true,"Boss observation notifies exact-goal source")
Hub.Snapshot:Build(characters)
local history=0; for _,g in ipairs(Hub.Goals:List()) do if g.intent.scope.characterID=="A" and g.intent.conditions.catalogID=="world:galleon" then history=#g.history end end
Equal(history,1,"source completion recorded")
dofile("YiboTaskHub/GoalEditor.lua")
local management = CreateFrame("Frame"); Hub.GoalEditor.Create(management); Hub.GoalEditor.Refresh(management,{characters=characters})
local cycleCompleted = false
for _, row in ipairs(management.rows) do if row.goal and row.goal.intent.scope.characterID == "A"
    and row.goal.intent.conditions.catalogID == "world:galleon" then cycleCompleted = row.detail.text:find(Core.Locale:Get("YiboTaskHub", "TEXT.COMPLETED_THIS_CYCLE.A1A9A4"),1,true) ~= nil end end
Equal(cycleCompleted,true,"management explains why completed Boss is absent from work list")
Equal(Plans:IsPlanned("暮光-甲","galleon"),false,"unplanned role does not inherit another role's goal")
local first=Hub.Goals:List()[1]; local preview=assert(Hub.Goals:PreviewCopy({first.id},{"C"})); assert(Hub.Goals:ApplyCopy(preview.token))
Equal(#Targets:List("C"),1,"generic copy visible to original editor")
assert(Hub.Goals:Add({providerID="YiboAltoBoss:targets",scope={mode="character",characterID="D"},conditions=Boss(),repeatPolicy="once"}))
assert(Targets:Put("D",Boss()))
Equal(#Targets:List("D"),2,"legacy editor keeps once and recurring goals separate")
Plans:Shutdown();Equal(Core.Contracts:List("action.targets",{major=1})[1],nil,"source unregister cleanup")
Equal(#Hub.Goals:List(),7,"source removal retains goals")
print("BossGoalsSpec: " .. checks .. " checks passed")
