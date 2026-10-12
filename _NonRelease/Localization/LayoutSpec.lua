-- Real settings renderer and frame fixture from the existing workspace suite.
-- Geometry checks do not replace WoW font/rendering acceptance.
dofile("YiboMail/_NonRelease/Tests/WorkspaceSpec.lua")
local Core, checks = YiboCore, 0
dofile("YiboCore/Util/LevelFilter.lua")
local function Check(value, label) checks = checks + 1; assert(value, label) end
dofile("YiboCore/UI/AccountPages/CharacterArchive.lua")
dofile("YiboCore/UI/AccountPages/Overview.lua")
dofile("YiboCore/Runtime/SettingsRegistry.lua")
dofile("YiboCore/UI/AccountPages/SettingsWorkbench.lua")
dofile("YiboCore/UI/Entry.lua")
local fields = {
    { id = "identity", title = "Character", defaultVisible = true, defaultPreviewVisible = true },
    { id = "profession", title = "Primary profession", defaultVisible = true, defaultPreviewVisible = true },
}
Core.Fields = { GetByConsumer = function() return fields end }
Core.Locale:Initialize()
local view = Core.AccountView
view._pageOrder = {}
local business = { id = "fixture", addonName = "YiboFixture", title = "Fixture", fields = fields,
    previewEnabled = true, SetPreviewFieldVisible = function() end }
