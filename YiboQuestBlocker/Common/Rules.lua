local YQB = _G.YQB

function YQB.GetBlockScope(questID)
    local db = YQB.GetDatabase()
    if db.globalBlocked[questID] then return "global" end
    local current = db.characterData[YQB.GetCurrentCharacterID()]
    if current and current.blocked and current.blocked[questID] then return "char" end
end

function YQB.IsQuestBlocked(questID)
    return YQB.GetBlockScope(questID) ~= nil
end

function YQB.GetBlockStatus(questID)
    local db = YQB.GetDatabase()
    local status = { global = db.globalBlocked[questID] or false }
    for id, character in pairs(db.characterData) do
        status[id] = character.blocked and character.blocked[questID] or false
    end
    return status
end

function YQB.IsQuestBlockedByAny(questID)
    local db = YQB.GetDatabase()
    if db.globalBlocked[questID] then return true end
    for _, character in pairs(db.characterData) do
        if character.blocked and character.blocked[questID] then return true end
    end
    return false
end

local function SetRule(questID, characterID, blocked, title)
    local db = YQB.GetDatabase()
    local rules = db.globalBlocked
    if characterID then
        local character = db.characterData[characterID]
        if not character then
            if not blocked then return end
            character = { blocked = {}, cache = {} }
            db.characterData[characterID] = character
        end
        character.blocked = character.blocked or {}
        rules = character.blocked
    end
    rules[questID] = blocked
    if blocked then
        YQB.RememberQuestName(questID, title or YQB.ReadQuestTitle(questID))
    end
    if YQB.OnRuleChanged then YQB.OnRuleChanged(questID, characterID) end
    YQB.NotifyCorePageChanged()
end

local function AddRule(questID, characterID, title)
    if YQB.ConfirmProtectedRule and YQB.ConfirmProtectedRule(questID, title, function()
        SetRule(questID, characterID, true, title)
    end) then return end
    SetRule(questID, characterID, true, title)
end

function YQB.AddBlock(questID, scope, title)
    if not questID then return end
    AddRule(questID, scope ~= "global" and YQB.GetCurrentCharacterID() or nil, title)
end

function YQB.RemoveBlock(questID, scope)
    SetRule(questID, scope ~= "global" and YQB.GetCurrentCharacterID() or nil)
end

function YQB.AddCharBlock(questID, characterID, title)
    if not (questID and characterID) then return end
    AddRule(questID, characterID, title)
end

function YQB.RemoveCharBlock(questID, characterID)
    SetRule(questID, characterID)
end

function YQB.GetStats()
    local db = YQB.GetDatabase()
    local global, current, total = 0, 0, 0
    for _ in pairs(db.globalBlocked) do global = global + 1 end
    total = global
    for id, character in pairs(db.characterData) do
        for _ in pairs(character.blocked or {}) do
            total = total + 1
            if id == YQB.GetCurrentCharacterID() then current = current + 1 end
        end
    end
    return global, current, total
end
