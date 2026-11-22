local Capacity = _G.YiboVault.BagCapacity

local function ValidMask(value)
    return type(value) == "number" and value >= 0 and value % 1 == 0
end

function Capacity:ResolveContainerType(bagID, reportedType, recordCount)
    if bagID == 0 or bagID == (tonumber(BANK_CONTAINER) or -1) then return 0 end
    local inventorySlot = C_Container and C_Container.ContainerIDToInventoryID or ContainerIDToInventoryID
    local itemFamily = C_Item and C_Item.GetItemFamily or GetItemFamily
    if type(inventorySlot) == "function" and type(GetInventoryItemID) == "function"
        and type(itemFamily) == "function" then
        local slotOK, slot = pcall(inventorySlot, bagID)
        if slotOK and type(slot) == "number" and slot > 0 then
            local itemOK, itemID = pcall(GetInventoryItemID, "player", slot)
            if itemOK and type(itemID) == "number" and itemID > 0 then
                local familyOK, family = pcall(itemFamily, itemID)
                if familyOK and ValidMask(family) then return family end
            end
        end
    end
    -- A zero reported for an emptied bag does not establish ordinary capacity.
    -- Never reuse a previous type: the player may have replaced the equipped bag.
    if ValidMask(reportedType) and (reportedType > 0 or recordCount > 0) then return reportedType end
end
