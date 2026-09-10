local YAB = _G.YAB
local Theme = _G.YiboCore.UITheme
local C = Theme.Colors

local BOSS_WIDTH, ACTION_WIDTH, PHASE_WIDTH = 88, 88, 72
-- The shared width uses the live roster between four and six CJK glyphs, so
-- pooled cells cannot cause header overlap when the matrix direction changes.
local CHARACTER_MIN_WIDTH = Theme:GetCharacterMatrixColumnWidth()
local HEADER_H, COMPACT_HEADER_H, ROW_H, CELL_H = Theme.Table.groupHeight, Theme.Table.headerHeight, Theme.Table.rowHeight, 24
local GROUP_GAP = 2
local FIXED_CELL = { 0.025, 0.145, 0.16, 0.98 }

local function Text(parent, size, justify, color)
    return Theme:CreateText(parent, size or Theme.Font.body, color or C.text, justify or "LEFT")
end

local function Button(parent, width, label)
    return Theme:CreateButton(parent, width, label)
end

local function Release(pool, start)
    for index = start or 1, #pool do pool[index]:Hide() end
end

local function CharacterInfo(key)
    local info = (YiboAltoBossDB and YiboAltoBossDB.knownChars and YiboAltoBossDB.knownChars[key]) or {}
    return info.name or key:match("^(.-)-") or key, info.realm or key:match("-(.+)$") or "未知服务器"
end

local function CharacterColor(key)
    local info = (YiboAltoBossDB and YiboAltoBossDB.knownChars and YiboAltoBossDB.knownChars[key]) or {}
    local class = info.class
    if not class and _G.YiboCore and _G.YiboCore.Characters then
        local name, realm = CharacterInfo(key)
        for _, character in ipairs(_G.YiboCore.Characters:GetAll()) do
            if character.name == name and character.realm == realm then class = character.class; break end
        end
    end
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return color or C.text
end

local function VisualTextUnits(value)
    local text = tostring(value or "")
    local units, index, length = 0, 1, #text
    while index <= length do
        local byte = text:byte(index)
        if byte < 128 then
            units = units + (byte == 32 and 0.35 or 0.58)
            index = index + 1
        elseif byte < 224 then
            units = units + 1
            index = index + 2
        elseif byte < 240 then
            units = units + 1
            index = index + 3
        else
            units = units + 1
            index = index + 4
        end
    end
    return units
end

local function GetCharacterColumnMetrics(key, context, resolvedWidth)
    local titleFont = Theme.Font.assist
    return resolvedWidth or Theme:GetCharacterMatrixColumnWidth(context), titleFont
end

local function ScopeRealm(scope)
    return type(scope) == "string" and scope:match("^realm:(.+)$") or nil
end

