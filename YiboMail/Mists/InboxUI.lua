local Addon = _G.YiboMail
local Native, View = Addon.NativeUI, Addon.ViewModel
local Text, InboxButton, Surface, Tooltip, BACKDROP = unpack(Native.inboxWidgets)

-- WoW frames are pooled for the session. Release their business references
-- when unmounted instead of leaving callbacks pointing at an old mailbox.
local function ReleaseWidget(control)
    if not control then return end
    for _, event in ipairs({ "OnClick", "OnEnter", "OnLeave" }) do control:SetScript(event, nil) end
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(control) then GameTooltip:Hide() end
end
function Native:ReleaseInboxRow(row)
    row:Hide(); ReleaseWidget(row); ReleaseWidget(row.check); ReleaseWidget(row.delete); ReleaseWidget(row.iconHover)
    row.mailOriginalIndex, row.mailEntryKey, row.mailAttachmentSlot = nil, nil, nil
    row.mailListTop, row.mailIndented = nil, nil
    row.icon:SetTexture(nil)
    for _, key in ipairs({ "title", "detail", "summary", "count", "expiry" }) do row[key]:SetText("") end
    for _, button in ipairs(row.attachments and row.attachments.itemButtons or {}) do
        button:Hide(); ReleaseWidget(button); button.icon:SetTexture(nil); button.name:SetText(""); button.count:SetText("")
    end
end
function Native:ReleaseInboxTile(tile)
    tile:Hide(); ReleaseWidget(tile)
    tile.mailGroup, tile.eligibleCount = nil, nil
    tile.displayTexture, tile.displayKey, tile.displayAvailable = nil, nil, nil
    tile.icon:SetTexture(nil); tile.count:SetText("")
end
function Native:ReleaseInboxPresentation()
    local panel = self.inbox; if not panel then return end
    for _, row in ipairs(panel.rows or {}) do self:ReleaseInboxRow(row) end
    for _, tile in ipairs(panel.tiles or {}) do self:ReleaseInboxTile(tile) end
    panel.available, panel.selection, panel.expanded = {}, {}, {}
    panel.previousTileAvailability, panel.keepTilesDuringQueue, panel.observationMounted = nil, nil, nil
    self.pendingItemInfo = nil
    self.itemRefreshTicket = nil
end

function Native:SelectInboxActions()
    local selection, count = {}, 0
    local skipped = { preference = 0 }
    for _, entry in ipairs(View:GetMails(self:Context(), self.inbox.options)) do
        local entrySkipped = false
        for _, action in ipairs(self:GetSelectableMailActions(entry)) do
            if action.actionable and Addon:SelectByDefault(action) then
                if not selection[action.id] then selection[action.id] = true; count = count + 1 end
            elseif not action.actionable then
                entrySkipped = entry.restriction or Addon:T("UI.TEXT_0284")
            else
                skipped.preference = skipped.preference + 1
            end
        end
        if entrySkipped then skipped[entrySkipped] = (skipped[entrySkipped] or 0) + 1 end
    end
    return selection, count, skipped
