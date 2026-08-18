local YAB = _G.YAB
local Theme = _G.YiboCore.UITheme
local C = Theme.Colors

local BOSS_WIDTH, ACTION_WIDTH, PHASE_WIDTH = 120, 88, 72
local CHARACTER_MIN_WIDTH, CHARACTER_MAX_WIDTH = 72, 96
local HEADER_H, COMPACT_HEADER_H, ROW_H, CELL_H = 40, 28, 30, 26
local GROUP_GAP = 4
local FIXED_HEADER = { 0.035, 0.18, 0.19, 1 }
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
    local color = info.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[info.class]
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

local function GetCharacterColumnMetrics(key, context)
    local name, realm = CharacterInfo(key)
    local titleFont = context and context.scope == "all" and Theme.Font.body or (Theme.Font.body + 1)
    local nameWidth = VisualTextUnits(name) * titleFont
    local realmWidth = context and context.scope == "all" and (VisualTextUnits(realm) * Theme.Font.assist) or 0
    local contentWidth = math.max(nameWidth, realmWidth)
    local width = math.ceil(contentWidth + 16)
    return math.max(CHARACTER_MIN_WIDTH, math.min(CHARACTER_MAX_WIDTH, width)), titleFont
end

local function GetScopeTitle(context)
    for _, value in ipairs(context.scopeDefinition and context.scopeDefinition.values or {}) do
        if value.id == context.scope then return value.title end
    end
    return "账号范围"
end

local function ScopeRealm(scope)
    return type(scope) == "string" and scope:match("^realm:(.+)$") or nil
end

