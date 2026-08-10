local YAB = _G.YAB

local ADDON_VERSION = "2.0.0"
local ICON_PATH = "Interface\\AddOns\\YiboAltoBoss\\Media\\YAB_MinimapIcon"
local BACKDROP_BG = "Interface\\ChatFrame\\ChatFrameBackground"
local BORDER_COLOR = { 0.78, 0.58, 0.14, 0.9 }
local PANEL_COLOR = { 0.015, 0.015, 0.02, 0.96 }
local TITLE_BAR_COLOR = { 0.12, 0.1, 0.07, 0.985 }
local TITLE_COLOR = { 1, 0.86, 0.28 }
local TEXT_COLOR = { 0.94, 0.94, 0.95 }
local SUBTEXT_COLOR = { 0.82, 0.82, 0.85 }
local MUTED_HEADER_COLOR = { 0.58, 0.58, 0.62 }
local OK_COLOR = { 0.16, 0.68, 0.24, 0.98 }
local NO_COLOR = { 0.18, 0.18, 0.2, 0.98 }
local READY_COLOR = { 0.28, 0.58, 0.18, 0.98 }
local WAIT_COLOR = { 0.45, 0.28, 0.08, 0.96 }
local OBSERVED_COLOR = { 0.12, 0.28, 0.48, 0.96 }
local CELL_BORDER_COLOR = { 0.5, 0.44, 0.3, 0.2 }
-- 保持 Boss 行在大面积角色格中仍有清楚的横向节奏；不能依赖低透明度叠色。
local CELL_IDLE_ODD_COLOR = { 0.18, 0.18, 0.205, 1 }
local CELL_IDLE_EVEN_COLOR = { 0.055, 0.055, 0.07, 1 }
local CELL_IDLE_COLOR = CELL_IDLE_ODD_COLOR
local CELL_PHASE_COLOR = { 0.1, 0.16, 0.24, 0.9 }
local BUTTON_PRIMARY_BG = { 0.4, 0.08, 0.03, 0.98 }
local BUTTON_PRIMARY_HOVER_BG = { 0.52, 0.12, 0.05, 0.98 }
local BUTTON_PRIMARY_ACTIVE_BG = { 0.62, 0.16, 0.06, 0.98 }
local BUTTON_SECONDARY_BG = { 0.16, 0.16, 0.18, 0.98 }
local BUTTON_SECONDARY_HOVER_BG = { 0.22, 0.22, 0.25, 0.98 }
local BUTTON_SECONDARY_ACTIVE_BG = { 0.28, 0.28, 0.32, 0.98 }
local BUTTON_BORDER_COLOR = { 0.7, 0.5, 0.16, 0.92 }
local BUTTON_TEXT_COLOR = { 0.95, 0.95, 0.95 }
local BUTTON_MUTED_TEXT_COLOR = { 0.74, 0.74, 0.78 }
local CURRENT_CHAR_COLUMN_BG = { 0.76, 0.58, 0.16, 0.2 }
local CURRENT_CHAR_COLUMN_BORDER = { 0.96, 0.8, 0.28, 0.3 }
local CURRENT_CHAR_HEADER_COLOR = { 1, 0.94, 0.5 }
local HEADER_CHARS_PER_LINE = 3
local PHASE_HEADER_CHARS_PER_LINE = 3
local ACTION_COLUMN_WIDTH = 72
local PHASE_SUMMARY_COLUMN_WIDTH = 64
local MIN_FRAME_WIDTH = 500
local MAX_FRAME_WIDTH = 860
local MIN_FRAME_HEIGHT = 250
-- 20 行 Boss（含双行角色表头）可完整显示；超过该规模才使用滚动条。
local MAX_FRAME_HEIGHT = 600
local HOVER_MIN_FRAME_WIDTH = 640
local HOVER_MAX_FRAME_WIDTH = 1180
local HOVER_MIN_FRAME_HEIGHT = 260
local HOVER_MAX_FRAME_HEIGHT = 760
local TITLE_FONT_SIZE = 16
local SECTION_FONT_SIZE = 14
local LABEL_FONT_SIZE = 12
local CELL_FONT_SIZE = 12
local FOOTER_FONT_SIZE = 11
local TITLE_BAR_HEIGHT = 36
local CONTENT_TOP_INSET = 42
local MAIN_GRID_CHROME_HEIGHT = 50
local HOVER_GRID_CHROME_HEIGHT = 58
local HEADER_LINE_HEIGHT = 14
local HEADER_BOTTOM_GAP = 8
local SECTION_GAP = 10
local GRID_BOTTOM_PADDING = 4

local MainFrame
local HoverFrame
local GridFrame
local MainScrollFrame
local HoverBody
local HoverSimpleBody
local EntryAdapter
local MainControls = {}
local HoverControls = {}
local ResizeHandle
local HideTransientHover
local MainChrome
local HoverChrome
local suppressMainFrameResizePersistence = false
local isUserResizingMainFrame = false
local NormalizeViewMode
local pendingMainLayoutRefresh
local RefreshGrid
local UpdatePhaseSummaryCellButton

local function GetMainContentViewportHeight()
    if not MainChrome or not MainChrome.contentPanel then
        return 0
    end
    return math.max((MainChrome.contentPanel:GetHeight() or 0) - 4, 0)
end

local function GetMainScrollBar()
    if not MainScrollFrame then
        return nil
    end
    return MainScrollFrame.ScrollBar or MainScrollFrame.scrollBar
end

local function SetMainScrollReserve(needed)
    if not MainScrollFrame or MainScrollFrame.usesScrollReserve == needed then
        return false
    end
    MainScrollFrame.usesScrollReserve = needed
    MainScrollFrame:ClearAllPoints()
    MainScrollFrame:SetPoint("TOPLEFT", MainChrome.contentPanel, "TOPLEFT", 8, -4)
    MainScrollFrame:SetPoint("BOTTOMRIGHT", MainChrome.contentPanel, "BOTTOMRIGHT", needed and -28 or -8, 0)
    return true
end

local function RefreshMainScrollBounds()
    if not MainScrollFrame or not GridFrame then
        return
    end
    local viewportHeight = GetMainContentViewportHeight()
    local contentHeight = GridFrame.contentHeight or 0
    local maxScroll = math.max(contentHeight - viewportHeight, 0)
    if maxScroll < 3 then
        maxScroll = 0
    end
    if SetMainScrollReserve(maxScroll > 0) then
        if RefreshGrid then
            RefreshGrid(GridFrame, MainFrame and MainFrame.viewMode or "current")
        end
        return
    end
    local current = MainScrollFrame:GetVerticalScroll() or 0
    MainScrollFrame:SetVerticalScroll(math.min(current, maxScroll))
    local scrollBar = GetMainScrollBar()
    if scrollBar then
        scrollBar:SetMinMaxValues(0, maxScroll)
        scrollBar:SetValue(math.min(current, maxScroll))
        scrollBar:SetShown(maxScroll > 0)
    end
end

