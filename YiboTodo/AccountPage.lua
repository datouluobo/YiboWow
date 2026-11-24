local Addon = _G.YiboTodo
local Page = {}
Addon.AccountPage = Page
local Theme = _G.YiboCore.UITheme
local C = Theme.Colors

local ROW_HEIGHT, ROW_GAP, ICON_SIZE, ICON_GAP = Theme.Table.iconRowHeight, 0, 22, 3
-- Use the theme's standard small gutter to make adjacent icon families
-- scannable without adding a foreign divider treatment.
local COLUMN_GAP = Theme.Space.xs
local MIN_PROJECT_SLOTS = 1
local ICON_COLUMN_MIN_WIDTH = ICON_SIZE + 8

local function IconColumnWidth(headerTitle)
    -- Match the width consumed by Theme:SetMatrixHeader's built-in label inset.
    -- This does not add table-cell padding; it keeps the measured title inside
    -- the text region the shared header actually provides.
    local titleWidth = Theme:MeasureText(Theme.Font.assist, headerTitle or "") + Theme.Table.cellInset * 2
    return math.max(ICON_COLUMN_MIN_WIDTH, math.ceil(titleWidth))
end
local function StatusText(state)
    local key = ({ actionable = "STATUS.ACTIONABLE", ["ready-to-turn-in"] = "STATUS.TURN_IN", ["in-progress"] = "STATUS.TURN_IN", cooldown = "STATUS.COOLDOWN", completed = "STATUS.COMPLETED", estimated = "STATUS.ESTIMATED", ["skill-insufficient"] = "STATUS.SKILL_LOW", unknown = "STATUS.UNKNOWN" })[state]
    return key and Addon:T(key) or Theme.StatusText.unknown
end

local function ProjectColumnWidth(slots)
    slots = math.max(MIN_PROJECT_SLOTS, tonumber(slots) or 0)
    return slots * ICON_SIZE + (slots - 1) * ICON_GAP
end

local MIN_PROJECT_COLUMN_WIDTH = ProjectColumnWidth(MIN_PROJECT_SLOTS)

local function CharacterLabel(character, showRealm)
    local name = tostring(character and character.name or "?")
    local formatted = Addon.Core.Characters:FormatName(character, { nameMode = "short", realmMode = showRealm and "full" or "omit" })
    return formatted or name
end

local function CharacterColumnWidth(context)
    return Theme:GetCharacterRowHeaderWidth(true, context, context and context.characters)
end

local function SetProfessionIcon(icon, character)
    local coords = CLASS_ICON_TCOORDS and character and CLASS_ICON_TCOORDS[character.class]
    if not coords then icon:Hide(); return false end
    icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    icon:SetTexCoord(unpack(coords)); icon:Show()
    return true
end

local function ApplyCharacterColor(text, character)
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local color = colors and colors[character and character.class or ""]
    text:SetTextColor(color and color.r or C.text[1], color and color.g or C.text[2], color and color.b or C.text[3])
end

local function Text(parent, size, color, justify)
    return Theme:CreateText(parent, size, color, justify or "LEFT")
end

local function Release(pool, from)
    for index = from or 1, #pool do pool[index]:Hide() end
end