local function ScopeControlsWidth(context)
    return 32 + (#(context and context.scopeDefinition and context.scopeDefinition.values or {}) * 104)
end

local function GetHeaderHeight(context)
    return context and context.scope == "all" and HEADER_H or COMPACT_HEADER_H
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

local function GetVisibleSummary(keys, bosses)
    local killed, total = 0, 0
    for _, key in ipairs(keys) do
        for _, boss in ipairs(bosses) do
            total = total + 1
            if YAB.IsBossKilled(key, boss.key) then killed = killed + 1 end
        end
    end
    return killed, total
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
    header = CreateFrame("Frame", nil, instance.header, "BackdropTemplate")
    header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    header:SetBackdropColor(C.chrome[1], C.chrome[2], C.chrome[3], 0.96)
    header:SetBackdropBorderColor(C.lineSoft[1], C.lineSoft[2], C.lineSoft[3], C.lineSoft[4])
    header.title = Text(header, Theme.Font.assist, "CENTER", C.muted)
    header.title:SetPoint("TOPLEFT", 3, -3); header.title:SetPoint("TOPRIGHT", -3, -3); header.title:SetHeight(17)
    header.sub = Text(header, Theme.Font.assist, "CENTER", C.muted)
    header.sub:SetPoint("TOPLEFT", 3, -20); header.sub:SetPoint("TOPRIGHT", -3, -20); header.sub:SetHeight(16)
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

local function SetStatus(cell, killed, key, boss)
    cell:SetText(killed and "已击杀" or "未击杀")
    cell:SetState(killed and "selected" or "default")
    if killed then cell:SetBackdropColor(C.success[1], C.success[2], C.success[3], C.success[4]) end
    cell:SetScript("OnLeave", function(control)
        if killed then control:SetBackdropColor(C.success[1], C.success[2], C.success[3], C.success[4])
        else control:SetBackdropColor(C.chrome[1], C.chrome[2], C.chrome[3], C.chrome[4]) end
        control.label:SetTextColor(C.text[1], C.text[2], C.text[3])
        local border = killed and C.accent or C.line
        control:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
    end)
    cell:SetScript("OnClick", function() YAB.ToggleBossKill(key, boss.key) end)
end

local function RefreshHeaders(instance, context, keys, showAction, showPhase, showKills)
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
        header.title:ClearAllPoints(); header.sub:ClearAllPoints()
        if headerHeight == HEADER_H then
            header.title:SetPoint("TOPLEFT", 3, -3); header.title:SetPoint("TOPRIGHT", -3, -3); header.title:SetHeight(17)
            header.sub:SetPoint("TOPLEFT", 3, -20); header.sub:SetPoint("TOPRIGHT", -3, -20); header.sub:SetHeight(16)
            header.sub:Show()
        else
            header.title:SetPoint("TOPLEFT", 3, 0); header.title:SetPoint("BOTTOMRIGHT", -3, 0)
            header.sub:Hide()
        end
        header.title:SetText(title); header.sub:SetText(sub or "")
        header.title:SetFont(STANDARD_TEXT_FONT, titleFont or Theme.Font.assist)
        header.sub:SetFont(STANDARD_TEXT_FONT, Theme.Font.assist)
        local color = titleColor or C.muted
        header.title:SetTextColor(color.r or color[1], color.g or color[2], color.b or color[3])
        header.sub:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        local fill = fixedArea and FIXED_HEADER or C.chrome
        header:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
        header:SetBackdropBorderColor(C.lineSoft[1], C.lineSoft[2], C.lineSoft[3], C.lineSoft[4])
        header:Show(); x = x + width
    end
    Place("Boss / 目标", BOSS_WIDTH, nil, nil, true)
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
            local columnWidth, titleFont = GetCharacterColumnMetrics(key, context)
            instance.characterWidths[characterIndex] = columnWidth
            if key == currentKey then
                instance.currentColumnX = x
                instance.currentColumnWidth = columnWidth
            end
            Place(name, columnWidth, realmSubtitle, CharacterColor(key), false, titleFont)
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
    parent.body = CreateFrame("Frame", nil, parent.scroll); parent.scroll:SetScrollChild(parent.body)
    parent.currentColumnOutline = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    parent.currentColumnOutline:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    parent.currentColumnOutline:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    parent.currentColumnOutline:SetFrameLevel(math.max(parent.header:GetFrameLevel(), parent.scroll:GetFrameLevel()) + 10)
    parent.currentColumnOutline:EnableMouse(false)
    parent.currentColumnOutline:Hide()
    parent.headers, parent.rows = {}, {}
end

local function RefreshCurrentColumnOutline(instance, bosses, showKills)
    local outline = instance.currentColumnOutline
    outline:ClearAllPoints()
    if not showKills or not instance.currentColumnX then
        outline:Hide()
        return
    end
    outline:SetPoint("TOPLEFT", instance.header, "TOPLEFT", instance.currentColumnX, 0)
    outline:SetPoint("BOTTOMRIGHT", instance.body, "TOPLEFT", instance.currentColumnX + (instance.currentColumnWidth or CHARACTER_MIN_WIDTH), -(#bosses * ROW_H))
    outline:Show()
end

function YAB.RefreshAccountPage(instance, context)
    local preview = context.preview == true
    local keys, bosses = YAB.GetAccountCharacterKeys(context), YAB.GetBossList()
    local showKills = context:GetFieldVisible("kills")
    local showAction = context:GetFieldVisible("action")
    local showPhase = context:GetFieldVisible("phase")
    local killed, total = GetVisibleSummary(keys, bosses)
    instance.title:SetText("Boss 击杀、行动与位面 · " .. GetScopeTitle(context)); instance.title:SetShown(not preview)
    instance.summary:SetText("击杀 " .. killed .. "/" .. total); instance.summary:SetShown(not preview)

    for index, value in ipairs(context.scopeDefinition and context.scopeDefinition.values or {}) do
        local scopeID = value.id
        local control = instance.scopeButtons[index] or Button(instance, 96, value.title)
        instance.scopeButtons[index] = control
        control:ClearAllPoints(); control:SetPoint("TOPLEFT", instance, "TOPLEFT", (preview and Theme.Space.xs or Theme.Space.lg) + ((index - 1) * 104), preview and -Theme.Space.xs or -44)
        control:SetText(value.title); control:SetState(scopeID == context.scope and "selected" or "default")
        control:SetScript("OnClick", function() context:SetScope(scopeID) end)
        control:SetShown(true)
    end
    Release(instance.scopeButtons, #(context.scopeDefinition and context.scopeDefinition.values or {}) + 1)

    instance.header:ClearAllPoints(); instance.scroll:ClearAllPoints()
    instance.header:SetPoint("TOPLEFT", preview and Theme.Space.xs or Theme.Space.lg, preview and -44 or -84)
    instance.header:SetPoint("TOPRIGHT", preview and -Theme.Space.md or -38, preview and -44 or -84)
    instance.scroll:SetPoint("TOPLEFT", instance.header, "BOTTOMLEFT", 0, -Theme.Space.xs)
    instance.scroll:SetPoint("BOTTOMRIGHT", preview and -Theme.Space.md or -38, preview and Theme.Space.xs or Theme.Space.md)
    RefreshHeaders(instance, context, keys, showAction, showPhase, showKills)

    for rowIndex, boss in ipairs(bosses) do
        local row = GetRow(instance, rowIndex)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", instance.body, "TOPLEFT", 0, -((rowIndex - 1) * ROW_H)); row:SetSize(instance.gridWidth, ROW_H)
        row:SetBackdropColor(rowIndex % 2 == 0 and 0.035 or 0.025, rowIndex % 2 == 0 and 0.115 or 0.085, rowIndex % 2 == 0 and 0.13 or 0.10, 0.88)
        row:SetBackdropBorderColor(C.lineSoft[1], C.lineSoft[2], C.lineSoft[3], C.lineSoft[4])
        row.fixedBackground:SetWidth(instance.fixedWidth)
        row.groupGap:ClearAllPoints()
        row.groupGap:SetPoint("TOPLEFT", row, "TOPLEFT", instance.fixedWidth, 0)
        row.groupGap:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", instance.fixedWidth, 0)
        row.groupGap:SetShown(showKills)
        local x = 0
        row.name:ClearAllPoints(); row.name:SetPoint("LEFT", row, "LEFT", 8, 0); row.name:SetText(boss.name); x = x + BOSS_WIDTH

        row.action:ClearAllPoints(); row.action:SetShown(showAction)
        if showAction then
            row.action:SetPoint("LEFT", x + 1, 0); x = x + ACTION_WIDTH
            if boss.hideAction then
                SetEmptyButton(row.action)
            else
                local candidate = PickBestAction(boss, context.scope)
                local fills = { window = C.success, soon = C.success, scheduled = C.selected, weak = C.timer, observed = C.current, overdue = C.dangerSurface }
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
                local columnWidth = instance.characterWidths[cellIndex] or CHARACTER_MIN_WIDTH
                cell:SetWidth(columnWidth - 2)
                cell:ClearAllPoints(); cell:SetPoint("LEFT", x + 1, 0); cell:SetShown(true)
                SetStatus(cell, YAB.IsBossKilled(key, boss.key), key, boss)
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

local function GetMatrixSize(context)
    local keys, bosses = YAB.GetAccountCharacterKeys(context), YAB.GetBossList()
    local characterWidth = 0
    if context:GetFieldVisible("kills") then
        for _, key in ipairs(keys) do
            local columnWidth = GetCharacterColumnMetrics(key, context)
            characterWidth = characterWidth + columnWidth
        end
    end
    local width = BOSS_WIDTH
        + (context:GetFieldVisible("action") and ACTION_WIDTH or 0)
        + (context:GetFieldVisible("phase") and PHASE_WIDTH or 0)
        + (context:GetFieldVisible("kills") and GROUP_GAP or 0)
        + characterWidth
    return width, #bosses
end

function YAB.GetAccountPreviewSize(context)
    local matrixWidth, rows = GetMatrixSize(context)
    -- Core title bar, scope controls, inter-section gaps and the bottom inset
    -- consume 110 px; add the actual one- or two-line matrix header height.
    local chromeHeight = 110 + GetHeaderHeight(context)
    return math.max(matrixWidth + 26, ScopeControlsWidth(context)), math.max(150, chromeHeight + (rows * ROW_H))
end

function YAB.GetAccountLayoutMetrics(context)
    local matrixWidth, rows = GetMatrixSize(context)
    return { minWidth = 582, preferredWidth = math.max(matrixWidth + 38, ScopeControlsWidth(context)), minHeight = 383, preferredHeight = math.max(383, 142 + (rows * ROW_H)), horizontalOverflow = "matrix", verticalOverflow = "content" }
end

function YAB.GetAccountHoverMetrics(context)
    local width, height = YAB.GetAccountPreviewSize(context)
    return { minWidth = 420, preferredWidth = width, minHeight = 150, preferredHeight = height, horizontalOverflow = "matrix", verticalOverflow = "content" }
end
