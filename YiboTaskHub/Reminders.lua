local Addon = _G.YiboTaskHub
local Reminder = {}
Addon.Reminders = Reminder

function Reminder:Start(characterID)
    self.characterID, self.sent, self.pendingList, self.known, self.new = characterID, false, false, {}, {}
end

function Reminder:Update(value, counts)
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    local id = current and current.id
    if id ~= self.characterID then self:Start(id) end
    if value.uniqueCount == 0 then self.pendingList = false; return 0 end
    if not value.currentAllowed then self.pendingList = false; return 0 end
    local present = {}
    for _, row in ipairs(counts.rows) do present[row.task.identity] = true end
    for identity in pairs(self.new) do if not present[identity] then self.new[identity] = nil end end
    for identity in pairs(present) do
        if self.sent and not self.known[identity] then self.new[identity] = true end
        self.known[identity] = true
    end
    if not self.sent and value.providerCount > #value.errors then
        self.sent = true
        local mode = Addon.db.settings.reminderMode
        if mode == "summary" then
            local message = string.format(Addon:T("TEXT.CURRENT_CHARACTER_D_ACTIONABLE_D_REA.48EA7A"), counts.actionable, counts.preparation, counts.candidates)
            if counts.unknown > 0 then message = message .. Addon:T("TEXT..4518B1") .. counts.unknown .. Addon:T("TEXT.ITEMS.12DE8E") end
            Addon:Print(message .. Addon:T("TEXT..F92669"))
        elseif mode == "list" and #counts.rows > 0 then self.pendingList = true end
    end
    if self.pendingList and not (InCombatLockdown and InCombatLockdown()) then
        self.pendingList = false
        Addon.AccountPage:OpenCurrent()
    end
    local newCount = 0
    for _ in pairs(self.new) do newCount = newCount + 1 end
    return newCount
end

function Reminder:Acknowledge(rows)
    local changed
    for _, pair in ipairs(rows) do
        if pair.section == "current" and self.new and self.new[pair.row.task.identity] then
            self.new[pair.row.task.identity] = nil; changed = true
        end
    end
    if changed then Addon.Displays:ScheduleRefresh() end
end
