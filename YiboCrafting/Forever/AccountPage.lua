local Addon,Core=_G.YiboCrafting,_G.YiboCore or {}
local Page,Theme={},Core.UITheme; Addon.AccountPage=Page
function Page:Fields()
    return {{id="profession",title=Addon:T("FOREVER.PROFESSION"),defaultVisible=true},{id="recipe",title=Addon:T("FOREVER.RECIPE"),defaultVisible=true},
        {id="learned",title=Addon:T("FOREVER.LEARNING"),defaultVisible=true},{id="state",title=Addon:T("FOREVER.DATA_STATE"),defaultVisible=true}}
end
function Page:Status()
    local keys={partial="FOREVER.PARTIAL",pending="FOREVER.PENDING",external="FOREVER.EXTERNAL",profile="FOREVER.PROFILE_PENDING",
        error="FOREVER.ERROR",unavailable="FOREVER.UNAVAILABLE",closed="FOREVER.CLOSED"}
    return Addon:T(keys[Addon.Scanner.state] or "FOREVER.UNKNOWN")
end
function Page:Create(parent)
    parent.heading=Theme:CreateText(parent,Theme.Font.section,Theme.Colors.text)
    parent.heading:SetPoint("TOPLEFT",12,-10); parent.heading:SetPoint("RIGHT",-130,0); parent.heading:SetHeight(26)
    parent.refresh=Theme:CreateButton(parent,100,Addon:T("FOREVER.REFRESH")); parent.refresh:SetPoint("TOPRIGHT",-12,-10)
    parent.refresh:SetScript("OnClick",function() Addon.Scanner:Scan() end)
    parent.professions=Theme:CreateText(parent,Theme.Font.body,Theme.Colors.text)
    parent.professions:SetPoint("TOPLEFT",12,-48); parent.professions:SetPoint("RIGHT",-12,0); parent.professions:SetHeight(60)
    parent.status=Theme:CreateText(parent,Theme.Font.assist,Theme.Colors.muted)
    parent.status:SetPoint("TOPLEFT",12,-112); parent.status:SetPoint("RIGHT",-12,0); parent.status:SetHeight(42)
    parent.header=CreateFrame("Frame",nil,parent); parent.header:SetPoint("TOPLEFT",12,-160); parent.header:SetPoint("TOPRIGHT",-12,-160); parent.header:SetHeight(26)
    parent.scroll=Theme:CreateScrollFrame(parent); parent.scroll:SetPoint("TOPLEFT",12,-190); parent.scroll:SetPoint("BOTTOMRIGHT",-12,10)
    parent.content=CreateFrame("Frame",nil,parent.scroll); parent.scroll:SetScrollChild(parent.content)
    parent.labels,parent.rows={},{}
    for _,field in ipairs(self:Fields()) do parent.labels[field.id]=Theme:CreateText(parent.header,Theme.Font.assist,Theme.Colors.muted) end
    parent.scroll:HookScript("OnVerticalScroll",function() Page:PaintRows(parent) end)
    parent.scroll:HookScript("OnSizeChanged",function() Page:PaintRows(parent) end)
end
local function Layout(container,labels,columns)
    for _,label in pairs(labels) do label:Hide() end
    for _,column in ipairs(columns) do local label=labels[column.id]; label:ClearAllPoints(); label:SetPoint("TOPLEFT",container,"TOPLEFT",column.x,0); label:SetSize(column.width,30); label:Show() end
