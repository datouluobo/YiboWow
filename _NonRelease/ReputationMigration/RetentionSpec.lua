-- Extends the real-runtime fixture with retention, retries and deletion audits.
dofile("_NonRelease/ReputationMigration/Spec.lua")
local addon, core = YiboReputation, YiboCore
local db, store = core.Database:GetDB(), addon.Store
local checks=0
local function Check(value, message) checks=checks+1;assert(value,message) end
local function Source()
    return {schemaVersion=5,state="known",updatedAt=123,revision=17,data={contractVersion=1,
        factions={[47]={factionID=47,name="Ironforge",standingID=6,min=9000,max=21000,value=16000}},
        statuses={[47]="known"}}}
end
local function Character(id, source)
    db.characters.byID[id]={id=id,name=id,realm="Realm",domains=source and {reputation=source} or {}}
end

-- A failed initial scan must not permanently prevent a later legacy retry.
Character("RetryPlaceholder", Source())
addon:CommitSnapshot("RetryPlaceholder",nil,"error",{error="temporary"})
Check(addon.Migration:ImportCharacter("RetryPlaceholder"),"empty error placeholder blocked legacy recovery")
Check(addon:GetSnapshot("RetryPlaceholder").data.factions[47].value==16000,"legacy payload recovered")
Check(addon:GetSnapshot("RetryPlaceholder").updatedAt==123,"original source timestamp recovered")
Check(db.characters.byID.RetryPlaceholder.domains.reputation.revision==17,"source not changed")

-- Completed metadata without its snapshot can recover unless explicitly deleted.
Character("MissingSnapshot",Source())
store.db.migrations.coreReputationV1.characters.MissingSnapshot={status="imported"}
Check(addon.Migration:ImportCharacter("MissingSnapshot"),"missing snapshot prevented safe recovery")
Check(addon:GetSnapshot("MissingSnapshot").updatedAt==123,"missing snapshot restored")

-- Repeating Core's same identity event must not introduce a deletion blocker.
Character("StableID")
store.db.characters["legacy:Realm:Stable"]={snapshot=Source(),origin={kind="core-import"}}
store:RemapCharacter("legacy:Realm:Stable","StableID")
Check(not store.db.migrations.coreReputationV1.blocked.StableID,"first promotion unexpectedly blocked target")
local revision=addon._matrixDataRevision
store:RemapCharacter("legacy:Realm:Stable","StableID")
Check(not store.db.migrations.coreReputationV1.blocked.StableID,"duplicate promotion propagated old-ID blocker")
Check(addon._matrixDataRevision==revision,"duplicate promotion refreshed data")

-- Persisted data and migration markers survive a new Store initialization.
local Copy=store.Copy
YiboReputationDB=Copy(store.db);store.db=nil
Check(store:Initialize(),"persisted store initialization")
Check(not addon.Migration:ImportCharacter("RetryPlaceholder"),"reload imported a second time")
Check(addon:GetSnapshot("RetryPlaceholder").updatedAt==123,"reload changed source time")

-- User deletion clears data, marker and conflict evidence, keeping only a blocker.
store.db.identityConflicts.RetryPlaceholder={record={snapshot=Source()}}
local result=core.CharacterCleanup:Delete("RetryPlaceholder")
Check(result and result.owners.YiboReputation.status=="deleted","cleanup acknowledgement")
Check(not store.db.characters.RetryPlaceholder and not store.db.identityConflicts.RetryPlaceholder,"cleanup left a business snapshot")
Check(not store.db.migrations.coreReputationV1.characters.RetryPlaceholder,"cleanup left import state")
Check(store.db.migrations.coreReputationV1.blocked.RetryPlaceholder,"cleanup missing blocker")
Character("RetryPlaceholder",Source())
Check(not addon.Migration:ImportCharacter("RetryPlaceholder"),"deleted snapshot resurrected")

