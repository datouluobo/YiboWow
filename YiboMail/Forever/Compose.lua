local Addon = _G.YiboMail
function Addon.Compose:NativeRecipient(address)
    return address:match("^[^-]+") or address
end
function Addon.Compose:InstallBagItemClicks(callback)
    if self.bagItemClicksInstalled or type(HandleModifiedItemClick) ~= "function" then return end
    -- Native bag mixins pass the real location here, including combined bags.
    hooksecurefunc("HandleModifiedItemClick", function(_, location)
        if location and type(location.IsBagAndSlot) == "function" and location:IsBagAndSlot() then
            callback(location:GetBagAndSlot())
        end
    end)
    self.bagItemClicksInstalled = true
end
function Addon.Compose:PrepareSendAction()
    local button = _G.SendMailMailButton
    if not button or type(button.Click) ~= "function" then return nil, Addon:T("UI.TEXT_0173") end
    if SendMailFrame_Update then SendMailFrame_Update() end
    if not button:IsEnabled() then return nil, Addon:T("UI.TEXT_0172") end
    -- Retain the client's button handler and native transfer confirmation.
    return function() button:Click("LeftButton") end
end
