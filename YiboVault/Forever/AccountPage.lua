local Addon, Core = _G.YiboVault, _G.YiboCore
local Page, PAGE_ID = { pendingItems = {} }, "vault-items"
Addon.AccountPage = Page
local Theme = Core.UITheme
local sources = {"bags", "equipment", "bank", "mail", "auction", "guild-bank"}
local cachedSources = {"bags", "equipment", "bank"}
local sidebarWidth = 168
local slotSize, slotStep = 37, 43
function Page:SourceLabel(source)
    if source == "guild-bank" then return Addon:T("FOREVER.guild_bank") end
    if source == "bank" then return Addon:T("FOREVER.bank") end
    if source == "mail" then return Addon:T("FOREVER.mail") end
    if source == "auction" then return Addon:T("FOREVER.auction") end
    return source == "equipment" and Addon:T("FOREVER.equipment") or Addon:T("FOREVER.bags")
end
function Page:PendingStatus(source)
    if source == "bank" and Addon._bankWaiting then return "bank_waiting" end
    if source == "auction" then return "auction_pending" end
    return source == "mail" and "mail_pending" or (source == "bank" and "bank_pending" or "pending")
end
function Page:CanRefresh(source)
    return (source ~= "guild-bank" or Addon:IsGuildBankReadable()) and (source ~= "bank" or Addon._bankOpen) and (source ~= "mail" or Addon:IsMailboxReadable()) and (source ~= "auction" or Addon:IsAuctionReadable())
end
function Page:StatusLabel(status)
    local labels = { guild_none = Addon:T("FOREVER.STATUS_guild_none"), guild_identity = Addon:T("FOREVER.STATUS_guild_identity"), guild_no_view = Addon:T("FOREVER.STATUS_guild_no_view"), guild_pending = Addon:T("FOREVER.STATUS_guild_pending"), guild_waiting = Addon:T("FOREVER.STATUS_guild_waiting"), guild_partial = Addon:T("FOREVER.STATUS_guild_partial"), pending = Addon:T("FOREVER.STATUS_pending"), known = Addon:T("FOREVER.STATUS_known"),
        stale = Addon:T("FOREVER.STATUS_stale"), error = Addon:T("FOREVER.STATUS_error"), empty = Addon:T("FOREVER.STATUS_empty"), bank_pending = Addon:T("FOREVER.STATUS_bank_pending"), mail_pending = Addon:T("FOREVER.STATUS_mail_pending"), mail_incomplete = Addon:T("FOREVER.STATUS_mail_incomplete"), auction_pending = Addon:T("FOREVER.STATUS_auction_pending"), auction_incomplete = Addon:T("FOREVER.STATUS_auction_incomplete") }
    if status == "bank_waiting" then return Addon:T("FOREVER.STATUS_bank_waiting") end
    return labels[status] or labels.pending
end
local function Fields()
    return {
        { id = "item", title = Addon:T("FOREVER.ITEM"), defaultVisible = true },
        { id = "location", title = Addon:T("FOREVER.LOCATION"), defaultVisible = true },
        { id = "quantity", title = Addon:T("FOREVER.QUANTITY"), defaultVisible = true },
    }
end
function Page:Status(source, characterID)
    if source == "guild-bank" then return Addon:GuildBankViewStatus() end
    if source == "auction" and Addon._auctionOpen and Addon._auctionPendingReason then return "auction_incomplete" end
    if source == "mail" and Addon._mailOpen and Addon._mailPendingReason then return "mail_incomplete" end
    local states = characterID and Addon:GetCharacterCoverage(characterID, source) or {}
    if not next(states) then return self:PendingStatus(source) end
    local stale, empty, pending = false, true, false
    for _, state in pairs(states) do
        if state.status == "error" then return "error" end
        if state.status == "stale" then stale = true end
        if (state.recordCount or 0) > 0 then empty = false end
        if not state.completedScan then pending = true end
    end
    if pending or (source == "bank" and Addon._bankWaiting) then return self:PendingStatus(source) end
    return stale and "stale" or (empty and "empty" or "known")