end
function Native:InboxMenuAction(value)
    local panel, queue = self.inbox, Addon.Queue
    panel.menu.menu:Hide(); panel.notice = nil
    if value == "select" or value == "clear" then
        if queue.state == "running" or queue.pending then panel.notice = Addon:T("UI.TEXT_0529")
        elseif value == "select" then
            if queue.state == "paused" then queue:Discard() end
            local count, skipped
            panel.selection, count, skipped = self:SelectInboxActions()
            local details, reasons = {}, {}
            for reason in pairs(skipped) do reasons[#reasons + 1] = reason end
            table.sort(reasons)
            for _, reason in ipairs(reasons) do details[#details + 1] = skipped[reason] .. Addon:T("UI.TEXT_0032") .. reason end
            if skipped.preference > 0 then details[#details + 1] = skipped.preference .. Addon:T("UI.TEXT_0055") end
            panel.notice = count > 0 and (Addon:T("UI.TEXT_0256") .. count .. Addon:T("UI.TEXT_0052") .. (#details > 0 and (Addon:T("UI.TEXT_0658") .. table.concat(details, Addon:T("UI.TEXT_0078"))) or Addon:T("UI.TEXT_0079")))
                or (#details > 0 and (Addon:T("UI.TEXT_0438") .. table.concat(details, Addon:T("UI.TEXT_0078"))) or Addon:T("UI.TEXT_0272"))
            panel.scroll:SetVerticalScroll(0)
        else
            local ok, err = queue:Discard()
            if ok then panel.selection, panel.notice = {}, Addon:T("UI.TEXT_0580") else panel.notice = err end
        end
    elseif value == "pause" then
        if queue.state == "running" then queue:Pause(Addon:T("UI.TEXT_0461")) else panel.notice = Addon:T("UI.TEXT_0271") end
    elseif value == "sort" then
        panel.options.sort = panel.options.sort == "expiry" and "inbox" or "expiry"
        self:RememberInboxSort()
        panel.scroll:SetVerticalScroll(0); panel.notice = panel.options.sort == "expiry" and Addon:T("UI.TEXT_0249") or Addon:T("UI.TEXT_0250")
    elseif value == "account" and Addon.FEATURES.account then
        if Addon.Core.AccountView:Toggle("mail-inbox") == false then panel.notice = Addon:T("UI.TEXT_0308") end
    end
    panel.menu:SetValue(nil); panel.menu:SetText(Addon:T("UI.TEXT_0385"))
    self:RememberInboxFilters(); self:RefreshInbox()
end
function Native:SetInboxShell(shown)
    if not shown then
        local saved = self.shellAppearance
        if not saved then return end
        for region, alpha in pairs(saved.alpha) do region:SetAlpha(alpha) end
        if saved.fill then MailFrame:SetBackdropColor(unpack(saved.fill)); MailFrame:SetBackdropBorderColor(unpack(saved.border)) end
        self.shellAppearance = nil
        return
    end
    self.shellAppearance = self.shellAppearance or { alpha = {} }
    local saved = self.shellAppearance
    local function HideDecoration(region)
        if not region or type(region.GetAlpha) ~= "function" or type(region.SetAlpha) ~= "function" then return end
        if saved.alpha[region] == nil then saved.alpha[region] = region:GetAlpha() end
        region:SetAlpha(0)
    end
    for _, region in ipairs({ MailFrame:GetRegions() }) do HideDecoration(region) end
    -- Native art and common skin backdrops share the mailbox's outer shell.
    for _, key in ipairs({ "backdrop", "Backdrop", "shadow", "Shadow", "BorderFrame", "Background", "NineSlice", "Bg", "Inset", "TitleBg", "Portrait", "PortraitFrame", "TopTileStreaks" }) do HideDecoration(MailFrame[key]) end
    for _, name in ipairs({ "MailFrameBg", "MailFrameInset", "MailFramePortrait", "MailFrameTitleBg", "MailFrameTitleText", "SendMailFrameTitleText", "SendMailTitleText" }) do HideDecoration(_G[name]) end
    HideDecoration(MailFrame.TitleText); HideDecoration(SendMailFrame and SendMailFrame.TitleText)
    if type(MailFrame.GetBackdrop) == "function" and MailFrame:GetBackdrop() then
        if not saved.fill then saved.fill = { MailFrame:GetBackdropColor() }; saved.border = { MailFrame:GetBackdropBorderColor() } end
        MailFrame:SetBackdropColor(0, 0, 0, 0); MailFrame:SetBackdropBorderColor(0, 0, 0, 0)
    end
end
function Native:SuppressInboxContent()
    if not self.nativeInboxContent then
        self.nativeInboxContent = CreateFrame("Frame", nil, InboxFrame)
        self.nativeInboxContent:SetAllPoints(InboxFrame); self.nativeInboxContent:Hide()
    end
    -- Original controls still receive Blizzard updates through their globals,
    -- while their hidden parent removes both rendering and mouse interaction.
    for _, child in ipairs({ InboxFrame:GetChildren() }) do
        if child ~= self.nativeInboxContent and child ~= self.inbox and child ~= OpenMailFrame then child:SetParent(self.nativeInboxContent) end
    end
    for _, region in ipairs({ InboxFrame:GetRegions() }) do region:SetAlpha(0) end
    local close = MailFrame.CloseButton or _G.MailFrameCloseButton
    if close and InboxFrame:IsShown() then close:Hide() end
    if InboxFrame:IsShown() then self:SetInboxShell(true) end
end
function Native:CreateInbox()
    self:SuppressInboxContent()
    local theme = Addon.Core.UITheme
    local height = theme.Size.standard
    local panel = Surface(InboxFrame); self.inbox = panel
    panel:SetFrameLevel(InboxFrame:GetFrameLevel() + 15)
    panel:SetAllPoints(MailFrame)
    panel.close = InboxButton(panel, 22, "x", function() if HideUIPanel then HideUIPanel(MailFrame) else MailFrame:Hide() end end)
    panel.close:SetSize(height, height); panel.close:SetPoint("TOPRIGHT", -8, -6)
    panel.mode, panel.selection, panel.expanded, panel.rows, panel.options = "mail", {}, {}, {}, { search = "", kind = "all", sort = "expiry" }
    panel.search = CreateFrame("EditBox", nil, panel, "BackdropTemplate"); panel.search:SetAutoFocus(false); panel.search:SetMaxLetters(100); panel.search:SetHeight(height)
    panel.search:SetBackdrop(BACKDROP); panel.search:SetBackdropColor(unpack(theme.Colors.panel)); panel.search:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
    panel.search:SetFont(STANDARD_TEXT_FONT, theme.Font.body, ""); panel.search:SetTextColor(unpack(theme.Colors.text)); panel.search:SetTextInsets(8, 8, 0, 0)
    panel.search:SetPoint("TOPLEFT", 8, -6)
    panel.search:SetScript("OnEditFocusGained", function(control) control:SetBackdropBorderColor(unpack(theme.Colors.accent)) end)
    panel.search:SetScript("OnEditFocusLost", function(control) control:SetBackdropBorderColor(unpack(theme.Colors.lineSoft)) end)
    panel.search:SetScript("OnEscapePressed", function(control) control:ClearFocus() end)
    panel.search.hint = Text(panel.search); panel.search.hint:SetPoint("LEFT", 8, 0); panel.search.hint:SetText(Addon:T("UI.TEXT_0328")); panel.search.hint:SetTextColor(unpack(theme.Colors.muted))
    panel.search.hint:SetFont(STANDARD_TEXT_FONT, theme.Font.body, ""); panel.search.hint:SetPoint("RIGHT", -8, 0)
    panel.search:SetScript("OnTextChanged", function(control)
        panel.options.search = control:GetText(); control.hint:SetShown(control:GetText() == ""); Native:RememberInboxFilters(); Native:RefreshInbox()
    end)
    theme:AttachClearButton(panel.search)
    panel.filter = self:Dropdown(panel, 96, Addon:T("UI.TEXT_0138")); panel.filter:SetHeight(height); panel.filter:SetPoint("RIGHT", panel.close, "LEFT", -6, 0)
    panel.search:SetPoint("RIGHT", panel.filter, "LEFT", -6, 0)
    panel.filter:SetOptions({ { value = "all", label = Addon:T("UI.TEXT_0138") }, { value = "items", label = Addon:T("UI.TEXT_0205") }, { value = "money", label = Addon:T("UI.TEXT_0204") },
        { value = "cod", label = Addon:T("UI.TEXT_0110") }, { value = "returned", label = Addon:T("UI.TEXT_0578") }, { value = "urgent", label = Addon:T("UI.TEXT_0084") } })
    panel.filter:SetValue("all"); panel.filter:SetOnValueChanged(function(value) panel.options.kind = value; Native:RememberInboxFilters(); Native:RefreshInbox() end)
    panel.scroll = Addon.Core.UITheme:CreateScrollFrame(panel); panel.scroll:SetPoint("TOPLEFT", 8, -height - 14); panel.scroll:SetPoint("BOTTOMRIGHT", -8, theme.Size.compact + 20)
    panel.scroll:SetFrameLevel(panel:GetFrameLevel() + 2)
    panel.content = CreateFrame("Frame", nil, panel.scroll); panel.content:SetSize(1, 1); panel.scroll:SetScrollChild(panel.content)
    panel.scroll:HookScript("OnSizeChanged", function() Native:RefreshInbox() end)
    panel.selectAll = Addon.Core.UITheme:CreateCheckbox(panel, "")
    panel.selectAll:SetSize(22, 24); panel.selectAll.box:SetSize(18, 18); panel.selectAll.mark:SetSize(18, 18)
    panel.selectAll:SetPoint("BOTTOMLEFT", 8, 9)
    panel.selectAll:SetScript("OnClick", function(control)
        if Addon.Queue.state == "running" or Addon.Queue.pending then return end
        if control:GetCheckState() == "checked" then
            panel.selection, panel.notice = {}, nil
            Native:RefreshInbox()
        else
            Native:InboxMenuAction("select")
        end
    end)
    Tooltip(panel.selectAll, Addon:T("UI.TEXT_0131"), Addon:T("UI.TEXT_0165"))
    panel.status = Text(panel); panel.status:SetHeight(theme.Size.compact); panel.status:SetWordWrap(false)
    panel.statusHover = CreateFrame("Frame", nil, panel); panel.statusHover:SetAllPoints(panel.status); panel.statusHover:EnableMouse(true)
    panel.collect = InboxButton(panel, 72, Addon:T("UI.TEXT_0347"), function() Native:Collect() end)
    panel.collect.kind = "primary"
    panel.collect:SetHeight(theme.Size.compact); panel.collect:SetPoint("BOTTOMRIGHT", -76, 8)
    panel.returnMail = InboxButton(panel, 72, Addon:T("RETURN.BUTTON", 0), function() Native:ReturnSelectedMail() end)
    panel.returnMail:SetHeight(theme.Size.compact); panel.returnMail:SetPoint("RIGHT", panel.collect, "LEFT", -4, 0)
    panel.returnMail:Hide()
    panel.menu = self:Dropdown(panel, 64, Addon:T("UI.TEXT_0385")); panel.menu:SetHeight(theme.Size.compact); panel.menu:SetPoint("BOTTOMRIGHT", -8, 8)
    -- Action menus need their own width and open upward from the footer.
    panel.menu:SetScript("OnClick", function(control)
        if control.menu:IsShown() then control.menu:Hide(); return end
        panel.filter.menu:Hide()
        control.menu:ClearAllPoints(); control.menu:SetPoint("BOTTOMRIGHT", control, "TOPRIGHT", 0, 4); control.menu:SetWidth(220)
        Native:RaiseDropdown(control)
        control.menu:Show(); control.menu:Raise()
    end)
    panel.menu:SetOnValueChanged(function(value) Native:InboxMenuAction(value) end)
    panel:SetScript("OnShow", function() Native:SuppressInboxContent(); Native:RefreshInbox() end)
    panel:SetScript("OnHide", function() Native:CancelReturnConfirmation(); panel.filter.menu:Hide(); panel.menu.menu:Hide(); Native:SetInboxShell(false) end)
    self.readyInbox = true
end
function Native:Row(data)
    local panel = self.inbox; panel.used = panel.used + 1
    local row = panel.rows[panel.used]
    if not row then
        row = CreateFrame("Button", nil, panel.content, "BackdropTemplate"); row:SetBackdrop(BACKDROP)
        row.separator = row:CreateTexture(nil, "BACKGROUND"); row.separator:SetColorTexture(0.12, 0.24, 0.22, 0.6)
        row.separator:SetPoint("BOTTOMLEFT", 0, 0); row.separator:SetPoint("BOTTOMRIGHT", 0, 0); row.separator:SetHeight(1)
        row.check = Addon.Core.UITheme:CreateCheckbox(row, ""); row.check:SetSize(24, 46); row.check:SetPoint("LEFT", 0, 0)
        row.check.label:Hide(); row.check.box:ClearAllPoints(); row.check.box:SetPoint("CENTER"); row.check.box:EnableMouse(false)
        row.check:SetHitRectInsets(0, 0, 0, 0); row.check:RegisterForClicks("LeftButtonUp")
        row.delete = CreateFrame("Button", nil, row); row.delete:SetSize(24, 46); row.delete:SetPoint("LEFT", 0, 0); row.delete:RegisterForClicks("LeftButtonUp")
        row.delete.label = Text(row.delete, "GameFontHighlightSmall", "CENTER"); row.delete.label:SetAllPoints(); row.delete.label:SetText("X")
        row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetPoint("LEFT", 26, 0); row.icon:SetSize(32, 32)
        row.count = Text(row, "NumberFontNormal", "RIGHT"); row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 1, -1)
        row.title = Text(row, "GameFontNormal"); row.title:SetPoint("TOPLEFT", 66, -5); row.title:SetPoint("TOPRIGHT", -62, -5); row.title:SetHeight(18)
        row.detail = Text(row); row.detail:SetPoint("TOPLEFT", 66, -24); row.detail:SetPoint("TOPRIGHT", -6, -24); row.detail:SetHeight(17)
        row.summary = Text(row, "GameFontHighlightSmall", "RIGHT"); row.summary:SetPoint("BOTTOMRIGHT", -6, 4); row.summary:SetWidth(72); row.summary:SetHeight(18); row.summary:SetTextColor(0.72, 0.82, 0.79)
        row.expiry = Text(row, "GameFontGreenSmall", "RIGHT"); row.expiry:SetPoint("TOPRIGHT", -6, -5); row.expiry:SetWidth(68)
        panel.rows[panel.used] = row
    end
    local height = 32
    row.mailOriginalIndex = data.mailOriginalIndex
    row.mailEntryKey = data.mailEntryKey
    row.mailAttachmentSlot = data.mailAttachmentSlot
    row.mailListTop = panel.top
    row.mailIndented = data.indent == true
    row:ClearAllPoints(); row:SetPoint("TOPLEFT", data.indent and 16 or 0, -panel.top); row:SetSize(panel.width - (data.indent and 16 or 0), height)
    row:SetBackdropColor(0, 0, 0, 0); row:SetBackdropBorderColor(0, 0, 0, 0)
    row.title:SetText(tostring(data.title or ""):gsub("[\r\n]+", " ")); row.detail:SetText(tostring(data.detail or ""):gsub("[\r\n]+", " ")); row.expiry:SetText(data.expiry or "")
    if data.expiryMail then row.expiry:SetTextColor(View:ExpiryColor(data.expiryMail)) else row.expiry:SetTextColor(0.25, 0.9, 0.35) end
    local bodyWidth = math.max(1, row:GetWidth() - 58 - (data.expiry and 76 or 6))
    local titleWidth = data.mailAttachmentSlot and bodyWidth or math.min(100, bodyWidth * 0.38)
    row.title:ClearAllPoints(); row.title:SetPoint("TOPLEFT", 58, -7); row.title:SetSize(titleWidth, 18)
    row.title:SetWordWrap(false); row.detail:SetWordWrap(false)
    row.detail:ClearAllPoints(); row.detail:SetPoint("TOPLEFT", 58 + titleWidth + 6, -7); row.detail:SetSize(math.max(1, bodyWidth - titleWidth - 6), 18)
    row.detail:SetShown(not data.mailAttachmentSlot)
    row.icon:ClearAllPoints(); row.icon:SetPoint("TOPLEFT", 28, -4); row.icon:SetSize(24, 24)
    row.expiry:ClearAllPoints(); row.expiry:SetPoint("TOPRIGHT", -6, -7); row.expiry:SetHeight(18)
    row.check:SetHeight(32); row.check:ClearAllPoints(); row.check:SetPoint("TOPLEFT", 0, 0)
    row.delete:SetHeight(32); row.delete:ClearAllPoints(); row.delete:SetPoint("TOPLEFT", 0, 0)
    row.summary:SetText(data.summary or ""); row.summary:Hide()
    if data.wasRead then
        row.title:SetTextColor(0.60, 0.68, 0.68)
        row.detail:SetTextColor(0.65, 0.72, 0.72)
        row.summary:SetTextColor(0.55, 0.63, 0.62)
    else
        row.title:SetTextColor(1, 0.82, 0)
        row.detail:SetTextColor(1, 1, 1)
        row.summary:SetTextColor(0.72, 0.82, 0.79)
    end
    row.icon:SetTexture(data.texture or "Interface\\Icons\\INV_Letter_15"); row.count:SetText(data.quantity and tostring(data.quantity) or "")
    local actions, eligible, selected = data.actions or {}, 0, 0
    for _, action in ipairs(actions) do if action.actionable then eligible = eligible + 1; panel.available[#panel.available + 1] = action; if panel.selection[action.id] then selected = selected + 1 end end end
    row.check:SetFrameLevel(row:GetFrameLevel() + 2)
    row.delete:SetFrameLevel(row:GetFrameLevel() + 2)
    row.delete:SetShown(data.onDelete ~= nil)
    row.delete:SetEnabled(data.onDelete ~= nil and not self.deleting and Addon.Queue.state ~= "running" and not Addon.Queue.pending)
    row.delete:SetAlpha(row.delete:IsEnabled() and 1 or 0.45)
    row.delete:SetScript("OnClick", data.onDelete)
    Tooltip(row.delete, Addon:T("UI.TEXT_0155"))
    row.check:SetShown(#actions > 0); row.check:SetCheckState(selected > 0 and (selected == eligible and "checked" or "partial") or "unchecked")
    row.check:SetEnabled(eligible > 0 and Addon.Queue.state ~= "running" and not Addon.Queue.pending)
    row.check:SetAlpha(row.check:IsEnabled() and 1 or 0.45)
    Tooltip(row.check, Addon:T("UI.TEXT_0166"), Addon.Queue.pending and Addon:T("UI.TEXT_0265") or (Addon.Queue.state == "running" and Addon:T("UI.TEXT_0350") or (eligible == 0 and (data.tooltip or data.detail or Addon:T("UI.TEXT_0285")) or Addon:T("UI.TEXT_0447"))))
    if selected > 0 then row:SetBackdropColor(0.02, 0.17, 0.14, 1) end
    row.check:SetScript("OnClick", function()
        if eligible == 0 or Addon.Queue.state == "running" or Addon.Queue.pending then return end
        if Addon.Queue.state == "paused" then Addon.Queue:Discard() end
        local allSelected = true
        for _, action in ipairs(actions) do if action.actionable and not panel.selection[action.id] then allSelected = false end end
        panel.notice = nil; for _, action in ipairs(actions) do if action.actionable then panel.selection[action.id] = not allSelected or nil end end
        Native:RefreshInbox()
    end)
    row:SetScript("OnClick", data.onClick)
    Tooltip(row, data.title, data.tooltip or data.detail, data.itemLink)
    row.iconHover = row.iconHover or CreateFrame("Button", nil, row)
    row.iconHover:ClearAllPoints(); row.iconHover:SetPoint("TOPLEFT", 28, -4); row.iconHover:SetSize(24, 24)
    row.iconHover:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    row.iconHover:SetScript("OnClick", data.onClick)
    local item = data.item or (data.itemList or {})[1]
    Tooltip(row.iconHover, data.title, data.tooltip or data.detail, item and (item.itemLink or item.itemID and ("item:" .. item.itemID)) or data.itemLink)
    row.iconHover:SetShown(item ~= nil or data.itemLink ~= nil)
    self:RowItems(row, data.itemList)
    if data.empty then
        -- Empty-state text has the whole row; it is not a sender/subject pair.
        row.title:SetWidth(math.max(1, row:GetWidth() - 64))
        row.detail:ClearAllPoints(); row.detail:SetPoint("TOPLEFT", 58, -30)
        row.detail:SetWidth(math.max(1, row:GetWidth() - 64)); row.detail:SetHeight(0); row.detail:SetWordWrap(true)
        local detailHeight = math.max(18, row.detail:GetStringHeight())
        row.detail:SetHeight(detailHeight); row:SetHeight(38 + detailHeight)
    end
    height = row:GetHeight()
    row:Show(); panel.top = panel.top + height + 2
end
function Native:RowItems(row, items)
    if row.attachments then
        row.attachments:Hide()
        for _, button in ipairs(row.attachments.itemButtons or {}) do button:Hide() end
    end
    row:SetHeight(32)
    if #(items or {}) <= 1 then return end
    local ui, width = Addon.CacheUI, math.max(1, row:GetWidth() - 62)
    local values = { itemList = items, items = Addon:T("UI.TEXT_0448") }
    local _, height = ui:ItemLayout(values, width)
    if not row.attachments then
        row.attachments = CreateFrame("Button", nil, row)
        row.attachments.cell = Addon.Core.UITheme:CreateText(row.attachments, Addon.Core.UITheme.Font.body, Addon.Core.UITheme.Colors.text, "LEFT")
    end
    row.attachments:ClearAllPoints(); row.attachments:SetPoint("TOPLEFT", 56, -30); row.attachments:SetSize(width, height + 8)
    -- Item buttons preserve the parent row's normal mail interactions.
    row.attachments:SetScript("OnMouseUp", function(_, mouse) local click = row:GetScript("OnClick"); if click then click(row, mouse) end end)
    ui:ItemCell(row.attachments, row.attachments.cell, values, 0, width, height + 8)
    for _, button in ipairs(row.attachments.itemButtons) do
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
        button:SetScript("OnClick", function(_, mouse) local click = row:GetScript("OnClick"); if click then click(row, mouse) end end)
    end
    row.attachments:Show(); row:SetHeight(38 + height)
end
function Native:DeleteEmptyMail(entry)
    if self.deleting or Addon.Queue.state == "running" or Addon.Queue.pending then return end
    local character = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    local mails, err = Addon.Scanner:ReadVisible()
    local index = entry.mail.inboxIndex
    local mail = mails and mails[index]
    if not character or character.id ~= entry.character.id or not mail or mail.signature ~= entry.mail.signature
        or #mail.attachments > 0 or mail.money > 0 or mail.cod > 0 then
        self.inbox.notice = err or Addon:T("UI.TEXT_0594"); self:RefreshInbox(); return
    end
    if type(InboxItemCanDelete) ~= "function" or not InboxItemCanDelete(index) or type(DeleteInboxItem) ~= "function" then
        self.inbox.notice = Addon:T("UI.TEXT_0283"); self:RefreshInbox(); return
    end
    local ticket = {}
    self.deleting = ticket
    self.deleteStartedAt = GetTime()
    C_Timer.After(12.01, function()
        if Native.deleting ~= ticket then return end
        Native.deleting = nil
        Native.inbox.notice = Addon:T("UI.TEXT_0154")
        Native:RefreshInbox()
    end)
    if OpenMailFrame and OpenMailFrame:IsShown() and InboxFrame.openMailID == index then
        InboxFrame.openMailID, self.openMailKey = nil, nil
        if HideUIPanel then HideUIPanel(OpenMailFrame) else OpenMailFrame:Hide() end
    end
    DeleteInboxItem(index)
    self:RefreshInbox()
    if Addon.Scanner.Schedule then Addon.Scanner:Schedule() end
end
function Native:OpenMail(entry, keepOpen)
    if not keepOpen and OpenMailFrame and OpenMailFrame:IsShown() and self.openMailKey == entry.key and InboxFrame.openMailID == entry.mail.inboxIndex then
        self.openMailKey = nil
        if HideUIPanel then HideUIPanel(OpenMailFrame) else OpenMailFrame:Hide() end
        return
    end
    if Addon.Queue.state == "running" or Addon.Queue.pending then self.inbox.notice = Addon:T("UI.TEXT_0529"); self:RefreshInbox(); return end
    local current, err
    if Addon.Scanner.ReadEntry then current, err = Addon.Scanner:ReadEntry(entry)
    else
        local mails; mails, err = Addon.Scanner:ReadVisible()
        current = mails and mails[entry.mail.inboxIndex]
        if current and current.signature ~= entry.mail.signature then current = nil end
    end
    if not current then self.inbox.notice = err or Addon:T("UI.TEXT_0594"); self:RefreshInbox(); return end
    if OpenMail_Update and ShowUIPanel then
        local index = entry.mail.inboxIndex
        InboxFrame.openMailID = index
        OpenMailFrame.updateButtonPositions = true
        ShowUIPanel(OpenMailFrame)
        -- Some mailbox skins initialize or clear the native letter controls
        -- from OpenMailFrame's OnShow handler. Populate the fields after the
        -- frame is visible so the sender, subject, body and attachments remain
        -- present in the native panel.
        OpenMailFrame.updateButtonPositions = true
        OpenMail_Update()
        self.openMailKey = entry.key
        if Addon.MarkMailOpened then Addon:MarkMailOpened(entry) else entry.mail.openedByUser = true end
        if InboxFrame_Update then InboxFrame_Update() end
        if Addon.Scanner.Schedule then Addon.Scanner:Schedule() end
        return true, current
    end
    self.inbox.notice = Addon:T("UI.TEXT_0171"); self:RefreshInbox()
end
function Native:ReadMail(entry, automatic, batch)
    if Addon.Queue.state == "running" or Addon.Queue.pending then
        if not automatic then self.inbox.notice = Addon:T("UI.TEXT_0529"); self:RefreshInbox() end
        return nil
    end
    local current, err
    if Addon.Scanner.ReadEntry then current, err = Addon.Scanner:ReadEntry(entry)
    else
        local mails; mails, err = Addon.Scanner:ReadVisible()
        current = mails and mails[entry.mail.inboxIndex]
        if current and current.signature ~= entry.mail.signature then current = nil end
    end
    if not current then
        if not automatic then self.inbox.notice = err or Addon:T("UI.TEXT_0594"); self:RefreshInbox() end
        return nil
    end
    if type(GetInboxText) == "function" then
        local ok, why = pcall(GetInboxText, entry.mail.inboxIndex)
        if not ok then
            if not automatic then self.inbox.notice = tostring(why); self:RefreshInbox() end
            return nil
        end
        entry.mail.wasRead = true
    elseif automatic then
        return nil
    end
    if Addon.MarkMailOpened then return Addon:MarkMailOpened(entry, batch) end
    entry.mail.openedByUser = true; return true
end
function Native:ReadDisplayedMails(entries)
    -- Only the live mailbox surface acknowledges mail, never background
    -- snapshots, account previews, or entries excluded by the active filter.
    if not Addon.Scanner.IsOpen or not Addon.Scanner:IsOpen() then return end
    local seen, batch = {}, {}
    for _, entry in ipairs(entries) do
        if not seen[entry.key] then
            seen[entry.key] = true
            if not entry.mail.wasRead or not entry.mail.openedByUser then self:ReadMail(entry, true, batch) end
        end
    end
    for characterID, keys in pairs(batch) do
        Addon:UpdateMailNoticeBatch(characterID)
        Addon:Publish(characterID, keys, {}, "scan", true)
    end
end
function Native:CollectCOD(entry, item)
    local ok, current = self:OpenMail(entry, true)
    if not ok then return end
    local matched
    for _, attachment in ipairs(current.attachments) do
        if attachment.attachmentIndex == item.attachmentIndex and attachment.variantKey == item.variantKey and attachment.quantity == item.quantity then matched = attachment end
    end
    if not matched or current.cod <= 0 then
        self.inbox.notice = Addon:T("UI.TEXT_0629"); self:RefreshInbox(); return
    end
    if type(OpenMailAttachment_OnClick) ~= "function" then
        self.inbox.notice = Addon:T("UI.TEXT_0546"); self:RefreshInbox(); return
    end
    OpenMailAttachment_OnClick(_G["OpenMailAttachmentButton" .. item.attachmentIndex] or OpenMailFrame, item.attachmentIndex)
end
function Native:EntryRows(entry)
    local panel, mail = self.inbox, entry.mail
    local expandable = #mail.attachments > 0 or mail.money > 0
    local attachmentSummary = Addon:T("UI.TEXT_0623") .. #mail.attachments .. Addon:T("UI.TEXT_0023")
    local parts = {}
    if mail.money > 0 then parts[#parts + 1] = Addon:T("UI.TEXT_0615") .. View:Money(mail.money) end
    if mail.cod > 0 then parts[#parts + 1] = Addon:T("UI.TEXT_0109") .. View:Money(mail.cod) end
    if mail.wasReturned then parts[#parts + 1] = Addon:T("UI.TEXT_0577") end
    local extra = table.concat(parts, " · ")
    local subject = View:Escape(mail.subject) .. (extra ~= "" and (" · " .. extra) or "")
    local function ToggleAttachments()
        if not expandable then return end
        panel.expanded[entry.key] = not panel.expanded[entry.key]; Native:RefreshInbox()
    end
    local middleClickHelp = entry.actionable and #mail.attachments > 0 and Addon:T("UI.TEXT_0070") or ""
    self:Row({ title = View:CounterpartLabel(mail.sender, entry.character), detail = subject, summary = attachmentSummary, wasRead = mail.openedByUser,
        itemList = mail.attachments,
        onDelete = #mail.attachments == 0 and mail.money == 0 and mail.cod == 0 and mail.canReturn ~= true and function() Native:DeleteEmptyMail(entry) end or nil,
        texture = mail.attachments[1] and mail.attachments[1].texture, quantity = #mail.attachments == 1 and mail.attachments[1].quantity or nil,
        mailOriginalIndex = mail.inboxIndex, mailEntryKey = entry.key,
        expiry = View:Expiry(mail), expiryMail = mail, actions = self:GetSelectableMailActions(entry), tooltip = subject .. "\n" .. attachmentSummary .. Addon:T("UI.TEXT_0071") .. View:Expiry(mail) .. Addon:T("UI.TEXT_0073") .. middleClickHelp .. (not entry.actionable and ("\n" .. entry.restriction) or ""),
        onClick = function(_, mouse)
            if mouse == "MiddleButton" then Native:CollectMailAttachments(entry)
            elseif mouse == "RightButton" or not expandable then Native:OpenMail(entry)
            elseif panel.expanded[entry.key] then ToggleAttachments()
            elseif Native:ReadMail(entry) then ToggleAttachments() end
        end })
    panel.rows[panel.used]:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    if panel.expanded[entry.key] then
        for _, item in ipairs(mail.attachments) do
            self:Row({ title = item.itemLink or View:Escape(item.name), detail = Addon:T("UI.TEXT_0631") .. item.attachmentIndex .. " · " .. (mail.cod > 0 and (Addon:T("UI.TEXT_0109") .. View:Money(mail.cod)) or (entry.actionable and Addon:T("UI.TEXT_0196") or entry.restriction)),
                mailOriginalIndex = mail.inboxIndex, mailEntryKey = entry.key, mailAttachmentSlot = item.attachmentIndex,
                texture = item.texture, quantity = item.quantity, expiry = View:Expiry(mail), expiryMail = mail, indent = true, item = item, itemLink = item.itemLink, actions = Addon:GetInboxActions(entry, item),
                onClick = function(_, mouse)
                    if mouse == "RightButton" then Native:OpenMail(entry)
                    elseif mail.cod > 0 then Native:CollectCOD(entry, item) end
                end })
            panel.rows[panel.used]:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        end
        if mail.money > 0 then
            local actions = {}; for _, action in ipairs(Addon:GetInboxActions(entry)) do if action.slot == "money" then actions[1] = action end end
            self:Row({ title = Addon:T("UI.TEXT_0615") .. View:Money(mail.money), detail = Addon:T("UI.TEXT_0412") .. View:Escape(mail.sender), mailOriginalIndex = mail.inboxIndex,
                mailEntryKey = entry.key, mailAttachmentSlot = "money", indent = true,
                texture = "Interface\\Icons\\INV_Misc_Coin_01", actions = actions })
        end
    end
end
function Native:Collect()
    local panel, queue = self.inbox, Addon.Queue; panel.notice = nil
    if queue.state == "running" or queue.pending then panel.notice = Addon:T("UI.TEXT_0552"); self:RefreshInbox(); return end
    local selection, _, selectionError = self:GetCollectSelection(View:GetMails(self:Context(), {}))
    if not selection then panel.notice = selectionError; self:RefreshInbox(); return end
    local actions, err = queue:Prepare(selection, self:Context())
    panel.notice = err
    if actions then
        -- The native inbox panel uses this entry point for checked batch
        -- collection; keep its rows mounted while per-mail updates arrive.
        panel.keepTilesDuringQueue = true
        local ok, why = queue:Start(actions)
        if not ok then panel.keepTilesDuringQueue = nil; panel.notice = why end
    end
    if not actions then panel.keepTilesDuringQueue = nil end
    self:RefreshInbox()
end
function Native:CollectMailAttachments(entry)
    local panel, queue = self.inbox, Addon.Queue
    if queue.state == "running" or queue.pending then
        panel.notice = Addon:T("UI.TEXT_0552"); self:RefreshInbox(); return
    end
    local selection = {}
    for _, item in ipairs(entry.mail.attachments or {}) do
        for _, action in ipairs(Addon:GetInboxActions(entry, item)) do
            if action.actionable then selection[action.id] = true end
        end
    end
    if not next(selection) then
        panel.notice = entry.mail.cod > 0 and Addon:T("UI.TEXT_0112") or Addon:T("UI.TEXT_0576")
        self:RefreshInbox(); return
    end
    panel.notice = nil
    local actions, err = queue:Prepare(selection, self:Context())
    if not actions then panel.notice = err; self:RefreshInbox(); return end
    local ok, why = queue:Start(actions)
    if not ok then panel.notice = why end
    self:RefreshInbox()
end
function Native:CollectItem(group, single)
    local panel, queue = self.inbox, Addon.Queue
    if queue.state == "running" or queue.pending then return end
    local selection, sources = {}, {}
    for _, source in ipairs(group.sources) do sources[#sources + 1] = source end
    table.sort(sources, function(a, b)
        local aExpiry = tonumber(a.entry.mail.expiresAtEstimate) or math.huge
        local bExpiry = tonumber(b.entry.mail.expiresAtEstimate) or math.huge
        if aExpiry ~= bExpiry then return aExpiry < bExpiry end
        local aIndex = tonumber(a.entry.mail.inboxIndex) or math.huge
        local bIndex = tonumber(b.entry.mail.inboxIndex) or math.huge
        if aIndex ~= bIndex then return aIndex < bIndex end
        if group.money then return tostring(a.entry.key or "") < tostring(b.entry.key or "") end
        return (tonumber(a.item.attachmentIndex) or math.huge) < (tonumber(b.item.attachmentIndex) or math.huge)
    end)
    for _, source in ipairs(sources) do
        for _, action in ipairs(Addon:GetInboxActions(source.entry, source.item)) do
            if action.actionable and ((group.money and action.slot == "money") or (not group.money and action.slot ~= "money")) then
                selection[action.id] = true
                if single then break end
            end
        end
        if single and next(selection) then break end
    end
    if single and not next(selection) then panel.notice = group.money and Addon:T("UI.TEXT_0437") or Addon:T("UI.TEXT_0516"); self:RefreshInbox(); return end
    local actions, err = queue:Prepare(selection, self:Context())
    panel.notice = err
    if actions then
        -- Keep the visible list mounted for the whole batch. Rebuilding every
        -- row after each MAIL_INBOX_UPDATE flickers the list and repeats layout work.
        panel.keepTilesDuringQueue = true
        local ok, why = queue:Start(actions)
        if not ok then panel.keepTilesDuringQueue = nil; panel.notice = why end
    end
    self:RefreshInbox()
end
function Native:ItemTile(group, index, columns, size)
    local panel = self.inbox
    panel.tiles = panel.tiles or {}
    local tile = panel.tiles[index]
    if not tile then
        tile = CreateFrame("Button", nil, panel.content, "BackdropTemplate"); tile:SetBackdrop(BACKDROP); tile:SetSize(42, 42)
        tile.icon = tile:CreateTexture(nil, "ARTWORK"); tile.icon:SetPoint("TOPLEFT", 1, -1); tile.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        tile.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tile.count = Text(tile, "NumberFontNormal", "RIGHT"); tile.count:SetPoint("BOTTOMRIGHT", -3, 3)
        panel.tiles[index] = tile
    end
    size = size or 42
    tile:SetSize(size, size)
    tile:ClearAllPoints(); tile:SetPoint("TOPLEFT", ((index - 1) % columns) * (size + 4), -math.floor((index - 1) / columns) * (size + 4))
    local texture = group.item.texture or "Interface\\Icons\\INV_Misc_QuestionMark"
    if tile.displayTexture ~= texture then tile.icon:SetTexture(texture); tile.displayTexture = texture end
    tile.count:SetText(group.money and tostring(math.floor(group.quantity / 10000)) or tostring(group.quantity))
    local eligible, codSource = 0, nil
    for _, source in ipairs(group.sources) do
        if not codSource and source.entry.mail.cod > 0 then codSource = source end
        for _, action in ipairs(Addon:GetInboxActions(source.entry, source.item)) do
            if action.actionable and ((group.money and action.slot == "money") or (not group.money and action.slot ~= "money")) then
                eligible = eligible + 1
            end
        end
    end
    tile:SetBackdropColor(0, 0, 0, 0)
    local borderColor, needsItemInfo
    if group.money then borderColor = { 1, 0.75, 0.15, 1 }
    else borderColor, needsItemInfo = View:AttachmentBorder(group) end
    tile:SetBackdropBorderColor(unpack(borderColor))
    if not group.money and needsItemInfo and group.item.itemID then
        self.pendingItemInfo = self.pendingItemInfo or {}
        if not self.pendingItemInfo[group.item.itemID]
            and Addon.Core.ItemResolver:GetInfo(group.item.itemID).state ~= "ready" then
            self.pendingItemInfo[group.item.itemID] = true
            local id = group.item.itemID
            Addon.Core.ItemResolver:Request(id, function(info)
                Native:OnEvent("GET_ITEM_INFO_RECEIVED", id, info and info.state == "ready")
            end)
        end
    end
    local groupKey = group.id or (group.money and "money") or group.item.variantKey or group.item.itemID
    local available = eligible > 0 or codSource ~= nil
    local rechecking = Addon.Scanner.refreshPending and not Addon.Scanner.lastError
    -- Display continuity is independent of eligibleCount and the click guard.
    local displayAvailable = available
        or (rechecking and groupKey ~= nil and panel.previousTileAvailability
            and panel.previousTileAvailability[groupKey]) or false
    if tile.displayAvailable ~= displayAvailable then tile.icon:SetDesaturated(not displayAvailable) end
    tile.displayKey, tile.displayAvailable = groupKey, displayAvailable
    tile.mailGroup = group
    tile.eligibleCount = eligible
    -- Keep the tile active so its hover tooltip remains available while the
    -- queue is running; CollectItem/OpenMail already guard mouse activation.
    tile:SetEnabled(eligible > 0 or codSource ~= nil)
    tile:SetScript("OnClick", function()
        if eligible > 0 then Native:CollectItem(group, IsAltKeyDown and IsAltKeyDown())
        elseif codSource then Native:CollectCOD(codSource.entry, codSource.item) end
    end)
    tile:SetScript("OnEnter", function(control)
        if not GameTooltip then return end
        GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        if group.money then
            GameTooltip:SetText(Addon:T("UI.TEXT_0286") .. View:Money(group.quantity))
            local orderedSources = {}
            for _, source in ipairs(group.sources) do orderedSources[#orderedSources + 1] = source end
            table.sort(orderedSources, function(a, b)
                return (tonumber(a.entry.mail.expiresAtEstimate) or math.huge) < (tonumber(b.entry.mail.expiresAtEstimate) or math.huge)
            end)
            for _, source in ipairs(orderedSources) do
                local mail = source.entry.mail
                local red, green, blue = View:ExpiryColor(mail)
                local subject = mail.subject and mail.subject ~= "" and (" · " .. mail.subject) or ""
                GameTooltip:AddLine(View:Escape((mail.sender or "") .. subject .. " · " .. View:Money(source.money) .. " · " .. View:Expiry(mail)), red, green, blue, false)
            end
            if (control.eligibleCount or eligible) > 0 then GameTooltip:AddLine(Addon:T("UI.TEXT_0067"), 0.25, 0.9, 0.75, true) end
            GameTooltip:Show()
            return
        end
        local itemLink = group.item.itemLink
        if itemLink and itemLink ~= "" then
            GameTooltip:SetHyperlink(itemLink)
        elseif group.item.itemID then
            -- The inbox API can provide an item ID before it provides a full
            -- hyperlink. An item hyperlink still lets Blizzard build its
            -- normal item tooltip from that ID.
            GameTooltip:SetHyperlink("item:" .. tostring(group.item.itemID))
        end
        if GameTooltip:NumLines() == 0 then GameTooltip:SetText(group.item.name or Addon:T("UI.TEXT_0624")) end
        local mailSources, orderedSources, seenMails, mailCount = {}, {}, {}, 0
        for _, source in ipairs(group.sources) do
            local mail = source.entry.mail
            local mailKey = Addon.Encode({ source.entry.character.id, source.entry.key or mail.signature or mail.subject })
            if not seenMails[mailKey] then seenMails[mailKey] = true; mailCount = mailCount + 1 end
            local quantity = tonumber(source.item.quantity) or 0
            local expires = tonumber(mail.expiresAtEstimate)
            local expiryDay = expires and date("%Y-%m-%d", expires) or mailKey
            local key = Addon.Encode({ source.entry.character.id, mail.sender or "", expiryDay,
                source.item.variantKey or source.item.itemID, quantity })
            local grouped = mailSources[key]
            if not grouped then
                grouped = { mail = mail, item = source.item, quantity = quantity, slots = 0,
                    expiryDay = expiryDay, order = #orderedSources + 1 }
                mailSources[key] = grouped; orderedSources[#orderedSources + 1] = grouped
            end
            -- A merged row uses the earliest expiry so its countdown stays conservative.
            if (mail.expiresAtEstimate or math.huge) < (grouped.mail.expiresAtEstimate or math.huge) then grouped.mail = mail end
            grouped.slots = grouped.slots + 1
        end
        table.sort(orderedSources, function(a, b)
            if a.expiryDay ~= b.expiryDay then return a.expiryDay < b.expiryDay end
            local aSender, bSender = a.mail.sender or "", b.mail.sender or ""
            if aSender ~= bSender then return aSender < bSender end
            if a.quantity ~= b.quantity then return a.quantity > b.quantity end
            return a.order < b.order
        end)
        if #orderedSources > 0 then GameTooltip:AddLine(" ") end
        GameTooltip:AddLine(Addon:T("UI.TEXT_0201") .. group.quantity .. Addon:T("UI.TEXT_0027") .. mailCount .. Addon:T("UI.TEXT_0033"), 1, 1, 1)
        for _, source in ipairs(orderedSources) do
            local mail = source.mail
            local red, green, blue = View:ExpiryColor(mail)
            local sender = mail.sender and mail.sender ~= "" and (mail.sender .. " · ") or ""
            local itemName = source.item.name
            if not itemName or itemName == "" then itemName = (source.item.itemLink or ""):match("%[(.-)%]") or group.item.name or Addon:T("UI.TEXT_0624") end
            local line = sender .. itemName .. Addon:T("UI.TEXT_0646") .. source.quantity .. Addon:T("UI.TEXT_0650") .. source.slots .. Addon:T("UI.TEXT_0115")
            line = line .. " · " .. View:Expiry(mail)
            GameTooltip:AddLine(View:Escape(line), red, green, blue, false)
        end
        if (control.eligibleCount or eligible) > 0 then GameTooltip:AddLine(Addon:T("UI.TEXT_0066"), 0.25, 0.9, 0.75, true) end
        GameTooltip:Show()
    end)
    tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tile:Show()
end
function Native:RefreshInboxProgress()
    local panel, queue = self.inbox, Addon.Queue
    if not self.readyInbox or not panel or not panel:IsShown() then return end
    local progress
    if queue.pending then
        local state = queue.pending.success or queue.pending.updated and Addon:T("UI.TEXT_0424") or Addon:T("UI.TEXT_0422")
        if type(state) == "boolean" then state = Addon:T("UI.TEXT_0424") end
        progress = state .. " " .. tostring(queue.completed + 1) .. "/" .. #queue.actions
    else
        progress = queue.message .. " " .. queue.completed .. "/" .. #queue.actions
    end
    panel.status:SetText(progress)
    Tooltip(panel.statusHover, Addon:T("UI.TEXT_0342"), progress)
    panel.collect:SetEnabled(false)
    panel.collect:SetState("disabled")
    panel.returnMail:SetEnabled(false); panel.returnMail:SetState("disabled")
    self:LayoutInboxFooter()
    for _, row in ipairs(panel.rows or {}) do if row:IsShown() then row.check:SetEnabled(false) end end
    -- A mounted list skips the normal refresh, so refresh its menu availability
    -- here too: pause must become available as soon as a batch starts.
    for index, option in ipairs(panel.menu.options or {}) do
        local enabled = option.value ~= "select" and option.value ~= "clear"
        if option.value == "pause" then enabled = queue.state == "running" end
        local button = panel.menu.menu.buttons[index]
        button:SetEnabled(enabled); button:SetState(enabled and "default" or "disabled")
    end
end
function Native:LayoutInboxFooter()
    local panel = self.inbox
    if not panel or not panel.status then return end
    panel.status:ClearAllPoints()
    panel.status:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", panel.mode == "mail" and 32 or 8, 8)
    local right = panel.mode == "mail" and (panel.returnMail:IsShown() and panel.returnMail or panel.collect) or panel.menu
    panel.status:SetPoint("RIGHT", right, "LEFT", -6, 0)
end
function Native:RefreshCollectedMailRow(action)
    local panel = self.inbox
    if not panel or panel.mode ~= "mail" or not action or not action.original then return end
    local originalIndex = action.original.inboxIndex
    local mainRow
    for _, row in ipairs(panel.rows) do
        if row:IsShown() and row.mailOriginalIndex == originalIndex then
            if row.mailAttachmentSlot == action.slot then
                row.detail:SetText(action.slot == "money" and Addon:T("UI.TEXT_0616") or (Addon:T("UI.TEXT_0631") .. tostring(action.slot) .. Addon:T("UI.TEXT_0006")))
                row.check:SetShown(false)
            elseif row.mailAttachmentSlot == nil then
                mainRow = row
            end
        end
    end
    if action.mailCollected then
        local firstTop, removedHeight
        removedHeight = 0
        for _, row in ipairs(panel.rows) do
            if row:IsShown() and row.mailOriginalIndex == originalIndex then
                firstTop = firstTop and math.min(firstTop, row.mailListTop or 0) or (row.mailListTop or 0)
                removedHeight = removedHeight + row:GetHeight() + 2
                self:ReleaseInboxRow(row)
            end
        end
        if removedHeight > 0 then
            local shift = removedHeight
            for _, row in ipairs(panel.rows) do
                if row:IsShown() and (row.mailListTop or 0) > firstTop then
                    row.mailListTop = row.mailListTop - shift
                    row:ClearAllPoints(); row:SetPoint("TOPLEFT", row.mailIndented and 16 or 0, -row.mailListTop)
                end
            end
            panel.top = math.max(0, panel.top - shift)
            panel.content:SetSize(panel.width, math.max(1, panel.top)); panel.scroll:SetContentHeight(panel.top)
            local scrollOffset = panel.scroll:GetVerticalScroll()
            if scrollOffset and firstTop < scrollOffset then panel.scroll:SetVerticalScroll(math.max(0, scrollOffset - shift)) end
        end
        return
    end
    local mail, entry
    if action.resultMail and mainRow then
        mail = action.resultMail
        entry = { character = Addon.Core.Characters:GetCurrent({ identityOnly = true }), key = action.resultMailKey, mail = mail,
            actionable = mail.cod == 0 and mail.state == "observed" }
        local extra = {}
        if mail.money > 0 then extra[#extra + 1] = Addon:T("UI.TEXT_0615") .. View:Money(mail.money) end
        if mail.cod > 0 then extra[#extra + 1] = Addon:T("UI.TEXT_0109") .. View:Money(mail.cod) end
        if mail.wasReturned then extra[#extra + 1] = Addon:T("UI.TEXT_0577") end
        mainRow.detail:SetText(View:Escape(mail.subject) .. (#extra > 0 and (" · " .. table.concat(extra, " · ")) or ""))
        mainRow.summary:SetText(Addon:T("UI.TEXT_0623") .. #mail.attachments .. Addon:T("UI.TEXT_0023"))
        mainRow.icon:SetTexture(mail.attachments[1] and mail.attachments[1].texture or "Interface\\Icons\\INV_Letter_15")
        local previousHeight = mainRow:GetHeight()
        self:RowItems(mainRow, mail.attachments)
        local shift = mainRow:GetHeight() - previousHeight
        if shift ~= 0 then
            for _, row in ipairs(panel.rows) do
                if row:IsShown() and (row.mailListTop or 0) > mainRow.mailListTop then
                    row.mailListTop = row.mailListTop + shift
                    row:ClearAllPoints(); row:SetPoint("TOPLEFT", row.mailIndented and 16 or 0, -row.mailListTop)
                end
            end
            panel.top = panel.top + shift
            panel.content:SetHeight(panel.top); panel.scroll:SetContentHeight(panel.top)
        end
        mainRow.count:SetText(#mail.attachments == 1 and tostring(mail.attachments[1].quantity) or "")
        local item = mail.attachments[1]
        Tooltip(mainRow.iconHover, View:Escape(mail.sender), View:Escape(mail.subject), item and (item.itemLink or item.itemID and ("item:" .. item.itemID)))
        mainRow.iconHover:SetShown(item ~= nil)
        mainRow.expiry:SetText(View:Expiry(mail)); mainRow.expiry:SetTextColor(View:ExpiryColor(mail))
        local attachments = {}; for _, item in ipairs(mail.attachments) do attachments[#attachments + 1] = View:Escape(item.name or item.itemLink or Addon:T("UI.TEXT_0624")) end
        Tooltip(mainRow, View:Escape(mail.sender), View:Escape(mail.subject) .. "\n"
            .. (#attachments > 0 and table.concat(attachments, Addon:T("UI.TEXT_0078")) or Addon:T("UI.TEXT_0434")))
        local actions, eligible, selected = Addon:GetInboxActions(entry), 0, 0
        for _, candidate in ipairs(actions) do
            if candidate.actionable then
                eligible = eligible + 1
                if panel.selection[candidate.id] then selected = selected + 1 end
            end
        end
        -- Pending queued actions retain their original IDs until each result is
        -- confirmed; use them to show the live remaining selection on this row.
        for index = Addon.Queue.index, #Addon.Queue.actions do
            local candidate = Addon.Queue.actions[index]
            if candidate.state == "pending" and candidate.characterID == action.characterID
                and candidate.original and candidate.original.inboxIndex == originalIndex then selected = selected + 1 end
        end
        mainRow.check:SetShown(#actions > 0)
        mainRow.check:SetCheckState(selected == 0 and "unchecked" or (selected >= eligible and "checked" or "partial"))
        mainRow.check:SetEnabled(false)
        mainRow:SetBackdropColor(selected > 0 and 0.02 or 0, selected > 0 and 0.17 or 0, selected > 0 and 0.14 or 0, 1)
    elseif mainRow then
        mainRow.detail:SetText(Addon:T("UI.TEXT_0403"))
        mainRow.summary:SetText(Addon:T("UI.TEXT_0251"))
        mainRow.count:SetText("")
        mainRow.check:SetShown(false)
        mainRow:SetBackdropColor(0.025, 0.055, 0.055, 1)
    end
end
function Native:RefreshInbox(observation)
    local panel = self.inbox; if not self.readyInbox or not panel:IsShown() or self.refreshingInbox then return end
    -- Invalidation is not a new mailbox observation. Keep the mounted list
    -- until the scanner commits or reports an error; execution still checks
    -- live readiness, even while these last observed rows remain visible.
    if observation and panel.observationMounted and Addon.Scanner.refreshPending
        and not Addon.Scanner.lastError and Addon.Queue.state ~= "running" then return end
    if Addon.Queue.state == "running" and panel.keepTilesDuringQueue then
        self:RefreshInboxProgress()
        return
    end
    if Addon.Queue.state ~= "running" then panel.keepTilesDuringQueue = nil end
    self.refreshingInbox = true
    -- A removed group shifts every later pool slot. Carry appearance by item
    -- identity before overwriting those slots, never by the old tile index.
    panel.previousTileAvailability = {}
    for _, tile in ipairs(panel.tiles or {}) do
        if tile:IsShown() and tile.displayKey ~= nil then
            panel.previousTileAvailability[tile.displayKey] = tile.displayAvailable
        end
    end
    panel.observationMounted = true
    panel.used, panel.top, panel.available, panel.width = 0, 0, {}, math.max(1, panel.scroll:GetWidth())
    local usedTiles = 0
    local context = self:Context()
    local character = context.characters[1]
    local snapshot = character and Addon.db.byCharacter and Addon.db.byCharacter[character.id]
    if snapshot then
        local expanded = {}
        for _, key in ipairs(snapshot.visibleKeys or {}) do if panel.expanded[key] then expanded[key] = true end end
        panel.expanded = expanded
    end
    local allMails = panel.mode == "mail" and View:GetMails(context, { sort = panel.options.sort }) or nil
    local visibleMails
    if panel.mode == "mail" and panel.options.search == "" and (panel.options.kind == nil or panel.options.kind == "all") then
        visibleMails = allMails
    else
        visibleMails = View:GetMails(context, panel.options)
    end
    if panel.mode == "mail" then
        self:ReadDisplayedMails(visibleMails)
        for _, entry in ipairs(visibleMails) do self:EntryRows(entry) end
    else
        local groups = View.GetGroupsFromEntries and View:GetGroupsFromEntries(visibleMails, panel.options)
            or View:GetGroups(context, panel.options)
        local displayed = {}
        for _, group in ipairs(groups) do
            for _, source in ipairs(group.sources) do displayed[#displayed + 1] = source.entry end
        end
        self:ReadDisplayedMails(displayed)
        -- Reserve the possible gutter before wrapping so overflow cannot clip
        -- the last tile when Core resolves the scrollbar on the next frame.
        local gridWidth = math.max(1, math.min(panel.width, panel:GetWidth() - 16 - Addon.Core.UITheme.Geometry.scrollbarGutter))
        local columns = math.max(1, math.min(7, math.floor((gridWidth + 4) / 42)))
        local size = math.max(1, (gridWidth - (columns - 1) * 4) / columns)
        for index, group in ipairs(groups) do self:ItemTile(group, index, columns, size) end
        usedTiles = #groups
        panel.top = #groups > 0 and math.ceil(#groups / columns) * (size + 4) - 4 or 0
    end
    if panel.top == 0 then
        local scan = Addon.Scanner
        local failed = scan.lastError ~= nil
        local pending = not scan.validAt or (type(HasNewMail) == "function" and HasNewMail()
            and type(GetInboxNumItems) == "function" and GetInboxNumItems() == 0)
        self:Row({ empty = true, title = failed and Addon:T("UI.TEXT_0600") or (pending and Addon:T("UI.TEXT_0423") or (panel.mode == "items" and Addon:T("UI.TEXT_0382") or Addon:T("UI.TEXT_0381"))),
            detail = failed and Addon:T("UI.TEXT_0561") or (pending and Addon:T("UI.TEXT_0476") or Addon:T("UI.TEXT_0198")) })
    end
    for index = usedTiles + 1, #(panel.tiles or {}) do self:ReleaseInboxTile(panel.tiles[index]) end
    for index = panel.used + 1, #panel.rows do self:ReleaseInboxRow(panel.rows[index]) end
    panel.content:SetSize(panel.width, math.max(1, panel.top)); panel.scroll:SetContentHeight(panel.top)
    local selected = self:UpdateReturnButton(allMails or {})
    local _, collectCount = self:GetCollectSelection(allMails or {})
    local selectedAttachments, counted = 0, {}
    for _, entry in ipairs(allMails or {}) do
        for _, item in ipairs(entry.mail.attachments) do
            local id = View:ActionID(entry.character.id, entry.key, item.attachmentIndex)
            if panel.selection[id] and not counted[id] then counted[id] = true; selectedAttachments = selectedAttachments + 1 end
        end
    end
    local character = context.characters[1]; local coverage = character and Addon.Items:GetState(character.id)
    local progress = Addon.Queue.state == "running" or Addon.Queue.state == "paused"
    local returnSummary
    if Addon.Queue.operation == "return" then
        if Addon.Queue.state == "complete" then returnSummary = Addon.Queue.message
        elseif Addon.Queue.state == "paused" then
            local unknown = Addon.Queue.pending and 1 or 0
            for _, action in ipairs(Addon.Queue.actions) do
                if action.state == "unverified" then unknown = unknown + 1 end
            end
            returnSummary = Addon:T("RETURN.PAUSED", Addon.Queue.completed, unknown,
                #Addon.Queue.actions - Addon.Queue.completed - unknown) .. " " .. Addon.Queue.message
        end
    end
    local selectable, selectedSelectable = 0, 0
    if panel.mode == "mail" then
        for _, entry in ipairs(visibleMails) do
            for _, action in ipairs(self:GetSelectableMailActions(entry)) do
                if action.actionable and Addon:SelectByDefault(action) then
                    selectable = selectable + 1
                    if panel.selection[action.id] then selectedSelectable = selectedSelectable + 1 end
                end
            end
        end
    end
    panel.selectAll:SetShown(panel.mode == "mail")
    panel.selectAll:SetCheckState(selectable > 0 and selectedSelectable == selectable and "checked"
        or (selectedSelectable > 0 and "partial" or "unchecked"))
    panel.selectAll:SetEnabled(not progress and not Addon.Queue.pending and selectable > 0)
    local coverageText = Addon:T("UI.TEXT_0199") .. tostring(coverage and coverage.currentCount or 0) .. "/" .. tostring(coverage and coverage.totalCount or 0) .. Addon:T("UI.TEXT_0032")
    panel.status:SetText(panel.notice or returnSummary or (progress and (Addon.Queue.message .. " " .. Addon.Queue.completed .. "/" .. #Addon.Queue.actions))
        or (panel.mode == "items" and (Addon:T("UI.TEXT_0588") .. tostring(coverage and coverage.currentCount or 0) .. "/" .. tostring(coverage and coverage.totalCount or 0)) or (Addon:T("UI.TEXT_0255") .. selected)))
    Tooltip(panel.statusHover, Addon:T("UI.TEXT_0342"), panel.status:GetText() .. "\n" .. coverageText)
    self:LayoutInboxFooter()
    panel.collect:SetText(selected > 0 and (Addon:T("UI.TEXT_0346") .. selectedAttachments) or Addon:T("UI.TEXT_0347"))
    panel.collect:SetEnabled(collectCount > 0 and Addon.Queue.state ~= "running" and not Addon.Queue.pending and not self.deleting)
    panel.collect:SetShown(panel.mode == "mail")
    panel.collect:SetState(panel.collect:IsEnabled() and "default" or "disabled")
    self:RefreshMailboxTabs()
    local options = {}
    if panel.mode == "mail" then options[#options + 1] = { value = "select", label = Addon:T("UI.TEXT_0131") } end
    options[#options + 1] = { value = "clear", label = panel.mode == "mail" and Addon:T("UI.TEXT_0443") or Addon:T("UI.TEXT_0444") }
    options[#options + 1] = { value = "pause", label = Addon:T("UI.TEXT_0379") }
    options[#options + 1] = { value = "sort", label = Addon:T("UI.TEXT_0151") }
    if Addon.FEATURES.account then options[#options + 1] = { value = "account", label = Addon:T("UI.TEXT_0568") } end
    panel.menu:SetOptions(options)
    self:RaiseDropdown(panel.menu)
    for index, option in ipairs(options) do
        local enabled = true
        if option.value == "select" or option.value == "clear" then enabled = Addon.Queue.state ~= "running" and not Addon.Queue.pending
        elseif option.value == "pause" then enabled = Addon.Queue.state == "running" end
        local button = panel.menu.menu.buttons[index]
        button:SetEnabled(enabled); button:SetState(enabled and "default" or "disabled")
    end
    self.refreshingInbox = nil
end

function Native:OnCollected(id, action)
    local panel = self.inbox
    if not panel then return end
    panel.selection[id] = nil
    if panel.keepTilesDuringQueue and panel.mode == "mail" then self:RefreshCollectedMailRow(action); return end
    if not panel.keepTilesDuringQueue or not action then return end
    for _, tile in ipairs(panel.tiles or {}) do
        local group, collected
        group = tile.mailGroup
        if group then
            for index = #group.sources, 1, -1 do
                local source = group.sources[index]
                local sameMail = source.entry.character.id == action.characterID
                    and (source.entry.key == action.mailKey or source.entry.mail.signature == action.signature)
                local sameItem = action.slot ~= "money" and source.item and action.item
                    and source.item.attachmentIndex == action.slot
                    and source.item.variantKey == action.item.variantKey
                    and source.item.quantity == action.item.quantity
                local sameMoney = action.slot == "money" and source.money == action.original.money
                if sameMail and (sameItem or sameMoney) then
                    collected = source
                    table.remove(group.sources, index)
                    break
                end
            end
        end
        if collected then
            group.quantity = math.max(0, group.quantity - (tonumber(collected.money or collected.item and collected.item.quantity) or 0))
            tile.eligibleCount = math.max(0, (tile.eligibleCount or 1) - 1)
            tile.count:SetText(group.money and tostring(math.floor(group.quantity / 10000)) or tostring(group.quantity))
            -- The removed source invalidates this hover. Dismiss it instead of
            -- rebuilding the native hyperlink and every hooked tooltip consumer
            -- after each confirmation. A fresh hover reads the updated group.
            if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == tile then
                GameTooltip:Hide()
            end
            return
        end
    end
end
