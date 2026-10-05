local Core, Theme = _G.YiboCore, _G.YiboCore.UITheme
Core.Capabilities:Register("basic-input", 1)
local function IsComposing(input)
    local check = input.IsInIMECompositionMode or input.IsInIMEComposition
    return check and check(input) or false
end

-- Shared search affordance used by Core and business-plugin inputs. The
-- button lives inside the edit box and reserves text space for its hit target.
function Theme:AttachClearButton(input, options)
    if not input then return nil end
    options = options or {}
    if input.clearButton then return input.clearButton end
    local button = CreateFrame("Button", nil, input, "BackdropTemplate")
    local width = options.width or 24
    button:SetSize(width, options.height or math.max(18, (input:GetHeight() or self.Size.standard) - 6))
    button:SetPoint("RIGHT", input, "RIGHT", -4, 0)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    button:SetBackdropColor(unpack(self.Colors.bg))
    button:SetBackdropBorderColor(unpack(self.Colors.accent))
    button.label = self:CreateText(button, self.Font.assist, self.Colors.text, "CENTER")
    button.label:SetPoint("CENTER", 0, 0)
    button.label:SetText("X")
    input:SetTextInsets(options.leftInset or self.Space.xs, width + 10, 0, 0)
    local function Update()
        button:SetShown((input:GetText() or "") ~= "")
    end
    input:HookScript("OnTextChanged", Update)
    button:SetScript("OnEnter", function(control)
        control:SetBackdropBorderColor(unpack(Theme.Colors.accent))
    end)
    button:SetScript("OnLeave", function(control)
        control:SetBackdropBorderColor(unpack(Theme.Colors.accent))
    end)
    button:SetScript("OnClick", function()
        if input.SetValue then input:SetValue("", true) else input:SetText("") end
        if options.OnClear then options.OnClear(input) end
        input:SetFocus()
    end)
    input.clearButton = button
    Update()
    return button
end

function Theme:CreateInput(parent, options)
    options = options or {}
    local input = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    input:SetSize(options.width or 240, self.Size[options.size or "standard"] or self.Size.standard)
    if options.height then input:SetHeight(options.height) end
    input:SetAutoFocus(false)
    input:SetFont(STANDARD_TEXT_FONT, self.Font.body, "")
    input:SetTextColor(unpack(self.Colors.text))
    input:SetTextInsets(self.Space.xs, self.Space.xs, 0, 0)
    input:SetMaxLetters(options.maxLetters or 255)
    input:SetNumeric(options.numeric == true)
    input:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    input:SetBackdropColor(unpack(self.Colors.bg))
    input:SetBackdropBorderColor(unpack(self.Colors.lineSoft))
    input.placeholder = self:CreateText(input, self.Font.assist, self.Colors.muted, "LEFT")
    input.placeholder:SetPoint("LEFT", self.Space.xs, 0)
    input.placeholder:SetPoint("RIGHT", -self.Space.xs, 0)
    input.placeholder:SetWordWrap(false)
    input.placeholder:SetText(options.placeholder or "")
    local function Changed(control, userInput)
        control.imePending = nil
        control.placeholder:SetShown(control:GetText() == "")
        if options.OnChanged then options.OnChanged(control:GetText(), userInput == true, control) end
    end
    input:SetScript("OnTextChanged", function(control, userInput)
        control.placeholder:SetShown(control:GetText() == "")
        if control.silent or not options.OnChanged then return end
        local pending = control.imePending
        local composing = IsComposing(control)
        if not (userInput or control.notifyProgrammatic or pending or composing) then return end
        userInput = userInput == true or (pending and pending.userInput) or (composing and not control.notifyProgrammatic) or false
        if composing then control.imePending = { userInput = userInput }; return end
        Changed(control, userInput)
    end)
    -- Some clients deliver the final text event before clearing the IME flag.
    -- Flush that pending change on the first frame after composition ends.
    input:SetScript("OnUpdate", function(control)
        local pending = control.imePending
        if pending and not IsComposing(control) then Changed(control, pending.userInput) end
    end)
    function input:SetValue(value, notify)
        value = tostring(value or "")
        -- SetText even with identical text can reset the caret or IME buffer.
        if self:GetText() == value then
            self.placeholder:SetShown(value == "")
            if notify then
                if IsComposing(self) then self.imePending = self.imePending or { userInput = false }
                else Changed(self, false) end
            elseif not IsComposing(self) then self.imePending = nil end
            return
        end
        self.imePending = nil
        self.silent, self.notifyProgrammatic = not notify, notify
        self:SetText(value)
        self.silent, self.notifyProgrammatic = nil, nil
    end
    function input:SetInputEnabled(enabled)
        self:SetEnabled(enabled); self:SetAlpha(enabled and 1 or 0.5)
        if not enabled then self:ClearFocus() end
    end
    input:SetScript("OnEditFocusGained", function(control)
        control.originalValue = control:GetText()
        control:SetBackdropBorderColor(unpack(Theme.Colors.accent))
        if options.OnFocus then options.OnFocus(true, control) end
    end)
    input:SetScript("OnEditFocusLost", function(control)
        control:SetBackdropBorderColor(unpack(Theme.Colors.lineSoft))
        if options.OnFocus then options.OnFocus(false, control) end
    end)
    input:SetScript("OnEnterPressed", function(control)
        if IsComposing(control) then return end
        if options.Validate then
            local valid, message = options.Validate(control:GetText())
            if not valid then if options.OnInvalid then options.OnInvalid(message, control) end; return end
        end
        if options.OnSubmit then options.OnSubmit(control:GetText(), control) end
        control:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(control)
        if IsComposing(control) then return end
        if options.restoreOnEscape then control:SetValue(control.originalValue, true) end
        control:ClearFocus()
    end)
    input:SetScript("OnHide", function(control) control.imePending = nil; control:ClearFocus() end)
    input:SetValue(options.value)
    if options.clearable then self:AttachClearButton(input, options.clearButtonOptions) end
    return input
end
