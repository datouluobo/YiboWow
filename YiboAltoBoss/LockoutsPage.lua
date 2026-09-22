local Core = _G.YiboCore
local YAB = _G.YAB
local Theme = Core.UITheme
local C = Theme.Colors

local TAB_H = 34
local CELL_W = 88
local ROW_H = 24

function YAB.SetAccountBusinessPage(pageID)
    YiboAltoBossDB = YiboAltoBossDB or {}
    YiboAltoBossDB.settings = YiboAltoBossDB.settings or {}
    YiboAltoBossDB.settings.accountPage = pageID == "alto-lockouts" and "lockouts" or "boss"
end

function YAB.GetAccountBusinessPageID()
    local selected = YiboAltoBossDB and YiboAltoBossDB.settings and YiboAltoBossDB.settings.accountPage
    return selected == "lockouts" and "alto-lockouts" or "alto-boss"
end

function YAB.GetBusinessTabHeight() return TAB_H end

function YAB.CreateBusinessTabs(parent, active)
    local tabs = CreateFrame("Frame", nil, parent)
    tabs:SetHeight(TAB_H)
    tabs:SetPoint("TOPLEFT", 0, 0)
    tabs:SetPoint("TOPRIGHT", 0, 0)
    tabs:SetFrameLevel((parent:GetFrameLevel() or 0) + 5)
    tabs.buttons = {}
    tabs.leftBridge = tabs:CreateTexture(nil, "OVERLAY")
    tabs.leftBridge:SetHeight(1)
    tabs.rightBridge = tabs:CreateTexture(nil, "OVERLAY")
    tabs.rightBridge:SetHeight(1)
    local defs = {
        { id = "boss", title = "Boss", page = "alto-boss", width = 112 },
        { id = "lockouts", title = "副本", page = "alto-lockouts", width = 126 },
    }
    for index, def in ipairs(defs) do
        local button = CreateFrame("Button", nil, tabs, "BackdropTemplate")
        button:SetSize(def.width, TAB_H)
        button:SetPoint("TOPLEFT", 8 + (index - 1) * (def.width + 2), 0)
        button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        button.label = Theme:CreateText(button, Theme.Font.body, C.text, "CENTER")
        button.label:SetPoint("CENTER")
        button:SetScript("OnClick", function()
            YAB.SetAccountBusinessPage(def.page)
            if Core.AccountView and Core.AccountView.ShowPage then Core.AccountView:ShowPage(def.page) end
        end)
        button:SetScript("OnEnter", function(self) if self.active ~= true then self:SetBackdropColor(C.toolbar[1], C.toolbar[2], C.toolbar[3], 1) end end)
        button:SetScript("OnLeave", function(self) self:SetBackdropColor(self.active and C.chrome[1] or C.bg[1], self.active and C.chrome[2] or C.bg[2], self.active and C.chrome[3] or C.bg[3], 1) end)
        button.tabBottom = button:CreateTexture(nil, "OVERLAY")
        button.tabBottom:SetPoint("BOTTOMLEFT", 1, 0)
        button.tabBottom:SetPoint("BOTTOMRIGHT", -1, 0)
        button.tabBottom:SetHeight(2)
        button.label:SetText(def.title)
        tabs.buttons[def.id] = button
    end
    -- Render the rule from a frame above every tab so button backdrops cannot
    -- replace it with a different bottom border or leave a gap.
    tabs.lineOverlay = CreateFrame("Frame", nil, tabs)
    tabs.lineOverlay:SetAllPoints(tabs)
    tabs.lineOverlay:SetFrameLevel(tabs:GetFrameLevel() + 20)
    tabs.lineOverlay.left = tabs.lineOverlay:CreateTexture(nil, "OVERLAY")
    tabs.lineOverlay.left:SetHeight(1)
    tabs.lineOverlay.left:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    tabs.lineOverlay.right = tabs.lineOverlay:CreateTexture(nil, "OVERLAY")
    tabs.lineOverlay.right:SetHeight(1)
    tabs.lineOverlay.right:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    tabs.lineOverlay.activeGap = tabs.lineOverlay:CreateTexture(nil, "OVERLAY")
    tabs.lineOverlay.activeGap:SetHeight(2)
    tabs.lineOverlay.activeGap:SetColorTexture(C.chrome[1], C.chrome[2], C.chrome[3], 1)
    function tabs:SetActive(id)
        local activeButton
        for key, button in pairs(self.buttons) do
            button.active = key == id
            local active = button.active
            if active then activeButton = button end
            button:SetBackdropColor(active and C.chrome[1] or C.bg[1], active and C.chrome[2] or C.bg[2], active and C.chrome[3] or C.bg[3], 1)
            button:SetBackdropBorderColor(active and C.accent[1] or C.matrixLine[1], active and C.accent[2] or C.matrixLine[2], active and C.accent[3] or C.matrixLine[3], 1)
            button.label:SetTextColor(active and C.text[1] or C.muted[1], active and C.text[2] or C.muted[2], active and C.text[3] or C.muted[3])
            -- The rule is rendered above all tabs and remains continuous;
            -- active state is communicated by the tab's fill and outline.
            button.tabBottom:Hide()
        end
        self.lineOverlay.left:ClearAllPoints()
        self.lineOverlay.left:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)
        self.lineOverlay.left:SetPoint("BOTTOMRIGHT", activeButton, "BOTTOMLEFT", 1, 0)
        self.lineOverlay.right:ClearAllPoints()
        self.lineOverlay.right:SetPoint("BOTTOMLEFT", activeButton, "BOTTOMRIGHT", -1, 0)
        self.lineOverlay.right:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
        self.lineOverlay.activeGap:ClearAllPoints()
        self.lineOverlay.activeGap:SetPoint("BOTTOMLEFT", activeButton, "BOTTOMLEFT", 1, 0)
        self.lineOverlay.activeGap:SetPoint("BOTTOMRIGHT", activeButton, "BOTTOMRIGHT", -1, 0)
        self.lineOverlay.left:Show()
        self.lineOverlay.right:Show()
        self.lineOverlay.activeGap:Show()
        self.leftBridge:Hide()
        self.rightBridge:Hide()
    end
    tabs:SetActive(active)
    return tabs
