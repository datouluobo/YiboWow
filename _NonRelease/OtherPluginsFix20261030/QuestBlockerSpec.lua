local Boot=dofile('_NonRelease/CoreForever/Harness.lua')
local function Start()
    local e,c,fire,flush,load=Boot(false)
    e.TEST_GUID='Player-Quest-1'; e.IsLoggedIn=function() return true end
    e.GetNumQuestLogEntries=function() return 0 end
    fire('ADDON_LOADED');fire('PLAYER_LOGIN');flush()
    assert(c:IsInitialized())
    return e,c,fire,flush,load
end
local e,c,fire,flush,load=Start()
local function LoadQuestBlocker(loader, trigger)
    for line in io.lines('YiboQuestBlocker/YiboQuestBlocker_Mists.toc') do
        local path=line:match('^([^#].-%.lua)%s*$')
        if path then loader('YiboQuestBlocker/'..path:gsub('\\','/'),'YiboQuestBlocker') end
    end
    trigger('ADDON_LOADED','YiboQuestBlocker')
end
local original=c.HasCapability
c.HasCapability=function(self,name,version) return name~='character-identity' and original(self,name,version) end
local saved={sentinel='keep'}; e.YiboQuestBlockerDB=saved
LoadQuestBlocker(load,fire)
assert(not e.YQB.CoreCompatible and saved.sentinel=='keep' and next(saved,'sentinel')==nil)
c.HasCapability=original
e.WOW_PROJECT_ID=18
LoadQuestBlocker(load,fire)
assert(not e.YQB.CoreCompatible and next(saved,'sentinel')==nil,'wrong client retains DB')
e.WOW_PROJECT_ID=19
local identity=c.Characters:GetCurrent({identityOnly=true})
local oldKey=identity.realm..'-'..identity.name
saved.schemaVersion=1
saved.knownChars={[oldKey]={class=identity.class,level=identity.level}}
saved.perChar={[oldKey]={blocked={[12345]=true},cache={[12345]='Retained quest'},customFact=7}}
saved.globalBlocked={[67890]=true};saved.globalCache={[67890]='Global quest'}
LoadQuestBlocker(load,fire)
assert(e.YQB.CoreCompatible and e.YQB.CoreIntegration.initialized)
assert(saved.characterData[identity.id].blocked[12345] and saved.characterData[identity.id].customFact==7)
assert(saved.characterData[identity.id].cache[12345]=='Retained quest' and saved.globalBlocked[67890],'legacy rules and cache retained')
local notifications=0
c.AccountView.NotifyPageChanged=function(_,id) assert(id=='quest-blocker');notifications=notifications+1 end
for i=1,100 do fire('QUEST_LOG_UPDATE') end
assert(notifications==0 and #e.TEST_TIMERS==1,'quest-log page notifications coalesce')
flush();assert(notifications==1)
e.YQB.NotifyCorePageChanged(true);e.YQB.NotifyCorePageChanged();flush()
assert(notifications==2,'synchronous rule change replaces pending notification')
local registrations=#e.TEST_FRAMES
assert(e.YQB.CoreIntegration:Initialize() and #e.TEST_FRAMES==registrations,'repeat initialization does not register again')
assert(e.YiboQuestBlockerDB==saved and saved.sentinel=='keep','archive identity retained')
assert(e.YQB.IsAutoRejectEnabled() and e.YQB.IsAutoAbandonEnabled(),'Mists legacy direct retains its abandonment fallback')
local accepted, declined, abandoned, selected = 0, 0, 0, 12345
e.GetQuestID=function() return selected end
e.AcceptQuest=function() accepted=accepted+1 end
e.DeclineQuest=function() declined=declined+1 end
fire('ADDON_LOADED','AutoQuestFixture')
e.AcceptQuest()
selected=42
e.AcceptQuest()
assert(declined==1 and accepted==1,'direct mode declines only matching offers')
e.GetNumQuestLogEntries=function() return abandoned==0 and 1 or 0 end
e.GetQuestLogTitle=function() return 'Kept quest',90,nil,false,nil,false,1,12345 end
e.GetQuestLogIndexByID=function(id) return abandoned==0 and id==12345 and 1 or nil end
e.SelectQuestLogEntry=function() end
e.SetAbandonQuest=function() end
e.AbandonQuest=function() abandoned=abandoned+1 end
e.YQB.SetProcessMode('abandon')
e.YQB.AddCharBlock(12345,'OtherCharacter')
flush()
assert(abandoned==0,'a rule change on another character does not queue current work')
e.YQB.AddBlock(12345,'global')
e.YQB.SetProcessMode('paused')
flush()
assert(abandoned==0 and e.YQB.AbandonRejectedQuestsInLog()==0,'pause cancels pending and manual abandonment')
e.YQB.SetProcessMode('abandon')
e.YQB.RemoveBlock(12345,'global')
flush()
assert(abandoned==1,'remaining current-role rule still queues abandonment')
print('PASS: QuestBlocker real TOC/Core, missing capability/client stops, page event coalescing, immediate actions and retained archive')
