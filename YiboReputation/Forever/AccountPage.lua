local Addon, Core = _G.YiboReputation, _G.YiboCore or {}
local Page, Theme = {}, Core.UITheme; Addon.AccountPage = Page
local rowHeight = 32
local weights = { faction=2.6, reaction=1.1, value=2.6, session=1.25, scope=1.5, state=1.3, watch=1.35 }
function Page:Fields()
    local fields = {}
    for _, field in ipairs({ {"faction","FOREVER.FIELD_FACTION"}, {"reaction","FOREVER.FIELD_REACTION"},
        {"value","FOREVER.FIELD_VALUE"}, {"session","FOREVER.FIELD_SESSION"}, {"scope","FOREVER.FIELD_SCOPE"}, {"state","FOREVER.FIELD_STATE"} }) do
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
    local toolbar = CreateFrame("Frame", nil, parent)
    parent.toolbar = toolbar
    toolbar:SetPoint("TOPLEFT", 12, -94); toolbar:SetPoint("TOPRIGHT", -12, -94); toolbar:SetHeight(64)
    local function FilterChanged()
        parent.scroll:SetVerticalScroll(0)
        Addon:NotifyChanged()
    end
    parent.search = Theme:CreateInput(toolbar, {
        width = 250, height = 28, maxLetters = 100, clearable = true,
        placeholder = Addon:T("FOREVER.SEARCH_FACTION"), OnChanged = FilterChanged,
    })
    parent.search:SetPoint("TOPLEFT")
    parent.rankFilter = Theme:CreateDropdown(toolbar, 160)
    parent.rankFilter:SetPoint("LEFT", parent.search, "RIGHT", 8, 0)
    local options = { { value = "all", label = Addon:T("FOREVER.ALL_RANKS") } }
    for rank = 1, 8 do options[#options + 1] = { value = rank, label = Addon.ReputationDisplay:RankLabel(rank) } end
    options[#options + 1] = { value = "unknown", label = Addon:T("FOREVER.DISPLAY_UNCONFIRMED") }
    parent.rankFilter:SetOptions(options)
    parent.rankFilter:SetValue("all")
    parent.rankFilter:SetOnValueChanged(FilterChanged)
    parent.watchFilter = Theme:CreateButton(toolbar, 112, Addon:T("FOREVER.WATCH_ONLY"), "secondary")
    parent.watchFilter:SetPoint("LEFT", parent.rankFilter, "RIGHT", 8, 0)
    parent.watchFilter:SetScript("OnClick", function()
        parent.watchedOnly = not parent.watchedOnly
        FilterChanged()
    end)
    parent.sortMode = Theme:CreateDropdown(toolbar, 188, {
        {value="default",label=Addon:T("FOREVER.SORT_DEFAULT")},
        {value="name",label=Addon:T("FOREVER.SORT_NAME")},
        {value="rank",label=Addon:T("FOREVER.SORT_RANK")},
        {value="progress",label=Addon:T("FOREVER.SORT_PROGRESS")},
        {value="session",label=Addon:T("FOREVER.SORT_SESSION")},
    })
    parent.sortMode:SetPoint("TOPLEFT", 0, -34)
    parent.sortMode:SetValue("default")
    parent.sortMode:SetOnValueChanged(FilterChanged)
    parent.matchCount = Theme:CreateText(toolbar, Theme.Font.assist, Theme.Colors.muted)
    parent.matchCount:SetPoint("TOPLEFT", parent.sortMode, "TOPRIGHT", 12, 0)
    parent.matchCount:SetPoint("TOPRIGHT", 0, -34)
    parent.matchCount:SetHeight(30)
    parent.header = CreateFrame("Frame", nil, parent); parent.header:SetPoint("TOPLEFT", 12, -94); parent.header:SetPoint("TOPRIGHT", -12, -94); parent.header:SetHeight(26)
    parent.scroll = Theme:CreateScrollFrame(parent); parent.scroll:SetPoint("TOPLEFT", 12, -124); parent.scroll:SetPoint("BOTTOMRIGHT", -12, 10)
    parent.content = CreateFrame("Frame", nil, parent.scroll); parent.scroll:SetScrollChild(parent.content)
    parent.labels, parent.rows = {}, {}
    for _, field in ipairs(self:Fields()) do parent.labels[field.id] = Theme:CreateText(parent.header, Theme.Font.assist, Theme.Colors.muted) end
    parent.labels.watch = Theme:CreateText(parent.header, Theme.Font.assist, Theme.Colors.muted)
    parent.scroll:HookScript("OnVerticalScroll",function() Page:PaintRows(parent,true) end)
    parent.scroll:HookScript("OnSizeChanged",function() Page:LayoutRows(parent) end)
end
local function Layout(container, labels, columns)
    for _, label in pairs(labels) do label:Hide() end
    for _, column in ipairs(columns) do
        local label = labels[column.id]
        if label then
            label:ClearAllPoints(); label:SetPoint("TOPLEFT", container, "TOPLEFT", column.x, 0)
            label:SetSize(column.width, rowHeight); label:Show()
        end
    end
end
function Page:RefreshMonitored(parent, context)
    if not parent.monitoredHeader then
        parent.monitoredHeader = CreateFrame("Frame", nil, parent)
        parent.monitoredHeader:SetHeight(28)
        parent.monitoredLabels, parent.monitoredRows = {}, {}
    end
    parent.heading:Hide(); parent.refresh:Hide(); parent.toolbar:Hide(); parent.header:Hide()
    for _, row in ipairs(parent.rows) do row:Hide() end
    parent.monitoredHeader:SetPoint("TOPLEFT", 12, -8)
    parent.scroll:SetPoint("TOPLEFT", 12, -38)
    local characters = context.characters or {}
    local available = math.max(1, (context.surfaceAvailableWidth or parent.scroll:GetWidth()) - 36)
    local nameWidth, cellWidth = 152, 94
    local visible, pageInfo = Core.AccountView:GetColumnPage(Addon.PAGE_ID, "monitored", characters, available, nameWidth, cellWidth)
    Core.AccountView:UpdateColumnPager(parent, Addon.PAGE_ID, "monitored", pageInfo, nil, Core:Text("CORE.CHARACTER"))
    local columns = {{id="faction", x=0, width=nameWidth}}
    local titles = {faction=Addon:T("FOREVER.FIELD_FACTION")}
    for index, character in ipairs(visible) do
        columns[#columns + 1] = {id=character.id, x=nameWidth + (index - 1) * cellWidth, width=cellWidth}
        titles[character.id] = Core.Characters:FormatName(character, {realmMode="full"})
    end
    for _, column in ipairs(columns) do
        local label = parent.monitoredLabels[column.id] or Theme:CreateText(parent.monitoredHeader, Theme.Font.assist, Theme.Colors.muted)
        parent.monitoredLabels[column.id] = label
        label:SetWordWrap(false)
        label:SetText(titles[column.id])
    end
    Layout(parent.monitoredHeader, parent.monitoredLabels, columns)
    local count = 0
    local width = nameWidth + #visible * cellWidth
    local snapshots = Addon.Store.db.characters
    local factionDir = Addon.Store:GetFactionDirectory()
    for _, factionID in ipairs(Addon.Store.db.settings.watchedFactionIDs) do
        local sample
        for _, character in ipairs(characters) do
            local charSnapshot = snapshots[character.id]
            sample = charSnapshot and charSnapshot.factions and charSnapshot.factions[factionID]
            if sample then break end
        end
        local factionName = sample and sample.name or (factionDir[factionID] and factionDir[factionID].name)
        if factionName then
            count = count + 1
            local row = parent.monitoredRows[count]
            if not row then
                row = CreateFrame("Frame", nil, parent.content, "BackdropTemplate")
                row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"})
                row.labels, row.cells = {}, {}
                parent.monitoredRows[count] = row
            end
            local activeColumns = {}
            for _, column in ipairs(columns) do
                local key = column.id
                local label = row.labels[key] or Theme:CreateText(row, Theme.Font.body, Theme.Colors.text,
                    key == "faction" and "LEFT" or "CENTER")
                row.labels[key] = label
                label:SetWordWrap(false)
                if key == "faction" then
                    label:SetText(factionName)
                else
                    activeColumns[key] = true
                    local charSnapshot = snapshots[key]
                    local faction = charSnapshot and charSnapshot.factions and charSnapshot.factions[factionID]
                    local display = faction and Addon.ReputationDisplay:Get(faction)
                    local text = display and (display.reaction == 8 and display.rank or display.current) or "?"
                    label:SetText(tostring(text))
                    label:SetTextColor(unpack(display and display.color or Theme.Colors.muted))
                    local cell = row.cells[key]
                    if not cell then
                        cell = CreateFrame("Frame", nil, row)
                        cell:SetAllPoints(label)
                        cell:EnableMouse(true)
                        cell:SetScript("OnEnter", function(self)
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:AddLine(self.characterName)
                            GameTooltip:AddLine(self.detail)
                            GameTooltip:Show()
                        end)
                        cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
                        cell:SetScript("OnHide", function(self)
                            if GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
                        end)
                        row.cells[key] = cell
                    end
                    cell.characterName = titles[key]
                    cell.detail = display and (sample.name .. " · " .. display.rank .. " · " .. display.progress)
                        or Addon:T("FOREVER.UNKNOWN")
                    cell:Show()
                end
            end
            for key, cell in pairs(row.cells) do
                if not activeColumns[key] then cell:Hide() end
            end
            row:SetPoint("TOPLEFT", 0, -(count - 1) * rowHeight)
            row:SetSize(width, rowHeight)
            row:SetBackdropColor(unpack(count % 2 == 0 and Theme.Colors.alternate or Theme.Colors.row))
            Layout(row, row.labels, columns)
            row:Show()
        end
    end
    for index = count + 1, #parent.monitoredRows do parent.monitoredRows[index]:Hide() end
    parent.monitoredHeader:SetShown(count > 0)
    parent.status:SetShown(count == 0)
    parent.status:SetText(#characters == 0 and self:Status() or Addon:T("FOREVER.NO_WATCHED"))
    parent.content:SetSize(width, math.max(1, count * rowHeight))
    parent.scroll:SetContentHeight(count * rowHeight)
    parent.monitoredCount = count
end

function Page:Refresh(parent, context)
    if parent.wasPreview ~= context.preview then parent.scroll:SetVerticalScroll(0) end
    parent.wasPreview = context.preview
    if context.preview then self:RefreshMonitored(parent, context); return end
    if parent.monitoredHeader then
        parent.monitoredHeader:Hide()
        for _, row in ipairs(parent.monitoredRows) do row:Hide() end
    end
    parent.heading:Show(); parent.status:Show(); parent.header:Show()
    local current = Core.Characters:GetCurrentID()
    local character = context.characters and context.characters[1]
    if character and character.id ~= current then character = nil end
    local snapshot = character and Addon.Store:Get(current)
    local watched = {}
    for _, factionID in ipairs(Addon.Store.db.settings.watchedFactionIDs) do watched[factionID] = true end
    local watchedOnly = context.preview or parent.watchedOnly
    local factions, displays, sortKeys, recorded, watchedCount = {}, {}, {}, 0, 0
    local query = context.preview and "" or parent.search:GetText():match("^%s*(.-)%s*$"):lower()
    local rank = context.preview and "all" or parent.rankFilter.value
    local sort = not context.preview and parent.sortMode.value or "default"
    for _, row in pairs(snapshot and snapshot.factions or {}) do
        recorded = recorded + 1
        if watched[row.factionID] then watchedCount = watchedCount + 1 end
        if (not watchedOnly or watched[row.factionID])
            and (query == "" or row.name:lower():find(query, 1, true) or tostring(row.factionID):find(query, 1, true)) then
            local display = Addon.ReputationDisplay:Get(row)
            if rank == "all" or rank == (display.reaction or "unknown") then
                factions[#factions + 1] = row
                displays[row.factionID] = display
                display.sessionChange = Addon.Store:GetSessionChange(current,row.factionID)
                if sort=="name" then sortKeys[row.factionID]=row.name:lower()
                elseif sort=="rank" then sortKeys[row.factionID]=display.reaction
                elseif sort=="progress" then sortKeys[row.factionID]=display.fraction
                elseif sort=="session" then sortKeys[row.factionID]=display.sessionChange end
            end
        end
    end
    table.sort(factions, function(a,b)
        local left,right=sortKeys[a.factionID],sortKeys[b.factionID]
        if left~=right then
            if left==nil then return false end
            if right==nil then return true end
            if sort=="name" then return left<right end
            return left>right
        end
        return a.factionID < b.factionID
    end)
    parent.toolbar:SetShown(not context.preview)
    if not context.preview then
        parent.watchFilter:SetState(watchedOnly and "selected" or "default")
        local count = ""
        if recorded > 0 then
            local total = watchedOnly and watchedCount or recorded
            if watchedOnly and total == 0 then count = Addon:T("FOREVER.NO_WATCHED")
            elseif #factions == 0 then count = Addon:T("FOREVER.NO_MATCH")
            else count = Addon:T("FOREVER.MATCH_COUNT", #factions, total) end
        end
        parent.matchCount:SetText(count)
    end
    local headerY = context.preview and -94 or -165
    parent.header:SetPoint("TOPLEFT", 12, headerY); parent.header:SetPoint("TOPRIGHT", -12, headerY)
    parent.scroll:SetPoint("TOPLEFT", 12, headerY - 30)
    parent.heading:SetText(character and Core.Characters:FormatName(character, {realmMode="full"}) or Addon:T("FOREVER.CURRENT"))
    local status = context.preview and snapshot and watchedCount == 0 and Addon:T("FOREVER.NO_WATCHED") or self:Status()
    parent.status:SetText(status); parent.refresh:SetShown(not context.preview)
    parent.header:SetShown(not context.preview or #factions > 0)
    parent.refresh:SetState(Addon.Scanner.inWorld and current and "default" or "disabled")
    local fields = context.fields or self:Fields()
    local showWatch, showSession = false, false
    for _, field in ipairs(fields) do
        if field.id == "faction" and not context.preview then showWatch = true end
        if field.id == "session" then showSession = true end
    end
    if showWatch then
        fields = { unpack(fields) }
        fields[#fields + 1] = { id = "watch", title = Addon:T("FOREVER.FIELD_WATCH") }
    end
    parent.presentation = { current=current, factions=factions, displays=displays, watched=watched,
        fields=fields, showWatch=showWatch, showSession=showSession }
    parent.renderedFactions=factions
    local height = #factions * rowHeight
    parent.content:SetHeight(math.max(1,height))
    parent.scroll:SetContentHeight(height)
    local maximum=math.max(0,height-parent.scroll:GetHeight())
    if parent.scroll:GetVerticalScroll()>maximum then parent.scroll:SetVerticalScroll(maximum) end
    self:LayoutRows(parent)
end

function Page:LayoutRows(parent)
    local presentation=parent.presentation
    if not presentation or parent.wasPreview then return end
    local width, columns, x, total = math.max(320,parent.scroll:GetWidth()-20), {}, 0, 0
    for _, field in ipairs(presentation.fields) do total = total + (weights[field.id] or 1) end
    presentation.valueColumn=nil
    for _, field in ipairs(presentation.fields) do
        local w = width * (weights[field.id] or 1) / math.max(1,total)
        columns[#columns + 1] = {id=field.id,x=x,width=math.max(1,w-8)}; x=x+w
        parent.labels[field.id]:SetText(field.title)
        if field.id=="value" then presentation.valueColumn=columns[#columns] end
    end
    presentation.width,presentation.columns=width,columns
    Layout(parent.header,parent.labels,columns); parent.content:SetWidth(width)
    self:PaintRows(parent)
end

local function ShowFactionTooltip(row)
    if not row.faction then return end
    GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(row.faction.name)
    GameTooltip:AddLine(row.display.rank)
    GameTooltip:AddLine(row.display.progress)
    if row.showSession then GameTooltip:AddLine(Addon:T("FOREVER.SESSION_DETAIL",row.labels.session:GetText())) end
    GameTooltip:Show()
end

function Page:PaintRows(parent, scrollOnly)
    local view=parent.presentation
    if not view or not view.columns or parent.wasPreview then return end
    local first=math.floor((parent.scroll:GetVerticalScroll() or 0)/rowHeight)+1
    if scrollOnly and view.first==first then return end
    view.first=first
    local capacity=math.ceil(math.max(1,parent.scroll:GetHeight())/rowHeight)+2
    local used=0
    for index=first,math.min(#view.factions,first+capacity-1) do
        local faction=view.factions[index]
        used=used+1
        local row = parent.rows[used]
        if not row then
            row = CreateFrame("Button",nil,parent.content,"BackdropTemplate"); row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"}); row.labels={}
            row.progress=CreateFrame("Frame",nil,row,"BackdropTemplate")
            row.progress:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8",edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=1})
            row.progress:SetBackdropColor(0.02,0.04,0.04,1); row.progress:SetBackdropBorderColor(0.15,0.3,0.3,1)
            row.progress.fill=row.progress:CreateTexture(nil,"ARTWORK")
            row.progress.fill:SetPoint("TOPLEFT",1,-1); row.progress.fill:SetPoint("BOTTOMLEFT",1,1)
            for _, field in ipairs(self:Fields()) do row.labels[field.id]=Theme:CreateText(field.id=="value" and row.progress or row,Theme.Font.body,Theme.Colors.text) end
            row.labels.value:SetJustifyH("CENTER")
            row.watch = Theme:CreateButton(row, 80, "", "secondary")
            row.watch:SetScript("OnClick",function()
                if row.characterID and row.faction then Addon.Store:ToggleWatched(row.characterID,row.faction.factionID) end
            end)
            row:SetScript("OnEnter",ShowFactionTooltip)
            row:SetScript("OnLeave",function() GameTooltip:Hide() end)
            row:SetScript("OnHide",function(self)
                if GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            end)
            parent.rows[used]=row
        end
        local tooltipOwned=GameTooltip.IsOwned and GameTooltip:IsOwned(row) and GameTooltip:IsShown()
        local sameFaction=row.faction and row.faction.factionID==faction.factionID
        if tooltipOwned and not sameFaction then
            GameTooltip:Hide()
        end
        row.characterID=view.showWatch and view.current or nil
        row.showSession=view.showSession
        row.faction=faction; row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(index-1)*rowHeight); row:SetSize(view.width,rowHeight)
        row:SetBackdropColor(unpack(index%2==0 and Theme.Colors.alternate or Theme.Colors.row))
        local display=view.displays[faction.factionID]
        row.labels.faction:SetText(faction.name); row.labels.reaction:SetText(display.rank)
        row.labels.value:SetText(display.progress)
        if view.showSession then
            local change = display.sessionChange
            local label = row.labels.session
            label:SetText(change and string.format(change > 0 and "%+.0f" or "%.0f",change) or Addon:T("FOREVER.SESSION_UNKNOWN"))
            local color = change and (change > 0 and Theme.Colors.accent or change < 0 and Theme.Colors.danger) or Theme.Colors.muted
            label:SetTextColor(unpack(color))
        end
        row.labels.scope:SetText(Addon:T(faction.isAccountWide==nil and "FOREVER.SCOPE_UNKNOWN" or (faction.isAccountWide and "FOREVER.SCOPE_ACCOUNT_FLAG" or "FOREVER.SCOPE_CHARACTER_FLAG")))
        row.labels.state:SetText(Addon:T(Addon.Store:RowState(view.current,faction.factionID)=="observed" and "FOREVER.OBSERVED" or "FOREVER.OLD"))
        Layout(row,row.labels,view.columns)
        row.watch:SetShown(view.showWatch)
        if view.showWatch then
            local column = view.columns[#view.columns]
            row.watch:ClearAllPoints(); row.watch:SetPoint("TOPLEFT",row,"TOPLEFT",column.x,-3)
            row.watch:SetSize(column.width,26)
            local selected = view.watched[faction.factionID] == true
            row.watch:SetText(Addon:T(selected and "FOREVER.WATCHED" or "FOREVER.WATCH"))
            row.watch:SetState(selected and "selected" or "default")
        end
        local column=view.valueColumn
        if column then
            row.progress:ClearAllPoints(); row.progress:SetPoint("TOPLEFT",row,"TOPLEFT",column.x,-5); row.progress:SetSize(column.width,22)
            if display.color then
                row.progress:SetBackdropColor(0.02,0.04,0.04,1); row.progress:SetBackdropBorderColor(0.15,0.3,0.3,1)
                row.progress.fill:SetColorTexture(display.color[1],display.color[2],display.color[3],0.8)
                row.progress.fill:SetWidth(math.max(0.001,(column.width-2)*display.fraction)); row.progress.fill:SetShown(display.fraction>0)
            else
                row.progress.fill:Hide()
                row.progress:SetBackdropColor(0,0,0,0); row.progress:SetBackdropBorderColor(0,0,0,0)
            end
        end
        row.progress:SetShown(column~=nil)
        row.display=display; row:Show()
        if tooltipOwned and sameFaction then ShowFactionTooltip(row) end
    end
    for index=used+1,#parent.rows do parent.rows[index].faction=nil; parent.rows[index]:Hide() end
end
function Page:Register()
    local ok,err=Core.AccountView:RegisterPage(Addon.NAME,{id=Addon.PAGE_ID,title=Addon:T("FOREVER.TITLE"),fields=self:Fields(),defaultEnabled=true,previewEnabled=true,
        scope={mode="realms", previewOnly=true},
        HasCharacterSnapshot=function(character) return Addon.Store.db.characters[character.id] ~= nil end,
        GetEligibleCharacters=function(characters, context)
            local result = {}
            for _, character in ipairs(characters or {}) do
                if (context.preview or character.id == Core.Characters:GetCurrentID()) and Addon.Store.db.characters[character.id] then
                    result[#result + 1] = character
                end
            end
            return result
        end,
        GetSurfaceMetrics=function(context)
            if context.preview then
                return {minContentWidth=290, naturalContentWidth=188 + #context.characters * 94, minContentHeight=94,
                    naturalContentHeight=48 + math.max(1, #Addon.Store.db.settings.watchedFactionIDs) * rowHeight}
            end
            return {minContentWidth=720,naturalContentWidth=1040,minContentHeight=311,naturalContentHeight=531}
        end,
        Create=function(parent) Page:Create(parent) end,Refresh=function(parent,context) Page:Refresh(parent,context) end})
    if not ok then return nil,err end
    return Core.Entry:RegisterBusinessEntry(Addon.NAME,{id="yrp",brokerName="YiboReputation",pageID=Addon.PAGE_ID,text=Addon:T("FOREVER.TITLE"),
        icon="Interface\\AddOns\\YiboReputation\\Media\\YiboReputationIcon",defaultChannels={minimap=false,broker=false,builtinBar=false}})
end