end
local function ItemInfo(record)
    local info = Core.ItemResolver:GetInfo(record.itemID)
    if info and info.state == "unloaded" and not Page.pendingItems[record.itemID] then
        Page.pendingItems[record.itemID] = true
        Core.ItemResolver:Request(record.itemID, function(result)
            Page.pendingItems[record.itemID] = nil
            if result and result.state == "ready" then Core.AccountView:NotifyPageChanged(PAGE_ID) end
        end)
    end
    return info or {}
end
function Page:Create(parent)
    parent.heading = Theme:CreateText(parent, Theme.Font.section, Theme.Colors.text)
    parent.heading:SetPoint("TOPLEFT", 12, -10); parent.heading:SetHeight(26)
    parent.search = Theme:CreateInput(parent, {
        width = 320, height = 28, maxLetters = 100, clearable = true,
        placeholder = Addon:T("FOREVER.SEARCH_ITEMS"),
        OnChanged = function()
            parent.scroll:SetVerticalScroll(0)
            Core.AccountView:NotifyPageChanged(PAGE_ID)
        end,
    })
    parent.search:SetPoint("TOPRIGHT", -12, -10)
    parent.tabs = {}
    for index, source in ipairs(sources) do
        local button = Theme:CreateButton(parent, 110, Page:SourceLabel(source))
        button:SetHeight(28)
        button:SetPoint("TOPLEFT", 12 + (index - 1) * 120, -45)
        button:SetScript("OnClick", function()
            Addon.db.settings.foreverSource = source
            parent.container:SetValue("all")
            parent.search:SetValue("")
            parent.scroll:SetVerticalScroll(0)
            Core.AccountView:NotifyPageChanged(PAGE_ID)
        end)
        parent.tabs[source] = button
    end
    parent.refresh = Theme:CreateButton(parent, 100, Addon:T("FOREVER.REFRESH"))
    parent.refresh:SetHeight(28)
    parent.refresh:SetPoint("TOPRIGHT", -12, -45)
    parent.refresh:SetScript("OnClick", function() if parent.refresh.state == "disabled" or not Page:CanRefresh(Addon.db.settings.foreverSource) then return end; Addon:ScanInitial("manual"); Core.AccountView:NotifyPageChanged(PAGE_ID) end)
    parent.status = Theme:CreateText(parent, Theme.Font.assist, Theme.Colors.muted)
    parent.status:SetPoint("TOPLEFT", 12, -82); parent.status:SetPoint("RIGHT", -12, 0); parent.status:SetHeight(26)
    parent.header = CreateFrame("Frame", nil, parent); parent.header:SetPoint("TOPLEFT", 12, -114); parent.header:SetPoint("TOPRIGHT", -12, -114); parent.header:SetHeight(26)
    parent.scroll = Theme:CreateScrollFrame(parent)
    parent.scroll:SetPoint("TOPLEFT", 12, -144); parent.scroll:SetPoint("BOTTOMRIGHT", -12, 10)
    parent.content = CreateFrame("Frame", nil, parent.scroll); parent.scroll:SetScrollChild(parent.content)
    parent.labels, parent.rows = {}, {}
    for _, field in ipairs(Fields()) do parent.labels[field.id] = Theme:CreateText(parent.header, Theme.Font.assist, Theme.Colors.muted) end
    parent.rosterScroll = Theme:CreateScrollFrame(parent)
    parent.rosterScroll:SetPoint("TOPLEFT", 12, -10)
    parent.rosterScroll:SetPoint("BOTTOMLEFT", 12, 10)
    parent.rosterScroll:SetWidth(sidebarWidth)
    parent.rosterContent = CreateFrame("Frame", nil, parent.rosterScroll)
    parent.rosterContent:SetWidth(sidebarWidth-16)
    parent.rosterScroll:SetScrollChild(parent.rosterContent)
    parent.rosterButtons, parent.grid = {}, {}
    parent.container = Theme:CreateDropdown(parent, 156)
    parent.container:SetPoint("TOPLEFT", sidebarWidth+24, -117)
    parent.container:SetOnValueChanged(function()
        parent.scroll:SetVerticalScroll(0)
        Core.AccountView:NotifyPageChanged(PAGE_ID)
    end)
    parent.scroll:HookScript("OnSizeChanged", function()
        if parent.gridRecords then Page:PaintGrid(parent) end
    end)
