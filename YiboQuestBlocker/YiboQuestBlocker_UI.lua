-- ============================================================================
-- YiboQuestBlocker_UI.lua
-- 旧业务窗口（账号视图由 YiboCore 承载）
-- ============================================================================

-- ==================== 常量 ====================
local Theme = _G.YiboCore.UITheme
local DEFAULT_W = 520
local DEFAULT_H = 500
local MIN_W     = 460
local MIN_H     = 420

local PAD            = 10
local TITLE_H        = 30
local FILTER_ROW_H   = 22
local FILTER_AREA_H  = 48
local HEADER_H       = 24
local GROUP_H        = 24
local ROW_H          = 22
local BOTTOM_H       = 52

local CHECK_SIZE     = 16
local GLOBAL_COL_W   = 40
local CHAR_COL_W     = 36

local BACKDROP_BG    = "Interface\\ChatFrame\\ChatFrameBackground"
local CHECK_TEXTURE  = "Interface\\Buttons\\UI-CheckBox-Check"

local COL_TITLE      = {1, .82, .2}
local COL_TEXT       = {.95, .95, .95}
local COL_SUBTEXT    = {.76, .76, .76}
local COL_BORDER     = {.18, .18, .18, .95}
local COL_BORDER_RED = {.6, .12, .15, .95}
local COL_HILITE     = {.2, .7, .85, .9}
local COL_BG         = {0, 0, 0, .82}
local COL_PANEL      = {.03, .03, .03, .58}
local COL_ROW        = {.05, .05, .05, .45}
local COL_ROW_HOVER  = {.12, .12, .12, .72}
local COL_GROUP      = {.18, .03, .06, .72}
local COL_GROUP_ALT  = {.08, .08, .08, .78}
local COL_CHECK      = {.9, .2, .25}

local SORT_KEYS = {"custom", "name", "level", "count"}
local SORT_NAMES = {
    custom = "自定义",
    order  = "自定义",
    name   = "名称",
    level  = "等级",
    count  = "拒绝数",
}

-- ==================== 全局变量 ====================
local YQB = _G.YQB
local YQBDB = YiboQuestBlockerDB
local curCharKey = YQB.curCharKey
local ADDON_NAME = ...
local ADDON_VERSION = (GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME or "YiboQuestBlocker", "Version")) or "?"

local RefreshUI, ApplyLayout, RebuildContent, UpdateStats, ClearInputFocus
local MainFrame
local RefreshOrderEditor
local SetRefreshPending
local ApplySavedWindowSize

local function SyncUIBindings()
    YQB = _G.YQB or YQB
    YQBDB = YiboQuestBlockerDB or YQBDB
    if YQB and YQB.curCharKey then
        curCharKey = YQB.curCharKey
    end
end

if YQB then
    YQB.SyncUIBindings = SyncUIBindings
end

-- ==================== 基础工具 ====================
local function ShortName(charKey)
    local name = string.match(charKey or "", "^(.-)%-")
    return name or charKey or "?"
end

local function Utf8Sub(str, maxChars)
    if not str or maxChars <= 0 then return "" end
    local length = 0
    local index = 1
    while index <= #str and length < maxChars do
        length = length + 1
        local byte = string.byte(str, index)
        if byte < 0x80 then
            index = index + 1
        elseif byte < 0xE0 then
            index = index + 2
        elseif byte < 0xF0 then
            index = index + 3
        else
            index = index + 4
        end
    end
    return string.sub(str, 1, index - 1)
end

