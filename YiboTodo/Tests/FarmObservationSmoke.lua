_G.YiboTodo = nil
GetServerTime = function() return 1725105600 end
time = GetServerTime
GetGameTime = function() return 12, 0 end
date = function(format) if format == "%Y-%m-%d" then return "2024-09-01" end return "" end
C_Map = { GetBestMapForUnit = function() return 376 end }
UnitName = function() return "生长中的毒蛇荆" end
UnitGUID = function() return "Creature-0-4891-870-6013-65973-0000000001" end
GetSpellInfo = function(spellID)
    return ({
        [900001] = "播种翠玉白菜种子",
        [900002] = "购买种子包（4块地）",
        [900003] = "兑换种子包",
    })[tonumber(spellID)]
end

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
assert(provider:ResolveRule(129883).plantType == "single", "known single-seed spell is classified")
assert(provider:ResolveRule(900001).plantType == "single", "single-seed spell is inferred")
assert(provider:ResolveRule(900002).plantType == "bundle", "direct seed bundle spell is inferred")
assert(provider:ResolveRule(900003).plantType == "bundle", "30-seed exchange package is normalized to bundle")
assert(provider:ResolveRule(111108).kind == "operate", "watering-can spell is tracked by spell ID")
assert(provider:ResolveRule(115481).kind == "operate", "pesticide spell is tracked by spell ID")
assert(provider:ResolveRule(6478).kind == "operate", "farm-object activation spell is tracked")
assert(provider:ResolveRule(139977).plantType == "bundle", "snake-root seed bundle spell is tracked")
assert(provider:ResolveRule(139981).plantType == "bundle", "magic bulb seed bundle spell is tracked")
assert(provider:ResolveRule(116356).plantType == "bundle", "green cabbage seed bundle spell is tracked")
assert(provider:ResolveRule(139983).plantType == "bundle", "wind-shear cactus bundle spell is tracked")
assert(provider:ResolveRule(139975).plantType == "bundle", "joy-singing bell bundle spell is tracked")
assert(provider:ResolveRule(139978).plantType == "bundle", "mysterious seed bundle spell is tracked")
assert(provider:ResolveRule(131095).plantType == "bundle", "gourd bundle spell is tracked")
assert(provider:ResolveRule(139986).plantType == "bundle", "carnivorous plant bundle spell is tracked")
assert(provider:ResolveRule(131093).plantType == "bundle", "witchberry bundle spell is tracked")
assert(provider:ResolveRule(131094).plantType == "bundle", "jade squash bundle spell is tracked")
assert(provider:ResolveRule(123567).plantType == "bundle", "white turnip bundle spell is tracked")
assert(provider:ResolveRule(123566).plantType == "bundle", "pink turnip bundle spell is tracked")
assert(provider:ResolveRule(123486).plantType == "bundle", "mogu pumpkin bundle spell is tracked")
assert(provider:ResolveRule(123537).plantType == "bundle", "red chive bundle spell is tracked")
assert(provider:ResolveRule(123362).plantType == "bundle", "juicycrunch carrot package spell is tracked")
assert(provider:ResolveRule(123389).plantType == "bundle", "scallion bundle spell is tracked")
for _, spellID in ipairs({ 111102, 123388, 123485, 123568, 129974 }) do
    assert(provider:ResolveRule(spellID).plantType == "single", "new single-seed spell is tracked: " .. spellID)
end
for _, spellID in ipairs({ 123361, 123535, 123565, 129978 }) do
    assert(provider:ResolveRule(spellID).plantType == "single", "previously observed single-seed spell is tracked: " .. spellID)
end
for _, spellID in ipairs({ 123773, 123774, 123775, 129623, 129628, 129863, 129976, 133036 }) do
    assert(provider:ResolveRule(spellID).plantType == "single", "observed single-seed spell is tracked: " .. spellID)
end
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

-- A growing-crop mouseover is the only signal available for some characters.
-- Once that observation expires into the next server day, it still proves the
-- farm is ready to harvest and must not collapse to an empty cell.
local record = Addon.Database:GetProvider("farm-character", "farm-operation-observation", false)
record.days = {
    previous = {
        observedAt = Addon:Now() - 86400,
        nextResetAt = Addon:Now() - 1,
        operations = { { kind = "growing", label = "生长中的毒蛇荆" } },
    },
}
Addon.Snapshot:Invalidate()
character = assert(Addon.Snapshot:GetCharacter("farm-character"))
assert(#character.farmProjects == 1 and character.farmProjects[1].state == "actionable", "a previous growing observation becomes harvest-ready after reset")

print("YiboTodo farm observation smoke passed")
