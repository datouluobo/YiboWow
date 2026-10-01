local Addon = _G.YiboCrafting
local Core = _G.YiboCore
local Collector = {}
Addon.Collector = Collector

local NON_CATEGORY_HEADERS = { ["全部"] = true, ["搜索"] = true, All = true, Search = true }

local function RecipeID(link)
    if type(link) ~= "string" then return nil end
    local family, id = link:match("|H([^:|]+):(%d+)")
    if family == "spell" or family == "enchant" or family == "trade" then return tonumber(id) end
end

local function OwnWindowShown()
    if not (TradeSkillFrame and TradeSkillFrame.IsShown and TradeSkillFrame:IsShown()) then return false end
    local function ReadFlag(name)
        local callback = _G[name]
        if type(callback) ~= "function" then return nil end
        local ok, value = pcall(callback)
        if not ok then return nil end
        return value == true
    end
    local linked, guild = ReadFlag("IsTradeSkillLinked"), ReadFlag("IsTradeSkillGuild")
    if linked == true or guild == true then return false end
    -- MoP Classic does not expose IsTradeSkillGuild.  A shown frame with an
    -- explicit false result from either source check is still an own-window
    -- candidate; unavailable optional checks must not suppress every scan.
    return linked == false or guild == false
end

local function CurrentProfession(characterID)
    if not (Core and Core.DataDomains) then return nil end
    local domain = Core.DataDomains:Get(characterID, "professions")
    if not domain or domain.state ~= "known" then return nil end
    local line = type(GetTradeSkillLine) == "function" and GetTradeSkillLine() or nil
    if type(line) ~= "string" or line == "" or line == "UNKNOWN" then return nil end
    local id
    for _, entry in ipairs(domain.data and domain.data.professions or {}) do
        if entry.name == line and type(entry.id) == "number" then
            if id and id ~= entry.id then return nil end
            id = entry.id
        end
    end
    return id
end

function Collector:Scan(reason)
    if not OwnWindowShown() then return nil, "own-window-unavailable" end
    if not (Core and Core.Characters and Core.Characters.GetCurrentID) then return nil, "core-unavailable" end
    local characterID = Core.Characters:GetCurrentID()
    local professionID = CurrentProfession(characterID)
    if not professionID then return nil, "profession-unconfirmed" end
    if type(GetNumTradeSkills) ~= "function" or type(GetTradeSkillInfo) ~= "function" or
        type(GetTradeSkillRecipeLink) ~= "function" then
        Addon.Store:RecordAttempt(characterID, professionID, reason, "unavailable")
        return nil, "legacy-api-unavailable"
    end
    local ok, result = pcall(function()
        local count = GetNumTradeSkills()
        if type(count) ~= "number" or count < 0 or count > 10000 then error("invalid-row-count") end
        local ids, seen, outputItemIDs, recipeCategories = {}, {}, {}, {}
        local category, subcategory
        for index = 1, count do
            local name, difficulty = GetTradeSkillInfo(index)
            if difficulty == "header" then
                category, subcategory = not NON_CATEGORY_HEADERS[name] and name or nil, nil
            elseif difficulty == "subheader" then
                subcategory = name
            elseif difficulty then
                local id = RecipeID(GetTradeSkillRecipeLink(index))
                if id then
                    if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
                    if type(category) == "string" and category ~= "" then
                        recipeCategories[id] = subcategory and (category .. " · " .. subcategory) or category
                    end
                    local outputLink
                    if type(GetTradeSkillItemLink) == "function" then
                        local linkOK, link = pcall(GetTradeSkillItemLink, index)
                        if linkOK then outputLink = link end
                    end
                    local itemID = type(outputLink) == "string" and tonumber(outputLink:match("item:(%d+)"))
                    if itemID and itemID > 0 then outputItemIDs[id] = itemID end
                end
            end
        end
        return { ids = ids, outputItemIDs = outputItemIDs, recipeCategories = recipeCategories, rowCount = count }
    end)
    if not ok then
        Addon.Store:RecordAttempt(characterID, professionID, reason, "error")
        return nil, "legacy-api-error"
    end
    local added = Addon.Store:ApplyObservation(characterID, professionID, result.ids, reason, "partial", result.outputItemIDs, result.recipeCategories)
    if not added then return nil, "store-unavailable" end
    result.professionID, result.added = professionID, added
    if Addon.NotifyPageChanged then Addon:NotifyPageChanged() end
    return result
end
