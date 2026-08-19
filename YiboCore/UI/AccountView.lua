local Core = _G.YiboCore

-- AccountView 是共享窗口壳。页面布局与业务数据仍由注册插件负责。
local AccountView = {}
Core.AccountView = AccountView
AccountView._pages = AccountView._pages or {}
AccountView._pageOrder = AccountView._pageOrder or {}

local Theme = Core.UITheme
local COLORS = Theme.Colors
local SORT_MODES = { "recent", "name", "level", "custom" }
local SORT_LABELS = { recent = "最近登录", name = "角色名称", level = "角色等级", custom = "自定义" }
local PROFILE_FILTER_LABELS = { all = "全部角色", profiled = "仅有档案", missing = "仅缺少档案" }
local Settings

local CHARACTER_ARCHIVE_FIELDS = {
    { id = "identity", title = "角色", width = 210, defaultVisible = true, align = "LEFT", maxWidth = 260 },
    { id = "level", title = "等级", width = 42, defaultVisible = true, align = "LEFT", gapAfter = 12 },
    { id = "itemLevel", title = "装等", width = 50, defaultVisible = true, align = "LEFT", gapAfter = 12 },
    { id = "zone", title = "地点", width = 110, defaultVisible = true, align = "LEFT", maxWidth = 140 },
    { id = "primary", title = "主专业", width = 92, defaultVisible = true, professionSlot = 1, align = "LEFT" },
    { id = "secondary", title = "副专业", width = 92, defaultVisible = true, professionSlot = 2, align = "LEFT", gapAfter = 4 },
    { id = "archaeology", title = "考古", width = 54, defaultVisible = false, skillLine = 794, align = "LEFT" },
    { id = "fishing", title = "钓鱼", width = 54, defaultVisible = true, skillLine = 356, align = "LEFT" },
    { id = "cooking", title = "烹饪", width = 54, defaultVisible = true, skillLine = 185, align = "LEFT" },
    { id = "firstAid", title = "急救", width = 54, defaultVisible = true, skillLine = 129, align = "LEFT" },
}

local ARCHIVE_COLUMN_GAP = 10

local SECONDARY_PROFESSION_IDS = { [794] = true, [356] = true, [185] = true, [129] = true }
local SECONDARY_SLOT_IDS = { [3] = 794, [4] = 356, [5] = 185, [6] = 129 }
local SECONDARY_PROFESSION_NAMES = { ["考古学"] = true, ["考古"] = true, ["钓鱼"] = true, ["烹饪"] = true, ["急救"] = true }

local function HasCharacterProfile(character)
    local profile = character and character.profile or {}
    return profile.zone or profile.itemLevel or #(profile.professions or {}) > 0
end

local function ArchiveSettings()
    local settings = Settings()
    settings.characterArchive = type(settings.characterArchive) == "table" and settings.characterArchive or {}
    local archive = settings.characterArchive
    archive.fields = type(archive.fields) == "table" and archive.fields or {}
    archive.previewFields = type(archive.previewFields) == "table" and archive.previewFields or {}
    archive.filters = type(archive.filters) == "table" and archive.filters or {}
    for _, mode in ipairs({ "page", "preview" }) do
        archive.filters[mode] = type(archive.filters[mode]) == "table" and archive.filters[mode] or {}
        local filter = archive.filters[mode]
        if filter.profile ~= "profiled" and filter.profile ~= "missing" then filter.profile = "all" end
        if filter.includeHidden == nil then filter.includeHidden = mode == "page" end
        local valid, normalized = Core.LevelFilter:Validate(filter.levelExpr or "")
        filter.levelExpr = valid and normalized or ""
    end
    return archive
end

local function ArchiveFieldVisible(field, preview)
    local values = preview and ArchiveSettings().previewFields or ArchiveSettings().fields
    if values[field.id] == nil then return field.defaultVisible == true end
    return values[field.id] == true
end

