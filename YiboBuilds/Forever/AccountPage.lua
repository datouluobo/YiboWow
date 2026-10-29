local Addon,Core=_G.YiboBuilds,_G.YiboCore or {}
local Page,Theme={},Core.UITheme; Addon.AccountPage=Page
local slotKeys={"FOREVER.SLOT_HEAD","FOREVER.SLOT_NECK","FOREVER.SLOT_SHOULDER","FOREVER.SLOT_SHIRT","FOREVER.SLOT_CHEST","FOREVER.SLOT_WAIST","FOREVER.SLOT_LEGS","FOREVER.SLOT_FEET","FOREVER.SLOT_WRIST","FOREVER.SLOT_HANDS","FOREVER.SLOT_FINGER1","FOREVER.SLOT_FINGER2","FOREVER.SLOT_TRINKET1","FOREVER.SLOT_TRINKET2","FOREVER.SLOT_BACK","FOREVER.SLOT_MAINHAND","FOREVER.SLOT_OFFHAND","FOREVER.SLOT_RANGED","FOREVER.SLOT_TABARD"}
function Page:Fields() return {{id="slot",title=Addon:T("FOREVER.SLOT"),defaultVisible=true},{id="item",title=Addon:T("FOREVER.ITEM"),defaultVisible=true}} end
function Page:Status()
    local _,state=Addon.Store:Get(Core.Characters:GetCurrentID())
    local keys={known="FOREVER.KNOWN",stale="FOREVER.STALE",error="FOREVER.ERROR",unknown="FOREVER.UNKNOWN"}
    return Addon:T(keys[state] or "FOREVER.UNKNOWN")
end
function Page:ItemText(item)
    if item.itemID==0 then return Addon:T("FOREVER.EMPTY") end
    local ok,info=pcall(Core.ItemResolver.GetInfo,Core.ItemResolver,item.itemID)
    if ok and type(info)=="table" and Addon.Store:Plain(info.name) and type(info.name)=="string" and info.name~="" then return info.name end
    return Addon:T("FOREVER.UNCACHED",item.itemID)
end
function Page:Create(parent)
    parent.heading=Theme:CreateText(parent,Theme.Font.section,Theme.Colors.text)
    parent.heading:SetPoint("TOPLEFT",12,-10); parent.heading:SetPoint("RIGHT",-130,0); parent.heading:SetHeight(26)
    parent.refresh=Theme:CreateButton(parent,100,Addon:T("FOREVER.REFRESH")); parent.refresh:SetPoint("TOPRIGHT",-12,-10)
    parent.refresh:SetScript("OnClick",function() Addon.Scanner:Scan(true) end)
    parent.status=Theme:CreateText(parent,Theme.Font.assist,Theme.Colors.muted)
    parent.status:SetPoint("TOPLEFT",12,-48); parent.status:SetPoint("RIGHT",-12,0); parent.status:SetHeight(42)
    parent.header=CreateFrame("Frame",nil,parent); parent.header:SetPoint("TOPLEFT",12,-96); parent.header:SetPoint("TOPRIGHT",-12,-96); parent.header:SetHeight(26)
    parent.scroll=Theme:CreateScrollFrame(parent); parent.scroll:SetPoint("TOPLEFT",12,-126); parent.scroll:SetPoint("BOTTOMRIGHT",-12,10)
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
    local snapshot=character and Addon.Store:Get(id)
    local equipment={}
    for slot=1,19 do if snapshot then equipment[#equipment+1]={slot=slot,item=snapshot.slots[slot]} end end
    parent.heading:SetText(character and Core.Characters:FormatName(character,{realmMode="full"}) or Addon:T("FOREVER.CURRENT"))
    parent.status:SetText(self:Status()); parent.refresh:SetShown(not context.preview)
    parent.refresh:SetState(Addon.Scanner.inWorld and "default" or "disabled")
    local width,columns,x,total=math.max(320,parent.scroll:GetWidth()-20),{},0,0
    local fields,weights=context.fields or self:Fields(),{slot=1,item=3}
    for _,field in ipairs(fields) do total=total+(weights[field.id] or 1) end
    for _,field in ipairs(fields) do local w=width*(weights[field.id] or 1)/math.max(1,total); columns[#columns+1]={id=field.id,x=x,width=math.max(1,w-8)}; x=x+w; parent.labels[field.id]:SetText(field.title) end
    Layout(parent.header,parent.labels,columns); parent.content:SetWidth(width)
    parent.renderedEquipment,parent.columns,parent.rowWidth=equipment,columns,width
    parent.content:SetHeight(math.max(1,#equipment*30)); parent.scroll:SetContentHeight(#equipment*30)
    self:PaintRows(parent)
end
function Page:PaintRows(parent)
    if not parent.renderedEquipment then return end
    local first=math.floor((parent.scroll:GetVerticalScroll() or 0)/30)+1
    local capacity=math.ceil(math.max(1,parent.scroll:GetHeight())/30)+2
    local used=0
    for index=first,math.min(#parent.renderedEquipment,first+capacity-1) do
        used=used+1
        local item=parent.renderedEquipment[index]
        local row=parent.rows[used]
        if not row then
            row=CreateFrame("Frame",nil,parent.content,"BackdropTemplate"); row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"}); row.labels={}
            for _,field in ipairs(self:Fields()) do row.labels[field.id]=Theme:CreateText(row,Theme.Font.body,Theme.Colors.text) end
            parent.rows[used]=row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(index-1)*30); row:SetSize(parent.rowWidth,30); row:SetBackdropColor(unpack(index%2==0 and Theme.Colors.alternate or Theme.Colors.row))
        row.labels.slot:SetText(Addon:T(slotKeys[item.slot])); row.labels.item:SetText(self:ItemText(item.item))
        Layout(row,row.labels,parent.columns); row:Show()
    end
    for index=used+1,#parent.rows do parent.rows[index]:Hide() end
end
function Page:Register()
    local function Eligible(character)
        return character.id==Core.Characters:GetCurrentID() and Addon.Store.db.characters[character.id]~=nil
    end
    local ok,err=Core.AccountView:RegisterPage(Addon.NAME,{id=Addon.PAGE_ID,title=Addon:T("FOREVER.TITLE"),fields=self:Fields(),defaultEnabled=true,previewEnabled=true,
        HasCharacterSnapshot=Eligible,GetEligibleCharacters=function(characters) local result={}; for _,character in ipairs(characters or {}) do if Eligible(character) then result[#result+1]=character end end; return result end,
        GetPreviewFields=function() return Core.Defaults:Copy(Addon.Store.db.settings.previewColumns) end,
        SetPreviewFieldVisible=function(id,visible) for _,field in ipairs(Page:Fields()) do if id==field.id then Addon.Store.db.settings.previewColumns[id]=visible==true; Addon:NotifyChanged(); return true end end; return false end,
        GetSurfaceMetrics=function() return {minContentWidth=420,naturalContentWidth=760,minContentHeight=260,naturalContentHeight=560} end,
        Create=function(parent) Page:Create(parent) end,Refresh=function(parent,context) Page:Refresh(parent,context) end})
    if not ok then return nil,err end
    return Core.Entry:RegisterBusinessEntry(Addon.NAME,{id="ybb",brokerName="YiboBuilds",pageID=Addon.PAGE_ID,text=Addon:T("FOREVER.TITLE"),
        icon="Interface\\AddOns\\YiboBuilds\\Media\\YiboBuildsIcon",defaultChannels={minimap=false,broker=false,builtinBar=false}})
end