local function GetHeaderCharText(charKey)
    local name = ShortName(charKey)
    local charsPerLine = math.max(1, math.min(6, tonumber((YQBDB.ui and YQBDB.ui.headerCharsPerLine) or 3) or 3))
    local pieces = {}
    local rest = name

    while rest ~= "" do
        local chunk = Utf8Sub(rest, charsPerLine)
        if chunk == "" then break end
        pieces[#pieces + 1] = chunk
        rest = string.sub(rest, #chunk + 1)
    end

    return table.concat(pieces, "\n")
end

local function GetHeaderLineCount(charKey)
    local name = ShortName(charKey)
    local charsPerLine = math.max(1, math.min(6, tonumber((YQBDB.ui and YQBDB.ui.headerCharsPerLine) or 3) or 3))
    local count = 0
    local rest = name
    while rest ~= "" do
        local chunk = Utf8Sub(rest, charsPerLine)
        if chunk == "" then break end
        count = count + 1
        rest = string.sub(rest, #chunk + 1)
    end
    return math.max(count, 1)
end

local function GetCharColumnWidth()
    local charsPerLine = math.max(1, math.min(6, tonumber((YQBDB.ui and YQBDB.ui.headerCharsPerLine) or 3) or 3))
    return math.max(34, 16 + charsPerLine * 13)
end

local function GetHeaderHeight()
    local maxLines = 1
    if YQB and YQB.GetSortedVisibleChars then
        for _, charKey in ipairs(YQB.GetSortedVisibleChars() or {}) do
            local lines = GetHeaderLineCount(charKey)
            if lines > maxLines then
                maxLines = lines
            end
        end
    end
    return math.max(HEADER_H, 14 + maxLines * 16)
end

local function EnsureCharDB(charKey)
    SyncUIBindings()
    if not YQBDB.perChar[charKey] then
        YQBDB.perChar[charKey] = {
            blocked = {},
            cache = {},
            windowShown = false,
            _foldedBlocked = false,
            _foldedCurrent = false,
        }
    end

    local db = YQBDB.perChar[charKey]
    if db._foldedBlocked == nil then db._foldedBlocked = false end
    if db._foldedCurrent == nil then db._foldedCurrent = false end
    if db.windowShown == nil then db.windowShown = false end
    if not db.blocked then db.blocked = {} end
    if not db.cache then db.cache = {} end
    return db
end

local function EnsureUIConfig()
    SyncUIBindings()
    YQBDB.ui = YQBDB.ui or {}
    if YQBDB.ui.windowWidth == nil then
        YQBDB.ui.windowWidth = DEFAULT_W
    end
    if YQBDB.ui.windowHeight == nil then
        YQBDB.ui.windowHeight = DEFAULT_H
    end
    if YQBDB.ui.headerCharsPerLine == nil then
        YQBDB.ui.headerCharsPerLine = 3
    end
    return YQBDB.ui
end

local function PersistNow()
    if YQB and YQB.PersistDB then
        YQB.PersistDB()
    end
end

local function ClampSize(frame)
    local w = frame:GetWidth()
    local h = frame:GetHeight()
    local changed

    if w < MIN_W then
        frame:SetWidth(MIN_W)
        changed = true
    end
    if h < MIN_H then
        frame:SetHeight(MIN_H)
        changed = true
    end

    return changed
end

ApplySavedWindowSize = function()
    if not MainFrame then return end
    local uiDB = EnsureUIConfig()
    local width = tonumber(uiDB.windowWidth) or DEFAULT_W
    local height = tonumber(uiDB.windowHeight) or DEFAULT_H
    if width < MIN_W then width = MIN_W end
    if height < MIN_H then height = MIN_H end
    MainFrame:SetSize(width, height)
end

local function SetBackdropStyle(frame, bgColor, borderColor, inset)
    inset = inset or 1
    frame:SetBackdrop({
        bgFile = BACKDROP_BG,
        edgeFile = BACKDROP_BG,
        tile = false,
        edgeSize = 1,
        insets = { left = inset, right = inset, top = inset, bottom = inset },
    })
    frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
end

local function CreateLine(parent, layer)
    local line = parent:CreateTexture(nil, layer or "BORDER")
    line:SetColorTexture(.18, .18, .18, .85)
    return line
end

local function CreateBackdropFrame(parent, bgColor, borderColor, levelOffset)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if levelOffset then
        frame:SetFrameLevel(parent:GetFrameLevel() + levelOffset)
    end
    SetBackdropStyle(frame, bgColor, borderColor)
    return frame
end

local function CreateLabel(parent, template, text, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    if text then fs:SetText(text) end
    if r then fs:SetTextColor(r, g, b) end
    return fs
end

local function CreateFlatButton(parent, width, height, text)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    SetBackdropStyle(button, {.07, .07, .07, .72}, COL_BORDER_RED)

    local fs = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -1)
    fs:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 1)
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    if fs.SetWordWrap then
        fs:SetWordWrap(false)
    end
    fs:SetText(text or "")
    fs:SetTextColor(COL_TEXT[1], COL_TEXT[2], COL_TEXT[3])
    button.text = fs

    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(COL_HILITE[1], COL_HILITE[2], COL_HILITE[3], COL_HILITE[4])
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(COL_BORDER_RED[1], COL_BORDER_RED[2], COL_BORDER_RED[3], COL_BORDER_RED[4])
    end)

    return button
end

local function CreateCellButton(parent, width)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, ROW_H)

    local box = CreateFrame("Frame", nil, button, "BackdropTemplate")
    box:SetSize(CHECK_SIZE, CHECK_SIZE)
    box:SetPoint("CENTER")
    SetBackdropStyle(box, {.04, .04, .04, .95}, COL_BORDER)
    button.box = box

    local check = box:CreateTexture(nil, "OVERLAY")
    check:SetTexture(CHECK_TEXTURE)
    check:SetVertexColor(COL_CHECK[1], COL_CHECK[2], COL_CHECK[3])
    check:SetPoint("CENTER")
    check:SetSize(CHECK_SIZE, CHECK_SIZE)
    check:Hide()
    button.check = check

    button:SetScript("OnEnter", function(self)
        self.box:SetBackdropBorderColor(COL_HILITE[1], COL_HILITE[2], COL_HILITE[3], COL_HILITE[4])
    end)
    button:SetScript("OnLeave", function(self)
        self.box:SetBackdropBorderColor(COL_BORDER[1], COL_BORDER[2], COL_BORDER[3], COL_BORDER[4])
    end)

    return button
end

local function CreateInlineCheckbox(parent, text)
    local check = Theme:CreateCheckbox(parent, text)
    check:SetWidth(150)
    check.text = check.label
    check:SetHitRectInsets(0, -(check.text:GetStringWidth() + 8), 0, 0)
    return check
end

local function CycleValue(list, current)
    local index = 1
    for i, value in ipairs(list) do
        if value == current then
            index = i
            break
        end
    end
    index = index + 1
    if index > #list then index = 1 end
    return list[index]
end

local function GetTaskColumnWidth()
    local charList = YQB.GetSortedVisibleChars()
    local charColWidth = GetCharColumnWidth()
    local available = MainFrame:GetWidth() - PAD * 2
    local taskWidth = available - GLOBAL_COL_W - #charList * charColWidth - 12
    if taskWidth < 200 then taskWidth = 200 end
    if taskWidth > 460 then taskWidth = 460 end
    return taskWidth
end

local function GetGlobalX(taskWidth)
    return taskWidth + 8
end

local function GetCharX(taskWidth, index)
    return taskWidth + 8 + GLOBAL_COL_W + (index - 1) * GetCharColumnWidth()
end

local function GetContentWidth(charList)
    local width = GetTaskColumnWidth() + 8 + GLOBAL_COL_W + #charList * GetCharColumnWidth()
    local viewport = MainFrame and (MainFrame:GetWidth() - PAD * 2) or width
    if width < viewport then
        width = viewport
    end
    return width
end

-- ==================== 主窗口 ====================
EnsureCharDB(curCharKey)
local initialUIDB = EnsureUIConfig()

MainFrame = CreateFrame("Frame", "YQB_MainFrame", UIParent, "BackdropTemplate")
MainFrame:SetSize(initialUIDB.windowWidth or DEFAULT_W, initialUIDB.windowHeight or DEFAULT_H)
MainFrame:SetPoint("CENTER", UIParent, "CENTER")
MainFrame:SetFrameStrata("DIALOG")
MainFrame:EnableMouse(true)
MainFrame:SetMovable(true)
MainFrame:SetResizable(true)
MainFrame:SetClampedToScreen(true)
SetBackdropStyle(MainFrame, COL_BG, COL_BORDER_RED, 1)
MainFrame:Hide()

local TitleBar = CreateBackdropFrame(MainFrame, {.12, .02, .04, .92}, COL_BORDER_RED, 2)
TitleBar:EnableMouse(true)
TitleBar:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
        MainFrame:StartMoving()
    end
end)
TitleBar:SetScript("OnMouseUp", function()
    MainFrame:StopMovingOrSizing()
end)

local TitleIcon = TitleBar:CreateTexture(nil, "ARTWORK")
TitleIcon:SetTexture(ICON_PATH)
TitleIcon:SetSize(22, 22)

local TitleText = CreateLabel(TitleBar, "GameFontNormalLarge", "YiboQuestBlocker", COL_TITLE[1], COL_TITLE[2], COL_TITLE[3])
local SubtitleText = CreateLabel(TitleBar, "GameFontHighlightSmall", "任务拒绝管理", .9, .25, .28)
local VersionText = CreateLabel(TitleBar, "GameFontHighlightSmall", "v" .. tostring(ADDON_VERSION), COL_SUBTEXT[1], COL_SUBTEXT[2], COL_SUBTEXT[3])

