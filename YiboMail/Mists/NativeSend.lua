local Addon = _G.YiboMail
local Native = Addon.NativeUI
function Native:InstallMoneySendConfirmation()
    local button = _G.SendMailMailButton or _G.SendMailSendButton
    if self.moneyConfirmationInstalled or not button then return end
    local original = button:GetScript("OnClick")
    if type(original) ~= "function" then return end
    self.moneyConfirmationInstalled, self.nativeSendButton = true, button
    button:SetScript("OnClick", function(control, ...)
        if Native.moneyConfirmPending then return end
        if Addon.Compose and Addon.Compose:HasSendMoney() then
            local args = { ... }
            Native:ConfirmMoneySend(control, original, args)
            return
        end
        return original(control, ...)
    end)
end
