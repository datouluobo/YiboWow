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

local CORE_ENTRY_MODES = { none = true, broker = true, minimap = true, both = true }

local ARCHIVE_COLUMN_GAP = 10

local function HasCharacterProfile(character)
    for _, field in ipairs(Core.Fields:GetByConsumer("character-archive")) do
        if Core.Fields:GetValue(character, field) ~= nil then return true end
    end
    return false
end

local function ArchiveSettings()
    local settings = Settings()
    settings.characterArchive = type(settings.characterArchive) == "table" and settings.characterArchive or {}
    local archive = settings.characterArchive
    archive.fields = type(archive.fields) == "table" and archive.fields or {}
    archive.previewFields = type(archive.previewFields) == "table" and archive.previewFields or {}
    local legacyIDs = { identity = "character.identity", level = "character.level", itemLevel = "character.item-level", zone = "character.zone", primary = "character.profession-primary", secondary = "character.profession-secondary", archaeology = "character.archaeology", fishing = "character.fishing", cooking = "character.cooking", firstAid = "character.first-aid" }
    for oldID, newID in pairs(legacyIDs) do
        if archive.fields[newID] == nil and archive.fields[oldID] ~= nil then archive.fields[newID] = archive.fields[oldID] end
        if archive.previewFields[newID] == nil and archive.previewFields[oldID] ~= nil then archive.previewFields[newID] = archive.previewFields[oldID] end
    end
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
    if values[field.id] == nil then
        return preview and field.defaultPreviewVisible == true or (not preview and field.defaultVisible == true)
    end
    return values[field.id] == true
end

