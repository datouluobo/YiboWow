local Addon = _G.YiboBuilds
local Enhancements = {}
Addon.Enhancements = Enhancements

local function Read(callback, ...)
    if type(callback) ~= "function" then return end
    local ok, value = pcall(callback, ...)
    if ok and Addon.Store:Plain(value) then return value end
end

local function ProfessionContext()
    local api = C_TradeSkillUI
    local enchanting = Enum and Enum.Profession and Enum.Profession.Enchanting
    if not api or enchanting == nil or not (ProfessionsFrame and ProfessionsFrame:IsShown())
        or Read(api.IsTradeSkillReady) ~= true or Read(api.IsTradeSkillLinked) ~= false
        or Read(api.IsTradeSkillGuild) ~= false or Read(api.IsTradeSkillGuildMember) ~= false
        or Read(api.IsNPCCrafting) ~= false then return end
    local info = Read(api.GetBaseProfessionInfo)
    if info and Addon.Store:Plain(info.profession) and info.profession == enchanting then return api end
end

local function Target(slot, itemLink)
    if not itemLink or Read(GetInventoryItemLink, "player", slot) ~= itemLink then return end
    if not (ItemLocation and C_Item) then return end
    local location = ItemLocation:CreateFromEquipmentSlot(slot)
    local guid = Read(C_Item.GetItemGUID, location)
    if type(guid) == "string" and guid ~= "" then return location, guid end
end

