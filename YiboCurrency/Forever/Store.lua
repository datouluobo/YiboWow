local Addon = _G.YiboCurrency
local Store = {}; Addon.Store = Store
function Store:Count(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return false end
    return type(value) == "number" and value >= 0 and value <= 9007199254740991 and value % 1 == 0
end
function Store:Initialize()
    local db = _G.YiboCurrencyForeverDB
    if db ~= nil then
        if type(db) ~= "table" or db.schema ~= 1 or type(db.clientScope) ~= "table"
            or db.clientScope.target ~= "Forever" or db.clientScope.projectID ~= WOW_PROJECT_ID
            or db.clientScope.scope ~= "current-character" or type(db.characters) ~= "table"
            or type(db.settings) ~= "table" or type(db.settings.previewColumns) ~= "table" then return false end
        for id, row in pairs(db.characters) do
            if type(id) ~= "string" or type(row) ~= "table" or not self:Count(row.moneyCopper)
                or not self:Count(row.observedAt) then return false end
        end
    else
        db = { schema = 1, clientScope = { target = "Forever", projectID = WOW_PROJECT_ID,
            scope = "current-character", rulesetState = "unknown" }, characters = {},
            settings = { previewColumns = { money = true } } }
    end
    self.db = db; _G.YiboCurrencyForeverDB = db
    return true
end
function Store:Get(id)
    if not Addon.Core or id ~= Addon.Core.Characters:GetCurrentID() then return nil, "unsupported-scope" end
    local row = self.db and self.db.characters[id]
    local state = self.error and "error" or (row and (self.freshID == id and Addon.Scanner.inWorld and "known" or "stale") or "unknown")
    return row and Addon.Core.Defaults:Copy(row) or nil, state
end
function Store:Commit(id, copper, observedAt)
    if id ~= Addon.Core.Characters:GetCurrentID() or not self:Count(copper) or not self:Count(observedAt) then return false end
    self.db.characters[id] = { moneyCopper = copper, observedAt = observedAt }
    self.freshID, self.error = id, nil; Addon:NotifyChanged(); return true
end
function Store:Delete(character, context)
    local row = self.db.characters[character.id]
    local now = GetServerTime and GetServerTime()
    if context and context.replay and row and self:Count(context.deletedAt) and self:Count(now)
        and row.observedAt > context.deletedAt and row.observedAt <= now then return true end
    self.db.characters[character.id] = nil
    Addon.Scanner:Cancel(); self.freshID, self.error = nil, nil
    Addon:NotifyChanged(); return true
end
