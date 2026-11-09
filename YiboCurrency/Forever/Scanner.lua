local Addon = _G.YiboCurrency
local Scanner = { generation = 0 }; Addon.Scanner = Scanner
local function Read(callback)
    if type(callback) ~= "function" then return nil end
    local ok, value = pcall(callback)
    if not ok or not Addon.Store:Count(value) then return nil end
    return value
end
function Scanner:Cancel() self.generation = self.generation + 1; self.queued, self.confirmZero = false, nil end
function Scanner:Scan(confirmZero)
    if not Addon.initialized or not self.inWorld then return false end
    if type(IsLoggedIn) == "function" then
        local ok, loggedIn = pcall(IsLoggedIn)
        if not ok or loggedIn ~= true then return false end
    end
    local id = Addon.Core.Characters:GetCurrentID()
    if not id then return false end
    local copper, stamp = Read(GetMoney), Read(GetServerTime)
    if copper == nil or stamp == nil then
        Addon.Store.freshID, Addon.Store.error = nil, true; Addon:NotifyChanged(); return false
    end
    if copper == 0 and not confirmZero then
        Addon.Store.freshID, Addon.Store.error = nil, nil; Addon:NotifyChanged(); return false
    end
    if Read(GetMoney) ~= copper or id ~= Addon.Core.Characters:GetCurrentID() or not self.inWorld then
        Addon.Store.freshID, Addon.Store.error = nil, true; Addon:NotifyChanged(); return false
    end
    return Addon.Store:Commit(id, copper, stamp)
end
function Scanner:Request(confirmZero)
    self.confirmZero = self.confirmZero or confirmZero
    if self.queued or not self.inWorld then return end
    self.queued = true
    local generation = self.generation
    local function Run()
        if generation ~= self.generation then return end
        self.queued = false
        local confirmed = self.confirmZero; self.confirmZero = nil
        self:Scan(confirmed)
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0.2, Run) else Run() end
end
function Scanner:OnEvent(event, unit)
    if event == "PLAYER_ENTERING_WORLD" then self:Cancel(); self.inWorld = true; self:Request(false)
    elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
        if event == "PLAYER_LOGOUT" and self.inWorld then self:Scan(false) end
        self:Cancel(); self.inWorld, self.confirmZero = false, nil
        Addon.Store.freshID = nil; Addon:NotifyChanged()
    elseif event == "PLAYER_MONEY" then self:Request(true)
    elseif event == "BAG_UPDATE_DELAYED" or (event == "UNIT_INVENTORY_CHANGED" and unit == "player") then self:Request(false) end
end
