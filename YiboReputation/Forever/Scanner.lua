local Addon = _G.YiboReputation
local Scanner = { generation = 0 }; Addon.Scanner = Scanner
local function Read(callback, ...)
    if type(callback) ~= "function" then return false end
    local ok, value = pcall(callback, ...)
    if not ok or not Addon.Store:Plain(value) then return false end
    return true, value
end
local function Parse(info, stamp)
    if type(info) ~= "table" then return nil end
    for _, key in ipairs({ "factionID", "name", "reaction", "currentReactionThreshold", "nextReactionThreshold",
        "currentStanding", "isHeader", "isHeaderWithRep", "isAccountWide" }) do
        if not Addon.Store:Plain(info[key]) then return nil end
    end
    if type(info.isHeader) ~= "boolean" or type(info.isHeaderWithRep) ~= "boolean" then return nil end
    if info.isHeader and not info.isHeaderWithRep then return false end
    local row = { factionID = info.factionID, name = info.name, reaction = info.reaction,
        minimum = info.currentReactionThreshold, maximum = info.nextReactionThreshold, value = info.currentStanding,
        isAccountWide = info.isAccountWide, observedAt = stamp }
    return Addon.Store:ValidRow(row.factionID, row) and row or nil
end
function Scanner:Collect(known, stamp)
    local api = C_Reputation
    if type(api) ~= "table" or type(api.GetNumFactions) ~= "function" or type(api.GetFactionDataByIndex) ~= "function" then return nil, "unavailable" end
    local ok, count = Read(api.GetNumFactions)
    if not ok or not Addon.Store:Integer(count, 0, 2000) then return nil, "error" end
    local factions = {}
    for index = 1, count do
        local success, info = Read(api.GetFactionDataByIndex, index)
        if not success then return nil, "error" end
        local row = Parse(info, stamp)
        if row == nil then return nil, "error" end
        if row then
            if factions[row.factionID] then return nil, "error" end
            factions[row.factionID] = row
        end
    end
    if type(api.GetFactionDataByID) == "function" then
        for id in pairs(known) do
            if not factions[id] then
                local success, info = Read(api.GetFactionDataByID, id)
                if not success then return nil, "error" end
                if info ~= nil then
                    local row = Parse(info, stamp)
                    if row == nil or (row and row.factionID ~= id) then return nil, "error" end
                    if row then factions[id] = row end
                end
            end
        end
    end
    return factions, count
end
local function Equal(left, right)
    for id, row in pairs(left) do
        local other = right[id]; if not other then return false end
        for key, value in pairs(row) do if other[key] ~= value then return false end end
        for key, value in pairs(other) do if row[key] ~= value then return false end end
    end
    for id in pairs(right) do if not left[id] then return false end end
    return true
end
function Scanner:Scan()
    if not Addon.initialized or not self.inWorld then return false end
    if type(IsLoggedIn) == "function" then local ok, value = pcall(IsLoggedIn); if not ok or value ~= true then return false end end
    local id = Addon.Core.Characters:GetCurrentID(); if not id then return false end
    local ok, stamp = Read(GetServerTime)
    if not ok or not Addon.Store:Integer(stamp, 0, 9007199254740991) then return self:Fail("error") end
    local previous = Addon.Store.db.characters[id]
    local known = previous and previous.factions or {}
    local first, count = self:Collect(known, stamp)
    if not first then return self:Fail(count) end
    local second, afterCount = self:Collect(known, stamp)
    if not second then return self:Fail(afterCount) end
    if count ~= afterCount or not Equal(first, second) or id ~= Addon.Core.Characters:GetCurrentID() or not self.inWorld then return self:Fail("error") end
    -- An empty visible list never proves that this character has no reputation.
    if not next(second) then return self:Fail("pending") end
    return Addon.Store:Commit(id, second, stamp)
end
function Scanner:Fail(state)
    Addon.Store.freshID, Addon.Store.freshFactions, Addon.Store.error = nil, nil, state
    Addon:NotifyChanged(); return false
end
function Scanner:Cancel() self.generation = self.generation + 1; self.queued = false end
function Scanner:Request()
    if self.queued or not self.inWorld then return end
    self.queued = true; local generation = self.generation
    local function Run()
        if generation ~= self.generation then return end
        self.queued = false; self:Scan()
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0.2, Run) else Run() end
end
function Scanner:OnEvent(event)
    if event == "PLAYER_ENTERING_WORLD" then self:Cancel(); self.inWorld = true; self:Request()
    elseif event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
        if event == "PLAYER_LOGOUT" and self.inWorld then self:Scan() end
        self:Cancel(); self.inWorld = false; Addon.Store.freshID = nil; Addon:NotifyChanged()
    else self:Request() end
end
