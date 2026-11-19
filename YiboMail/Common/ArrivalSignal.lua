local Addon = _G.YiboMail
local Scanner = Addon.Scanner
function Scanner:ObserveArrivalSignal()
    if type(HasNewMail) ~= "function" or not Addon.db then return end
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not current then return end
    local ok, value = pcall(HasNewMail)
    if not ok then return end
    local present = value == true or value == 1
    local previous = Addon.db.mailArrivalSignals[current.id]
    if previous and previous.present == present then return end
    Addon.db.mailArrivalSignals[current.id] = { present = present, awaitingScan = present, observedAt = Addon:Now() }
    Addon:UpdateMailNoticeBatch(current.id)
    if present or (previous and previous.awaitingScan) then Addon:Publish(current.id, {}, {}, "scan", true) end
end
