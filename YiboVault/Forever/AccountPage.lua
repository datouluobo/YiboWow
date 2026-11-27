local Addon, Core = _G.YiboVault, _G.YiboCore
local Page, PAGE_ID = { pendingItems = {} }, "vault-items"
Addon.AccountPage = Page
Page.ID = PAGE_ID
local Theme = Core.UITheme
local Layout = Addon.StorageLayout
local Browse = Addon.StorageBrowse
local sources = {"bags", "equipment", "bank", "mail", "auction", "guild-bank"}
local cachedSources = {"bags", "equipment", "bank", "mail", "auction"}
local sourceTabs = {}
for index, source in ipairs(sources) do
    sourceTabs[index] = { id = source, enabled = true }
end
local sidebarWidth = 168
local slotSize, slotStep = 37, 43
local gridGeometry = { size = slotSize, gap = slotStep - slotSize, inset = 0, rowHeight = slotStep, widthInset = 20 }
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
    parent.browse = Browse:New(Addon.db.settings.foreverSource)
    parent.heading = Theme:CreateText(parent, Theme.Font.section, Theme.Colors.text)
    parent.heading:SetPoint("TOPLEFT", 12, -10); parent.heading:SetHeight(26)
    parent.search = Theme:CreateInput(parent, {
        width = 320, height = 28, maxLetters = 100, clearable = true,
        placeholder = Addon:T("FOREVER.SEARCH_ITEMS"),
        OnChanged = function()
            parent.rosterScroll:SetVerticalScroll(0)
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
            parent.search:SetValue("")
            parent.browse:SetQuery("")
            parent.browse:SelectSource(source, true)
            Addon.db.settings.foreverSource = parent.browse.normal.source
            parent.selectedGuildTab = nil
            parent.container:SetValue("all")
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
    parent.transitMoney = Theme:CreateText(parent, Theme.Font.assist, Theme.Colors.text)
    parent.transitMoney:SetPoint("RIGHT", -12, 0); parent.transitMoney:SetHeight(20)
    parent.transitMoney:Hide()
    parent.capacity = Theme:CreateText(parent, Theme.Font.assist, Theme.Colors.muted)
    parent.capacity:SetHeight(24)
    parent.scroll = Theme:CreateScrollFrame(parent)
    parent.scroll:SetPoint("TOPLEFT", 12, -144); parent.scroll:SetPoint("BOTTOMRIGHT", -12, 10)
    parent.content = CreateFrame("Frame", nil, parent.scroll); parent.scroll:SetScrollChild(parent.content)
    parent.rosterScroll = Theme:CreateScrollFrame(parent)
    parent.rosterScroll:SetPoint("TOPLEFT", 12, -39)
    parent.rosterScroll:SetPoint("BOTTOMLEFT", 12, 10)
    parent.rosterScroll:SetWidth(sidebarWidth)
    parent.showHidden = Theme:CreateCheckbox(parent, Addon:T("TEXT.SHOW_HIDDEN_GUILDS_4B158B"))
    parent.showHidden:SetPoint("TOPLEFT", 12, -10)
    parent.showHidden:SetWidth(sidebarWidth)
    parent.showHidden:SetScript("OnClick", function(control)
        control:SetChecked(not control:GetChecked())
        if not parent.searching then parent.explicitGuild = nil end
        Core.AccountView:NotifyPageChanged(PAGE_ID)
    end)
    parent.rosterContent = CreateFrame("Frame", nil, parent.rosterScroll)
    parent.rosterContent:SetWidth(sidebarWidth-16)
    parent.rosterScroll:SetScrollChild(parent.rosterContent)
    parent.rosterButtons, parent.grid = {}, {}
    parent.guildTabAnchor = CreateFrame("Frame", nil, parent)
    parent.guildTabAnchor:SetSize(1, 1)
    parent.guildTabs = {}
    parent.container = Theme:CreateDropdown(parent, 156)
    parent.container:SetPoint("TOPLEFT", sidebarWidth+24, -117)
    parent.container:SetOnValueChanged(function()
        parent.scroll:SetVerticalScroll(0)
        Core.AccountView:NotifyPageChanged(PAGE_ID)
    end)
    local function paintGrid()
        if parent.gridRecords then Page:PaintGrid(parent) end
    end
    parent.scroll:HookScript("OnSizeChanged", paintGrid)
    parent.scroll:HookScript("OnVerticalScroll", paintGrid)
end
local function SearchItemName(record)
    return ItemInfo(record).name
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

local function PaintRoster(parent, owners, selected)
    for index, owner in ipairs(owners) do
        local button = parent.rosterButtons[index]
        if not button then
            button = Theme:CreateButton(parent.rosterContent, sidebarWidth-16, "")
            button:SetPoint("TOPLEFT", 0, -(index-1)*36)
            button:SetHeight(32)
            button:SetScript("OnClick", function(self)
                parent.browse:SelectOwner(self.ownerID)
                if not parent.searching then
                    parent.explicitGuild = nil
                    parent.selectedGuildTab = nil
                    parent.container:SetValue("all")
                end
                parent.scroll:SetVerticalScroll(0)
                Core.AccountView:NotifyPageChanged(PAGE_ID)
            end)
            parent.rosterButtons[index] = button
        end
        button.ownerID = owner.id
        button:SetText(owner.label or Core.Characters:FormatName(owner, {realmMode="full"}))
        button:SetState(selected and selected.id == owner.id and "selected" or "default")
        button:Show()
    end
    for index = #owners + 1, #parent.rosterButtons do parent.rosterButtons[index]:Hide() end
    parent.rosterContent:SetHeight(math.max(1, #owners * 36))
    parent.rosterScroll:SetContentHeight(#owners * 36)
end

local function LabelSearchOwners(byID, groups, characters)
    local ordered = {}
    for _, owner in ipairs(groups) do
        if owner.guildKey then
            owner.label = owner.guildName or Addon:T("TEXT.GUILD_AE2266")
            if Addon:IsGuildHidden(owner.id) then
                owner.label = owner.label .. Addon:T("TEXT.HIDDEN_EXCLUDED_FROM_TOTAL_EA8796")
            end
            ordered[#ordered + 1] = owner
        end
    end
    for _, character in ipairs(characters) do
        local owner = byID[character.id]
        if owner then
            owner.label = Core.Characters:FormatName(character, {realmMode="full"})
            ordered[#ordered + 1] = owner
        end
    end
    return ordered
end

local function SelectContainer(parent, records, source, searching, characterID, guildCoverage, width)
    local byContainer = source == "bags" or source == "bank"
    local byTab = source == "guild-bank"
    if searching or not (byContainer or byTab) then
        parent.container:Hide()
        Layout:HideTabs(parent.guildTabs)
        return records, "all", 0
    end

    local key = byTab and "tabID" or "container"
    local ids, seen = {}, {}
    if byContainer and characterID then
        for locationKey, state in pairs(Addon:GetCachedCharacterCoverage(characterID, source)) do
            local id = tonumber(locationKey)
            if id and state.completedScan and state.capacity and (state.capacity.totalSlots or 0) > 0 then
                ids[#ids + 1], seen[id] = id, true
            end
        end
    end
    for tab, state in pairs(guildCoverage or {}) do
        local id = tonumber(tab)
        if state.completedScan then ids[#ids + 1], seen[id] = id, true end
    end
    for _, record in ipairs(records) do
        local id = record.location[key]
        if id ~= nil and not seen[id] then ids[#ids + 1], seen[id] = id, true end
    end
    table.sort(ids)

    local selected, selectorHeight
    if byTab then
        parent.container:Hide()
        local tabs = {}
        if #ids > 0 then tabs[1] = { id = "all", label = Addon:T("FOREVER.ALL_GUILD_TABS"), enabled = true } end
        for _, id in ipairs(ids) do
            local state = guildCoverage and guildCoverage[tostring(id)]
            tabs[#tabs + 1] = { id = id, enabled = true, label = state and state.location and state.location.tabName
                or Addon:T("FOREVER.TAB_NUMBER", id) }
        end
        selected = Browse:ResolveSource(parent.selectedGuildTab, tabs) or "all"
        parent.selectedGuildTab = selected
        for index = #parent.guildTabs + 1, #tabs do
            local button = Theme:CreateButton(parent, 105, "", "secondary")
            button:SetHeight(28)
            button:SetScript("OnClick", function(control)
                if not control.tabEnabled or control.tabKey == parent.selectedGuildTab then return end
                parent.selectedGuildTab = control.tabKey
                parent.scroll:SetVerticalScroll(0)
                Core.AccountView:NotifyPageChanged(PAGE_ID)
            end)
            parent.guildTabs[index] = button
        end
        local columns = math.max(1, math.min(#tabs, math.floor((width + 6) / 92)))
        Layout:PlaceTabs(parent.guildTabs, tabs, selected, parent.guildTabAnchor, width, columns, 6, 28, 0)
        selectorHeight = math.ceil(#tabs / columns) * 34
    else
        Layout:HideTabs(parent.guildTabs)
        local options = { { value = "all", label = Addon:T("FOREVER.ALL_CONTAINERS") } }
        for _, id in ipairs(ids) do
            options[#options + 1] = { value = id, label = Addon:T("FOREVER.CONTAINER_NUMBER", id) }
        end
        selected = seen[parent.container.value] and parent.container.value or "all"
        parent.container:SetOptions(options)
        parent.container:SetValue(selected)
        parent.container:SetShown(#ids > 1)
        selectorHeight = #ids > 1 and 34 or 0
    end

    if not seen[selected] then return records, selected, selectorHeight end
    local filtered = {}
    for _, record in ipairs(records) do
        if record.location[key] == selected then filtered[#filtered + 1] = record end
    end
    return filtered, selected, selectorHeight
end

local function CreateGridTile(parent)
    local tile = CreateFrame("Button", nil, parent, "BackdropTemplate")
    tile:SetSize(slotSize, slotSize)
    -- Tiles keep a gap between them; each owns a one-pixel, border-only frame.
    Theme:ApplyPixelBackdrop(tile, { background = false })
    tile.icon = tile:CreateTexture(nil,"ARTWORK")
    tile.icon:SetPoint("TOPLEFT",2,-2)
    tile.icon:SetPoint("BOTTOMRIGHT",-2,2)
    tile.quantity = Theme:CreateText(tile,Theme.Font.assist,Theme.Colors.text,"RIGHT")
    tile.quantity:SetPoint("BOTTOMRIGHT",-2,2)
    tile.emptyLabel = Theme:CreateText(tile, Theme.Font.assist, Theme.Colors.muted, "CENTER")
    tile.emptyLabel:SetAllPoints(tile)
    tile:EnableMouse(true)
    tile:SetScript("OnEnter",function(self)
        local record = self.record
        if not record then return end
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        local link = record.itemLink
        if not link or not (link:match("^item:") or link:find("|Hitem:",1,true)) then link = "item:" .. record.itemID end
        GameTooltip._yiboVaultGuildKey = record.guildKey
        GameTooltip:SetHyperlink(link)
        GameTooltip:AddLine(self.locationText)
        if record.mailStatus == "in-transit" then
            GameTooltip:AddLine(Addon:T("MAIL.IN_TRANSIT_FROM", record.senderName or ""))
        end
        if Addon.GoalTargets.ref then
            GameTooltip:AddLine(Core.BusinessItemActions:GestureLabel() .. Addon:T("TEXT.ADD_TO_ACTION_HUB_OPEN_THE_ADD_MENU_1EB204"))
        end
        Addon.Tooltip:Append(GameTooltip, record.itemID)
        GameTooltip:Show()
    end)
    local function hideTooltip(control) Layout:HideCellTooltip(control) end
    tile:SetScript("OnLeave", hideTooltip)
    tile:SetScript("OnHide", hideTooltip)
    return tile
end

local function PaintItemTile(parent, tile, record)
    tile.locationText = record.state == "stale" and Addon:T("FOREVER.SEARCH_STALE_LOCATION",LocationLabel(record))
        or LocationLabel(record)
    local owner = parent.searchOwners and parent.searchOwners[record.characterID]
    if owner then tile.locationText = Core.Characters:FormatName(owner, { realmMode = "full" }) .. " · " .. tile.locationText end
    if record.guildKey and Addon:IsGuildHidden(record.guildKey) then
        tile.locationText = Addon:T("TEXT.HIDDEN_EXCLUDED_FROM_ACCOUNT_TOTAL_79BC9B") .. " · " .. tile.locationText
    end
    local info = ItemInfo(record)
    tile.itemName = info.name or Addon:T("FOREVER.ITEM_ID",record.itemID)
    tile.icon:SetTexture(info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local quantity = tostring(record.quantity)
    tile.quantity:SetText(record.mailStatus == "in-transit" and (Addon:T("MAIL.TRANSIT_SHORT") .. quantity) or quantity)
    local quality = info.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.quality]
    if quality then
        tile:SetBackdropBorderColor(quality.r, quality.g, quality.b)
    else
        tile:SetBackdropBorderColor(unpack(record.state == "stale" and Theme.Colors.muted or Theme.Colors.line))
    end
end

function Page:PaintGrid(parent)
    local records, groups = parent.gridRecords, parent.freeGroups
    Layout:RenderGrid(parent.scroll, parent.content, parent.grid, #records + #groups, gridGeometry,
        CreateGridTile, function(tile, slot)
            local record, group = records[slot], groups[slot - #records]
            Layout:ClearReusedCellTooltip(tile, tile.record, record)
            tile.record = record
            Addon.GoalTargets:Bind(tile, record)
            tile.icon:SetShown(record ~= nil)
            tile.quantity:SetShown(record ~= nil)
            tile.emptyLabel:SetShown(group ~= nil)
            if record then
                PaintItemTile(parent, tile, record)
            else
                tile.emptyLabel:SetText(Addon:T(group.emptyLabelKey) .. "\n" .. group.emptySlots)
                tile:SetBackdropBorderColor(0, 0, 0, 0)
            end
        end)
end

function Page:Refresh(parent, context)
    local characters = context.characters or {}
    local ids, owners = {}, {}
    for _, candidate in ipairs(characters) do
        ids[#ids + 1] = candidate.id
        owners[candidate.id] = candidate
    end
    local current = Core.Characters:GetCurrentID()
    local browse = parent.browse
    local character = Browse:ResolveOwner(browse.normal, characters, owners, current)
    local id = character and character.id
    local offline = id and id ~= current
    local left = sidebarWidth + 24
    local width = context.surfaceAvailableWidth or parent:GetWidth()
    parent.heading:SetPoint("TOPLEFT",left,-10)
    parent.heading:SetText(character and Core.Characters:FormatName(character, { realmMode = "full" })
        or Addon:T("TEXT.ITEM_OVERVIEW_70B215"))
    local searchWidth = math.min(320, math.floor((width-left) * 0.52))
    parent.search:SetWidth(math.max(1, searchWidth))
    parent.heading:SetPoint("RIGHT", -(searchWidth + 24), 0)
    browse.normal.source = Addon.db.settings.foreverSource
    local query, searching = browse:SetQuery(parent.search:GetText())
    parent.searching = searching
    if not searching then
        PaintRoster(parent, characters, character)
    end
    local source = Browse:ResolveSource(browse.normal.source, sourceTabs, offline and "guild-bank")
    local gap, tabPitch, count = 6, 36, 0
    local usable = math.max(1, width - left - 12)
    local columns = math.max(1, math.min(#sources, math.floor((usable + gap) / 86)))
    local tabWidth = math.max(1, math.min(110, math.floor((usable + gap) / columns) - gap))
    for _, tabSource in ipairs(sources) do
        local button = parent.tabs[tabSource]
        local allowed = not searching and (not offline or tabSource ~= "guild-bank")
        button:SetWidth(tabWidth)
        if allowed then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", left + (count % columns) * (tabWidth + gap), -45 - math.floor(count / columns) * tabPitch)
            count = count + 1
        end
        button:SetShown(allowed)
        button:SetState(not searching and tabSource == source and "selected" or "default")
    end
    local tabOffset = searching and -tabPitch or math.max(0, math.floor((count - 1) / columns)) * tabPitch
    parent.status:ClearAllPoints()
    parent.status:SetPoint("TOPLEFT", left, -82 - tabOffset)
    parent.status:SetPoint("TOPRIGHT", -124, -82 - tabOffset)
    parent.refresh:ClearAllPoints()
    parent.refresh:SetPoint("TOPRIGHT", -12, -78 - tabOffset)
    local options = { sources = not searching and { source } or nil }
    options.scope = { mode = "characters", characterIDs = searching and ids or id and { id } or {} }
    local copper = 0
    if not searching and source == "mail" then
        local transitMoney = Addon.Items:GetMailTransitMoney(options.scope)
        for _, characterID in ipairs(options.scope.characterIDs) do copper = copper + (transitMoney[characterID] or 0) end
    end
    local moneyHeight = copper > 0 and 22 or 0
    parent.transitMoney:SetPoint("TOPLEFT", left, -112 - tabOffset)
    parent.transitMoney:SetText(copper > 0 and Addon:T("MAIL.TRANSIT_MONEY", copper / 10000) or "")
    parent.transitMoney:SetShown(copper > 0)
    if not searching and source == "guild-bank" and parent.explicitGuild
        and self:CanOpenGuild(parent.explicitGuild) then
        options.guildKey, options.includeHiddenGuilds = parent.explicitGuild, true
    end
    if parent.showHidden:GetChecked() then options.includeHiddenGuilds = true end
    local result = Addon.Items:Query(options)
    local records
    if searching then
        local byID, groups = Browse:GroupRecords(result.records, result.transitRecords, query, SearchItemName)
        local ordered = LabelSearchOwners(byID, groups, characters)
        local selected = Browse:ResolveOwner(browse:Selection(), ordered, byID, id)
        browse:SelectOwner(selected and selected.id)
        PaintRoster(parent, ordered, selected)
        records = selected and selected.records or {}
        parent.heading:SetText(selected and selected.label or Addon:T("TEXT.ITEM_OVERVIEW_70B215"))
    else
        records = result.records
        for _, record in ipairs(result.transitRecords) do records[#records + 1] = record end
    end
    local status
    if offline then status = HasCompletedSource(id, source) and "stale" or (source == "bank" and "bank_pending" or "pending")
    else status = self:Status(source, id or current) end
    if searching and #records > 0 then
        parent.status:SetText(Addon:T("FOREVER.SEARCH_COUNT", #records))
    elseif searching then
        parent.status:SetText(Addon:T("TEXT.NO_CACHED_ITEMS_MATCH_89E336"))
    else
        parent.status:SetText(Addon:T("FOREVER.SOURCE_STATUS", self:SourceLabel(source), self:StatusLabel(status)))
    end
    local color = status == "error" and Theme.Colors.danger or ((status == "stale" or status == "bank_waiting" or status == "mail_incomplete" or status == "auction_incomplete" or status == "guild_partial" or status == "guild_waiting") and Theme.Colors.warning or Theme.Colors.text)
    parent.status:SetTextColor(unpack(searching and Theme.Colors.text or color))
    parent.refresh:SetShown(not searching)
    parent.refresh:SetState((offline or not self:CanRefresh(source)) and "disabled" or "default")
    self.host = parent
    parent.searchOwners = searching and owners or nil
    local guildCoverage = result.coverage["guild-bank"]
    local guildKey, tabs
    if guildCoverage then guildKey, tabs = next(guildCoverage) end
    parent.guildTabAnchor:ClearAllPoints()
    parent.guildTabAnchor:SetPoint("TOPLEFT", left, -116 - tabOffset)
    local selected, selectorHeight
    parent.gridRecords, selected, selectorHeight = SelectContainer(parent, records, source, searching, id, tabs and tabs.locations, usable)
    parent.container:SetPoint("TOPLEFT", left, -117 - tabOffset)
    local area = not searching and Addon.Items:GetSourceCapacity(source, id, selected, guildKey)
    parent.freeGroups = Addon.BagCapacity:Group(area, source)
    parent.capacity:ClearAllPoints()
    parent.capacity:SetPoint("TOPLEFT", left, -113 - selectorHeight - tabOffset)
    parent.capacity:SetText(Addon.BagCapacity:Format(area))
    parent.capacity:SetShown(area and area.totalSlots ~= nil or false)
    local gridTop = parent.capacity:IsShown() and -141 - selectorHeight
        or -116 - (selectorHeight > 0 and selectorHeight + 3 or 0)
    parent.scroll:SetPoint("TOPLEFT",left,gridTop - moneyHeight - tabOffset)
    self:PaintGrid(parent)
    parent.renderedRecords,parent.renderedStatus = parent.gridRecords,status
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
        id = PAGE_ID, title = Addon:T("TEXT.ITEM_OVERVIEW_70B215"), defaultEnabled = true, previewEnabled = false,
        GetSurfaceMetrics = function()
            return { minContentWidth = 440, naturalContentWidth = 960, minContentHeight = 300, naturalContentHeight = 520 }
        end,
        scope = {mode="realms", mainOnly=true, allTitle=Addon:T("TEXT.ALL_REALMS_A166AB")},
        HasCharacterSnapshot = HasCharacterSnapshot,
        GetEligibleCharacters = function(characters)
            local ids = {}
            for index, character in ipairs(characters) do ids[index] = character.id end
            local transitMoney = Addon.Items:GetMailTransitMoney({ mode = "characters", characterIDs = ids })
            local result = {}
            for _, character in ipairs(characters) do
                if transitMoney[character.id] or HasCharacterSnapshot(character) then
                    result[#result+1] = character
                end
            end
            return result
        end,
        settings = {
            title = Addon:T("TEXT.ITEM_OVERVIEW_70B215"),
            description = Addon:T("TEXT.VAULT_ITEM_TOOLTIP_AND_CACHE_SETTINGS_03FFD9"),
            CreateSettingsPanel = function(parent, context) return Addon.Settings:CreatePanel(parent, context) end,
        },
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

function Page:CanOpenGuild(key)
    return next(Addon:GetGuildCoverage(key)) ~= nil
end

function Page:OpenGuild(key)
    if not self:CanOpenGuild(key) then return end
    Core.AccountView:ShowPage(PAGE_ID)
    local parent = self.host
    if not parent then return end
    parent.browse.normal.owner = Core.Characters:GetCurrentID()
    parent.explicitGuild = key
    parent.tabs["guild-bank"]:GetScript("OnClick")()
end
