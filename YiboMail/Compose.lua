local Addon = _G.YiboMail
local Compose = { draft = { recipient = "", subject = "", body = "", copper = 0, cod = false } }; Addon.Compose = Compose
function Compose:DraftFingerprint()
    local values = { self.draft.recipient, self.draft.subject, self.draft.body, self.draft.copper, self.draft.cod }
    for _, item in ipairs(self:GetAttachments()) do values[#values + 1] = Addon.Encode({ item.slot, item.itemLink or item.itemID, item.quantity }) end
    return Addon.Encode(values)
end
function Compose:SubjectForAttachments(items)
    if type(items) ~= "table" then items = {} end
    if #items == 0 then
        return self:HasSendMoney() and Addon:T("UI.TEXT_0617") or nil
    end
    local firstName = type(items[1].name) == "string" and items[1].name:match("%S") and items[1].name or Addon:T("UI.TEXT_0457")
    local distinct, kinds = {}, 0
    for _, item in ipairs(items) do
        local key = item.itemID or item.name
        if key ~= nil and not distinct[key] then distinct[key], kinds = true, kinds + 1 end
    end
    return firstName .. (kinds > 1 and (Addon:T("UI.TEXT_0474") .. kinds .. Addon:T("UI.TEXT_0044")) or "")
end
function Compose:OnEvent(event)
    if event == "MAIL_SEND_INFO_UPDATE" and Addon.Scanner:IsOpen() and SendMailFrame and SendMailFrame:IsShown() then
        self:EnsureSubject()
    end
    if event == "MAIL_SEND_SUCCESS" and self.pendingSend then
        self.pendingSend.state = "in-transit"
        self.pendingSend.attemptedAt, self.pendingSend.observedAt = self.pendingSend.observedAt, Addon:Now()
        if Addon.Recipients and Addon.Recipients.ObserveSuccessfulMail then
            -- Gold proves an ordinary mail under this client's faction rules;
            -- attachment-only mail may contain cross-faction account-bound items.
            Addon.Recipients:ObserveSuccessfulMail(self.pendingSend.recipient, self.pendingSend.senderFaction, (self.pendingSend.copper or 0) > 0)
        end
        if Addon.Recipients then Addon.Recipients:RecordRecent(self.pendingSend.recipient) end
        Addon:AddHistory(self.pendingSend.characterID, self.pendingSend)
        self.pendingSend = nil; self:ClearDraft()
    elseif (event == "MAIL_FAILED" or event == "MAIL_CLOSED") and self.pendingSend then
        Addon:AddHistory(self.pendingSend.characterID, self.pendingSend); self.pendingSend = nil
    end
    if event == "MAIL_CLOSED" then self:ClearDraft() end
    if Addon.FEATURES.account and (event == "MAIL_SEND_INFO_UPDATE" or event == "MAIL_SEND_SUCCESS" or event == "MAIL_FAILED" or event == "BAG_UPDATE_DELAYED") then
        Addon.Core.AccountView:NotifyPageChanged("mail-inbox")
    end
end