local CloseBtn = CreateFlatButton(TitleBar, 18, 18, "X")
CloseBtn.text:SetTextColor(.95, .95, .95)
CloseBtn:SetScript("OnClick", function()
    ClearInputFocus()
    MainFrame:Hide()
    EnsureCharDB(curCharKey).windowShown = false
end)

local ResizeGrip = CreateFrame("Button", nil, MainFrame)
ResizeGrip:SetSize(16, 16)
ResizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
ResizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
ResizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
ResizeGrip:SetScript("OnMouseDown", function()
    MainFrame:StartSizing("BOTTOMRIGHT")
end)
ResizeGrip:SetScript("OnMouseUp", function()
    MainFrame:StopMovingOrSizing()
    ApplyLayout()
    RefreshUI()
end)

-- ==================== 过滤区 ====================
local FilterPanel = CreateBackdropFrame(MainFrame, COL_PANEL, COL_BORDER, 1)
local FilterLine1 = CreateLine(FilterPanel)
local FilterLine2 = CreateLine(FilterPanel)

local chkDaily = CreateInlineCheckbox(FilterPanel, "日常")
local chkNormal = CreateInlineCheckbox(FilterPanel, "普通")
local chkHide = CreateInlineCheckbox(FilterPanel, "隐藏完成")
local chkReport = CreateInlineCheckbox(FilterPanel, "输出报告")
local chkAutoAbandon = CreateInlineCheckbox(FilterPanel, "自动放弃")

chkDaily:SetChecked(YQBDB.filters.showDaily)
chkNormal:SetChecked(YQBDB.filters.showNormal)
chkHide:SetChecked(YQBDB.filters.hideComplete)
chkReport:SetChecked(YQBDB.filters.reportChat)
chkAutoAbandon:SetChecked(YQBDB.filters.autoAbandon)

local LevelLabel = CreateLabel(FilterPanel, "GameFontHighlightSmall", "等级", COL_TITLE[1], COL_TITLE[2], COL_TITLE[3])
local LevelExprBox = CreateBackdropFrame(FilterPanel, {.04, .04, .04, .92}, COL_BORDER, 1)
LevelExprBox:SetSize(186, 20)

local EditLevelExpr = CreateFrame("EditBox", nil, LevelExprBox)
EditLevelExpr:SetAutoFocus(false)
EditLevelExpr:SetFontObject(GameFontHighlightSmall)
EditLevelExpr:SetTextInsets(6, 6, 0, 0)
EditLevelExpr:SetPoint("TOPLEFT", LevelExprBox, "TOPLEFT", 1, -1)
EditLevelExpr:SetPoint("BOTTOMRIGHT", LevelExprBox, "BOTTOMRIGHT", -1, 1)
EditLevelExpr:SetText(tostring(YQBDB.filters.levelExpr or ""))
EditLevelExpr:SetJustifyH("LEFT")

local LevelHelpBtn = CreateFlatButton(FilterPanel, 20, 20, "?")

local SortLabel = CreateLabel(FilterPanel, "GameFontHighlightSmall", "排序", COL_TITLE[1], COL_TITLE[2], COL_TITLE[3])
local SortBtn = CreateFlatButton(FilterPanel, 92, 20, SORT_NAMES[YQBDB.filters.sortBy] or "自定义")
local SortEditBtn = CreateFlatButton(FilterPanel, 46, 20, "调整")

-- ==================== 列头与滚动区域 ====================
local HeaderFrame = CreateBackdropFrame(MainFrame, {.1, .1, .1, .82}, COL_BORDER, 2)
local headerTask = CreateLabel(HeaderFrame, "GameFontHighlightSmall", "任务", COL_TEXT[1], COL_TEXT[2], COL_TEXT[3])
local headerGlobal = CreateLabel(HeaderFrame, "GameFontHighlightSmall", "全局", COL_TEXT[1], COL_TEXT[2], COL_TEXT[3])
local headerChars = {}

local ScrollFrame = Theme:CreateScrollFrame(MainFrame)
ScrollFrame:BindScrollbarGutter(HeaderFrame)
local ScrollChild = CreateFrame("Frame", nil, ScrollFrame)
ScrollFrame:SetScrollChild(ScrollChild)
ScrollChild:SetWidth(1)
local ScrollBar = ScrollFrame.ScrollBar

-- ==================== 底部区域 ====================
local BottomFrame = CreateBackdropFrame(MainFrame, COL_PANEL, COL_BORDER, 1)
local BottomLine = CreateLine(BottomFrame)

local ManualLabel = CreateLabel(BottomFrame, "GameFontHighlightSmall", "任务ID", COL_TITLE[1], COL_TITLE[2], COL_TITLE[3])
local EditManual = CreateFrame("EditBox", nil, BottomFrame, "InputBoxTemplate")
EditManual:SetAutoFocus(false)
EditManual:SetSize(96, 18)

local radioChar = CreateInlineCheckbox(BottomFrame, "当前角色")
local radioGlobal = CreateInlineCheckbox(BottomFrame, "全局")
radioChar:SetChecked(true)
radioGlobal:SetChecked(false)
local addScope = "char"

local AddBtn = CreateFlatButton(BottomFrame, 62, 20, "添加")
local RefreshBtn = CreateFlatButton(BottomFrame, 92, 20, "放弃已拒绝")
local StatusText = CreateLabel(BottomFrame, "GameFontHighlightSmall", "", COL_SUBTEXT[1], COL_SUBTEXT[2], COL_SUBTEXT[3])
local refreshPending = false
local refreshBtnCountdownActive = false

local function HasRejectedQuestInLog()
    if YQB and YQB.HasRejectedQuestInLog then
        return YQB.HasRejectedQuestInLog()
    end
    local numEntries = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
    for idx = 1, numEntries do
        local _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(idx)
        if not isHeader and questID and YQB.IsQuestBlocked and YQB.IsQuestBlocked(questID) then
            return true
        end
    end
    return false
end

SetRefreshPending = function(pending)
    refreshPending = pending and true or false

    if refreshPending then
        RefreshBtn:Enable()
        RefreshBtn:SetBackdropColor(.12, .08, .02, .88)
        RefreshBtn:SetBackdropBorderColor(COL_TITLE[1], COL_TITLE[2], COL_TITLE[3], .95)
        RefreshBtn.text:SetTextColor(COL_TITLE[1], COL_TITLE[2], COL_TITLE[3])
    else
        RefreshBtn:Disable()
        RefreshBtn:SetBackdropColor(.04, .04, .04, .5)
        RefreshBtn:SetBackdropBorderColor(COL_BORDER[1], COL_BORDER[2], COL_BORDER[3], .8)
        RefreshBtn.text:SetTextColor(.45, .45, .45)
    end
