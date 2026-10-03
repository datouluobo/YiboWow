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
function Native:RememberInboxFilters()
    if not self.inbox or self.applyingPreferences or not Addon:GetInboxPreferences().rememberFilters then return end
    Addon.db.settings.inboxFilters = Addon.Copy(self.inbox.options)
end
function Native:ApplyInboxPreferences(deferWhileOpen)
    if not self.readyInbox then return end
    if deferWhileOpen and Addon.Scanner:IsOpen() then return end
    local prefs = Addon:GetInboxPreferences()
    local options = prefs.rememberFilters and Addon.db.settings.inboxFilters or nil
    self.applyingPreferences = true
    self.inbox.mode = prefs.mode
    self.inbox.options = { search = options and options.search or "", kind = options and options.kind or prefs.kind, sort = options and options.sort or prefs.sort }
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
    for _, entry in ipairs(View:GetMails(self:Context(), self.inbox.options)) do
        for _, action in ipairs(Addon:GetInboxActions(entry)) do
            if action.actionable and Addon:SelectByDefault(action) and not selection[action.id] then selection[action.id] = true; count = count + 1 end
        end
    end
    return selection, count
end
function Native:InboxMenuAction(value)
    local panel, queue = self.inbox, Addon.Queue
    panel.menu.menu:Hide(); panel.notice = nil
    if value == "select" or value == "clear" then
        if queue.state == "running" or queue.pending then panel.notice = "请先暂停队列并等待当前操作结束。"
        elseif value == "select" then
            if queue.state == "paused" then queue:Discard() end
            local count
            panel.selection, count = self:SelectInboxActions()
            panel.notice = count > 0 and ("已选择 " .. count .. " 项可收项目。") or "当前筛选下没有符合全选范围的可收项目。"
            panel.scroll:SetVerticalScroll(0)
        else
            local ok, err = queue:Discard()
            if ok then panel.selection, panel.notice = {}, "选择与队列已清空。" else panel.notice = err end
        end
    elseif value == "pause" then
        if queue.state == "running" then queue:Pause("玩家已暂停，当前操作仍等待结果。") else panel.notice = "当前没有运行中的收取队列。" end
    elseif value == "sort" then
        panel.options.sort = panel.options.sort == "expiry" and "inbox" or "expiry"
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
    for _, name in ipairs({ "MailFrameBg", "MailFrameInset", "MailFramePortrait", "MailFrameTitleBg" }) do HideDecoration(_G[name]) end
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
    panel.status = Text(panel); panel.status:SetPoint("BOTTOMLEFT", 8, 40); panel.status:SetPoint("BOTTOMRIGHT", -8, 40); panel.status:SetHeight(18)
    panel.statusHover = CreateFrame("Frame", nil, panel); panel.statusHover:SetAllPoints(panel.status); panel.statusHover:EnableMouse(true)
    panel.mail = InboxButton(panel, 52, "邮件", function() panel.mode, panel.notice = "mail", nil; panel.scroll:SetVerticalScroll(0); Native:RefreshInbox() end); panel.mail:SetPoint("BOTTOMLEFT", 6, 6)
    panel.items = InboxButton(panel, 52, "附件", function() panel.mode, panel.notice = "items", nil; panel.scroll:SetVerticalScroll(0); Native:RefreshInbox() end); panel.items:SetPoint("LEFT", panel.mail, "RIGHT", 2, 0)
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
    row:ClearAllPoints(); row:SetPoint("TOPLEFT", data.indent and 16 or 0, -panel.top); row:SetSize(panel.width - (data.indent and 16 or 0), height)
    row:SetBackdropColor(0, 0, 0, 0); row:SetBackdropBorderColor(0, 0, 0, 0)
    row.title:SetText(data.title or ""); row.detail:SetText(data.detail or ""); row.expiry:SetText(data.expiry or "")
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
    local mails, err = Addon.Scanner:ReadVisible(); if not mails then self.inbox.notice = err; self:RefreshInbox(); return end
    local index = entry.mail.inboxIndex; local current = mails[index]
    if not current or current.signature ~= entry.mail.signature then self.inbox.notice = "邮件已变化，请等待更新。"; self:RefreshInbox(); return end
    if OpenMail_Update and ShowUIPanel then
        InboxFrame.openMailID = index
        OpenMailFrame.updateButtonPositions = true
        OpenMail_Update(); ShowUIPanel(OpenMailFrame)
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
    local mails, err = Addon.Scanner:ReadVisible()
    local current = mails and mails[entry.mail.inboxIndex]
    if not current or current.signature ~= entry.mail.signature then
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
    self:Row({ title = View:Escape(mail.sender), detail = subject, summary = attachmentSummary, wasRead = mail.openedByUser,
        onDelete = #mail.attachments == 0 and mail.money == 0 and mail.cod == 0 and function() Native:DeleteEmptyMail(entry) end or nil,
        texture = mail.attachments[1] and mail.attachments[1].texture, quantity = #mail.attachments == 1 and mail.attachments[1].quantity or nil,
        expiry = View:Expiry(mail), actions = Addon:GetInboxActions(entry), tooltip = subject .. "\n" .. attachmentSummary .. "\n到期：" .. View:Expiry(mail) .. "\n左键展开／收起附件；右键打开／关闭原生信件。" .. (not entry.actionable and ("\n" .. entry.restriction) or ""),
        onClick = function(_, mouse)
            if mouse == "RightButton" or not expandable then Native:OpenMail(entry)
            elseif panel.expanded[entry.key] then ToggleAttachments()
            elseif Native:ReadMail(entry) then ToggleAttachments() end
        end })
    panel.rows[panel.used]:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if panel.expanded[entry.key] then
        for _, item in ipairs(mail.attachments) do
            self:Row({ title = item.itemLink or View:Escape(item.name), detail = "附件槽 " .. item.attachmentIndex .. " · " .. (mail.cod > 0 and ("付款 " .. View:Money(mail.cod)) or (entry.actionable and "可收取" or entry.restriction)),
                texture = item.texture, quantity = item.quantity, expiry = View:Expiry(mail), indent = true, itemLink = item.itemLink, actions = Addon:GetInboxActions(entry, item),
                onClick = function(_, mouse)
                    if mouse == "RightButton" then Native:OpenMail(entry)
                    elseif mail.cod > 0 then Native:CollectCOD(entry, item) end
                end })
            panel.rows[panel.used]:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        end
        if mail.money > 0 then
            local actions = {}; for _, action in ipairs(Addon:GetInboxActions(entry)) do if action.slot == "money" then actions[1] = action end end
            self:Row({ title = "金币 " .. View:Money(mail.money), detail = "来自：" .. View:Escape(mail.sender), indent = true,
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
        local ok, why = queue:Start(actions)
        if not ok then panel.notice = why end
    end
    self:RefreshInbox()
end
function Native:CollectItem(group)
    local panel, queue = self.inbox, Addon.Queue
    if queue.state == "running" or queue.pending then return end
    local selection = {}
    for _, source in ipairs(group.sources) do
        for _, action in ipairs(Addon:GetInboxActions(source.entry, source.item)) do
            if action.actionable then selection[action.id] = true end
        end
    end
    local actions, err = queue:Prepare(selection, self:Context())
    panel.notice = err
    if actions then
        local ok, why = queue:Start(actions)
        if not ok then panel.notice = why end
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
    tile:SetBackdropBorderColor(unpack(borderColor))
    if needsItemInfo and group.item.itemID and C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        self.pendingItemInfo = self.pendingItemInfo or {}
        if not self.pendingItemInfo[group.item.itemID] then
            self.pendingItemInfo[group.item.itemID] = true
            C_Item.RequestLoadItemDataByID(group.item.itemID)
        end
    end
    tile.icon:SetDesaturated(eligible == 0 and not codSource)
    tile:SetEnabled((eligible > 0 or codSource ~= nil) and Addon.Queue.state ~= "running" and not Addon.Queue.pending)
    tile:SetScript("OnClick", function()
        if eligible > 0 then Native:CollectItem(group)
        elseif codSource then Native:CollectCOD(codSource.entry, codSource.item) end
    end)
    tile:SetScript("OnEnter", function(control)
        GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
        if group.item.itemLink then GameTooltip:SetHyperlink(group.item.itemLink) else GameTooltip:SetText(group.item.name or "附件") end
        GameTooltip:AddLine("合计 " .. group.quantity .. " 件 · " .. #group.sources .. " 个附件槽", 1, 1, 1)
        GameTooltip:AddLine("最早到期：" .. View:Expiry(group), 1, 1, 1)
        for sourceIndex = 1, math.min(8, #group.sources) do
            local source = group.sources[sourceIndex]
            GameTooltip:AddLine(View:Escape(source.entry.mail.sender .. " · " .. source.entry.mail.subject) .. " ×" .. source.item.quantity, 0.8, 0.85, 0.83, true)
            if not source.entry.actionable then GameTooltip:AddLine(source.entry.restriction, 1, 0.65, 0.2, true) end
        end
        if #group.sources > 8 then GameTooltip:AddLine("另有 " .. (#group.sources - 8) .. " 个来源", 0.8, 0.85, 0.83) end
        GameTooltip:AddLine((Addon.Queue.state == "running" or Addon.Queue.pending) and "正在处理附件，请等待当前操作结束。" or (eligible > 0 and "点击收取此物品的全部可收附件" or (codSource and "点击确认付款取信" or "当前没有可收取附件")), 0.2, 0.9, 0.65, true)
        GameTooltip:Show()
    end)
    tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tile:Show()
end
function Native:RefreshInbox()
    local panel = self.inbox; if not self.readyInbox or not panel:IsShown() or self.refreshingInbox then return end
    self.refreshingInbox = true
    panel.used, panel.top, panel.available, panel.width = 0, 0, {}, math.max(1, panel.scroll:GetWidth())
    for _, tile in ipairs(panel.tiles or {}) do tile:Hide() end
    local context = self:Context()
    if panel.mode == "mail" then
        for _, entry in ipairs(View:GetMails(context, panel.options)) do self:EntryRows(entry) end
    else
        local groups = View:GetGroups(context, panel.options)
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
    for _, entry in ipairs(View:GetMails(context, {})) do
        for _, item in ipairs(entry.mail.attachments) do
            local id = View:ActionID(entry.character.id, entry.key, item.attachmentIndex)
            if panel.selection[id] and not counted[id] then counted[id] = true; selectedAttachments = selectedAttachments + 1 end
        end
    end
    local character = context.characters[1]; local coverage = character and Addon.Items:GetState(character.id)
    local progress = Addon.Queue.state == "running" or Addon.Queue.state == "paused"
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
function Native:Install()
    if self.installed or not MailFrame or not InboxFrame then return end
    if Addon.FEATURES.send and (not SendMailFrame or not SendMailNameEditBox or not SendMailCancelButton) then return end
    if InCombatLockdown and InCombatLockdown() then return end
    self.installed = true
    if Addon.FEATURES.send then
        -- Reserve two compact rows inside the native shell for rule assistance.
        MailFrame:SetHeight(MailFrame:GetHeight() + 70)
        MoveDown(SendMailCancelButton, 70)
        MoveDown(_G.SendMailMoneyFrame, 70); MoveDown(_G.SendMailMoneyInset, 70); MoveDown(_G.SendMailMoneyBg, 70)
        local recipientWidth = math.max(100, math.min(SendMailNameEditBox:GetWidth(), MailFrame:GetWidth() - 248))
        SendMailNameEditBox:SetWidth(recipientWidth)
    end
    self:CreateInbox(); if Addon.FEATURES.send then self:CreateSend() end
    if OpenMailFrame then OpenMailFrame:HookScript("OnHide", function() Native.openMailKey = nil end) end
    InboxFrame:HookScript("OnShow", function() Native:SuppressInboxContent(); Native:RefreshInbox() end)
    if hooksecurefunc and type(InboxFrame_Update) == "function" then hooksecurefunc("InboxFrame_Update", function() Native:SuppressInboxContent() end) end
    if SendMailFrame then SendMailFrame:HookScript("OnShow", function()
        local close = MailFrame.CloseButton or _G.MailFrameCloseButton
        if close and close:GetParent() ~= Native.nativeInboxContent then close:Show() end
        if Addon.FEATURES.send then Native:RefreshSend() end
    end) end
    MailFrame:HookScript("OnShow", function() Native:ApplyInboxPreferences(); Native:Refresh() end)
    MailFrame:HookScript("OnHide", function()
        Native.deleting = nil
        Native:RememberInboxFilters()
        Native.inbox.selection = {}
        Native.inbox.search:ClearFocus(); Native.inbox.filter.menu:Hide(); Native.inbox.menu.menu:Hide()
        if Native.send then Native.send.notice = nil; Native.send.contacts.menu:Hide(); Native.send.suggestions.menu:Hide() end
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
function Native:OnCollected(id)
    if self.inbox then self.inbox.selection[id] = nil end
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
    if event == "MAIL_SEND_SUCCESS" then if self.fillPreview then self.fillPreview:Hide() end; if self.send then self.send.notice = "发送成功。" end end
    if self.installed and (event == "MAIL_INBOX_UPDATE" or event == "MAIL_SHOW" or event == "MAIL_SEND_INFO_UPDATE" or event == "MAIL_SEND_SUCCESS" or event == "MAIL_FAILED" or event == "BAG_UPDATE_DELAYED") then self:Refresh() end
end
