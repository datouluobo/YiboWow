local Addon = _G.YiboMailStage0Probe
local frame = CreateFrame("Frame")
Addon.EventFrame = frame
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
for _, eventName in ipairs(Addon.EVENT_NAMES) do pcall(frame.RegisterEvent, frame, eventName) end

frame:SetScript("OnEvent", function(_, eventName, ...)
    if eventName == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName == Addon.NAME then Addon:InitializeDatabase() end
        if loadedName == "Blizzard_MailUI" then
            Addon:InstallMailOperationObservers()
            Addon:InstallMailFrameObserver()
        end
        return
    end
    if eventName == "PLAYER_LOGIN" then
        if not Addon.Session then Addon:InitializeDatabase() end
        Addon:InstallMailOperationObservers()
        Addon:InstallMailFrameObserver()
        Addon:Print("只读邮箱探针已加载。输入 /ymp help 查看命令。")
        return
    end
    if eventName == "MAIL_SHOW" then
        Addon.Runtime.mailOpen = true
        Addon.MailInboxUpdatedThisOpen = false
    end
    if eventName == "MAIL_CLOSED" then
        Addon.Runtime.mailOpen = false
        Addon.MailInboxUpdatedThisOpen = false
        Addon.MailProbeToken = (Addon.MailProbeToken or 0) + 1
    end
    if eventName == "MAIL_INBOX_UPDATE" and Addon:IsFrameShown("MailFrame") then
        Addon.MailInboxUpdatedThisOpen = true
    end
    Addon:AddEvent(eventName, ...)
    if eventName == "MAIL_SHOW" then
        Addon:InstallMailOperationObservers()
        Addon:InstallMailFrameObserver()
        Addon:ScheduleMailProbe("mail-show")
    elseif eventName == "MAIL_INBOX_UPDATE" then
        Addon:ScheduleMailProbe("inbox-update")
    elseif eventName == "MAIL_CLOSED" and Addon.MailWatch then
        Addon:ProbeMail("mail-closed-residue")
    end
end)
