local Addon = _G.YiboMail

Addon.INBOX_DEFAULTS = { mode = "mail", sort = "expiry", kind = "all", rememberFilters = false, selectItems = true, selectMoney = true, showSummary = true }
function Addon:GetInboxPreferences()
    local saved = self.db.settings.inbox or {}
    local result = self.Copy(self.INBOX_DEFAULTS)
    for key in pairs(result) do if saved[key] ~= nil then result[key] = saved[key] end end
    return result
end
function Addon:SelectByDefault(action)
    local prefs = self:GetInboxPreferences()
    return action.slot == "money" and prefs.selectMoney or (action.slot ~= "money" and prefs.selectItems)
end
function Addon:GetInboxActions(entry, onlyItem)
    local result, mail = {}, entry.mail
    local function Add(slot, item)
        result[#result + 1] = { id = self.ViewModel:ActionID(entry.character.id, entry.key, slot), actionable = entry.actionable,
            slot = slot, item = item, entry = entry }
    end
    if not onlyItem and mail.money > 0 then Add("money") end
    for _, item in ipairs(mail.attachments) do if not onlyItem or item == onlyItem then Add(item.attachmentIndex, item) end end
    return result
end
