local Addon = _G.YiboTaskHub
local View = {}
Addon.Presentation = View
View.fields = {
    { id = "character", title = Addon:T("TEXT.ACTING_CHARACTER.456AFC"), weight = 15, defaultVisible = true, preview = false },
    { id = "work", title = Addon:T("TEXT.TASK.DD9FC2"), weight = 33, defaultVisible = true },
    { id = "beneficiary", title = Addon:T("TEXT.FOR_WHOM.A11FA5"), weight = 9, defaultVisible = true },
    { id = "source", title = Addon:T("TEXT.SOURCE.C63F79"), weight = 11, defaultVisible = true },
    { id = "status", title = Addon:T("TEXT.STATUS.62E951"), weight = 22, defaultVisible = true },
    { id = "action", title = Addon:T("TEXT.ACTIONS.F3EA6D"), weight = 10, defaultVisible = true, preview = false },
}

function View:Columns(context)
    local fields, total = {}, 0
    local previewWeights = { work = 36, beneficiary = 10, source = 12, status = 26 }
    for _, field in ipairs(self.fields) do
        local visible
        if context.preview then visible = field.preview ~= false and Addon.db.settings.previewColumns[field.id]
        else visible = not context.GetFieldVisible or context:GetFieldVisible(field.id) end
        if visible then
            local projected = field
            if context.preview then projected = Addon.Core.Defaults:Copy(field); projected.weight = previewWeights[field.id] or field.weight end
            fields[#fields + 1] = projected; total = total + projected.weight
        end
    end
    if #fields == 0 then fields, total = { self.fields[2] }, self.fields[2].weight end
    return fields, total
end

function View:Title(task)
    return task.title .. (type(task.quantity) == "number" and (" ×" .. task.quantity) or "")
end

function View:Icon(task)
    if task.icon then return task.icon end
    local id = type(task.item) == "table" and tonumber(task.item.itemID)
    if id then
        local resolver = Addon.Core.ItemResolver
        local info = resolver:GetInfo(id)
        if info and info.icon then return info.icon end
        -- Todo can already show an item texture while full item details are
        -- uncached. Keep the same icon in Task instead of a generic quest mark.
        local icon = GetItemIcon and GetItemIcon(id)
        if icon then return icon end
        self.itemRequests = self.itemRequests or {}
        if info and info.state ~= "ready" and self.itemRequests[id] == nil then
            self.itemRequests[id] = true
            resolver:Request(id, function(result)
                View.itemRequests[id] = false
                if result and result.icon then
                    Addon.Core.AccountView:NotifyPageChanged(Addon.PAGE_ID)
                    Addon.Displays:ScheduleRefresh()
                end
            end)
        end
    end
    return task.temporal.kind == "daily" and "Interface\\GossipFrame\\AvailableQuestIcon" or "Interface\\Icons\\INV_Misc_Note_01"
end

function View:WorkText(task)
    return "|T" .. tostring(self:Icon(task)) .. ":20:20:0:0|t " .. self:Title(task)
end
function View:BindWork(band, cell, task)
    if not cell or not task then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local icon = band.workIcon
    if not icon then
        icon = CreateFrame("Frame", nil, band, "BackdropTemplate"); band.workIcon = icon
        icon:SetSize(24, 24); icon:EnableMouse(false)
        icon:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        icon:SetBackdropColor(unpack(Addon.Core.UITheme.Colors.chrome))
        icon:SetBackdropBorderColor(unpack(Addon.Core.UITheme.Colors.matrixLine))
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetPoint("TOPLEFT", 2, -2); icon.texture:SetPoint("BOTTOMRIGHT", -2, 2)
    end
    icon:ClearAllPoints(); icon:SetPoint("LEFT", band, "LEFT", band.workOffset, 0)
    icon.texture:SetTexture(self:Icon(task)); icon.texture:SetDesaturated(task.state == "completed")
    icon:Show()
    local width = cell:GetWidth()
    cell:ClearAllPoints(); cell:SetPoint("LEFT", band.workOffset + 28, 0)
    cell:SetWidth(math.max(1, width - 28)); cell:SetText(self:Title(task))
end

function View:Status(row)
    local text, color = Addon.AccountPage:Status(row.task, row.candidate)
    local marker = row.task.readiness == "unknown" and "?" or (row.candidate and "@"
        or ((row.task.readiness == "actionable" or row.task.readiness == "preparation") and ">" or "~"))
    return marker .. " " .. text, color
end

local function Tint(text, color)
    return string.format("|cff%02x%02x%02x%s|r", math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5), text)
