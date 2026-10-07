local Addon = _G.YiboMail
local Native = {}; Addon.NativeUI = Native
local View = Addon.ViewModel
local BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local function StripNativeArt(control, hideText)
    if not control then return end
    if control.GetRegions then
        for _, region in ipairs({ control:GetRegions() }) do
            local kind = region.GetObjectType and region:GetObjectType()
            if kind == "Texture" or hideText and kind == "FontString" then region:SetAlpha(0) end
        end
    end
    for _, method in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture", "GetCheckedTexture" }) do
        local texture = control[method] and control[method](control)
        if texture then texture:SetAlpha(0) end
    end
    for _, key in ipairs({ "NineSlice", "backdrop", "Backdrop", "BorderFrame", "Background", "Bg", "shadow", "Shadow" }) do
        local decoration = control[key]
        if decoration then decoration:SetAlpha(0) end
    end
end
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
function Native:InstallMailboxTabs()
    if self.mailboxTabs or not MailFrameTab1 or not MailFrameTab2 then return end
    self.mailboxTabs = {}
    -- Own the navigation controls; leave Blizzard's two-page registry untouched.
    for _, entry in ipairs({ { "mail", "收件箱" }, { "items", "附件箱" }, { "send", "发件箱" }, { "rules", "规则寄" } }) do
        local key = entry[1]
        local tab = Addon.Core.UITheme:CreateButton(MailFrame, 1, entry[2], "secondary")
        local theme = Addon.Core.UITheme
        tab.indicator = tab:CreateTexture(nil, "OVERLAY")
        tab.indicator:SetColorTexture(unpack(theme.Colors.accent)); tab.indicator:SetHeight(2)
        tab.indicator:SetPoint("TOPLEFT"); tab.indicator:SetPoint("TOPRIGHT")
        tab.SetState = function(control, state)
            control.state = state or "default"
            control:SetBackdropColor(unpack(theme.Colors.nav))
            control:SetBackdropBorderColor(0, 0, 0, 0)
            control.label:SetTextColor(unpack(control.state == "selected" and theme.Colors.accent or theme.Colors.muted))
            control.indicator:SetShown(control.state == "selected")
        end
        tab:SetScript("OnEnter", function(control) control.label:SetTextColor(unpack(theme.Colors.text)) end)
        tab:SetScript("OnLeave", function(control) control:SetState(control.state) end)
        tab:SetFrameLevel(MailFrame:GetFrameLevel() + 20)
        tab:SetScript("OnClick", function() Native:SelectMailboxTab(key) end)
        self.mailboxTabs[key] = tab
    end
    MailFrameTab1:Hide(); MailFrameTab2:Hide()
    MailFrame:HookScript("OnSizeChanged", function() Native:LayoutMailboxTabs() end)
    self:RefreshMailboxTabs()
end
function Native:LayoutMailboxTabs()
    if not self.mailboxTabs then return end
    local gap = 2
    local width = math.max(1, (MailFrame:GetWidth() - gap * 3) / 4)
    local height = Addon.Core.UITheme.Size.compact
    for index, key in ipairs({ "mail", "items", "send", "rules" }) do
        local tab = self.mailboxTabs[key]
        tab:ClearAllPoints()
        tab:SetSize(width, height)
        tab:SetPoint("TOPLEFT", MailFrame, "BOTTOMLEFT", (index - 1) * (width + gap), 0)
    end
end
function Native:RefreshMailboxTabs()
    if not self.mailboxTabs then return end
    self:LayoutMailboxTabs()
    local key = Addon.RuleSendUI and Addon.RuleSendUI.active and "rules"
        or (self.activePage == 2 and "send" or (self.inbox and self.inbox.mode == "items" and "items" or "mail"))
    for name, tab in pairs(self.mailboxTabs) do tab:SetState(name == key and "selected" or "default") end
end
function Native:SelectMailboxTab(key)
    if key ~= "mail" and key ~= "items" and key ~= "send" and key ~= "rules" then return end
    if key == "rules" and (not Addon.RuleSendUI or not Addon.RuleSendUI.root) then return end
    -- Rules and compose share native page 2. Always leave rule mode explicitly,
    -- even when Blizzard skips its page handler because page 2 is selected.
    if Addon.RuleSendUI then Addon.RuleSendUI:SetActive(false) end
    if self.inbox and (key == "mail" or key == "items") then
        local changed = self.inbox.mode ~= key
        self.inbox.mode, self.inbox.notice = key, nil
        if changed then
            self.inbox.keepTilesDuringQueue = nil
            self.inbox.scroll:SetVerticalScroll(0)
        end
        self.inbox.filter.menu:Hide(); self.inbox.menu.menu:Hide()
    end
    local page = (key == "send" or key == "rules") and 2 or 1
    if type(MailFrameTab_OnClick) == "function" then
        if securecallfunction then securecallfunction(MailFrameTab_OnClick, nil, page)
        else MailFrameTab_OnClick(nil, page) end
    end
    self:RememberBrowsePage(page)
    if key == "rules" then
        Addon.RuleSendUI:SetActive(true)
        Addon.RuleSendController:Scan(); Addon.RuleSendUI:Refresh()
    elseif page == 1 then self:RefreshInbox() end
    self:RefreshMailboxTabs()