end

local function Text(parent, size, color, justify)
    return Theme:CreateText(parent, size or Theme.Font.body, color or C.text, justify or "LEFT")
end

local function CharacterInfo(key)
    local info = YiboAltoBossDB.knownChars[key] or {}
    return info.name or key:match("^(.-)-") or key, info.realm or key:match("-(.+)$") or "未知服务器", info.class
end

local function CharacterColor(key)
    local _, _, class = CharacterInfo(key)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return color or C.text
end

local function Release(pool, start)
    for index = start or 1, #pool do pool[index]:Hide() end
end

local function HeaderCell(parent, x, width, title, secondary)
    local header = Theme:CreateMatrixHeader(parent)
    header:SetWidth(width)
    header:SetPoint("TOPLEFT", x, 0)
    Theme:SetMatrixHeader(header, title, secondary and { secondary = secondary } or nil)
    return header
end

local function StatusCell(parent, index, x, y, column, charKey)
    local cell = parent.cells[index] or CreateFrame("Button", nil, parent, "BackdropTemplate")
    parent.cells[index] = cell
    cell:Show()
    cell:SetSize(CELL_W, ROW_H)
    cell:SetPoint("TOPLEFT", x, y)
    cell:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    local status, label = YAB.GetLockoutStatus(charKey, column)
    local color = status == "clear" and C.success or status == "locked" and C.accent or C.muted
    cell:SetBackdropColor(color[1] * 0.18, color[2] * 0.18, color[3] * 0.18, 0.95)
    cell:SetBackdropBorderColor(C.matrixLine[1], C.matrixLine[2], C.matrixLine[3], 1)
    cell.text = cell.text or Text(cell, Theme.Font.body, color, "CENTER")
    cell.text:SetAllPoints()
    cell.text:SetText(label)
    Theme:BindTooltip(cell, column.name, YAB.GetLockoutTooltip(charKey, column))
end

function YAB.CreateLockoutsPage(parent)
    parent:SetClipsChildren(true)
    parent.businessTabs = YAB.CreateBusinessTabs(parent, "lockouts")
    parent.header = CreateFrame("Frame", nil, parent)
    parent.header:SetHeight(Theme.Table.headerHeight)
    -- The lockout page is a compact character-row matrix.  Its host window
    -- measures the rendered rows and grows to fit them, so a second vertical
    -- scrollbar would only duplicate Core's page sizing behavior.
    parent.body = CreateFrame("Frame", nil, parent)
    parent.headers, parent.rows = {}, {}
    return parent
end

