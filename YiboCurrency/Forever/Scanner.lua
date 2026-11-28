local Addon = _G.YiboCurrency
local Scanner = { generation = 0 }; Addon.Scanner = Scanner
local function Read(callback, ...)
    if type(callback) ~= "function" then return nil end
    local ok, value = pcall(callback, ...)
    if not ok or not Addon.Store:Count(value) then return nil end
    return value
end
function Scanner:Cancel() self.generation = self.generation + 1; self.queued, self.confirmZero, self.confirmItems = false, nil, nil end
function Scanner:Scan(confirmZero, confirmItems)
    if not Addon.initialized or not self.inWorld then return false end
    if type(IsLoggedIn) == "function" then
        local ok, loggedIn = pcall(IsLoggedIn)
        if not ok or loggedIn ~= true then return false end
    end
    local id = Addon.Core.Characters:GetCurrentID()
    if not id then return false end
    local copper, stamp = Read(GetMoney), Read(GetServerTime)
    if confirmItems == nil then confirmItems = confirmZero end
    local itemIDs = Addon.Store:Items()
    if next(itemIDs) then
        local counts = {}
        local getCount = C_Item and C_Item.GetItemCount or GetItemCount
        if stamp ~= nil then
            for itemID in pairs(itemIDs) do
                local count = Read(getCount, itemID, false, false, false, false)
                local lastCount, fresh = Addon.Store:GetItemCount(id, itemID)
                if count ~= nil and (count > 0 or confirmItems or (fresh and lastCount == 0))
                    and Read(getCount, itemID, false, false, false, false) == count then counts[itemID] = count end
            end
        end
        if stamp ~= nil and self.inWorld and id == Addon.Core.Characters:GetCurrentID() then
            Addon.Store:CommitItems(id, counts, stamp)
        else
            Addon.Store.freshItemsID = nil
        end
    end
    if stamp ~= nil and self.inWorld and id == Addon.Core.Characters:GetCurrentID()
        and Addon.NativeAPI and Addon.NativeDiscovery and Addon.Store.nativeStore then
        local adapter = Addon.NativeAPI:ForClient(_G)
        local existingDir = Addon.Store:GetNativeDirectory()
        local directory, observations = Addon.NativeDiscovery:Collect(adapter, existingDir, stamp, Addon.NativeCatalog)
        if Addon.Store.nativeStore:Commit(id, directory, observations) then
            Addon.Store.freshObservationsID = id
            Addon.Store.freshObservations = observations
        else
            Addon.Store.freshObservationsID = nil
            Addon.Store.freshObservations = nil
        end
    end
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
function Scanner:Request(confirmZero, confirmItems)
    self.confirmZero = self.confirmZero or confirmZero
    self.confirmItems = self.confirmItems or confirmItems
    if self.queued or not self.inWorld then return end
    self.queued = true
    local generation = self.generation
    local function Run()
        if generation ~= self.generation then return end
        self.queued = false
        local confirmed, items = self.confirmZero, self.confirmItems
        self.confirmZero, self.confirmItems = nil, nil
        self:Scan(confirmed, items == true)
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0.2, Run) else Run() end
end
function Scanner:OnEvent(event, unit)
    if event == "PLAYER_ENTERING_WORLD" then self:Cancel(); self.inWorld = true; self:Request(false)
    elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
        if event == "PLAYER_LOGOUT" and self.inWorld then self:Scan(false) end
        if event == "PLAYER_LOGOUT" then Addon.Store:ResetSession() end
        self:Cancel(); self.inWorld, self.confirmZero = false, nil
        Addon.Store.freshID, Addon.Store.freshItemsID = nil, nil
        Addon.Store.freshObservationsID, Addon.Store.freshObservations = nil, nil
        Addon:NotifyChanged()
    elseif event == "PLAYER_MONEY" then self:Request(true)
    elseif event == "BAG_UPDATE_DELAYED" then self:Request(false, true)
    elseif event == "CURRENCY_DISPLAY_UPDATE" then self:Request(true)
    elseif event == "UNIT_INVENTORY_CHANGED" and unit == "player" then self:Request(false) end
end
