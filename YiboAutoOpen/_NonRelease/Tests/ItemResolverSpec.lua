YiboAutoOpen = {}
dofile("YiboAutoOpen/Mists/LegacyResolver.lua")

assert(YiboAutoOpen.ItemResolver:Resolve("123") == 123)
assert(YiboAutoOpen.ItemResolver:Resolve("item:456") == 456)

print("Item resolver spec passed")