end

-- ==================== 排序侧窗 ====================
local OrderEditor = CreateBackdropFrame(MainFrame, {.04, .04, .04, .94}, COL_BORDER_RED, 4)
OrderEditor:SetSize(232, 240)
OrderEditor:SetFrameStrata("DIALOG")
OrderEditor:Hide()

local OrderEditorTitle = CreateLabel(OrderEditor, "GameFontHighlight", "角色顺序", COL_TITLE[1], COL_TITLE[2], COL_TITLE[3])
local OrderEditorHint = CreateLabel(OrderEditor, "GameFontHighlightSmall", "上下移动自定义排序", COL_SUBTEXT[1], COL_SUBTEXT[2], COL_SUBTEXT[3])
local OrderEditorModeHint = CreateLabel(OrderEditor, "GameFontHighlightSmall", "当前非自定义排序，已隐藏顺序调整。", COL_SUBTEXT[1], COL_SUBTEXT[2], COL_SUBTEXT[3])
local OrderEditorClose = CreateFlatButton(OrderEditor, 18, 18, "X")
local OrderEditorEmpty = CreateLabel(OrderEditor, "GameFontHighlightSmall", "暂无角色数据", COL_SUBTEXT[1], COL_SUBTEXT[2], COL_SUBTEXT[3])
local HeaderCharsLabel = CreateLabel(OrderEditor, "GameFontHighlightSmall", "表头每行字数", COL_SUBTEXT[1], COL_SUBTEXT[2], COL_SUBTEXT[3])
local HeaderCharsValue = CreateLabel(OrderEditor, "GameFontHighlightSmall", "", COL_TITLE[1], COL_TITLE[2], COL_TITLE[3])
local HeaderCharsSlider = CreateFrame("Slider", nil, OrderEditor, "OptionsSliderTemplate")
local orderEditorRows = {}

HeaderCharsSlider:SetMinMaxValues(1, 6)
HeaderCharsSlider:SetValueStep(1)
HeaderCharsSlider:SetObeyStepOnDrag(true)
HeaderCharsSlider:SetOrientation("HORIZONTAL")
HeaderCharsSlider:SetWidth(136)
HeaderCharsSlider.Low:SetText("")
HeaderCharsSlider.High:SetText("")
HeaderCharsSlider.Text:SetText("")

local function ClearOrderEditorRows()
    for _, row in ipairs(orderEditorRows) do
        row:Hide()
    end
    wipe(orderEditorRows)
end

