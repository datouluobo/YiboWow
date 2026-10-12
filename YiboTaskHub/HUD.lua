local Addon = _G.YiboTaskHub
local HUD = {}
Addon.HUD = HUD

function HUD:RestorePosition()
    local frame, position = self.frame, Addon.db.settings.hudPosition
    frame:ClearAllPoints()
    local points = { CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
        TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
    local function Finite(value) return type(value) == "number" and value == value and math.abs(value) < math.huge end
    if type(position) == "table" and points[position.point] and points[position.relativePoint]
        and Finite(position.x) and Finite(position.y) then
        frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -220) end
end

function HUD:SavePosition()
    self.frame:StopMovingOrSizing()
    local x, y = self.frame:GetCenter()
    if x and y then
        Addon.db.settings.hudPosition = { point = "CENTER", relativePoint = "CENTER",
            x = x - UIParent:GetWidth() / 2, y = y - UIParent:GetHeight() / 2 }
    end
end

function HUD:Create()
    if self.frame then return self.frame end
    local theme = Addon.Core.UITheme
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate"); self.frame = frame
    frame:SetFrameStrata("MEDIUM"); frame:SetClampedToScreen(true); frame:SetMovable(true)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    frame:SetBackdropColor(unpack(theme.Colors.panel)); frame:SetBackdropBorderColor(unpack(theme.Colors.matrixLine))
    frame.header = Addon.Presentation:Band(frame, 1); frame.header:EnableMouse(true); frame.header:RegisterForDrag("LeftButton")
    frame.header.cells[1]:SetPoint("LEFT", 6, 0)
    frame.header:SetScript("OnDragStart", function() if not Addon.db.settings.hudLocked then frame:StartMoving() end end)
    frame.header:SetScript("OnDragStop", function() HUD:SavePosition() end)
    frame.open = theme:CreateButton(frame.header, 42, Addon:T("TEXT.LIST.D46F82"), "secondary")
    frame.open:SetPoint("RIGHT", -3, 0); frame.open:SetHeight(theme.Table.rowHeight - 4)
    frame.open:SetScript("OnClick", function() Addon.AccountPage:OpenCurrent() end)
    frame.summary = theme:CreateText(frame, theme.Font.assist, theme.Colors.text)
    frame.summary:SetPoint("TOPLEFT", 6, -(theme.Table.rowHeight + 4))
    frame.footer = theme:CreateText(frame, theme.Font.assist, theme.Colors.muted)
    frame.footer:SetPoint("BOTTOMLEFT", 6, 4); frame.footer:SetPoint("BOTTOMRIGHT", -6, 4)
    frame.rows = {}; self:RestorePosition()
    return frame
end

function HUD:Refresh(value, counts, newCount)
    local frame, theme = self:Create(), Addon.Core.UITheme
    if not Addon.db.settings.hudEnabled or not value.currentAllowed then frame:Hide(); return end
    local h = theme.Table.rowHeight
    local width = math.max(180, math.min(380, UIParent:GetWidth() - 40))
    local capacity = math.max(0, math.min(Addon.db.settings.hudRows, math.floor((UIParent:GetHeight() - 80) / h) - 3))
    local visible = math.min(capacity, #counts.rows)
    frame:SetSize(width, (visible + 3) * h + 8)
    frame.header:ClearAllPoints(); frame.header:SetPoint("TOPLEFT", 1, -1); frame.header:SetSize(width - 2, h)
    frame.header.cells[1]:SetSize(width - 62, h); frame.header.cells[1]:SetText(Addon:T("TEXT.ACTION_HUB_CURRENT_CHARACTER.7BC66E"))
    frame.summary:SetSize(width - 12, h)
    frame.summary:SetText(Addon.Presentation:CountText({ actionable = counts.actionable, preparation = counts.preparation, candidates = counts.candidates }, nil, true))
    for _, row in ipairs(frame.rows) do row:Hide() end
    local context = { scope = "all" }
    for index = 1, visible do
        local band = frame.rows[index]
        if not band then
            band = Addon.Presentation:Band(frame, 2); frame.rows[index] = band; band:EnableMouse(true)
            band:SetScript("OnEnter", function(control)
                theme:ShowTooltip(control, Addon.Presentation:Title(control.row.task), Addon.Presentation:Details(control.row, context), "ANCHOR_LEFT")
            end)
            band:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        end
        band.row = counts.rows[index]
        band:ClearAllPoints(); band:SetPoint("TOPLEFT", 1, -(2 * h + 4 + (index - 1) * h)); band:SetSize(width - 2, h)
        band.cells[1]:ClearAllPoints(); band.cells[1]:SetPoint("LEFT", 6, 0); band.cells[1]:SetSize(width - 134, h)
        band.cells[2]:ClearAllPoints(); band.cells[2]:SetPoint("RIGHT", -6, 0); band.cells[2]:SetSize(110, h)
        band.cells[1]:SetText(Addon.Presentation:WorkText(band.row.task))
        local text, color = Addon.Presentation:Status(band.row)
        band.cells[2]:SetText(text); band.cells[2]:SetTextColor(unpack(color)); band:Show()
    end
    local remaining, footer = #counts.rows - visible, ""
    if value.providerCount == 0 then footer = Addon.db.goals and Addon:T("TEXT.NO_GOALS_YET_ADD_ONE_IN_GOAL_MANAGEM.AE1EF7") or Addon:T("TEXT.WAITING_FOR_TASK_SOURCES.C437D4")
    elseif #counts.rows == 0 then footer = Addon:T("TEXT.NO_CONFIRMED_ACTIONABLE_TASKS.FC0AAD") end
    if remaining > 0 then footer = Addon:T("TEXT.PLUS.202859") .. remaining .. Addon:T("TEXT.ITEMS_OPEN_THE_LIST.D85225") end
    if counts.unknown > 0 then footer = footer .. (footer ~= "" and " · " or "") .. counts.unknown .. Addon:T("TEXT.ITEMS_UNVERIFIED.214E8B") end
    if #value.errors > 0 then footer = footer .. (footer ~= "" and " · " or "") .. #value.errors .. Addon:T("TEXT.UNAVAILABLE_SOURCES.7032E2") end
    if newCount > 0 then footer = Addon:T("TEXT.NEW.D46996") .. newCount .. Addon:T("TEXT.ITEMS.12DE8E") .. (footer ~= "" and " · " .. footer or "") end
    frame.footer:SetHeight(h); frame.footer:SetText(footer); frame:Show()
end
