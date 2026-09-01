local Addon = _G.YiboLegendary
local UI = {}
Addon.UI = UI

local Theme = _G.YiboCore.UITheme
local C = Theme.Colors
local ROW_HEIGHT = Theme.Table.rowHeight
local CELL_INSET = Theme.Table.cellInset
local CELL_PADDING = Theme.Table.cellPadding

local STATUS = {
    completed = { label = "已获得 ✓", color = C.success }, available = { label = "可推进", color = C.accent },
    in_progress = { label = "进行中", color = { 1, 0.78, 0.34 } }, obtainable = { label = "本周可刷", color = { 0.48, 0.76, 0.96 } },
    not_started = { label = "未开始", color = C.muted }, unavailable = { label = "已绝版 ⊘", color = { 1, 0.48, 0.5 } },
    ineligible = { label = "— 不适用", color = C.muted }, unknown = { label = "未知", color = { 1, 0.48, 0.5 } },
}

local PREVIEW_FIELDS = {
    { id = "character", title = "角色", minWidth = 160, previewMinWidth = 150, defaultVisible = true },
    { id = "CLOAK", title = "橙披", minWidth = 170, previewMinWidth = 160, defaultVisible = true },
    { id = "THUNDERFURY", title = "风剑", minWidth = 180, previewMinWidth = 160, defaultVisible = true },
}

local function CharacterLabel(character) return (character.name or "未知角色") .. "-" .. (character.realm or "未知服务器") end
local function TargetState(snapshot, id) return snapshot and snapshot.targets and snapshot.targets[id] end
local function StateMeta(state) return STATUS[state and state.status or "unknown"] or STATUS.unknown end
local function ClassColor(character)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[character.class or ""]
    if color then return color.r, color.g, color.b end
    return C.text[1], C.text[2], C.text[3]
end

