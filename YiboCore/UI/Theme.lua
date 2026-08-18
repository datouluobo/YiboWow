local Core = _G.YiboCore

-- Shared visual system for every page hosted by YiboCore.  Business addons may
-- choose layout and data, but must consume these tokens and controls.
local Theme = {}
Core.UITheme = Theme

Theme.Colors = {
    bg = { 0.018, 0.045, 0.060, 0.98 },
    chrome = { 0.035, 0.105, 0.125, 1 },
    nav = { 0.028, 0.078, 0.094, 1 },
    panel = { 0.035, 0.105, 0.125, 0.96 },
    toolbar = { 0.045, 0.14, 0.16, 0.90 },
    row = { 0.035, 0.115, 0.13, 0.88 },
    alternate = { 0.045, 0.135, 0.15, 0.88 },
    selected = { 0.055, 0.23, 0.23, 1 },
    line = { 0.12, 0.42, 0.43, 0.85 },
    lineSoft = { 0.12, 0.42, 0.43, 0.46 },
    text = { 0.90, 0.96, 0.97 },
    muted = { 0.53, 0.70, 0.73 },
    accent = { 0.125, 0.88, 0.44 },
    current = { 0.055, 0.23, 0.23, 0.92 },
    success = { 0.16, 0.68, 0.24, 0.98 },
    timer = { 0.12, 0.28, 0.48, 0.96 },
    danger = { 0.70, 0.20, 0.20, 0.96 },
    dangerSurface = { 0.17, 0.075, 0.09, 0.98 },
    blocked = { 0.17, 0.075, 0.09, 0.98 },
}

Theme.Space = { xxs = 4, xs = 8, sm = 12, md = 16, lg = 20, xl = 24 }
Theme.Size = { compact = 24, standard = 28, action = 32, double = 44, title = 46 }
Theme.Font = { title = 16, section = 14, body = 12, assist = 11 }

local function Color(color)
    return color[1], color[2], color[3], color[4] or 1
end

