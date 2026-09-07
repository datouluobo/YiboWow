local Addon = _G.YiboLegendary
local UI = {}
Addon.UI = UI

local Theme = _G.YiboCore.UITheme
local C = Theme.Colors
local ROW_HEIGHT = Theme.Table.iconRowHeight
local CELL_INSET = Theme.Table.cellInset
local CELL_PADDING = Theme.Table.cellPadding

local STATUS = {
    completed = { label = "已获得", color = C.success, icon = "Interface\\RaidFrame\\ReadyCheck-Ready" },
    in_progress = { label = "进行中", color = { 1, 0.78, 0.34 }, icon = "Interface\\RaidFrame\\ReadyCheck-Waiting" },
    obtainable = { label = "可刷", color = { 0.48, 0.76, 0.96 }, icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up" },
    pending_sync = { label = "待同步", color = C.muted, icon = "Interface\\RaidFrame\\ReadyCheck-NotReady" },
    unavailable = { label = "绝版", color = { 1, 0.48, 0.5 }, icon = "Interface\\Buttons\\UI-GroupLoot-Pass-Up" },
    ineligible = { label = "不适用", color = C.muted, icon = "Interface\\RaidFrame\\ReadyCheck-NotReady" },
    unknown = { label = "无法读取", color = { 1, 0.48, 0.5 }, icon = "Interface\\RaidFrame\\ReadyCheck-NotReady" },
}

local function CharacterLabel(character, context)
    local name = character.name or "未知角色"
    return context and context.scope == "all" and (name .. "-" .. (character.realm or "未知服务器")) or name
end
local function TargetState(snapshot, id) return snapshot and snapshot.targets and snapshot.targets[id] end
local function DisplayState(snapshot, target)
    local state = TargetState(snapshot, target.id)
    if state or not target.catalogOnly then return state end
    if target.archived then
        return { targetId=target.id, status="unavailable", placeholder=true, acquired=false, stageLabel="已绝版", progressText="不可从零开始", nextAction="仅保留历史收藏入口。" }
    end
    return { targetId=target.id, status="pending_sync", placeholder=true, acquired=false, stageLabel="待接入", progressText="仅图标占位", nextAction="后续版本接入采集器。" }
end
local function StateMeta(state)
    if state and state.placeholder and state.status == "unavailable" then return STATUS.unavailable end
    if state and state.placeholder then return { label="待接入", color=C.muted } end
    return STATUS[state and state.status or "unknown"] or STATUS.unknown
end
local function EvidenceLabel(state)
    local source = state and state.evidence and state.evidence.source
    return ({ real = "自动", manual = "确认", projection = "测试" })[source] or "—"
end
local function CellProjection(snapshot, target)
    local state = DisplayState(snapshot, target)
    local meta = StateMeta(state)
    local value
    if state and state.acquired then value = EvidenceLabel(state)
    elseif state and state.placeholder then value = state.status == "unavailable" and "绝版" or "待接入"
    elseif not state then value = "待同步"
    elseif state.status == "ineligible" then value = "不适用"
    elseif state.status == "unknown" then value = "无法读取"
    elseif state.status == "pending_sync" then value = "待同步"
    else
        local progress = tostring(state.progressText or "")
        value = progress:match("(%d+/%d+)") or (progress:find("材料已齐") and "材料齐") or (progress:find("可刷") and "可刷") or progress
        if value == "" or value == "未获得" then value = meta.label end
    end
    return { state=state, icon=meta.icon, color=meta.color, value=value, status=meta.label,
        tooltipValue=(state and state.progressText) or "等待角色数据同步。", evidence=EvidenceLabel(state) }
end
local function TargetIcon(target)
    local itemID = target and target.iconItemId
    if itemID and C_Item and type(C_Item.GetItemIconByID) == "function" then
        local icon = C_Item.GetItemIconByID(itemID)
        if icon then return icon end
    end
    if itemID and type(GetItemIcon) == "function" then
        local icon = GetItemIcon(itemID)
        if icon then return icon end
    end
    return "Interface\\AddOns\\YiboLegendary\\Media\\YiboLegendaryIcon-v1"
end
local function PreviewTargetWidths(target)
    -- Core owns all icon-text and column-padding geometry. This page supplies
    -- only its title content; the returned width also drives Core pagination.
    return Theme:GetMatrixTargetColumnWidths(16, Theme.Font.assist, target.shortTitle or target.title or target.id)
end
local function ArchiveIcon()
    return "Interface\\Icons\\INV_Misc_Book_09"
end
local function ClassColor(character)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class or ""]
    if color then return color.r, color.g, color.b end
    return C.text[1], C.text[2], C.text[3]
end

