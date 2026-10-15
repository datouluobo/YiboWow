-- Actual Crafting page/input/resources with deterministic frame geometry.
local function Frame()
    local f={scripts={},width=1200,height=640,shown=true,text=""}
    function f:SetScript(event, fn) self.scripts[event]=fn end
    function f:GetScript(event) return self.scripts[event] end
    function f:HookScript(event, fn) local old=self.scripts[event];self.scripts[event]=function(...)if old then old(...)end;fn(...)end end
    function f:SetSize(w,h)self.width,self.height=w,h end
    function f:SetWidth(w)self.width=w end
    function f:SetHeight(h)self.height=h end
    function f:GetWidth()return self.width end
    function f:GetHeight()return self.height end
    function f:GetVerticalScroll()return 0 end
    function f:GetFrameLevel()return 1 end
    function f:SetText(text)self.text=text or "" end
    function f:GetText()return self.text end
    function f:SetShown(v)self.shown=v end
    function f:IsShown()return self.shown end
    function f:Show()self.shown=true end
    function f:Hide()self.shown=false end
    function f:CreateTexture()return Frame() end
    function f:CreateFontString()return Frame() end
    function f:IsMouseOver()return false end
    return setmetatable(f,{__index=function(_,key)if key:match("^[A-Z]")then return function()end end end})
end
CreateFrame=Frame;GameTooltip=Frame();STANDARD_TEXT_FONT="fixture"
local theme={Colors={},Font={body=16,assist=14,section=16},Table={rowHeight=28,cellInset=4,iconTextRasterTolerance=1},
    Space={xs=4,sm=8,md=16},Size={standard=30},Geometry={shellBorder=1,titleBar=46}}
for _,key in ipairs({"text","muted","warning","panel","row","alternate","bg","accent","lineSoft","matrixLine","selected"})do theme.Colors[key]={0,0,0,1}end
theme.CreateText=function()return Frame()end
theme.CreateMatrixHeader=theme.CreateText;theme.SetCharacterHeader=function()end
theme.GetMatrixInsets=function()return{left=8,right=8,top=8,bottom=8}end
theme.GetIconTextColumnWidth=function(_,_,_,text)return math.max(66,#text*7+24)end
theme.MeasureText=function(_,_,text)return #text*7 end
theme.CreateButton=function(_,_,_,label)local f=Frame();f:SetText(label);return f end
theme.CreateDropdown=function()local f=Frame();f.menu=Frame();return f end
theme.CreateScrollFrame=function()return Frame()end
local registered,entry,refreshes=nil,nil,0
YiboCore={UITheme=theme,ItemResolver={GetInfo=function()return{state="unloaded"}end},
    DataDomains={Get=function()return{state="known",data={professions={{id=333,name="附魔"}}}}end},
    Characters={GetCurrentID=function()return"A"end,FormatName=function(_,identity)return identity.name end},
    AccountView={RegisterPage=function(_,_,p)registered=p;return p end,
        GetScrollSurfaceWidth=function(_,context,parent)return context.surfaceAvailableWidth or parent:GetWidth()end,
        FitRepeatedColumnWidth=function()return 110 end,
        GetColumnPage=function(_,_,_,characters)return characters,{}end,
        UpdateColumnPager=function()end,NotifyPageChanged=function()refreshes=refreshes+1 end},
    Entry={RegisterBusinessEntry=function(_,_,e)entry=e;return true end}}
dofile("YiboCrafting/Namespace.lua")
dofile("YiboCrafting/Tests/LoadLocale.lua")
dofile("YiboCore/UI/Input.lua")
dofile("YiboCrafting/Store.lua");assert(YiboCrafting.Store:Initialize())
dofile("YiboCrafting/CategoryCatalog.lua")
YiboCrafting.RecipeCatalog={catalogVersion="test",professions={[333]={}}}
for id=1,100 do YiboCrafting.RecipeCatalog.professions[333][id]={outputItemIDs={600}}end
GetSpellInfo=function(id)return"Recipe "..id end
YiboCrafting.Store.db.characters.A={professions={[333]={learnedRecipeIDs={[1]=true}}}}
dofile("YiboCrafting/AccountPage.lua")
local Page=YiboCrafting.AccountPage;assert(Page:Register())
assert(registered.previewEnabled and registered.settings)
assert(entry.defaultChannels.broker==false and entry.defaultChannels.builtinBar==false)
local chars={{id="A",name="Alpha"},{id="B",name="Beta"}}
assert(#registered.GetEligibleCharacters(chars,{preview=true})==1)
assert(#registered.GetEligibleCharacters(chars,{preview=false})==2)
local fields=registered.GetPreviewFields();fields["recipe-name"]=false
assert(registered.GetPreviewFields()["recipe-name"]==true,"preview fields are returned as copies")
registered.SetPreviewFieldVisible("recipe-name",false);assert(refreshes==1)
registered.SetPreviewFieldVisible("recipe-name",true)
local metrics=registered.GetHoverMetrics({characters=chars,preview=true,surfaceAvailableHeight=300})
assert(metrics.preferredHeight==348 and type(metrics.scrollContentHeight)=="number" and type(metrics.scrollFixedHeight)=="number")
YiboCore.Locale.previewLanguage="en"
local parent=Frame();Page:Create(parent)
assert(parent.crafting.search.SetValue,"uses Core basic-input rather than a local EditBox implementation")
local context={characters={chars[1]},scope="all",preview=true,surfaceAvailableWidth=1200,surfaceAvailableHeight=300,
    GetFieldVisible=function()return true end}
YiboCore.Locale.previewLanguage="en";Page:Refresh(parent,context)
assert(select(2,Page:Snapshot(context))[1].name=="Enchanting","profession ID localization overrides native snapshot names")
assert(parent.crafting.searchHint.text=="Search recipes, products or IDs", "English search hint: "..tostring(parent.crafting.searchHint.text))
assert(#parent.crafting.matrix.visibleItems<100,"hover is a bounded projection of the shared recipe snapshot")
assert(not parent.crafting.modeProfession.shown,"hover cannot misleadingly switch to a hidden layout")
local input=parent.crafting.search
local composing=true
input.IsInIMECompositionMode=function()return composing end
input:SetText("灯");input.scripts.OnTextChanged(input,true)
assert(parent.crafting.state.search=="","IME composition must not bypass the Core input handler")
composing=false;input.scripts.OnUpdate(input)
assert(parent.crafting.state.search=="灯","Core input forwards the committed IME text")
parent.crafting.state.search=""
YiboCore.Locale.previewLanguage="zh";parent=Frame();Page:Create(parent);Page:Refresh(parent,context)
assert(select(2,Page:Snapshot(context))[1].name=="附魔","Chinese profession label")
assert(parent.crafting.searchHint.text=="搜索配方、产物或 ID")
local category=YiboCrafting.CategoryCatalog
assert(category:GetID(129,3275)=="BANDAGES")
assert(category:Get(129,3275)=="绷带")
YiboCore.Locale.previewLanguage="en";assert(category:Get(129,3275)=="Bandages")
local resources=YiboCore.Locale.resources.YiboCrafting
for key in pairs(resources.zh)do assert(resources.en[key],"missing English: "..key)end
for key in pairs(resources.en)do assert(resources.zh[key],"missing Chinese: "..key)end
assert(#YiboCore.Locale:GetMissingEnglish("YiboCrafting")==0)
print("CoreAdaptation OK: owner resources, shared input, preview admission/fields/height, settings, channels and stable category IDs")