end
function Native:SetMailRecipient(address)
    if not SendMailNameEditBox or type(address) ~= "string" or address == "" then return false end
    SendMailNameEditBox:SetText(address)
    if type(_G.SendMailFrame_Update) == "function" then _G.SendMailFrame_Update() end
    SendMailNameEditBox:ClearFocus()
    return SendMailNameEditBox:GetText() == address
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
    self:SelectMailboxTab(page == 2 and "send" or (self.inbox and self.inbox.mode == "items" and "items" or "mail"))
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
    theme:AttachClearButton(panel.search)
    panel.filter = self:Dropdown(panel, 96, "全部邮件"); panel.filter:SetHeight(height); panel.filter:SetPoint("RIGHT", panel.close, "LEFT", -6, 0)
    panel.search:SetPoint("RIGHT", panel.filter, "LEFT", -6, 0)
    panel.filter:SetOptions({ { value = "all", label = "全部邮件" }, { value = "items", label = "含附件" }, { value = "money", label = "含金币" },
        { value = "cod", label = "付款取信" }, { value = "returned", label = "退回邮件" }, { value = "urgent", label = "三天内到期" } })
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
    Tooltip(panel.selectAll, "全选当前可收项目", "勾选后选择当前筛选下默认允许收取的项目；再次点击清空选择。")
    panel.status = Text(panel); panel.status:SetHeight(theme.Size.compact); panel.status:SetWordWrap(false)
    panel.statusHover = CreateFrame("Frame", nil, panel); panel.statusHover:SetAllPoints(panel.status); panel.statusHover:EnableMouse(true)
    panel.collect = InboxButton(panel, 72, "收取", function() Native:Collect() end)
    panel.collect.kind = "primary"
    panel.collect:SetHeight(theme.Size.compact); panel.collect:SetPoint("BOTTOMRIGHT", -76, 8)
    panel.menu = self:Dropdown(panel, 64, "更多"); panel.menu:SetHeight(theme.Size.compact); panel.menu:SetPoint("BOTTOMRIGHT", -8, 8)
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
    local borderColor, needsItemInfo = View:AttachmentBorder(group)
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
    panel.status:SetPoint("RIGHT", panel.mode == "mail" and panel.collect or panel.menu, "LEFT", -6, 0)
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
        local gridWidth = math.max(1, math.min(panel.width, panel:GetWidth() - 16 - Addon.Core.UITheme.Geometry.scrollbarGutter))
        local columns = math.max(1, math.min(7, math.floor((gridWidth + 4) / 42)))
        local size = math.max(1, (gridWidth - (columns - 1) * 4) / columns)
        for index, group in ipairs(groups) do self:ItemTile(group, index, columns, size) end
        panel.top = #groups > 0 and math.ceil(#groups / columns) * (size + 4) - 4 or 0
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
        or (panel.mode == "items" and ("邮件 " .. tostring(coverage and coverage.currentCount or 0) .. "/" .. tostring(coverage and coverage.totalCount or 0)) or ("已选 " .. selected)))
    Tooltip(panel.statusHover, "收件状态", panel.status:GetText() .. "\n" .. coverageText)
    self:LayoutInboxFooter()
    panel.collect:SetText(selected > 0 and ("收取 " .. selectedAttachments) or "收取")
    panel.collect:SetEnabled(selected > 0 and Addon.Queue.state ~= "running" and not Addon.Queue.pending)
    panel.collect:SetShown(panel.mode == "mail")
    panel.collect:SetState(panel.collect:IsEnabled() and "default" or "disabled")
    self:RefreshMailboxTabs()
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
    for index = 1, 72 do
        local button = CreateFrame("Button", nil, panel.favoritesPanel, "BackdropTemplate")
        button:SetBackdrop(BACKDROP)
        button:SetBackdropColor(unpack(theme.Colors.panel))
        button:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 1, -1); button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        button.emptyMark = theme:CreateText(button, theme.Font.title, theme.Colors.muted, "CENTER")
        button.emptyMark:SetAllPoints(); button.emptyMark:SetText("+")
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:RegisterForDrag("LeftButton")
        button.slot = index
        button:SetScript("OnDragStart", function(control) Native:StartShortcutDrag(control) end)
        button:SetScript("OnDragStop", function() Native:FinishShortcutDrag() end)
        button:SetScript("OnClick", function(control, mouseButton)
            if control.suppressShortcutClick or Native.shortcutDrag then
                control.suppressShortcutClick = nil; return
            end
            if mouseButton == "RightButton" then Addon.RecipientUI:Open(control, control.slot); return end
            local contact = control.contact
            if not contact then return end
            if Addon.RuleSendUI and Addon.RuleSendUI.active then
                local ok, err = Addon.RuleSendController:Contact(contact.address)
                if not ok then Addon.RuleSendController.notice = err end
                Addon.RuleSendUI:Refresh(); return
            end
            if not SendMailNameEditBox then return end
            Native:SetMailRecipient(contact.address)
            local hasText = (SendMailSubjectEditBox and SendMailSubjectEditBox:GetText() or ""):match("%S")
                or (Addon.Compose:GetBodyEditBox() and Addon.Compose:GetBodyEditBox():GetText() or ""):match("%S")
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
        button:SetScript("OnReceiveDrag", function(control)
            if Addon.RuleSendUI then Addon.RuleSendUI:Drop(control.contact) end
        end)
        button:SetScript("OnEnter", function(control)
            control:SetBackdropBorderColor(unpack(theme.Colors.accent))
            local contact = control.contact
            if not contact then return end
            GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
            -- Escape uses string.gsub internally, which also returns the
            -- replacement count. Parenthesize it so the tooltip receives only
            -- the escaped string as its first argument.
            GameTooltip:SetText((Addon.Recipients:Escape(contact.address)))
            if Addon.RuleSendUI and Addon.RuleSendUI.active then
                local c = Addon.RuleSendController
                local ready = c.state == "ready" and c.packet and Addon.Recipients:Key(c.packet[1].recipient) == Addon.Recipients:Key(contact.address)
                GameTooltip:AddLine(ready and "再次点击：发送当前邮件" or "点击：填入此人规则物品", 0.55, 0.78, 0.78, true)
                GameTooltip:AddLine("拖入物品：建立指定物品规则", 0.55, 0.78, 0.78, true)
            else GameTooltip:AddLine("拖入物品：快速填入此组附件与收件人", 0.55, 0.78, 0.78, true) end
            GameTooltip:AddLine("左键拖动：移到空格，或与已有收件人对调。", 0.55, 0.78, 0.78, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function(control)
            local contact, c = control.contact, Addon.RuleSendController
            local hit = Addon.RuleSendUI and Addon.RuleSendUI.active and contact and c and c.match and c.match.groups[Addon.Recipients:Key(contact.address)]
            control:SetBackdropBorderColor(unpack(hit and theme.Colors.accent or theme.Colors.lineSoft)); GameTooltip:Hide()
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
    panel:SetScript("OnHide", function() panel.contacts.menu:Hide(); Addon.RecipientUI:Hide(); if Native.favoriteEditor then Native.favoriteEditor:Hide() end; Native:HideShortcutIconPicker(); panel.shell:Hide(); panel.favoritesPanel:Hide() end)
    panel.favoritesPanel:SetScript("OnSizeChanged", function() Native:LayoutFavoriteButtons() end)
    panel.favoritesPanel:HookScript("OnHide", function() Native:CancelShortcutDrag() end)
    MailFrame:HookScript("OnSizeChanged", function() Native:LayoutBasicSend(); Addon.RecipientUI:Refresh() end)
    MailFrame:HookScript("OnDragStop", function() Addon.RecipientUI:Refresh() end)
    self.readySend = true
end
function Native:CancelShortcutDrag()
    local drag = self.shortcutDrag
    self.shortcutDrag = nil
    if drag then
        drag.button:SetAlpha(1)
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() drag.button.suppressShortcutClick = nil end)
        end
    end
    if self.shortcutGhost then self.shortcutGhost:Hide(); self.shortcutGhost:SetScript("OnUpdate", nil) end
end
function Native:StartShortcutDrag(button)
    self:CancelShortcutDrag()
    local saved = Addon.db.quickRecipients[button.slot]
    if not saved or not button.contact or not button:IsShown() then return end
    self:HideShortcutIconPicker()
    Addon.RecipientUI:Hide(); GameTooltip:Hide()
    self.shortcutDrag = { button = button, saved = saved }
    button.suppressShortcutClick = true; button:SetAlpha(0.45)
    local ghost = self.shortcutGhost
    if not ghost then
        ghost = CreateFrame("Frame", nil, UIParent); self.shortcutGhost = ghost
        ghost:SetFrameStrata("TOOLTIP"); ghost:EnableMouse(false)
        ghost.icon = ghost:CreateTexture(nil, "ARTWORK"); ghost.icon:SetAllPoints()
    end
    ghost:SetSize(button:GetWidth(), button:GetHeight())
    local coords = not button.contact.icon and button.contact.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[button.contact.class]
    ghost.icon:SetTexture(button.contact.icon or (coords and "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES" or "Interface\\Icons\\INV_Misc_GroupLooking"))
    if coords then ghost.icon:SetTexCoord(unpack(coords)) else ghost.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94) end
    local function FollowCursor()
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        ghost:ClearAllPoints(); ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    end
    ghost:SetScript("OnUpdate", FollowCursor); FollowCursor(); ghost:Show()
end
function Native:FinishShortcutDrag()
    local drag = self.shortcutDrag
    if not drag then return end
    local target
    for _, button in ipairs(self.send.favoriteButtons) do
        if button:IsShown() and button:IsMouseOver() then target = button; break end
    end
    local insideBar = self.send.favoritesPanel:IsMouseOver()
    self:CancelShortcutDrag()
    -- A drag release must never fall through to the normal click-to-send path.
    drag.button.suppressShortcutClick = true
    if target then
        target.suppressShortcutClick = true
        local ok, err = Addon.Recipients:MoveShortcut(drag.button.slot, target.slot, drag.saved)
        if not ok then Addon:Print(err) end
    elseif not insideBar then
        local ok, err = Addon.Recipients:ClearShortcut(drag.button.slot, drag.saved)
        if not ok then Addon:Print(err) end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            drag.button.suppressShortcutClick = nil
            if target then target.suppressShortcutClick = nil end
        end)
    end
