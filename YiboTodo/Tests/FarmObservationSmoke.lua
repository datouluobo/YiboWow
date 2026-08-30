_G.YiboTodo = nil
GetServerTime = function() return 1725105600 end
time = GetServerTime
GetGameTime = function() return 12, 0 end
C_Map = { GetBestMapForUnit = function() return 376 end }
UnitName = function() return "生长中的毒蛇荆" end
UnitGUID = function() return "Creature-0-4891-870-6013-65973-0000000001" end

dofile("YiboTodo/Namespace.lua")
dofile("YiboTodo/Database.lua")
dofile("YiboTodo/Catalog/ActivityCatalog.lua")
dofile("YiboTodo/Catalog/FarmOperationCatalog.lua")
dofile("YiboTodo/Catalog/Validator.lua")
dofile("YiboTodo/Model/Schedule.lua")
dofile("YiboTodo/Model/Snapshot.lua")
dofile("YiboTodo/Providers/Registry.lua")
dofile("YiboTodo/Providers/FarmOperationObservation.lua")

local Addon = _G.YiboTodo
Addon.Now = GetServerTime
_G.YiboTodoDB = {}
Addon.Database:Initialize()
Addon.Settings = { GetMode = function() return "display" end }
Addon.Core = {
    Characters = {
        GetCurrent = function() return { id = "farm-character" } end,
        GetAll = function() return { { id = "farm-character" } } end,
    },
    DataDomains = { Get = function() return nil end },
}

local provider = assert(Addon.Providers.Registry:Get("farm-operation-observation"))
assert(not provider:RecordSucceededCast("player", "cast-ignored", 1449), "non-farm spell is ignored")
assert(provider:RecordSucceededCast("player", "cast-till", 111003), "observed till is recorded")
assert(not provider:RecordSucceededCast("player", "cast-till", 111003), "cast GUID is deduplicated")
assert(provider:RecordSucceededCast("player", "cast-harvest", 129814), "observed harvest is recorded")
assert(provider:RecordGrowingMouseover(), "growing crop mouseover is recorded")
assert(not provider:RecordGrowingMouseover(), "mouseover GUID is deduplicated")

local day, definition = provider:GetCurrentDay("farm-character", Addon:Now())
assert(day and definition and definition.id == "mop.farm.operation-observed", "provider returns day and definition")
assert(#day.operations == 3, "only tracked casts and growing observations are stored")
assert(day.operations[1].kind == "till" and day.operations[2].kind == "harvest", "operation kinds persist")

Addon.Snapshot:Invalidate()
local character = assert(Addon.Snapshot:GetCharacter("farm-character"))
assert(#character.farmProjects == 1, "farm has a separate project projection")
assert(character.farmProjects[1].state == "completed" and character.farmProjects[1].operationObserved, "farm projection completes under the optimistic rule")
assert(character.summary.todo == 0, "farm observation never enters todo totals")
assert(Addon.Snapshot.nextTransitionAt == day.nextResetAt, "farm projection schedules the next 07:00 refresh")

print("YiboTodo farm observation smoke passed")
