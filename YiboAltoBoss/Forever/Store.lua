if not _G.YAB.CoreReady then return end
local YAB = _G.YAB
local Targets = YAB.CustomTargets
local Store = {}
YAB.Store = Store

function Store:Initialize()
    if YiboAltoBossForeverDB ~= nil and (type(YiboAltoBossForeverDB) ~= "table" or YiboAltoBossForeverDB.schema ~= 1) then
        return false
    end
    YiboAltoBossForeverDB = YiboAltoBossForeverDB or {
        schema = 1, customTargets = {}, marks = {}, instances = {}, instanceSnapshots = {}, settings = {},
    }
    self.db = YiboAltoBossForeverDB
    return true
end

function Store:Mark(id, key)
    local marks = self.db.marks[id]
    return marks and marks[key]
end

function Store:ToggleMark(id, target)
    if self.db.customTargets[tostring(target.id)] ~= target then return end
    local marks = self.db.marks[id] or {}
    local now = GetServerTime()
    if Targets:IsActive(marks[target.key], now) then
        marks[target.key] = nil
    else
        marks[target.key] = { killed = true, source = "manual", updatedAt = now }
    end
    self.db.marks[id] = next(marks) and marks or nil
    return true
end

function Store:RemoveTarget(input)
    local target, message = Targets:Remove(self.db.customTargets, input)
    if not target then return false, message end
    for id, marks in pairs(self.db.marks) do
        marks[target.key] = nil
        if not next(marks) then self.db.marks[id] = nil end
    end
    return true, message
end