local function RequiredMaterials(schematic)
    local slots = schematic.reagentSlotSchematics
    if not Addon.Store:Plain(slots) or type(slots) ~= "table" then return {}, true end
    local materials, byItem = {}, {}
    local needsNative = false
    local basic = Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
    local itemSlot = Enum.TradeskillSlotDataType and Enum.TradeskillSlotDataType.Reagent
    for _, slot in ipairs(slots) do
        local required = slot.required
        if not Addon.Store:Plain(required) or type(required) ~= "boolean" then
            needsNative = true
        elseif required then
            local reagents, quantity = slot.reagents, slot.quantityRequired
            local isBasic = basic ~= nil and Addon.Store:Plain(slot.reagentType) and slot.reagentType == basic
                and itemSlot ~= nil and Addon.Store:Plain(slot.dataSlotType) and slot.dataSlotType == itemSlot
            local reagent = isBasic and Addon.Store:Plain(reagents) and type(reagents) == "table"
                and #reagents == 1 and reagents[1]
            local id = Addon.Store:Plain(reagent) and type(reagent) == "table" and reagent.itemID
            if Addon.Store:Integer(id, 1, 2147483647) and Addon.Store:Integer(quantity, 1, 2147483647) then
                local material = byItem[id]
                if material then
                    material.quantity = material.quantity + quantity
                else
                    material = {id=id, quantity=quantity}
                    byItem[id] = material
                    materials[#materials + 1] = material
                end
            else
                needsNative = true
            end
        end
    end
    return materials, needsNative
end

local function Candidate(api, recipeID, guid)
    local info = Read(api.GetRecipeInfo, recipeID)
    if type(info) ~= "table" or not Addon.Store:Plain(info.learned)
        or not Addon.Store:Plain(info.isEnchantingRecipe) then return nil, true end
    if info.learned ~= true or info.isEnchantingRecipe ~= true then return end
    if not Addon.Store:Plain(info.name) or type(info.name) ~= "string" then return nil, true end

    local schematic = Read(api.GetRecipeSchematic, recipeID, false)
    local recipeType = Enum.TradeskillRecipeType
    if type(schematic) ~= "table" or not recipeType
        or not Addon.Store:Plain(schematic.recipeType) then return nil, true end
    if schematic.recipeType ~= recipeType.Enchant then return end

    local targets = Read(api.GetEnchantItems, recipeID, {})
    if type(targets) ~= "table" then return nil, true end
    for _, allowed in ipairs(targets) do
        if Addon.Store:Plain(allowed) and allowed == guid then
            local defaults = Addon.Store:Plain(info.supportsQualities) and info.supportsQualities == false
                and Addon.Store:Plain(schematic.reagentSlotSchematics) and type(schematic.reagentSlotSchematics) == "table"
                and Enum.CraftingReagentType and Enum.TradeskillSlotDataType
            if defaults then
                for _, reagent in ipairs(schematic.reagentSlotSchematics) do
                    if not Addon.Store:Plain(reagent.reagentType)
                        or reagent.reagentType ~= Enum.CraftingReagentType.Basic
                        or not Addon.Store:Plain(reagent.dataSlotType)
                        or reagent.dataSlotType ~= Enum.TradeskillSlotDataType.Reagent then
                        defaults = false
                        break
                    end
                end
            end
            local count = defaults and Read(api.GetCraftableCount, recipeID)
            local craftable = Addon.Store:Plain(info.disabled) and info.disabled == false
                and Addon.Store:Plain(info.craftable) and info.craftable == true
            local materials, needsNative = RequiredMaterials(schematic)
            return {id=recipeID, name=info.name, guid=guid, materials=materials, needsNativeMaterials=needsNative,
                ready=not not (defaults and craftable and type(count) == "number" and count >= 1
                    and type(api.CraftEnchant) == "function")}
        end
    end
end

function Enhancements:ReadCarriedMaterial(itemID)
    local count = Read(C_Item and C_Item.GetItemCount, itemID, false, false, false, false)
    if Addon.Store:Integer(count, 0, 2147483647) then return count end
end

function Enhancements:GetCandidates(slot, itemLink)
    local api = ProfessionContext()
    if not api then return nil, "FOREVER.ENCHANT_OPEN_PROFESSION" end
    local _, guid = Target(slot, itemLink)
    local recipes = guid and Read(api.GetAllRecipeIDs)
    if type(recipes) ~= "table" then return nil, "FOREVER.ENCHANT_UNAVAILABLE" end
    local candidates, partial = {}, false
    for _, id in ipairs(recipes) do
        if Addon.Store:Integer(id, 1, 2147483647) then
            local candidate, unavailable = Candidate(api, id, guid)
            if candidate then candidates[#candidates + 1] = candidate end
            partial = partial or unavailable
        end
    end
    table.sort(candidates, function(a, b) return a.name == b.name and a.id < b.id or a.name < b.name end)
    return candidates, partial and "FOREVER.ENCHANT_UNAVAILABLE" or nil
end

function Enhancements:Apply(slot, itemLink, candidate)
    if InCombatLockdown and InCombatLockdown() then return false end
    local api = ProfessionContext()
    local location, guid = Target(slot, itemLink)
    if not (api and location and guid == candidate.guid) then return false end
    local selected = Candidate(api, candidate.id, guid)
    if not selected or not selected.ready then return false end
    return pcall(api.CraftEnchant, candidate.id, 1, {}, location, false)
end

function Enhancements:OpenRecipe(slot, itemLink, candidate)
    if InCombatLockdown and InCombatLockdown() then return false end
    local api = ProfessionContext()
    local _, guid = Target(slot, itemLink)
    if not (api and guid and guid == candidate.guid and Candidate(api, candidate.id, guid)
        and type(api.OpenRecipe) == "function") then return false end
    return pcall(api.OpenRecipe, candidate.id)
end

function Enhancements:Read(item)
    local link = item.itemLink
    if not Addon.Store:Plain(link) or type(link) ~= "string" then return nil end
    local payload = link:match("|Hitem:([^|]*)|h") or link:match("^item:([^|]*)$")
    if not payload then return nil end
    local itemID, enchant = (payload .. ":"):match("^(%d+):(%d*):")
    if item.itemID == 0 or tonumber(itemID) ~= item.itemID then return nil end
    local enchantID = enchant == "" and 0 or tonumber(enchant)
    if Addon.Store:Integer(enchantID, 0, 2147483647) then return enchantID end
end

function Enhancements:GetEnchantEffect(item, enchantID)
    if not enchantID or enchantID==0 then return nil end
    local lineTypes=Enum and Enum.TooltipDataLineType
    local enchantType=lineTypes and lineTypes.ItemEnchantmentPermanent
    local getTooltip=C_TooltipInfo and C_TooltipInfo.GetHyperlink
    if enchantType==nil or type(getTooltip)~="function" then return nil end
    local store=Addon.Store
    local ok,tooltip=pcall(getTooltip,item.itemLink)
    if not ok or not store:Plain(tooltip) or type(tooltip)~="table"
        or not store:Plain(tooltip.lines) or type(tooltip.lines)~="table" then return nil end
    local effect, matches=nil,0
    for _,line in ipairs(tooltip.lines) do
        if store:Plain(line) and type(line)=="table" and store:Plain(line.type) and line.type==enchantType then
            local id=line.enchantID
            if store:Plain(id) and id==nil then id=line.itemEnchantmentID end
            if store:Plain(id) and (id==nil or id==enchantID) then
                local text=line.leftText
                if not store:Plain(text) or type(text)~="string" or not text:find("%S") then text=line.rightText end
                if store:Plain(text) and type(text)=="string" and text:find("%S") then
                    if id==enchantID then return text end
                    effect,matches=text,matches+1
                end
            end
        end
    end
    if matches==1 then return effect end
end
