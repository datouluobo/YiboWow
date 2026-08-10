local Core = _G.YiboCore

-- AccountView 是共享窗口壳。页面布局与业务数据仍由注册插件负责。
local AccountView = {}
Core.AccountView = AccountView
AccountView._pages = AccountView._pages or {}
AccountView._pageOrder = AccountView._pageOrder or {}

local COLORS = {
    bg = { 0.018, 0.045, 0.060, 0.98 },
    chrome = { 0.035, 0.105, 0.125, 1 },
    nav = { 0.028, 0.078, 0.094, 1 },
    selected = { 0.055, 0.23, 0.23, 1 },
    line = { 0.12, 0.42, 0.43, 0.85 },
    text = { 0.90, 0.96, 0.97 },
    muted = { 0.53, 0.70, 0.73 },
    accent = { 0.125, 0.88, 0.44 },
}

local function Copy(value)
    return Core.Defaults:Copy(value)
end

local function Settings()
    local db = Core.Database:GetDB()
    db.settings.accountView = db.settings.accountView or {}
    local settings = db.settings.accountView
    settings.pages = settings.pages or {}
    settings.fields = settings.fields or {}
    settings.hiddenCharacters = settings.hiddenCharacters or {}
    settings.characterSort = settings.characterSort or "seen"
    settings.width = tonumber(settings.width) or 1120
    settings.height = tonumber(settings.height) or 650
    settings.entry = settings.entry or {}
    settings.entry.minimap = settings.entry.minimap or { show = true, angle = 225 }
    settings.entry.broker = settings.entry.broker or { show = true }
    settings.entry.pageModes = settings.entry.pageModes or {}
    settings.entry.pagePositions = settings.entry.pagePositions or {}
    return settings
end

function AccountView:GetSettings()
    return Settings()
end

function AccountView:ResetWindowLayout()
    local settings = Settings()
    settings.point, settings.relativePoint, settings.x, settings.y = "CENTER", "CENTER", 0, 0
    settings.width, settings.height = 1120, 650
    if self.frame then self:ApplyNormalLayout() end
end

local function AddText(parent, template, size, color)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    if size then text:SetFont(STANDARD_TEXT_FONT, size) end
    if color then text:SetTextColor(color[1], color[2], color[3]) end
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    return text
end

local function CreateChromeButton(parent, width, height, label, destructive)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    button:SetBackdropColor(0.035, 0.105, 0.125, 0.98)
    button:SetBackdropBorderColor(destructive and 0.70 or COLORS.line[1], destructive and 0.20 or COLORS.line[2], destructive and 0.20 or COLORS.line[3], 0.9)
    button.label = AddText(button, "GameFontNormalSmall", nil, destructive and { 1, 0.55, 0.55 } or COLORS.text)
    button.label:SetPoint("CENTER")
    button.SetText = function(self, text) self.label:SetText(text) end
    button:SetText(label or "")
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(destructive and 0.20 or COLORS.selected[1], destructive and 0.055 or COLORS.selected[2], destructive and 0.055 or COLORS.selected[3], 1)
    end)
    button:SetScript("OnLeave", function(self) self:SetBackdropColor(0.035, 0.105, 0.125, 0.98) end)
    return button
end

local function PageEnabled(page)
    if page.internal then return true end
    local saved = Settings().pages[page.id]
    return saved == nil and page.defaultEnabled ~= false or saved == true
end

local function SortPages(left, right)
    if (left.order or 100) ~= (right.order or 100) then
        return (left.order or 100) < (right.order or 100)
    end
    return left.title < right.title
end