function UI:GetEligibleCharacters(characters)
    local result = {}
    for _, character in ipairs(characters or Addon.Core.Characters:GetAll()) do
        local store = Addon.db.byCharacter[character.id]
        if (character.level or 0) >= 90 and store and store.snapshot then result[#result + 1] = character end
    end
    return result
end

function UI:GetVisibleCharacters(characters)
    local result = {}
    for _, character in ipairs(self:GetEligibleCharacters(characters)) do
        result[#result + 1] = { character = character, snapshot = Addon.db.byCharacter[character.id].snapshot }
    end
    return result
end

function UI:GetSelectedTarget()
    return Addon.Catalog:GetTarget(Addon.db.settings.selectedTargetId) or Addon.Catalog:GetTarget("CLOAK")
end
function UI:SelectTarget(id) if Addon.Catalog:GetTarget(id) then Addon.db.settings.selectedTargetId = id; self:Refresh() end end

function UI:Text(parent, size, color, justify)
    local text = Theme:CreateText(parent, size or Theme.Font.body, color or C.text, justify or "LEFT")
    text:SetWordWrap(false)
    return text
end

function UI:CreateTargetButton(parent, index, target)
    local button = Theme:CreateButton(parent, 148, target.shortTitle, "disclosure")
    button:SetPoint("TOPLEFT", Theme.Space.xs, -(Theme.Size.standard + Theme.Space.sm + (index - 1) * (Theme.Size.standard + Theme.Space.xs)))
    button.targetID = target.id
    button:SetScript("OnClick", function(control) UI:SelectTarget(control.targetID) end)
    button.label:ClearAllPoints(); button.label:SetPoint("TOPLEFT", 8, -3); button.label:SetPoint("TOPRIGHT", -8, -3)
    button.meta = self:Text(button, Theme.Font.meta, C.muted); button.meta:SetPoint("BOTTOMLEFT", 8, 2)
    return button
end

function UI:CreateMain(parent)
    local frame = CreateFrame("Frame", nil, parent); frame:SetAllPoints(parent)
    frame.targets = CreateFrame("Frame", nil, frame); frame.targets:SetWidth(152); frame.targets:SetPoint("TOPLEFT", Theme.Space.sm, -Theme.Space.sm); frame.targets:SetPoint("BOTTOMLEFT", Theme.Space.sm, Theme.Space.sm)
    frame.targets.bg = frame.targets:CreateTexture(nil, "BACKGROUND"); frame.targets.bg:SetAllPoints(); frame.targets.bg:SetColorTexture(C.nav[1], C.nav[2], C.nav[3], 0.82)
    frame.targets.title = self:Text(frame.targets, Theme.Font.assist, C.muted); frame.targets.title:SetPoint("TOPLEFT", Theme.Space.xs, -Theme.Space.xs); frame.targets.title:SetText("传说目标")
    frame.targets.buttons = {}
    for index, target in ipairs(Addon.Catalog:GetTargets()) do frame.targets.buttons[target.id] = self:CreateTargetButton(frame.targets, index, target) end

    frame.detail = CreateFrame("Frame", nil, frame); frame.detail:SetPoint("TOPLEFT", frame.targets, "TOPRIGHT", Theme.Space.sm, 0); frame.detail:SetPoint("BOTTOMRIGHT", -Theme.Space.sm, Theme.Space.sm)
    frame.detail.title = self:Text(frame.detail, Theme.Font.section); frame.detail.title:SetPoint("TOPLEFT", 0, 0)
    frame.detail.badge = self:Text(frame.detail, Theme.Font.assist, C.accent, "RIGHT"); frame.detail.badge:SetPoint("TOPRIGHT", 0, 0)
    frame.detail.meta = self:Text(frame.detail, Theme.Font.assist, C.muted); frame.detail.meta:SetPoint("TOPLEFT", frame.detail.title, "BOTTOMLEFT", 0, -Theme.Space.xxs)
    frame.detail.route = self:Text(frame.detail, Theme.Font.assist, C.text); frame.detail.route:SetPoint("TOPLEFT", frame.detail.meta, "BOTTOMLEFT", 0, -Theme.Space.sm); frame.detail.route:SetPoint("TOPRIGHT", 0, 0); frame.detail.route:SetWordWrap(true); frame.detail.route:SetJustifyV("TOP"); frame.detail.route:SetHeight(58)
    frame.detail.header = CreateFrame("Frame", nil, frame.detail); frame.detail.header:SetHeight(ROW_HEIGHT); frame.detail.header:SetPoint("TOPLEFT", frame.detail.route, "BOTTOMLEFT", 0, -Theme.Space.sm); frame.detail.header:SetPoint("TOPRIGHT", 0, 0)
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
    frame.summary = self:Text(frame, Theme.Font.assist, C.muted); frame.summary:Hide()
    frame.header = CreateFrame("Frame", nil, frame); frame.header:SetHeight(ROW_HEIGHT); frame.header:SetPoint("TOPLEFT", Theme.Space.xs, -Theme.Space.xs); frame.header:SetPoint("TOPRIGHT", -Theme.Space.xs, -Theme.Space.xs); frame.header.bg = frame.header:CreateTexture(nil, "BACKGROUND"); frame.header.bg:SetAllPoints(); frame.header.bg:SetColorTexture(C.chrome[1], C.chrome[2], C.chrome[3], 0.96); frame.header.cells = {}
    frame.scroll = Theme:CreateScrollFrame(frame); frame.scroll:BindScrollbarGutter(frame.header); frame.scroll:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 0, -Theme.Space.xxs); frame.scroll:SetPoint("BOTTOMRIGHT", -Theme.Space.xs, Theme.Space.xs)
    frame.content = CreateFrame("Frame", nil, frame.scroll); frame.content:SetWidth(1); frame.scroll:SetScrollChild(frame.content); frame.rows = {}
    return frame
end

function UI:CreateAccountPage(parent)
    self.details = CreateFrame("Frame", nil, parent); self.details:SetAllPoints(parent)
    self.details.main = self:CreateMain(self.details); self.details.preview = self:CreatePreview(self.details)
end

function UI:CreateMainRow(index)
    local parent = self.details.main.detail
    local row = CreateFrame("Button", nil, parent.content); row:SetHeight(ROW_HEIGHT); row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_HEIGHT)); row:SetPoint("TOPRIGHT", 0, -((index - 1) * ROW_HEIGHT))
    row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(row); row.outline = Theme:CreateCurrentCharacterOutline(row); row.cells = {}
    for _, key in ipairs({ "character", "stage", "progress", "action" }) do row.cells[key] = self:Text(row, Theme.Font.body) end
    Theme:BindTooltip(row, nil, row.tooltipLines or {}); parent.rows[index] = row; return row
end

function UI:CreatePreviewRow(index)
    local parent = self.details.preview
    local row = CreateFrame("Button", nil, parent.content); row:SetHeight(Theme.Table.previewRowHeight); row:SetPoint("TOPLEFT", 0, -((index - 1) * Theme.Table.previewRowHeight)); row:SetPoint("TOPRIGHT", 0, -((index - 1) * Theme.Table.previewRowHeight))
    row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(row); row.outline = Theme:CreateCurrentCharacterOutline(row); row.cells = {}
    Theme:BindTooltip(row, nil, row.tooltipLines or {}); parent.rows[index] = row; return row