end
function Native:HideShortcutIconPicker()
    if self.shortcutIconConfig and Addon.Core.iconPicker and Addon.Core.iconPicker.config == self.shortcutIconConfig then
        Addon.Core:HideIconPicker()
    end
    self.shortcutIconConfig = nil
end
function Native:EditShortcutIcon(slot)
    local saved = Addon.db.quickRecipients[slot]
    if not saved then return end
    if type(Addon.Core.ShowIconPicker) ~= "function" then Addon:Print("请同步更新 YiboCore 后选择图标。"); return end
    self:CancelShortcutDrag()
    local contact = self.send.favoriteEntries[slot]
    local coords = contact and contact.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[contact.class]
    local config = {
        icon = saved.icon,
        autoTexture = coords and "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES" or "Interface\\Icons\\INV_Misc_GroupLooking",
        autoCoords = coords,
        onConfirm = function(icon)
            local ok, err = Addon.Recipients:SetShortcutIcon(slot, icon, saved)
            if not ok then Addon:Print(err) end
        end,
    }
    self.shortcutIconConfig = config
    Addon.Core:ShowIconPicker(config)
end
function Native:LayoutFavoriteButtons()
    self:CancelShortcutDrag()
    local panel = self.send
    local favorites = panel and panel.favoritesPanel
    if not favorites then return end
    local width, height = favorites:GetWidth(), favorites:GetHeight()
    if width <= 0 or height <= 0 then return end
    local gapX, gapY, paddingX, paddingY = 6, 4, 6, 6
    local rows, columns = Addon:GetShortcutLayout()
    local size = math.max(1, math.min(math.floor((width - paddingX * 2 - gapX * (columns - 1)) / columns), math.floor((height - paddingY * 2 - gapY * (rows - 1)) / rows)))
    local totalWidth, totalHeight = size * columns + gapX * (columns - 1), size * rows + gapY * (rows - 1)
    local left, top = math.floor((width - totalWidth) / 2), math.floor((height - totalHeight) / 2)
    for index, button in ipairs(panel.favoriteButtons) do
        local row, column = math.floor((index - 1) / columns), (index - 1) % columns
        button:ClearAllPoints(); button:SetSize(size, size)
        button:SetPoint("TOPLEFT", favorites, "TOPLEFT", left + column * (size + gapX), -(top + row * (size + gapY)))
        button:SetShown(panel.favoritesExpanded and index <= rows * columns)
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
    for index = 1, 72 do
        local saved = Addon.db.quickRecipients and Addon.db.quickRecipients[index]
        local address = saved and Addon.Recipients:Normalize(saved.address)
        if address then
            local character = byAddress[ContactAddressKey(address)]
            panel.favoriteEntries[index] = { address = address, label = saved.label, icon = saved.icon, class = character and character.class }
        end
    end
    for index, button in ipairs(panel.favoriteButtons) do
        local contact = panel.favoriteEntries[index]
        button.contact = contact
        local match = Addon.RuleSendController and Addon.RuleSendController.match
        local hit = Addon.RuleSendUI and Addon.RuleSendUI.active and contact and match and match.groups[Addon.Recipients:Key(contact.address)]
        local c = Addon.RuleSendController
        local selected = Addon.RuleSendUI and Addon.RuleSendUI.active and contact and c and c.packet and c.owned
            and Addon.Recipients:Key(c.packet[1].recipient) == Addon.Recipients:Key(contact.address)
        button:SetBackdropBorderColor(unpack(selected and Addon.Core.UITheme.Colors.text or hit and Addon.Core.UITheme.Colors.accent or Addon.Core.UITheme.Colors.lineSoft))
        if button.hitLabel == nil then
            button.hitLabel = Addon.Core.UITheme:CreateText(button, Addon.Core.UITheme.Font.assist, Addon.Core.UITheme.Colors.text, "RIGHT")
            button.hitLabel:SetPoint("BOTTOMRIGHT", -2, 2)
        end
        button.hitLabel:SetText(selected and "发送" or hit and tostring(hit.quantity) or "")
        local rows, columns = Addon:GetShortcutLayout()
        button:SetShown(panel.favoritesExpanded and index <= rows * columns)
        button.emptyMark:SetShown(contact == nil)
        if contact then
            local coords = contact.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[contact.class]
            if contact.icon then
                button.icon:SetTexture(contact.icon); button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            elseif coords then
                button.icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
                button.icon:SetTexCoord(unpack(coords))
            else
                button.icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
                button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
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
    panel.recipientField:ClearAllPoints(); panel.recipientField:SetPoint("TOPLEFT", MailFrame, "TOPLEFT", 8, -6); panel.recipientField:SetSize(fieldWidth, theme.Size.standard)
    panel.subjectField:ClearAllPoints(); panel.subjectField:SetPoint("TOPLEFT", panel.recipientField, "BOTTOMLEFT", 0, -4); panel.subjectField:SetSize(fieldWidth, theme.Size.standard)
    local function StyleInput(editBox, field)
        if not editBox then return end
        StripNativeArt(editBox)
        -- The field's opaque backdrop is above the original native EditBox.
        -- Keep the native input above it for both text rendering and mouse input.
        if editBox:GetParent() ~= field then editBox:SetParent(field) end
        editBox:SetFrameLevel(field:GetFrameLevel() + 1)
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
    local body = Addon.Compose:GetBodyEditBox()
    if body and SendMailScrollChildFrame then
        body:ClearAllPoints()
        body:SetPoint("TOPLEFT", SendMailScrollChildFrame, "TOPLEFT", 6, -10)
        body:SetWidth(math.max(140, SendMailScrollChildFrame:GetWidth() - 16))
    end
    panel.contacts:ClearAllPoints(); panel.contacts:SetSize(theme.Size.standard, theme.Size.standard)
    panel.contacts:SetPoint("TOPRIGHT", panel.close, "TOPLEFT", -theme.Size.standard - 6, 0)
    panel.favoriteToggle:ClearAllPoints(); panel.favoriteToggle:SetSize(theme.Size.standard, theme.Size.standard)
    panel.favoriteToggle:SetPoint("LEFT", panel.contacts, "RIGHT", 6, 0)
    panel.favoritesPanel:ClearAllPoints(); panel.favoritesPanel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 0, 0)
    local gridGapX, gridGapY, gridPaddingX, gridPaddingY = 6, 4, 6, 6
    local rows, columns = Addon:GetShortcutLayout()
    -- Keep the existing tile size when fewer rows are displayed.
    local sizingRows = math.max(8, rows)
    local tileSize = math.max(1, math.floor((MailFrame:GetHeight() - gridPaddingY * 2 - gridGapY * (sizingRows - 1)) / sizingRows))
    panel.favoritesPanel:SetWidth(tileSize * columns + gridGapX * (columns - 1) + gridPaddingX * 2)
    panel.favoritesPanel:SetHeight(MailFrame:GetHeight())
    panel.favoritesPanel:SetShown(panel.favoritesExpanded)
    panel.favoriteToggle:SetText(panel.favoritesExpanded and "<" or ">")
    self:LayoutFavoriteButtons()
    local postage = _G.SendMailCostMoneyFrame
    if postage then postage:ClearAllPoints(); postage:SetPoint("TOPRIGHT", MailFrame, "TOPRIGHT", -12, -48) end
    if _G.SendMailMoneyFrame then _G.SendMailMoneyFrame:Hide() end
    local sendButton = _G.SendMailMailButton or _G.SendMailSendButton
    local cancelButton = SendMailCancelButton
    if sendButton and cancelButton then
        local width, height = 80, theme.Size.compact
        cancelButton:ClearAllPoints(); cancelButton:SetSize(width, height)
        cancelButton:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -8, 8)
        sendButton:ClearAllPoints(); sendButton:SetSize(width, height)
        sendButton:SetPoint("RIGHT", cancelButton, "LEFT", -6, 0)
    end
    panel.balance:ClearAllPoints(); panel.balance:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", 8, 8)
    panel.balance:SetSize(math.max(60, frameWidth - (Addon.RuleSendUI and Addon.RuleSendUI.active and 276 or 194)), theme.Size.compact)
    panel.balance:SetFont(STANDARD_TEXT_FONT, theme.Font.assist, "")
    self:LayoutSendMoney()
    self:LayoutSendAttachments()
    self:StyleComposeAppearance()
    self:InstallBodyScrollHooks()
    self:RefreshBodyScrollBar()
    if Addon.RuleSendUI and Addon.RuleSendUI.root then Addon.RuleSendUI:Layout() end
    self:RefreshSendBalance()
