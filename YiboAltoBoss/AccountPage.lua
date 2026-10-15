if _G.YAB and _G.YAB.CoreReady == false then return end
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
    local identity = YAB.GetCharacterIdentity(key)
    return YAB.FormatCharacterName(key, "current"), identity and identity.realm or ""
end

local function CharacterColor(key)
    local identity = YAB.GetCharacterIdentity(key)
    local color = identity and identity.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[identity.class]
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
    return YAB.FormatCharacterName(key, context and context.scope == "all" and "all" or "current")
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
    local width = Theme:MeasureText(Theme.Font.body, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.BOSS_TARGET"))
    for _, boss in ipairs(bosses or {}) do
        width = math.max(width, Theme:MeasureText(Theme.Font.body, boss.name or ""))
    end
    return math.ceil(width + Theme.Table.cellPadding * 2 + Theme.Table.iconTextRasterTolerance)
end

local function FormatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    if seconds < 60 then return tostring(seconds) .. _G.YiboCore.Locale:Get("YiboAltoBoss", "TIME.SECONDS_SUFFIX") end
    if seconds < 3600 then return tostring(math.floor(seconds / 60)) .. _G.YiboCore.Locale:Get("YiboAltoBoss", "TIME.MINUTES_SUFFIX") end
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    return minutes > 0 and (hours .. _G.YiboCore.Locale:Get("YiboAltoBoss", "TIME.HOURS_SUFFIX") .. minutes .. _G.YiboCore.Locale:Get("YiboAltoBoss", "TIME.MINUTES_SUFFIX")) or (hours .. _G.YiboCore.Locale:Get("YiboAltoBoss", "TIME.HOURS_SUFFIX"))
end

local function FormatClock(timestamp)
    return date and date("%H:%M", timestamp) or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.PENDING")
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
        phaseLabel = state.phaseLabel or column.label or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNKNOWN"),
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
                candidate.text, candidate.kind, candidate.priority = FormatDuration(remaining) .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.REMAINING"), "soon", 6
            else
                candidate.text, candidate.kind, candidate.priority = FormatClock(startsAt), "scheduled", 5
            end
            candidate.orderValue = remaining
        elseif now <= endsAt then
            candidate.text, candidate.kind, candidate.priority = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.IN_WINDOW"), "window", 7
            candidate.orderValue = endsAt - now
        else
            candidate.text, candidate.kind, candidate.priority = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.OVERDUE"), "overdue", 4
            candidate.orderValue = now - endsAt
        end
        return candidate
    end
    if state.lastKilledAt then
        candidate.text, candidate.kind, candidate.priority = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.FEW_SAMPLES"), "weak", 3
        candidate.orderValue = now - state.lastKilledAt
        return candidate
    end
    if state.observedAt then
        candidate.text, candidate.kind, candidate.priority = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.OBSERVED_ONLY"), "observed", 2
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

    AddTooltipSection(lines, sectionTitle or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.RESPAWN_ESTIMATE"))
    if predictedMin and predictedMax then
        local predictionText
        if predictedMax > predictedMin then
            predictionText = FormatDuration(predictedMin) .. " – " .. FormatDuration(predictedMax)
        else
            predictionText = FormatDuration(predictedMin)
        end
        AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ESTIMATED_RESPAWN"), predictionText, C.accent)
        if lastKilledAt then
            local startsAt, endsAt = lastKilledAt + predictedMin, lastKilledAt + predictedMax
            if endsAt > startsAt then
                AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ESTIMATED_WINDOW"), FormatClock(startsAt) .. " – " .. FormatClock(endsAt), C.accent)
            else
                AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ESTIMATED_TIME"), FormatClock(startsAt), C.accent)
            end
        end
    end
    if observedMin then
        local observedText = FormatDuration(observedMin)
        if observedMax and observedMax ~= observedMin then observedText = observedText .. " – " .. FormatDuration(observedMax) end
        AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.OBSERVED_RANGE"), observedText)
    end
    if estimate.lastRespawnSampleSeconds then
        AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.LATEST_SAMPLE"), FormatDuration(estimate.lastRespawnSampleSeconds))
    end
    if realmCount > 0 then AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SAMPLE_SOURCES"), realmCount .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.REALMS")) end
    AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.COMPLETED_SAMPLES"), tostring(samples))
    if v3Samples > 0 then AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.V3_OBSERVATIONS"), tostring(v3Samples)) end
    if legacySamples > 0 then AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.V2_HISTORICAL_REFERENCE"), tostring(legacySamples)) end
    AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.USED_IN_ESTIMATE"), tostring(effectiveSamples > 0 and effectiveSamples or samples))
    if excludedSamples > 0 then AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.OUTLIERS_EXCLUDED"), tostring(excludedSamples)) end
    local modelText = mode == "fixed" and _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.FIXED_INTERVAL") or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.INTERVAL_RANGE")
    if confidence then modelText = modelText .. " · " .. YAB.FormatRespawnConfidence(confidence) end
    AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.MODEL"), modelText)
