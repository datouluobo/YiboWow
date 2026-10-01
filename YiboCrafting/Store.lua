local Addon = _G.YiboCrafting
local Store = {}
Addon.Store = Store

local function Now()
    return (GetServerTime and GetServerTime()) or time()
end

function Store:Initialize()
    local db = _G.YiboCraftingDB
    if type(db) ~= "table" then db = {} end
    if db.schemaVersion ~= nil and db.schemaVersion ~= 1 then
        return nil, "不支持的 YiboCraftingDB 版本。"
    end
    db.schemaVersion = 1
    db.characters = type(db.characters) == "table" and db.characters or {}
    db.settings = type(db.settings) == "table" and db.settings or {}
    _G.YiboCraftingDB = db
    self.db = db
    return db
end

function Store:GetProfession(characterID, professionID)
    local character = self.db and self.db.characters[characterID]
    return character and character.professions and character.professions[professionID] or nil
end

local function EnsureProfession(db, characterID, professionID)
    local character = db.characters[characterID] or { professions = {} }
    character.professions = character.professions or {}
    local profession = character.professions[professionID] or { learnedRecipeIDs = {} }
    profession.learnedRecipeIDs = profession.learnedRecipeIDs or {}
    profession.outputItemIDs = profession.outputItemIDs or {}
    profession.recipeCategories = profession.recipeCategories or {}
    character.professions[professionID] = profession
    db.characters[characterID] = character
    return profession
end

function Store:RecordAttempt(characterID, professionID, reason, state)
    if not self.db then return nil, "数据库尚未初始化。" end
    if type(characterID) ~= "string" or characterID == "" or
        type(professionID) ~= "number" or professionID < 1 then
        return nil, "角色或专业 ID 无效。"
    end
    local profession = EnsureProfession(self.db, characterID, professionID)
    profession.lastAttempt = { at = Now(), reason = reason or "unknown", state = state or "unavailable" }
    return true
end

function Store:ApplyObservation(characterID, professionID, ids, reason, state, outputItemIDs, recipeCategories)
    if type(characterID) ~= "string" or characterID == "" or
        type(professionID) ~= "number" or professionID < 1 then
        return nil, "角色或专业 ID 无效。"
    end
    local db = self.db
    if not db then return nil, "数据库尚未初始化。" end
    local profession = EnsureProfession(db, characterID, professionID)
    local seen, added = {}, 0
    for _, id in ipairs(ids or {}) do
        if type(id) == "number" and id > 0 and id % 1 == 0 and not seen[id] then
            seen[id] = true
            if not profession.learnedRecipeIDs[id] then
                profession.learnedRecipeIDs[id] = true
                added = added + 1
            end
        end
    end
    for recipeID, itemID in pairs(outputItemIDs or {}) do
        if type(recipeID) == "number" and recipeID > 0 and recipeID % 1 == 0
            and type(itemID) == "number" and itemID > 0 and itemID % 1 == 0 then
            profession.outputItemIDs[recipeID] = itemID
        end
    end
    for recipeID, category in pairs(recipeCategories or {}) do
        if seen[recipeID] and type(category) == "string" and category ~= "" then
            profession.recipeCategories[recipeID] = category
        end
    end
    profession.lastAttempt = {
        at = Now(), reason = reason or "unknown", state = state or "partial",
        visibleRecipeCount = 0,
    }
    for _ in pairs(seen) do profession.lastAttempt.visibleRecipeCount = profession.lastAttempt.visibleRecipeCount + 1 end
    profession.lastAttempt.newlyRecordedCount = added
    return added
end

function Store:MoveCharacterID(oldID, newID)
    if not self.db or oldID == newID then return false end
    local old = self.db.characters[oldID]
    if not old then return false end
    local current = self.db.characters[newID]
    if current then
        current.professions = current.professions or {}
        for professionID, earlier in pairs(old.professions or {}) do
            local later = current.professions[professionID]
            if later then
                later.learnedRecipeIDs = later.learnedRecipeIDs or {}
                for id in pairs(earlier.learnedRecipeIDs or {}) do later.learnedRecipeIDs[id] = true end
                later.outputItemIDs = later.outputItemIDs or {}
                for recipeID, itemID in pairs(earlier.outputItemIDs or {}) do
                    later.outputItemIDs[recipeID] = later.outputItemIDs[recipeID] or itemID
                end
                later.recipeCategories = later.recipeCategories or {}
                for recipeID, category in pairs(earlier.recipeCategories or {}) do
                    later.recipeCategories[recipeID] = later.recipeCategories[recipeID] or category
                end
            else current.professions[professionID] = earlier end
        end
    else self.db.characters[newID] = old end
    self.db.characters[oldID] = nil
    return true
end

function Store:GetRecipeState(characterID, professionID, recipeID)
    local profession = self:GetProfession(characterID, professionID)
    if profession and profession.learnedRecipeIDs and profession.learnedRecipeIDs[recipeID] then
        return "learned"
    end
    return "unknown"
end

function Store:GetKnownRecipeIDs(characterID, professionID)
    local profession = self:GetProfession(characterID, professionID)
    local ids = {}
    for id in pairs(profession and profession.learnedRecipeIDs or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end
