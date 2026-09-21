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
local Settings

local CORE_ENTRY_MODES = { none = true, broker = true, minimap = true, both = true }

local function Copy(value)
    return Core.Defaults:Copy(value)
end

Settings = function()
    local db = Core.Database:GetDB()
    db.settings.accountView = db.settings.accountView or {}
    local settings = db.settings.accountView
    settings.pages = settings.pages or {}
    settings.fields = settings.fields or {}
    settings.pageCharacterFilters = type(settings.pageCharacterFilters) == "table" and settings.pageCharacterFilters or {}
    settings.pageViewModes = type(settings.pageViewModes) == "table" and settings.pageViewModes or {}
    settings.pageScopes = settings.pageScopes or {}
    settings.selectedRealmScope = type(settings.selectedRealmScope) == "string" and settings.selectedRealmScope or "all"
    settings.hiddenCharacters = settings.hiddenCharacters or {}
    settings.characterSort = Core.CharacterSort:NormalizeSettings(settings.characterSort)
    settings.pageCharacterSorts = type(settings.pageCharacterSorts) == "table" and settings.pageCharacterSorts or {}
    settings.columnPages = type(settings.columnPages) == "table" and settings.columnPages or {}
    settings.columnPageStructures = type(settings.columnPageStructures) == "table" and settings.columnPageStructures or {}
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

-- Resolve one shared width for a repeated matrix column.  A complete roster
-- may compact down to its semantic minimum before column pagination begins.
function AccountView:FitRepeatedColumnWidth(availableWidth, fixedWidth, columnCount, preferredWidth, minimumWidth)
    local preferred = math.max(1, tonumber(preferredWidth) or 1)
    local minimum = math.max(1, math.min(preferred, tonumber(minimumWidth) or preferred))
    local count = math.max(0, math.floor(tonumber(columnCount) or 0))
    if count == 0 then return preferred end
    -- Keep the fractional remainder.  Flooring each repeated column discards
    -- almost one logical pixel per character; across a full roster that turns
    -- into a conspicuous blank strip at the trailing edge of the matrix.
    local fitted = (math.max(1, tonumber(availableWidth) or 1) - math.max(0, tonumber(fixedWidth) or 0)) / count
    return math.max(minimum, math.min(preferred, fitted))
end

