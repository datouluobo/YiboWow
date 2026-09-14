local freeByBag = { [0] = 2 }

C_Container = {
    GetContainerNumFreeSlots = function(bag)
        local free = freeByBag[bag]
        if free == nil then return nil end
        return free, 0
    end,
}
InCombatLockdown = function() return false end
UnitIsDeadOrGhost = function() return false end
UnitInVehicle = function() return false end
UnitCastingInfo = function() return nil end
UnitChannelInfo = function() return nil end

YiboAutoOpen = {
    db = { enabled = true, minFreeSlots = 5 },
    runtime = { loggedIn = true, sensitiveFrames = {} },
}

dofile("YiboAutoOpen/BagAdapter.lua")
dofile("YiboAutoOpen/Safety.lua")

local ok, reason = YiboAutoOpen.Safety:CanRun()
assert(not ok and reason == "BAG_DATA_PENDING", "missing bag data must not be reported as zero free slots")

freeByBag = { [0] = 2, [1] = 4, [2] = 0, [3] = 0, [4] = 0 }
ok, reason = YiboAutoOpen.Safety:CanRun()
assert(ok and reason == nil, "known generic free slots above the threshold should be accepted")

freeByBag[1] = 1
ok, reason = YiboAutoOpen.Safety:CanRun()
assert(not ok and reason == "INSUFFICIENT_SPACE", "confirmed low free space should still pause opening")

print("Bag space readiness spec passed")
