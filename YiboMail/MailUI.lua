local Addon = _G.YiboMail
local UI = {}; Addon.MailUI = UI
local Theme, View = _G.YiboCore.UITheme, Addon.ViewModel
local function Text(parent, size, color) return Theme:CreateText(parent, size or Theme.Font.body, color or Theme.Colors.text, "LEFT") end
local function Enabled(button, enabled)
    button:SetEnabled(not not enabled); button:SetState(enabled and "default" or "disabled")
end
function UI:Input(parent, width, label, maxLetters)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 26); box:SetAutoFocus(false); box:SetMaxLetters(maxLetters or 200)
    box:SetScript("OnEscapePressed", function(control) control:ClearFocus() end)
    box.hint = Text(box, Theme.Font.assist, Theme.Colors.muted); box.hint:SetPoint("LEFT", 2, 0); box.hint:SetPoint("RIGHT", -4, 0); box.hint:SetText(label)
    box:HookScript("OnTextChanged", function(control) control.hint:SetShown(control:GetText() == "") end)
    Theme:BindTooltip(box, label, { label }); return box
end