function UI:GetEligibleCharacters(characters)
    local result = {}
    self._eligibleCharacterIDs = self._eligibleCharacterIDs or {}
    for _, character in ipairs(characters or Addon.Core.Characters:GetAll()) do
        local store = Addon.db.byCharacter[character.id]
        local snapshot = Addon.runtime.snapshotsByCharacter[character.id] or (store and store.snapshot)
        if (character.level or 0) >= 90 and (snapshot or self._eligibleCharacterIDs[character.id]) then
            self._eligibleCharacterIDs[character.id] = true
            result[#result + 1] = character
        end
    end
    return result
end

function UI:GetVisibleCharacters(characters)
    local result = {}
    for _, character in ipairs(self:GetEligibleCharacters(characters)) do
        local store = Addon.db.byCharacter[character.id]
        result[#result + 1] = { character = character, snapshot = Addon.runtime.snapshotsByCharacter[character.id] or (store and store.snapshot) }
    end
    return result
end

-- 目标图标属于当前页面的局部状态。切换目标时直接复用已经通过 Core
-- 准入的角色上下文，避免一次无关的整页刷新把角色矩阵重建成空列表。
function UI:GetMainRoster(context, previousRoster)
    local roster = {}
    for _, character in ipairs(context and context.characters or {}) do
        if character and character.id then
            local store = Addon.db.byCharacter[character.id]
            roster[#roster + 1] = { character = character, snapshot = Addon.runtime.snapshotsByCharacter[character.id] or (store and store.snapshot) }
        end
    end
    if #roster > 0 then return roster end
    if previousRoster and #previousRoster > 0 then return previousRoster end
    if Addon.Core.Characters and Addon.Core.Characters.GetAll then
        for _, character in ipairs(Addon.Core.Characters:GetAll()) do
            if (character.level or 0) >= 90 then
                local store = Addon.db.byCharacter[character.id]
                roster[#roster + 1] = { character = character, snapshot = Addon.runtime.snapshotsByCharacter[character.id] or (store and store.snapshot) }
            end
        end
    end
    return roster
end

local function RegionFlag(region, method)
    if not region or type(region[method]) ~= "function" then return "?" end
    local ok, value = pcall(region[method], region)
    return ok and (value and "1" or "0") or "!"
end

local function RegionSize(region)
    if not region then return "?x?" end
    local width = type(region.GetWidth) == "function" and tonumber(region:GetWidth()) or 0
    local height = type(region.GetHeight) == "function" and tonumber(region:GetHeight()) or 0
    return string.format("%.0fx%.0f", width or 0, height or 0)
end

function UI:SetMatrixDebug(enabled)
    Addon.runtime.matrixDebug = enabled == true
    Addon:Print("矩阵诊断已" .. (Addon.runtime.matrixDebug and "开启；切换一次橙装后复制聊天框中的 [矩阵诊断] 行。" or "关闭。"))
    if Addon.runtime.matrixDebug then self:DebugMatrix("manual") end
end

function UI:DebugMatrix(phase)
    if not (Addon.runtime and Addon.runtime.matrixDebug) then return end
    local page = self.details and self.details.main
    local detail = page and page.detail
    local row = detail and detail.rows and detail.rows[1]
    local cells = row and row.cells
    local target = self:GetSelectedTarget()
    Addon:Print(string.format("[矩阵诊断] %s target=%s render=%d context=%d roster=%d rows=%d",
        tostring(phase), target and target.id or "nil", tonumber(self._matrixRenderSerial) or 0,
        page and page.context and #(page.context.characters or {}) or -1,
        page and #(page.roster or {}) or -1, detail and #(detail.rows or {}) or -1))
    Addon:Print(string.format("[矩阵诊断] page=%s/%s %s detail=%s/%s %s header=%s/%s %s scroll=%s/%s %s content=%s/%s %s",
        RegionFlag(page, "IsShown"), RegionFlag(page, "IsVisible"), RegionSize(page),
        RegionFlag(detail, "IsShown"), RegionFlag(detail, "IsVisible"), RegionSize(detail),
        RegionFlag(detail and detail.header, "IsShown"), RegionFlag(detail and detail.header, "IsVisible"), RegionSize(detail and detail.header),
        RegionFlag(detail and detail.scroll, "IsShown"), RegionFlag(detail and detail.scroll, "IsVisible"), RegionSize(detail and detail.scroll),
        RegionFlag(detail and detail.content, "IsShown"), RegionFlag(detail and detail.content, "IsVisible"), RegionSize(detail and detail.content)))
    if row then
        Addon:Print(string.format("[矩阵诊断] row1=%s/%s %s char=%s/%s[%s] stage=%s/%s[%s] progress=%s/%s[%s] action=%s/%s[%s]",
            RegionFlag(row, "IsShown"), RegionFlag(row, "IsVisible"), RegionSize(row),
            RegionFlag(cells.character, "IsShown"), RegionFlag(cells.character, "IsVisible"), tostring(cells.character:GetText() or ""),
            RegionFlag(cells.stage, "IsShown"), RegionFlag(cells.stage, "IsVisible"), tostring(cells.stage:GetText() or ""),
            RegionFlag(cells.progress, "IsShown"), RegionFlag(cells.progress, "IsVisible"), tostring(cells.progress:GetText() or ""),
            RegionFlag(cells.action, "IsShown"), RegionFlag(cells.action, "IsVisible"), tostring(cells.action:GetText() or "")))
    end
end

function UI:GetSelectedTarget()
    return Addon.Catalog:GetTarget(Addon.db.settings.selectedTargetId) or Addon.Catalog:GetTarget("CLOAK")
end
function UI:IsArchivePage()
    return Addon.db.settings.targetPage == "archived"
end
function UI:GetDirectoryTargets()
    return self:IsArchivePage() and Addon.Catalog:GetArchivedTargets() or Addon.Catalog:GetActiveTargets()
end
function UI:SelectTargetPage(page)
    local archived = page == "archived"
    Addon.db.settings.targetPage = archived and "archived" or "active"
    local target = self:GetSelectedTarget()
    if target.archived ~= archived then
        local targets = archived and Addon.Catalog:GetArchivedTargets() or Addon.Catalog:GetActiveTargets()
        if targets[1] then Addon.db.settings.selectedTargetId = targets[1].id end
    end
    self:RefreshTargetSelection()
end
function UI:SelectTarget(id)
    local target = Addon.Catalog:GetTarget(id)
    if target then
        Addon.db.settings.selectedTargetId = id
        Addon.db.settings.targetPage = target.archived and "archived" or "active"
        self:RefreshTargetSelection()
    end
end

function UI:RefreshTargetSelection()
    local page = self.details and self.details.main
    self:DebugMatrix("target-before")
    if page and page:IsShown() and page.context then
        self:RefreshMain(page.context)
    else
        self:Refresh("target-fallback")
    end
    self:DebugMatrix("target-after")
    if Addon.runtime.matrixDebug and C_Timer and C_Timer.After then
        C_Timer.After(0, function() UI:DebugMatrix("target-next-frame") end)
        C_Timer.After(0.25, function() UI:DebugMatrix("target-after-250ms") end)
    end
end

function UI:Text(parent, size, color, justify)
    local text = Theme:CreateText(parent, size or Theme.Font.body, color or C.text, justify or "LEFT")
    text:SetWordWrap(false)
    return text
end

function UI:CreateTargetButton(parent, index, target)
    local button = Theme:CreateButton(parent, 44, "", "disclosure")
    button:SetHeight(44)
    button.targetID = target.id
    button:SetScript("OnClick", function(control) UI:SelectTarget(control.targetID) end)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(32, 32); button.icon:SetPoint("CENTER", 0, 0); button.icon:SetTexture(TargetIcon(target))
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.label:Hide()
    button.meta = self:Text(button, Theme.Font.meta, C.muted); button.meta:Hide()
    Theme:BindTooltip(button, target.title, { { text = target.expansionLabel .. " · " .. target.routeLabel, color = C.muted } })
    return button
end

function UI:CreateArchiveButton(parent)
    local button = Theme:CreateButton(parent, 44, "", "disclosure")
    button:SetHeight(44)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(32, 32); button.icon:SetPoint("CENTER", 0, 0); button.icon:SetTexture(ArchiveIcon())
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.label:Hide()
    button:SetScript("OnClick", function() UI:SelectTargetPage(UI:IsArchivePage() and "active" or "archived") end)
    Theme:BindTooltip(button, "绝版目标", { { text = "查看已绝版传说物品", color = C.muted } })
    return button
end

function UI:GetTargetBarLayout(width)
    local targets = self:GetDirectoryTargets()
    local startX = 58
    local gap = Theme.Space.xs
    local main = self.details and self.details.main
    local bar = main and main.targets
    local barWidth = width or (bar and bar:GetWidth()) or 900
    local available = math.max(1, barWidth - startX - Theme.Space.xs)
    local archiveReserve = 44 + gap
    local targetAvailable = math.max(1, available - archiveReserve)
    local buttonSize = math.max(36, math.min(44, math.floor((targetAvailable - gap * math.max(0, #targets - 1)) / math.max(1, #targets))))
    local columns = math.max(1, math.floor((targetAvailable + gap) / (buttonSize + gap)))
    local rows = math.max(1, math.ceil(#targets / columns))
    return { startX=startX, gap=gap, buttonSize=buttonSize, columns=columns, rows=rows, height=Theme.Space.xs + rows * buttonSize + math.max(0, rows - 1) * gap + Theme.Space.xs }
end

function UI:LayoutTargetBar(width)
    local bar = self.details.main.targets
    local layout = self:GetTargetBarLayout(width)
    local targets = self:GetDirectoryTargets()
    local archiveButton = bar.archiveButton
    bar:SetHeight(layout.height)
    for _, button in pairs(bar.buttons) do button:Hide() end
    archiveButton:Hide()
    for index, target in ipairs(targets) do
        local button = bar.buttons[target.id]
        local row = math.floor((index - 1) / layout.columns)
        local column = (index - 1) % layout.columns
        button:ClearAllPoints(); button:SetSize(layout.buttonSize, layout.buttonSize); button:SetPoint("TOPLEFT", layout.startX + column * (layout.buttonSize + layout.gap), -(Theme.Space.xxs + row * (layout.buttonSize + layout.gap)))
        button.icon:SetSize(math.max(26, layout.buttonSize - 10), math.max(26, layout.buttonSize - 10))
        button:Show()
    end
    archiveButton:ClearAllPoints(); archiveButton:SetSize(layout.buttonSize, layout.buttonSize); archiveButton:SetPoint("TOPRIGHT", -Theme.Space.xs, -Theme.Space.xxs)
    archiveButton.icon:SetSize(math.max(26, layout.buttonSize - 10), math.max(26, layout.buttonSize - 10))
    archiveButton:SetState(self:IsArchivePage() and "selected" or "default")
    Theme:BindTooltip(archiveButton, self:IsArchivePage() and "返回传说目标" or "绝版目标", { { text = self:IsArchivePage() and "返回当前与待接入目标" or "查看已绝版传说物品", color = C.muted } })
    archiveButton:Show()
    local divider = bar.archiveDivider
    divider:ClearAllPoints(); divider:SetPoint("RIGHT", archiveButton, "LEFT", -math.floor(layout.gap / 2), 0); divider:SetHeight(math.max(1, layout.height - Theme.Space.xs * 2)); divider:Show()
    bar.title:SetText(self:IsArchivePage() and "绝版目标" or "传说目标")
end

function UI:CreateMain(parent)
    local frame = CreateFrame("Frame", nil, parent); frame:SetAllPoints(parent)
    frame.targets = CreateFrame("Frame", nil, frame); frame.targets:SetHeight(64); frame.targets:SetPoint("TOPLEFT", Theme.Space.sm, -Theme.Space.sm); frame.targets:SetPoint("TOPRIGHT", -Theme.Space.sm, -Theme.Space.sm)
    frame.targets.bg = frame.targets:CreateTexture(nil, "BACKGROUND"); frame.targets.bg:SetAllPoints(); frame.targets.bg:SetColorTexture(C.nav[1], C.nav[2], C.nav[3], 0.82)
    frame.targets.title = self:Text(frame.targets, Theme.Font.assist, C.muted); frame.targets.title:SetPoint("TOPLEFT", Theme.Space.xs, -Theme.Space.xs); frame.targets.title:SetText("传说目标")
    frame.targets.buttons = {}
    for index, target in ipairs(Addon.Catalog:GetTargets()) do frame.targets.buttons[target.id] = self:CreateTargetButton(frame.targets, index, target) end
    frame.targets.archiveButton = self:CreateArchiveButton(frame.targets)
    frame.targets.archiveDivider = frame.targets:CreateTexture(nil, "ARTWORK")
    frame.targets.archiveDivider:SetWidth(1); frame.targets.archiveDivider:SetColorTexture(C.line[1], C.line[2], C.line[3], 0.9)

    frame.detail = CreateFrame("Frame", nil, frame); frame.detail:SetPoint("TOPLEFT", frame.targets, "BOTTOMLEFT", 0, -Theme.Space.sm); frame.detail:SetPoint("BOTTOMRIGHT", -Theme.Space.sm, Theme.Space.sm)
    frame.detail.title = self:Text(frame.detail, Theme.Font.section); frame.detail.title:SetPoint("TOPLEFT", 0, 0)
    frame.detail.badge = self:Text(frame.detail, Theme.Font.assist, C.accent, "RIGHT"); frame.detail.badge:SetPoint("TOPRIGHT", 0, 0)
    frame.detail.meta = self:Text(frame.detail, Theme.Font.assist, C.muted); frame.detail.meta:SetPoint("TOPLEFT", frame.detail.title, "BOTTOMLEFT", 0, -Theme.Space.xxs)
    frame.detail.route = self:Text(frame.detail, Theme.Font.assist, C.text); frame.detail.route:SetPoint("TOPLEFT", frame.detail.meta, "BOTTOMLEFT", 0, -Theme.Space.sm); frame.detail.route:SetPoint("TOPRIGHT", 0, 0); frame.detail.route:SetWordWrap(true); frame.detail.route:SetJustifyV("TOP"); frame.detail.route:SetHeight(58)
    frame.detail.header = CreateFrame("Frame", nil, frame.detail); frame.detail.header:SetHeight(Theme.Table.headerHeight); frame.detail.header:SetPoint("TOPLEFT", frame.detail.route, "BOTTOMLEFT", 0, -Theme.Space.sm); frame.detail.header:SetPoint("TOPRIGHT", 0, 0)
    frame.detail.header.bg = frame.detail.header:CreateTexture(nil, "BACKGROUND"); frame.detail.header.bg:SetAllPoints(); frame.detail.header.bg:SetColorTexture(C.chrome[1], C.chrome[2], C.chrome[3], 0.96)
    frame.detail.header.cells = {}
    for _, data in ipairs({ { "character", "角色" }, { "stage", "当前检查点" }, { "progress", "进度" }, { "action", "下一步" } }) do frame.detail.header.cells[data[1]] = self:Text(frame.detail.header, Theme.Font.assist, C.muted); frame.detail.header.cells[data[1]]:SetText(data[2]) end
    -- Preserve a real right inset for the shared scrollbar; it must not sit
    -- on the final “下一步” cell when this target has a long roster.
    frame.detail.scroll = Theme:CreateScrollFrame(frame.detail); frame.detail.scroll:BindScrollbarGutter(frame.detail.header); frame.detail.scroll:SetPoint("TOPLEFT", frame.detail.header, "BOTTOMLEFT", 0, -Theme.Space.xxs); frame.detail.scroll:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.detail.content = CreateFrame("Frame", nil, frame.detail.scroll); frame.detail.content:SetWidth(1); frame.detail.scroll:SetScrollChild(frame.detail.content); frame.detail.rows = {}
    return frame
end

function UI:CreatePreview(parent)
    local frame = CreateFrame("Frame", nil, parent); frame:SetAllPoints(parent)
    frame.legend = CreateFrame("Frame", nil, frame); frame.legend:SetHeight(18); frame.legend:SetPoint("TOPLEFT", Theme.Space.xs, -Theme.Space.xs); frame.legend:SetPoint("TOPRIGHT", -Theme.Space.xs, -Theme.Space.xs)
    local legendOrder = { "completed", "in_progress", "obtainable", "pending_sync", "ineligible", "unavailable" }
    local offset = 0
    for _, id in ipairs(legendOrder) do
        local meta = STATUS[id]; local item = CreateFrame("Frame", nil, frame.legend); item:SetSize(52, 18); item:SetPoint("LEFT", offset, 0)
        item.icon = item:CreateTexture(nil, "ARTWORK"); item.icon:SetSize(12, 12); item.icon:SetPoint("LEFT", 0, 0); item.icon:SetTexture(meta.icon); item.icon:SetVertexColor(meta.color[1], meta.color[2], meta.color[3])
        item.label = self:Text(item, Theme.Font.meta, meta.color); item.label:SetPoint("LEFT", item.icon, "RIGHT", 2, 0); item.label:SetPoint("RIGHT", 0, 0); item.label:SetText(meta.label)
        offset = offset + 52
    end
    frame.header = CreateFrame("Frame", nil, frame); frame.header:SetHeight(Theme.Table.headerHeight); frame.header:SetPoint("TOPLEFT", frame.legend, "BOTTOMLEFT", 0, -Theme.Space.xxs); frame.header:SetPoint("TOPRIGHT", frame.legend, "BOTTOMRIGHT", 0, -Theme.Space.xxs); frame.header.bg = frame.header:CreateTexture(nil, "BACKGROUND"); frame.header.bg:SetAllPoints(); frame.header.bg:SetColorTexture(C.toolbar[1], C.toolbar[2], C.toolbar[3], 0.96); frame.header.cells = {}
    frame.scroll = Theme:CreateScrollFrame(frame); frame.scroll:BindScrollbarGutter(frame.header); frame.scroll:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 0, -Theme.Space.xxs); frame.scroll:SetPoint("BOTTOMRIGHT", -Theme.Space.xs, Theme.Space.xs)
    frame.content = CreateFrame("Frame", nil, frame.scroll); frame.content:SetWidth(1); frame.scroll:SetScrollChild(frame.content); frame.rows = {}
    return frame
end

function UI:CreateAccountPage(parent)
    self.details = CreateFrame("Frame", nil, parent); self.details:SetAllPoints(parent)
    self.details.main = self:CreateMain(self.details); self.details.preview = self:CreatePreview(self.details)
end

function UI:CreateMainRow(page, index)
    local parent = page.detail
    local row = CreateFrame("Button", nil, parent.content); row:SetHeight(ROW_HEIGHT); row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_HEIGHT)); row:SetPoint("TOPRIGHT", 0, -((index - 1) * ROW_HEIGHT))
    row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(row); row.outline = Theme:CreateCurrentCharacterOutline(row); row.cells = {}
    row.professionIcon = row:CreateTexture(nil, "ARTWORK"); row.professionIcon:SetSize(16, 16)
    for _, key in ipairs({ "character", "stage", "progress", "action" }) do row.cells[key] = self:Text(row, Theme.Font.body) end
    row:SetScript("OnMouseUp", function(control, button)
        if button ~= "LeftButton" and button ~= "RightButton" then return end
        local item = page.roster and page.roster[index]
        local target = UI:GetSelectedTarget()
        local state = item and target and TargetState(item.snapshot, target.id)
        if not item or not target or not target.manualEvidenceAllowed or not state then return end
        if button == "RightButton" and state.evidence and state.evidence.source == "manual" then UI:ConfirmManualEvidence(item.character, target.id, true); return end
        if button == "LeftButton" and state.status ~= "completed" then UI:ConfirmManualEvidence(item.character, target.id) end
    end)
    Theme:BindTooltip(row, nil, row.tooltipLines or {}); parent.rows[index] = row; return row
end

function UI:CreatePreviewRow(index)
    local parent = self.details.preview
    local row = CreateFrame("Button", nil, parent.content); row:SetHeight(Theme.Table.previewRowHeight); row:SetPoint("TOPLEFT", 0, -((index - 1) * Theme.Table.previewRowHeight)); row:SetPoint("TOPRIGHT", 0, -((index - 1) * Theme.Table.previewRowHeight))
    row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(row); row.outline = Theme:CreateCurrentCharacterOutline(row); row.cells = {}
    Theme:BindTooltip(row, nil, row.tooltipLines or {}); parent.rows[index] = row; return row
end

function UI:CreatePreviewHeaderCell(parent, field)
    if field.id == "character" then return self:Text(parent, Theme.Font.assist, C.muted) end
    local cell = Theme:CreateButton(parent, 1, "", "secondary")
    cell.icon = cell:CreateTexture(nil, "ARTWORK"); cell.icon:SetSize(16, 16); cell.icon:SetPoint("LEFT", Theme.Table.cellInset, 0); cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cell.label:SetFont(STANDARD_TEXT_FONT, Theme.Font.assist)
    -- The icon occupies the leading slot.  Center the target name within the
    -- remaining text area instead of centering icon and text as one group.
    cell.label:ClearAllPoints(); cell.label:SetPoint("LEFT", cell.icon, "RIGHT", Theme.Table.iconTextGap, 0); cell.label:SetPoint("RIGHT", -Theme.Table.iconTextTrailing, 0); cell.label:SetJustifyH("CENTER")
    cell:SetScript("OnClick", function(control) UI:OpenTarget(control.targetID) end)
    return cell
end

function UI:CreatePreviewTargetCell(row, targetID)
    local cell = Theme:CreateButton(row, 1, "", "secondary")
    cell.targetID = targetID
    cell.icon = cell:CreateTexture(nil, "ARTWORK"); cell.icon:SetSize(14, 14); cell.icon:SetPoint("LEFT", Theme.Table.cellInset, 0)
    cell.label:ClearAllPoints(); cell.label:SetPoint("LEFT", cell.icon, "RIGHT", Theme.Table.iconTextGap, 0); cell.label:SetPoint("RIGHT", -Theme.Table.iconTextTrailing, 0); cell.label:SetJustifyH("LEFT")
    cell:SetScript("OnClick", function(control) UI:OpenTarget(control.targetID) end)
    return cell
end

function UI:OpenTarget(targetID)
    local target = Addon.Catalog:GetTarget(targetID)
    if not target then return end
    self:SelectTarget(targetID)
    Addon.Core.AccountView:ShowPage("legendary")
end

function UI:LayoutMainHeader(page, width, context)
    local header = page.detail.header
    local characterWidth = Theme:GetCharacterRowHeaderWidth(true, context, context and context.characters)
    local tracks = { character = characterWidth, stage = 184, progress = 150, action = math.max(180, width - characterWidth - 334) }
    local titles = { character = "角色", stage = "当前检查点", progress = "进度", action = "下一步" }
    local offset = CELL_INSET
    for _, key in ipairs({ "character", "stage", "progress", "action" }) do
        local cell = header.cells[key]
        cell:SetText(titles[key]); cell:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        cell:ClearAllPoints(); cell:SetPoint("LEFT", offset, 0); cell:SetWidth(tracks[key] - CELL_PADDING); cell:Show()
        offset = offset + tracks[key]
    end
    return tracks
end

function UI:RefreshMain(context)
    local page, target = self.details.main, self:GetSelectedTarget()
    self._matrixRenderSerial = (tonumber(self._matrixRenderSerial) or 0) + 1
    if context then page.context = context end
    context = page.context or context
    page:Show(); page.detail:Show(); page.detail.header:Show(); page.detail.scroll:Show()
    page.detail.content:Show(); page.detail.scroll:SetVerticalScroll(0)
    self:LayoutTargetBar(page:GetWidth())
    local width = math.max(620, page.detail:GetWidth() or 620); local tracks = self:LayoutMainHeader(page, width, context)
    local roster = self:GetMainRoster(context, page.roster)
    page.roster = roster
    for id, button in pairs(page.targets.buttons) do
        button:SetState(id == target.id and "selected" or "default")
        local complete, total = 0, 0
        for _, item in ipairs(roster) do local state = DisplayState(item.snapshot, Addon.Catalog:GetTarget(id)); if state and not state.placeholder and state.status ~= "ineligible" then total = total + 1; if state.acquired then complete = complete + 1 end end end
        local targetDefinition = Addon.Catalog:GetTarget(id)
        local tooltipText = targetDefinition.archived and "已绝版 · 不可从零开始" or targetDefinition.availability == "catalog" and "待接入采集器" or string.format("%d/%d 已获得", complete, total)
        Theme:BindTooltip(button, targetDefinition.title, { { text = tooltipText, color = C.muted }, { text = id == target.id and "当前目标" or "点击查看路线", color = C.accent } })
    end
    page.detail.title:SetText(target.title); page.detail.meta:SetText(target.expansionLabel .. " · " .. target.routeLabel); page.detail.badge:SetText(target.archived and "已绝版" or target.availability == "obtainable" and "当前可获取" or target.availability == "catalog" and "待接入" or "历史归档")
    local lines = {}
    if target.id == "CLOAK" then lines = { "黑王子任务线：第 1–5 章；声望门槛与收集目标可能并行。", "选择角色行可查看当前任务、目标和行动。" } else for _, node in ipairs(target.nodes or {}) do lines[#lines + 1] = node.title .. " · " .. (node.boss or "任务材料") end end
    if #lines == 0 then lines = { target.routeDescription or "该目标的路线尚未接入。" } end
    page.detail.route:SetText(table.concat(lines, "\n"))
    local currentCharacter = Addon.Core.Characters:GetCurrent()
    for index, item in ipairs(roster) do
        local row = page.detail.rows[index] or self:CreateMainRow(page, index); local state = DisplayState(item.snapshot, target); local meta = StateMeta(state)
        local bg = Theme:GetDataRowColor(index); row.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4]); Theme:SetCurrentCharacterOutline(row.outline, currentCharacter and item.character.id == currentCharacter.id)
        Theme:ApplyDataColumnTints(row, { tracks.character, tracks.stage, tracks.progress, tracks.action }, ROW_HEIGHT)
        local red, green, blue = ClassColor(item.character); local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[item.character.class]
        if coords then row.professionIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"); row.professionIcon:SetTexCoord(unpack(coords)); row.professionIcon:ClearAllPoints(); row.professionIcon:SetPoint("LEFT", CELL_INSET, 0); row.professionIcon:Show() else row.professionIcon:Hide() end
        row.cells.character:SetText(CharacterLabel(item.character, context)); row.cells.character:SetTextColor(red, green, blue); row.cells.character:Show()
        row.cells.stage:SetText((state and state.stageLabel) or Theme.StatusText.unsynced); row.cells.stage:SetTextColor(C.text[1], C.text[2], C.text[3]); row.cells.stage:Show()
        row.cells.progress:SetText((state and state.progressText) or "—"); row.cells.progress:SetTextColor(meta.color[1], meta.color[2], meta.color[3]); row.cells.progress:Show()
        row.cells.action:SetText((state and state.nextAction) or "登录该角色后同步。"); row.cells.action:SetTextColor(C.muted[1], C.muted[2], C.muted[3]); row.cells.action:Show()
        local evidenceText = state and state.evidence and ({ real="自动检测", projection="测试投影", manual="玩家确认" })[state.evidence.source] or "—"
        row.tooltipLines = { { text=CharacterLabel(item.character, context), color={red,green,blue} }, { text="状态：" .. meta.label, color=meta.color }, { text="检查点：" .. (state and state.stageLabel or Theme.StatusText.unsynced), color=C.text }, { text="进度：" .. (state and state.progressText or "—"), color=C.muted }, { text="证据：" .. evidenceText, color=C.muted }, { text="下一步：" .. (state and state.nextAction or "登录该角色后同步。"), color=C.muted } }
        if item.snapshot and tonumber(item.snapshot.updatedAt) and tonumber(item.snapshot.updatedAt) > 0 and date then row.tooltipLines[#row.tooltipLines + 1] = { kind="pair", label="最近同步", value=date("%m-%d %H:%M", item.snapshot.updatedAt) } end
        Theme:BindTooltip(row, nil, row.tooltipLines)
        local offset = CELL_INSET
        for _, key in ipairs({ "character", "stage", "progress", "action" }) do local cell = row.cells[key]; cell:ClearAllPoints(); local iconOffset = key == "character" and (16 + Theme.Table.iconTextGap) or 0; cell:SetPoint("LEFT", offset + iconOffset, 0); cell:SetWidth(tracks[key] - CELL_PADDING - iconOffset); offset = offset + tracks[key] end
        row:Show()
    end
    for index = #roster + 1, #page.detail.rows do page.detail.rows[index]:Hide() end
    page.detail.content:SetHeight(math.max(1, #roster * ROW_HEIGHT)); page.detail.content:SetWidth(width); page.detail.scroll:SetContentHeight(page.detail.content:GetHeight()); page.detail.scroll:RefreshScrollbar()
    self:DebugMatrix("render:" .. tostring(self._lastRefreshReason or "page"))
end

function UI:GetMatrixColumns(context)
    local fixed = { { id="character", title="角色", previewMinWidth=Theme:GetCharacterRowHeaderWidth(false, context, context and context.characters) } }
    local targets = {}
    for _, target in ipairs(Addon.Catalog:GetTargets()) do
        -- 由 Core 的 preview field override 统一决策；插件只提供保存的
        -- 目标 ID 映射，不绕过 Core 的显示设置与页面上下文。
        if context:GetFieldVisible(target.id) then
            local preferredWidth, compactWidth = PreviewTargetWidths(target)
            targets[#targets + 1] = { id=target.id, title=target.shortTitle, target=target, previewMinWidth=preferredWidth, previewCompactMinWidth=compactWidth, defaultVisible=true }
        end
    end
    return fixed, targets
end

function UI:RefreshPreview(context)
    local page = self.details.preview; local fixed, candidates = self:GetMatrixColumns(context)
    -- Core has already selected a surface width for this pass, expanding up
    -- to its safe screen boundary before any target paging is allowed. Do not
    -- use a transient child-frame width here: it may still belong to the
    -- preceding layout pass and would paginate early.
    local surfaceWidth = context and context.surfaceAvailableWidth or page:GetWidth()
    local width = math.max(1, surfaceWidth - Theme.Space.xs * 2); local fixedWidth = 0
    for _, field in ipairs(fixed) do fixedWidth = fixedWidth + field.previewMinWidth end
    if #candidates > 0 then
        local targetWidth = Addon.Core.AccountView:FitRepeatedColumnWidth(width, fixedWidth, #candidates, candidates[1].previewMinWidth, candidates[1].previewCompactMinWidth)
        for _, field in ipairs(candidates) do field.previewMinWidth = targetWidth end
    end
    local visible, info = Addon.Core.AccountView:GetColumnPageByWidth("legendary", "targets", candidates, width, fixedWidth, function(field) return field.previewMinWidth end)
    -- Core owns the title-bar chrome and the saved page index.  The matrix only
    -- supplies its stable target slice, so headers and cells always share it.
    page.pagerHost = page.pagerHost or CreateFrame("Frame", nil, page)
    Addon.Core.AccountView:UpdateColumnPager(page.pagerHost, "legendary", "targets", info, nil, "目标")
    if info.pages > 1 then
        local pagerWidth = Addon.Core.AccountView:GetColumnPagerWidth("目标", info.total)
        page.pagerHost:SetSize(pagerWidth, Theme.Size.compact)
        context:SetTitleBarControl(page.pagerHost, pagerWidth)
    else
        context:ClearTitleBarControl()
    end
    local columns = {}; for _, field in ipairs(fixed) do columns[#columns+1]=field end; for _, field in ipairs(visible) do columns[#columns+1]=field end
    local offset = CELL_INSET
    local rendered = {}
    for _, field in ipairs(columns) do
        local cell = page.header.cells[field.id] or self:CreatePreviewHeaderCell(page.header, field); page.header.cells[field.id]=cell
        if field.id == "character" then cell:SetText(field.title) else cell.targetID=field.id; cell.icon:SetTexture(TargetIcon(field.target)); cell.label:SetText(field.title); Theme:BindTooltip(cell, field.target.title, { { text=field.target.expansionLabel .. " · " .. field.target.routeLabel, color=C.muted }, { text="点击查看路线", color=C.accent } }) end
        cell:ClearAllPoints(); cell:SetPoint("LEFT", offset, 0); cell:SetSize(Theme:GetTableCellContentWidth(field.previewMinWidth), Theme.Table.headerHeight); cell:Show(); field.yiboOffset=offset; rendered[field.id]=true; offset=offset+field.previewMinWidth
    end
    for id, cell in pairs(page.header.cells) do if not rendered[id] then cell:Hide() end end
    local currentCharacter = Addon.Core.Characters:GetCurrent(); local roster = self:GetVisibleCharacters(context.characters)
    for index,item in ipairs(roster) do
        local row = page.rows[index] or self:CreatePreviewRow(index); local bg = Theme:GetDataRowColor(index); row.bg:SetColorTexture(bg[1],bg[2],bg[3],bg[4]); Theme:SetCurrentCharacterOutline(row.outline,currentCharacter and item.character.id==currentCharacter.id)
        -- Cells and column tints share Core's left inset. The row itself is
        -- widened below to the scroll viewport so its zebra background and
        -- right-side safety margin never stop at the final target column.
        Theme:ApplyDataColumnTints(row, columns, Theme.Table.previewRowHeight, CELL_INSET)
        local red,green,blue=ClassColor(item.character); row.tooltipLines={{text=CharacterLabel(item.character, context),color={red,green,blue}}}
        for _,field in ipairs(columns) do
            -- Core measures row identities using body 16px.  Use that same
            -- role here; assist 14px made the Core-owned column look as if it
            -- had a spurious right reserve despite its correct measurement.
            local cell=row.cells[field.id] or (field.id=="character" and self:Text(row,Theme.Font.body) or self:CreatePreviewTargetCell(row,field.id)); row.cells[field.id]=cell; cell:ClearAllPoints(); cell:SetPoint("LEFT",field.yiboOffset,0); cell:SetWidth(Theme:GetTableCellContentWidth(field.previewMinWidth)); if field.id ~= "character" then cell:SetHeight(Theme.Table.previewRowHeight) end; cell:Show()
            if field.id=="character" then cell:SetText(CharacterLabel(item.character, context));cell:SetTextColor(red,green,blue) else
                local projection=CellProjection(item.snapshot,field.target); cell.targetID=field.id; cell.icon:SetTexture(projection.icon); cell.icon:SetVertexColor(projection.color[1],projection.color[2],projection.color[3]); cell.label:SetText(projection.value); cell.label:SetTextColor(projection.color[1],projection.color[2],projection.color[3])
                Theme:BindTooltip(cell, field.target.title, { { text="状态："..projection.status, color=projection.color }, { text="进度："..projection.tooltipValue, color=C.text }, { text="证据："..projection.evidence, color=C.muted }, { text="点击进入传说之路", color=C.accent } })
            end
        end
        for id,cell in pairs(row.cells) do if not rendered[id] then cell:Hide() end end; Theme:BindTooltip(row,nil,row.tooltipLines); row:Show()
    end
    for index=#roster+1,#page.rows do page.rows[index]:Hide() end
    local matrixWidth = math.max(1, offset + CELL_INSET)
    page.content:SetWidth(matrixWidth);page.content:SetHeight(math.max(1,#roster*Theme.Table.previewRowHeight));page.scroll:SetContentHeight(page.content:GetHeight());page.scroll:RefreshScrollbar()
    for _, field in ipairs(columns) do field.yiboOffset = nil end
end

function UI:RefreshDetails(context)
    self.accountContext=context;local preview=context and context.preview==true;self.details.main:SetShown(not preview);self.details.preview:SetShown(preview);if preview then self:RefreshPreview(context) else self:RefreshMain(context) end
end
function UI:GetPreviewColumns()
    return Addon.db.settings.previewColumns
end
function UI:SetPreviewFieldVisible(id,visible) Addon.db.settings.previewColumns[id]=not not visible;if Addon.Core.AccountView then Addon.Core.AccountView:RefreshPage() end end
function UI:GetSurfaceMetrics(context)
    local preview=context and context.preview;local rows=#self:GetVisibleCharacters(context and context.characters)
    if preview then
        local fixed, targets = self:GetMatrixColumns(context)
        local width = 0
        for _, field in ipairs(fixed) do width = width + field.previewMinWidth end
        for _, field in ipairs(targets) do width = width + field.previewMinWidth end
        return {minContentWidth=310,naturalContentWidth=width+Theme.Space.xs*2,minContentHeight=122,naturalContentHeight=Theme.Space.xs+18+Theme.Space.xxs+Theme.Table.headerHeight+Theme.Space.xxs+rows*Theme.Table.previewRowHeight+Theme.Space.xs,fixedLeftWidth=fixed[1] and fixed[1].previewMinWidth or 0,fixedTopHeight=18+Theme.Space.xxs+Theme.Table.headerHeight,horizontalOverflow="paginate",verticalOverflow="content"}
    end
    local targetBar = self:GetTargetBarLayout(context and context.surfaceAvailableWidth or 900)
    return {minContentWidth=720,naturalContentWidth=910,minContentHeight=270,naturalContentHeight=math.min(640,targetBar.height+126+rows*ROW_HEIGHT),horizontalOverflow="none",verticalOverflow="content"}
end
-- Core uses the page's natural surface metrics for this matrix. Do not expose
-- a second post-render height measurement: asynchronous refreshes can run
-- while anchors are settling and would otherwise resize the shared window
-- from a transient zero-height detail frame.
function UI:PrintStatus() local store,character=Addon:GetCharacterStore();local target=self:GetSelectedTarget();local snapshot=character and (Addon.runtime.snapshotsByCharacter[character.id] or (store and store.snapshot));local state=snapshot and TargetState(snapshot,target.id);Addon:Print(target.shortTitle.."："..(state and state.stageLabel or Theme.StatusText.unsynced)) end
function UI:ConfirmManualEvidence(character, targetID, revoke)
    StaticPopupDialogs.YIBO_LEGENDARY_MANUAL = {
        text = revoke and string.format("撤销 %s 的 %s 人工确认？", CharacterLabel(character), (Addon.Catalog:GetTarget(targetID) or {}).title or targetID) or string.format("确认 %s 已获得 %s？\n不会伪装成自动检测，仅记录玩家确认。", CharacterLabel(character), (Addon.Catalog:GetTarget(targetID) or {}).title or targetID),
        button1 = revoke and "撤销确认" or "标记已获得", button2 = "取消", timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function() if revoke then Addon.Model:ClearManualEvidence(character.id, targetID) else Addon.Model:SetManualEvidence(character.id, targetID) end; Addon:Refresh("manual") end,
    }
    StaticPopup_Show("YIBO_LEGENDARY_MANUAL")
end

function UI:ToggleDetails() Addon.Core.AccountView:Toggle("legendary") end

function UI:GetPreviewSettingsFields()
    local fields = {}
    for _, target in ipairs(Addon.Catalog:GetTargets()) do
        fields[#fields + 1] = { id=target.id, title=target.shortTitle, defaultVisible=true }
    end
    return fields
end

function UI:Initialize()
    Addon.Core.AccountView:RegisterPage(Addon.NAME,{id="legendary",title="传说之路",icon="Interface\\AddOns\\YiboLegendary\\Media\\YiboLegendaryIcon-v1",order=20,defaultEnabled=true,previewEnabled=true,scope={mode="realms",allTitle="所有服务器"},characterFilter={defaultExpression="",GetExpression=function()return Addon.db.settings.levelExpr or "" end,SetExpression=function(expression)local valid,normalized,bad=Addon.Core.LevelFilter:Validate(expression or "");if not valid then return false,bad end;Addon.db.settings.levelExpr=normalized;UI:Refresh();return true,normalized end},HasCharacterSnapshot=function(character)local store=Addon.db.byCharacter[character.id];return (character.level or 0)>=90 and (Addon.runtime.snapshotsByCharacter[character.id] or (store and store.snapshot))~=nil end,GetEligibleCharacters=function(characters)return UI:GetEligibleCharacters(characters) end,settings={title="传说之路",description="页面、入口、角色范围和悬停目标列由 Core 统一管理；传说路线与角色快照由本插件保存。",CreateSettingsPanel=function(parent,host)
        local section=host.createSection(parent,"业务设置"); section:SetHeight(70)
        local label=host.createText(section,12,C.muted); label:SetPoint("TOPLEFT",4,-4); label:SetText("索利达尔人工证据保留在角色数据中，可在角色缓存清理时一并删除。")
        return 70
    end},fields=UI:GetPreviewSettingsFields(),GetPreviewFields=function()return UI:GetPreviewColumns() end,SetPreviewFieldVisible=function(id,visible)Addon.db.settings.previewColumns[id]=not not visible;if Addon.Core.AccountView then Addon.Core.AccountView:RefreshPage() end end,GetSurfaceMetrics=function(context)return UI:GetSurfaceMetrics(context) end,Create=function(parent)UI:CreateAccountPage(parent) end,Refresh=function(_,context)UI:RefreshDetails(context) end,GetSummary=function(characters)return string.format("传说目标 %d · 已同步角色 %d",#Addon.Catalog:GetTargets(),#UI:GetVisibleCharacters(characters)) end,GetActions=function(characters)local actions={};for _,item in ipairs(UI:GetVisibleCharacters(characters)) do for _,target in ipairs(Addon.Catalog:GetTargets()) do local state=TargetState(item.snapshot,target.id);if state and(state.status=="obtainable" or state.status=="in_progress")then actions[#actions+1]={priority=1,title=CharacterLabel(item.character).." · "..target.shortTitle,text=state.nextAction}end end end;return actions end})
    Addon.Core.Entry:RegisterBusinessEntry(Addon.NAME,{id="YiboLegendary",brokerName="YiboLegendary",pageID="legendary",text="[Yibo] 传说之路",icon="Interface\\AddOns\\YiboLegendary\\Media\\YiboLegendaryIcon-v1"})
end
function UI:Refresh(reason)
    self._lastRefreshReason = reason or "unspecified"
    if Addon.Core.AccountView then Addon.Core.AccountView:RefreshPage() end
end