RefreshOrderEditor = function()
    SyncUIBindings()
    if not OrderEditor:IsShown() then return end

    ClearOrderEditorRows()

    OrderEditorTitle:SetPoint("TOPLEFT", OrderEditor, "TOPLEFT", 10, -10)
    OrderEditorHint:SetPoint("TOPLEFT", OrderEditorTitle, "BOTTOMLEFT", 0, -4)
    OrderEditorModeHint:SetPoint("TOPLEFT", OrderEditorHint, "BOTTOMLEFT", 0, -4)
    OrderEditorClose:SetPoint("TOPRIGHT", OrderEditor, "TOPRIGHT", -8, -8)
    HeaderCharsLabel:SetPoint("BOTTOMLEFT", OrderEditor, "BOTTOMLEFT", 12, 34)
    HeaderCharsValue:SetPoint("LEFT", HeaderCharsLabel, "RIGHT", 8, 0)
    HeaderCharsValue:SetText(tostring(EnsureUIConfig().headerCharsPerLine or 3))
    HeaderCharsSlider:SetPoint("BOTTOMLEFT", OrderEditor, "BOTTOMLEFT", 24, 8)
    HeaderCharsSlider:SetValue(EnsureUIConfig().headerCharsPerLine or 3)
    HeaderCharsSlider.Low:ClearAllPoints()
    HeaderCharsSlider.High:ClearAllPoints()
    HeaderCharsSlider.Low:SetPoint("RIGHT", HeaderCharsSlider, "LEFT", -8, 0)
    HeaderCharsSlider.High:SetPoint("LEFT", HeaderCharsSlider, "RIGHT", 8, 0)
    HeaderCharsSlider.Low:SetTextColor(COL_SUBTEXT[1], COL_SUBTEXT[2], COL_SUBTEXT[3])
    HeaderCharsSlider.High:SetTextColor(COL_SUBTEXT[1], COL_SUBTEXT[2], COL_SUBTEXT[3])
    HeaderCharsSlider.Low:SetText("1")
    HeaderCharsSlider.High:SetText("6")

    local allowCustomOrderEdit = (YQBDB.filters.sortBy == "custom" or YQBDB.filters.sortBy == "order")
    OrderEditorHint:SetShown(allowCustomOrderEdit)
    OrderEditorModeHint:SetShown(not allowCustomOrderEdit)

    if not allowCustomOrderEdit then
        OrderEditorEmpty:SetShown(false)
        OrderEditor:SetHeight(132)
        return
    end

    local y = -52
    local order = {}
    if YQB.GetCustomCharOrder then
        for _, charKey in ipairs(YQB.GetCustomCharOrder() or {}) do
            order[#order + 1] = charKey
        end
    end

    local existing = {}
    for _, charKey in ipairs(order) do
        existing[charKey] = true
    end
    if YQB.GetSortedVisibleChars then
        for _, charKey in ipairs(YQB.GetSortedVisibleChars() or {}) do
            if not existing[charKey] then
                order[#order + 1] = charKey
                existing[charKey] = true
            end
        end
    end

    OrderEditorEmpty:ClearAllPoints()
    OrderEditorEmpty:SetPoint("TOPLEFT", OrderEditor, "TOPLEFT", 12, -58)
    OrderEditorEmpty:SetShown(#order == 0)

    local height = 116 + math.max(#order, 1) * 26

    for index, charKey in ipairs(order) do
        local row = CreateFrame("Frame", nil, OrderEditor, "BackdropTemplate")
        row:SetSize(208, 22)
        row:SetPoint("TOPLEFT", OrderEditor, "TOPLEFT", 10, y)
        row:SetFrameStrata(OrderEditor:GetFrameStrata())
        row:SetFrameLevel(OrderEditor:GetFrameLevel() + 1)
        SetBackdropStyle(row, COL_ROW, COL_BORDER)
        row:Show()

        local r, g, b = COL_TEXT[1], COL_TEXT[2], COL_TEXT[3]
        local class = YQBDB.knownChars[charKey] and YQBDB.knownChars[charKey].class
        if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
            r = RAID_CLASS_COLORS[class].r
            g = RAID_CLASS_COLORS[class].g
            b = RAID_CLASS_COLORS[class].b
        end

        local indexText = CreateLabel(row, "GameFontHighlightSmall", index .. ".", COL_SUBTEXT[1], COL_SUBTEXT[2], COL_SUBTEXT[3])
        indexText:SetPoint("LEFT", row, "LEFT", 6, 0)

        local nameText = CreateLabel(row, "GameFontHighlightSmall", ShortName(charKey), r, g, b)
        nameText:SetPoint("LEFT", row, "LEFT", 22, 0)
        nameText:SetWidth(122)
        nameText:SetJustifyH("LEFT")

        local upBtn = CreateFlatButton(row, 24, 18, "↑")
        upBtn:SetPoint("RIGHT", row, "RIGHT", -32, 0)
        upBtn:SetScript("OnClick", function()
            if YQB.MoveCustomCharOrder(charKey, -1) then
                RefreshUI()
            end
        end)
        if index == 1 then
            upBtn:Disable()
            upBtn.text:SetTextColor(.4, .4, .4)
        end

        local downBtn = CreateFlatButton(row, 24, 18, "↓")
        downBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        downBtn:SetScript("OnClick", function()
            if YQB.MoveCustomCharOrder(charKey, 1) then
                RefreshUI()
            end
        end)
        if index == #order then
            downBtn:Disable()
            downBtn.text:SetTextColor(.4, .4, .4)
        end

        orderEditorRows[#orderEditorRows + 1] = row
        y = y - 26
    end

    OrderEditor:SetHeight(math.max(132, math.min(height, 400)))
end

-- ==================== 动态内容 ====================
local dynamicWidgets = {}

local function TrackWidget(widget)
    dynamicWidgets[#dynamicWidgets + 1] = widget
    return widget
end

local function ClearDynamicWidgets()
    for _, widget in ipairs(dynamicWidgets) do
        widget:Hide()
    end
    wipe(dynamicWidgets)
end

local function ClearHeaderChars()
    for _, font in ipairs(headerChars) do
        font:Hide()
    end
    wipe(headerChars)
end

local function UpdateCheckTexture(button, checked)
    if checked then
        button.check:Show()
    else
        button.check:Hide()
    end
end

ClearInputFocus = function()
    EditLevelExpr:ClearFocus()
    EditManual:ClearFocus()
end

local function CreateRow(parent, width, taskWidth, charList, item, blockStatus, isCurrentTask)
    local row = TrackWidget(CreateFrame("Frame", nil, parent, "BackdropTemplate"))
    row:SetSize(width, ROW_H)
    SetBackdropStyle(row, COL_ROW, COL_BORDER)
    row:EnableMouse(true)

    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(COL_ROW_HOVER[1], COL_ROW_HOVER[2], COL_ROW_HOVER[3], COL_ROW_HOVER[4])
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(item.name, 1, 1, 1)
        GameTooltip:AddLine("ID: " .. item.id, .65, .85, 1)
        GameTooltip:AddLine("单击发送到聊天", .6, .6, .6)
        if isCurrentTask then
            GameTooltip:AddLine("当前任务：可加入拒绝，手动放弃后同步列表", .95, .82, .25)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropColor(COL_ROW[1], COL_ROW[2], COL_ROW[3], COL_ROW[4])
        GameTooltip:Hide()
    end)
    row:SetScript("OnMouseUp", function(_, btn)
        ClearInputFocus()
        if btn == "LeftButton" then
            DEFAULT_CHAT_FRAME:AddMessage(YQB.PREFIX .. " " .. item.name .. " (ID: " .. item.id .. ")")
        end
    end)

    local nameFont = CreateLabel(row, "GameFontHighlightSmall", nil, COL_TEXT[1], COL_TEXT[2], COL_TEXT[3])
    nameFont:SetPoint("LEFT", row, "LEFT", 8, 0)
    nameFont:SetWidth(taskWidth - 12)
    nameFont:SetJustifyH("LEFT")
    nameFont:SetText("[" .. item.id .. "] " .. item.name)

    local cellGlobal = CreateCellButton(row, GLOBAL_COL_W)
    cellGlobal:SetPoint("LEFT", row, "LEFT", GetGlobalX(taskWidth), 0)
    UpdateCheckTexture(cellGlobal, blockStatus.global)
    cellGlobal:SetScript("OnClick", function()
        ClearInputFocus()
        local newState = not blockStatus.global
        blockStatus.global = newState
        UpdateCheckTexture(cellGlobal, newState)

        if newState then
            YQB.AddBlock(item.id, "global")
        else
            YQB.RemoveBlock(item.id, "global")
        end
        if isCurrentTask then
            SetRefreshPending(true)
        end
        RefreshUI()
    end)

    for index, charKey in ipairs(charList) do
        local cell = CreateCellButton(row, GetCharColumnWidth())
        cell:SetPoint("LEFT", row, "LEFT", GetCharX(taskWidth, index), 0)
        UpdateCheckTexture(cell, blockStatus[charKey] or false)

        cell:SetScript("OnClick", function()
            ClearInputFocus()
            local newState = not (blockStatus[charKey] or false)
            blockStatus[charKey] = newState
            UpdateCheckTexture(cell, newState)

            if newState then
                YQB.AddCharBlock(item.id, charKey)
            else
                YQB.RemoveCharBlock(item.id, charKey)
            end
            if isCurrentTask then
                SetRefreshPending(true)
            end
            RefreshUI()
        end)
    end

    return row
end

local function CreateGroupHeader(parent, width, text, expanded, accentColor, onClick)
    local header = TrackWidget(CreateFrame("Button", nil, parent, "BackdropTemplate"))
    header:SetSize(width, GROUP_H)
    SetBackdropStyle(header, accentColor, COL_BORDER_RED)

    local arrow = CreateLabel(header, "GameFontHighlightSmall", expanded and "▼" or "▲", COL_TITLE[1], COL_TITLE[2], COL_TITLE[3])
    arrow:SetPoint("LEFT", header, "LEFT", 6, 0)

    local label = CreateLabel(header, "GameFontHighlight", text, COL_TEXT[1], COL_TEXT[2], COL_TEXT[3])
    label:SetPoint("LEFT", header, "LEFT", 22, 0)

    header:SetScript("OnClick", function()
        ClearInputFocus()
        onClick()
    end)
    header:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(COL_HILITE[1], COL_HILITE[2], COL_HILITE[3], COL_HILITE[4])
    end)
    header:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(COL_BORDER_RED[1], COL_BORDER_RED[2], COL_BORDER_RED[3], COL_BORDER_RED[4])
    end)

    return header
end

function UpdateStats()
    local g, c, t = YQB.GetStats()
    StatusText:SetText("全局: " .. g .. " | 当前角色: " .. c .. " | 总计: " .. t)
end

function RebuildContent()
    ClearDynamicWidgets()
    ClearHeaderChars()

    local charDB = EnsureCharDB(curCharKey)
    local charList = YQB.GetSortedVisibleChars()
    local taskWidth = GetTaskColumnWidth()
    local contentWidth = GetContentWidth(charList)
    local yOffset = -4

    ScrollChild:SetWidth(contentWidth)
    headerTask:SetPoint("LEFT", HeaderFrame, "LEFT", 8, 0)
    headerTask:SetWidth(taskWidth - 12)

    headerGlobal:SetWidth(GLOBAL_COL_W)
    headerGlobal:SetPoint("LEFT", HeaderFrame, "LEFT", GetGlobalX(taskWidth), 0)

    for index, charKey in ipairs(charList) do
        local r, g, b = COL_TEXT[1], COL_TEXT[2], COL_TEXT[3]
        local class = YQBDB.knownChars[charKey] and YQBDB.knownChars[charKey].class
        if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
            r = RAID_CLASS_COLORS[class].r
            g = RAID_CLASS_COLORS[class].g
            b = RAID_CLASS_COLORS[class].b
        end
        local font = CreateLabel(HeaderFrame, "GameFontHighlightSmall", GetHeaderCharText(charKey), r, g, b)
        font:SetWidth(GetCharColumnWidth())
        font:SetHeight(GetHeaderHeight() - 4)
        font:SetJustifyH("CENTER")
        font:SetJustifyV("MIDDLE")
        font:SetPoint("LEFT", HeaderFrame, "LEFT", GetCharX(taskWidth, index), 0)
        headerChars[#headerChars + 1] = font
    end

    local blockedList = YQB.GetBlockedQuestList()
    local blockedExpanded = not charDB._foldedBlocked
    local blockedHeader = CreateGroupHeader(
        ScrollChild,
        contentWidth,
        "拒绝组 (" .. #blockedList .. " 个)",
        blockedExpanded,
        COL_GROUP,
        function()
            charDB._foldedBlocked = not charDB._foldedBlocked
            RefreshUI()
        end
    )
    blockedHeader:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - GROUP_H

    if blockedExpanded then
        for _, item in ipairs(blockedList) do
            local status = YQB.GetBlockStatus(item.id)
            local row = CreateRow(ScrollChild, contentWidth, taskWidth, charList, item, status, false)
            row:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 0, yOffset)
            yOffset = yOffset - ROW_H
        end
        yOffset = yOffset - 4
    end

    local currentList = YQB.GetCurrentQuestList()
    local visibleCurrentCount = 0
    for _, item in ipairs(currentList) do
        if not YQB.IsQuestBlockedByAny(item.id) then
            visibleCurrentCount = visibleCurrentCount + 1
        end
    end
    local totalCurrentCount = YQB.GetCurrentQuestTotalCount and YQB.GetCurrentQuestTotalCount() or visibleCurrentCount
    local currentExpanded = not charDB._foldedCurrent
    local currentHeader = CreateGroupHeader(
        ScrollChild,
        contentWidth,
        "当前任务列表 (" .. ShortName(curCharKey) .. ") - " .. visibleCurrentCount .. "/" .. totalCurrentCount,
        currentExpanded,
        COL_GROUP_ALT,
        function()
            charDB._foldedCurrent = not charDB._foldedCurrent
            RefreshUI()
        end
    )
    currentHeader:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 0, yOffset)
    yOffset = yOffset - GROUP_H

    if currentExpanded then
        for _, item in ipairs(currentList) do
            if not YQB.IsQuestBlockedByAny(item.id) then
                local status = { global = false }
                for _, charKey in ipairs(charList) do
                    status[charKey] = false
                end
                local row = CreateRow(ScrollChild, contentWidth, taskWidth, charList, item, status, true)
                row:SetPoint("TOPLEFT", ScrollChild, "TOPLEFT", 0, yOffset)
                yOffset = yOffset - ROW_H
            end
        end
        yOffset = yOffset - 4
    end

    ScrollChild:SetHeight(math.max(math.abs(yOffset) + 10, 50))
    UpdateStats()
end

-- ==================== 布局 ====================
function ApplyLayout()
    if ClampSize(MainFrame) then return end

    TitleBar:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", PAD, -PAD)
    TitleBar:SetPoint("TOPRIGHT", MainFrame, "TOPRIGHT", -PAD, -PAD)
    TitleBar:SetHeight(TITLE_H)

    TitleIcon:SetPoint("LEFT", TitleBar, "LEFT", 8, 0)
    TitleText:SetPoint("LEFT", TitleIcon, "RIGHT", 8, 1)
    SubtitleText:SetPoint("LEFT", TitleText, "RIGHT", 8, 0)
    VersionText:SetPoint("LEFT", SubtitleText, "RIGHT", 10, 0)
    CloseBtn:SetPoint("RIGHT", TitleBar, "RIGHT", -6, 0)

    FilterPanel:SetPoint("TOPLEFT", TitleBar, "BOTTOMLEFT", 0, -6)
    FilterPanel:SetPoint("TOPRIGHT", TitleBar, "BOTTOMRIGHT", 0, -6)
    FilterPanel:SetHeight(FILTER_AREA_H)

    FilterLine1:SetPoint("TOPLEFT", FilterPanel, "TOPLEFT", 8, -FILTER_ROW_H - 3)
    FilterLine1:SetPoint("TOPRIGHT", FilterPanel, "TOPRIGHT", -8, -FILTER_ROW_H - 3)
    FilterLine1:SetHeight(1)

    FilterLine2:SetPoint("BOTTOMLEFT", FilterPanel, "BOTTOMLEFT", 8, 22)
    FilterLine2:SetPoint("BOTTOMRIGHT", FilterPanel, "BOTTOMRIGHT", -8, 22)
    FilterLine2:SetHeight(1)

    chkDaily:SetPoint("TOPLEFT", FilterPanel, "TOPLEFT", 8, -3)
    chkNormal:SetPoint("LEFT", chkDaily.text, "RIGHT", 18, 0)
    chkHide:SetPoint("LEFT", chkNormal.text, "RIGHT", 18, 0)
    chkReport:SetPoint("LEFT", chkHide.text, "RIGHT", 18, 0)
    chkAutoAbandon:SetPoint("LEFT", chkReport.text, "RIGHT", 18, 0)

    LevelLabel:SetPoint("BOTTOMLEFT", FilterPanel, "BOTTOMLEFT", 8, 7)
    LevelExprBox:SetPoint("LEFT", LevelLabel, "RIGHT", 6, 0)
    LevelHelpBtn:SetPoint("LEFT", LevelExprBox, "RIGHT", 6, 0)

    SortBtn:SetPoint("RIGHT", FilterPanel, "RIGHT", -8, 0)
    SortBtn:SetPoint("BOTTOM", FilterPanel, "BOTTOM", 0, 7)
    SortEditBtn:SetPoint("RIGHT", SortBtn, "LEFT", -8, 0)
    SortLabel:SetPoint("RIGHT", SortEditBtn, "LEFT", -8, 0)

    OrderEditor:ClearAllPoints()
    OrderEditor:SetPoint("TOPLEFT", MainFrame, "TOPRIGHT", 8, -PAD)

    HeaderFrame:SetPoint("TOPLEFT", FilterPanel, "BOTTOMLEFT", 0, -6)
    HeaderFrame:SetPoint("TOPRIGHT", FilterPanel, "BOTTOMRIGHT", 0, -6)
    HeaderFrame:SetHeight(GetHeaderHeight())

    BottomFrame:SetPoint("BOTTOMLEFT", MainFrame, "BOTTOMLEFT", PAD, PAD)
    BottomFrame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -PAD, PAD)
    BottomFrame:SetHeight(BOTTOM_H)

    BottomLine:SetPoint("TOPLEFT", BottomFrame, "TOPLEFT", 8, -24)
    BottomLine:SetPoint("TOPRIGHT", BottomFrame, "TOPRIGHT", -8, -24)
    BottomLine:SetHeight(1)

    ManualLabel:SetPoint("TOPLEFT", BottomFrame, "TOPLEFT", 8, -8)
    EditManual:SetPoint("LEFT", ManualLabel, "RIGHT", 6, 0)
    radioChar:SetPoint("LEFT", EditManual, "RIGHT", 10, 0)
    radioGlobal:SetPoint("LEFT", radioChar.text, "RIGHT", 14, 0)
    AddBtn:SetPoint("LEFT", radioGlobal.text, "RIGHT", 10, 0)
    RefreshBtn:SetPoint("BOTTOMRIGHT", BottomFrame, "BOTTOMRIGHT", -8, 7)
    StatusText:SetPoint("BOTTOMLEFT", BottomFrame, "BOTTOMLEFT", 8, 6)

    ScrollFrame:SetPoint("TOPLEFT", HeaderFrame, "BOTTOMLEFT", 0, -4)
    ScrollFrame:SetPoint("BOTTOMRIGHT", BottomFrame, "TOPRIGHT", 0, 6)

    ResizeGrip:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -2, 2)