end

function View:CountText(counts, includeTotal, styled)
    local parts = {}
    local colors = Addon.Core.UITheme.Colors
    for _, pair in ipairs({ { "actionable", Addon:T("TEXT.ACTIONABLE.F5D1DA"), colors.accent }, { "preparation", Addon:T("TEXT.READY.CC3CE6"), colors.accent },
        { "candidates", Addon:T("TEXT.CANDIDATE.0461E4"), colors.text }, { "blocked", Addon:T("TEXT.WAITING.25D23B"), colors.warning }, { "unknown", Addon:T("TEXT.UNVERIFIED.8708E4"), colors.muted }, { "completed", Addon:T("TEXT.COMPLETE.E99B48"), colors.muted } }) do
        if (counts[pair[1]] or 0) > 0 then
            local text = pair[2] .. " " .. counts[pair[1]]
            parts[#parts + 1] = styled and Tint(text, pair[3]) or text
        end
    end
    if includeTotal then parts[#parts + 1] = styled and Tint(includeTotal .. Addon:T("TEXT.TASKS.08777B"), colors.muted) or includeTotal .. Addon:T("TEXT.TASKS.08777B") end
    return #parts > 0 and table.concat(parts, " · ") or Addon:T("TEXT.NO_ACTIONABLE_TASKS.0A2BB7")
end

function View:GroupDetails(rows, context)
    local lines = { self:CountText(self:Counts(rows)) }
    local seen, metadata = {}, {}
    for index = 1, math.min(8, #rows) do
        local row = rows[index]
        local status, color = Addon.AccountPage:Status(row.task, row.candidate)
        lines[#lines + 1] = { kind = "pair", label = self:Title(row.task),
            value = status,
            labelColor = Addon.Core.UITheme.Colors.text,
            valueColor = color }
        local detail = Addon:T("TEXT.SOURCE.64B3B5") .. row.task.sourceTitle .. Addon:T("TEXT.FOR.265A6C") .. self:Beneficiary(row, context)
        if not seen[detail] then metadata[#metadata + 1], seen[detail] = { text = detail, color = Addon.Core.UITheme.Colors.muted }, true end
    end
    for _, line in ipairs(metadata) do lines[#lines + 1] = line end
    if #rows > 8 then lines[#lines + 1] = Addon:T("TEXT.PLUS.202859") .. (#rows - 8) .. Addon:T("TEXT.ITEMS_EXPAND_IN_THE_MAIN_WINDOW.031C6D") end
    return lines
end

function View:Beneficiary(row, context, full)
    local beneficiary = row.task.beneficiary
    if beneficiary.mode == "account" then return Addon:T("TEXT.ACCOUNT.901384") end
    if beneficiary.mode ~= "character" then return Addon:T("TEXT.UNVERIFIED.8708E4") end
    if beneficiary.characterID == row.character.id then return Addon:T("TEXT.SELF.4B8C92") end
    return Addon.AccountPage:CharacterLabel(Addon.Core.Characters:Get(beneficiary.characterID, { identityOnly = true }), context, full)
end

function View:Details(row, context)
    local task, lines = row.task, {}
    lines[#lines + 1] = Addon:T("TEXT.ACTING.C12CD8") .. Addon.AccountPage:CharacterLabel(row.character, context, true)
    lines[#lines + 1] = Addon:T("TEXT.FOR.B65F34") .. self:Beneficiary(row, context, true)
    lines[#lines + 1] = Addon:T("TEXT.SOURCE.64B3B5") .. task.sourceTitle
    lines[#lines + 1] = Addon.AccountPage:Status(task, row.candidate)
    if task.summary then lines[#lines + 1] = task.summary end
    if task.freshness.observedAt and date then lines[#lines + 1] = Addon:T("TEXT.OBSERVED.99143B") .. date("%Y-%m-%d %H:%M", task.freshness.observedAt) end
    return lines
end

function View:Cell(row, field, context)
    if field.id == "character" then return Addon.AccountPage:CharacterLabel(row.character, context) end
    if field.id == "work" then return self:WorkText(row.task), row.task.readiness == "unknown" and Addon.Core.UITheme.Colors.muted or nil end
    if field.id == "beneficiary" then return self:Beneficiary(row, context), Addon.Core.UITheme.Colors.muted end
    if field.id == "source" then return row.task.sourceTitle, Addon.Core.UITheme.Colors.muted end
    if field.id == "status" then return self:Status(row) end
    return ""
end

-- These are compact role rows, not role-column matrices. Reuse Core's
-- identity control in its single-line mode with an explicitly formatted name.
function View:IdentityCell(band, index, character, context, label)
    if not character then return end
    local theme = Addon.Core.UITheme
    band.identities = band.identities or {}
    local header = band.identities[index]
    if not header then header = theme:CreateMatrixHeader(band); band.identities[index] = header end
    local cell = band.cells[index]
    header:ClearAllPoints(); header:SetPoint("TOPLEFT", cell, "TOPLEFT"); header:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT")
    theme:SetCharacterHeader(header, character, { scope = "realm" }, {
        name = Addon.AccountPage:CharacterLabel(character, context), justify = "LEFT",
        inset = 0, fill = { 0, 0, 0, 0 }, rule = { 0, 0, 0, 0 },
    })
    if label then header.label:SetText(label) end
    theme:ApplyTextStyle(header.label, theme.Font.body)
    cell:Hide()
end

function View:Muted(text) return Tint(text, Addon.Core.UITheme.Colors.muted) end

function View:ResetIdentities(band)
    if band.workIcon then band.workIcon:Hide() end
    for _, header in pairs(band.identities or {}) do header:Hide() end
end

function View:Priority(row)
    if row.task.readiness == "unknown" then return 4 end
    if row.task.readiness == "blocked" then return 3 end
    return row.candidate and 2 or 1
end

function View:RowColor(row, index)
    local theme = Addon.Core.UITheme
    if not row.candidate and row.task.readiness == "actionable" then return theme.Colors.successSurface end
    return theme:GetDataRowColor(index)
end

function View:Counts(rows)
    local result = { actionable = 0, preparation = 0, candidates = 0, unknown = 0, blocked = 0, completed = 0, rows = {} }
    local seen = {}
    for _, row in ipairs(rows or {}) do
        local task = row.task
        if not seen[task.identity] then
            seen[task.identity] = true
            if task.state == "completed" then result.completed = result.completed + 1
            elseif task.readiness == "unknown" then result.unknown = result.unknown + 1
            elseif task.readiness == "actionable" or task.readiness == "preparation" then
                result.rows[#result.rows + 1] = row
                if row.candidate then result.candidates = result.candidates + 1
                else result[task.readiness] = result[task.readiness] + 1 end
            else result.blocked = result.blocked + 1 end
        end
    end
    return result
end

function View:Current()
    -- Core admission is shared; account-page scope/source selection is a view
    -- preference and must not suppress the logged-in character's reminders.
    local characters = Addon.Core.AccountView:GetVisibleCharacters()
    local filter = Addon.CoreIntegration.page and Addon.CoreIntegration.page.characterFilter
    if filter and Addon.Core.LevelFilter then
        local matcher = Addon.Core.LevelFilter:Compile(filter.GetExpression() or "")
        local eligible = {}
        for _, character in ipairs(characters) do if matcher:Matches(character.level) then eligible[#eligible + 1] = character end end
        characters = eligible
    end
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    local admitted = {}
    for _, character in ipairs(characters) do
        if current and character.id == current.id then admitted[1] = character; break end
    end
    local value = Addon.Snapshot:Build(admitted)
    value.currentAllowed = false
    for _, character in ipairs(characters) do if current and character.id == current.id then value.currentAllowed = true end end
    return value, self:Counts(value.current)
end

function View:Band(parent, count)
    local theme = Addon.Core.UITheme
    local band = CreateFrame("Frame", nil, parent)
    band.fill = band:CreateTexture(nil, "BACKGROUND"); band.fill:SetAllPoints()
    band.fill:SetColorTexture(unpack(theme.Colors.row))
    band.rule = band:CreateTexture(nil, "ARTWORK")
    band.rule:SetHeight(1); band.rule:SetPoint("BOTTOMLEFT"); band.rule:SetPoint("BOTTOMRIGHT")
    band.rule:SetColorTexture(unpack(theme.Colors.matrixLine))
    band.cells = {}
    for index = 1, count do band.cells[index] = theme:CreateText(band, theme.Font.body, theme.Colors.text) end
    return band
end