function YAB.RefreshLockoutsPage(instance, context)
    YAB.SetAccountBusinessPage("alto-lockouts")
    local inset = Theme:GetMatrixInsets(context and context.preview)
    local keys = YAB.GetAccountCharacterKeys(context)
    local allColumns = YAB.GetLockoutColumns(context)
    instance.businessTabs:SetActive("lockouts")
    instance.header:ClearAllPoints()
    instance.header:SetPoint("TOPLEFT", inset.left, -TAB_H)
    instance.header:SetPoint("TOPRIGHT", -inset.right, -TAB_H)
    instance.body:ClearAllPoints()
    instance.body:SetPoint("TOPLEFT", instance.header, "BOTTOMLEFT", 0, -Theme.Space.xs)
    instance.body:SetPoint("TOPRIGHT", instance.header, "BOTTOMRIGHT", 0, -Theme.Space.xs)
    local charWidth = math.max(150, Theme:MeasureText(Theme.Font.body, "角色") + Theme.Space.lg * 2)
    local availableWidth = math.max(
        charWidth + CELL_W,
        (tonumber(context and context.surfaceAvailableWidth) or instance:GetWidth() or 1) - inset.left - inset.right
    )
    local columns, pageInfo = Core.AccountView:GetColumnPage(
        "alto-lockouts", "instances", allColumns, availableWidth, charWidth, CELL_W
    )
    -- Pagination shares the tab row so no separate status strip interrupts
    -- the active tab's connection to the matrix header.
    Core.AccountView:UpdateColumnPager(instance, "alto-lockouts", "instances", pageInfo, instance.businessTabs, "副本")
    Release(instance.headers)
    local first = HeaderCell(instance.header, 0, charWidth, "角色")
    instance.headers[1] = first
    for index, column in ipairs(columns) do
        local abbreviation = column.abbreviation or "INST"
        local header = HeaderCell(
            instance.header,
            charWidth + (index - 1) * CELL_W,
            CELL_W,
            column.shortName or column.name,
            "（" .. abbreviation .. "）"
        )
        Theme:BindTooltip(header, string.format("%s（%s）", column.name, abbreviation))
        instance.headers[index + 1] = header
    end
    local y = 0
    Release(instance.rows)
    for rowIndex, charKey in ipairs(keys) do
        local row = instance.rows[rowIndex] or CreateFrame("Frame", nil, instance.body)
        instance.rows[rowIndex] = row
        row:Show()
        row:SetHeight(ROW_H)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", 0, -y)
        row.cells = row.cells or {}
        local name = CharacterInfo(charKey)
        row.label = row.label or Text(row, Theme.Font.body, C.text, "LEFT")
        row.label:SetPoint("LEFT", 6, 0)
        row.label:SetWidth(charWidth - 12)
        row.label:SetText(name)
        local color = CharacterColor(charKey)
        row.label:SetTextColor(color.r or color[1], color.g or color[2], color.b or color[3])
        for index, column in ipairs(columns) do StatusCell(row, index, charWidth + (index - 1) * CELL_W, 0, column, charKey) end
        Release(row.cells, #columns + 1)
        y = y + ROW_H + 2
    end
    Release(instance.rows, #keys + 1)
    instance.body:SetSize(math.max(1, charWidth + #columns * CELL_W), math.max(1, y))
    instance.renderedContentHeight = TAB_H + Theme.Table.headerHeight
        + Theme.Space.xs + math.max(1, y) + inset.bottom
end

function YAB.GetLockoutsSurfaceMetrics(context)
    local columns = YAB.GetLockoutColumns(context)
    local keys = YAB.GetAccountCharacterKeys(context)
    local inset = Theme:GetMatrixInsets(context and context.preview)
    local charWidth = 150
    local height = TAB_H + Theme.Table.headerHeight + Theme.Space.xs
        + math.max(1, #keys) * (ROW_H + 2) + inset.bottom
    return {
        naturalContentWidth = inset.left + charWidth + #columns * CELL_W + inset.right,
        minContentWidth = inset.left + charWidth + math.min(1, #columns) * CELL_W + inset.right,
        naturalContentHeight = height,
        minContentHeight = height,
        fixedTopHeight = TAB_H,
        horizontalOverflow = "paginate",
        verticalOverflow = "none",
    }
end

-- Core calls this after the page has rendered.  Keeping the measurement in
-- the page makes the window height follow the actual character-row matrix,
-- including rows that were filtered or added after the first layout pass.
function YAB.GetLockoutsMeasuredHeight(instance, context)
    if instance and instance.renderedContentHeight then return instance.renderedContentHeight end
    return YAB.GetLockoutsSurfaceMetrics(context).naturalContentHeight
end

function YAB.GetLockoutsHoverMetrics(context)
    local metrics = YAB.GetLockoutsSurfaceMetrics(context)
    return {
        minWidth = metrics.minContentWidth + Theme.Geometry.shellBorder * 2,
        preferredWidth = metrics.naturalContentWidth + Theme.Geometry.shellBorder * 2,
        minHeight = metrics.minContentHeight + Theme.Geometry.titleBar + Theme.Geometry.shellBorder * 2,
        preferredHeight = metrics.naturalContentHeight + Theme.Geometry.titleBar + Theme.Geometry.shellBorder * 2,
        horizontalOverflow = "paginate",
        verticalOverflow = "none",
    }
end

function YAB.GetLockoutsSummary(characters)
    local count, limit = YAB.GetThrottleStatus()
    return string.format("普通本 %d/%d", count, limit)
end

function YAB.GetLockoutsActions() return {} end