local function SetBackdrop(frame, bgColor, borderColor)
    frame:SetBackdrop({
        bgFile = BACKDROP_BG,
        edgeFile = BACKDROP_BG,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
end

local function SetBackdropInset(frame, bgColor, borderColor, inset)
    inset = inset or 1
    frame:SetBackdrop({
        bgFile = BACKDROP_BG,
        edgeFile = BACKDROP_BG,
        edgeSize = 1,
        insets = { left = inset, right = inset, top = inset, bottom = inset },
    })
    frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
end

local function SetLabel(fontString, text, color)
    fontString:SetText(text or "")
    color = color or TEXT_COLOR
    fontString:SetTextColor(color[1], color[2], color[3])
end

local function CreateText(parent, size, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local font, _, flags = text:GetFont()
    text:SetFont(font, size or 12, flags)
    text:SetJustifyH(justify or "LEFT")
    text:SetJustifyV("MIDDLE")
    return text
end

local function SetVertexColor(texture, color)
    if texture and color then
        texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    end
end

local function Clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function FormatElapsed(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    if seconds < 60 then
        return seconds .. "秒前"
    end
    if seconds < 3600 then
        return math.floor(seconds / 60) .. "分钟前"
    end
    return math.floor(seconds / 3600) .. "小时前"
end

local function FormatDurationCompact(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local minutes = math.floor(seconds / 60)
    local remainSeconds = seconds % 60
    if minutes >= 60 then
        local hours = math.floor(minutes / 60)
        minutes = minutes % 60
        return string.format("%d时%02d", hours, minutes)
    end
    return string.format("%02d:%02d", minutes, remainSeconds)
end

local function FormatClockTime(timestamp)
    timestamp = tonumber(timestamp)
    if not timestamp or timestamp <= 0 then
        return "?"
    end
    return date("%H:%M:%S", timestamp)
end

local function BuildRespawnSampleLines(viewMode)
    viewMode = NormalizeViewMode(viewMode)
    local lines = {
        "位面观测保留 6 小时；每个位面单独计时，刷新间隔样本按服务器内 Boss 汇总。",
    }
    local predictions = YAB.GetRespawnPredictionEntries and YAB.GetRespawnPredictionEntries(viewMode, 2, false) or {}
    for _, item in ipairs(predictions) do
        local rangeText
        if item.windowMinSeconds and item.windowMaxSeconds and item.windowMaxSeconds > item.windowMinSeconds then
            rangeText = FormatDurationCompact(item.windowMinSeconds) .. "-" .. FormatDurationCompact(item.windowMaxSeconds)
        else
            rangeText = FormatDurationCompact(item.estimateSeconds or item.windowMinSeconds or 0)
        end
        local prefix = item.mode == "fixed" and "固定规律" or "刷新规律"
        local text = prefix .. ": " .. tostring(item.bossName) .. " / " .. rangeText .. " / " .. tostring(item.sampleCount or 0) .. "样本"
        if viewMode ~= "current" and item.realm then
            text = text .. " / " .. tostring(item.realm)
        end
        lines[#lines + 1] = text
    end

    local samples = YAB.GetRecentRespawnSamples and YAB.GetRecentRespawnSamples(viewMode, 3) or {}
    if #predictions == 0 and (not samples or #samples == 0) then
        lines[#lines + 1] = "实测刷新样本: 暂无"
        return lines
    end

    for _, sample in ipairs(samples) do
        local parts = {
            sample.bossName or "?",
            "位面" .. tostring(sample.phaseDisplayId or "00"),
            FormatDurationCompact(sample.elapsedSeconds or 0),
        }
        if viewMode ~= "current" and sample.realm then
            parts[#parts + 1] = tostring(sample.realm)
        end
        lines[#lines + 1] = "实测刷新: " .. table.concat(parts, " / ")
    end
    return lines
end

local function ShortCharacterName(charKey)
    return charKey and charKey:match("^(.-)-") or charKey or "?"
end

local function CompactPhaseText(phaseInfo)
    if not phaseInfo or not phaseInfo.phase or phaseInfo.phase == "" then
        return "?"
    end

    local phaseText = tostring(phaseInfo.phase)
    local phaseNum = phaseText:match("[Pp][Hh][Aa][Ss][Ee]%s*:?(%d+)")
    if not phaseNum then
        phaseNum = phaseText:match("[Pp](%d+)")
    end
    if phaseNum then
        return "P" .. phaseNum
    end
    if phaseText:find("稀有") then
        return "稀有"
    end
    if phaseText:find("场景") then
        return "场景"
    end
    if phaseInfo.observedAt then
        local elapsed = time() - phaseInfo.observedAt
        if elapsed < 3600 then
            return math.max(1, math.floor(elapsed / 60)) .. "分"
        end
        return math.floor(elapsed / 3600) .. "时"
    end
    return "?"
end

local function GetColumnHeaderText(column, showAllServers)
    if not column then
        return "未知"
    end
    local phaseIdText = tostring(column.displayId or "0")
    local viewMode = YAB.NormalizeViewMode and YAB.NormalizeViewMode(showAllServers) or (showAllServers and "all" or "current")
    if viewMode ~= "current" then
        return phaseIdText .. "\n" .. tostring(column.realm or "")
    end
    return phaseIdText
end

NormalizeViewMode = function(viewMode)
    if YAB.NormalizeViewMode then
        return YAB.NormalizeViewMode(viewMode)
    end
    return viewMode and "all" or "current"
end

local function Utf8Sub(str, maxChars)
    if not str or maxChars <= 0 then
        return ""
    end
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

local function Utf8Len(str)
    str = tostring(str or "")
    local length = 0
    local index = 1
    while index <= #str do
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
    return length
end

local function IsTransientGridFrame(frame)
    return frame == HoverBody
end

local function GetDisplayedCharacterLabel(charKey, viewMode)
    if NormalizeViewMode(viewMode) ~= "current" then
        return YAB.GetCharacterLabel(charKey, viewMode)
    end
    return ShortCharacterName(charKey)
end

local function GetPreferredBossColumnWidth(viewMode, isTransient)
    local minWidth = viewMode == "current" and 156 or 132
    local maxWidth = isTransient and 260 or 220
    local longest = 0
    for _, boss in ipairs(YAB.GetBossList()) do
        longest = math.max(longest, Utf8Len(boss.name))
    end
    local estimated = 26 + (longest * 12)
    return Clamp(estimated, minWidth, maxWidth)
end

local function GetPreferredCharacterCellWidth(viewMode, isTransient)
    local labels = YAB.GetCharacterKeys(viewMode)
    local longest = 0
    for _, charKey in ipairs(labels) do
        longest = math.max(longest, Utf8Len(GetDisplayedCharacterLabel(charKey, viewMode)))
    end
    local targetLines = isTransient and 2 or 3
    local minWidth = isTransient and (viewMode == "current" and 58 or 52) or (viewMode == "current" and 52 or 48)
    local maxWidth = isTransient and 92 or 72
    local estimated = 10 + (math.ceil(longest / targetLines) * 12)
    return Clamp(estimated, minWidth, maxWidth)
end

local function GetHeaderCharsPerLineForWidth(width, fallbackChars)
    local usableWidth = math.max(tonumber(width) or 0, 24)
    local approxChars = math.floor((usableWidth - 6) / 10)
    return math.max(fallbackChars or 3, approxChars)
end

local function BreakHeaderText(text, charsPerLine)
    local pieces = {}
    charsPerLine = charsPerLine or HEADER_CHARS_PER_LINE
    for rawLine in string.gmatch(tostring(text or ""), "([^\n]*)\n?") do
        if rawLine == "" and #pieces > 0 then
            break
        end
        local rest = rawLine
        if rest == "" then
            pieces[#pieces + 1] = ""
        end
        while rest ~= "" do
            local chunk = Utf8Sub(rest, charsPerLine)
            if chunk == "" then
                break
            end
            pieces[#pieces + 1] = chunk
            rest = string.sub(rest, #chunk + 1)
        end
    end
    if #pieces == 0 then
        return text or ""
    end
    return table.concat(pieces, "\n")
end

local function BreakPhaseHeaderText(text, charsPerLine)
    return BreakHeaderText(text, charsPerLine or PHASE_HEADER_CHARS_PER_LINE)
end

local function GetPhaseHeaderLineCount(text, charsPerLine)
    charsPerLine = charsPerLine or PHASE_HEADER_CHARS_PER_LINE
    local count = 0
    for rawLine in string.gmatch(tostring(text or ""), "([^\n]*)\n?") do
        if rawLine == "" and count > 0 then
            break
        end
        local rest = rawLine
        if rest == "" then
            count = count + 1
        end
        while rest ~= "" do
            local chunk = Utf8Sub(rest, charsPerLine)
            if chunk == "" then
                break
            end
            count = count + 1
            rest = string.sub(rest, #chunk + 1)
        end
    end
    return math.max(count, 1)
end

local function GetHeaderLineCount(text, charsPerLine)
    charsPerLine = charsPerLine or HEADER_CHARS_PER_LINE
    local count = 0
    for rawLine in string.gmatch(tostring(text or ""), "([^\n]*)\n?") do
        if rawLine == "" and count > 0 then
            break
        end
        local rest = rawLine
        if rest == "" then
            count = count + 1
        end
        while rest ~= "" do
            local chunk = Utf8Sub(rest, charsPerLine)
            if chunk == "" then
                break
            end
            count = count + 1
            rest = string.sub(rest, #chunk + 1)
        end
    end
    return math.max(count, 1)
end

local function SetCellBackdrop(frame, bgColor)
    SetBackdrop(frame, bgColor, CELL_BORDER_COLOR)
end

local function GetRowIdleColor(rowIndex)
    return rowIndex and rowIndex % 2 == 0 and CELL_IDLE_EVEN_COLOR or CELL_IDLE_ODD_COLOR
end

local function AnchorFrameBelow(anchorFrame, frame)
    frame:ClearAllPoints()
    if not (anchorFrame and anchorFrame.GetLeft and anchorFrame.GetRight and anchorFrame.GetTop and anchorFrame.GetBottom) then
        frame:SetPoint("CENTER")
        return
    end

    local left = anchorFrame:GetLeft()
    local right = anchorFrame:GetRight()
    local top = anchorFrame:GetTop()
    local bottom = anchorFrame:GetBottom()
    if not (left and right and top and bottom) then
        frame:SetPoint("CENTER")
        return
    end

    local parent = UIParent
    local parentWidth = parent:GetWidth() or 0
    local parentHeight = parent:GetHeight() or 0
    local popupHeight = (frame:GetHeight() or 0) * (frame.GetEffectiveScale and frame:GetEffectiveScale() or 1) / (parent.GetEffectiveScale and parent:GetEffectiveScale() or 1)
    local margin = 10
    local gap = 4
    local spaceBelow = bottom - margin - gap

    local centerX = anchorFrame.GetCenter and anchorFrame:GetCenter() or ((left + right) * 0.5)
    local attachRight = centerX and centerX > (parentWidth * 0.5)
    local showAbove = spaceBelow < popupHeight

    if showAbove then
        if attachRight then
            frame:SetPoint("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", 0, gap)
        else
            frame:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, gap)
        end
    else
        if attachRight then
            frame:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -gap)
        else
            frame:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -gap)
        end
    end
end

local function RaiseTooltipAboveFrame(ownerFrame)
    local tooltip = GameTooltip
    if not tooltip then
        return
    end
    tooltip:SetToplevel(true)
    tooltip:SetFrameStrata("TOOLTIP")
    local ownerLevel = ownerFrame and ownerFrame.GetFrameLevel and ownerFrame:GetFrameLevel() or 0
    local hoverLevel = HoverFrame and HoverFrame.GetFrameLevel and HoverFrame:GetFrameLevel() or 0
    tooltip:SetFrameLevel(math.max(tooltip:GetFrameLevel() or 0, ownerLevel + 80, hoverLevel + 40))
end

local function ReleaseDynamicWidgets(pool)
    for _, widget in ipairs(pool) do
        widget:Hide()
        widget:ClearAllPoints()
        widget:SetScript("OnUpdate", nil)
        if widget.glow then
            widget.glow:Hide()
        end
    end
    wipe(pool)
end

local function ScheduleMainLayoutRefresh(viewMode)
    pendingMainLayoutRefresh = NormalizeViewMode(viewMode)
    if not C_Timer or not C_Timer.After then
        if MainFrame and MainFrame:IsShown() then
            RefreshGrid(GridFrame, pendingMainLayoutRefresh)
            RefreshMainScrollBounds()
        end
        return
    end
    C_Timer.After(0, function()
        if MainFrame and MainFrame:IsShown() and GridFrame then
            RefreshGrid(GridFrame, pendingMainLayoutRefresh or (MainFrame.viewMode or "current"))
            RefreshMainScrollBounds()
        end
    end)
end

local function CreateCellButton(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetHeight(21)
    SetCellBackdrop(button, CELL_IDLE_COLOR)
    button.glow = button:CreateTexture(nil, "ARTWORK")
    button.glow:SetTexture(BACKDROP_BG)
    button.glow:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.glow:Hide()
    button.text = CreateText(button, CELL_FONT_SIZE, "CENTER")
    button.text:SetPoint("CENTER")
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(self.tooltipTitle or "Boss 击杀")
        if self.tooltipLine then
            GameTooltip:AddLine(self.tooltipLine, 0.85, 0.85, 0.85, true)
        end
        RaiseTooltipAboveFrame(self)
        GameTooltip:Show()
        GameTooltip:Raise()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return button
end

local function SetButtonPulse(button, color, pulse)
    if not button or not button.glow then
        return
    end
    if color then
        button.glow:Show()
        SetVertexColor(button.glow, color)
    else
        button.glow:Hide()
    end
    if pulse then
        button.pulseTime = 0
        button:SetScript("OnUpdate", function(self, elapsed)
            self.pulseTime = (self.pulseTime or 0) + elapsed
            local alpha = 0.16 + (0.14 * (0.5 + 0.5 * math.sin((self.pulseTime or 0) * 2.5)))
            if self.glow then
                self.glow:SetAlpha(alpha)
            end
        end)
    else
        button:SetScript("OnUpdate", nil)
        if button.glow then
            button.glow:SetAlpha(0.12)
        end
    end
end

-- A bad optional detail (action/phase history) must never prevent the boss row
-- itself from rendering.  This is especially important for old saved world-state
-- records, whose shape may predate the P5 data model.
local function TryRenderBossWidget(frame, boss, stage, render)
    local ok, err = pcall(render)
    if not ok then
        frame.renderErrors = frame.renderErrors or {}
        frame.renderErrors[#frame.renderErrors + 1] = tostring(boss and boss.key or "?") .. "/" .. tostring(stage) .. ": " .. tostring(err)
    end
    return ok
end

local function HasPendingRespawnSample(state)
    return state and state.lastKilledAt
end

local function UpdateRefreshCellButton(button, boss, column, width)
    local state = YAB.GetBossPhaseState(boss.key or boss.id, column)
    local now = time()
    button:SetWidth(width)
    local phaseIdText = "位面" .. tostring((state and state.phaseDisplayId) or (column and column.displayId) or "00")
    button.tooltipTitle = boss.name .. " / " .. phaseIdText
    button:SetScript("OnClick", nil)

    if not state then
        button.tooltipLine = "该位面暂无近期记录"
        SetCellBackdrop(button, CELL_IDLE_COLOR)
        SetLabel(button.text, "?", SUBTEXT_COLOR)
        return
    end

    local lines = {}
    lines[#lines + 1] = "服务器: " .. tostring(state.realm or YAB.GetCurrentRealm())
    lines[#lines + 1] = "位面ID: " .. phaseIdText
    lines[#lines + 1] = "位面标识: " .. tostring(state.phaseLabel or column.label or "未知")
    if state.lastKilledAt then
        lines[#lines + 1] = "上次击杀: " .. FormatElapsed(now - state.lastKilledAt)
        lines[#lines + 1] = "击杀计时: 当前位面独立"
    end
    if state.lastKilledBy then
        lines[#lines + 1] = "击杀角色: " .. tostring(state.lastKilledBy)
    end
    if state.observedAt then
        lines[#lines + 1] = "最近观测: " .. FormatElapsed(now - state.observedAt)
    end
    if HasPendingRespawnSample(state) then
        lines[#lines + 1] = "样本状态: 当前仅记录到击杀，需等待下次刷新并再次观测后才会新增"
    end
    if state.lastRespawnSampleSeconds then
        lines[#lines + 1] = "最近实测刷新: " .. FormatDurationCompact(state.lastRespawnSampleSeconds)
    end
    if state.respawnEstimateSeconds and state.respawnEstimateSamples and state.respawnEstimateSamples > 0 then
        local minSeconds = state.respawnEstimateMinSeconds or state.respawnEstimateSeconds
        local maxSeconds = state.respawnEstimateMaxSeconds or state.respawnEstimateSeconds
        local observedMinSeconds = state.respawnEstimateObservedMinSeconds or minSeconds
        local estimateText
        if state.respawnEstimateMode == "fixed" then
            estimateText = "固定刷新估计: " .. FormatDurationCompact(state.respawnEstimateSeconds) .. "（" .. tostring(state.respawnEstimateSamples) .. "样本/" .. tostring(state.respawnEstimateConfidence or "参考") .. "）"
        elseif maxSeconds and minSeconds and maxSeconds > minSeconds then
            estimateText = "刷新区间估计: " .. FormatDurationCompact(minSeconds) .. " - " .. FormatDurationCompact(maxSeconds) .. "（" .. tostring(state.respawnEstimateSamples) .. "样本/" .. tostring(state.respawnEstimateConfidence or "参考") .. "）"
        else
            estimateText = "刷新间隔估计: " .. FormatDurationCompact(state.respawnEstimateSeconds) .. "（" .. tostring(state.respawnEstimateSamples) .. "样本/" .. tostring(state.respawnEstimateConfidence or "参考") .. "）"
        end
        lines[#lines + 1] = estimateText
        if observedMinSeconds then
            lines[#lines + 1] = "最小实测刷新: " .. FormatDurationCompact(observedMinSeconds)
        end
        if state.lastKilledAt and minSeconds and maxSeconds then
            local predictedStartAt = state.lastKilledAt + minSeconds
            local predictedEndAt = state.lastKilledAt + maxSeconds
            if predictedEndAt > predictedStartAt then
                if now < predictedStartAt then
                    lines[#lines + 1] = "预测窗口: " .. FormatClockTime(predictedStartAt) .. " - " .. FormatClockTime(predictedEndAt)
                elseif now <= predictedEndAt then
                    lines[#lines + 1] = "预测窗口: 当前已进入，持续到 " .. FormatClockTime(predictedEndAt)
                else
                    lines[#lines + 1] = "预测窗口: " .. FormatClockTime(predictedStartAt) .. " - " .. FormatClockTime(predictedEndAt) .. "（已过）"
                end
            else
                local predictedAt = predictedStartAt
                local remaining = predictedAt - now
                if remaining > 0 then
                    lines[#lines + 1] = "预测刷新: " .. FormatClockTime(predictedAt) .. "，约 " .. FormatDurationCompact(remaining) .. " 后"
                else
                    lines[#lines + 1] = "预测刷新: " .. FormatClockTime(predictedAt) .. "，已过 " .. FormatDurationCompact(math.abs(remaining))
                end
            end
        end
    end
    if state.zone and state.zone ~= "" then
        lines[#lines + 1] = "区域: " .. tostring(state.zone)
    end
    if state.subZone and state.subZone ~= "" and state.subZone ~= state.zone then
        lines[#lines + 1] = "子区域: " .. tostring(state.subZone)
    end

    if state.lastKilledAt then
        local elapsed = now - state.lastKilledAt
        SetCellBackdrop(button, WAIT_COLOR)
        SetLabel(button.text, FormatDurationCompact(elapsed), { 1, 1, 1 })
        lines[#lines + 1] = "击杀后计时: " .. FormatDurationCompact(elapsed)
    elseif state.observedAt then
        SetCellBackdrop(button, OBSERVED_COLOR)
        SetLabel(button.text, "观测", { 1, 1, 1 })
        lines[#lines + 1] = "当前仅记录位面观测"
    else
        SetCellBackdrop(button, CELL_IDLE_COLOR)
        SetLabel(button.text, "?", SUBTEXT_COLOR)
    end

    button.tooltipLine = table.concat(lines, "\n")
    SetButtonPulse(button, nil, false)
end

local function UpdateObservationCellButton(button, boss, column, width)
    local state = YAB.GetBossPhaseState(boss.key or boss.id, column)
    local now = time()
    button:SetWidth(width)
    local phaseIdText = "位面" .. tostring((state and state.phaseDisplayId) or (column and column.displayId) or "00")
    button.tooltipTitle = boss.name .. " / " .. phaseIdText
    button:SetScript("OnClick", nil)

    if not state or not state.observedAt then
        button.tooltipLine = "该位面暂无 6 小时内观测"
        SetCellBackdrop(button, CELL_IDLE_COLOR)
        SetLabel(button.text, "?", SUBTEXT_COLOR)
        return
    end

    local text = CompactPhaseText({
        phase = state.rawPhase or state.phaseLabel,
        observedAt = state.observedAt,
    })
    local lines = {
        "位面ID: " .. phaseIdText,
        "位面标识: " .. tostring(state.phaseLabel or column.label or "未知"),
        "最近观测: " .. FormatElapsed(now - state.observedAt),
    }
    if state.lastObservedBy then
        lines[#lines + 1] = "观测角色: " .. tostring(state.lastObservedBy)
    end
    if state.zone and state.zone ~= "" then
        lines[#lines + 1] = "区域: " .. tostring(state.zone)
    end
    if state.subZone and state.subZone ~= "" and state.subZone ~= state.zone then
        lines[#lines + 1] = "子区域: " .. tostring(state.subZone)
    end

    button.tooltipLine = table.concat(lines, "\n")
    SetCellBackdrop(button, CELL_PHASE_COLOR)
    SetLabel(button.text, text, { 1, 1, 1 })
    SetButtonPulse(button, nil, false)
end

local function UpdateCellButton(button, charKey, boss, width, rowIndex)
    local targetRef = boss.key or boss.id
    local status, statusInfo, lockoutBoss = YAB.GetBossKillStatus(charKey, targetRef)
    local killed = status == "killed"
    local killInfo = killed and statusInfo or nil
    button:SetWidth(width)
    button.charKey = charKey
    button.bossId = targetRef
    button.tooltipTitle = boss.name
    if killed and killInfo then
        local sourceText = ({
            manual = "手动记录",
            manual_recovery = "手动补记",
            party_kill = "战斗日志(PARTY_KILL)",
            unit_died = "战斗日志(UNIT_DIED)",
            quest_flag = "服务器周常锁定恢复",
            weekly_lockout = "服务器周常锁定恢复",
        })[killInfo.source or "manual"] or tostring(killInfo.source)
        local lines = {
            charKey .. " 已记录击杀",
            "来源: " .. sourceText,
        }
        if killInfo.actualName then
            lines[#lines + 1] = "实际击杀: " .. tostring(killInfo.actualName)
        end
        button.tooltipLine = table.concat(lines, "\n")
    else
        button.tooltipLine = charKey .. " 本周未记录击杀\n点击可手动补录或撤销；若格子不可用，输入 /yab celestial 补记当前角色"
    end
    button:SetScript("OnClick", function()
        YAB.ToggleBossKill(charKey, targetRef)
    end)

    if killed then
        SetCellBackdrop(button, OK_COLOR)
        SetLabel(button.text, "已击杀", { 1, 1, 1 })
    else
        SetCellBackdrop(button, GetRowIdleColor(rowIndex))
        SetLabel(button.text, "未击杀", SUBTEXT_COLOR)
    end
    SetButtonPulse(button, nil, false)
end

local function UpdatePhaseCellButton(button, charKey, target, width)
    local targetRef = target.key or target.id
    local phaseInfo = YAB.GetPhaseInfo(charKey, targetRef)
    local phaseText = CompactPhaseText(phaseInfo)
    button:SetWidth(width)
    button.charKey = charKey
    button.bossId = targetRef
    button.tooltipTitle = target.name
    if phaseInfo then
        local lines = {
            charKey .. " 最近观测标签: " .. tostring(phaseInfo.phase),
        }
        if phaseInfo.source then
            lines[#lines + 1] = "来源: " .. tostring(phaseInfo.source)
        end
        if phaseInfo.zone and phaseInfo.zone ~= "" then
            lines[#lines + 1] = "区域: " .. tostring(phaseInfo.zone)
        end
        if phaseInfo.subZone and phaseInfo.subZone ~= "" and phaseInfo.subZone ~= phaseInfo.zone then
            lines[#lines + 1] = "子区域: " .. tostring(phaseInfo.subZone)
        end
        if phaseInfo.observedAt then
            lines[#lines + 1] = "时间: " .. FormatElapsed(time() - phaseInfo.observedAt)
        end
        button.tooltipLine = table.concat(lines, "\n")
        SetCellBackdrop(button, CELL_PHASE_COLOR)
        SetLabel(button.text, phaseText, { 1, 1, 1 })
    else
        button.tooltipLine = charKey .. " 暂无 6 小时内位面记录"
        SetCellBackdrop(button, CELL_IDLE_COLOR)
        SetLabel(button.text, "?", SUBTEXT_COLOR)
    end
    button:SetScript("OnClick", nil)
    SetButtonPulse(button, nil, false)
end

local function BuildActionCandidate(state, column)
    if not state then
        return nil
    end
    local now = time()
    local candidate = {
        state = state,
        column = column,
        realm = state.realm or (column and column.realm) or YAB.GetCurrentRealm(),
        phaseDisplayId = state.phaseDisplayId or (column and column.displayId) or "00",
        phaseLabel = state.phaseLabel or (column and column.label) or "未知",
        priority = 0,
        orderValue = math.huge,
        text = "-",
        kind = "empty",
        pulse = false,
    }

    if state.lastKilledAt and state.respawnEstimateSeconds and (state.respawnEstimateSamples or 0) > 0 then
        local minSeconds = state.respawnEstimateMinSeconds or state.respawnEstimateSeconds
        local maxSeconds = state.respawnEstimateMaxSeconds or state.respawnEstimateSeconds
        local predictedStartAt = state.lastKilledAt + minSeconds
        local predictedEndAt = state.lastKilledAt + maxSeconds
        if now < predictedStartAt then
            local remaining = predictedStartAt - now
            if remaining <= 10 * 60 then
                candidate.text = FormatDurationCompact(remaining) .. "后"
                candidate.kind = "soon"
                candidate.priority = 6
                candidate.pulse = true
            else
                candidate.text = FormatClockTime(predictedStartAt)
                candidate.kind = "scheduled"
                candidate.priority = 5
            end
            candidate.orderValue = remaining
        elseif now <= predictedEndAt then
            candidate.text = "窗口中"
            candidate.kind = "window"
            candidate.priority = 7
            candidate.orderValue = predictedEndAt - now
            candidate.pulse = true
        else
            candidate.text = "已过"
            candidate.kind = "overdue"
            candidate.priority = 4
            candidate.orderValue = now - predictedEndAt
        end
        return candidate
    end

    if state.lastKilledAt then
        candidate.text = "样本少"
        candidate.kind = "weak"
        candidate.priority = 3
        candidate.orderValue = now - state.lastKilledAt
        return candidate
    end

    if state.observedAt then
        candidate.text = "仅观测"
        candidate.kind = "observed"
        candidate.priority = 2
        candidate.orderValue = now - state.observedAt
        return candidate
    end

    return nil
end

local function PickBestActionCandidate(boss, viewMode)
    local columns = YAB.GetPhaseColumns(viewMode)
    local best
    for _, column in ipairs(columns) do
        local state = YAB.GetBossPhaseState(boss.key or boss.id, column)
        local candidate = BuildActionCandidate(state, column)
        if candidate then
            if not best
                or candidate.priority > best.priority
                or (candidate.priority == best.priority and candidate.orderValue < best.orderValue) then
                best = candidate
            end
        end
    end
    return best
end

local function CollectActionPhaseStates(boss, viewMode)
    local items = {}
    for _, column in ipairs(YAB.GetPhaseColumns(viewMode)) do
        local state = YAB.GetBossPhaseState(boss.key or boss.id, column)
        if state then
            local candidate = BuildActionCandidate(state, column)
            items[#items + 1] = {
                state = state,
                column = column,
                candidate = candidate,
                priority = candidate and candidate.priority or 0,
                sortAt = math.max(
                    tonumber(state.observedAt or 0) or 0,
                    tonumber(state.lastKilledAt or 0) or 0
                ),
            }
        end
    end
    table.sort(items, function(left, right)
        if (left.priority or 0) ~= (right.priority or 0) then
            return (left.priority or 0) > (right.priority or 0)
        end
        return (left.sortAt or 0) > (right.sortAt or 0)
    end)
    return items
end

local function BuildPhaseSummaryText(phaseStates)
    if not phaseStates or #phaseStates == 0 then
        return "-"
    end

    local killCount = 0
    local observeCount = 0
    for _, item in ipairs(phaseStates) do
        if item.state and item.state.lastKilledAt then
            killCount = killCount + 1
        elseif item.state and item.state.observedAt then
            observeCount = observeCount + 1
        end
    end

    if killCount > 0 and observeCount > 0 then
        return tostring(killCount) .. "击/" .. tostring(observeCount) .. "观"
    end
    if killCount > 0 then
        return tostring(killCount) .. "击"
    end
    return tostring(observeCount) .. "观"
end

local function AppendSection(lines, title, sectionLines)
    if not sectionLines or #sectionLines == 0 then
        return
    end
    if #lines > 0 then
        lines[#lines + 1] = " "
    end
    lines[#lines + 1] = title
    for _, line in ipairs(sectionLines) do
        if line and line ~= "" then
            lines[#lines + 1] = line
        end
    end
end

local function GetBossHistoryEntries(boss, viewMode)
    local bossKey = tostring((boss and (boss.key or boss.id)) or "")
    local predictions = YAB.GetRespawnPredictionEntries and YAB.GetRespawnPredictionEntries(viewMode, nil, false) or {}
    local samples = YAB.GetRecentRespawnSamples and YAB.GetRecentRespawnSamples(viewMode, nil) or {}
    local matchedPredictions = {}
    local matchedSamples = {}

    for _, item in ipairs(predictions) do
        if tostring(item.bossId) == bossKey then
            matchedPredictions[#matchedPredictions + 1] = item
        end
    end

    for _, sample in ipairs(samples) do
        if tostring(sample.bossId) == bossKey then
            matchedSamples[#matchedSamples + 1] = sample
        end
    end

    return matchedPredictions, matchedSamples
end

local function BuildBossHistoryTooltipLines(boss, viewMode)
    local predictions, samples = GetBossHistoryEntries(boss, viewMode)
    if #predictions == 0 and #samples == 0 then
        return {
            "状态: 暂无即时数据",
            "说明: 当前没有近期位面记录，也没有可用历史样本",
        }
    end

    local lines = {
        "状态: 暂无即时数据",
        "说明: 当前没有近期位面记录，以下为历史参考",
    }

    local predictionLines = {}
    local maxPredictions = math.min(#predictions, 4)
    for index = 1, maxPredictions do
        local item = predictions[index]
        local rangeText
        if item.windowMinSeconds and item.windowMaxSeconds and item.windowMaxSeconds > item.windowMinSeconds then
            rangeText = FormatDurationCompact(item.windowMinSeconds) .. " - " .. FormatDurationCompact(item.windowMaxSeconds)
        else
            rangeText = FormatDurationCompact(item.estimateSeconds or item.windowMinSeconds or 0)
        end
        local parts = {
            tostring(item.realm or YAB.GetCurrentRealm()),
            rangeText,
            tostring(item.sampleCount or 0) .. "样本",
        }
        if item.mode == "fixed" then
            parts[#parts + 1] = "固定"
        else
            parts[#parts + 1] = "区间"
        end
        if item.confidence then
            parts[#parts + 1] = tostring(item.confidence)
        end
        predictionLines[#predictionLines + 1] = table.concat(parts, " / ")
    end
    AppendSection(lines, "历史规律", predictionLines)

    local sampleLines = {}
    local maxSamples = math.min(#samples, 4)
    for index = 1, maxSamples do
        local sample = samples[index]
        local parts = {
            tostring(sample.realm or YAB.GetCurrentRealm()),
            "位面" .. tostring(sample.phaseDisplayId or "00"),
            FormatDurationCompact(sample.elapsedSeconds or 0),
        }
        if sample.observedAt then
            parts[#parts + 1] = "记录于 " .. FormatElapsed(time() - sample.observedAt)
        end
        sampleLines[#sampleLines + 1] = table.concat(parts, " / ")
    end
    AppendSection(lines, "最近样本", sampleLines)

    return lines
end

local function BuildPhaseTooltipLines(boss, viewMode)
    local phaseStates = CollectActionPhaseStates(boss, viewMode)
    if #phaseStates == 0 then
        return BuildBossHistoryTooltipLines(boss, viewMode)
    end

    local now = time()
    local lines = {}
    AppendSection(lines, "概览", {
        "位面总数: " .. tostring(#phaseStates),
        "摘要: " .. BuildPhaseSummaryText(phaseStates),
    })

    if viewMode ~= "current" then
        local grouped = {}
        local realmOrder = {}
        for _, item in ipairs(phaseStates) do
            local realm = tostring((item.state and item.state.realm) or (item.column and item.column.realm) or YAB.GetCurrentRealm())
            if not grouped[realm] then
                grouped[realm] = {}
                realmOrder[#realmOrder + 1] = realm
            end
            grouped[realm][#grouped[realm] + 1] = item
        end

        for _, realm in ipairs(realmOrder) do
            local sectionLines = {}
            for _, item in ipairs(grouped[realm]) do
                local state = item.state
                local candidate = item.candidate
                local parts = {
                    "位面" .. tostring(state.phaseDisplayId or item.column.displayId or "00"),
                    tostring(state.phaseLabel or item.column.label or "未知"),
                }
                if candidate and candidate.text and candidate.text ~= "-" then
                    parts[#parts + 1] = candidate.text
                elseif state.lastKilledAt then
                    parts[#parts + 1] = "击杀后"
                else
                    parts[#parts + 1] = "仅观测"
                end
                if state.lastKilledAt then
                    parts[#parts + 1] = "击杀 " .. FormatElapsed(now - state.lastKilledAt)
                elseif state.observedAt then
                    parts[#parts + 1] = "观测 " .. FormatElapsed(now - state.observedAt)
                end
                if state.zone and state.zone ~= "" then
                    parts[#parts + 1] = tostring(state.zone)
                end
                if state.subZone and state.subZone ~= "" and state.subZone ~= state.zone then
                    parts[#parts + 1] = tostring(state.subZone)
                end
                sectionLines[#sectionLines + 1] = table.concat(parts, " / ")
            end
            AppendSection(lines, "服务器: " .. realm, sectionLines)
        end
    else
        local sectionLines = {}
        for _, item in ipairs(phaseStates) do
            local state = item.state
            local candidate = item.candidate
            local parts = {
                "位面" .. tostring(state.phaseDisplayId or item.column.displayId or "00"),
                tostring(state.phaseLabel or item.column.label or "未知"),
            }
            if candidate and candidate.text and candidate.text ~= "-" then
                parts[#parts + 1] = candidate.text
            elseif state.lastKilledAt then
                parts[#parts + 1] = "击杀后"
            else
                parts[#parts + 1] = "仅观测"
            end
            if state.lastKilledAt then
                parts[#parts + 1] = "击杀 " .. FormatElapsed(now - state.lastKilledAt)
            elseif state.observedAt then
                parts[#parts + 1] = "观测 " .. FormatElapsed(now - state.observedAt)
            end
            if state.zone and state.zone ~= "" then
                parts[#parts + 1] = tostring(state.zone)
            end
            if state.subZone and state.subZone ~= "" and state.subZone ~= state.zone then
                parts[#parts + 1] = tostring(state.subZone)
            end
            sectionLines[#sectionLines + 1] = table.concat(parts, " / ")
        end
        AppendSection(lines, "位面列表", sectionLines)
    end

    return lines
end

local function BuildActionTooltipLines(boss, candidate, viewMode)
    if not candidate then
        return BuildBossHistoryTooltipLines(boss, viewMode)
    end

    local state = candidate.state
    local now = time()
    local summaryLines = {
        "状态: " .. tostring(candidate.text),
    }

    if candidate.kind == "window" then
        summaryLines[#summaryLines + 1] = "建议: 当前已进入预测刷新窗口"
    elseif candidate.kind == "soon" then
        summaryLines[#summaryLines + 1] = "建议: 即将进入预测刷新窗口"
    elseif candidate.kind == "scheduled" then
        summaryLines[#summaryLines + 1] = "建议: 已有可参考的预测时刻"
    elseif candidate.kind == "weak" then
        summaryLines[#summaryLines + 1] = "建议: 先继续积累样本"
    elseif candidate.kind == "observed" then
        summaryLines[#summaryLines + 1] = "建议: 当前只有位面观测"
    elseif candidate.kind == "overdue" then
        summaryLines[#summaryLines + 1] = "建议: 预测窗口已过，等待新的确认"
    end

    local locationLines = {
        "服务器: " .. tostring(candidate.realm or YAB.GetCurrentRealm()),
        "最近位面: 位面" .. tostring(candidate.phaseDisplayId) .. " / " .. tostring(candidate.phaseLabel or "未知"),
    }

    if state.zone and state.zone ~= "" then
        locationLines[#locationLines + 1] = "区域: " .. tostring(state.zone)
    end
    if state.subZone and state.subZone ~= "" and state.subZone ~= state.zone then
        locationLines[#locationLines + 1] = "子区域: " .. tostring(state.subZone)
    end

    local observeLines = {}
    if state.observedAt then
        observeLines[#observeLines + 1] = "最近观测: " .. FormatElapsed(now - state.observedAt)
    end
    if state.lastObservedBy then
        observeLines[#observeLines + 1] = "观测角色: " .. tostring(state.lastObservedBy)
    end

    local killLines = {}
    if state.lastKilledAt then
        killLines[#killLines + 1] = "最近击杀: " .. FormatElapsed(now - state.lastKilledAt)
    end
    if state.lastKilledBy then
        killLines[#killLines + 1] = "击杀角色: " .. tostring(state.lastKilledBy)
    end
    if HasPendingRespawnSample(state) then
        killLines[#killLines + 1] = "样本状态: 已记录击杀，需等待下次刷新并再次观测后才会新增"
    end

    local predictLines = {}
    if state.respawnEstimateSeconds and (state.respawnEstimateSamples or 0) > 0 then
        if state.respawnEstimateMode == "fixed" then
            predictLines[#predictLines + 1] = "预测模式: 固定刷新"
        else
            predictLines[#predictLines + 1] = "预测模式: 区间刷新"
        end
        predictLines[#predictLines + 1] = "样本数: " .. tostring(state.respawnEstimateSamples)
        if (state.respawnEstimateEffectiveSamples or 0) > 0
            and state.respawnEstimateEffectiveSamples ~= state.respawnEstimateSamples then
            predictLines[#predictLines + 1] = "参与估算: " .. tostring(state.respawnEstimateEffectiveSamples)
        end
        if state.respawnEstimateObservedMinSeconds then
            predictLines[#predictLines + 1] = "最小实测刷新: " .. FormatDurationCompact(state.respawnEstimateObservedMinSeconds)
        end
        if state.lastRespawnSampleSeconds then
            predictLines[#predictLines + 1] = "最近实测刷新: " .. FormatDurationCompact(state.lastRespawnSampleSeconds)
        end
        if state.respawnEstimateMinSeconds and state.respawnEstimateMaxSeconds then
            local startAt = state.lastKilledAt and (state.lastKilledAt + state.respawnEstimateMinSeconds) or nil
            local endAt = state.lastKilledAt and (state.lastKilledAt + state.respawnEstimateMaxSeconds) or nil
            if startAt and endAt then
                if endAt > startAt then
                    predictLines[#predictLines + 1] = "预测窗口: " .. FormatClockTime(startAt) .. " - " .. FormatClockTime(endAt)
                else
                    predictLines[#predictLines + 1] = "预测时刻: " .. FormatClockTime(startAt)
                end
            end
        end
        if state.respawnEstimateConfidence then
            predictLines[#predictLines + 1] = "置信度: " .. tostring(state.respawnEstimateConfidence)
        end
    end

    local lines = {}
    AppendSection(lines, "当前判断", summaryLines)
    AppendSection(lines, "位面位置", locationLines)
    AppendSection(lines, "观测信息", observeLines)
    AppendSection(lines, "击杀信息", killLines)
    AppendSection(lines, "预测信息", predictLines)

    return lines
end

local function UpdateActionCellButton(button, boss, viewMode, width, rowIndex)
    local candidate = PickBestActionCandidate(boss, viewMode)
    button:SetWidth(width)
    button.tooltipTitle = boss.name .. " / 行动详情"
    button:SetScript("OnClick", nil)

    local kind = candidate and candidate.kind or "empty"
    local text = candidate and candidate.text or "-"
    local colors = {
        empty = { bg = GetRowIdleColor(rowIndex), text = SUBTEXT_COLOR, glow = nil, pulse = false },
        observed = { bg = OBSERVED_COLOR, text = { 1, 1, 1 }, glow = { 0.24, 0.52, 0.82, 0.24 }, pulse = false },
        weak = { bg = WAIT_COLOR, text = { 1, 1, 1 }, glow = { 0.75, 0.56, 0.16, 0.22 }, pulse = false },
        scheduled = { bg = READY_COLOR, text = { 1, 1, 1 }, glow = { 0.28, 0.7, 0.34, 0.18 }, pulse = false },
        soon = { bg = READY_COLOR, text = { 1, 1, 1 }, glow = { 0.36, 0.9, 0.42, 0.26 }, pulse = true },
        window = { bg = OK_COLOR, text = { 1, 1, 1 }, glow = { 0.42, 1, 0.5, 0.34 }, pulse = true },
        overdue = { bg = { 0.52, 0.24, 0.08, 0.96 }, text = { 1, 1, 1 }, glow = { 0.95, 0.48, 0.16, 0.24 }, pulse = false },
    }
    local palette = colors[kind] or colors.empty
    SetCellBackdrop(button, palette.bg)
    SetLabel(button.text, text, palette.text)
    SetButtonPulse(button, palette.glow, palette.pulse)
    button.tooltipLine = table.concat(BuildActionTooltipLines(boss, candidate, viewMode), "\n")
end

UpdatePhaseSummaryCellButton = function(button, boss, viewMode, width, rowIndex)
    local phaseStates = CollectActionPhaseStates(boss, viewMode)
    button:SetWidth(width)
    button.tooltipTitle = boss.name .. " / 位面详情"
    button:SetScript("OnClick", nil)

    if #phaseStates == 0 then
        button.tooltipLine = table.concat(BuildBossHistoryTooltipLines(boss, viewMode), "\n")
        SetCellBackdrop(button, GetRowIdleColor(rowIndex))
        SetLabel(button.text, "-", SUBTEXT_COLOR)
        SetButtonPulse(button, nil, false)
        return
    end

    local hasWindow = false
    local hasSoon = false
    local hasKill = false
    for _, item in ipairs(phaseStates) do
        if item.candidate and item.candidate.kind == "window" then
            hasWindow = true
        elseif item.candidate and item.candidate.kind == "soon" then
            hasSoon = true
        end
        if item.state and item.state.lastKilledAt then
            hasKill = true
        end
    end

    if hasWindow then
        SetCellBackdrop(button, OK_COLOR)
        SetLabel(button.text, BuildPhaseSummaryText(phaseStates), { 1, 1, 1 })
        SetButtonPulse(button, { 0.42, 1, 0.5, 0.34 }, true)
    elseif hasSoon then
        SetCellBackdrop(button, READY_COLOR)
        SetLabel(button.text, BuildPhaseSummaryText(phaseStates), { 1, 1, 1 })
        SetButtonPulse(button, { 0.36, 0.9, 0.42, 0.26 }, true)
    elseif hasKill then
        SetCellBackdrop(button, WAIT_COLOR)
        SetLabel(button.text, BuildPhaseSummaryText(phaseStates), { 1, 1, 1 })
        SetButtonPulse(button, nil, false)
    else
        SetCellBackdrop(button, OBSERVED_COLOR)
        SetLabel(button.text, BuildPhaseSummaryText(phaseStates), { 1, 1, 1 })
        SetButtonPulse(button, nil, false)
    end

    button.tooltipLine = table.concat(BuildPhaseTooltipLines(boss, viewMode), "\n")
end

local function ApplyActionButtonVisual(button)
    if not button then
        return
    end

    local bgColor
    local textColor
    if button.variant == "primary" then
        if not button:IsEnabled() then
            bgColor = BUTTON_SECONDARY_BG
            textColor = BUTTON_MUTED_TEXT_COLOR
        elseif button.isPressed then
            bgColor = BUTTON_PRIMARY_ACTIVE_BG
            textColor = TITLE_COLOR
        elseif button.isSelected or button.isHovered then
            bgColor = BUTTON_PRIMARY_HOVER_BG
            textColor = TITLE_COLOR
        else
            bgColor = BUTTON_PRIMARY_BG
            textColor = BUTTON_TEXT_COLOR
        end
    else
        if not button:IsEnabled() then
            bgColor = BUTTON_SECONDARY_BG
            textColor = BUTTON_MUTED_TEXT_COLOR
        elseif button.isPressed then
            bgColor = BUTTON_SECONDARY_ACTIVE_BG
            textColor = TITLE_COLOR
        elseif button.isSelected then
            bgColor = BUTTON_PRIMARY_BG
            textColor = TITLE_COLOR
        elseif button.isHovered then
            bgColor = BUTTON_SECONDARY_HOVER_BG
            textColor = BUTTON_TEXT_COLOR
        else
            bgColor = BUTTON_SECONDARY_BG
            textColor = BUTTON_MUTED_TEXT_COLOR
        end
    end

    SetBackdropInset(button, bgColor, BUTTON_BORDER_COLOR, 1)
    if button.label then
        SetLabel(button.label, button.textValue or "", textColor)
    end
end

local function ResizeActionButtonToText(button, minWidth, padding)
    if not button or not button.label then
        return
    end
    local width = minWidth or 52
    if button.label.GetStringWidth then
        width = math.max(width, math.ceil(button.label:GetStringWidth() + (padding or 26)))
    end
    button:SetWidth(width)
end

local function CreateActionButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 72, 24)
    button.textValue = text or ""
    button.variant = "secondary"
    button.label = CreateText(button, LABEL_FONT_SIZE, "CENTER")
    button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.label:SetFontObject(GameFontHighlightSmall)
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self)
        self.isHovered = true
        ApplyActionButtonVisual(self)
    end)
    button:SetScript("OnLeave", function(self)
        self.isHovered = false
        self.isPressed = false
        ApplyActionButtonVisual(self)
    end)
    button:SetScript("OnMouseDown", function(self)
        self.isPressed = true
        ApplyActionButtonVisual(self)
    end)
    button:SetScript("OnMouseUp", function(self)
        self.isPressed = false
        ApplyActionButtonVisual(self)
    end)
    button:SetScript("OnEnable", ApplyActionButtonVisual)
    button:SetScript("OnDisable", ApplyActionButtonVisual)
    ApplyActionButtonVisual(button)
    return button
end

local function ConfigureActionButton(button, text, isPrimary, isSelected)
    if not button then
        return
    end
    button.textValue = text or button.textValue or ""
    button.variant = isPrimary and "primary" or "secondary"
    button.isSelected = not not isSelected
    ResizeActionButtonToText(button, isPrimary and 84 or 56, isPrimary and 34 or 28)
    ApplyActionButtonVisual(button)
end

local ApplyActionButtonTextScale
local GetHoverVisualScale

local function RefreshControlButtons(buttons, titleBar, viewMode)
    if not buttons then
        return
    end
    viewMode = NormalizeViewMode(viewMode)
    local controlScale = (HoverChrome and titleBar == HoverChrome.titleBar) and GetHoverVisualScale() or 1
    for _, button in ipairs({
        buttons.current,
        buttons.other,
        buttons.all,
        buttons.settings,
        buttons.close,
    }) do
        ApplyActionButtonTextScale(button, controlScale)
    end
    local realmLabel = YAB.GetCurrentRealmLabel and YAB.GetCurrentRealmLabel() or "当前服务器"
    if buttons.current then
        ConfigureActionButton(buttons.current, realmLabel, false, viewMode == "current")
    end
    if buttons.other then
        local otherLabel = YAB.GetOtherRealmButtonLabel and YAB.GetOtherRealmButtonLabel() or "其它服务器"
        ConfigureActionButton(buttons.other, otherLabel, false, viewMode == "other")
    end
    if buttons.all then
        ConfigureActionButton(buttons.all, "所有服务器", false, viewMode == "all")
    end
    if buttons.settings then
        ConfigureActionButton(buttons.settings, "设置", false, false)
    end
    if buttons.close then
        ConfigureActionButton(buttons.close, "关闭", false, false)
    end

    if buttons.close then
        buttons.close:ClearAllPoints()
        buttons.close:SetPoint("RIGHT", titleBar, "RIGHT", -8, 0)
    end
    if buttons.settings and buttons.close then
        buttons.settings:ClearAllPoints()
        buttons.settings:SetPoint("RIGHT", buttons.close, "LEFT", -4, 0)
    end
    if buttons.all and buttons.settings then
        buttons.all:ClearAllPoints()
        buttons.all:SetPoint("RIGHT", buttons.settings, "LEFT", -10, 0)
    end
    local rightAnchor = buttons.all
    if buttons.other and rightAnchor then
        buttons.other:ClearAllPoints()
        buttons.other:SetPoint("RIGHT", rightAnchor, "LEFT", -6, 0)
        rightAnchor = buttons.other
    end
    if buttons.current and rightAnchor then
        buttons.current:ClearAllPoints()
        buttons.current:SetPoint("RIGHT", rightAnchor, "LEFT", -6, 0)
    end
end

local function GetControlButtonsMinWidth(buttons)
    local width = 16
    local ordered = {
        buttons and buttons.current,
        buttons and buttons.other,
        buttons and buttons.all,
        buttons and buttons.settings,
        buttons and buttons.close,
    }
    local previous
    for _, button in ipairs(ordered) do
        if button then
            width = width + (button:GetWidth() or 0)
            if previous then
                if button == buttons.settings then
                    width = width + 10
                else
                    width = width + 6
                end
            end
            previous = button
        end
    end
    return width + 16
end

local function SetTextSize(fontString, size)
    if not fontString then
        return
    end
    local font, _, flags = fontString:GetFont()
    fontString:SetFont(font, size, flags)
end

GetHoverVisualScale = function()
    return YAB.GetHoverScale and YAB.GetHoverScale() or 1
end

local function ScaleFontSize(baseSize, scale)
    scale = tonumber(scale) or 1
    return math.max(8, math.floor((baseSize * scale) + 0.5))
end

ApplyActionButtonTextScale = function(button, scale)
    if not (button and button.label) then
        return
    end
    SetTextSize(button.label, ScaleFontSize(LABEL_FONT_SIZE, scale))
    button:SetHeight(math.max(24, math.floor((24 * scale) + 0.5)))
end

local function ConfigureHoverHeader(viewMode, isSimple)
    if not HoverChrome then
        return
    end

    local titleText = HoverChrome.titleText
    local versionText = HoverChrome.versionText
    local subtitleText = HoverChrome.subtitleText
    local icon = HoverChrome.icon
    local hoverScale = GetHoverVisualScale()

    if isSimple then
        if icon then
            icon:Hide()
        end
        if titleText then
            titleText:ClearAllPoints()
            titleText:SetPoint("LEFT", HoverChrome.titleBar, "LEFT", 10, 1)
            titleText:SetWidth(92)
            titleText:SetWordWrap(false)
            SetTextSize(titleText, ScaleFontSize(13, hoverScale))
            SetLabel(titleText, "悬停速览", TITLE_COLOR)
            titleText:Hide()
        end
        if subtitleText then
            subtitleText:Hide()
        end
        if versionText then
            versionText:Hide()
        end
        return
    end

    if icon then
        icon:Show()
    end
    if titleText then
        titleText:ClearAllPoints()
        titleText:SetPoint("LEFT", icon, "RIGHT", 8, 4)
    titleText:SetWidth(math.floor(104 * hoverScale))
        titleText:SetWordWrap(false)
        SetTextSize(titleText, ScaleFontSize(TITLE_FONT_SIZE, hoverScale))
        SetLabel(titleText, "YiboAltoBoss", TITLE_COLOR)
        titleText:Show()
    end
    if subtitleText then
        subtitleText:ClearAllPoints()
        subtitleText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -1)
        SetTextSize(subtitleText, ScaleFontSize(LABEL_FONT_SIZE, hoverScale))
        SetLabel(subtitleText, YAB.GetViewLabel and YAB.GetViewLabel(viewMode) or "服务器视图", MUTED_HEADER_COLOR)
        subtitleText:Show()
    end
    if versionText then
        versionText:ClearAllPoints()
        versionText:SetPoint("BOTTOMLEFT", titleText, "BOTTOMRIGHT", 5, 0)
        SetTextSize(versionText, ScaleFontSize(11, hoverScale))
        SetLabel(versionText, "v" .. ADDON_VERSION, SUBTEXT_COLOR)
        versionText:Show()
    end
end

local function CreatePanelChrome(frame, isTransient)
    local chrome = {}

    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    SetBackdropInset(frame, PANEL_COLOR, BORDER_COLOR, 2)
    frame:SetToplevel(true)

    chrome.titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    chrome.titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    chrome.titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    chrome.titleBar:SetHeight(TITLE_BAR_HEIGHT)
    SetBackdropInset(chrome.titleBar, TITLE_BAR_COLOR, BORDER_COLOR, 1)

    if not isTransient then
        chrome.titleBar:EnableMouse(true)
        chrome.titleBar:RegisterForDrag("LeftButton")
        chrome.titleBar:SetScript("OnDragStart", function()
            frame:StartMoving()
        end)
        chrome.titleBar:SetScript("OnDragStop", function()
            frame:StopMovingOrSizing()
            if YAB.SetStoredWindowPosition then
                local point, _, relativePoint, x, y = frame:GetPoint(1)
                YAB.SetStoredWindowPosition(point, relativePoint, x, y)
                YAB.PersistDB()
            end
        end)
    end

    chrome.titleGlow = chrome.titleBar:CreateTexture(nil, "ARTWORK")
    chrome.titleGlow:SetTexture(BACKDROP_BG)
    chrome.titleGlow:SetPoint("TOPLEFT", chrome.titleBar, "TOPLEFT", 1, -1)
    chrome.titleGlow:SetPoint("BOTTOMRIGHT", chrome.titleBar, "BOTTOMRIGHT", -1, 1)
    SetVertexColor(chrome.titleGlow, { 0.24, 0.14, 0.03, 0.35 })

    chrome.icon = chrome.titleBar:CreateTexture(nil, "ARTWORK")
    chrome.icon:SetTexture(ICON_PATH)
    chrome.icon:SetSize(18, 18)
    chrome.icon:SetPoint("LEFT", chrome.titleBar, "LEFT", 10, 1)

    chrome.titleText = CreateText(chrome.titleBar, TITLE_FONT_SIZE, "LEFT")
    chrome.titleText:SetPoint("LEFT", chrome.icon, "RIGHT", 8, 4)
    SetLabel(chrome.titleText, "YiboAltoBoss", TITLE_COLOR)

    chrome.versionText = CreateText(chrome.titleBar, 11, "LEFT")
    chrome.versionText:SetPoint("BOTTOMLEFT", chrome.titleText, "BOTTOMRIGHT", 5, 0)
    SetLabel(chrome.versionText, "v" .. ADDON_VERSION, SUBTEXT_COLOR)

    chrome.subtitleText = CreateText(chrome.titleBar, LABEL_FONT_SIZE, "LEFT")
    chrome.subtitleText:SetPoint("TOPLEFT", chrome.titleText, "BOTTOMLEFT", 0, -1)
    SetLabel(chrome.subtitleText, "", MUTED_HEADER_COLOR)

    chrome.contentPanel = CreateFrame("Frame", nil, frame)
    chrome.contentPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -CONTENT_TOP_INSET)
    chrome.contentPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 4)

    frame.chrome = chrome
    return chrome
end

local function EnsureHeaderPool(frame)
    frame.headers = frame.headers or {}
    frame.rowLabels = frame.rowLabels or {}
    frame.rowBands = frame.rowBands or {}
    frame.currentColumnHighlights = frame.currentColumnHighlights or {}
end

local function HideUnusedFontStrings(pool, startIndex)
    if not pool then
        return
    end
    for index = startIndex, #pool do
        pool[index]:Hide()
    end
end

local function HideUnusedFrames(pool, startIndex)
    if not pool then
        return
    end
    for index = startIndex, #pool do
        pool[index]:Hide()
    end
end

local function GetFrameLayoutWidth(frame)
    if frame == GridFrame and MainScrollFrame then
        local viewportWidth = MainScrollFrame:GetWidth() or 0
        if viewportWidth > 0 then
            return math.max(viewportWidth - 8, 320)
        end
    end
    return math.max((frame:GetWidth() or 500) - 20, 320)
end

local function CalculateCharacterColumnLayout(frame, viewMode)
    viewMode = NormalizeViewMode(viewMode)
    local contentWidth = GetFrameLayoutWidth(frame)
    local chars = YAB.GetCharacterKeys(viewMode)
    local charCount = math.max(#chars, 1)
    local isTransient = IsTransientGridFrame(frame)
    local minBossWidth = viewMode == "current" and 148 or 124
    local bossWidth = GetPreferredBossColumnWidth(viewMode, isTransient)
    local actionWidth = ACTION_COLUMN_WIDTH
    local phaseSummaryWidth = PHASE_SUMMARY_COLUMN_WIDTH
    local minCellWidth = GetPreferredCharacterCellWidth(viewMode, isTransient)
    local remainingWidth = math.max(contentWidth - bossWidth - actionWidth - phaseSummaryWidth, 120)
    local cellWidth = math.floor(remainingWidth / charCount)
    if cellWidth < minCellWidth then
        cellWidth = minCellWidth
        bossWidth = math.max(minBossWidth, contentWidth - actionWidth - phaseSummaryWidth - cellWidth * charCount)
    end
    bossWidth = math.max(minBossWidth, bossWidth)
    return chars, bossWidth, actionWidth, phaseSummaryWidth, cellWidth, contentWidth
end

local function CalculatePhaseColumnLayout(frame, viewMode)
    viewMode = NormalizeViewMode(viewMode)
    local contentWidth = GetFrameLayoutWidth(frame)
    local columns = YAB.GetPhaseColumns(viewMode)
    local columnCount = math.max(#columns, 1)
    local minBossWidth = viewMode == "current" and 110 or 92
    local bossWidth = viewMode == "current" and 112 or 96
    local remainingWidth = math.max(contentWidth - bossWidth, 120)
    local cellWidth = math.floor(remainingWidth / columnCount)
    if cellWidth < 54 then
        cellWidth = 54
        bossWidth = math.max(92, contentWidth - cellWidth * columnCount)
    end
    bossWidth = math.max(minBossWidth, bossWidth)
    return columns, bossWidth, cellWidth, contentWidth
end

local function CalculateGridContentHeight(maxHeaderLines, bossCount)
    local headerHeight = math.max(22, (maxHeaderLines or 1) * HEADER_LINE_HEIGHT)
    return 24
        + headerHeight
        + HEADER_BOTTOM_GAP
        + ((bossCount or 0) * 22)
        + GRID_BOTTOM_PADDING
end

local function GetFrameMetrics(viewMode, isTransient)
    viewMode = NormalizeViewMode(viewMode)
    local chars = YAB.GetCharacterKeys(viewMode)
    local bosses = YAB.GetBossList()
    local charCount = math.max(#chars, 1)
    local killBossWidth = GetPreferredBossColumnWidth(viewMode, isTransient)
    local actionWidth = ACTION_COLUMN_WIDTH
    local phaseSummaryWidth = PHASE_SUMMARY_COLUMN_WIDTH
    local killCellWidth = GetPreferredCharacterCellWidth(viewMode, isTransient)
    local killCharsPerLine = GetHeaderCharsPerLineForWidth(killCellWidth - 4, HEADER_CHARS_PER_LINE)
    local maxKillHeaderLines = 1
    for _, charKey in ipairs(chars) do
        local lines = GetHeaderLineCount(GetDisplayedCharacterLabel(charKey, viewMode), killCharsPerLine)
        if lines > maxKillHeaderLines then
            maxKillHeaderLines = lines
        end
    end
    local contentWidth = 12 + killBossWidth + actionWidth + phaseSummaryWidth + (charCount * killCellWidth)
    local width = contentWidth + 20
    local gridHeight = CalculateGridContentHeight(maxKillHeaderLines, #bosses)
    local height = gridHeight + (isTransient and HOVER_GRID_CHROME_HEIGHT or MAIN_GRID_CHROME_HEIGHT)
    if isTransient then
        width = math.max(HOVER_MIN_FRAME_WIDTH, math.min(width, HOVER_MAX_FRAME_WIDTH))
        height = math.max(HOVER_MIN_FRAME_HEIGHT, math.min(height, HOVER_MAX_FRAME_HEIGHT))
    else
        width = math.max(MIN_FRAME_WIDTH, math.min(width, MAX_FRAME_WIDTH))
        height = math.max(MIN_FRAME_HEIGHT, math.min(height, MAX_FRAME_HEIGHT))
    end
    return width, height
end

local function EstimateContentHeight(frame, viewMode)
    viewMode = NormalizeViewMode(viewMode)
    local chars = YAB.GetCharacterKeys(viewMode)
    local bosses = YAB.GetBossList()
    local killCellWidth = GetPreferredCharacterCellWidth(viewMode, IsTransientGridFrame(frame))
    local killCharsPerLine = GetHeaderCharsPerLineForWidth(killCellWidth - 4, HEADER_CHARS_PER_LINE)
    local maxKillHeaderLines = 1
    for _, charKey in ipairs(chars) do
        local lines = GetHeaderLineCount(GetDisplayedCharacterLabel(charKey, viewMode), killCharsPerLine)
        if lines > maxKillHeaderLines then
            maxKillHeaderLines = lines
        end
    end
    return CalculateGridContentHeight(maxKillHeaderLines, #bosses)
end

RefreshGrid = function(frame, viewMode)
    viewMode = NormalizeViewMode(viewMode)
    local chrome = frame and frame.chrome or nil
    local textScale = (frame == HoverBody) and GetHoverVisualScale() or 1
    frame.dynamicButtons = frame.dynamicButtons or {}
    frame.renderErrors = {}
    ReleaseDynamicWidgets(frame.dynamicButtons)
    EnsureHeaderPool(frame)

    local chars, killBossWidth, actionWidth, phaseSummaryWidth, killCellWidth, contentWidth = CalculateCharacterColumnLayout(frame, viewMode)
    local bosses = YAB.GetBossList()
    local killCharsPerLine = GetHeaderCharsPerLineForWidth(killCellWidth - 4, HEADER_CHARS_PER_LINE)

    local title = frame.title or CreateText(frame, SECTION_FONT_SIZE, "LEFT")
    frame.title = title
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -4)
    SetTextSize(title, ScaleFontSize(SECTION_FONT_SIZE, textScale))
    SetLabel(title, YAB.GetViewLabel and YAB.GetViewLabel(viewMode) or "服务器视图", TITLE_COLOR)

    local subtitle = frame.subtitle or CreateText(frame, LABEL_FONT_SIZE, "LEFT")
    frame.subtitle = subtitle
    subtitle:ClearAllPoints()
    subtitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -5)
    SetTextSize(subtitle, ScaleFontSize(LABEL_FONT_SIZE, textScale))
    local killed, total = YAB.GetBossSummary(viewMode)
    SetLabel(subtitle, "击杀记录 " .. killed .. "/" .. total, SUBTEXT_COLOR)

    local headerBoss = frame.headerBoss or CreateText(frame, SECTION_FONT_SIZE, "LEFT")
    frame.headerBoss = headerBoss
    local phaseTitle = frame.phaseTitle or CreateText(frame, SECTION_FONT_SIZE, "LEFT")
    frame.phaseTitle = phaseTitle
    local phaseHeaderBoss = frame.phaseHeaderBoss or CreateText(frame, SECTION_FONT_SIZE, "LEFT")
    frame.phaseHeaderBoss = phaseHeaderBoss
    local phaseLine = frame.phaseLine or CreateText(frame, FOOTER_FONT_SIZE, "LEFT")
    frame.phaseLine = phaseLine

    headerBoss:Show()
    headerBoss:ClearAllPoints()
    headerBoss:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -24)
    headerBoss:SetWidth(killBossWidth - 6)
    SetTextSize(headerBoss, ScaleFontSize(SECTION_FONT_SIZE, textScale))
    SetLabel(headerBoss, "Boss / 目标", TITLE_COLOR)
    phaseTitle:Hide()
    phaseHeaderBoss:Hide()
    phaseLine:Hide()

    local maxKillHeaderLines = 1
    for _, charKey in ipairs(chars) do
        local lines = GetHeaderLineCount(GetDisplayedCharacterLabel(charKey, viewMode), killCharsPerLine)
        if lines > maxKillHeaderLines then
            maxKillHeaderLines = lines
        end
    end

    local killHeaderY = -24
    local actionHeader = frame.actionHeader or CreateText(frame, SECTION_FONT_SIZE, "CENTER")
    frame.actionHeader = actionHeader
    actionHeader:Show()
    actionHeader:ClearAllPoints()
    actionHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 6 + killBossWidth, killHeaderY)
    actionHeader:SetWidth(actionWidth - 2)
    SetTextSize(actionHeader, ScaleFontSize(SECTION_FONT_SIZE, textScale))
    SetLabel(actionHeader, "行动", TITLE_COLOR)

    local phaseSummaryHeader = frame.phaseSummaryHeader or CreateText(frame, SECTION_FONT_SIZE, "CENTER")
    frame.phaseSummaryHeader = phaseSummaryHeader
    phaseSummaryHeader:Show()
    phaseSummaryHeader:ClearAllPoints()
    phaseSummaryHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 6 + killBossWidth + actionWidth, killHeaderY)
    phaseSummaryHeader:SetWidth(phaseSummaryWidth - 2)
    SetTextSize(phaseSummaryHeader, ScaleFontSize(SECTION_FONT_SIZE, textScale))
    SetLabel(phaseSummaryHeader, "位面", TITLE_COLOR)

    for index, charKey in ipairs(chars) do
        local header = frame.headers[index]
        if not header then
            header = CreateText(frame, LABEL_FONT_SIZE, "CENTER")
            header:SetWordWrap(true)
            frame.headers[index] = header
        end
        header:Show()
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", 6 + killBossWidth + actionWidth + phaseSummaryWidth + (index - 1) * killCellWidth, killHeaderY)
        header:SetWidth(killCellWidth - 2)
        SetTextSize(header, ScaleFontSize(LABEL_FONT_SIZE, textScale))
        SetLabel(
            header,
            BreakHeaderText(GetDisplayedCharacterLabel(charKey, viewMode), killCharsPerLine),
            charKey == (YAB.GetCurrentCharKey and YAB.GetCurrentCharKey() or nil) and CURRENT_CHAR_HEADER_COLOR or TITLE_COLOR
        )
    end
    HideUnusedFontStrings(frame.headers, #chars + 1)

    local killHeaderHeight = math.max(22, maxKillHeaderLines * HEADER_LINE_HEIGHT)
    local currentCharKey = YAB.GetCurrentCharKey and YAB.GetCurrentCharKey() or nil
    local highlightHeight = killHeaderHeight + HEADER_BOTTOM_GAP + (#bosses * 22) - 1
    local highlightCount = 0
    if currentCharKey then
        for index, charKey in ipairs(chars) do
            if charKey == currentCharKey then
                highlightCount = highlightCount + 1
                local highlight = frame.currentColumnHighlights[highlightCount]
                if not highlight then
                    highlight = CreateFrame("Frame", nil, frame, "BackdropTemplate")
                    highlight:SetFrameLevel(math.max((frame:GetFrameLevel() or 1) - 1, 1))
                    SetBackdropInset(highlight, CURRENT_CHAR_COLUMN_BG, CURRENT_CHAR_COLUMN_BORDER, 1)
                    frame.currentColumnHighlights[highlightCount] = highlight
                end
                highlight:Show()
                highlight:ClearAllPoints()
                highlight:SetPoint("TOPLEFT", frame, "TOPLEFT", 6 + killBossWidth + actionWidth + phaseSummaryWidth + (index - 1) * killCellWidth, killHeaderY + 1)
                highlight:SetSize(killCellWidth - 2, highlightHeight)
            end
        end
    end
    HideUnusedFrames(frame.currentColumnHighlights, highlightCount + 1)

    local rowY = killHeaderY - killHeaderHeight - HEADER_BOTTOM_GAP
    for rowIndex, boss in ipairs(bosses) do
        local rowBand = frame.rowBands[rowIndex]
        if not rowBand then
            rowBand = frame:CreateTexture(nil, "BACKGROUND")
            rowBand:SetTexture(BACKDROP_BG)
            frame.rowBands[rowIndex] = rowBand
        end
        rowBand:Show()
        rowBand:ClearAllPoints()
        rowBand:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, rowY + 1)
        rowBand:SetSize(math.max(contentWidth - 12, 1), 21)
        if rowIndex % 2 == 0 then
            rowBand:SetVertexColor(0.15, 0.15, 0.17, 0.64)
        else
            rowBand:SetVertexColor(0.075, 0.075, 0.09, 0.68)
        end

        local rowLabel = frame.rowLabels[rowIndex]
        if not rowLabel then
            rowLabel = CreateText(frame, LABEL_FONT_SIZE, "LEFT")
            frame.rowLabels[rowIndex] = rowLabel
        end
        rowLabel:Show()
        rowLabel:ClearAllPoints()
        rowLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, rowY)
        rowLabel:SetWidth(killBossWidth - 6)
        SetTextSize(rowLabel, ScaleFontSize(LABEL_FONT_SIZE, textScale))
        SetLabel(rowLabel, boss.name, TEXT_COLOR)

        if not boss.hideAction then
            local actionButton = CreateCellButton(frame)
            actionButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 6 + killBossWidth, rowY + 1)
            if TryRenderBossWidget(frame, boss, "action", function()
                SetTextSize(actionButton.text, ScaleFontSize(CELL_FONT_SIZE, textScale))
                UpdateActionCellButton(actionButton, boss, viewMode, actionWidth - 2, rowIndex)
            end) then
                actionButton:Show()
            end
            frame.dynamicButtons[#frame.dynamicButtons + 1] = actionButton
        end

        if not boss.hidePhase then
            local phaseSummaryButton = CreateCellButton(frame)
            phaseSummaryButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 6 + killBossWidth + actionWidth, rowY + 1)
            if TryRenderBossWidget(frame, boss, "phase", function()
                SetTextSize(phaseSummaryButton.text, ScaleFontSize(CELL_FONT_SIZE, textScale))
                UpdatePhaseSummaryCellButton(phaseSummaryButton, boss, viewMode, phaseSummaryWidth - 2, rowIndex)
            end) then
                phaseSummaryButton:Show()
            end
            frame.dynamicButtons[#frame.dynamicButtons + 1] = phaseSummaryButton
        end

        for charIndex, charKey in ipairs(chars) do
            local button = CreateCellButton(frame)
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", 6 + killBossWidth + actionWidth + phaseSummaryWidth + (charIndex - 1) * killCellWidth, rowY + 1)
            if TryRenderBossWidget(frame, boss, "kill", function()
                SetTextSize(button.text, ScaleFontSize(CELL_FONT_SIZE, textScale))
                UpdateCellButton(button, charKey, boss, killCellWidth - 2, rowIndex)
            end) then
                button:Show()
            end
            frame.dynamicButtons[#frame.dynamicButtons + 1] = button
        end

        rowY = rowY - 22
    end
    HideUnusedFontStrings(frame.rowLabels, #bosses + 1)
    HideUnusedFrames(frame.rowBands, #bosses + 1)

    frame.contentWidth = contentWidth
    frame.contentHeight = EstimateContentHeight(frame, viewMode)
    if frame.SetSize then
        frame:SetSize(contentWidth, frame.contentHeight)
    end
    if frame == GridFrame then
        if MainFrame and MainFrame:IsShown() then
            local _, requiredHeight = GetFrameMetrics(viewMode, false)
            local currentHeight = MainFrame:GetHeight() or 0
            if math.abs(currentHeight - requiredHeight) > 0.5 then
                suppressMainFrameResizePersistence = true
                MainFrame:SetHeight(requiredHeight)
                suppressMainFrameResizePersistence = false
            end
        end
        RefreshMainScrollBounds()
    end

    if chrome and chrome.subtitleText then
        local viewLabel = YAB.GetViewLabel and YAB.GetViewLabel(viewMode) or "服务器视图"
        SetLabel(chrome.subtitleText, viewLabel, MUTED_HEADER_COLOR)
    end
    if chrome and chrome.controls and chrome.titleBar then
        RefreshControlButtons(chrome.controls, chrome.titleBar, viewMode)
    end
end

local function RefreshHoverBody(viewMode)
    viewMode = NormalizeViewMode(viewMode)
    if not HoverBody or not HoverChrome then
        return
    end

    local mode = YAB.GetHoverMode()
    local hoverScale = YAB.GetHoverScale and YAB.GetHoverScale() or 1
    HoverFrame:SetScale(hoverScale)
    if mode == "off" then
        HoverBody:Hide()
        HoverSimpleBody:Hide()
        if HoverFrame.simpleLines then
            for _, line in ipairs(HoverFrame.simpleLines) do
                line:Hide()
            end
        end
        HoverFrame:Hide()
        return
    end

    if mode == "simple" then
        ConfigureHoverHeader(viewMode, true)
        HoverBody:Hide()
        HoverSimpleBody:Show()
        HoverFrame.simpleLines = HoverFrame.simpleLines or {}
        local lines = YAB.GetSimpleHoverLines(viewMode)
        local lastAnchor
        for index, text in ipairs(lines) do
            local line = HoverFrame.simpleLines[index]
            if not line then
                line = CreateText(HoverSimpleBody, LABEL_FONT_SIZE, "LEFT")
                HoverFrame.simpleLines[index] = line
            end
            line:Show()
            line:ClearAllPoints()
            SetTextSize(line, ScaleFontSize(LABEL_FONT_SIZE, hoverScale))
            if lastAnchor then
                line:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -6)
            else
                line:SetPoint("TOPLEFT", HoverSimpleBody, "TOPLEFT", 4, -4)
            end
            line:SetWidth(420)
            SetLabel(line, text, TEXT_COLOR)
            lastAnchor = line
        end
        for index = #lines + 1, #(HoverFrame.simpleLines or {}) do
            HoverFrame.simpleLines[index]:Hide()
        end
        if HoverChrome.controls then
            RefreshControlButtons(HoverChrome.controls, HoverChrome.titleBar, viewMode)
        end
        local height = 78 + math.max(#lines, 1) * 18
        local minWidth = math.max(420, GetControlButtonsMinWidth(HoverChrome.controls))
        HoverFrame:SetSize(minWidth, Clamp(height, 144, 260))
    else
        ConfigureHoverHeader(viewMode, false)
        if HoverFrame.simpleLines then
            for _, line in ipairs(HoverFrame.simpleLines) do
                line:Hide()
            end
        end
        HoverSimpleBody:Hide()
        HoverBody:Show()
        local hoverWidth, hoverHeight = GetFrameMetrics(viewMode, true)
        HoverFrame:SetSize(hoverWidth, hoverHeight)
        RefreshGrid(HoverBody, viewMode)
    end
end

local function ShowMainFrame(viewMode)
    viewMode = NormalizeViewMode(viewMode)
    local uiState = YAB.GetUIState()
    local autoWidth, autoHeight = GetFrameMetrics(viewMode, false)
    local storedWidth, storedHeight = YAB.GetStoredViewSize and YAB.GetStoredViewSize(viewMode)
    local lastManualWidth, lastManualHeight
    if YAB.GetLastManualViewSize then
        lastManualWidth, lastManualHeight = YAB.GetLastManualViewSize()
    end
    local widthCap = MAX_FRAME_WIDTH
    local heightCap = MAX_FRAME_HEIGHT
    local targetWidth = tonumber(lastManualWidth) or tonumber(storedWidth) or math.max(autoWidth, MIN_FRAME_WIDTH)
    local targetHeight = autoHeight
    local width = Clamp(targetWidth, MIN_FRAME_WIDTH, widthCap)
    local height = Clamp(targetHeight, MIN_FRAME_HEIGHT, heightCap)
    HideTransientHover()
    if MainFrame.SetMinResize then
        MainFrame:SetMinResize(MIN_FRAME_WIDTH, MIN_FRAME_HEIGHT)
    end
    if MainFrame.SetMaxResize then
        MainFrame:SetMaxResize(MAX_FRAME_WIDTH, MAX_FRAME_HEIGHT)
    end
    MainFrame.viewMode = viewMode
    suppressMainFrameResizePersistence = true
    MainFrame:SetSize(width, height)
    suppressMainFrameResizePersistence = false
    if YAB.GetStoredWindowPosition then
        local point, relativePoint, x, y = YAB.GetStoredWindowPosition()
        MainFrame:ClearAllPoints()
        MainFrame:SetPoint(point or "CENTER", UIParent, relativePoint or point or "CENTER", x or 0, y or -88)
    end
    uiState.width = width
    uiState.height = height
    if MainChrome and MainChrome.subtitleText then
        local viewLabel = YAB.GetViewLabel and YAB.GetViewLabel(viewMode) or "服务器视图"
        SetLabel(MainChrome.subtitleText, viewLabel, MUTED_HEADER_COLOR)
    end
    if YAB.SyncWorldBossQuestKillsIfNeeded then
        YAB.SyncWorldBossQuestKillsIfNeeded()
    end
    if MainChrome and MainChrome.controls then
        RefreshControlButtons(MainChrome.controls, MainChrome.titleBar, viewMode)
    end
    MainFrame:Show()
    MainFrame:Raise()
    YAB.SetWindowState(true, viewMode)
    if MainScrollFrame then
        MainScrollFrame:SetVerticalScroll(0)
    end
    RefreshGrid(GridFrame, viewMode)
    RefreshMainScrollBounds()
    ScheduleMainLayoutRefresh(viewMode)
end

local function HideMainFrame()
    MainFrame:Hide()
    YAB.SetWindowState(false, MainFrame and MainFrame.viewMode or "current")
end

local function ToggleMainFrame(viewMode)
    viewMode = NormalizeViewMode(viewMode)
    if MainFrame:IsShown() and MainFrame.viewMode == viewMode then
        HideMainFrame()
    else
        ShowMainFrame(viewMode)
    end
end

local function ShowTransientHover(anchorFrame, viewMode)
    viewMode = NormalizeViewMode(viewMode)
    HoverFrame.viewMode = viewMode
    RefreshHoverBody(viewMode)
    HoverFrame:SetToplevel(true)
    HoverFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    if anchorFrame and anchorFrame.GetFrameLevel and HoverFrame.SetFrameLevel then
        HoverFrame:SetFrameLevel(math.max(HoverFrame:GetFrameLevel() or 0, (anchorFrame:GetFrameLevel() or 1) + 80))
    end
    HoverFrame:Show()
    HoverFrame:Raise()
    if YAB.GetHoverMode() ~= "simple" and HoverBody and HoverBody:IsShown() then
        RefreshGrid(HoverBody, viewMode)
    end
    AnchorFrameBelow(anchorFrame, HoverFrame)
    return true
end

HideTransientHover = function()
    if HoverFrame then
        HoverFrame:Hide()
    end
end

function YAB.HideEntryHover()
    HideTransientHover()
    if EntryAdapter and EntryAdapter.ResetHoverState then
        EntryAdapter:ResetHoverState()
    end
end

local function BuildTooltip(tooltip)
    tooltip:AddLine("YiboAltoBoss", 1, 0.82, 0.2)
    tooltip:AddLine("左键: 打开/切换当前服务器视图", 0.95, 0.95, 0.95)
    tooltip:AddLine("Shift + 左键: 打开/切换所有服务器视图", 0.95, 0.95, 0.95)
    tooltip:AddLine("右键: 打开设置页", 0.95, 0.95, 0.95)
    tooltip:AddLine("悬停: 临时显示窗口", 0.95, 0.95, 0.95)
    tooltip:AddLine("Shift + 悬停: 临时显示所有服务器视图", 0.95, 0.95, 0.95)
    local killed, total = YAB.GetBossSummary(false)
    local activeKills, tracked = YAB.GetBossPhaseSummary(false)
    tooltip:AddLine("当前服务器击杀: " .. killed .. "/" .. total, 0.72, 0.72, 0.72)
    tooltip:AddLine("当前服务器击杀计时: " .. activeKills .. " / 位面 " .. tracked, 0.72, 0.72, 0.72)
end

function YAB.IsPrimaryWindowShown()
    return MainFrame and MainFrame:IsShown() or false
end

function YAB.ToggleCurrentServerView()
    HideTransientHover()
    ToggleMainFrame("current")
end

function YAB.ToggleOtherServersView()
    HideTransientHover()
    ToggleMainFrame("other")
end

function YAB.ToggleAllServersView()
    HideTransientHover()
    ToggleMainFrame("all")
end

function YAB.ShowSettingsFromEntry()
    if YAB.ToggleSettingsWindow then
        YAB.ToggleSettingsWindow()
    end
end

function YAB.RefreshAllViews()
    if MainFrame and MainFrame:IsShown() then
        RefreshGrid(GridFrame, MainFrame.viewMode or "current")
        RefreshMainScrollBounds()
    end
    if HoverFrame and HoverFrame:IsShown() then
        RefreshHoverBody(HoverFrame.viewMode or "current")
        if EntryAdapter and EntryAdapter.hoverAnchorFrame then
            AnchorFrameBelow(EntryAdapter.hoverAnchorFrame, HoverFrame)
        end
    end
    if YAB.NotifyCorePageChanged then
        YAB.NotifyCorePageChanged()
    end
end

function YAB.RefreshEntryVisibility()
    local minimapConfig = YAB.GetMinimapConfig()
    local iconLib = type(LibStub) == "table" and LibStub.GetLibrary and LibStub:GetLibrary("LibDBIcon-1.0", true)
    local hasBrokerIcon = false
    if iconLib then
        if minimapConfig.hide then
            iconLib:Hide("YiboAltoBoss")
        else
            iconLib:Show("YiboAltoBoss")
        end
        hasBrokerIcon = iconLib:GetMinimapButton("YiboAltoBoss") ~= nil
    end
    if EntryAdapter and EntryAdapter.CreateFallbackButton and not EntryAdapter.fallbackButton then
        EntryAdapter:CreateFallbackButton()
    end
    if EntryAdapter and EntryAdapter.fallbackButton then
        if minimapConfig.hide or hasBrokerIcon then
            EntryAdapter.fallbackButton:Hide()
        else
            EntryAdapter.fallbackButton:Show()
            if EntryAdapter.UpdateFallbackPosition then
                EntryAdapter:UpdateFallbackPosition()
            end
        end
    end
end

function YAB.DebugBrokerState()
    if not (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage) then
        return
    end
    local iconLib = type(LibStub) == "table" and LibStub.GetLibrary and LibStub:GetLibrary("LibDBIcon-1.0", true)
    local minimapButton = iconLib and iconLib.GetMinimapButton and iconLib:GetMinimapButton("YiboAltoBoss") or nil
    local minimapConfig = YAB.GetMinimapConfig and YAB.GetMinimapConfig() or {}
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFD84AYiboAltoBoss:|r broker adapter=" .. tostring(EntryAdapter ~= nil)
        .. " ldb=" .. tostring(EntryAdapter and EntryAdapter.brokerDataObject ~= nil)
        .. " libdbiconButton=" .. tostring(minimapButton ~= nil)
        .. " fallback=" .. tostring(EntryAdapter and EntryAdapter.fallbackButton ~= nil)
        .. " hide=" .. tostring(minimapConfig and minimapConfig.hide)
        .. " hoverMode=" .. tostring(YAB.GetHoverMode and YAB.GetHoverMode() or "nil")
        .. " mainShown=" .. tostring(MainFrame and MainFrame:IsShown() or false))
end

function YAB.InitializeUI()
    if MainFrame then
        return
    end

    MainFrame = CreateFrame("Frame", "YiboAltoBossMainFrame", UIParent, "BackdropTemplate")
    MainFrame:SetMovable(true)
    MainFrame:SetResizable(true)
    MainFrame:SetFrameStrata("DIALOG")
    MainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -88)
    MainFrame:Hide()
    MainChrome = CreatePanelChrome(MainFrame, false)
    MainFrame:SetScript("OnSizeChanged", function(self, width, height)
        local uiState = YAB.GetUIState()
        uiState.width = math.floor(width + 0.5)
        uiState.height = math.floor(height + 0.5)
        if not suppressMainFrameResizePersistence and isUserResizingMainFrame and YAB.SetStoredViewSize then
            YAB.SetStoredViewSize(self.viewMode or "current", width, height)
        end
        if not suppressMainFrameResizePersistence and isUserResizingMainFrame and YAB.SetLastManualViewSize then
            YAB.SetLastManualViewSize(width, height)
        end
        if ResizeHandle then
            ResizeHandle:ClearAllPoints()
            ResizeHandle:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -4, 4)
        end
        RefreshMainScrollBounds()
        if self:IsShown() then
            RefreshGrid(GridFrame, self.viewMode or "current")
            ScheduleMainLayoutRefresh(self.viewMode or "current")
        end
    end)
    MainFrame:SetScript("OnHide", function()
        YAB.SetWindowState(false, MainFrame and MainFrame.viewMode or "current")
    end)

    MainControls.current = CreateActionButton(MainChrome.titleBar, "当前服务器", 84, function()
        ShowMainFrame("current")
    end)

    MainControls.other = CreateActionButton(MainChrome.titleBar, "其它服务器", 84, function()
        ShowMainFrame("other")
    end)

    MainControls.all = CreateActionButton(MainChrome.titleBar, "所有服务器", 84, function()
        ShowMainFrame("all")
    end)

    MainControls.settings = CreateActionButton(MainChrome.titleBar, "设置", 52, function()
        if YAB.ToggleSettingsWindow then
            YAB.ToggleSettingsWindow()
        end
    end)

    MainControls.close = CreateActionButton(MainChrome.titleBar, "关闭", 52, function()
        HideMainFrame()
    end)
    MainChrome.controls = MainControls
    RefreshControlButtons(MainControls, MainChrome.titleBar, "current")

    MainScrollFrame = CreateFrame("ScrollFrame", nil, MainChrome.contentPanel, "UIPanelScrollFrameTemplate")
    SetMainScrollReserve(false)
    MainScrollFrame:EnableMouseWheel(true)
    MainScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local nextValue = current - (delta * 36)
        local maxScroll = math.max((GridFrame and GridFrame.contentHeight or 0) - GetMainContentViewportHeight(), 0)
        self:SetVerticalScroll(Clamp(nextValue, 0, maxScroll))
        RefreshMainScrollBounds()
    end)

    GridFrame = CreateFrame("Frame", nil, MainScrollFrame)
    GridFrame.chrome = MainChrome
    GridFrame:SetPoint("TOPLEFT", MainScrollFrame, "TOPLEFT", 0, 0)
    GridFrame:SetSize(1, 1)
    MainScrollFrame:SetScrollChild(GridFrame)
    local scrollBar = GetMainScrollBar()
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPLEFT", MainScrollFrame, "TOPRIGHT", 4, -16)
        scrollBar:SetPoint("BOTTOMLEFT", MainScrollFrame, "BOTTOMRIGHT", 4, 16)
        scrollBar:SetWidth(16)
        scrollBar:SetShown(false)
    end

    ResizeHandle = CreateFrame("Button", nil, MainFrame)
    ResizeHandle:SetSize(18, 18)
    ResizeHandle:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -4, 4)
    ResizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    ResizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    ResizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    ResizeHandle:SetScript("OnMouseDown", function()
        isUserResizingMainFrame = true
        if MainFrame.StartSizing then
            MainFrame:StartSizing("RIGHT")
        end
    end)
    ResizeHandle:SetScript("OnMouseUp", function()
        isUserResizingMainFrame = false
        MainFrame:StopMovingOrSizing()
        if MainFrame then
            local finalWidth = MainFrame:GetWidth()
            local finalHeight = MainFrame:GetHeight()
            if YAB.SetStoredViewSize then
                YAB.SetStoredViewSize(MainFrame.viewMode or "current", finalWidth, finalHeight)
            end
            if YAB.SetLastManualViewSize then
                YAB.SetLastManualViewSize(finalWidth, finalHeight)
            end
        end
        YAB.PersistDB()
    end)

    HoverFrame = CreateFrame("Frame", "YiboAltoBossHoverFrame", UIParent, "BackdropTemplate")
    HoverFrame:Hide()
    HoverFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    HoverFrame:SetScale(YAB.GetHoverScale and YAB.GetHoverScale() or 1)
    HoverChrome = CreatePanelChrome(HoverFrame, true)

    HoverControls.current = CreateActionButton(HoverChrome.titleBar, "当前服务器", 84, function()
        HoverFrame.viewMode = "current"
        RefreshHoverBody("current")
    end)
    HoverControls.other = CreateActionButton(HoverChrome.titleBar, "其它服务器", 84, function()
        HoverFrame.viewMode = "other"
        RefreshHoverBody("other")
    end)
    HoverControls.all = CreateActionButton(HoverChrome.titleBar, "所有服务器", 84, function()
        HoverFrame.viewMode = "all"
        RefreshHoverBody("all")
    end)
    HoverControls.settings = CreateActionButton(HoverChrome.titleBar, "设置", 52, function()
        HideTransientHover()
        if YAB.ToggleSettingsWindow then
            YAB.ToggleSettingsWindow()
        end
    end)
    HoverControls.close = CreateActionButton(HoverChrome.titleBar, "关闭", 52, function()
        HideTransientHover()
    end)
    HoverChrome.controls = HoverControls
    RefreshControlButtons(HoverControls, HoverChrome.titleBar, "current")

    HoverBody = CreateFrame("Frame", nil, HoverChrome.contentPanel)
    HoverBody.chrome = HoverChrome
    HoverBody:SetPoint("TOPLEFT", HoverChrome.contentPanel, "TOPLEFT", 8, -8)
    HoverBody:SetPoint("BOTTOMRIGHT", HoverChrome.contentPanel, "BOTTOMRIGHT", -8, 4)

    HoverSimpleBody = CreateFrame("Frame", nil, HoverChrome.contentPanel)
    HoverSimpleBody:SetPoint("TOPLEFT", HoverChrome.contentPanel, "TOPLEFT", 8, -8)
    HoverSimpleBody:SetPoint("BOTTOMRIGHT", HoverChrome.contentPanel, "BOTTOMRIGHT", -8, 4)
    HoverSimpleBody:Hide()

    -- 2.0 起由 YiboCore 持有默认 Broker 与小地图入口。2.1 将在 Core
    -- 页面内重建同一份网格投影；在此之前旧窗口只由 Core 页面或 /yab 打开。
    EntryAdapter = nil
    YAB.EntryAdapter = nil
    YAB.BrokerLauncher = nil

    local uiState = YAB.GetUIState()
    if uiState.windowShown and not (YAB.CoreIntegration and YAB.CoreIntegration.initialized) then
        ShowMainFrame(uiState.viewMode or (uiState.showAllServers and "all" or "current"))
    end

    YAB.RefreshEntryVisibility()
end
