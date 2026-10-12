local Addon = _G.YiboCrafting
local Core = _G.YiboCore
local function L(key, ...)
    local fullKey = "UI." .. key
    return Core.Locale:Get("YiboCrafting", fullKey, ...)
end
local Store = {}
Addon.Store = Store

local function Now()
    return (GetServerTime and GetServerTime()) or time()
end

function Store:Initialize()
    local db = _G.YiboCraftingDB
    if type(db) ~= "table" then db = {} end
    if db.schemaVersion ~= nil and db.schemaVersion ~= 1 and db.schemaVersion ~= 2 then
        return nil, L("DB_VERSION")
    end
    db.schemaVersion = 2
    db.characters = type(db.characters) == "table" and db.characters or {}
    db.settings = type(db.settings) == "table" and db.settings or {}
    db.settings.previewColumns = type(db.settings.previewColumns) == "table" and db.settings.previewColumns
        or { ["recipe-name"] = true, ["recipe-state"] = true }
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
    profession.recipeSpellSnapshot = type(profession.recipeSpellSnapshot) == "table" and profession.recipeSpellSnapshot or nil
    character.professions[professionID] = profession
    db.characters[characterID] = character
    return profession
end

function Store:RecordAttempt(characterID, professionID, reason, state)
    if not self.db then return nil, L("DB_UNINITIALIZED") end
    if type(characterID) ~= "string" or characterID == "" or
        type(professionID) ~= "number" or professionID < 1 then
        return nil, L("INVALID_ID")
    end
    local profession = EnsureProfession(self.db, characterID, professionID)
    profession.lastAttempt = { at = Now(), reason = reason or "unknown", state = state or "unavailable" }
    return true
end

function Store:ApplyObservation(characterID, professionID, ids, reason, state, outputItemIDs, recipeCategories)
    if type(characterID) ~= "string" or characterID == "" or
        type(professionID) ~= "number" or professionID < 1 then
        return nil, L("INVALID_ID")
    end
    local db = self.db
    if not db then return nil, L("DB_UNINITIALIZED") end
    local profession = EnsureProfession(db, characterID, professionID)
    local changed = profession.lastAttempt == nil or profession.lastAttempt.state ~= (state or "partial")
    local seen, added = {}, 0
    for _, id in ipairs(ids or {}) do
        if type(id) == "number" and id > 0 and id % 1 == 0 and not seen[id] then
            seen[id] = true
            if not profession.learnedRecipeIDs[id] then
                profession.learnedRecipeIDs[id] = true
                added = added + 1
                changed = true
            end
        end
    end
    for recipeID, itemID in pairs(outputItemIDs or {}) do
        if type(recipeID) == "number" and recipeID > 0 and recipeID % 1 == 0
            and type(itemID) == "number" and itemID > 0 and itemID % 1 == 0 then
            if profession.outputItemIDs[recipeID] ~= itemID then changed = true end
            profession.outputItemIDs[recipeID] = itemID
        end
    end
    for recipeID, category in pairs(recipeCategories or {}) do
        if seen[recipeID] and type(category) == "string" and category ~= "" then
            if profession.recipeCategories[recipeID] ~= category then changed = true end
            profession.recipeCategories[recipeID] = category
        end
    end
    local visibleCount = 0
    for _ in pairs(seen) do visibleCount = visibleCount + 1 end
    if not profession.lastAttempt or profession.lastAttempt.visibleRecipeCount ~= visibleCount then changed = true end
    profession.lastAttempt = {
        at = Now(), reason = reason or "unknown", state = state or "partial",
        visibleRecipeCount = 0,
    }
    for _ in pairs(seen) do profession.lastAttempt.visibleRecipeCount = profession.lastAttempt.visibleRecipeCount + 1 end
    profession.lastAttempt.newlyRecordedCount = added
    return added, changed
end

function Store:MoveCharacterID(oldID, newID)
    if not self.db or type(oldID) ~= "string" or type(newID) ~= "string" or oldID == newID then return false end
    self.db.goalCharacterAliases = self.db.goalCharacterAliases or {}
    self.db.goalCharacterAliases[oldID] = newID
    local counts = self.db.goalCraftCounts
    if counts and counts[oldID] then
        counts[newID] = counts[newID] or {}
        for spellID, count in pairs(counts[oldID]) do counts[newID][spellID] = math.max(counts[newID][spellID] or 0, count) end
        counts[oldID] = nil
    end
    local old = self.db.characters[oldID]
    if not old then return true end
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
                local oldSnapshot, newSnapshot = earlier.recipeSpellSnapshot, later.recipeSpellSnapshot
                if oldSnapshot and (not newSnapshot or (oldSnapshot.at or 0) > (newSnapshot.at or 0)) then
                    later.recipeSpellSnapshot = oldSnapshot
                end
            else current.professions[professionID] = earlier end
        end
    else self.db.characters[newID] = old end
    self.db.characters[oldID] = nil
    return true
end

function Store:ResolveCharacterID(id)
    local seen = {}
    local aliases = self.db and self.db.goalCharacterAliases or {}
    while id and aliases[id] and not seen[id] do seen[id], id = true, aliases[id] end
    return id
end

function Store:GetRecipeState(characterID, professionID, recipeID)
    local profession = self:GetProfession(characterID, professionID)
    local snapshot = profession and profession.recipeSpellSnapshot
    local catalog = Addon.RecipeCatalog
    if snapshot and catalog and snapshot.catalogVersion == catalog.catalogVersion
        and snapshot.source == "IsPlayerSpell" and type(snapshot.states) == "table" then
        local state = snapshot.states[recipeID]
        if state == true then return "learned" end
        if state == false then return "unlearned" end
    end
    if profession and profession.learnedRecipeIDs and profession.learnedRecipeIDs[recipeID] then
        return "learned"
    end
    return "unknown"
end

function Store:ApplyRecipeSpellSnapshot(characterID, professionID, states, catalogVersion, expectedCount)
    if not self.db then return nil, L("DB_UNINITIALIZED") end
    if type(characterID) ~= "string" or characterID == "" or type(professionID) ~= "number" or professionID < 1
        or type(states) ~= "table" or type(catalogVersion) ~= "string" or catalogVersion == ""
        or type(expectedCount) ~= "number" or expectedCount < 1 then
        return nil, L("INVALID_SNAPSHOT")
    end
    local count = 0
    for recipeID, learned in pairs(states) do
        if type(recipeID) ~= "number" or recipeID < 1 or recipeID % 1 ~= 0
            or type(learned) ~= "boolean" then
            return nil, L("INVALID_RECORD")
        end
        count = count + 1
    end
    if count ~= expectedCount then return nil, L("INCOMPLETE_SNAPSHOT") end
    local profession = EnsureProfession(self.db, characterID, professionID)
    local old = profession.recipeSpellSnapshot
    local changed = not old or old.catalogVersion ~= catalogVersion or old.count ~= count
    if not changed and type(old.states) ~= "table" then changed = true end
    if not changed then
        for recipeID, learned in pairs(states) do
            if old.states[recipeID] ~= learned then changed = true; break end
        end
    end
    profession.recipeSpellSnapshot = {
        at = Now(), source = "IsPlayerSpell", catalogVersion = catalogVersion,
        count = count, states = states,
    }
    profession.lastAttempt = { at = Now(), reason = "recipe-spell-scan", state = "complete", visibleRecipeCount = count }
    return true, changed
end

function Store:GetKnownRecipeIDs(characterID, professionID)
    local profession = self:GetProfession(characterID, professionID)
    local ids = {}
    for id in pairs(profession and profession.learnedRecipeIDs or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end
