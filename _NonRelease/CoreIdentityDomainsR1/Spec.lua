local Boot = dofile("_NonRelease/CoreForever/Harness.lua")
local checks = 0
local function Check(value, label) checks = checks + 1; assert(value, label) end
local function Equal(a,b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k,v in pairs(a) do if not Equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function Start(forever,saved)
    local e,c,fire,flush,load = Boot(forever,saved)
    e.TEST_GUID, e.clock = "Player-Identity-1", 1000
    e.GetServerTime = function() return e.clock end
    e.IsLoggedIn = function() return true end
    e.UnitName = function() return "猎手" end
    e.UnitClass = function() return "猎人", "HUNTER", 3 end
    e.UnitRace = function() return "人类", "Human", 1 end
    e.UnitFactionGroup = function() return "Alliance", "联盟" end
    fire("ADDON_LOADED"); fire("PLAYER_LOGIN"); flush()
    Check(c:IsInitialized(),"real target starts")
    return e,c,fire,flush,load
end

for _,forever in ipairs({false,true}) do
    local e,c,fire,flush,load = Start(forever)
    local id = e.TEST_GUID
    local record = c.Database:GetDB().characters.byID[id]
    Check(record.class=="HUNTER" and record.name=="猎手", "native second class return preserved")
    Check(record.race=="人类" and record.faction=="Alliance", "v1 native race/faction representation retained")
    local basic = c.Characters:GetCurrent({identityOnly=true}); basic.name="changed"
    Check(c.Characters:GetCurrent().name=="猎手" and basic.domains==nil,"detached lightweight identity")
    e.TEST_GUID="Player-Identity-2"; e.GetRealmName=function() return "OtherRealm" end
    c.Characters:RefreshCurrent()
    Check(#c.Characters:GetAll()==2,"same name across realms remains two GUIDs")
    e.TEST_GUID="Player-Identity-3"; c.Characters:RefreshCurrent()
    Check(#c.Characters:GetAll()==3 and c.Characters:Get("Player-Identity-2")~=nil,"same realm/name cannot promote a real GUID into another GUID")
    local last = c.Characters:GetCurrent()
    e.clock=1100; e.UnitClass=function() return nil end
    Check(c.Characters:RefreshCurrent()==nil and c._private.characterPending,"partial native identity waits")
    Check(Equal(c.Characters:Get(last.id),last),"failed identity read cannot change stored class/level/time")
    e.UnitClass=function() return "猎人","HUNTER",3 end
    fire("PLAYER_LEVEL_UP")
    Check(not c._private.characterPending and c.Characters:GetCurrent().lastSeenAt==1100,"late native identity recovers")
    e.TEST_GUID=nil
    Check(c.Characters:GetCurrentID()==nil and c.Characters:RefreshCurrent()==nil,"lost GUID cannot create a new fallback after real GUID observed")
    Check(#c.Characters:GetAll()==3,"no duplicate fallback row")
    local hidden={}
    e.UnitGUID=function() return hidden end
    e.issecretvalue=function(value) return value==hidden end
    Check(c.Characters:GetCurrentID()==nil and c.Characters:RefreshCurrent()==nil,"restricted native identity not persisted or guessed")
    e.TEST_GUID="Player-Identity-3"
    e.UnitGUID=function() return e.TEST_GUID end; e.issecretvalue=nil
    c.Characters:RefreshCurrent()
    local snapshot=c.Characters:GetCurrent()
    e.UnitName=function() error("native name unavailable") end
    Check(c.Characters:RefreshCurrent()==nil and Equal(c.Characters:Get(snapshot.id),snapshot),"native exception leaves directory untouched")
    e.UnitName=function() return "猎手" end; c.Characters:RefreshCurrent()

    local result,state,raise = {value=7},"known",false
    local updated,keys=0,nil
    c.Events:Register("DATA_DOMAIN_UPDATED",{},function(_,payload)
        if payload.domainID=="fixture.snapshot" then updated=updated+1; keys=payload.changedKeys end
    end)
    Check(c.DataDomains:Register("YiboCore",{id="fixture.snapshot",version=1,events={UNIT_NAME_UPDATE=true},
        Collect=function() if raise then error("collector failure") end; return result,state,{value=true} end})~=nil,"late domain registered")
    Check(c._private.eventRegistration.UNIT_NAME_UPDATE==true,"late domain event subscribed")
    fire("UNIT_NAME_UPDATE","player")
    local domain=c.DomainStore:Get(e.TEST_GUID,"fixture.snapshot")
    Check(domain.data.value==7 and domain.state=="known","late native event dispatches domain")
    local base=c.Defaults:Copy(domain.data)
    for _,failedState in ipairs({"unavailable","not-yet-scanned","error","stale"}) do
        for _,partial in ipairs({false,true}) do
            result=partial and {value=999} or nil; state=failedState
            e.clock=e.clock+1; c.Profile:RefreshCurrent("UNIT_NAME_UPDATE")
            local failed=c.DomainStore:Get(e.TEST_GUID,"fixture.snapshot")
            Check(Equal(failed.data,base) and failed.state==failedState,"nil/partial failed result preserves old values")
        end
    end
    Check(keys and next(keys)==nil,"failure does not report false value deletions")
    state="known"; result=nil; c.Profile:RefreshCurrent("UNIT_NAME_UPDATE")
    Check(c.DomainStore:GetState(e.TEST_GUID,"fixture.snapshot")=="error" and Equal(c.DomainStore:Get(e.TEST_GUID,"fixture.snapshot").data,base),"known without snapshot cannot clear data")
    state="invalid"; result={}; c.Profile:RefreshCurrent("UNIT_NAME_UPDATE")
    Check(Equal(c.DomainStore:Get(e.TEST_GUID,"fixture.snapshot").data,base),"invalid state preserves old data")
    state=false; result={value=0}; c.Profile:RefreshCurrent("UNIT_NAME_UPDATE")
    Check(Equal(c.DomainStore:Get(e.TEST_GUID,"fixture.snapshot").data,base),"false state is not an implicit success")
    raise=true; c.Profile:RefreshCurrent("UNIT_NAME_UPDATE"); raise=false
    Check(Equal(c.DomainStore:Get(e.TEST_GUID,"fixture.snapshot").data,base),"collector exception preserves values")
    state="known"; result={}; c.Profile:RefreshCurrent("UNIT_NAME_UPDATE")
    domain=c.DomainStore:Get(e.TEST_GUID,"fixture.snapshot")
    Check(domain.state=="known" and next(domain.data)==nil,"successful known empty snapshot replaces old values")
    local revision,at=domain.revision,domain.updatedAt
    e.clock=e.clock+10; c.Profile:RefreshCurrent("UNIT_NAME_UPDATE")
    Check(c.DomainStore:Get(e.TEST_GUID,"fixture.snapshot").revision==revision and c.DomainStore:Get(e.TEST_GUID,"fixture.snapshot").updatedAt==at,"unchanged known snapshot preserves revision/change timestamp")
    domain.data.injected=true
    Check(c.DomainStore:Get(e.TEST_GUID,"fixture.snapshot").data.injected==nil,"domain getter returns detached data")
    local legacyCalls=0
    Check(c.Profile:RegisterCollector("fixture.legacy",function() legacyCalls=legacyCalls+1 end,{PLAYER_FLAGS_CHANGED=true}),"late legacy collector registered")
    fire("PLAYER_FLAGS_CHANGED")
    Check(legacyCalls==1 and c._private.eventRegistration.PLAYER_FLAGS_CHANGED==true,"late legacy native event dispatched once")
    Check(not c.Profile:RegisterCollector("fixture.bad-events",function() end,"PLAYER_LOGIN") and c.Profile._collectors["fixture.bad-events"]==nil,"invalid late collector fails before registration")
    Check(c.Profile:RegisterCollector("fixture.disabled-event",function() error("disabled legacy collector ran") end,{UNIT_HEALTH=false}) and c._private.eventRegistration.UNIT_HEALTH==nil,"legacy disabled events remain valid without a native subscription")

    -- Native collectors retain both domain data and the v4 projection on failure.
    e.clock=2000; fire("PLAYER_LOGIN")
    local location=c.DomainStore:Get(e.TEST_GUID,"location")
    local live=c.Database:GetDB().characters.byID[e.TEST_GUID]
    local zone,observed=live.profile.zone,live.observedAt.profile
    e.C_Map.GetBestMapForUnit=function() return nil end; e.clock=2001
    fire("ZONE_CHANGED_NEW_AREA")
    Check(Equal(c.DomainStore:Get(e.TEST_GUID,"location").data,location.data),"nil native map preserves location")
    Check(live.profile.zone==zone and live.observedAt.profile==observed and live.availability.profile~="known","failed location retains v4 values and last successful projection time")
    e.C_Map.GetBestMapForUnit=function() return 2 end; fire("ZONE_CHANGED_NEW_AREA")
    Check(live.profile.mapID==2 and live.availability.profile=="known","location recovers with real new map")
    local guildBefore=live.profile.guild
    e.IsInGuild=function() return true end; e.GetGuildInfo=function() return nil end
    fire("PLAYER_GUILD_UPDATE")
    Check(c.DomainStore:GetState(e.TEST_GUID,"identity")~="known" and live.profile.guild==guildBefore,"guild loading is not a known empty guild")
    e.GetGuildInfo=function() return "Guild" end; fire("PLAYER_GUILD_UPDATE")
    Check(live.profile.guild=="Guild","guild read recovers")
    e.IsInGuild=function() return false end; fire("PLAYER_GUILD_UPDATE")
    Check(live.profile.guild==nil and c.DomainStore:GetState(e.TEST_GUID,"identity")=="known","confirmed guild leave can clear guild")

    if not forever then
        e.C_PaperDollInfo={GetAverageItemLevel=function() return 420,410 end}
        e.GetSpecialization=function() return 1 end
        e.GetSpecializationInfo=function() return 253,"Beast Mastery",nil,"icon" end
        fire("PLAYER_EQUIPMENT_CHANGED"); fire("PLAYER_SPECIALIZATION_CHANGED")
        local equipAt,specAt=live.observedAt.itemLevel,live.observedAt.specialization
        e.C_PaperDollInfo.GetAverageItemLevel=function() return nil end
        e.GetSpecialization=function() return nil end; e.clock=2010
        fire("PLAYER_EQUIPMENT_CHANGED"); fire("PLAYER_SPECIALIZATION_CHANGED")
        Check(live.profile.itemLevel==410 and live.observedAt.itemLevel==equipAt,"failed equipment preserves value/time")
        Check(live.profile.specialization.id==253 and live.observedAt.specialization==specAt,"unready specialization preserves value/time")
    else
        Check(c.DataDomains._definitions.equipment==nil and c.Fields._definitions["character.item-level"]==nil,"unsupported domain and field absent on Forever")
    end

    local slots = forever and {1,nil,3,nil,nil,nil,7} or {1,nil,3,4,5,6}
    local ids = forever and {[1]=197,[3]=129,[7]=9123} or {[1]=197,[3]=794,[4]=356,[5]=185,[6]=129}
    e.GetProfessions=function() return unpack(slots,1,forever and 7 or 6) end
    e.GetProfessionInfo=function(index) return "Profession"..index,1,30,75,nil,nil,ids[index] end
    fire("SKILL_LINES_CHANGED")
    Check(live.profile.primaryProfessions[1].id==197 and live.profile.primaryProfessions[2]==nil,"primary slots retained without dense-list confusion")
    local primary2=c.Fields._definitions["character.profession-secondary"]
    Check(c.Fields:GetValue(c.Characters:GetCurrent(),primary2)==nil,"secondary profession is not promoted into empty second primary")
    local firstAid=c.Fields._definitions["character.first-aid"]
    Check(c.Fields:GetValue(c.Characters:GetCurrent(),firstAid).id==129,"target profession field resolves skill ID")
    local archaeology=c.Fields._definitions["character.archaeology"]
    Check((c.Fields:GetValue(c.Characters:GetCurrent(),archaeology)~=nil)==(not forever),"Forever does not apply Mists secondary slot IDs")
    Check(c:HasCapability("profession-profile",1)==forever,"capability asymmetry intentionally preserved")
    local prof=c.Defaults:Copy(live.profile.professions); local profAt=live.observedAt.professions
    e.GetProfessionInfo=function() return nil end; e.clock=2020; fire("SKILL_LINES_CHANGED")
    Check(Equal(live.profile.professions,prof) and live.observedAt.professions==profAt,"partial profession info preserves previous profile/time")
    e.GetProfessions=function() return nil end
    fire("PLAYER_ENTERING_WORLD")
    Check(Equal(live.profile.professions,prof),"empty startup API result is not confirmed unlearning")
    fire("SKILL_LINES_CHANGED")
    Check(next(live.profile.professions)==nil and c.DomainStore:GetState(e.TEST_GUID,"professions")=="known","confirmed unlearning produces known empty professions")

    -- Legacy v4 fields without domains must also survive the first failed read.
    local old={id="Player-Identity-1",name="猎手",realm="ProbeRealm",class="HUNTER",level=5,
        profile={zone="OldZone",mapID=9,itemLevel=300,professions={{id=197,slot=1,name="Tailoring",skillLevel=20,maxSkillLevel=75}}},
        observedAt={profile=123,itemLevel=123,professions=123},availability={}}
    local saved={schemaVersion=6,characters={byID={[old.id]=old}}}
    local e2,c2,fire2=Start(forever,saved)
    local legacy=c2.Database:GetDB().characters.byID[old.id]
    -- Start already read a good location; remove that domain to emulate a frozen v4-only value.
    legacy.domains.location=nil; legacy.profile.zone="OldZone"; legacy.observedAt.profile=123
    e2.C_Map.GetBestMapForUnit=function() return nil end; fire2("ZONE_CHANGED_NEW_AREA")
    Check(legacy.profile.zone=="OldZone" and legacy.observedAt.profile==123,"first failed domain read cannot erase v4-only fields")
    Check(legacy.profile.professions[1].id==197 and legacy.observedAt.professions==123,"failed profession bootstrap preserves v4-only snapshot")
    Check(c2.Fields:GetValue(c2.Characters:GetCurrent(),c2.Fields._definitions["character.profession-primary"]).id==197,"failed first domain read still displays retained v4-only profession")
    e2.GetProfessions=function() return nil end
    e2.GetProfessionInfo=function() return "Unused",1,0,75,nil,nil,197 end
    fire2("SKILL_LINES_CHANGED")
    Check(c2.Fields:GetValue(c2.Characters:GetCurrent(),c2.Fields._definitions["character.profession-primary"])==nil,"confirmed empty snapshot cannot resurrect legacy profession")
    local savedAgain=c2.Defaults:Copy(c2.Database:GetDB())
    local _,restored=Start(forever,savedAgain)
    Check(restored.Fields:GetValue(restored.Characters:GetCurrent(),restored.Fields._definitions["character.profession-primary"])==nil,"known empty profession survives a failed read in the next session")

    for _,path in ipairs({"Professions","Equipment","Specialization"}) do
        local count=#c.DataDomains:GetDefinitions()
        load("YiboCore/Data/Domains/"..path..".lua")
        Check(#c.DataDomains:GetDefinitions()==count,"old residual path is inert")
    end

    local late,lateCore,lateEvent=Boot(forever)
    late.TEST_GUID="Player-Late"
    late.UnitClass=function() return nil end
    lateEvent("ADDON_LOADED")
    Check(lateCore:IsInitialized() and lateCore._private.characterPending,"facilities ready while native character still pending")
    lateCore:RegisterAddon("FixtureBusiness", {requiredAPI=13})
    local businessCalls=0
    lateCore.DataDomains:Register("FixtureBusiness", {id="fixture.business-ready",version=1,events={PLAYER_FLAGS_CHANGED=true},
        Collect=function() businessCalls=businessCalls+1; return {},"known" end})
    local collected={}
    for _,definition in ipairs(lateCore.DataDomains:GetDefinitions()) do
        local previous,id=definition.Collect,definition.id
        definition.Collect=function(context) collected[id]=(collected[id] or 0)+1; return previous(context) end
    end
    late.UnitClass=function() return "Hunter","HUNTER",3 end
    lateEvent("BAG_UPDATE_DELAYED")
    Check(lateCore.DomainStore:GetState("Player-Late","identity")=="known" and lateCore.DomainStore:GetState("Player-Late","location")=="known","late character recovery refreshes domains missed by native event")
    Check(collected.identity==1 and collected.location==1 and collected.professions==1,"recovery does not double-collect domains handled by the same native event")
    Check(businessCalls==0,"Core character recovery does not poll another owner's domains")
    lateEvent("PLAYER_FLAGS_CHANGED")
    Check(businessCalls==1,"other owner still receives its declared native event")
end
print("CoreIdentityDomainsR1 passed: "..checks.." checks (real Mists/Forever manifests, identity, fields and failure retention)")