end

-- ==================== 交互 ====================
chkDaily:SetScript("OnClick", function(self)
    self:SetChecked(not self:GetChecked())
    ClearInputFocus()
    YQBDB.filters.showDaily = self:GetChecked()
    RefreshUI()
end)

chkNormal:SetScript("OnClick", function(self)
    self:SetChecked(not self:GetChecked())
    ClearInputFocus()
    YQBDB.filters.showNormal = self:GetChecked()
    RefreshUI()
end)

chkHide:SetScript("OnClick", function(self)
    self:SetChecked(not self:GetChecked())
    ClearInputFocus()
    YQBDB.filters.hideComplete = self:GetChecked()
    PersistNow()
    RefreshUI()
end)

chkReport:SetScript("OnClick", function(self)
    self:SetChecked(not self:GetChecked())
    ClearInputFocus()
    YQBDB.filters.reportChat = self:GetChecked()
    RefreshUI()
    PersistNow()
end)

chkAutoAbandon:SetScript("OnClick", function(self)
    self:SetChecked(not self:GetChecked())
    ClearInputFocus()
    YQBDB.filters.autoAbandon = self:GetChecked()
    if self:GetChecked() and YQB and YQB.SyncRejectedQuestsToQueue then
        YQB.SyncRejectedQuestsToQueue(true)
    elseif not self:GetChecked() and YQB and YQB.CancelAutoAbandonTimer then
        YQB.CancelAutoAbandonTimer()
    end
    PersistNow()
    RefreshUI()
end)

