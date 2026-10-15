-- Run from the workspace root with Lua 5.1. No client SavedVariables are loaded.
local checks = 0
local function Check(value, message)
    checks = checks + 1
    assert(value, message or ("check " .. checks))
end
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k,v in pairs(value) do result[k] = Copy(v) end; return result
end
local now, currentID, loggedIn, timers, frames, prints = 1000, "Player-A", false, {}, {}, {}
GetServerTime = function() return now end
UnitGUID = function() return currentID end
UnitName = function() return "A" end
GetRealmName = function() return "Realm" end
UnitClass = function() return "Warrior", "WARRIOR" end
UnitLevel = function() return 90 end
IsLoggedIn = function() return loggedIn end
GetLocale = function() return "zhCN" end
DEFAULT_CHAT_FRAME = { AddMessage=function(_, message) prints[#prints+1] = message end }
C_Timer = { After=function(_, callback) timers[#timers+1] = callback end }
CreateFrame = function()
    local frame = { events={} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(_, callback) self.callback = callback end
    frames[#frames+1] = frame
    return frame
end
SlashCmdList = {}
dofile("YiboCore/Bootstrap.lua")
local core = YiboCore
core.Defaults = { Copy=function(_, value) return Copy(value) end }
core.Text = function(_, key) return key end
core.LevelFilter = { Validate=function(_, value) return true, value end }
core.Capabilities = { Register=function() end }
core.HasCapability = function() return true end
core._private.initialized = true
local resources, language = {}, "zh"
core.Locale = {
    Register=function(_, owner, locale, values) resources[owner..":"..locale] = values end,
    Get=function(_, owner, key, ...)
        local value = (resources[owner..":"..language] or {})[key]
        assert(value, "missing locale key "..key)
        return string.format(value, ...)
    end,
    Bind=function(_, callback) return callback() end,
}
local db = { characters={byID={}, aliases={}, seenOrder={}}, settings={}, characterDeletionHistory={} }
core.Database = { GetDB=function() return db end }
dofile("YiboCore/Runtime/Registry.lua")
dofile("YiboCore/Runtime/Events.lua")
dofile("YiboCore/Runtime/DataDomains.lua")
dofile("YiboCore/Data/DomainStore.lua")
dofile("YiboCore/Data/Characters.lua")
dofile("YiboCore/Data/CharacterCleanup.lua")
local notifications, pages, entries = 0, 0, 0
local pageDefinition
core.AccountView = {
    NotifyPageChanged=function() notifications = notifications+1 end,
    RegisterPage=function(_, _, definition) pages=pages+1; pageDefinition=definition; return definition end,
    GetColumnPage=function() end, UpdateColumnPager=function() end,
}
core.Entry = { RegisterBusinessEntry=function(_, _, definition) entries=entries+1; return definition end }
core.UITheme = { CreateInput=function() end }
core.Contracts = { Register=function(_, _, definition) return definition end, NotifyChanged=function() end }
core.BusinessItemActions = { Bind=function() end, Handle=function() end, Unbind=function() end, TooltipLines=function() end }
assert(loadfile("YiboReputation/Bootstrap.lua"))("YiboReputation")
local addon = YiboReputation
local bootstrap = frames[#frames]
dofile("YiboReputation/Locales/Interface.lua")
for _, file in ipairs({ "ReputationCatalog", "Store", "Migration", "Scanner", "ReputationHierarchy", "Friendship", "ReputationFormat", "GoalTargets", "CoreIntegration" }) do
    dofile("YiboReputation/"..file..".lua")
end
local function Character(id, snapshot)
    db.characters.byID[id] = { id=id, name=id, realm="Realm", domains=snapshot and {reputation=Copy(snapshot)} or {}, seenOrder=1 }
end
local function Snapshot(version, state)
    return {schemaVersion=version or 5,state=state or "known",updatedAt=400,revision=9,
        data={contractVersion=1,coverage="registered-and-enumerated", factions={
            [1272]={factionID=1272,name="The Tillers",standingID=6,min=9000,max=21000,value=12345,state="known"},
            [1358]={factionID=1358,name="Nat Pagle",friendship={rank=2,maxRank=6,reaction=9000,reactionThreshold=8400,nextThreshold=16800,reactionName="同伴"}},
        },statuses={[1272]="known",[1358]="known"},enumeratedCount=2,registeredCount=2}}
end
Character("Player-A", Snapshot())
Character("Offline", Snapshot())
Character("Deleted", Snapshot())
for version=1,4 do Character("Old"..version, Snapshot(version)) end
local corrupt = Snapshot(); corrupt.schemaVersion=99; Character("Future", corrupt)
local malformed = Snapshot(); malformed.data.factions[1358].friendship.rank="bad"; Character("Malformed", malformed)
local sourceBefore = Copy(db.characters.byID.Offline.domains.reputation)

-- Stop on an old collector or insufficient release, before writing local data.
core.DataDomains._definitions.reputation={id="reputation",owner="YiboCore"}
local ok, err = addon.CoreIntegration:Initialize()
Check(not ok and err:find("1.12.4",1,true), "old collector rejected")
Check(YiboReputationDB.characters==nil and pages==0 and entries==0, "no partial initialization")
core.DataDomains._definitions.reputation=nil
core.VERSION="1.12.3"; Check(not addon.CoreIntegration:Initialize(), "old version rejected")
core.VERSION="1.12.4"

-- Deletion while Reputation is disabled is replayed before import.
local deleted = core.CharacterCleanup:Delete("Deleted")
Check(deleted and deleted.owners.YiboReputation.status=="pending", "disabled owner pending")
bootstrap.callback(bootstrap,"ADDON_LOADED","YiboReputation")
Check(addon.CoreIntegration.initialized, "compatible bootstrap initialization")
Check(addon.CoreIntegration.initialized and pages==1 and entries==1)
Check(addon.CoreIntegration:Initialize() and pages==1 and entries==1, "idempotent registration")
Check(#timers==0, "no scan before login")
Check(addon.Store.db.migrations.coreReputationV1.blocked.Deleted, "pending deletion blocks import")
Check(not addon:GetSnapshot("Deleted"))
Character("NoData")
addon.Store.db.characters.NoData={snapshot={schemaVersion=5,state="not-yet-scanned",data={contractVersion=1,factions={},statuses={}}}}
Check(not pageDefinition.HasCharacterSnapshot({id="NoData"}),"no-data characters excluded")
Check(pageDefinition.HasCharacterSnapshot({id="Offline"}),"imported character admitted")
Check(db.characters.byID.Offline.domains.reputation.updatedAt==sourceBefore.updatedAt, "source time preserved")
local imported = addon:GetSnapshot("Offline")
Check(imported.updatedAt==400 and imported.revision==1 and imported.schemaVersion==5)
Check(imported.data.factions[1272].value==12345 and imported.data.factions[1358].friendship.rank==2)
Check(db.characters.byID.Offline.domains.reputation.revision==9, "Core source unchanged")
imported.data.factions[1272].value=0
Check(addon:GetSnapshot("Offline").data.factions[1272].value==12345, "defensive copy")
for version=1,4 do
    local snapshot = addon:GetSnapshot("Old"..version)
    Check(snapshot.schemaVersion==version and snapshot.state=="not-yet-scanned", "old schema not upgraded")
end
Check(not addon:GetSnapshot("Future") and not addon:GetSnapshot("Malformed"), "invalid sources quarantined")
Check(addon.Store.db.migrations.coreReputationV1.characters.Future.status=="failed")
local count, failed = addon:ImportLegacySnapshots(); Check(count==0 and failed==2, "retry skips successful imports")
db.characters.byID.Future.domains.reputation=Snapshot()
count,failed=addon:ImportLegacySnapshots(); Check(count==1 and failed==1, "individual failures retry")
addon.Store.db.migrations.coreReputationV1.characters.Offline=nil
count=addon:ImportLegacySnapshots(); Check(count==0, "interruption after data write does not overwrite")

-- All native rows, stable IDs under collapsed headers, primary header and friendship normalization.
local rows = {
    {id=1272,name="The Tillers",rank=6,min=9000,max=21000,value=13000,header=true},
    {id=9999,name="Discovered",rank=8,min=42000,max=43000,value=42999},
    {name="Structural",header=true},
}
local function Tuple(row)
    if not row then return end
    return row.name,nil,row.rank,row.min,row.max,row.value,nil,nil,row.header,nil,nil,nil,nil,row.id
end
GetNumFactions=function() return #rows end
GetFactionInfo=function(index) return Tuple(rows[index]) end
GetFactionInfoByID=function(id)
    if id==1358 then return Tuple({id=id,name="Nat Pagle",rank=5,min=0,max=8400,value=8400}) end
    if id==1283 then return Tuple({id=id,name="Capped friend",header=false}) end
    if id==1134 then return Tuple({id=id,name="Collapsed faction",rank=7,min=21000,max=42000,value=26000}) end
end
GetFriendshipReputationByID=function(id)
    if id==1358 then return 123,9000,42000,nil,nil,"同伴",8400 end
    if id==1283 then return 124,42000,42000,nil,nil,"挚友",42000 end
end
local rankID
GetFriendshipReputationRanks=function(id) rankID=id; if id==123 then return 2,6 else return 6,6 end end
local payload,state=addon.Scanner:Collect()
Check(state=="known" and payload.factions[1272].value==13000, "primary header retained")
Check(payload.factions[1134].value==26000, "collapsed ID lookup")
Check(payload.factions[1283].friendship.rank==6, "capped friendship without standing")
Check(payload.factions[1358].friendship.rank==2 and payload.factions[1358].friendship.reactionName=="同伴")
Check(payload.factions[9999] and not payload.factions[3], "no row-index identity")
local events=0
core.Events:Register("YIBO_REPUTATION_SNAPSHOT_CHANGED",{},function(_,event)
    events=events+1; Check(event.source=="YiboReputation" and event.characterID~=nil)
end)
loggedIn=true
addon.Scanner.frame.callback(addon.Scanner.frame,"PLAYER_LOGIN")
addon.Scanner.frame.callback(addon.Scanner.frame,"PLAYER_ENTERING_WORLD")
addon.Scanner.frame.callback(addon.Scanner.frame,"UPDATE_FACTION")
Check(#timers==1, "burst coalesced")
local function Flush() local batch=timers;timers={};for _,callback in ipairs(batch) do callback() end end
Flush()
local scanned=addon:GetSnapshot("Player-A")
Check(scanned.state=="known" and scanned.updatedAt==now and addon.Store.db.characters["Player-A"].lastScanAt==now)
Check(addon.Store.db.characters["Player-A"].origin.kind=="local-scan")
Check(addon.FactionRegistry[9999], "discovered ID retained")
local revision, notificationsBefore, eventsBefore=scanned.revision,notifications,events
-- Discovery increases registeredCount on the next scan, then stabilizes.
addon:ScanCurrent("settle")
scanned=addon:GetSnapshot("Player-A");revision=scanned.revision;notificationsBefore=notifications;eventsBefore=events
now=1100; Check(addon:ScanCurrent("unchanged"))
Check(addon:GetSnapshot("Player-A").revision==revision and notifications==notificationsBefore and events==eventsBefore, "unchanged data does not refresh")
Check(addon.Store.db.characters["Player-A"].lastScanAt==1100 and addon:GetSnapshot("Player-A").updatedAt==1000)
addon:ImportLegacySnapshots()
Check(addon:GetSnapshot("Player-A").data.factions[1272].value==13000, "import never overwrites local scan")
Check(db.characters.byID["Player-A"].domains.reputation.data.factions[1272].value==12345, "no dual write")
Check(core.DataDomains:Dispatch("UPDATE_FACTION")==0, "Core no longer collects reputation")

local savedNum, savedRows, savedID=GetNumFactions,GetFactionInfo,GetFactionInfoByID
GetFactionInfo=function() error("native failure") end
Check(not addon:ScanCurrent("error"))
Check(addon:GetSnapshot("Player-A").state=="error" and addon:GetSnapshot("Player-A").data.factions[1272].value==13000, "failure preserves payload")
Check(addon:FormatState(addon:GetSnapshot("Player-A"))==addon:T("STATE.ERROR"))
GetNumFactions,GetFactionInfo,GetFactionInfoByID=function() return 0 end,function() end,function() end
Check(not addon:ScanCurrent("empty"))
Check(addon:GetSnapshot("Player-A").data.factions[1272].value==13000, "empty scan preserves payload")
addon.Scanner:Request("empty")
for i=1,5 do Flush() end
Check(#timers==0 and addon.Scanner.retryCount==3, "bounded retry")
GetNumFactions,GetFactionInfo,GetFactionInfoByID=savedNum,savedRows,savedID
Check(addon:ScanCurrent("recovered"))
GetNumFactions,GetFactionInfo=nil,nil
Check(not addon:ScanCurrent("missing-api"))
Check(addon:GetSnapshot("Player-A").state=="unavailable" and addon:GetSnapshot("Player-A").data.factions[1272].value==13000,"missing API keeps last data")
GetNumFactions,GetFactionInfo=savedNum,savedRows
Check(addon:ScanCurrent("api-returned"))
GetNumFactions,GetFactionInfo=nil,nil
C_Reputation={GetNumFactions=function() return 1 end,GetFactionDataByIndex=function() return {factionID=9998,name="Structured",reaction=6,currentReactionThreshold=9000,nextReactionThreshold=21000,currentStanding=12000} end}
payload,state=addon.Scanner:Collect();Check(payload.factions[9998].value==12000,"structured native API")
GetNumFactions,GetFactionInfo,C_Reputation=savedNum,savedRows,nil

-- Goal rank absence must remain unknown, even when the ordinary API returns a standing ID.
local friendMissing=Snapshot();friendMissing.data.factions[1358].standingID=8;friendMissing.data.factions[1358].friendship.rank=nil;friendMissing.data.factions[1358].friendship.reactionName="Unrecognized"
addon.Store.db.characters.Offline.snapshot=friendMissing
local result=addon.GoalTargets:Evaluate({goals={{id="goal",intent={objectID=1358,scope={characterID="Offline"},conditions={rank=6}}}}})
Check(result.evaluations.goal.task.readiness=="unknown" and result.evaluations.goal.task.state~="completed")
addon.Store.db.characters.Offline.snapshot=Snapshot()
result=addon.GoalTargets:Evaluate({goals={{id="goal",intent={objectID=1358,scope={characterID="Offline"},conditions={rank=2}}}}})
Check(result.evaluations.goal.task.state=="completed", "valid imported goal")
addon.Store.db.characters.Offline.snapshot.state="error"
result=addon.GoalTargets:Evaluate({goals={{id="goal",intent={objectID=1358,scope={characterID="Offline"},conditions={rank=2}}}}})
Check(result.evaluations.goal.task.readiness=="unknown", "error data cannot complete goal")

-- ID promotion, collision preservation and deletion cannot revive frozen imports.
Character("Promoted")
addon.Store.db.characters.legacy=Copy(addon.Store.db.characters["Player-A"])
core.Events:Fire("CHARACTER_ID_CHANGED","legacy","Promoted")
Check(addon:GetSnapshot("Promoted") and not addon:GetSnapshot("legacy"))
Check(addon.Store.db.migrations.coreReputationV1.blocked.legacy)
Character("Collision")
addon.Store.db.characters.left={snapshot=Snapshot(),origin={kind="core-import"}}
addon.Store.db.characters.Collision={snapshot=Snapshot(),origin={kind="core-import"}}
addon.Store.db.characters.left.snapshot.data.factions[1272].value=999
core.Events:Fire("CHARACTER_ID_CHANGED","left","Collision")
Check(addon.Store.db.identityConflicts.Collision and addon:GetSnapshot("Collision").state=="not-yet-scanned" and addon:GetSnapshot("Collision").revision==10)
core.CharacterCleanup:Delete("Offline")
Check(not addon:GetSnapshot("Offline") and addon.Store.db.migrations.coreReputationV1.blocked.Offline)
Character("Offline",Snapshot());addon:ImportLegacySnapshots()
Check(not addon:GetSnapshot("Offline"), "deleted data cannot be reimported")
currentID="Offline";Check(addon:ScanCurrent("fresh-login") and addon:GetSnapshot("Offline"), "real login can collect anew")
currentID="Player-A"
-- A promotion that happened before the addon loaded can be repaired only by Core aliases.
Character("LateGUID")
db.characters.aliases["Late-Realm"]="LateGUID"
addon.Store.db.characters["legacy:Realm:Late"]={snapshot=Snapshot(),identityAliases={["Late-Realm"]=true},origin={kind="core-import"}}
addon.Store:ReconcileLegacyIDs()
Check(addon:GetSnapshot("LateGUID") and not addon:GetSnapshot("legacy:Realm:Late"), "late promotion reconciled")
Character("DeleteGUID")
db.characters.aliases["Delete-Realm"]="DeleteGUID"
addon.Store.db.characters["legacy:Realm:Delete"]={snapshot=Snapshot(),identityAliases={["Delete-Realm"]=true}}
Check(addon:InspectCharacter({id="DeleteGUID"},{["Delete-Realm"]=true}).hasData)
core.CharacterCleanup:Delete("DeleteGUID")
Check(not addon:GetSnapshot("legacy:Realm:Delete") and addon.Store.db.migrations.coreReputationV1.blocked["legacy:Realm:Delete"], "pending cleanup covers fallback aliases")
local pageCount,entryCount=pages,entries
core._private.initialized=false
bootstrap.callback(bootstrap,"ADDON_LOADED","YiboReputation")
core._private.initialized=true;core.Events:Fire("CORE_READY")
Check(pages==pageCount and entries==entryCount,"late Core readiness does not duplicate UI")
addon.Scanner.initialized=false;addon.Scanner:Initialize()
Check(#timers==1,"late-loaded logged-in scanner schedules initial scan");Flush()
local bad=Snapshot();bad.data.factions[1272].value="bad"
local before=addon:GetSnapshot("Player-A")
Check(not addon:CommitSnapshot("Player-A",bad.data,"known"),"invalid numeric payload rejected")
Check(addon:GetSnapshot("Player-A").revision==before.revision,"rejected commit atomic")
for _,locale in ipairs({"zh","en"}) do language=locale;Check(addon:T("ERROR.CORE_COLLECTOR"):find("1.12.4",1,true));Check(#addon:T("COMMAND.STATUS",1,0,addon:T("COMMAND.SCAN_OK"))>0) end
local toc=assert(io.open("YiboCore/YiboCore.toc")):read("*a")
Check(not toc:find("Data\\Domains\\Reputation.lua",1,true),"retired domain absent from runtime TOC")
Check(core.RegisterReputationFactions==nil and core.ReputationRegistry==nil,"no Core business registry")
print("PASS: "..checks.." reputation migration, scanner, goal, identity, cleanup and initialization checks")
