local Addon = _G.YiboMail
local Native = {}; Addon.NativeUI = Native
local View = Addon.ViewModel
local BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local function Text(parent, font, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    text:SetJustifyH(justify or "LEFT"); return text
end
local function Button(parent, width, label, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24); button:SetText(label); button:SetScript("OnClick", callback); return button
end
local function InboxButton(parent, width, label, callback)
    local button = Addon.Core.UITheme:CreateButton(parent, width, label, "secondary")
    button:SetScript("OnClick", callback); return button
end
local function Surface(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop(BACKDROP); frame:SetBackdropColor(0.025, 0.055, 0.055, 1); frame:SetBackdropBorderColor(0.18, 0.29, 0.27, 1)
    frame:EnableMouse(true); return frame
end
local function Tooltip(control, title, detail, link)
    control:SetScript("OnEnter", function()
        GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
        if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetText(title or ""); if detail then GameTooltip:AddLine(detail, 1, 1, 1, true) end end
        GameTooltip:Show()
    end)
    control:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
local function ContactAddressKey(value)
    return string.lower((tostring(value or "")):gsub("%s", ""))
end
function Native:RememberInboxFilters()
    if not self.inbox or self.applyingPreferences or not Addon:GetInboxPreferences().rememberFilters then return end
    Addon.db.settings.inboxFilters = Addon.Copy(self.inbox.options)
end
function Native:RememberInboxSort()
    if not self.inbox or self.applyingPreferences or not Addon.db or not Addon.db.settings then return end
    local settings = Addon.db.settings.inbox or {}
    Addon.db.settings.inbox = settings
    settings.sort = self.inbox.options.sort == "inbox" and "inbox" or "expiry"
end
function Native:RememberBrowsePage(page)
    if not Addon.db or not Addon.db.settings then return end
    if page == 1 or page == 2 then self.activePage = page end
    if self.restorePagePending or self.restoringPage then return end
    local settings = Addon.db.settings.inbox or {}
    Addon.db.settings.inbox = settings
    settings.page = self.activePage or 1
    if self.inbox and (self.inbox.mode == "mail" or self.inbox.mode == "items") then settings.mode = self.inbox.mode end
end
function Native:RestoreBrowsePage()
    local settings = Addon.db.settings.inbox or {}
    local page = settings.page == 2 and 2 or 1
    self.activePage = page
    self.restoringPage = true
    if type(MailFrameTab_OnClick) == "function" then MailFrameTab_OnClick(nil, page) end
    self.restoringPage = nil
    self.restorePagePending = nil
    self:RememberBrowsePage(page)
end
function Native:ApplyInboxPreferences(deferWhileOpen)
    if not self.readyInbox then return end
    if deferWhileOpen and Addon.Scanner:IsOpen() then return end
    local prefs = Addon:GetInboxPreferences()
    local options = prefs.rememberFilters and Addon.db.settings.inboxFilters or nil
    self.applyingPreferences = true
    self.inbox.mode = prefs.mode
    local savedSort = Addon.db.settings.inbox and Addon.db.settings.inbox.sort
    if savedSort ~= "expiry" and savedSort ~= "inbox" then savedSort = nil end
    self.inbox.options = { search = options and options.search or "", kind = options and options.kind or prefs.kind,
        sort = savedSort or options and options.sort or prefs.sort }
    self.inbox.search:SetText(self.inbox.options.search); self.inbox.filter:SetValue(self.inbox.options.kind)
    self.applyingPreferences = nil
    self:RefreshInbox()
end
function Native:Context()
    local character = Addon.Core.Characters:GetCurrent()
    return { characters = character and { character } or {} }
end
function Native:Dropdown(parent, width, label)
    local dropdown = Addon.Core.UITheme:CreateDropdown(parent, width, {})
    dropdown.menu:SetParent(parent)
    local open = dropdown:GetScript("OnClick")
    dropdown:SetScript("OnClick", function(control)
        open(control)
        Native:RaiseDropdown(control)
    end)
    dropdown:SetText(label); return dropdown
end
function Native:RaiseDropdown(control)
    local parent = control:GetParent()
    control.menu:SetFrameStrata(parent:GetFrameStrata())
    control.menu:SetFrameLevel(parent:GetFrameLevel() + 30)
    for _, button in ipairs(control.menu.buttons) do button:SetFrameLevel(control.menu:GetFrameLevel() + 1) end
end
function Native:SelectInboxActions()
    local selection, count = {}, 0
    local skipped = { preference = 0 }
    for _, entry in ipairs(View:GetMails(self:Context(), self.inbox.options)) do
        local entrySkipped = false
        for _, action in ipairs(Addon:GetInboxActions(entry)) do
            if action.actionable and Addon:SelectByDefault(action) then
                if not selection[action.id] then selection[action.id] = true; count = count + 1 end
            elseif not action.actionable then
                entrySkipped = entry.restriction or "当前邮件暂不可收取"
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
        if queue.state == "running" or queue.pending then panel.notice = "请先暂停队列并等待当前操作结束。"
        elseif value == "select" then
            if queue.state == "paused" then queue:Discard() end
            local count, skipped
            panel.selection, count, skipped = self:SelectInboxActions()
            local details, reasons = {}, {}
            for reason in pairs(skipped) do reasons[#reasons + 1] = reason end
            table.sort(reasons)
            for _, reason in ipairs(reasons) do details[#details + 1] = skipped[reason] .. " 封" .. reason end
            if skipped.preference > 0 then details[#details + 1] = skipped.preference .. " 项被默认收取设置排除" end
            panel.notice = count > 0 and ("已选择 " .. count .. " 项" .. (#details > 0 and ("；跳过：" .. table.concat(details, "、")) or "。"))
                or (#details > 0 and ("没有选中项目；跳过：" .. table.concat(details, "、")) or "当前筛选下没有符合全选范围的可收项目。")
            panel.scroll:SetVerticalScroll(0)
        else
            local ok, err = queue:Discard()
            if ok then panel.selection, panel.notice = {}, "选择与队列已清空。" else panel.notice = err end
        end
    elseif value == "pause" then
        if queue.state == "running" then queue:Pause("玩家已暂停，当前操作仍等待结果。") else panel.notice = "当前没有运行中的收取队列。" end
    elseif value == "sort" then
        panel.options.sort = panel.options.sort == "expiry" and "inbox" or "expiry"
        self:RememberInboxSort()
        panel.scroll:SetVerticalScroll(0); panel.notice = panel.options.sort == "expiry" and "已按临期优先排序。" or "已按邮箱顺序排序。"
    elseif value == "account" and Addon.FEATURES.account then
        if Addon.Core.AccountView:Toggle("mail-inbox") == false then panel.notice = "战斗中无法打开账号邮件视图。" end
    end
    panel.menu:SetValue(nil); panel.menu:SetText("更多")
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
    panel.search.hint = Text(panel.search); panel.search.hint:SetPoint("LEFT", 8, 0); panel.search.hint:SetText("搜索物品、发件人或主题"); panel.search.hint:SetTextColor(unpack(theme.Colors.muted))
    panel.search.hint:SetFont(STANDARD_TEXT_FONT, theme.Font.body, ""); panel.search.hint:SetPoint("RIGHT", -8, 0)
    panel.search:SetScript("OnTextChanged", function(control)
        panel.options.search = control:GetText(); control.hint:SetShown(control:GetText() == ""); Native:RememberInboxFilters(); Native:RefreshInbox()
    end)
    panel.filter = self:Dropdown(panel, 96, "全部邮件"); panel.filter:SetHeight(height); panel.filter:SetPoint("RIGHT", panel.close, "LEFT", -6, 0)
    panel.search:SetPoint("RIGHT", panel.filter, "LEFT", -6, 0)
    panel.filter:SetOptions({ { value = "all", label = "全部邮件" }, { value = "items", label = "含附件" }, { value = "money", label = "含金币" },
        { value = "cod", label = "付款取信" }, { value = "returned", label = "退回邮件" }, { value = "urgent", label = "三天内到期" } })
    panel.filter:SetValue("all"); panel.filter:SetOnValueChanged(function(value) panel.options.kind = value; Native:RememberInboxFilters(); Native:RefreshInbox() end)
    panel.scroll = Addon.Core.UITheme:CreateScrollFrame(panel); panel.scroll:SetPoint("TOPLEFT", 8, -height - 14); panel.scroll:SetPoint("BOTTOMRIGHT", -8, 66)
    panel.scroll:SetFrameLevel(panel:GetFrameLevel() + 2)
    panel.content = CreateFrame("Frame", nil, panel.scroll); panel.content:SetSize(1, 1); panel.scroll:SetScrollChild(panel.content)
    panel.scroll:HookScript("OnSizeChanged", function() Native:RefreshInbox() end)
    panel.selectAll = Addon.Core.UITheme:CreateCheckbox(panel, "")
    panel.selectAll:SetSize(22, 24); panel.selectAll.box:SetSize(18, 18); panel.selectAll.mark:SetSize(18, 18)
    panel.selectAll:SetPoint("BOTTOMLEFT", 8, 40)
    panel.selectAll:SetScript("OnClick", function(control)
        if Addon.Queue.state == "running" or Addon.Queue.pending then return end
        if control:GetCheckState() == "checked" then
            panel.selection, panel.notice = {}, nil
            Native:RefreshInbox()
        else
            Native:InboxMenuAction("select")
        end
    end)
    Tooltip(panel.selectAll, "全选当前可收项目", "勾选后选择当前筛选下默认允许收取的项目；再次点击清空选择。")
    panel.status = Text(panel); panel.status:SetPoint("BOTTOMLEFT", 34, 40); panel.status:SetPoint("BOTTOMRIGHT", -8, 40); panel.status:SetHeight(18)
    panel.statusHover = CreateFrame("Frame", nil, panel); panel.statusHover:SetAllPoints(panel.status); panel.statusHover:EnableMouse(true)
    panel.mail = InboxButton(panel, 52, "邮件", function() panel.mode, panel.notice = "mail", nil; Native:RememberBrowsePage(); panel.scroll:SetVerticalScroll(0); Native:RefreshInbox() end); panel.mail:SetPoint("BOTTOMLEFT", 6, 6)
    panel.items = InboxButton(panel, 52, "附件", function() panel.mode, panel.notice = "items", nil; Native:RememberBrowsePage(); panel.scroll:SetVerticalScroll(0); Native:RefreshInbox() end); panel.items:SetPoint("LEFT", panel.mail, "RIGHT", 2, 0)
    panel.collect = InboxButton(panel, 100, "收取", function() Native:Collect() end); panel.collect:SetPoint("BOTTOMRIGHT", -70, 6)
    panel.menu = self:Dropdown(panel, 58, "更多"); panel.menu:SetPoint("BOTTOMRIGHT", -6, 6)
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
    panel:SetScript("OnHide", function() panel.filter.menu:Hide(); panel.menu.menu:Hide(); Native:SetInboxShell(false) end)
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
    local height = 46
    row.mailOriginalIndex = data.mailOriginalIndex
    row.mailEntryKey = data.mailEntryKey
    row.mailAttachmentSlot = data.mailAttachmentSlot
    row.mailListTop = panel.top
    row.mailIndented = data.indent == true
    row:ClearAllPoints(); row:SetPoint("TOPLEFT", data.indent and 16 or 0, -panel.top); row:SetSize(panel.width - (data.indent and 16 or 0), height)
    row:SetBackdropColor(0, 0, 0, 0); row:SetBackdropBorderColor(0, 0, 0, 0)
    row.title:SetText(data.title or ""); row.detail:SetText(data.detail or ""); row.expiry:SetText(data.expiry or "")
    if data.expiryMail then row.expiry:SetTextColor(View:ExpiryColor(data.expiryMail)) else row.expiry:SetTextColor(0.25, 0.9, 0.35) end
    row.title:SetPoint("TOPRIGHT", data.expiry and -80 or -6, -5)
    row.summary:SetText(data.summary or ""); row.summary:SetShown(data.summary ~= nil)
    if data.wasRead then
        row.title:SetTextColor(0.60, 0.68, 0.68)
        row.detail:SetTextColor(0.65, 0.72, 0.72)
        row.summary:SetTextColor(0.55, 0.63, 0.62)
    else
        row.title:SetTextColor(1, 0.82, 0)
        row.detail:SetTextColor(1, 1, 1)
        row.summary:SetTextColor(0.72, 0.82, 0.79)
    end
    row.detail:SetPoint("TOPRIGHT", data.summary and -86 or -6, -24)
    row.icon:SetTexture(data.texture or "Interface\\Icons\\INV_Letter_15"); row.count:SetText(data.quantity and tostring(data.quantity) or "")
    local actions, eligible, selected = data.actions or {}, 0, 0
    for _, action in ipairs(actions) do if action.actionable then eligible = eligible + 1; panel.available[#panel.available + 1] = action; if panel.selection[action.id] then selected = selected + 1 end end end
    row.check:SetFrameLevel(row:GetFrameLevel() + 2)
    row.delete:SetFrameLevel(row:GetFrameLevel() + 2)
    row.delete:SetShown(data.onDelete ~= nil)
    row.delete:SetEnabled(data.onDelete ~= nil and not self.deleting and Addon.Queue.state ~= "running" and not Addon.Queue.pending)
    row.delete:SetAlpha(row.delete:IsEnabled() and 1 or 0.45)
    row.delete:SetScript("OnClick", data.onDelete)
    Tooltip(row.delete, "删除空邮件")
    row.check:SetShown(#actions > 0); row.check:SetCheckState(selected > 0 and (selected == eligible and "checked" or "partial") or "unchecked")
    row.check:SetEnabled(eligible > 0 and Addon.Queue.state ~= "running" and not Addon.Queue.pending)
    row.check:SetAlpha(row.check:IsEnabled() and 1 or 0.45)
    Tooltip(row.check, "勾选收取项目", Addon.Queue.pending and "当前收取结果仍待核实，请等待邮箱更新。" or (Addon.Queue.state == "running" and "收取队列运行中，请先暂停。" or (eligible == 0 and (data.tooltip or data.detail or "当前项目不可收取。") or "点击勾选／取消勾选；部分选择时点击全选这一行。")))
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
    row:Show(); panel.top = panel.top + height + 2
end
function Native:DeleteEmptyMail(entry)
    if self.deleting or Addon.Queue.state == "running" or Addon.Queue.pending then return end
    local character = Addon.Core.Characters:GetCurrent()
    local mails, err = Addon.Scanner:ReadVisible()
    local index = entry.mail.inboxIndex
    local mail = mails and mails[index]
    if not character or character.id ~= entry.character.id or not mail or mail.signature ~= entry.mail.signature
        or #mail.attachments > 0 or mail.money > 0 or mail.cod > 0 then
        self.inbox.notice = err or "邮件已变化，请等待更新。"; self:RefreshInbox(); return
    end
    if type(InboxItemCanDelete) ~= "function" or not InboxItemCanDelete(index) or type(DeleteInboxItem) ~= "function" then
        self.inbox.notice = "当前邮件无法删除。"; self:RefreshInbox(); return
    end
    self.deleting = true
    self.deleteStartedAt = GetTime()
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
    if Addon.Queue.state == "running" or Addon.Queue.pending then self.inbox.notice = "请先暂停队列并等待当前操作结束。"; self:RefreshInbox(); return end
    local current, err
    if Addon.Scanner.ReadEntry then current, err = Addon.Scanner:ReadEntry(entry)
    else
        local mails; mails, err = Addon.Scanner:ReadVisible()
        current = mails and mails[entry.mail.inboxIndex]
        if current and current.signature ~= entry.mail.signature then current = nil end
    end
    if not current then self.inbox.notice = err or "邮件已变化，请等待更新。"; self:RefreshInbox(); return end
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
    self.inbox.notice = "原生信件界面尚未就绪，请重新打开邮箱。"; self:RefreshInbox()
end
function Native:ReadMail(entry)
    if Addon.Queue.state == "running" or Addon.Queue.pending then
        self.inbox.notice = "请先暂停队列并等待当前操作结束。"; self:RefreshInbox(); return nil
    end
    local current, err
    if Addon.Scanner.ReadEntry then current, err = Addon.Scanner:ReadEntry(entry)
    else
        local mails; mails, err = Addon.Scanner:ReadVisible()
        current = mails and mails[entry.mail.inboxIndex]
        if current and current.signature ~= entry.mail.signature then current = nil end
    end
    if not current then
        self.inbox.notice = err or "邮件已变化，请等待更新。"; self:RefreshInbox(); return nil
    end
    if type(GetInboxText) == "function" then
        local ok, why = pcall(GetInboxText, entry.mail.inboxIndex)
        if not ok then self.inbox.notice = tostring(why); self:RefreshInbox(); return nil end
    end
    if Addon.MarkMailOpened then return Addon:MarkMailOpened(entry) end
    entry.mail.openedByUser = true; return true
end
function Native:CollectCOD(entry, item)
    local ok, current = self:OpenMail(entry, true)
    if not ok then return end
    local matched
    for _, attachment in ipairs(current.attachments) do
        if attachment.attachmentIndex == item.attachmentIndex and attachment.variantKey == item.variantKey and attachment.quantity == item.quantity then matched = attachment end
    end
    if not matched or current.cod <= 0 then
        self.inbox.notice = "附件或付款金额已变化，请等待更新。"; self:RefreshInbox(); return
    end
    if type(OpenMailAttachment_OnClick) ~= "function" then
        self.inbox.notice = "请点击原生信件中的附件完成付款。"; self:RefreshInbox(); return
    end
    OpenMailAttachment_OnClick(_G["OpenMailAttachmentButton" .. item.attachmentIndex] or OpenMailFrame, item.attachmentIndex)
end
function Native:EntryRows(entry)
    local panel, mail = self.inbox, entry.mail
    local expandable = #mail.attachments > 0 or mail.money > 0
    local attachmentSummary = "附件 " .. #mail.attachments .. " 个"
    local parts = {}
    if mail.money > 0 then parts[#parts + 1] = "金币 " .. View:Money(mail.money) end
    if mail.cod > 0 then parts[#parts + 1] = "付款 " .. View:Money(mail.cod) end
    if mail.wasReturned then parts[#parts + 1] = "退回" end
    local extra = table.concat(parts, " · ")
    local subject = View:Escape(mail.subject) .. (extra ~= "" and (" · " .. extra) or "")
    local function ToggleAttachments()
        if not expandable then return end
        panel.expanded[entry.key] = not panel.expanded[entry.key]; Native:RefreshInbox()
    end
    local middleClickHelp = entry.actionable and #mail.attachments > 0 and "\n中键直接收取本封邮件的附件。" or ""
    self:Row({ title = View:Escape(mail.sender), detail = subject, summary = attachmentSummary, wasRead = mail.openedByUser,
        onDelete = #mail.attachments == 0 and mail.money == 0 and mail.cod == 0 and function() Native:DeleteEmptyMail(entry) end or nil,
        texture = mail.attachments[1] and mail.attachments[1].texture, quantity = #mail.attachments == 1 and mail.attachments[1].quantity or nil,
        mailOriginalIndex = mail.inboxIndex, mailEntryKey = entry.key,
        expiry = View:Expiry(mail), expiryMail = mail, actions = Addon:GetInboxActions(entry), tooltip = subject .. "\n" .. attachmentSummary .. "\n到期：" .. View:Expiry(mail) .. "\n左键展开／收起附件；右键打开／关闭原生信件。" .. middleClickHelp .. (not entry.actionable and ("\n" .. entry.restriction) or ""),
        onClick = function(_, mouse)
            if mouse == "MiddleButton" then Native:CollectMailAttachments(entry)
            elseif mouse == "RightButton" or not expandable then Native:OpenMail(entry)
            elseif panel.expanded[entry.key] then ToggleAttachments()
            elseif Native:ReadMail(entry) then ToggleAttachments() end
        end })
    panel.rows[panel.used]:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    if panel.expanded[entry.key] then
        for _, item in ipairs(mail.attachments) do
            self:Row({ title = item.itemLink or View:Escape(item.name), detail = "附件槽 " .. item.attachmentIndex .. " · " .. (mail.cod > 0 and ("付款 " .. View:Money(mail.cod)) or (entry.actionable and "可收取" or entry.restriction)),
                mailOriginalIndex = mail.inboxIndex, mailEntryKey = entry.key, mailAttachmentSlot = item.attachmentIndex,
                texture = item.texture, quantity = item.quantity, expiry = View:Expiry(mail), expiryMail = mail, indent = true, itemLink = item.itemLink, actions = Addon:GetInboxActions(entry, item),
                onClick = function(_, mouse)
                    if mouse == "RightButton" then Native:OpenMail(entry)
                    elseif mail.cod > 0 then Native:CollectCOD(entry, item) end
                end })
            panel.rows[panel.used]:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        end
        if mail.money > 0 then
            local actions = {}; for _, action in ipairs(Addon:GetInboxActions(entry)) do if action.slot == "money" then actions[1] = action end end
            self:Row({ title = "金币 " .. View:Money(mail.money), detail = "来自：" .. View:Escape(mail.sender), mailOriginalIndex = mail.inboxIndex,
                mailEntryKey = entry.key, mailAttachmentSlot = "money", indent = true,
                texture = "Interface\\Icons\\INV_Misc_Coin_01", actions = actions })
        end
    end
end
function Native:Collect()
    local panel, queue = self.inbox, Addon.Queue; panel.notice = nil
    if queue.state == "running" or queue.pending then panel.notice = "请等待当前收取操作结束。"; self:RefreshInbox(); return end
    local actions, err = queue:Prepare(panel.selection, self:Context())
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
        panel.notice = "请等待当前收取操作结束。"; self:RefreshInbox(); return
    end
    local selection = {}
    for _, item in ipairs(entry.mail.attachments or {}) do
        for _, action in ipairs(Addon:GetInboxActions(entry, item)) do
            if action.actionable then selection[action.id] = true end
        end
    end
    if not next(selection) then
        panel.notice = entry.mail.cod > 0 and "付款取信请使用原生邮箱。" or "这封邮件没有可直接收取的附件。"
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
        return (tonumber(a.item.attachmentIndex) or math.huge) < (tonumber(b.item.attachmentIndex) or math.huge)
    end)
    for _, source in ipairs(sources) do
        for _, action in ipairs(Addon:GetInboxActions(source.entry, source.item)) do
            if action.actionable then
                selection[action.id] = true
                if single then break end
            end
        end
        if single and next(selection) then break end
    end
    if single and not next(selection) then panel.notice = "该物品组中没有可单独收取的附件。"; self:RefreshInbox(); return end
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
local function ItemBorder(item)
    local name, link, quality
    if type(GetItemInfo) == "function" then name, link, quality = GetItemInfo(item.itemLink or item.itemID) end
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then return { color.r, color.g, color.b, 1 }, not name end
    if type(item.itemLink) == "string" then
        local red, green, blue = item.itemLink:match("^|c[fF][fF](%x%x)(%x%x)(%x%x)|H")
        if red then return { tonumber(red, 16) / 255, tonumber(green, 16) / 255, tonumber(blue, 16) / 255, 1 }, not name end
    end
    return { 0.55, 0.6, 0.58, 1 }, not name
end
function Native:ItemTile(group, index, columns)
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
    tile:ClearAllPoints(); tile:SetPoint("TOPLEFT", ((index - 1) % columns) * 46 + 4, -math.floor((index - 1) / columns) * 46 - 4)
    tile.icon:SetTexture(group.item.texture or "Interface\\Icons\\INV_Misc_QuestionMark"); tile.count:SetText(tostring(group.quantity))
    local eligible, codSource = 0, nil
    for _, source in ipairs(group.sources) do
        if not codSource and source.entry.mail.cod > 0 then codSource = source end
        for _, action in ipairs(Addon:GetInboxActions(source.entry, source.item)) do
            if action.actionable then
                eligible = eligible + 1
            end
        end
    end
    tile:SetBackdropColor(0, 0, 0, 0)
    local borderColor, needsItemInfo = ItemBorder(group.item)
    local soonest = group.expiresAtEstimate and (group.expiresAtEstimate - Addon:Now()) or math.huge
    if soonest <= 3 * 86400 then
        borderColor = soonest <= 86400 and { 1, 0.22, 0.16, 1 } or { 1, 0.68, 0.12, 1 }
    end
    tile:SetBackdropBorderColor(unpack(borderColor))
    if needsItemInfo and group.item.itemID and C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        self.pendingItemInfo = self.pendingItemInfo or {}
        if not self.pendingItemInfo[group.item.itemID] then
            self.pendingItemInfo[group.item.itemID] = true
            C_Item.RequestLoadItemDataByID(group.item.itemID)
        end
    end
    tile.icon:SetDesaturated(eligible == 0 and not codSource)
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
        local itemLink = group.item.itemLink
        if itemLink and itemLink ~= "" then
            GameTooltip:SetHyperlink(itemLink)
        elseif group.item.itemID then
            -- The inbox API can provide an item ID before it provides a full
            -- hyperlink. An item hyperlink still lets Blizzard build its
            -- normal item tooltip from that ID.
            GameTooltip:SetHyperlink("item:" .. tostring(group.item.itemID))
        end
        if GameTooltip:NumLines() == 0 then GameTooltip:SetText(group.item.name or "附件") end
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
        GameTooltip:AddLine("合计 " .. group.quantity .. " 件 · 来自 " .. mailCount .. " 封邮件", 1, 1, 1)
        for _, source in ipairs(orderedSources) do
            local mail = source.mail
            local red, green, blue = View:ExpiryColor(mail)
            local sender = mail.sender and mail.sender ~= "" and (mail.sender .. " · ") or ""
            local itemName = source.item.name
            if not itemName or itemName == "" then itemName = (source.item.itemLink or ""):match("%[(.-)%]") or group.item.name or "附件" end
            local line = sender .. itemName .. "（" .. source.quantity .. "）×" .. source.slots .. "件"
            line = line .. " · " .. View:Expiry(mail)
            GameTooltip:AddLine(View:Escape(line), red, green, blue, false)
        end
        if (control.eligibleCount or eligible) > 0 then GameTooltip:AddLine("Alt+左键：只收最早到期邮件中的一个附件", 0.25, 0.9, 0.75, true) end
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
        local state = queue.pending.success or queue.pending.updated and "正在核对" or "正在收取"
        if type(state) == "boolean" then state = "正在核对" end
        progress = state .. " " .. tostring(queue.completed + 1) .. "/" .. #queue.actions
    else
        progress = queue.message .. " " .. queue.completed .. "/" .. #queue.actions
    end
    panel.status:SetText(progress)
    Tooltip(panel.statusHover, "收件状态", progress)
    panel.collect:SetEnabled(false)
    panel.collect:SetState("disabled")
    panel.mail:SetEnabled(false)
    panel.items:SetEnabled(false)
end
function Native:RefreshCollectedMailRow(action)
    local panel = self.inbox
    if not panel or panel.mode ~= "mail" or not action or not action.original then return end
    local originalIndex = action.original.inboxIndex
    local mainRow
    for _, row in ipairs(panel.rows) do
        if row:IsShown() and row.mailOriginalIndex == originalIndex then
            if row.mailAttachmentSlot == action.slot then
                row.detail:SetText(action.slot == "money" and "金币 · 已收取" or ("附件槽 " .. tostring(action.slot) .. " · 已收取"))
                row.check:SetShown(false)
            elseif row.mailAttachmentSlot == nil then
                mainRow = row
            end
        end
    end
    if action.mailCollected then
        local firstTop, removedRows
        removedRows = 0
        for _, row in ipairs(panel.rows) do
            if row:IsShown() and row.mailOriginalIndex == originalIndex then
                firstTop = firstTop and math.min(firstTop, row.mailListTop or 0) or (row.mailListTop or 0)
                removedRows = removedRows + 1
                row:Hide()
            end
        end
        if removedRows > 0 then
            local shift = removedRows * 48
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
        entry = { character = Addon.Core.Characters:GetCurrent(), key = action.resultMailKey, mail = mail,
            actionable = mail.cod == 0 and mail.state == "observed" }
        local extra = {}
        if mail.money > 0 then extra[#extra + 1] = "金币 " .. View:Money(mail.money) end
        if mail.cod > 0 then extra[#extra + 1] = "付款 " .. View:Money(mail.cod) end
        if mail.wasReturned then extra[#extra + 1] = "退回" end
        mainRow.detail:SetText(View:Escape(mail.subject) .. (#extra > 0 and (" · " .. table.concat(extra, " · ")) or ""))
        mainRow.summary:SetText("附件 " .. #mail.attachments .. " 个")
        mainRow.icon:SetTexture(mail.attachments[1] and mail.attachments[1].texture or "Interface\\Icons\\INV_Letter_15")
        mainRow.count:SetText(#mail.attachments == 1 and tostring(mail.attachments[1].quantity) or "")
        mainRow.expiry:SetText(View:Expiry(mail)); mainRow.expiry:SetTextColor(View:ExpiryColor(mail))
        local attachments = {}; for _, item in ipairs(mail.attachments) do attachments[#attachments + 1] = View:Escape(item.name or item.itemLink or "附件") end
        Tooltip(mainRow, View:Escape(mail.sender), View:Escape(mail.subject) .. "\n"
            .. (#attachments > 0 and table.concat(attachments, "、") or "没有剩余附件"))
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
        mainRow.detail:SetText("本批已收取")
        mainRow.summary:SetText("已收取")
        mainRow.count:SetText("")
        mainRow.check:SetShown(false)
        mainRow:SetBackdropColor(0.025, 0.055, 0.055, 1)
    end
end
function Native:RefreshInbox()
    local panel = self.inbox; if not self.readyInbox or not panel:IsShown() or self.refreshingInbox then return end
    if Addon.Queue.state == "running" and panel.keepTilesDuringQueue then
        self:RefreshInboxProgress()
        return
    end
    if Addon.Queue.state ~= "running" then panel.keepTilesDuringQueue = nil end
    self.refreshingInbox = true
    panel.used, panel.top, panel.available, panel.width = 0, 0, {}, math.max(1, panel.scroll:GetWidth())
    for _, tile in ipairs(panel.tiles or {}) do tile:Hide() end
    local context = self:Context()
    local allMails = View:GetMails(context, { sort = panel.options.sort })
    if panel.mode == "mail" then
        local visibleMails = panel.options.search == "" and (panel.options.kind == nil or panel.options.kind == "all")
            and panel.options.sort == "expiry" and allMails or View:GetMails(context, panel.options)
        for _, entry in ipairs(visibleMails) do self:EntryRows(entry) end
    else
        local groups = {}
        if panel.options.search == "" and (panel.options.kind == nil or panel.options.kind == "all") then
            local byIdentity = {}
            for _, entry in ipairs(allMails) do
                for _, item in ipairs(entry.mail.attachments) do
                    local group = byIdentity[item.variantKey]
                    if not group then
                        group = { id = item.variantKey, item = item, quantity = 0, sources = {}, expiresAtEstimate = entry.mail.expiresAtEstimate }
                        byIdentity[item.variantKey] = group; groups[#groups + 1] = group
                    end
                    group.quantity = group.quantity + item.quantity
                    group.expiresAtEstimate = math.min(group.expiresAtEstimate, entry.mail.expiresAtEstimate)
                    group.sources[#group.sources + 1] = { entry = entry, item = item }
                end
            end
            if panel.options.sort ~= "inbox" then
                table.sort(groups, function(a, b) if a.expiresAtEstimate ~= b.expiresAtEstimate then return a.expiresAtEstimate < b.expiresAtEstimate end; return a.id < b.id end)
            end
        else
            groups = View:GetGroups(context, panel.options)
        end
        -- Reserve the possible gutter before wrapping so overflow cannot clip
        -- the last tile when Core resolves the scrollbar on the next frame.
        local columns = math.max(1, math.floor((panel:GetWidth() - 16 - Addon.Core.UITheme.Geometry.scrollbarGutter - 8) / 46))
        for index, group in ipairs(groups) do self:ItemTile(group, index, columns) end
        panel.top = #groups > 0 and math.ceil(#groups / columns) * 46 + 8 or 0
    end
    if panel.top == 0 then self:Row({ title = panel.mode == "items" and "暂无匹配附件" or "暂无匹配邮件", detail = Addon.Scanner.updated and "可清除搜索和筛选。" or "等待原生邮箱列表更新。" }) end
    for index = panel.used + 1, #panel.rows do panel.rows[index]:Hide() end
    panel.content:SetSize(panel.width, math.max(1, panel.top)); panel.scroll:SetContentHeight(panel.top)
    local selected = 0; for _ in pairs(panel.selection) do selected = selected + 1 end
    local selectedAttachments, counted = 0, {}
    for _, entry in ipairs(allMails) do
        for _, item in ipairs(entry.mail.attachments) do
            local id = View:ActionID(entry.character.id, entry.key, item.attachmentIndex)
            if panel.selection[id] and not counted[id] then counted[id] = true; selectedAttachments = selectedAttachments + 1 end
        end
    end
    local character = context.characters[1]; local coverage = character and Addon.Items:GetState(character.id)
    local progress = Addon.Queue.state == "running" or Addon.Queue.state == "paused"
    local selectable, selectedSelectable = 0, 0
    if panel.mode == "mail" then
        for _, entry in ipairs(View:GetMails(context, panel.options)) do
            for _, action in ipairs(Addon:GetInboxActions(entry)) do
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
    local coverageText = "可见 " .. tostring(coverage and coverage.currentCount or 0) .. "/" .. tostring(coverage and coverage.totalCount or 0) .. " 封"
    panel.status:SetText(panel.notice or (progress and (Addon.Queue.message .. " " .. Addon.Queue.completed .. "/" .. #Addon.Queue.actions))
        or (panel.mode == "items" and coverageText or ("已选 " .. selected .. " 项 · " .. coverageText)))
    Tooltip(panel.statusHover, "收件状态", panel.status:GetText())
    panel.collect:SetText(selected > 0 and ("收取（" .. selectedAttachments .. "）") or "收取")
    panel.collect:SetEnabled(selected > 0 and Addon.Queue.state ~= "running" and not Addon.Queue.pending)
    panel.collect:SetShown(panel.mode == "mail")
    panel.mail:SetEnabled(true); panel.items:SetEnabled(true)
    panel.collect:SetState(panel.collect:IsEnabled() and "default" or "disabled")
    panel.mail:SetText("邮件"); panel.items:SetText("附件")
    panel.mail:SetState(panel.mode == "mail" and "selected" or "default")
    panel.items:SetState(panel.mode == "items" and "selected" or "default")
    local options = {}
    if panel.mode == "mail" then options[#options + 1] = { value = "select", label = "全选当前可收项目" } end
    options[#options + 1] = { value = "clear", label = panel.mode == "mail" and "清空选择" or "清空队列" }
    options[#options + 1] = { value = "pause", label = "暂停队列" }
    options[#options + 1] = { value = "sort", label = "切换临期／邮箱排序" }
    if Addon.FEATURES.account then options[#options + 1] = { value = "account", label = "账号邮件视图" } end
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
function Native:CreateSend()
    local panel = CreateFrame("Frame", nil, SendMailFrame); self.send = panel
    panel:SetAllPoints(SendMailFrame); panel:SetFrameLevel(SendMailFrame:GetFrameLevel() + 8)
    panel.contacts = self:Dropdown(panel, 116, "常用联系人"); panel.contacts:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", 8, 0)
    panel.contacts:SetOnValueChanged(function(value)
        if value == "__next" or value == "__prev" then panel.contactPage = (panel.contactPage or 1) + (value == "__next" and 1 or -1)
        elseif value == "__settings" then Addon.Core.AccountView:ShowSettings("mail-inbox")
        elseif value == "__save" then local ok, err = View:SaveContact(SendMailNameEditBox:GetText(), SendMailNameEditBox:GetText()); panel.notice = ok and "联系人已收藏。" or err
        else SendMailNameEditBox:SetText(value) end
        Native:RefreshSend()
    end)
    panel.bar = Surface(panel); panel.bar:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", 16, 36); panel.bar:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -28, 36); panel.bar:SetHeight(56)
    panel.suggestions = self:Dropdown(panel.bar, 290, "规则匹配"); panel.suggestions:SetPoint("TOPLEFT", 3, -2); panel.suggestions:SetPoint("TOPRIGHT", -3, -2)
    panel.suggestions:SetOnValueChanged(function(value)
        if value == "__next" or value == "__prev" then panel.rulePage = (panel.rulePage or 1) + (value == "__next" and 1 or -1); panel.selected = nil
        elseif value == "__reset" then panel.skipped, panel.selected = {}, nil
        else panel.selected = value end
        Native:RefreshSend()
    end)
    panel.preview = Button(panel.bar, 90, "预览装填", function() Native:PreviewFill() end); panel.preview:SetPoint("BOTTOMLEFT", 3, 2)
    panel.next = Button(panel.bar, 80, "装填下一格", function() local ok, err = Addon.Compose:FillNext(); panel.notice = ok and "已装填，请继续核对原生发件箱。" or err; Native:RefreshSend() end); panel.next:SetPoint("LEFT", panel.preview, "RIGHT", 2, 0)
    panel.undo = Button(panel.bar, 54, "撤销", function() local ok, err = Addon.Compose:UndoFill(); panel.notice = ok and "本次装填已撤销。" or err; Native:RefreshSend() end); panel.undo:SetPoint("LEFT", panel.next, "RIGHT", 2, 0)
    panel.skip = Button(panel.bar, 44, "跳过", function()
        local suggestion = panel.matches and panel.matches[panel.selected]; panel.skipped = panel.skipped or {}; if suggestion then panel.skipped[suggestion.itemID] = true end
        panel.selected = nil; Native:RefreshSend()
    end); panel.skip:SetPoint("LEFT", panel.undo, "RIGHT", 2, 0)
    panel.noticeText = Text(panel); panel.noticeText:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", 16, 14); panel.noticeText:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -200, 14); panel.noticeText:SetHeight(18)
    Tooltip(panel.preview, "预览本封规则装填", "核对收件人、物品和数量后逐格装填，最后手动点击原生发送。")
    self.fillPreview = Surface(SendMailFrame); local preview = self.fillPreview
    preview:SetFrameLevel(panel:GetFrameLevel() + 20); preview:SetPoint("TOPLEFT", MailFrame, "TOPLEFT", 16, -82); preview:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -28, 104)
    preview.title = Text(preview, "GameFontNormal"); preview.title:SetPoint("TOPLEFT", 8, -8); preview.title:SetPoint("TOPRIGHT", -8, -8); preview.title:SetHeight(34)
    preview.scroll = Addon.Core.UITheme:CreateScrollFrame(preview); preview.scroll:SetPoint("TOPLEFT", 8, -48); preview.scroll:SetPoint("BOTTOMRIGHT", -8, 44)
    preview.content = CreateFrame("Frame", nil, preview.scroll); preview.content:SetSize(1, 1); preview.scroll:SetScrollChild(preview.content)
    preview.items = Text(preview.content); preview.items:SetPoint("TOPLEFT", 0, 0); preview.items:SetPoint("TOPRIGHT", 0, 0)
    preview.accept = Button(preview, 160, "确认并装填第 1 格", function()
        preview:Hide(); local ok, err = Addon.Compose:FillNext(); panel.notice = ok and "首格已装填，继续点击装填下一格。" or err; Native:RefreshSend()
    end); preview.accept:SetPoint("BOTTOMRIGHT", -8, 8)
    preview.cancel = Button(preview, 70, "取消", function() preview:Hide(); Addon.Compose.fill = nil; Native:RefreshSend() end); preview.cancel:SetPoint("BOTTOMLEFT", 8, 8)
    preview:Hide()
    panel:SetScript("OnShow", function() Native:RefreshSend() end)
    panel:SetScript("OnHide", function() panel.contacts.menu:Hide(); panel.suggestions.menu:Hide(); preview:Hide() end)
    self.readySend = true
end
function Native:CreateBasicSend()
    local panel = CreateFrame("Frame", nil, SendMailFrame); self.send = panel
    panel:SetAllPoints(SendMailFrame); panel:SetFrameLevel(SendMailFrame:GetFrameLevel() + 1)
    local theme = Addon.Core.UITheme
    panel.shell = CreateFrame("Frame", nil, MailFrame, "BackdropTemplate")
    panel.shell:SetAllPoints(MailFrame); panel.shell:SetFrameLevel(MailFrame:GetFrameLevel() + 1)
    panel.shell:SetBackdrop(BACKDROP); panel.shell:SetBackdropColor(unpack(theme.Colors.bg)); panel.shell:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
    local function CreateSendField(label)
        local field = Surface(panel)
        field.label = theme:CreateText(field, theme.Font.body, theme.Colors.muted, "LEFT")
        field.label:SetPoint("LEFT", 8, 0); field.label:SetWidth(58); field.label:SetHeight(theme.Size.standard)
        field.label:SetText(label)
        return field
    end
    panel.recipientField = CreateSendField("收件人")
    panel.subjectField = CreateSendField("主题")
    panel.close = InboxButton(panel, 22, "x", function() if HideUIPanel then HideUIPanel(MailFrame) else MailFrame:Hide() end end)
    panel.close:SetSize(theme.Size.standard, theme.Size.standard); panel.close:SetPoint("TOPRIGHT", MailFrame, "TOPRIGHT", -8, -6)
    panel.contactPage, panel.serverPage = 1, 1
    panel.contacts = self:Dropdown(panel, theme.Size.standard, "")
    panel.contacts:SetSize(theme.Size.standard, theme.Size.standard)
    panel.contacts:SetPoint("TOPRIGHT", panel.close, "TOPLEFT", -6, 0)
    panel.favoritesExpanded = true
    panel.favoritesPanel = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.favoritesPanel:SetFrameLevel(panel:GetFrameLevel() + 2)
    panel.favoritesPanel:SetBackdrop(BACKDROP)
    panel.favoritesPanel:SetBackdropColor(unpack(theme.Colors.bg))
    panel.favoritesPanel:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
    panel.favoritesPanel:EnableMouse(true)
    panel.favoriteButtons = {}
    for index = 1, 16 do
        local button = CreateFrame("Button", nil, panel.favoritesPanel, "BackdropTemplate")
        button:SetBackdrop(BACKDROP)
        button:SetBackdropColor(unpack(theme.Colors.panel))
        button:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 3, -3); button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        button.emptyMark = theme:CreateText(button, theme.Font.title, theme.Colors.muted, "CENTER")
        button.emptyMark:SetAllPoints(); button.emptyMark:SetText("+")
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button.slot = index
        button:SetScript("OnClick", function(control, mouseButton)
            if mouseButton == "RightButton" then Addon.RecipientUI:Open(control, control.slot); return end
            local contact = control.contact
            if not contact then return end
            if not SendMailNameEditBox then return end
            SendMailNameEditBox:SetText(contact.address)
            local hasText = (SendMailSubjectEditBox and SendMailSubjectEditBox:GetText() or ""):match("%S")
                or (SendMailBodyEditBox and SendMailBodyEditBox:GetText() or ""):match("%S")
            local hasAttachments = Addon.Compose and #Addon.Compose:GetAttachments() > 0
            if hasText and hasAttachments then
                local sendButton = _G.SendMailMailButton or _G.SendMailSendButton
                if not sendButton then Addon:Print("原生发送按钮不可用，请检查发件箱。"); return end
                -- Recompute the native button state after changing the recipient, then
                -- run its Blizzard click handler directly. Button:Click() ignores a
                -- disabled button, which made the first favorite click only fill the
                -- recipient and required a second click to send.
                if type(_G.SendMailFrame_Update) == "function" then _G.SendMailFrame_Update() end
                local onClick = sendButton:GetScript("OnClick")
                if type(onClick) == "function" then
                    onClick(sendButton, "LeftButton")
                else
                    sendButton:Click("LeftButton")
                end
            end
        end)
        button:SetScript("OnEnter", function(control)
            control:SetBackdropBorderColor(unpack(theme.Colors.accent))
            local contact = control.contact
            GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
            if not contact then
                GameTooltip:SetText("配置快捷收件人")
                GameTooltip:AddLine("右键添加快捷收件人。", 0.8, 0.85, 0.83, true)
                GameTooltip:Show(); return
            end
            GameTooltip:SetText(Addon.Recipients:Label(contact))
            GameTooltip:AddLine(Addon.Recipients:Escape(contact.address), 0.8, 0.85, 0.83, true)
            GameTooltip:AddLine("有邮件文本和附件时点击发送；否则填入收件人。", 0.55, 0.78, 0.78, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function(control)
            control:SetBackdropBorderColor(unpack(theme.Colors.lineSoft)); GameTooltip:Hide()
        end)
        panel.favoriteButtons[index] = button
    end
    panel.favoriteToggle = InboxButton(panel, theme.Size.standard, "<", function()
        panel.favoritesExpanded = not panel.favoritesExpanded
        panel.favoritesPanel:SetShown(panel.favoritesExpanded)
        panel.favoriteToggle:SetText(panel.favoritesExpanded and "<" or ">")
        Tooltip(panel.favoriteToggle, panel.favoritesExpanded and "收起快捷寄件栏" or "展开快捷寄件栏")
    end)
    panel.favoriteToggle:SetSize(theme.Size.standard, theme.Size.standard)
    panel.favoriteToggle:SetPoint("LEFT", panel.contacts, "RIGHT", 6, 0)
    Tooltip(panel.favoriteToggle, "收起快捷寄件栏")
    panel.favoriteEntries = {}
    panel.contacts:SetScript("OnClick", function(control)
        local picker = Addon.RecipientUI
        if picker.popup and picker.popup:IsShown() and picker.anchor == control then picker:Hide()
        else picker:Open(control) end
    end)
    Tooltip(panel.contacts, "收件人通讯录", "搜索、筛选并选择收件人；常用名单与快捷寄件栏分别保存。")
    if SendMailNameEditBox then SendMailNameEditBox:HookScript("OnTextChanged", function() Addon.RecipientUI.confirm = nil; Addon.RecipientUI:Refresh() end) end
    panel.balance = theme:CreateText(panel, theme.Font.body, theme.Colors.text, "LEFT")
    panel.balance:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", 14, 8)
    panel.balance:SetSize(148, theme.Size.standard)
    panel.moneyEvents = CreateFrame("Frame", nil, panel)
    panel.moneyEvents:RegisterEvent("PLAYER_MONEY")
    panel.moneyEvents:SetScript("OnEvent", function() Native:RefreshSendBalance() end)
    panel:SetScript("OnShow", function() Native:LayoutBasicSend(); Native:RefreshSend() end)
    panel:SetScript("OnHide", function() panel.contacts.menu:Hide(); Addon.RecipientUI:Hide(); if Native.favoriteEditor then Native.favoriteEditor:Hide() end; panel.shell:Hide(); panel.favoritesPanel:Hide() end)
    panel.favoritesPanel:SetScript("OnSizeChanged", function() Native:LayoutFavoriteButtons() end)
    MailFrame:HookScript("OnSizeChanged", function() Addon.RecipientUI:Refresh() end)
    MailFrame:HookScript("OnDragStop", function() Addon.RecipientUI:Refresh() end)
    self.readySend = true
end
function Native:LayoutFavoriteButtons()
    local panel = self.send
    local favorites = panel and panel.favoritesPanel
    if not favorites then return end
    local width, height = favorites:GetWidth(), favorites:GetHeight()
    if width <= 0 or height <= 0 then return end
    local gapX, gapY, paddingX, paddingY = 6, 4, 6, 6
    local size = math.max(1, math.min(math.floor((width - paddingX * 2 - gapX) / 2), math.floor((height - paddingY * 2 - gapY * 7) / 8)))
    local totalWidth, totalHeight = size * 2 + gapX, size * 8 + gapY * 7
    local left, top = math.floor((width - totalWidth) / 2), math.floor((height - totalHeight) / 2)
    for index, button in ipairs(panel.favoriteButtons) do
        local row, column = math.floor((index - 1) / 2), (index - 1) % 2
        button:ClearAllPoints(); button:SetSize(size, size)
        button:SetPoint("TOPLEFT", favorites, "TOPLEFT", left + column * (size + gapX), -(top + row * (size + gapY)))
    end
end
function Native:PromptAddFavorite(prefill, slot)
    local editor = self.favoriteEditor
    if not editor then
        local theme = Addon.Core.UITheme
        editor = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        editor:SetSize(344, 156); editor:SetPoint("CENTER")
        editor:SetFrameStrata("DIALOG"); editor:SetFrameLevel(1000)
        editor:SetClampedToScreen(true); editor:EnableMouse(true); editor:SetToplevel(true)
        editor:SetBackdrop(BACKDROP); editor:SetBackdropColor(unpack(theme.Colors.bg)); editor:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
        editor.title = theme:CreateText(editor, theme.Font.section, theme.Colors.text, "LEFT")
        editor.title:SetPoint("TOPLEFT", 14, -12); editor.title:SetText("配置快捷收件人")
        editor.address = CreateFrame("EditBox", nil, editor, "BackdropTemplate")
        editor.address:SetPoint("TOPLEFT", 14, -42); editor.address:SetSize(316, theme.Size.standard)
        editor.address:SetAutoFocus(false); editor.address:SetMaxLetters(160)
        editor.address:SetFont(STANDARD_TEXT_FONT, theme.Font.body, "OUTLINE"); editor.address:SetTextColor(unpack(theme.Colors.text))
        editor.address:SetTextInsets(8, 8, 0, 0); editor.address:SetBackdrop(BACKDROP)
        editor.address:SetBackdropColor(unpack(theme.Colors.panel)); editor.address:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
        editor.status = theme:CreateText(editor, theme.Font.assist, theme.Colors.muted, "LEFT")
        editor.status:SetPoint("TOPLEFT", editor.address, "BOTTOMLEFT", 0, -5); editor.status:SetPoint("RIGHT", editor, "RIGHT", -14, 0); editor.status:SetHeight(20)
        editor.cancel = InboxButton(editor, 76, "取消", function() editor:Hide() end)
        editor.cancel:SetPoint("BOTTOMRIGHT", -14, 10)
        editor.save = InboxButton(editor, 76, "保存", function() Native:SaveFavoriteFromEditor() end)
        editor.save:SetPoint("RIGHT", editor.cancel, "LEFT", -6, 0)
        editor.address:SetScript("OnEnterPressed", function() Native:SaveFavoriteFromEditor() end)
        editor.address:SetScript("OnEscapePressed", function()
            if editor.address.IsInIMEComposition and editor.address:IsInIMEComposition() then return end
            editor.address:ClearFocus(); editor:Hide()
        end)
        editor:SetScript("OnShow", function()
            editor.address:SetFocus(); editor.address:HighlightText()
        end)
        editor:SetScript("OnHide", function() editor.address:ClearFocus() end)
        self.favoriteEditor = editor
    end
    editor.slot = slot
    editor.title:SetText("配置快捷收件人 · 第 " .. tostring(slot) .. " 格")
    editor.address:SetText(prefill or ""); editor.status:SetText(""); editor:Show()
end
function Native:SaveFavoriteFromEditor()
    local editor = self.favoriteEditor
    if not editor then return end
    local address = editor.address:GetText()
    if editor.address.IsInIMEComposition and editor.address:IsInIMEComposition() then return end
    local ok, err = Addon.Recipients:SetShortcut(editor.slot, address)
    if not ok then editor.status:SetText(err or "保存失败，请检查联系人地址。"); editor.address:SetFocus(); editor.address:HighlightText(); return end
    Addon:Print("快捷格已保存。")
    editor:Hide()
    self:RefreshBasicSend()
end
function Native:RefreshFavoriteButtons()
    local panel = self.send
    if not panel or not panel.favoriteButtons then return end
    local roster, byAddress = Addon.Core.Characters:GetAllCached(), {}
    for _, character in ipairs(roster) do
        local address = character.name .. "-" .. character.realm
        byAddress[ContactAddressKey(address)] = character
    end
    panel.favoriteEntries = {}
    for index = 1, 16 do
        local saved = Addon.db.quickRecipients and Addon.db.quickRecipients[index]
        local address = saved and Addon.Recipients:Normalize(saved.address)
        if address then
            local character = byAddress[ContactAddressKey(address)]
            panel.favoriteEntries[index] = { address = address, label = saved.label, class = character and character.class }
        end
    end
    for index, button in ipairs(panel.favoriteButtons) do
        local contact = panel.favoriteEntries[index]
        button.contact = contact
        button:SetShown(panel.favoritesExpanded)
        button.emptyMark:SetShown(contact == nil)
        if contact then
            local coords = contact.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[contact.class]
            if coords then
                button.icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
                button.icon:SetTexCoord(unpack(coords))
            else
                button.icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
                button.icon:SetTexCoord(0, 1, 0, 1)
            end
        else
            button.icon:SetTexture(nil)
        end
    end
    self:LayoutFavoriteButtons()
end
function Native:LayoutBasicSend()
    local panel = self.send
    if not panel or Addon.FEATURES.sendAssist or not MailFrame or not SendMailNameEditBox then return end
    local theme = Addon.Core.UITheme
    local frameWidth = MailFrame:GetWidth()
    local fieldWidth = math.max(170, frameWidth - 124)
    panel.recipientField:ClearAllPoints(); panel.recipientField:SetPoint("TOPLEFT", MailFrame, "TOPLEFT", 16, -6); panel.recipientField:SetSize(fieldWidth, theme.Size.standard)
    panel.subjectField:ClearAllPoints(); panel.subjectField:SetPoint("TOPLEFT", panel.recipientField, "BOTTOMLEFT", 0, -4); panel.subjectField:SetSize(fieldWidth, theme.Size.standard)
    local function StyleInput(editBox, field)
        if not editBox then return end
        editBox:ClearAllPoints(); editBox:SetPoint("LEFT", field, "LEFT", 74, 0); editBox:SetWidth(math.max(80, fieldWidth - 80))
        editBox:SetFont(STANDARD_TEXT_FONT, theme.Font.body, "OUTLINE"); editBox:SetTextColor(unpack(theme.Colors.text))
        for _, region in ipairs({ editBox:GetRegions() }) do
            if type(region.GetObjectType) == "function" then
                local objectType = region:GetObjectType()
                local name = type(region.GetName) == "function" and region:GetName() or nil
                local nativeBackground = name == "SendMailNameEditBoxLeft" or name == "SendMailNameEditBoxMiddle" or name == "SendMailNameEditBoxRight"
                    or name == "SendMailSubjectEditBoxLeft" or name == "SendMailSubjectEditBoxMiddle" or name == "SendMailSubjectEditBoxRight"
                if objectType == "Texture" and nativeBackground then region:SetAlpha(0)
                elseif objectType == "FontString" then
                    local text = region:GetText()
                    if text and ((type(MAIL_TO_LABEL) == "string" and text == MAIL_TO_LABEL)
                        or (type(MAIL_SUBJECT_LABEL) == "string" and text == MAIL_SUBJECT_LABEL)
                        or text == "收件人：" or text == "收件人:" or text == "主题：" or text == "主题:") then region:Hide() end
                end
            end
        end
    end
    StyleInput(SendMailNameEditBox, panel.recipientField)
    StyleInput(SendMailSubjectEditBox, panel.subjectField)
    if SendMailBodyEditBox and SendMailScrollChildFrame then
        SendMailBodyEditBox:ClearAllPoints()
        SendMailBodyEditBox:SetPoint("TOPLEFT", SendMailScrollChildFrame, "TOPLEFT", 6, -10)
        SendMailBodyEditBox:SetWidth(math.max(140, SendMailScrollChildFrame:GetWidth() - 16))
    end
    panel.contacts:ClearAllPoints(); panel.contacts:SetSize(theme.Size.standard, theme.Size.standard)
    panel.contacts:SetPoint("TOPRIGHT", panel.close, "TOPLEFT", -theme.Size.standard - 6, 0)
    panel.favoriteToggle:ClearAllPoints(); panel.favoriteToggle:SetSize(theme.Size.standard, theme.Size.standard)
    panel.favoriteToggle:SetPoint("LEFT", panel.contacts, "RIGHT", 6, 0)
    panel.favoritesPanel:ClearAllPoints(); panel.favoritesPanel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 0, 0)
    panel.favoritesPanel:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMRIGHT", 0, 0)
    local gridGapX, gridGapY, gridPaddingX, gridPaddingY = 6, 4, 6, 6
    local tileSize = math.max(1, math.floor((MailFrame:GetHeight() - gridPaddingY * 2 - gridGapY * 7) / 8))
    panel.favoritesPanel:SetWidth(tileSize * 2 + gridGapX + gridPaddingX * 2)
    panel.favoritesPanel:SetShown(panel.favoritesExpanded)
    panel.favoriteToggle:SetText(panel.favoritesExpanded and "<" or ">")
    self:LayoutFavoriteButtons()
    local postage = _G.SendMailCostMoneyFrame
    if postage then postage:ClearAllPoints(); postage:SetPoint("TOPRIGHT", MailFrame, "TOPRIGHT", -12, -48) end
    if _G.SendMailMoneyFrame then _G.SendMailMoneyFrame:Hide() end
    local sendButton = _G.SendMailMailButton or _G.SendMailSendButton
    local cancelButton = SendMailCancelButton
    if sendButton and cancelButton then
        local width, height = 96, theme.Size.standard
        cancelButton:ClearAllPoints(); cancelButton:SetSize(width, height)
        cancelButton:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -12, 5)
        sendButton:ClearAllPoints(); sendButton:SetSize(width, height)
        sendButton:SetPoint("RIGHT", cancelButton, "LEFT", -6, 0)
    end
    self:RefreshSendBalance()
end
function Native:RefreshSendBalance()
    local balance = self.send and self.send.balance
    if not balance or type(GetMoney) ~= "function" then return end
    local gold = math.floor((tonumber(GetMoney()) or 0) / 10000)
    local digits = tostring(gold)
    local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    balance:SetText(formatted .. " |TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t")
end
function Native:RefreshBasicSend()
    local panel = self.send
    if not panel or not panel:IsShown() or self.refreshingSend then return end
    self.refreshingSend = true
    panel.contacts:SetText("")
    self:RefreshFavoriteButtons()
    Addon.RecipientUI:Refresh()
    self.refreshingSend = nil
end
function Native:PreviewFill()
    local panel = self.send; local suggestion = panel.matches and panel.matches[panel.selected]
    if not suggestion then panel.notice = "暂无匹配的可寄送物品。"; self:RefreshSend(); return end
    local ok, err = Addon.Compose:PrepareFill(suggestion); if not ok then panel.notice = err; self:RefreshSend(); return end
    local preview, lines = self.fillPreview, {}
    preview.title:SetText("收件人：" .. View:Escape(suggestion.recipient) .. "\n共 " .. suggestion.quantity .. " 件 · " .. #suggestion.items .. " 格")
    for index, item in ipairs(suggestion.items) do lines[#lines + 1] = index .. ". " .. item.itemLink .. " ×" .. item.quantity end
    preview.items:SetText(table.concat(lines, "\n\n")); preview.items:SetHeight(#lines * 38)
    preview.content:SetSize(math.max(1, preview.scroll:GetWidth() - 16), math.max(1, #lines * 38)); preview.scroll:SetContentHeight(#lines * 38); preview:Show(); self:RefreshSend()
end
function Native:RefreshSend()
    if not Addon.FEATURES.sendAssist then return self:RefreshBasicSend() end
    local panel = self.send; if not self.readySend or not panel:IsShown() or self.refreshingSend then return end
    self.refreshingSend = true
    local contacts, roster = {}, View:GetContacts()
    panel.contactPage = math.max(1, math.min(panel.contactPage or 1, math.max(1, math.ceil(#roster / 6))))
    for index = (panel.contactPage - 1) * 6 + 1, math.min(#roster, panel.contactPage * 6) do local contact = roster[index]; contacts[#contacts + 1] = { value = contact.address, label = View:Escape(contact.label) } end
    if panel.contactPage > 1 then contacts[#contacts + 1] = { value = "__prev", label = "上一页联系人" } end
    if panel.contactPage * 6 < #roster then contacts[#contacts + 1] = { value = "__next", label = "下一页联系人" } end
    contacts[#contacts + 1] = { value = "__save", label = "收藏当前收件人" }; contacts[#contacts + 1] = { value = "__settings", label = "管理联系人与规则" }
    panel.contacts:SetOptions(contacts); panel.contacts:SetText("常用联系人")
    panel.matches = {}; for _, suggestion in ipairs(Addon.Compose:GetSuggestions()) do if not (panel.skipped and panel.skipped[suggestion.itemID]) then panel.matches[#panel.matches + 1] = suggestion end end
    local options = {}; panel.rulePage = math.max(1, math.min(panel.rulePage or 1, math.max(1, math.ceil(#panel.matches / 5))))
    for index = (panel.rulePage - 1) * 5 + 1, math.min(#panel.matches, panel.rulePage * 5) do
        local suggestion = panel.matches[index]; local name = GetItemInfo(suggestion.itemID) or ("物品 " .. suggestion.itemID)
        options[#options + 1] = { value = index, label = View:Escape(name) .. " → " .. View:Escape(suggestion.recipient) .. " ×" .. suggestion.quantity }
    end
    if panel.rulePage > 1 then options[#options + 1] = { value = "__prev", label = "上一页规则建议" } end
    if panel.rulePage * 5 < #panel.matches then options[#options + 1] = { value = "__next", label = "下一页规则建议" } end
    if panel.skipped and next(panel.skipped) then options[#options + 1] = { value = "__reset", label = "显示跳过的建议" } end
    panel.suggestions:SetOptions(options)
    if panel.selected == nil or not panel.matches[panel.selected] then panel.selected = #panel.matches > 0 and ((panel.rulePage - 1) * 5 + 1) or nil end
    if panel.selected then panel.suggestions:SetValue(panel.selected) else panel.suggestions:SetText("规则匹配：暂无可寄送物品") end
    local fill = Addon.Compose.fill
    panel.preview:SetEnabled(panel.selected ~= nil and not Addon.Queue.pending and Addon.Queue.state ~= "running" and not self.fillPreview:IsShown())
    local canFill = not Addon.Queue.pending and Addon.Queue.state ~= "running" and not self.fillPreview:IsShown()
    panel.next:SetEnabled(canFill and fill ~= nil and fill.index <= #fill.items); panel.undo:SetEnabled(canFill and fill ~= nil and #fill.staged > 0); panel.skip:SetEnabled(panel.selected ~= nil)
    panel.noticeText:SetText(panel.notice or (fill and ("已装填 " .. #fill.staged .. "/" .. #fill.items .. " 格") or ""))
    self.refreshingSend = nil
end
local function MoveDown(frame, offset)
    if not frame then return end
    local points = {}; for index = 1, frame:GetNumPoints() do points[index] = { frame:GetPoint(index) } end
    frame:ClearAllPoints()
    for _, point in ipairs(points) do frame:SetPoint(point[1], point[2], point[3], point[4], (point[5] or 0) - offset) end
end
local function StyleNativeActionButton(button, primary)
    if not button then return end
    local theme = Addon.Core.UITheme
    local skin = CreateFrame("Frame", nil, button, "BackdropTemplate")
    skin:SetAllPoints(button); skin:SetFrameLevel(button:GetFrameLevel() + 1); skin:EnableMouse(false)
    skin:SetBackdrop(BACKDROP)
    skin.label = theme:CreateText(skin, theme.Font.body, theme.Colors.text, "CENTER")
    skin.label:SetAllPoints()
    button.yiboMailSkin = skin
    local function Apply(hovered)
        local enabled = button:IsEnabled()
        local fill = enabled and (primary and theme.Colors.chrome or theme.Colors.panel) or theme.Colors.bg
        local border = enabled and (hovered and theme.Colors.accent or (primary and theme.Colors.line or theme.Colors.lineSoft)) or theme.Colors.lineSoft
        skin:SetBackdropColor(unpack(fill))
        skin:SetBackdropBorderColor(unpack(border))
        skin.label:SetText(button:GetText() or "")
        skin.label:SetTextColor(unpack(enabled and theme.Colors.text or theme.Colors.muted))
        for _, region in ipairs({ button:GetRegions() }) do
            if type(region.GetObjectType) == "function" then
                local objectType = region:GetObjectType()
                if objectType == "Texture" then region:SetAlpha(0)
                elseif objectType == "FontString" then region:SetAlpha(0) end
            end
        end
    end
    Apply(false)
    button:HookScript("OnEnter", function() Apply(true) end)
    button:HookScript("OnLeave", function() Apply(false) end)
    button:HookScript("OnEnable", function() Apply(false) end)
    button:HookScript("OnDisable", function() Apply(false) end)
end
function Native:Install()
    if self.installed or not MailFrame or not InboxFrame then return end
    if Addon.FEATURES.send and (not SendMailFrame or not SendMailNameEditBox or not SendMailCancelButton) then return end
    if InCombatLockdown and InCombatLockdown() then return end
    self.installed = true
    if Addon.FEATURES.send and not Addon.FEATURES.sendAssist then
        StyleNativeActionButton(_G.SendMailMailButton or _G.SendMailSendButton, false)
        StyleNativeActionButton(SendMailCancelButton, false)
    end
    if Addon.FEATURES.sendAssist then
        -- Reserve two compact rows inside the native shell for rule assistance.
        MailFrame:SetHeight(MailFrame:GetHeight() + 70)
        MoveDown(SendMailCancelButton, 70)
        MoveDown(_G.SendMailMoneyFrame, 70); MoveDown(_G.SendMailMoneyInset, 70); MoveDown(_G.SendMailMoneyBg, 70)
        local recipientWidth = math.max(100, math.min(SendMailNameEditBox:GetWidth(), MailFrame:GetWidth() - 248))
        SendMailNameEditBox:SetWidth(recipientWidth)
    end
    self:CreateInbox()
    if Addon.FEATURES.sendAssist then self:CreateSend() elseif Addon.FEATURES.send then self:CreateBasicSend() end
    if OpenMailFrame then OpenMailFrame:HookScript("OnHide", function() Native.openMailKey = nil end) end
    InboxFrame:HookScript("OnShow", function()
        Native:RememberBrowsePage(1)
        Native:SuppressInboxContent(); Native:RefreshInbox()
    end)
    if hooksecurefunc and type(InboxFrame_Update) == "function" then hooksecurefunc("InboxFrame_Update", function() Native:SuppressInboxContent() end) end
    if SendMailFrame then SendMailFrame:HookScript("OnShow", function()
        Native:RememberBrowsePage(2)
        local close = MailFrame.CloseButton or _G.MailFrameCloseButton
        if close and close:GetParent() ~= Native.nativeInboxContent then
            if Addon.FEATURES.send and not Addon.FEATURES.sendAssist then close:Hide() else close:Show() end
        end
        if Addon.FEATURES.send and not Addon.FEATURES.sendAssist then Native:SetInboxShell(true) end
        if Addon.FEATURES.send and not Addon.FEATURES.sendAssist then
            if MailFrame.TitleText then MailFrame.TitleText:SetAlpha(0) end
            for _, name in ipairs({ "MailFrameTitleText", "SendMailFrameTitleText", "SendMailTitleText" }) do
                if _G[name] then _G[name]:SetAlpha(0) end
            end
        end
        if Native.send and Native.send.shell then Native.send.shell:Show() end
        if Addon.FEATURES.send then
            Native:LayoutBasicSend()
            if C_Timer and C_Timer.After and not Addon.FEATURES.sendAssist then C_Timer.After(0, function() Native:LayoutBasicSend() end) end
            Native:RefreshSend()
        end
    end) end
    if hooksecurefunc and type(MailFrameTab_OnClick) == "function" then
        hooksecurefunc("MailFrameTab_OnClick", function(_, page)
            if page == 1 or page == 2 then Native:RememberBrowsePage(page) end
        end)
    end
    MailFrame:HookScript("OnShow", function()
        Native.restorePagePending = true
        Native:ApplyInboxPreferences()
        Native:Refresh()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if MailFrame:IsShown() then Native:RestoreBrowsePage()
                else Native.restorePagePending = nil end
            end)
        else Native:RestoreBrowsePage() end
    end)
    MailFrame:HookScript("OnHide", function()
        Native:SetInboxShell(false)
        Native.deleting = nil
        Native.restorePagePending = nil
        Native:RememberBrowsePage()
        Native:RememberInboxFilters()
        Native.inbox.selection = {}
        Native.inbox.search:ClearFocus(); Native.inbox.filter.menu:Hide(); Native.inbox.menu.menu:Hide()
        if Native.send then
            Native.send.notice = nil; Native.send.contacts.menu:Hide()
            if Native.send.suggestions then Native.send.suggestions.menu:Hide() end
        end
        if Native.fillPreview then Native.fillPreview:Hide() end
    end)
    Addon.Items.Events:Register(self, function() Native.deleting = nil; Native:Refresh() end)
    Addon.Frame:HookScript("OnUpdate", function()
        if Native.deleting and GetTime() - Native.deleteStartedAt > 12 then
            Native.deleting = nil; Native.inbox.notice = "删除未确认，请检查邮箱后重试。"; Native:RefreshInbox()
        end
    end)
    self:ApplyInboxPreferences()
    self:Refresh()
end
function Native:Refresh()
    self:RefreshInbox(); if Addon.FEATURES.send then self:RefreshSend() end
end
function Native:OnCollected(id, action)
    local panel = self.inbox
    if not panel then return end
    panel.selection[id] = nil
    if panel.keepTilesDuringQueue and panel.mode == "mail" then self:RefreshCollectedMailRow(action); return end
    if not panel.keepTilesDuringQueue or not action or action.slot == "money" or not action.item then return end
    for _, tile in ipairs(panel.tiles or {}) do
        local group, collected
        group = tile.mailGroup
        if group then
            for index = #group.sources, 1, -1 do
                local source = group.sources[index]
                local sameMail = source.entry.character.id == action.characterID
                    and (source.entry.key == action.mailKey or source.entry.mail.signature == action.signature)
                if sameMail and source.item.attachmentIndex == action.slot
                    and source.item.variantKey == action.item.variantKey
                    and source.item.quantity == action.item.quantity then
                    collected = source
                    table.remove(group.sources, index)
                    break
                end
            end
        end
        if collected then
            group.quantity = math.max(0, group.quantity - (tonumber(collected.item.quantity) or 0))
            tile.eligibleCount = math.max(0, (tile.eligibleCount or 1) - 1)
            tile.count:SetText(tostring(group.quantity))
            -- Re-run the existing tooltip builder against the updated aggregate
            -- while keeping the same owner and tile mounted under the cursor.
            if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == tile then
                local onEnter = tile:GetScript("OnEnter")
                if onEnter then onEnter(tile) end
            end
            return
        end
    end
end
function Native:OnEvent(event, itemID, success)
    if event == "MAIL_FAILED" and self.deleting then
        self.deleting = nil; self.inbox.notice = "删除未完成，请检查游戏提示。"
    end
    if event == "GET_ITEM_INFO_RECEIVED" then
        if self.pendingItemInfo and self.pendingItemInfo[itemID] then
            self.pendingItemInfo[itemID] = nil
            if success then self:RefreshInbox() end
        end
        return
    end
    if event == "ADDON_LOADED" or event == "MAIL_SHOW" or event == "PLAYER_REGEN_ENABLED" then self:Install() end
    if event == "MAIL_SEND_SUCCESS" then
        if self.fillPreview then self.fillPreview:Hide() end
        if self.send then
            self.send.notice = "发送成功。"
            if self.send.status then self.send.status:SetText("发送成功 · 已记录为在途，尚未确认送达") end
        end
    elseif event == "MAIL_FAILED" and self.send and self.send.status then
        self.send.status:SetText("发送未确认 · 请检查原生游戏提示")
    end
    if self.installed and (event == "MAIL_INBOX_UPDATE" or event == "MAIL_SUCCESS" or event == "MAIL_SHOW" or event == "MAIL_SEND_INFO_UPDATE" or event == "MAIL_SEND_SUCCESS" or event == "MAIL_FAILED" or event == "BAG_UPDATE_DELAYED") then self:Refresh() end
end
