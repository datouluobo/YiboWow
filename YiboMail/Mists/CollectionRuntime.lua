local Addon = _G.YiboMail
local Runtime = Addon.CollectionRuntime

function Runtime:CanDeleteEmpty(mail)
    if #mail.attachments ~= 0 or mail.money ~= 0 or mail.cod ~= 0 or mail.isGM or mail.auctionMail
        or type(GetInboxText) ~= "function" or type(DeleteInboxItem) ~= "function"
        or type(InboxItemCanDelete) ~= "function" then return false end
    local ok, permitted = pcall(InboxItemCanDelete, mail.inboxIndex)
    if not ok or (permitted ~= true and permitted ~= 1) then return false end
    local read, body, _, _, _, invoice = pcall(GetInboxText, mail.inboxIndex)
    if not read or type(body) ~= "string" or (invoice ~= nil and invoice ~= false and invoice ~= 0) then
        return false
    end
    if body == "" then return true end
    if type(GetLocale) ~= "function" or GetLocale() ~= "zhCN" or mail.wasReturned
        or not mail.replyExplicitlyDisabled or type(CanComplainInboxItem) ~= "function" then return false end
    local complaintOK, canComplain = pcall(CanComplainInboxItem, mail.inboxIndex)
    return complaintOK and canComplain == false
end