local function GetArchiveFields(preview)
    local fields = {}
    for _, field in ipairs(CHARACTER_ARCHIVE_FIELDS) do
        if ArchiveFieldVisible(field, preview) then fields[#fields + 1] = field end
    end
    if #fields == 0 then fields[1] = CHARACTER_ARCHIVE_FIELDS[1] end
    return fields
end

local function Copy(value)
    return Core.Defaults:Copy(value)
end

Settings = function()
    local db = Core.Database:GetDB()
    db.settings.accountView = db.settings.accountView or {}
    local settings = db.settings.accountView
    settings.pages = settings.pages or {}
    settings.fields = settings.fields or {}
    settings.pageScopes = settings.pageScopes or {}
    settings.hiddenCharacters = settings.hiddenCharacters or {}
    settings.characterSort = Core.CharacterSort:NormalizeSettings(settings.characterSort)
    settings.pageCharacterSorts = type(settings.pageCharacterSorts) == "table" and settings.pageCharacterSorts or {}
    settings.customCharacterOrder = Core.CharacterSort:NormalizeOrder(settings.customCharacterOrder)
    settings.layoutMode = settings.layoutMode == "manual" and "manual" or "auto"
    settings.pageLayouts = settings.pageLayouts or {}
    settings.width = tonumber(settings.width) or 1120
    settings.height = tonumber(settings.height) or 650
    if settings.anchorVersion ~= 2 then
        settings.point, settings.relativePoint, settings.x, settings.y = "TOPLEFT", "TOPLEFT", 16, -80
        settings.anchorVersion = 2
    end
    settings.entry = settings.entry or {}
    settings.entry.minimap = settings.entry.minimap or { show = true, angle = 225 }
    settings.entry.broker = settings.entry.broker or { show = true }
    settings.entry.previewPageID = type(settings.entry.previewPageID) == "string" and settings.entry.previewPageID or "overview"
    settings.entry.pageModes = settings.entry.pageModes or {}
    settings.entry.pagePositions = settings.entry.pagePositions or {}
    return settings
end

function AccountView:GetSettings()
    return Settings()
end

function AccountView:ResetWindowLayout()
    local settings = Settings()
    settings.point, settings.relativePoint, settings.x, settings.y = "TOPLEFT", "TOPLEFT", 16, -80
    settings.width, settings.height = 1120, 650
    settings.layoutMode = "auto"
    settings.pageLayouts = {}
    if self.frame then
        self:ApplyNormalLayout()
        if self.frame:IsShown() and self.activePageID then self:ShowPage(self.activePageID, { autoFit = true }) end
    end
end

local function GetPageLayout(settings, pageID)
    local saved = settings.pageLayouts and settings.pageLayouts[pageID]
    if type(saved) ~= "table" then return { mode = "auto" } end
    return saved
end

local function ScreenBounds()
    -- Frame coordinates use UI scale, while GetScreenWidth/Height can return
    -- physical pixels.  Prefer UIParent so manual sizing never exceeds view.
    local width = UIParent:GetWidth() or (GetScreenWidth and GetScreenWidth()) or 1600
    local height = UIParent:GetHeight() or (GetScreenHeight and GetScreenHeight()) or 900
    return math.max(1, width - 32), math.max(1, height - 80)
end

local function ClampWindowSize(width, height)
    local maxWidth, maxHeight = ScreenBounds()
    local minWidth, minHeight = math.min(760, maxWidth), math.min(430, maxHeight)
    width = math.max(minWidth, math.min(tonumber(width) or 1120, maxWidth))
    height = math.max(minHeight, math.min(tonumber(height) or 650, maxHeight))
    return width, height, minWidth, minHeight, maxWidth, maxHeight
end

local function ApplyResizeBounds(frame)
    local _, _, minWidth, minHeight, maxWidth, maxHeight = ClampWindowSize(frame:GetWidth(), frame:GetHeight())
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
    else
        -- Compatibility with clients predating SetResizeBounds.
        if frame.SetMinResize then frame:SetMinResize(minWidth, minHeight) end
        if frame.SetMaxResize then frame:SetMaxResize(maxWidth, maxHeight) end
    end
end

local function PageLayoutMetrics(page, context)
    local metrics = { minWidth = 582, preferredWidth = 942, minHeight = 383, preferredHeight = 603, horizontalOverflow = "content", verticalOverflow = "content" }
    if type(page.GetLayoutMetrics) ~= "function" then return metrics end
    local ok, supplied = xpcall(function() return page.GetLayoutMetrics(context) end, function(message) return tostring(message) end)
    if not ok or type(supplied) ~= "table" then
        Core:Print("账号视图页面 “" .. tostring(page.title) .. "”尺寸测量失败，使用兼容尺寸。")
        return metrics
    end
    for _, key in ipairs({ "minWidth", "preferredWidth", "minHeight", "preferredHeight" }) do
        local value = tonumber(supplied[key])
        if value and value > 0 then metrics[key] = math.floor(value + 0.5) end
    end
    metrics.preferredWidth = math.max(metrics.minWidth, metrics.preferredWidth)
    metrics.preferredHeight = math.max(metrics.minHeight, metrics.preferredHeight)
    metrics.horizontalOverflow = supplied.horizontalOverflow == "matrix" and "matrix" or "content"
    metrics.verticalOverflow = supplied.verticalOverflow == "none" and "none" or "content"
    return metrics
end

local function AddText(parent, template, size, color)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    if size then text:SetFont(STANDARD_TEXT_FONT, size) end
    if color then text:SetTextColor(color[1], color[2], color[3]) end
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    return text
end

local function GetHeaderIdentity(page)
    local addonName = page and page.addonName or Core.NAME or "YiboCore"
    local registered = Core.Registry and Core.Registry:Get(addonName)
    local version = registered and registered.version
    if not version and addonName == (Core.NAME or "YiboCore") and Core.GetVersion then
        version = Core:GetVersion()
    end
    return addonName, tostring(version or "?")
end

local function SetHeaderIdentity(frame, page, subtitle)
    local addonName, version = GetHeaderIdentity(page)
    frame.title:SetText(addonName)
    frame.version:SetText("v" .. version)
    frame.subtitle:SetText(subtitle or (page and page.title) or "")
end

local function CreateChromeButton(parent, width, height, label, destructive)
    local button = Theme:CreateButton(parent, width, label, destructive and "danger" or "default")
    button:SetHeight(height or Theme.Size.standard)
    return button
end

local function PageEnabled(page)
    if page.internal then return true end
    local saved = Settings().pages[page.id]
    return saved == nil and page.defaultEnabled ~= false or saved == true
end

local function SortPages(left, right)
    if not left.internal and not right.internal and left.addonName ~= right.addonName then
        return tostring(left.addonName) < tostring(right.addonName)
    end
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
    if definition.GetEligibleCharacters ~= nil and type(definition.GetEligibleCharacters) ~= "function" then
        return nil, "页面 GetEligibleCharacters 必须是 function。"
    end
    if definition.GetLayoutMetrics ~= nil and type(definition.GetLayoutMetrics) ~= "function" then
        return nil, "页面 GetLayoutMetrics 必须是 function。"
    end
    if definition.GetHoverMetrics ~= nil and type(definition.GetHoverMetrics) ~= "function" then
        return nil, "页面 GetHoverMetrics 必须是 function。"
    end
    if definition.HasCharacterSnapshot ~= nil and type(definition.HasCharacterSnapshot) ~= "function" then
        return nil, "页面 HasCharacterSnapshot 必须是 function。"
    end
    if definition.scope ~= nil then
        if type(definition.scope) == "table" and definition.scope.mode == "realms" then
            -- Realm scopes are derived by Core from its character directory and
            -- the page's business-snapshot admission callback.
        elseif type(definition.scope) ~= "table" or type(definition.scope.default) ~= "string" or type(definition.scope.values) ~= "table" then
            return nil, "页面 scope 必须提供 default 与 values。"
        else
            local scopeIDs = {}
            for _, value in ipairs(definition.scope.values) do
                if type(value) ~= "table" or type(value.id) ~= "string" or value.id == "" or type(value.title) ~= "string" then
                    return nil, "页面 scope.values 必须提供 id 与 title。"
                end
                if scopeIDs[value.id] then return nil, "页面 scope ID 重复: " .. value.id end
                scopeIDs[value.id] = true
            end
            if not scopeIDs[definition.scope.default] then
                return nil, "页面 scope.default 必须存在于 scope.values。"
            end
        end
    end
    if not (Core.Registry and Core.Registry:Get(addonName)) then
        return nil, "页面所属插件尚未通过 Core:RegisterAddon 注册: " .. addonName
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
    local claimed, claimError = Core:ClaimResource("page", definition.id, addonName)
    if not claimed then return nil, claimError end
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
    if Core.Entry and Core.Entry.UnregisterEntriesForPage then Core.Entry:UnregisterEntriesForPage(pageID) end
    if Core.Registry then Core.Registry:ReleaseResource("page", pageID, page.addonName) end
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
    Core:Print("账号视图页面 “" .. page.title .. "”（" .. tostring(page.addonName or "Core") .. "）" .. phase .. " 失败：" .. page.lastError)
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
    return visible
end

function AccountView:GetDefaultCharacterSort()
    return Copy(Settings().characterSort)
end

function AccountView:GetPageCharacterSort(pageID)
    local saved = Settings().pageCharacterSorts[pageID]
    return Core.CharacterSort:NormalizeSettings(saved or { mode = "inherit" }, Settings().characterSort, true)
end

function AccountView:GetEffectiveCharacterSort(pageID)
    local pageSort = self:GetPageCharacterSort(pageID)
    if pageSort.mode == "inherit" then
        local inherited = self:GetDefaultCharacterSort()
        inherited.inherited = true
        return inherited
    end
    pageSort.inherited = false
    return pageSort
end

function AccountView:SetDefaultCharacterSort(value)
    Settings().characterSort = Core.CharacterSort:NormalizeSettings(value, Settings().characterSort)
    self:RefreshPage()
    return self:GetDefaultCharacterSort()
end

function AccountView:SetPageCharacterSort(pageID, value)
    if not self._pages[pageID] or self._pages[pageID].internal then return nil end
    local normalized = Core.CharacterSort:NormalizeSettings(value, Settings().characterSort, true)
    Settings().pageCharacterSorts[pageID] = normalized
    self:RefreshPage()
    return self:GetPageCharacterSort(pageID)
end

function AccountView:ResetPageCharacterSort(pageID)
    if not self._pages[pageID] or self._pages[pageID].internal then return false end
    Settings().pageCharacterSorts[pageID] = { mode = "inherit" }
    self:RefreshPage()
    return true
end

function AccountView:GetCustomCharacterOrder()
    local settings = Settings()
    local characters, known, order, present = Core.Characters:GetAll(), {}, {}, {}
    for _, character in ipairs(characters) do known[character.id] = true end
    for _, characterID in ipairs(Core.CharacterSort:NormalizeOrder(settings.customCharacterOrder)) do
        if known[characterID] then order[#order + 1] = characterID; present[characterID] = true end
    end
    for _, characterID in ipairs(Core.CharacterSort:BuildCustomOrder(characters)) do
        if not present[characterID] then order[#order + 1] = characterID; present[characterID] = true end
    end
    settings.customCharacterOrder = order
    return Copy(order)
end

function AccountView:MoveCustomCharacter(characterID, delta)
    local order, moved = Core.CharacterSort:MoveCharacter(self:GetCustomCharacterOrder(), characterID, delta)
    if not moved then return false end
    Settings().customCharacterOrder = order
    self:RefreshPage()
    return true
end

function AccountView:RebuildCustomCharacterOrder(mode)
    local characters = Core.Characters:GetAll()
    if mode == "recent" then
        characters = Core.CharacterSort:Sort(characters, { mode = "recent", direction = "desc" })
        local order = {}
        for _, character in ipairs(characters) do order[#order + 1] = character.id end
        Settings().customCharacterOrder = order
    else
        Settings().customCharacterOrder = Core.CharacterSort:BuildCustomOrder(characters)
    end
    self:RefreshPage()
end

local function NextSortMode(mode)
    for index, candidate in ipairs(SORT_MODES) do
        if candidate == mode then return SORT_MODES[(index % #SORT_MODES) + 1] end
    end
    return SORT_MODES[1]
end

local function DefaultDirection(mode)
    return mode == "name" and "asc" or "desc"
end

function AccountView:CycleCharacterSort(pageID, reverseDirection)
    local page = self._pages[pageID]
    local current = self:GetEffectiveCharacterSort(pageID)
    local updated = Copy(current)
    updated.inherited = nil
    if reverseDirection then
        if updated.mode == "custom" then return current end
        updated.direction = updated.direction == "asc" and "desc" or "asc"
    else
        updated.mode = NextSortMode(updated.mode)
        updated.direction = DefaultDirection(updated.mode)
    end
    if page and not page.internal then return self:SetPageCharacterSort(pageID, updated) end
    return self:SetDefaultCharacterSort(updated)
end

function AccountView:UpdateSortButton()
    local frame = self.frame
    if not (frame and frame.sortButton) then return end
    local pageID = self.activePageID or "overview"
    local page = self._pages[pageID]
    local show = not frame.preview and page and pageID ~= "settings" and pageID ~= "about"
    frame.sortButton:SetShown(show)
    if not show then return end
    local sort = self:GetEffectiveCharacterSort(pageID)
    local arrow = sort.mode == "custom" and "" or (sort.direction == "asc" and " ↑" or " ↓")
    frame.sortButton:SetText("排序：" .. (SORT_LABELS[sort.mode] or "最近登录") .. arrow)
    frame.sortButton.sortDescription = (sort.inherited and "跟随通用设置。" or "此页面独立设置。") .. " 左键切换排序；Shift+左键切换方向。"
end

local function GetScopeDefinition(page, characters)
    if type(page) == "table" and page.scope and page.scope.mode == "realms" then
        local current = Core.Characters:GetCurrent()
        local currentRealm = (current and current.realm) or (GetRealmName and GetRealmName()) or "Unknown"
        local realms = { [currentRealm] = true }
        for _, character in ipairs(characters or Core.Characters:GetAll()) do
            local admitted = true
            if type(page.HasCharacterSnapshot) == "function" then
                local ok, result = xpcall(function() return page.HasCharacterSnapshot(character) end, function(message) return tostring(message) end)
                admitted = ok and result == true
                if not ok then Core:Print("账号视图页面“" .. tostring(page.title or page.id) .. "”读取角色快照失败：" .. result) end
            end
            if admitted and character.realm and character.realm ~= "" then realms[character.realm] = true end
        end
        local others = {}
        for realm in pairs(realms) do if realm ~= currentRealm then others[#others + 1] = realm end end
        table.sort(others)
        local values = { { id = "realm:" .. currentRealm, title = currentRealm } }
        for _, realm in ipairs(others) do values[#values + 1] = { id = "realm:" .. realm, title = realm } end
        values[#values + 1] = { id = "all", title = page.scope.allTitle or "所有服务器" }
        return { default = "realm:" .. currentRealm, values = values, mode = "realms" }
    end
    return type(page) == "table" and type(page.scope) == "table" and page.scope or nil
end

local function IsKnownScope(scopeDefinition, scopeID)
    for _, value in ipairs(scopeDefinition and scopeDefinition.values or {}) do
        if value.id == scopeID then return true end
    end
    return false
end

function AccountView:GetPageScope(pageID)
    local page = self._pages[pageID]
    local scopeDefinition = GetScopeDefinition(page, self:GetVisibleCharacters())
    if not scopeDefinition then return nil end
    local saved = Settings().pageScopes[pageID]
    if IsKnownScope(scopeDefinition, saved) then return saved end
    return scopeDefinition.default
end

function AccountView:SetPageScope(pageID, scopeID)
    local page = self._pages[pageID]
    local scopeDefinition = GetScopeDefinition(page, self:GetVisibleCharacters())
    if not scopeDefinition or not IsKnownScope(scopeDefinition, scopeID) then return false end
    Settings().pageScopes[pageID] = scopeID
    if self.frame and self.frame.preview and self.previewPageID == pageID then
        -- Scope can materially change the number of matrix columns.  Reopen
        -- the same preview against its original anchor so both dimensions and
        -- edge clamping are recomputed before the page is rendered again.
        self:ShowPreview(pageID, self.previewAnchor)
    elseif self.activePageID == pageID then
        -- Auto-sized main pages should follow the selected realm's matrix
        -- width.  ApplyPageSize still preserves a user's manual page size.
        self:ShowPage(pageID, { autoFit = true })
    end
    return true
end

function AccountView:SetCharacterHidden(characterID, hidden)
    Settings().hiddenCharacters[characterID] = not not hidden
    self:RefreshPage()
end

function AccountView:CreateFrame()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "YiboCoreAccountView", UIParent, "BackdropTemplate")
    local settings = Settings()
    settings.width, settings.height = ClampWindowSize(settings.width, settings.height)
    frame:SetSize(settings.width, settings.height)
    frame:SetPoint(settings.point or "CENTER", UIParent, settings.relativePoint or "CENTER", settings.x or 0, settings.y or 0)
    frame:SetMovable(true)
    frame:SetResizable(true)
    ApplyResizeBounds(frame)
    frame:SetClampedToScreen(true)
    frame:SetToplevel(true)
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
            if not AccountView._applyingPageSize then
                settings.layoutMode = "manual"
                settings.pageLayouts = settings.pageLayouts or {}
                local pageID = AccountView.activePageID or "overview"
                settings.pageLayouts[pageID] = { mode = "manual", width = settings.width, height = settings.height }
                -- A resize emits this event once per pixel.  Rebuilding a
                -- matrix here made QuestBlocker redraw every cell while the
                -- grip was dragged.  The anchored layout already reflows;
                -- refresh only once after the mouse is released.
                AccountView._resizeDirty = true
            end
        end
    end)
    frame:SetScript("OnShow", function(self)
        if not self.preview then self:Raise() end
    end)
    frame:SetScript("OnHide", function(self)
        -- UISpecialFrames closes the frame directly.  A hover preview must
        -- therefore restore its normal shell here as well, otherwise the next
        -- ordinary open would inherit tooltip layout and strata.
        if self.preview then
            self.preview = false
            AccountView.previewPageID, AccountView.previewPageOptions, AccountView.previewAnchor = nil, nil, nil
            AccountView:ApplyNormalLayout()
        end
    end)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    frame:SetBackdropColor(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], COLORS.bg[4])
    frame:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], COLORS.line[4])

    frame.top = frame:CreateTexture(nil, "BACKGROUND")
    frame.top:SetPoint("TOPLEFT", 1, -1); frame.top:SetPoint("TOPRIGHT", -1, -1); frame.top:SetHeight(46)
    frame.top:SetColorTexture(COLORS.chrome[1], COLORS.chrome[2], COLORS.chrome[3], COLORS.chrome[4])
    frame.brand = AddText(frame, "GameFontNormalLarge", nil, COLORS.accent)
    frame.brand:Hide()
    frame.title = AddText(frame, "GameFontNormalLarge", nil, COLORS.text)
    frame.title:SetPoint("LEFT", frame, "LEFT", 16, 0); frame.title:SetText("账号总览")
    frame.version = AddText(frame, "GameFontNormalSmall", 11, COLORS.muted)
    frame.version:SetPoint("BOTTOMLEFT", frame.title, "BOTTOMRIGHT", 7, 1); frame.version:SetText("v?")
    frame.subtitle = AddText(frame, "GameFontNormalSmall", nil, COLORS.muted)
    frame.subtitle:SetPoint("BOTTOMLEFT", frame.version, "BOTTOMRIGHT", 12, 1); frame.subtitle:SetText("多角色状态")
    frame.controls = CreateFrame("Frame", nil, frame)
    frame.controls:SetSize(256, 24)
    frame.controls:SetPoint("TOPRIGHT", -14, -12)
    frame.sortButton = CreateChromeButton(frame.controls, 150, 22, "排序：最近登录 ↓")
    frame.sortButton:SetPoint("LEFT", 0, 0)
    frame.sortButton:SetScript("OnClick", function()
        AccountView:CycleCharacterSort(AccountView.activePageID or "overview", IsShiftKeyDown and IsShiftKeyDown())
    end)
    frame.sortButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(self.label:GetText() or "角色排序", COLORS.text[1], COLORS.text[2], COLORS.text[3])
        GameTooltip:AddLine(self.sortDescription or "", COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], true)
        GameTooltip:Show()
    end)
    frame.sortButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.settingsButton = CreateChromeButton(frame.controls, 62, 22, "设置")
    frame.settingsButton:SetPoint("LEFT", frame.sortButton, "RIGHT", 10, 0)
    frame.settingsButton:SetScript("OnClick", function() AccountView:ShowSettings() end)
    frame.close = CreateChromeButton(frame.controls, 28, 24, "×", true)
    frame.close:SetPoint("LEFT", frame.settingsButton, "RIGHT", 6, 0)
    frame.close.label:SetFont(STANDARD_TEXT_FONT, 20)
    -- Closing is an icon affordance, not a destructive text action.  Keep it
    -- visually light beside Settings instead of showing a second red button.
    frame.close.SetState = function(control)
        control:SetBackdropColor(0, 0, 0, 0)
        control:SetBackdropBorderColor(0, 0, 0, 0)
        control.label:SetTextColor(COLORS.danger[1], COLORS.danger[2], COLORS.danger[3])
    end
    frame.close:SetState()
    frame.close:SetScript("OnEnter", function(control) control.label:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3]) end)
    frame.close:SetScript("OnLeave", function(control) control:SetState() end)
    frame.close:SetScript("OnClick", function() frame:Hide() end)
    frame.resize = CreateFrame("Button", nil, frame)
    frame.resize:SetSize(18, 18); frame.resize:SetPoint("BOTTOMRIGHT", -3, 3)
    frame.resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    frame.resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    frame.resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    frame.resize:SetScript("OnMouseDown", function(_, button)
        if frame.preview or button ~= "LeftButton" then return end
        ApplyResizeBounds(frame)
        -- The grip sits inside the frame corner. Starting from the actual mouse
        -- position prevents the bottom-right edge snapping to the cursor.
        frame:StartSizing("BOTTOMRIGHT", true)
    end)
    frame.resize:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        local width, height = ClampWindowSize(frame:GetWidth(), frame:GetHeight())
        if math.abs((frame:GetWidth() or 0) - width) >= 1 or math.abs((frame:GetHeight() or 0) - height) >= 1 then
            AccountView._applyingPageSize = true
            frame:SetSize(width, height)
            AccountView._applyingPageSize = nil
            settings.width, settings.height = width, height
        end
        if AccountView._resizeDirty then
            AccountView._resizeDirty = nil
            AccountView:RefreshPage()
        end
    end)

    frame.nav = CreateFrame("Frame", nil, frame)
    frame.nav:SetPoint("TOPLEFT", 1, -47); frame.nav:SetPoint("BOTTOMLEFT", 1, 1); frame.nav:SetWidth(176)
    frame.nav.bg = frame.nav:CreateTexture(nil, "BACKGROUND"); frame.nav.bg:SetAllPoints(); frame.nav.bg:SetColorTexture(COLORS.nav[1], COLORS.nav[2], COLORS.nav[3], COLORS.nav[4])
    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", frame.nav, "TOPRIGHT", 1, 0); frame.content:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.navButtons, frame.instances = {}, {}
    frame:Hide()
    if UISpecialFrames then
        local registered = false
        for _, frameName in ipairs(UISpecialFrames) do if frameName == "YiboCoreAccountView" then registered = true; break end end
        if not registered then tinsert(UISpecialFrames, "YiboCoreAccountView") end
    end
    self.frame = frame
    return frame
