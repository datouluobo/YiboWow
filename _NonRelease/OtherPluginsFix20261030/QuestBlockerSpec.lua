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
local original=c.HasCapability
c.HasCapability=function(self,name,version) return name~='character-identity' and original(self,name,version) end
local saved={sentinel='keep'}; e.YiboQuestBlockerDB=saved
load('YiboQuestBlocker/Locale.lua','YiboQuestBlocker')
load('YiboQuestBlocker/YiboQuestBlocker_Core.lua','YiboQuestBlocker')
assert(not e.YQB.CoreCompatible and saved.sentinel=='keep' and next(saved,'sentinel')==nil)
c.HasCapability=original
e.WOW_PROJECT_ID=18
load('YiboQuestBlocker/Locale.lua','YiboQuestBlocker')
load('YiboQuestBlocker/YiboQuestBlocker_Core.lua','YiboQuestBlocker')
assert(not e.YQB.CoreCompatible and next(saved,'sentinel')==nil,'wrong client retains DB')
e.WOW_PROJECT_ID=19
local identity=c.Characters:GetCurrent({identityOnly=true})
local oldKey=identity.realm..'-'..identity.name
saved.schemaVersion=1
saved.knownChars={[oldKey]={class=identity.class,level=identity.level}}
saved.perChar={[oldKey]={blocked={[12345]=true},cache={[12345]='Retained quest'},customFact=7}}
saved.globalBlocked={[67890]=true};saved.globalCache={[67890]='Global quest'}
for line in io.lines('YiboQuestBlocker/YiboQuestBlocker.toc') do
    local path=line:match('^([^#].-%.lua)%s*$')
    if path then load('YiboQuestBlocker/'..path:gsub('\\','/'),'YiboQuestBlocker') end
end
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
print('PASS: QuestBlocker real TOC/Core, missing capability/client stops, page event coalescing, immediate actions and retained archive')
