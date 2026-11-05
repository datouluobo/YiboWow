-- Real Core layout with six registered business pages and old narrow saved sizes.
local SourceBoot = dofile('_NonRelease/CoreRetailR2/Harness.lua')
local function Boot(target, saved, project, configure)
    return SourceBoot(target, saved, project, configure, nil,
        target == 'Forever' and arg and arg[1] or nil,
        target == 'Forever' and arg and arg[1] and 'YiboCore.toc' or nil)
end
local checks = 0
local function Check(value, label) checks=checks+1; assert(value,label) end
for _, target in ipairs({'Forever','Mists','Retail'}) do
    for _, language in ipairs({'zhCN','enUS'}) do
        local e,c,event,flush=Boot(target,nil,nil,function(env)
            env.GetLocale=function() return language end
            env.UIParent:SetSize(2048,1080)
        end)
        event('ADDON_LOADED'); event('PLAYER_LOGIN'); flush()
        local view,theme=c.AccountView,c.UITheme
        for n=1,6 do
            local owner='LayoutFixture'..n
            Check(c:RegisterAddon(owner,{requiredAPI=13}), 'fixture owner')
            Check(view:RegisterPage(owner,{id='layout.'..n,title='Layout '..n,Create=function() end,Refresh=function() end}), 'fixture page')
        end
        local settings=view:GetSettings()
        local context=view:BuildContext(view._pages.characters)
        settings.pageSizes['characters:'..tostring(context.viewMode or 'default')]={width=960,height=350}
        view:Toggle('characters'); flush()
        local frame=view.frame
        local metrics=view._pages.characters.GetSurfaceMetrics(view:BuildContext(view._pages.characters))
        local shellWidth=theme:GetNavigationWidth()+theme.Geometry.shellBorder*2+1
        Check(frame:GetWidth()-shellWidth>=metrics.naturalContentWidth, target..'/'..language..' visible archive columns fit old saved width')
        local count=0
        for _,button in ipairs(frame.navButtons) do if button:IsShown() then count=count+1 end end
        Check(count==11,'back, overview, archive, six businesses, help, about')
        local required=theme.Geometry.titleBar+theme.Geometry.shellBorder*2+16+count*theme.Table.rowHeight+(count-1)*theme.Space.xxs
        Check(frame:GetHeight()>=required,'all navigation rows fit old saved height')
        Check(frame.navButtons[count].pageID=='about','about remains last navigation item')
        local stableWidth,stableHeight=frame:GetWidth(),frame:GetHeight()
        view:ShowPage('characters'); flush()
        Check(frame:GetWidth()==stableWidth and frame:GetHeight()==stableHeight,'repeat layout stable')
    end
end
print('PASS archive/navigation bounds: '..checks..' checks across three targets/two languages')