end

local function BuildActionTooltip(boss, candidate, scope)
    if not candidate then
        local estimate = GetHistoricalPrediction(boss)
        if not estimate then return { { text = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.NO_RECENT_PHASE_OBSERVATIONS_OR_USABLE_SHARED_RESPAWN_SAMPLES"), color = C.muted } } end
        local lines = { { text = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.RECENT_PHASE_OBSERVATIONS_EXPIRED_SHOWING_SHARED_SAMPLES_FROM_OTHER_REAL"), color = C.muted } }
        AppendPredictionLines(lines, estimate, nil, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SHARED_RESPAWN_MODEL"))
        return lines
    end
    local state, now = candidate.state, YAB.GetServerTimestamp()
    local statusColors = { window = C.success, soon = C.accent, scheduled = C.accent, overdue = C.danger, weak = C.muted, observed = C.muted }
    local lines = {}
    AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.STATUS"), candidate.text, statusColors[candidate.kind] or C.text)
    local displayID = tostring(candidate.phaseDisplayId or "00")
    local phaseLabel = tostring(candidate.phaseLabel or "")
    local target = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.PHASE") .. displayID
    if phaseLabel ~= "" and phaseLabel ~= _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNKNOWN") and phaseLabel ~= displayID then target = target .. " · " .. phaseLabel end
    if scope == "all" then target = tostring(candidate.realm) .. " · " .. target end
    AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.TARGET"), target)
    if state.lastKilledAt then AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.TIMER_START"), FormatDuration(now - state.lastKilledAt) .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.AGO")) end
    if (tonumber(state.pendingCycleCount) or 0) > 0 then
        AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CYCLE_PENDING"), tostring(state.pendingCycleCount) .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.WAITING_FOR_NEXT_RESPAWN"), C.accent)
    end
    AppendPredictionLines(lines, state, state.lastKilledAt, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SHARED_RESPAWN_MODEL"))
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
        local sectionTitle = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.PHASE") .. displayID
        if scope == "all" then sectionTitle = tostring(column.realm) .. " · " .. sectionTitle end
        AddTooltipSection(lines, sectionTitle)
        local phaseLabel = tostring(state.phaseLabel or column.label or "")
        if phaseLabel ~= "" and phaseLabel ~= _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNKNOWN") and phaseLabel ~= displayID then
            AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.PHASE_IDENTIFIER"), phaseLabel)
        end
        if state.observedAt then AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.LAST_OBSERVED"), FormatDuration(YAB.GetServerTimestamp() - state.observedAt) .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.AGO")) end
        if state.lastKilledAt then AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.LAST_KILL"), FormatDuration(YAB.GetServerTimestamp() - state.lastKilledAt) .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.AGO")) end
        if state.lastObservedBy then AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.OBSERVER"), tostring(state.lastObservedBy)) end
        if state.lastKilledBy then AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.KILLED_BY"), tostring(state.lastKilledBy)) end
        if state.zone and state.zone ~= "" then AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ZONE"), tostring(state.zone)) end
        if state.subZone and state.subZone ~= "" and state.subZone ~= state.zone then
            AddTooltipPair(lines, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SUBZONE"), tostring(state.subZone))
        end
    end
    local summary = "—"
    if killed > 0 and observed > 0 then summary = killed .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.KILLS") .. observed .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.OBSERVATIONS")
    elseif killed > 0 then summary = killed .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.KILLS_2")
    elseif observed > 0 then summary = observed .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.OBSERVATIONS") end
    if #lines == 0 then lines[1] = { text = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.NO_PHASE_OBSERVATIONS_IN_THE_LAST_6_HOURS"), color = C.muted } end
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
    control:SetScript("OnClick", nil)
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
    local planned, characterID, target
    if YAB.PlannedTargets then planned, characterID, target = YAB.PlannedTargets:IsPlanned(key, boss.key) end
    if planned then
        local progress = YAB.PlannedTargets:Progress(characterID, target)
        local labels = { completed = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.COMPLETED"), ready = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.READY"), unknown = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNCONFIRMED"), dormant = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNAVAILABLE") }
        local color = progress.state == "completed" and C.success or (progress.state == "ready" and C.accent or C.muted)
        local fill = progress.state == "completed" and C.successSurface or C.chrome
        cell:SetText((labels[progress.state] or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNCONFIRMED")) .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.GOAL")); cell:SetState("default")
        cell:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
        cell:SetBackdropBorderColor(color[1], color[2], color[3], color[4] or 1)
        cell.label:SetTextColor(color[1], color[2], color[3])
        cell:SetScript("OnClick", nil)
        local lines = { _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SOURCE_ACTION_CENTER_GOAL"), _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.STATUS_2") .. progress.reason }
        if progress.observedAt then lines[#lines + 1] = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SNAPSHOT") .. date("%m-%d %H:%M", progress.observedAt) end
        Theme:BindTooltip(cell, boss.name, lines)
        return
    end
    if YAB.Holiday and YAB.Holiday:IsBoss(boss) then
        local completed = status == "completed"
        local labels = { completed = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.DEFEATED"), available = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.NOT_DEFEATED"), unobserved = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.NOT_OBSERVED") }
        local text = labels[status] or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.UNAVAILABLE_2")
        cell:SetText(text); cell:SetState("default")
        local fill, border, labelColor = C.chrome, C.matrixLine, C.text
        if completed then fill, border, labelColor = C.successSurface, C.success, C.success
        elseif status == "unobserved" then fill, border, labelColor = FIXED_CELL, C.muted, C.muted end
        cell:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
        cell:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
        cell.label:SetTextColor(labelColor[1], labelColor[2], labelColor[3])
        local _, record = YAB.Holiday:GetStatus(key, boss)
        local sourceLabels = { quest = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.DAILY_QUEST"), ["lfg-reward"] = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.DUNGEON_COMPLETION_REWARD"), manual = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.MANUAL_MARK") }
        local lines = { { text = completed and _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SEASONAL_BOSS_COMPLETED") or (status == "unobserved" and _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.TODAY_S_STATUS_HAS_NOT_BEEN_OBSERVED") or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.OBSERVED_TODAY_NOT_COMPLETED_YET")), color = labelColor } }
        if record and record.source then lines[#lines + 1] = { text = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SOURCE") .. (sourceLabels[record.source] or tostring(record.source)), color = C.muted } end
        if not (record and record.source and record.source ~= "manual") then
            lines[#lines + 1] = { text = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CLICK_TO_ADD_OR_REMOVE_A_MANUAL_MARK"), color = C.muted }
            cell:SetScript("OnClick", function() YAB.Holiday:ToggleManual(boss, key) end)
        else
            cell:SetScript("OnClick", nil)
        end
        Theme:BindTooltip(cell, boss.name .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.DAILY_REWARD"), lines)
        return
    end
    local killed = status == "killed"
    cell:SetText(killed and _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.DEFEATED") or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.NOT_DEFEATED"))
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

local SetBusinessStatus = SetStatus
SetStatus = function(cell, status, key, boss)
    if _G.YiboCore.BusinessItemActions then _G.YiboCore.BusinessItemActions:Unbind(cell) end
    SetBusinessStatus(cell, status, key, boss)
    if YAB.GoalTargets and YAB.GoalTargets.ref then
        local definition
        for _, entry in ipairs(YAB.TargetCatalog:Query().targets) do if entry.bossKey == boss.key then definition = entry; break end end
        if definition then YAB.GoalTargets:Bind(cell, key, { catalogID = definition.id, scope = "all", encounterIDs = {} }, cell:GetScript("OnClick")) end
    end
end

local function PhaseTitle()
    return YAB.Holiday and YAB.Holiday:HasActiveBosses() and _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.PHASE_ROLE") or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.PHASE_2")
end

local function SetHolidayAction(control, boss)
    local queue = YAB.Holiday:GetQueueState(boss)
    local text, lines = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.QUEUE"), {}
    if queue.state == "queued" then
        text = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.LEAVE_QUEUE"); lines[1] = { text = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.YOU_ARE_QUEUED_FOR_THIS_SEASONAL_DUNGEON_CLICK_TO_LEAVE"), color = C.accent }
    elseif queue.state == "ready" then
        lines[1] = { text = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.QUEUE_FOR_THE_SEASONAL_DUNGEON_USING_YOUR_SELECTED_ROLES"), color = C.text }
        lines[#lines + 1] = { text = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ROLES") .. table.concat(YAB.Holiday:GetRoleNames(), " / "), color = C.muted }
    else
        text = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CANNOT_QUEUE"); lines[1] = { text = queue.reason or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.THIS_CHARACTER_CANNOT_QUEUE_RIGHT_NOW"), color = C.muted }
    end
    SetSemanticButton(control, text, queue.state == "ready" and C.successSurface or (queue.state == "queued" and C.timer or FIXED_CELL), boss.name .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ACTION"), lines)
    if queue.state == "ready" then
        -- Reuse Core's selected-state language for an actionable holiday
        -- button: the bright teal outline and label are visible in the dense
        -- matrix without introducing a new visual treatment.
        control:SetState("selected")
        control:SetBackdropColor(C.selected[1], C.selected[2], C.selected[3], C.selected[4] or 1)
        control.label:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
    end
    if queue.state == "ready" or queue.state == "queued" then
        control:SetScript("OnClick", function() YAB.Holiday:ToggleQueue(boss) end)
    end
end

local function SetHolidayPhase(control, boss)
    local roles, note = YAB.Holiday:GetRoles()
    local roleNames = YAB.Holiday:GetRoleNames()
    local text = #roles > 0 and table.concat(roles, "/") or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.NO_ROLE")
    local lines = { { text = #roles > 0 and (_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SELECTED_ROLES") .. table.concat(roleNames, " / ")) or (note or _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.SELECT_ROLES_IN_THE_DUNGEON_FINDER_FIRST")), color = #roles > 0 and C.text or C.muted }, { text = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CLICK_TO_SELECT_DUNGEON_FINDER_ROLES"), color = C.muted } }
    SetSemanticButton(control, text, #roles > 0 and C.current or FIXED_CELL, boss.name .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ROLES_2"), lines)
    control:SetScript("OnClick", function() YAB.Holiday:OpenRoleSelector(control) end)
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
    Place(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.BOSS_TARGET"), bossNameWidth, nil, nil, true)
    if showAction then Place(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ACTION_2"), ACTION_WIDTH, nil, nil, true) end
    if showPhase then Place(PhaseTitle(), PHASE_WIDTH, nil, nil, true) end
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
            Theme:BindTooltip(header, YAB.FormatCharacterName(key, "all", true))
        end
    end
    Release(instance.headers, index + 1)
    instance.gridWidth = x
end

function YAB.CreateAccountPage(parent)
    parent:SetClipsChildren(true)
    parent.businessTabs = YAB.CreateBusinessTabs(parent, "boss")
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
    local allKeys, bosses = YAB.GetAccountCharacterKeys(context), YAB.GetBossList(context)
    local showKills = context:GetFieldVisible("kills")
    local showAction = context:GetFieldVisible("action")
    local showPhase = context:GetFieldVisible("phase")
    local bossNameWidth = GetBossRowLabelWidth(bosses)
    -- Core's title bar and shared scope bar already identify this view and its
    -- active server range.  Keeping a second page title consumed a full blank
    -- row between the scope controls and matrix.
    instance.title:SetShown(false)
    instance.summary:SetShown(false)
    instance.businessTabs:SetActive("boss")

    Release(instance.scopeButtons, 1)

    instance.header:ClearAllPoints(); instance.scroll:ClearAllPoints()
    -- The page instance begins immediately below Core's shared scope bar.
    -- Keep only the compact visual gap before the matrix; the previous 44 px
    -- offset reserved a now-removed local title/control row.
    local inset = Theme:GetMatrixInsets(preview)
    local matrixTop = -(inset.top + YAB.GetBusinessTabHeight())
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
        1,
        _G.YiboCore.AccountView:GetScrollSurfaceWidth(context, instance, #bosses * ROW_H,
            inset.top + YAB.GetBusinessTabHeight() + GetHeaderHeight(context) + Theme.Space.xs + inset.bottom) - inset.left - inset.right
    )
    instance.characterColumnWidth = characterWidth
    local keys, pageInfo = allKeys, nil
    if showKills then
        keys, pageInfo = _G.YiboCore.AccountView:GetColumnPage("alto-boss", "characters", allKeys, availableWidth, fixedWidth, instance.characterColumnWidth, YAB.GetCurrentCharKey and YAB.GetCurrentCharKey() or nil)
    end
    _G.YiboCore.AccountView:UpdateColumnPager(instance, "alto-boss", "characters", pageInfo, instance.header, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CHARACTER"))
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
            if YAB.Holiday and YAB.Holiday:IsBoss(boss) then
                SetHolidayAction(row.action, boss)
            elseif boss.hideAction then
                SetEmptyButton(row.action)
            else
                local candidate = PickBestAction(boss, context.scope)
                local fills = { window = C.successSurface, soon = C.successSurface, scheduled = C.selected, weak = C.timer, observed = C.current, overdue = C.dangerSurface }
                SetSemanticButton(row.action, candidate and candidate.text or "—", fills[candidate and candidate.kind or ""] or FIXED_CELL, boss.name .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ACTION"), BuildActionTooltip(boss, candidate, context.scope))
            end
        end

        row.phase:ClearAllPoints(); row.phase:SetShown(showPhase)
        if showPhase then
            row.phase:SetPoint("LEFT", x + 1, 0); x = x + PHASE_WIDTH
            if YAB.Holiday and YAB.Holiday:IsBoss(boss) then
                SetHolidayPhase(row.phase, boss)
            elseif boss.hidePhase then
                SetEmptyButton(row.phase)
            else
                local summary, lines, hasKill, hasObserve = BuildPhaseSummary(boss, context.scope)
                local fill = hasKill and C.timer or (hasObserve and C.current or FIXED_CELL)
                SetSemanticButton(row.phase, summary, fill, boss.name .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.PHASE_3"), lines)
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
    Place(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.CHARACTER"), characterWidth, nil, nil, true)
    if showBossColumns then
        for _, boss in ipairs(bosses) do
            Place(boss.name, BOSS_WIDTH)
            Theme:BindTooltip(instance.headers[index], boss.name)
        end
    end
    Release(instance.headers, index + 1)
    instance.fixedWidth, instance.gridWidth = characterWidth, x
    instance.header.fixedDivider:Hide()
end

function YAB.RefreshAccountPage(instance, context)
    if YAB.SetAccountBusinessPage then YAB.SetAccountBusinessPage("alto-boss") end
    if context.viewMode == "character-columns" then
        return RefreshAccountPageByCharacterColumns(instance, context)
    end
    local preview = context.preview == true
    local keys, bosses = YAB.GetAccountCharacterKeys(context), YAB.GetBossList(context)
    local showKills = context:GetFieldVisible("kills")
    local showAction = context:GetFieldVisible("action")
    local showPhase = context:GetFieldVisible("phase")
    local showBossColumns = showKills or showAction or showPhase
    local inset = Theme:GetMatrixInsets(preview)
    local characterWidth = Theme:GetCharacterRowHeaderWidth(true, context, context.characters)

    instance.title:Hide(); instance.summary:Hide(); Release(instance.scopeButtons, 1)
    instance.businessTabs:SetActive("boss")
    instance.header:ClearAllPoints(); instance.scroll:ClearAllPoints()
    instance.header:SetPoint("TOPLEFT", inset.left, -inset.top - YAB.GetBusinessTabHeight())
    instance.header:SetPoint("TOPRIGHT", -inset.right, -inset.top - YAB.GetBusinessTabHeight())
    instance.scroll:SetPoint("TOPLEFT", instance.header, "BOTTOMLEFT", 0, -Theme.Space.xs)
    instance.scroll:SetPoint("BOTTOMRIGHT", -inset.right, inset.bottom)
    local candidates = {}
    if showBossColumns then for _, boss in ipairs(bosses) do candidates[#candidates + 1] = { id = boss.key, boss = boss } end end
    local summaryRows = (showAction and 1 or 0) + (showPhase and 1 or 0)
    local fixedHeight = inset.top + YAB.GetBusinessTabHeight() + Theme.Table.headerHeight + Theme.Space.xs + inset.bottom
    local availableWidth = math.max(1, _G.YiboCore.AccountView:GetScrollSurfaceWidth(context, instance, (summaryRows + #keys) * ROW_H, fixedHeight) - inset.left - inset.right)
    local visible, pageInfo = _G.YiboCore.AccountView:GetColumnPage("alto-boss", "bosses", candidates, availableWidth, characterWidth, BOSS_WIDTH)
    bosses = {}; for _, column in ipairs(visible) do bosses[#bosses + 1] = column.boss end
    _G.YiboCore.AccountView:UpdateColumnPager(instance, "alto-boss", "bosses", showBossColumns and pageInfo or nil, instance.businessTabs, _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.BOSS_TARGET"))
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
        row.professionIcon:Hide(); row.name:ClearAllPoints(); row.name:SetPoint("LEFT", Theme.Table.cellPadding, 0); row.name:SetWidth(Theme:GetTableCellContentWidth(characterWidth)); row.name:SetText(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ACTION_2")); row.name:SetTextColor(C.muted[1], C.muted[2], C.muted[3]); row.name:Show()
        local x = characterWidth
        for bossIndex, boss in ipairs(bosses) do
            local cell = GetCell(row, bossIndex); cell:SetWidth(BOSS_WIDTH - 2); cell:ClearAllPoints(); cell:SetPoint("LEFT", x + 1, 0); cell:Show()
            if YAB.Holiday and YAB.Holiday:IsBoss(boss) then SetHolidayAction(cell, boss)
            elseif boss.hideAction then SetEmptyButton(cell) else
                local candidate = PickBestAction(boss, context.scope)
                SetSemanticButton(cell, candidate and candidate.text or "—", actionFills[candidate and candidate.kind or ""] or FIXED_CELL, boss.name .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.ACTION"), BuildActionTooltip(boss, candidate, context.scope))
            end
            x = x + BOSS_WIDTH
        end
        Release(row.cells, showBossColumns and (#bosses + 1) or 1); Theme:SetCurrentCharacterOutline(row.currentOutline, false); row:Show()
    end
    if showPhase then
        rowIndex = rowIndex + 1
        local row = GetRow(instance, rowIndex); PrepareRow(row, rowIndex)
        row.professionIcon:Hide(); row.name:ClearAllPoints(); row.name:SetPoint("LEFT", Theme.Table.cellPadding, 0); row.name:SetWidth(Theme:GetTableCellContentWidth(characterWidth)); row.name:SetText(PhaseTitle()); row.name:SetTextColor(C.muted[1], C.muted[2], C.muted[3]); row.name:Show()
        local x = characterWidth
        for bossIndex, boss in ipairs(bosses) do
            local cell = GetCell(row, bossIndex); cell:SetWidth(BOSS_WIDTH - 2); cell:ClearAllPoints(); cell:SetPoint("LEFT", x + 1, 0); cell:Show()
            if YAB.Holiday and YAB.Holiday:IsBoss(boss) then SetHolidayPhase(cell, boss)
            elseif boss.hidePhase then SetEmptyButton(cell) else
                local summary, lines, hasKill, hasObserve = BuildPhaseSummary(boss, context.scope)
                SetSemanticButton(cell, summary, hasKill and C.timer or (hasObserve and C.current or FIXED_CELL), boss.name .. _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.PHASE_3"), lines)
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
        row.professionIcon:Hide()
        row.name:ClearAllPoints(); row.name:SetPoint("LEFT", Theme.Table.cellPadding, 0)
        row.name:SetWidth(Theme:GetTableCellContentWidth(characterWidth))
        row.name:SetText(YAB.FormatCharacterName(key, context.scope == "all" and "all" or "current")); row.name:SetTextColor(color.r or color[1], color.g or color[2], color.b or color[3]); row.name:Show()
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
    local keys, bosses = YAB.GetAccountCharacterKeys(context), YAB.GetBossList(context)
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
    local bosses = YAB.GetBossList(context)
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
            scrollContentHeight = #bosses * ROW_H,
            scrollFixedHeight = inset.top + YAB.GetBusinessTabHeight() + GetHeaderHeight(context) + Theme.Space.xs + inset.bottom,
            minContentHeight = inset.top + YAB.GetBusinessTabHeight() + GetHeaderHeight(context) + Theme.Space.xs + ROW_H + inset.bottom,
            naturalContentHeight = inset.top + YAB.GetBusinessTabHeight() + GetHeaderHeight(context) + Theme.Space.xs + math.max(1, #bosses) * ROW_H + inset.bottom,
            fixedLeftWidth = fixedWidth,
            fixedTopHeight = YAB.GetBusinessTabHeight() + GetHeaderHeight(context),
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
        scrollContentHeight = (summaryRows + #keys) * ROW_H,
        scrollFixedHeight = inset.top + YAB.GetBusinessTabHeight() + Theme.Table.headerHeight + Theme.Space.xs + inset.bottom,
        minContentHeight = inset.top + YAB.GetBusinessTabHeight() + Theme.Table.headerHeight + Theme.Space.xs + ROW_H + inset.bottom,
        naturalContentHeight = inset.top + YAB.GetBusinessTabHeight() + Theme.Table.headerHeight + Theme.Space.xs + math.max(1, summaryRows + #keys) * ROW_H + inset.bottom,
        fixedLeftWidth = fixedWidth,
        fixedTopHeight = YAB.GetBusinessTabHeight() + Theme.Table.headerHeight,
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
