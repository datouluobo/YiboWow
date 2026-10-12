local Addon = _G.YiboTaskHub
local Displays = {}
Addon.Displays = Displays

function Displays:ScheduleRefresh(delay)
    if not self.initialized or self.queued then return end
    self.queued = true
    local generation = self.generation
    local function Refresh()
        if generation ~= Displays.generation or not Displays.initialized then return end
        Displays.queued = nil
        local value, counts = Addon.Presentation:Current()
        local newCount = Addon.Reminders:Update(value, counts)
        Addon.HUD:Refresh(value, counts, newCount)
    end
    if C_Timer and C_Timer.After then C_Timer.After(delay or 0, Refresh) else Refresh() end
end

function Displays:Initialize()
    if self.initialized then return end
    self.initialized = true
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    Addon.Reminders:Start(current and current.id)
    self.callback = function(_, change)
        if type(change) == "table" and change.pageID and change.pageID ~= Addon.PAGE_ID then return end
        Displays:ScheduleRefresh()
    end
    for _, event in ipairs({ "CHARACTER_DISPLAY_UPDATED", "ACCOUNT_VIEW_CHARACTERS_CHANGED" }) do
        Addon.Core.Events:Register(event, self, self.callback)
    end
    self:ScheduleRefresh(0.5)
end

function Displays:Shutdown()
    self.generation, self.queued, self.initialized = (self.generation or 0) + 1, nil, false
    if self.callback then
        for _, event in ipairs({ "CHARACTER_DISPLAY_UPDATED", "ACCOUNT_VIEW_CHARACTERS_CHANGED" }) do Addon.Core.Events:Unregister(event, self, self.callback) end
    end
    if Addon.HUD.frame then Addon.HUD.frame:Hide() end
end