function AccountView:RegisterPage(addonName, definition)
    if type(addonName) ~= "string" or type(definition) ~= "table" then
        return nil, "页面注册参数无效。"
    end
    if type(definition.id) ~= "string" or definition.id == "" or type(definition.title) ~= "string" then
        return nil, "页面必须提供 id 和 title。"
    end
    if type(definition.Create) ~= "function" or type(definition.Refresh) ~= "function" then
        return nil, "页面必须提供 Create 与 Refresh。"
    end
    if definition.settings ~= nil and type(definition.settings) ~= "table" then
        return nil, "页面 settings 必须是 table。"
    end
    if type(definition.settings) == "table" and definition.settings.title ~= nil and type(definition.settings.title) ~= "string" then
        return nil, "页面 settings.title 必须是 string。"
    end
    if type(definition.settings) == "table" and definition.settings.description ~= nil and type(definition.settings.description) ~= "string" then
        return nil, "页面 settings.description 必须是 string。"
    end
    if type(definition.settings) == "table" and definition.settings.openLabel ~= nil and type(definition.settings.openLabel) ~= "string" then
        return nil, "页面 settings.openLabel 必须是 string。"
    end
    if type(definition.settings) == "table" and definition.settings.OpenAddonSettings ~= nil and type(definition.settings.OpenAddonSettings) ~= "function" then
        return nil, "页面 settings.OpenAddonSettings 必须是 function。"
    end
    local fieldIDs = {}
    for _, field in ipairs(definition.fields or {}) do
        if type(field.id) ~= "string" or field.id == "" then return nil, "页面字段必须提供 id。" end
        if fieldIDs[field.id] then return nil, "页面字段 ID 重复: " .. field.id end
        fieldIDs[field.id] = true
    end
    if self._pages[definition.id] then
        return nil, "页面 ID 已被占用: " .. definition.id
    end
    local page = Copy(definition)
    page.addonName = addonName
    page.fields = page.fields or {}
    self._pages[page.id] = page
    self._pageOrder[#self._pageOrder + 1] = page
    table.sort(self._pageOrder, SortPages)
    if self.frame and self.frame:IsShown() then self:RefreshNavigation() end
    Core.Events:Fire("ACCOUNT_VIEW_PAGE_REGISTERED", page.id, addonName)
    return page
end

function AccountView:UnregisterPage(pageID)
    local page = self._pages[pageID]
    if not page or page.internal then return false end
    self._pages[pageID] = nil
    for index = #self._pageOrder, 1, -1 do
        if self._pageOrder[index].id == pageID then table.remove(self._pageOrder, index) end
    end
    if self.frame and self.frame.instances[pageID] then self.frame.instances[pageID]:Hide() end
    if self.activePageID == pageID then self.activePageID = "overview" end
    self:RefreshPage()
    Core.Events:Fire("ACCOUNT_VIEW_PAGE_UNREGISTERED", pageID, page.addonName)
    return true
end

local function PageError(instance, page, phase, errorMessage)
    page.lastError = tostring(errorMessage)
    Core:Print("账号视图页面 “" .. page.title .. "” " .. phase .. " 失败：" .. page.lastError)
    if not instance.errorText then
        instance.errorText = AddText(instance, "GameFontNormal", nil, { 1, 0.48, 0.5 })
        instance.errorText:SetPoint("TOPLEFT", 20, -20); instance.errorText:SetPoint("TOPRIGHT", -20, -20)
        instance.errorText:SetJustifyV("TOP"); instance.errorText:SetWordWrap(true)
    end
    instance.errorText:SetText("此页面暂时无法显示。\n" .. page.lastError)
    instance.errorText:Show()
end

local function CallPage(instance, page, phase, context)
    local callback = phase == "创建" and page.Create or page.Refresh
    local ok, errorMessage = xpcall(function() callback(instance, context) end, function(message) return tostring(message) end)
    if not ok then PageError(instance, page, phase, errorMessage); return false end
    if instance.errorText then instance.errorText:Hide() end
    page.lastError = nil
    return true
end

function AccountView:GetFieldVisible(pageID, field, overrides)
    local fieldID = type(field) == "table" and field.id or field
    if overrides and overrides[fieldID] ~= nil then
        return overrides[fieldID] == true
    end
    local default = type(field) == "table" and field.defaultVisible ~= false or true
    local saved = Settings().fields[pageID] and Settings().fields[pageID][fieldID]
    return saved == nil and default or saved == true
end

function AccountView:SetFieldVisible(pageID, fieldID, visible)
    local fields = Settings().fields
    fields[pageID] = fields[pageID] or {}
    fields[pageID][fieldID] = not not visible
    self:RefreshPage()
end

local function GetPreviewFieldVisible(page, field)
    local fields = type(page.GetPreviewFields) == "function" and page.GetPreviewFields() or page.previewFields
    return type(fields) == "table" and fields[field.id] == true
end

function AccountView:GetVisibleFields(pageID, overrides)
    local page = self._pages[pageID]
    local visible = {}
    for _, field in ipairs(page and page.fields or {}) do
        if self:GetFieldVisible(pageID, field, overrides) then visible[#visible + 1] = Copy(field) end
    end
    return visible
end

function AccountView:GetVisibleCharacters()
    local hidden = Settings().hiddenCharacters
    local visible = {}
    for _, character in ipairs(Core.Characters:GetAll()) do
        if not hidden[character.id] then visible[#visible + 1] = character end
    end
    local sort = Settings().characterSort
    if sort == "name" then
        table.sort(visible, function(left, right) return tostring(left.name) < tostring(right.name) end)
    elseif sort == "level" then
        table.sort(visible, function(left, right)
            if (left.level or 0) ~= (right.level or 0) then return (left.level or 0) > (right.level or 0) end
            return tostring(left.name) < tostring(right.name)
        end)
    end
    return visible
end

function AccountView:SetCharacterHidden(characterID, hidden)
    Settings().hiddenCharacters[characterID] = not not hidden
    self:RefreshPage()
end

function AccountView:CreateFrame()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "YiboCoreAccountView", UIParent, "BackdropTemplate")
    local settings = Settings()
    frame:SetSize(settings.width, settings.height)
    frame:SetPoint(settings.point or "CENTER", UIParent, settings.relativePoint or "CENTER", settings.x or 0, settings.y or 0)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetMinResize then frame:SetMinResize(760, 430) end
    if frame.SetMaxResize then frame:SetMaxResize(1600, 1000) end
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        settings.point, settings.relativePoint, settings.x, settings.y = point, relativePoint, x, y
    end)
    frame:SetScript("OnSizeChanged", function(self, width, height)
        if not self.preview and width >= 760 and height >= 430 then
            settings.width, settings.height = math.floor(width + 0.5), math.floor(height + 0.5)
            if AccountView.activePageID == "characters" and self:IsShown() then AccountView:RefreshPage() end
        end
    end)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    frame:SetBackdropColor(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], COLORS.bg[4])
    frame:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], COLORS.line[4])

    frame.top = frame:CreateTexture(nil, "BACKGROUND")
    frame.top:SetPoint("TOPLEFT", 1, -1); frame.top:SetPoint("TOPRIGHT", -1, -1); frame.top:SetHeight(46)
    frame.top:SetColorTexture(COLORS.chrome[1], COLORS.chrome[2], COLORS.chrome[3], COLORS.chrome[4])
    frame.brand = AddText(frame, "GameFontNormalLarge", nil, COLORS.accent)
    frame.brand:SetPoint("TOPLEFT", 16, -13); frame.brand:SetText("[Yibo]")
    frame.title = AddText(frame, "GameFontNormalLarge", nil, COLORS.text)
    frame.title:SetPoint("LEFT", frame.brand, "RIGHT", 9, 0); frame.title:SetText("账号总览")
    frame.subtitle = AddText(frame, "GameFontNormalSmall", nil, COLORS.muted)
    frame.subtitle:SetPoint("LEFT", frame.title, "RIGHT", 12, 0); frame.subtitle:SetText("多角色状态")
    frame.settingsButton = CreateChromeButton(frame, 62, 22, "设置")
    frame.settingsButton:SetPoint("TOPRIGHT", -42, -12)
    frame.settingsButton:SetScript("OnClick", function() AccountView:ShowSettings() end)
    frame.close = CreateChromeButton(frame, 22, 22, "×", true)
    frame.close:SetPoint("TOPRIGHT", -14, -12)
    frame.close:SetScript("OnClick", function() frame:Hide() end)
    frame.resize = CreateFrame("Button", nil, frame)
    frame.resize:SetSize(18, 18); frame.resize:SetPoint("BOTTOMRIGHT", -3, 3)
    frame.resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    frame.resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    frame.resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    frame.resize:SetScript("OnMouseDown", function() if not frame.preview then frame:StartSizing("BOTTOMRIGHT") end end)
    frame.resize:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)

    frame.nav = CreateFrame("Frame", nil, frame)
    frame.nav:SetPoint("TOPLEFT", 1, -47); frame.nav:SetPoint("BOTTOMLEFT", 1, 1); frame.nav:SetWidth(176)
    frame.nav.bg = frame.nav:CreateTexture(nil, "BACKGROUND"); frame.nav.bg:SetAllPoints(); frame.nav.bg:SetColorTexture(COLORS.nav[1], COLORS.nav[2], COLORS.nav[3], COLORS.nav[4])
    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", frame.nav, "TOPRIGHT", 1, 0); frame.content:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.navButtons, frame.instances = {}, {}
    frame:Hide()
    self.frame = frame
    return frame
