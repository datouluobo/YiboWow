local Addon = _G.YiboVault
local Items = Addon.Items
local SOURCES = { "bags", "bank", "equipment" }

-- Runtime-only compact index. Building is spread across frames; a hover never
-- walks SavedVariables or sorts item records.
local index, generation = nil, 0

local function BuildSource(characterID, source)
    local character = Addon.db.byCharacter and Addon.db.byCharacter[characterID] or {}
    local locations = character[source] or {}
    local coverage = character.coverage and character.coverage[source] or {}
    local counts, known = {}, false
    for _, state in pairs(coverage) do
        if type(state) == "table" and state.completedScan then known = true; break end
    end
    for _, records in pairs(locations) do
        if type(records) == "table" then
            for _, record in ipairs(records) do
                local itemID, quantity = tonumber(record.itemID), tonumber(record.quantity)
                if itemID and itemID > 0 and quantity and quantity > 0 then
                    counts[itemID] = (counts[itemID] or 0) + quantity
                    known = true
                end
            end
        end
    end
    return { counts = counts, hasSnapshot = known }
end

function Items:WarmPersonalCountsIndex()
    generation = generation + 1
    index = nil
    local currentGeneration = generation
    local jobs, nextIndex, nextData = {}, 1, {}
    for characterID in pairs(Addon.db.byCharacter or {}) do
        for _, source in ipairs(SOURCES) do jobs[#jobs + 1] = { characterID, source } end
    end
    local function Step()
        if currentGeneration ~= generation then return end
        -- Two character/source pairs per frame bound work on large accounts.
        for _ = 1, 2 do
            local job = jobs[nextIndex]
            if not job then break end
            local characterID, source = job[1], job[2]
            local owner = nextData[characterID] or {}
            nextData[characterID] = owner
            owner[source] = BuildSource(characterID, source)
            nextIndex = nextIndex + 1
        end
        if nextIndex <= #jobs then
            if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0, Step) else Step() end
        else
            index = { revision = self:GetRevision(), characters = nextData }
            self.Events:Fire("VAULT_PERSONAL_COUNTS_READY", { apiVersion = self.API_VERSION, revision = index.revision })
        end
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0, Step) else Step() end
end

function Items:UpdatePersonalCountsIndex(source, characterID)
    if source ~= "bags" and source ~= "bank" and source ~= "equipment" then
        if index then index.revision = self:GetRevision() end
        return
    end
    if not index then
        self:WarmPersonalCountsIndex()
        return
    end
    local owner = index.characters[characterID] or {}
    index.characters[characterID] = owner
    owner[source] = BuildSource(characterID, source)
    index.revision = self:GetRevision()
end

function Items:GetPersonalCounts(options)
    if type(options) ~= "table" then return nil, "invalid-options" end
    local valid, errorCode = self._ValidateScope(options.scope)
    if not valid then return nil, errorCode end
    if type(options.itemIDs) ~= "table" then return nil, "invalid-item-ids" end
    local itemIDs, seen, count = {}, {}, 0
    for _, id in ipairs(options.itemIDs) do
        if type(id) ~= "number" or id <= 0 or id % 1 ~= 0 then return nil, "invalid-item-ids" end
        if not seen[id] then itemIDs[#itemIDs + 1], seen[id] = id, true end
    end
    for key in pairs(options.itemIDs) do
        count = count + 1
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or key > #options.itemIDs then return nil, "invalid-item-ids" end
    end
    if count ~= #options.itemIDs then return nil, "invalid-item-ids" end
    if index and index.revision ~= self:GetRevision() then self:WarmPersonalCountsIndex() end
    if not index then
        if generation == 0 then self:WarmPersonalCountsIndex() end
        if not index then return nil, "index-pending" end
    end
    local result = { apiVersion = 1, revision = index.revision, characters = {} }
    for _, character in ipairs(self._ResolveCharacters(options.scope)) do
        local cached = index.characters[character.id] or {}
        local bags, bank, equipment = cached.bags, cached.bank, cached.equipment
        local row = {
            coverage = { bags = { hasSnapshot = bags and bags.hasSnapshot or false },
                bank = { hasSnapshot = bank and bank.hasSnapshot or false },
                equipment = { hasSnapshot = equipment and equipment.hasSnapshot or false } },
            items = {},
        }
        for _, itemID in ipairs(itemIDs) do
            row.items[itemID] = {
                bags = bags and bags.hasSnapshot and (bags.counts[itemID] or 0) or nil,
                bank = bank and bank.hasSnapshot and (bank.counts[itemID] or 0) or nil,
                equipment = equipment and equipment.hasSnapshot and (equipment.counts[itemID] or 0) or nil,
            }
        end
        result.characters[character.id] = row
    end
    return result
end
