local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
GetServerTime = function() return 1000 end
UnitGUID = function() return "Current" end
GetLocale = function() return "enUS" end
for _, path in ipairs({ "Bootstrap.lua", "Util/Defaults.lua", "Runtime/Capabilities.lua", "Runtime/Locale.lua",
    "Locales/zhCN.lua", "Locales/enUS.lua", "Runtime/Events.lua", "Runtime/Registry.lua" }) do dofile("YiboCore/" .. path) end
local Core = YiboCore
dofile("_NonRelease/CoreIdentityDomainsR1/LoadClient.lua")
local db = { settings = {}, characters = { byID = {}, aliases = {}, seenOrder = {} } }
Core.Database = { GetDB = function() return db end }
Core.Print = function() end
Core:RegisterAddon("YiboCore", {requiredAPI=13})
Core:RegisterAddon("Fixture", {requiredAPI=13})
dofile("YiboCore/Runtime/DataDomains.lua")
Core.DataDomains:Register("YiboCore", {id="identity",version=1,Collect=function() return {} end})
dofile("YiboCore/Data/Characters.lua")
dofile("YiboCore/Data/CharacterCleanup.lua")
Check(Core:HasCapability("character-cleanup",2), "capability version")
local callbacks = {}
local owner = { Inspect = function() return {hasData=true,label="Fixture"} end,
    Delete = function(character,aliases,context)
        Check(type(context.deletedAt)=="number" and type(context.deletionID)=="string", "tombstone context")
        callbacks[#callbacks+1]={character=character,aliases=aliases,context=context}; return true
    end }
Check(Core.CharacterCleanup:RegisterOwner("Fixture",owner), "owner registration")
Check(db.characterDataOwners.Fixture == true, "owner persisted")
Check(not Core.CharacterCleanup:RegisterOwner("Fixture",owner), "duplicate registration rejected")
-- The old two-argument signature remains valid.
for name in pairs(Core.CharacterCleanup.EXPECTED_OWNERS) do
    Core:RegisterAddon(name,{})
    Core.CharacterCleanup:RegisterOwner(name,{Inspect=function() return {} end,Delete=function(character,aliases)
        Check(type(character)=="table" and type(aliases)=="table", "legacy callback compatible"); return true
    end})
end
db.characters.byID.Direct={id="Direct",name="Direct",realm="Realm"}
assert(Core.CharacterCleanup:Delete("Direct"))
Check(#callbacks==1 and callbacks[1].context.replay==false, "direct delete context")
Core.CharacterCleanup._owners.Fixture=nil
Core.CharacterCleanup.MAX_HISTORY=1
for _,id in ipairs({"A","B","C"}) do
    db.characters.byID[id]={id=id,name=id,realm="Realm"}
    local result=assert(Core.CharacterCleanup:Delete(id))
    Check(result.owners.Fixture.status=="pending", "disabled dynamic owner remains pending")
end
local pending=0
for _,record in pairs(db.characterDeletionHistory) do if record.acknowledgedOwners.Fixture~=true then pending=pending+1 end end
Check(pending==3, "pending history survives soft limit")
dofile("YiboCore/Data/CharacterCleanup.lua")
Check(Core.CharacterCleanup:RegisterOwner("Fixture",owner), "cold start registers and replays")
Check(#callbacks==4, "all pending records replayed")
for i=2,#callbacks do Check(callbacks[i].context.replay==true, "replay context") end
Check(Core.CharacterCleanup:IsLegacyImportBlocked("Fixture",nil,"A"), "deleted identity remains blocked")
print("CharacterCleanupV2Spec passed: " .. checks .. " checks")