end

function AccountView:ApplyPageSize(page, context, allowAutoResize)
    local frame = self:CreateFrame()
    if frame.preview then return end
    local settings, metrics = Settings(), PageLayoutMetrics(page, context)
    local maxWidth, maxHeight = ScreenBounds()
    local preferredWidth = metrics.preferredWidth + 178
    local preferredHeight = metrics.preferredHeight + 47
    local minWidth = math.max(760, metrics.minWidth + 178)
    local minHeight = math.max(430, metrics.minHeight + 47)
    local width, height
    local saved = GetPageLayout(settings, page.id)
    if not allowAutoResize then return end
    if saved.mode == "manual" then
        width = math.max(tonumber(saved.width) or preferredWidth, minWidth)
        height = math.max(tonumber(saved.height) or preferredHeight, minHeight)
    else
        width, height = preferredWidth, preferredHeight
    end
    width = math.max(math.min(760, maxWidth), math.min(math.max(minWidth, width), maxWidth))
    height = math.max(math.min(430, maxHeight), math.min(math.max(minHeight, height), maxHeight))
    if math.abs((frame:GetWidth() or 0) - width) < 1 and math.abs((frame:GetHeight() or 0) - height) < 1 then return end
    self._applyingPageSize = true
    frame:SetSize(width, height)
    self._applyingPageSize = nil
    settings.width, settings.height = width, height
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
        pages[#pages + 1] = { id = "settings-core-heading", title = "Core 常规设置", section = true }
        pages[#pages + 1] = { id = "settings-core", title = "  窗口", settingsTargetID = "core" }
        pages[#pages + 1] = { id = "settings-sorting", title = "  角色与排序", settingsTargetID = "sorting" }
        pages[#pages + 1] = { id = "settings-display", title = "  显示与入口", settingsTargetID = "display" }
        for _, page in ipairs(self._pageOrder) do
            if not page.internal then pages[#pages + 1] = { id = "settings-" .. page.id, title = page.addonName or page.title, settingsTargetID = page.id } end
        end
    else
        pages = { self._pages.overview, self._pages.characters }
        for _, page in ipairs(self._pageOrder) do if PageEnabled(page) then pages[#pages + 1] = page end end
        pages[#pages + 1] = self._pages.about
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
        button.pageID = page.id; button.settingsTargetID = page.settingsTargetID; button.section = page.section; button.label:SetText(page.title)
        local selected = page.settingsTargetID and self.activePageID == "settings" and self.settingsTargetPageID == page.settingsTargetID or self.activePageID == page.id
        button:EnableMouse(not page.section)
        button.label:SetTextColor(page.section and COLORS.accent[1] or COLORS.text[1], page.section and COLORS.accent[2] or COLORS.text[2], page.section and COLORS.accent[3] or COLORS.text[3])
        button:SetBackdropColor(selected and not page.section and COLORS.selected[1] or 0, selected and not page.section and COLORS.selected[2] or 0, selected and not page.section and COLORS.selected[3] or 0, selected and not page.section and 1 or 0)
        button:Show()
    end
    for index = #pages + 1, #frame.navButtons do frame.navButtons[index]:Hide() end
end

function AccountView:BuildContext(page, options)
    options = options or {}
    local overrides = options.fieldOverrides
    -- Character archive owns its own inclusion filters.  Business pages keep
    -- the account-wide hidden-character admission rule.
    local characters = page and page.id == "characters" and Core.Characters:GetAll() or self:GetVisibleCharacters()
    local scopeDefinition = GetScopeDefinition(page, characters)
    local scope = scopeDefinition and self:GetPageScope(page.id) or nil
    local baseContext = {
        page = page,
        scope = scope,
        scopeDefinition = scopeDefinition,
        preview = options.preview == true,
    }
    if type(page.GetEligibleCharacters) == "function" then
        local ok, eligible = xpcall(function()
            return page.GetEligibleCharacters(characters, baseContext)
        end, function(message) return tostring(message) end)
        if not ok then
            Core:Print("账号视图页面 “" .. page.title .. "”（" .. tostring(page.addonName or "Core") .. "）角色准入失败：" .. tostring(eligible))
            characters = {}
        elseif type(eligible) == "table" then
            characters = eligible
        else
            Core:Print("账号视图页面 “" .. page.title .. "”（" .. tostring(page.addonName or "Core") .. "）角色准入必须返回 table。")
            characters = {}
        end
    end
    local characterSort = self:GetEffectiveCharacterSort(page.id)
    characters = Core.CharacterSort:Sort(
        characters,
        characterSort,
        Core.Characters:GetCurrentID(),
        self:GetCustomCharacterOrder()
    )
    -- 悬停预览是正式账号视图的投影，但不应成为可滚动的小窗口。
    -- 统一限定为前 20 名有效角色，保证业务页可按固定行高一次排完。
    if options.preview and page.id ~= "characters" then
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
        scope = scope,
        scopeDefinition = scopeDefinition,
        SetScope = function(_, scopeID) return self:SetPageScope(page.id, scopeID) end,
        Refresh = function() self:RefreshPage() end,
        preview = options.preview == true,
        characterSort = characterSort,
    }
end

function AccountView:ShowPage(pageID, options)
    options = options or {}
    local page = self._pages[pageID] or self._pages.overview
    if not page or (not page.internal and not PageEnabled(page)) then page = self._pages.overview end
    self:CreateFrame()
    local context = self:BuildContext(page, options)
    if not options.preview then self:ApplyPageSize(page, context, options.autoFit == true) end
    for id, instance in pairs(self.frame.instances) do if id ~= page.id then instance:Hide() end end
    local instance = self.frame.instances[page.id]
    if not instance then
        instance = CreateFrame("Frame", nil, self.frame.content)
        instance:SetAllPoints(self.frame.content)
        self.frame.instances[page.id] = instance
        CallPage(instance, page, "创建", context)
    end
    instance:Show()
    if options.preview then
        -- 悬停投影不能改变正式窗口最后打开的页面；否则 Core 默认入口会
        -- 被业务入口的预览反向影响，产生页面和尺寸来回跳变。
        self.previewPageID = page.id
        self.previewPageOptions = options
    else
        self.activePageID = page.id
        -- Auto-fit is an opening action, never a persistent page option.  A
        -- later data refresh must not resize a window the player is using.
        options.autoFit = nil
        self.activePageOptions = options
    end
    SetHeaderIdentity(self.frame, page, options.preview and ((page.title or "账号") .. " · 账号角色预览") or page.title)
    CallPage(instance, page, "刷新", context)
    self:RefreshNavigation()
    self:UpdateSortButton()
end

function AccountView:RefreshPage()
    if not (self.frame and self.frame:IsShown()) then return end
    if self.frame.preview and self.previewPageID then
        self:ShowPage(self.previewPageID, self.previewPageOptions)
    elseif self.activePageID then
        self:ShowPage(self.activePageID, self.activePageOptions)
    end
end

function AccountView:NotifyPageChanged(pageID)
    if self.frame and self.frame.preview then
        if self.previewPageID == pageID then self:RefreshPage() end
    elseif self.activePageID == pageID then
        self:RefreshPage()
    end
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
    frame:SetToplevel(true)
    settings.width, settings.height = ClampWindowSize(settings.width, settings.height)
    ApplyResizeBounds(frame)
    self._applyingPageSize = true
    frame:SetSize(settings.width, settings.height)
    self._applyingPageSize = nil
    frame:ClearAllPoints()
    frame:SetPoint(settings.point or "CENTER", UIParent, settings.relativePoint or "CENTER", settings.x or 0, settings.y or 0)
    frame.nav:Show(); frame.settingsButton:Show(); frame.close:Show(); frame.resize:Show(); self:UpdateSortButton()
    SetHeaderIdentity(frame, self._pages.overview, "账号总览 · 多角色状态")
    frame.content:ClearAllPoints()
    frame.content:SetPoint("TOPLEFT", frame.nav, "TOPRIGHT", 1, 0)
    frame.content:SetPoint("BOTTOMRIGHT", -1, 1)
    if frame:IsShown() then frame:Raise() end
end

function AccountView:GetPreviewPage()
    -- Core 入口可选择任一支持悬停预览且当前可用的页面；业务入口会显式
    -- 传入自己的 pageID，因此不受该偏好影响。无效的旧值安全回退到概览。
    local settings = Settings()
    local page = self._pages[settings.entry.previewPageID]
    if page and page.previewEnabled and (page.internal or PageEnabled(page)) then return page end
    settings.entry.previewPageID = "overview"
    return self._pages.overview
end

function AccountView:GetPreviewPageOptions()
    local options = {}
    local overview = self._pages.overview
    if overview and overview.previewEnabled then options[#options + 1] = overview end
    local characters = self._pages.characters
    if characters and characters.previewEnabled then options[#options + 1] = characters end
    for _, page in ipairs(self._pageOrder) do
        if page.previewEnabled and not page.internal and PageEnabled(page) then
            options[#options + 1] = page
        end
    end
    return options
end

local function HoverMetrics(page, context)
    local metrics = { minWidth = 420, preferredWidth = 820, minHeight = 150, preferredHeight = 360, horizontalOverflow = "content", verticalOverflow = "content" }
    if type(page.GetHoverMetrics) == "function" then
        local ok, supplied = xpcall(function() return page.GetHoverMetrics(context) end, function(message) return tostring(message) end)
        if ok and type(supplied) == "table" then
            for _, key in ipairs({ "minWidth", "preferredWidth", "minHeight", "preferredHeight" }) do
                local value = tonumber(supplied[key])
                if value and value > 0 then metrics[key] = math.floor(value + 0.5) end
            end
            metrics.horizontalOverflow = supplied.horizontalOverflow == "matrix" and "matrix" or "content"
            metrics.verticalOverflow = supplied.verticalOverflow == "none" and "none" or "content"
        else
            Core:Print("账号视图页面 “" .. tostring(page.title) .. "”悬停尺寸测量失败，使用兼容尺寸。")
        end
    elseif type(page.GetPreviewSize) == "function" then
        local width, height = page.GetPreviewSize(context)
        metrics.preferredWidth, metrics.preferredHeight = tonumber(width) or metrics.preferredWidth, tonumber(height) or metrics.preferredHeight
    end
    metrics.preferredWidth = math.max(metrics.minWidth, metrics.preferredWidth)
    metrics.preferredHeight = math.max(metrics.minHeight, metrics.preferredHeight)
    return metrics
end

-- A preview contains buttons owned by business pages.  WoW does not reliably
-- bubble mouse enter/leave events from those children to this parent frame, so
-- each mouse-enabled descendant participates in the same hover lifetime.
function AccountView:TrackPreviewControls(root)
    local function Track(control)
        if control.previewHoverTracked or not (control.IsMouseEnabled and control:IsMouseEnabled()) then return end
        control.previewHoverTracked = true
        control:HookScript("OnEnter", function()
            if AccountView.frame and AccountView.frame.preview and AccountView.previewOnEnter then AccountView.previewOnEnter() end
        end)
        control:HookScript("OnLeave", function()
            if AccountView.frame and AccountView.frame.preview and AccountView.previewOnLeave then AccountView.previewOnLeave() end
        end)
    end
    local function Visit(control)
        Track(control)
        local children = { control:GetChildren() }
        for _, child in ipairs(children) do Visit(child) end
    end
    Visit(root)
end

function AccountView:ShowPreview(pageID, anchor)
    local page = self._pages[pageID] or self:GetPreviewPage()
    local frame = self:CreateFrame()
    if not page or not page.previewEnabled or (not page.internal and not PageEnabled(page)) or (frame:IsShown() and not frame.preview) then return false end

    local fields = type(page.GetPreviewFields) == "function" and page.GetPreviewFields() or page.previewFields
    local context = self:BuildContext(page, { preview = true, fieldOverrides = fields })
    local metrics = HoverMetrics(page, context)
    local width, height = metrics.preferredWidth, metrics.preferredHeight
    local screenWidth = UIParent:GetWidth() or (GetScreenWidth and GetScreenWidth()) or width
    local screenHeight = UIParent:GetHeight() or (GetScreenHeight and GetScreenHeight()) or height
    width = math.max(math.min(metrics.minWidth, screenWidth - 32), math.min(width, screenWidth - 32))

    frame.preview = true
    frame:SetMovable(false)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", self.previewOnEnter)
    frame:SetScript("OnLeave", self.previewOnLeave)
    frame:SetFrameStrata("TOOLTIP")
    frame:ClearAllPoints()
    local anchorFrame = anchor and type(anchor.GetLeft) == "function" and anchor or nil
    self.previewAnchor = anchorFrame
    if anchorFrame then
        local left, right = anchorFrame:GetLeft(), anchorFrame:GetRight()
        local top, bottom = anchorFrame:GetTop(), anchorFrame:GetBottom()
        local roomBelow = math.max(0, (bottom or 0) - 8)
        local roomAbove = math.max(0, screenHeight - (top or screenHeight) - 8)
        local openBelow = roomBelow >= roomAbove
        local usableHeight = openBelow and roomBelow or roomAbove
        local centerPreview = height > usableHeight and height <= screenHeight - 32
        -- Prefer the anchor side, but preserving the guaranteed 20-row
        -- capacity takes priority when neither side has enough room and the
        -- screen itself can fit the preview.
        if not centerPreview then height = math.min(height, math.max(120, usableHeight)) end
        -- Anchor placement is only a preference.  Clamp against UIParent so
        -- a broker/minimap control near either screen edge can never push the
        -- left or right side of the preview out of view.
        local previewLeft = left or ((screenWidth - width) / 2)
        previewLeft = math.max(16, math.min(previewLeft, screenWidth - width - 16))
        if centerPreview then
            frame:SetPoint("CENTER", UIParent, "CENTER")
        elseif openBelow then
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", previewLeft, (bottom or 8) - 8)
        else
            frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", previewLeft, (top or screenHeight - 8) + 8)
        end
    else
        height = math.max(math.min(metrics.minHeight, screenHeight - 80), math.min(height, screenHeight - 80))
        frame:SetPoint("CENTER", UIParent, "CENTER")
    end
    frame:SetSize(width, height)
    frame.nav:Hide(); frame.sortButton:Hide(); frame.settingsButton:Hide(); frame.close:Hide(); frame.resize:Hide()
    frame.content:ClearAllPoints()
    frame.content:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -47)
    frame.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    SetHeaderIdentity(frame, page, (page.title or "账号") .. " · 账号角色预览")
    frame:Show()
    self:ShowPage(page.id, { preview = true, fieldOverrides = fields })
    self:TrackPreviewControls(frame)
    return true
end

function AccountView:HidePreview()
    local frame = self.frame
    if not frame or not frame.preview then return end
    frame:Hide()
    self:ApplyNormalLayout()
    self.previewPageID = nil
    self.previewPageOptions = nil
    self.previewAnchor = nil
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
    local opening = not frame:IsShown()
    frame:Show(); self:ShowPage(pageID or self.activePageID or "overview", { autoFit = opening })
end

function AccountView:ShowSettings()
    if self.activePageID and self.activePageID ~= "settings" then
        local active = self._pages[self.activePageID]
        self.settingsTargetPageID = active and not active.internal and active.id or "display"
    end
    self:Toggle("settings")
end

function AccountView:SelectSettingsTarget(targetID)
    if targetID ~= "display" and targetID ~= "sorting" and targetID ~= "core" then
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

local function RefreshOverview(parent, context)
    local lines = {}
    local actions = {}
    local allCharacters = Core.Characters:GetAll()
    local visibleCharacters = AccountView:GetVisibleCharacters()
    parent.characterSummary:SetText(string.format("已记录 %d 名角色 · 视图显示 %d 名", #allCharacters, #visibleCharacters))
    local actionsPerPage = {}
    local pageCharacters = {}
    local function CollectPageValue(page, callbackName)
        local ok, result = xpcall(function()
            if not pageCharacters[page.id] then pageCharacters[page.id] = AccountView:BuildContext(page).characters end
            return page[callbackName](pageCharacters[page.id])
        end, function(message) return tostring(message) end)
        if not ok then
            page.lastError = result
            Core:Print("账号概览读取页面 “" .. page.title .. "”（" .. tostring(page.addonName) .. "）的 " .. callbackName .. " 失败：" .. result)
            return nil
        end
        return result
    end
    for _, page in ipairs(AccountView._pageOrder) do
        if PageEnabled(page) and type(page.GetSummary) == "function" then
            local summary = CollectPageValue(page, "GetSummary")
            if summary and summary ~= "" then lines[#lines + 1] = { title = page.title, text = summary, pageID = page.id } end
        end
        if PageEnabled(page) and type(page.GetActions) == "function" then
            for _, suppliedAction in ipairs(CollectPageValue(page, "GetActions") or {}) do
                if type(suppliedAction) == "table" and (actionsPerPage[page.id] or 0) < 3 then
                    local action = Copy(suppliedAction)
                    action.pageID = page.id
                    action.pageTitle = page.title
                    action.addonName = page.addonName
                    actions[#actions + 1] = action
                    actionsPerPage[page.id] = (actionsPerPage[page.id] or 0) + 1
                end
            end
        end
    end
    table.sort(actions, function(left, right)
        if (left.priority or 0) ~= (right.priority or 0) then return (left.priority or 0) > (right.priority or 0) end
        if tostring(left.pageTitle) ~= tostring(right.pageTitle) then return tostring(left.pageTitle) < tostring(right.pageTitle) end
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
    local actionLimit = 8
    if context and context.preview then
        -- 悬停预览没有滚动区。按当前内容区高度收紧行动条数，确保每一条
        -- 都完整落在窗口内，而不是让底部条目溢出预览框。
        local availableHeight = parent:GetHeight() or 0
        local firstActionBottom = 170 + (#lines * 42)
        if availableHeight >= firstActionBottom then
            actionLimit = math.min(8, 1 + math.floor((availableHeight - firstActionBottom) / 38))
        else
            actionLimit = 0
        end
    end
    local visibleActionCount = math.min(#actions, actionLimit)
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
    parent.filter = CreateChromeButton(parent, 116, 20, "档案：全部角色")
    parent.filter:SetPoint("TOPRIGHT", -142, -18)
    parent.filter:SetScript("OnClick", function()
        local filter = ArchiveSettings().filters.page
        local choices = { "all", "profiled", "missing" }
        for index, choice in ipairs(choices) do if choice == filter.profile then filter.profile = choices[(index % #choices) + 1]; break end end
        parent.resetScroll = true; AccountView:RefreshPage()
    end)
    parent.levelLabel = AddText(parent, "GameFontNormalSmall", nil, COLORS.muted); parent.levelLabel:SetText("等级")
    parent.levelLabel:SetPoint("RIGHT", parent.searchLabel, "LEFT", -122, 0)
    parent.level = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    parent.level:SetSize(112, 20); parent.level:SetPoint("RIGHT", parent.searchLabel, "LEFT", -6, 0); parent.level:SetAutoFocus(false); parent.level:SetMaxLetters(64); parent.level:SetTextInsets(7, 7, 0, 0)
    local function SaveLevelFilter(control)
        local valid, normalized, badToken = Core.LevelFilter:Validate(control:GetText())
        if not valid then
            control:SetText(ArchiveSettings().filters.page.levelExpr or "")
            Core:Print("等级过滤格式无效：" .. tostring(badToken))
            return
        end
        ArchiveSettings().filters.page.levelExpr = normalized
        control:SetText(normalized); parent.resetScroll = true; AccountView:RefreshPage()
    end
    parent.level:SetScript("OnEnterPressed", function(self) SaveLevelFilter(self); self:ClearFocus() end)
    parent.level:SetScript("OnEditFocusLost", SaveLevelFilter)
    parent.level:SetScript("OnEscapePressed", function(self) self:SetText(ArchiveSettings().filters.page.levelExpr or ""); self:ClearFocus() end)
    parent.listHeader = CreateFrame("Frame", nil, parent)
    parent.listHeader:SetPoint("TOPLEFT", 20, -82); parent.listHeader:SetWidth(850); parent.listHeader:SetHeight(22)
    parent.listHeader.bg = parent.listHeader:CreateTexture(nil, "BACKGROUND"); parent.listHeader.bg:SetAllPoints(); parent.listHeader.bg:SetColorTexture(COLORS.chrome[1], COLORS.chrome[2], COLORS.chrome[3], 0.95)
    parent.listHeader.name = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.name:SetPoint("LEFT", 9, 0); parent.listHeader.name:SetWidth(246); parent.listHeader.name:SetText("角色")
    parent.listHeader.level = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.level:SetPoint("LEFT", parent.listHeader.name, "RIGHT", 6, 0); parent.listHeader.level:SetWidth(32); parent.listHeader.level:SetText("等级")
    parent.listHeader.zone = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.zone:SetPoint("LEFT", parent.listHeader.level, "RIGHT", 6, 0); parent.listHeader.zone:SetWidth(78); parent.listHeader.zone:SetText("地点")
    parent.listHeader.itemLevel = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.itemLevel:SetPoint("LEFT", parent.listHeader.zone, "RIGHT", 6, 0); parent.listHeader.itemLevel:SetWidth(42); parent.listHeader.itemLevel:SetText("装等")
    parent.listHeader.professions = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.professions:SetPoint("LEFT", parent.listHeader.itemLevel, "RIGHT", 6, 0); parent.listHeader.professions:SetText("专业")
    parent.scroll = Theme:CreateScrollFrame(parent)
    parent.scroll:SetPoint("TOPLEFT", 20, -106); parent.scroll:SetPoint("BOTTOMRIGHT", -40, 12)
    parent.listContent = CreateFrame("Frame", nil, parent.scroll)
    parent.listContent:SetWidth(850)
    parent.scroll:SetScrollChild(parent.listContent)
    parent.rows = {}
end

local DELETE_POPUP = "YIBOCORE_DELETE_CHARACTER_CACHE"
StaticPopupDialogs[DELETE_POPUP] = {
    text = "%s",
    button1 = "删除缓存",
    button2 = "取消",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function(_, data)
        local result, errorMessage = Core.CharacterCleanup:Delete(data)
        if not result then
            Core:Print("角色缓存删除失败：" .. tostring(errorMessage))
            return
        end
        local pending = 0
        for _, ownerResult in pairs(result.owners or {}) do if ownerResult.status ~= "deleted" then pending = pending + 1 end end
        if pending > 0 then
            Core:Print("角色缓存已从账号视图移除；" .. pending .. " 个插件缓存等待下次加载重试。")
        else
            Core:Print("角色缓存已删除。")
        end
        AccountView:RefreshPage()
    end,
}

local function ShowCharacterDeleteConfirmation(characterID)
    local allowed, errorMessage = Core.CharacterCleanup:CanDelete(characterID)
    if not allowed then Core:Print(errorMessage); return end
    local impact, impactError = Core.CharacterCleanup:GetImpact(characterID)
    if not impact then Core:Print(impactError); return end
    local character = impact.character
    local lines = {
        "确定删除“" .. tostring(character.name or "未知角色") .. "-" .. tostring(character.realm or "未知服务器") .. "”的插件缓存吗？",
        "",
        "将删除：",
        "• Core 角色档案",
    }
    local ownerOrder = { "YiboAltoBoss", "YiboLegendary", "YiboQuestBlocker" }
    local added = {}
    for _, addonName in ipairs(ownerOrder) do
        local ownerImpact = impact.owners[addonName]
        if ownerImpact then
            lines[#lines + 1] = "• " .. tostring(ownerImpact.label or addonName) .. "：" .. tostring(ownerImpact.detail or (ownerImpact.hasData and "有缓存" or "无缓存"))
            added[addonName] = true
        end
    end
    for addonName, ownerImpact in pairs(impact.owners) do
        if not added[addonName] then lines[#lines + 1] = "• " .. tostring(ownerImpact.label or addonName) end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "不会删除账号共享设置，也不会删除游戏角色。"
    lines[#lines + 1] = "删除后不可撤销。"
    StaticPopup_Show(DELETE_POPUP, table.concat(lines, "\n"), nil, characterID)
end

local function GetProfessionSlots(character)
    local primary = {}
    local secondary = {}
    local primaryCandidates = {}
    local profile = character.profile or {}
    for slot, profession in pairs(profile.primaryProfessions or {}) do
        slot = tonumber(slot)
        if slot and slot <= 2 and profession then primary[slot] = profession end
    end
    for _, profession in ipairs(profile.professions or {}) do
        local slot = tonumber(profession.slot)
        local isSecondary = SECONDARY_PROFESSION_IDS[profession.id] or SECONDARY_SLOT_IDS[slot] == profession.id or SECONDARY_PROFESSION_NAMES[profession.name]
        if slot and slot <= 2 and not isSecondary and not primary[slot] then
            primary[slot] = profession
        elseif isSecondary then
            secondary[profession.id or profession.name or slot] = profession
        else
            primaryCandidates[#primaryCandidates + 1] = profession
        end
    end
    local candidateIndex = 1
    for slot = 1, 2 do
        if not primary[slot] and primaryCandidates[candidateIndex] then
            primary[slot] = primaryCandidates[candidateIndex]
            candidateIndex = candidateIndex + 1
        end
    end
    return primary, secondary
end

local function GetArchiveProfession(character, field)
    local profile = character.profile or {}
    -- The first two entries are the exact primary slots returned by
    -- GetProfessions(). Prefer them directly; classification is only a
    -- compatibility fallback for older cached records.
    if field.professionSlot then
        local direct = profile.professions and profile.professions[field.professionSlot]
        if direct then return direct end
        local stored = profile.primaryProfessions and profile.primaryProfessions[field.professionSlot]
        if stored then return stored end
    end
    local primary, secondary = GetProfessionSlots(character)
    if field.professionSlot then return primary[field.professionSlot] end
    for _, profession in ipairs(profile.professions or {}) do
        if profession.id == field.skillLine or SECONDARY_SLOT_IDS[tonumber(profession.slot)] == field.skillLine then return profession end
    end
end

local function ArchiveFieldText(character, field)
    local profile = character.profile or {}
    if field.id == "identity" then return tostring(character.name or "未知角色") .. "-" .. tostring(character.realm or "未知服务器") end
    if field.id == "level" then return tostring(character.level or "?") end
    if field.id == "zone" then return profile.zone or "未知位置" end
    if field.id == "itemLevel" then return profile.itemLevel and string.format("%.0f", profile.itemLevel) or "—" end
    local profession = GetArchiveProfession(character, field)
    return profession and tostring(profession.skillLevel or "?") or "—"
end

local function ArchiveCharacters(context)
    local preview = context and context.preview == true
    local archive = ArchiveSettings()
    local filter = archive.filters[preview and "preview" or "page"]
    local levelFilter = Core.LevelFilter:Compile(filter.levelExpr)
    local characters, hidden = {}, Settings().hiddenCharacters
    for _, character in ipairs((context and context.characters) or Core.Characters:GetAll()) do
        local profiled = HasCharacterProfile(character)
        local profileMatches = filter.profile == "all" or (filter.profile == "profiled" and profiled) or (filter.profile == "missing" and not profiled)
        if profileMatches and levelFilter:Matches(character.level) and (filter.includeHidden or not hidden[character.id]) then characters[#characters + 1] = character end
    end
    return Core.CharacterSort:Sort(characters, AccountView:GetDefaultCharacterSort(), Core.Characters:GetCurrentID(), AccountView:GetCustomCharacterOrder())
end

local function GetArchiveColumnWidths(fields)
    local widths = {}
    for index, field in ipairs(fields) do
        widths[index] = math.min(field.width, field.maxWidth or field.width)
    end
    return widths
end

local function GetArchiveColumnGap(fields, index)
    return tonumber(fields[index].gapAfter) or ARCHIVE_COLUMN_GAP
end

local function GetArchiveTableWidth(fields, widths)
    local width = 16
    for index, columnWidth in ipairs(widths) do
        width = width + columnWidth
        if index < #widths then width = width + GetArchiveColumnGap(fields, index) end
    end
    return width
end

local function RefreshCharacters(parent, context)
    local current = Core.Characters:GetCurrent()
    local preview = context and context.preview == true
    local characters = (context and ArchiveCharacters(context)) or ArchiveCharacters({ preview = false })
    local query = preview and "" or string.lower(parent.search:GetText() or "")
    local filtered = {}
    for _, character in ipairs(characters) do
        local identity = string.lower((character.name or "") .. " " .. (character.realm or ""))
        if query == "" or string.find(identity, query, 1, true) then
            filtered[#filtered + 1] = character
        end
    end
    local sort = AccountView:GetDefaultCharacterSort()
    local pageFilter = ArchiveSettings().filters.page
    parent.filter:SetText("档案：" .. (PROFILE_FILTER_LABELS[pageFilter.profile] or PROFILE_FILTER_LABELS.all))
    parent.filter:SetShown(not preview)
    parent.search:SetShown(not preview); parent.searchLabel:SetShown(not preview); parent.level:SetShown(not preview); parent.levelLabel:SetShown(not preview)
    if not parent.level:HasFocus() then parent.level:SetText(pageFilter.levelExpr or "") end
    local arrow = sort.mode == "custom" and "" or (sort.direction == "asc" and " ↑" or " ↓")
    local sortLabel = (SORT_LABELS[sort.mode] or "最近登录") .. arrow
    parent.hint:SetText((preview and "预览 " or "共 ") .. #filtered .. (preview and " 名角色" or " / " .. #characters .. " 名角色") .. " · 排序：" .. sortLabel)
    local previousScroll = parent.resetScroll and 0 or parent.scroll:GetVerticalScroll()
    -- The custom scrollbar overlays the scroll frame.  Only the full archive
    -- reserves space for its hidden-state control; hover is deliberately
    -- read-only and contains no management affordances.
    local contentWidth = (parent.scroll:GetWidth() or 0) - 18
    if contentWidth <= 0 then contentWidth = 832 end
    parent.listContent:SetWidth(contentWidth)
    local fields = GetArchiveFields(preview)
    local widths = GetArchiveColumnWidths(fields)
    local tableWidth = GetArchiveTableWidth(fields, widths)
    parent.listContent:SetWidth(math.max(contentWidth, tableWidth))
    parent.listHeader:SetWidth(tableWidth)
    parent.listHeader.name:Hide(); parent.listHeader.level:Hide(); parent.listHeader.zone:Hide(); parent.listHeader.itemLevel:Hide(); parent.listHeader.professions:Hide()
    parent.listHeader.dynamicCells = parent.listHeader.dynamicCells or {}
    local x = 8
    for fieldIndex, field in ipairs(fields) do
        local cell = parent.listHeader.dynamicCells[fieldIndex]
        if not cell then cell = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); cell:SetWordWrap(false); parent.listHeader.dynamicCells[fieldIndex] = cell end
        local width = widths[fieldIndex]
        cell:ClearAllPoints(); cell:SetPoint("LEFT", x, 0); cell:SetWidth(width); cell:SetJustifyH("LEFT"); cell:SetText(field.title); cell:Show(); x = x + width + GetArchiveColumnGap(fields, fieldIndex)
    end
    for fieldIndex = #fields + 1, #parent.listHeader.dynamicCells do parent.listHeader.dynamicCells[fieldIndex]:Hide() end
    for index, character in ipairs(filtered) do
        local row = parent.rows[index]
        if not row then
            row = CreateFrame("Button", nil, parent.listContent, "BackdropTemplate"); row:SetHeight(30); row:SetPoint("TOPLEFT", 0, -((index - 1) * 34)); row:SetWidth(tableWidth)
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); row.name = AddText(row, "GameFontNormalSmall", nil, COLORS.text); row.name:SetPoint("LEFT", 9, 0); row.name:SetWidth(246)
            row.level = AddText(row, "GameFontNormalSmall", nil, COLORS.text); row.level:SetPoint("LEFT", row.name, "RIGHT", 6, 0); row.level:SetWidth(32)
            row.zone = AddText(row, "GameFontNormalSmall", nil, COLORS.muted); row.zone:SetPoint("LEFT", row.level, "RIGHT", 6, 0); row.zone:SetWidth(78)
            row.itemLevel = AddText(row, "GameFontNormalSmall", nil, COLORS.muted); row.itemLevel:SetPoint("LEFT", row.zone, "RIGHT", 6, 0); row.itemLevel:SetWidth(42)
            row.professions = AddText(row, "GameFontNormalSmall", nil, COLORS.muted); row.professions:SetPoint("LEFT", row.itemLevel, "RIGHT", 6, 0); row.professions:SetPoint("RIGHT", -86, 0)
            row.name:SetWordWrap(false); row.zone:SetWordWrap(false); row.professions:SetWordWrap(false)
            row.delete = CreateChromeButton(row, 28, 20, "删")
            row.delete:SetPoint("RIGHT", -8, 0)
            row.delete.label:SetTextColor(COLORS.danger[1], COLORS.danger[2], COLORS.danger[3])
            row.delete:SetScript("OnClick", function(self) ShowCharacterDeleteConfirmation(self.characterID) end)
            row.delete:HookScript("OnEnter", function(self)
                if self.state == "disabled" or not self.characterID then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine("删除角色缓存", COLORS.danger[1], COLORS.danger[2], COLORS.danger[3])
                GameTooltip:AddLine("删除此角色在 Core 与业务插件中的缓存；不会删除游戏角色。", COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], true)
                GameTooltip:Show()
            end)
            row.delete:HookScript("OnLeave", function() GameTooltip:Hide() end)
            parent.rows[index] = row
        end
        -- Hover uses compact rows so its maximum safe height can show twenty
        -- complete characters without activating a scrollbar.
        local rowHeight, rowStep = preview and 21 or 30, preview and 24 or 34
        row:SetHeight(rowHeight); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -((index - 1) * rowStep)); row:SetWidth(tableWidth)
        row.name:Hide(); row.level:Hide(); row.zone:Hide(); row.itemLevel:Hide(); row.professions:Hide(); row.delete:Hide()
        row.dynamicCells = row.dynamicCells or {}
        x = 8
        for fieldIndex, field in ipairs(fields) do
            local cell = row.dynamicCells[fieldIndex]
            if not cell or cell.icon then
                if cell and cell.icon then cell:Hide() end
                cell = AddText(row, "GameFontNormalSmall", nil, COLORS.muted)
                cell:SetWordWrap(false); row.dynamicCells[fieldIndex] = cell
            end
            local width = widths[fieldIndex]
            cell:ClearAllPoints(); cell:SetPoint("LEFT", x, 0); cell:SetWidth(width)
            local profession = field.professionSlot and GetArchiveProfession(character, field)
            if field.professionSlot then
                local value = ArchiveFieldText(character, field)
                local icon = profession and profession.icon
                if icon and value ~= "—" then
                    cell:SetText("|T" .. tostring(icon) .. ":16:16:0:0:64:64|t " .. value)
                else
                    cell:SetText(value)
                end
                cell:SetJustifyH(field.align or "LEFT")
            else
                cell:SetText(ArchiveFieldText(character, field))
                cell:SetJustifyH(field.align or "LEFT")
            end
            local classColor = field.id == "identity" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class or ""]
            local r, g, b = classColor and classColor.r or COLORS.muted[1], classColor and classColor.g or COLORS.muted[2], classColor and classColor.b or COLORS.muted[3]
            cell:SetTextColor(r, g, b)
            cell:Show(); x = x + width + GetArchiveColumnGap(fields, fieldIndex)
        end
        for fieldIndex = #fields + 1, #row.dynamicCells do row.dynamicCells[fieldIndex]:Hide() end
        local isCurrent = current and current.id == character.id
        if isCurrent then
            row:SetBackdropColor(COLORS.current[1], COLORS.current[2], COLORS.current[3], 0.72)
            row:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.74)
        elseif index % 2 == 0 then
            row:SetBackdropColor(0.025, 0.085, 0.10, 0.88)
            row:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.28)
        else
            row:SetBackdropColor(0.018, 0.060, 0.075, 0.88)
            row:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.28)
        end
        row:Show()
    end
    for index = #filtered + 1, #parent.rows do parent.rows[index]:Hide() end
    local contentHeight = #filtered * (preview and 24 or 34)
    local viewportHeight = parent.scroll:GetHeight() or 500
    parent.listContent:SetHeight(math.max(contentHeight, viewportHeight))
    parent.scroll:SetContentHeight(contentHeight)
    parent.scroll:SetVerticalScroll(math.min(previousScroll, math.max(0, contentHeight - viewportHeight)))
    parent.resetScroll = nil
    parent.scroll:RefreshScrollbar()
end

local function CreateSettings(parent)
    parent.heading = AddText(parent, "GameFontNormalLarge", nil, COLORS.text); parent.heading:SetPoint("TOPLEFT", 20, -18)
    parent.hint = AddText(parent, "GameFontNormalSmall", nil, COLORS.muted); parent.hint:SetPoint("TOPLEFT", 20, -47)
    parent.resetLayout = CreateChromeButton(parent, 116, 22, "重置窗口布局")
    parent.resetLayout:SetPoint("TOPRIGHT", -20, -18)
    parent.resetLayout:SetScript("OnClick", function() AccountView:ResetWindowLayout() end)
    parent.scroll = Theme:CreateScrollFrame(parent)
    parent.scroll:SetPoint("TOPLEFT", 20, -76); parent.scroll:SetPoint("BOTTOMRIGHT", -38, 14)
    parent.content = CreateFrame("Frame", nil, parent.scroll); parent.content:SetWidth(620); parent.scroll:SetScrollChild(parent.content)
    parent.rows = {}
end

local function SettingsRow(parent, index, kind)
    local row = parent.rows[index]
    if row and row.kind ~= kind then row:Hide(); row = nil end
    if not row then
        if kind == "check" then
            row = Theme:CreateCheckbox(parent.content, "")
            row:SetWidth(540)
            row.label:SetWidth(520)
        elseif kind == "heading" then
            row = AddText(parent.content, "GameFontNormal", nil, COLORS.accent)
        elseif kind == "character-order" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetSize(600, 24)
            row.label = AddText(row, "GameFontNormalSmall", nil, COLORS.text)
            row.label:SetPoint("LEFT", 2, 0); row.label:SetPoint("RIGHT", -258, 0)
            row.up = CreateChromeButton(row, 44, 22, "上移")
            row.up:SetPoint("RIGHT", -206, 0)
            row.down = CreateChromeButton(row, 44, 22, "下移")
            row.down:SetPoint("RIGHT", -158, 0)
            row.hidden = CreateChromeButton(row, 58, 22, "隐藏", false)
            row.hidden:SetPoint("RIGHT", -96, 0)
            row.delete = CreateChromeButton(row, 88, 22, "删除缓存", true)
            row.delete:SetPoint("RIGHT", -2, 0)
        elseif kind == "addon-panel" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetWidth(600)
        elseif kind == "input" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetHeight(Theme.Size.standard)
            row.label = AddText(row, "GameFontNormalSmall", nil, COLORS.muted)
            row.label:SetPoint("LEFT", 0, 0)
            row.input = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
            row.input:SetHeight(20); row.input:SetAutoFocus(false); row.input:SetMaxLetters(64)
            row.input:SetTextInsets(7, 7, 0, 0)
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

-- Settings supplied by a business addon live in this host.  Addons own their
-- data and validation, while Core owns the visual vocabulary so a legacy
-- settings frame can never leak a second theme, title bar, or scrollbar into
-- the workbench.
local function CreateHostedSettingsSection(parent, title, width, height)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetSize(width, height)
    section:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    section:SetBackdropColor(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], 0.92)
    section:SetBackdropBorderColor(COLORS.lineSoft[1], COLORS.lineSoft[2], COLORS.lineSoft[3], 1)
    section.title = Theme:CreateText(section, Theme.Font.body, COLORS.accent, "LEFT")
    section.title:SetPoint("TOPLEFT", 12, -10)
    section.title:SetPoint("TOPRIGHT", -12, -10)
    section.title:SetText(title or "")
    section.rule = section:CreateTexture(nil, "ARTWORK")
    section.rule:SetColorTexture(COLORS.lineSoft[1], COLORS.lineSoft[2], COLORS.lineSoft[3], 0.8)
    section.rule:SetHeight(1)
    section.rule:SetPoint("TOPLEFT", 12, -30)
    section.rule:SetPoint("TOPRIGHT", -12, -30)
    return section
end

local function RefreshSettings(parent)
    local settings = Settings()
    -- The settings host follows the available right pane.  Individual controls
    -- may stay compact, but hosted plugin sections can use the spare width
    -- instead of leaving a narrow legacy panel stranded on the left.
    local settingsViewportWidth = parent.scroll:GetWidth() or 0
    if settingsViewportWidth <= 100 then settingsViewportWidth = (parent:GetWidth() or 658) - 38 end
    parent.content:SetWidth(math.max(600, settingsViewportWidth - 18))
    local activeLayout = GetPageLayout(settings, AccountView.activePageID or "overview")
    local targetID = AccountView.settingsTargetPageID or "display"
    local selected = AccountView._pages[targetID]
    local displayMode, sortingMode, coreMode = targetID == "display", targetID == "sorting", targetID == "core"
    if not (displayMode or sortingMode or coreMode or (selected and not selected.internal)) then
        targetID, displayMode = "display", true
        AccountView.settingsTargetPageID = targetID
    end
    local titles = { display = "显示与入口", sorting = "角色与排序", core = "窗口与 Core" }
    parent.heading:SetText(titles[targetID] or (selected.title .. "业务设置"))
    parent.hint:SetText(displayMode and "集中管理插件页面、独立入口与显示字段。" or (sortingMode and "统一设置账号角色的默认排列规则。" or (coreMode and "管理窗口布局与 YiboCore 默认入口。" or "这里只保留该插件自身的业务规则与数据管理。")))
    parent.resetLayout:SetShown(coreMode)

    local index, y, gridColumn = 0, 0, 0
    local gridGap, gridMinimum = 16, 230
    local gridColumns = math.max(1, math.floor((parent.content:GetWidth() + gridGap) / (gridMinimum + gridGap)))
    local gridWidth = math.floor((parent.content:GetWidth() - gridGap * (gridColumns - 1)) / gridColumns)
    local function PlaceGridControl(row)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2 + gridColumn * (gridWidth + gridGap), -y); row:SetWidth(gridWidth)
        gridColumn = gridColumn + 1
        if gridColumn >= gridColumns then y = y + Theme.Size.standard + 4; gridColumn = 0 end
    end
    local function FinishGridRow()
        if gridColumn ~= 0 then
            y = y + Theme.Size.standard + 4
            gridColumn = 0
        end
    end
    local function SetGridMinimum(value)
        FinishGridRow()
        gridMinimum = value
        gridColumns = math.max(1, math.floor((parent.content:GetWidth() + gridGap) / (gridMinimum + gridGap)))
        gridWidth = math.floor((parent.content:GetWidth() - gridGap * (gridColumns - 1)) / gridColumns)
    end
    local function Heading(text)
        FinishGridRow()
        index = index + 1; local row = SettingsRow(parent, index, "heading"); PlaceSettingsRow(row, y); row:SetText(text); row:SetTextColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3]); row:Show(); y = y + 28
    end
    local function Check(label, checked, callback)
        index = index + 1; local row = SettingsRow(parent, index, "check")
        PlaceGridControl(row); row.label:SetWidth(math.max(40, gridWidth - 24))
        row.label:SetText(label); row:SetChecked(checked); row:SetScript("OnClick", function(self) self:SetChecked(not self:GetChecked()); callback(self:GetChecked()); AccountView:RefreshPage() end); row:Show()
    end
    local function Button(label, callback, width, kind, selected)
        index = index + 1; local row = SettingsRow(parent, index, "button")
        PlaceGridControl(row)
        row.kind = kind or "default"; row:SetText(label); row:SetState(selected and "selected" or "default"); row:SetScript("OnClick", callback); row:Show()
        return row
    end
    local function Input(label, value, callback)
        index = index + 1; local row = SettingsRow(parent, index, "input")
        PlaceGridControl(row)
        row.label:SetText(label); row.label:SetWidth(math.min(84, math.floor(gridWidth * 0.36)))
        row.input:ClearAllPoints(); row.input:SetPoint("LEFT", row.label, "RIGHT", 6, 0); row.input:SetPoint("RIGHT", 0, 0)
        row.input:SetText(value or "")
        local function Save(control)
            local valid, normalized, badToken = Core.LevelFilter:Validate(control:GetText())
            if not valid then
                control:SetText(value or "")
                Core:Print("等级过滤格式无效：" .. tostring(badToken))
                return
            end
            callback(normalized)
            control:SetText(normalized)
            AccountView:RefreshPage()
        end
        row.input:SetScript("OnEnterPressed", function(control) Save(control); control:ClearFocus() end)
        row.input:SetScript("OnEditFocusLost", Save)
        row.input:SetScript("OnEscapePressed", function(control) control:SetText(value or ""); control:ClearFocus() end)
        row:Show()
        return row
    end
    local function AddonPanel(details)
        if type(details.CreateSettingsPanel) ~= "function" then return end
        FinishGridRow()
        index = index + 1
        local row = SettingsRow(parent, index, "addon-panel")
        row:SetWidth(parent.content:GetWidth() or 600)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2, -y)
        row:Show()
        local ok, heightOrError = xpcall(function()
            return details.CreateSettingsPanel(row, {
                refreshPage = function() AccountView:RefreshPage() end,
                notifyPageChanged = function() AccountView:NotifyPageChanged(selected.id) end,
                createSection = CreateHostedSettingsSection,
                createText = function(owner, size, color, justify) return Theme:CreateText(owner, size, color, justify) end,
                createButton = function(owner, width, label, kind) return Theme:CreateButton(owner, width, label, kind) end,
                createCheckbox = function(owner, label) return Theme:CreateCheckbox(owner, label) end,
                bindTooltip = function(control, title, lines) Theme:BindTooltip(control, title, lines) end,
                selectSettingsTarget = function(targetID) AccountView:SelectSettingsTarget(targetID) end,
            })
        end, function(message) return tostring(message) end)
        if not ok then
            Core:Print("插件 “" .. selected.title .. "” 的嵌入设置创建失败：" .. tostring(heightOrError))
            if not row.errorLabel then
                row.errorLabel = AddText(row, "GameFontNormalSmall", nil, COLORS.danger)
                row.errorLabel:SetPoint("TOPLEFT", 2, 0); row.errorLabel:SetPoint("RIGHT", -2, 0)
                row.errorLabel:SetWordWrap(true)
            end
            row.errorLabel:SetText("业务设置加载失败：" .. tostring(heightOrError))
            row.errorLabel:Show()
            row:SetHeight(40)
            y = y + 50
            return
        end
        if row.errorLabel then row.errorLabel:Hide() end
        row:SetHeight(math.max(1, tonumber(heightOrError) or row:GetHeight() or 1))
        y = y + row:GetHeight() + 10
    end
    local function SortControls(pageID)
        local page = pageID and AccountView._pages[pageID]
        local saved = page and AccountView:GetPageCharacterSort(pageID) or AccountView:GetDefaultCharacterSort()
        local effective = page and AccountView:GetEffectiveCharacterSort(pageID) or saved
        if page then
            Button("跟随通用设置", function()
                AccountView:ResetPageCharacterSort(pageID)
            end, 300, "default", saved.mode == "inherit")
        end
        for _, mode in ipairs(SORT_MODES) do
            local selectedMode = mode
            Button(SORT_LABELS[selectedMode], function()
                local nextSettings = Copy(effective)
                nextSettings.inherited = nil
                nextSettings.mode = selectedMode
                nextSettings.direction = DefaultDirection(selectedMode)
                if page then AccountView:SetPageCharacterSort(pageID, nextSettings) else AccountView:SetDefaultCharacterSort(nextSettings) end
            end, 300, "default", saved.mode == selectedMode)
        end
        if effective.mode ~= "custom" then
            Button("排序方向：" .. (effective.direction == "asc" and "升序 ↑" or "降序 ↓"), function()
                local nextSettings = Copy(effective)
                nextSettings.inherited = nil
                nextSettings.direction = nextSettings.direction == "asc" and "desc" or "asc"
                if page then AccountView:SetPageCharacterSort(pageID, nextSettings) else AccountView:SetDefaultCharacterSort(nextSettings) end
            end, 300, "secondary")
        end
        Check("当前角色置顶", effective.pinCurrent == true, function(checked)
            local nextSettings = Copy(effective)
            nextSettings.inherited = nil
            nextSettings.pinCurrent = checked
            if page then AccountView:SetPageCharacterSort(pageID, nextSettings) else AccountView:SetDefaultCharacterSort(nextSettings) end
        end)
    end
    local function CharacterOrderRows()
        Button("按最近登录顺序重建", function() AccountView:RebuildCustomCharacterOrder("recent") end, 300, "secondary")
        Button("恢复初始登记顺序", function() AccountView:RebuildCustomCharacterOrder("seen") end, 300, "secondary")
        local byID = {}
        for _, character in ipairs(Core.Characters:GetAll()) do byID[character.id] = character end
        local order = AccountView:GetCustomCharacterOrder()
        local pageSize = 12
        local totalPages = math.max(1, math.ceil(#order / pageSize))
        parent.characterOrderPage = math.max(1, math.min(tonumber(parent.characterOrderPage) or 1, totalPages))
        Button("上一页（" .. parent.characterOrderPage .. " / " .. totalPages .. "）", function()
            parent.characterOrderPage = math.max(1, parent.characterOrderPage - 1); AccountView:RefreshPage()
        end, 300, "secondary")
        Button("下一页（" .. parent.characterOrderPage .. " / " .. totalPages .. "）", function()
            parent.characterOrderPage = math.min(totalPages, parent.characterOrderPage + 1); AccountView:RefreshPage()
        end, 300, "secondary")
        FinishGridRow()
        local first = (parent.characterOrderPage - 1) * pageSize + 1
        local last = math.min(#order, first + pageSize - 1)
        local orderGap, orderMinimum = 16, 520
        local orderColumns = math.max(1, math.floor((parent.content:GetWidth() + orderGap) / (orderMinimum + orderGap)))
        local orderWidth = math.floor((parent.content:GetWidth() - orderGap * (orderColumns - 1)) / orderColumns)
        local orderColumn = 0
        for orderIndex = first, last do
            local characterID = order[orderIndex]
            local character = byID[characterID]
            if character then
                index = index + 1
                local row = SettingsRow(parent, index, "character-order")
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2 + orderColumn * (orderWidth + orderGap), -y); row:SetWidth(orderWidth)
                row.label:SetText(tostring(orderIndex) .. ". " .. (character.name or "未知角色") .. "-" .. (character.realm or "未知服务器") .. " · " .. tostring(character.level or "?") .. "级")
                local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class or ""]
                row.label:SetTextColor(classColor and classColor.r or COLORS.text[1], classColor and classColor.g or COLORS.text[2], classColor and classColor.b or COLORS.text[3])
                row.up:SetState(orderIndex == 1 and "disabled" or "default")
                row.down:SetState(orderIndex == #order and "disabled" or "default")
                row.up:EnableMouse(orderIndex > 1); row.down:EnableMouse(orderIndex < #order)
                local rowCharacterID = characterID
                row.up:SetScript("OnClick", function() AccountView:MoveCustomCharacter(rowCharacterID, -1) end)
                row.down:SetScript("OnClick", function() AccountView:MoveCustomCharacter(rowCharacterID, 1) end)
                local hidden = Settings().hiddenCharacters[rowCharacterID] == true
                row.hidden:SetText(hidden and "显示" or "隐藏")
                row.hidden.kind = "secondary"; row.hidden:SetState(hidden and "selected" or "default")
                row.hidden:SetScript("OnClick", function()
                    AccountView:SetCharacterHidden(rowCharacterID, not hidden)
                end)
                local current = Core.Characters:GetCurrentID() == characterID
                row.delete:SetText(current and "当前角色" or "删除缓存")
                row.delete:SetState(current and "disabled" or "default")
                row.delete:EnableMouse(not current)
                row.delete:SetScript("OnClick", function() ShowCharacterDeleteConfirmation(rowCharacterID) end)
                row:Show()
                orderColumn = orderColumn + 1
                if orderColumn >= orderColumns then y = y + 28; orderColumn = 0 end
            end
        end
        if orderColumn ~= 0 then y = y + 28 end
    end

    if sortingMode then
        Heading("默认角色排序")
        SortControls(nil)
        Heading("角色顺序与缓存")
        Button(parent.showCharacterOrder and "▾ 收起顺序与缓存" or "▸ 打开顺序与缓存", function()
            parent.showCharacterOrder = not parent.showCharacterOrder
            AccountView:RefreshPage()
        end, 300, "disclosure")
        if parent.showCharacterOrder then
            FinishGridRow()
            CharacterOrderRows()
        end
    elseif coreMode then
        Heading("窗口布局")
        Button("重置窗口布局", function() AccountView:ResetWindowLayout() end)
        Button("窗口尺寸：" .. (activeLayout.mode == "manual" and "此页面手动固定（恢复自动适配）" or "此页面自动适配"), function()
            settings.pageLayouts[AccountView.activePageID or "overview"] = { mode = "auto" }
            AccountView:ShowPage(AccountView.activePageID or "overview", { autoFit = true })
        end, 300)
        Heading("Core 入口")
        Check("显示 Core 小地图入口", settings.entry.minimap.show ~= false, function(checked)
            settings.entry.minimap.show = checked
            if Core.Entry then Core.Entry:Refresh() end
        end)
        Check("启用 Broker 入口（重载界面后生效）", settings.entry.broker.show ~= false, function(checked)
            settings.entry.broker.show = checked
        end)
        Heading("入口悬停页面")
        local selectedPreviewPage = AccountView:GetPreviewPage()
        for _, page in ipairs(AccountView:GetPreviewPageOptions()) do
            local optionPage = page
            local option = Button(optionPage.title, function()
                settings.entry.previewPageID = optionPage.id
                AccountView:RefreshPage()
            end, 286)
            option:SetState(optionPage.id == selectedPreviewPage.id and "selected" or "default")
        end
        FinishGridRow()
    elseif displayMode then
        local archive = ArchiveSettings()
        local function CycleArchiveProfile(mode)
            local values = { "all", "profiled", "missing" }
            local current = archive.filters[mode].profile
            for position, value in ipairs(values) do
                if value == current then archive.filters[mode].profile = values[(position % #values) + 1]; break end
            end
            AccountView:RefreshPage()
        end
        SetGridMinimum(260)
        Heading("角色档案：显示与筛选")
        Button("角色档案筛选：" .. (PROFILE_FILTER_LABELS[archive.filters.page.profile] or PROFILE_FILTER_LABELS.all), function() CycleArchiveProfile("page") end, 300)
        Check("筛选时包含已隐藏角色", archive.filters.page.includeHidden == true, function(checked) archive.filters.page.includeHidden = checked end)
        Input("等级过滤", archive.filters.page.levelExpr, function(value) archive.filters.page.levelExpr = value end)
        Heading("角色档案：显示字段")
        SetGridMinimum(160)
        for _, field in ipairs(CHARACTER_ARCHIVE_FIELDS) do
            Check(field.title, ArchiveFieldVisible(field, false), function(checked) archive.fields[field.id] = checked end)
        end
        Heading("角色档案悬停：显示与筛选")
        SetGridMinimum(260)
        Button("悬停筛选：" .. (PROFILE_FILTER_LABELS[archive.filters.preview.profile] or PROFILE_FILTER_LABELS.all), function() CycleArchiveProfile("preview") end, 300)
        Check("筛选时包含已隐藏角色", archive.filters.preview.includeHidden == true, function(checked) archive.filters.preview.includeHidden = checked end)
        Input("等级过滤", archive.filters.preview.levelExpr, function(value) archive.filters.preview.levelExpr = value end)
        Heading("角色档案悬停：显示字段")
        SetGridMinimum(160)
        for _, field in ipairs(CHARACTER_ARCHIVE_FIELDS) do
            Check(field.title, ArchiveFieldVisible(field, true), function(checked) archive.previewFields[field.id] = checked end)
        end
        Heading("插件页面与入口")
        SetGridMinimum(260)
        for _, page in ipairs(AccountView._pageOrder) do
            if not page.internal then
                local entry = Core.Entry and Core.Entry.GetBusinessEntryByPageID and Core.Entry:GetBusinessEntryByPageID(page.id)
                Check(page.title .. "显示在账号视图", PageEnabled(page), function(checked) settings.pages[page.id] = checked end)
                if entry then
                    Button(page.title .. "入口：" .. Core.Entry:GetBusinessEntryModeLabel(Core.Entry:GetBusinessEntryMode(entry.id)), function()
                        local modes = { "none", "broker", "minimap", "both" }
                        local current = Core.Entry:GetBusinessEntryMode(entry.id)
                        for i, mode in ipairs(modes) do if mode == current then settings.entry.pageModes[entry.id] = modes[(i % #modes) + 1]; break end end
                        Core.Entry:Refresh(); AccountView:RefreshPage()
                    end)
                end
            end
        end
        Heading("主表字段与悬停预览")
        for _, page in ipairs(AccountView._pageOrder) do
            if not page.internal and #page.fields > 0 then
                Heading(page.title)
                for _, field in ipairs(page.fields) do
                    Check("主表 · " .. field.title, AccountView:GetFieldVisible(page.id, field), function(checked) AccountView:SetFieldVisible(page.id, field.id, checked) end)
                    if page.previewEnabled and type(page.SetPreviewFieldVisible) == "function" then
                        Check("悬停 · " .. field.title, GetPreviewFieldVisible(page, field), function(checked) page.SetPreviewFieldVisible(field.id, checked) end)
                    end
                end
            end
        end
    else
        local details = selected.settings or {}
        if details.description then
            local text = SettingsRow(parent, index + 1, "heading"); index = index + 1; PlaceSettingsRow(text, y); text:SetText(details.description); text:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3]); text:Show(); y = y + 28
        end
            if type(details.CreateSettingsPanel) == "function" then
                AddonPanel(details)
            elseif type(details.OpenAddonSettings) == "function" then
                Heading("插件专属设置")
                Button(details.openLabel or "打开详细设置", function()
                    local ok, errorMessage = xpcall(details.OpenAddonSettings, function(message) return tostring(message) end)
                    if not ok then Core:Print("插件 “" .. selected.title .. "” 的设置打开失败：" .. errorMessage) end
                end)
            else
                Heading("暂无插件专属设置")
            end
    end
    for stale = index + 1, #parent.rows do parent.rows[stale]:Hide() end
    parent.content:SetHeight(math.max(y + 8, parent.scroll:GetHeight() or 1))
    parent.scroll:RefreshScrollbar()
end

local ABOUT_ADDONS = {
    {
        name = "YiboAltoBoss",
        version = "2.0",
        description = "汇总多角色首领进度，快速决定下一步。",
        icon = "Interface\\AddOns\\YiboCore\\Media\\YAB_MinimapIcon",
        url = "https://www.curseforge.com/wow/addons/yiboaltoboss",
    },
    {
        name = "YiboLegendary",
        version = "0.3",
        description = "追踪多角色传说任务与橙色传说装备进度。",
        icon = "Interface\\AddOns\\YiboLegendary\\Media\\YiboLegendaryIcon-v1.tga",
        url = "https://www.curseforge.com/wow/addons/yibolegendary",
    },
    {
        name = "YiboQuestBlocker",
        version = "2.0.0",
        description = "识别任务限制与风险，避免误接关键任务。",
        icon = "Interface\\AddOns\\YiboCore\\Media\\YQB_MinimapIcon",
        url = "https://www.curseforge.com/wow/addons/yiboquestblocker",
    },
    {
        name = "YiboBeastPaths",
        version = "1.5",
        description = "在地图上显示稀有猎人宠物的巡逻路线。",
        icon = "Interface\\AddOns\\YiboCore\\Media\\YBP_AddonIcon",
        url = "https://www.curseforge.com/wow/addons/yibobeastpaths",
        independent = true,
    },
}

local function SetAboutLinkOpen(parent, target)
    for _, row in ipairs(parent.addonRows) do
        local open = row == target and not row.linkOpen
        row.linkOpen = open
        row.linkBox:SetShown(open)
        row.copyHint:SetShown(open)
        row.linkButton:SetText(open and "收起链接" or "获取链接")
        row:SetHeight(open and 130 or 96)
        if open then
            row.linkBox:SetText(row.addon.url)
            row.linkBox:SetFocus()
            row.linkBox:HighlightText()
        else
            row.linkBox:ClearFocus()
        end
    end

    parent:LayoutAboutContent()
end

local function CreateAboutAddonRow(parent, addon)
    local row = CreateFrame("Frame", nil, parent.content or parent, "BackdropTemplate")
    row:SetHeight(96)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    row:SetBackdropColor(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], 0.72)
    row:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.58)
    row.addon = addon

    row.iconFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.iconFrame:SetSize(72, 72); row.iconFrame:SetPoint("TOPLEFT", 12, -12)
    row.iconFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    row.iconFrame:SetBackdropColor(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], 1)
    row.iconFrame:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.72)
    row.icon = row.iconFrame:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", 3, -3); row.icon:SetPoint("BOTTOMRIGHT", -3, 3); row.icon:SetTexture(addon.icon)

    row.name = AddText(row, "GameFontNormal", 14, COLORS.text)
    row.name:SetPoint("TOPLEFT", row.iconFrame, "TOPRIGHT", 12, -2); row.name:SetText(addon.name)
    row.version = AddText(row, "GameFontNormalSmall", 11, COLORS.muted)
    row.version:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.version:SetText(addon.version and ("v" .. addon.version) or "")
    row.description = AddText(row, "GameFontNormalSmall", 12, COLORS.muted)
    row.description:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -8); row.description:SetPoint("RIGHT", -154, 0); row.description:SetText(addon.description)
    if addon.independent then
        row.badge = AddText(row, "GameFontNormalSmall", 11, COLORS.muted)
        row.badge:SetJustifyH("RIGHT")
        row.badge:SetPoint("RIGHT", -142, 0); row.badge:SetText("独立作品")
    end

    row.linkButton = CreateChromeButton(row, 112, 26, "获取链接")
    row.linkButton:SetPoint("TOPRIGHT", -12, -22)
    row.linkBox = CreateFrame("EditBox", nil, row, "BackdropTemplate")
    row.linkBox:SetHeight(24); row.linkBox:SetPoint("BOTTOMLEFT", 96, 9); row.linkBox:SetPoint("BOTTOMRIGHT", -128, 9)
    row.linkBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    row.linkBox:SetBackdropColor(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], 1)
    row.linkBox:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.82)
    row.linkBox:SetFontObject(GameFontHighlightSmall)
    row.linkBox:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    row.linkBox:SetTextInsets(7, 7, 0, 0); row.linkBox:SetAutoFocus(false); row.linkBox:SetMaxLetters(240)
    row.linkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    row.linkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    row.linkBox:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    row.linkBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput and self:GetText() ~= addon.url then
            self:SetText(addon.url); self:HighlightText()
        end
    end)
    row.copyHint = AddText(row, "GameFontNormalSmall", 11, COLORS.accent)
    row.copyHint:SetJustifyH("RIGHT")
    row.copyHint:SetPoint("LEFT", row.linkBox, "RIGHT", 8, 0); row.copyHint:SetPoint("RIGHT", -12, 0); row.copyHint:SetText("按 Ctrl+C 复制")
    row.linkBox:Hide(); row.copyHint:Hide()
    row.linkButton:SetScript("OnClick", function() SetAboutLinkOpen(parent, row) end)
    parent.addonRows[#parent.addonRows + 1] = row
    parent.addonRowsByName[addon.name] = row
    return row
end

local function CreateAbout(parent)
    parent.addonRows = {}
    parent.addonRowsByName = {}
    -- The about page is a growing directory. Keep its footer and page chrome
    -- fixed, while only the directory content participates in scrolling.
    parent.scroll = Theme:CreateScrollFrame(parent)
    parent.scroll:SetPoint("TOPLEFT", 20, -18); parent.scroll:SetPoint("BOTTOMRIGHT", -38, 34)
    parent.content = CreateFrame("Frame", nil, parent.scroll)
    parent.content:SetPoint("TOPLEFT")
    parent.scroll:SetScrollChild(parent.content)
    local function GetContentWidth(scroll)
        local scrollbarWidth = scroll.ScrollBar and scroll.ScrollBar:GetWidth() or 14
        return math.max(1, (scroll:GetWidth() or 1) - scrollbarWidth - 6)
    end
    parent.scroll:SetScript("OnSizeChanged", function(scroll)
        parent.content:SetWidth(GetContentWidth(scroll))
        scroll:RefreshScrollbar()
    end)

    parent.hero = CreateFrame("Frame", nil, parent.content, "BackdropTemplate")
    parent.hero:SetPoint("TOPLEFT", 0, 0); parent.hero:SetPoint("TOPRIGHT", 0, 0); parent.hero:SetHeight(112)
    parent.hero:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    parent.hero:SetBackdropColor(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], 0.70)
    parent.hero:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.72)
    parent.hero.iconFrame = CreateFrame("Frame", nil, parent.hero, "BackdropTemplate")
    parent.hero.iconFrame:SetSize(72, 72); parent.hero.iconFrame:SetPoint("LEFT", 16, 0)
    parent.hero.iconFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    parent.hero.iconFrame:SetBackdropColor(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], 1)
    parent.hero.iconFrame:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.72)
    parent.hero.icon = parent.hero.iconFrame:CreateTexture(nil, "ARTWORK")
    parent.hero.icon:SetPoint("TOPLEFT", 3, -3); parent.hero.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    parent.hero.icon:SetTexture("Interface\\AddOns\\YiboCore\\Media\\YiboCoreLogo-v7")
    parent.hero.title = AddText(parent.hero, "GameFontNormalLarge", 19, COLORS.text)
    parent.hero.title:SetPoint("TOPLEFT", 110, -20); parent.hero.title:SetText("YiboCore")
    parent.hero.description = AddText(parent.hero, "GameFontNormalSmall", 12, COLORS.text)
    parent.hero.description:SetPoint("TOPLEFT", parent.hero.title, "BOTTOMLEFT", 0, -9); parent.hero.description:SetText("统一管理 Yibo 系列的账号角色、入口与业务页面")
    parent.hero.status = AddText(parent.hero, "GameFontNormalSmall", 12, COLORS.muted)
    parent.hero.status:SetJustifyH("RIGHT")
    parent.hero.status:SetPoint("RIGHT", -18, 0)

    parent.childHeading = AddText(parent.content, "GameFontNormal", 14, COLORS.accent)
    parent.childHeading:SetText("YiboCore 子插件")
    parent.otherHeading = AddText(parent.content, "GameFontNormal", 14, COLORS.accent)
    parent.otherHeading:SetText("探索其它 Yibo 插件")
    parent.otherLine = parent.content:CreateTexture(nil, "ARTWORK")
    parent.otherLine:SetHeight(1)
    parent.otherLine:SetColorTexture(COLORS.lineSoft[1], COLORS.lineSoft[2], COLORS.lineSoft[3], COLORS.lineSoft[4])
    for _, addon in ipairs(ABOUT_ADDONS) do CreateAboutAddonRow(parent, addon) end
    parent.footer = AddText(parent, "GameFontNormalSmall", 11, COLORS.muted, "RIGHT")
    parent.footer:SetPoint("BOTTOMRIGHT", -20, 12); parent.footer:SetText("作者 YiboSoft · CurseForge")
    parent.LayoutAboutContent = function(container)
        local y = 140
        container.childHeading:ClearAllPoints(); container.childHeading:SetPoint("TOPLEFT", 0, -y)
        y = y + 26
        for _, row in ipairs(container.addonRows) do
            if not row.addon.independent then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y); row:SetPoint("TOPRIGHT", 0, -y)
                y = y + row:GetHeight() + 6
            end
        end
        y = y + 14
        container.otherHeading:ClearAllPoints(); container.otherHeading:SetPoint("TOPLEFT", 0, -y)
        y = y + 22
        container.otherLine:ClearAllPoints(); container.otherLine:SetPoint("TOPLEFT", 0, -y); container.otherLine:SetPoint("TOPRIGHT", 0, -y)
        y = y + 12
        for _, row in ipairs(container.addonRows) do
            if row.addon.independent then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y); row:SetPoint("TOPRIGHT", 0, -y)
                y = y + row:GetHeight() + 6
            end
        end
        local contentHeight = y + 4
        container.content:SetHeight(math.max(contentHeight, container.scroll:GetHeight() or 1))
        container.scroll:SetContentHeight(contentHeight)
        container.scroll:RefreshScrollbar()
    end
    parent.content:SetWidth(GetContentWidth(parent.scroll))
    parent:LayoutAboutContent()
end

local function RefreshAbout(parent)
    parent.hero.title:SetText("YiboCore v" .. tostring(Core:GetVersion() or "?"))
    local connected = 0
    for _, addon in ipairs(ABOUT_ADDONS) do
        local registered = Core.Registry and Core.Registry:Get(addon.name)
        if registered then
            if parent.addonRowsByName[addon.name] then
                parent.addonRowsByName[addon.name].version:SetText("v" .. tostring(registered.version or addon.version or "?"))
            end
            if not addon.independent then connected = connected + 1 end
        end
    end
    parent.hero.status:SetText("已连接 " .. connected .. " 个子插件")
end

local function GetAboutLayoutMetrics()
    return { minWidth = 760, preferredWidth = 942, minHeight = 740, preferredHeight = 760, verticalOverflow = "content" }
end

local function GetCharacterHoverMetrics(context)
    local count = #ArchiveCharacters(context)
    local fields = GetArchiveFields(true)
    local tableWidth = GetArchiveTableWidth(fields, GetArchiveColumnWidths(fields))
    -- Include chrome, heading, table header and bottom padding.  The previous
    -- formula counted only rows, which made a nominal 20-row preview clip at
    -- roughly 13 rows before the scrollbar appeared.
    return {
        minWidth = 420,
        preferredWidth = math.max(520, tableWidth + 72),
        minHeight = 150,
        preferredHeight = 168 + math.min(count, 20) * 24,
        verticalOverflow = "content",
    }
end

AccountView._pages.overview = { id = "overview", title = "概览", order = -20, internal = true, previewEnabled = true, Create = CreateOverview, Refresh = RefreshOverview }
AccountView._pages.characters = { id = "characters", title = "角色档案", order = -10, internal = true, previewEnabled = true, Create = CreateCharacters, Refresh = RefreshCharacters, GetHoverMetrics = GetCharacterHoverMetrics }
AccountView._pages.about = { id = "about", title = "关于", order = 990, internal = true, Create = CreateAbout, Refresh = RefreshAbout, GetLayoutMetrics = GetAboutLayoutMetrics }
AccountView._pages.settings = { id = "settings", title = "设置", order = 999, internal = true, Create = CreateSettings, Refresh = RefreshSettings }
Core.Events:Register("CHARACTER_ID_CHANGED", AccountView, function(self, oldID, newID)
    local settings = Settings()
    local order, changed = Core.CharacterSort:ReplaceCharacterID(settings.customCharacterOrder, oldID, newID)
    if changed then settings.customCharacterOrder = order end
    if settings.hiddenCharacters[oldID] ~= nil then
        if settings.hiddenCharacters[newID] == nil then settings.hiddenCharacters[newID] = settings.hiddenCharacters[oldID] end
        settings.hiddenCharacters[oldID] = nil
        changed = true
    end
    if changed then self:RefreshPage() end
end)
Core.Events:Register("CHARACTER_CACHE_DELETED", AccountView, function(self)
    self:RefreshPage()
end)
Core.Capabilities:Register("account-view", 1)
