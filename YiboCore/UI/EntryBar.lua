local Core = _G.YiboCore
local Bar = { buttons = {}, page = 1 }
Core.EntryBar = Bar
local Theme = Core.UITheme
function Bar:EnsureFrame()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "YiboCoreEntryBar", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("MEDIUM"); frame:SetMovable(true); frame:SetClampedToScreen(true)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8",edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=1})
    local c = Theme.Colors
    frame:SetBackdropColor(c.panel[1],c.panel[2],c.panel[3],0.95)
    frame:SetBackdropBorderColor(c.lineSoft[1],c.lineSoft[2],c.lineSoft[3],1)
    local handle = CreateFrame("Button",nil,frame)
    handle:SetSize(18,18); handle:SetPoint("TOPLEFT",2,-2); handle:EnableMouse(true); handle:RegisterForDrag("LeftButton")
    handle.label = Theme:CreateText(handle,Theme.Font.body,c.muted,"CENTER"); handle.label:SetAllPoints(); handle.label:SetText("::")
    handle:SetScript("OnDragStart",function() if not Core.Entry:GetBuiltinBarSettings().locked then frame:StartMoving(); Bar.dragging=true end end)
    handle:SetScript("OnDragStop",function()
        frame:StopMovingOrSizing(); Bar.dragging=nil
        local point,_,relativePoint,x,y = frame:GetPoint()
        Core.Entry:SetBuiltinBarPosition(point,relativePoint,x,y)
    end)
    frame.handle = handle
    frame.previous = Theme:CreateButton(frame,28,"<")
    frame.next = Theme:CreateButton(frame,28,">")
    frame.previous:SetScript("OnClick",function() Bar.page=math.max(1,Bar.page-1);Bar:Refresh() end)
    frame.next:SetScript("OnClick",function() Bar.page=Bar.page+1;Bar:Refresh() end)
    self.frame = frame
    return frame
