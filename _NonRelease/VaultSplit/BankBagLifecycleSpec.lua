local Boot = dofile("_NonRelease/VaultForever/Smoke.lua")
local count = 0
local function Check(value, message) count = count + 1; assert(value, message) end
local equipped, scans = true, 0
local env, core, vault, event, flush = Boot(nil, nil, function(e)
    e.C_Container.GetContainerNumSlots = function(id)
        if id == -1 then return 28 end
        if id == 8 and equipped then return 12 end
        return 0
    end
    e.C_Container.GetContainerItemInfo = function() return nil end
    e.C_Container.GetContainerNumFreeSlots = function(id)
        return id == -1 and 28 or (id == 8 and equipped and 12 or 0), 0
    end
    e.C_Container.ContainerIDToInventoryID = function(id) return id + 100 end
    e.GetInventoryItemID = function(_, slot) return slot == 108 and equipped and 22250 or nil end
    e.C_Item.GetItemFamily = function() return 32 end
end, false)
local scan = vault.ScanBankContainer
vault.ScanBankContainer = function(self, ...) scans = scans + 1; return scan(self, ...) end
local function Capacity()
    return vault:GetCharacterCoverage(env.TEST_GUID, "bank")["8"].capacity
end
event("BANKFRAME_OPENED"); flush()
Check(Capacity().totalSlots == 12 and Capacity().bagType == 32, "initial empty herb bag captured")
local before = scans
equipped = false
-- No BAG_UPDATE or BAG_UPDATE_DELAYED: the bank-slot event must suffice.
event("PLAYERBANKSLOTS_CHANGED", 32)
event("PLAYERBANKSLOTS_CHANGED", 32)
event("PLAYERBANKSLOTS_CHANGED", 32)
Check(scans == before, "bank slot notifications defer reads")
flush()
Check(scans == before + 8, "burst coalesces to one bounded bank pass")
Check(Capacity().totalSlots == 0 and Capacity().bagType == nil, "removed bag capacity replaced with zero")
local groups = vault.BagCapacity:Group({ locations = { { capacity = Capacity() } } }, "bank")
Check(#groups == 0, "removed herb tile disappears")
local after = scans
event("BAG_UPDATE_DELAYED"); flush()
Check(scans == after, "later delayed event does not duplicate bank pass")
equipped = true
event("PLAYERBANKSLOTS_CHANGED", 32); flush()
Check(Capacity().totalSlots == 12 and Capacity().freeSlots == 12 and Capacity().bagType == 32, "re-equipped bag captured without reload")
groups = vault.BagCapacity:Group({ locations = { { capacity = Capacity() } } }, "bank")
Check(#groups == 1 and groups[1].emptyLabelKey == "CAPACITY.HERBS", "herb tile restored")
before = scans
event("PLAYERBANKSLOTS_CHANGED", 32)
event("BAG_UPDATE_DELAYED"); flush()
Check(scans == before + 8, "delayed event before timer consumes dirty bank only once")
before = scans
event("PLAYERBANKSLOTS_CHANGED", 32)
event("BANKFRAME_CLOSED"); equipped = false; flush()
Check(scans == before, "bank close cancels queued reads")
Check(Capacity().totalSlots == 12, "closed bank retains previous capacity")
event("PLAYERBANKSLOTS_CHANGED", 32); event("BAG_UPDATE_DELAYED"); flush()
Check(scans == before, "closed bank notifications never read bank")
event("BANKFRAME_OPENED"); flush()
Check(Capacity().totalSlots == 0, "reopen replaces stale removed-bag snapshot")
before = scans
event("PLAYERBANKSLOTS_CHANGED", 32); event("BANKFRAME_CLOSED")
equipped = true
event("BANKFRAME_OPENED"); flush()
Check(scans == before + 8 and Capacity().totalSlots == 12, "old queued callback cannot scan a reopened bank")
before = scans
flush()
Check(scans == before, "no recurring scans")
print("Vault BankBagLifecycleSpec passed: " .. count .. " checks")