end
local function ConfigureColumns(container, labels, columns, height)
    for _, label in pairs(labels) do label:Hide() end
    for _, column in ipairs(columns) do
        local label = labels[column.id]
        label:ClearAllPoints(); label:SetPoint("TOPLEFT", container, "TOPLEFT", column.x, 0)
        label:SetSize(column.width, height); label:Show()
    end
end
local function SearchRecords(records, query)
    local matches, names = {}, {}
    for _, record in ipairs(records) do
        local itemID = record.itemID
        if tostring(itemID):find(query, 1, true) then
            matches[#matches + 1] = record
        else
            if names[itemID] == nil then names[itemID] = (ItemInfo(record).name or ""):lower() end
            if names[itemID]:find(query, 1, true) then matches[#matches + 1] = record end
        end
    end
    return matches
end
local function LocationLabel(record)
    local source, location = record.source, record.location
    if source == "bags" then return Addon:T("FOREVER.BAG_SLOT", location.container, location.slot) end
    if source == "bank" then return Addon:T("FOREVER.BANK_SLOT", location.container, location.slot) end
    if source == "mail" then return Addon:T("FOREVER.MAIL_SLOT", location.slot, location.attachmentIndex) end
    if source == "auction" then return Addon:T("FOREVER.AUCTION_SLOT", record.auctionID) end
    if source == "guild-bank" then return Addon:T("FOREVER.GUILD_SLOT", location.tabID, location.slot) end
    return Addon:T("FOREVER.EQUIPMENT_SLOT", location.slot)
end
local function HasCompletedSource(characterID, source)
    for _, state in pairs(Addon:GetCachedCharacterCoverage(characterID, source)) do
        if state.completedScan then return true end
    end
    return false
end

local function CachedRecords(characterID, source, searching)
    local records = {}
    for _, key in ipairs(cachedSources) do
        if searching or key == source then
            for _, record in ipairs(Addon:GetCachedCharacterRecords(characterID, key)) do
                record.state = "stale"
                records[#records+1] = record
            end
        end
    end
    return records
end

local function PaintRoster(parent, characters)
    local selected
    local current = Core.Characters:GetCurrentID()
    for _, character in ipairs(characters) do
        if character.id == parent.selectedCharacter then selected = character; break end
        if character.id == current then selected = character end
    end
    selected = selected or characters[1]
    for index, character in ipairs(characters) do
        local button = parent.rosterButtons[index]
        if not button then
            button = Theme:CreateButton(parent.rosterContent, sidebarWidth-16, "")
            button:SetPoint("TOPLEFT", 0, -(index-1)*36)
            button:SetHeight(32)
            button:SetScript("OnClick", function(self)
                parent.selectedCharacter = self.characterID
                parent.container:SetValue("all")
                parent.scroll:SetVerticalScroll(0)
                Core.AccountView:NotifyPageChanged(PAGE_ID)
            end)
            parent.rosterButtons[index] = button
        end
        button.characterID = character.id
        button:SetText(Core.Characters:FormatName(character, {realmMode="full"}))
        button:SetState(selected == character and "selected" or "default")
        button:Show()
    end
    for index=#characters+1,#parent.rosterButtons do parent.rosterButtons[index]:Hide() end
    parent.rosterContent:SetHeight(math.max(1,#characters*36))
    parent.rosterScroll:SetContentHeight(#characters*36)
    return selected
end

local function SelectContainer(parent, records, source, searching, characterID)
    local byContainer = source == "bags" or source == "bank"
    local byTab = source == "guild-bank"
    if searching or not (byContainer or byTab) then parent.container:Hide(); return records end
    local key = byTab and "tabID" or "container"
    local ids, seen = {}, {}
    if byContainer and characterID then
        for locationKey, state in pairs(Addon:GetCachedCharacterCoverage(characterID, source)) do
            local id = tonumber(locationKey)
            if id and state.completedScan and state.capacity and (state.capacity.totalSlots or 0) > 0 then
                ids[#ids+1] = id
                seen[id] = true
            end
        end
    end
    for _, record in ipairs(records) do
        local id = record.location[key]
        if id ~= nil and not seen[id] then ids[#ids+1]=id; seen[id]=true end
    end
    table.sort(ids)
    local options = {{value="all", label=Addon:T("FOREVER.ALL_CONTAINERS")}}
    for _, id in ipairs(ids) do
        options[#options+1] = {value=id,label=Addon:T(byTab and "FOREVER.TAB_NUMBER" or "FOREVER.CONTAINER_NUMBER", id)}
    end
    local selected = parent.container.value
    parent.container:SetOptions(options)
    parent.container:SetValue(seen[selected] and selected or "all")
    parent.container:SetShown(#ids > 1)
    if not seen[selected] then return records end
    local filtered = {}
    for _, record in ipairs(records) do
        if record.location[key] == selected then filtered[#filtered+1]=record end
    end
    return filtered
end

local function HideGridTooltip(tile)
    if GameTooltip.IsOwned and GameTooltip:IsOwned(tile) then GameTooltip:Hide() end
end

local function CreateGridTile(parent)
    local tile = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    tile:SetSize(slotSize, slotSize)
    tile:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=1})
    tile.icon = tile:CreateTexture(nil,"ARTWORK")
    tile.icon:SetPoint("TOPLEFT",2,-2)
    tile.icon:SetPoint("BOTTOMRIGHT",-2,2)
    tile.quantity = Theme:CreateText(tile,Theme.Font.assist,Theme.Colors.text,"RIGHT")
    tile.quantity:SetPoint("BOTTOMRIGHT",-2,2)
    tile:EnableMouse(true)
    tile:SetScript("OnEnter",function(self)
        local record = self.record
        if not record then return end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        local link = record.itemLink
        if not link or not (link:match("^item:") or link:find("|Hitem:",1,true)) then link = "item:" .. record.itemID end
        GameTooltip:SetHyperlink(link)
        GameTooltip:AddLine(self.locationText)
        GameTooltip:Show()
    end)
    tile:SetScript("OnLeave",HideGridTooltip)
    tile:SetScript("OnHide",HideGridTooltip)
    return tile
end

function Page:PaintGrid(parent)
    local records = parent.gridRecords
    local width = math.max(1,parent.scroll:GetWidth()-20)
    local columns = math.max(1, math.floor((width + slotStep-slotSize)/slotStep))
    local height = math.ceil(#records/columns)*slotStep
    for index, record in ipairs(records) do
        local tile = parent.grid[index] or CreateGridTile(parent.content)
        parent.grid[index] = tile
        if tile.record and tile.record.sourceID ~= record.sourceID then HideGridTooltip(tile) end
        tile.record = record
        tile.locationText = record.state == "stale" and Addon:T("FOREVER.SEARCH_STALE_LOCATION",LocationLabel(record))
            or LocationLabel(record)
        local info = ItemInfo(record)
        tile.itemName = info.name or Addon:T("FOREVER.ITEM_ID",record.itemID)
        tile.icon:SetTexture(info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        tile.quantity:SetText(record.quantity > 1 and tostring(record.quantity) or "")
        tile:SetBackdropBorderColor(unpack(record.state=="stale" and Theme.Colors.muted or Theme.Colors.line))
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT",((index-1)%columns)*slotStep,-math.floor((index-1)/columns)*slotStep)
        tile:Show()
    end
    for index=#records+1,#parent.grid do parent.grid[index]:Hide() end
    parent.content:SetSize(width,math.max(1,height))
    parent.scroll:SetContentHeight(height)
end

function Page:Refresh(parent, context)
    local preview = context.preview
    local characters = context.characters or {}
    local character = characters[1]
    if not preview then character = PaintRoster(parent, characters) end
    local id = character and character.id
    local current = Core.Characters:GetCurrentID()
    local offline = id and id ~= current
    local left = preview and 12 or sidebarWidth+24
    parent.rosterScroll:SetShown(not preview)
    parent.header:SetShown(preview == true)
    parent.heading:SetPoint("TOPLEFT",left,-10)
    parent.status:SetPoint("TOPLEFT",left,-82)
    parent.heading:SetText(character and Core.Characters:FormatName(character, { realmMode = "full" }) or Addon:T("FOREVER.CURRENT_ONLY"))
    parent.heading:SetPoint("RIGHT", context.preview and -12 or -348, 0)
    parent.search:SetShown(not context.preview)
    local query = context.preview and "" or parent.search:GetText():match("^%s*(.-)%s*$"):lower()
    local searching = query ~= ""
    local source = Addon.db.settings.foreverSource
    if offline and source ~= "bags" and source ~= "equipment" and source ~= "bank" then source = "bags" end
    local tabWidth = preview and 110 or math.max(80, math.min(100, math.floor(((context.surfaceAvailableWidth or 960)-left-122)/6)-6))
    for index, tabSource in ipairs(sources) do
        local button = parent.tabs[tabSource]
        local allowed = not offline or tabSource == "bags" or tabSource == "equipment" or tabSource == "bank"
        button:SetWidth(tabWidth)
        button:SetPoint("TOPLEFT",left+(index-1)*(tabWidth+6),-45)
        button:SetShown(allowed)
        button:SetState(not searching and tabSource == source and "selected" or "default")
    end
    local options = { sources = not searching and { source } or nil }
    if character then options.scope = { mode = "characters", characterIDs = { character.id } } end
    local records
    if offline then
        records = CachedRecords(id, source, searching)
    else
        local result = character and Addon.Items:Query(options)
        records = result and result.records or {}
    end
    if searching then records = SearchRecords(records, query) end
    local status
    if offline then status = HasCompletedSource(id, source) and "stale" or (source == "bank" and "bank_pending" or "pending")
    else status = self:Status(source, id or (not preview and current)) end
    if searching and #records > 0 then
        parent.status:SetText(Addon:T("FOREVER.SEARCH_COUNT", #records))
    elseif searching then
        parent.status:SetText(Addon:T("TEXT.NO_CACHED_ITEMS_MATCH_89E336"))
    else
        parent.status:SetText(Addon:T("FOREVER.SOURCE_STATUS", self:SourceLabel(source), self:StatusLabel(status)))
    end
    local color = status == "error" and Theme.Colors.danger or ((status == "stale" or status == "bank_waiting" or status == "mail_incomplete" or status == "auction_incomplete" or status == "guild_partial" or status == "guild_waiting") and Theme.Colors.warning or Theme.Colors.text)
    parent.status:SetTextColor(unpack(searching and Theme.Colors.text or color))
    parent.refresh:SetShown(not context.preview and not searching)
    parent.refresh:SetState((offline or not self:CanRefresh(source)) and "disabled" or "default")
    if not preview then
        for _, row in ipairs(parent.rows) do row:Hide() end
        parent.gridRecords = SelectContainer(parent, records, source, searching, id)
        parent.scroll:SetPoint("TOPLEFT",left,parent.container:IsShown() and -153 or -116)
        self:PaintGrid(parent)
        parent.renderedRecords,parent.renderedStatus = parent.gridRecords,status
        return
    end
    parent.gridRecords = nil
    parent.container:Hide()
    for _, tile in ipairs(parent.grid) do tile:Hide() end
    parent.scroll:SetPoint("TOPLEFT",12,-144)
    local width = math.max(320, parent.scroll:GetWidth() - 20)
    parent.content:SetWidth(width)
    local columns, x = {}, 0
    local visible = context.fields or Fields()
    local locationWidth = searching and 250 or 170
    local fixed, itemVisible = 0, false
    for _, field in ipairs(visible) do if field.id == "item" then itemVisible = true else fixed = fixed + (field.id == "location" and locationWidth or 70) end end
    for _, field in ipairs(visible) do
        local w = field.id == "item" and math.max(80, width - fixed) or (field.id == "location" and locationWidth or 70)
        columns[#columns + 1] = { id = field.id, x = x, width = w - 8 }; x = x + w
        parent.labels[field.id]:SetText(field.title)
    end
    ConfigureColumns(parent.header, parent.labels, columns, 26)
    for index, record in ipairs(records) do
        local row = parent.rows[index]
        if not row then
            row = CreateFrame("Button", nil, parent.content, "BackdropTemplate")
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            row.labels = {}
            for _, field in ipairs(Fields()) do row.labels[field.id] = Theme:CreateText(row, Theme.Font.body, Theme.Colors.text) end
            row:SetScript("OnEnter", function(self)
                if self.record then
                    local link = self.record.itemLink
                    if not link or not (link:match("^item:") or link:find("|Hitem:", 1, true)) then link = "item:" .. self.record.itemID end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(link); GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            parent.rows[index] = row
        end
        row.record = record
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(index - 1) * 30); row:SetSize(width, 30)
        row:SetBackdropColor(unpack(index % 2 == 0 and Theme.Colors.alternate or Theme.Colors.row))
        local info = itemVisible and ItemInfo(record) or {}
        row.labels.item:SetText(info.name or Addon:T("FOREVER.ITEM_ID", record.itemID))
        local location = LocationLabel(record)
        if searching and record.state == "stale" then location = Addon:T("FOREVER.SEARCH_STALE_LOCATION", location) end
        row.labels.location:SetText(location)
        row.labels.quantity:SetText(tostring(record.quantity))
        ConfigureColumns(row, row.labels, columns, 30); row:Show()
    end
    for index = #records + 1, #parent.rows do parent.rows[index].record = nil; parent.rows[index]:Hide() end
    parent.content:SetHeight(math.max(1, #records * 30))
    parent.scroll:SetContentHeight(#records * 30)
    parent.renderedRecords, parent.renderedStatus = records, status
end
function Page:Register()
    local function HasCharacterSnapshot(character)
        local current = Core.Characters:GetCurrentID()
        for _, source in ipairs(character.id == current and sources or cachedSources) do
            local states = character.id == current and Addon:GetCharacterCoverage(current, source)
                or Addon:GetCachedCharacterCoverage(character.id, source)
            for _, state in pairs(states) do
                if state.completedScan then return true end
            end
        end
        if character.id == current then
            local identity = Addon:CurrentGuildBankIdentity()
            for _, state in pairs(identity and Addon:GetGuildCoverage(identity.key) or {}) do
                if state.completedScan then return true end
            end
        end
        return false
    end
    local definition = {
        id = PAGE_ID, title = Addon:T("TEXT.ITEM_OVERVIEW_70B215"), defaultEnabled = true, previewEnabled = true,
        fields = Fields(), GetPreviewFields = function() return Addon.db.settings.previewColumns end,
        GetSurfaceMetrics = function() return { minContentWidth = 870, naturalContentWidth = 960, minContentHeight = 240, naturalContentHeight = 520 } end,
        scope = {mode="realms", mainOnly=true, allTitle=Addon:T("TEXT.ALL_REALMS_A166AB")},
        HasCharacterSnapshot = HasCharacterSnapshot,
        GetEligibleCharacters = function(characters, context)
            local result, current = {}, Core.Characters:GetCurrentID()
            for _, character in ipairs(characters) do
                if (not context.preview or character.id == current) and HasCharacterSnapshot(character) then
                    result[#result+1] = character
                end
            end
            return result
        end,
        Create = function(parent) Page:Create(parent) end, Refresh = function(parent, context) Page:Refresh(parent, context) end,
    }
    local page, err = Core.AccountView:RegisterPage(Addon.NAME, definition)
    if not page then return nil, err end
    local entry, entryError = Core.Entry:RegisterBusinessEntry(Addon.NAME, {
        id = "yva", brokerName = "YiboVault", pageID = PAGE_ID, text = Addon:T("TEXT.ITEM_OVERVIEW_70B215"),
        icon = "Interface\\AddOns\\YiboVault\\Media\\YiboVaultIcon", defaultChannels = { minimap = false, broker = false, builtinBar = false },
    })
    if not entry then return nil, entryError end
    Addon.Items.Events:Register(Page, function() Core.AccountView:NotifyPageChanged(PAGE_ID) end)
    return true
end
function Page:Open() return Core.AccountView:Toggle(PAGE_ID) end