local function ScopeControlsWidth(context)
    return 32 + (#(context and context.scopeDefinition and context.scopeDefinition.values or {}) * 104)
end

local function GetHeaderHeight(context)
    return Theme:GetCharacterHeaderHeight(context)
end

local function GetCharacterRowLabel(key, context)
    local name, realm = CharacterInfo(key)
    if context and context.scope == "all" then return name .. " - " .. realm end
    return name
end

local function GetCharacterRowWidth(keys, context)
    local width = 180
    for _, key in ipairs(keys or {}) do
        width = math.max(width, Theme:MeasureText(Theme.Font.body, GetCharacterRowLabel(key, context)) + Theme.Space.lg * 2)
    end
    -- A long realm name may widen the identity column, but must not turn the
    -- boss grid into a mostly-empty character label strip.
    return math.min(300, width)
end

-- In the transposed layout this is the frozen Boss identity column, not a
-- compact data column. Measure the current target names so Chinese labels
-- remain fully legible instead of inheriting the 88px status-cell width.
local function GetBossRowLabelWidth(bosses)
    local width = Theme:MeasureText(Theme.Font.body, "Boss / 目标")
    for _, boss in ipairs(bosses or {}) do
        width = math.max(width, Theme:MeasureText(Theme.Font.body, boss.name or ""))
    end
    return math.ceil(width + Theme.Table.cellPadding * 2 + Theme.Table.iconTextRasterTolerance)
end

local function FormatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    if seconds < 60 then return tostring(seconds) .. "秒" end
    if seconds < 3600 then return tostring(math.floor(seconds / 60)) .. "分" end
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    return minutes > 0 and (hours .. "时" .. minutes .. "分") or (hours .. "时")
end

local function FormatClock(timestamp)
    return date and date("%H:%M", timestamp) or "待定"
end

local function GetScopedPhaseStates(boss, scope)
    local selectedRealm = ScopeRealm(scope)
    local result = {}
    for _, column in ipairs(YAB.GetPhaseColumns("all")) do
        if not selectedRealm or column.realm == selectedRealm then
            local state = YAB.GetBossPhaseState(boss.key, column)
            if state then result[#result + 1] = { state = state, column = column } end
        end
    end
    return result
end

local function BuildActionCandidate(state, column)
    if not state then return nil end
    local now = YAB.GetServerTimestamp()
    local candidate = {
        state = state,
        column = column,
        realm = state.realm or column.realm or YAB.GetCurrentRealm(),
        phaseDisplayId = state.phaseDisplayId or column.displayId or "00",
        phaseLabel = state.phaseLabel or column.label or "未知",
        priority = 0,
        orderValue = math.huge,
        text = "—",
        kind = "empty",
    }
    if state.lastKilledAt and state.respawnEstimateSeconds and (state.respawnEstimateSamples or 0) > 0 then
        local minSeconds = state.respawnEstimateMinSeconds or state.respawnEstimateSeconds
        local maxSeconds = state.respawnEstimateMaxSeconds or state.respawnEstimateSeconds
        local startsAt, endsAt = state.lastKilledAt + minSeconds, state.lastKilledAt + maxSeconds
        if now < startsAt then
            local remaining = startsAt - now
            if remaining <= 600 then
                candidate.text, candidate.kind, candidate.priority = FormatDuration(remaining) .. "后", "soon", 6
            else
                candidate.text, candidate.kind, candidate.priority = FormatClock(startsAt), "scheduled", 5
            end
            candidate.orderValue = remaining
        elseif now <= endsAt then
            candidate.text, candidate.kind, candidate.priority = "窗口中", "window", 7
            candidate.orderValue = endsAt - now
        else
            candidate.text, candidate.kind, candidate.priority = "已过", "overdue", 4
            candidate.orderValue = now - endsAt
        end
        return candidate
    end
    if state.lastKilledAt then
        candidate.text, candidate.kind, candidate.priority = "样本少", "weak", 3
        candidate.orderValue = now - state.lastKilledAt
        return candidate
    end
    if state.observedAt then
        candidate.text, candidate.kind, candidate.priority = "仅观测", "observed", 2
        candidate.orderValue = now - state.observedAt
        return candidate
    end
end

local function PickBestAction(boss, scope)
    local best
    for _, item in ipairs(GetScopedPhaseStates(boss, scope)) do
        local candidate = BuildActionCandidate(item.state, item.column)
        if candidate and (not best
            or candidate.priority > best.priority
            or (candidate.priority == best.priority and candidate.orderValue < best.orderValue)) then
            best = candidate
        end
    end
    return best
end

local function GetHistoricalPrediction(boss)
    return YAB.GetBossRespawnEstimate(boss.key or boss.id)
end

local function AddTooltipPair(lines, label, value, valueColor)
    if value == nil or value == "" then return end
    lines[#lines + 1] = { kind = "pair", label = label, value = value, valueColor = valueColor }
end

local function AddTooltipSection(lines, text)
    if #lines > 0 then lines[#lines + 1] = { kind = "spacer" } end
    lines[#lines + 1] = { kind = "section", text = text }
end

local function AppendPredictionLines(lines, estimate, lastKilledAt, sectionTitle)
    local samples = tonumber(estimate.respawnEstimateSamples or estimate.sampleCount) or 0
    if samples <= 0 then return end

    local mode = estimate.respawnEstimateMode or estimate.mode
    local effectiveSamples = tonumber(estimate.respawnEstimateEffectiveSamples or estimate.effectiveSampleCount) or 0
    local excludedSamples = tonumber(estimate.respawnEstimateExcludedSamples or estimate.excludedSampleCount)
        or math.max(0, samples - effectiveSamples)
    local observedMin = estimate.respawnEstimateObservedMinSeconds or estimate.minSeconds
    local observedMax = estimate.respawnEstimateObservedMaxSeconds or estimate.maxSeconds
    local predictedMin = estimate.respawnEstimateMinSeconds or estimate.windowMinSeconds or estimate.respawnEstimateSeconds or estimate.estimateSeconds
    local predictedMax = estimate.respawnEstimateMaxSeconds or estimate.windowMaxSeconds or estimate.respawnEstimateSeconds or estimate.estimateSeconds
    local confidence = estimate.respawnEstimateConfidence or estimate.confidence
    local realmCount = tonumber(estimate.respawnEstimateRealmCount or estimate.sampleRealmCount) or 0
    local v3Samples = tonumber(estimate.respawnEstimateV3Samples or estimate.v3SampleCount) or 0
    local legacySamples = tonumber(estimate.respawnEstimateLegacySamples or estimate.legacySampleCount) or 0

    AddTooltipSection(lines, sectionTitle or "刷新预测")
    if predictedMin and predictedMax then
        local predictionText
        if predictedMax > predictedMin then
            predictionText = FormatDuration(predictedMin) .. " – " .. FormatDuration(predictedMax)
        else
            predictionText = FormatDuration(predictedMin)
        end
        AddTooltipPair(lines, "预计刷新", predictionText, C.accent)
        if lastKilledAt then
            local startsAt, endsAt = lastKilledAt + predictedMin, lastKilledAt + predictedMax
            if endsAt > startsAt then
                AddTooltipPair(lines, "预计时段", FormatClock(startsAt) .. " – " .. FormatClock(endsAt), C.accent)
            else
                AddTooltipPair(lines, "预计时刻", FormatClock(startsAt), C.accent)
            end
        end
    end
    if observedMin then
        local observedText = FormatDuration(observedMin)
        if observedMax and observedMax ~= observedMin then observedText = observedText .. " – " .. FormatDuration(observedMax) end
        AddTooltipPair(lines, "实测范围", observedText)
    end
    if estimate.lastRespawnSampleSeconds then
        AddTooltipPair(lines, "最近实测", FormatDuration(estimate.lastRespawnSampleSeconds))
    end
    if realmCount > 0 then AddTooltipPair(lines, "样本来源", realmCount .. " 个服务器") end
    AddTooltipPair(lines, "已完成样本", tostring(samples))
    if v3Samples > 0 then AddTooltipPair(lines, "v3 实测", tostring(v3Samples)) end
    if legacySamples > 0 then AddTooltipPair(lines, "v2 历史参考", tostring(legacySamples)) end
    AddTooltipPair(lines, "参与预测", tostring(effectiveSamples > 0 and effectiveSamples or samples))
    if excludedSamples > 0 then AddTooltipPair(lines, "排除异常", tostring(excludedSamples)) end
    local modelText = mode == "fixed" and "固定刷新" or "区间刷新"
    if confidence then modelText = modelText .. " · " .. tostring(confidence) end
    AddTooltipPair(lines, "模型", modelText)
end

local function BuildActionTooltip(boss, candidate, scope)
    if not candidate then
        local estimate = GetHistoricalPrediction(boss)
        if not estimate then return { { text = "暂无近期位面记录或可用共享刷新样本。", color = C.muted } } end
        local lines = { { text = "近期位面记录已过期，显示跨服务器共享样本。", color = C.muted } }
        AppendPredictionLines(lines, estimate, nil, "共享刷新模型")
        return lines
    end
    local state, now = candidate.state, YAB.GetServerTimestamp()
    local statusColors = { window = C.success, soon = C.accent, scheduled = C.accent, overdue = C.danger, weak = C.muted, observed = C.muted }
    local lines = {}
    AddTooltipPair(lines, "状态", candidate.text, statusColors[candidate.kind] or C.text)
    local displayID = tostring(candidate.phaseDisplayId or "00")
    local phaseLabel = tostring(candidate.phaseLabel or "")
    local target = "位面 " .. displayID
    if phaseLabel ~= "" and phaseLabel ~= "未知" and phaseLabel ~= displayID then target = target .. " · " .. phaseLabel end
    if scope == "all" then target = tostring(candidate.realm) .. " · " .. target end
    AddTooltipPair(lines, "目标", target)
    if state.lastKilledAt then AddTooltipPair(lines, "计时起点", FormatDuration(now - state.lastKilledAt) .. "前") end
    if (tonumber(state.pendingCycleCount) or 0) > 0 then
        AddTooltipPair(lines, "待完成周期", tostring(state.pendingCycleCount) .. " · 等待下一次刷新", C.accent)
    end
    AppendPredictionLines(lines, state, state.lastKilledAt, "共享刷新模型")
    return lines
end

local function BuildPhaseSummary(boss, scope)
    local items = GetScopedPhaseStates(boss, scope)
    local killed, observed = 0, 0
    local lines = {}
    table.sort(items, function(left, right)
        local leftAt = math.max(tonumber(left.state.lastKilledAt) or 0, tonumber(left.state.observedAt) or 0)
        local rightAt = math.max(tonumber(right.state.lastKilledAt) or 0, tonumber(right.state.observedAt) or 0)
        return leftAt > rightAt
    end)
    for _, item in ipairs(items) do
        local state, column = item.state, item.column
        if state.lastKilledAt then killed = killed + 1 elseif state.observedAt then observed = observed + 1 end
        local displayID = tostring(state.phaseDisplayId or column.displayId or "00")
        local sectionTitle = "位面 " .. displayID
        if scope == "all" then sectionTitle = tostring(column.realm) .. " · " .. sectionTitle end
        AddTooltipSection(lines, sectionTitle)
        local phaseLabel = tostring(state.phaseLabel or column.label or "")
        if phaseLabel ~= "" and phaseLabel ~= "未知" and phaseLabel ~= displayID then
            AddTooltipPair(lines, "位面标识", phaseLabel)
        end
        if state.observedAt then AddTooltipPair(lines, "最近观测", FormatDuration(YAB.GetServerTimestamp() - state.observedAt) .. "前") end
        if state.lastKilledAt then AddTooltipPair(lines, "最近击杀", FormatDuration(YAB.GetServerTimestamp() - state.lastKilledAt) .. "前") end
        if state.lastObservedBy then AddTooltipPair(lines, "观测角色", tostring(state.lastObservedBy)) end
        if state.lastKilledBy then AddTooltipPair(lines, "击杀角色", tostring(state.lastKilledBy)) end
        if state.zone and state.zone ~= "" then AddTooltipPair(lines, "区域", tostring(state.zone)) end
        if state.subZone and state.subZone ~= "" and state.subZone ~= state.zone then
            AddTooltipPair(lines, "子区域", tostring(state.subZone))
        end
    end
    local summary = "—"
    if killed > 0 and observed > 0 then summary = killed .. "击/" .. observed .. "观"
    elseif killed > 0 then summary = killed .. "击"
    elseif observed > 0 then summary = observed .. "观" end
    if #lines == 0 then lines[1] = { text = "暂无 6 小时内的位面记录。", color = C.muted } end
    return summary, lines, killed > 0, observed > 0
end

local function GetHeader(instance, index)
    local header = instance.headers[index]
    if header then return header end
    header = Theme:CreateMatrixHeader(instance.header)
    instance.headers[index] = header
    return header
end

local function GetRow(instance, index)
    local row = instance.rows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, instance.body, "BackdropTemplate")
    row:SetHeight(ROW_H)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    row.fixedBackground = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.fixedBackground:SetPoint("TOPLEFT")
    row.fixedBackground:SetPoint("BOTTOMLEFT")
    row.fixedBackground:SetColorTexture(FIXED_CELL[1], FIXED_CELL[2], FIXED_CELL[3], FIXED_CELL[4])
    row.groupGap = row:CreateTexture(nil, "ARTWORK")
    row.groupGap:SetWidth(GROUP_GAP)
    row.groupGap:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 1)
    row.name = Text(row, Theme.Font.body, "LEFT", C.text); row.name:SetWidth(BOSS_WIDTH - 12)
    row.professionIcon = row:CreateTexture(nil, "ARTWORK"); row.professionIcon:SetSize(16, 16)
    row.currentOutline = Theme:CreateCurrentCharacterOutline(row)
    row.action = Button(row, ACTION_WIDTH - 2, "—"); row.action:SetHeight(CELL_H)
    row.phase = Button(row, PHASE_WIDTH - 2, "—"); row.phase:SetHeight(CELL_H)
    row.cells = {}
    instance.rows[index] = row
    return row
end

local function GetCell(row, index)
    local cell = row.cells[index]
    if cell then return cell end
    cell = Button(row, CHARACTER_MIN_WIDTH - 2, "")
    cell:SetHeight(CELL_H)
    row.cells[index] = cell
    return cell
end

local function SetSemanticButton(control, text, fill, title, lines)
    control:SetText(text)
    control:SetState("default")
    control:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
    control.label:SetTextColor(C.text[1], C.text[2], C.text[3])
    Theme:BindTooltip(control, title, lines)
end

local function SetEmptyButton(control)
    control:SetText("")
    control:SetState("disabled")
    control:SetBackdropColor(FIXED_CELL[1], FIXED_CELL[2], FIXED_CELL[3], FIXED_CELL[4])
    control:SetScript("OnEnter", nil)
    control:SetScript("OnLeave", nil)
    control:SetScript("OnClick", nil)
end

local function SetStatus(cell, status, key, boss)
    local killed = status == "killed"
    cell:SetText(killed and "已击杀" or "未击杀")
    cell:SetState("default")
    if killed then
        cell:SetBackdropColor(C.successSurface[1], C.successSurface[2], C.successSurface[3], C.successSurface[4])
        cell:SetBackdropBorderColor(C.success[1], C.success[2], C.success[3], C.success[4])
        cell.label:SetTextColor(C.success[1], C.success[2], C.success[3])
    else
        cell:SetBackdropColor(C.chrome[1], C.chrome[2], C.chrome[3], C.chrome[4])
        cell:SetBackdropBorderColor(C.matrixLine[1], C.matrixLine[2], C.matrixLine[3], C.matrixLine[4])
        cell.label:SetTextColor(C.text[1], C.text[2], C.text[3])
    end
    cell:SetScript("OnLeave", function(control)
        if killed then control:SetBackdropColor(C.successSurface[1], C.successSurface[2], C.successSurface[3], C.successSurface[4])
        else control:SetBackdropColor(C.chrome[1], C.chrome[2], C.chrome[3], C.chrome[4]) end
        local labelColor = killed and C.success or C.text
        control.label:SetTextColor(labelColor[1], labelColor[2], labelColor[3])
        local border = killed and C.success or C.matrixLine
        control:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
    end)
    cell:SetScript("OnClick", function() YAB.ToggleBossKill(key, boss.key) end)
end

local function RefreshHeaders(instance, context, keys, showAction, showPhase, showKills, bossNameWidth)
    local x, index = 0, 0
    local headerHeight = GetHeaderHeight(context)
    instance.currentColumnX = nil
    instance.header:SetHeight(headerHeight)
    instance.characterWidths = {}
    instance.currentColumnWidth = nil
    local function Place(title, width, sub, titleColor, fixedArea, titleFont)
        index = index + 1
        local header = GetHeader(instance, index)
        header:ClearAllPoints(); header:SetPoint("TOPLEFT", instance.header, "TOPLEFT", x, 0); header:SetSize(width, headerHeight)
        local color = titleColor or C.muted
        local fill = C.toolbar
        Theme:SetMatrixHeader(header, title, { height=headerHeight, secondary=sub, color=color, fill=fill, rule=C.lineSoft })
        header.title:SetFont(STANDARD_TEXT_FONT, titleFont or Theme.Font.assist)
        header:Show(); x = x + width
        return header
    end
    Place("Boss / 目标", bossNameWidth, nil, nil, true)
    if showAction then Place("行动", ACTION_WIDTH, nil, nil, true) end
    if showPhase then Place("位面", PHASE_WIDTH, nil, nil, true) end
    instance.fixedWidth = x
    instance.header.fixedDivider:ClearAllPoints()
    instance.header.fixedDivider:SetPoint("TOPLEFT", instance.header, "TOPLEFT", instance.fixedWidth, 0)
    instance.header.fixedDivider:SetPoint("BOTTOMLEFT", instance.header, "BOTTOMLEFT", instance.fixedWidth, 0)
    instance.header.fixedDivider:SetShown(showKills)
    if showKills then
        x = x + GROUP_GAP
        local currentKey = YAB.GetCurrentCharKey()
        for characterIndex, key in ipairs(keys) do
            local name, realm = CharacterInfo(key)
            -- The realm is redundant in a realm-scoped view.  Keep the second
            -- header line exclusively for the cross-realm comparison where it
            -- disambiguates characters with the same name.
            local realmSubtitle = context.scope == "all" and realm or ""
            local columnWidth, titleFont = GetCharacterColumnMetrics(key, context, instance.characterColumnWidth)
            instance.characterWidths[characterIndex] = columnWidth
            if key == currentKey then
                instance.currentColumnX = x
                instance.currentColumnWidth = columnWidth
            end
            local header = Place(name, columnWidth, realmSubtitle, CharacterColor(key), false, titleFont)
            Theme:BindTooltip(header, name .. "-" .. realm)
        end
    end
    Release(instance.headers, index + 1)
    instance.gridWidth = x
end

function YAB.CreateAccountPage(parent)
    parent:SetClipsChildren(true)
    parent.title = Text(parent, Theme.Font.title, "LEFT", C.text); parent.title:SetPoint("TOPLEFT", Theme.Space.lg, -Theme.Space.md)
    parent.summary = Text(parent, Theme.Font.body, "RIGHT", C.muted); parent.summary:SetPoint("TOPRIGHT", -Theme.Space.lg, -Theme.Space.md)
    parent.scopeButtons = {}
    parent.header = CreateFrame("Frame", nil, parent); parent.header:SetHeight(HEADER_H)
    parent.header.fixedDivider = parent.header:CreateTexture(nil, "ARTWORK")
    parent.header.fixedDivider:SetWidth(GROUP_GAP)
    parent.header.fixedDivider:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 1)
    parent.scroll = Theme:CreateScrollFrame(parent)
    parent.scroll:BindScrollbarGutter(parent.header)
    parent.body = CreateFrame("Frame", nil, parent.scroll); parent.scroll:SetScrollChild(parent.body)
    parent.currentColumnOutline = Theme:CreateCurrentCharacterOutline(parent)
    parent.headers, parent.rows = {}, {}
end

local function RefreshCurrentColumnOutline(instance, bosses, showKills)
    local outline = instance.currentColumnOutline
    if not showKills or not instance.currentColumnX then
        Theme:SetCurrentCharacterOutline(outline, false)
        return
    end
    Theme:UpdateCurrentCharacterColumnOutline(outline, instance.header, instance.scroll, instance.currentColumnX, instance.currentColumnWidth or CHARACTER_MIN_WIDTH, true)
end

-- Transposed matrix: Bosses stay on rows while Core paginates character
-- columns as one consistent header/data slice.
local function RefreshAccountPageByCharacterColumns(instance, context)
    local preview = context.preview == true
    local allKeys, bosses = YAB.GetAccountCharacterKeys(context), YAB.GetBossList()
    local showKills = context:GetFieldVisible("kills")
    local showAction = context:GetFieldVisible("action")
    local showPhase = context:GetFieldVisible("phase")
    local bossNameWidth = GetBossRowLabelWidth(bosses)
    -- Core's title bar and shared scope bar already identify this view and its
    -- active server range.  Keeping a second page title consumed a full blank
    -- row between the scope controls and matrix.
    instance.title:SetShown(false)
    instance.summary:SetShown(false)

    Release(instance.scopeButtons, 1)

    instance.header:ClearAllPoints(); instance.scroll:ClearAllPoints()
    -- The page instance begins immediately below Core's shared scope bar.
    -- Keep only the compact visual gap before the matrix; the previous 44 px
    -- offset reserved a now-removed local title/control row.
    local inset = Theme:GetMatrixInsets(preview)
    local matrixTop = -inset.top
    instance.header:SetPoint("TOPLEFT", inset.left, matrixTop)
    instance.header:SetPoint("TOPRIGHT", -inset.right, matrixTop)
    instance.scroll:SetPoint("TOPLEFT", instance.header, "BOTTOMLEFT", 0, -Theme.Space.xs)
    instance.scroll:SetPoint("BOTTOMRIGHT", -inset.right, inset.bottom)
    local fixedWidth = bossNameWidth + (showAction and ACTION_WIDTH or 0) + (showPhase and PHASE_WIDTH or 0) + (showKills and GROUP_GAP or 0)
    -- Core has already measured the complete roster and selected this pass's
    -- final surface width.  Header anchors may still report the previous page
    -- width immediately after that resize, which used to make one extra
    -- character trigger pagination prematurely.
    local characterWidth = Theme:GetCharacterMatrixColumnWidth(context)
    local availableWidth = math.max(
        fixedWidth + characterWidth,
        (tonumber(context.surfaceAvailableWidth) or instance:GetWidth() or 1) - inset.left - inset.right
    )
    instance.characterColumnWidth = characterWidth
    local keys, pageInfo = _G.YiboCore.AccountView:GetColumnPage("alto-boss", "characters", allKeys, availableWidth, fixedWidth, instance.characterColumnWidth, YAB.GetCurrentCharKey and YAB.GetCurrentCharKey() or nil)
    _G.YiboCore.AccountView:UpdateColumnPager(instance, "alto-boss", "characters", pageInfo, instance.header, "角色")
    RefreshHeaders(instance, context, keys, showAction, showPhase, showKills, bossNameWidth)

    for rowIndex, boss in ipairs(bosses) do
        local row = GetRow(instance, rowIndex)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", instance.body, "TOPLEFT", 0, -((rowIndex - 1) * ROW_H)); row:SetSize(instance.gridWidth, ROW_H)
        local rowTone = Theme:GetDataRowColor(rowIndex)
        row:SetBackdropColor(rowTone[1], rowTone[2], rowTone[3], rowTone[4] or 0.88)
        row:SetBackdropBorderColor(C.matrixLine[1], C.matrixLine[2], C.matrixLine[3], C.matrixLine[4])
        -- The frozen boss/action segment is still part of this data row.
        -- Give it the same parity tone instead of a single flat slab.
        row.fixedBackground:SetColorTexture(rowTone[1], rowTone[2], rowTone[3], rowTone[4] or 0.88)
        local columnWidths = { { width = bossNameWidth } }
        if showAction then columnWidths[#columnWidths + 1] = { width = ACTION_WIDTH } end
        if showPhase then columnWidths[#columnWidths + 1] = { width = PHASE_WIDTH } end
        for _ = 1, #keys do columnWidths[#columnWidths + 1] = { width = instance.characterColumnWidth } end
        Theme:ApplyDataColumnTints(row, columnWidths, ROW_H)
        row.fixedBackground:SetWidth(instance.fixedWidth)
        row.groupGap:ClearAllPoints()
        row.groupGap:SetPoint("TOPLEFT", row, "TOPLEFT", instance.fixedWidth, 0)
        row.groupGap:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", instance.fixedWidth, 0)
        row.groupGap:SetShown(showKills)
        local x = 0
        row.name:ClearAllPoints(); row.name:SetPoint("LEFT", row, "LEFT", Theme.Table.cellPadding, 0); row.name:SetWidth(Theme:GetTableCellContentWidth(bossNameWidth)); row.name:SetText(boss.name); x = x + bossNameWidth

        row.action:ClearAllPoints(); row.action:SetShown(showAction)
        if showAction then
            row.action:SetPoint("LEFT", x + 1, 0); x = x + ACTION_WIDTH
            if boss.hideAction then
                SetEmptyButton(row.action)
            else
                local candidate = PickBestAction(boss, context.scope)
                local fills = { window = C.successSurface, soon = C.successSurface, scheduled = C.selected, weak = C.timer, observed = C.current, overdue = C.dangerSurface }
                SetSemanticButton(row.action, candidate and candidate.text or "—", fills[candidate and candidate.kind or ""] or FIXED_CELL, boss.name .. " / 行动", BuildActionTooltip(boss, candidate, context.scope))
            end
        end

        row.phase:ClearAllPoints(); row.phase:SetShown(showPhase)
        if showPhase then
            row.phase:SetPoint("LEFT", x + 1, 0); x = x + PHASE_WIDTH
            if boss.hidePhase then
                SetEmptyButton(row.phase)
            else
                local summary, lines, hasKill, hasObserve = BuildPhaseSummary(boss, context.scope)
                local fill = hasKill and C.timer or (hasObserve and C.current or FIXED_CELL)
                SetSemanticButton(row.phase, summary, fill, boss.name .. " / 位面", lines)
            end
        end

        if showKills then
            x = x + GROUP_GAP
            for cellIndex, key in ipairs(keys) do
                local cell = GetCell(row, cellIndex)
                local columnWidth = instance.characterWidths[cellIndex] or instance.characterColumnWidth or CHARACTER_MIN_WIDTH
                cell:SetWidth(columnWidth - 2)
                cell:ClearAllPoints(); cell:SetPoint("LEFT", x + 1, 0); cell:SetShown(true)
                SetStatus(cell, YAB.GetBossKillStatus(key, boss.key), key, boss)
                x = x + columnWidth
            end
        end
        Release(row.cells, showKills and (#keys + 1) or 1)
        row:Show()
    end
    Release(instance.rows, #bosses + 1)
    instance.body:SetSize(instance.gridWidth, math.max(#bosses * ROW_H, 1))
    instance.scroll:SetContentHeight(instance.body:GetHeight())
    if preview then instance.scroll:SetVerticalScroll(0) end
    instance.scroll:RefreshScrollbar()
    RefreshCurrentColumnOutline(instance, bosses, showKills)
end

-- Default matrix: characters are rows and Bosses are the stable comparison
-- columns. The alternate, transposed arrangement is selected in Core's
-- display settings above.
local function RefreshBossColumnHeaders(instance, bosses, showBossColumns, characterWidth)
    local x, index = 0, 0
    -- Character identity lives in row headers for this view. Its table header
    -- is therefore always a normal single-line header in every scope.
    local headerHeight = Theme.Table.headerHeight
    instance.header:SetHeight(headerHeight)
    local function Place(title, width, sub, color, fixed)
        index = index + 1
        local header = GetHeader(instance, index)
        header:ClearAllPoints(); header:SetPoint("TOPLEFT", instance.header, "TOPLEFT", x, 0); header:SetSize(width, headerHeight)
        local textColor = color or C.muted; local fill = C.toolbar
        Theme:SetMatrixHeader(header,title,{height=headerHeight,secondary=sub,color=textColor,fill=fill,rule=C.lineSoft});header:Show()
        x = x + width
    end
    Place("角色", characterWidth, nil, nil, true)
    if showBossColumns then
        for _, boss in ipairs(bosses) do
            Place(boss.name, BOSS_WIDTH)
        end
    end
    Release(instance.headers, index + 1)
    instance.fixedWidth, instance.gridWidth = characterWidth, x
    instance.header.fixedDivider:Hide()
end

function YAB.RefreshAccountPage(instance, context)
    if context.viewMode == "character-columns" then
        return RefreshAccountPageByCharacterColumns(instance, context)
    end
    local preview = context.preview == true
    local keys, bosses = YAB.GetAccountCharacterKeys(context), YAB.GetBossList()
    local showKills = context:GetFieldVisible("kills")
    local showAction = context:GetFieldVisible("action")
    local showPhase = context:GetFieldVisible("phase")
    local showBossColumns = showKills or showAction or showPhase
    local inset = Theme:GetMatrixInsets(preview)
    local characterWidth = Theme:GetCharacterRowHeaderWidth(true, context, context.characters)

    instance.title:Hide(); instance.summary:Hide(); Release(instance.scopeButtons, 1)
    instance.header:ClearAllPoints(); instance.scroll:ClearAllPoints()
    instance.header:SetPoint("TOPLEFT", inset.left, -inset.top)
    instance.header:SetPoint("TOPRIGHT", -inset.right, -inset.top)
    instance.scroll:SetPoint("TOPLEFT", instance.header, "BOTTOMLEFT", 0, -Theme.Space.xs)
    instance.scroll:SetPoint("BOTTOMRIGHT", -inset.right, inset.bottom)
    RefreshBossColumnHeaders(instance, bosses, showBossColumns, characterWidth)

    local fixedWidth = characterWidth
    local currentKey = YAB.GetCurrentCharKey and YAB.GetCurrentCharKey() or nil
    local actionFills = { window = C.successSurface, soon = C.successSurface, scheduled = C.selected, timer = C.timer, weak = C.timer, observed = C.current, overdue = C.dangerSurface }
    local function PrepareRow(row, rowIndex)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", instance.body, "TOPLEFT", 0, -((rowIndex - 1) * ROW_H)); row:SetSize(instance.gridWidth, ROW_H)
        local tone = Theme:GetDataRowColor(rowIndex)
        row:SetBackdropColor(tone[1], tone[2], tone[3], tone[4] or 0.88)
        row:SetBackdropBorderColor(C.matrixLine[1], C.matrixLine[2], C.matrixLine[3], C.matrixLine[4])
        row.fixedBackground:SetWidth(fixedWidth); row.fixedBackground:SetColorTexture(tone[1], tone[2], tone[3], tone[4] or 0.88)
        row.groupGap:Hide(); row.action:Hide(); row.phase:Hide()
        local widths = { { width = characterWidth } }
        if showBossColumns then for _ = 1, #bosses do widths[#widths + 1] = { width = BOSS_WIDTH } end end
        Theme:ApplyDataColumnTints(row, widths, ROW_H)
    end
    local rowIndex = 0
    if showAction then
        rowIndex = rowIndex + 1
        local row = GetRow(instance, rowIndex); PrepareRow(row, rowIndex)
        row.professionIcon:Hide(); row.name:ClearAllPoints(); row.name:SetPoint("LEFT", Theme.Table.cellPadding, 0); row.name:SetWidth(Theme:GetTableCellContentWidth(characterWidth)); row.name:SetText("行动"); row.name:SetTextColor(C.muted[1], C.muted[2], C.muted[3]); row.name:Show()
        local x = characterWidth
        for bossIndex, boss in ipairs(bosses) do
            local cell = GetCell(row, bossIndex); cell:SetWidth(BOSS_WIDTH - 2); cell:ClearAllPoints(); cell:SetPoint("LEFT", x + 1, 0); cell:Show()
            if boss.hideAction then SetEmptyButton(cell) else
                local candidate = PickBestAction(boss, context.scope)
                SetSemanticButton(cell, candidate and candidate.text or "—", actionFills[candidate and candidate.kind or ""] or FIXED_CELL, boss.name .. " / 行动", BuildActionTooltip(boss, candidate, context.scope))
            end
            x = x + BOSS_WIDTH
        end
        Release(row.cells, showBossColumns and (#bosses + 1) or 1); Theme:SetCurrentCharacterOutline(row.currentOutline, false); row:Show()
    end
    if showPhase then
        rowIndex = rowIndex + 1
        local row = GetRow(instance, rowIndex); PrepareRow(row, rowIndex)
        row.professionIcon:Hide(); row.name:ClearAllPoints(); row.name:SetPoint("LEFT", Theme.Table.cellPadding, 0); row.name:SetWidth(Theme:GetTableCellContentWidth(characterWidth)); row.name:SetText("位面"); row.name:SetTextColor(C.muted[1], C.muted[2], C.muted[3]); row.name:Show()
        local x = characterWidth
        for bossIndex, boss in ipairs(bosses) do
            local cell = GetCell(row, bossIndex); cell:SetWidth(BOSS_WIDTH - 2); cell:ClearAllPoints(); cell:SetPoint("LEFT", x + 1, 0); cell:Show()
            if boss.hidePhase then SetEmptyButton(cell) else
                local summary, lines, hasKill, hasObserve = BuildPhaseSummary(boss, context.scope)
                SetSemanticButton(cell, summary, hasKill and C.timer or (hasObserve and C.current or FIXED_CELL), boss.name .. " / 位面", lines)
            end
            x = x + BOSS_WIDTH
        end
        Release(row.cells, showBossColumns and (#bosses + 1) or 1); Theme:SetCurrentCharacterOutline(row.currentOutline, false); row:Show()
    end
    for _, key in ipairs(keys) do
        rowIndex = rowIndex + 1
        local row = GetRow(instance, rowIndex)
        PrepareRow(row, rowIndex)
        Theme:SetCurrentCharacterOutline(row.currentOutline, key == currentKey)

        local name, realm = CharacterInfo(key)
        local color = CharacterColor(key)
        local info = (YiboAltoBossDB and YiboAltoBossDB.knownChars and YiboAltoBossDB.knownChars[key]) or {}
        local class = info.class
        local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
        local iconOffset = 0
        if coords then
            row.professionIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            row.professionIcon:SetTexCoord(unpack(coords)); row.professionIcon:ClearAllPoints(); row.professionIcon:SetPoint("LEFT", Theme.Table.cellPadding, 0); row.professionIcon:Show()
            iconOffset = 16 + Theme.Table.iconTextGap
        else row.professionIcon:Hide() end
        row.name:ClearAllPoints(); row.name:SetPoint("LEFT", Theme.Table.cellPadding + iconOffset, 0)
        row.name:SetWidth(Theme:GetTableCellContentWidth(characterWidth) - iconOffset)
        row.name:SetText(context.scope == "all" and (name .. "-" .. realm) or name); row.name:SetTextColor(color.r or color[1], color.g or color[2], color.b or color[3]); row.name:Show()
        local x = characterWidth
        if showKills then
            for bossIndex, boss in ipairs(bosses) do
                local cell = GetCell(row, bossIndex)
                cell:SetWidth(BOSS_WIDTH - 2); cell:ClearAllPoints(); cell:SetPoint("LEFT", x + 1, 0); cell:Show()
                SetStatus(cell, YAB.GetBossKillStatus(key, boss.key), key, boss); x = x + BOSS_WIDTH
            end
        end
        Release(row.cells, showKills and (#bosses + 1) or 1)
        row:Show()
    end
    Release(instance.rows, rowIndex + 1)
    instance.body:SetSize(instance.gridWidth, math.max(1, rowIndex * ROW_H))
    instance.scroll:SetContentHeight(instance.body:GetHeight())
    if preview then instance.scroll:SetVerticalScroll(0) end
    instance.scroll:RefreshScrollbar()
    Theme:SetCurrentCharacterOutline(instance.currentColumnOutline, false)
end

local function GetMatrixSize(context)
    local keys, bosses = YAB.GetAccountCharacterKeys(context), YAB.GetBossList()
    local fixedWidth = GetBossRowLabelWidth(bosses)
        + (context:GetFieldVisible("action") and ACTION_WIDTH or 0)
        + (context:GetFieldVisible("phase") and PHASE_WIDTH or 0)
        + (context:GetFieldVisible("kills") and GROUP_GAP or 0)
    local characterWidth = 0
    if context:GetFieldVisible("kills") then
        for _, key in ipairs(keys) do
            local columnWidth = GetCharacterColumnMetrics(key, context)
            characterWidth = characterWidth + columnWidth
        end
    end
    local width = fixedWidth + characterWidth
    return width, #bosses
end

function YAB.GetAccountSurfaceMetrics(context)
    local bosses = YAB.GetBossList()
    local keys = YAB.GetAccountCharacterKeys(context) or {}
    local inset = Theme:GetMatrixInsets(context and context.preview)
    if context and context.viewMode == "character-columns" then
        local matrixWidth = GetMatrixSize(context)
        local fixedWidth = GetBossRowLabelWidth(bosses)
            + (context:GetFieldVisible("action") and ACTION_WIDTH or 0)
            + (context:GetFieldVisible("phase") and PHASE_WIDTH or 0)
            + (context:GetFieldVisible("kills") and GROUP_GAP or 0)
        local characterWidth = Theme:GetCharacterMatrixColumnWidth(context)
        return {
            minContentWidth = math.max(360, fixedWidth + characterWidth + inset.left + inset.right),
            naturalContentWidth = matrixWidth + inset.left + inset.right,
            minContentHeight = inset.top + GetHeaderHeight(context) + Theme.Space.xs + ROW_H + inset.bottom,
            naturalContentHeight = inset.top + GetHeaderHeight(context) + Theme.Space.xs + math.max(1, #bosses) * ROW_H + inset.bottom,
            fixedLeftWidth = fixedWidth,
            fixedTopHeight = GetHeaderHeight(context),
            horizontalOverflow = "paginate", verticalOverflow = "content",
        }
    end
    local fixedWidth = Theme:GetCharacterRowHeaderWidth(true, context, context.characters)
    local bossWidth = 0
    local showBossColumns = context:GetFieldVisible("kills") or context:GetFieldVisible("action") or context:GetFieldVisible("phase")
    if showBossColumns then
        bossWidth = #bosses * BOSS_WIDTH
    end
    local summaryRows = (context:GetFieldVisible("action") and 1 or 0) + (context:GetFieldVisible("phase") and 1 or 0)
    return {
        minContentWidth = math.max(360, fixedWidth + (showBossColumns and BOSS_WIDTH or 0) + inset.left + inset.right),
        naturalContentWidth = fixedWidth + bossWidth + inset.left + inset.right,
        minContentHeight = inset.top + Theme.Table.headerHeight + Theme.Space.xs + ROW_H + inset.bottom,
        naturalContentHeight = inset.top + Theme.Table.headerHeight + Theme.Space.xs + math.max(1, summaryRows + #keys) * ROW_H + inset.bottom,
        fixedLeftWidth = fixedWidth,
        fixedTopHeight = Theme.Table.headerHeight,
        horizontalOverflow = "content", verticalOverflow = "content",
    }
end

-- Deprecated adapters are retained for third-party integrations during the
-- API-v5 migration. Bundled registration uses GetAccountSurfaceMetrics only.
function YAB.GetAccountPreviewSize(context)
    local metrics = YAB.GetAccountSurfaceMetrics(context)
    return metrics.naturalContentWidth + 2, metrics.naturalContentHeight + Theme.Geometry.titleBar + 2
end

function YAB.GetAccountLayoutMetrics(context)
    local metrics = YAB.GetAccountSurfaceMetrics(context)
    local geometry = Theme.Geometry
    local shellWidth = geometry.navigation + geometry.shellBorder * 2 + 1
    local shellHeight = geometry.titleBar + geometry.shellBorder * 2
    return { minWidth = metrics.minContentWidth + shellWidth, preferredWidth = metrics.naturalContentWidth + shellWidth, minHeight = metrics.minContentHeight + shellHeight, preferredHeight = metrics.naturalContentHeight + shellHeight, horizontalOverflow = metrics.horizontalOverflow, verticalOverflow = metrics.verticalOverflow }
end

function YAB.GetAccountMeasuredHeight(instance)
    local pageHeight = instance:GetHeight() or 0
    local viewportHeight = instance.scroll and instance.scroll:GetHeight() or 0
    local bodyHeight = instance.body and instance.body:GetHeight() or 0
    if pageHeight <= 0 or viewportHeight <= 0 or bodyHeight <= 0 then return nil end
    return pageHeight - viewportHeight + bodyHeight
end

function YAB.GetAccountHoverMetrics(context)
    local width, height = YAB.GetAccountPreviewSize(context)
    return { minWidth = 420, preferredWidth = width, minHeight = 150, preferredHeight = height, horizontalOverflow = "paginate", verticalOverflow = "content" }
end
