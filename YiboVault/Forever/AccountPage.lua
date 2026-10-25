local Addon, Core = _G.YiboVault, _G.YiboCore
local Page, PAGE_ID = { pendingItems = {} }, "vault-items"
Addon.AccountPage = Page
local Theme = Core.UITheme
function Page:SourceLabel(source)
    if source == "guild-bank" then return Addon:T("FOREVER.guild_bank") end
    if source == "bank" then return Addon:T("FOREVER.bank") end
    if source == "mail" then return Addon:T("FOREVER.mail") end
    if source == "auction" then return Addon:T("FOREVER.auction") end
    return source == "equipment" and Addon:T("FOREVER.equipment") or Addon:T("FOREVER.bags")
end
function Page:PendingStatus(source)
    if source == "auction" then return "auction_pending" end
    return source == "mail" and "mail_pending" or (source == "bank" and "bank_pending" or "pending")
end
function Page:CanRefresh(source)
    return (source ~= "guild-bank" or Addon:IsGuildBankReadable()) and (source ~= "bank" or Addon._bankOpen) and (source ~= "mail" or Addon:IsMailboxReadable()) and (source ~= "auction" or Addon:IsAuctionReadable())
end
function Page:StatusLabel(status)
    local labels = { guild_none = Addon:T("FOREVER.STATUS_guild_none"), guild_identity = Addon:T("FOREVER.STATUS_guild_identity"), guild_no_view = Addon:T("FOREVER.STATUS_guild_no_view"), guild_pending = Addon:T("FOREVER.STATUS_guild_pending"), guild_waiting = Addon:T("FOREVER.STATUS_guild_waiting"), guild_partial = Addon:T("FOREVER.STATUS_guild_partial"), pending = Addon:T("FOREVER.STATUS_pending"), known = Addon:T("FOREVER.STATUS_known"),
        stale = Addon:T("FOREVER.STATUS_stale"), error = Addon:T("FOREVER.STATUS_error"), empty = Addon:T("FOREVER.STATUS_empty"), bank_pending = Addon:T("FOREVER.STATUS_bank_pending"), mail_pending = Addon:T("FOREVER.STATUS_mail_pending"), mail_incomplete = Addon:T("FOREVER.STATUS_mail_incomplete"), auction_pending = Addon:T("FOREVER.STATUS_auction_pending"), auction_incomplete = Addon:T("FOREVER.STATUS_auction_incomplete") }
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
    if pending then return self:PendingStatus(source) end
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
    parent.heading:SetPoint("TOPLEFT", 12, -10); parent.heading:SetPoint("RIGHT", -12, 0); parent.heading:SetHeight(26)
    parent.tabs = {}
    for index, source in ipairs({ "bags", "equipment", "bank", "mail", "auction", "guild-bank" }) do
        local button = Theme:CreateButton(parent, 110, Page:SourceLabel(source))
        button:SetHeight(28)
        button:SetPoint("TOPLEFT", 12 + (index - 1) * 120, -45)
        button:SetScript("OnClick", function() Addon.db.settings.foreverSource = source; Core.AccountView:NotifyPageChanged(PAGE_ID) end)
        parent.tabs[source] = button
    end
    parent.refresh = Theme:CreateButton(parent, 100, Addon:T("FOREVER.REFRESH"))
    parent.refresh:SetHeight(28)
    parent.refresh:SetPoint("TOPRIGHT", -12, -45)
    parent.refresh:SetScript("OnClick", function() if not Page:CanRefresh(Addon.db.settings.foreverSource) then return end; Addon:ScanInitial("manual"); Core.AccountView:NotifyPageChanged(PAGE_ID) end)
    parent.status = Theme:CreateText(parent, Theme.Font.assist, Theme.Colors.muted)
    parent.status:SetPoint("TOPLEFT", 12, -82); parent.status:SetPoint("RIGHT", -12, 0); parent.status:SetHeight(26)
    parent.header = CreateFrame("Frame", nil, parent); parent.header:SetPoint("TOPLEFT", 12, -114); parent.header:SetPoint("TOPRIGHT", -12, -114); parent.header:SetHeight(26)
    parent.scroll = Theme:CreateScrollFrame(parent)
    parent.scroll:SetPoint("TOPLEFT", 12, -144); parent.scroll:SetPoint("BOTTOMRIGHT", -12, 10)
    parent.content = CreateFrame("Frame", nil, parent.scroll); parent.scroll:SetScrollChild(parent.content)
    parent.labels, parent.rows = {}, {}
    for _, field in ipairs(Fields()) do parent.labels[field.id] = Theme:CreateText(parent.header, Theme.Font.assist, Theme.Colors.muted) end