end

function UI:LayoutMainHeader(width)
    local header = self.details.main.detail.header
    local tracks = { character = 154, stage = 184, progress = 150, action = math.max(180, width - 488) }
    local offset = CELL_INSET
    for _, key in ipairs({ "character", "stage", "progress", "action" }) do local cell = header.cells[key]; cell:ClearAllPoints(); cell:SetPoint("LEFT", offset, 0); cell:SetWidth(tracks[key] - CELL_PADDING); offset = offset + tracks[key] end
    return tracks
end

function UI:RefreshMain(context)
    local page, target = self.details.main, self:GetSelectedTarget()
    local width = math.max(620, page.detail:GetWidth() or 620); local tracks = self:LayoutMainHeader(width)
    local roster = self:GetVisibleCharacters(context.characters)
    for id, button in pairs(page.targets.buttons) do
        button:SetState(id == target.id and "selected" or "default")
        local complete, total = 0, 0
        for _, item in ipairs(roster) do local state = TargetState(item.snapshot, id); if state and state.status ~= "ineligible" then total = total + 1; if state.acquired then complete = complete + 1 end end end
        button.meta:SetText(string.format("%d/%d 已获得", complete, total))
    end
    page.detail.title:SetText(target.title); page.detail.meta:SetText(target.expansionLabel .. " · " .. target.routeLabel); page.detail.badge:SetText(target.availability == "obtainable" and "当前可获取" or "历史归档")
    local lines = {}
    if target.id == "CLOAK" then lines = { "黑王子任务线：第 1–5 章；声望门槛与收集目标可能并行。", "选择角色行可查看当前任务、目标和行动。" } else for _, node in ipairs(target.nodes) do lines[#lines + 1] = node.title .. " · " .. (node.boss or "任务材料") end end
    page.detail.route:SetText(table.concat(lines, "\n"))
    local currentCharacter = Addon.Core.Characters:GetCurrent()
    for index, item in ipairs(roster) do
        local row = page.detail.rows[index] or self:CreateMainRow(index); local state = TargetState(item.snapshot, target.id); local meta = StateMeta(state)
        local bg = Theme:GetDataRowColor(index); row.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4]); Theme:SetCurrentCharacterOutline(row.outline, currentCharacter and item.character.id == currentCharacter.id)
        local red, green, blue = ClassColor(item.character); row.cells.character:SetText(CharacterLabel(item.character)); row.cells.character:SetTextColor(red, green, blue)
        row.cells.stage:SetText(state and state.stageLabel or Theme.StatusText.unsynced); row.cells.stage:SetTextColor(C.text[1], C.text[2], C.text[3])
        row.cells.progress:SetText(state and state.progressText or "—"); row.cells.progress:SetTextColor(meta.color[1], meta.color[2], meta.color[3])
        row.cells.action:SetText(state and state.nextAction or "登录该角色后同步。"); row.cells.action:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        row.tooltipLines = { { text=CharacterLabel(item.character), color={red,green,blue} }, { text="状态：" .. meta.label, color=meta.color }, { text="检查点：" .. (state and state.stageLabel or Theme.StatusText.unsynced), color=C.text }, { text="进度：" .. (state and state.progressText or "—"), color=C.muted }, { text="下一步：" .. (state and state.nextAction or "登录该角色后同步。"), color=C.muted } }
        if item.snapshot and tonumber(item.snapshot.updatedAt) and tonumber(item.snapshot.updatedAt) > 0 and date then row.tooltipLines[#row.tooltipLines + 1] = { kind="pair", label="最近同步", value=date("%m-%d %H:%M", item.snapshot.updatedAt) } end
        Theme:BindTooltip(row, nil, row.tooltipLines)
        local offset = CELL_INSET
        for _, key in ipairs({ "character", "stage", "progress", "action" }) do local cell = row.cells[key]; cell:ClearAllPoints(); cell:SetPoint("LEFT", offset, 0); cell:SetWidth(tracks[key] - CELL_PADDING); offset = offset + tracks[key] end
        row:Show()
    end
    for index = #roster + 1, #page.detail.rows do page.detail.rows[index]:Hide() end
    page.detail.content:SetHeight(math.max(1, #roster * ROW_HEIGHT)); page.detail.content:SetWidth(width); page.detail.scroll:SetContentHeight(page.detail.content:GetHeight()); page.detail.scroll:RefreshScrollbar()
end

function UI:GetPreviewFields(context)
    local fixed, targets = {}, {}
    for _, field in ipairs(PREVIEW_FIELDS) do
        if field.id == "character" or context:GetFieldVisible(field.id) then
            if field.id == "character" then fixed[#fixed + 1] = field else targets[#targets + 1] = field end
        end
    end
    return fixed, targets
end

function UI:RefreshPreview(context)
    local page = self.details.preview; local fixed, candidates = self:GetPreviewFields(context); local width = math.max(1, page:GetWidth() - Theme.Space.xs * 2); local fixedWidth = 0
    for _, field in ipairs(fixed) do fixedWidth = fixedWidth + field.previewMinWidth end
    local visible, info = Addon.Core.AccountView:GetColumnPageByWidth("legendary", "targets", candidates, width, fixedWidth, function(field) return field.previewMinWidth end)
    local columns = {}; for _, field in ipairs(fixed) do columns[#columns+1]=field end; for _, field in ipairs(visible) do columns[#columns+1]=field end
    local offset = CELL_INSET
    local rendered = {}
    for _, field in ipairs(columns) do local cell = page.header.cells[field.id] or self:Text(page.header, Theme.Font.assist, C.muted); page.header.cells[field.id]=cell; cell:SetText(field.title); cell:ClearAllPoints(); cell:SetPoint("LEFT", offset, 0); cell:SetWidth(field.previewMinWidth-CELL_PADDING); cell:Show(); field.yiboOffset=offset; rendered[field.id]=true; offset=offset+field.previewMinWidth end
    for _, field in ipairs(PREVIEW_FIELDS) do if not rendered[field.id] and page.header.cells[field.id] then page.header.cells[field.id]:Hide() end end
    local currentCharacter = Addon.Core.Characters:GetCurrent(); local roster = self:GetVisibleCharacters(context.characters)
    for index,item in ipairs(roster) do
        local row = page.rows[index] or self:CreatePreviewRow(index); local bg = Theme:GetDataRowColor(index); row.bg:SetColorTexture(bg[1],bg[2],bg[3],bg[4]); Theme:SetCurrentCharacterOutline(row.outline,currentCharacter and item.character.id==currentCharacter.id)
        local red,green,blue=ClassColor(item.character); row.tooltipLines={{text=CharacterLabel(item.character),color={red,green,blue}}};if item.snapshot and tonumber(item.snapshot.updatedAt) and tonumber(item.snapshot.updatedAt)>0 and date then row.tooltipLines[#row.tooltipLines+1]={kind="pair",label="最近同步",value=date("%m-%d %H:%M",item.snapshot.updatedAt)} end
        for _,field in ipairs(columns) do
            local cell=row.cells[field.id] or self:Text(row,Theme.Font.assist); row.cells[field.id]=cell; cell:ClearAllPoints(); cell:SetPoint("LEFT",field.yiboOffset,0); cell:SetWidth(field.previewMinWidth-CELL_PADDING); cell:Show()
            if field.id=="character" then cell:SetText(CharacterLabel(item.character));cell:SetTextColor(red,green,blue) else local state=TargetState(item.snapshot,field.id);local meta=StateMeta(state);cell:SetText((state and state.acquired and "已获得 ✓" or meta.label).." · "..(state and state.progressText or "—"));cell:SetTextColor(meta.color[1],meta.color[2],meta.color[3]);row.tooltipLines[#row.tooltipLines+1]={text=field.title.."："..(state and state.stageLabel or Theme.StatusText.unsynced),color=meta.color};row.tooltipLines[#row.tooltipLines+1]={text=state and state.nextAction or "登录该角色后同步。",color=C.muted} end
        end
        for _,field in ipairs(PREVIEW_FIELDS) do if not rendered[field.id] and row.cells[field.id] then row.cells[field.id]:Hide() end end; Theme:BindTooltip(row,nil,row.tooltipLines); row:Show()
    end
    for index=#roster+1,#page.rows do page.rows[index]:Hide() end
    page.content:SetWidth(math.max(1,offset+CELL_INSET));page.content:SetHeight(math.max(1,#roster*Theme.Table.previewRowHeight));page.scroll:SetContentHeight(page.content:GetHeight());page.scroll:RefreshScrollbar();page.summary:Hide()
    for _, field in ipairs(PREVIEW_FIELDS) do field.yiboOffset = nil end
end

function UI:RefreshDetails(context)
    self.accountContext=context;local preview=context and context.preview==true;self.details.main:SetShown(not preview);self.details.preview:SetShown(preview);if preview then self:RefreshPreview(context) else self:RefreshMain(context) end
end
function UI:GetPreviewColumns() return Addon.db.settings.previewColumns end
function UI:SetPreviewFieldVisible(id,visible) Addon.db.settings.previewColumns[id]=not not visible;if Addon.Core.AccountView then Addon.Core.AccountView:RefreshPage() end end
function UI:GetSurfaceMetrics(context)
    local preview=context and context.preview;local rows=#self:GetVisibleCharacters(context and context.characters)
    if preview then
        local fixed, targets = self:GetPreviewFields(context)
        local width = 0
        for _, field in ipairs(fixed) do width = width + field.previewMinWidth end
        for _, field in ipairs(targets) do width = width + field.previewMinWidth end
        return {minContentWidth=310,naturalContentWidth=width+Theme.Space.xs*2,minContentHeight=100,naturalContentHeight=Theme.Space.xs+ROW_HEIGHT+Theme.Space.xxs+rows*Theme.Table.previewRowHeight+Theme.Space.xs,fixedLeftWidth=fixed[1] and fixed[1].previewMinWidth or 0,fixedTopHeight=ROW_HEIGHT,horizontalOverflow="paginate",verticalOverflow="content"}
    end
    return {minContentWidth=720,naturalContentWidth=910,minContentHeight=270,naturalContentHeight=math.min(640,190+rows*ROW_HEIGHT),horizontalOverflow="none",verticalOverflow="content"}
end
function UI:GetMeasuredHeight() return self.details and self.details:GetHeight() or nil end
function UI:PrintStatus() local store=Addon:GetCharacterStore();local target=self:GetSelectedTarget();local state=store and TargetState(store.snapshot,target.id);Addon:Print(target.shortTitle.."："..(state and state.stageLabel or Theme.StatusText.unsynced)) end
function UI:ToggleDetails() Addon.Core.AccountView:Toggle("legendary") end

function UI:Initialize()
    Addon.Core.AccountView:RegisterPage(Addon.NAME,{id="legendary",title="传说之路",icon="Interface\\AddOns\\YiboLegendary\\Media\\YiboLegendaryIcon-v1",order=20,defaultEnabled=true,previewEnabled=true,scope={mode="realms",allTitle="所有服务器"},characterFilter={defaultExpression="",GetExpression=function()return Addon.db.settings.levelExpr or "" end,SetExpression=function(expression)local valid,normalized,bad=Addon.Core.LevelFilter:Validate(expression or "");if not valid then return false,bad end;Addon.db.settings.levelExpr=normalized;UI:Refresh();return true,normalized end},HasCharacterSnapshot=function(character)return (character.level or 0)>=90 and Addon.db.byCharacter[character.id] and Addon.db.byCharacter[character.id].snapshot~=nil end,GetEligibleCharacters=function(characters)return UI:GetEligibleCharacters(characters) end,settings={title="传说之路",description="页面、入口、角色范围和悬停目标列由 Core 统一管理；传说路线与角色快照由本插件保存。"},fields=PREVIEW_FIELDS,GetPreviewFields=function()return UI:GetPreviewColumns() end,SetPreviewFieldVisible=function(id,visible)UI:SetPreviewFieldVisible(id,visible) end,GetSurfaceMetrics=function(context)return UI:GetSurfaceMetrics(context) end,GetMeasuredHeight=function()return UI:GetMeasuredHeight() end,Create=function(parent)UI:CreateAccountPage(parent) end,Refresh=function(_,context)UI:RefreshDetails(context) end,GetSummary=function(characters)return string.format("传说目标 %d · 已同步角色 %d",#Addon.Catalog:GetTargets(),#UI:GetVisibleCharacters(characters)) end,GetActions=function(characters)local actions={};for _,item in ipairs(UI:GetVisibleCharacters(characters)) do for _,target in ipairs(Addon.Catalog:GetTargets()) do local state=TargetState(item.snapshot,target.id);if state and(state.status=="available" or state.status=="in_progress" or state.status=="obtainable")then actions[#actions+1]={priority=state.status=="available" and 2 or 1,title=CharacterLabel(item.character).." · "..target.shortTitle,text=state.nextAction}end end end;return actions end})
    Addon.Core.Entry:RegisterBusinessEntry(Addon.NAME,{id="YiboLegendary",brokerName="YiboLegendary",pageID="legendary",text="[Yibo] 传说之路",icon="Interface\\AddOns\\YiboLegendary\\Media\\YiboLegendaryIcon-v1"})
end
function UI:Refresh() if Addon.Core.AccountView then Addon.Core.AccountView:RefreshPage() end end
