local Addon = _G.YiboMail
local Compose = Addon.Compose
function Compose:NativeRecipient(address)
    return address
end
function Compose:InstallBagItemClicks(callback)
    if self.bagItemClicksInstalled or type(ContainerFrameItemButton_OnModifiedClick) ~= "function" then return end
    hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(button)
        if not button then return end
        local parent = button:GetParent()
        local bag = button.bagID or (parent and (parent:GetID() or parent.bagID))
        local slot = button:GetID()
        if bag ~= nil and slot then callback(bag, slot) end
    end)
    self.bagItemClicksInstalled = true
end
function Compose:PrepareSendAction()
    local button=_G.SendMailMailButton or _G.SendMailSendButton
    local click=button and button:GetScript("OnClick")
    if not click then return nil, Addon:T("UI.TEXT_0173") end
    if SendMailFrame_Update then SendMailFrame_Update() end
    if not button:IsEnabled() then return nil, Addon:T("UI.TEXT_0172") end
    return function() return click(button,"LeftButton") end
end