end
function Native:StyleComposeAppearance()
    local panel, theme = self.send, Addon.Core.UITheme
    if not panel then return end
    StripNativeArt(SendMailFrame)
    for _, name in ipairs({ "SendStationeryBackgroundLeft", "SendStationeryBackgroundRight", "SendMailMoneyInset", "SendMailMoneyBg", "SendMailMoneyFrame" }) do
        local decoration = _G[name]
        if decoration then
            decoration:Hide()
            if decoration.HookScript and not decoration.yiboMailHidden then
                decoration.yiboMailHidden = true
                decoration:HookScript("OnShow", function(control) control:Hide() end)
            end
        end
    end
    local wrapper = _G.MailEditBox or _G.SendMailScrollFrame
    local body = Addon.Compose:GetBodyEditBox()
    StripNativeArt(wrapper); StripNativeArt(_G.SendMailScrollChildFrame)
    if wrapper then StripNativeArt(wrapper.ScrollBox) end
    if wrapper then
        wrapper:SetFrameLevel(panel:GetFrameLevel() + 2)
        if not wrapper.yiboMailBodySurface then
            local surface = CreateFrame("Frame", nil, wrapper, "BackdropTemplate")
            surface:SetAllPoints(wrapper); surface:SetFrameLevel(wrapper:GetFrameLevel()); surface:EnableMouse(false)
            surface:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            surface:SetBackdropColor(unpack(theme.Colors.bg)); wrapper.yiboMailBodySurface = surface
        end
    end
    if body then body:SetFont(STANDARD_TEXT_FONT, theme.Font.body, ""); body:SetTextColor(unpack(theme.Colors.text)) end
    if _G.SendMailCostMoneyFrame then
        for _, region in ipairs({ SendMailCostMoneyFrame:GetRegions() }) do
            if region.GetObjectType and region:GetObjectType() == "FontString" then
                region:SetFont(STANDARD_TEXT_FONT, theme.Font.assist, ""); region:SetTextColor(unpack(theme.Colors.muted))
            end
        end
    end
    local bar = _G.MailEditBoxScrollBar or _G.SendMailScrollFrameScrollBar
    if bar then
        if wrapper then
            bar:ClearAllPoints(); bar:SetPoint("TOPLEFT", wrapper, "TOPRIGHT", 4, -2); bar:SetPoint("BOTTOMLEFT", wrapper, "BOTTOMRIGHT", 4, 2)
            bar:SetWidth(14); bar:SetFrameLevel(wrapper:GetFrameLevel() + 2)
        end
        StripNativeArt(bar)
        StripNativeArt(bar.Track)
        local thumb = bar.ThumbTexture or (bar.GetThumbTexture and bar:GetThumbTexture())
        if thumb then thumb:SetColorTexture(unpack(theme.Colors.accent)); thumb:SetAlpha(1) end
        if bar.Thumb then
            StripNativeArt(bar.Thumb)
            if not bar.Thumb.yiboMailFill then
                bar.Thumb.yiboMailFill = bar.Thumb:CreateTexture(nil, "ARTWORK")
                bar.Thumb.yiboMailFill:SetAllPoints(); bar.Thumb.yiboMailFill:SetColorTexture(unpack(theme.Colors.accent))
            end
            bar.Thumb.yiboMailFill:SetAlpha(1)
        end
        for _, key in ipairs({ "ScrollUpButton", "ScrollDownButton", "Back", "Forward" }) do
            local button = bar[key]
            if button then
                StripNativeArt(button)
                if not button.yiboMailArrow then
                    button.yiboMailArrow = theme:CreateText(button, theme.Font.body, theme.Colors.muted, "CENTER")
                    button.yiboMailArrow:SetAllPoints(); button.yiboMailArrow:SetText((key == "ScrollUpButton" or key == "Back") and "↑" or "↓")
                end
            end
        end
    end
    if _G.SendMailFrameLockSendMail then SendMailFrameLockSendMail:SetFrameLevel(panel:GetFrameLevel() + 10) end
