local Env=dofile('_NonRelease/OtherPluginsFix20261030/Harness.lua')
local checks=0
for _,client in ipairs({'zhCN','enUS'}) do for _,mode in ipairs({'auto','zh','en'}) do
    local e=Env();e.GetLocale=function() return client end
    e.YiboCore={Capabilities={Register=function() end}}
    e.load('YiboCore/Runtime/Locale.lua')
    local locale=e.YiboCore.Locale
    if mode~='auto' then locale.previewLanguage=mode end
    e.load('YiboLegendary/Bootstrap.lua','YiboLegendary')
    e.load('YiboLegendary/Locales/Interface.lua')
    e.load('YiboQuestBlocker/Locale.lua')
    local ns={};e.load('YiboMounts/Namespace.lua','YiboMounts',ns)
    e.load('YiboMounts/Locale/zhCN.lua','YiboMounts',ns)
    e.load('YiboMounts/Locale/enUS.lua','YiboMounts',ns)
    locale:Register('YiboMounts','zh',ns.Locale.zhCN);locale:Register('YiboMounts','en',ns.Locale.enUS)
    ns.CoreIntegration={localeAvailable=true}
    local values={e.YiboLegendary:T('ERROR.CLIENT_REQUIRED'),locale:Get('YiboQuestBlocker','CORE.STARTUP_REQUIREMENTS'),ns:L('CLIENT_REQUIRED')}
    local english=mode=='en' or (mode=='auto' and client=='enUS')
    for _,value in ipairs(values) do
        checks=checks+1
        assert(type(value)=='string' and value:sub(1,1)~='[','startup key resolves')
        assert((value:find('Mists Classic',1,true)~=nil)==english,'Core session language applies')
    end
end end
print('PASS: '..checks..' startup resource checks across Chinese/English clients and auto/manual languages (offline)')
