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
dofile("YiboCore/Runtime/Events.lua")
dofile("YiboCore/Runtime/Registry.lua")
dofile("YiboCore/Runtime/Contracts.lua")
dofile("YiboCore/UI/Theme.lua")
dofile("YiboCore/Runtime/ItemResolver.lua")
local Core = YiboCore
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
for _, name in ipairs({ "Database", "Common/Goals", "BossTargets", "Snapshot", "Contracts", "GoalContracts" }) do dofile("YiboTaskHub/" .. name .. ".lua") end
Hub.Core = Core
assert(Core:RegisterAddon(Hub.NAME, { version = "test", requiredAPI = 12 }))
assert(Core:RegisterAddon("Spec", { version = "test", requiredAPI = 12 }))
Hub.GoalEditor = { Locate = function(_, id) Hub.located = id; return true end, Configure = function(_, intent) Hub.configuring = intent; return true end }
assert(Hub.Database:Initialize()); assert(Hub.Goals:Initialize()); Hub.Contracts:Initialize()


local calls=0
local def={name="action.targets",kind="provider",providerID="Spec:surfaces",version={major=1,minor=0},methods={
 Normalize=function(r)local i=Core.Defaults:Copy(r.intent);i.repeatPolicy="recurring";return{intent=i,identity=i.objectID..":"..i.scope.characterID,title=i.objectID}end,
 Evaluate=function(r)calls=calls+1;local result={sourceEpoch="surface:1",revision=1,sourceTitle="Source",evaluations={}}
 for _,g in ipairs(r.goals)do local id=g.intent.scope.characterID;result.evaluations[g.id]={task={title=g.title,state="active",readiness="actionable",
 execution={mode="self",characterID=id},beneficiary={mode="character",characterID=id},temporal={kind="persistent"},freshness={state="known",observedAt=clock}}}end;return result end}}
assert(Core.Contracts:Register("Spec",def))
local function Add(id)return assert(Hub.Goals:Add({providerID=def.providerID,objectID="work",scope={mode="character",characterID=id}}))end
local a,b=Add("C"),Add("D")
for _,name in ipairs({"Presentation","Preview","AccountPage","HUD","Reminders","Settings"})do dofile("YiboTaskHub/"..name..".lua")end
Hub.CoreIntegration={page={}};UIParent=CreateFrame("Frame");UIParent:SetSize(1280,720)
local printed=0;Hub.Print=function()printed=printed+1 end
local value=Hub.Snapshot:Build(characters)
Equal(value.uniqueCount,2);Equal(#Hub.AccountPage:Filter(value),2)
local preview=Hub.Preview:Build({characters=characters});Equal(#preview.rows,2,"preview uses added goals")
local current,counts=Hub.Presentation:Current();Equal(#counts.rows,1);Equal(counts.rows[1].task.goalID,a.id)
Hub.HUD:Refresh(current,counts,0);Equal(Hub.HUD.frame.rows[1].row.task.goalID,a.id,"HUD same goal")
Hub.Reminders:Start("C");Hub.Reminders:Update(current,counts);Equal(printed,1,"login reminder same snapshot")
Hub.Preview:Build({characters=characters});Hub.Presentation:Current();Equal(calls,2,"four surfaces reuse full/current caches")
Hub.Displays = { ScheduleRefresh = function() end }
assert(Hub.Settings:Set("showOtherCharacters", false))
Equal(#Hub.AccountPage:Filter(value),1,"hide other roles in overview")
Equal(#Hub.Preview:Build({characters=characters}).rows,1,"same role switch in hover")
Equal(#Hub.Goals:List(),2,"hide does not change saved goals")
Equal(#Hub.Settings:GetDisplayCharacters(characters),1,"UI scope avoids querying hidden roles")
local accountRow = Core.Defaults:Copy(value.others[1]); accountRow.task.execution.mode = "account"
local accountValue = {sources=value.sources,current={},others={accountRow,Core.Defaults:Copy(accountRow)}}
Equal(#Hub.AccountPage:Filter(accountValue),1,"account target remains once without current-role candidate")
assert(Hub.Settings:Set("showOtherCharacters", true))
Equal(#Hub.Preview:Build({characters=characters}).rows,2,"restore other roles")
Equal(calls,2,"display preference retains goal caches")
-- Exercise the actual management controls, including the shared role preference.
dofile("YiboTaskHub/GoalEditor.lua")
local editor, management = Hub.GoalEditor, CreateFrame("Frame")
editor.Create(management); editor.Refresh(management,{characters=characters})
Equal(management.rows[2].shown,true,"management shows other role by default")
Equal(management.previous.enabled,false,"first page cannot go backwards")
management:SetHeight(266);editor.Refresh(management,{characters=characters})
Equal(editor.capacity,2,"short management uses available row capacity")
Equal(management.next.enabled,false,"last page cannot go forward")
management:SetHeight(420)
assert(Hub.Settings:Set("showOtherCharacters",false));editor.Refresh(management,{characters=characters})
Equal(management.rows[2].shown,false,"management hides other role")
editor:Locate(b.id);Equal(editor.message ~= nil,true,"locating hidden goal explains preference")
assert(Hub.Settings:Set("showOtherCharacters",true));editor.message=nil
editor.roleID="D";editor.Refresh(management,{characters=characters})
Equal(management.rows[1].goal.id,b.id,"management role filter uses stable ID")
editor.roleID=nil
local entryDef={name="action.targets",kind="provider",providerID="Spec:entry",version={major=1,minor=1},methods={GetEntry=function()return{title="测试来源",pageID="source-page"}end}}
assert(Core.Contracts:Register("Spec",entryDef));Equal(#editor:Entries(),1,"entry picker discovers compatible sources")
management.add.scripts.OnClick();editor.Refresh(management,{characters=characters})
Equal(management.addControls.shown,true,"add entry opens picker")
management.addControls.buttons[1].scripts.OnClick();Equal(Core.lastPage,"source-page","picker opens registered business page")
editor.adding=nil;editor.Refresh(management,{characters=characters})
Equal(management.addControls.shown,false,"picker closes after choosing source")
Hub.Goals:Update(b.id,Hub.db.goals.byID[b.id].revision,{state="removed"})
Equal(#Hub.Preview:Build({characters=characters}).rows,1,"removal reflected in preview")
Hub.Goals:Update(a.id,Hub.db.goals.byID[a.id].revision,{state="removed"})
local before=calls;value=Hub.Snapshot:Build(characters);Equal(value.uniqueCount,0);Equal(calls,before,"empty queries no source")
current,counts=Hub.Presentation:Current();Hub.Reminders:Start("C");Hub.Reminders:Update(current,counts);Equal(printed,1,"empty login stays quiet")
print("GoalSurfacesSpec: "..checks.." checks passed")