-- Deletion while disabled is replayed once, before any subsequent import.
Character("DisabledDelete",Source())
store.db.characters.DisabledDelete={snapshot=Source()}
local owner=core.CharacterCleanup._owners.YiboReputation
core.CharacterCleanup._owners.YiboReputation=nil
local pending=core.CharacterCleanup:Delete("DisabledDelete")
Check(pending.owners.YiboReputation.status=="pending","disabled deletion not pending")
Check(store.db.characters.DisabledDelete~=nil,"disabled owner should not be called")
Check(core.CharacterCleanup:RegisterOwner("YiboReputation",owner),"disabled owner registration")
Check(not addon:GetSnapshot("DisabledDelete") and store.db.migrations.coreReputationV1.blocked.DisabledDelete,"pending deletion not replayed")
local processed,failed=core.CharacterCleanup:RetryPending("YiboReputation")
Check(processed==0 and failed==0,"acknowledged deletions replayed again")
Check(not db.characters.byID.DisabledDelete,"Core source not removed by explicit user deletion")

-- Neither retries nor local edits may mutate the complete frozen Core source.
local function Equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
Character("LocalWins",Source())
local localRecord={snapshot=Source(),origin={kind="local-scan"},lastScanAt=500}
localRecord.snapshot.data.factions[47].value=17000
store.db.characters.LocalWins=localRecord
store.db.migrations.coreReputationV1.characters.LocalWins={status="failed",reason="earlier-source-error"}
local reads, originalGet=0,core.DataDomains.Get
core.DataDomains.Get=function(...) reads=reads+1;return originalGet(...) end
Check(not addon.Migration:ImportCharacter("LocalWins"),"local data replaced by old source")
Check(reads==0 and addon:GetSnapshot("LocalWins").data.factions[47].value==17000,"successful local record reread old source")
Check(store.db.migrations.coreReputationV1.characters.LocalWins.status=="existing","resolved source failure still counted")
core.DataDomains.Get=originalGet
Check(Equal(db.characters.byID.LocalWins.domains.reputation,Source()),"complete frozen source changed")
Character("FuturePlaceholder",Source())
store.db.characters.FuturePlaceholder={snapshot={schemaVersion=99,state="error",data={contractVersion=99,factions={}}}}
Check(not addon.Migration:ImportCharacter("FuturePlaceholder") and addon:GetSnapshot("FuturePlaceholder").schemaVersion==99,"unknown-version empty record overwritten")

-- Current-role deletion is rejected before any business data or markers change.
local currentID=core.Characters:GetCurrentID()
local beforeCurrent=Copy(store.db.characters[currentID])
Check(not core.CharacterCleanup:Delete(currentID),"current role deletion was allowed")
Check(Equal(store.db.characters[currentID],beforeCurrent),"rejected deletion changed current snapshot")

-- Owner failure is pending, retry succeeds once, and subsequent retries are inert.
Character("OwnerFailure",Source())
store.db.characters.OwnerFailure={snapshot=Source()}
local delete=addon.DeleteCharacter
addon.DeleteCharacter=function() return nil,"injected-owner-failure" end
local failure=core.CharacterCleanup:Delete("OwnerFailure")
addon.DeleteCharacter=delete
Check(failure.owners.YiboReputation.status=="pending" and addon:GetSnapshot("OwnerFailure"),"owner failure was acknowledged or lost retained data")
processed,failed=core.CharacterCleanup:RetryPending("YiboReputation")
Check(processed==1 and failed==0 and not addon:GetSnapshot("OwnerFailure"),"failed owner did not recover")
processed,failed=core.CharacterCleanup:RetryPending("YiboReputation")
Check(processed==0 and failed==0,"successful owner retry repeated")
Check(addon:GetSnapshot("LocalWins").data.factions[47].value==17000,"deletion damaged unrelated role")

-- Reload must preserve deletion blockers as well as successful imports.
YiboReputationDB=Copy(store.db);store.db=nil;Check(store:Initialize(),"reload after deletion")
Check(not addon.Migration:ImportCharacter("RetryPlaceholder") and not addon:GetSnapshot("RetryPlaceholder"),"reload lost deletion blocker")
local saved=Copy(store.db.characters)
YiboReputationDB.dataSchemaVersion=99;store.db=nil
Check(not store:Initialize(),"unknown store version accepted")
Check(Equal(YiboReputationDB.characters,saved),"unknown store version discarded retained data")
YiboReputationDB.dataSchemaVersion=1;Check(store:Initialize(),"restore fixture schema")
print("PASS: "..checks.." additional history retention, import recovery, reload and cleanup checks")
