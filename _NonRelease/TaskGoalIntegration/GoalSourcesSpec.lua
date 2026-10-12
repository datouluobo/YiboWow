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
dofile("YiboTaskHub/Locales/zh.lua")
dofile("YiboTaskHub/Locales/en.lua")
assert(loadfile("YiboTaskHub/Namespace.lua"))("YiboTaskHub", {})
local Hub = YiboTaskHub
for _, name in ipairs({ "Database", "Goals", "BossTargets", "Snapshot", "Contracts", "GoalContracts" }) do dofile("YiboTaskHub/" .. name .. ".lua") end
Hub.Core = Core
assert(Core:RegisterAddon(Hub.NAME, { version = "test", requiredAPI = 12 }))
assert(Core:RegisterAddon("Spec", { version = "test", requiredAPI = 12 }))
Hub.GoalEditor = { Locate = function(_, id) Hub.located = id; return true end, Configure = function(_, intent) Hub.configuring = intent; return true end }
assert(Hub.Database:Initialize()); assert(Hub.Goals:Initialize()); Hub.Contracts:Initialize()

local function Register(owner) assert(Core:RegisterAddon(owner, { requiredAPI = 12 })) end
Register("YiboTodo")
dofile("YiboTodo/Namespace.lua")
for _, file in ipairs({ "Database", "Catalog/ActivityCatalog", "Catalog/CooldownGroupCatalog", "Catalog/CooldownCatalog_MoP", "Catalog/Ruleset_50504", "Catalog/DailyActivityCatalog_MoP", "Catalog/Validator", "Model/Schedule", "Model/State", "Providers/Registry", "Providers/DailyQuest", "Model/Snapshot", "ActionTodo", "ActionNomi", "ActionActivities", "GoalTargets" }) do dofile("YiboTodo/" .. file .. ".lua") end
local Todo = YiboTodo; Todo.Core = Core; Todo.Database:Initialize(); Todo:ValidateCatalog()
Todo.Settings = { IsMonitoringItemEnabled = function() return false end, IsMonitoringGroupEnabled = function() return false end }
local record = Todo.Database:GetProvider("C", "profession-cooldown", true)
record.state, record.lastSuccessAt = "known", clock
record.observations[Todo.ActionTodo.GROUP] = { sourceState = "known", observedAt = clock, recipes = { [143011] = { learned = true, craftable = true, cooldownKnown = true, readyAt = 0 } } }
assert(Todo.GoalTargets:Initialize())
local intent = Todo.GoalTargets:Intent({ groupID = Todo.ActionTodo.GROUP }, "C")
local goal = assert(Hub.Goals:Add(intent))
Equal(Hub.Snapshot:Build(characters).current[1].task.readiness, "preparation", "Todo hidden monitoring queried exactly")
local oldBuild = Todo.Snapshot.Build; Todo.Snapshot.Build = function() error("full scan forbidden") end
Hub.Contracts:Invalidate(); Equal(Hub.Snapshot:Build(characters).uniqueCount, 1, "Todo does not call account Build")
record.observations[Todo.ActionTodo.GROUP].recipes[143011].readyAt = clock + 600
Hub.Contracts:Invalidate(); Equal(Hub.Snapshot:Build(characters).uniqueCount, 0, "cooldown completes this cycle")
Equal(#Hub.db.goals.byID[goal.id].history, 1)
Todo.Snapshot.Build = oldBuild
dofile("YiboTodo/Catalog/FarmOperationCatalog.lua")
dofile("YiboTodo/Providers/FarmOperationObservation.lua")
local farmID = "mop.farm.operation-observed"
local farmIntent = Todo.GoalTargets:Intent({ groupID = farmID }, "C")
local farmGoal = assert(Hub.Goals:Add(farmIntent))
Equal(Hub.Goals:Lookup(farmIntent).id, farmGoal.id, "farm can be added and queried")
local function FarmTask()
    return Todo.GoalTargets:Evaluate({ goals = { { id = farmGoal.id, intent = farmIntent } } }).evaluations[farmGoal.id].task
end
Equal(FarmTask(), nil, "farm without observation stays unverified")
local farmRecord = Todo.Database:GetProvider("C", "farm-operation-observation", true)
local serverDay = Todo.Model.Schedule:ServerDay(clock, 7)
farmRecord.days = { [serverDay] = { observedAt = clock, nextResetAt = clock + 60, operations = { { kind = "plant" } } } }
Equal(FarmTask().state, "completed", "farm uses source planting projection")
Equal(FarmTask().freshness.state, "known", "farm observation has completion evidence")
clock = clock + 61; hour, minute = 7, 1
Equal(FarmTask().readiness, "actionable", "farm reset restores harvest work")
farmIntent.scope.characterID = "D"
Equal(FarmTask(), nil, "farm observation does not cross characters")
farmIntent.scope.characterID = "C"
local savedFarm = Hub.db.goals.byID[farmGoal.id]
assert(Hub.Goals:Update(farmGoal.id, savedFarm.revision, { state = "removed" }))
local coreVersion = Core.API_VERSION; Core.API_VERSION = 11; Todo.GoalTargets.ref = nil
Equal(Todo.GoalTargets:Initialize(), nil, "old Core stops new enhancement"); Core.API_VERSION = coreVersion
-- Inventory's evaluator is tested with its authoritative query boundary.
Register("YiboVault")
local quantity, covered = 3, true
YiboVault = { NAME = "YiboVault", Core = Core, db = {}, Copy = function(v) return Core.Defaults:Copy(v) end, Now = function() return clock end, Print = function() end }
YiboVault.Items = { GetRevision = function() return 1 end, Query = function(_, options)
    local coverage = {}; for _, source in ipairs(options.sources) do coverage[source] = {}; for _, id in ipairs(options.scope.characterIDs) do local locations = {}
        if covered then
            if source == "bags" then for bagID = 0, 4 do locations[tostring(bagID)] = { status = "known", observedAt = clock, completedScan = true } end
            else locations[source == "mail" and "inbox" or source] = { status = "known", observedAt = clock, completedScan = true } end
        end
        coverage[source][id] = { locations = locations } end end
    return { coverage = coverage, totals = { totalQuantity = quantity } }
end }
dofile("YiboVault/GoalTargets.lua"); local Vault = YiboVault.GoalTargets; assert(Vault:Initialize())
local vi = { providerID = Vault.PROVIDER, objectID = 123, scope = { mode = "character", characterID = "C" }, conditions = { quantity = 5, storage = "bags", mode = "maintain", scopeMode = "character" } }
local vg = assert(Hub.Goals:Add(vi))
local function Task(id) for _, t in ipairs(Hub.Snapshot:Build(characters).tasks) do if t.goalID == id then return t end end end
Equal(Task(vg.id).readiness, "actionable", "confirmed shortage")
covered = false; Hub.Contracts:Invalidate(Vault.PROVIDER); Equal(Task(vg.id).readiness, "unknown", "partial coverage not zero")
covered, quantity = true, 5; Hub.Contracts:Invalidate(Vault.PROVIDER); Equal(Task(vg.id), nil, "maintain enough quiet")
quantity = 1; Hub.Contracts:Invalidate(Vault.PROVIDER); Equal(Task(vg.id).readiness, "actionable", "maintain drops reopens")
vi.scope = { mode = "character", characterID = "C" }; vi.conditions.scopeMode = "account"
local normalized = assert(Vault:Normalize({ intent = vi })); Equal(normalized.intent.scope.mode, "account"); Equal(#normalized.intent.scope.characterIDs, 4, "account saved explicit roster")
Equal(Vault:Normalize({ intent = { objectID = 123, conditions = {}, scope = { mode = "character", characterID = "C" } } }).needsConfiguration, true)
-- Reputation owns the interpretation of Core's public reputation snapshots.
Register("YiboReputation")
YiboReputation = { db = {}, EnsureDB = function(self) return self.db end, GetFactionName = function(_, id) return "Faction " .. id end,
 GetFactionData = function(_, snapshot, id) return snapshot and snapshot.data.factions[id] end, GetFriendship = function(_, data) return data.friendship end,
 FormatReputation = function(_, data) return tostring(data.standingID) end }
local repRank, repState = 6, "known"
local domainGet = Core.DataDomains.Get
Core.DataDomains.Get = function(_, id, domain) if domain == "reputation" then return { schemaVersion = 5, state = repState, updatedAt = clock, data = { contractVersion = 1, factions = { [1] = { standingID = repRank } } } } end; return domainGet(nil,id,domain) end
dofile("YiboReputation/GoalTargets.lua"); local Rep = YiboReputation.GoalTargets; assert(Rep:Initialize())
local rg = assert(Hub.Goals:Add({ providerID = Rep.PROVIDER, objectID = 1, scope = { characterID = "C" }, conditions = { rank = 8 } }))
Equal(Task(rg.id).readiness, "actionable")
repRank, repState = 8, "stale"; Hub.Contracts:Invalidate(Rep.PROVIDER); Equal(Task(rg.id).readiness, "unknown", "stale exalted cannot complete")
repState = "known"; Hub.Contracts:Invalidate(Rep.PROVIDER); Equal(Task(rg.id), nil); Equal(Hub.db.goals.byID[rg.id].state, "completed")
-- Crafting keeps cast facts separate from inventory changes.
for _, id in ipairs({ "C", "D" }) do domains[id].data.professions = { { id = 197 } } end
Register("YiboCrafting")
for _, id in ipairs({ "C", "D" }) do domains[id].data.professions = { { id = 197 } } end
YiboCrafting = { NAME = "YiboCrafting", RecipeCatalog = { professions = { [197] = { [100] = { outputItemIDs = { 123 } } } } },
 Store = { db = {}, GetRecipeState = function() return "learned" end } }
dofile("YiboCrafting/Locales/Targets.lua")
dofile("YiboCrafting/GoalTargets.lua"); local Craft = YiboCrafting.GoalTargets; assert(Craft:Initialize())
local ci = { providerID = Craft.PROVIDER, objectID = 100, scope = { characterID = "C" }, conditions = { professionID = 197, outputItemID = 123, mode = "craft-times", quantity = 2 } }
local cg = assert(Hub.Goals:Add(ci))
Equal(Task(cg.id).readiness, "preparation")
quantity = 100; Hub.Contracts:Invalidate(Craft.PROVIDER); Equal(Hub.db.goals.byID[cg.id].state, "active", "stock cannot prove manufacturing")
Craft.frame.scripts.OnEvent(nil,"UNIT_SPELLCAST_SUCCEEDED","player","cast1",100)
Equal(Task(cg.id).state, "active", "one of two crafts")
Craft.frame.scripts.OnEvent(nil,"UNIT_SPELLCAST_SUCCEEDED","player","cast2",100)
Equal(Task(cg.id), nil, "actual two crafts complete")
local completedCraft = Hub.db.goals.byID[cg.id]
assert(Hub.Goals:Update(cg.id, completedCraft.revision, { state = "active", reopen = true }))
Equal(Task(cg.id).state, "active", "restart uses a new craft baseline")
Equal(Hub.db.goals.byID[cg.id].intent.conditions.startCount, 2)
local copiedCraft = assert(Hub.Goals:PreviewCopy({ cg.id }, { "D" }))
assert(Hub.Goals:ApplyCopy(copiedCraft.token))
local copiedIntent = Core.Defaults:Copy(ci); copiedIntent.scope.characterID = "D"
local copied = Hub.Goals:Lookup(copiedIntent)
Equal(Hub.db.goals.byID[copied.id].intent.conditions.startCount, 0, "copy resets manufacturing baseline")
-- Shared profession goals project to every eligible character, but never sum casts.
local sharedIntent = Core.Defaults:Copy(ci)
sharedIntent.scope = { mode = "account" }; sharedIntent.conditions.executorMode = "any"
sharedIntent.conditions.quantity = 3
local sharedNormalized = assert(Craft:Normalize({ intent = sharedIntent }))
Equal(#sharedNormalized.intent.scope.characterIDs, 2, "only confirmed profession characters")
Equal(sharedNormalized.managesExecutionScope, true, "provider owns execution selector")
Equal(sharedNormalized.needsCharacter, false, "shared target needs no fixed character")
local sharedGoal = assert(Hub.Goals:Add(sharedIntent))
local craftCounts = YiboCrafting.Store.db.goalCraftCounts
craftCounts.C[100] = craftCounts.C[100] + 2; craftCounts.D = { [100] = 2 }
local function SharedTask()
    return Craft:Evaluate({ goals = { Hub.db.goals.byID[sharedGoal.id] } }).evaluations[sharedGoal.id].task
end
Equal(SharedTask().state, "active", "two plus two does not satisfy three")
Equal(SharedTask().execution.mode, "account", "one goal shared across roles")
craftCounts.D[100] = 3
Equal(SharedTask().state, "completed", "one role independently completes shared goal")
Hub.Contracts:Invalidate(Craft.PROVIDER); Task(sharedGoal.id)
Equal(Hub.db.goals.byID[sharedGoal.id].state, "completed", "global completion persisted once")
-- The item path queries each role independently through the public inventory provider.
local vaultEvaluate = YiboVault.GoalTargets.Evaluate
local stock = { C = 2, D = 2 }
YiboVault.GoalTargets.Evaluate = function(_, request)
    local goal = request.goals[1]; local n = stock[goal.intent.scope.characterID] or 0
    return { evaluations = { [goal.id] = { task = { state = n >= 3 and "completed" or "active",
        freshness = { state = "known", observedAt = clock }, item = { quantity = n } } } } }
end
local holdingIntent = Core.Defaults:Copy(sharedIntent); holdingIntent.conditions.mode = "holding"
local holdingGoal = assert(Hub.Goals:Add(holdingIntent))
local function HoldingTask()
    return Craft:Evaluate({ goals = { Hub.db.goals.byID[holdingGoal.id] } }).evaluations[holdingGoal.id].task
end
Equal(HoldingTask().state, "active", "inventory is not summed across profession characters")
stock.D = 3; Equal(HoldingTask().state, "completed", "one role inventory completes product target")
YiboVault.GoalTargets.Evaluate = function(_, request)
    return {evaluations={[request.goals[1].id]={task={state="completed",
        freshness={state="known",observedAt=clock-10,validUntil=clock-1},item={quantity=3}}}}}
end
Equal(HoldingTask().state,"active","expired inventory evidence cannot complete a crafting product goal")
Equal(HoldingTask().readiness,"unknown","expired public source evidence stays unknown")
YiboVault.GoalTargets.Evaluate = vaultEvaluate
local recipeState = YiboCrafting.Store.GetRecipeState
YiboCrafting.Store.GetRecipeState = function() return "unlearned" end
local cell = Frame()
Craft:Bind(cell, { id = 100, professionID = 197, name = "测试配方", outputItemID = 123 }, "C")
Equal(Core.BusinessItemActions.bindings[cell], nil, "unlearned matrix cell cannot add")
YiboCrafting.Store.GetRecipeState = function() return "unknown" end
Craft:Bind(cell, { id = 100, professionID = 197, name = "测试配方", outputItemID = 123 }, "C")
Equal(Core.BusinessItemActions.bindings[cell], nil, "unknown matrix cell cannot add")
YiboCrafting.Store.GetRecipeState = recipeState
Craft:Bind(cell, { id = 100, professionID = 197, name = "测试配方", outputItemID = 123 }, "C")
Equal(Core.BusinessItemActions.bindings[cell].GetIntent().conditions.executorMode, "character", "learned cell targets chosen role")
Craft:Bind(cell, { id = 100, professionID = 197, name = "测试配方", outputItemID = 123 }, nil, nil, true, true)
Equal(Core.BusinessItemActions.bindings[cell].GetIntent().conditions.mode, "holding", "product icon creates holding target")
Equal(Core.BusinessItemActions.bindings[cell].GetIntent().conditions.executorMode, "any", "product defaults to shared profession scope")
Equal(Core.BusinessItemActions.bindings[cell].GetIntent().conditions.quantity, 1, "product defaults to one item")
local defaultIntent = Core.Defaults:Copy(Core.BusinessItemActions.bindings[cell].GetIntent())
local defaultNormalized = assert(Craft:Normalize({ intent = defaultIntent }))
Equal(defaultNormalized.needsConfiguration, nil, "single-output product can be added immediately")
Core.BusinessItemActions:SetOptions({mode="middle"})
YiboCrafting.RecipeCatalog.professions[197][101] = {outputItemIDs={123}}
Craft:Bind(cell, { id = 101, professionID = 197, name = "测试配方", outputItemID = 123 }, nil, nil, true, true)
local goalsBefore = #Hub.Goals:List()
cell.scripts.OnClick(cell, "MiddleButton")
Equal(#Hub.Goals:List(), goalsBefore + 1, "middle click saves one default product goal without editor")
Craft:Bind(cell, { id = 100, professionID = 197, name = "测试配方", outputItemID = 123 }, "C")
local castDefault = assert(Craft:Normalize({intent=Core.BusinessItemActions.bindings[cell].GetIntent()}))
Equal(castDefault.intent.conditions.quantity, 1, "learned cell defaults to one craft")
Equal(castDefault.intent.scope.characterID, "C", "default craft preserves selected role")
local minAPI = Core.CheckAPIVersion
Core.CheckAPIVersion = function() return false end
local existingRef = Craft.ref; Craft.ref = nil
Equal(Craft:Initialize(), nil, "old Core stops localized target initialization")
Craft.ref, Core.CheckAPIVersion = existingRef, minAPI
local oldLanguage = Core.Locale.previewLanguage
Core.Locale.previewLanguage = "en"
local english = assert(Craft:Normalize({intent=Core.BusinessItemActions.bindings[cell].GetIntent()}))
Equal(english.fields[1].label, "Execution scope", "target controls use owner English resources")
Equal(english.title:find("Craft 1", 1, true) ~= nil, true, "English target title formatting")
Core.Locale.previewLanguage = "zh"
local chinese = assert(Craft:Normalize({intent=Core.BusinessItemActions.bindings[cell].GetIntent()}))
Equal(chinese.fields[1].label, "执行范围", "target controls use owner Chinese resources")
Core.Locale.previewLanguage = oldLanguage
YiboCrafting.RecipeCatalog.professions[197][102]={outputItemIDs={123,124}}
Craft:Bind(cell, {id=102,professionID=197,name="多产物配方"}, nil)
Hub.configuring=nil
cell.scripts.OnClick(cell,"MiddleButton")
Equal(Hub.configuring and Hub.configuring.objectID,102,"ambiguous product opens configuration immediately")
Core.BusinessItemActions:Unbind(cell)
-- Builds only completes the same concrete equipment instance.
Register("YiboBuilds")
local equip = { itemID = 555, instanceKey = "instance:A", gems = { { itemID = 123, state = "uninstalled" } } }
YiboBuilds = { NAME = "YiboBuilds", Core = Core, db = {}, Now = function() return clock end, Print = function() end,
 EnsureDB = function(self) return self.db end, EnchantCatalog = {}, AccountPage = { IsGoalTargetApplicable = function() return true end },
 Snapshot = { GetCharacter = function() return { slots = { primary = { observedEquipment = { capturedAt = clock, slots = { ["1"] = equip } } } } } end } }
dofile("YiboBuilds/GoalTargets.lua"); local Builds = YiboBuilds.GoalTargets; assert(Builds:Initialize())
local bi = { providerID = Builds.PROVIDER, scope = { characterID = "C" }, conditions = { buildSlot = "primary", slotID = 1, itemID = 555, instanceKey = "instance:A", kind = "gem", enhancementID = 123, socketIndex = 1 } }
local bg = assert(Hub.Goals:Add(bi)); Equal(Task(bg.id).readiness, "actionable", "owned gem not applied")
equip.gems[1].state = "installed"; Hub.Contracts:Invalidate(Builds.PROVIDER); Equal(Task(bg.id), nil); Equal(Hub.db.goals.byID[bg.id].state, "completed")
bi.conditions.enhancementID = 124; local swapped = assert(Hub.Goals:Add(bi)); equip.instanceKey = "instance:B"
Hub.Contracts:Invalidate(Builds.PROVIDER); Task(swapped.id); Equal(Hub.db.goals.byID[swapped.id].state, "paused", "equipment replacement pauses")
bi.conditions.enhancementID, bi.conditions.instanceKey = 125, nil; local unknown = assert(Hub.Goals:Add(bi))
Equal(Task(unknown.id).readiness, "unknown", "unknown instance not inferred")
-- Remaining business providers keep their own completion interpretation.
Register("YiboCurrency")
local balance, balanceState = 3, "known"
YiboCurrency = { NAME="YiboCurrency", Core=Core, db={}, EnsureDB=function(self)return self.db end,
 GetCatalog=function()return {{id="money",title="金币",source="money"}}end,
 GetValue=function()return {quantity=balance},balanceState end }
dofile("YiboCurrency/GoalTargets.lua"); local Currency=YiboCurrency.GoalTargets;assert(Currency:Initialize())
local money=assert(Hub.Goals:Add({providerID=Currency.PROVIDER,objectID="money",scope={characterID="C"},conditions={quantity=5,mode="maintain"}}))
Equal(Task(money.id).readiness,"actionable"); balanceState="stale";balance=10;Hub.Contracts:Invalidate(Currency.PROVIDER)
Equal(Task(money.id).readiness,"unknown","stale money cannot satisfy")
balanceState="known";Hub.Contracts:Invalidate(Currency.PROVIDER);Equal(Task(money.id),nil)
balance=2;Hub.Contracts:Invalidate(Currency.PROVIDER);Equal(Task(money.id).state,"active","money falls below maintained threshold")
Register("YiboLegendary")
local legendaryState={status="completed",acquired=true,evidence={source="projection",updatedAt=clock}}
YiboLegendary={NAME="YiboLegendary",Core=Core,db={byCharacter={C={snapshot={targets={cloak=legendaryState}}}}},
 GetTimestamp=function()return clock end,Catalog={GetTarget=function(_,id)if id=="cloak" then return{id=id,title="披风"}end end}}
dofile("YiboLegendary/GoalTargets.lua");local Legendary=YiboLegendary.GoalTargets;assert(Legendary:Initialize())
local lg=assert(Hub.Goals:Add({providerID=Legendary.PROVIDER,objectID="cloak",scope={characterID="C"}}))
Equal(Task(lg.id).readiness,"unknown","projection is not completion evidence")
legendaryState.evidence.source="real";Hub.Contracts:Invalidate(Legendary.PROVIDER);Equal(Task(lg.id),nil)
Register("YiboMail")
local mailKnown=false
YiboMail={NAME="YiboMail",Core=Core,db={},Now=function()return clock end,ActionTodo={
 Metadata=function()return{revision=1}end,Query=function()return{coverage={C={state=mailKnown and "known-empty" or "not-yet-scanned"}},data={tasks={}}}end}}
dofile("YiboMail/GoalTargets.lua");local Mail=YiboMail.GoalTargets;assert(Mail:Initialize())
local mg=assert(Hub.Goals:Add({providerID=Mail.PROVIDER,objectID="view-mailbox",scope={characterID="C"}}))
Equal(Task(mg.id).readiness,"unknown","unobserved mailbox is not empty")
mailKnown=true;Hub.Contracts:Invalidate(Mail.PROVIDER);Equal(Task(mg.id),nil)
-- Actual Items resolver: personal explicit scopes need lightweight identity only.
local previousItems, oldGet, oldAll = YiboVault.Items, Core.Characters.Get, Core.Characters.GetAll
local identityReads=0
Core.Characters.Get=function(self,id,options)Equal(options.identityOnly,true);identityReads=identityReads+1;return oldGet(self,id)end
Core.Characters.GetAll=function()error("must not enumerate full character domains")end
dofile("YiboVault/Items.lua")
local resolved=YiboVault.Items._ResolveCharacters({mode="characters",characterIDs={"C","D","C"}},true)
Equal(#resolved,2);Equal(identityReads,2,"explicit duplicate IDs read once")
Core.Characters.Get,Core.Characters.GetAll,YiboVault.Items=oldGet,oldAll,previousItems
print("GoalSourcesSpec: " .. checks .. " checks passed")
