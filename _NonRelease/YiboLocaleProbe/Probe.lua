-- Deliberately excluded from all release TOCs and packaging.
local Core = _G.YiboCore
if not Core or not Core:CheckAPIVersion(13) or not Core:HasCapability("localization", 1) then
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("YiboLocaleProbe requires YiboCore API 13 / localization:1.") end
    return
end
local instances, iconPickers = {}, {}
local function Print(message) Core:Print("LocaleProbe: " .. tostring(message)) end
local function Preview(language)
    if InCombatLockdown and InCombatLockdown() then Print("Leave combat first."); return end
    if language ~= "zh" and language ~= "en" and language ~= "reset" then return end
    local locale, view = Core.Locale, Core.AccountView
    local oldLanguage = locale:GetLanguage()
    if view.frame then
        view.frame:Hide()
        instances[oldLanguage] = view.frame.instances
        for _, instance in pairs(view.frame.instances) do instance:Hide() end
    end
    if Core.iconPicker then Core.iconPicker:Hide(); iconPickers[oldLanguage] = Core.iconPicker end
    if GameTooltip then GameTooltip:Hide() end
    -- This override lives only in the non-release addon and is never saved.
    locale.previewLanguage = language ~= "reset" and language or nil
    locale:RefreshBindings()
    if view.frame then
        local frame = view.frame
        frame.instances = instances[locale:GetLanguage()] or {}
        frame.nav:SetWidth(Core.UITheme:GetNavigationWidth())
        frame.settingsButton:SetText(Core:Text("CORE.SETTINGS"))
        frame.settingsButton:SetWidth(Core.UITheme:MeasureText(Core.UITheme.Font.body, Core:Text("CORE.SETTINGS")) + 18)
        view:UpdateSortButton()
    end
    Core.iconPicker = iconPickers[locale:GetLanguage()]
    if Core.Entry then Core.Entry:Refresh() end
    view:ShowPage("overview", nil, true)
    Print("Preview=" .. locale:GetLanguage() .. "; saved preference=" .. locale:GetPreference())
end
SLASH_YIBOLOCALEPROBE1 = "/ylp"
SlashCmdList.YIBOLOCALEPROBE = function(message)
    local command = tostring(message or ""):match("^%s*(%S+)") or ""
    if command == "zh" or command == "en" or command == "reset" then Preview(command)
    elseif command == "missing" then
        local missing = Core.Locale:GetMissingEnglish()
        for _, entry in ipairs(missing) do Print(entry.owner .. ":" .. entry.key) end
        Print("Missing English keys: " .. #missing)
    else Print("/ylp zh | en | reset | missing") end
end