-- Character matrices use the complete natural width first.  Paging is only
-- needed after the caller has reached the screen-safe width; the caller passes
-- that actual width into this helper on every render.
function AccountView:GetColumnPage(pageID, stateKey, columns, availableWidth, fixedWidth, columnWidth, currentID)
    local count = #(columns or {})
    local usableWidth = math.max(1, tonumber(availableWidth) or 1) - math.max(0, tonumber(fixedWidth) or 0)
    local resolvedColumnWidth = math.max(1, tonumber(columnWidth) or 1)
    -- FitRepeatedColumnWidth can intentionally return a fractional width that
    -- fills the viewport exactly.  Tolerate floating-point residue here so an
    -- exact 13-column fit cannot collapse to a 12-column page.
    local capacity = math.max(1, math.floor((usableWidth / resolvedColumnWidth) + 0.0001))
    local totalPages = math.max(1, math.ceil(count / capacity))
    local pages = Settings().columnPages
    pages[pageID] = pages[pageID] or {}
    local current = math.max(1, math.min(tonumber(pages[pageID][stateKey]) or 1, totalPages))
    -- A structural change (roster, order, range, or capacity) returns the
    -- initial view to the page containing the current character. Subsequent
    -- ordinary refreshes preserve the user's manually selected page.
    local settings = Settings()
    settings.columnPageStructures[pageID] = settings.columnPageStructures[pageID] or {}
    local identities, currentIndex = {}, nil
    local currentCharacter = Core.Characters and Core.Characters:GetCurrent()
    local currentIdentity = currentID or (currentCharacter and currentCharacter.id)
    for index, column in ipairs(columns or {}) do
        local identity = type(column) == "table" and (column.id or column.characterID or (column.character and column.character.id)) or column
        identities[index] = tostring(identity or index)
        if currentIdentity and (identity == currentIdentity or (type(column) == "table" and column.character and column.character.id == currentIdentity)) then currentIndex = index end
    end
    local structure = table.concat(identities, "\31") .. "|" .. tostring(capacity)
    if settings.columnPageStructures[pageID][stateKey] ~= structure then
        settings.columnPageStructures[pageID][stateKey] = structure
        if currentIndex then current = math.max(1, math.ceil(currentIndex / capacity)) end
    end
    pages[pageID][stateKey] = current
    local first = count > 0 and ((current - 1) * capacity + 1) or 0
    local last = count > 0 and math.min(count, current * capacity) or 0
    local visible = {}
    for index = first, last do visible[#visible + 1] = columns[index] end
    return visible, { page = current, pages = totalPages, first = first, last = last, capacity = capacity, total = count }
end

function AccountView:GetColumnPageByWidth(pageID, stateKey, columns, availableWidth, fixedWidth, getWidth)
    local count = #(columns or {})
    local limit = math.max(1, tonumber(availableWidth) or 1)
    local base = math.max(0, tonumber(fixedWidth) or 0)
    local allPages, currentPage, used = {}, {}, base
    for _, column in ipairs(columns or {}) do
        local width = math.max(1, tonumber(getWidth(column)) or 1)
        -- Repeated-column fitting intentionally produces fractional widths.
        -- Accept a tiny accumulated residue so an exact fit never ejects the
        -- final column into an otherwise empty page.
        if #currentPage > 0 and used + width > limit + 0.0001 then
            allPages[#allPages + 1], currentPage, used = currentPage, {}, base
        end
        currentPage[#currentPage + 1], used = column, used + width
    end
    if #currentPage > 0 or #allPages == 0 then allPages[#allPages + 1] = currentPage end
    local pages = Settings().columnPages
    pages[pageID] = pages[pageID] or {}
    local current = math.max(1, math.min(tonumber(pages[pageID][stateKey]) or 1, #allPages))
    pages[pageID][stateKey] = current
    local first = 1
    for index = 1, current - 1 do first = first + #allPages[index] end
    local visible = allPages[current]
    return visible, { page = current, pages = #allPages, first = first, last = first + #visible - 1, total = count }
end

function AccountView:SetColumnPage(pageID, stateKey, page, totalPages)
    local pages = Settings().columnPages
    pages[pageID] = pages[pageID] or {}
    pages[pageID][stateKey] = math.max(1, math.min(tonumber(page) or 1, tonumber(totalPages) or 1))
    self:RefreshPage()
end

function AccountView:GetColumnPagerWidth(noun, total)
    local count = math.max(1, tonumber(total) or 20)
    local label = string.format("%s %d–%d / %d · %d/%d", noun or "角色", count, count, count, count, count)
    return Theme:MeasureText(Theme.Font.assist, label) + Theme.Space.xs + Theme.Space.xxs + Theme.Size.compact * 2
end

function AccountView:UpdateColumnPager(parent, pageID, stateKey, info, anchor, noun)
    parent.yiboColumnPager = parent.yiboColumnPager or {}
    local pager = parent.yiboColumnPager
    self._columnPagers = self._columnPagers or {}
    self._columnPagers[pager] = true
    pager.previous = pager.previous or Theme:CreateButton(parent, Theme.Size.compact, "‹", "secondary")
    pager.next = pager.next or Theme:CreateButton(parent, Theme.Size.compact, "›", "secondary")
    pager.label = pager.label or Theme:CreateText(parent, Theme.Font.assist, COLORS.text, "RIGHT")
    pager.previous:ClearAllPoints(); pager.next:ClearAllPoints(); pager.label:ClearAllPoints()
    pager.next:SetPoint("TOPRIGHT", anchor or parent, "TOPRIGHT", 0, 0)
    pager.previous:SetPoint("RIGHT", pager.next, "LEFT", -Theme.Space.xxs, 0)
    pager.label:SetPoint("RIGHT", pager.previous, "LEFT", -Theme.Space.xs, 0)
    local show = info and info.pages > 1
    pager.previous:SetShown(show); pager.next:SetShown(show); pager.label:SetShown(show)
    if not show then return end
    local text = string.format("%s %d–%d / %d · %d/%d", noun or "角色", info.first, info.last, info.total, info.page, info.pages)
    pager.label:SetText(text); pager.label:SetWidth(Theme:MeasureText(Theme.Font.assist, text))
    pager.previous:SetState(info.page > 1 and "default" or "disabled")
    pager.next:SetState(info.page < info.pages and "default" or "disabled")
    pager.previous:SetScript("OnClick", function() if info.page > 1 then AccountView:SetColumnPage(pageID, stateKey, info.page - 1, info.pages) end end)
    pager.next:SetScript("OnClick", function() if info.page < info.pages then AccountView:SetColumnPage(pageID, stateKey, info.page + 1, info.pages) end end)
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
    -- A business page may place one compact state/action control in the
    -- title bar.  It is laid out by Core, so identity text never overlaps it.
    local pageControlWidth = frame.pageTitleControl and frame.pageTitleControl:IsShown()
        and ((frame.pageTitleControlWidth or frame.pageTitleControl:GetWidth() or 0) + Theme.Space.sm) or 0
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
        local available = math.max(0, (frame:GetWidth() or 0) - controlsWidth - scopeWidth - pageControlWidth - pagerWidth - leftInset - rightInset)
        if Theme:MeasureText(Theme.Font.title, candidate.text) <= available then selected, selectedAvailable = candidate, available; break end
    end
    frame.title:SetText(selected.text); frame.title:SetWidth(math.max(1, selectedAvailable)); frame.title:SetShown(selected.text ~= "")
    frame.version:Hide(); frame.subtitle:Hide()
    frame.pageIcon:SetShown(selected.icon and page and page.icon ~= nil)
    frame.title:ClearAllPoints()
    frame.title:SetPoint("LEFT", frame.titleBar, "LEFT", (selected.icon and page and page.icon) and 44 or 16, 0)
    if frame.identityHit then
        local identityWidth = math.max(1, (frame:GetWidth() or 0) - controlsWidth - scopeWidth - pageControlWidth - Theme.Space.sm)
        frame.identityHit:SetWidth(identityWidth)
        -- The title bar is a drag handle, not a duplicate page description.
        -- Keep it mouse-enabled for dragging while deliberately leaving it
        -- without a hover tooltip on every account page.
        Theme:ClearTooltip(frame.identityHit)
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
    if definition.viewModes ~= nil then
        if type(definition.viewModes) ~= "table" or #definition.viewModes < 2 then
            return nil, "页面 viewModes 至少需要两个选项。"
        end
        local ids = {}
        for _, mode in ipairs(definition.viewModes) do
            if type(mode) ~= "table" or type(mode.id) ~= "string" or mode.id == "" or type(mode.title) ~= "string" then
                return nil, "页面 viewModes 必须提供 id 与 title。"
            end
            if ids[mode.id] then return nil, "页面 viewMode ID 重复: " .. mode.id end
            ids[mode.id] = true
        end
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
    -- A business page may opt into its own filter storage, but it must never
    -- disappear from the shared role-filter workbench merely because it has
    -- no special filtering needs.  Core owns this neutral fallback so every
    -- account page has one consistent filter control.
    if not page.internal and not page.characterFilter then
        page.characterFilter = {
            defaultExpression = "",
            GetExpression = function()
                return Settings().pageCharacterFilters[page.id] or ""
            end,
            SetExpression = function(expression)
                local valid, normalized, badToken = Core.LevelFilter:Validate(expression or "")
                if not valid then return false, "无效等级规则：" .. tostring(badToken) end
                Settings().pageCharacterFilters[page.id] = normalized
                AccountView:NotifyPageChanged(page.id)
                return true, normalized
            end,
        }
    end
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

function AccountView:GetPageViewMode(pageID, modes)
    local saved = Settings().pageViewModes[pageID]
    for _, mode in ipairs(modes or {}) do
        if mode.id == saved then return saved end
    end
    return modes and modes[1] and modes[1].id or nil
end

function AccountView:SetPageViewMode(pageID, modeID)
    local page = self._pages[pageID]
    for _, mode in ipairs(page and page.viewModes or {}) do
        if mode.id == modeID then
            Settings().pageViewModes[pageID] = modeID
            self:RefreshPage()
            return true
        end
    end
    return false
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
    for _, character in ipairs(Core.Characters:GetAllCached()) do
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
    local characters, known, order, present = Core.Characters:GetAllCached(), {}, {}, {}
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
    local characters = Core.Characters:GetAllCached()
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
        for _, character in ipairs(characters or Core.Characters:GetAllCached()) do
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
        -- A scope selection changes the preview's data set even when its
        -- page and entry anchor are unchanged.  Force a rebuild; otherwise
        -- ShowPreview's same-page fast path returns before the new range is
        -- rendered.
        self:ShowPreview(pageID, self.previewAnchor, true)
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

-- The account shell can contain secure action controls supplied by a business
-- page.  A normal Lua Frame:Hide() is therefore blocked once combat starts.
-- This state handler runs the visibility change in WoW's secure environment.
function AccountView:EnsureCombatWindowHider()
    if self.combatWindowHider or not self.frame or (InCombatLockdown and InCombatLockdown()) then return end
    local hider = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
    hider:SetFrameRef("accountFrame", self.frame)
    hider:SetAttribute("_onstate-combat", [[
        local accountFrame = self:GetFrameRef("accountFrame")
        if newstate == "1" then
            accountFrame:Hide()
        end
    ]])
    RegisterStateDriver(hider, "combat", "[combat] 1; 0")
    self.combatWindowHider = hider
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
    self:EnsureCombatWindowHider()
    return frame
end

local function NavigationRequiredHeight(page)
    local count
    if page and page.id == "settings" then
        count = 5
        for _, registered in ipairs(AccountView._pageOrder) do if not registered.internal then count = count + 1 end end
        for _ in ipairs(Core:GetRegisteredSettingsPanels()) do count = count + 1 end
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
        local businessSettings = {}
        for _, page in ipairs(self._pageOrder) do
            if not page.internal and not page.hideFromSettings then businessSettings[#businessSettings + 1] = { id = "settings-" .. page.id, title = page.title, settingsTargetID = page.id, addonName = page.addonName or page.id } end
        end
        for _, panel in ipairs(Core:GetRegisteredSettingsPanels()) do
            businessSettings[#businessSettings + 1] = { id = "addon-settings:" .. panel.id, title = panel.title, settingsTargetID = "addon-settings:" .. panel.id, addonName = panel.addonName }
        end
        table.sort(businessSettings, function(left, right) return left.addonName < right.addonName end)
        for _, item in ipairs(businessSettings) do pages[#pages + 1] = item end
    else
        pages = { self._pages.overview }
        -- The interval between overview (-20) and character archive (-10) is
        -- reserved for a page explicitly promoted directly below overview.
        -- All ordinary business pages retain their catalog's alphabetical order.
        for _, page in ipairs(self._pageOrder) do
            if PageEnabled(page) and (page.order or 100) < -10 then pages[#pages + 1] = page end
        end
        pages[#pages + 1] = self._pages.characters
        for _, page in ipairs(self._pageOrder) do
            if PageEnabled(page) and (page.order or 100) >= -10 then pages[#pages + 1] = page end
        end
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

-- Page-owned title-bar controls are deliberately constrained to one compact
-- control.  The title remains the left-side identity, while state/actions
-- occupy the right side before scope controls and the window's own buttons.
function AccountView:ClearTitleBarControl()
    local frame = self.frame
    if not frame then return end
    if frame.pageTitleControl then frame.pageTitleControl:Hide() end
    frame.pageTitleControl, frame.pageTitleControlWidth = nil, nil
end

function AccountView:SetTitleBarControl(control, width)
    local frame = self:CreateFrame()
    if frame.pageTitleControl and frame.pageTitleControl ~= control then frame.pageTitleControl:Hide() end
    if not control then self:ClearTitleBarControl(); return end
    frame.pageTitleControl, frame.pageTitleControlWidth = control, width or control:GetWidth()
    control:SetParent(frame.titleBar)
    control:SetFrameLevel((frame.titleBar:GetFrameLevel() or 0) + 2)
    control:ClearAllPoints()
    if frame.scopeBar and frame.scopeBar:IsShown() then
        control:SetPoint("RIGHT", frame.scopeBar, "LEFT", -Theme.Space.sm, 0)
    else
        control:SetPoint("RIGHT", frame.titleBar, "RIGHT", -Theme.Space.sm, 0)
    end
    control:Show()
end

function AccountView:BuildContext(page, options)
    options = options or {}
    local overrides = options.fieldOverrides
    -- Character archive owns its own inclusion filters.  Business pages keep
    -- the account-wide hidden-character admission rule.
    local characters = page and page.id == "characters" and Core.Characters:GetAllCached() or self:GetVisibleCharacters()
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
        viewMode = self:GetPageViewMode(page.id, page.viewModes),
        scope = scope,
        scopeDefinition = scopeDefinition,
        SetScope = function(_, scopeID) return self:SetPageScope(page.id, scopeID) end,
        Refresh = function() self:RefreshPage() end,
        SetTitleBarControl = function(_, control, width) return self:SetTitleBarControl(control, width) end,
        ClearTitleBarControl = function() self:ClearTitleBarControl() end,
        preview = options.preview == true,
        characterSort = characterSort,
    }
end

function AccountView:ShowPage(pageID, options)
    options = options or {}
    -- Some hosted pages (for example YiboTodo) contain secure action buttons.
    -- Switching pages hides every inactive page instance, which WoW forbids
    -- while in combat when any of them is protected.  Keep the requested
    -- refresh and apply it immediately after combat instead.
    if InCombatLockdown and InCombatLockdown() then
        self._pendingPageID = pageID
        self._pendingPageOptions = options
        self._refreshPendingAfterCombat = true
        return false
    end
    local page = self._pages[pageID] or self._pages.overview
    if not page or (not page.internal and not PageEnabled(page)) then page = self._pages.overview end
    self:CreateFrame()
    local context = options.context or self:BuildContext(page, options)
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
    -- The refreshing page may opt back in through context.SetTitleBarControl.
    -- Hide the previous page's control first so page switches never leave
    -- stale actions in the shared chrome.
    self:ClearTitleBarControl()
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
    if InCombatLockdown and InCombatLockdown() then
        self._refreshPendingAfterCombat = true
        return false
    end
    if self.frame.preview and self.previewPageID then
        -- Preview geometry is derived from page metrics before rendering.  A
        -- fold/unfold changes those metrics, so rebuild the same preview from
        -- its original anchor instead of only repainting the old-sized page.
        -- ShowPreview's same-anchor fast path is for pointer movement only;
        -- a data notification must render the new page state.
        self:ShowPreview(self.previewPageID, self.previewAnchor, true)
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

function AccountView:ShowPreview(pageID, anchor, forceRefresh)
    local page = self._pages[pageID] or self:GetPreviewPage()
    local frame = self:CreateFrame()
    local allowWhileMainWindowOpen = Settings().entry.showPreviewWhileMainWindowOpen == true
    if not page or not page.previewEnabled or (not page.internal and not PageEnabled(page)) or (frame:IsShown() and not frame.preview and not allowWhileMainWindowOpen) then return false end

    -- The shared shell can temporarily become a preview when the player has
    -- opted in.  Remember that it was a normal window so it is restored when
    -- the pointer leaves the entry instead of remaining in preview layout.
    self.restoreNormalWindowAfterPreview = frame:IsShown() and not frame.preview

    local fields = type(page.GetPreviewFields) == "function" and page.GetPreviewFields() or page.previewFields
    local anchorFrame = anchor and type(anchor.GetLeft) == "function" and anchor or nil
    if not forceRefresh and frame:IsShown() and frame.preview and self.previewPageID == page.id and self.previewAnchor == anchorFrame then
        return true
    end
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
    self:ShowPage(page.id, { preview = true, fieldOverrides = fields, context = context })
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
    if InCombatLockdown and InCombatLockdown() then
        Core:Print("战斗中不能打开设置。脱离战斗后再试。")
        return false
    end
    self:CreateFrame()
    self:EnsureCombatWindowHider()
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
    return true
end

-- Refreshing a hosted page can hide another page instance.  That operation is
-- deferred until combat ends; visibility itself is handled by the secure
-- state driver installed above.
Core.Events:Register("PLAYER_REGEN_ENABLED", AccountView, function(view)
    if view._refreshPendingAfterCombat then
        local pageID = view._pendingPageID
        local options = view._pendingPageOptions
        view._refreshPendingAfterCombat = nil
        view._pendingPageID = nil
        view._pendingPageOptions = nil
        if pageID then
            view:ShowPage(pageID, options)
        else
            view:RefreshPage()
        end
    end
end)

function AccountView:SelectSettingsTarget(targetID)
    local settingsOnlyID = type(targetID) == "string" and targetID:match("^addon%-settings:(.+)$")
    if settingsOnlyID then
        if not (Core.SettingsRegistry and Core.SettingsRegistry._panels[settingsOnlyID]) then return false end
    elseif targetID ~= "display" and targetID ~= "sorting" and targetID ~= "core" and targetID ~= "filters" then
        local page = self._pages[targetID]
        if not page or page.internal then return false end
    end
    self.settingsTargetPageID = targetID
    if self.activePageID == "settings" then self:RefreshPage() end
    return true
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

local function GetAboutSurfaceMetrics()
    return { minContentWidth = 582, naturalContentWidth = 764, minContentHeight = 693, naturalContentHeight = 713, verticalOverflow = "content" }
end

-- Page modules receive these intentionally narrow implementation helpers.  This
-- keeps the public AccountView API stable while separating concrete page views.
AccountView._internal = {
    AddText = AddText,
    CreateChromeButton = CreateChromeButton,
    Settings = Settings,
    Copy = Copy,
    PageEnabled = PageEnabled,
    SORT_MODES = SORT_MODES,
    SORT_LABELS = SORT_LABELS,
    GetPreviewFieldVisible = GetPreviewFieldVisible,
    GetOverviewSurfaceMetrics = GetOverviewSurfaceMetrics,
    GetAboutSurfaceMetrics = GetAboutSurfaceMetrics,
}
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