end
-- Pure layout contract also used by the non-release tests.
function Bar:Layout(widths, iconSize, spacing, safeWidth, safeHeight)
    local padding,handle = 6,22
    local limit = math.max(handle+padding*2+iconSize,safeWidth)
    local maxRows = math.max(1,math.floor((safeHeight-32-padding*2)/(iconSize+spacing)))
    local pages, page = {}, {items={},width=0,height=0}
    pages[1]=page
    local x,y,row=handle+padding,padding,1
    for index,width in ipairs(widths) do
        width=math.min(width,limit-handle-padding*2)
        if x+width+padding > limit and #page.items > 0 then x=handle+padding;y=y+iconSize+spacing;row=row+1 end
        if row > maxRows then
            page={items={},width=0,height=0};pages[#pages+1]=page;x=handle+padding;y=padding;row=1
        end
        page.items[#page.items+1]={index=index,x=x,y=y,width=width}
        page.width=math.max(page.width,x+width+padding);page.height=y+iconSize+padding
        x=x+width+spacing
    end
    return pages
end
function Bar:FinishIconDrag(targetID)
    local sourceID=self.draggedID
    self.draggedID=nil
    for _,button in ipairs(self.buttons) do button:SetAlpha(1) end
    if sourceID and targetID then Core.Entry:ReorderBuiltinBarEntry(sourceID,targetID) end
end
function Bar:Refresh()
    local settings = Core.Entry:GetBuiltinBarSettings()
    local entries = Core.Entry:GetBuiltinBarEntries()
    if not settings.enabled or #entries == 0 then
        if self.frame then self.frame:StopMovingOrSizing();self.frame:Hide() end
        self.dragging=nil;self:FinishIconDrag();Core.Entry:CloseEntryPreview(nil,"builtinBar");return
    end
    local frame = self:EnsureFrame()
    if settings.locked and self.dragging then frame:StopMovingOrSizing();self.dragging=nil end
    frame.handle:SetShown(not settings.locked)
    local backgrounds = {
        theme=Theme.Colors.panel,black={0,0,0},charcoal={0.08,0.08,0.08},navy={0.025,0.06,0.14},forest={0.025,0.10,0.065},
    }
    local color=backgrounds[settings.background] or backgrounds.theme
    frame:SetBackdropColor(color[1],color[2],color[3],settings.backgroundAlpha)
    local line=Theme.Colors.lineSoft
    frame:SetBackdropBorderColor(line[1],line[2],line[3],settings.showBorder and 1 or 0)
    local widths={}
    for index,entry in ipairs(entries) do
        widths[index]=settings.iconSize+(settings.showNames and Theme:MeasureText(Theme.Font.body,entry.text)+8 or 0)
    end
    local safeWidth=math.max(64,UIParent:GetWidth()-32)
    local safeHeight=math.max(64,UIParent:GetHeight()-32)
    local pages=self:Layout(widths,settings.iconSize,settings.spacing,safeWidth,safeHeight)
    self.page=math.max(1,math.min(#pages,self.page))
    local layout=pages[self.page]
    local paged=#pages>1
    frame:SetSize(math.max(paged and 76 or 1,layout.width),layout.height+(paged and 26 or 0))
    for _,button in ipairs(self.buttons) do button:Hide() end
    for slot,item in ipairs(layout.items) do
        local button=self.buttons[slot]
        if not button then
            button=CreateFrame("Button",nil,frame)
            button:RegisterForClicks("LeftButtonUp","RightButtonUp")
            button:RegisterForDrag("LeftButton")
            button:SetScript("OnMouseDown",function(control) control.suppressClick=nil end)
            button:SetScript("OnDragStart",function(control)
                Bar.draggedID=control.entryID;control.suppressClick=true;control:SetAlpha(0.4)
                Core.Entry:CloseEntryPreview(nil,"builtinBar")
            end)
            button:SetScript("OnDragStop",function()
                local target
                for _,candidate in ipairs(Bar.buttons) do
                    if candidate:IsShown() and candidate:IsMouseOver() then target=candidate.entryID;break end
                end
                Bar:FinishIconDrag(target)
            end)
            button:SetScript("OnReceiveDrag",function(control) Bar:FinishIconDrag(control.entryID) end)
            button:SetScript("OnHide",function(control)
                if Bar.draggedID==control.entryID then Bar:FinishIconDrag() end
            end)
            button.icon=button:CreateTexture(nil,"ARTWORK");button.icon:SetPoint("LEFT")
            button.label=Theme:CreateText(button,Theme.Font.body,Theme.Colors.text,"LEFT")
            button.label:SetPoint("LEFT",button.icon,"RIGHT",8,0);button.label:SetPoint("RIGHT")
            button:SetScript("OnClick",function(control,mouseButton) if not control.suppressClick then Core.Entry:HandleEntryClick(control.entryID,mouseButton) end end)
            button:SetScript("OnEnter",function(control) if Bar.draggedID then if control.entryID~=Bar.draggedID then control:SetAlpha(0.65) end else Core.Entry:ShowEntryPreview(control.entryID,control,"builtinBar") end end)
            button:SetScript("OnLeave",function(control) if Bar.draggedID then control:SetAlpha(control.entryID==Bar.draggedID and 0.4 or 1) else Core.Entry:SchedulePreviewClose() end end)
            self.buttons[slot]=button
        end
        local entry=entries[item.index]
        if button.entryID ~= entry.id then Core.Entry:CloseEntryPreview(button.entryID,"builtinBar") end
        button.entryID=entry.id;button:SetSize(item.width,settings.iconSize)
        button:ClearAllPoints();button:SetPoint("TOPLEFT",item.x,-item.y)
        button.icon:SetSize(settings.iconSize,settings.iconSize);button.icon:SetTexture(entry.icon)
        button.label:SetText(entry.text);button.label:SetShown(settings.showNames);button:Show()
    end
    local owner=Core.Entry.previewOwner
    if owner and owner.source=="builtinBar" then
        local visible=false
        for _,item in ipairs(layout.items) do if entries[item.index].id==owner.id then visible=true end end
        if not visible then Core.Entry:CloseEntryPreview(owner.id,"builtinBar") end
    end
    frame.previous:ClearAllPoints();frame.previous:SetPoint("BOTTOMLEFT",6,3)
    frame.next:ClearAllPoints();frame.next:SetPoint("BOTTOMRIGHT",-6,3)
    frame.previous:SetShown(paged);frame.next:SetShown(paged)
    frame:ClearAllPoints();frame:SetPoint(settings.point,UIParent,settings.relativePoint,settings.x,settings.y)
    frame:Show()
end
Core.Events:Register("DISPLAY_SIZE_CHANGED",Bar,function(owner) owner:Refresh() end)
Core.Events:Register("UI_SCALE_CHANGED",Bar,function(owner) owner:Refresh() end)