function Theme:CreateText(parent, size, color, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetFont(STANDARD_TEXT_FONT, size or self.Font.body)
    text:SetJustifyH(justify or "LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    if color then text:SetTextColor(Color(color)) end
    return text
end

function Theme:CreateButton(parent, width, label, kind)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 84, self.Size.standard)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    button.kind = kind or "default"
    button.label = self:CreateText(button, self.Font.body, self.Colors.text, "CENTER")
    button.label:SetAllPoints()
    button.SetText = function(control, text) control.label:SetText(text or "") end
    button.SetState = function(control, state)
        control.state = state or "default"
        local border, fill = Theme.Colors.line, Theme.Colors.chrome
        if control.kind == "secondary" then border, fill = Theme.Colors.lineSoft, Theme.Colors.panel end
        if control.kind == "disclosure" then border, fill = Theme.Colors.lineSoft, Theme.Colors.bg end
        if control.kind == "danger" then border, fill = Theme.Colors.danger, Theme.Colors.dangerSurface end
        if control.state == "selected" then border, fill = Theme.Colors.accent, Theme.Colors.selected end
        if control.state == "disabled" then border, fill = Theme.Colors.lineSoft, Theme.Colors.bg end
        control:SetBackdropColor(Color(fill)); control:SetBackdropBorderColor(Color(border))
        control.label:SetTextColor(Color(control.state == "disabled" and Theme.Colors.muted or Theme.Colors.text))
    end
    button:SetText(label)
    button:SetState("default")
    button:SetScript("OnEnter", function(control)
        -- Hover may clarify the hit target, but must not overwrite semantic
        -- text colours (class, success, warning, and per-cell status colours).
        if control.state ~= "disabled" then control:SetBackdropBorderColor(Color(Theme.Colors.accent)) end
    end)
    button:SetScript("OnLeave", function(control)
        local border = Theme.Colors.line
        if control.kind == "secondary" or control.kind == "disclosure" then border = Theme.Colors.lineSoft end
        if control.kind == "danger" then border = Theme.Colors.danger end
        if control.state == "selected" then border = Theme.Colors.accent end
        if control.state == "disabled" then border = Theme.Colors.lineSoft end
        control:SetBackdropBorderColor(Color(border))
    end)
    return button
end

function Theme:CreateCheckbox(parent, label)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(190, self.Size.standard)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    -- The outer button only owns hit-testing and its label.  Rendering this
    -- texture without an explicit alpha defaults to an opaque white strip.
    button:SetBackdropColor(0, 0, 0, 0)
    button.box = CreateFrame("Frame", nil, button, "BackdropTemplate")
    button.box:SetSize(16, 16); button.box:SetPoint("LEFT", 0, 0)
    button.box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    button.mark = button.box:CreateTexture(nil, "OVERLAY")
    button.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    button.mark:SetPoint("CENTER")
    button.mark:SetSize(16, 16)
    button.mark:SetVertexColor(Color(self.Colors.bg))
    button.label = self:CreateText(button, self.Font.body, self.Colors.text, "LEFT"); button.label:SetPoint("LEFT", button.box, "RIGHT", 8, 0); button.label:SetPoint("RIGHT", 0, 0); button.label:SetText(label or "")
    button.checked = false
    button.RefreshVisual = function(control)
        if type(control.visualizer) == "function" then
            control.visualizer(control)
            return
        end
        local color = control.checked and Theme.Colors.accent or Theme.Colors.line
        control.box:SetBackdropColor(Color(control.checked and Theme.Colors.accent or Theme.Colors.chrome))
        control.box:SetBackdropBorderColor(Color(color))
    end
    button.SetChecked = function(control, checked)
        control.checked = checked == true
        control.mark:SetShown(control.checked)
        control:RefreshVisual()
    end
    button.GetChecked = function(control) return control.checked end
    button:SetChecked(false)
    button:SetScript("OnClick", function(control) control:SetChecked(not control:GetChecked()) end)
    button:SetScript("OnEnter", function(control)
        if not control.disableHoverAccent then control.box:SetBackdropBorderColor(Color(Theme.Colors.accent)) end
    end)
    button:SetScript("OnLeave", function(control) control:SetChecked(control:GetChecked()) end)
    return button
end

-- Scroll frames intentionally avoid UIPanelScrollFrameTemplate so every hosted
-- page keeps the same compact teal track and thumb instead of the Blizzard art.
function Theme:CreateScrollFrame(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetClipsChildren(true)
    scroll:EnableMouseWheel(true)

    local bar = CreateFrame("Slider", nil, scroll, "BackdropTemplate")
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(14)
    bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -2, -2)
    bar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", -2, 2)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
    bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    bar:SetBackdropColor(Color(self.Colors.bg))
    bar:SetBackdropBorderColor(Color(self.Colors.lineSoft))
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(10, 24)
    thumb:SetColorTexture(Color(self.Colors.accent))
    bar:SetThumbTexture(thumb)
    bar:SetScript("OnEnter", function(control) control:GetThumbTexture():SetColorTexture(Color(Theme.Colors.text)) end)
    bar:SetScript("OnLeave", function(control) control:GetThumbTexture():SetColorTexture(Color(Theme.Colors.accent)) end)

    local syncing = false
    function scroll:UpdateScrollbar()
        local range = self:GetVerticalScrollRange() or 0
        if self.contentHeight then
            range = math.max(0, self.contentHeight - (self:GetHeight() or 0))
        end
        self.scrollRange = range
        bar:SetMinMaxValues(0, range)
        bar:SetValue(math.min(self:GetVerticalScroll() or 0, range))
        bar:SetShown(range > 0)
        return range
    end
    function scroll:RefreshScrollbar()
        if self.scrollbarRefreshPending then return end
        self.scrollbarRefreshPending = true
        local function Refresh()
            scroll.scrollbarRefreshPending = nil
            scroll:UpdateScrollbar()
        end
        if C_Timer and C_Timer.After then C_Timer.After(0, Refresh) else Refresh() end
    end
    function scroll:SetContentHeight(height)
        self.contentHeight = math.max(0, tonumber(height) or 0)
        self:RefreshScrollbar()
    end
    scroll:SetScript("OnVerticalScroll", function(control, offset)
        if not syncing then
            syncing = true; bar:SetValue(offset); syncing = false
        end
    end)
    bar:SetScript("OnValueChanged", function(_, value)
        if not syncing then
            syncing = true; scroll:SetVerticalScroll(value); syncing = false
        end
    end)
    scroll:SetScript("OnMouseWheel", function(control, delta)
        local step = Theme.Size.standard * 2
        local range = control.scrollRange or control:GetVerticalScrollRange()
        control:SetVerticalScroll(math.max(0, math.min(range, control:GetVerticalScroll() - delta * step)))
    end)
    scroll:SetScript("OnSizeChanged", function(control) control:RefreshScrollbar() end)
    local nativeSetScrollChild = scroll.SetScrollChild
    scroll.SetScrollChild = function(control, child)
        nativeSetScrollChild(control, child)
        child:HookScript("OnSizeChanged", function() control:RefreshScrollbar() end)
        control:RefreshScrollbar()
    end
    scroll.ScrollBar = bar
    return scroll
end

function Theme:BindTooltip(control, title, lines)
    control.tooltipTitle, control.tooltipLines = title, lines
    control:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetFrameStrata("TOOLTIP")
        GameTooltip:SetFrameLevel((self:GetFrameLevel() or 0) + 20)
        -- Blizzard's tooltip background is intentionally translucent, but that
        -- makes dense account matrices show through the labels.  Add a scoped
        -- near-opaque underlay for Yibo tooltips only; it stays behind the
        -- native border and all tooltip text.
        if not GameTooltip.YiboOpaqueBackground then
            local background = GameTooltip:CreateTexture(nil, "BACKGROUND", nil, -7)
            background:SetPoint("TOPLEFT", GameTooltip, "TOPLEFT", 2, -2)
            background:SetPoint("BOTTOMRIGHT", GameTooltip, "BOTTOMRIGHT", -2, 2)
            GameTooltip.YiboOpaqueBackground = background
        end
        GameTooltip.YiboOpaqueBackground:SetColorTexture(Theme.Colors.bg[1], Theme.Colors.bg[2], Theme.Colors.bg[3], 0.98)
        GameTooltip.YiboOpaqueBackground:Show()
        GameTooltip:ClearLines()
        local red, green, blue = Color(Theme.Colors.text)
        if self.tooltipTitle then GameTooltip:AddLine(self.tooltipTitle, red, green, blue) end
        for _, line in ipairs(self.tooltipLines or {}) do
            if type(line) ~= "table" then
                GameTooltip:AddLine(line, red, green, blue, true)
            elseif line.kind == "spacer" then
                GameTooltip:AddLine(" ")
            elseif line.kind == "pair" then
                local labelColor = line.labelColor or Theme.Colors.muted
                local valueColor = line.valueColor or Theme.Colors.text
                local lr, lg, lb = Color(labelColor)
                local vr, vg, vb = Color(valueColor)
                GameTooltip:AddDoubleLine(tostring(line.label or ""), tostring(line.value or ""), lr, lg, lb, vr, vg, vb)
            elseif line.kind == "section" then
                local sr, sg, sb = Color(line.color or Theme.Colors.accent)
                GameTooltip:AddLine(tostring(line.text or ""), sr, sg, sb)
            else
                local tr, tg, tb = Color(line.color or Theme.Colors.text)
                GameTooltip:AddLine(tostring(line.text or ""), tr, tg, tb, line.wrap ~= false)
            end
        end
        GameTooltip:Show()
    end)
    control:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if GameTooltip.YiboOpaqueBackground then GameTooltip.YiboOpaqueBackground:Hide() end
    end)
end
