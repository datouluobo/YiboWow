local Addon = _G.YiboMail
local Native = Addon.NativeUI
function Native:CaptureMoneySendDraft()
    local fields = Addon.Compose:ReadDraftFields()
    local draft = {recipient=fields.recipient, subject=fields.subject, body=fields.body,
        copper=fields.copper, cod=fields.cod, attachments={}}
    for _, item in ipairs(Addon.Compose:GetAttachments()) do
        draft.attachments[#draft.attachments+1]={item.slot,item.itemLink or item.itemID,item.quantity}
    end
    return draft
end
function Native:MoneySendDraftMatches(expected)
    if not expected or not Addon.Scanner:IsOpen() then return false end
    local current = self:CaptureMoneySendDraft()
    for _, key in ipairs({"recipient","subject","body","copper","cod"}) do
        if current[key]~=expected[key] then return false end
    end
    if #current.attachments~=#expected.attachments then return false end
    for index,item in ipairs(expected.attachments) do
        local actual=current.attachments[index]
        if not actual or actual[1]~=item[1] or actual[2]~=item[2] or actual[3]~=item[3] then return false end
    end
    return current.copper>0
end
function Native:CancelMoneySendConfirmation()
    local pending=self.moneyConfirmPending
    self.moneyConfirmPending=nil
    if pending and pending.handle then pending.handle:Cancel() end
end
function Native:ConfirmMoneySend(button, original, clickArgs)
    if Addon.db.settings.confirmGoldSend==false then original(button,unpack(clickArgs)); return end
    if self.moneyConfirmPending then return end
    local draft=self:CaptureMoneySendDraft()
    if draft.copper<=0 then original(button,unpack(clickArgs)); return end
    local pending={draft=draft}; self.moneyConfirmPending=pending
    pending.handle=Addon.Core.ItemConfirmation:Show({
        text=Addon:T("UI.TEXT_0670",draft.recipient,Addon.ViewModel:Money(draft.copper)),
        IsCurrent=function() return Native.moneyConfirmPending==pending end,
        OnAccept=function()
            if Native.moneyConfirmPending~=pending then return end
            Native.moneyConfirmPending=nil
            if not Native:MoneySendDraftMatches(draft) or not button:IsEnabled() then
                Addon:Print(Addon:T("UI.TEXT_0672")); return
            end
            original(button,unpack(clickArgs))
        end,
        OnCancel=function() if Native.moneyConfirmPending==pending then Native.moneyConfirmPending=nil end end})
    if not pending.handle then
        if self.moneyConfirmPending==pending then self.moneyConfirmPending=nil end
        Addon:Print(Addon:T("UI.TEXT_0671"))
    end
end
