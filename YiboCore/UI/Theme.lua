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
    -- Dense data grids use a single low-contrast teal rule.  It remains
    -- visible on dark surfaces without reading as a white spreadsheet grid.
    matrixLine = { 0.10, 0.36, 0.37, 0.72 },
    text = { 0.90, 0.96, 0.97 },
    muted = { 0.53, 0.70, 0.73 },
    accent = { 0.125, 0.88, 0.44 },
    current = { 0.055, 0.23, 0.23, 0.92 },
    success = { 0.16, 0.68, 0.24, 0.98 },
    -- Completion is an informational state in dense matrices.  Keep its
    -- semantic green border/text without turning the whole cell into a bright
    -- action button.
    successSurface = { 0.035, 0.15, 0.075, 0.96 },
    timer = { 0.12, 0.28, 0.48, 0.96 },
    danger = { 0.70, 0.20, 0.20, 0.96 },
    dangerSurface = { 0.17, 0.075, 0.09, 0.98 },
    blocked = { 0.17, 0.075, 0.09, 0.98 },
}

Theme.Space = { xxs = 4, xs = 8, sm = 12, md = 16, lg = 20, xl = 24 }
-- WoW's UI scale makes the former 11–12px data text too small on modern
-- displays. Keep the compact hierarchy, but make every shared surface legible.
Theme.Size = { compact = 26, standard = 30, action = 34, double = 46, title = 48 }
-- Account data is deliberately denser than settings controls.  Every hosted
-- page uses these semantic roles instead of inheriting a client template's
-- implicit GameFont size.
Theme.Font = { title = 18, section = 16, body = 14, assist = 12, meta = 11 }
-- Matrices are the account view's primary surface.  Keep their geometry
-- compact and shared so business pages do not trade comparable rows for
-- local title chrome or arbitrary whitespace.
Theme.Table = { headerHeight = 24, rowHeight = 24, previewRowHeight = 22, groupHeight = 28, cellInset = 3, cellPadding = 6 }

-- Geometry is deliberately kept beside the visual tokens: it is the one
-- source of truth for every shared surface.  Business pages report content
-- only and must never guess the width of the account shell.
Theme.Geometry = {
    -- Matrix insets are directional on purpose.  Their current values happen
    -- to match, but pages must consume this table instead of assuming that a
    -- single arbitrary offset is valid on all four edges.
    matrixInsets = {
        main = { top = 8, right = 8, bottom = 8, left = 8 },
        preview = { top = 6, right = 6, bottom = 6, left = 6 },
    },
    mainInset = 8,
    previewInset = 6,
    titleBar = 46,
    navigation = 140,
    shellBorder = 1,
    scopeBar = 30,
    -- A data viewport always keeps its normal inset.  This extra gutter is
    -- added to the outer measured width only when a vertical scrollbar is
    -- actually needed, so the bar never overlays its final data column.
    scrollbarGutter = 16,
    mainSafety = { left = 16, right = 16, top = 80, bottom = 32 },
    previewSafety = { left = 16, right = 16, top = 16, bottom = 16, anchorGap = 8 },
}

function Theme:GetMatrixInsets(preview)
    return self.Geometry.matrixInsets[preview and "preview" or "main"]
end

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

function Theme:ApplyTextStyle(text, size)
    text:SetFont(STANDARD_TEXT_FONT, size or self.Font.body)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    return text
end

function Theme:MeasureText(size, value)
    if not self._measureText then
        self._measureText = UIParent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        self._measureText:Hide()
    end
    self._measureText:SetFont(STANDARD_TEXT_FONT, size or self.Font.body)
    self._measureText:SetText(tostring(value or ""))
    return math.ceil(self._measureText:GetStringWidth() or 0)
end

