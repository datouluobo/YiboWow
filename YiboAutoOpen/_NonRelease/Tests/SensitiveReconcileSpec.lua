local merchantVisible = false
MerchantFrame = { IsVisible = function() return merchantVisible end }
YiboAutoOpen = {
    runtime = { sensitiveFrames = { merchant = true, bank = true, void = true } },
}
dofile("YiboAutoOpen/Safety.lua")

YiboAutoOpen.Safety:ReconcileSensitiveFrames()
assert(not YiboAutoOpen.runtime.sensitiveFrames.merchant, "a hidden known frame must clear a missed-close marker")
assert(not YiboAutoOpen.runtime.sensitiveFrames.bank, "a missing frame must clear a stale marker")
assert(not YiboAutoOpen.runtime.sensitiveFrames.void, "an unavailable sensitive frame must not leave a permanent pause")

merchantVisible = true
YiboAutoOpen.Safety:SetSensitive("MERCHANT_SHOW", true)
YiboAutoOpen.Safety:ReconcileSensitiveFrames()
assert(YiboAutoOpen.runtime.sensitiveFrames.merchant, "a currently visible sensitive frame must remain blocked")

print("Sensitive reconcile spec passed")
