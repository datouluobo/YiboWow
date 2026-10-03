local Core, Theme = _G.YiboCore, _G.YiboCore.UITheme
Core.Capabilities:Register("basic-input", 1)

function Theme:CreateInput(parent, options)
    options = options or {}
    local input = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    input:SetSize(options.width or 240, self.Size[options.size or "standard"] or self.Size.standard)
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
    input:SetScript("OnTextChanged", function(control, userInput)
        control.placeholder:SetShown(control:GetText() == "")
        if not control.silent and (userInput or control.notifyProgrammatic) and options.OnChanged then
            options.OnChanged(control:GetText(), userInput == true, control)
        end
    end)
    function input:SetValue(value, notify)
        self.silent, self.notifyProgrammatic = not notify, notify
        self:SetText(tostring(value or ""))
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
        if options.Validate then
            local valid, message = options.Validate(control:GetText())
            if not valid then if options.OnInvalid then options.OnInvalid(message, control) end; return end
        end
        if options.OnSubmit then options.OnSubmit(control:GetText(), control) end
        control:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(control)
        if options.restoreOnEscape then control:SetValue(control.originalValue, true) end
        control:ClearFocus()
    end)
    input:SetScript("OnHide", function(control) control:ClearFocus() end)
    input:SetValue(options.value)
    return input
end