-- A current character is a navigation aid, not a data state.  Account pages
-- therefore mark it with this shared accent outline instead of changing the
-- row/column's semantic fill or adding a text glyph beside the name.
function Theme:CreateCurrentCharacterOutline(parent)
    local outline = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    outline:SetAllPoints(parent)
    outline:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    outline:SetBackdropBorderColor(self.Colors.accent[1], self.Colors.accent[2], self.Colors.accent[3], 0.96)
    outline:SetFrameLevel((parent:GetFrameLevel() or 0) + 10)
    outline:EnableMouse(false)
    outline:Hide()
    return outline
end

function Theme:SetCurrentCharacterOutline(outline, shown)
    if outline then outline:SetShown(shown == true) end
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

function Theme:CreateDropdown(parent, width, options)
    local dropdown = self:CreateButton(parent, width or 220, "", "secondary")
    dropdown.arrow = self:CreateText(dropdown, self.Font.assist, self.Colors.muted, "RIGHT")
    -- ASCII is guaranteed by every supported WoW font; several CJK client
    -- fonts render the otherwise preferred triangle as an empty square.
    dropdown.arrow:SetPoint("RIGHT", -8, 0); dropdown.arrow:SetText("v")
    dropdown.label:SetPoint("LEFT", 10, 0); dropdown.label:SetPoint("RIGHT", dropdown.arrow, "LEFT", -6, 0)
    dropdown.options = {}
    dropdown.value = nil
    dropdown.menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    dropdown.menu:SetFrameStrata("DIALOG")
    dropdown.menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    dropdown.menu:SetBackdropColor(Color(self.Colors.panel)); dropdown.menu:SetBackdropBorderColor(Color(self.Colors.line))
    dropdown.menu:Hide()
    dropdown.menu.buttons = {}
    function dropdown:SetOptions(nextOptions)
        self.options = nextOptions or {}
        for _, button in ipairs(self.menu.buttons) do button:Hide() end
        for index, option in ipairs(self.options) do
            local button = self.menu.buttons[index]
            if not button then
                button = Theme:CreateButton(self.menu, 1, "", "secondary")
                self.menu.buttons[index] = button
            end
            button:ClearAllPoints(); button:SetPoint("TOPLEFT", 4, -4 - (index - 1) * (Theme.Size.standard + 2)); button:SetPoint("RIGHT", -4, 0)
            button:SetText(option.label or tostring(option.value or "")); button:SetState(option.value == self.value and "selected" or "default")
            button:SetScript("OnClick", function()
                self:SetValue(option.value)
                self.menu:Hide()
                if type(self.onValueChanged) == "function" then self.onValueChanged(option.value, option) end
            end)
            button:Show()
        end
        self.menu:SetHeight(math.max(1, #self.options) * (Theme.Size.standard + 2) + 6)
    end
    function dropdown:SetValue(value)
        self.value = value
        local label = ""
        for _, option in ipairs(self.options) do
            if option.value == value then label = option.label or tostring(value); break end
        end
        self:SetText(label)
        for _, button in ipairs(self.menu.buttons) do
            local option = self.options[_]
            if option then button:SetState(option.value == value and "selected" or "default") end
        end
    end
    function dropdown:SetOnValueChanged(callback) self.onValueChanged = callback end
    dropdown:SetScript("OnClick", function(self)
        if self.menu:IsShown() then self.menu:Hide(); return end
        self.menu:ClearAllPoints(); self.menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2); self.menu:SetWidth(self:GetWidth())
        self.menu:Show(); self.menu:SetFrameLevel((self:GetFrameLevel() or 0) + 20)
    end)
    dropdown:SetOptions(options)
    return dropdown
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
        local viewportHeight = self:GetHeight() or 0
        -- Anchored frames can refresh once before WoW has resolved their
        -- final height.  A zero-height viewport must not be interpreted as
        -- a fully overflowing list, or it leaves a phantom scrollbar behind.
        local range = viewportHeight > 1 and (self:GetVerticalScrollRange() or 0) or 0
        if self.contentHeight and viewportHeight > 1 then range = math.max(0, self.contentHeight - viewportHeight) end
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