end
function Native:RefreshBodyScrollBar()
    local scroll = _G.MailEditBox and MailEditBox.ScrollBox or _G.SendMailScrollFrame
    local bar = _G.MailEditBoxScrollBar or _G.SendMailScrollFrameScrollBar or (scroll and scroll.ScrollBar)
    if not bar then return end
    local range = scroll and (scroll.GetDerivedScrollRange and scroll:GetDerivedScrollRange()
        or scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange()) or 0
    bar:SetShown(range > 0 and SendMailFrame:IsShown() and not (Addon.RuleSendUI and Addon.RuleSendUI.active))
end
function Native:InstallBodyScrollHooks()
    if not self.send or self.send.bodyScrollHooks then return end
    local scroll = _G.MailEditBox and MailEditBox.ScrollBox or _G.SendMailScrollFrame
    local bar = _G.MailEditBoxScrollBar or _G.SendMailScrollFrameScrollBar or (scroll and scroll.ScrollBar)
    local body = Addon.Compose:GetBodyEditBox()
    if not scroll or not bar or not body then return end
    self.send.bodyScrollHooks = true
    local function Refresh()
        Native:RefreshBodyScrollBar()
        if C_Timer and C_Timer.After then C_Timer.After(0, function() Native:RefreshBodyScrollBar() end) end
    end
    bar:HookScript("OnShow", function() Native:RefreshBodyScrollBar() end)
    scroll:HookScript("OnSizeChanged", Refresh)
    body:HookScript("OnTextChanged", Refresh)
    if _G.MailEditBox then
        if MailEditBox.SetBackdropBorderColor then MailEditBox:SetBackdropBorderColor(0, 0, 0, 0) end
        for _, key in ipairs({ "backdrop", "Backdrop", "BorderFrame" }) do
            local decoration = MailEditBox[key]
            if decoration and decoration.SetBackdropBorderColor then decoration:SetBackdropBorderColor(0, 0, 0, 0) end
        end
    end