local function ProjectTooltip(project)
    local lines = { { kind = "pair", label = Addon:T("TOOLTIP.STATUS"), value = project.statusText or StatusText(project.state) or Addon:T("STATUS.INVALID") } }
    if project.state == "actionable" then
        lines[#lines + 1] = { kind = "text", text = Addon:T("TOOLTIP.READY_NOW") }
    elseif project.state == "cooldown" then
        lines[#lines + 1] = { kind = "text", text = Addon:T("TOOLTIP.COOLDOWN") }
    elseif project.state == "completed" then
        lines[#lines + 1] = { kind = "text", text = Addon:T("TOOLTIP.CYCLE_DONE") }
    elseif project.state == "ready-to-turn-in" or project.state == "in-progress" then
        lines[#lines + 1] = { kind = "text", text = Addon:T("TOOLTIP.RETURN_TURN_IN") }
    end
    if project.action then
        if project.action.actionMode == "use-item" and project.action.itemID then
            lines[#lines + 1] = { kind = "text", text = Addon:T("TOOLTIP.NOMI_ACTION") }
        elseif project.action.actionMode == "direct-craft" and project.action.castSpellID then
            lines[#lines + 1] = { kind = "text", text = Addon:T("TOOLTIP.CRAFT_FIRST") }
            lines[#lines + 1] = { kind = "text", text = Addon:T("TOOLTIP.OPEN_PROFESSION") }
        elseif project.action.fallbackMode == "open-and-select-recipe" then
            lines[#lines + 1] = { kind = "text", text = Addon:T("TOOLTIP.SELECT_RECIPE") }
        else
            lines[#lines + 1] = { kind = "text", text = Addon:T("TOOLTIP.OPEN_PROFESSION_LEFT") }
        end
    end
    if project.dailyTaskLabel then lines[#lines + 1] = { kind = "pair", label = Addon:T("TOOLTIP.DAILY_TASK"), value = project.dailyTaskLabel } end
    if project.state == "unknown" and not project.optimisticFarm then
        local detail = project.reason == "recipe-unlearned"
            and Addon:T("TOOLTIP.UNLEARNED_RECIPE")
            or Addon:T("TOOLTIP.NO_RELIABLE_COOLDOWN")
        lines[#lines + 1] = { kind = "text", text = detail }
    end
    if project.readyAt and project.state == "cooldown" then
        lines[#lines + 1] = { kind = "pair", label = Addon:T("TOOLTIP.RECOVERY"), value = date("%m-%d %H:%M", project.readyAt) }
    end
    if project.state == "skill-insufficient" then
        local current, required = tonumber(project.skillLevel), tonumber(project.requiredSkillLevel)
        local detail = current and required and Addon:T("TOOLTIP.SKILL_LOW_VALUE", current, required) or Addon:T("TOOLTIP.SKILL_LOW")
        lines[#lines + 1] = { kind = "text", text = detail }
    end
    if project.operationLabels and #project.operationLabels > 0 then lines[#lines + 1] = { kind = "pair", label = Addon:T("TOOLTIP.TODAY_RECORD"), value = table.concat(project.operationLabels, Addon:T("LIST.SEP")) } end
    if project.observedAt then lines[#lines + 1] = { kind = "pair", label = Addon:T("TOOLTIP.LAST_OBSERVED"), value = date("%m-%d %H:%M", project.observedAt) } end
    if project.nextResetAt then lines[#lines + 1] = { kind = "pair", label = Addon:T("TOOLTIP.ENDS_TODAY"), value = date("%m-%d %H:%M", project.nextResetAt) } end
    if project.optimisticFarm then lines[#lines + 1] = { kind = "text", text = Addon:T("TOOLTIP.FARM_PROJECTION") } end
    return lines
end

local function GetIcon(parent, index)
    parent.icons = parent.icons or {}
    local button = parent.icons[index]
    if button then return button end
    button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate,BackdropTemplate")
    button:SetSize(ICON_SIZE, ICON_SIZE)
    -- This is a bare Button rather than a click-enabled template.  Register
    -- the hardware click explicitly so its OnClick action is reliable on the
    -- target client instead of depending on template/default behavior.
    button:EnableMouse(true)
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("useOnKeyDown", false)
    -- Do not replace SecureActionButtonTemplate's OnClick handler.  It owns
    -- the protected item action; a post-click hook preserves that handler and
    -- still lets ordinary project icons run their Lua-side action afterward.
    button:HookScript("PostClick", function(self, mouseButton)
        if Addon.Core.BusinessItemActions and Addon.Core.BusinessItemActions:Handle(self, mouseButton) then return end
        if mouseButton ~= "LeftButton" and mouseButton ~= "RightButton" then return end
        -- Direct crafting from the interactive hover preview is a protected
        -- macro action.  It does not reliably emit UNIT_SPELLCAST_SUCCEEDED
        -- for this addon, so explicitly request the shared, debounced
        -- verification scan.  The scan refreshes the visible preview only
        -- after the real cooldown state is available.
        if mouseButton == "LeftButton" and self.professionAction and Addon.QueueProfessionCooldownRefresh then
            Addon:QueueProfessionCooldownRefresh({ button = self, project = self.actionProject, characterID = self.actionProject.characterID, groupID = self.actionProject.groupID })
        end
        if mouseButton == "LeftButton" and self.secureLeftAction then return end
        if mouseButton == "RightButton" and self.secureRightAction then return end
        if not self.actionProject or not self.actionIsCurrent or not Addon.Actions then return end
        Addon.Actions:Execute(self.actionProject, self.actionIsCurrent)
    end)
    -- Standalone icon frame inset inside its cell; it never touches the row rules.
    Theme:ApplyPixelBackdrop(button, { background = true, pixels = 1 })
    button.texture = button:CreateTexture(nil, "ARTWORK")
    button.texture:SetPoint("TOPLEFT", 2, -2); button.texture:SetPoint("BOTTOMRIGHT", -2, 2)
    button.check = button:CreateTexture(nil, "OVERLAY")
    button.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    button.check:SetSize(12, 12); button.check:SetPoint("BOTTOMRIGHT", 2, -2)
    button.skillInsufficient = button:CreateTexture(nil, "OVERLAY")
    button.skillInsufficient:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    button.skillInsufficient:SetSize(10, 10); button.skillInsufficient:SetPoint("BOTTOMRIGHT", -1, 1)
    button.unknown = button:CreateTexture(nil, "OVERLAY")
    button.unknown:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    button.unknown:SetSize(11, 11); button.unknown:SetPoint("TOPRIGHT", 1, 1)
    button.estimatedBorder = CreateFrame("Frame", nil, button, "BackdropTemplate")
    button.estimatedBorder:SetAllPoints()
    button.estimatedBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 5 })
    button.estimatedBorder:EnableMouse(false)
    button.actionableBorder = CreateFrame("Frame", nil, button, "BackdropTemplate")
    button.actionableBorder:SetAllPoints()
    Theme:ApplyPixelBackdrop(button.actionableBorder, { background = false, pixels = 1 })
    button.actionableBorder:EnableMouse(false)
    parent.icons[index] = button
    return button
end

local function SetIcon(button, project, isCurrentCharacter)
    local resolved
    if project.iconKind == "spell" and GetSpellTexture then resolved = GetSpellTexture(project.icon)
    elseif project.iconKind == "texture" then resolved = project.icon
    elseif project.iconKind == "currency" then
        if C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
            local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, project.icon)
            if ok and type(info) == "table" then resolved = info.iconFileID or info.icon end
        elseif type(GetCurrencyInfo) == "function" then
            local ok, _, _, icon = pcall(GetCurrencyInfo, project.icon)
            if ok then resolved = icon end
        end
    elseif GetItemIcon and project.icon then resolved = GetItemIcon(project.icon) end
    if not resolved and project.fallbackSpellID and GetSpellTexture then resolved = GetSpellTexture(project.fallbackSpellID) end
    local texture = resolved or project.fallbackIcon or "Interface\\Icons\\INV_Misc_QuestionMark"
    button:SetSize(ICON_SIZE, ICON_SIZE)
    button.texture:SetTexture(texture)
    local skillInsufficient = project.state == "skill-insufficient"
    -- A farm observation deliberately retains the model's unknown state, but
    -- it is not missing data: today's operation was witnessed. Do not cover
    -- its harvest basket with the generic missing-information question mark.
    local unknown = project.state == "unknown" and not project.operationObserved
    local readyToTurnIn = project.state == "ready-to-turn-in" or project.state == "in-progress"
    local completed = project.state == "completed"
    -- A checkmark on a colored icon means the objectives are ready to hand
    -- in; grey plus checkmark is reserved for a completed hand-in.
    button.texture:SetDesaturated(project.state == "cooldown" or completed or skillInsufficient or unknown)
    if project.state == "cooldown" or completed then button.texture:SetVertexColor(0.42, 0.48, 0.50, 0.92) else button.texture:SetVertexColor(1, 1, 1, 1) end
    if skillInsufficient then button.texture:SetVertexColor(0.82, 0.53, 0.28, 0.92) end
    if unknown then button.texture:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 0.76) end
    button.check:SetShown(project.state == "cooldown" or readyToTurnIn or completed)
    button.check:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
    button.skillInsufficient:SetShown(skillInsufficient)
    button.unknown:SetShown(unknown)
    button.estimatedBorder:SetShown(project.state == "estimated")
    button.estimatedBorder:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.9)
    button.actionableBorder:SetShown(isCurrentCharacter and project.state == "actionable")
    button.actionableBorder:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    button:SetBackdropColor(C.chrome[1], C.chrome[2], C.chrome[3], 0.95)
    button:SetBackdropBorderColor(C.matrixLine[1], C.matrixLine[2], C.matrixLine[3], C.matrixLine[4])
    button.actionProject = project.action and project or nil
    button.actionIsCurrent = isCurrentCharacter == true
    local action = project.action
    local itemID = action and action.actionMode == "use-item" and tonumber(action.itemID)
    local itemName = itemID and (action.itemName or (GetItemInfo and GetItemInfo(itemID)))
    local interactName = itemID and action.interactName
    local spellID = action and action.actionMode == "direct-craft" and tonumber(action.castSpellID)
    -- Nomi uses a secure item action. A loaded profession uses the player's
    -- verified DoTradeSkill macro on left click; right click stays on the
    -- normal action path and opens that profession panel.
    if not (InCombatLockdown and InCombatLockdown()) then
        local descriptor = Addon.Actions:Describe(project, isCurrentCharacter)
        local attributes = descriptor and descriptor.attributes or {}
        local secureItem, spellName = attributes.item1, descriptor and descriptor.spellName
        local secureSpell, leftMacro, rightMacro = nil, attributes.macrotext1, attributes.macrotext2
        local openProfessionMacro = descriptor and descriptor.openProfessionMacro
        local professionProvider = Addon.Providers.Registry:Get("profession-cooldown")
        local professionLoaded = spellID and professionProvider and professionProvider:IsProfessionLoaded(project.characterID, project.professionID)
        local professionName = spellID and isCurrentCharacter and project.professionName
        button:SetAttribute("type", secureItem and "item" or nil)
        button:SetAttribute("item", secureItem); button:SetAttribute("spell", nil); button:SetAttribute("macrotext", nil)
        for _, key in ipairs({ "type1", "item1", "spell1", "macrotext1", "type2", "macrotext2" }) do button:SetAttribute(key, attributes[key]) end
        button.secureItemAction = secureItem ~= nil
        button.secureLeftAction = secureItem ~= nil or leftMacro ~= nil
        button.secureRightAction = rightMacro ~= nil
        button.professionAction = descriptor and descriptor.professionAction or false
        if spellID and isCurrentCharacter then
            Addon.professionActionDiagnostics = Addon.professionActionDiagnostics or {}
            Addon.professionActionDiagnostics[#Addon.professionActionDiagnostics + 1] = {
                label = project.label, groupID = project.groupID, spellID = spellID, spellName = spellName,
                secureSpell = secureSpell, state = project.state, type = button:GetAttribute("type"),
                spell = button:GetAttribute("spell"), type1 = button:GetAttribute("type1"),
                spell1 = button:GetAttribute("spell1"), macrotext1 = button:GetAttribute("macrotext1"),
                macrotext2 = button:GetAttribute("macrotext2"), professionLoaded = professionLoaded == true,
                professionName = professionName, openProfessionMacro = openProfessionMacro,
                protected = button.IsProtected and button:IsProtected() or false,
            }
        end
        if itemID and isCurrentCharacter then
            Addon.nomiActionDiagnostic = {
                itemID = itemID, itemName = itemName, characterID = project.characterID, isCurrentCharacter = true,
                secureItem = secureItem, spellID = spellID, spellName = spellName, type = button:GetAttribute("type"), item = button:GetAttribute("item"), spell = button:GetAttribute("spell"),
                type1 = button:GetAttribute("type1"), item1 = button:GetAttribute("item1"), spell1 = button:GetAttribute("spell1"), type2 = button:GetAttribute("type2"),
                protected = button.IsProtected and button:IsProtected() or false,
            }
        end
    end
    button:SetScript("OnHide", function(self)
        if Addon.Core.BusinessItemActions then Addon.Core.BusinessItemActions:Unbind(self) end
        self.actionProject = nil; self.actionIsCurrent = false; self.secureLeftAction = false; self.secureRightAction = false; self.professionAction = false; self:SetAlpha(1)
    end)
    local lines = ProjectTooltip(project)
    if Addon.GoalTargets and Addon.GoalTargets.ref and Addon.Core.BusinessItemActions then
        local intent = Addon.GoalTargets:Intent(project, project.characterID or button.goalCharacterID)
        if intent and intent.scope.characterID then
            -- Disable the secure fallback on non-business physical buttons.
            if not (InCombatLockdown and InCombatLockdown()) then
                button:SetAttribute("type3", ""); button:SetAttribute("type4", ""); button:SetAttribute("type5", "")
            end
            Addon.Core.BusinessItemActions:Bind(button, { owner = Addon.NAME, GetIntent = function() return intent end,
                ConfigureCtrlLeft = function(enabled)
                    if InCombatLockdown and InCombatLockdown() then return false end
                    button:SetAttribute("ctrl-type1", enabled and "" or nil)
                    return true
                end,
                reservedButtons = { LeftButton = true, RightButton = true } })
            lines = Addon.Core.BusinessItemActions:TooltipLines(lines, button)
        else Addon.Core.BusinessItemActions:Unbind(button) end
    end
    Theme:BindTooltip(button, project.label, lines)
    button:Show()
end

-- Keep a direct-craft completion local to its originating control.  The
-- model snapshot is rebuilt only to obtain authoritative cooldown data; no
-- rows, headers, scrollbars, or preview geometry are touched.
function Page:RefreshProjectIcon(target)
    local button = target and target.button
    local original = target and target.project
    if not (button and original and button:IsShown() and button.actionProject == original) then return false end
    local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not current or current.id ~= target.characterID then return false end
    local snapshot = Addon.Snapshot and Addon.Snapshot:Build()
    local data = snapshot and snapshot.characters and snapshot.characters[target.characterID]
    for _, project in ipairs(data and data.professionProjects or {}) do
        if project.groupID == target.groupID then
            SetIcon(button, project, true)
            return true
        end
    end
    return false
end

local function RenderProjects(cell, projects, isCurrentCharacter, groupIndex, characterID)
    cell:Show()
    if #projects == 0 or (#projects == 1 and projects[1].state == "not-applicable") then
        Release(cell.icons or {}, 1)
        cell.empty:SetText("—"); cell.empty:Show()
        return
    end
    cell.empty:Hide()
    local width = math.max(ICON_SIZE, cell:GetWidth() or ICON_SIZE)
    local contentWidth = #projects * ICON_SIZE + math.max(0, #projects - 1) * ICON_GAP
    local x = math.max(0, math.floor((width - contentWidth) / 2))
    for index, project in ipairs(projects) do
        local icon = GetIcon(cell, index)
        icon:ClearAllPoints(); icon:SetPoint("LEFT", cell, "LEFT", x, 0)
        icon.goalCharacterID = characterID
        SetIcon(icon, project, isCurrentCharacter)
        x = x + ICON_SIZE + ICON_GAP
    end
    Release(cell.icons or {}, #projects + 1)
end

local function Cell(row, index)
    row.cells = row.cells or {}
    local cell = row.cells[index]
    if cell then return cell end
    cell = CreateFrame("Frame", nil, row)
    cell.empty = Text(cell, Theme.Font.body, C.muted, "CENTER"); cell.empty:SetAllPoints()
    row.cells[index] = cell
    return cell
end

local function HasCommonProjects(snapshot, characters)
    for _, character in ipairs(characters or {}) do
        local data = snapshot.characters[character.id]
        if data and #(data.commonProjects or {}) > 0 then return true end
    end
    return false
end

local function HasMonitoringProjects(snapshot, characters, groupID)
    for _, character in ipairs(characters or {}) do
        local data = snapshot.characters[character.id]
        if data and data.monitoringProjects and #(data.monitoringProjects[groupID] or {}) > 0 then return true end
    end
    return false
end

local function ProfessionColumnWidth(snapshot, characters)
    local slots = MIN_PROJECT_SLOTS
    for _, character in ipairs(characters or {}) do
        local data = snapshot.characters[character.id]
        slots = math.max(slots, #(data and data.professionProjects or {}))
    end
    return ProjectColumnWidth(slots)
end

local function HasFarmColumn()
    return Addon.Settings:IsMonitoringGroupEnabled("farm")
end

local function HasNomiColumn()
    return Addon.Settings:IsMonitoringGroupEnabled("nomi")
end

local function HasCookingColumn()
    return Addon.Settings:IsMonitoringGroupEnabled("cooking-daily")
end

local function DailyColumnWidth(snapshot, characters, groupID, headerTitle, contentOnly)
    local slots = MIN_PROJECT_SLOTS
    for _, character in ipairs(characters or {}) do
        local data = snapshot.characters[character.id]
        slots = math.max(slots, #(data and data.monitoringProjects and data.monitoringProjects[groupID] or {}))
    end
    if contentOnly then return ProjectColumnWidth(slots) end
    local headerWidth = Theme:MeasureText(Theme.Font.assist, headerTitle or "") + Theme.Table.cellPadding * 2
    return math.max(ProjectColumnWidth(slots), headerWidth)
end

local function Row(frame, index)
    local row = frame.rows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, frame.body, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)
    -- Fill only; rows touch (ROW_GAP = 0), so their rules come from
    -- SetRowBorder and each shared boundary is painted once.
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    row.professionIcon = row:CreateTexture(nil, "ARTWORK")
    row.professionIcon:SetSize(16, 16)
    row.name = Text(row, Theme.Font.body, C.text)
    row.status = Text(row, Theme.Font.body, C.muted, "LEFT")
    frame.rows[index] = row
    return row
end

-- Stacked rows share one pixel boundary: every row draws its sides and
-- bottom, and only the first row draws the matrix's top edge.
local function SetRowBorder(row, rowIndex)
    Theme:CreatePixelBorder(row, { color = C.matrixLine, sides = { top = rowIndex == 1, right = true, bottom = true, left = true } })
end

local function Header(frame, index)
    local header = frame.headers[index]
    if header then return header end
    header = Theme:CreateMatrixHeader(frame.header)
    frame.headers[index] = header
    return header
end

function Page.Create(frame)
    frame:SetClipsChildren(true)
    frame.header = CreateFrame("Frame", nil, frame); frame.header:SetHeight(Theme.Table.headerHeight)
    frame.account = CreateFrame("Frame", nil, frame, "BackdropTemplate"); frame.account:SetHeight(ROW_HEIGHT)
    -- The shared-account row sits directly above data row 1 (ROW_GAP = 0).
    -- It draws top and sides; the boundary below it is data row 1's top rule.
    frame.account:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    Theme:CreatePixelBorder(frame.account, { color = C.matrixLine, sides = { top = true, right = true, bottom = false, left = true } })
    frame.account.label = Text(frame.account, Theme.Font.assist, C.muted); frame.account.label:SetPoint("LEFT", 8, 0); frame.account.label:SetText(Addon:T("PAGE.ACCOUNT_SHARED"))
    frame.account.projects = CreateFrame("Frame", nil, frame.account)
    frame.account.projects.empty = Text(frame.account.projects, Theme.Font.body, C.muted, "CENTER"); frame.account.projects.empty:SetAllPoints()
    frame.scroll = Theme:CreateScrollFrame(frame)
    frame.scroll:BindScrollbarGutter(frame.header, frame.account)
    frame.body = CreateFrame("Frame", nil, frame.scroll)
    frame.scroll:SetScrollChild(frame.body)
    frame.emptyTitle = Text(frame, Theme.Font.section, C.text)
    frame.empty = Text(frame, Theme.Font.body, C.muted); frame.empty:SetWordWrap(true)
    frame.pagerAnchor = CreateFrame("Frame", nil, frame)
    frame.rows, frame.headers = {}, {}
end

local function ProjectColumns(snapshot, characters, showCommon)
    local columns = {}
    local function Add(title, width, key, group)
        columns[#columns + 1] = { title = title, width = width, key = key, group = group }
    end
    local function Daily(group, titleKey)
        if not Addon.Settings:IsMonitoringGroupEnabled(group) then return end
        if group == "darkmoon-faire" and not HasMonitoringProjects(snapshot, characters, group) then return end
        local title = Addon:T(titleKey)
        Add(title, DailyColumnWidth(snapshot, characters, group, title, group == "brilltron-4000"), nil, group)
    end
    if Addon.Settings:IsMonitoringGroupEnabled("profession-cooldown") then
        Add(Addon:T("COLUMN.PROFESSION"), ProfessionColumnWidth(snapshot, characters), "professionProjects")
    end
    if Addon.Settings:IsMonitoringGroupEnabled("farm") and HasFarmColumn() then
        local title = Addon:T("COLUMN.FARM")
        Add(title, IconColumnWidth(title), "farmProjects")
    end
    if Addon.Settings:IsMonitoringGroupEnabled("nomi") and HasNomiColumn() then
        local title = Addon:T("COLUMN.NOMI")
        Add(title, IconColumnWidth(title), "nomiProjects")
    end
    Daily("jewelcrafting-daily", "COLUMN.JEWELCRAFTING")
    if HasCookingColumn() then Daily("cooking-daily", "COLUMN.COOKING") end
    Daily("fishing-daily", "COLUMN.FISHING")
    Daily("nat-pagle", "COLUMN.NAT")
    Daily("darkmoon-faire", "COLUMN.DARKMOON")
    Daily("brilltron-4000", "COLUMN.BRILLTRON")
    if showCommon and HasCommonProjects(snapshot, characters) then
        Add(Addon:T("COLUMN.COMMON"), MIN_PROJECT_COLUMN_WIDTH, "commonProjects")
    end
    return columns
end

local function ConfigureScroll(frame, top, tableWidth, contentHeight, inset)
    local scroll = frame.scroll
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -ROW_GAP)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset.right, inset.bottom)
    -- Match the Boss Tracker matrix: the scroll viewport owns the available
    -- page space, while the child owns only actual table content width.
    -- The shared scroll frame then decides whether a thumb is necessary.
    frame.body:SetSize(tableWidth, math.max(1, contentHeight))
    scroll:SetContentHeight(frame.body:GetHeight())
    scroll:RefreshScrollbar()
end

function Page.Refresh(frame, context)
    local snapshot, count = Addon.Snapshot:Build(), 0
    -- The diagnostic concerns only the actual character's secure button.
    -- Clear the prior frame's record before rebuilding pooled icon controls.
    Addon.nomiActionDiagnostic = nil
    Addon.professionActionDiagnostics = nil
    local showCommon = false
    local projects = ProjectColumns(snapshot, context.characters, showCommon)
    local characterWidth = CharacterColumnWidth(context)
    local inset = Theme:GetMatrixInsets(context.preview)
    local pageInfo
    if not context.preview then
        local view = Addon.Core.AccountView
        local rows, tableWidth = 0, characterWidth
        for _, character in ipairs(context.characters) do
            if snapshot.characters[character.id] then rows = rows + 1 end
        end
        for _, project in ipairs(projects) do tableWidth = tableWidth + project.width + COLUMN_GAP end
        local fixedHeight = inset.top + Theme.Table.headerHeight + inset.bottom
        local bodyHeight, edges = rows * (ROW_HEIGHT + ROW_GAP), inset.left + inset.right
        local budget = view:GetScrollSurfaceWidth(context, frame, bodyHeight, fixedHeight) - edges
        if tableWidth > budget and not context.columnPagerInFooter then
            budget = view:GetScrollSurfaceWidth(context, frame, bodyHeight, fixedHeight + Theme.Size.standard) - edges
        end
        projects, pageInfo = view:GetColumnPageByWidth("todo", "projects", projects, budget, characterWidth,
            function(column) return column.width + COLUMN_GAP end)
    end
    local pagerHeight = not context.columnPagerInFooter and pageInfo and pageInfo.pages > 1 and Theme.Size.standard or 0
    frame.pagerAnchor:ClearAllPoints()
    frame.pagerAnchor:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset.right, -inset.top)
    Addon.Core.AccountView:UpdateColumnPager(frame, "todo", "projects", pageInfo, frame.pagerAnchor, Addon:T("COLUMN.PROJECTS"))
    local columns = { { title = Addon:T("COLUMN.CHARACTER"), width = characterWidth } }
    local tableWidth = characterWidth
    for _, project in ipairs(projects) do
        columns[#columns + 1] = project
        tableWidth = tableWidth + project.width + COLUMN_GAP
    end
    frame.header:ClearAllPoints()
    frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", inset.left, -inset.top - pagerHeight)
    frame.header:SetSize(tableWidth, Theme.Table.headerHeight)
    local x = 0
    for index, definition in ipairs(columns) do
        local header = Header(frame, index); header:ClearAllPoints(); header:SetPoint("TOPLEFT", frame.header, "TOPLEFT", x, 0); header:SetSize(definition.width, Theme.Table.headerHeight)
        Theme:SetMatrixHeader(header, definition.title, { height=Theme.Table.headerHeight, fill=C.toolbar, rule=C.lineSoft })
        header.projectIcon = header.projectIcon or header:CreateTexture(nil, "OVERLAY")
        if definition.group == "brilltron-4000" then
            header.label:SetText("")
            header.projectIcon:SetTexture((GetItemIcon and GetItemIcon(87214)) or "Interface\\Icons\\INV_Misc_QuestionMark")
            header.projectIcon:SetSize(18, 18); header.projectIcon:ClearAllPoints(); header.projectIcon:SetPoint("CENTER"); header.projectIcon:Show()
        else
            header.projectIcon:Hide()
        end
        header:Show(); x = x + definition.width + COLUMN_GAP
    end
    Release(frame.headers, #columns + 1)
    local accountProjects = snapshot.accountActivities or {}
    frame.account:SetShown(showCommon and #accountProjects > 0)
    local top = frame.header
    if showCommon and #accountProjects > 0 then
        frame.account:ClearAllPoints(); frame.account:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 0, -ROW_GAP); frame.account:SetSize(tableWidth, ROW_HEIGHT)
        frame.account:SetBackdropColor(C.row[1], C.row[2], C.row[3], C.row[4])
        frame.account.label:SetWidth(characterWidth - 8)
        frame.account.projects:Show()
        frame.account.projects:ClearAllPoints(); frame.account.projects:SetPoint("TOP", 0, 0); frame.account.projects:SetPoint("BOTTOM", 0, 0)
        frame.account.projects:SetPoint("LEFT", characterWidth, 0); frame.account.projects:SetPoint("RIGHT", 0, 0)
        RenderProjects(frame.account.projects, accountProjects)
        top = frame.account
    end
    local y = 0
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    for _, character in ipairs(context.characters or {}) do
        local data = snapshot.characters[character.id]
        if data then
            count = count + 1
            local row = Row(frame, count)
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", frame.body, "TOPLEFT", 0, -y); row:SetSize(tableWidth, ROW_HEIGHT)
            local fill = Theme:GetDataRowColor(count)
            row:SetBackdropColor(fill[1], fill[2], fill[3], 0.9); SetRowBorder(row, count)
            Theme:ApplyDataColumnTints(row, columns, ROW_HEIGHT, 0, COLUMN_GAP)
            Theme:UpdateCurrentCharacterRowOutline(row, current and character.id == current.id)
            local hasIcon = SetProfessionIcon(row.professionIcon, character)
            if hasIcon then row.professionIcon:ClearAllPoints(); row.professionIcon:SetPoint("LEFT", Theme.Table.cellPadding, 0) end
            row.name:ClearAllPoints(); row.name:SetPoint("LEFT", Theme.Table.cellPadding + (hasIcon and (16 + Theme.Table.iconTextGap) or 0), 0); row.name:SetWidth(Theme:GetTableCellContentWidth(characterWidth) - (hasIcon and (16 + Theme.Table.iconTextGap) or 0))
            row.name:SetText(CharacterLabel(character, context and context.scope == "all")); ApplyCharacterColor(row.name, character)
            local offset = characterWidth + COLUMN_GAP
            for cellIndex, column in ipairs(projects) do
                local cell = Cell(row, cellIndex)
                cell:ClearAllPoints(); cell:SetPoint("LEFT", offset, 0); cell:SetSize(column.width, ROW_HEIGHT)
                local items = column.group and data.monitoringProjects[column.group] or data[column.key]
                RenderProjects(cell, items or {}, current and character.id == current.id, cellIndex, character.id)
                offset = offset + column.width + COLUMN_GAP
            end
            row.status:Hide()
            Release(row.cells or {}, #projects + 1)
            row:Show()
            y = y + ROW_HEIGHT + ROW_GAP
        end
    end
    Release(frame.rows, count + 1)
    frame.header:SetShown(count > 0)
    if count == 0 then Addon.Core.AccountView:UpdateColumnPager(frame, "todo", "projects", nil, frame.pagerAnchor) end
    frame.scroll:SetShown(count > 0)
    if count > 0 then ConfigureScroll(frame, top, tableWidth, y, inset) end
    frame.emptyTitle:SetShown(count == 0); frame.empty:SetShown(count == 0)
    if count == 0 then
        frame.emptyTitle:ClearAllPoints(); frame.emptyTitle:SetPoint("TOPLEFT", 24, -26); frame.emptyTitle:SetText(Addon:T("PAGE.EMPTY_TITLE"))
        frame.empty:ClearAllPoints(); frame.empty:SetPoint("TOPLEFT", 24, -56); frame.empty:SetPoint("TOPRIGHT", -24, -56); frame.empty:SetText(Addon:T("PAGE.EMPTY_BODY"))
    end
end

function Page.GetSurfaceMetrics(context)
    local snapshot, count = Addon.Snapshot:Build(), 0
    local characters = context and context.characters or {}
    local preview = context and context.preview
    for _, character in ipairs(characters) do if snapshot.characters[character.id] then count = count + 1 end end
    local inset = Theme:GetMatrixInsets(preview)
    local identityWidth = CharacterColumnWidth(context)
    local widest, natural = 0, identityWidth
    for _, column in ipairs(ProjectColumns(snapshot, characters, false)) do
        widest = math.max(widest, column.width + COLUMN_GAP)
        natural = natural + column.width + COLUMN_GAP
    end
    local height = inset.top + Theme.Table.headerHeight + math.max(1, math.min(20, count)) * (ROW_HEIGHT + ROW_GAP) + inset.bottom
    local edges = inset.left + inset.right
    return {
        minContentWidth = preview and natural + edges or identityWidth + widest + edges,
        naturalContentWidth = natural + edges,
        minContentHeight = 120,
        naturalContentHeight = height,
        horizontalOverflow = "paginate",
        verticalOverflow = "content",
    }
end

function Page.GetMeasuredHeight(frame)
    local pageHeight = frame:GetHeight() or 0
    local viewportHeight = frame.scroll and frame.scroll:GetHeight() or 0
    local bodyHeight = frame.body and frame.body:GetHeight() or 0
    if pageHeight <= 0 or viewportHeight <= 0 or bodyHeight <= 0 then return nil end
    return pageHeight - viewportHeight + bodyHeight
end

function Page.GetHoverMetrics(context)
    local metrics = Page.GetSurfaceMetrics(context)
    local shell = Theme.Geometry.shellBorder * 2
    return {
        minWidth = metrics.minContentWidth + shell,
        preferredWidth = metrics.naturalContentWidth + shell,
        minHeight = metrics.minContentHeight + Theme.Geometry.titleBar + shell,
        preferredHeight = metrics.naturalContentHeight + Theme.Geometry.titleBar + shell,
        horizontalOverflow = "content",
        verticalOverflow = "content",
    }
end