end

function AccountView:SetPreviewHoverCallbacks(onEnter, onLeave)
    self.previewOnEnter, self.previewOnLeave = onEnter, onLeave
    if self.frame then
        self.frame:SetScript("OnEnter", onEnter)
        self.frame:SetScript("OnLeave", onLeave)
    end
end

function AccountView:RefreshNavigation()
    local frame = self:CreateFrame()
    if frame.preview then return end
    local pages = {}
    if self.activePageID == "settings" then
        pages[#pages + 1] = { id = "overview", title = "‹ 返回账号视图" }
        pages[#pages + 1] = { id = "settings-general", title = "通用", settingsTargetID = "general" }
        for _, page in ipairs(self._pageOrder) do
            if not page.internal then pages[#pages + 1] = { id = "settings-" .. page.id, title = page.title, settingsTargetID = page.id } end
        end
    else
        pages = { self._pages.overview, self._pages.characters }
        for _, page in ipairs(self._pageOrder) do if PageEnabled(page) then pages[#pages + 1] = page end end
    end
    for index, page in ipairs(pages) do
        local button = frame.navButtons[index]
        if not button then
            button = CreateFrame("Button", nil, frame.nav, "BackdropTemplate")
            button:SetHeight(30); button:SetPoint("TOPLEFT", 8, -10 - ((index - 1) * 34)); button:SetPoint("TOPRIGHT", -8, -10 - ((index - 1) * 34))
            button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            button.label = AddText(button, "GameFontNormalSmall", nil, COLORS.text); button.label:SetPoint("LEFT", 9, 0); button.label:SetPoint("RIGHT", -6, 0)
            button:SetScript("OnClick", function(self)
                if self.settingsTargetID then AccountView:SelectSettingsTarget(self.settingsTargetID) else AccountView:ShowPage(self.pageID) end
            end)
            frame.navButtons[index] = button
        end
        button.pageID = page.id; button.settingsTargetID = page.settingsTargetID; button.label:SetText(page.title)
        local selected = page.settingsTargetID and self.activePageID == "settings" and self.settingsTargetPageID == page.settingsTargetID or self.activePageID == page.id
        button:SetBackdropColor(selected and COLORS.selected[1] or 0, selected and COLORS.selected[2] or 0, selected and COLORS.selected[3] or 0, selected and 1 or 0)
        button:Show()
    end
    for index = #pages + 1, #frame.navButtons do frame.navButtons[index]:Hide() end
end

function AccountView:BuildContext(page, options)
    options = options or {}
    local overrides = options.fieldOverrides
    local characters = self:GetVisibleCharacters()
    -- 悬停预览是正式账号视图的投影，但不应成为可滚动的小窗口。
    -- 统一限定为前 20 名有效角色，保证业务页可按固定行高一次排完。
    if options.preview then
        local limit = math.max(1, math.floor(tonumber(options.characterLimit) or 20))
        if #characters > limit then
            local limited = {}
            for index = 1, limit do limited[index] = characters[index] end
            characters = limited
        end
    end
    return {
        page = page,
        characters = characters,
        fields = self:GetVisibleFields(page.id, overrides),
        GetFieldVisible = function(_, field) return self:GetFieldVisible(page.id, field, overrides) end,
        Refresh = function() self:RefreshPage() end,
        preview = options.preview == true,
    }
end

function AccountView:ShowPage(pageID, options)
    local page = self._pages[pageID] or self._pages.overview
    if not page or (not page.internal and not PageEnabled(page)) then page = self._pages.overview end
    self:CreateFrame()
    for id, instance in pairs(self.frame.instances) do if id ~= page.id then instance:Hide() end end
    local instance = self.frame.instances[page.id]
    if not instance then
        instance = CreateFrame("Frame", nil, self.frame.content)
        instance:SetAllPoints(self.frame.content)
        self.frame.instances[page.id] = instance
        CallPage(instance, page, "创建", self:BuildContext(page, options))
    end
    self.activePageID = page.id
    instance:Show()
    self.activePageOptions = options
    CallPage(instance, page, "刷新", self:BuildContext(page, options))
    self:RefreshNavigation()
end

function AccountView:RefreshPage()
    if self.frame and self.frame:IsShown() and self.activePageID then self:ShowPage(self.activePageID, self.activePageOptions) end
end

function AccountView:NotifyPageChanged(pageID)
    if self.activePageID == pageID then self:RefreshPage() end
end

function AccountView:GetRegisteredPages()
    local pages = {}
    for _, page in ipairs(self._pageOrder) do pages[#pages + 1] = page end
    return pages
end

function AccountView:ApplyNormalLayout()
    local frame = self:CreateFrame()
    local settings = Settings()
    frame.preview = false
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", nil)
    frame:SetScript("OnLeave", nil)
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(settings.width, settings.height)
    frame:ClearAllPoints()
    frame:SetPoint(settings.point or "CENTER", UIParent, settings.relativePoint or "CENTER", settings.x or 0, settings.y or 0)
    frame.nav:Show(); frame.settingsButton:Show(); frame.close:Show(); frame.resize:Show()
    frame.title:SetText("账号总览")
    frame.subtitle:SetText("多角色状态")
    frame.content:ClearAllPoints()
    frame.content:SetPoint("TOPLEFT", frame.nav, "TOPRIGHT", 1, 0)
    frame.content:SetPoint("BOTTOMRIGHT", -1, 1)
end

function AccountView:GetPreviewPage()
    local active = self._pages[self.activePageID]
    if active and active.previewEnabled and PageEnabled(active) then return active end
    for _, page in ipairs(self._pageOrder) do
        if page.previewEnabled and PageEnabled(page) then return page end
    end
end

function AccountView:ShowPreview(pageID, anchor)
    local page = self._pages[pageID] or self:GetPreviewPage()
    local frame = self:CreateFrame()
    if not page or (not page.internal and not PageEnabled(page)) or (frame:IsShown() and not frame.preview) then return end

    local fields = type(page.GetPreviewFields) == "function" and page.GetPreviewFields() or page.previewFields
    local context = self:BuildContext(page, { preview = true, fieldOverrides = fields })
    local width, height = 820, 360
    if type(page.GetPreviewSize) == "function" then width, height = page.GetPreviewSize(context) end
    local screenWidth = (GetScreenWidth and GetScreenWidth()) or UIParent:GetWidth() or width
    local screenHeight = (GetScreenHeight and GetScreenHeight()) or UIParent:GetHeight() or height
    width = math.max(420, math.min(tonumber(width) or 820, screenWidth - 32))
    height = math.max(150, math.min(tonumber(height) or 360, screenHeight - 80))

    frame.preview = true
    frame:SetMovable(false)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", self.previewOnEnter)
    frame:SetScript("OnLeave", self.previewOnLeave)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetSize(width, height)
    frame:ClearAllPoints()
    local anchorFrame = anchor and type(anchor.GetLeft) == "function" and anchor or nil
    if anchorFrame then
        local left, right = anchorFrame:GetLeft(), anchorFrame:GetRight()
        local top, bottom = anchorFrame:GetTop(), anchorFrame:GetBottom()
        local alignRight = right and right > screenWidth - width
        local hasRoomBelow = bottom and (bottom - height - 8) >= 0
        if hasRoomBelow then
            frame:SetPoint(alignRight and "TOPRIGHT" or "TOPLEFT", anchorFrame, alignRight and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, -8)
        else
            frame:SetPoint(alignRight and "BOTTOMRIGHT" or "BOTTOMLEFT", anchorFrame, alignRight and "TOPRIGHT" or "TOPLEFT", 0, 8)
        end
    else
        frame:SetPoint("CENTER", UIParent, "CENTER")
    end
    frame.nav:Hide(); frame.settingsButton:Hide(); frame.close:Hide(); frame.resize:Hide()
    frame.content:ClearAllPoints()
    frame.content:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -47)
    frame.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.title:SetText(page.title); frame.subtitle:SetText("账号角色预览")
    frame:Show()
    self:ShowPage(page.id, { preview = true, fieldOverrides = fields })
end

function AccountView:HidePreview()
    local frame = self.frame
    if not frame or not frame.preview then return end
    frame:Hide()
    self:ApplyNormalLayout()
    self.activePageOptions = nil
end

function AccountView:Toggle(pageID)
    local frame = self:CreateFrame()
    if frame.preview then
        self:HidePreview()
        frame:Show()
        self:ShowPage(pageID or self.activePageID or "overview")
        return
    end
    if frame:IsShown() and not pageID then frame:Hide(); return end
    frame:Show(); self:ShowPage(pageID or self.activePageID or "overview")
end

function AccountView:ShowSettings()
    if self.activePageID and self.activePageID ~= "settings" then
        local active = self._pages[self.activePageID]
        self.settingsTargetPageID = active and not active.internal and active.id or "general"
    end
    self:Toggle("settings")
end

function AccountView:SelectSettingsTarget(targetID)
    if targetID ~= "general" then
        local page = self._pages[targetID]
        if not page or page.internal then return false end
    end
    self.settingsTargetPageID = targetID
    if self.activePageID == "settings" then self:RefreshPage() end
    return true
end

local function CreateOverview(parent)
    parent.heading = AddText(parent, "GameFontNormalLarge", nil, COLORS.text); parent.heading:SetPoint("TOPLEFT", 20, -18); parent.heading:SetText("账号概览")
    parent.hint = AddText(parent, "GameFontNormalSmall", nil, COLORS.muted); parent.hint:SetPoint("TOPLEFT", 20, -47); parent.hint:SetText("从左侧选择业务页，比较角色的下一步行动。")
    parent.characterSummary = AddText(parent, "GameFontNormalSmall", nil, COLORS.muted); parent.characterSummary:SetPoint("TOPRIGHT", -20, -18)
    parent.actionHeading = AddText(parent, "GameFontNormalSmall", nil, COLORS.muted); parent.actionHeading:SetPoint("TOPLEFT", 20, -78); parent.actionHeading:SetText("下一步行动")
    parent.lines = {}
    parent.actions = {}
end

local function RefreshOverview(parent)
    local lines = {}
    local actions = {}
    local allCharacters = Core.Characters:GetAll()
    local visibleCharacters = AccountView:GetVisibleCharacters()
    parent.characterSummary:SetText(string.format("已记录 %d 名角色 · 视图显示 %d 名", #allCharacters, #visibleCharacters))
    for _, page in ipairs(AccountView._pageOrder) do
        if PageEnabled(page) and type(page.GetSummary) == "function" then
            local summary = page.GetSummary(AccountView:GetVisibleCharacters())
            if summary and summary ~= "" then lines[#lines + 1] = { title = page.title, text = summary, pageID = page.id } end
        end
        if PageEnabled(page) and type(page.GetActions) == "function" then
            for _, action in ipairs(page.GetActions(AccountView:GetVisibleCharacters()) or {}) do
                action.pageID = page.id
                action.pageTitle = page.title
                actions[#actions + 1] = action
            end
        end
    end
    table.sort(actions, function(left, right)
        if (left.priority or 0) ~= (right.priority or 0) then return (left.priority or 0) > (right.priority or 0) end
        return tostring(left.title) < tostring(right.title)
    end)
    for index, line in ipairs(lines) do
        local button = parent.lines[index]
        if not button then
            button = CreateFrame("Button", nil, parent, "BackdropTemplate"); button:SetHeight(38); button:SetPoint("TOPLEFT", 20, -104 - ((index - 1) * 42)); button:SetPoint("TOPRIGHT", -20, -104 - ((index - 1) * 42))
            button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); button:SetBackdropColor(0.03, 0.10, 0.12, 0.85); button:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.45)
            button.title = AddText(button, "GameFontNormalSmall", nil, COLORS.accent); button.title:SetPoint("LEFT", 10, 0); button.title:SetWidth(125)
            button.text = AddText(button, "GameFontNormalSmall", nil, COLORS.text); button.text:SetPoint("LEFT", button.title, "RIGHT", 8, 0); button.text:SetPoint("RIGHT", -10, 0)
            button:SetScript("OnClick", function(self) AccountView:ShowPage(self.pageID) end); parent.lines[index] = button
        end
        button.title:SetText(line.title); button.text:SetText(line.text); button.pageID = line.pageID; button:Show()
    end
    for index = #lines + 1, #parent.lines do parent.lines[index]:Hide() end
    local actionBase = -112 - (#lines * 42)
    parent.actionHeading:ClearAllPoints(); parent.actionHeading:SetPoint("TOPLEFT", 20, actionBase)
    local visibleActionCount = math.min(#actions, 8)
    parent.actionHeading:SetText(#actions > 0 and ("下一步行动（显示 " .. visibleActionCount .. " / " .. #actions .. "）") or "暂无需要处理的账号行动")
    for index = 1, visibleActionCount do
        local action = actions[index]
        local button = parent.actions[index]
        if not button then
            button = CreateFrame("Button", nil, parent, "BackdropTemplate"); button:SetHeight(34)
            button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); button:SetBackdropColor(0.035, 0.12, 0.12, 0.9); button:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.45)
            button.title = AddText(button, "GameFontNormalSmall", nil, COLORS.text); button.title:SetPoint("LEFT", 9, 0); button.title:SetWidth(210)
            button.text = AddText(button, "GameFontNormalSmall", nil, COLORS.muted); button.text:SetPoint("LEFT", button.title, "RIGHT", 8, 0); button.text:SetPoint("RIGHT", -9, 0)
            button:SetScript("OnClick", function(self) AccountView:ShowPage(self.pageID) end); parent.actions[index] = button
        end
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", 20, actionBase - 24 - ((index - 1) * 38)); button:SetPoint("TOPRIGHT", -20, actionBase - 24 - ((index - 1) * 38))
        button.title:SetText((action.pageTitle or "业务") .. " · " .. (action.title or "角色")); button.text:SetText(action.text or "")
        button.pageID = action.pageID; button:Show()
    end
    for index = visibleActionCount + 1, #parent.actions do parent.actions[index]:Hide() end
end

local function CreateCharacters(parent)
    parent.heading = AddText(parent, "GameFontNormalLarge", nil, COLORS.text); parent.heading:SetPoint("TOPLEFT", 20, -18); parent.heading:SetText("角色档案")
    parent.hint = AddText(parent, "GameFontNormalSmall", nil, COLORS.muted); parent.hint:SetPoint("TOPLEFT", 20, -47); parent.hint:SetText("角色概况会自动保存；隐藏仅影响账号业务视图。")
    parent.search = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    parent.search:SetSize(174, 20); parent.search:SetPoint("TOPRIGHT", -20, -47); parent.search:SetAutoFocus(false); parent.search:SetMaxLetters(48)
    parent.search:SetTextInsets(7, 7, 0, 0); parent.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    parent.search:SetScript("OnTextChanged", function(self, userInput)
        if userInput then parent.resetScroll = true; AccountView:RefreshPage() end
    end)
    parent.searchLabel = AddText(parent, "GameFontNormalSmall", nil, COLORS.muted); parent.searchLabel:SetPoint("RIGHT", parent.search, "LEFT", -6, 0); parent.searchLabel:SetText("搜索")
    parent.filter = CreateChromeButton(parent, 100, 20, "仅缺少档案")
    parent.filter:SetPoint("TOPRIGHT", -142, -18)
    parent.filter:SetScript("OnClick", function()
        parent.showMissingOnly = not parent.showMissingOnly; parent.resetScroll = true; AccountView:RefreshPage()
    end)
    parent.sort = CreateChromeButton(parent, 116, 20, "排序")
    parent.sort:SetPoint("TOPRIGHT", -20, -18)
    parent.sort:SetScript("OnClick", function()
        local settings = Settings()
        settings.characterSort = settings.characterSort == "seen" and "name" or (settings.characterSort == "name" and "level" or "seen")
        parent.resetScroll = true; AccountView:RefreshPage()
    end)
    parent.listHeader = CreateFrame("Frame", nil, parent)
    parent.listHeader:SetPoint("TOPLEFT", 20, -82); parent.listHeader:SetPoint("TOPRIGHT", -40, -82); parent.listHeader:SetHeight(22)
    parent.listHeader.bg = parent.listHeader:CreateTexture(nil, "BACKGROUND"); parent.listHeader.bg:SetAllPoints(); parent.listHeader.bg:SetColorTexture(COLORS.chrome[1], COLORS.chrome[2], COLORS.chrome[3], 0.95)
    parent.listHeader.name = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.name:SetPoint("LEFT", 9, 0); parent.listHeader.name:SetWidth(246); parent.listHeader.name:SetText("角色")
    parent.listHeader.level = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.level:SetPoint("LEFT", parent.listHeader.name, "RIGHT", 6, 0); parent.listHeader.level:SetWidth(32); parent.listHeader.level:SetText("等级")
    parent.listHeader.zone = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.zone:SetPoint("LEFT", parent.listHeader.level, "RIGHT", 6, 0); parent.listHeader.zone:SetWidth(78); parent.listHeader.zone:SetText("地点")
    parent.listHeader.itemLevel = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.itemLevel:SetPoint("LEFT", parent.listHeader.zone, "RIGHT", 6, 0); parent.listHeader.itemLevel:SetWidth(42); parent.listHeader.itemLevel:SetText("装等")
    parent.listHeader.professions = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.professions:SetPoint("LEFT", parent.listHeader.itemLevel, "RIGHT", 6, 0); parent.listHeader.professions:SetText("专业")
    parent.listHeader.hide = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.hide:SetPoint("RIGHT", -9, 0); parent.listHeader.hide:SetText("隐藏")
    parent.scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    parent.scroll:SetPoint("TOPLEFT", 20, -106); parent.scroll:SetPoint("BOTTOMRIGHT", -40, 12)
    parent.listContent = CreateFrame("Frame", nil, parent.scroll)
    parent.listContent:SetWidth(850)
    parent.scroll:SetScrollChild(parent.listContent)
    parent.rows = {}
end

local function RefreshCharacters(parent)
    local current = Core.Characters:GetCurrent()
    local characters = Core.Characters:GetAll()
    local query = string.lower(parent.search:GetText() or "")
    local filtered = {}
    for _, character in ipairs(characters) do
        local profile = character.profile or {}
        local hasProfile = profile.zone or profile.itemLevel or #(profile.professions or {}) > 0
        local identity = string.lower((character.name or "") .. " " .. (character.realm or ""))
        if (not parent.showMissingOnly or not hasProfile) and (query == "" or string.find(identity, query, 1, true)) then
            filtered[#filtered + 1] = character
        end
    end
    local sort = Settings().characterSort
    if sort == "name" then
        table.sort(filtered, function(left, right) return tostring(left.name) < tostring(right.name) end)
    elseif sort == "level" then
        table.sort(filtered, function(left, right)
            if (left.level or 0) ~= (right.level or 0) then return (left.level or 0) > (right.level or 0) end
            return tostring(left.name) < tostring(right.name)
        end)
    end
    parent.filter:SetText(parent.showMissingOnly and "显示全部" or "仅缺少档案")
    local sortLabels = { seen = "最近登录", name = "角色名称", level = "角色等级" }
    parent.sort:SetText("排序：" .. (sortLabels[sort] or "最近登录"))
    parent.hint:SetText("共 " .. #filtered .. " / " .. #characters .. " 名角色 · 排序：" .. (sortLabels[sort] or "最近登录"))
    local previousScroll = parent.resetScroll and 0 or parent.scroll:GetVerticalScroll()
    local contentWidth = parent.scroll:GetWidth() or 0
    if contentWidth <= 0 then contentWidth = 850 end
    parent.listContent:SetWidth(contentWidth)
    local nameWidth = math.max(132, math.min(190, math.floor(contentWidth * 0.18)))
    local levelWidth = 32
    local zoneWidth = math.max(62, math.min(78, math.floor(contentWidth * 0.08)))
    local itemLevelWidth = 42
    parent.listHeader.name:SetWidth(nameWidth); parent.listHeader.level:SetWidth(levelWidth); parent.listHeader.zone:SetWidth(zoneWidth); parent.listHeader.itemLevel:SetWidth(itemLevelWidth)
    parent.listHeader.professions:SetPoint("RIGHT", parent.listHeader.hide, "LEFT", -8); parent.listHeader.professions:SetWordWrap(false)
    for index, character in ipairs(filtered) do
        local row = parent.rows[index]
        if not row then
            row = CreateFrame("Button", nil, parent.listContent, "BackdropTemplate"); row:SetHeight(30); row:SetPoint("TOPLEFT", 0, -((index - 1) * 34)); row:SetPoint("TOPRIGHT", 0, -((index - 1) * 34))
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" }); row.name = AddText(row, "GameFontNormalSmall", nil, COLORS.text); row.name:SetPoint("LEFT", 9, 0); row.name:SetWidth(246)
            row.level = AddText(row, "GameFontNormalSmall", nil, COLORS.text); row.level:SetPoint("LEFT", row.name, "RIGHT", 6, 0); row.level:SetWidth(32)
            row.zone = AddText(row, "GameFontNormalSmall", nil, COLORS.muted); row.zone:SetPoint("LEFT", row.level, "RIGHT", 6, 0); row.zone:SetWidth(78)
            row.itemLevel = AddText(row, "GameFontNormalSmall", nil, COLORS.muted); row.itemLevel:SetPoint("LEFT", row.zone, "RIGHT", 6, 0); row.itemLevel:SetWidth(42)
            row.professions = AddText(row, "GameFontNormalSmall", nil, COLORS.muted); row.professions:SetPoint("LEFT", row.itemLevel, "RIGHT", 6, 0); row.professions:SetPoint("RIGHT", -44, 0)
            row.name:SetWordWrap(false); row.zone:SetWordWrap(false); row.professions:SetWordWrap(false)
            row.hide = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate"); row.hide:SetPoint("RIGHT", -8, 0); row.hide:SetScript("OnClick", function(self) AccountView:SetCharacterHidden(self.characterID, self:GetChecked()) end)
            row:SetScript("OnEnter", function(self)
                if not self.fullInfo then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(self.fullInfo, COLORS.text[1], COLORS.text[2], COLORS.text[3], true); GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            parent.rows[index] = row
        end
        row.name:SetWidth(nameWidth); row.level:SetWidth(levelWidth); row.zone:SetWidth(zoneWidth); row.itemLevel:SetWidth(itemLevelWidth)
        local profile = character.profile or {}; local professions = {}
        for _, profession in ipairs(profile.professions or {}) do professions[#professions + 1] = (profession.name or "专业") .. " " .. tostring(profession.skillLevel or "?") end
        local isCurrent = current and current.id == character.id
        if isCurrent then
            row:SetBackdropColor(COLORS.selected[1], COLORS.selected[2], COLORS.selected[3], 0.92)
        elseif index % 2 == 0 then
            row:SetBackdropColor(0.025, 0.085, 0.10, 0.88)
        else
            row:SetBackdropColor(0.018, 0.060, 0.075, 0.88)
        end
        local nameText = character.name .. "-" .. character.realm
        local zoneText = profile.zone or "未知位置"
        local itemLevelText = profile.itemLevel and string.format("%.0f", profile.itemLevel) or "—"
        local professionText = #professions > 0 and table.concat(professions, " / ") or "未采集"
        row.name:SetText(nameText); row.level:SetText(tostring(character.level or "?")); row.zone:SetText(zoneText); row.itemLevel:SetText(itemLevelText); row.professions:SetText(professionText)
        row.fullInfo = nameText .. "\n等级 " .. tostring(character.level or "?") .. " · " .. zoneText .. " · 装等 " .. itemLevelText .. "\n专业：" .. professionText
        row.hide.characterID = character.id; row.hide:SetChecked(Settings().hiddenCharacters[character.id] == true); row:Show()
    end
    for index = #filtered + 1, #parent.rows do parent.rows[index]:Hide() end
    local contentHeight = #filtered * 34
    local viewportHeight = parent.scroll:GetHeight() or 500
    parent.listContent:SetHeight(math.max(contentHeight, viewportHeight))
    parent.scroll:SetVerticalScroll(math.min(previousScroll, parent.scroll:GetVerticalScrollRange()))
    parent.resetScroll = nil
    if parent.scroll.ScrollBar then parent.scroll.ScrollBar:SetShown(contentHeight > viewportHeight) end
end

local function CreateSettings(parent)
    parent.heading = AddText(parent, "GameFontNormalLarge", nil, COLORS.text); parent.heading:SetPoint("TOPLEFT", 20, -18)
    parent.hint = AddText(parent, "GameFontNormalSmall", nil, COLORS.muted); parent.hint:SetPoint("TOPLEFT", 20, -47)
    parent.resetLayout = CreateChromeButton(parent, 116, 22, "重置窗口布局")
    parent.resetLayout:SetPoint("TOPRIGHT", -20, -18)
    parent.resetLayout:SetScript("OnClick", function() AccountView:ResetWindowLayout() end)
    parent.sortButton = CreateChromeButton(parent, 150, 22, "角色排序")
    parent.sortButton:SetPoint("TOPRIGHT", parent.resetLayout, "BOTTOMRIGHT", 0, -6)
    parent.sortButton:SetScript("OnClick", function()
        local settings = Settings()
        settings.characterSort = settings.characterSort == "seen" and "name" or (settings.characterSort == "name" and "level" or "seen")
        AccountView:RefreshPage()
    end)
    parent.scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    parent.scroll:SetPoint("TOPLEFT", 20, -76); parent.scroll:SetPoint("BOTTOMRIGHT", -38, 14)
    parent.content = CreateFrame("Frame", nil, parent.scroll); parent.content:SetWidth(620); parent.scroll:SetScrollChild(parent.content)
    parent.rows = {}
end

local function SettingsRow(parent, index, kind)
    local row = parent.rows[index]
    if row and row.kind ~= kind then row:Hide(); row = nil end
    if not row then
        if kind == "check" then
            row = CreateFrame("CheckButton", nil, parent.content, "UICheckButtonTemplate")
            row.label = AddText(row, "GameFontNormalSmall", nil, COLORS.text); row.label:SetPoint("LEFT", row, "RIGHT", 2, 0); row.label:SetWidth(520)
        elseif kind == "heading" then
            row = AddText(parent.content, "GameFontNormal", nil, COLORS.accent)
        else
            row = CreateChromeButton(parent.content, 250, 22, "")
        end
        parent.rows[index] = row
    end
    row.kind = kind
    return row
end

local function PlaceSettingsRow(row, y)
    row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2, -y)
end

local function RefreshSettings(parent)
    local settings = Settings()
    local sortLabels = { seen = "最近登录", name = "角色名称", level = "角色等级" }
    parent.sortButton:SetText("角色排序：" .. (sortLabels[settings.characterSort] or "最近登录"))
    local selected = AccountView._pages[AccountView.settingsTargetPageID]
    local general = not selected or selected.internal
    if general then AccountView.settingsTargetPageID = "general" end
    parent.heading:SetText(general and "通用设置" or (selected.title .. "设置"))
    parent.hint:SetText(general and "统一管理窗口、角色范围与 Core 入口。" or "配置此插件的页面、独立入口和字段；业务进度仍由插件保存。")
    parent.resetLayout:SetShown(general); parent.sortButton:SetShown(general)

    local index, y = 0, 0
    local function Heading(text)
        index = index + 1; local row = SettingsRow(parent, index, "heading"); PlaceSettingsRow(row, y); row:SetText(text); row:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3]); row:Show(); y = y + 28
    end
    local function Check(label, checked, callback)
        index = index + 1; local row = SettingsRow(parent, index, "check"); PlaceSettingsRow(row, y); row.label:SetText(label); row:SetChecked(checked); row:SetScript("OnClick", function(self) callback(self:GetChecked()); AccountView:RefreshPage() end); row:Show(); y = y + 28
    end
    local function Button(label, callback, width)
        index = index + 1; local row = SettingsRow(parent, index, "button"); row:SetWidth(width or 250); PlaceSettingsRow(row, y); row:SetText(label); row:SetScript("OnClick", callback); row:Show(); y = y + 28
    end

    if general then
        Heading("账号视图")
        Button("重置窗口布局", function() AccountView:ResetWindowLayout() end)
        Button("角色排序：" .. (sortLabels[settings.characterSort] or "最近登录"), function()
            settings.characterSort = settings.characterSort == "seen" and "name" or (settings.characterSort == "name" and "level" or "seen")
            AccountView:RefreshPage()
        end)
        Heading("Core 入口")
        Check("显示 Core 小地图入口", settings.entry.minimap.show ~= false, function(checked)
            settings.entry.minimap.show = checked
            if Core.Entry then Core.Entry:Refresh() end
        end)
        Check("启用 Broker 入口（重载界面后生效）", settings.entry.broker.show ~= false, function(checked)
            settings.entry.broker.show = checked
        end)
    else
        local details = selected.settings or {}
        if details.description then
            local text = SettingsRow(parent, index + 1, "heading"); index = index + 1; PlaceSettingsRow(text, y); text:SetText(details.description); text:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3]); text:Show(); y = y + 28
        end
            Check("在账号视图中显示此页面", PageEnabled(selected), function(checked) settings.pages[selected.id] = checked end)
            local entry = Core.Entry and Core.Entry.GetBusinessEntryByPageID and Core.Entry:GetBusinessEntryByPageID(selected.id)
            if entry then
                Heading("独立入口")
                for _, mode in ipairs({ "none", "broker", "minimap", "both" }) do
                    Button((Core.Entry:GetBusinessEntryMode(entry.id) == mode and "● " or "○ ") .. Core.Entry:GetBusinessEntryModeLabel(mode), function()
                        settings.entry.pageModes[entry.id] = mode; Core.Entry:Refresh(); AccountView:RefreshPage()
                    end, 210)
                end
            end
            if #selected.fields > 0 then
                Heading("主表字段")
                for _, field in ipairs(selected.fields) do
                    Check(field.title, AccountView:GetFieldVisible(selected.id, field), function(checked) AccountView:SetFieldVisible(selected.id, field.id, checked) end)
                end
            end
            if selected.previewEnabled and type(selected.SetPreviewFieldVisible) == "function" then
                Heading("悬停预览字段")
                for _, field in ipairs(selected.fields) do
                    Check(field.title, GetPreviewFieldVisible(selected, field), function(checked) selected.SetPreviewFieldVisible(field.id, checked) end)
                end
            end
            if type(details.OpenAddonSettings) == "function" then
                Heading("插件专属设置")
                Button(details.openLabel or "打开详细设置", function()
                    local ok, errorMessage = xpcall(details.OpenAddonSettings, function(message) return tostring(message) end)
                    if not ok then Core:Print("插件 “" .. selected.title .. "” 的设置打开失败：" .. errorMessage) end
                end)
            end
    end
    for stale = index + 1, #parent.rows do parent.rows[stale]:Hide() end
    parent.content:SetHeight(math.max(y + 8, parent.scroll:GetHeight() or 1))
    if parent.scroll.ScrollBar then parent.scroll.ScrollBar:SetShown(y > (parent.scroll:GetHeight() or 0)) end
end

AccountView._pages.overview = { id = "overview", title = "概览", order = -20, internal = true, Create = CreateOverview, Refresh = RefreshOverview }
AccountView._pages.characters = { id = "characters", title = "角色档案", order = -10, internal = true, Create = CreateCharacters, Refresh = RefreshCharacters }
AccountView._pages.settings = { id = "settings", title = "设置", order = 999, internal = true, Create = CreateSettings, Refresh = RefreshSettings }
Core.Capabilities:Register("account-view", 1)
