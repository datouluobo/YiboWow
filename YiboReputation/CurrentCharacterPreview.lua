local Addon, Core = _G.YiboReputation, _G.YiboCore
local Theme = Core.UITheme
local function Text(parent, size, color, justify) return Theme:CreateText(parent, size, color, justify or "LEFT") end
local function Current() local c=Core.Characters:GetCurrent(); return c, c and Core.DataDomains:Get(c.id,"reputation") end

function Addon:CreateCurrentPreview(parent)
    parent.currentPreviewHeading=Text(parent,Theme.Font.body,Theme.Colors.accent,"LEFT")
    parent.currentPreviewNameHeader=Text(parent,Theme.Font.assist,Theme.Colors.muted,"LEFT")
    parent.currentPreviewValueHeader=Text(parent,Theme.Font.assist,Theme.Colors.muted,"RIGHT")
    parent.currentPreviewScroll=Theme:CreateScrollFrame(parent); parent.currentPreviewBody=CreateFrame("Frame",nil,parent.currentPreviewScroll); parent.currentPreviewScroll:SetScrollChild(parent.currentPreviewBody); parent.currentPreviewRows={}
end
function Addon:RefreshCurrentPreview(parent)
    local character, snapshot=Current(); parent.currentPreviewHeading:ClearAllPoints();parent.currentPreviewHeading:SetPoint("TOPLEFT",parent,"TOPLEFT",Theme.Space.sm,-(Theme.Space.xs+Theme.Size.standard+Theme.Space.xs));parent.currentPreviewHeading:SetPoint("TOPRIGHT",parent.previewModeButton,"BOTTOMRIGHT",0,-Theme.Space.xs);parent.currentPreviewHeading:SetText((character and character.name or "当前角色").." · 声望概览")
    parent.currentPreviewNameHeader:ClearAllPoints();parent.currentPreviewNameHeader:SetPoint("TOPLEFT",parent.currentPreviewHeading,"BOTTOMLEFT",0,-Theme.Space.xs);parent.currentPreviewNameHeader:SetText("声望")
    parent.currentPreviewValueHeader:ClearAllPoints();parent.currentPreviewValueHeader:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-Theme.Space.xs,-(Theme.Space.xs+Theme.Size.standard+Theme.Space.xs+Theme.Size.compact));parent.currentPreviewValueHeader:SetText(character and character.name or "当前角色")
    parent.currentPreviewScroll:ClearAllPoints();parent.currentPreviewScroll:SetPoint("TOPLEFT",parent.currentPreviewNameHeader,"BOTTOMLEFT",0,-Theme.Space.xxs);parent.currentPreviewScroll:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",-Theme.Space.xs,Theme.Space.sm)
    local state=self:FormatState(snapshot); if state then
        local row=parent.currentPreviewRows[1] or Text(parent.currentPreviewBody,Theme.Font.body,Theme.Colors.muted);parent.currentPreviewRows[1]=row;row:SetAllPoints(parent.currentPreviewBody);row:SetText("当前角色尚无可用声望快照："..state);parent.currentPreviewBody:SetSize(390,40);parent.currentPreviewScroll:SetContentHeight(40);return
    end
    local chosen=self:GetSettings().currentPreviewExpanded or self:GetSettings().defaultExpansion; if chosen=="auto" or not chosen then chosen="mop" end
    local y,index=0,0; local rowHeight=Theme.Table.rowHeight
    local function Row(kind)
        index=index+1;local row=parent.currentPreviewRows[index] or CreateFrame("Button",nil,parent.currentPreviewBody,"BackdropTemplate");parent.currentPreviewRows[index]=row;row:SetSize(450,rowHeight);row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"});row.text=row.text or Text(row,Theme.Font.assist,Theme.Colors.text,"LEFT");row.text:ClearAllPoints();row.text:SetPoint("LEFT",row,"LEFT",Theme.Space.sm,0);row.text:SetPoint("RIGHT",row,"RIGHT",-150,0);row.text:SetJustifyH("LEFT");row.value=row.value or Text(row,Theme.Font.assist,Theme.Colors.text,"RIGHT");row.value:ClearAllPoints();row.value:SetPoint("RIGHT",row,"RIGHT",-Theme.Space.sm,0);row.value:SetWidth(142);return row
    end
    for _, expansion in ipairs(self:GetTreeNodes(snapshot)) do
        local open=chosen==expansion.key; local complete,total=0,0
        local function Count(node) if node.kind=="faction" and node.data then total=total+1;if self:IsComplete(node.data) then complete=complete+1 end end;for _,child in ipairs(node.children or {}) do Count(child) end end
        Count(expansion);local row=Row("expansion");row:ClearAllPoints();row:SetPoint("TOPLEFT",parent.currentPreviewBody,"TOPLEFT",0,-y);row:SetBackdropColor(Theme.Colors.selected[1],Theme.Colors.selected[2],Theme.Colors.selected[3],1);row.text:SetText((open and "- " or "+ ")..expansion.title);row.value:SetText(string.format("%d / %d 已满",complete,total));row:SetScript("OnClick",function() self:GetSettings().currentPreviewExpanded=expansion.key;self:NotifyChanged() end);y=y+rowHeight
        if open then local function Add(node,depth)
            if node.kind=="faction" then local r=Row();r:ClearAllPoints();r:SetPoint("TOPLEFT",parent.currentPreviewBody,"TOPLEFT",0,-y);r:SetBackdropColor(Theme.Colors.row[1],Theme.Colors.row[2],Theme.Colors.row[3],1);r.text:SetText(string.rep(" ",depth*2)..node.title);r.value:SetText(self:FormatSnapshotValue(snapshot,node.data,"matrix",self:GetFactionState(snapshot,node.factionID)));r:SetScript("OnClick",function() self:GetSettings().matrixFocusFactionID=node.factionID;Core.AccountView:ShowPage("reputation",{autoFit=true}) end);y=y+rowHeight end;for _,child in ipairs(node.children or {}) do Add(child,depth+1) end end;for _,child in ipairs(expansion.children) do Add(child,0) end end
    end
    for i=index+1,#parent.currentPreviewRows do parent.currentPreviewRows[i]:Hide() end;for i=1,index do parent.currentPreviewRows[i]:Show() end;parent.currentPreviewBody:SetSize(430,math.max(1,y));parent.currentPreviewScroll:SetContentHeight(y)
end
