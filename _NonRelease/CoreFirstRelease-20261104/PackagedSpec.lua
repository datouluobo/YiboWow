local Boot = dofile('_NonRelease/CoreRetailR2/Harness.lua')
local checks = 0
local function Check(value, label) checks=checks+1; assert(value,label) end
local roots={'_NonRelease/CoreFirstRelease-20261104/Clean/YiboCore'}
if arg[1] then roots[#roots+1]=arg[1] end
for _,root in ipairs(roots) do
  for _,mode in ipairs({{'zhCN','auto','zh'},{'enUS','auto','en'},{'zhCN','en','en'},{'enUS','zh','zh'},{'zhTW','auto','zh'}}) do
    local saved={schemaVersion=11, clientScope={target='Forever',projectID=18,rulesetState='unknown'},marker='keep',settings={language=mode[2]},characters={byID={}}}
    local e,c,fire,flush=Boot('Forever',saved,nil,function(env) env.GetLocale=function() return mode[1] end end,nil,root,'YiboCore.toc')
    local ready=0; c.Events:Register('CORE_READY',{},function() ready=ready+1 end)
    fire('ADDON_LOADED'); fire('ADDON_LOADED'); fire('PLAYER_LOGIN'); flush()
    Check(c:IsInitialized(),'package ready'); Check(c.VERSION=='0.2.0','target version'); Check(c.API_VERSION==13 and c:HasCapability('localization',1),'API capability ready')
    Check(c.Database:GetDB()==e.YiboCoreForeverDB and saved.marker=='keep','own store preserved')
    Check(e.YiboCoreDB.sentinel=='mists' and e.YiboCoreRetailDB.sentinel=='retail','other stores untouched')
    Check(ready==1,'one ready notification'); Check(c.Locale:GetLanguage()==mode[3],'language mode')
    Check(c:Initialize() and ready==1,'repeat initialization')
    c.AccountView:ShowPage('characters'); flush(); Check(not c.AccountView._pages.characters.lastError,'archive rendering')
    c.AccountView:ShowSettings('sorting'); flush(); Check(not c.AccountView._pages.settings.lastError,'settings rendering')
    local helper=c.AccountView._internal
    Check(helper.SetArchiveLevelFilter('page','>=5'),'persist page filter'); Check(helper.SetArchiveLevelFilter('preview','1-20'),'persist preview filter')
    local copy=c.Defaults:Copy(c.Database:GetDB())
    local re,rc,rf,rt=Boot('Forever',copy,nil,function(env) env.GetLocale=function() return mode[1] end end,nil,root,'YiboCore.toc')
    rf('ADDON_LOADED'); rt(); Check(rc:IsInitialized(),'snapshot restore startup')
    local filters=rc.AccountView._internal.ArchiveSettings().filters
    Check(filters.page.levelExpr=='>=5' and filters.preview.levelExpr=='1-20','snapshot filter restore')
    Check(rc.Locale:GetLanguage()==mode[3] and copy.marker=='keep','snapshot settings restore')
    Check(#e.TEST_MESSAGES==0 and #re.TEST_MESSAGES==0,'no callback failures')
  end
  for _,wrong in ipairs({'Mists','Retail'}) do
    local e,c,fire=Boot(wrong,nil,nil,nil,nil,root,'YiboCore.toc'); fire('ADDON_LOADED')
    Check(not c:IsInitialized(),'wrong target stops')
    Check(not c.Database:GetDB(),'wrong target does not initialize store')
    Check(not e.YiboCoreForeverDB.characters,'wrong target leaves foreign store')
  end
end
print('PASS packaged Forever clean/overlay: '..checks..' checks; actual game rendering and disk persistence remain pending')