end
function Page:Refresh(parent,context)
    local id=Core.Characters:GetCurrentID()
    local character=context.characters and context.characters[1]; if character and character.id~=id then character=nil end
    local profile=character and Addon:GetProfessionProfile()
    local names,summary,recipes={},{},{}
    if profile and profile.state=="known" then
        for _,profession in ipairs(profile.data.professions or {}) do
            names[profession.id]=profession.name
            summary[#summary+1]=Addon:T("FOREVER.PROFILE_LINE",profession.name,profession.skillLevel,profession.maxSkillLevel)
        end
        local snapshot=Addon.Store:Get(id)
        for pid,profession in pairs(snapshot and snapshot.professions or {}) do
            if names[pid] then
                local fresh=Addon.Scanner.inWorld and Addon.Scanner.open and Addon.Scanner.state=="partial" and Addon.Store.freshID==id and Addon.Store.freshProfessionID==pid
                for _,recipe in pairs(profession.recipes) do recipes[#recipes+1]={professionID=pid,profession=names[pid],recipe=recipe,
                    fresh=fresh and Addon.Store.freshRecipes and Addon.Store.freshRecipes[recipe.recipeID]~=nil} end
            end
        end
    end
    table.sort(recipes,function(a,b) return a.professionID==b.professionID and a.recipe.recipeID<b.recipe.recipeID or a.professionID<b.professionID end)
    parent.heading:SetText(character and Core.Characters:FormatName(character,{realmMode="full"}) or Addon:T("FOREVER.CURRENT"))
    parent.professions:SetText(#summary>0 and table.concat(summary," · ") or Addon:T("FOREVER.PROFILE_PENDING"))
    parent.status:SetText(self:Status()); parent.refresh:SetShown(not context.preview)
    parent.refresh:SetState(Addon.Scanner.inWorld and Addon.Scanner.open and "default" or "disabled")
    local width,columns,x,total=math.max(320,parent.scroll:GetWidth()-20),{},0,0
    local fields,weights=context.fields or self:Fields(),{profession=2,recipe=3.5,learned=1,state=1.6}
    for _,field in ipairs(fields) do total=total+(weights[field.id] or 1) end
    for _,field in ipairs(fields) do local w=width*(weights[field.id] or 1)/math.max(1,total); columns[#columns+1]={id=field.id,x=x,width=math.max(1,w-8)}; x=x+w; parent.labels[field.id]:SetText(field.title) end
    Layout(parent.header,parent.labels,columns); parent.content:SetWidth(width)
    parent.renderedRecipes,parent.columns,parent.rowWidth=recipes,columns,width
    parent.content:SetHeight(math.max(1,#recipes*30)); parent.scroll:SetContentHeight(#recipes*30)
    self:PaintRows(parent)
end
function Page:PaintRows(parent)
    if not parent.renderedRecipes then return end
    local first=math.floor((parent.scroll:GetVerticalScroll() or 0)/30)+1
    local capacity=math.ceil(math.max(1,parent.scroll:GetHeight())/30)+2
    local used=0
    for index=first,math.min(#parent.renderedRecipes,first+capacity-1) do
        used=used+1
        local item=parent.renderedRecipes[index]
        local row=parent.rows[used]
        if not row then
            row=CreateFrame("Frame",nil,parent.content,"BackdropTemplate"); row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"}); row.labels={}
            for _,field in ipairs(self:Fields()) do row.labels[field.id]=Theme:CreateText(row,Theme.Font.body,Theme.Colors.text) end
            parent.rows[used]=row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(index-1)*30); row:SetSize(parent.rowWidth,30); row:SetBackdropColor(unpack(index%2==0 and Theme.Colors.alternate or Theme.Colors.row))
        row.labels.profession:SetText(item.profession); row.labels.recipe:SetText(item.recipe.name)
        row.labels.learned:SetText(Addon:T(item.recipe.learned and "UI.LEARNED" or "FOREVER.NOT_LEARNED"))
        row.labels.state:SetText(Addon:T(item.fresh and "FOREVER.OBSERVED" or "FOREVER.OLD"))
        Layout(row,row.labels,parent.columns); row:Show()
    end
    for index=used+1,#parent.rows do parent.rows[index]:Hide() end
end
function Page:Register()
    local function Eligible(character)
        local profile=Addon:GetProfessionProfile()
        return character.id==Core.Characters:GetCurrentID() and profile and profile.state=="known" and #(profile.data.professions or {})>0
    end
    local ok,err=Core.AccountView:RegisterPage(Addon.NAME,{id=Addon.PAGE_ID,title=Addon:T("FOREVER.TITLE"),fields=self:Fields(),defaultEnabled=true,previewEnabled=true,
        HasCharacterSnapshot=Eligible,GetEligibleCharacters=function(characters) local result={}; for _,character in ipairs(characters or {}) do if Eligible(character) then result[#result+1]=character end end; return result end,
        GetPreviewFields=function() return Core.Defaults:Copy(Addon.Store.db.settings.previewColumns) end,
        SetPreviewFieldVisible=function(id,visible) for _,field in ipairs(Page:Fields()) do if id==field.id then Addon.Store.db.settings.previewColumns[id]=visible==true; Addon:NotifyChanged(); return true end end; return false end,
        GetSurfaceMetrics=function() return {minContentWidth=700,naturalContentWidth=1000,minContentHeight=300,naturalContentHeight=500} end,
        Create=function(parent) Page:Create(parent) end,Refresh=function(parent,context) Page:Refresh(parent,context) end})
    if not ok then return nil,err end
    return Core.Entry:RegisterBusinessEntry(Addon.NAME,{id="ycr",brokerName="YiboCrafting",pageID=Addon.PAGE_ID,text=Addon:T("FOREVER.TITLE"),
        icon="Interface\\AddOns\\YiboCrafting\\Media\\YiboCraftingIcon",defaultChannels={minimap=false,broker=false,builtinBar=false}})
end
