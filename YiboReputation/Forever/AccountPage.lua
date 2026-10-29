local Addon, Core = _G.YiboReputation, _G.YiboCore or {}
local Page, Theme = {}, Core.UITheme; Addon.AccountPage = Page
function Page:Fields()
    local fields = {}
    for _, field in ipairs({ {"faction","FOREVER.FIELD_FACTION"}, {"reaction","FOREVER.FIELD_REACTION"},
        {"value","FOREVER.FIELD_VALUE"}, {"scope","FOREVER.FIELD_SCOPE"}, {"state","FOREVER.FIELD_STATE"} }) do
        fields[#fields + 1] = { id = field[1], title = Addon:T(field[2]), defaultVisible = true }
    end
    return fields
end
function Page:Status()
    local _, state = Addon.Store:Get(Core.Characters:GetCurrentID())
    local keys = { partial = "FOREVER.PARTIAL", stale = "FOREVER.STALE", error = "FOREVER.ERROR", pending = "FOREVER.PENDING", unavailable = "FOREVER.UNAVAILABLE" }
    return Addon:T(keys[state] or "FOREVER.UNKNOWN")
end
function Page:Create(parent)
    parent.heading = Theme:CreateText(parent, Theme.Font.section, Theme.Colors.text)
    parent.heading:SetPoint("TOPLEFT", 12, -10); parent.heading:SetPoint("RIGHT", -130, 0); parent.heading:SetHeight(26)
    parent.refresh = Theme:CreateButton(parent, 100, Addon:T("FOREVER.REFRESH")); parent.refresh:SetPoint("TOPRIGHT", -12, -10)
    parent.refresh:SetScript("OnClick", function() Addon.Scanner:Scan() end)
    parent.status = Theme:CreateText(parent, Theme.Font.assist, Theme.Colors.muted)
    parent.status:SetPoint("TOPLEFT", 12, -48); parent.status:SetPoint("RIGHT", -12, 0); parent.status:SetHeight(40)
    parent.header = CreateFrame("Frame", nil, parent); parent.header:SetPoint("TOPLEFT", 12, -94); parent.header:SetPoint("TOPRIGHT", -12, -94); parent.header:SetHeight(26)
    parent.scroll = Theme:CreateScrollFrame(parent); parent.scroll:SetPoint("TOPLEFT", 12, -124); parent.scroll:SetPoint("BOTTOMRIGHT", -12, 10)
    parent.content = CreateFrame("Frame", nil, parent.scroll); parent.scroll:SetScrollChild(parent.content)
    parent.labels, parent.rows = {}, {}
    for _, field in ipairs(self:Fields()) do parent.labels[field.id] = Theme:CreateText(parent.header, Theme.Font.assist, Theme.Colors.muted) end
end
local function Layout(container, labels, columns)
    for _, label in pairs(labels) do label:Hide() end
    for _, column in ipairs(columns) do
        local label = labels[column.id]; label:ClearAllPoints(); label:SetPoint("TOPLEFT", container, "TOPLEFT", column.x, 0)
        label:SetSize(column.width, 32); label:Show()
    end
end
function Page:Refresh(parent, context)
    local current = Core.Characters:GetCurrentID()
    local character = context.characters and context.characters[1]
    if character and character.id ~= current then character = nil end
    local snapshot = character and Addon.Store:Get(current)
    local factions = {}
    for _, row in pairs(snapshot and snapshot.factions or {}) do factions[#factions + 1] = row end
    table.sort(factions, function(a,b) return a.factionID < b.factionID end)
    parent.heading:SetText(character and Core.Characters:FormatName(character, {realmMode="full"}) or Addon:T("FOREVER.CURRENT"))
    parent.status:SetText(self:Status()); parent.refresh:SetShown(not context.preview)
    parent.refresh:SetState(Addon.Scanner.inWorld and current and "default" or "disabled")
    local width, columns, x, total = math.max(320,parent.scroll:GetWidth()-20), {}, 0, 0
    local fields, weights = context.fields or self:Fields(), { faction=2.6, reaction=1.1, value=3, scope=1.5, state=1.3 }
    for _, field in ipairs(fields) do total = total + (weights[field.id] or 1) end
    for _, field in ipairs(fields) do
        local w = width * (weights[field.id] or 1) / math.max(1,total)
        columns[#columns + 1] = {id=field.id,x=x,width=math.max(1,w-8)}; x=x+w
        parent.labels[field.id]:SetText(field.title)
    end
    Layout(parent.header,parent.labels,columns); parent.content:SetWidth(width)
    for index, faction in ipairs(factions) do
        local row = parent.rows[index]
        if not row then
            row = CreateFrame("Button",nil,parent.content,"BackdropTemplate"); row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"}); row.labels={}
            row.progress=CreateFrame("Frame",nil,row,"BackdropTemplate")
            row.progress:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8",edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=1})
            row.progress:SetBackdropColor(0.02,0.04,0.04,1); row.progress:SetBackdropBorderColor(0.15,0.3,0.3,1)
            row.progress.fill=row.progress:CreateTexture(nil,"ARTWORK")
            row.progress.fill:SetPoint("TOPLEFT",1,-1); row.progress.fill:SetPoint("BOTTOMLEFT",1,1)
            for _, field in ipairs(self:Fields()) do row.labels[field.id]=Theme:CreateText(field.id=="value" and row.progress or row,Theme.Font.body,Theme.Colors.text) end
            row.labels.value:SetJustifyH("CENTER")
            row:SetScript("OnEnter",function(self)
                if not self.faction then return end
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(self.faction.name)
                local display=Addon.ReputationDisplay:Get(self.faction)
                GameTooltip:AddLine(display.rank); GameTooltip:AddLine(display.progress)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave",function() GameTooltip:Hide() end); parent.rows[index]=row
        end
        row.faction=faction; row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(index-1)*32); row:SetSize(width,32)
        row:SetBackdropColor(unpack(index%2==0 and Theme.Colors.alternate or Theme.Colors.row))
        local display=Addon.ReputationDisplay:Get(faction)
        row.labels.faction:SetText(faction.name); row.labels.reaction:SetText(display.rank)
        row.labels.value:SetText(display.progress)
        row.labels.scope:SetText(Addon:T(faction.isAccountWide==nil and "FOREVER.SCOPE_UNKNOWN" or (faction.isAccountWide and "FOREVER.SCOPE_ACCOUNT_FLAG" or "FOREVER.SCOPE_CHARACTER_FLAG")))
        row.labels.state:SetText(Addon:T(Addon.Store:RowState(current,faction.factionID)=="observed" and "FOREVER.OBSERVED" or "FOREVER.OLD"))
        Layout(row,row.labels,columns); row.progress:Hide()
        if display.color then
            row.progress:SetBackdropColor(0.02,0.04,0.04,1); row.progress:SetBackdropBorderColor(0.15,0.3,0.3,1)
            for _,column in ipairs(columns) do if column.id=="value" then
                row.progress:ClearAllPoints(); row.progress:SetPoint("TOPLEFT",row,"TOPLEFT",column.x,-5); row.progress:SetSize(column.width,22)
                row.progress.fill:SetColorTexture(display.color[1],display.color[2],display.color[3],0.8)
                row.progress.fill:SetWidth(math.max(0.001,(column.width-2)*display.fraction)); row.progress.fill:SetShown(display.fraction>0)
                row.progress:Show()
            end end
        else
            -- Keep the text visible when no validated progress bar is available.
            row.progress:ClearAllPoints(); row.progress:SetAllPoints(row); row.progress.fill:Hide(); row.progress:Show()
            row.progress:SetBackdropColor(0,0,0,0); row.progress:SetBackdropBorderColor(0,0,0,0)
        end
        row.display=display; row:Show()
    end
    for index=#factions+1,#parent.rows do parent.rows[index].faction=nil; parent.rows[index]:Hide() end
    parent.content:SetHeight(math.max(1,#factions*32)); parent.scroll:SetContentHeight(#factions*32)
    parent.renderedFactions=factions
end
function Page:Register()
    local ok,err=Core.AccountView:RegisterPage(Addon.NAME,{id=Addon.PAGE_ID,title=Addon:T("FOREVER.TITLE"),fields=self:Fields(),defaultEnabled=true,previewEnabled=true,
        GetPreviewFields=function() return Core.Defaults:Copy(Addon.Store.db.settings.previewColumns) end,
        SetPreviewFieldVisible=function(id,visible)
            for _,field in ipairs(Page:Fields()) do if field.id==id then Addon.Store.db.settings.previewColumns[id]=visible==true; Addon:NotifyChanged(); return true end end
            return false
        end,
        HasCharacterSnapshot=function(character) return character.id==Core.Characters:GetCurrentID() and Addon.Store.db.characters[character.id]~=nil end,
        GetEligibleCharacters=function(characters)
            local result={}; for _,character in ipairs(characters or {}) do
                if character.id==Core.Characters:GetCurrentID() and Addon.Store.db.characters[character.id] then result[#result+1]=character end
            end; return result
        end,
        GetSurfaceMetrics=function() return {minContentWidth=720,naturalContentWidth=1040,minContentHeight=240,naturalContentHeight=460} end,
        Create=function(parent) Page:Create(parent) end,Refresh=function(parent,context) Page:Refresh(parent,context) end})
    if not ok then return nil,err end
    return Core.Entry:RegisterBusinessEntry(Addon.NAME,{id="yrp",brokerName="YiboReputation",pageID=Addon.PAGE_ID,text=Addon:T("FOREVER.TITLE"),
        icon="Interface\\AddOns\\YiboReputation\\Media\\YiboReputationIcon",defaultChannels={minimap=false,broker=false,builtinBar=false}})
end