local function GetArchiveFields(preview)
    local fields = {}
    for _, field in ipairs(Core.Fields:GetByConsumer("character-archive")) do
        if ArchiveFieldVisible(field, preview) then fields[#fields + 1] = field end
    end
    if #fields == 0 then fields[1] = Core.Fields:GetByConsumer("character-archive")[1] end
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
    settings.selectedRealmScope = type(settings.selectedRealmScope) == "string" and settings.selectedRealmScope or "all"
    settings.hiddenCharacters = settings.hiddenCharacters or {}
    settings.characterSort = Core.CharacterSort:NormalizeSettings(settings.characterSort)
    settings.pageCharacterSorts = type(settings.pageCharacterSorts) == "table" and settings.pageCharacterSorts or {}
    settings.columnPages = type(settings.columnPages) == "table" and settings.columnPages or {}
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
    if not CORE_ENTRY_MODES[settings.entry.coreMode] then
        local hasBroker = settings.entry.broker.show ~= false
        local hasMinimap = settings.entry.minimap.show ~= false
        settings.entry.coreMode = hasBroker and hasMinimap and "both" or (hasBroker and "broker" or (hasMinimap and "minimap" or "none"))
    end
    settings.entry.previewPageID = type(settings.entry.previewPageID) == "string" and settings.entry.previewPageID or "overview"
    settings.entry.showPreviewWhileMainWindowOpen = settings.entry.showPreviewWhileMainWindowOpen == true
    settings.entry.pageModes = settings.entry.pageModes or {}
    settings.entry.pagePositions = settings.entry.pagePositions or {}
    return settings
end

function AccountView:GetSettings()
    return Settings()
end

-- Character matrices are a single account surface.  Never split the roster
-- into horizontal pages: a partial roster is harder to compare than a dense
-- complete matrix, and page arrows conceal the missing characters.
function AccountView:GetColumnPage(pageID, stateKey, columns, availableWidth, fixedWidth, columnWidth)
    local count = #(columns or {})
    local visible = {}
    for index, column in ipairs(columns or {}) do visible[index] = column end
    return visible, { page = 1, pages = 1, first = count > 0 and 1 or 0, last = count, capacity = count, total = count }
end

function AccountView:GetColumnPageByWidth(pageID, stateKey, columns, availableWidth, fixedWidth, getWidth)
    local count = #(columns or {})
    local visible = {}
    for index, column in ipairs(columns or {}) do visible[index] = column end
    return visible, { page = 1, pages = 1, first = count > 0 and 1 or 0, last = count, total = count }
end

function AccountView:SetColumnPage(pageID, stateKey, page, totalPages)
    local pages = Settings().columnPages
    pages[pageID] = pages[pageID] or {}
    pages[pageID][stateKey] = math.max(1, math.min(tonumber(page) or 1, tonumber(totalPages) or 1))
    self:RefreshPage()
end

function AccountView:GetColumnPagerWidth(noun, total)
    -- Kept as a zero-width compatibility shim for external business pages.
    -- Character matrices no longer have horizontal pagination chrome.
    return 0
end

function AccountView:UpdateColumnPager(parent, pageID, stateKey, info, anchor, noun)
    parent.yiboColumnPager = parent.yiboColumnPager or {}
    local pager = parent.yiboColumnPager
    self._columnPagers = self._columnPagers or {}
    self._columnPagers[pager] = true
    if pager.previous then pager.previous:Hide() end
    if pager.next then pager.next:Hide() end
    if pager.label then pager.label:Hide() end
end

function AccountView:HideColumnPagers()
    -- Pagers are hosted in the shared title bar so they never consume matrix
    -- width.  Their lifetime must nevertheless remain page-local: otherwise
    -- a pager from a character-column matrix survives into a row-oriented
    -- page, where it is both misleading and inoperative.
    for pager in pairs(self._columnPagers or {}) do
        if pager.previous then pager.previous:Hide() end
        if pager.next then pager.next:Hide() end
        if pager.label then pager.label:Hide() end
    end
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

local function SafeRect(preview)
    local safety = preview and Theme.Geometry.previewSafety or Theme.Geometry.mainSafety
    local width = UIParent:GetWidth() or 1600
    local height = UIParent:GetHeight() or 900
    return {
        left = safety.left, right = math.max(safety.left + 1, width - safety.right),
        bottom = safety.bottom, top = math.max(safety.bottom + 1, height - safety.top),
        width = math.max(1, width - safety.left - safety.right),
        height = math.max(1, height - safety.top - safety.bottom),
    }
end

local function ScreenBounds()
    local safe = SafeRect(false)
    return safe.width, safe.height
end

local function ShellMetrics(preview)
    local geometry = Theme.Geometry
    if preview then
        return geometry.shellBorder * 2, geometry.titleBar + geometry.shellBorder * 2
    end
    return geometry.navigation + geometry.shellBorder * 2 + 1, geometry.titleBar + geometry.shellBorder * 2
end

local function ClampWindowSize(width, height)
    local maxWidth, maxHeight = ScreenBounds()
    local minWidth, minHeight = math.min(760, maxWidth), math.min(150, maxHeight)
    width = math.max(minWidth, math.min(tonumber(width) or 1120, maxWidth))
    height = math.max(minHeight, math.min(tonumber(height) or 650, maxHeight))
    return width, height, minWidth, minHeight, maxWidth, maxHeight
end

local function SurfaceMetrics(page, context)
    local metrics = { minContentWidth = 582, naturalContentWidth = 942, minContentHeight = 150, naturalContentHeight = 603, fixedLeftWidth = 0, fixedTopHeight = 0, horizontalOverflow = "content", verticalOverflow = "content" }
    local callback = page.GetSurfaceMetrics or page.GetLayoutMetrics
    if type(callback) ~= "function" then return metrics end
    local ok, supplied = xpcall(function() return callback(context) end, function(message) return tostring(message) end)
    if not ok or type(supplied) ~= "table" then
        Core:Print("账号视图页面 “" .. tostring(page.title) .. "”尺寸测量失败，使用兼容尺寸。")
        return metrics
    end
    -- GetLayoutMetrics is the removed window-sized API.  Retain it only as a
    -- load-safe adapter for third-party pages while bundled pages migrate.
    local legacy = type(page.GetSurfaceMetrics) ~= "function"
    local widthShell, heightShell = ShellMetrics(false)
    local values = legacy and {
        minContentWidth = (tonumber(supplied.minWidth) or 0) - widthShell,
        naturalContentWidth = (tonumber(supplied.preferredWidth) or 0) - widthShell,
        minContentHeight = (tonumber(supplied.minHeight) or 0) - heightShell,
        naturalContentHeight = (tonumber(supplied.preferredHeight) or 0) - heightShell,
    } or supplied
    for _, key in ipairs({ "minContentWidth", "naturalContentWidth", "minContentHeight", "naturalContentHeight", "fixedLeftWidth", "fixedTopHeight" }) do
        local value = tonumber(values[key])
        if value and value >= 0 then metrics[key] = math.floor(value + 0.5) end
    end
    metrics.naturalContentWidth = math.max(metrics.minContentWidth, metrics.naturalContentWidth)
    metrics.naturalContentHeight = math.max(metrics.minContentHeight, metrics.naturalContentHeight)
    -- A paginated matrix reports its full roster in naturalContentWidth.
    -- ApplyPageSize consumes that width up to the screen-safe edge; a page's
    -- column pager is used only after that edge has been reached.
    metrics.horizontalOverflow = (supplied.horizontalOverflow == "paginate" or supplied.horizontalOverflow == "matrix") and supplied.horizontalOverflow or "content"
    metrics.verticalOverflow = supplied.verticalOverflow == "none" and "none" or "content"
    return metrics
end

local function AddText(parent, template, size, color)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    local resolvedSize = size
    if not resolvedSize then
        if template == "GameFontNormalLarge" then resolvedSize = Theme.Font.title
        elseif template == "GameFontNormalSmall" then resolvedSize = Theme.Font.assist
        else resolvedSize = Theme.Font.body end
    end
    Theme:ApplyTextStyle(text, resolvedSize)
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
    local pageTitle = subtitle or (page and page.title) or ""
    if page and page.icon then
        frame.pageIcon:SetTexture(page.icon)
        frame.pageIcon:Show()
        frame.title:ClearAllPoints(); frame.title:SetPoint("LEFT", frame.titleBar, "LEFT", 44, 0)
    else
        frame.pageIcon:Hide()
        frame.title:ClearAllPoints(); frame.title:SetPoint("LEFT", frame.titleBar, "LEFT", 16, 0)
    end
    -- Use complete identity levels instead of a clipped title or the old
    -- redundant “账号角色预览” suffix.
    local scopeWidth = frame.scopeBar and frame.scopeBar:IsShown() and ((frame.scopeBar:GetWidth() or 0) + Theme.Space.sm) or 0
    -- Hover previews hide normal controls.  Reserving their invisible width
    -- caused both an empty title bar and server controls outside the shell.
    local controlsWidth = not frame.preview and frame.controls and frame.controls:IsShown() and (frame.controls:GetWidth() or 0) or 0
    local pagerWidth = 0
    for pager in pairs(AccountView._columnPagers or {}) do
        if pager.chrome == frame.titleBar and ((pager.previous and pager.previous:IsShown()) or (pager.next and pager.next:IsShown())) then
            pagerWidth = math.max(pagerWidth, pager.width or (Theme.Size.compact * 2 + Theme.Space.xxs * 2))
        end
    end
    local candidates = {
        { text = addonName .. " v" .. version .. " · " .. pageTitle, icon = true },
        { text = addonName .. " · " .. pageTitle, icon = true },
        { text = pageTitle, icon = true }, { text = pageTitle, icon = false }, { text = "", icon = false },
    }
    local selected, selectedAvailable = candidates[#candidates], 1
    for _, candidate in ipairs(candidates) do
        local leftInset = candidate.icon and page and page.icon and 44 or 16
        local rightInset = frame.preview and Theme.Space.xxs or (14 + Theme.Space.sm)
        local available = math.max(0, (frame:GetWidth() or 0) - controlsWidth - scopeWidth - pagerWidth - leftInset - rightInset)
        if Theme:MeasureText(Theme.Font.title, candidate.text) <= available then selected, selectedAvailable = candidate, available; break end
    end
    frame.title:SetText(selected.text); frame.title:SetWidth(math.max(1, selectedAvailable)); frame.title:SetShown(selected.text ~= "")
    frame.version:Hide(); frame.subtitle:Hide()
    frame.pageIcon:SetShown(selected.icon and page and page.icon ~= nil)
    frame.title:ClearAllPoints()
    frame.title:SetPoint("LEFT", frame.titleBar, "LEFT", (selected.icon and page and page.icon) and 44 or 16, 0)
    if frame.identityHit then
        local identityWidth = math.max(1, (frame:GetWidth() or 0) - controlsWidth - scopeWidth - Theme.Space.sm)
        frame.identityHit:SetWidth(identityWidth)
        Theme:BindTooltip(frame.identityHit, addonName .. " v" .. version .. " · " .. pageTitle)
    end
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
    if definition.characterFilter ~= nil then
        local filter = definition.characterFilter
        if type(filter) ~= "table" or type(filter.GetExpression) ~= "function" or type(filter.SetExpression) ~= "function" then
            return nil, "页面 characterFilter 必须提供 GetExpression 与 SetExpression。"
        end
    end
    if definition.GetSurfaceMetrics ~= nil and type(definition.GetSurfaceMetrics) ~= "function" then
        return nil, "页面 GetSurfaceMetrics 必须是 function。"
    end
    if definition.GetLayoutMetrics ~= nil and type(definition.GetLayoutMetrics) ~= "function" then
        return nil, "页面 GetLayoutMetrics 必须是 function。"
    end
    if definition.GetMeasuredHeight ~= nil and type(definition.GetMeasuredHeight) ~= "function" then
        return nil, "页面 GetMeasuredHeight 必须是 function。"
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
        local realms = {}
        for _, character in ipairs(characters or Core.Characters:GetAll()) do
            local admitted = true
            if type(page.HasCharacterSnapshot) == "function" then
                local ok, result = xpcall(function() return page.HasCharacterSnapshot(character) end, function(message) return tostring(message) end)
                admitted = ok and result == true
                if not ok then Core:Print("账号视图页面“" .. tostring(page.title or page.id) .. "”读取角色快照失败：" .. result) end
            end
            if admitted and character.realm and character.realm ~= "" then realms[character.realm] = true end
        end
        -- Keep the current realm first only when this page has an admitted
        -- character there; empty realm buttons are deliberately not rendered.
        local currentAdmitted = realms[currentRealm] == true
        local others = {}
        for realm in pairs(realms) do if realm ~= currentRealm then others[#others + 1] = realm end end
        table.sort(others)
        local values = {}
        if currentAdmitted then values[#values + 1] = { id = "realm:" .. currentRealm, title = currentRealm } end
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
    local saved = scopeDefinition.mode == "realms" and Settings().selectedRealmScope or Settings().pageScopes[pageID]
    if IsKnownScope(scopeDefinition, saved) then return saved end
    return scopeDefinition.default
end

function AccountView:SetPageScope(pageID, scopeID)
    local page = self._pages[pageID]
    local scopeDefinition = GetScopeDefinition(page, self:GetVisibleCharacters())
    if not scopeDefinition or not IsKnownScope(scopeDefinition, scopeID) then return false end
    if scopeDefinition.mode == "realms" then Settings().selectedRealmScope = scopeID else Settings().pageScopes[pageID] = scopeID end
    if self.frame and self.frame.preview and self.previewPageID == pageID then
        -- Rebuilding a preview can shrink it away from the current pointer.
        -- Treat the server click as an interaction inside the preview rather
        -- than an accidental leave caused by that geometry change.
        if Core.Entry and Core.Entry.SuppressPreviewClose then Core.Entry:SuppressPreviewClose(0.75) end
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

local function GetScopeControlMetrics(scope, selectedScope)
    if not (scope and #scope.values > 2) then return nil end
    local realms, allValue = {}, nil
    for _, value in ipairs(scope.values) do
        if value.id == "all" then allValue = value else realms[#realms + 1] = value end
    end
    local current = realms[1]
    if not current or not allValue then return nil end
    local selectedOther
    for index = 2, #realms do if realms[index].id == selectedScope then selectedOther = realms[index]; break end end
    local currentWidth = math.max(88, Theme:MeasureText(Theme.Font.assist, current.title) + 24)
    local otherCount = math.max(0, #realms - 1)
    local directOther = otherCount == 1 and realms[2] or nil
    local otherTitle = directOther and directOther.title or (selectedOther and selectedOther.title or "其它 v")
    local otherWidth = math.max(82, Theme:MeasureText(Theme.Font.assist, otherTitle) + 24)
    local allWidth = math.max(72, Theme:MeasureText(Theme.Font.assist, allValue.title) + 24)
    return {
        current = current, allValue = allValue, selectedOther = selectedOther, directOther = directOther,
        currentWidth = currentWidth, otherWidth = otherWidth, allWidth = allWidth,
        otherTitle = otherTitle, width = currentWidth + otherWidth + allWidth + Theme.Space.xs * 2,
    }
end

local function RefreshScopeBar(frame, context)
    local scope, bar = context.scopeDefinition, frame.scopeBar
    local pageAllowsScope = not (context.page and type(context.page.ShowScopeBar) == "function")
        or context.page.ShowScopeBar(context) ~= false
    local function RestoreHeaderControls()
        frame.controls:ClearAllPoints()
        frame.controls:SetSize(256, Theme.Size.standard)
        frame.controls:SetPoint("TOPRIGHT", frame.titleBar, "TOPRIGHT", -14, -8)
    end
    if not (pageAllowsScope and scope and #scope.values > 2) then
        bar:Hide()
        if bar.menu then bar.menu:Hide() end
        frame.compactTitle = false
        RestoreHeaderControls()
        return false
    end
    -- A server range is never a linear strip of realm buttons.  It is the
    -- responsive three-control selector required by the window contract:
    -- current realm, an explicit Other menu, and All realms.
    local scopeMetrics = GetScopeControlMetrics(scope, context.scope)
    if not scopeMetrics then bar:Hide(); return false end
    local current, allValue = scopeMetrics.current, scopeMetrics.allValue
    local selectedOther, directOther = scopeMetrics.selectedOther, scopeMetrics.directOther
    local currentWidth, otherWidth, allWidth = scopeMetrics.currentWidth, scopeMetrics.otherWidth, scopeMetrics.allWidth
    local otherTitle, barWidth = scopeMetrics.otherTitle, scopeMetrics.width
    bar.current = bar.current or Theme:CreateButton(bar, currentWidth, "", "secondary")
    bar.other = bar.other or Theme:CreateButton(bar, otherWidth, "", "secondary")
    bar.all = bar.all or Theme:CreateButton(bar, allWidth, "", "secondary")
    bar:ClearAllPoints(); bar:SetSize(barWidth, Theme.Size.standard)
    RestoreHeaderControls()
    if frame.preview then
        -- No hidden normal controls may reserve title-bar space in a preview.
        bar:SetPoint("RIGHT", frame.titleBar, "RIGHT", -Theme.Space.sm, 0)
    else
        bar:SetPoint("RIGHT", frame.controls, "LEFT", -Theme.Space.sm, 0)
    end
    bar.current:SetSize(currentWidth, Theme.Size.standard); bar.current:ClearAllPoints(); bar.current:SetPoint("LEFT", bar, "LEFT", 0, 0)
    bar.other:SetSize(otherWidth, Theme.Size.standard); bar.other:ClearAllPoints(); bar.other:SetPoint("LEFT", bar.current, "RIGHT", Theme.Space.xs, 0)
    bar.all:SetSize(allWidth, Theme.Size.standard); bar.all:ClearAllPoints(); bar.all:SetPoint("LEFT", bar.other, "RIGHT", Theme.Space.xs, 0)
    bar.current:SetText(current.title); bar.current:SetState(context.scope == current.id and "selected" or "default")
    bar.other:SetText(otherTitle); bar.other:SetState(selectedOther and "selected" or "default")
    bar.all:SetText(allValue.title); bar.all:SetState(context.scope == allValue.id and "selected" or "default")
    bar.current:SetScript("OnClick", function() if bar.menu then bar.menu:Hide() end; context:SetScope(current.id) end)
    bar.all:SetScript("OnClick", function() if bar.menu then bar.menu:Hide() end; context:SetScope(allValue.id) end)
    -- The realm menu must belong to the account frame.  A UIParent popup is
    -- outside hover-preview hit testing, so entering it immediately closes
    -- the preview before an option can receive its click.
    bar.menu = bar.menu or CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bar.menu:SetFrameStrata(frame:GetFrameStrata() or "DIALOG")
    bar.menu:SetFrameLevel((frame:GetFrameLevel() or 0) + 30)
    bar.menu:SetToplevel(true)
    bar.menu:EnableMouse(true)
    bar.menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    bar.menu:SetBackdropColor(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], 1)
    bar.menu:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], COLORS.line[4])
    bar.menu.buttons = bar.menu.buttons or {}
    local function ToggleOtherMenu()
        if bar.menu:IsShown() then bar.menu:Hide(); return end
        bar.menu:ClearAllPoints(); bar.menu:SetPoint("TOPRIGHT", bar.other, "BOTTOMRIGHT", 0, -Theme.Space.xxs)
        local width = otherWidth
        local realms = {}
        for _, value in ipairs(scope.values) do if value.id ~= "all" then realms[#realms + 1] = value end end
        for index = 2, #realms do width = math.max(width, Theme:MeasureText(Theme.Font.assist, realms[index].title) + 24) end
        bar.menu:SetSize(width, math.max(1, #realms - 1) * Theme.Size.standard + Theme.Space.xxs * 2)
        for index = 2, #realms do
            local option = bar.menu.buttons[index - 1] or Theme:CreateButton(bar.menu, width - Theme.Space.xs, "", "secondary")
            bar.menu.buttons[index - 1] = option
            option:SetFrameLevel((bar.menu:GetFrameLevel() or 0) + 1)
            option:SetSize(width - Theme.Space.xs, Theme.Size.standard); option:ClearAllPoints(); option:SetPoint("TOPLEFT", bar.menu, "TOPLEFT", Theme.Space.xxs, -Theme.Space.xxs - (index - 2) * Theme.Size.standard)
            option:SetText(realms[index].title); option:SetState(realms[index].id == context.scope and "selected" or "default")
            local scopeID = realms[index].id
            option:SetScript("OnClick", function() bar.menu:Hide(); context:SetScope(scopeID) end); option:Show()
        end
        for index = #realms, #bar.menu.buttons do bar.menu.buttons[index]:Hide() end
        bar.menu:Show()
    end
    if directOther then
        -- A single alternative realm is a direct range switch, not a menu.
        bar.other:SetScript("OnClick", function()
            if bar.menu then bar.menu:Hide() end
            context:SetScope(directOther.id)
        end)
    else
        bar.other:SetScript("OnClick", ToggleOtherMenu)
    end
    bar.current:Show(); bar.other:Show(); bar.all:Show()
    for _, control in ipairs(bar.buttons) do control:Hide() end
    frame.compactTitle = (frame.titleBar:GetWidth() or 0) < (barWidth + (frame.preview and 72 or 330))
    bar:Show()
    return false
end

function AccountView:CreateFrame()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "YiboCoreAccountView", UIParent, "BackdropTemplate")
    local settings = Settings()
    settings.width, settings.height = ClampWindowSize(settings.width, settings.height)
    frame:SetSize(settings.width, settings.height)
    frame:SetPoint(settings.point or "CENTER", UIParent, settings.relativePoint or "CENTER", settings.x or 0, settings.y or 0)
    frame:SetMovable(true)
    -- No resize affordance is exposed to players, but programmatic autosizing
    -- must remain unconstrained by stale minimum bounds from older versions.
    frame:SetResizable(true)
    local screenWidth, screenHeight = ScreenBounds()
    if frame.SetResizeBounds then
        frame:SetResizeBounds(1, 1, screenWidth, screenHeight)
    else
        if frame.SetMinResize then frame:SetMinResize(1, 1) end
        if frame.SetMaxResize then frame:SetMaxResize(screenWidth, screenHeight) end
    end
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
        if not self.preview and width >= 760 and height >= 150 then
            settings.width, settings.height = math.floor(width + 0.5), math.floor(height + 0.5)
        end
    end)
    frame:SetScript("OnShow", function(self)
        if not self.preview then self:Raise() end
    end)
    frame:SetScript("OnHide", function(self)
        if self.scopeBar and self.scopeBar.menu then self.scopeBar.menu:Hide() end
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

    -- Keep the shell header in its own, higher frame level.  Page instances
    -- are child frames of `content` and can otherwise cover shell regions
    -- when a page is rebuilt or switched into preview mode.
    frame.titleBar = CreateFrame("Frame", nil, frame)
    frame.titleBar:SetPoint("TOPLEFT", 1, -1)
    frame.titleBar:SetPoint("TOPRIGHT", -1, -1)
    frame.titleBar:SetHeight(46)
    frame.titleBar:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.top = frame.titleBar:CreateTexture(nil, "BACKGROUND")
    frame.top:SetAllPoints()
    frame.top:SetColorTexture(COLORS.chrome[1], COLORS.chrome[2], COLORS.chrome[3], COLORS.chrome[4])
    frame.brand = AddText(frame.titleBar, "GameFontNormalLarge", nil, COLORS.accent)
    frame.brand:Hide()
    frame.title = AddText(frame.titleBar, "GameFontNormalLarge", nil, COLORS.text)
    frame.title:SetPoint("LEFT", frame.titleBar, "LEFT", 16, 0); frame.title:SetText("账号总览")
    frame.pageIcon = frame.titleBar:CreateTexture(nil, "ARTWORK")
    frame.pageIcon:SetSize(22, 22); frame.pageIcon:SetPoint("LEFT", frame.titleBar, "LEFT", 16, 0); frame.pageIcon:Hide()
    frame.identityHit = CreateFrame("Frame", nil, frame.titleBar)
    frame.identityHit:SetPoint("TOPLEFT", frame.titleBar, "TOPLEFT", 0, 0)
    frame.identityHit:SetPoint("BOTTOMLEFT", frame.titleBar, "BOTTOMLEFT", 0, 0)
    frame.identityHit:SetWidth(1); frame.identityHit:EnableMouse(true); frame.identityHit:RegisterForDrag("LeftButton")
    frame.identityHit:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame.identityHit:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint(1)
        settings.point, settings.relativePoint, settings.x, settings.y = point, relativePoint, x, y
    end)
    frame.version = AddText(frame.titleBar, "GameFontNormalSmall", Theme.Font.meta, COLORS.muted)
    frame.version:SetPoint("BOTTOMLEFT", frame.title, "BOTTOMRIGHT", 7, 1); frame.version:SetText("v?")
    frame.subtitle = AddText(frame.titleBar, "GameFontNormalSmall", nil, COLORS.muted)
    frame.subtitle:SetPoint("BOTTOMLEFT", frame.version, "BOTTOMRIGHT", 12, 1); frame.subtitle:SetText("多角色状态")
    frame.controls = CreateFrame("Frame", nil, frame.titleBar)
    frame.controls:SetSize(256, Theme.Size.standard)
    frame.controls:SetPoint("TOPRIGHT", -14, -8)
    frame.sortButton = CreateChromeButton(frame.controls, 150, Theme.Size.standard, "排序：最近登录 ↓")
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
    frame.settingsButton = CreateChromeButton(frame.controls, 62, Theme.Size.standard, "设置")
    frame.settingsButton:SetPoint("LEFT", frame.sortButton, "RIGHT", 10, 0)
    frame.settingsButton:SetScript("OnClick", function() AccountView:ShowSettings() end)
    frame.close = CreateChromeButton(frame.controls, 28, Theme.Size.standard, "×", true)
    frame.close:SetPoint("LEFT", frame.settingsButton, "RIGHT", 6, 0)
    frame.close.label:SetFont(STANDARD_TEXT_FONT, Theme.Font.section)
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
    frame.nav = CreateFrame("Frame", nil, frame)
    frame.nav:SetPoint("TOPLEFT", 1, -47); frame.nav:SetPoint("BOTTOMLEFT", 1, 1); frame.nav:SetWidth(140)
    frame.nav.bg = frame.nav:CreateTexture(nil, "BACKGROUND"); frame.nav.bg:SetAllPoints(); frame.nav.bg:SetColorTexture(COLORS.nav[1], COLORS.nav[2], COLORS.nav[3], COLORS.nav[4])
    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", frame.nav, "TOPRIGHT", 1, 0); frame.content:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.scopeBar = CreateFrame("Frame", nil, frame.titleBar)
    frame.scopeBar:SetSize(1, Theme.Size.standard); frame.scopeBar.buttons = {}; frame.scopeBar:Hide()
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

local function NavigationRequiredHeight(page)
    local count
    if page and page.id == "settings" then
        count = 5
        for _, registered in ipairs(AccountView._pageOrder) do if not registered.internal then count = count + 1 end end
    else
        count = 3 -- 概览、角色档案、关于
        for _, registered in ipairs(AccountView._pageOrder) do if PageEnabled(registered) then count = count + 1 end end
    end
    local navigationHeight = Theme.Space.xs * 2 + count * Theme.Table.rowHeight + math.max(0, count - 1) * Theme.Space.xxs
    return Theme.Geometry.titleBar + Theme.Geometry.shellBorder * 2 + navigationHeight
end

function AccountView:ApplyPageSize(page, context)
    local frame = self:CreateFrame()
    if frame.preview then return end
    local maxWidth, maxHeight = ScreenBounds()
    local shellWidth, shellHeight = ShellMetrics(false)
    -- A matrix may use the whole safe screen width before resorting to
    -- pagination.  Its natural width describes every character column;
    -- pagination begins only when that width reaches this hard boundary.
    context.surfaceAvailableWidth = math.max(1, maxWidth - shellWidth)
    local settings, metrics = Settings(), SurfaceMetrics(page, context)
    local preferredWidth = metrics.naturalContentWidth + shellWidth
    local preferredHeight = metrics.naturalContentHeight + shellHeight
    -- Most account pages are matrix-like and retain the shared 760px floor.
    -- A page may explicitly opt into a compact layout when its content has a
    -- fixed, small column set (for example a short icon-only task table).
    local widthFloor = page.compactWidth and 360 or 760
    local minWidth = math.max(widthFloor, metrics.minContentWidth + shellWidth)
    local scopeMetrics = GetScopeControlMetrics(context.scopeDefinition, context.scope)
    if scopeMetrics then
        -- Main windows show normal controls beside the range selector.  Both
        -- must fit inside the shell; the title may disappear, controls may not.
        local headerWidth = scopeMetrics.width + 256 + Theme.Space.sm * 2 + 22
        minWidth = math.max(minWidth, headerWidth)
    end
    -- The screen-safe width is the only horizontal ceiling for a data page.
    preferredWidth = math.min(preferredWidth, maxWidth)
    -- Individual pages own their safe minimum height.  A global 430 px floor
    -- left large empty regions below compact data matrices.
    local minHeight = math.max(150, metrics.minContentHeight + shellHeight, NavigationRequiredHeight(page))
    if page.id == "settings" then
        minWidth, minHeight = math.max(minWidth, 820), math.max(minHeight, 560)
        preferredWidth, preferredHeight = math.max(preferredWidth, 960), math.max(preferredHeight, 720)
    end
    local width, height = preferredWidth, preferredHeight
    width = math.max(math.min(widthFloor, maxWidth), math.min(math.max(minWidth, width), maxWidth))
    height = math.max(math.min(minHeight, maxHeight), math.min(math.max(minHeight, height), maxHeight))
    if math.abs((frame:GetWidth() or 0) - width) < 1 and math.abs((frame:GetHeight() or 0) - height) < 1 then return end
    self._applyingPageSize = true
    frame:SetResizable(true)
    if frame.SetResizeBounds then frame:SetResizeBounds(1, 1, maxWidth, maxHeight) end
    frame:SetSize(width, height)
    self._applyingPageSize = nil
    settings.width, settings.height = width, height
end

function AccountView:ApplyMeasuredPageHeight(page, instance, context)
    if self.frame.preview or type(page.GetMeasuredHeight) ~= "function" then return end
    local ok, measured = xpcall(function() return page.GetMeasuredHeight(instance, context) end, function(message) return tostring(message) end)
    if not ok or type(measured) ~= "number" or measured <= 0 then return end
    local frame = self.frame
    -- The page instance fills Core's content area.  Preserve the shell's
    -- actual chrome height, then replace only the content portion with the
    -- post-layout measurement supplied by the page.
    local shellHeight = math.max(0, (frame:GetHeight() or 0) - (instance:GetHeight() or 0))
    local maxWidth, maxHeight = ScreenBounds()
    local targetHeight = math.min(maxHeight, math.max(NavigationRequiredHeight(page), math.floor(measured + shellHeight + 0.5)))
    if math.abs((frame:GetHeight() or 0) - targetHeight) < 1 then return end
    self._applyingPageSize = true
    if frame.SetResizeBounds then frame:SetResizeBounds(1, 1, maxWidth, maxHeight) end
    frame:SetHeight(targetHeight)
    self._applyingPageSize = nil
    Settings().height = targetHeight
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
        local target = self._pages[self.settingsTargetPageID or ""]
        local returnPage = target and not target.internal and target or self._pages.overview
        pages[#pages + 1] = { id = returnPage.id, title = "‹ 返回" .. returnPage.title }
        pages[#pages + 1] = { id = "settings-core-heading", title = "Core 常规设置", section = true }
        pages[#pages + 1] = { id = "settings-core", title = "  窗口", settingsTargetID = "core" }
        pages[#pages + 1] = { id = "settings-sorting", title = "  角色与排序", settingsTargetID = "sorting" }
        pages[#pages + 1] = { id = "settings-display", title = "  显示与入口", settingsTargetID = "display" }
        for _, page in ipairs(self._pageOrder) do
            -- Settings is user-facing navigation.  Technical addon IDs are
            -- useful for diagnostics, but must never replace the page title
            -- users see in the account view.
            if not page.internal then pages[#pages + 1] = { id = "settings-" .. page.id, title = page.title, settingsTargetID = page.id } end
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
            local navigationStep = Theme.Table.rowHeight + Theme.Space.xxs
            button:SetHeight(Theme.Table.rowHeight); button:SetPoint("TOPLEFT", 8, -8 - ((index - 1) * navigationStep)); button:SetPoint("TOPRIGHT", -8, -8 - ((index - 1) * navigationStep))
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
    if page.characterFilter then
        local expression = page.characterFilter.GetExpression() or ""
        local matcher = Core.LevelFilter:Compile(expression)
        local filtered = {}
        for _, character in ipairs(characters) do
            if matcher:Matches(character.level) then filtered[#filtered + 1] = character end
        end
        characters = filtered
    end
    if scopeDefinition and scopeDefinition.mode == "realms" and scope ~= "all" then
        local realm, filtered = scope:match("^realm:(.+)$"), {}
        for _, character in ipairs(characters) do
            if realm and character.realm == realm then filtered[#filtered + 1] = character end
        end
        characters = filtered
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
    if not options.preview then self:ApplyPageSize(page, context) end
    self:HideColumnPagers()
    for id, instance in pairs(self.frame.instances) do if id ~= page.id then instance:Hide() end end
    local instance = self.frame.instances[page.id]
    if not instance then
        instance = CreateFrame("Frame", nil, self.frame.content)
        instance:SetAllPoints(self.frame.content)
        self.frame.instances[page.id] = instance
        CallPage(instance, page, "创建", context)
    end
    instance:ClearAllPoints()
    if RefreshScopeBar(self.frame, context) then
        instance:SetPoint("TOPLEFT", self.frame.scopeBar, "BOTTOMLEFT", -20, -4)
        instance:SetPoint("BOTTOMRIGHT", self.frame.content, "BOTTOMRIGHT")
    else
        instance:SetAllPoints(self.frame.content)
    end
    local shellWidth = ShellMetrics(context.preview)
    local contentWidth = math.max(1, (self.frame:GetWidth() or 1) - shellWidth)
    -- Business renderers must consume the width chosen for this layout pass,
    -- never a stale frame width left by the previously visible page.
    context.surfaceAvailableWidth = contentWidth
    instance:Show()
    if options.preview then
        -- 悬停投影不能改变正式窗口最后打开的页面；否则 Core 默认入口会
        -- 被业务入口的预览反向影响，产生页面和尺寸来回跳变。
        self.previewPageID = page.id
        self.previewPageOptions = options
    else
        self.activePageID = page.id
        options.autoFit = nil
        self.activePageOptions = options
    end
    CallPage(instance, page, "刷新", context)
    -- Pages may create or hide a title-bar pager while refreshing. Resolve
    -- the identity only after that chrome is final for this pass.
    SetHeaderIdentity(self.frame, page, page.title)
    self:ApplyMeasuredPageHeight(page, instance, context)
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
    self._applyingPageSize = true
    frame:SetSize(settings.width, settings.height)
    self._applyingPageSize = nil
    frame:ClearAllPoints()
    frame:SetPoint(settings.point or "CENTER", UIParent, settings.relativePoint or "CENTER", settings.x or 0, settings.y or 0)
    frame.nav:Show(); frame.settingsButton:Show(); frame.close:Show(); self:UpdateSortButton()
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
    -- Hover previews are content-sized.  A legacy 150 px global floor was
    -- applied in addition to each page's own measured minimum and left an
    -- empty footer beneath compact two-row tables.
    local metrics = { minWidth = 1, preferredWidth = 820, minHeight = 1, preferredHeight = 360, horizontalOverflow = "content", verticalOverflow = "content" }
    -- A page can use a compact hover projection with different row cadence
    -- from its full matrix.  Prefer that explicit contract; falling back to
    -- surface metrics here was what kept the Core character preview taller
    -- than its thirteen rendered rows.
    if type(page.GetHoverMetrics) == "function" then
        local ok, supplied = xpcall(function() return page.GetHoverMetrics(context) end, function(message) return tostring(message) end)
        if ok and type(supplied) == "table" then
            for _, key in ipairs({ "minWidth", "preferredWidth", "minHeight", "preferredHeight" }) do
                local value = tonumber(supplied[key])
                if value and value > 0 then metrics[key] = math.floor(value + 0.5) end
            end
            metrics.horizontalOverflow = supplied.horizontalOverflow == "paginate" and "paginate" or supplied.horizontalOverflow == "matrix" and "matrix" or "content"
            metrics.verticalOverflow = supplied.verticalOverflow == "none" and "none" or "content"
        else
            Core:Print("账号视图页面 “" .. tostring(page.title) .. "”悬停尺寸测量失败，使用兼容尺寸。")
        end
    elseif type(page.GetSurfaceMetrics) == "function" then
        local ok, supplied = xpcall(function() return page.GetSurfaceMetrics(context) end, function(message) return tostring(message) end)
        if ok and type(supplied) == "table" then
            local shellWidth, shellHeight = ShellMetrics(true)
            metrics.minWidth = math.max(metrics.minWidth, (tonumber(supplied.minContentWidth) or 0) + shellWidth)
            metrics.preferredWidth = math.max(metrics.minWidth, (tonumber(supplied.naturalContentWidth) or 0) + shellWidth)
            metrics.minHeight = math.max(metrics.minHeight, (tonumber(supplied.minContentHeight) or 0) + shellHeight)
            metrics.preferredHeight = math.max(metrics.minHeight, (tonumber(supplied.naturalContentHeight) or 0) + shellHeight)
            metrics.horizontalOverflow = supplied.horizontalOverflow == "paginate" and "paginate" or supplied.horizontalOverflow == "matrix" and "matrix" or "content"
            metrics.verticalOverflow = supplied.verticalOverflow == "none" and "none" or "content"
        end
    elseif type(page.GetPreviewSize) == "function" then
        local width, height = page.GetPreviewSize(context)
        metrics.preferredWidth, metrics.preferredHeight = tonumber(width) or metrics.preferredWidth, tonumber(height) or metrics.preferredHeight
    end
    metrics.preferredWidth = math.max(metrics.minWidth, metrics.preferredWidth)
    metrics.preferredHeight = math.max(metrics.minHeight, metrics.preferredHeight)
    local scopeMetrics = GetScopeControlMetrics(context.scopeDefinition, context.scope)
    if scopeMetrics then
        -- Previews hide normal buttons, but their selectable realm range
        -- remains interactive and must stay completely inside the shell.
        local selectorWidth = scopeMetrics.width + Theme.Space.sm * 2
        metrics.minWidth = math.max(metrics.minWidth, selectorWidth)
        metrics.preferredWidth = math.max(metrics.preferredWidth, selectorWidth)
    end
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
    local allowWhileMainWindowOpen = Settings().entry.showPreviewWhileMainWindowOpen == true
    if not page or not page.previewEnabled or (not page.internal and not PageEnabled(page)) or (frame:IsShown() and not frame.preview and not allowWhileMainWindowOpen) then return false end

    -- The shared shell can temporarily become a preview when the player has
    -- opted in.  Remember that it was a normal window so it is restored when
    -- the pointer leaves the entry instead of remaining in preview layout.
    self.restoreNormalWindowAfterPreview = frame:IsShown() and not frame.preview

    local fields = type(page.GetPreviewFields) == "function" and page.GetPreviewFields() or page.previewFields
    local context = self:BuildContext(page, { preview = true, fieldOverrides = fields })
    local safe = SafeRect(true)
    context.surfaceAvailableWidth = safe.width
    local metrics = HoverMetrics(page, context)
    local width, height = metrics.preferredWidth, metrics.preferredHeight
    width = math.max(math.min(metrics.minWidth, safe.width), math.min(width, safe.width))

    frame.preview = true
    -- The normal window installs a large minimum resize bound.  A hover is
    -- intentionally allowed to shrink to its measured content height.
    if frame.SetResizeBounds then frame:SetResizeBounds(metrics.minWidth, metrics.minHeight, math.max(metrics.minWidth, safe.width), math.max(metrics.minHeight, safe.height))
    else
        if frame.SetMinResize then frame:SetMinResize(metrics.minWidth, metrics.minHeight) end
        if frame.SetMaxResize then frame:SetMaxResize(math.max(metrics.minWidth, safe.width), math.max(metrics.minHeight, safe.height)) end
    end
    frame:SetMovable(false)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", self.previewOnEnter)
    frame:SetScript("OnLeave", self.previewOnLeave)
    -- The account preview is an interactive window, not the Broker's native
    -- tooltip. Keep it below TOOLTIP so the Broker tooltip always remains
    -- readable when both are visible.
    frame:SetFrameStrata("DIALOG")
    frame:ClearAllPoints()
    local anchorFrame = anchor and type(anchor.GetLeft) == "function" and anchor or nil
    self.previewAnchor = anchorFrame
    if anchorFrame then
        local left, right = anchorFrame:GetLeft(), anchorFrame:GetRight()
        local top, bottom = anchorFrame:GetTop(), anchorFrame:GetBottom()
        local centerX = ((left or 0) + (right or 0)) / 2
        local centerY = ((top or 0) + (bottom or 0)) / 2
        local opensDown = centerY >= (safe.bottom + safe.top) / 2
        -- A broker preview must be reachable by moving straight up or down.
        -- The former corner-to-corner anchor left a diagonal gap, so the
        -- hover closed before the pointer could enter it.
        local gap = 0
        local roomWidth = safe.width
        local roomHeight = opensDown and ((bottom or safe.top) - safe.bottom - gap) or (safe.top - (top or safe.bottom) - gap)
        width = math.max(math.min(metrics.minWidth, safe.width), math.min(width, math.max(1, roomWidth)))
        height = math.max(math.min(metrics.minHeight, safe.height), math.min(height, math.max(1, roomHeight)))
        local offsetX = math.max(safe.left + width / 2 - centerX, math.min(safe.right - width / 2 - centerX, 0))
        frame:SetPoint(opensDown and "TOP" or "BOTTOM", anchorFrame, opensDown and "BOTTOM" or "TOP", offsetX, opensDown and -gap or gap)
    else
        height = math.max(math.min(metrics.minHeight, safe.height), math.min(height, safe.height))
        frame:SetPoint("CENTER", UIParent, "CENTER")
    end
    frame:SetSize(width, height)
    frame.nav:Hide(); frame.sortButton:Hide(); frame.settingsButton:Hide(); frame.close:Hide()
    frame.content:ClearAllPoints()
    frame.content:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -47)
    frame.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    SetHeaderIdentity(frame, page, page.title)
    frame:Show()
    self:ShowPage(page.id, { preview = true, fieldOverrides = fields })
    self:TrackPreviewControls(frame)
    return true
end

function AccountView:HidePreview()
    local frame = self.frame
    if not frame or not frame.preview then return end
    local restoreNormalWindow = self.restoreNormalWindowAfterPreview == true
    frame:Hide()
    self:ApplyNormalLayout()
    self.previewPageID = nil
    self.previewPageOptions = nil
    self.previewAnchor = nil
    self.restoreNormalWindowAfterPreview = nil
    if restoreNormalWindow then
        frame:Show()
        self:ShowPage(self.activePageID or "overview", self.activePageOptions)
    end
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

function AccountView:ShowSettings(targetID)
    if targetID then
        -- Entry shortcuts provide the business page explicitly.  Validate it
        -- before changing state so a stale/unregistered entry falls back to
        -- the normal settings landing page instead of rendering a blank host.
        if self:SelectSettingsTarget(targetID) == false then targetID = nil end
    end
    if not targetID and self.activePageID and self.activePageID ~= "settings" then
        local active = self._pages[self.activePageID]
        self.settingsTargetPageID = active and not active.internal and active.id or "display"
    end
    self:Toggle("settings")
end

function AccountView:SelectSettingsTarget(targetID)
    if targetID ~= "display" and targetID ~= "sorting" and targetID ~= "core" and targetID ~= "filters" then
        local page = self._pages[targetID]
        if not page or page.internal then return false end
    end
    self.settingsTargetPageID = targetID
    if self.activePageID == "settings" then self:RefreshPage() end
    return true
end

local function CreateOverview(parent)
    parent.scroll = Theme:CreateScrollFrame(parent)
    parent.scroll:SetPoint("TOPLEFT", 0, 0); parent.scroll:SetPoint("BOTTOMRIGHT", 0, 0)
    parent.content = CreateFrame("Frame", nil, parent.scroll); parent.scroll:SetScrollChild(parent.content)
    local content = parent.content
    parent.heading = AddText(content, "GameFontNormalLarge", nil, COLORS.text); parent.heading:SetPoint("TOPLEFT", 20, -18); parent.heading:SetText("账号概览")
    parent.hint = AddText(content, "GameFontNormalSmall", nil, COLORS.muted); parent.hint:SetPoint("TOPLEFT", 20, -47); parent.hint:SetText("从左侧选择业务页，比较角色的下一步行动。")
    parent.characterSummary = AddText(content, "GameFontNormalSmall", nil, COLORS.muted); parent.characterSummary:Hide()
    parent.actionHeading = AddText(content, "GameFontNormalSmall", nil, COLORS.muted); parent.actionHeading:SetPoint("TOPLEFT", 20, -78); parent.actionHeading:SetText("下一步行动")
    parent.lines = {}
    parent.actions = {}
end

local function RefreshOverview(parent, context)
    local lines = {}
    local actions = {}
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
            button = CreateFrame("Button", nil, parent.content, "BackdropTemplate"); button:SetHeight(38); button:SetPoint("TOPLEFT", 20, -104 - ((index - 1) * 42)); button:SetPoint("TOPRIGHT", -20, -104 - ((index - 1) * 42))
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
            button = CreateFrame("Button", nil, parent.content, "BackdropTemplate"); button:SetHeight(34)
            button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); button:SetBackdropColor(0.035, 0.12, 0.12, 0.9); button:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.45)
            button.title = AddText(button, "GameFontNormalSmall", nil, COLORS.text); button.title:SetPoint("LEFT", 9, 0); button.title:SetWidth(210)
            button.text = AddText(button, "GameFontNormalSmall", nil, COLORS.muted); button.text:SetPoint("LEFT", button.title, "RIGHT", 8, 0); button.text:SetPoint("RIGHT", -9, 0)
            button:SetScript("OnClick", function(self) AccountView:ShowPage(self.pageID) end); parent.actions[index] = button
        end
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", parent.content, "TOPLEFT", 20, actionBase - 24 - ((index - 1) * 38)); button:SetPoint("TOPRIGHT", parent.content, "TOPRIGHT", -20, actionBase - 24 - ((index - 1) * 38))
        button.title:SetText((action.pageTitle or "业务") .. " · " .. (action.title or "角色")); button.text:SetText(action.text or "")
        button.pageID = action.pageID; button:Show()
    end
    for index = visibleActionCount + 1, #parent.actions do parent.actions[index]:Hide() end
    local contentHeight = 136 + #lines * 42 + visibleActionCount * 38
    parent.content:SetSize(math.max(1, parent.scroll:GetWidth() or 1), math.max(1, contentHeight))
    parent.scroll:SetContentHeight(parent.content:GetHeight())
    parent.scroll:RefreshScrollbar()
end

local function CreateCharacters(parent)
    -- The title bar and its sort control already communicate page identity
    -- and ordering; a second count/sort sentence only delays the table.
    parent.heading = AddText(parent, "GameFontNormalLarge", nil, COLORS.text); parent.heading:Hide()
    parent.hint = AddText(parent, "GameFontNormalSmall", nil, COLORS.muted); parent.hint:Hide()
    parent.listHeader = CreateFrame("Frame", nil, parent)
    parent.listHeader:SetPoint("TOPLEFT", 20, -82); parent.listHeader:SetWidth(850); parent.listHeader:SetHeight(Theme.Table.headerHeight)
    parent.listHeader.bg = parent.listHeader:CreateTexture(nil, "BACKGROUND"); parent.listHeader.bg:SetAllPoints(); parent.listHeader.bg:SetColorTexture(COLORS.chrome[1], COLORS.chrome[2], COLORS.chrome[3], 0.95)
    parent.listHeader.name = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.name:SetPoint("LEFT", 9, 0); parent.listHeader.name:SetWidth(246); parent.listHeader.name:SetText("角色")
    parent.listHeader.level = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.level:SetPoint("LEFT", parent.listHeader.name, "RIGHT", 6, 0); parent.listHeader.level:SetWidth(32); parent.listHeader.level:SetText("等级")
    parent.listHeader.zone = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.zone:SetPoint("LEFT", parent.listHeader.level, "RIGHT", 6, 0); parent.listHeader.zone:SetWidth(78); parent.listHeader.zone:SetText("地点")
    parent.listHeader.itemLevel = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.itemLevel:SetPoint("LEFT", parent.listHeader.zone, "RIGHT", 6, 0); parent.listHeader.itemLevel:SetWidth(42); parent.listHeader.itemLevel:SetText("装等")
    parent.listHeader.professions = AddText(parent.listHeader, "GameFontNormalSmall", nil, COLORS.muted); parent.listHeader.professions:SetPoint("LEFT", parent.listHeader.itemLevel, "RIGHT", 6, 0); parent.listHeader.professions:SetText("专业")
    parent.scroll = Theme:CreateScrollFrame(parent)
    parent.scroll:SetPoint("TOPLEFT", 20, -106); parent.scroll:SetPoint("BOTTOMRIGHT", -Theme.Space.xs, 12)
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

local function ArchiveFieldText(character, field)
    return Core.Fields:FormatValue(character, field)
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
    local inset = Theme:GetMatrixInsets(preview)
    local characters = (context and ArchiveCharacters(context)) or ArchiveCharacters({ preview = false })
    -- The matrix begins at the normal content inset; count and sorting remain
    -- available through the actual rows and the title-bar sort control.
    parent.heading:Hide()
    parent.hint:Hide()
    parent.listHeader:ClearAllPoints(); parent.listHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", inset.left, -inset.top)
    parent.scroll:ClearAllPoints(); parent.scroll:SetPoint("TOPLEFT", parent.listHeader, "BOTTOMLEFT", 0, -Theme.Space.xs); parent.scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset.right, inset.bottom)
    local previousScroll = parent.resetScroll and 0 or parent.scroll:GetVerticalScroll()
    -- The custom scrollbar overlays the scroll frame.  Only the full archive
    -- reserves space for its hidden-state control; hover is deliberately
    -- The scrollbar lives in the matrix inset, outside the data viewport.
    local contentWidth = parent.scroll:GetWidth() or 0
    if contentWidth <= 0 then contentWidth = 832 end
    parent.listContent:SetWidth(contentWidth)
    local fields = GetArchiveFields(preview)
    local widths = GetArchiveColumnWidths(fields)
    local tableWidth = GetArchiveTableWidth(fields, widths)
    local surfaceWidth = math.max(contentWidth, tableWidth)
    parent.listContent:SetWidth(surfaceWidth)
    parent.listHeader:SetWidth(surfaceWidth)
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
    for index, character in ipairs(characters) do
        local row = parent.rows[index]
        if not row then
            row = CreateFrame("Button", nil, parent.listContent, "BackdropTemplate"); row:SetHeight(Theme.Table.rowHeight); row:SetPoint("TOPLEFT", 0, -((index - 1) * Theme.Table.rowHeight)); row:SetWidth(tableWidth)
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); row.currentOutline = Theme:CreateCurrentCharacterOutline(row); row.name = AddText(row, "GameFontNormalSmall", Theme.Font.body, COLORS.text); row.name:SetPoint("LEFT", 9, 0); row.name:SetWidth(246)
            row.level = AddText(row, "GameFontNormalSmall", Theme.Font.body, COLORS.text); row.level:SetPoint("LEFT", row.name, "RIGHT", 6, 0); row.level:SetWidth(32)
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
        -- Hover uses the same compact matrix rhythm as every other preview;
        -- no local row-step may create invisible whitespace between records.
        local rowHeight = preview and Theme.Table.previewRowHeight or Theme.Table.rowHeight
        row:SetHeight(rowHeight); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -((index - 1) * rowHeight)); row:SetWidth(surfaceWidth)
        row.name:Hide(); row.level:Hide(); row.zone:Hide(); row.itemLevel:Hide(); row.professions:Hide(); row.delete:Hide()
        row.dynamicCells = row.dynamicCells or {}
        x = 8
        for fieldIndex, field in ipairs(fields) do
            local cell = row.dynamicCells[fieldIndex]
            if not cell or cell.icon then
                if cell and cell.icon then cell:Hide() end
                cell = AddText(row, "GameFontNormalSmall", Theme.Font.body, COLORS.muted)
                cell:SetWordWrap(false); row.dynamicCells[fieldIndex] = cell
            end
            local width = widths[fieldIndex]
            cell:ClearAllPoints(); cell:SetPoint("LEFT", x, 0); cell:SetWidth(width)
            local text, value = ArchiveFieldText(character, field)
            local icon = field.GetIcon and field.GetIcon(value, character)
            if icon and text ~= "—" then
                cell:SetText("|T" .. tostring(icon) .. ":16:16:0:0:64:64|t " .. text)
            else
                cell:SetText(text)
            end
            cell:SetJustifyH(field.align or "LEFT")
            local color = field.GetColor and field.GetColor(value, character)
            local r, g, b = color and color[1] or COLORS.muted[1], color and color[2] or COLORS.muted[2], color and color[3] or COLORS.muted[3]
            cell:SetTextColor(r, g, b)
            cell:Show(); x = x + width + GetArchiveColumnGap(fields, fieldIndex)
        end
        for fieldIndex = #fields + 1, #row.dynamicCells do row.dynamicCells[fieldIndex]:Hide() end
        local isCurrent = current and current.id == character.id
        local rowTone = Theme:GetDataRowColor(index)
        row:SetBackdropColor(rowTone[1], rowTone[2], rowTone[3], rowTone[4] or 0.88)
        row:SetBackdropBorderColor(COLORS.matrixLine[1], COLORS.matrixLine[2], COLORS.matrixLine[3], COLORS.matrixLine[4])
        Theme:SetCurrentCharacterOutline(row.currentOutline, isCurrent)
        row:Show()
    end
    for index = #characters + 1, #parent.rows do parent.rows[index]:Hide() end
    local contentHeight = #characters * (preview and Theme.Table.previewRowHeight or Theme.Table.rowHeight)
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
    parent.scroll:SetPoint("TOPLEFT", 20, -76); parent.scroll:SetPoint("BOTTOMRIGHT", -Theme.Space.xs, 14)
    parent.content = CreateFrame("Frame", nil, parent.scroll); parent.content:SetWidth(620); parent.scroll:SetScrollChild(parent.content)
    parent.rows = {}
end

local function SettingsRow(parent, index, kind)
    local row = parent.rows[index]
    if row and row.controlType ~= kind then row:Hide(); row = nil end
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
        elseif kind == "dropdown" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetHeight(Theme.Size.standard)
            row.label = AddText(row, "GameFontNormalSmall", nil, COLORS.muted)
            row.label:SetPoint("LEFT", 0, 0); row.label:SetWidth(104)
            row.dropdown = Theme:CreateDropdown(row, 180, {})
            row.dropdown:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
        elseif kind == "short-name" then
            row = CreateFrame("Frame", nil, parent.content)
            row:SetHeight(28)
            row.label = AddText(row, "GameFontNormalSmall", nil, COLORS.text)
            row.label:SetPoint("LEFT", 2, 0); row.label:SetPoint("RIGHT", -198, 0)
            row.input = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
            row.input:SetSize(112, 20); row.input:SetPoint("RIGHT", -80, 0); row.input:SetAutoFocus(false); row.input:SetMaxLetters(32); row.input:SetTextInsets(6, 6, 0, 0)
            row.clear = CreateChromeButton(row, 70, 20, "清除", false); row.clear:SetPoint("RIGHT", -2, 0)
        else
            row = CreateChromeButton(parent.content, 250, 22, "")
        end
        parent.rows[index] = row
    end
    row.controlType = kind
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
    local targetID = AccountView.settingsTargetPageID or "display"
    local selected = AccountView._pages[targetID]
    local displayMode, sortingMode, coreMode = targetID == "display", targetID == "sorting", targetID == "core"
    if not (displayMode or sortingMode or coreMode or (selected and not selected.internal)) then
        targetID, displayMode = "display", true
        AccountView.settingsTargetPageID = targetID
    end
    local titles = { display = "显示与入口", sorting = "角色与排序", core = "窗口" }
    parent.heading:SetText(titles[targetID] or (selected.title .. "业务设置"))
    parent.hint:SetText(displayMode and "集中管理 Core 与插件页面、独立入口及显示字段。" or (sortingMode and "统一设置角色、排序、缓存和业务页面的角色过滤。" or (coreMode and "管理窗口布局。" or "这里只保留该插件自身的业务规则与数据管理。")))
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
    local function Input(label, value, callback, inputWidth)
        index = index + 1; local row = SettingsRow(parent, index, "input")
        PlaceGridControl(row)
        row.label:SetText(label); row.label:SetWidth(math.min(84, math.floor(gridWidth * 0.36)))
        row.input:ClearAllPoints(); row.input:SetPoint("LEFT", row.label, "RIGHT", 6, 0)
        if inputWidth then row.input:SetWidth(inputWidth) else row.input:SetPoint("RIGHT", 0, 0) end
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
    local function Dropdown(label, value, options, callback)
        index = index + 1; local row = SettingsRow(parent, index, "dropdown")
        PlaceGridControl(row)
        row.label:SetText(label); row.label:SetWidth(math.min(120, math.floor(gridWidth * 0.38)))
        row.dropdown:ClearAllPoints(); row.dropdown:SetPoint("LEFT", row.label, "RIGHT", 8, 0); row.dropdown:SetPoint("RIGHT", 0, 0)
        row.dropdown:SetOptions(options); row.dropdown:SetValue(value)
        row.dropdown:SetOnValueChanged(function(nextValue)
            callback(nextValue)
            AccountView:RefreshPage()
        end)
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
        -- The same host row is reused when switching business settings.  Hide
        -- the previous addon's child frame first; otherwise its controls can
        -- remain above the newly selected page.
        if row.yiboHostedOwner ~= selected.id then
            for _, child in ipairs({ row:GetChildren() }) do child:Hide() end
            row.yiboHostedOwner = selected.id
        end
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
        local orderGap, orderMinimum = 16, 520
        local orderColumns = math.max(1, math.floor((parent.content:GetWidth() + orderGap) / (orderMinimum + orderGap)))
        local orderWidth = math.floor((parent.content:GetWidth() - orderGap * (orderColumns - 1)) / orderColumns)
        -- Keep the order editor inside the visible workbench whenever possible.
        -- Reserve the pagination controls first, then derive how many complete
        -- rows fit in each column from the actual scroll viewport.
        local controlRows = math.ceil(4 / gridColumns)
        local orderTop = y + controlRows * (Theme.Size.standard + 4)
        local availableHeight = math.max(Theme.Size.standard + 4, (parent.scroll:GetHeight() or 0) - orderTop - 8)
        local rowsPerColumn = math.max(1, math.floor(availableHeight / 28))
        local pageSize = rowsPerColumn * orderColumns
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
        local visibleCount = math.max(0, last - first + 1)
        for slot = 0, visibleCount - 1 do
            local orderIndex = first + slot
            local characterID = order[orderIndex]
            local character = byID[characterID]
            if character then
                index = index + 1
                local row = SettingsRow(parent, index, "character-order")
                -- Fill down the left column before continuing at the right.
                -- This preserves the visible sequence when the editor switches
                -- between one and two columns.
                local orderColumn = math.floor(slot / rowsPerColumn)
                local orderRow = slot % rowsPerColumn
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", 2 + orderColumn * (orderWidth + orderGap), -(y + orderRow * 28)); row:SetWidth(orderWidth)
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
            end
        end
        y = y + math.min(rowsPerColumn, visibleCount) * 28
    end

    local function ShortNameRows()
        local characters = Core.Characters:GetAll()
        local pageSize = 20
        local totalPages = math.max(1, math.ceil(#characters / pageSize))
        parent.shortNamePage = math.max(1, math.min(tonumber(parent.shortNamePage) or 1, totalPages))
        Button("上一页（" .. parent.shortNamePage .. " / " .. totalPages .. "）", function() parent.shortNamePage = math.max(1, parent.shortNamePage - 1); AccountView:RefreshPage() end, 300, "secondary")
        Button("下一页（" .. parent.shortNamePage .. " / " .. totalPages .. "）", function() parent.shortNamePage = math.min(totalPages, parent.shortNamePage + 1); AccountView:RefreshPage() end, 300, "secondary")
        FinishGridRow()
        local duplicates = Core.Characters:GetShortNameDuplicates()
        local first, last = (parent.shortNamePage - 1) * pageSize + 1, math.min(#characters, parent.shortNamePage * pageSize)
        for characterIndex = first, last do
            local character = characters[characterIndex]
            index = index + 1
            local row = SettingsRow(parent, index, "short-name")
            PlaceSettingsRow(row, y); row:SetWidth(parent.content:GetWidth() or 600)
            local displayName = Core.Characters:GetDisplayName(character, "short")
            local warning = duplicates[displayName] and " · 短名重复" or ""
            row.label:SetText((character.name or "未知角色") .. "-" .. (character.realm or "未知服务器") .. warning)
            row.input:SetText(displayName == character.name and "" or displayName)
            local characterID = character.id
            local function Save(control)
                local result, errorMessage = Core.Characters:SetShortName(characterID, control:GetText())
                if result == nil then Core:Print("短名保存失败：" .. tostring(errorMessage)); return end
                AccountView:RefreshPage()
            end
            row.input:SetScript("OnEnterPressed", function(control) Save(control); control:ClearFocus() end)
            row.input:SetScript("OnEditFocusLost", Save)
            row.input:SetScript("OnEscapePressed", function(control) control:SetText(Core.Characters:GetDisplayName(character, "short") == character.name and "" or Core.Characters:GetDisplayName(character, "short")); control:ClearFocus() end)
            row.clear:SetScript("OnClick", function() Core.Characters:SetShortName(characterID, ""); AccountView:RefreshPage() end)
            row:Show(); y = y + 30
        end
    end

    if sortingMode then
        Heading("默认角色排序")
        SortControls(nil)
        Heading("角色名称")
        local shortNameToggle = Button(parent.showShortNames and "▾ 收起短名管理" or "▸ 管理自定义短名", function() parent.showShortNames = not parent.showShortNames; AccountView:RefreshPage() end, 300, "disclosure")
        if parent.showShortNames then
            FinishGridRow()
            ShortNameRows()
        end
        Heading("角色顺序与缓存")
        Button(parent.showCharacterOrder and "▾ 收起顺序与缓存" or "▸ 打开顺序与缓存", function()
            parent.showCharacterOrder = not parent.showCharacterOrder
            AccountView:RefreshPage()
        end, 300, "disclosure")
        if parent.showCharacterOrder then
            FinishGridRow()
            CharacterOrderRows()
        end
        -- Character filters share the same roster context as sorting and cache
        -- management, so they are a section here rather than a fourth Core
        -- navigation page.
        SetGridMinimum(math.max(300, parent.content:GetWidth() or 620))
        Heading("业务页面角色过滤")
        FinishGridRow()
        index = index + 1
        local ruleHint = SettingsRow(parent, index, "heading")
        PlaceSettingsRow(ruleHint, y)
        ruleHint:SetText("填写规则：90 = 仅 90 级；1-20 = 等级范围；<=3 / >=85 = 比较；留空或 0 = 不过滤。")
        ruleHint:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3])
        ruleHint:Show(); y = y + 24
        local count = 0
        for _, page in ipairs(AccountView._pageOrder) do
            local filter = page.characterFilter
            if not page.internal and filter then
                count = count + 1
                Input(page.title .. " · 等级", filter.GetExpression() or "", function(value)
                    local ok, errorMessage = filter.SetExpression(value)
                    if ok == false then Core:Print(page.title .. "等级过滤保存失败：" .. tostring(errorMessage)) end
                end, 112)
            end
        end
        if count == 0 then Heading("暂无支持角色过滤的业务页面") end
        local archive = ArchiveSettings()
        local function CycleArchiveProfile(mode)
            local values = { "all", "profiled", "missing" }
            local current = archive.filters[mode].profile
            for position, value in ipairs(values) do
                if value == current then archive.filters[mode].profile = values[(position % #values) + 1]; break end
            end
            AccountView:RefreshPage()
        end
        Heading("角色档案角色过滤")
        Button("主表筛选：" .. (PROFILE_FILTER_LABELS[archive.filters.page.profile] or PROFILE_FILTER_LABELS.all), function() CycleArchiveProfile("page") end, 300)
        Check("主表筛选时包含已隐藏角色", archive.filters.page.includeHidden == true, function(checked) archive.filters.page.includeHidden = checked end)
        Input("主表等级过滤", archive.filters.page.levelExpr, function(value) archive.filters.page.levelExpr = value end)
        Heading("角色档案悬停角色过滤")
        Button("悬停筛选：" .. (PROFILE_FILTER_LABELS[archive.filters.preview.profile] or PROFILE_FILTER_LABELS.all), function() CycleArchiveProfile("preview") end, 300)
        Check("悬停筛选时包含已隐藏角色", archive.filters.preview.includeHidden == true, function(checked) archive.filters.preview.includeHidden = checked end)
        Input("悬停等级过滤", archive.filters.preview.levelExpr, function(value) archive.filters.preview.levelExpr = value end)
    elseif coreMode then
        Heading("窗口布局")
        Button("重置窗口位置", function() AccountView:ResetWindowLayout() end)
        Heading("窗口尺寸会随当前页面内容自动适配。")
    elseif displayMode then
        local archive = ArchiveSettings()
        local entryModeOptions = {
            { value = "none", label = "不显示" },
            { value = "broker", label = "仅 Broker" },
            { value = "minimap", label = "仅小地图" },
            { value = "both", label = "两者都显示" },
        }
        Dropdown("Core 入口", Core.Entry and Core.Entry:GetCoreEntryMode() or "both", entryModeOptions, function(mode)
            if Core.Entry then Core.Entry:SetCoreEntryMode(mode) end
        end)
        Heading("入口悬停页面")
        Check("主窗口打开时仍显示悬停预览", settings.entry.showPreviewWhileMainWindowOpen == true, function(checked)
            settings.entry.showPreviewWhileMainWindowOpen = checked == true
        end)
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
        Heading("角色档案显示字段")
        Button(parent.showArchiveFields and "▾ 收起角色档案字段" or "▸ 配置角色档案字段", function()
            parent.showArchiveFields = not parent.showArchiveFields
            AccountView:RefreshPage()
        end, 300, "disclosure")
        if parent.showArchiveFields then
            Heading("主表字段")
            SetGridMinimum(160)
            for _, field in ipairs(Core.Fields:GetByConsumer("character-archive")) do
                Check(field.title, ArchiveFieldVisible(field, false), function(checked) archive.fields[field.id] = checked end)
            end
            Heading("悬停字段")
            for _, field in ipairs(Core.Fields:GetByConsumer("character-archive")) do
                Check(field.title, ArchiveFieldVisible(field, true), function(checked) archive.previewFields[field.id] = checked end)
            end
        end
        Heading("插件页面与入口")
        SetGridMinimum(260)
        local displayPages = {}
        for _, page in ipairs(AccountView._pageOrder) do
            if not page.internal then displayPages[#displayPages + 1] = page end
        end
        if parent.displayFieldsPageID and not AccountView._pages[parent.displayFieldsPageID] then parent.displayFieldsPageID = nil end
        if not parent.displayFieldsPageID and displayPages[1] then parent.displayFieldsPageID = displayPages[1].id end
        for _, page in ipairs(AccountView._pageOrder) do
            if not page.internal then
                local entry = Core.Entry and Core.Entry.GetBusinessEntryByPageID and Core.Entry:GetBusinessEntryByPageID(page.id)
                Button("字段：" .. page.title, function()
                    parent.displayFieldsPageID = page.id
                    AccountView:RefreshPage()
                end, 300, "disclosure", parent.displayFieldsPageID == page.id)
                Check(page.title .. "显示在账号视图", PageEnabled(page), function(checked) settings.pages[page.id] = checked end)
                if entry then
                    Dropdown(page.title .. "入口", Core.Entry:GetBusinessEntryMode(entry.id), entryModeOptions, function(mode)
                        settings.entry.pageModes[entry.id] = mode
                        Core.Entry:Refresh()
                    end)
                end
            end
        end
        Heading("主表字段与悬停预览")
        local fieldPage = parent.displayFieldsPageID and AccountView._pages[parent.displayFieldsPageID]
        if fieldPage and #fieldPage.fields > 0 then
            Heading(fieldPage.title)
            for _, field in ipairs(fieldPage.fields) do
                Check("主表 · " .. field.title, AccountView:GetFieldVisible(fieldPage.id, field), function(checked) AccountView:SetFieldVisible(fieldPage.id, field.id, checked) end)
                if fieldPage.previewEnabled and type(fieldPage.SetPreviewFieldVisible) == "function" then
                    Check("悬停 · " .. field.title, GetPreviewFieldVisible(fieldPage, field), function(checked) fieldPage.SetPreviewFieldVisible(field.id, checked) end)
                end
            end
        elseif #displayPages == 0 then
            Heading("暂无已注册的业务插件")
        else
            Heading("所选插件没有可配置字段")
        end
    else
        local details = selected.settings or {}
        if details.description then
            local text = SettingsRow(parent, index + 1, "heading"); index = index + 1; PlaceSettingsRow(text, y); text:SetText(details.description); text:SetTextColor(COLORS.muted[1], COLORS.muted[2], COLORS.muted[3]); text:Show(); y = y + 28
        end
            if type(details.CreateSettingsPanel) == "function" then
                AddonPanel(details)
            else
                Heading("暂无插件专属设置")
            end
    end
    for stale = index + 1, #parent.rows do
        local row = parent.rows[stale]
        if row.dropdown and row.dropdown.menu then row.dropdown.menu:Hide() end
        row:Hide()
    end
    parent.content:SetHeight(math.max(y + 8, parent.scroll:GetHeight() or 1))
    parent.scroll:RefreshScrollbar()
end

local ABOUT_ADDONS = {
    {
        name = "YiboAltoBoss",
        version = "2.1",
        description = "汇总多角色首领进度，快速决定下一步。",
        icon = "Interface\\AddOns\\YiboCore\\Media\\YAB_MinimapIcon",
        url = "https://www.curseforge.com/wow/addons/yiboaltoboss",
    },
    {
        name = "YiboCurrency",
        version = "0.1",
        description = "汇总多角色货币余额，统一查看常规货币与物品代币。",
        icon = "Interface\\AddOns\\YiboCurrency\\Media\\YiboCurrencyIcon-v1",
    },
    {
        name = "YiboLegendary",
        version = "1.0",
        description = "追踪多角色传说任务与橙色传说装备进度。",
        icon = "Interface\\AddOns\\YiboLegendary\\Media\\YiboLegendaryIcon-v1.tga",
        url = "https://www.curseforge.com/wow/addons/yibolegendary",
    },
    {
        name = "YiboQuestBlocker",
        version = "2.1",
        description = "识别任务限制与风险，避免误接关键任务。",
        icon = "Interface\\AddOns\\YiboCore\\Media\\YQB_MinimapIcon",
        url = "https://www.curseforge.com/wow/addons/yiboquestblocker",
    },
    {
        name = "YiboTodo",
        version = "0.1",
        description = "汇总多角色待办与专业冷却，明确下一项可做事务。",
        icon = "Interface\\AddOns\\YiboTodo\\Media\\YiboTodoIcon-v6",
        url = "https://www.curseforge.com/wow/addons/yibotodo",
    },
    {
        name = "YiboReputation",
        version = "1.0",
        description = "汇总多角色声望，掌握阵营关系与晋升进度。",
        icon = "Interface\\AddOns\\YiboReputation\\Media\\YiboReputationIcon-v1",
        url = "https://www.curseforge.com/wow/addons/yiboreputation",
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

-- Compatibility fallback for an incomplete local checkout only.  Normal
-- releases replace this legacy presentation list with the shared catalog so
-- the UI never owns plugin versions.
ABOUT_ADDONS = Core.AddonCatalog or ABOUT_ADDONS

local function SetAboutLinkOpen(parent, target)
    for _, row in ipairs(parent.addonRows) do
        if row.linkButton then
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
    end

    parent:LayoutAboutContent()
end

local CORE_PROJECT_URL = "https://www.curseforge.com/wow/addons/yibocore"

local function SetAboutCoreLinkOpen(parent)
    local hero = parent.hero
    hero.linkOpen = not hero.linkOpen
    hero:SetHeight(hero.linkOpen and 146 or 112)
    hero.linkBox:SetShown(hero.linkOpen)
    hero.copyHint:SetShown(hero.linkOpen)
    hero.linkButton:SetText(hero.linkOpen and "收起链接" or "获取链接")
    if hero.linkOpen then
        hero.linkBox:SetText(CORE_PROJECT_URL)
        hero.linkBox:SetFocus()
        hero.linkBox:HighlightText()
    else
        hero.linkBox:ClearFocus()
    end
    parent:LayoutAboutContent()
end

local function CreateAboutAddonRow(parent, addon)
    addon.independent = addon.relation == "independent" or addon.independent == true
    addon.url = addon.projectURL or addon.url
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

    row.name = AddText(row, "GameFontNormal", Theme.Font.body, COLORS.text)
    row.name:SetPoint("TOPLEFT", row.iconFrame, "TOPRIGHT", 12, -2); row.name:SetText(addon.name)
    row.version = AddText(row, "GameFontNormalSmall", Theme.Font.meta, COLORS.muted)
    row.version:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.version:SetText(addon.version and ("v" .. addon.version) or "")
    row.description = AddText(row, "GameFontNormalSmall", Theme.Font.assist, COLORS.muted)
    row.description:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -8); row.description:SetPoint("RIGHT", addon.url and -154 or -12, 0); row.description:SetText(addon.description)
    if addon.independent then
        row.badge = AddText(row, "GameFontNormalSmall", Theme.Font.meta, COLORS.muted)
        row.badge:SetJustifyH("RIGHT")
        row.badge:SetPoint("RIGHT", -142, 0); row.badge:SetText("独立作品")
    end

    if addon.url then
        row.linkButton = CreateChromeButton(row, 112, 26, "获取链接")
        row.linkButton:SetPoint("TOPRIGHT", -12, -22)
        row.linkBox = CreateFrame("EditBox", nil, row, "BackdropTemplate")
        row.linkBox:SetHeight(24); row.linkBox:SetPoint("BOTTOMLEFT", 96, 9); row.linkBox:SetPoint("BOTTOMRIGHT", -128, 9)
        row.linkBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        row.linkBox:SetBackdropColor(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], 1)
        row.linkBox:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.82)
        -- EditBox:SetFont requires the flags argument on the client used by
        -- this UI.  FontStrings accept two arguments, EditBoxes do not.
        row.linkBox:SetFont(STANDARD_TEXT_FONT, Theme.Font.assist, "")
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
        row.copyHint = AddText(row, "GameFontNormalSmall", Theme.Font.meta, COLORS.accent)
        row.copyHint:SetJustifyH("RIGHT")
        row.copyHint:SetPoint("LEFT", row.linkBox, "RIGHT", 8, 0); row.copyHint:SetPoint("RIGHT", -12, 0); row.copyHint:SetText("按 Ctrl+C 复制")
        row.linkBox:Hide(); row.copyHint:Hide()
        row.linkButton:SetScript("OnClick", function() SetAboutLinkOpen(parent, row) end)
    end
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
    parent.scroll:SetPoint("TOPLEFT", 20, -18); parent.scroll:SetPoint("BOTTOMRIGHT", -Theme.Space.xs, 34)
    parent.content = CreateFrame("Frame", nil, parent.scroll)
    parent.content:SetPoint("TOPLEFT")
    parent.scroll:SetScrollChild(parent.content)
    local function GetContentWidth(scroll)
        return math.max(1, scroll:GetWidth() or 1)
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
    parent.hero.title = AddText(parent.hero, "GameFontNormalLarge", Theme.Font.title, COLORS.text)
    parent.hero.title:SetPoint("TOPLEFT", 110, -20); parent.hero.title:SetText("YiboCore")
    parent.hero.description = AddText(parent.hero, "GameFontNormalSmall", Theme.Font.assist, COLORS.text)
    parent.hero.description:SetPoint("TOPLEFT", parent.hero.title, "BOTTOMLEFT", 0, -9); parent.hero.description:SetText("统一管理 Yibo 系列的账号角色、入口与业务页面")
    parent.hero.status = AddText(parent.hero, "GameFontNormalSmall", Theme.Font.assist, COLORS.muted)
    parent.hero.status:SetJustifyH("RIGHT")
    parent.hero.status:SetPoint("TOPRIGHT", -18, -22)
    parent.hero.metadata = AddText(parent.hero, "GameFontNormalSmall", Theme.Font.meta, COLORS.muted)
    parent.hero.metadata:SetJustifyH("RIGHT")
    parent.hero.metadata:SetPoint("TOPRIGHT", parent.hero.status, "BOTTOMRIGHT", 0, -7)
    parent.hero.linkButton = CreateChromeButton(parent.hero, 112, 26, "获取链接")
    parent.hero.linkButton:SetPoint("TOPRIGHT", -18, -74)
    parent.hero.linkBox = CreateFrame("EditBox", nil, parent.hero, "BackdropTemplate")
    parent.hero.linkBox:SetHeight(24); parent.hero.linkBox:SetPoint("BOTTOMLEFT", 110, 10); parent.hero.linkBox:SetPoint("BOTTOMRIGHT", -128, 10)
    parent.hero.linkBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    parent.hero.linkBox:SetBackdropColor(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], 1)
    parent.hero.linkBox:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.82)
    parent.hero.linkBox:SetFont(STANDARD_TEXT_FONT, Theme.Font.assist, "")
    parent.hero.linkBox:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    parent.hero.linkBox:SetTextInsets(7, 7, 0, 0); parent.hero.linkBox:SetAutoFocus(false); parent.hero.linkBox:SetMaxLetters(240)
    parent.hero.linkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    parent.hero.linkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    parent.hero.linkBox:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    parent.hero.linkBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput and self:GetText() ~= CORE_PROJECT_URL then
            self:SetText(CORE_PROJECT_URL); self:HighlightText()
        end
    end)
    parent.hero.copyHint = AddText(parent.hero, "GameFontNormalSmall", Theme.Font.meta, COLORS.accent)
    parent.hero.copyHint:SetJustifyH("RIGHT")
    parent.hero.copyHint:SetPoint("LEFT", parent.hero.linkBox, "RIGHT", 8, 0); parent.hero.copyHint:SetPoint("RIGHT", -18, 0); parent.hero.copyHint:SetText("按 Ctrl+C 复制")
    parent.hero.linkBox:Hide(); parent.hero.copyHint:Hide()
    parent.hero.linkButton:SetScript("OnClick", function() SetAboutCoreLinkOpen(parent) end)

    parent.childHeading = AddText(parent.content, "GameFontNormal", Theme.Font.section, COLORS.accent)
    parent.childHeading:SetText("YiboCore 子插件")
    parent.otherHeading = AddText(parent.content, "GameFontNormal", Theme.Font.section, COLORS.accent)
    parent.otherHeading:SetText("探索其它 Yibo 插件")
    parent.otherLine = parent.content:CreateTexture(nil, "ARTWORK")
    parent.otherLine:SetHeight(1)
    parent.otherLine:SetColorTexture(COLORS.lineSoft[1], COLORS.lineSoft[2], COLORS.lineSoft[3], COLORS.lineSoft[4])
    for _, addon in ipairs(ABOUT_ADDONS) do CreateAboutAddonRow(parent, addon) end
    parent.footer = AddText(parent, "GameFontNormalSmall", Theme.Font.meta, COLORS.muted, "RIGHT")
    parent.footer:SetPoint("BOTTOMRIGHT", -20, 12); parent.footer:SetText("作者 YiboSoft · CurseForge")
    parent.LayoutAboutContent = function(container)
        local y = (container.hero:GetHeight() or 112) + 28
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
    local stateLabels = {
        connected = "已连接",
        ["enabled-not-connected"] = "已启用尚未连接",
        ["installed-disabled"] = "已安装但未启用",
        missing = "未安装",
    }
    for _, addon in ipairs(ABOUT_ADDONS) do
        local status = Core.AddonStatus and Core.AddonStatus:Get(addon.name) or {}
        local row = parent.addonRowsByName[addon.name]
        if row then
            local installed = status.installedVersion and ("本机 v" .. tostring(status.installedVersion)) or "本机未安装"
            local packaged = status.packagedVersion and (" · 打包时 v" .. tostring(status.packagedVersion)) or ""
            row.version:SetText(installed .. packaged)
            row.description:SetText((stateLabels[status.state] or "状态未知") .. " · " .. tostring(addon.description or ""))
        end
        if not addon.independent and status.connected then
            connected = connected + 1
        end
    end
    parent.hero.status:SetText("已连接 " .. connected .. " 个子插件")
    parent.hero.metadata:SetText("Public API v" .. tostring(Core.API_VERSION or "?") .. " · 数据库 Schema v" .. tostring(Core.Migrations and Core.Migrations.CURRENT_SCHEMA or "?"))
end

local function GetAboutLayoutMetrics()
    return { minWidth = 760, preferredWidth = 942, minHeight = 740, preferredHeight = 760, verticalOverflow = "content" }
end

local function GetOverviewSurfaceMetrics()
    local visiblePages = 0
    for _, page in ipairs(AccountView._pageOrder) do if PageEnabled(page) and not page.internal then visiblePages = visiblePages + 1 end end
    local rows = math.min(visiblePages, 8) + math.min(visiblePages * 2, 8)
    return { minContentWidth = 582, naturalContentWidth = 680, minContentHeight = 150, naturalContentHeight = 84 + rows * 34, verticalOverflow = "content" }
end

local function GetCharacterSurfaceMetrics(context)
    local count = #ArchiveCharacters(context)
    local fields = GetArchiveFields(false)
    local tableWidth = GetArchiveTableWidth(fields, GetArchiveColumnWidths(fields))
    local inset = Theme:GetMatrixInsets(context and context.preview)
    return { minContentWidth = 582, naturalContentWidth = tableWidth + inset.left + inset.right, minContentHeight = 150, naturalContentHeight = inset.top + Theme.Table.headerHeight + Theme.Space.xs + math.min(count, 20) * Theme.Table.rowHeight + inset.bottom, verticalOverflow = "content" }
end

local function GetAboutSurfaceMetrics()
    return { minContentWidth = 582, naturalContentWidth = 764, minContentHeight = 693, naturalContentHeight = 713, verticalOverflow = "content" }
end

local function GetCharacterHoverMetrics(context)
    local count = #ArchiveCharacters(context)
    local fields = GetArchiveFields(true)
    local tableWidth = GetArchiveTableWidth(fields, GetArchiveColumnWidths(fields))
    local inset = Theme:GetMatrixInsets(true)
    local contentHeight = inset.top + Theme.Table.headerHeight + Theme.Space.xs + math.max(1, math.min(count, 20)) * Theme.Table.previewRowHeight + inset.bottom
    return {
        minWidth = 420,
        preferredWidth = math.max(520, tableWidth + 72),
        minHeight = 150,
        preferredHeight = Theme.Geometry.titleBar + Theme.Geometry.shellBorder * 2 + contentHeight,
        verticalOverflow = "content",
    }
end

AccountView._pages.overview = { id = "overview", title = "概览", order = -20, internal = true, previewEnabled = true, Create = CreateOverview, Refresh = RefreshOverview, GetSurfaceMetrics = GetOverviewSurfaceMetrics }
AccountView._pages.characters = { id = "characters", title = "角色档案", order = -10, internal = true, previewEnabled = true, Create = CreateCharacters, Refresh = RefreshCharacters, GetSurfaceMetrics = GetCharacterSurfaceMetrics, GetHoverMetrics = GetCharacterHoverMetrics }
AccountView._pages.about = { id = "about", title = "关于", order = 990, internal = true, Create = CreateAbout, Refresh = RefreshAbout, GetSurfaceMetrics = GetAboutSurfaceMetrics }
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