end
function Native:LayoutSendAttachments()
    local columns, gap = 8, 4
    local count = ATTACHMENTS_MAX_SEND or 12
    local rows = math.ceil(count / columns)
    local size = math.min(36, (MailFrame:GetWidth() - 16 - gap * (columns - 1)) / columns)
    for index = 1, count do
        local button = _G["SendMailAttachment" .. index] or (SendMailFrame.SendMailAttachments and SendMailFrame.SendMailAttachments[index])
        if button then
            local row, column = math.floor((index - 1) / columns), (index - 1) % columns
            button:ClearAllPoints(); button:SetSize(size, size)
            button:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", 8 + column * (size + gap), 80 + (rows - row - 1) * (size + gap))
            self:StyleSendAttachment(button, index)
            button:Show()
        end
    end
    for index = count + 1, math.max(count, ATTACHMENTS_MAX or 16, #(SendMailFrame.SendMailAttachments or {})) do
        local button = _G["SendMailAttachment" .. index] or (SendMailFrame.SendMailAttachments and SendMailFrame.SendMailAttachments[index])
        if button then button:Hide() end
    end
    if SendMailScrollFrame and SendMailAttachment1 then
        SendMailScrollFrame:ClearAllPoints(); SendMailScrollFrame:SetPoint("TOPLEFT", MailFrame, "TOPLEFT", 8, -82)
        SendMailScrollFrame:SetPoint("BOTTOMRIGHT", SendMailAttachment1, "TOPLEFT", MailFrame:GetWidth() - 32, 10)
    end
    if _G.MailEditBox and SendMailAttachment1 then
        MailEditBox:ClearAllPoints(); MailEditBox:SetPoint("TOPLEFT", MailFrame, "TOPLEFT", 8, -82)
        MailEditBox:SetPoint("BOTTOMRIGHT", SendMailAttachment1, "TOPLEFT", MailFrame:GetWidth() - 32, 10)
    end
end
function Native:StyleSendAttachment(button, index)
    local theme = Addon.Core.UITheme
    button:SetFrameLevel(self.send:GetFrameLevel() + 2)
    StripNativeArt(button, true)
    local skin = button.yiboMailAttachment
    if not skin then
        skin = CreateFrame("Frame", nil, button, "BackdropTemplate")
        skin:SetAllPoints(button); skin:SetFrameLevel(button:GetFrameLevel() + 1); skin:EnableMouse(false)
        skin:SetBackdrop(BACKDROP); skin:SetBackdropColor(unpack(theme.Colors.panel))
        skin.icon = skin:CreateTexture(nil, "ARTWORK")
        skin.icon:SetPoint("TOPLEFT", 1, -1); skin.icon:SetPoint("BOTTOMRIGHT", -1, 1); skin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        skin.count = theme:CreateText(skin, theme.Font.assist, theme.Colors.text, "RIGHT")
        skin.count:SetPoint("BOTTOMRIGHT", -2, 2)
        button.yiboMailAttachment = skin
        button:HookScript("OnEnter", function() skin:SetBackdropBorderColor(unpack(theme.Colors.accent)) end)
        button:HookScript("OnLeave", function() skin:SetBackdropBorderColor(unpack(theme.Colors.lineSoft)) end)
    end
    local name, id, texture, quantity
    if GetSendMailItem then name, id, texture, quantity = GetSendMailItem(index) end
    skin.icon:SetTexture(name and texture or nil); skin.icon:SetShown(name ~= nil)
    skin.count:SetText(name and (quantity or 0) > 1 and tostring(quantity) or "")
    skin:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
end
function Native:LayoutSendMoney()
    local theme = Addon.Core.UITheme
    local money = _G.SendMailMoney
    if money then
        if money:GetParent() ~= self.send then money:SetParent(self.send) end
        money:SetFrameLevel(self.send:GetFrameLevel() + 2)
        money:ClearAllPoints(); money:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", 8, 44)
        for _, unit in ipairs({ "Gold", "Silver", "Copper" }) do
            local input = _G["SendMailMoney" .. unit] or money[unit:lower()] or money[unit]
            if input then
                StripNativeArt(input)
                local offset = unit == "Gold" and 0 or unit == "Silver" and 78 or 122
                input:ClearAllPoints(); input:SetPoint("LEFT", money, "LEFT", offset, 0)
                input:SetSize(unit == "Gold" and 58 or 24, theme.Size.compact)
                input:SetFont(STANDARD_TEXT_FONT, theme.Font.assist, ""); input:SetTextColor(unpack(theme.Colors.text)); input:SetTextInsets(4, 4, 0, 0)
                if input.texture then
                    input.texture:SetAlpha(1); input.texture:ClearAllPoints(); input.texture:SetPoint("LEFT", input, "RIGHT", 2, 0); input.texture:SetSize(13, 13)
                end
                if input.label then input.label:ClearAllPoints(); input.label:SetPoint("LEFT", input, "RIGHT", 2, 0) end
                if not input.yiboMailInput then
                    local surface = CreateFrame("Frame", nil, input:GetParent(), "BackdropTemplate")
                    surface:SetAllPoints(input); surface:SetFrameLevel(math.max(0, input:GetFrameLevel() - 1)); surface:EnableMouse(false)
                    surface:SetBackdrop(BACKDROP); surface:SetBackdropColor(unpack(theme.Colors.panel)); surface:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
                    input.yiboMailInput = surface
                end
            end
        end
    end
    if _G.SendMailMoneyText then _G.SendMailMoneyText:Hide() end
    local controls = { { "SendMailSendMoneyButton", "寄币", -132 }, { "SendMailCODButton", "到付", -66 } }
    for _, entry in ipairs(controls) do
        local control = _G[entry[1]]
        if control then
            if control:GetParent() ~= self.send then control:SetParent(self.send) end
            control:SetFrameLevel(self.send:GetFrameLevel() + 2)
            StripNativeArt(control)
            if not control.yiboMailRadio then
                local skin = CreateFrame("Frame", nil, control, "BackdropTemplate")
                skin:SetAllPoints(control); skin:EnableMouse(false); skin:SetBackdrop(BACKDROP)
                skin:SetBackdropColor(unpack(theme.Colors.panel)); skin:SetBackdropBorderColor(unpack(theme.Colors.lineSoft))
                skin.mark = skin:CreateTexture(nil, "ARTWORK"); skin.mark:SetPoint("TOPLEFT", 4, -4); skin.mark:SetPoint("BOTTOMRIGHT", -4, 4)
                skin.mark:SetColorTexture(unpack(theme.Colors.accent)); control.yiboMailRadio = skin
                control:HookScript("OnClick", function() Native:LayoutSendMoney() end)
            end
            control.yiboMailRadio.mark:SetShown(control.GetChecked and control:GetChecked() or false)
            control:ClearAllPoints(); control:SetSize(18, 18)
            control:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMRIGHT", entry[3], 48)
            local label = _G[entry[1] .. "Text"] or control.Text
            if label then
                if label:GetParent() ~= control then label:SetParent(control) end
                label:SetText(entry[2]); label:SetFont(STANDARD_TEXT_FONT, theme.Font.assist, "")
                label:ClearAllPoints(); label:SetPoint("LEFT", control, "RIGHT", 4, 0)
            end
        end
    end
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
    self:LayoutBasicSend()
    panel.contacts:SetText("")
    self:RefreshFavoriteButtons()
    Addon.RecipientUI:Refresh()
    self.refreshingSend = nil
end
function Native:RefreshSend()
    self:RefreshBasicSend()
    if Addon.RuleSendUI then Addon.RuleSendUI:Refresh() end
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
    -- Do not initialize or restyle Blizzard panels during login. In particular,
    -- leave hidden mailbox state untouched before GameMenu's logout callback.
    if not MailFrame:IsShown() then
        if not self.waitingForMailbox then
            self.waitingForMailbox = true
            MailFrame:HookScript("OnShow", function() Native:Install() end)
        end
        return
    end
    self.installed = true
    if Addon.FEATURES.send and hooksecurefunc and type(ContainerFrameItemButton_OnModifiedClick) == "function" then
        hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(button)
            if not button or not IsControlKeyDown or not IsControlKeyDown()
                or not SendMailFrame or not SendMailFrame:IsShown() or (CursorHasItem and CursorHasItem()) then return end
            local parent = button:GetParent()
            local bag = button.bagID or (parent and (parent:GetID() or parent.bagID))
            local slot = button:GetID()
            if bag == nil or not slot then return end
            local ok, message = Addon.Compose:AddMatchingBagItems(bag, slot)
            if self.send then self.send.notice = message; self:RefreshSend() end
        end)
    end
    if Addon.FEATURES.send and not Addon.FEATURES.sendAssist then
        StyleNativeActionButton(_G.SendMailMailButton or _G.SendMailSendButton, true)
        StyleNativeActionButton(SendMailCancelButton, false)
    end
    self:CreateInbox()
    if Addon.FEATURES.send then self:CreateBasicSend(); if Addon.RuleSendUI then Addon.RuleSendUI:Install() end end
    if Addon.FEATURES.send and hooksecurefunc and type(SendMailFrame_Update) == "function" then
        hooksecurefunc("SendMailFrame_Update", function() Native:LayoutBasicSend() end)
    end
    self:InstallMailboxTabs()
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
            if page == 1 or page == 2 then Native:RememberBrowsePage(page); Native:RefreshMailboxTabs() end
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
        if Addon.RuleSendUI then Addon.RuleSendUI:SetActive(false) end
        Native.deleting = nil
        Native.restorePagePending = nil
        Native:RememberBrowsePage()
        Native:RememberInboxFilters()
        Native.inbox.selection = {}
        Native.inbox.search:ClearFocus(); Native.inbox.filter.menu:Hide(); Native.inbox.menu.menu:Hide()
        if Native.send then
            Native.send.notice = nil; Native.send.contacts.menu:Hide()
        end
    end)
    Addon.Items.Events:Register(self, function() Native.deleting = nil; Native:Refresh() end)
    Addon.Frame:HookScript("OnUpdate", function()
        if Addon.RuleSendController then Addon.RuleSendController:Tick() end
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
        if self.send then
            self.send.notice = "发送成功。"
            if self.send.status then self.send.status:SetText("发送成功 · 已记录为在途，尚未确认送达") end
        end
    elseif event == "MAIL_FAILED" and self.send and self.send.status then
        self.send.status:SetText("发送未确认 · 请检查原生游戏提示")
    end
    if self.installed and (event == "MAIL_INBOX_UPDATE" or event == "MAIL_SUCCESS" or event == "MAIL_SHOW" or event == "MAIL_SEND_INFO_UPDATE" or event == "MAIL_SEND_SUCCESS" or event == "MAIL_FAILED" or event == "BAG_UPDATE_DELAYED") then self:Refresh() end
end