local function UpdateLevelExprVisual(valid, badToken)
    if valid then
        LevelExprBox:SetBackdropBorderColor(COL_BORDER[1], COL_BORDER[2], COL_BORDER[3], COL_BORDER[4])
        EditLevelExpr:SetTextColor(COL_TEXT[1], COL_TEXT[2], COL_TEXT[3])
    else
        LevelExprBox:SetBackdropBorderColor(COL_BORDER_RED[1], COL_BORDER_RED[2], COL_BORDER_RED[3], COL_BORDER_RED[4])
        EditLevelExpr:SetTextColor(1, .55, .55)
        if badToken and badToken ~= "" then
            YQB.ReportMessage("等级过滤格式无效: " .. badToken, true)
        end
    end
end

local function CommitLevelExpr(refresh)
    local valid, normalized, badToken = YQB.ValidateLevelExpr(EditLevelExpr:GetText())
    EditLevelExpr:SetText(normalized)
    UpdateLevelExprVisual(valid, badToken)
    if valid then
        YQBDB.filters.levelExpr = normalized
        PersistNow()
        if refresh then
            RefreshUI()
        end
    end
    return valid
end

EditLevelExpr:SetScript("OnEnterPressed", function(self)
    CommitLevelExpr(true)
    self:ClearFocus()
end)
EditLevelExpr:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
EditLevelExpr:SetScript("OnEditFocusLost", function()
    CommitLevelExpr(true)
end)
EditLevelExpr:SetScript("OnEscapePressed", function(self)
    self:SetText(tostring(YQBDB.filters.levelExpr or ""))
    UpdateLevelExprVisual(true)
    self:ClearFocus()
end)
EditLevelExpr:SetScript("OnTextChanged", function(self)
    return
end)

LevelHelpBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("等级过滤说明", 1, .82, .2)
    GameTooltip:AddLine("支持多个条件，分隔符只能使用英文逗号。", .9, .9, .9, true)
    GameTooltip:AddLine("可用格式: 90  1-20  <=3  >=85", .7, .85, 1, true)
    GameTooltip:AddLine("示例: <=3,89,90", .7, 1, .7, true)
    GameTooltip:AddLine("输入 0 或留空表示不过滤等级。", 1, .82, .25, true)
    GameTooltip:AddLine("输入后按回车或移开焦点即可生效。", 1, .82, .25, true)
    GameTooltip:Show()
end)
LevelHelpBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