end
local function ConfigureColumns(container, labels, columns, height)
    for _, label in pairs(labels) do label:Hide() end
    for _, column in ipairs(columns) do
        local label = labels[column.id]
        label:ClearAllPoints(); label:SetPoint("TOPLEFT", container, "TOPLEFT", column.x, 0)
        label:SetSize(column.width, height); label:Show()
    end
end
function Page:Refresh(parent, context)
    local character = context.characters and context.characters[1]
    parent.heading:SetText(character and Core.Characters:FormatName(character, { realmMode = "full" }) or Addon:T("FOREVER.CURRENT_ONLY"))
    local source = Addon.db.settings.foreverSource
    for tabSource, button in pairs(parent.tabs) do button:SetState(tabSource == source and "selected" or "default") end
    local result = character and Addon.Items:Query({ scope = { mode = "characters", characterIDs = { character.id } }, sources = { source } })
    local records = result and result.records or {}
    local status = self:Status(source, character and character.id or (not context.preview and Core.Characters:GetCurrentID()))
    parent.status:SetText(Addon:T("FOREVER.SOURCE_STATUS", self:SourceLabel(source), self:StatusLabel(status)))
    local color = status == "error" and Theme.Colors.danger or ((status == "stale" or status == "mail_incomplete" or status == "auction_incomplete" or status == "guild_partial" or status == "guild_waiting") and Theme.Colors.warning or Theme.Colors.text)
    parent.status:SetTextColor(unpack(color))
    parent.refresh:SetShown(not context.preview)
    parent.refresh:SetState(not self:CanRefresh(source) and "disabled" or "default")
    local width = math.max(320, parent.scroll:GetWidth() - 20)
    parent.content:SetWidth(width)
    local columns, x = {}, 0
    local visible = context.fields or Fields()
    local fixed, itemVisible = 0, false
    for _, field in ipairs(visible) do if field.id == "item" then itemVisible = true else fixed = fixed + (field.id == "location" and 170 or 70) end end
    for _, field in ipairs(visible) do
        local w = field.id == "item" and math.max(80, width - fixed) or (field.id == "location" and 170 or 70)
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
        row.labels.location:SetText(source == "bags" and Addon:T("FOREVER.BAG_SLOT", record.location.container, record.location.slot)
            or (source == "bank" and Addon:T("FOREVER.BANK_SLOT", record.location.container, record.location.slot)
                or (source == "mail" and Addon:T("FOREVER.MAIL_SLOT", record.location.slot, record.location.attachmentIndex)
                    or (source == "auction" and Addon:T("FOREVER.AUCTION_SLOT", record.auctionID)
                        or (source == "guild-bank" and Addon:T("FOREVER.GUILD_SLOT", record.location.tabID, record.location.slot)
                            or Addon:T("FOREVER.EQUIPMENT_SLOT", record.location.slot))))))
        row.labels.quantity:SetText(tostring(record.quantity))
        ConfigureColumns(row, row.labels, columns, 30); row:Show()
    end
    for index = #records + 1, #parent.rows do parent.rows[index].record = nil; parent.rows[index]:Hide() end
    parent.content:SetHeight(math.max(1, #records * 30))
    parent.scroll:SetContentHeight(#records * 30)
    parent.renderedRecords, parent.renderedStatus = records, status
end
function Page:Register()
    local definition = {
        id = PAGE_ID, title = Addon:T("TEXT.ITEM_OVERVIEW_70B215"), defaultEnabled = true, previewEnabled = true,
        fields = Fields(), GetPreviewFields = function() return Addon.db.settings.previewColumns end,
        GetSurfaceMetrics = function() return { minContentWidth = 870, naturalContentWidth = 960, minContentHeight = 240, naturalContentHeight = 520 } end,
        GetEligibleCharacters = function(characters)
            local result, current = {}, Core.Characters:GetCurrentID()
            local store, sampled = current and Addon.db.byCharacter[current], false
            for _, source in ipairs({ "bags", "equipment", "bank", "mail", "auction", "guild-bank" }) do
                for _, state in pairs(current and Addon:GetCharacterCoverage(current, source) or {}) do
                    if state.completedScan then sampled = true end
                end
            end
            local identity = Addon:CurrentGuildBankIdentity()
            if identity then
                for _, state in pairs(Addon:GetGuildCoverage(identity.key)) do if state.completedScan then sampled = true end end
            end
            for _, character in ipairs(characters) do if character.id == current and sampled then result[#result + 1] = character end end
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
