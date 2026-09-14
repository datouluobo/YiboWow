YiboAutoOpen = {}
dofile("YiboAutoOpen/Defaults.lua")

assert(YiboAutoOpen.LIMITS.maxRetries == 2)
assert(YiboAutoOpen.LIMITS.operationTimeout > 0)

print("Queue limits spec passed")