view._pageOrder[1], view._pages.fixture = business, business
view.settingsTargetPageID = "general"
local page = view._pages.settings
for _, language in ipairs({ "zh", "en" }) do
    Core.Locale.previewLanguage = language
    Core.Locale:RefreshBindings()
    for _, width in ipairs({ 620, 800, 1100 }) do
        local parent = CreateFrame("Frame", nil, UIParent); parent:SetSize(width, 650)
        page.Create(parent); parent.displaySection="general"; parent.scroll:SetSize(width - 20, 550)
        page.Refresh(parent)
        Check(parent.settingsContentHeight > 0, "settings render")
        local languageRow
        for _, row in ipairs(parent.rows) do
            if row.controlType == "dropdown" and row.label:GetText() == Core:Text("LANGUAGE.TITLE") then languageRow = row end
            if row.controlType == "core-entry" or row.controlType == "archive-entry" or row.controlType == "business-entry" then
                for _, control in ipairs({ row.title, row.dropdown, row.preview, row.mainFields, row.previewFields }) do
                    if control and control:IsShown() and control.points[1] then
                        local point = control.points[1]
                        local x = type(point[2]) == "number" and point[2] or 0
                        Check(x + control:GetWidth() <= parent.content:GetWidth() + 1, "display controls stay within viewport")
                    end
                end
            end
        end
        Check(languageRow ~= nil, "language selector in display settings")
        Check(#languageRow.dropdown.options == 3, "three language modes")
        Check(#parent.displayTabs==0, "general is an independent page")
        view.settingsTargetPageID="display";parent.displaySection="entries";page.Refresh(parent)
        for _,row in ipairs(parent.rows) do
            if row:IsShown() and row.controlType=="business-entry" then
                for _,control in ipairs({row.mainFields,row.previewFields}) do
                    if control:IsShown() then
                        local point=control.points[1];local top=-(point[#point] or 0)
                        Check(top+control:GetHeight()<=row:GetHeight(),"field row reserves full control height")
                    end
                end
            end
        end
        view.settingsTargetPageID="general";page.Refresh(parent)
        local previous = Core.Locale:GetLanguage()
        languageRow.dropdown.onValueChanged(previous == "en" and "zh" or "en")
        Check(Core.Locale:GetLanguage() == previous, "selection does not switch session text")
        page.Refresh(parent)
        local reload
        for _, row in ipairs(parent.rows) do
            if row.controlType == "button" and row.label:GetText() == Core:Text("LANGUAGE.RELOAD") then reload = row end
        end
        -- SetPreference may equal the session default in one iteration.
        if Core.Locale:IsReloadPending() then
            Check(reload ~= nil, "pending setting provides explicit reload action")
            local reloads = 0; ReloadUI = function() reloads = reloads + 1 end
            reload.scripts.OnClick(reload)
            Check(reloads == 1, "reload happens only on explicit click")
        end
    end
    Check(Core.UITheme:GetNavigationWidth() >= Core.UITheme:MeasureText(Core.UITheme.Font.body, Core:Text("CORE.CHARACTERS_SORTING")) + 40, "navigation includes natural label width")
    local dropdown = Core.UITheme:CreateDropdown(UIParent, 80, { { value = "long", label = "A longer English option" } })
    dropdown.scripts.OnClick(dropdown)
    Check(dropdown.menu:GetWidth() >= Core.UITheme:MeasureText(Core.UITheme.Font.body, "A longer English option") + 24, "popup fits natural option width")
end
Core.Locale.previewLanguage = nil
Core.Locale:RefreshBindings()
-- Core child navigation uses identical button and label anchors.
view.frame.preview=false;view.activePageID="settings";view.settingsTargetPageID="bar"
view:RefreshNavigation()
local offsets={}
for _,button in ipairs(view.frame.navButtons) do
 if button.shown then
  local id=button.settingsTargetID
  if id=="core" or id=="sorting" or id=="display" or id=="bar" then
   offsets[id]=button.points[1][2]
  end
 end
end
Check(offsets.bar~=nil and offsets.core==offsets.bar and offsets.sorting==offsets.bar and offsets.display==offsets.bar,"all Core child pages align")
dofile("YiboCore/UI/AccountPages/Help.lua")
local about={id="about",internal=true,GetSurfaceMetrics=view._internal.GetAboutSurfaceMetrics}
view._pages.about=about
local sizes=view:GetSettings().pageSizes
sizes["about:default"]={width=960,height=800}
sizes["help:default"]={width=960,height=180}
view:ApplyPageSize(about,{viewMode="default"})
local aboutHeight=view.frame:GetHeight()
view:ApplyPageSize(view._pages.help,{viewMode="default"})
Check(view.frame:GetHeight()==aboutHeight,"help uses saved About height despite stale small Help size")
sizes["about:default"]=nil;sizes["help:default"]={width=960,height=180}
view:ApplyPageSize(view._pages.help,{viewMode="default"})
local helpHeight=view.frame:GetHeight()
view:ApplyPageSize(about,{viewMode="default"})
Check(view.frame:GetHeight()==helpHeight,"help and About share default height")
-- Dense role settings reuse the shared input and preserve validation.
local pagesBefore=view._pageOrder
local filters={}
view._pageOrder={}
for i=1,12 do
 local id="role-fixture-"..i
 filters[id]="90"
 local entry={id=id,addonName=id,title="Fixture "..i,fields={},characterFilter={}}
 entry.characterFilter.GetExpression=function() return filters[id] end
 entry.characterFilter.SetExpression=function(value) filters[id]=value;return true end
 view._pageOrder[i]=entry
end
for _,language in ipairs({"zh","en"}) do
 Core.Locale.previewLanguage=language;Core.Locale:RefreshBindings()
 for _,width in ipairs({620,1200}) do
  local host=CreateFrame("Frame",nil,UIParent);host:SetSize(width,650)
  page.Create(host);host.scroll:SetSize(width-20,550);view.settingsTargetPageID="sorting";page.Refresh(host)
  local inputs,columns=0,{}
  for _,row in ipairs(host.rows) do
   if row:IsShown() and row.controlType=="input" then
    inputs=inputs+1
    Check(row.input.placeholder~=nil,"role editor uses shared CreateInput")
    Check(row.input:GetWidth()<=120,"role editor stays compact")
    if row.label:GetText():match("^Fixture") then columns[row.points[1][2]]=true end
    if row.label:GetText()=="Fixture 1" then
     row.input:SetText(">=55");row.input.scripts.OnEnterPressed(row.input)
     Check(filters["role-fixture-1"]==">=55","shared input saves validated expression")
    end
   elseif row:IsShown() and row.controlType=="button" then
    Check(row:GetWidth()<host.content:GetWidth()*0.75,"role button does not span full pane")
   end
  end
  local columnCount=0;for _ in pairs(columns) do columnCount=columnCount+1 end
  Check(columnCount>=2,"business filters use multiple columns")
  Check(inputs==14,"all business and archive filters retained")
 end
end
Core.Locale.previewLanguage=nil;Core.Locale:RefreshBindings();view._pageOrder=pagesBefore
view.activePageID="settings";view:RefreshNavigation()
local order={}
for _,button in ipairs(view.frame.navButtons) do
 if button.shown and button.settingsTargetID then order[#order+1]=button.settingsTargetID end
end
Check(order[3]=="sorting" and order[4]=="bar" and order[5]=="display","bar is between role sorting and display")
-- Real shared dropdown factories: peers exclude each other; nested group
-- selectors retain their parent and cannot survive the parent's closure.
local theme=Core.UITheme
local first=theme:CreateDropdown(UIParent,120,{{value=1,label="One"}})
local second=theme:CreateDropdown(UIParent,120,{{value=2,label="Two"}})
local multi=theme:CreateMultiSelectDropdown(UIParent,180,{
 {title="First",group="A"},{title="Second",group="B"},
})
first:Fire("OnClick");second:Fire("OnClick")
Check(not first.menu:IsShown() and second.menu:IsShown(),"ordinary dropdown peers are exclusive")
multi:Fire("OnClick")
Check(not second.menu:IsShown() and multi.menu:IsShown(),"multiselect excludes ordinary dropdown")
multi.groupSelector:Fire("OnClick")
Check(multi.menu:IsShown() and multi.groupSelector.menu:IsShown(),"nested group selector preserves parent")
first:Fire("OnClick")
Check(first.menu:IsShown() and not multi.menu:IsShown() and not multi.groupSelector.menu:IsShown(),"switching roots closes whole old menu chain")
first:Fire("OnClick");Check(not first.menu:IsShown(),"same button toggles closed")
multi:Fire("OnClick");multi.groupSelector:Fire("OnClick");multi:Hide()
Check(not multi.menu:IsShown() and not multi.groupSelector.menu:IsShown(),"hidden source closes its descendants")
first:Fire("OnClick");first.menu.buttons[1]:Fire("OnClick")
Check(first.value==1 and not first.menu:IsShown(),"selection still closes popup")
print("LocaleLayoutSpec passed: " .. checks .. " checks")
