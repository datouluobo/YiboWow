local Boot = dofile("_NonRelease/MailForever/Harness.lua")
for _, target in ipairs({ "Forever", "Mists" }) do
    for _, language in ipairs({ "zh", "en" }) do
        local e, core, mail = Boot(nil, nil, target == "Forever")
        core.Locale.language = language
        mail.db.settings.confirmGoldSend = false
        local parent = e.CreateFrame("Frame", nil, e.UIParent)
        local helpers = {
            createSection = function(owner) return e.CreateFrame("Frame", nil, owner) end,
            createCheckbox = function(owner, text) return core.UITheme:CreateCheckbox(owner, text) end,
        }
        local render = mail.AccountSettings:GetDefinition().CreateSettingsPanel
        local children
        for _, width in ipairs({ 1000, 400, 280, 1000 }) do
            parent:SetWidth(width); render(parent, helpers)
            local business = parent.mailBusinessSettings
            if children then assert(#business.children == children, "resize reuses existing settings controls") end
            children = #business.children
            if target == "Forever" then
                assert(not business.goldConfirmation or not business.goldConfirmation:IsShown(),
                    "Forever must not offer a toggle that cannot disable native confirmation")
                assert(business.goldConfirmationNote:GetText() == mail:T("SETTINGS.NATIVE_GOLD_CONFIRMATION"))
                assert(business.goldConfirmationNote:GetText():find(language == "zh" and "原生" or "native", 1, true),
                    "the target explanation has a real translation")
            else
                assert(business.goldConfirmation:IsShown() and not business.goldConfirmation:GetChecked())
                business.goldConfirmation:GetScript("OnClick")(business.goldConfirmation)
                assert(mail.db.settings.confirmGoldSend)
                business.goldConfirmation:GetScript("OnClick")(business.goldConfirmation)
            end
            assert(mail.db.settings.confirmGoldSend == false, "rendering preserves saved preferences")
            local note = business.goldConfirmationNote
            local position = note.points[1]
            local noteBottom = -position[#position] + note:GetHeight()
            assert(note:GetHeight() >= note:GetStringHeight(), "localized note is not clipped")
            if width < 600 then
                local point = business.gridTitle.points[1]
                assert(-point[#point] >= noteBottom + 8, "next setting group must follow the complete note")
            end
            assert(business:GetHeight() >= noteBottom)
        end
    end
end
print("PASS: Forever native-confirmation settings, MoP toggle, both languages and narrow/wide layout")