SortBtn:SetScript("OnClick", function(self)
    ClearInputFocus()
    YQBDB.filters.sortBy = CycleValue(SORT_KEYS, YQBDB.filters.sortBy)
    self.text:SetText(SORT_NAMES[YQBDB.filters.sortBy] or YQBDB.filters.sortBy)
    if YQBDB.filters.sortBy ~= "custom" and YQBDB.filters.sortBy ~= "order" then
        OrderEditor:Hide()
    end
    RefreshUI()
end)

SortEditBtn:SetScript("OnClick", function()
    ClearInputFocus()
    if OrderEditor:IsShown() then
        OrderEditor:Hide()
    else
        OrderEditor:Show()
        RefreshOrderEditor()
    end
end)

OrderEditorClose:SetScript("OnClick", function()
    OrderEditor:Hide()
end)

HeaderCharsSlider:SetScript("OnValueChanged", function(self, value)
    local rounded = math.floor((value or 1) + 0.5)
    local uiDB = EnsureUIConfig()
    if uiDB.headerCharsPerLine ~= rounded then
        uiDB.headerCharsPerLine = rounded
        PersistNow()
        HeaderCharsValue:SetText(tostring(rounded))
        ApplyLayout()
        RefreshUI()
    else
        HeaderCharsValue:SetText(tostring(rounded))
    end
end)

radioChar:SetScript("OnClick", function(self)
    self:SetChecked(not self:GetChecked())
    ClearInputFocus()
    if self:GetChecked() then
        radioGlobal:SetChecked(false)
        addScope = "char"
    else
        self:SetChecked(true)
    end
end)

radioGlobal:SetScript("OnClick", function(self)
    self:SetChecked(not self:GetChecked())
    ClearInputFocus()
    if self:GetChecked() then
        radioChar:SetChecked(false)
        addScope = "global"
    else
        self:SetChecked(true)
    end
end)

EditManual:SetScript("OnTextChanged", function(self)
    local text = self:GetText()
    if text ~= "" and not tonumber(text) then
        self:SetText(string.match(text, "^%d*"))
    end
end)
EditManual:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
EditManual:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
EditManual:SetScript("OnEnterPressed", function()
    AddBtn:Click()
end)

AddBtn:SetScript("OnClick", function()
    ClearInputFocus()
    local questID = tonumber(EditManual:GetText())
    if not questID then return end

    if addScope == "global" then
        YQB.AddBlock(questID, "global")
    else
        YQB.AddBlock(questID, "char")
    end

    EditManual:SetText("")
    SetRefreshPending(true)
    RefreshUI()
end)

RefreshBtn:SetScript("OnClick", function()
    if not refreshPending then return end
    if refreshBtnCountdownActive then return end
    ClearInputFocus()

    refreshBtnCountdownActive = true
    local originalText = RefreshBtn.text:GetText()
    local count = 3

    local function tick()
        if count <= 0 then
            refreshBtnCountdownActive = false
            RefreshBtn.text:SetText(originalText)

            local abandoned = 0
            if YQB.AbandonRejectedQuestsInLog then
                abandoned = YQB.AbandonRejectedQuestsInLog() or 0
            end
            if QuestLog_Update then
                QuestLog_Update()
            end
            SetRefreshPending(false)
            RefreshUI()
            if abandoned > 0 then
                YQB.ReportMessage("已放弃 " .. abandoned .. " 个已拒绝任务。")
            else
                YQB.ReportMessage("当前任务日志中没有可放弃的已拒绝任务。")
            end
            return
        end
        RefreshBtn.text:SetText("(" .. count .. "s)")
        count = count - 1
        C_Timer.After(1, tick)
    end
    tick()
end)

local UIEventFrame = CreateFrame("Frame")
UIEventFrame:RegisterEvent("QUEST_LOG_UPDATE")
UIEventFrame:SetScript("OnEvent", function()
    if MainFrame and MainFrame:IsShown() then
        RefreshUI()
    end
end)

MainFrame:SetScript("OnSizeChanged", function()
    ApplyLayout()
    local uiDB = EnsureUIConfig()
    uiDB.windowWidth = math.floor(MainFrame:GetWidth() + 0.5)
    uiDB.windowHeight = math.floor(MainFrame:GetHeight() + 0.5)
    PersistNow()
    RefreshUI()
end)
MainFrame:HookScript("OnMouseDown", ClearInputFocus)

-- ==================== 刷新入口 ====================
function RefreshUI()
    SyncUIBindings()
    if not MainFrame:IsShown() then return end
    -- 同步所有 checkbox 状态（确保显示与持久化数据一致）
    chkDaily:SetChecked(YQBDB.filters.showDaily)
    chkNormal:SetChecked(YQBDB.filters.showNormal)
    chkHide:SetChecked(YQBDB.filters.hideComplete)
    chkReport:SetChecked(YQBDB.filters.reportChat)
    chkAutoAbandon:SetChecked(YQBDB.filters.autoAbandon)
    SetRefreshPending(HasRejectedQuestInLog())
    SortBtn.text:SetText(SORT_NAMES[YQBDB.filters.sortBy] or YQBDB.filters.sortBy)
    SortEditBtn:SetShown(true)
    ApplyLayout()
    RebuildContent()
    RefreshOrderEditor()
end

function YQB.ToggleWindow()
    local charDB = EnsureCharDB(curCharKey)
    if EntryAdapter then
        EntryAdapter:ResetHoverState()
    end
    if MainFrame:IsShown() then
        if not charDB.windowShown then
            -- Promote the hover-preview window to a persistent open state.
            charDB.windowShown = true
            ApplyLayout()
            RefreshUI()
            return
        end
        MainFrame:Hide()
        OrderEditor:Hide()
        charDB.windowShown = false
    else
        ApplySavedWindowSize()
        MainFrame:Show()
        charDB.windowShown = true
        ApplyLayout()
        RefreshUI()
    end
end

function YQB.ShowWindow()
    local charDB = EnsureCharDB(curCharKey)
    if MainFrame:IsShown() then
        return
    end

    ApplySavedWindowSize()
    MainFrame:Show()
    charDB.windowShown = true
    ApplyLayout()
    RefreshUI()
end

-- Broker、小地图、悬停预览和其位置均由 YiboCore 创建、保存和注销。

-- ==================== 初始化 ====================
ApplyLayout()
SetRefreshPending(false)
do
    local valid, _, badToken = YQB.ValidateLevelExpr(YQBDB.filters.levelExpr or "")
    UpdateLevelExprVisual(valid, badToken)
end

-- 不再恢复旧独立窗口；账号页面的显示状态由 YiboCore 保存。
