local refreshes = 0

YiboAutoOpen = nil
dofile("YiboAutoOpen/Bootstrap.lua")

YiboAutoOpen.db = { scanExistingOnLogin = true }
YiboAutoOpen.Queue = { RequestScan = function() refreshes = refreshes + 1 end }
YiboAutoOpen.CoreIntegration = { Initialize = function() end }

assert(YiboAutoOpen:StartPostLogin() == true, "the first login transition should start")
assert(YiboAutoOpen:StartPostLogin() == false, "later world transitions must not restart login")
assert(YiboAutoOpen:StartPostLogin() == false, "opening settings must not restart login")
assert(refreshes == 1, "the login scan should be requested exactly once")

print("Startup lifecycle spec passed")
