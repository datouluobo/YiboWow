local Boot = dofile("_NonRelease/VaultForever/Smoke.lua")
local count = 0
local function Check(value, message) count = count + 1; assert(value, message) end
local empty, equipped, family = false, 22250, 32
local env, core, vault = Boot(nil, nil, function(e)
    local slots, info, free = e.C_Container.GetContainerNumSlots, e.C_Container.GetContainerItemInfo, e.C_Container.GetContainerNumFreeSlots
    local inventory = e.GetInventoryItemID
    e.C_Container.GetContainerNumSlots = function(id) return id == 8 and 12 or slots(id) end
    e.C_Container.GetContainerItemInfo = function(id, slot)
        if id == 8 then return not empty and slot == 1 and { itemID = 2447, stackCount = 1 } or nil end
        return info(id, slot)
    end
    e.C_Container.GetContainerNumFreeSlots = function(id)
        if id == 8 then return empty and 12 or 11, empty and 0 or 32 end
        return free(id)
    end
    e.C_Container.ContainerIDToInventoryID = function(id) return id + 100 end
    e.GetInventoryItemID = function(unit, slot) if slot == 108 then return equipped end; return inventory(unit, slot) end
    e.C_Item.GetItemFamily = function(id) return id == equipped and family or nil end
end, false)
local function Snapshot()
    Check(vault:ScanBankContainer(8), "bank container scan commits")
    return vault:GetCharacterCoverage(env.TEST_GUID, "bank")["8"]
end
local before = Snapshot()
Check(before.capacity.bagType == 32 and before.capacity.freeSlots == 11 and before.recordCount == 1, "occupied herb bag")
empty = true
local after = Snapshot()
Check(after.capacity.bagType == 32 and after.capacity.freeSlots == 12 and after.recordCount == 0, "empty herb bag retains equipped item family despite reported zero")
local groups = vault.BagCapacity:Group({ locations = { after } }, "bank")
Check(#groups == 1 and groups[1].emptyLabelKey == "CAPACITY.HERBS" and groups[1].emptySlots == 12, "empty herb bag remains herb tile")
local records = vault:GetCharacterRecords(env.TEST_GUID, "bank", 2447)
Check(#records == 0, "removed herb has no ghost record")
equipped, family = 10050, 0
local replaced = Snapshot()
Check(replaced.capacity.bagType == 0, "same-size replacement with ordinary bag does not reuse old herb type")
Check(vault.BagCapacity:Group({ locations = { replaced } }, "bank")[1].emptyLabelKey == "CAPACITY.GENERAL", "ordinary replacement yields ordinary tile")
env.C_Item.GetItemFamily = function() return nil end
local unknown = Snapshot()
Check(unknown.capacity.bagType == nil and unknown.capacity.freeSlots == 12, "unavailable item family preserves count with unknown classification")
Check(vault.BagCapacity:Group({ locations = { unknown } }, "bank")[1].emptyLabelKey == "CAPACITY.UNKNOWN", "no guessed ordinary capacity")
Check(vault.BagCapacity:ResolveContainerType(8, 32, 0) == 32, "positive native type remains usable")
Check(vault.BagCapacity:ResolveContainerType(8, 0, 1) == 0, "nonempty ordinary native fallback remains usable")
Check(vault.BagCapacity:ResolveContainerType(0, nil, 0) == 0 and vault.BagCapacity:ResolveContainerType(-1, nil, 0) == 0, "built-in containers stay general")
env.C_Item.GetItemFamily = function() error("not ready") end
Check(vault.BagCapacity:ResolveContainerType(8, 0, 0) == nil, "native failure does not invent a type")
env.GetItemFamily = function() return 32 end
env.C_Item.GetItemFamily = nil
Check(vault.BagCapacity:ResolveContainerType(8, 0, 0) == 32, "legacy global item-family API supported")
env.ContainerIDToInventoryID = env.C_Container.ContainerIDToInventoryID
env.C_Container.ContainerIDToInventoryID = nil
Check(vault.BagCapacity:ResolveContainerType(8, 0, 0) == 32, "legacy global inventory-slot API supported")
print("Vault EmptyBagFamilySpec passed: " .. count .. " checks")
