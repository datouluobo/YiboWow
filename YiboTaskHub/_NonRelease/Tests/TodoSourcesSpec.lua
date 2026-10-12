-- Historical action.todo source-envelope checks; explicit user goals are covered by
-- _NonRelease/TaskGoalIntegration. This fixture deliberately omits the goal library.
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
    function frame:HookScript(event, callback) self.scripts[event] = callback end
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
Core.Capabilities:Register("account-entry", 2)
Core.Capabilities:Register("builtin-entry-bar", 1)

Core.Capabilities:Register("business-item-actions", 1)
assert(loadfile("YiboTaskHub/Namespace.lua"))("YiboTaskHub", {})
dofile("YiboTaskHub/Locales/zh.lua")
dofile("YiboTaskHub/Locales/en.lua")
for _, file in ipairs({ "Database", "Snapshot", "Contracts", "Presentation", "Preview", "AccountPage", "HUD", "Reminders", "Displays", "Settings", "CoreIntegration" }) do dofile("YiboTaskHub/" .. file .. ".lua") end
local Hub = YiboTaskHub
Hub.Database:Initialize()
Hub.db.goals = nil -- legacy envelope fixture
Hub.Goals = { Initialize = function() return true end, Shutdown = function() end }
assert(Hub.CoreIntegration:Initialize())
Equal(pages.taskhub.previewEnabled, true, "O4 Core hover enabled")
Equal(entries.yth.pageID, "taskhub")
Equal(Hub.Snapshot:Build(characters).providerCount, 0, "missing source is not an exception")
assert(Hub.CoreIntegration:Initialize())
Equal(#Core.Events._listeners.BUSINESS_CONTRACT_CHANGED, 1, "idempotent subscriptions")


time = os.time
clock, hour, minute = os.time({year=2024,month=9,day=1,hour=12}), 12, 0
C_Calendar = { GetNumDayEvents = function() return 1 end, GetDayEvent = function() return {title="Darkmoon Faire"} end }
dofile("YiboTodo/Namespace.lua")
for _, file in ipairs({ "Database", "Catalog/MonitoringGroupCatalog", "Catalog/ActivityCatalog", "Catalog/CooldownGroupCatalog", "Catalog/CooldownCatalog_MoP", "Catalog/Ruleset_50504", "Catalog/FarmOperationCatalog", "Catalog/DailyActivityCatalog_MoP", "Catalog/DailyActivityCatalog_Legacy", "Catalog/SpecialActivityCatalog_MoP", "Catalog/Validator", "Model/Schedule", "Model/State", "Model/Snapshot", "ActionTodo", "ActionNomi", "ActionActivities", "ActionContracts", "Providers/Registry", "Providers/ProfessionCooldown", "Providers/FarmOperationObservation", "Providers/DailyQuest", "Providers/SpecialActivity" }) do dofile("YiboTodo/" .. file .. ".lua") end
local Todo = YiboTodo
Todo.Core = Core
Todo.Database:Initialize()
Todo:ValidateCatalog()
local disabled = {}
Todo.Settings = { IsMonitoringGroupEnabled = function(_, id) return not disabled[id] end,
    IsMonitoringItemEnabled = function(_, group, id) return not disabled[group] and not disabled[id] end }
characters[1].level, characters[2].level = 90, 90
domains.C.data.primaryProfessions[2] = {id=755,skillLevel=600,name="珠宝"}
domains.C.data.professions = {{id=185,skillLevel=600,name="烹饪"},{id=356,skillLevel=600,name="钓鱼"}}
assert(Core:RegisterAddon("YiboTodo", { requiredAPI = 10 }))
assert(Todo.ActionContracts:Initialize())
Equal(#Hub.Contracts.list, 3, "all Todo providers registered")
local request = {scope={characterIDs={"C","D","F","U","C"}}}
local function Find(result, suffix)
    for _, task in ipairs(result.data.tasks) do if task.itemKey:sub(-#suffix)==suffix then return task end end
end
local function Refresh()
    Todo:NotifyChanged()
    return Todo.ActionActivities:Query(request)
end
local result = Refresh()
local expected=0
for id, project in pairs(Todo.Snapshot:GetCharacter("C").activities) do
    expected=expected+1
    local task=Find(Todo.ActionTodo:Query({scope={characterIDs={"C"}}}),id)
    Equal(task ~= nil,true,"profession included "..id)
    Equal(task.sourceState,project.state,"profession view agreement "..id)
end
Equal(expected>2,true,"more than initial celestial cloth")
for group, projects in pairs(Todo.Snapshot:GetCharacter("C").monitoringProjects) do
    if group~="profession-cooldown" and group~="nomi" then
        for _, project in ipairs(projects) do
            if project.state~="not-applicable" then
                local task=Find(result,project.groupID)
                Equal(task~=nil,true,"project included "..project.groupID)
                Equal(task.sourceState,project.state,"view agreement "..project.groupID)
            end
        end
    end
end
local account=Find(result,"mop.brilltron-4000")
Equal(account.execution.mode,"account")
Equal(#account.execution.candidateCharacterIDs,4,"account candidate list deduplicates repeated scope")
local accountCount=0
for _,task in ipairs(result.data.tasks) do if task.itemKey==account.itemKey then accountCount=accountCount+1 end end
Equal(accountCount,1,"account task emitted once")
local descriptor
for _,entry in ipairs(Hub.Contracts.list) do if entry.providerID==Todo.ActionActivities.PROVIDER then descriptor=entry end end
assert(Hub.Snapshot:ValidateResult(result,descriptor,request.scope.characterIDs))
Equal(#Hub.Snapshot:Build(characters).errors,0,"consumer accepts all sources")
local revision=result.revision
Equal(Todo.ActionActivities:Query(request).revision,revision,"read-only query stable")
result.data.tasks[1].title="tampered"
Equal(Todo.ActionActivities:Query(request).data.tasks[1].title=="tampered",false,"result isolation")
local special=Todo.Providers.Registry:Get("special-activity")
assert(special:RecordTurnIn("C",31443))
result=Refresh()
Equal(Find(Todo.ActionActivities:Query({scope={characterIDs={"C"}}}),"mop.nat-pagle.flying-tiger-gourami").state,"completed","individual fish turn-in")
assert(special:RecordTurnIn("D",31752))
result=Refresh()
Equal(Find(result,"mop.brilltron-4000").state,"completed","account completion shared")
local view=Hub.Snapshot:Build(characters)
for _,task in ipairs(view.tasks) do Equal(task.itemKey:find("mop.brilltron-4000",1,true)==nil,true,"completed account absent") end
local oldCycle=Find(result,"mop.darkmoon-faire.29520").temporal.cycleKey
clock=clock+4*86400
result=Refresh()
Equal(Find(result,"mop.darkmoon-faire.29520").temporal.cycleKey~=oldCycle,true,"source Thursday cycle reused")
Equal(Find(result,"mop.brilltron-4000").state,"active","account daily reset")
C_Calendar.GetNumDayEvents=function() return 0 end
result=Refresh()
Equal(Find(result,"mop.darkmoon-faire.29520"),nil,"closed event omitted")
disabled["nat-pagle"],disabled["cooking-daily"],disabled["jewelcrafting-daily"]=true,true,true
result=Refresh()
Equal(Find(result,"mop.nat-pagle.spinefish-alpha"),nil,"monitoring group off")
Equal(Find(result,"ctm.cooking-daily"),nil,"daily group off")
disabled["mop.tailoring.imperial-silk"]=true
Refresh()
Equal(Find(Todo.ActionTodo:Query(request),"mop.tailoring.imperial-silk"),nil,"individual cooldown off")
local farm=Todo.Providers.Registry:Get("farm-operation-observation")
C_Map={GetBestMapForUnit=function() return 376 end}
assert(farm:RecordSucceededCast("player","plant",139977))
result=Refresh()
Equal(Find(result,"mop.farm.operation-observed").state,"completed","farm same-day source projection")
clock=clock+86400
result=Refresh()
Equal(Find(result,"mop.farm.operation-observed").readiness,"actionable","previous planting ready next day")
-- Exercise every active profession group against its real catalog recipe.
for groupID, group in pairs(Todo.Catalog.groups) do
    if group.active then
        disabled[groupID] = nil
        domains.F.data.primaryProfessions = {{id=group.professionID, skillLevel=600}}
        local recipe
        for _, entry in pairs(Todo.Catalog.recipes) do
            if entry.catalogEnabled and entry.cooldownGroupID == groupID then recipe=entry; break end
        end
        if recipe and recipe.recipeSpellID then
            local record=Todo.Database:GetProvider("F","profession-cooldown",true)
            record.observations[groupID]={sourceState="known",observedAt=clock,
                recipes={[recipe.recipeSpellID]={learned=true,craftable=true,cooldownKnown=true,readyAt=0}}}
            Refresh()
            local task=Find(Todo.ActionTodo:Query({scope={characterIDs={"F"}}}),groupID)
            Equal(task~=nil,true,"all profession groups "..groupID)
            Equal(task.readiness,"preparation","no invented materials "..groupID)
            Equal(task.title,Todo.Snapshot:GetCharacter("F").activities[groupID].label,"correct profession title")
            if task.item then
                Equal(task.item.itemID,Todo.Snapshot:GetCharacter("F").activities[groupID].icon,"source result icon")
            end
        end
    end
end
Todo.ActionContracts:Shutdown()
local checkAPI=Core.CheckAPIVersion
Core.CheckAPIVersion=function() return false end
Equal(Todo.ActionContracts:Initialize(),nil,"old Core stops optional integration")
Equal(#Hub.Contracts.list,0,"old Core has no partial providers")
Core.CheckAPIVersion=checkAPI
assert(Todo.ActionContracts:Initialize())
Todo.ActionContracts:Shutdown()
Equal(#Hub.Contracts.list,0,"all sources unregister")
assert(Todo.ActionContracts:Initialize())
Equal(#Hub.Contracts.list,3,"all sources re-register")
print("TodoSourcesSpec: "..checks.." checks passed")
