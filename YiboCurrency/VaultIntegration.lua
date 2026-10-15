local Addon = _G.YiboCurrency

-- Vault is optional. Query by explicit character IDs so its last recorded
-- personal inventory can fill item-token balances for cached characters.
local function VaultItems()
    local core = _G.YiboCore
    local descriptor = core and core.Contracts and core.Contracts:Resolve("vault.items", { major = 1, minMinor = 0 })
    if not descriptor then return end
    return {
        HasCapability = function(_, name, minimumVersion)
            return core.Contracts:Call(Addon.NAME, descriptor, "HasCapability", { name = name, minimumVersion = minimumVersion })
        end,
        Query = function(_, request) return core.Contracts:Call(Addon.NAME, descriptor, "Query", request) end,
        GetPersonalCounts = function(_, request) return core.Contracts:Call(Addon.NAME, descriptor, "GetPersonalCounts", request) end,
    }
end

local function CountsAPI()
    local vault = VaultItems()
    if vault and vault:HasCapability("items.personal-counts", 1) then return vault end
end

local function CharacterIDs(characters)
    local ids, seen = {}, {}
    for _, character in ipairs(characters or {}) do
        local id = character and character.id
        if type(id) == "string" and id ~= "" and not seen[id] then
            ids[#ids + 1], seen[id] = id, true
        end
    end
    return ids
end

function Addon:GetVaultPersonalCounts(characters, itemIDs)
    local vault = CountsAPI()
    if not vault or #itemIDs == 0 then return nil end
    local ok, result = pcall(vault.GetPersonalCounts, vault, {
        scope = { mode = "characters", characterIDs = CharacterIDs(characters) }, itemIDs = itemIDs,
    })
    if not (ok and type(result) == "table" and type(result.characters) == "table") then return nil end
    for _, row in pairs(result.characters) do
        if type(row) ~= "table" or type(row.items) ~= "table" or type(row.coverage) ~= "table"
            or type(row.coverage.bags) ~= "table" or type(row.coverage.bank) ~= "table" then return nil end
        for _, source in ipairs({ "bags", "bank", "equipment" }) do
            local coverage = row.coverage[source]
            if coverage ~= nil and (type(coverage) ~= "table" or type(coverage.hasSnapshot) ~= "boolean") then return nil end
        end
        for _, item in pairs(row.items) do
            if type(item) ~= "table" then return nil end
            for _, source in ipairs({ "bags", "bank", "equipment" }) do
                local count = item[source]
                if count ~= nil and (type(count) ~= "number" or count < 0 or count % 1 ~= 0) then return nil end
            end
        end
    end
    return result
end

function Addon:GetVaultItemBalance(character, itemID)
    itemID = tonumber(itemID)
    if not character or not itemID then return nil end
    local result = self:GetVaultPersonalCounts({ character }, { itemID })
    local row = result and result.characters[character.id]
    local item = row and row.items[itemID]
    if not item then return nil end
    local bagsKnown, bankKnown = row.coverage.bags.hasSnapshot, row.coverage.bank.hasSnapshot
    local equipmentKnown = row.coverage.equipment and row.coverage.equipment.hasSnapshot or false
    if not bagsKnown and not bankKnown and not equipmentKnown then return nil end
    return { carried = item.bags, bank = item.bank, equipped = item.equipment,
        bagsKnown = bagsKnown, bankKnown = bankKnown, equipmentKnown = equipmentKnown }
end

function Addon:GetVaultItemDetail(entry, characters)
    if not entry or entry.source ~= "item" then return nil end
    local itemID = tonumber(entry.itemID)
    if not itemID or itemID <= 0 or itemID % 1 ~= 0 then return nil end
    local vault = VaultItems()
    if not vault or not vault:HasCapability("items.query", 1) then return nil end
    local ids = CharacterIDs(characters)
    local ok, result = pcall(vault.Query, vault, {
        scope = { mode = "characters", characterIDs = ids },
        itemID = itemID,
        identityMode = "item-id",
        sources = { "bags", "mail", "bank", "auction", "equipment", "guild-bank" },
        includeStale = true,
    })
    if ok and type(result) == "table" and type(result.records) == "table"
        and type(result.totals) == "table" then return result end
    return nil
end
