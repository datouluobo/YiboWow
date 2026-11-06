local Env=dofile('_NonRelease/OtherPluginsFix20261030/Harness.lua')
for _,project in ipairs({19,18}) do
    local e=Env();e.WOW_PROJECT_ID=project
    e.GetLocale=function() return 'enUS' end
    local messages,hooks={},0
    e.DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
    e.YiboMountsDB={version=1,settings={collectionStatus={showCollected=false,showUncollected=true}},customFact=42}
    e.YiboMountsDiagnostics={customFact=13}
    local saved,diagnostics=e.YiboMountsDB,e.YiboMountsDiagnostics
    e.GameTooltip={HookScript=function() hooks=hooks+1 end}
    local ns,loaded={},{}
    for line in io.lines('YiboMounts/YiboMounts.toc') do
        local path=line:match('^([^#].-%.lua)%s*$')
        if path then
            path=path:gsub('\\','/');loaded[path]=(loaded[path] or 0)+1
            e.load('YiboMounts/'..path,'YiboMounts',ns)
        end
    end
    assert(loaded['Mists/CollectionState.lua']==1 and loaded['Tooltip.lua']==1,'TOC loads one new collection implementation')
    local boot=e.frame
    boot.OnEvent(nil,'ADDON_LOADED','YiboMounts')
    boot.OnEvent(nil,'PLAYER_LOGIN')
    if project==19 then
        assert(ns.Probe.initialized and ns.Tooltip.initialized and hooks>0,'standalone source hints still start without Core')
        local count=hooks
        boot.OnEvent(nil,'ADDON_LOADED','YiboMounts');boot.OnEvent(nil,'PLAYER_LOGIN')
        assert(hooks==count,'repeat events do not duplicate hooks')
        assert(not ns.CoreIntegration.initialized,'Core-backed enhancement stays unavailable without Core')
    else
        assert(not ns.Probe.initialized and not ns.Tooltip.initialized and hooks==0,'wrong target stops registrations')
        assert(#messages==1 and messages[1]:find('Mists Classic',1,true),'localized wrong-client notice')
    end
    assert(e.YiboMountsDB==saved and saved.customFact==42 and not saved.settings.collectionStatus.showCollected,'settings identity retained')
    assert(e.YiboMountsDiagnostics==diagnostics and diagnostics.customFact==13,'diagnostic archive retained')
end
print('PASS: real Mounts TOC, one collection implementation, source-only mode, wrong-target stop, idempotent hooks and settings retention')
