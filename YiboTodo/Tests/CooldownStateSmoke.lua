_G.YiboTodo = nil
GetServerTime = function() return 1000 end
time = GetServerTime
GetGameTime = function() return 0, 0 end

dofile("YiboTodo/Namespace.lua")
dofile("YiboTodo/Catalog/ActivityCatalog.lua")
dofile("YiboTodo/Catalog/CooldownGroupCatalog.lua")
dofile("YiboTodo/Catalog/CooldownCatalog_MoP.lua")
dofile("YiboTodo/Catalog/Ruleset_50504.lua")
dofile("YiboTodo/Catalog/Validator.lua")
dofile("YiboTodo/Model/State.lua")
dofile("YiboTodo/Providers/Registry.lua")

local Addon = _G.YiboTodo
local State = Addon.Model.State
assert(#Addon:ValidateCatalog().errors == 0, "catalog validation")

local function Group(groupID)
    local group = Addon.Catalog.groups[groupID]
    group.members = {}
    for _, recipe in pairs(Addon.Catalog.recipes) do
        if recipe.catalogEnabled and recipe.cooldownGroupID == groupID then
            group.members[#group.members + 1] = recipe
        end
    end
    return group
end

local function Cooling(spellID, readyAt)
    return {
        sourceState = "known",
        observedAt = 1000,
        recipes = { [spellID] = { learned = true, cooldownKnown = true, readyAt = readyAt } },
    }
end

local celestial = Addon.Catalog.recipes["mop.tailoring.celestial-cloth"]
assert(celestial.recipeSpellID == 143011, "celestial-cloth spell ID")
assert(celestial.resultItemID == 98619, "celestial-cloth item ID")
assert(Addon.Catalog.recipes["mop.tailoring.imperial-silk"].resultItemID == 82447, "imperial-silk item ID")
assert(Addon.Catalog.recipes["mop.inscription.scroll-of-wisdom"].resultItemID == 79731, "scroll-of-wisdom item ID")
assert(Addon.Catalog.recipes["mop.leatherworking.magnificence-of-leather"].resultItemID == 72163, "magnificent-fur item ID")
assert(Addon.Catalog.recipes["mop.leatherworking.enhanced-magnificent-fur"].resultItemID == 98617, "enhanced-magnificent-fur item ID")
assert(Addon.Catalog.recipes["mop.leatherworking.magnificence-of-leather"].recipeSpellID == 140040, "magnificence-of-leather spell ID")
assert(Addon.Catalog.recipes["mop.leatherworking.magnificence-of-scales"].recipeSpellID == 140041, "magnificence-of-scales spell ID")
assert(Addon.Catalog.recipes["mop.leatherworking.enhanced-magnificent-fur"].recipeSpellID == 142976, "hardened-magnificent-hide spell ID")

local celestialGroup = Group("mop.tailoring.celestial-cloth")
assert(Addon.Catalog.groups["mop.tailoring.imperial-silk"].requiredSkillLevel == 550, "imperial silk keeps its own 550-point requirement")
assert(State:Evaluate(celestialGroup, nil, 1000).state == "unknown", "unobserved profession cooldown is never actionable")
assert(State:Evaluate(celestialGroup, Cooling(143011, 2000), 1000).state == "cooldown", "crafted celestial cloth is cooldown")
assert(State:Evaluate(celestialGroup, Cooling(143011, 2000), 2001).state == "estimated", "celestial cloth recovers without rescan")
assert(State:Evaluate(celestialGroup, nil, 1000, 481).state == "skill-insufficient", "cached 481 skill blocks a 600-point cooldown without a rescan")
local insufficientSkill = Cooling(143011, 0)
insufficientSkill.recipes[143011].craftable = false
assert(State:Evaluate(celestialGroup, insufficientSkill, 1000).state == "skill-insufficient", "skill-point shortfall is distinct from cooldown")
local unlearnedRecipe = { sourceState = "known", observedAt = 1000, recipes = { [143011] = { learned = false } } }
local unlearnedState = State:Evaluate(celestialGroup, unlearnedRecipe, 1000, 600)
assert(unlearnedState.state == "unknown" and unlearnedState.reason == "recipe-unlearned", "unlearned recipe keeps the unknown display state with a specific reason")

GetGameTime = function() return 7, 1 end
local afterDailyReset = Cooling(143011, 200000)
afterDailyReset.observedAt = 70000
assert(State:Evaluate(celestialGroup, afterDailyReset, 100000).state == "estimated", "07:00 daily reset overrides stale client cooldown")
for _, group in pairs(Addon.Catalog.groups) do
    if group.active then assert(group.resetKind == "daily-07" and group.resetHour == 7, "all active groups reset at 07:00") end
end

dofile("YiboTodo/Model/Snapshot.lua")
local clock, gameHour, gameMinute = 100000, 6, 59
Addon.Now = function() return clock end
GetGameTime = function() return gameHour, gameMinute end
Addon.Settings = { GetMode = function() return "required" end }
Addon.Core = {
    Characters = { GetAll = function() return { { id = "snapshot-character" } } end },
    DataDomains = {
        Get = function()
            return { state = "known", data = { primaryProfessions = { { id = 197, name = "裁缝", icon = "Interface\\Icons\\Trade_Tailoring", skillLevel = 600 } } } }
        end,
    },
}
Addon.db = {
    byCharacter = {
        ["snapshot-character"] = {
            providers = {
                ["profession-cooldown"] = {
                    observations = { ["mop.tailoring.celestial-cloth"] = afterDailyReset },
                },
            },
        },
    },
}
Addon.Snapshot:Invalidate()
assert(Addon.Snapshot:GetCharacter("snapshot-character").activities["mop.tailoring.celestial-cloth"].state == "cooldown", "before 07:00 remains cooldown")
assert(Addon.Snapshot.nextTransitionAt == 100060, "snapshot schedules 07:00 refresh")
clock, gameHour, gameMinute = 100120, 7, 1
assert(Addon.Snapshot:GetCharacter("snapshot-character").activities["mop.tailoring.celestial-cloth"].state == "estimated", "snapshot refreshes at 07:00")

Addon.db.byCharacter["unscanned-character"] = {}
Addon.Core.Characters.GetAll = function() return { { id = "unscanned-character" } } end
Addon.Snapshot:Invalidate()
assert(Addon.Snapshot:GetCharacter("unscanned-character").activities["mop.tailoring.celestial-cloth"].state == "unknown", "switching to an unscanned character does not show a craft as ready")

Addon.db.settings = { modeOverrides = { cooldownGroup = {} } }
dofile("YiboTodo/Settings.lua")
Addon.Settings:SetMode("cooldownGroup", "mop.tailoring.celestial-cloth", "hidden")
assert(Addon.Snapshot:GetCharacter("snapshot-character").activities["mop.tailoring.celestial-cloth"] == nil, "hidden project is removed from the snapshot")
Addon.Settings:SetMode("cooldownGroup", "mop.tailoring.celestial-cloth", nil)
assert(Addon.Snapshot:GetCharacter("snapshot-character").activities["mop.tailoring.celestial-cloth"] ~= nil, "checked project returns to the snapshot")
assert(Addon.Settings:GetMode("cooldownGroup", "mop.tailoring.celestial-cloth", "required") == "required", "restoring a hidden project returns to the inherited enabled mode")
Addon.Settings:SetMode("cooldownGroup", "mop.tailoring.celestial-cloth", "required")
assert(Addon.db.settings.modeOverrides.cooldownGroup["mop.tailoring.celestial-cloth"] == "required", "rechecking stores an explicit enabled mode")

local livingSteelGroup = Group("mop.alchemy.living-steel")
assert(State:Evaluate(livingSteelGroup, Cooling(114780, 2000), 1000).state == "cooldown", "crafted living steel remains cooldown")

local magnificentFurGroup = Group("mop.leatherworking.magnificent-fur")
assert(magnificentFurGroup.aggregation == "shared-cooldown", "magnificent hide alternatives share one cooldown group")
assert(State:Evaluate(magnificentFurGroup, Cooling(140040, 2000), 1000).state == "cooldown", "crafted magnificence of leather is cooldown")

Addon.Now = function() return 1000 end
GetGameTime = function() return 0, 0 end
GetNumTradeSkills = function() return 3 end
GetTradeSkillRecipeLink = function(index)
    if index == 1 then return "|Henchant:143011|h[神纹布]|h" end
    if index == 2 then return "|Henchant:114780|h[转化：活化钢]|h" end
    return "|Henchant:140040|h[华丽制皮秘决]|h"
end
GetTradeSkillCooldown = function() return 3600 end
GetTradeSkillInfo = function() return "神纹布", "none" end
Addon.Core = {
    Characters = { GetCurrent = function() return { id = "test-character" } end },
    DataDomains = {
        Get = function()
            return { state = "known", data = { primaryProfessions = { { id = 197, name = "裁缝" }, { id = 171, name = "炼金术" }, { id = 165, name = "制皮" } } } }
        end,
    },
}
dofile("YiboTodo/Providers/ProfessionCooldown.lua")
local observations = assert(Addon.Providers.Registry:Get("profession-cooldown"):Collect())
assert(observations["mop.tailoring.celestial-cloth"].recipes[143011].readyAt == 4600, "provider collects celestial cloth")
assert(observations["mop.alchemy.living-steel"].recipes[114780].readyAt == 4600, "provider keeps living steel collection")
assert(observations["mop.leatherworking.magnificent-fur"].recipes[140040].readyAt == 4600, "provider collects crafted magnificent hide cooldown")
assert(observations["mop.tailoring.celestial-cloth"].recipes[143011].craftable == false, "provider records skill-point shortfall")
GetTradeSkillLine = function() return "裁缝" end
observations = assert(Addon.Providers.Registry:Get("profession-cooldown"):Collect())
assert(observations["mop.tailoring.imperial-silk"].recipes[125557].learned == false, "identified profession window records an absent recipe as unlearned")

dofile("YiboTodo/Database.lua")
_G.YiboTodoDB = {
    schemaVersion = 6,
    byCharacter = {
        ["legacy:TestRealm:TestCharacter"] = {
            providers = {
                ["profession-cooldown"] = {
                    observations = { ["mop.tailoring.celestial-cloth"] = { observedAt = 2000, sourceState = "known" } },
                },
            },
        },
        ["Player-1-00000001"] = {
            providers = {
                ["profession-cooldown"] = {
                    observations = { ["mop.tailoring.celestial-cloth"] = { observedAt = 1000, sourceState = "known" } },
                },
            },
        },
    },
}
Addon.Database:Initialize()
assert(Addon.Database:MoveCharacterData("legacy:TestRealm:TestCharacter", "Player-1-00000001"), "legacy character data migrates to GUID")
assert(Addon.db.byCharacter["legacy:TestRealm:TestCharacter"] == nil, "legacy key is removed after migration")
assert(Addon.db.byCharacter["Player-1-00000001"].providers["profession-cooldown"].observations["mop.tailoring.celestial-cloth"].observedAt == 2000, "newer legacy cooldown observation survives GUID migration")

print("YiboTodo cooldown state smoke passed")
